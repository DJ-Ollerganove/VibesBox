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

# Eine Versionsquelle: pubspec.yaml (schreibt tool_version.dart + Inno-Default)
Write-Step "Version aus pubspec synchronisieren"
$AppVersion = & (Join-Path $ToolRoot 'scripts\sync_version_from_pubspec.ps1')
if (-not $AppVersion) { throw "Version-Sync lieferte keine Versionsnummer." }
$AppVersion = "$AppVersion".Trim()
$pubspec = Get-Content -Raw -Encoding UTF8 (Join-Path $ToolRoot 'pubspec.yaml')
Write-Host "VibesBox Sync Version: $AppVersion"

# Quelle muss die Windows-Fixes enthalten (sonst baut man die alte EXE weiter).
$sessionSrc = Get-Content -Raw -Encoding UTF8 (Join-Path $ToolRoot 'lib\tool_session.dart')
$mainCpp = Get-Content -Raw -Encoding UTF8 (Join-Path $ToolRoot 'windows\runner\main.cpp')
if ($sessionSrc -notlike '*redeemRbToolCode(code)*' -or $sessionSrc -like '*FirebaseFunctions*') {
  throw "Quellcode ohne Windows-REST-Login. Bitte zuerst: git pull (Branch cursor/djay-pro-library-b710)."
}
if ($mainCpp -notlike '*Size size(360, 640)*') {
  throw "Quellcode ohne Hochkant-Fenster. Bitte zuerst: git pull."
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
  # oder vom Explorer/Antivirus gesperrt ist.
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

# Alte Setup-Dateien mit anderer Versionsnummer entfernen, damit nichts Verwirrung stiftet
Get-ChildItem -Path $DistDir -Filter 'VibesBoxSync-Setup-*.exe' -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -ne "VibesBoxSync-Setup-$AppVersion.exe" } |
  ForEach-Object {
    Write-Host "Entferne alte Setup-Datei: $($_.Name)" -ForegroundColor Yellow
    Remove-Item -Force $_.FullName
  }

Write-Step "Inno Setup: $Iscc  (Version $AppVersion)"
& $Iscc "/DMyAppVersion=$AppVersion" $IssPath
if ($LASTEXITCODE -ne 0) { throw "Inno Setup fehlgeschlagen (Exit $LASTEXITCODE)" }

$SetupExe = Join-Path $DistDir "VibesBoxSync-Setup-$AppVersion.exe"
if (-not (Test-Path $SetupExe)) {
  throw "Setup-EXE wurde nicht erzeugt: $SetupExe"
}

Write-Host ""
Write-Host "Fertig." -ForegroundColor Green
Write-Host "Installer: $SetupExe"
Write-Host "Portable:  $ZipPath"
Write-Host ""
Write-Host "Wichtig: Dateiname muss VibesBoxSync-Setup-$AppVersion.exe sein." -ForegroundColor Cyan
Write-Host "Danach ggf. auf die Website:"
Write-Host "  ..\..\scripts\deploy_sync_windows.ps1"