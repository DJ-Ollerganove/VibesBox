#Requires -Version 5.1
<#
.SYNOPSIS
  Ein Zug: alte Sync-App VERWERFEN, hart auf 1.0.11, neu bauen, installieren.

.DESCRIPTION
  Default-Branch: cursor/windows-sync-all-in-one-b710
  Deinstalliert jede alte VibesBox Sync, hard-reset auf Origin, baut nur 1.0.11.

.NOTES
  Nur ASCII in dieser Datei (Windows PowerShell 5.1).
  Alte 1.0.5/1.0.7/1.0.9 werden nicht akzeptiert.
#>

[CmdletBinding()]
param(
  [string]$Branch = 'cursor/windows-sync-all-in-one-b710',
  # Nur fuer Notfall - Standard: alte Installation IMMER weg.
  [switch]$KeepOldInstall,
  [switch]$SkipInstall,
  [switch]$NoStart,
  # Schneller: kein flutter clean (inkrementeller Rebuild).
  [switch]$Fast,
  [string]$FlutterBat = "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat"
)

$ErrorActionPreference = 'Stop'
$ExpectVersion = '1.0.11'
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

function Remove-LeftoverInstallDirs {
  $dirs = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\VibesBox Sync'),
    (Join-Path ${env:ProgramFiles} 'VibesBox Sync'),
    (Join-Path ${env:ProgramFiles(x86)} 'VibesBox Sync')
  )
  foreach ($dir in $dirs) {
    if ($dir -and (Test-Path $dir)) {
      Write-Host ("Loesche Restordner: {0}" -f $dir) -ForegroundColor Yellow
      try {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop
      } catch {
        Write-Host ("Restordner konnte nicht komplett weg: {0}" -f $_) -ForegroundColor Yellow
      }
    }
  }
}

function Uninstall-VibesBoxSync {
  Write-Step "Alte Installation VERWERFEN (alles vor 1.0.11)"
  Clear-DjWatchRunKey

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\VibesBox Sync\unins000.exe'),
    (Join-Path ${env:ProgramFiles} 'VibesBox Sync\unins000.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'VibesBox Sync\unins000.exe')
  )
  $unins = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if ($unins) {
    Write-Host "Deinstalliere: $unins"
    $p = Start-Process -FilePath $unins -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne $null) {
      Write-Host ("Uninstaller ExitCode: {0} (weiter)" -f $p.ExitCode) -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 1
  } else {
    Write-Host "Kein unins000.exe - raeume Ordner manuell."
  }
  Stop-VibesBoxSyncProcesses
  Clear-DjWatchRunKey
  Remove-LeftoverInstallDirs
}

function Get-FileProductVersion([string]$path) {
  if (-not (Test-Path $path)) { return '' }
  try {
    $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)
    $raw = $info.ProductVersion
    if ([string]::IsNullOrWhiteSpace($raw)) { $raw = $info.FileVersion }
    if ($raw -match '([0-9]+\.[0-9]+\.[0-9]+)') { return $Matches[1] }
    return "$raw".Trim()
  } catch {
    return ''
  }
}

# --- Start ---
Set-Location $ToolRoot
Stop-VibesBoxSyncProcesses

if (-not $KeepOldInstall) {
  Uninstall-VibesBoxSync
} else {
  Write-Host "WARNUNG: KeepOldInstall gesetzt - alte EXE bleibt ggf. liegen." -ForegroundColor Yellow
}

Write-Step ("git fetch + HARD RESET auf origin/{0} (nur {1})" -f $Branch, $ExpectVersion)
Set-Location $RepoRoot
git fetch origin $Branch
if ($LASTEXITCODE -ne 0) { throw "git fetch origin $Branch fehlgeschlagen." }
git checkout -B $Branch "origin/$Branch"
if ($LASTEXITCODE -ne 0) { throw "git checkout -B $Branch fehlgeschlagen." }
git reset --hard "origin/$Branch"
if ($LASTEXITCODE -ne 0) { throw "git reset --hard fehlgeschlagen." }
git clean -fd -- tools/rb_now_playing/pubspec.yaml tools/rb_now_playing/lib/tool_version.dart
Set-Location $ToolRoot

Write-Host ("Aktueller Branch: {0}" -f (git rev-parse --abbrev-ref HEAD))
Write-Host ("Commit: {0}" -f (git rev-parse --short HEAD))
Write-Host ("origin/{0}: {1}" -f $Branch, (git rev-parse --short "origin/$Branch"))

# Sofort nach Reset: Version pruefen, BEVOR gebaut wird.
$pubspecEarly = Get-Content -Raw -Encoding UTF8 '.\pubspec.yaml'
if ($pubspecEarly -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw 'Version in pubspec.yaml nicht lesbar (nach git reset).'
}
$verEarly = $Matches[1]
Write-Host ("pubspec nach reset: {0}" -f $verEarly) -ForegroundColor Yellow
if ($verEarly -ne $ExpectVersion) {
  throw @"
FALSCHE VERSION nach hard reset: $verEarly (erwartet $ExpectVersion).
Alte Staende werden verworfen - Origin muss $ExpectVersion sein.

  cd C:\Users\Ollerganove\dev\VibesBox
  git fetch origin cursor/windows-sync-all-in-one-b710
  git reset --hard origin/cursor/windows-sync-all-in-one-b710
  Get-Content tools\rb_now_playing\pubspec.yaml | Select-String '^version:'

Muss zeigen: version: $ExpectVersion+1
Dann: cd tools\rb_now_playing ; .\run_windows_new.ps1
"@
}

