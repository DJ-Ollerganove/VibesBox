#Requires -Version 5.1
<#
.SYNOPSIS
  Erzwingt den Remote-Stand mit Version 1.0.6 und baut danach.
  Nutze das, wenn pubspec bei dir hartnaeckig 1.0.5 zeigt.
#>

$ErrorActionPreference = 'Stop'
$Branch = 'cursor/windows-sync-all-in-one-b710'
$ToolRoot = $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $ToolRoot '..\..')

Write-Host "RepoRoot: $RepoRoot" -ForegroundColor Cyan
Set-Location $RepoRoot

Write-Host "Remote:" -ForegroundColor Cyan
git remote -v
Write-Host "Vorher Branch/Commit:" -ForegroundColor Cyan
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
Write-Host "Vorher pubspec:" -ForegroundColor Cyan
Select-String -Path 'tools\rb_now_playing\pubspec.yaml' -Pattern '^version:'

Write-Host "==> fetch + hard reset auf origin/$Branch" -ForegroundColor Yellow
git fetch origin $Branch
if ($LASTEXITCODE -ne 0) { throw 'git fetch fehlgeschlagen' }

git checkout -B $Branch "origin/$Branch"
if ($LASTEXITCODE -ne 0) { throw 'git checkout -B fehlgeschlagen' }

git reset --hard "origin/$Branch"
if ($LASTEXITCODE -ne 0) { throw 'git reset --hard fehlgeschlagen' }

git clean -fd -- tools/rb_now_playing/pubspec.yaml tools/rb_now_playing/lib/tool_version.dart

Write-Host "Nachher Branch/Commit:" -ForegroundColor Green
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
Write-Host "Nachher pubspec:" -ForegroundColor Green
$verLine = Select-String -Path 'tools\rb_now_playing\pubspec.yaml' -Pattern '^version:' | Select-Object -First 1
Write-Host $verLine
if ("$verLine" -notmatch '1\.0\.6') {
  throw @"
IMMER NOCH NICHT 1.0.6 nach hard reset.
Remote zeigt lokal: $(git rev-parse origin/$Branch)
Bitte Output von:
  git remote -v
  git rev-parse HEAD
  git rev-parse origin/$Branch
hier posten. Repo-Pfad: $RepoRoot
"@
}

Write-Host "OK: 1.0.6 erkannt. Starte run_windows_new.ps1 ..." -ForegroundColor Green
Set-Location $ToolRoot
& (Join-Path $ToolRoot 'run_windows_new.ps1') -Branch $Branch
