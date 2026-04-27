# Anleitung: Settings-Dokument in Firestore erstellen

## Option 1: Über Firebase Console (Empfohlen)

1. Öffne die [Firebase Console](https://console.firebase.google.com/project/dj-ollerganove/firestore)
2. Gehe zu **Firestore Database**
3. Klicke auf **"Collection starten"** oder **"Daten hinzufügen"**
4. Erstelle eine neue Collection namens: `settings`
5. Füge ein Dokument hinzu mit der ID: `global_config`
6. Füge folgendes Feld hinzu:
   - Feldname: `copyright_text`
   - Typ: `string`
   - Wert: `2026 by VibesBox`

## Option 2: Über Firebase CLI

```bash
firebase firestore:set settings/global_config '{"copyright_text": "2026 by VibesBox"}'
```

## Option 3: Über Node.js Skript

1. Stelle sicher, dass du `firebase-admin` installiert hast:
   ```bash
   npm install firebase-admin
   ```

2. Erstelle eine `serviceAccountKey.json` Datei mit deinen Firebase Admin SDK Credentials

3. Führe das Skript aus:
   ```bash
   node create_settings_document.js
   ```

## Struktur

```
Collection: settings
  └── Document: global_config
      └── copyright_text: "2026 by VibesBox"
```

## Hinweis

Die PWA lädt den Copyright-Text automatisch aus diesem Dokument. Falls das Dokument nicht existiert, wird der Fallback-Wert "2026 by VibesBox" verwendet.
