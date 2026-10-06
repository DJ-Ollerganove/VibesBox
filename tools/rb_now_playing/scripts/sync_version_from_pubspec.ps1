#Requires -Version 5.1
<#
.SYNOPSIS
  Eine Versionsquelle: pubspec.yaml -> Tool-Runtime, Installer-Default, optional Hosting.

.NOTES
  Nur ASCII in diesem Skript (Windows PowerShell 5.1 / Codepage).
  Hosting: feste Dateinamen + Redirects (nicht Rewrite), damit Browser
  eine echte .exe/.pkg mit Dateiname speichern.
  Marker: SYNC_HOSTING_STABLE_v3
#>

[CmdletBinding()]
param(
  [switch]$UpdateHosting
)

$ErrorActionPreference = 'Stop'
$ToolRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RepoRoot = Resolve-Path (Join-Path $ToolRoot '..\..')
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

$pubspecPath = Join-Path $ToolRoot 'pubspec.yaml'
$pubspec = Get-Content -Raw -Encoding UTF8 $pubspecPath
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw "Konnte version in pubspec.yaml nicht lesen."
}
$Version = $Matches[1]
Write-Host ("Sync-Tool Version aus pubspec: {0}" -f $Version)

$versionDart = @"
// GENERATED from pubspec.yaml - nicht von Hand pflegen.
// Quelle: tools/rb_now_playing/pubspec.yaml (version:)
// Sync: scripts/sync_version_from_pubspec.ps1 / .sh
const kSyncToolVersion = '$Version';
"@
$versionDartPath = Join-Path $ToolRoot 'lib\tool_version.dart'
[System.IO.File]::WriteAllText($versionDartPath, $versionDart.Replace("`r`n", "`n"), $utf8NoBom)
Write-Host "OK: lib/tool_version.dart"

