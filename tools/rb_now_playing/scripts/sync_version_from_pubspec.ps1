#Requires -Version 5.1
<#
.SYNOPSIS
  Eine Versionsquelle: pubspec.yaml -> Tool-Runtime, Installer-Default, optional Hosting.
#>

[CmdletBinding()]
param(
  [switch]$UpdateHosting
)

$ErrorActionPreference = 'Stop'
$ToolRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RepoRoot = Resolve-Path (Join-Path $ToolRoot '..\..')

$pubspecPath = Join-Path $ToolRoot 'pubspec.yaml'
$pubspec = Get-Content -Raw -Encoding UTF8 $pubspecPath
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw "Konnte version in pubspec.yaml nicht lesen."
}
$Version = $Matches[1]
Write-Host "Sync-Tool Version aus pubspec: $Version"

$versionDart = @"
// GENERATED from pubspec.yaml - nicht von Hand pflegen.
// Quelle: tools/rb_now_playing/pubspec.yaml (version:)
// Sync: scripts/sync_version_from_pubspec.ps1 / .sh
const kSyncToolVersion = '$Version';
"@
$versionDartPath = Join-Path $ToolRoot 'lib\tool_version.dart'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($versionDartPath, $versionDart.Replace("`r`n", "`n"), $utf8NoBom)
Write-Host "OK: lib/tool_version.dart"

$issPath = Join-Path $ToolRoot 'installer\vibesbox_sync.iss'
$iss = [System.IO.File]::ReadAllText($issPath)
$iss2 = [regex]::Replace($iss, '(#define MyAppVersion\s+)"[^"]+"', "`$1`"$Version`"")
if ($iss2 -eq $iss -and $iss -notmatch [regex]::Escape("`"$Version`"")) {
  throw "Konnte MyAppVersion in vibesbox_sync.iss nicht setzen."
}
[System.IO.File]::WriteAllText($issPath, $iss2, $utf8NoBom)
Write-Host "OK: installer/vibesbox_sync.iss"

if ($UpdateHosting) {
  $winFile = "VibesBox-Sync-$Version-windows.exe"
  $htmlPath = Join-Path $RepoRoot 'public\sync\index.html'
  $html = [System.IO.File]::ReadAllText($htmlPath)
  $html2 = [regex]::Replace(
    $html,
    'Für Windows-OS:\s*<a class="download" href="/sync/VibesBox-Sync-[^"]+-windows\.exe">Download</a>\s*<span class="ver">Version [^<]+</span>',
    "Für Windows-OS:`n        <a class=`"download`" href=`"/sync/$winFile`">Download</a>`n        <span class=`"ver`">Version $Version</span>"
  )
  if ($html2 -eq $html) {
    throw "Konnte Windows-Link in public/sync/index.html nicht aktualisieren."
  }
  [System.IO.File]::WriteAllText($htmlPath, $html2, $utf8NoBom)
  Write-Host "OK: public/sync/index.html -> $winFile"

  $firebasePath = Join-Path $RepoRoot 'firebase.json'
  $firebase = [System.IO.File]::ReadAllText($firebasePath)
  $firebase2 = [regex]::Replace(
    $firebase,
    '"/download/vibesbox-sync-windows",\s*"destination":\s*"/sync/VibesBox-Sync-[^"]+-windows\.exe"',
    "`"/download/vibesbox-sync-windows`", `"destination`": `"/sync/$winFile`""
  )
  if ($firebase2 -eq $firebase) {
    throw "Konnte firebase.json Windows-Rewrite nicht aktualisieren."
  }
  [System.IO.File]::WriteAllText($firebasePath, $firebase2, $utf8NoBom)
  Write-Host "OK: firebase.json -> $winFile"
}

Write-Host "Version sync fertig: $Version"
Write-Output $Version
