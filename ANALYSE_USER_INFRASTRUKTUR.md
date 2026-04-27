# Analyse: Bestehende User-Infrastruktur (vor 2-Tage-Trial-Integration)

## 1. Stream-Check: Echtzeit-Stream auf das Firestore-User-Dokument

**Ergebnis: Es gibt mehrere lokale Streams auf `users/{uid}`, aber keinen zentralen User-Dokument-Stream.**

| Ort | Was wird abonniert | Gelesene Felder |
|-----|--------------------|-----------------|
| **main_main_page.dart** | `users/{uid}.snapshots()` (Listener `_userRoleSubscription`) | `role_id` → ViewRole / Rollenname |
| **main_main_page.dart** (Drawer) | `StreamBuilder` auf `users/{uid}.snapshots()` | `displayName`, `photoURL` (Header-Anzeige) |
| **home_guest_private.dart** | `_userDocSub` auf `users/{uid}.snapshots()` | `loginCount` |
| **home_admin.dart** | `_userDocSub` auf `users/{uid}.snapshots()` | `loginCount` |
| **home_dj.dart** | `StreamBuilder` auf `users/{uid}.snapshots()` | `displayName` (Welcome-Header) |
| **profil_page.dart** | `StreamBuilder` auf `users/{uid}.snapshots()` | **`isPro`, `proUntil`** (Pro-Status-Karte) |

- **auth_service.dart** existiert nicht; Auth läuft über **Firebase Auth** (`StreamBuilder<User?>`, `_authSubscription`).
- **subscription_service.dart** existiert nicht; Abo-Logik liegt in **subscription_sync_service.dart** (RevenueCat ↔ Firestore Sync, kein Stream).

**Fazit:** Ein Echtzeit-Stream auf das User-Dokument existiert an mehreren Stellen, aber jede Stelle nutzt nur die für sie relevanten Felder. **Nirgends wird ein einziger Stream zentral gehalten und app-weit (z. B. per Provider) verteilt.** Für Pro/Trial wäre die naheliegende Stelle die **Profil-Page** (liest bereits isPro/proUntil) sowie ggf. ein zentraler Listener, falls gewünscht.

---

## 2. User-Modell (user_model.dart)

**Vorhandene Felder:**

- `id`, `email`, `displayName`, `roleId`, `admin`
- `createdAt`, `lastLogin`, `loginCount`
- **Pro/Subscription:** `proUntil` (Timestamp?), `isPro` (bool), `lastPaymentProvider` (String)
- `referralCode`

**Nicht vorhanden (für Trial relevant):**

- **trialUsed** (ob User das 2-Tage-Trial schon genutzt hat)
- **trialEndsAt** / **trialUntil** (Ende der Trial-Periode)
- Kein separates Trial-Flag

**Fazit:** Pro-Status wird heute nur über **isPro** und **proUntil** abgebildet. Trial-Logik (einmal pro User, 2 Tage) ist im Modell und in Firestore noch nicht vorgesehen.

---

## 3. Session-Management: Wie der User-Status in der Session gehalten wird

**Ergebnis: Es wird kein globaler State (Provider, Bloc, GetX) für das User-Dokument oder Pro-Status genutzt.**

- **Auth:** Firebase Auth liefert den aktuellen User; in **MainPage** wird `StreamBuilder<User?>` bzw. `_authSubscription` verwendet – keine Firestore-User-Daten dort.
- **Pro-Status / Pro-Features:**
  - **Profil:** Liest **isPro** und **proUntil** direkt per **StreamBuilder** auf `users/{uid}.snapshots()` → UI aktualisiert sich bei Änderungen am Dokument.
  - **ContactRecipientService / ProFeatureGuard:** Machen **einmalige** Firestore-Reads (`get()`) auf `users/{djId}` und prüfen `isPro` / `plan`. Derzeit im **Test-Modus**: geben immer `true` zurück (Pro-Check deaktiviert).
  - **SubscriptionSyncService:** Schreibt nach Kauf/Sync **proUntil** und **isPro** in Firestore; hält keinen eigenen State.

**Fazit:** Änderungen am User-Dokument (z. B. nach Abo-Kauf oder Sync) werden **sofort** nur dort sichtbar, wo bereits ein Stream/StreamBuilder auf dieses Dokument hört (Profil, Drawer, Home-Varianten). Es gibt **keine zentrale Stelle**, die isPro/premiumUntil/trial an die gesamte App weitergibt – und damit auch keine Redundanz durch doppelten globalen User-State.

---

## 4. Zusammenfassung (Kurzliste)

1. **Stream auf User-Dokument:** Ja, mehrfach – aber **lokal pro Screen** (MainPage, Home-Guest, Home-Admin, Home-DJ, Profil). Kein zentraler „User-Doc-Stream“ für die ganze App.
2. **User-Modell:** Enthält **isPro**, **proUntil**, **lastPaymentProvider**. **Keine** Trial-Felder (trialUsed, trialUntil o. ä.).
3. **Session/Pro-Status:** Kein globaler State für User-Dokument oder Pro. Pro-Status kommt aus **Firestore** (StreamBuilder im Profil; einmalige Reads in ContactRecipientService/ProFeatureGuard). Nach Sync/Kauf schreibt **SubscriptionSyncService** nur **proUntil** + **isPro**.
4. **Integration 2-Tage-Trial:** Kann nahtlos an den bestehenden Flow anknüpfen: Firestore-User-Dokument um Trial-Felder erweitern (z. B. **trialUsed**, **trialUntil**), **SubscriptionSyncService** bzw. Kauf-/Trial-Logik diese setzen, bestehende **StreamBuilder** auf `users/{uid}` (v. a. Profil) können die neuen Felder mitlesen. Kein zwingender neuer globaler Provider nötig, um Redundanz zu vermeiden.

---

*Stand: Analyse vor Implementierung des 2-Tage-Trial-Systems.*
