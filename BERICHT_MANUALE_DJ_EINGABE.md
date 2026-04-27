# Analyse-Bericht: Manuelle Song-Eingabe durch den DJ

## 1. Funktions-Check (Suche & Validierung)

### Existierende Services und Methoden

| Service | Datei | Relevante Methoden |
|--------|-------|---------------------|
| **DuplicateCheckService** | `lib/services/duplicate_check_service.dart` | `checkIfSongWasPlayed(title, artist, partyId)` – prüft History + gespielte Wünsche<br>`checkIfSongInOpenWishes(title, artist, partyId)` – prüft offene Wunschliste<br>`ensurePartySettingsLoaded()` – lädt duplicate_threshold & ignored_keywords |
| **SpotifyService** | `lib/services/spotify_service.dart` | `SpotifyService.searchTracks(query, {searchType: 'track'})` – Spotify-Track-Suche (Cloud Function)<br>Alternativ: `lib/spotify_service.dart` mit `SpotifyService.instance.search(q, type)` (SpotifySearchResult mit artists/tracks) |
| **SpotifyService** (alternativ) | `lib/spotify_service.dart` | `searchTracks(query)` – gibt `List<SpotifyTrack>` zurück |
| **SpotifyService** (Cloud) | `lib/services/spotify_service.dart` | `SpotifyService.instance.search(q, type)` – verwendet `geocoding`/Cloud Function |
| **SpotifyService** (places) | `lib/services/google_places_service.dart` | (nicht relevant für Songs) |

### Dubletten-Prüfung (bereits in offen_page.dart integriert)

In `offen_page.dart` (Zeilen 319–325) wird vor dem Speichern eines DJ-Wunsches geprüft:

```dart
final inHistory = await DuplicateCheckService.checkIfSongWasPlayed(title, artist, ActivePartyService.currentPartyId!);
final inOpenWishes = await DuplicateCheckService.checkIfSongInOpenWishes(title, artist, ActivePartyService.currentPartyId!);
if (inHistory || inOpenWishes) {
  final force = await _showDuplicateInfoDialog(inHistory, inOpenWishes);
  if (force != true || !mounted) return;
}
```

**Empfehlung:** Diese Logik kann 1:1 für die manuelle DJ-Eingabe übernommen werden.

---

## 2. UI-Integration

### Plus-Icon in der Offen-Seite

| Aspekt | Details |
|--------|---------|
| **Ort** | `lib/dj_vibesbox_page.dart` Zeilen 153–158 |
| **Icon** | `Icons.add_circle_outline` |
| **Aktueller Zustand** | `onPressed: null` – **deaktiviert** |
| **Tooltip** | `'Wunsch hinzufügen (später)'` |
| **Verknüpfung** | Der `OffenPage` implementiert `openDjWishDialog()` (Mixin), wird aber **nicht** vom Plus-Icon aufgerufen – das Icon hat keine Aktion |

### Existierender DJ-Wunsch-Dialog (Spotify-Suche)

In `offen_page.dart`:

- `_openDjWishDialog()` – öffnet `_showSpotifySearchDialog()`, speichert danach mit `_saveDjWish()`
- `_showSpotifySearchDialog()` – `AlertDialog` mit `TextField`, Spotify-Suche, `ListView` mit Tracks
- Kein Dialog für manuelle Eingabe (Interpret, Titel, Gruß)

### Geeignete Dialoge/BottomSheets zum Adaptieren

| Widget | Datei | Beschreibung |
|--------|-------|--------------|
| **WishesFormWidget** | `lib/widgets/wishes_form_widget.dart` | Gast-Formular mit Interpret, Titel, Name, Gruß – Spotify-Suche integriert, für Gäste gedacht |
| **Spotify-Such-Dialog** | `offen_page.dart` `_showSpotifySearchDialog()` | `AlertDialog` mit Suchfeld + Ergebnisliste – nur Spotify, keine manuellen Felder |
| **_showDuplicateInfoDialog** | `offen_page.dart` | `AlertDialog` mit dunklem Design (0xFF1E1E1E), oranger Akzent |
| **BottomSheet/Dialog-Stil** | Diverse (z. B. `location_map_picker_page`, `neue_party_page` Dialoge) | Dunkles Design, `UIConstants.appOrange` für Buttons |

**Empfehlung:** Neuen Dialog anlegen (z. B. `ManualDjWishDialog`) mit:

- TextFields: Interpret, Titel, Gruß (optional)
- Optional: Spotify-Suche als Unterstützung (wie in WishesFormWidget)
- Styling analog zu `_showSpotifySearchDialog()` oder `_showDuplicateInfoDialog`

---

## 3. Daten-Struktur & l10n

### Firestore-Wish-Struktur (identisch zu Gast-Wünschen)

