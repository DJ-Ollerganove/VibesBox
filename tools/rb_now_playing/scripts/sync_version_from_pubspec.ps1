#Requires -Version 5.1
<#
.SYNOPSIS
  Eine Versionsquelle: pubspec.yaml -> Tool-Runtime, Installer-Default, optional Hosting.

.NOTES
  Nur ASCII in diesem Skript (Windows PowerShell 5.1 / Codepage).
  Hosting nutzt feste Dateinamen (VibesBox-Sync-windows.exe); nur version.json
  wird bei -UpdateHosting aktualisiert - die Sync-Seite selbst nicht.
#>

[CmdletBinding()]
param(
  [switch]$UpdateHosting
)

$ErrorActionPreference = 'Stop'
$ToolRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RepoRoot = Resolve-Path (Join-Path $ToolRoot '..\..')
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

$pubspecPath = Join-Path $ToolRoot 'pubspec.yaml'
$pubspec = Get-Content -Raw -Encoding UTF8 $pubspecPath
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw "Konnte version in pubspec.yaml nicht lesen."
}
$Version = $Matches[1]
Write-Host ("Sync-Tool Version aus pubspec: {0}" -f $Version)

$versionDart = @"
// GENERATED from pubspec.yaml - nicht von Hand pflegen.
// Quelle: tools/rb_now_playing/pubspec.yaml (version:)
// Sync: scripts/sync_version_from_pubspec.ps1 / .sh
const kSyncToolVersion = '$Version';
"@
$versionDartPath = Join-Path $ToolRoot 'lib\tool_version.dart'
[System.IO.File]::WriteAllText($versionDartPath, $versionDart.Replace("`r`n", "`n"), $utf8NoBom)
Write-Host "OK: lib/tool_version.dart"

$issPath = Join-Path $ToolRoot 'installer\vibesbox_sync.iss'
$iss = [System.IO.File]::ReadAllText($issPath)
$iss2 = [regex]::Replace($iss, '#define MyAppVersion\s+"[^"]+"', ("#define MyAppVersion `"{0}`"" -f $Version))
$iss2 = [regex]::Replace($iss2, 'OutputBaseFilename=VibesBoxSync-Setup-[^\r\n]+', ("OutputBaseFilename=VibesBoxSync-Setup-{0}" -f $Version))
if ($iss2 -notlike ("*#define MyAppVersion `"{0}`"*" -f $Version)) {
  throw "Konnte MyAppVersion in vibesbox_sync.iss nicht setzen."
}
if ($iss2 -notlike ("*OutputBaseFilename=VibesBoxSync-Setup-{0}*" -f $Version)) {
  throw "Konnte OutputBaseFilename in vibesbox_sync.iss nicht setzen."
}
[System.IO.File]::WriteAllText($issPath, $iss2, $utf8NoBom)
Write-Host ("OK: installer/vibesbox_sync.iss -> VibesBoxSync-Setup-{0}.exe" -f $Version)

if ($UpdateHosting) {
  $syncDir = Join-Path $RepoRoot 'public\sync'
  $htmlPath = Join-Path $syncDir 'index.html'
  $html = [System.IO.File]::ReadAllText($htmlPath)
  if ($html -notlike '*/download/vibesbox-sync-windows*') {
    throw "public/sync/index.html hat keinen festen Windows-Download-Link."
  }
  if ($html -notlike '*/sync/version.json*') {
    throw "public/sync/index.html laedt version.json nicht."
  }
  Write-Host "OK: public/sync/index.html (feste Download-URLs)"

  $firebasePath = Join-Path $RepoRoot 'firebase.json'
  $firebase = [System.IO.File]::ReadAllText($firebasePath)
  if ($firebase -notlike '*/sync/VibesBox-Sync-windows.exe*') {
    throw "firebase.json zeigt nicht auf /sync/VibesBox-Sync-windows.exe"
  }
  if ($firebase -notlike '*/sync/VibesBox-Sync-mac.pkg*') {
    throw "firebase.json zeigt nicht auf /sync/VibesBox-Sync-mac.pkg"
  }
  Write-Host "OK: firebase.json (feste Download-Rewrites)"

  # version.json: Windows aus pubspec, Mac beibehalten falls vorhanden
  $versionJsonPath = Join-Path $syncDir 'version.json'
  $macVer = $Version
  if (Test-Path $versionJsonPath) {
    $prev = [System.IO.File]::ReadAllText($versionJsonPath)
    if ($prev -match '"mac"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"') {
      $macVer = $Matches[1]
    }
  }
  $versionJson = @"
{
  "windows": "$Version",
  "mac": "$macVer"
}
"@
  [System.IO.File]::WriteAllText($versionJsonPath, $versionJson.Replace("`r`n", "`n"), $utf8NoBom)
  Write-Host ("OK: public/sync/version.json -> windows={0} mac={1}" -f $Version, $macVer)
}

Write-Host ("Version sync fertig: {0}" -f $Version)
Write-Output $Version
