# Cloud Functions für DJ OG App

## Setup

1. **Firebase CLI installieren:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Firebase einloggen:**
   ```bash
   firebase login
   ```

3. **Projekt initialisieren (falls noch nicht geschehen):**
   ```bash
   firebase init functions
   ```

4. **Dependencies installieren:**
   ```bash
   cd functions
   npm install
   ```

5. **Gmail App-Passwort erstellen:**
   - Gehe zu https://myaccount.google.com/apppasswords
   - Erstelle ein App-Passwort für "Mail"
   - Ersetze `YOUR_APP_PASSWORD` in `functions/index.js` mit dem App-Passwort

6. **Cloud Function deployen:**
   ```bash
   firebase deploy --only functions
   ```

## Funktionen

### sendContactEmail
Sendet automatisch eine Email an `info@dj-ollerganove.de`, wenn eine neue Kontaktanfrage in Firestore gespeichert wird.

## Wichtig

- Das Gmail App-Passwort muss in `functions/index.js` eingetragen werden
- Die Email-Adresse `ollerganove@gmail.com` muss in `functions/index.js` angepasst werden, falls nötig















