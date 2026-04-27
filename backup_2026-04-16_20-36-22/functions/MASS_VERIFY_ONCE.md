# Einmalige Mass-Verifizierung (`massVerifyExistingUsers`)

`firebase-admin` wird in `index.js` bereits mit `admin.initializeApp()` gestartet – Voraussetzung für `listUsers` / `updateUser`.

## 1. Admin-UID setzen (muss mit deiner eingeloggten Firebase-Auth-UID übereinstimmen)

```bash
firebase functions:config:set massverify.admin_uid="DEINE_AUTH_UID"
```

Die UID findest du z. B. in der Firebase Console unter **Authentication** oder in `AppConfig.adminDjId` (wenn das dein Account ist).

## 2. Nur diese Function deployen

```bash
cd functions
npm install
cd ..
firebase deploy --only functions:massVerifyExistingUsers
```

## 3. Einmal aus der App auslösen (temporärer Trigger)

- Release-/Alltags-Builds: **kein Eintrag im Drawer** (Standard).
- Einmalig bauen/starten mit:

```bash
flutter run --dart-define=MASS_VERIFY_TRIGGER=true
```

Als konfigurierter Admin einloggen → **Drawer** → **„E-Mail-Migration (Admin, einmal)“** → bestätigen.

## 4. Nach erfolgreichem Lauf

- **Kein** `--dart-define=MASS_VERIFY_TRIGGER` mehr verwenden.
- Optional: den markierten Block `// TEMP: Nach erfolgreicher Mass-E-Mail-Verifizierung` in `lib/main_main_page.dart` sowie `massVerifyTriggerEnabled` in `lib/config/app_config.dart` und die Methode `_runMassVerifyExistingUsersMigration` entfernen.
- Optional: Callable in Firebase löschen oder unangetastet lassen (Server prüft weiterhin `massverify.admin_uid`).

## Logs

In den Function-Logs erscheint u. a.:

`[massVerify] Fertig. emailVerified gesetzt: N | gescannt: …`
