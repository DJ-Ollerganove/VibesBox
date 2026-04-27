# Spotify-Credentials in Firebase reparieren

## Aktueller Stand (Code)

- **Secret Manager:** Es werden die Secrets `SPOTIFY_CLIENT_ID` und `SPOTIFY_CLIENT_SECRET` verwendet (2nd Gen Functions).
- **Token-URL:** `https://accounts.spotify.com/api/token` (korrekt).
- **Auth-Header:** `Authorization: Basic Base64(ClientID:ClientSecret)` (korrekt).
- **Body:** `grant_type=client_credentials` mit `Content-Type: application/x-www-form-urlencoded` (korrekt).
- **Absicherung:** Beide Credentials werden mit `.trim()` gelesen (verhindert 400 durch Leerzeichen/Zeilenumbrüche beim Einfügen).

## Keys prüfen / neu setzen

Da du kein eigenes Spotify-Konto hast: Keys kommen von der App im [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) (Client ID + Client Secret unter „Settings“).

### 1. Secrets neu setzen (neue Werte aus dem Dashboard eintragen)

Im Projektordner (dort wo `firebase.json` liegt):

```bash
firebase functions:secrets:set SPOTIFY_CLIENT_ID
```
Eingabeaufforderung: **Client ID** einfügen (nur die ID, keine Anführungszeichen, kein Leerzeichen am Ende), Enter.

```bash
firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
```
Eingabeaufforderung: **Client Secret** einfügen (nur das Secret, keine Anführungszeichen, kein Leerzeichen am Ende), Enter.

### 2. Cloud Functions neu deployen

Nach dem Setzen der Secrets müssen die Functions neu deployed werden, damit sie die neuen Werte laden:

```bash
firebase deploy --only functions:searchSpotifyTracks,functions:saveToMusicDatabase
```

Oder alle Functions:

```bash
firebase deploy --only functions
```

## Hinweis

- **400 vom Token-Endpunkt** liegt oft an: falschem/abgelaufenem Secret, Leerzeichen/Zeilenumbruch beim Kopieren, oder einer im Dashboard deaktivierten/geänderten App.
- Im [Spotify Dashboard](https://developer.spotify.com/dashboard) unter deiner App: **Settings** → **Client ID** und **Client Secret** erneut kopieren und wie oben eintragen.
