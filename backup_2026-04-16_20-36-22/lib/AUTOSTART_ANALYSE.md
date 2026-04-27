# Analyse: Autostart-Schalter „Musikerkennung automatisch starten bei Party-Beginn“

## 1. Speicherort des Schalters

### Firestore (persistenter Speicher)
- **Collection:** `users`
- **Dokument:** Abhängig von der aufrufenden Stelle (siehe unten)
- **Feld:** `auto_start_recognition` (Typ: `bool`)

### Wo wird geschrieben?
| Datei | Zeile | Dokument-ID | Methode |
|-------|--------|-------------|--------|
| `lib/widgets/audio_settings_card.dart` | 409–411 | **`user.uid`** (FirebaseAuth.currentUser!.uid) | `_saveAutoStartRecognition(bool enabled)` |
| `lib/pages/profile/widgets/shazam_settings_section.dart` | 755–760 | **`user.uid`** | `_saveAutoStartRecognition(bool enabled)` |

### Wo wird gelesen?
| Datei | Zeile | Dokument-ID | Variable / Methode |
|-------|--------|-------------|--------------------|
| `lib/services/party_autostart_service.dart` | 70–79 | **`effectiveDjId`** (siehe AppConfig.getEffectiveDjId) | `_lastAutoStartSetting` in `_loadAutoStartSetting()` |
| `lib/services/party_autostart_service.dart` | 126–128 | **`effectiveDjId`** | User-Snapshot-Listener in `_setupUserListener()` |

**effectiveDjId:** Für Admin-Login liefert `AppConfig.getEffectiveDjId()` die **adminDjId** (z.B. feste UID des DJ-Accounts), sonst `user.uid`.  
→ **Mögliche Lücke:** UI schreibt in `users/{user.uid}`, der Service liest für Admins aus `users/{adminDjId}`. Wenn Admin eingeloggt ist, sind das unterschiedliche Dokumente – der Service sieht ggf. nie die vom Admin gesetzte Einstellung.

---

## 2. Prüf-Mechanismus (wo wird der Wert abgefragt?)

### Einzige Stelle: PartyAutostartService._checkPartyStatus()

**Datei:** `lib/services/party_autostart_service.dart`  
**Zeilen:** 156–198 (Auszug)

```dart
void _checkPartyStatus(List<QueryDocumentSnapshot> partyDocs) {
  // ... isPartyActive aus start_date/end_date/lifecycle_status berechnet ...
  if (_lastPartyStatus != isPartyActive) {
    _lastPartyStatus = isPartyActive;
    if (isPartyActive) {
      if (_lastAutoStartSetting == true) {   // ← hier wird die Einstellung geprüft
        _startRecognition();
      } else {
        print('ℹ️ Party aktiv, aber Autostart deaktiviert');
      }
    } else {
      _stopRecognition();
    }
  }
}
```

- **Bedingung für Start:** `_lastAutoStartSetting == true` **und** `isPartyActive == true` (Party läuft laut Zeit + nicht beendet).
- **Weitere Nutzung:** Im User-Profil-Listener (Zeilen 134–147): wenn sich `auto_start_recognition` ändert und `_lastPartyStatus` true ist, wird je nach neuem Wert `_stopRecognition()` oder `_startRecognition()` aufgerufen.

---

## 3. App-Start vs. Party-Start (wann wird die Prüfung getriggert?)

### A) Kaltstart der App (User bereits eingeloggt)

**Datei:** `lib/main_main_page.dart`  
**Zeilen:** 211–219

```dart
// Initialisiere Autostart-Service wenn bereits eingeloggt
final previousUser = _previousUser;
if (previousUser != null) {
  // PartyAutostartService deaktiviert - Shazam wird nicht mehr automatisch gestartet
  // PartyAutostartService().initialize().catchError((e) {
  //   print('❌ Fehler beim Initialisieren des PartyAutostartService: $e');
  // });
}
```

- **Fakt:** Beim Kaltstart mit bereits eingeloggtem User wird **PartyAutostartService().initialize() auskommentiert** und **nicht** aufgerufen.
- **Folge:** Beim Öffnen der App ohne erneuten Login laufen weder Party-Listener noch User-Listener noch periodische Zeitprüfung – der Autostart-Code wird gar nicht aktiv.

### B) Login / Auth-Änderung (User wechselt von ausgeloggt → eingeloggt)

**Datei:** `lib/main_main_page.dart`  
**Zeilen:** 174–193

```dart
_authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
  if ((_previousUser == null) != (user == null) || (_previousUser?.email != user?.email)) {
    // ...
    if (user != null) {
      PartyAutostartService().initialize().catchError((e) { ... });
    } else {
      PartyAutostartService().dispose();
    }
  }
});
```

- **Fakt:** `initialize()` wird nur aufgerufen, wenn sich der Auth-Status (oder die User-Identität) **ändert** und `user != null` ist.
- **Folge:** Autostart läuft nur nach frischem Login, nicht bei App-Start mit bestehender Session.

