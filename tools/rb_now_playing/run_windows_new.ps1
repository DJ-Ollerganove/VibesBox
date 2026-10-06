#Requires -Version 5.1
<#
.SYNOPSIS
  Ein Zug: alte Sync-App beenden/deinstallieren, Branch holen, bauen, Setup
  installieren und starten.

.DESCRIPTION
  Enthaelt DJ-Autostart ("Mit der Dj-Software starten", Default an) und
  rahmenloses Fenster. Branch: cursor/windows-sync-all-in-one-b710

.NOTES
  Nur ASCII in dieser Datei (Windows PowerShell 5.1).
#>

[CmdletBinding()]
param(
  [string]$Branch = 'cursor/windows-sync-all-in-one-b710',
  [switch]$SkipUninstall,
  [switch]$SkipInstall,
  [switch]$NoStart,
  # Schneller: kein flutter clean (inkrementeller Rebuild).
  [switch]$Fast,
  [string]$FlutterBat = "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat"
)

$ErrorActionPreference = 'Stop'
$ToolRoot = $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $ToolRoot '..\..')

function Write-Step([string]$msg) {
  Write-Host ""
  Write-Host "==> $msg" -ForegroundColor Cyan
}

function Stop-VibesBoxSyncProcesses {
  Write-Step "Alte Prozesse beenden (UI + Watcher)"
  Get-Process -Name 'VibesBoxSync', 'rb_now_playing' -ErrorAction SilentlyContinue |
    Stop-Process -Force
  Start-Sleep -Seconds 1
}

function Clear-DjWatchRunKey {
  $runPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  try {
    if (Get-ItemProperty -Path $runPath -Name 'VibesBoxSyncDjWatch' -ErrorAction SilentlyContinue) {
      Remove-ItemProperty -Path $runPath -Name 'VibesBoxSyncDjWatch' -Force -ErrorAction SilentlyContinue
      Write-Host "HKCU Run VibesBoxSyncDjWatch entfernt."
    }
  } catch {
    # ignore
  }
}

function Uninstall-VibesBoxSync {
  Write-Step "Alte Installation deinstallieren (falls vorhanden)"
  Clear-DjWatchRunKey

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\VibesBox Sync\unins000.exe'),
    (Join-Path ${env:ProgramFiles} 'VibesBox Sync\unins000.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'VibesBox Sync\unins000.exe')
  )
  $unins = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if (-not $unins) {
    Write-Host "Kein unins000.exe gefunden - ggf. nicht installiert. OK."
    return
  }
  Write-Host "Deinstalliere: $unins"
  $p = Start-Process -FilePath $unins -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
  if ($p.ExitCode -ne 0 -and $p.ExitCode -ne $null) {
    Write-Host ("Uninstaller ExitCode: {0} (weiter)" -f $p.ExitCode) -ForegroundColor Yellow
  }
  Start-Sleep -Seconds 1
  Stop-VibesBoxSyncProcesses
  Clear-DjWatchRunKey
}

# --- Start ---
Set-Location $ToolRoot
Stop-VibesBoxSyncProcesses

if (-not $SkipUninstall) {
  Uninstall-VibesBoxSync
}

Write-Step ("git fetch/checkout/pull: {0}" -f $Branch)
Set-Location $RepoRoot
git fetch origin
git checkout $Branch
git pull origin $Branch
Set-Location $ToolRoot

$session = Get-Content -Raw -Encoding UTF8 '.\lib\tool_session.dart'
$main = Get-Content -Raw -Encoding UTF8 '.\windows\runner\main.cpp'
$win32 = Get-Content -Raw -Encoding UTF8 '.\windows\runner\win32_window.cpp'
$prefs = Get-Content -Raw -Encoding UTF8 '.\lib\dj_library_prefs.dart'
$packs = Get-Content -Raw -Encoding UTF8 '.\lib\tool_packs.dart'

