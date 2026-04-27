# Security Audit (App-only)

Stand: Automatischer Audit und Umsetzung nur im `lib/`-Bereich (Flutter App, ohne `public/` PWA-Dateien).

## 1) Audit: Eingabefelder (TextField/TextFormField)

Gefundene UI-Dateien mit freien Texteingaben:

- `lib/pages/login_page.dart`
- `lib/pages/wishes_page.dart`
- `lib/widgets/wishes_form_widget.dart`
- `lib/pages/manual_wish_page.dart`
- `lib/pages/profil_page.dart`
- `lib/pages/profile/widgets/profile_edit_dialogs.dart`
- `lib/pages/neue_party_page.dart`
- `lib/settings_party_edit_dialog.dart`
- `lib/pages/benutzer_verwaltung_page.dart`
- `lib/pages/home/home_admin.dart`
- `lib/widgets/home_cells/global_announcement_card.dart`
- `lib/pages/social_media_page.dart`
- `lib/widgets/party_check_in_widget.dart`
- `lib/pages/deine_wunsche_page.dart`
- `lib/offen_page.dart`
- `lib/main_main_page.dart`
- `lib/widgets/mandatory_profile_dialog.dart`
- `lib/pages/todo_page.dart`

## 2) Audit: Firestore-Schreibstellen (add/set/update)

Relevante App-Schreibpfade (Auszug nach Suche in `lib/`):

- Gäste-/Wunschpfade: `lib/pages/wishes_page.dart`, `lib/pages/manual_wish_page.dart`, `lib/offen_page.dart`
- Profil/User: `lib/pages/login_page.dart`, `lib/pages/profile/widgets/profile_edit_dialogs.dart`, `lib/services/user_service.dart`
- Party/DJ-Session: `lib/services/active_party_service.dart`
- Wunsch-Management-Service: `lib/services/wish_management_service.dart`
- Weitere App-Updates/Flags: `lib/main_main_page.dart`, `lib/services/global_announcement_popup_service.dart`, `lib/services/referral_service.dart`

## 3) Implementierte Absicherung

Neu eingefuehrt:

- `lib/helpers/security_helper.dart`
  - `SecurityHelper.sanitize(String?)`
  - Entfernt HTML/SVG/Script-Tags
  - Entfernt/neutralisiert u. a. `javascript:`, `onerror`, `onload`, `eval(`, `iframe/script` Muster
  - `trim()` + Null-Handling (`null -> ''`)
  - Rekursive Map/List-Bereinigung via `sanitizeDynamic` / `sanitizeMap`

Rueckwaertskompatibel verdrahtet:

- `lib/utils/sanitize.dart`
  - `sanitizeInput` und `sanitizeEmail` delegieren zentral an `SecurityHelper.sanitize`

Direkt abgesicherte Schreibpfade:

- `lib/services/wish_management_service.dart`
  - Sanitize vor `update`/Batch-`update`
- `lib/services/active_party_service.dart`
  - Sanitize vor `add` und `update` in `music_history`
- `lib/services/user_service.dart`
  - Sanitize vor `update` in `deactivateAccount`
- `lib/pages/wishes_page.dart`
  - Sanitizing der User-Inputs (`title`, `artist`, `greeting`, `name`)
  - Sanitize vor `add`/`update` auf `wishes`
- `lib/pages/manual_wish_page.dart`
  - Sanitizing der User-Inputs
  - Sanitize vor `add` auf `wishes`
- `lib/offen_page.dart`
  - Sanitizing bei manuellen DJ-Wuenschen
  - Sanitize vor `add` auf `wishes`

## 4) Zweiter, umfassender Lauf (zusaetzlich abgesichert)

In diesem Lauf wurden weitere freie Texteingaben plus zugehoerige Firestore-Schreibpfade explizit gehaertet:

- `lib/pages/social_media_page.dart`
  - URL-Eingaben mit `SecurityHelper.sanitize(..., maxLength: 300)` in der Eingabe (`onChanged`)
  - Firestore `set/update` ueber `SecurityHelper.sanitizeMap(...)`
- `lib/pages/neue_party_page.dart`
  - Lokale Sanitizer-Logik auf zentralen `SecurityHelper` umgestellt
  - Party-/Location-Felder (Name/Adresse/Stadt/Strasse/PLZ) mit maxLength beim Speichern
  - Firestore `add/update` ueber `SecurityHelper.sanitizeMap(...)`
- `lib/settings_party_edit_dialog.dart`
  - Partyname-Feld mit `maxLength`
  - Party-Update in Firestore ueber `SecurityHelper.sanitizeMap(...)`
- `lib/pages/benutzer_verwaltung_page.dart`
  - Admin-Updates/History-Entries vor Firestore ueber `SecurityHelper.sanitizeMap(...)`
- `lib/widgets/home_cells/global_announcement_card.dart`
  - Betreff/Nachricht in `onChanged` sanitisiert (`maxLength` 120/500)
  - Firestore `add/update` ueber `SecurityHelper.sanitizeMap(...)`
- `lib/pages/profile/widgets/profile_edit_dialogs.dart`
  - DJ-/RealName/Telefon/Email-Felder mit `maxLength`
  - Relevante `set/update/batch.update`-Writes ueber `SecurityHelper.sanitizeMap(...)`
- `lib/pages/login_page.dart`
  - Email/Name-Felder mit `maxLength` + sanitisiertes `onChanged`
  - Nutzer-`set`/Login-`set` ueber `SecurityHelper.sanitizeMap(...)`
- `lib/pages/profil_page.dart`
  - Alternative-Email/Profil-Updates ueber `SecurityHelper.sanitizeMap(...)`
  - Realname-Update mit zentralem Sanitizer + maxLength
- `lib/widgets/wishes_form_widget.dart`
  - Artist/Titel/Name/Gruss bereits am Entry-Point (`onChanged`) sanitisiert
  - Zusaetzliche `maxLength`-Grenzen (100/100/50/160)
- `lib/pages/deine_wunsche_page.dart`
  - Gruss-Bearbeitung im Dialog (`TextField`) mit `onChanged`-Sanitizer
  - Firestore-`update` ueber `SecurityHelper.sanitizeMap(...)`
- `lib/widgets/mandatory_profile_dialog.dart`
  - Realname-Feld mit `maxLength` + `onChanged`-Sanitizer
  - Firestore-`update` mit sanitisierten Werten
- `lib/pages/todo_page.dart`
  - Neues To-do-Feld mit `maxLength: 500` + `onChanged`-Sanitizer
  - Firestore `add/update` ueber sanitisierte Maps
- `lib/pages/home/home_admin.dart`
  - Admin-Settings (`admin_config`, `party_settings`, `status_logs`, PDF-Footer) ueber `SecurityHelper.sanitizeMap(...)`
- `lib/pages/wishes_page.dart`
  - Zusaetzlicher Firestore-`update`-Pfad (`browser_language`) ueber `SecurityHelper.sanitizeMap(...)`
- `lib/helpers/security_helper.dart`
  - Erweiterung um optionales `maxLength` in `sanitize(...)`
  - Feldbasierte Standardlimits (`name`, `title`, `description`, `message`, `url`, etc.) in `sanitizeMap(...)`

## 5) Hinweis zu Date-/Time-Pickern

Date-/Time-Picker wurden nicht durch Text-Sanitizer geleitet (wie gefordert), da sie keine freien Strings zulassen.
