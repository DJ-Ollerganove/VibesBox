# Skript zum Hinzufügen von Flutter zum Windows PATH (permanent)

$flutterBinPath = "C:\Users\Ollerganove\Downloads\flutter_windows_3.38.4-stable\flutter\bin"

Write-Host "Flutter PATH-Konfiguration" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Prüfe ob Flutter existiert
if (-not (Test-Path "$flutterBinPath\flutter.bat")) {
    Write-Host "FEHLER: Flutter nicht gefunden unter: $flutterBinPath" -ForegroundColor Red
    Write-Host "Bitte passe den Pfad in diesem Skript an." -ForegroundColor Yellow
    exit 1
}

Write-Host "Flutter gefunden: $flutterBinPath" -ForegroundColor Green
Write-Host ""

# Prüfe ob Flutter bereits im PATH ist
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -like "*$flutterBinPath*") {
    Write-Host "Flutter ist bereits im PATH enthalten." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Möchten Sie trotzdem fortfahren? (J/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne "J" -and $response -ne "j" -and $response -ne "Y" -and $response -ne "y") {
        Write-Host "Abgebrochen." -ForegroundColor Yellow
        exit 0
    }
}

# Füge Flutter zum User-PATH hinzu
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$flutterBinPath*") {
        $newPath = $userPath + ";$flutterBinPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "Flutter wurde erfolgreich zum PATH hinzugefügt!" -ForegroundColor Green
    } else {
        Write-Host "Flutter ist bereits im PATH enthalten." -ForegroundColor Yellow
    }
    
    # Aktualisiere PATH für aktuelle Session
    $env:PATH += ";$flutterBinPath"
    
    Write-Host ""
    Write-Host "Hinweis: Starten Sie ein neues Terminal/PowerShell-Fenster, damit die Änderungen wirksam werden." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Testen Sie Flutter mit: flutter --version" -ForegroundColor Cyan
    
} catch {
    Write-Host "FEHLER beim Hinzufügen zum PATH: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manuelle Lösung:" -ForegroundColor Yellow
    Write-Host "1. Öffnen Sie die Systemeigenschaften" -ForegroundColor Yellow
    Write-Host "2. Gehen Sie zu 'Erweitert' -> 'Umgebungsvariablen'" -ForegroundColor Yellow
    Write-Host "3. Bearbeiten Sie die 'Path' Variable unter 'Benutzervariablen'" -ForegroundColor Yellow
    Write-Host "4. Fügen Sie hinzu: $flutterBinPath" -ForegroundColor Yellow
    exit 1
}
























