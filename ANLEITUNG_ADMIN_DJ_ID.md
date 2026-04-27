# Anleitung: Admin-DJ-ID finden und fest eintragen

## Schritt 1: ID finden

Die Admin-DJ-ID kann auf folgende Weise gefunden werden:

### Methode 1: Über Firebase Console
1. Öffne die Firebase Console: https://console.firebase.google.com
2. Wähle das Projekt "dj-ollerganove"
3. Gehe zu Firestore Database
4. Suche in der Collection `users` nach einem Dokument mit `email = "info@vibesbox.app"`
5. Die Dokument-ID (UID) ist die gesuchte `adminDjId`

### Methode 2: Über Parties-Collection
1. In der Firebase Console, Collection `parties`
2. Suche nach einem Dokument mit `created_by_email = "info@vibesbox.app"`
3. Das Feld `created_by` enthält die gesuchte `adminDjId`

### Methode 3: Über die App (Debug-Funktion)
1. Öffne die App und logge dich als Admin ein
2. Die Console-Logs zeigen die gefundene ID
3. Oder verwende die Debug-Funktion `FindAdminDjIdHelper.findAllPossibleDjIds()`

## Schritt 2: ID fest eintragen

1. Öffne `lib/config/app_config.dart`
2. Finde die Zeile: `static String? adminDjId;`
3. Ändere sie zu: `static String? adminDjId = "DEINE_DJ_UID_HIER";`
4. Ersetze `DEINE_DJ_UID_HIER` mit der gefundenen UID

## Beispiel:

```dart
// Vorher:
static String? adminDjId;

// Nachher:
static String? adminDjId = "abc123xyz456"; // Firebase UID des DJ-Accounts
```

## Wichtig:

- Die ID muss die Firebase User-ID (UID) des DJ-Accounts sein
- Sie sollte nicht die UID des Admin-Accounts sein (falls unterschiedlich)
- Nach dem Eintragen wird die automatische Such-Logik nicht mehr verwendet


