#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Write-Host "force_pull_112 -> nur 1.0.12 (WAL ohne Live-SHM)" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'run_windows_new.ps1') -Branch 'cursor/windows-sync-all-in-one-b710'
