#Requires -Version 5.1
<#
.SYNOPSIS
  Kopiert den VibesBox-Sync Windows-Installer nach public/sync und deployt Firebase Hosting.

.NOTES
  Feste URLs:
    https://vibesbox.app/download/vibesbox-sync-windows  -> 302 -> /sync/VibesBox-Sync-windows.exe
    https://vibesbox.app/sync/VibesBox-Sync-windows.exe
  Prueft, dass Windows-EXE eine echte PE-Datei ist und Mac-PKG kein HTML.
#>

[CmdletBinding()]
param(
  [string]$SetupExe = "",
  [string]$MacVersion = ""
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ToolRoot = Join-Path $RepoRoot 'tools\rb_now_playing'
Set-Location $RepoRoot

function Test-BinaryMagic {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][byte[]]$Magic,
    [Parameter(Mandatory = $true)][long]$MinBytes,
    [Parameter(Mandatory = $true)][string]$Label
  )
  if (-not (Test-Path $Path)) {
    throw ("{0} fehlt: {1}" -f $Label, $Path)
  }
  $info = Get-Item $Path
  if ($info.Length -lt $MinBytes) {
    throw ("{0} zu klein ({1} Bytes): {2}" -f $Label, $info.Length, $Path)
  }
  $fs = [System.IO.File]::OpenRead($Path)
  try {
    $buf = New-Object byte[] $Magic.Length
    $read = $fs.Read($buf, 0, $Magic.Length)
  } finally {
    $fs.Close()
  }
  if ($read -lt $Magic.Length) {
    throw ("{0} unlesbar: {1}" -f $Label, $Path)
  }
  for ($i = 0; $i -lt $Magic.Length; $i++) {
    if ($buf[$i] -ne $Magic[$i]) {
      throw ("{0} ist keine gueltige Binaerdatei (falscher Dateikopf): {1}" -f $Label, $Path)
    }
  }
  # HTML-Fallback von Firebase erkennen
  $textHead = Get-Content -Path $Path -TotalCount 1 -ErrorAction SilentlyContinue
  if ("$textHead" -like '<!*' -or "$textHead" -like '<html*') {
    throw ("{0} ist HTML statt Installer: {1}" -f $Label, $Path)
  }
}

Write-Host "==> Version aus pubspec + Hosting-Meta syncen" -ForegroundColor Cyan
$syncScript = Join-Path $ToolRoot 'scripts\sync_version_from_pubspec.ps1'
$syncRaw = Get-Content -Raw -Encoding UTF8 $syncScript
if ($syncRaw -notlike '*SYNC_HOSTING_STABLE_v3*') {
  throw @"
Altes sync_version_from_pubspec.ps1 erkannt.

Einmal:
  git fetch origin cursor/windows-sync-installer-b710
  git checkout origin/cursor/windows-sync-installer-b710 -- scripts/deploy_sync_windows.ps1 scripts/pull_and_deploy_sync_windows.ps1 tools/rb_now_playing/scripts/sync_version_from_pubspec.ps1 public/sync/index.html public/sync/version.json firebase.json
  .\scripts\deploy_sync_windows.ps1
"@
}
$Version = & $syncScript -UpdateHosting |
  Select-Object -Last 1
$Version = ("{0}" -f $Version).Trim()
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
  throw ("Keine gueltige Version aus pubspec (bekommen: '{0}')." -f $Version)
}

if (-not $SetupExe) {
  $SetupExe = Join-Path $ToolRoot "dist\VibesBoxSync-Setup-$Version.exe"
}

if (-not (Test-Path $SetupExe)) {
  throw @"
Installer nicht gefunden:
  $SetupExe

Zuerst bauen:
  cd tools\rb_now_playing
  .\build_windows_installer.ps1
"@
}

# Windows-Quelle muss PE sein (MZ)
Test-BinaryMagic -Path $SetupExe -Magic ([byte[]](0x4D, 0x5A)) -MinBytes 5MB -Label 'Windows-Setup'

$DestDir = Join-Path $RepoRoot 'public\sync'
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