$issPath = Join-Path $ToolRoot 'installer\vibesbox_sync.iss'
$iss = [System.IO.File]::ReadAllText($issPath)
$iss2 = [regex]::Replace($iss, '#define MyAppVersion\s+"[^"]+"', ("#define MyAppVersion `"{0}`"" -f $Version))
$iss2 = [regex]::Replace($iss2, 'OutputBaseFilename=VibesBoxSync-Setup-[^\r\n]+', ("OutputBaseFilename=VibesBoxSync-Setup-{0}" -f $Version))
if ($iss2 -notlike ("*#define MyAppVersion `"{0}`"*" -f $Version)) {
  throw "Konnte MyAppVersion in vibesbox_sync.iss nicht setzen."
}
if ($iss2 -notlike ("*OutputBaseFilename=VibesBoxSync-Setup-{0}*" -f $Version)) {
  throw "Konnte OutputBaseFilename in vibesbox_sync.iss nicht setzen."
}
[System.IO.File]::WriteAllText($issPath, $iss2, $utf8NoBom)
Write-Host ("OK: installer/vibesbox_sync.iss -> VibesBoxSync-Setup-{0}.exe" -f $Version)

if ($UpdateHosting) {
  $syncDir = Join-Path $RepoRoot 'public\sync'
  New-Item -ItemType Directory -Force -Path $syncDir | Out-Null

  # Mac-Version nie mit altem Default ueberschreiben; Windows-Deploy aendert nur windows.
  $macVer = '1.0.5'
  $versionJsonPath = Join-Path $syncDir 'version.json'
  if (Test-Path $versionJsonPath) {
    $prev = [System.IO.File]::ReadAllText($versionJsonPath)
    if ($prev -match '"mac"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"') {
      $macVer = $Matches[1]
    }
  }

  $versionJson = "{`n  `"windows`": `"$Version`",`n  `"mac`": `"$macVer`"`n}`n"
  [System.IO.File]::WriteAllText($versionJsonPath, $versionJson, $utf8NoBom)
  Write-Host ("OK: public/sync/version.json -> windows={0} mac={1}" -f $Version, $macVer)

  $firebasePath = Join-Path $RepoRoot 'firebase.json'
  $firebase = [System.IO.File]::ReadAllText($firebasePath)
  if ($firebase -notlike '*"redirects"*') {
    throw "firebase.json hat keine redirects-Sektion (SYNC_HOSTING_STABLE_v3 fehlt)."
  }
  if ($firebase -notlike '*/download/vibesbox-sync-windows*') {
    throw "firebase.json fehlt Redirect /download/vibesbox-sync-windows"
  }
  if ($firebase -notlike '*/sync/VibesBox-Sync-windows.exe*') {
    throw "firebase.json Redirect zeigt nicht auf /sync/VibesBox-Sync-windows.exe"
  }
  $rewritesChunk = ''
  if ($firebase -match '"rewrites"\s*:\s*\[([\s\S]*?)\]') {
    $rewritesChunk = $Matches[1]
  }
  if ($rewritesChunk -like '*/download/vibesbox-sync-windows*') {
    throw "firebase.json hat Download noch als rewrite - muss redirect sein. Bitte git pull."
  }
  Write-Host "OK: firebase.json Download-Redirects vorhanden"

  $htmlPath = Join-Path $syncDir 'index.html'
  $html = @'
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VibesBox Sync</title>
  <meta name="description" content="VibesBox Sync fuer Windows und Mac herunterladen.">
  <link rel="icon" type="image/png" href="/vb/favicon.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #1A1A1A;
      --card: #242424;
      --accent: #d4834d;
      --text: #F0F0F0;
      --muted: #b0b0b0;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: Inter, sans-serif;
      background: var(--bg);
      color: var(--text);
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 32px 16px;
    }
    main {
      width: min(520px, 100%);
      background: var(--card);
      border: 1px solid rgba(212, 131, 77, 0.45);
      border-radius: 16px;
      padding: 36px 28px 28px;
      text-align: center;
    }
    h1 {
      margin: 0 0 28px;
      font-size: 22px;
      font-weight: 700;
      line-height: 1.35;
    }
    .row {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 14px;
      margin: 18px 0;
      font-size: 18px;
      font-weight: 600;
    }
    .logo {
      width: 36px;
      height: 36px;
      flex: 0 0 36px;
    }
    a.download {
      color: var(--accent);
      font-weight: 700;
      text-decoration: underline;
      text-underline-offset: 3px;
    }
    a.download:hover { color: #e0945a; }
    .ver {
      display: block;
      margin-top: 2px;
      color: var(--muted);
      font-size: 13px;
      font-weight: 400;
    }
  </style>
</head>
<body>
  <main>
    <h1>Hier kannst du VibesBox Sync downloaden</h1>
    <div class="row">
      <svg class="logo" viewBox="0 0 24 24" aria-hidden="true">
        <path fill="#00A4EF" d="M0 0h11.4v11.4H0z"/>
        <path fill="#7FBA00" d="M12.6 0H24v11.4H12.6z"/>
        <path fill="#FFB900" d="M0 12.6h11.4V24H0z"/>
        <path fill="#F25022" d="M12.6 12.6H24V24H12.6z"/>
      </svg>
      <div>
        Fuer Windows-OS:
        <a class="download" href="/sync/VibesBox-Sync-windows.exe" download="VibesBox-Sync-windows.exe">Download</a>
        <span class="ver" id="win-ver">Version …</span>
      </div>
    </div>
    <div class="row">
      <svg class="logo" viewBox="0 0 24 24" aria-hidden="true">
        <path fill="#F0F0F0" d="M16.4 12.6c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.9-3.5.9s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.3 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2-.1 2.9-2.3c.7-1 1.2-2 1.5-3.1-3.9-1.5-3.8-5.6-1.8-6.3zM14.7 5.8c.6-.8 1.1-1.9.9-3-1 .1-2.1.7-2.8 1.5-.6.7-1.2 1.8-.9 2.9 1.1.1 2.1-.5 2.8-1.4z"/>
      </svg>
      <div>
        Fuer Mac-OS:
        <a class="download" href="/sync/VibesBox-Sync-mac.pkg" download="VibesBox-Sync-mac.pkg">Download</a>
        <span class="ver" id="mac-ver">Version …</span>
      </div>
    </div>
  </main>
  <script>
    fetch('/sync/version.json?_=' + Date.now(), { cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .then(function (v) {
        if (v.windows) document.getElementById('win-ver').textContent = 'Version ' + v.windows;
        if (v.mac) document.getElementById('mac-ver').textContent = 'Version ' + v.mac;
      })
      .catch(function () {});
  </script>
</body>
</html>
'@
  [System.IO.File]::WriteAllText($htmlPath, $html.Replace("`r`n", "`n"), $utf8NoBom)
  Write-Host "OK: public/sync/index.html (direkte .exe/.pkg Links, SYNC_HOSTING_STABLE_v3)"
}

Write-Host ("Version sync fertig: {0}" -f $Version)
Write-Output $Version
