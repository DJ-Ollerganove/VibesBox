# Code-Analyse: Status-Umschaltung home_dj vs. party_verwaltung_page

## 1. Filter-Logik – direkter Code-Vergleich

### home_dj.dart (Zeilen 91–113, 541–562)

**Im Timer-Callback `_onTick()`:**
```dart
final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
final parties = _cachedParties ?? [];
bool hasActive = false;
// ...
for (final party in parties) {
  final data = party.data() as Map<String, dynamic>;
  if (data['lifecycle_status'] == 'finished' || data['finished_at'] != null) continue;
  final startPosix = data['start_time_posix'] as int?;
  final endPosix = data['end_time_posix'] as int?;
  if (startPosix == null || endPosix == null) continue;
  if (nowUnix >= startPosix && nowUnix < endPosix) {
    hasActive = true;
    break;
  }
  // ...
}
```

**Im StreamBuilder-Builder (Anzeige):**
```dart
final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
// ...
for (final party in parties) {
  final data = party.data() as Map<String, dynamic>;
  if (data['lifecycle_status'] == 'finished' || data['finished_at'] != null) continue;
  final startPosix = data['start_time_posix'] as int?;
  final endPosix = data['end_time_posix'] as int?;
  if (startPosix != null && endPosix != null) {
    if (nowUnix >= startPosix && nowUnix < endPosix) {
      activeParty = party;
      break;
    }
  }
}
```

- Zeitbasis: **UTC-Unix-Sekunden** (`nowUnix`, `start_time_posix`, `end_time_posix`).
- Bedingung „läuft“: `nowUnix >= startPosix && nowUnix < endPosix`.

---

### party_verwaltung_page.dart (Zeilen 635–652)

```dart
final parties = snapshot.data?.docs ?? [];
// ...
for (final party in parties) {
  final data = party.data() as Map<String, dynamic>;
  if (data['lifecycle_status'] == 'finished' || data['finished_at'] != null) continue;
  final startTimestamp = data['start_date'] as Timestamp?;
  final endTimestamp = data['end_date'] as Timestamp?;
  if (startTimestamp == null || endTimestamp == null) continue;
  final startDate = startTimestamp.toDate();
  final endDate = endTimestamp.toDate();
  final status = _getPartyStatus(startDate, endDate, context);
  if (status == running) {
    runningParties.add(party);
  } else if (status == upcoming) {
    upcomingParties.add(party);
  }
}
```

**_getPartyStatus (Zeilen 64–74):**
```dart
final now = DateTime.now();
if (now.compareTo(startDate) < 0) return 'Bevorstehend';
else if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) return 'Läuft';
else return 'Beendet';
```

- Zeitbasis: **lokale DateTime** (`DateTime.now()`, `start_date`/`end_date` als Timestamp → `.toDate()`).
- Bedingung „läuft“: `now >= startDate && now < endDate` (inhaltlich gleich, andere Typen).

**Unterschied:**  
home_dj nutzt **posix (UTC-Sekunden)**, party_verwaltung **Timestamp/DateTime (lokal)**. Die Logik ist äquivalent; die Lücke liegt nicht an der Zeitbasis, sondern am **Rebuild** (siehe unten).

---

## 2. Timer-Integration – wer löst setState aus?

### home_dj.dart

- **Stream:** Firestore-Snapshots werden nur gecacht (`_cachedParties = snapshot.docs`), es wird **kein** setState im Listener aufgerufen.
- **Timer:** `_secondTickTimer` ruft periodisch `_onTick()` auf (1 s oder 60 s).
- **In _onTick():**  
  Aus `_cachedParties` und **aktueller Zeit** wird `hasActive` berechnet und daraus `signature` ('running' / 'upcoming_…' / 'none').  
  Bei Signaturänderung:
  ```dart
  if (signature != _lastDisplaySignature && mounted) {
    _lastDisplaySignature = signature;
    // ...
    setState(() {});  // ← löst Rebuild der ganzen Seite aus
  }
  ```
- **Ergebnis:** Jeder Tick kann ein **setState** auslösen. Beim Rebuild läuft der **StreamBuilder-Builder erneut** mit denselben `snapshot.data?.docs`, aber **nowUnix** wird neu berechnet (Zeile 541). Dadurch wird **activeParty** bei abgelaufener Party zu `null`, die Liste wird mit **aktueller Zeit** neu berechnet, das Widget verschwindet zuverlässig.

