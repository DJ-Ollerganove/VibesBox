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
if ($main -notlike '*WIN-REST-360*') {
  throw 'main.cpp hat keinen WIN-REST-360 Titel. Falscher Stand.'
}
Write-Host "Quellcode OK: WIN-REST-360 vorhanden." -ForegroundColor Green

& (Join-Path $ToolRoot 'build_windows_installer.ps1')
$exe = Join-Path $ToolRoot 'build\windows\x64\runner\Release\VibesBoxSync.exe'
if (-not (Test-Path $exe)) { throw "EXE fehlt: $exe" }

Write-Host ""
Write-Host "==> Starte NEUE EXE (nicht Startmenue):" -ForegroundColor Green
Write-Host $exe
Start-Process -FilePath $exe
Write-Host ""
Write-Host "Fenster-Titel muss 'VibesBox Sync WIN-REST-360' heissen."
Write-Host "Unten auf der Connect-Seite muss 'WIN-REST-360' stehen."
Write-Host "Wenn nicht: du hast eine andere/alte Installation geoeffnet."
