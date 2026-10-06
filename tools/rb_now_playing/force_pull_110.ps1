#Requires -Version 5.1
<#
.SYNOPSIS
  Verwirft alte Sync-Installation und erzwingt Remote 1.0.10 + Build.
#>

$ErrorActionPreference = 'Stop'
$ToolRoot = $PSScriptRoot

Write-Host "force_pull_110 -> run_windows_new (Hard-Reset + alte Install weg)" -ForegroundColor Cyan
# Kein KeepOldInstall / SkipUninstall: alte 1.0.5/1.0.7/1.0.9 werden verworfen.
& (Join-Path $ToolRoot 'run_windows_new.ps1') -Branch 'cursor/windows-sync-all-in-one-b710'
