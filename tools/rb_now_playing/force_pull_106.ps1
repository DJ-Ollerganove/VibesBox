#Requires -Version 5.1
# Hard-Reset auf Sync 1.0.6 (all-in-one + Installer/VC++/Sprachen). Nie alter Installer-Ast.
Write-Host "force_pull -> 1.0.6 (Frameless + Close-X + VC++-Check)" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'run_windows_new.ps1') -Branch 'cursor/windows-vcredist-installer-b710'
