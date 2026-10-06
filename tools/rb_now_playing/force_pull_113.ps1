#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Write-Host "force_pull_113 -> 1.0.13 (Presence wipe fix + Mac-Open)" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'run_windows_new.ps1') -Branch 'cursor/windows-sync-all-in-one-b710'
