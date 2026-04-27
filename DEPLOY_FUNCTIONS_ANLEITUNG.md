# Cloud Functions deployen (inkl. Admin Passwort-Änderung)

## Voraussetzung: Admin-Flag in Firestore

Damit die Funktion `changeUserPassword` aufgerufen werden darf, muss der aufrufende Nutzer in Firestore als Admin markiert sein:

- Öffne **Firebase Console** → **Firestore** → Collection **users**
- Wähle das Dokument mit der **UID des Admin-Nutzers**
- Füge das Feld **`admin`** vom Typ **boolean** mit dem Wert **`true`** hinzu (oder bearbeite es)

Ohne `admin: true` unter `users/{uid}` liefert die Cloud Function einen Berechtigungsfehler.

---

## Terminal-Befehle (Projekt-Root)

### 1. Firebase CLI (falls noch nicht eingerichtet)

```bash
npm install -g firebase-tools
firebase login
```

### 2. Nur Functions initialisieren (falls noch kein `functions`-Ordner mit package.json existiert)

```bash
firebase init functions
```

- Bei "Use an existing project?" das richtige Projekt wählen.
- Sprache: **JavaScript** (bei dir bereits vorhanden).
- ESLint: nach Belieben.
- npm install: **Ja**.

**Hinweis:** Bei dir existiert der Ordner `functions` bereits – du kannst diesen Schritt überspringen.

### 3. Abhängigkeiten in `functions` installieren

```bash
cd functions
npm install
cd ..
```

### 4. Nur Cloud Functions deployen

```bash
firebase deploy --only functions
```

Um nur die neue Funktion zu deployen (weniger Risiko für bestehende Functions):

```bash
firebase deploy --only functions:changeUserPassword
```

### 5. (Optional) Flutter-App Abhängigkeiten

```bash
flutter pub get
```

---

## Kurz-Checkliste

| Schritt | Befehl |
|--------|--------|
| In Projekt-Root wechseln | `cd c:\Users\Ollerganove\Desktop\dj-og-app` |
| Functions-Abhängigkeiten | `cd functions` → `npm install` → `cd ..` |
| Functions deployen | `firebase deploy --only functions` |
| Nur eine Function | `firebase deploy --only functions:changeUserPassword` |

---

## Aufruf aus der Flutter-App

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:vibesbox/services/admin_service.dart';

// Beispiel: Passwort für Nutzer mit UID setzen
try {
  await AdminService.instance.changeUserPassword(
    targetUid: 'HIER_DIE_UID_DES_NUTZERS',
    newPassword: 'NeuesSicheresPasswort123',
  );
  // Erfolg
} on FirebaseFunctionsException catch (e) {
  // e.code: 'permission-denied', 'invalid-argument', 'unauthenticated', 'internal' usw.
  // e.message: Fehlermeldung
}
```

Die UID des Ziel-Nutzers findest du in der **Firebase Console** unter **Authentication** → **Users** (Spalte "User UID").
