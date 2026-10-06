#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Write-Host "force_pull_114 -> 1.0.14 WIN_WAL_COPY" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'run_windows_new.ps1') -Branch 'cursor/windows-sync-all-in-one-b710'