### party_verwaltung_page.dart

- **Stream:** Ein einziger `StreamBuilder<QuerySnapshot>` (Firestore). Dessen Builder läuft **nur**, wenn der Stream ein **neues Snapshot** liefert.
- **Timer:** Es gibt **keinen** `_secondTickTimer` und **kein** setState, das von einem Timer getriggert wird.
- **_timeStream:**  
  Wird nur **innerhalb** der Karten genutzt:
  ```dart
  timeStream: _timeStream,  // Zeile 826 – nur an SettingsPartyCard übergeben
  ```
  Der **StreamBuilder-Builder**, der `runningParties`/`upcomingParties` berechnet, **hört nicht** auf `_timeStream`. Er wird also **nicht** bei jedem Minuten-Tick neu ausgeführt.
- **Ergebnis:** Die **Gruppierung** (Läuft / Bevorstehend) und damit die Anzeige der Sektionen wird **nur bei neuem Firestore-Snapshot** neu berechnet. Bei reinem Zeitablauf (kein Firestore-Update) läuft der Builder nicht neu → **runningParties** bleibt unverändert → die „Läuft“-Karte verschwindet nicht.

---

## 3. Stream-Daten – Zugriff und Filterung

| Aspekt              | home_dj.dart                         | party_verwaltung_page.dart                    |
|---------------------|--------------------------------------|-----------------------------------------------|
| Firestore-Query     | `parties.where('created_by', isEqualTo: _effectiveDjId!)` | `parties.where('created_by', isEqualTo: user.uid)` |
| Zusätzliche Filter  | Keine (nur lifecycle/finished_at im Code) | Keine (gleiche Logik im Loop)                 |
| Wann neue Daten    | Listener schreibt nur in `_cachedParties` | StreamBuilder baut nur bei neuem Snapshot     |
| Wer nutzt die Daten| Timer + setState → Build mit **aktuellem** nowUnix | Nur StreamBuilder-Builder, **kein** Zeit-Tick |

Beide nutzen dieselbe Collection und ähnliche Filter; die Verwaltung verwendet **keinen** anderen Stream. Die Lücke ist, dass die Verwaltung **keinen Rebuild bei Zeitänderung** auslöst.

---

## 4. Identifikation der Lücke

**Warum verschwindet das Widget in der Verwaltung manchmal nicht?**

- **Nicht** wegen ceil/Abgleich oder anderer Zeit-Basis: Die Bedingungen „läuft“ sind äquivalent (now zwischen Start und Ende).
- **Ursache:**  
  Die **Gruppierung** (runningParties / upcomingParties) wird in party_verwaltung_page **nur** im Builder des **Firestore-StreamBuilders** berechnet. Dieser Builder wird **nur bei neuem Snapshot** aufgerufen.  
  Beim Ablauf der Party-Zeit gibt es **kein** Firestore-Update → **kein** neuer Snapshot → **kein** erneuter Lauf der Gruppierungslogik → **kein** Verschieben der Party von „Läuft“ nach „Beendet“ in der UI.  
  Der Minuten-Timer (`_timeStream`) aktualisiert nur die **Karten-Inhalte** (z. B. Countdown), **nicht** die Entscheidung, in welcher Sektion eine Party steht.

**Kurz:**  
- home_dj: **Timer → setState → Rebuild → nowUnix neu → activeParty neu berechnet → zuverlässige Umschaltung.**  
- party_verwaltung: **Kein Timer-setState für die Liste → Gruppierung hängt nur am Firestore-Snapshot → bei reinem Zeitablauf keine Aktualisierung.**

---

## 5. Fix (Implementierung)

Die Gruppierung in der PartyVerwaltungPage muss bei **Zeit-Ticks** neu laufen. Dafür wird die Berechnung von `runningParties`/`upcomingParties` und die daraus gebaute Liste in einen **StreamBuilder&lt;DateTime&gt;** mit `stream: _timeStream` gepackt. So wird bei jedem Tick von `_timeStream` (z. B. jede Minute) die Gruppierung mit **aktuellem** `DateTime.now()` neu berechnet und die Sektionen (Läuft / Bevorstehend) aktualisieren sich wie auf der DJ-Startseite.
