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
git fetch origin
git checkout cursor/windows-sync-installer-b710
git pull origin cursor/windows-sync-installer-b710
Set-Location $ToolRoot

$session = Get-Content -Raw -Encoding UTF8 '.\lib\tool_session.dart'
$main = Get-Content -Raw -Encoding UTF8 '.\windows\runner\main.cpp'
if ($session -like '*FirebaseFunctions*' -or $session -notlike '*redeemRbToolCode(code)*') {
  throw 'tool_session.dart ist noch alt. git pull hat nicht den Fix-Branch geholt.'
}
if ($main -notlike '*Size size(360, 640)*') {
  throw 'main.cpp ohne Hochkant-Fenster. Falscher Stand.'
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
Write-Host "Optional installieren: dist\VibesBoxSync-Setup-1.0.2.exe"
