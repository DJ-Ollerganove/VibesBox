# PWA Deployment Anleitung

Die PWA wurde erfolgreich erstellt und befindet sich im `public/` Verzeichnis.

## Dateien

- `public/index.html` - Hauptseite mit Wunschbox-Formular
- `public/styles.css` - Styling
- `public/manifest.json` - PWA Manifest
- `public/service-worker.js` - Service Worker für Offline-Funktionalität
- `public/icon-192.png` - App Icon (192x192)
- `public/icon-512.png` - App Icon (512x512)

## Deployment zu Firebase Hosting

### Option 1: Firebase CLI installieren und deployen

1. **Firebase CLI installieren:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Bei Firebase anmelden:**
   ```bash
   firebase login
   ```

3. **Projekt initialisieren (falls noch nicht geschehen):**
   ```bash
   firebase init hosting
   ```
   - Wähle "Use an existing project"
   - Wähle dein Projekt "dj-ollerganove"
   - Public directory: `public`
   - Configure as single-page app: `Yes`
   - Set up automatic builds: `No`

4. **Deployen:**
   ```bash
   firebase deploy --only hosting
   ```

### Option 2: Über Firebase Console

1. Gehe zu [Firebase Console](https://console.firebase.google.com/)
2. Wähle dein Projekt "dj-ollerganove"
3. Gehe zu "Hosting" im Menü
4. Klicke auf "Get started" oder "Add another site"
5. Folge den Anweisungen zum Deployment

## Nach dem Deployment

Die Website wird unter folgender URL erreichbar sein:
- **https://dj-ollerganove.web.app** (Standard)
- **https://dj-ollerganove.firebaseapp.com** (Alternativ)

## Features der PWA

✅ **Wunschbox-Formular** für Gäste
✅ **Duplikat-Erkennung** (ähnlich wie in der App)
✅ **Status-Anzeige** (geöffnet/geschlossen)
✅ **PWA-Funktionalität** (installierbar, offline-fähig)
✅ **Responsive Design** (funktioniert auf allen Geräten)
✅ **Firebase Firestore Integration** (gleiche Datenbank wie die App)

## Wichtige Hinweise

- Die PWA verwendet die gleiche Firestore-Datenbank wie die Flutter-App
- Wünsche werden in der Collection `wishes` gespeichert
- Die Wunschbox prüft automatisch den Status (manueller Schalter + aktive Partys)
- Duplikat-Erkennung funktioniert innerhalb der aktiven Party-Zeit










