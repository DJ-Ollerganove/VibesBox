#Requires -Version 5.1
<#
.SYNOPSIS
  Kopiert den VibesBox-Sync Windows-Installer nach public/sync und deployt Firebase Hosting.

.NOTES
  Die .exe/.pkg liegen absichtlich nicht im Git (.gitignore).
  Vor dem Deploy wird die Live-Mac-.pkg geholt, damit sie nicht geloescht wird.
#>

[CmdletBinding()]
param(
  [string]$SetupExe = "",
  [string]$Version = "1.0.2",
  [string]$MacVersion = "1.0.2"
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
  .\build_windows_installer.ps1
"@
}

$DestDir = Join-Path $RepoRoot 'public\sync'
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

# Mac-PKG von Live sichern (sonst wuerde firebase deploy sie vom Hosting loeschen)
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

# Sicherstellen, dass die Sync-Seite den Windows-Link hat (Branch-Stand)
$SyncHtml = Join-Path $DestDir 'index.html'
$html = Get-Content -Raw -Encoding UTF8 $SyncHtml
$linkNeedle = "/sync/$DestName"
if ($html -notlike "*$linkNeedle*") {
  throw "public/sync/index.html verlinkt nicht auf $DestName. Bitte zuerst: git pull"
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
Write-Host "Fertig. Pruefen:" -ForegroundColor Green
Write-Host "  https://vibesbox.app/sync/"
Write-Host "  https://vibesbox.app/download/vibesbox-sync-windows"
Write-Host ("  https://vibesbox.app/sync/{0}" -f $DestName)
