# Technische Basis: Free-DJ-Status – Analyse & Zusammenfassung

## 1. Identifikation: Woran erkennt das System einen "Free-DJ"?

**Aktuell gibt es keinen expliziten Begriff "Free-DJ" im Code.**  
Ein Nutzer gilt faktisch als **nicht-Premium (Free)**, wenn:

- **`UserModel.isPremiumActive == false`**

Diese Eigenschaft ist ein **Getter** in `lib/models/user_model.dart`:

```dart
bool get isPremiumActive {
  if (isPro) return true;
  final until = trialUntil?.toDate();
  return until != null && until.isAfter(DateTime.now());
}
```

- **Free** = weder `isPro == true` noch ein **aktives Trial** (`trialUntil` in der Zukunft).
- Es wird **nur** aus den Feldern des User-Modells abgeleitet:
  - `isPro` (Firestore: `isPro`)
  - `trialUntil` (Firestore: `trialUntil`)
- Es gibt **kein** separates Feld wie `isFree` oder `plan: 'free'`; Free ist implizit: **nicht Pro und kein aktives Trial**.

**Fazit:** Ein "Free-DJ" ist aktuell **ausschließlich** über `!userModel.isPremiumActive` definiert (bzw. Fehlen von Pro/Trial im UserModel).

---

## 2. Session & State: Wo wird die Information gehalten?

### Zentraler State: UserService

- **Quelle:** `lib/services/user_service.dart`
- **State:** `UserService().currentUser` (Singleton) vom Typ `ValueNotifier<UserModel?>`.
- **Aktualisierung:** Echtzeit-Stream:
  - `FirebaseAuth.instance.authStateChanges()` → bei Login wird `users/{uid}.snapshots()` abonniert.
  - Jede Änderung am User-Dokument in Firestore aktualisiert `currentUser.value`.
- **Start:** `UserService().startUserStream()` in `main.dart` (UserScopeWrapper.initState).
- **Ende:** `UserService().stopUserStream()` beim Logout (z. B. in main_main_page.dart).

### UI-Zugriff

- **UserScope** (InheritedNotifier um `currentUser`) umschließt die ganze App (`UserScopeWrapper` → `DJOgApp`).
- Zugriff in Widgets: `UserScope.userOf(context)` → liefert `UserModel?` und löst Rebuild bei Änderung aus.

### Weitere Stellen (teilweise abweichend / Cache)

| Stelle | Verhalten |
|--------|-----------|
| **ProFeatureGuard** (`lib/services/pro_feature_guard.dart`) | Eigenes **Cache**: `_cachedIsPro`, `_cacheTime`, `_cachedUserId` mit TTL 5 Minuten. Liest bei Bedarf über `ContactRecipientService.checkDjSubscriptionStatus(uid)` aus Firestore. **Aktuell:** Pro-Check ist im Test-Modus deaktiviert (`canUseMusicRecognition` gibt immer `true` zurück). |
| **ContactRecipientService** (`lib/services/contact_recipient_service.dart`) | Liest `users/{djId}` direkt aus Firestore (`isPro`, optional `plan`). **Aktuell:** Im Test-Modus gibt `checkDjSubscriptionStatus` / `isDjPro` immer `true` zurück. |
| **profil_page, home_dj, paywall_view, etc.** | Nutzen überwiegend **UserScope.userOf(context)** bzw. `UserService().currentUser.value` und damit den **zentralen** UserService-State. |

**Fazit:**  
- **Primäre Quelle für Premium/Free in der Session:** UserService (Firestore-Stream) + UserScope in der UI.  
- **Zu beachten:** ProFeatureGuard und ContactRecipientService haben eigene Logik/Cache und sind derzeit im Test-Modus; für ein einheitliches Free-DJ-Limit sollten alle relevanten Checks auf **UserService/UserModel** (z. B. `!userModel.isPremiumActive`) aufsetzen, um lokale Caches und Doppel-Logik zu vermeiden.

---

## 3. Zeitstempel: "Laufender Monat" für Free-DJ-Limits

### Im User-Dokument vorhanden

- **`created_at`** (UserModel: `createdAt` als `Timestamp?`)
  - Wird in `UserModel.fromFirestore` aus `data['created_at']` gelesen.
  - Geeignet als **Erstellungsdatum des Accounts** (z. B. Start des ersten "Monats" für Free).

### Nicht vorhanden

- **Kein** Feld wie `free_since`, `free_period_start`, `billing_cycle_start` o. Ä.
- Es gibt **keine** explizite Speicherung des Startzeitpunkts eines "Free-Status" oder eines rollierenden Monats (z. B. 6.2.–5.3.).

