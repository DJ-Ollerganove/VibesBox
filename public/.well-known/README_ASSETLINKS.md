# Digital Asset Links (`assetlinks.json`)

Android **App Links** (`autoVerify`) prüfen **pro Host** diese URL:

- `https://vibesbox.app/.well-known/assetlinks.json`
- `https://www.vibesbox.app/.well-known/assetlinks.json`

**Beide** müssen mit **HTTP 200** und gültigem **JSON** antworten (gleicher Inhalt wie `assetlinks.json` in diesem Ordner).

## Firebase Hosting

- Dieselbe `public/`-Datei wird für alle an die Site gehängten **Custom Domains** ausgeliefert.
- Im Firebase Console unter Hosting: **sowohl** Apex (`vibesbox.app`) **als auch** `www.vibesbox.app` zur **gleichen** Site hinzufügen (oder beide auf dasselbe Projekt zeigen lassen).
- Nach Deploy testen: Browser und [Statement List Generator / Google-Dokumentation zu App Links](https://developer.android.com/training/app-links).

## Fingerprints (lokal aus `./gradlew signingReport` für `:app`)

| Variante | SHA-256 (in `assetlinks.json`) |
|----------|--------------------------------|
| **debug** (Windows `~/.android/debug.keystore`) | `99:5A:15:31:D7:1A:87:6D:BC:ED:48:65:E9:25:3A:68:62:C7:32:76:26:1E:90:22:BB:58:BA:4A:DC:A6:03:41` |
| **debug** (macOS `~/.android/debug.keystore`) | `BB:8C:23:7C:FD:0B:D2:6C:46:51:49:29:03:20:93:BF:0B:57:9A:6A:47:99:AC:3D:15:5C:62:51:A9:26:28:76` |
| **release** (`upload-keystore.jks`, Alias `upload`) | `C2:7B:A7:1D:2C:D2:D8:F6:00:9B:D4:2D:A6:95:B4:16:6B:38:31:39:28:88:7A:95:73:9A:7D:9A:47:08:A4:E1` |

## Hinweis Play App Signing

Installations **aus dem Play Store** können mit dem **App-Signing-Key** von Google signiert sein. Dann muss der **SHA-256 aus der Play Console** (App-Integrität → App-Signatur) **zusätzlich** in `sha256_cert_fingerprints` stehen – nicht nur Upload- oder Debug-Key.
