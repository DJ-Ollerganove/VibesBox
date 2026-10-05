#Requires -Version 5.1
<#
.SYNOPSIS
  Kopiert den VibesBox-Sync Windows-Installer nach public/sync und deployt Firebase Hosting.

.NOTES
  Die .exe liegt absichtlich nicht im Git (.gitignore). Deploy muss lokal laufen.
#>

[CmdletBinding()]
param(
  [string]$SetupExe = "",
  [string]$Version = "1.0.2"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

if (-not $SetupExe) {
  $SetupExe = Join-Path $RepoRoot "tools\rb_now_playing\dist\VibesBoxSync-Setup-$Version.exe"
}

if (-not (Test-Path $SetupExe)) {
  throw @"
Installer nicht gefunden:
  $SetupExe

Zuerst bauen:
  cd tools\rb_now_playing
  .\build_windows_installer.ps1 -SkipFlutterBuild
"@
}

$DestDir = Join-Path $RepoRoot 'public\sync'
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
$DestName = "VibesBox-Sync-$Version-windows.exe"
$DestPath = Join-Path $DestDir $DestName

Write-Host "==> Kopiere Installer nach public\sync\$DestName" -ForegroundColor Cyan
Copy-Item -Force $SetupExe $DestPath
Write-Host "OK: $DestPath ($([math]::Round((Get-Item $DestPath).Length / 1MB, 1)) MB)"

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
Write-Host "Fertig. Downloads:" -ForegroundColor Green
Write-Host "  https://vibesbox.app/sync/"
Write-Host "  https://vibesbox.app/download/vibesbox-sync-windows"
Write-Host "  https://vibesbox.app/sync/$DestName"