$session = Get-Content -Raw -Encoding UTF8 '.\lib\tool_session.dart'
$main = Get-Content -Raw -Encoding UTF8 '.\windows\runner\main.cpp'
$win32 = Get-Content -Raw -Encoding UTF8 '.\windows\runner\win32_window.cpp'
$prefs = Get-Content -Raw -Encoding UTF8 '.\lib\dj_library_prefs.dart'
$packs = Get-Content -Raw -Encoding UTF8 '.\lib\tool_packs.dart'
$mainDart = Get-Content -Raw -Encoding UTF8 '.\lib\main.dart'
$rbHist = Get-Content -Raw -Encoding UTF8 '.\lib\rekordbox_history.dart'

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
if ($mainDart -notlike '*_DjHistoryPanel*' -or $mainDart -notlike '*_liveHistory*') {
  throw 'main.dart ohne History-Panel. Brauche Song-Detection-Merge (v1.0.11).'
}
if ($rbHist -notlike '*ORDER BY sh.created_at DESC*') {
  throw 'rekordbox_history.dart ohne Live-Latest-Query. Falscher Stand.'
}
if ($rbHist -like '*_selectLatestLibrary*' -or $rbHist -like '*fromLibrary*') {
  throw 'rekordbox_history.dart hat noch Library-Fallback (Load=Play). Brauche 1.0.11.'
}
if ($rbHist -notlike '*Warte auf Play*' -and $rbHist -notlike '*_pollPlayCountBump*') {
  throw 'rekordbox_history.dart ohne Play-Erkennung. Falscher Stand.'
}
if ($rbHist -notlike '*_pollPlayCountBump*' -or $rbHist -notlike '*Platform.isWindows*') {
  throw 'rekordbox_history.dart ohne Windows-WAL-Copy/PlayCount (brauche 1.0.11).'
}
$toolVer = Get-Content -Raw -Encoding UTF8 '.\lib\tool_version.dart'
if ($toolVer -notlike "*kSyncToolVersion = '$ExpectVersion'*") {
  throw ("tool_version.dart ist nicht $ExpectVersion - alte Version verworfen.")
}
Write-Host "Quellcode OK (nur 1.0.11, Play-only, History-Panel)." -ForegroundColor Green

Write-Step "Flutter + Installer bauen"
$buildArgs = @{ FlutterBat = $FlutterBat }
if ($Fast) { $buildArgs['Fast'] = $true }
& (Join-Path $ToolRoot 'build_windows_installer.ps1') @buildArgs

$pubspec = Get-Content -Raw -Encoding UTF8 (Join-Path $ToolRoot 'pubspec.yaml')
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw 'Version in pubspec.yaml nicht lesbar.'
}
$AppVersion = $Matches[1]
if ($AppVersion -ne $ExpectVersion) {
  throw ("Falsche Version $AppVersion - erwartet $ExpectVersion. Alte Builds werden verworfen.")
}
$setup = Join-Path $ToolRoot ("dist\VibesBoxSync-Setup-{0}.exe" -f $AppVersion)
$exe = Join-Path $ToolRoot 'build\windows\x64\runner\Release\VibesBoxSync.exe'
if (-not (Test-Path $exe)) { throw "EXE fehlt: $exe" }
$builtVer = Get-FileProductVersion $exe
if ($builtVer -and $builtVer -ne $ExpectVersion) {
  throw ("Gebaute EXE ist $builtVer - erwartet $ExpectVersion. Abbruch.")
}

if (-not $SkipInstall) {
  if (-not (Test-Path $setup)) {
    throw "Setup fehlt: $setup (Inno Setup installiert?)"
  }
  Write-Step ("Alte Reste weg, dann Setup {0}" -f $setup)
  Stop-VibesBoxSyncProcesses
  if (-not $KeepOldInstall) {
    Uninstall-VibesBoxSync
  }
  $inst = Start-Process -FilePath $setup -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
  if ($inst.ExitCode -ne 0 -and $inst.ExitCode -ne $null) {
    throw ("Setup ExitCode: {0}" -f $inst.ExitCode)
  }
  Write-Host "Installation fertig (nur 1.0.11)." -ForegroundColor Green
}

$installed = @(
  (Join-Path $env:LOCALAPPDATA 'Programs\VibesBox Sync\VibesBoxSync.exe'),
  (Join-Path ${env:ProgramFiles} 'VibesBox Sync\VibesBoxSync.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($installed) {
  $instVer = Get-FileProductVersion $installed
  Write-Host ("Installierte EXE: {0}  ProductVersion={1}" -f $installed, $instVer) -ForegroundColor Green
  if ($instVer -and $instVer -ne $ExpectVersion) {
    throw ("Installierte Version ist $instVer statt $ExpectVersion - alte Installation nicht verworfen.")
  }
}

if (-not $NoStart) {
  Write-Step "Starte VibesBox Sync 1.0.11"
  if ($installed) {
    Start-Process -FilePath $installed
  } else {
    Write-Host $exe -ForegroundColor Green
    Start-Process -FilePath $exe
  }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host ("NEUER BUILD  Branch={0}  Version={1}" -f $Branch, $AppVersion) -ForegroundColor Green
Write-Host "Alte Versionen verworfen. Panel muss v1.0.11 zeigen." -ForegroundColor Yellow
Write-Host "Features: Play-only History + rahmenlos + DJ-Autostart" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
if (Test-Path $setup) {
  Write-Host ("Setup: {0}" -f $setup)
}
