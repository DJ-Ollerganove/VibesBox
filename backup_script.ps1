# Backup-Script für DJ-OG-App
# Erstellt ein vollständiges Backup der App und PWA

param(
    [string]$BackupName = ""
)

# 1. Backup-Verzeichnis festlegen
if ($BackupName -eq "") {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $BackupName = "backup_$timestamp"
}

Write-Host "Erstelle Backup: $BackupName" -ForegroundColor Green

# Verzeichnis erstellen
New-Item -ItemType Directory -Path $BackupName -Force | Out-Null

# 2. Ordner kopieren
$directoriesToBackup = @("lib", "public", "functions", "assets", "android", "ios", "web", "windows", "linux", "macos", "test")

foreach ($dir in $directoriesToBackup) {
    if (Test-Path $dir) {
        Write-Host "Kopiere $dir..." -ForegroundColor Yellow
        Copy-Item -Path $dir -Destination $BackupName -Recurse -Force
    } else {
        Write-Host "Warnung: $dir nicht gefunden" -ForegroundColor Yellow
    }
}

# 3. Einzelne Dateien kopieren
$filesToBackup = @(
    "pubspec.yaml", "pubspec.lock", "firestore.rules", "storage.rules", 
    "firebase.json", ".firebaserc", "analysis_options.yaml", ".metadata", 
    "README.md", "DEPLOY_ANLEITUNG.txt", "EINFACHE_ANLEITUNG.txt", 
    "EMAILJS_SETUP.md", "KONTAKTFORMULAR_EMAIL_INFO.md", "PWA_DEPLOYMENT.md", 
    "SOUND_ANLEITUNG.txt", "SOUND_DOWNLOAD_HILFE.md", "SOUND_FINDEN_ANLEITUNG.txt", 
    "ZUSAMMENFASSUNG.txt", "RESTORE_ANLEITUNG.md"
)

foreach ($file in $filesToBackup) {
    if (Test-Path $file) {
        Write-Host "Kopiere $file..." -ForegroundColor Yellow
        Copy-Item -Path $file -Destination $BackupName -Force
    }
}

# 4. Backup-Info erstellen
$backupInfo = @"
DJ-OG-App Backup
================
Backup erstellt am: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Backup-Verzeichnis: $BackupName

Enthaltene Komponenten:
- Flutter App (lib/)
- PWA (public/)
- Firebase/Android Konfigurationen
"@

$backupInfo | Out-File -FilePath "$BackupName\BACKUP_INFO.txt" -Encoding UTF8

# 5. Abschluss und Größenberechnung (JETZT MIT KORREKTEM ZEILENUMBRUCH)
Write-Host "`nBackup erfolgreich erstellt: $BackupName" -ForegroundColor Green
Write-Host "Backup-Größe:" -ForegroundColor Cyan

Get-ChildItem -Path $BackupName -Recurse | Measure-Object -Property Length -Sum | ForEach-Object {
    $sizeMB = [math]::Round($_.Sum / 1MB, 2)
    Write-Host "  $sizeMB MB" -ForegroundColor Cyan
}