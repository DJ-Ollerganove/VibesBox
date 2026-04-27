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

6. **Secrets für Kontaktformular (App-Guest) setzen:**
   ```bash
   firebase functions:secrets:set CONTACT_APP_SECURITY_KEY
   ```
   Wert eingeben: derselbe wie `AppConfig.contactAppSecurityKey` (Build-Define / sichere Quelle, nicht im Repo).

7. **EmailJS (ohne Klartext im Repo):** Secret `EMAILJS_PRIVATE_KEY`; in der Functions-Umgebung u. a. setzen: `EMAILJS_PUBLIC_KEY`, `EMAILJS_SERVICE_ID`, `EMAILJS_TEMPLATE_ID` (Firebase Console → Functions → Konfiguration).

8. **Cloud Function deployen:**
   ```bash
   firebase deploy --only functions
   ```

## Funktionen

### sendContactEmail
Sendet automatisch eine Email an `info@vibesbox.app`, wenn eine neue Kontaktanfrage in Firestore gespeichert wird.

### validateRecaptchaAndSaveContact
Kontaktformular-API für PWA (reCAPTCHA) und Flutter-App (App-Security-Key).

- **PWA/Landingpage:** reCAPTCHA-Token im Body, speichert in Firestore `contacts`, versendet E-Mail
- **App-Guest (Flutter):** Kein reCAPTCHA, stattdessen Header `X-App-Security-Key`. Kein Firestore-Write (datenbankschonend), E-Mail geht an `info@vibesbox.app`

## Wichtig

- Das Gmail App-Passwort muss in `functions/index.js` eingetragen werden
- Die Email-Adresse `ollerganove@gmail.com` muss in `functions/index.js` angepasst werden, falls nötig





















































