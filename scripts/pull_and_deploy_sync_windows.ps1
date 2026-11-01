#Requires -Version 5.1
<#
.SYNOPSIS
  Erzwingt aktuellen Sync-Hosting-Stand vom Branch, dann Deploy.

.DESCRIPTION
  1) git fetch + kritische Dateien vom Remote ueberschreiben
  2) Installer nach public/sync/VibesBox-Sync-windows.exe kopieren
  3) firebase deploy --only hosting

.NOTES
  Ein Befehl, wenn lokaler Stand / Pull blockiert ist.
#>

[CmdletBinding()]
param(
  [string]$Branch = 'cursor/windows-sync-installer-b710',
  [string]$SetupExe = ''
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

Write-Host ("==> Hole Sync-Hosting-Dateien von origin/{0}" -f $Branch) -ForegroundColor Cyan
git fetch origin $Branch
if ($LASTEXITCODE -ne 0) { throw "git fetch fehlgeschlagen" }

$files = @(
  'scripts/deploy_sync_windows.ps1',
  'tools/rb_now_playing/scripts/sync_version_from_pubspec.ps1',
  'public/sync/index.html',
  'public/sync/version.json',
  'firebase.json'
)
# pull-Skript selbst, falls schon auf Remote
if (git cat-file -e "origin/$Branch`:scripts/pull_and_deploy_sync_windows.ps1" 2>$null) {
  $files += 'scripts/pull_and_deploy_sync_windows.ps1'
}
git checkout "origin/$Branch" -- @files
if ($LASTEXITCODE -ne 0) { throw 'git checkout der Sync-Dateien fehlgeschlagen' }

$marker = Select-String -Path 'tools\rb_now_playing\scripts\sync_version_from_pubspec.ps1' -Pattern 'SYNC_HOSTING_STABLE_v3' -SimpleMatch -ErrorAction SilentlyContinue
if (-not $marker) {
  throw "sync_version_from_pubspec.ps1 ist immer noch alt. Branch/Remote pruefen."
}
Write-Host "OK: SYNC_HOSTING_STABLE_v3 vorhanden" -ForegroundColor Green

$deployArgs = @{}
if ($SetupExe) { $deployArgs['SetupExe'] = $SetupExe }
& (Join-Path $RepoRoot 'scripts\deploy_sync_windows.ps1') @deployArgs
