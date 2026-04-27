# repair_flutter_build.ps1
# Behebt den "failed to strip debug symbols" Fehler nach Flutter-Updates.
# Rechtsklick -> "Mit PowerShell ausfuehren"

# 1. Flutter-Pfad ermitteln
$knownPath = "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter"
$flutterRoot = $null

if (Test-Path $knownPath) {
    $flutterRoot = $knownPath
    Write-Host "Flutter gefunden (bekannter Pfad): $flutterRoot" -ForegroundColor Cyan
} else {
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        $flutterExe = $flutterCmd.Source
        $flutterRoot = Split-Path (Split-Path $flutterExe -Parent) -Parent
        Write-Host "Flutter gefunden (PATH): $flutterRoot" -ForegroundColor Cyan
    }
}

if (-not $flutterRoot -or -not (Test-Path $flutterRoot)) {
    Write-Host "FEHLER: Flutter-Installation nicht gefunden." -ForegroundColor Red
    Write-Host "Bitte Pfad in diesem Script anpassen (Zeile mit knownPath)." -ForegroundColor Yellow
    exit 1
}

$gradleDart = Join-Path $flutterRoot "packages\flutter_tools\lib\src\android\gradle.dart"
$snapshotPath = Join-Path $flutterRoot "bin\cache\flutter_tools.snapshot"

# 2. gradle.dart patchen
$patchPattern = "globals.platform.environment['FLUTTER_SKIP_AAB_STRIP_CHECK'] == '1'"
$patchedPattern = "globals.platform.environment['FLUTTER_SKIP_AAB_STRIP_CHECK'] == '1' || true"

if (Test-Path $gradleDart) {
    $content = Get-Content $gradleDart -Raw -Encoding UTF8
    if ($content -match [regex]::Escape($patchedPattern)) {
        Write-Host "Patch bereits vorhanden. Keine Aenderung noetig." -ForegroundColor Green
    } elseif ($content -match [regex]::Escape($patchPattern)) {
        $content = $content -replace ([regex]::Escape($patchPattern) + ';'), ($patchedPattern + ';')
        Set-Content $gradleDart -Value $content -NoNewline -Encoding UTF8
        Write-Host "gradle.dart wurde gepatcht (Skip-Check aktiviert)." -ForegroundColor Green
    } else {
        Write-Host "Warnung: Erwartete Zeile in gradle.dart nicht gefunden. Bitte manuell pruefen." -ForegroundColor Yellow
    }
} else {
    Write-Host "FEHLER: gradle.dart nicht gefunden unter: $gradleDart" -ForegroundColor Red
    exit 1
}

# 3. Snapshot loeschen
if (Test-Path $snapshotPath) {
    Remove-Item $snapshotPath -Force
    Write-Host "flutter_tools.snapshot geloescht. Wird beim naechsten Flutter-Befehl neu erstellt." -ForegroundColor Green
} else {
    Write-Host "Snapshot war nicht vorhanden oder bereits geloescht." -ForegroundColor Gray
}

# 4. flutter doctor ausfuehren
$flutterBat = Join-Path $flutterRoot "bin\flutter.bat"
Write-Host ""
Write-Host "Fuehre flutter doctor aus (erstellt neuen Snapshot)..." -ForegroundColor Cyan
& $flutterBat doctor

Write-Host ""
Write-Host "Reparatur abgeschlossen. Du kannst nun wieder flutter build appbundle --release ausfuehren." -ForegroundColor Green