Basierend auf `offen_page.dart` `_saveDjWish()` (Zeilen 362–464) und `lib/models/song_request.dart`:

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `name` | String | Bei DJ-Wünschen: `''` |
| `title` | String | Songtitel (Pflicht) |
| `artist` | String | Interpret (Pflicht) |
| `status` | String | `'pending'` |
| `createdAt` | Timestamp | `FieldValue.serverTimestamp()` |
| `duplicate_count` | int | `0` |
| `requested_by` | List | `[]` |
| `greetings` | List | `[]` oder `[{'name':'','greeting':'…'}]` bei Gruß |
| `is_duplicate` | bool | `false` |
| `is_registered_user` | bool | `true` |
| `is_registered_users` | Map | `{}` |
| `client_id` | String | `FirebaseAuth.instance.currentUser?.uid ?? 'dj'` |
| `party_id` | String | `ActivePartyService.currentPartyId!` |
| `isSeen` | bool | `false` |
| `is_dj_wish` | bool | `true` |
| `spotify_id` | String? | Optional |
| `duration_ms` | int? | Optional |
| `genres` | List? | Optional |
| `greeting` | String? | Einzelner Gruß (falls nicht in greetings) |

Für manuelle Eingabe ohne Spotify: `spotify_id`, `duration_ms`, `genres` weglassen. `greeting` kann ein Textfeld „Gruß“ füllen (z. B. in `requested_by` oder als `greeting`/`greetings`).

### l10n: „Manuell vom DJ“ / „add_manual_wish“

| Sprache | Datei | Status |
|---------|-------|--------|
| **Deutsch** | `lib/l10n/app_localizations_de.dart` | **add_manual_wish fehlt** |
| Englisch | `lib/l10n/app_localizations_en.dart` | `'add_manual_wish': 'Add manual wish'` |
| Französisch | `lib/l10n/app_localizations_fr.dart` | `'add_manual_wish': 'Ajouter un souhait manuel'` |
| Spanisch | `lib/l10n/app_localizations_es.dart` | vorhanden |
| Weitere | pt, tr, zh, ru | vorhanden |

**Hinweis:** Es gibt keine `.arb`-Dateien; Übersetzungen stehen direkt in den Dart-Dateien unter `lib/l10n/`.

**Für die Implementierung in Deutsch hinzufügen:**

```dart
'add_manual_wish': 'Wunsch manuell hinzufügen',
```

Optional separat für die Anzeige auf der Wish-Card:

```dart
'manual_by_dj': 'Manuell vom DJ',
```

(Aktuell zeigt die WishCard bei DJ-Wünschen nur das `Icons.headset_mic`-Icon, keinen Text „Manuell vom DJ“ – bei leerem `name`/`requested_by` bleibt der Absender-Bereich leer.)

---

## 4. Ergebnis: Wiederverwendbare Dateien und Funktionen

### Direkt verknüpfbar (Redundanz vermeiden)

| Komponente | Verwendung |
|------------|------------|
| `DuplicateCheckService.checkIfSongWasPlayed()` | Dubletten-Check in History vor Speichern |
| `DuplicateCheckService.checkIfSongInOpenWishes()` | Dubletten-Check in offener Liste vor Speichern |
| `DuplicateCheckService.ensurePartySettingsLoaded()` | Bereits in `offen_page.initState()` – kein weiterer Aufruf nötig |
| `offen_page._saveDjWish(title, artist, {...})` | Speicherlogik – nur Parameter anpassen (z. B. `greeting` hinzufügen, optionale Spotify-Felder) |
| `offen_page._showDuplicateInfoDialog()` | Dialog bei Duplikat – kann übernommen werden |
| `offen_page.openDjWishDialog()` | Kann erweitert werden: entweder Spotify-Dialog ODER manueller Dialog (z. B. per Auswahl) |
| `SpotifyService.searchTracks(q)` | Optional für manuelle Eingabe mit Spotify-Vorschlägen |
| `WishManagementService.getWishesStream()` | Keine Änderung – manuelle Wünsche erscheinen wie andere pending-Wünsche |
| `WishCard` + `is_dj_wish` | Bereits `Icons.headset_mic` bei DJ-Wünschen |

### Noch zu implementieren

| Baustein | Beschreibung |
|----------|--------------|
| **ManualDjWishDialog** | Dialog/BottomSheet mit Feldern Interpret, Titel, Gruß (optional) |
| **Plus-Icon Aktivierung** | `dj_vibesbox_page.dart` Zeile 157: `onPressed: null` → z. B. `widget.offenPageKey.currentState?.openDjWishDialog()` oder Aufruf des manuellen Dialogs |
| **l10n DE** | `add_manual_wish` in `app_localizations_de.dart` ergänzen |
| **_saveDjWish erweitern** | Optionaler Parameter `greeting` für Gruß-Text |

### Architektur-Hinweis

`OffenPage` besitzt einen `GlobalKey<OffenPageState>` (`offenPageKey`). Die Plus-Icon-Aktion in `DjVibesBoxPage` kann so aufgerufen werden:

```dart
onPressed: hasActiveParty
  ? () => widget.offenPageKey.currentState?.openDjWishDialog()
  : null,
```

`openDjWishDialog()` kann intern wählen zwischen:

- Bestehender Spotify-Such-Dialog, oder
- Neuem manuellem Dialog (Interpret, Titel, Gruß).

---

*Bericht erstellt am 15.03.2025*
