#Requires -Version 5.1
<#
.SYNOPSIS
  Beendet alte VibesBoxSync-Prozesse, holt den Song-Detection-Branch,
  baut neu und startet die Release-EXE.

.NOTES
  Nur ASCII in dieser Datei (Windows PowerShell 5.1).
  WICHTIG: Frueher hat dieses Skript fest cursor/windows-sync-installer-b710
  ausgecheckt - dadurch kamen History-Fixes nie an. Default ist jetzt
  cursor/windows-song-detection-b710.
#>

[CmdletBinding()]
param(
  [string]$Branch = 'cursor/windows-song-detection-b710',
  [switch]$Fast,
  [switch]$NoStart,
  [string]$FlutterBat = "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat"
)

$ErrorActionPreference = 'Stop'
$ToolRoot = $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $ToolRoot '..\..')
Set-Location $ToolRoot

function Write-Step([string]$msg) {
  Write-Host ""
  Write-Host "==> $msg" -ForegroundColor Cyan
}

Write-Step "Alte Prozesse beenden"
Get-Process -Name 'VibesBoxSync','rb_now_playing' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Step ("git fetch/checkout/pull: {0}" -f $Branch)
Set-Location $RepoRoot
git fetch origin
git checkout $Branch
if ($LASTEXITCODE -ne 0) { throw "git checkout $Branch fehlgeschlagen." }
git pull origin $Branch
if ($LASTEXITCODE -ne 0) { throw "git pull $Branch fehlgeschlagen." }
Set-Location $ToolRoot

Write-Host ("Aktueller Branch: {0}" -f (git rev-parse --abbrev-ref HEAD))
Write-Host ("Commit: {0}" -f (git rev-parse --short HEAD))

$session = Get-Content -Raw -Encoding UTF8 '.\lib\tool_session.dart'
$mainCpp = Get-Content -Raw -Encoding UTF8 '.\windows\runner\main.cpp'
$win32 = Get-Content -Raw -Encoding UTF8 '.\windows\runner\win32_window.cpp'
$mainDart = Get-Content -Raw -Encoding UTF8 '.\lib\main.dart'
$rbHist = Get-Content -Raw -Encoding UTF8 '.\lib\rekordbox_history.dart'

if ($session -like '*FirebaseFunctions*' -or $session -notlike '*redeemRbToolCode(code)*') {
  throw 'tool_session.dart ist noch alt. Falscher Branch/Stand.'
}
if ($mainCpp -notlike '*Size size(360, 640)*') {
  throw 'main.cpp ohne Hochkant-Fenster. Falscher Stand.'
}
if ($mainCpp -like '*SetCurrentProcessExplicitAppUserModelID*') {
  throw 'main.cpp setzt noch AppUserModelID. Falscher Stand.'
}
if ($win32 -notlike '*RegisterClassEx*') {
  throw 'win32_window.cpp ohne RegisterClassEx. Falscher Stand.'
}
if ($mainDart -notlike '*_DjHistoryPanel*' -or $mainDart -notlike '*_liveHistory*') {
  throw 'main.dart ohne History-Panel (_DjHistoryPanel). Falscher Branch - brauche cursor/windows-song-detection-b710.'
}
if ($rbHist -notlike '*ORDER BY sh.created_at DESC*' -or $rbHist -notlike '*close();*') {
  throw 'rekordbox_history.dart ohne Live-Poll-Reconnect. Falscher Stand.'
}
Write-Host "Quellcode OK (Song-Detection + History-Panel)." -ForegroundColor Green

$pubspec = Get-Content -Raw -Encoding UTF8 '.\pubspec.yaml'
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw 'Version in pubspec.yaml nicht lesbar.'
}
$AppVersion = $Matches[1]
Write-Host ("Erwartete App-Version: {0}" -f $AppVersion) -ForegroundColor Yellow

Write-Step "Flutter + Installer bauen"
if ($Fast) {
  Write-Host "Fast: kein flutter clean (inkrementell)."
  # build_windows_installer.ps1 auf diesem Branch hat kein -Fast;
  # bei Bedarf vorherigen build behalten und direkt bauen.
  if (-not (Test-Path $FlutterBat)) { throw "Flutter fehlt: $FlutterBat" }
  & $FlutterBat pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get fehlgeschlagen.' }
  & $FlutterBat build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build windows fehlgeschlagen.' }
  & (Join-Path $ToolRoot 'build_windows_installer.ps1') -SkipFlutterBuild
} else {
  & (Join-Path $ToolRoot 'build_windows_installer.ps1') -FlutterBat $FlutterBat
}

$exe = Join-Path $ToolRoot 'build\windows\x64\runner\Release\VibesBoxSync.exe'
if (-not (Test-Path $exe)) { throw "EXE fehlt: $exe" }

$setup = Join-Path $ToolRoot ("dist\VibesBoxSync-Setup-{0}.exe" -f $AppVersion)

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host ("NEUER BUILD  Branch={0}  Version={1}" -f $Branch, $AppVersion) -ForegroundColor Green
Write-Host ("EXE: {0}" -f $exe)
if (Test-Path $setup) { Write-Host ("Setup: {0}" -f $setup) }
Write-Host "In den Einstellungen muss Version $AppVersion stehen." -ForegroundColor Yellow
Write-Host "History-Kasten unter Now Playing muss sichtbar sein." -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Green

if (-not $NoStart) {
  Write-Step "Starte NEUE EXE (build-Ordner, nicht alte Installation)"
  Start-Process -FilePath $exe
}
