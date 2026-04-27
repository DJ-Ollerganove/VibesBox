# Wiederherstellungsanleitung für DJ-OG-App Backup

## Voraussetzungen

1. **Flutter SDK** installiert (Version 3.10.3 oder höher)
2. **Firebase CLI** installiert (`npm install -g firebase-tools`)
3. **Node.js** installiert (für Firebase Functions)
4. **Git** installiert (optional, aber empfohlen)

## Schritt-für-Schritt Wiederherstellung

### 1. Neues Projekt-Verzeichnis erstellen

```bash
mkdir dj-og-app-restored
cd dj-og-app-restored
```

### 2. Backup-Verzeichnis identifizieren

Finden Sie das Backup-Verzeichnis (z.B. `backup_2025-01-18_14-30-00`)

### 3. Alle Dateien kopieren

**Windows (PowerShell):**
```powershell
Copy-Item -Path "backup_2025-01-18_14-30-00\*" -Destination . -Recurse -Force
```

**macOS/Linux:**
```bash
cp -r backup_2025-01-18_14-30-00/* .
```

### 4. Flutter Dependencies installieren

```bash
flutter pub get
```

### 5. Firebase Login

```bash
firebase login
```

### 6. Firebase Project verknüpfen

```bash
firebase use dj-ollerganove
```

### 7. Firebase Functions Dependencies installieren

```bash
cd functions
npm install
cd ..
```

### 8. Firebase Konfiguration prüfen

Öffnen Sie `.firebaserc` und prüfen Sie, ob das Projekt korrekt ist:
```json
{
  "projects": {
    "default": "dj-ollerganove"
  }
}
```

### 9. Firestore Rules deployen

```bash
firebase deploy --only firestore:rules
```

### 10. Storage Rules deployen

```bash
firebase deploy --only storage:rules
```

### 11. PWA (Hosting) deployen

```bash
firebase deploy --only hosting
```

### 12. Firebase Functions deployen (optional)

```bash
firebase deploy --only functions
```

### 13. Flutter App testen

```bash
# Android
flutter run

# Web
flutter run -d chrome

# iOS (nur auf macOS)
flutter run -d ios
```

## Wichtige Dateien und Ordner

### Haupt-Code
- `lib/main.dart` - Flutter App Hauptcode
- `lib/firebase_options.dart` - Firebase Konfiguration
- `public/index.html` - PWA Frontend
- `functions/index.js` - Cloud Functions

### Konfiguration
- `pubspec.yaml` - Flutter Dependencies
- `firebase.json` - Firebase Konfiguration
- `.firebaserc` - Firebase Projekt-Referenz
- `firestore.rules` - Firestore Security Rules
- `storage.rules` - Firebase Storage Rules

### Plattform-spezifisch
- `android/` - Android Konfiguration
- `ios/` - iOS Konfiguration
- `web/` - Web Konfiguration
- `windows/`, `linux/`, `macos/` - Desktop-Plattformen

### Assets
- `assets/` - Bilder, Logo, Datenschutz-Text

### Functions
- `functions/` - Cloud Functions Code

## Firebase Projekt wiederherstellen

Falls das Firebase Projekt nicht existiert:

1. Gehen Sie zu https://console.firebase.google.com
2. Erstellen Sie ein neues Projekt
3. Aktivieren Sie:
   - Firestore Database
   - Firebase Storage
   - Firebase Hosting
   - Cloud Functions
4. Führen Sie `firebase init` aus und wählen Sie die Services
5. Ersetzen Sie die generierten Dateien durch die aus dem Backup

## Probleme beheben

### Fehler: "Firebase project not found"
```bash
firebase use --add
# Wählen Sie das Projekt aus der Liste
```

### Fehler: "Flutter SDK not found"
- Stellen Sie sicher, dass Flutter im PATH ist
- Führen Sie `flutter doctor` aus, um Probleme zu identifizieren

### Fehler: "Missing dependencies"
```bash
flutter clean
flutter pub get
cd functions
npm install
cd ..
```

### PWA funktioniert nicht
- Prüfen Sie die Browser-Konsole (F12) auf Fehler
- Stellen Sie sicher, dass `firebase deploy --only hosting` erfolgreich war
- Leeren Sie den Browser-Cache

## Backup-Datum

**Backup erstellt am:** [Datum wird automatisch eingefügt]

## Kontakt

Bei Problemen bei der Wiederherstellung, prüfen Sie:
1. Firebase Console: https://console.firebase.google.com/project/dj-ollerganove
2. Flutter Documentation: https://flutter.dev/docs
3. Firebase Documentation: https://firebase.google.com/docs
