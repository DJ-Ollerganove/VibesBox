#Requires -Version 5.1
<#
.SYNOPSIS
  Baut VibesBox Sync (Flutter Windows Release) und erzeugt eine Setup-.exe (Inno Setup).

.DESCRIPTION
  1) flutter pub get
  2) flutter build windows --release
  3) Inno Setup (ISCC) -> dist\VibesBoxSync-Setup-<version>.exe

.NOTES
  Voraussetzungen auf dem Windows-PC:
  - Flutter (siehe $FlutterBat unten)
  - Visual Studio 2022 mit "Desktop development with C++"
  - Inno Setup 6 oder 7: https://jrsoftware.org/isdl.php

  WICHTIG: Diese Datei nur ASCII (kein UTF-8-Sonderzeichen), sonst ParserError
  unter Windows PowerShell 5.1 bei falscher Codepage.
#>

[CmdletBinding()]
param(
  [switch]$SkipFlutterBuild,
  [switch]$ZipOnly,
  [string]$FlutterBat = "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat"
)

$ErrorActionPreference = 'Stop'
$ToolRoot = $PSScriptRoot
Set-Location $ToolRoot

function Write-Step([string]$msg) {
  Write-Host ""
  Write-Host "==> $msg" -ForegroundColor Cyan
}

# Eine Versionsquelle: pubspec.yaml - direkt hier lesen
Write-Step "Version aus pubspec lesen"
$pubspecPath = Join-Path $ToolRoot 'pubspec.yaml'
$pubspec = Get-Content -Raw -Encoding UTF8 $pubspecPath
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw "Konnte version in pubspec.yaml nicht lesen."
}
$AppVersion = $Matches[1]
if ($AppVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
  throw "Ungueltige Version aus pubspec: '$AppVersion'"
}
Write-Host "pubspec.yaml version -> $AppVersion"

# tool_version.dart + iss-Default mitschreiben
$null = & (Join-Path $ToolRoot 'scripts\sync_version_from_pubspec.ps1')
$pubspec = Get-Content -Raw -Encoding UTF8 $pubspecPath
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' -or $Matches[1] -ne $AppVersion) {
  throw "Version nach Sync inkonsistent (erwartet $AppVersion)."
}
Write-Host "VibesBox Sync Version: $AppVersion" -ForegroundColor Green

# Quelle muss die Windows-Fixes enthalten
$sessionSrc = Get-Content -Raw -Encoding UTF8 (Join-Path $ToolRoot 'lib\tool_session.dart')
$mainCpp = Get-Content -Raw -Encoding UTF8 (Join-Path $ToolRoot 'windows\runner\main.cpp')
if ($sessionSrc -notlike '*redeemRbToolCode(code)*' -or $sessionSrc -like '*FirebaseFunctions*') {
  throw "Quellcode ohne Windows-REST-Login. Bitte zuerst: git pull (Branch cursor/windows-sync-installer-b710)."
}
if ($mainCpp -notlike '*Size size(360, 640)*') {
  throw "Quellcode ohne Hochkant-Fenster. Bitte zuerst: git pull."
}
if ($mainCpp -like '*SetCurrentProcessExplicitAppUserModelID*') {
  throw "main.cpp setzt noch AppUserModelID (Taskbar zeigt dann Datei-Icon). Bitte: git pull."
}
if ($mainCpp -notlike '*ICON_SMALL2*') {
  throw "main.cpp ohne ICON_SMALL2 (Taskbar-Icon). Bitte: git pull."
}
$win32Cpp = Get-Content -Raw -Encoding UTF8 (Join-Path $ToolRoot 'windows\runner\win32_window.cpp')
if ($win32Cpp -notlike '*RegisterClassEx*' -or $win32Cpp -notlike '*WNDCLASSEX*') {
  throw "win32_window.cpp ohne WNDCLASSEX/RegisterClassEx. Bitte: git pull."
}
if ($pubspec -match '(?m)^\s*cloud_functions:') {
  throw "pubspec.yaml enthaelt noch cloud_functions. Bitte zuerst: git pull."
}

$ReleaseDir = Join-Path $ToolRoot 'build\windows\x64\runner\Release'
$ExePath = Join-Path $ReleaseDir 'VibesBoxSync.exe'
$DistDir = Join-Path $ToolRoot 'dist'
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

