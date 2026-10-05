#Requires -Version 5.1
<#
.SYNOPSIS
  Kopiert den VibesBox-Sync Windows-Installer nach public/sync und deployt Firebase Hosting.

.NOTES
  Version kommt aus tools/rb_now_playing/pubspec.yaml (eine Quelle).
  Download-URL bleibt immer gleich:
    https://vibesbox.app/download/vibesbox-sync-windows
  -> public/sync/VibesBox-Sync-windows.exe
  Die Sync-Seite muss nicht von Hand angepasst werden.
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

Write-Host "==> Version aus pubspec + Hosting-Meta syncen" -ForegroundColor Cyan
$Version = & (Join-Path $ToolRoot 'scripts\sync_version_from_pubspec.ps1') -UpdateHosting |
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

$DestDir = Join-Path $RepoRoot 'public\sync'
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

# Mac: feste Datei VibesBox-Sync-mac.pkg (Version nur in version.json)
$MacStable = "VibesBox-Sync-mac.pkg"
$MacPath = Join-Path $DestDir $MacStable
if (-not (Test-Path $MacPath)) {
  # Fallback: von Live laden (neuer stabiler Name oder alter versionsierter Name)
  $candidates = @(
    "https://vibesbox.app/sync/VibesBox-Sync-mac.pkg",
    "https://vibesbox.app/download/vibesbox-sync-mac"
  )
  if (-not $MacVersion) {
    $verJsonPath = Join-Path $DestDir 'version.json'
    if (Test-Path $verJsonPath) {
      $vj = Get-Content -Raw -Encoding UTF8 $verJsonPath
      if ($vj -match '"mac"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"') {
        $MacVersion = $Matches[1]
        $candidates += "https://vibesbox.app/sync/VibesBox-Sync-$MacVersion-mac.pkg"
      }
    }
  } else {
    $candidates += "https://vibesbox.app/sync/VibesBox-Sync-$MacVersion-mac.pkg"
  }
  $loaded = $false
  foreach ($MacUrl in $candidates) {
    try {
      Write-Host "==> Lade Mac-PKG von Live: $MacUrl" -ForegroundColor Cyan
      Invoke-WebRequest -Uri $MacUrl -OutFile $MacPath -UseBasicParsing
      Write-Host ("OK: {0} ({1} MB)" -f $MacPath, [math]::Round((Get-Item $MacPath).Length / 1MB, 1))
      $loaded = $true
      break
    } catch {
      Write-Host ("  nicht erreichbar: {0}" -f $MacUrl) -ForegroundColor Yellow
    }
  }
  if (-not $loaded) {
    Write-Host "WARN: Mac-PKG fehlt lokal und konnte nicht geladen werden. Windows-Deploy geht trotzdem." -ForegroundColor Yellow
  }
} else {
  Write-Host "Mac-PKG bereits lokal: $MacPath"
}

$DestName = "VibesBox-Sync-windows.exe"
$DestPath = Join-Path $DestDir $DestName

Write-Host "==> Kopiere Windows-Installer nach public\sync\$DestName" -ForegroundColor Cyan
Copy-Item -Force $SetupExe $DestPath
Write-Host ("OK: {0} ({1} MB)" -f $DestPath, [math]::Round((Get-Item $DestPath).Length / 1MB, 1))

# Alte versionsierte Windows-EXEs entfernen (Seite nutzt nur noch den festen Namen)
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
Write-Host "  https://vibesbox.app/download/vibesbox-sync-windows"
Write-Host "  https://vibesbox.app/sync/VibesBox-Sync-windows.exe"
Write-Host ""
Write-Host "Download (PowerShell):"
Write-Host "  Invoke-WebRequest -Uri https://vibesbox.app/download/vibesbox-sync-windows -OutFile `$env:USERPROFILE\Downloads\VibesBox-Sync-windows.exe"
Write-Host ""
Write-Host "Danach in der VibesBox-App (Admin -> VibesBox Sync):"
Write-Host "  Windows-Zielversion = $Version"
Write-Host "  Mindestversion anhaken, wenn alte Clients blockiert werden sollen"
Write-Host "  Download-URL = https://vibesbox.app/download/vibesbox-sync-windows"
