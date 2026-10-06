#Requires -Version 5.1
<#
.SYNOPSIS
  Alias: weiterleiten auf force_pull_110.ps1 (Remote 1.0.10).
#>
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'force_pull_110.ps1')