if (-not $SkipFlutterBuild) {
  if (-not (Test-Path $FlutterBat)) {
    throw @"
Flutter nicht gefunden:
  $FlutterBat

Installiere Flutter oder uebergib den Pfad:
  .\build_windows_installer.ps1 -FlutterBat 'C:\Pfad\zu\flutter\bin\flutter.bat'
"@
  }

  # LNK1104: Linker kann VibesBoxSync.exe nicht ueberschreiben, solange sie laeuft
  Write-Step "Laufende VibesBoxSync-Prozesse beenden (sonst LNK1104)"
  Get-Process -Name 'VibesBoxSync', 'rb_now_playing' -ErrorAction SilentlyContinue |
    Stop-Process -Force
  Start-Sleep -Seconds 1
  if (Test-Path $ExePath) {
    try {
      $fs = [System.IO.File]::Open(
        $ExePath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
      )
      $fs.Close()
    } catch {
      throw @"
VibesBoxSync.exe ist noch gesperrt:
  $ExePath

Bitte VibesBox Sync schliessen (auch aus dem Infobereich), dann erneut:
  .\build_windows_installer.ps1
"@
    }
  }

  Write-Step "flutter --version"
  & $FlutterBat --version

  Write-Step "flutter clean (damit alte Windows-EXE wirklich neu gebaut wird)"
  & $FlutterBat clean
  if ($LASTEXITCODE -ne 0) { throw "flutter clean fehlgeschlagen (Exit $LASTEXITCODE)" }

  Write-Step "flutter pub get"
  & $FlutterBat pub get
  if ($LASTEXITCODE -ne 0) {
    throw @"
flutter pub get fehlgeschlagen (Exit $LASTEXITCODE).

Typische Ursache: Dart-SDK zu alt fuer pubspec (Flutter 3.38 = Dart 3.10).
Bitte die komplette Flutter-Ausgabe oberhalb mitkopieren.
"@
  }

  Write-Step "flutter build windows --release"
  & $FlutterBat build windows --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build windows fehlgeschlagen (Exit $LASTEXITCODE)" }
}

if (-not (Test-Path $ExePath)) {
  throw "Release-EXE fehlt: $ExePath`nZuerst flutter build windows --release ausfuehren (oder -SkipFlutterBuild weglassen)."
}

# Immer ein ZIP als portable Alternative
$ZipPath = Join-Path $DistDir "VibesBoxSync-$AppVersion-windows-x64.zip"
Write-Step "ZIP (portable): $ZipPath"
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path (Join-Path $ReleaseDir '*') -DestinationPath $ZipPath -Force
Write-Host "OK: $ZipPath" -ForegroundColor Green

if ($ZipOnly) {
  Write-Host ""
  Write-Host "Fertig (nur ZIP, kein Setup)." -ForegroundColor Green
  Write-Host $ZipPath
  exit 0
}

# Inno Setup Compiler suchen (7 bevorzugt, sonst 6; auch per Get-Command)
function Find-Iscc {
  $candidates = @(
    "${env:LocalAppData}\Programs\Inno Setup 7\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
    "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
  )
  foreach ($p in $candidates) {
    if (Test-Path $p) { return $p }
  }
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $null
}

$Iscc = Find-Iscc
if (-not $Iscc) {
  Write-Host ""
  Write-Host "Inno Setup (ISCC.exe) nicht gefunden." -ForegroundColor Yellow
  Write-Host "Download (Inno Setup 7): https://jrsoftware.org/isdl.php"
  Write-Host "Danach Skript erneut starten, oder vorerst das ZIP nutzen:"
  Write-Host "  $ZipPath"
  exit 2
}

$IssPath = Join-Path $ToolRoot 'installer\vibesbox_sync.iss'
$AppIcon = Join-Path $ToolRoot 'windows\runner\resources\app_icon.ico'
$SetupIcon = Join-Path $ToolRoot 'installer\vibesbox_sync.ico'
if (-not (Test-Path $AppIcon)) { throw "App-Icon fehlt: $AppIcon" }
if (-not (Test-Path $SetupIcon)) { throw "Setup-Icon fehlt: $SetupIcon" }
$setupIconInfo = Get-Item $SetupIcon
if ($setupIconInfo.Length -lt 10000) {
  throw ("Setup-Icon zu klein ({0} Bytes) - vermutlich kein VibesBox-Logo: {1}" -f $setupIconInfo.Length, $SetupIcon)
}
Write-Host ("Setup-Icon: {0} ({1} Bytes)" -f $SetupIcon, $setupIconInfo.Length)

