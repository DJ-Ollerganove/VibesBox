# Apple Developer Token Management (Cloud Secret)

## Übersicht
Der Apple Developer Token wird **nicht** mehr in Firestore gespeichert.  
Er liegt ausschließlich als Secret in Firebase Secret Manager:

- `APPLE_DEVELOPER_TOKEN`

Die App holt keinen Token mehr direkt aus der Datenbank.

## Token generieren und setzen

### Option 1: Automatisch (empfohlen)
```bash
python save_token_to_firestore.py
```

Historischer Dateiname, neue Funktion:
1. Token über `token_generator.py` erzeugen
2. Secret `APPLE_DEVELOPER_TOKEN` per Firebase CLI setzen
3. Hinweis zum Deploy ausgeben

### Option 2: Manuell
1. Token erzeugen:
   ```bash
   python token_generator.py
   ```
2. Secret setzen:
   ```bash
   firebase functions:secrets:set APPLE_DEVELOPER_TOKEN
   ```
3. Function deployen:
   ```bash
   firebase deploy --only functions:shazamProxy
   ```

## Benötigte Umgebungsvariablen für token_generator.py

- `APPLE_KEY_ID`
- `APPLE_TEAM_ID`
- `APPLE_MEDIA_ID`
- `APPLE_PRIVATE_KEY` **oder** `APPLE_PRIVATE_KEY_PATH`

## Troubleshooting

### 401 im `shazamProxy`
- Token abgelaufen oder ungültig -> Secret neu setzen
- Danach `firebase deploy --only functions:shazamProxy`

### 503 von Apple
- Signaturformat prüfen (ShazamKit-Fingerprint, nicht PCM)












