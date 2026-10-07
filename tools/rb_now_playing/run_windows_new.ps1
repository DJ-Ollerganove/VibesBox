#Requires -Version 5.1
<#
.SYNOPSIS
  Beendet alte VibesBoxSync-Prozesse, pullt, baut neu und startet die Release-EXE.
#>

$ErrorActionPreference = 'Stop'
$ToolRoot = $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $ToolRoot '..\..')
Set-Location $ToolRoot

Write-Host "==> Alte Prozesse beenden" -ForegroundColor Cyan
Get-Process -Name 'VibesBoxSync','rb_now_playing' -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "==> git pull" -ForegroundColor Cyan
Set-Location $RepoRoot
git fetch origin cursor/windows-vcredist-installer-b710
git checkout cursor/windows-vcredist-installer-b710
git pull origin cursor/windows-vcredist-installer-b710
Set-Location $ToolRoot

$pubspec = Get-Content -Raw -Encoding UTF8 '.\pubspec.yaml'
if ($pubspec -notmatch '(?m)^version:\s*1\.0\.6\b') {
  throw 'pubspec.yaml ist nicht 1.0.6 – falscher Branch/Stand.'
}

$session = Get-Content -Raw -Encoding UTF8 '.\lib\tool_session.dart'
$main = Get-Content -Raw -Encoding UTF8 '.\windows\runner\main.cpp'
if ($session -like '*FirebaseFunctions*' -or $session -notlike '*redeemRbToolCode(code)*') {
  throw 'tool_session.dart ist noch alt. git pull hat nicht den Fix-Branch geholt.'
}
if ($main -notlike '*Size size(360, 640)*') {
  throw 'main.cpp ohne Hochkant-Fenster. Falscher Stand.'
}
if ($main -like '*SetCurrentProcessExplicitAppUserModelID*') {
  throw 'main.cpp setzt noch AppUserModelID (Datei-Icon in Taskbar). Falscher Stand.'
}
$win32 = Get-Content -Raw -Encoding UTF8 '.\windows\runner\win32_window.cpp'
if ($win32 -notlike '*RegisterClassEx*') {
  throw 'win32_window.cpp ohne RegisterClassEx. Falscher Stand.'
}
Write-Host "Quellcode OK." -ForegroundColor Green

& (Join-Path $ToolRoot 'build_windows_installer.ps1')
$exe = Join-Path $ToolRoot 'build\windows\x64\runner\Release\VibesBoxSync.exe'
if (-not (Test-Path $exe)) { throw "EXE fehlt: $exe" }

Write-Host ""
Write-Host "==> Starte NEUE EXE:" -ForegroundColor Green
Write-Host $exe
Start-Process -FilePath $exe
Write-Host ""
Write-Host "Optional: Setup aus dist\VibesBoxSync-Setup-<version>.exe installieren"