if ($session -like '*FirebaseFunctions*' -or $session -notlike '*redeemRbToolCode(code)*') {
  throw 'tool_session.dart ist noch alt. git pull hat nicht den Fix-Branch geholt.'
}
if ($main -notlike '*Size size(360, 640)*') {
  throw 'main.cpp ohne Hochkant-Fenster. Falscher Stand.'
}
if ($main -like '*SetCurrentProcessExplicitAppUserModelID*') {
  throw 'main.cpp setzt noch AppUserModelID (Datei-Icon in Taskbar). Falscher Stand.'
}
if ($main -notlike '*HasDjWatchArgument*' -or $main -notlike '*RunDjWatchdog*') {
  throw 'main.cpp ohne DJ-Watchdog. Falscher Branch/Stand.'
}
if ($win32 -notlike '*RegisterClassEx*') {
  throw 'win32_window.cpp ohne RegisterClassEx. Falscher Stand.'
}
if ($win32 -notlike '*ApplyFramelessChrome*' -and $win32 -notlike '*WM_NCCALCSIZE*') {
  throw 'win32_window.cpp ohne Frameless-Chrome. Falscher Branch/Stand.'
}
if ($prefs -notlike '*launchWithDj*' -or $prefs -notlike '*setLaunchWithDj*') {
  throw 'dj_library_prefs.dart ohne launchWithDj. Falscher Branch/Stand.'
}
if ($packs -notlike '*Mit der Dj-Software starten*') {
  throw 'tool_packs.dart ohne Label "Mit der Dj-Software starten". Falscher Stand.'
}
if (-not (Test-Path '.\windows\runner\dj_watchdog.cpp')) {
  throw 'dj_watchdog.cpp fehlt. Falscher Branch/Stand.'
}
Write-Host "Quellcode OK (Autostart + Frameless)." -ForegroundColor Green

Write-Step "Flutter + Installer bauen"
$buildArgs = @{ FlutterBat = $FlutterBat }
if ($Fast) { $buildArgs['Fast'] = $true }
& (Join-Path $ToolRoot 'build_windows_installer.ps1') @buildArgs

$pubspec = Get-Content -Raw -Encoding UTF8 (Join-Path $ToolRoot 'pubspec.yaml')
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw 'Version in pubspec.yaml nicht lesbar.'
}
$AppVersion = $Matches[1]
$setup = Join-Path $ToolRoot ("dist\VibesBoxSync-Setup-{0}.exe" -f $AppVersion)
$exe = Join-Path $ToolRoot 'build\windows\x64\runner\Release\VibesBoxSync.exe'
if (-not (Test-Path $exe)) { throw "EXE fehlt: $exe" }

if (-not $SkipInstall) {
  if (-not (Test-Path $setup)) {
    throw "Setup fehlt: $setup (Inno Setup installiert?)"
  }
  Write-Step ("Setup installieren: {0}" -f $setup)
  Stop-VibesBoxSyncProcesses
  $inst = Start-Process -FilePath $setup -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
  if ($inst.ExitCode -ne 0 -and $inst.ExitCode -ne $null) {
    throw ("Setup ExitCode: {0}" -f $inst.ExitCode)
  }
  Write-Host "Installation fertig." -ForegroundColor Green
}

if (-not $NoStart) {
  Write-Step "Starte VibesBox Sync"
  $installed = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\VibesBox Sync\VibesBoxSync.exe'),
    (Join-Path ${env:ProgramFiles} 'VibesBox Sync\VibesBoxSync.exe')
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1

  if ($installed) {
    Write-Host $installed -ForegroundColor Green
    Start-Process -FilePath $installed
  } else {
    Write-Host $exe -ForegroundColor Green
    Start-Process -FilePath $exe
  }
}

Write-Host ""
Write-Host "Fertig. Branch: $Branch | Version: $AppVersion" -ForegroundColor Green
Write-Host "Features: rahmenlos + Mit der Dj-Software starten (Default an)"
if (Test-Path $setup) {
  Write-Host ("Setup: {0}" -f $setup)
}