### C) Party wechselt von „Bevorstehend“ zu „Laufend“

- **Trigger:** Firestore-`parties`-Snapshot-Änderung **oder** der 30-Sekunden-Timer im PartyAutostartService.
- **Ablauf:** `_checkPartyStatus(snapshot.docs)` wird ausgeführt, berechnet `isPartyActive`. Wenn `_lastPartyStatus != isPartyActive` und `isPartyActive == true`, dann wird bei `_lastAutoStartSetting == true` `_startRecognition()` aufgerufen.
- **Voraussetzung:** Der Service muss vorher einmal `initialize()` durchlaufen haben (siehe A/B).

---

## 4. Mögliche Blockaden (Flags / Bedingungen)

### PartyAutostartService

| Bedingung | Datei:Zeile | Wirkung |
|-----------|-------------|--------|
| `_isInitialized` | 27–29 | Wenn schon initialisiert: `initialize()` bricht sofort ab, keine erneute Registrierung. |
| `user == null` | 31–35 | Ohne eingeloggten User: `initialize()` bricht ab. |
| `effectiveDjId == null` | 93–96, 119–122 | Kein Listener für Partys/User, kein Laden der Einstellung. |
| `_lastAutoStartSetting != true` | 188 | Auch bei aktiver Party wird **nicht** gestartet. |
| `_lastPartyStatus == isPartyActive` | 183 | Nur bei **Wechsel** des Party-Status wird reagiert; gleicher Status → kein erneuter Start. |
| `_shazamService.isEnabled` | 204 | In `_startRecognition()`: wenn Shazam schon aktiv, wird kein zweiter Start ausgeführt. |

### ShazamService (aus PartyAutostartService aufgerufen)

| Bedingung | Wirkung |
|-----------|--------|
| `_isEnabled` (getter `isEnabled`) | In `startAutoScanning()`: wenn schon true, wird „bereits aktiv“ geloggt und sofort return – kein erneuter Start. |

### Race beim ersten Start

- In `initialize()` wird **`_loadAutoStartSetting()` ohne await** aufgerufen (Zeile 44).
- Direkt danach werden `_setupPartiesListener()` und `_setupUserListener()` gestartet.
- Beim **ersten** Firestore-Snapshot (Partys) läuft `_checkPartyStatus()` – zu diesem Zeitpunkt kann `_loadAutoStartSetting()` noch nicht fertig sein, also ist **`_lastAutoStartSetting` noch `null`**.
- Dann gilt `_lastAutoStartSetting == true` → **false** → Autostart startet nicht, obwohl der User die Einstellung in Firestore auf true gesetzt haben könnte.

---

## 5. UI-Zustand des Schalters (warum „zeigt keine Wirkung“?)

### Einstellungen / Profil: Schalter ist deaktiviert

**audio_settings_card.dart**, Zeilen 832–867:

- Autostart wird als **Checkbox** mit `value: false` und `onChanged: null` angezeigt.
- Darüber: `Opacity(opacity: 0.5)` und `IgnorePointer(ignoring: true)`.
- Beschreibungstext: „Funktion derzeit deaktiviert und ohne Funktion“.

**shazam_settings_section.dart**, Zeilen 627–659:

- Gleiche Logik: Checkbox fest `value: false`, `onChanged: null`, `IgnorePointer`, Opacity 0.5.
- Text: „… (Deaktiviert)“.

**Fazit:** Der Nutzer kann den Schalter in der aktuellen UI **nicht** umlegen; die Anzeige ist fest auf „Aus“ und nicht klickbar. Eine „Wirkung“ im Sinne von „Schalter an → Erkennung startet“ ist so nicht möglich. Zusätzlich verhindern die Punkte unter 1–4, dass der Service die Einstellung zuverlässig beim Kaltstart und beim ersten Party-Start anwendet, selbst wenn sie in Firestore stünde.

---

## 6. Kurz: Wo die logische Verbindung unterbrochen ist

1. **UI:** Schalter ist abgeschaltet (IgnorePointer, onChanged: null, value: false) – keine Nutzeraktion schreibt `auto_start_recognition`.
2. **Kaltstart:** `PartyAutostartService().initialize()` ist beim Start mit bestehendem Login auskommentiert – Service läuft oft gar nicht.
3. **Race:** `_loadAutoStartSetting()` wird in `initialize()` nicht awaited – erstes `_checkPartyStatus()` kann mit `_lastAutoStartSetting == null` laufen und startet dann nicht.
4. **Admin vs. Nutzer-Dokument:** UI schreibt `users/{user.uid}`, Service liest für Admins `users/{effectiveDjId}` (adminDjId) – unterschiedliche Dokumente, Einstellung kann für den Service unsichtbar bleiben.

Diese Punkte erklären, warum die Autostart-Einstellung in der Praxis keine Wirkung zeigt.
