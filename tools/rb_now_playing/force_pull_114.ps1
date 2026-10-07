#Requires -Version 5.1
# Alias: aktueller Sync-Release-Stand ist 1.0.6 auf windows-vcredist-installer.
Write-Host "force_pull_114 -> leitet auf 1.0.6 / vcredist-Branch um" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'force_pull_106.ps1')
