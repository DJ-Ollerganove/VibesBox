# Secret-Manager Anleitung (statt Firestore)

## Ziel
Apple Developer Token **nicht** in Firestore speichern, sondern als Secret:

- `APPLE_DEVELOPER_TOKEN`

## Schritt 1: Token erzeugen
Setze zuerst die Umgebungsvariablen für `token_generator.py`:

- `APPLE_KEY_ID`
- `APPLE_TEAM_ID`
- `APPLE_MEDIA_ID`
- `APPLE_PRIVATE_KEY` oder `APPLE_PRIVATE_KEY_PATH`

Dann:

```bash
python token_generator.py
```

## Schritt 2: Secret setzen
```bash
firebase functions:secrets:set APPLE_DEVELOPER_TOKEN
```

## Schritt 3: Function deployen
```bash
firebase deploy --only functions:shazamProxy
```

## Hinweis
- `serviceAccountKey.json` ist für diesen Token-Flow nicht mehr nötig.
- Keine Token-Ablage mehr unter `admin_config/apple_developer_token`.