$ExpectedSetupName = "VibesBoxSync-Setup-$AppVersion.exe"
$SetupExe = Join-Path $DistDir $ExpectedSetupName

# Version + Icon-Pfad FEST in die .iss schreiben
Write-Step ("Inno-.iss auf Version {0} + Setup-Icon festnageln" -f $AppVersion)
$issText = [System.IO.File]::ReadAllText($IssPath)
$issText = [regex]::Replace(
  $issText,
  '#define MyAppVersion\s+"[^"]+"',
  "#define MyAppVersion `"$AppVersion`""
)
$issText = [regex]::Replace(
  $issText,
  'OutputBaseFilename=VibesBoxSync-Setup-[^\r\n]+',
  "OutputBaseFilename=VibesBoxSync-Setup-$AppVersion"
)
# Absoluter Icon-Pfad in Anfuehrungszeichen
$setupIconForIss = $SetupIcon
$issText = [regex]::Replace(
  $issText,
  '(?m)^SetupIconFile=.*$',
  ("SetupIconFile=`"{0}`"" -f $setupIconForIss)
)
if ($issText -notlike ("*#define MyAppVersion `"{0}`"*" -f $AppVersion)) {
  throw ("Konnte MyAppVersion in vibesbox_sync.iss nicht auf {0} setzen." -f $AppVersion)
}
if ($issText -notlike ("*OutputBaseFilename=VibesBoxSync-Setup-{0}*" -f $AppVersion)) {
  throw ("Konnte OutputBaseFilename in vibesbox_sync.iss nicht auf {0} setzen." -f $AppVersion)
}
if ($issText -notmatch '(?m)^SetupIconFile=.+vibesbox_sync\.ico"?\s*$') {
  throw "Konnte SetupIconFile in vibesbox_sync.iss nicht setzen."
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($IssPath, $issText, $utf8NoBom)
Write-Host ("OK: OutputBaseFilename=VibesBoxSync-Setup-{0}" -f $AppVersion)
Write-Host ("OK: SetupIconFile={0}" -f $setupIconForIss)

# Alte Setup-Dateien entfernen, dann neu bauen
Get-ChildItem -Path $DistDir -Filter 'VibesBoxSync-Setup-*.exe' -ErrorAction SilentlyContinue |
  ForEach-Object {
    Write-Host ("Entferne alte Setup-Datei: {0}" -f $_.Name) -ForegroundColor Yellow
    Remove-Item -Force $_.FullName
  }

Write-Step ("Inno Setup: {0}" -f $Iscc)
Write-Host ("Erwartete Ausgabe: {0}" -f $SetupExe)
& $Iscc $IssPath
if ($LASTEXITCODE -ne 0) { throw ("Inno Setup fehlgeschlagen (Exit {0})" -f $LASTEXITCODE) }

$found = @(Get-ChildItem -Path $DistDir -Filter 'VibesBoxSync-Setup-*.exe' -ErrorAction SilentlyContinue)
Write-Host "Setup-Dateien in dist\:"
$found | ForEach-Object { Write-Host ("  - {0}" -f $_.Name) }

if (-not (Test-Path $SetupExe)) {
  $names = ($found | ForEach-Object { $_.Name }) -join ', '
  throw @"
Setup-EXE mit falschem Namen. Erwartet:
  $ExpectedSetupName
Vorhanden: $names

pubspec.yaml version muss $AppVersion sein. Bitte:
  Get-Content .\pubspec.yaml | Select-String '^version:'
  .\build_windows_installer.ps1
"@
}

if ($found.Count -ne 1 -or $found[0].Name -ne $ExpectedSetupName) {
  throw ("Unerwartete Setup-Dateien in dist\. Nur {0} ist erlaubt." -f $ExpectedSetupName)
}

Write-Host ""
Write-Host "Fertig." -ForegroundColor Green
Write-Host ("Installer: {0}" -f $SetupExe)
Write-Host ("Portable:  {0}" -f $ZipPath)
Write-Host ""
Write-Host "Taskbar-Logo: alte App deinstallieren, dann NEUES Setup starten." -ForegroundColor Yellow
Write-Host "Falls noch Datei-Icon: Explorer neu starten (Task-Manager -> Windows-Explorer -> Neu starten)."
Write-Host ""
Write-Host "Danach ggf. auf die Website:"
Write-Host "  ..\..\scripts\deploy_sync_windows.ps1"
