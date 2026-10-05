#Requires -Version 5.1
<#
.SYNOPSIS
  Eine Versionsquelle: pubspec.yaml -> Tool-Runtime, Installer-Default, optional Hosting.

.NOTES
  Nur ASCII in diesem Skript (Windows PowerShell 5.1 / Codepage).
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
  $winFile = "VibesBox-Sync-$Version-windows.exe"
  $htmlPath = Join-Path $RepoRoot 'public\sync\index.html'
  $html = [System.IO.File]::ReadAllText($htmlPath)

  # ASCII-only patterns (no umlauts). Idempotent if already current.
  $hrefPattern = 'href="/sync/VibesBox-Sync-[0-9]+\.[0-9]+\.[0-9]+-windows\.exe"'
  if ($html -notmatch $hrefPattern) {
    throw "Windows-Download-Link in public/sync/index.html nicht gefunden."
  }
  $html2 = [regex]::Replace($html, $hrefPattern, ('href="/sync/{0}"' -f $winFile), 1)
  $html2 = [regex]::Replace(
    $html2,
    '(href="/sync/VibesBox-Sync-[^"]+-windows\.exe">Download</a>\s*<span class="ver">Version )[^<]+(</span>)',
    ('$1{0}$2' -f $Version),
    1
  )

  if ($html2 -notlike ('*/sync/{0}*' -f $winFile)) {
    throw ("Windows-Link in public/sync/index.html zeigt nicht auf {0}." -f $winFile)
  }
  if ($html2 -ne $html) {
    [System.IO.File]::WriteAllText($htmlPath, $html2, $utf8NoBom)
    Write-Host ("OK: public/sync/index.html -> {0}" -f $winFile)
  } else {
    Write-Host ("OK: public/sync/index.html bereits {0}" -f $winFile)
  }

  $firebasePath = Join-Path $RepoRoot 'firebase.json'
  $firebase = [System.IO.File]::ReadAllText($firebasePath)
  $firebasePattern = '"/download/vibesbox-sync-windows",\s*"destination":\s*"/sync/VibesBox-Sync-[^"]+-windows\.exe"'
  $firebaseReplacement = ('"/download/vibesbox-sync-windows", "destination": "/sync/{0}"' -f $winFile)

  if ($firebase -like ('*/sync/{0}*' -f $winFile)) {
    Write-Host ("OK: firebase.json bereits {0}" -f $winFile)
  } elseif ($firebase -match $firebasePattern) {
    $firebase2 = [regex]::Replace($firebase, $firebasePattern, $firebaseReplacement, 1)
    if ($firebase2 -notlike ('*/sync/{0}*' -f $winFile)) {
      throw ("firebase.json zeigt nicht auf {0}." -f $winFile)
    }
    [System.IO.File]::WriteAllText($firebasePath, $firebase2, $utf8NoBom)
    Write-Host ("OK: firebase.json -> {0}" -f $winFile)
  } else {
    throw "firebase.json Windows-Rewrite nicht gefunden."
  }
}

Write-Host ("Version sync fertig: {0}" -f $Version)
Write-Output $Version
