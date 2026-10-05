#Requires -Version 5.1
<#
.SYNOPSIS
  Kopiert den VibesBox-Sync Windows-Installer nach public/sync und deployt Firebase Hosting.

.NOTES
  Version kommt aus tools/rb_now_playing/pubspec.yaml (eine Quelle).
  Hosting-Links (index.html + firebase.json) werden automatisch angepasst.
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

Write-Host "==> Version aus pubspec + Hosting-Links syncen" -ForegroundColor Cyan
$Version = & (Join-Path $ToolRoot 'scripts\sync_version_from_pubspec.ps1') -UpdateHosting
$Version = "$Version".Trim()
if (-not $Version) { throw "Keine Version aus pubspec." }

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

# Mac-Version aus der Sync-Seite lesen, falls nicht uebergeben
if (-not $MacVersion) {
  $htmlProbe = Get-Content -Raw -Encoding UTF8 (Join-Path $DestDir 'index.html')
  if ($htmlProbe -match 'VibesBox-Sync-([0-9]+\.[0-9]+\.[0-9]+)-mac\.pkg') {
    $MacVersion = $Matches[1]
  } else {
    $MacVersion = $Version
  }
}

$MacName = "VibesBox-Sync-$MacVersion-mac.pkg"
$MacPath = Join-Path $DestDir $MacName
if (-not (Test-Path $MacPath)) {
  $MacUrl = "https://vibesbox.app/sync/$MacName"
  Write-Host "==> Lade bestehende Mac-PKG von Live: $MacUrl" -ForegroundColor Cyan
  Invoke-WebRequest -Uri $MacUrl -OutFile $MacPath -UseBasicParsing
  Write-Host ("OK: {0} ({1} MB)" -f $MacPath, [math]::Round((Get-Item $MacPath).Length / 1MB, 1))
} else {
  Write-Host "Mac-PKG bereits lokal: $MacPath"
}

$DestName = "VibesBox-Sync-$Version-windows.exe"
$DestPath = Join-Path $DestDir $DestName

Write-Host "==> Kopiere Windows-Installer nach public\sync\$DestName" -ForegroundColor Cyan
Copy-Item -Force $SetupExe $DestPath
Write-Host ("OK: {0} ({1} MB)" -f $DestPath, [math]::Round((Get-Item $DestPath).Length / 1MB, 1))

$SyncHtml = Join-Path $DestDir 'index.html'
$html = Get-Content -Raw -Encoding UTF8 $SyncHtml
if ($html -notlike "*/sync/$DestName*") {
  throw "public/sync/index.html verlinkt nicht auf $DestName nach Version-Sync."
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
Write-Host ("  https://vibesbox.app/sync/{0}" -f $DestName)
Write-Host ""
Write-Host "Danach in der VibesBox-App (Admin -> VibesBox Sync):"
Write-Host "  Windows-Zielversion = $Version"
Write-Host "  Mindestversion anhaken, wenn alte Clients blockiert werden sollen"
Write-Host "  Download-URL = https://vibesbox.app/download/vibesbox-sync-windows"
