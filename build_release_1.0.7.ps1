# Release-Build (Version siehe pubspec.yaml, z. B. 1.0.32+32)
# Flutter: zuerst Downloads, dann Desktop (häufige lokale Pfade), sonst PATH
$flutterPath = "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat"
if (-not (Test-Path $flutterPath)) {
    $desktopFlutter = "$env:USERPROFILE\Desktop\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat"
    if (Test-Path $desktopFlutter) { $flutterPath = $desktopFlutter }
    else { $flutterPath = "flutter" }
}
$projectRoot = $PSScriptRoot
Set-Location $projectRoot

Write-Host "Flutter clean..."
& $flutterPath clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "flutter pub get..."
& $flutterPath pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Workaround für "strip debug symbols" (Flutter 3.32+): Validierung überspringen
# Deine Flutter gradle.dart wurde gepatcht (|| true) – Snapshot nach Änderungen ggf. löschen
$env:FLUTTER_SKIP_AAB_STRIP_CHECK = '1'

# AAB mit Obfuscation und Symbolen für Play Store
# Version aus pubspec.yaml nutzen; optional: --build-name=1.0.25 --build-number=25
# --no-tree-shake-icons verhindert Icon-Font-Probleme im Release
# Optional Geheimnisse (müssen zu Firebase Functions / Google Cloud passen):
#   --dart-define=CONTACT_APP_SECURITY_KEY=...
#   --dart-define=GOOGLE_MAPS_API_KEY=...
Write-Host "Build App Bundle / AAB (Release, mit --obfuscate, --split-debug-info, --no-tree-shake-icons)..."
& $flutterPath build appbundle --release --no-tree-shake-icons --obfuscate --split-debug-info=build/app/outputs/symbols
$buildOk = $LASTEXITCODE -eq 0

$aabPath = "build\app\outputs\bundle\release\app-release.aab"
$symbolsDir = "build\app\outputs\symbols"
if (Test-Path $aabPath) {
    Write-Host "AAB: $aabPath" -ForegroundColor Green
    Write-Host "  Größe: $((Get-Item $aabPath).Length / 1MB) MB"
} else {
    Write-Host "Hinweis: Bei Fehler 'strip debug symbols' wurde die AAB oft trotzdem erzeugt. Prüfe: $aabPath"
}
if (Test-Path $symbolsDir) {
    Write-Host "Symbole (für Play Store / Deobfuskierung): $symbolsDir" -ForegroundColor Cyan
    Get-ChildItem $symbolsDir -File | ForEach-Object { Write-Host "  - $($_.Name)" }
}
# Mapping (R8/ProGuard): android\app\build\outputs\mapping\release\mapping.txt (nur bei isMinifyEnabled = true)
if (-not $buildOk) {
    Write-Host "Hinweis: Build kann mit 'strip debug symbols' enden - AAB und Symbole liegen ggf. trotzdem vor." -ForegroundColor Yellow
}
