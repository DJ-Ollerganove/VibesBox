#Requires -Version 5.1
<#
.SYNOPSIS
  Verwirft alte Sync-Installation und erzwingt Remote 1.0.11 + Build.
#>
$ErrorActionPreference = 'Stop'
$ToolRoot = $PSScriptRoot
Write-Host "force_pull_111 -> run_windows_new (nur 1.0.11)" -ForegroundColor Cyan
& (Join-Path $ToolRoot 'run_windows_new.ps1') -Branch 'cursor/windows-sync-all-in-one-b710'