# Mac: feste Datei; echte PKG von Live holen (nie HTML speichern)
$MacStable = "VibesBox-Sync-mac.pkg"
$MacPath = Join-Path $DestDir $MacStable
$macOk = $false
if (Test-Path $MacPath) {
  try {
    # xar/pkg beginnt oft mit "xar!" 
    Test-BinaryMagic -Path $MacPath -Magic ([byte[]](0x78, 0x61, 0x72, 0x21)) -MinBytes 1MB -Label 'Mac-PKG (lokal)'
    $macOk = $true
    Write-Host "Mac-PKG bereits lokal und gueltig: $MacPath"
  } catch {
    Write-Host ("Lokale Mac-PKG ungueltig, lade neu: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    Remove-Item -Force $MacPath -ErrorAction SilentlyContinue
  }
}

if (-not $macOk) {
  if (-not $MacVersion) {
    $verJsonPath = Join-Path $DestDir 'version.json'
    if (Test-Path $verJsonPath) {
      $vj = Get-Content -Raw -Encoding UTF8 $verJsonPath
      if ($vj -match '"mac"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"') {
        $MacVersion = $Matches[1]
      }
    }
  }
  if (-not $MacVersion) { $MacVersion = '1.0.2' }

  $candidates = @(
    "https://vibesbox.app/sync/VibesBox-Sync-$MacVersion-mac.pkg",
    "https://vibesbox.app/sync/VibesBox-Sync-mac.pkg"
  )
  foreach ($MacUrl in $candidates) {
    try {
      Write-Host "==> Lade Mac-PKG von Live: $MacUrl" -ForegroundColor Cyan
      Invoke-WebRequest -Uri $MacUrl -OutFile $MacPath -UseBasicParsing
      Test-BinaryMagic -Path $MacPath -Magic ([byte[]](0x78, 0x61, 0x72, 0x21)) -MinBytes 1MB -Label 'Mac-PKG (download)'
      Write-Host ("OK: {0} ({1} MB)" -f $MacPath, [math]::Round((Get-Item $MacPath).Length / 1MB, 1))
      $macOk = $true
      break
    } catch {
      Write-Host ("  fehlgeschlagen: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
      Remove-Item -Force $MacPath -ErrorAction SilentlyContinue
    }
  }
  if (-not $macOk) {
    throw "Mac-PKG konnte nicht geladen werden. Ohne gueltige .pkg wuerde der Mac-Link HTML ausliefern."
  }
}

$DestName = "VibesBox-Sync-windows.exe"
$DestPath = Join-Path $DestDir $DestName

Write-Host "==> Kopiere Windows-Installer nach public\sync\$DestName" -ForegroundColor Cyan
Copy-Item -Force $SetupExe $DestPath
Test-BinaryMagic -Path $DestPath -Magic ([byte[]](0x4D, 0x5A)) -MinBytes 5MB -Label 'Windows-Hosting-EXE'
Write-Host ("OK: {0} ({1} MB)" -f $DestPath, [math]::Round((Get-Item $DestPath).Length / 1MB, 1))

# Alte versionsierte Windows-EXEs entfernen
Get-ChildItem -Path $DestDir -Filter 'VibesBox-Sync-*-windows.exe' -ErrorAction SilentlyContinue |
  ForEach-Object {
    Write-Host ("Entferne alte versionsierte Datei: {0}" -f $_.Name) -ForegroundColor Yellow
    Remove-Item -Force $_.FullName
  }

$verJsonPath = Join-Path $DestDir 'version.json'
$verJson = Get-Content -Raw -Encoding UTF8 $verJsonPath
if ($verJson -notlike ('*"windows": "{0}"*' -f $Version) -and $verJson -notlike ('*"windows":"{0}"*' -f $Version)) {
  throw ("version.json Windows-Version ist nicht {0}." -f $Version)
}

$firebase = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebase) {
  throw @"
Firebase CLI nicht gefunden. Installieren z. B.:
  npm install -g firebase-tools
Dann: firebase login
Danach dieses Skript erneut ausfuehren.
"@
}

Write-Host "==> firebase deploy --only hosting" -ForegroundColor Cyan
& firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { throw "firebase deploy fehlgeschlagen (Exit $LASTEXITCODE)" }

Write-Host ""
Write-Host "Fertig. Windows $Version online:" -ForegroundColor Green
Write-Host "  https://vibesbox.app/sync/"
Write-Host "  https://vibesbox.app/sync/VibesBox-Sync-windows.exe"
Write-Host "  https://vibesbox.app/download/vibesbox-sync-windows  (302 -> .exe)"
Write-Host ""
Write-Host "Download (PowerShell):"
Write-Host "  Invoke-WebRequest -Uri https://vibesbox.app/sync/VibesBox-Sync-windows.exe -OutFile `$env:USERPROFILE\Downloads\VibesBox-Sync-windows.exe"
Write-Host ""
Write-Host "Danach in der VibesBox-App (Admin -> VibesBox Sync):"
Write-Host "  Windows-Zielversion = $Version"
Write-Host "  Download-URL = https://vibesbox.app/download/vibesbox-sync-windows"
