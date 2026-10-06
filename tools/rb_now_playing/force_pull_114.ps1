#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Write-Host "force_pull -> 1.0.5 (ohne History-Panel)" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'run_windows_new.ps1') -Branch 'cursor/windows-sync-all-in-one-b710'
