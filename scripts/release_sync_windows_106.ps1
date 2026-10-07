#Requires -Version 5.1
<#
.SYNOPSIS
  Holt Branch, baut VibesBox Sync 1.0.6 und deployt Hosting.

.NOTES
  Bricht ab, wenn pubspec nicht genau 1.0.6 ist.
#>

$ErrorActionPreference = 'Stop'
$Branch = 'cursor/windows-vcredist-installer-b710'
$Expect = '1.0.6'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

Write-Host ("==> git fetch/checkout {0}" -f $Branch) -ForegroundColor Cyan
git fetch origin $Branch
if ($LASTEXITCODE -ne 0) { throw "git fetch fehlgeschlagen" }
git checkout $Branch
if ($LASTEXITCODE -ne 0) { throw "git checkout fehlgeschlagen" }
git pull origin $Branch
if ($LASTEXITCODE -ne 0) { throw "git pull fehlgeschlagen" }

$pubspecPath = Join-Path $RepoRoot 'tools\rb_now_playing\pubspec.yaml'
$pubspec = Get-Content -Raw -Encoding UTF8 $pubspecPath
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw "pubspec.yaml: version nicht lesbar"
}
$got = $Matches[1]
if ($got -ne $Expect) {
  throw @"
Falsche Version in pubspec.yaml: $got (erwartet $Expect)
Branch/Stand pruefen:
  git branch --show-current
  Get-Content tools\rb_now_playing\pubspec.yaml | Select-String '^version:'
"@
}
Write-Host ("OK: pubspec = {0}" -f $got) -ForegroundColor Green

Set-Location (Join-Path $RepoRoot 'tools\rb_now_playing')
Write-Host "==> build_windows_installer.ps1" -ForegroundColor Cyan
& .\build_windows_installer.ps1
if ($LASTEXITCODE -ne 0) { throw "Build fehlgeschlagen" }

$setup = Join-Path (Get-Location) ("dist\VibesBoxSync-Setup-{0}.exe" -f $Expect)
if (-not (Test-Path $setup)) {
  throw ("Setup fehlt: {0}" -f $setup)
}
Write-Host ("OK: {0}" -f $setup) -ForegroundColor Green

Set-Location $RepoRoot
Write-Host "==> deploy_sync_windows.ps1" -ForegroundColor Cyan
& .\scripts\deploy_sync_windows.ps1 -SetupExe $setup
if ($LASTEXITCODE -ne 0) { throw "Deploy fehlgeschlagen" }

Write-Host "==> Live version.json pruefen" -ForegroundColor Cyan
$live = Invoke-RestMethod -Uri 'https://vibesbox.app/sync/version.json' -Headers @{ 'Cache-Control' = 'no-cache' }
Write-Host ("Live: windows={0} mac={1}" -f $live.windows, $live.mac)
if ("{0}" -f $live.windows -ne $Expect) {
  throw ("Live windows ist {0}, nicht {1}. Deploy/Cache pruefen." -f $live.windows, $Expect)
}

Write-Host ""
Write-Host ("Fertig. Windows {0} online." -f $Expect) -ForegroundColor Green
Write-Host "In der App (Admin -> VibesBox Sync): Windows-Zielversion = $Expect"
