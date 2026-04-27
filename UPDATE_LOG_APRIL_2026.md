# Update-Log – April 2026 (Etappe A/B – Hausputz)

Kurzüberblick der umgesetzten Schritte (ohne Design- oder DJ-Logik-Änderungen).

## Backend (Cloud Functions)

- **Node.js 20** als Runtime (wie in `functions/package.json` vorgegeben).
- **Secrets (Secret Manager)** statt Legacy-Config für Apple Music und Mass-Verify:
  - `APPLE_KEY_ID`, `APPLE_TEAM_ID`, `APPLE_PRIVATE_KEY`
  - `MASSVERIFY_ADMIN_UID`
- **`firebase-functions` / `firebase-admin`** konservativ angehoben (Deploy erfolgreich).

## Sicherheit & Kontakt (PWA / Server)

- **reCAPTCHA Enterprise** weiterhin aktiv (Landing `enterprise.js`, Backend-Validierung unverändert im Sinne des bestehenden Flows).

## PWA / Hosting

- **Firebase JS SDK** auf der **v11**-CDN-Linie (z. B. **11.0.1**), modulare Imports beibehalten.
- Hosting-Deploy durchgeführt.

## Flutter

- **`flutter pub upgrade`** (Minor/Patch innerhalb der Constraints, u. a. Firebase-Storage/Messaging/Remote Config/App Check).
- Gezielte Major-Bereiche u. a.: **Syncfusion 33.x**, **fl_chart 1.2.0**, **app_links 7.0.0** (mit erfolgreicher Auflösung, keine nötigen Code-Anpassungen in den geprüften Chart-/Link-Pfaden).

## Design & Fachlogik

- **Design-System (Orange/Schwarz)** und **DJ-Namen-/DJ-Logik** wurden im Rahmen der Updates **geprüft** und **bewusst nicht verändert** (nur technische/upstream-Anheben und Backend-Migration).

---

## Abschluss-Check

- **`flutter analyze lib`:** keine **error**-Diagnosen in der aktiven App (`lib/`).
- Gesamtes Repo inkl. **`backup_*`**, **`test/widget_test.dart`:** dort können weiterhin Analyzer-Errors liegen (Archiv/Test-Stub); das ist **unabhängig** vom Pub-Upgrade.

---

## Free-DJ-Gast-Limit & `dj_plan_type` (Sicherheit + Erhalt)

- **Kontext:** Firestore-Regeln erlauben Gästen keinen Lesezugriff mehr auf `users/{uid}` (u. a. kein `planType` vom Client). Damit wäre die zusätzliche Free-DJ-Prüfung in `LimitService.canRequestSong` ohne Party-Feld nicht mehr möglich gewesen.
- **Lösung:** Auf jedem Party-Dokument wird **`dj_plan_type`** persistiert (Quelle: `users.planType` des DJs, Feld `created_by` / `dj_code`). Neue Partys schreiben den Wert bereits beim Anlegen; **bestehende** Partys werden per Cloud Function **`backfillPartyDjPlanType`** (nur Master-Admin, Bearer ID Token) aktualisiert.
- **Limit-Logik (Flutter):**
  - **Stundenlimit:** `WishesPage` zählt Wünsche im **aktuellen Kalenderstunden-Fenster** gegen **`guest_limit_per_hour`** auf der Party (Free-DJ: typisch **1 Wunsch pro Stunde**).
  - **Zusatz für Free-DJ:** `LimitService.canRequestSong` liest nur noch **`parties.dj_plan_type`**. Ist der Wert `free`, gilt zusätzlich das **2-Stunden-Block-Limit** (ein Gast-Wunsch pro Block), unverändert zur Vor-Regel-Logik — **sobald Backfill durchgelaufen ist**.
- **Backfill ausführen (Beispiel):** zuerst Trockenlauf  
  `GET https://us-central1-<PROJECT_ID>.cloudfunctions.net/backfillPartyDjPlanType?dryRun=true`  
  mit Header `Authorization: Bearer <Master-Admin-idToken>`; dann mit `dryRun=false` (oder Query weglassen) schreiben.

---

*Stand: April 2026 – Projektwurzel `UPDATE_LOG_APRIL_2026.md`*
