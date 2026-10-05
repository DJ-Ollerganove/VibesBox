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

# Version aus pubspec.yaml (z. B. 1.0.2+2 -> 1.0.2)
$pubspec = Get-Content -Raw (Join-Path $ToolRoot 'pubspec.yaml')
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw "Konnte version in pubspec.yaml nicht lesen."
}
$AppVersion = $Matches[1]
Write-Host "VibesBox Sync Version: $AppVersion"

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

  Write-Step "flutter --version"
  & $FlutterBat --version

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
Write-Step "Inno Setup: $Iscc"
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