**Fazit:**  
- Für einen "laufenden Monat" (z. B. 6.2. bis 5.3.) existiert **kein** fertiges Feld.  
- **Möglichkeiten für die Umsetzung:**
  1. **Ohne neues Feld:** Monat aus `created_at` ableiten (z. B. Kalendermonat der Registrierung oder rollierender 30-Tage-Zeitraum ab `created_at`).
  2. **Mit neuem Feld:** z. B. `free_period_start` (Timestamp) in `users/{uid}` setzen (z. B. beim ersten Ablauf von Pro/Trial oder bei bewusster Umstellung auf Free-Logik) und den laufenden Monat darauf basierend berechnen.

---

## 4. Wunsch-Tracking: Wie werden Gäste-Wünsche geloggt?

### Wishes-Collection

- **Collection:** `wishes`
- **Relevante Felder** (aus `SongRequest` / Nutzung im Code):
  - **`createdAt`** – Zeitstempel (beim Anlegen: `FieldValue.serverTimestamp()`)
  - **`party_id`** – Zuordnung zur Party
  - **`client_id`** – Gerät/Gast-ID (für Limits/Sperren; wird in wishes_page beim Anlegen gesetzt)
  - **`user_id`** – optional (z. B. eingeloggter User)
  - **`status`** – z. B. `'pending'`, `'played'`, `'rejected'`
  - **`name`**, **`requested_by`**, **`is_dj_wish`** usw.

### Wo werden Wünsche geschrieben?

- **Gast-Wünsche:** z. B. `lib/pages/wishes_page.dart` (`wishes.add(wishData)` mit `createdAt`, `party_id`, `client_id`, …).
- **DJ-Wünsche:** z. B. `lib/offen_page.dart` (`_saveDjWish` → `wishes.add(wishData)` mit `createdAt`, `party_id`, `is_dj_wish: true`).

### Filterung nach Zeit (z. B. 2-Stunden-Blöcke)

- **`createdAt`** ist in Firestore vorhanden und wird im Code mehrfach für Sortierung/Filterung genutzt (z. B. main_main_page, offen_page_backup, SongRequest).
- **Technisch:** Abfragen mit `where('createdAt', isGreaterThanOrEqualTo: startOfBlock)` und `where('createdAt', isLessThan: endOfBlock)` sind möglich.
- **Einschränkung:** Firestore erfordert für Range-Queries in der Regel einen **Composite-Index**, wenn zusätzlich z. B. nach `party_id` oder `dj_id` gefiltert wird. Für reine Zeitblöcke pro Party/DJ müssten die geplanten Abfragen (inkl. 2-Stunden-Intervallen) einmal konkret definiert und ggf. Indizes in der Firebase-Konsole angelegt werden.

**Fazit:**  
- Gäste-Wünsche werden in der **wishes**-Collection mit **`createdAt`**, **`party_id`** und **`client_id`** geloggt.  
- **2-Stunden-Blöcke** sind über **`createdAt`** filterbar; für Kombinationen mit `party_id`/`dj_id` sind passende Firestore-Indizes nötig.

---

## 5. Kurz-Checkliste für die nächsten Steps (Free-DJ-Limits)

| Thema | Aktueller Stand | Für Limits zu klären |
|-------|-----------------|----------------------|
| **Free-DJ erkennen** | `!userModel.isPremiumActive` | Einheitlich über UserService/UserModel nutzen; ProFeatureGuard/ContactRecipientService ggf. anbinden oder umstellen. |
| **Session-State** | UserService + UserScope zentral | Alle Limit-Checks auf `UserScope.userOf(context)` / `UserService().currentUser.value` aufsetzen; Caches (ProFeatureGuard) beachten oder invalidieren. |
| **Laufender Monat** | Nur `created_at` im User-Dokument | Entscheiden: Berechnung aus `created_at` (z. B. Kalender-/Rolling-Monat) oder neues Feld `free_period_start` (oder ähnlich) einführen. |
| **Wunsch-Zählung nach Zeit** | `wishes` mit `createdAt`, `party_id`, `client_id` | Konkrete Queries für 2-Stunden-Blöcke (und ggf. pro Monat) definieren; Firestore-Indizes dafür anlegen. |

Diese technische Basis bildet die Grundlage, um die neuen Free-DJ-Limits (z. B. Wünsche pro laufendem Monat, pro 2-Stunden-Block) präzise umzusetzen.
