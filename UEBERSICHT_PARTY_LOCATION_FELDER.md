# Übersicht: Location-Felder in der parties-Collection

## 1. Datenquelle: Was liefert _selectedGooglePlace / LocationResult?

**Modell:** `lib/models/location_result.dart`

| Feld          | Typ     | Quelle (Google Place Details) | Beschreibung |
|---------------|---------|--------------------------------|--------------|
| `placeId`     | String  | `place_id`                     | Google Place ID |
| `name`        | String  | `result['name']`               | Name des Orts (z. B. „Mündlich Bar“) |
| `address`     | String  | `result['formatted_address']`  | Vollständige Adresse als **ein** String |
| `latitude`    | double  | `geometry.location.lat`        | Breitengrad |
| `longitude`   | double  | `geometry.location.lng`        | Längengrad |
| `timezoneId`  | String? | Time Zone API                  | Zeitzone (z. B. Europe/Berlin) |

**Aktuell nicht aus der API geholt:**  
- Kein `formatted_address` in Einzelteile zerlegt  
- Keine separaten Felder für Straße, Hausnummer, PLZ, Ort  
- Die API liefert `address_components` (postal_code, locality, route, street_number), wird aber **aktuell nicht angefragt** (nur `fields=name,formatted_address,geometry,place_id`).

**Map-Pin (LocationMapPickerPage):**  
Liefert dasselbe `LocationResult`; `name` = „Ausgewählter Ort“ bzw. `initialLocationName`, `address` = Koordinaten-String oder per Reverse-Geocode – **keine** strukturierten address_components, sofern nicht separat per Geocoding geholt werden.

---

## 2. Speichervorgang: Was wird in parties geschrieben?

**Stelle:** `lib/pages/neue_party_page.dart`, ca. Zeile 1770–1795 (Aufbau von `partyData`).

| Firestore-Feld (parties) | Typ    | Inhalt / Quelle |
|--------------------------|--------|------------------|
| `location_id`            | String?| Nur bei öffentlicher Party + Location aus Dropdown; ID aus `locations`-Collection |
| `location_name`          | String | **Name** des Orts (z. B. „Mündlich Bar“) oder „Vom DJ nicht angegeben“ |
| `location_address`       | String | **Ein langer String** (formatted_address von Google bzw. Adresse der gespeicherten Location) |
| `latitude`               | double?| Koordinaten (Pin oder Google Place) |
| `longitude`              | double?| Koordinaten (Pin oder Google Place) |
| `timezone_id`             | String | Zeitzone (z. B. Europe/Berlin) |
| `place_id`                | String?| Google Place ID (nur bei Google-Suche/Karte) |
| `show_location_publicly`  | bool   | Sichtbarkeit der Location |

**Aktuell nicht in parties gespeichert:**  
- Kein `location_zip` (PLZ)  
- Kein `location_city` (Ort)  
- Kein `location_street` (Straße + Hausnummer)

Die Adresse existiert nur als **ein** String: `location_address`. Der **Name** (z. B. „Mündlich Bar“) wird **separat** in `location_name` gespeichert – nicht nur als Teil der Adresse.

---

## 3. Daten-Lücken

- **„Mündlich Bar“:**  
  - `location_name` = „Mündlich Bar“ (eigenes Feld).  
  - `location_address` = z. B. „Musterstraße 1, 10115 Berlin, Deutschland“ (formatted_address).  
  Name und Adresse sind also getrennt; die Adresse ist aber nur als **ein** String vorhanden.

- **Anzeige „Name, PLZ Ort“:**  
  Ohne eigene Felder für PLZ und Ort müsste man `location_address` parsen oder die Google API um `address_components` erweitern und **zusätzlich** `location_zip`, `location_city` (und optional `location_street`) in Firestore speichern.

---

## 4. Vorschlag: PLZ und Ort separat speichern

1. **Google Place Details:**  
   `address_components` anfordern (`fields=...,address_components`), auswerten:
   - `postal_code` → PLZ  
   - `locality` (oder `administrative_area_level_2` als Fallback) → Ort  
   - `route` + `street_number` → Straße (optional)

2. **LocationResult erweitern:**  
   Optionale Felder z. B. `postalCode`, `city`, `street` (String?).

3. **neue_party_page:**  
   Beim Schreiben von `partyData`:
   - `location_zip` = aus LocationResult (bzw. gespeicherter Location, falls später auch dort gepflegt).
   - `location_city` = analog.
   - `location_street` = optional.

4. **Party-Card / Lesepfade:**  
   In `party_verwaltung_page.dart` und `home_dj.dart` die neuen Felder aus dem Party-Dokument lesen und an die Card übergeben; in der Card Anzeige z. B. „Name · PLZ Ort“ oder „Name, PLZ Ort“.

---

## 5. Kurz: Location-Felder in parties (Stand nach Implementierung)

| Feld                     | Vorhanden? | Inhalt |
|--------------------------|------------|--------|
| location_id              | Ja         | Verknüpfung zu locations-Dokument |
| location_name            | Ja         | Ortsname (z. B. „Mündlich Bar“) |
| location_address         | Ja         | Volladresse als **ein** String |
| location_zip             | **Ja**     | PLZ aus Google address_components (postal_code) |
| location_city            | **Ja**     | Ort aus Google address_components (locality) |
| location_street          | **Ja**     | Straße + Hausnummer (route + street_number) |
| latitude / longitude     | Ja         | Koordinaten |
| timezone_id              | Ja         | Zeitzone |
| place_id                 | Ja (opt.)  | Google Place ID |
| show_location_publicly   | Ja         | Sichtbarkeit |

**Umsetzung:**  
- `LocationResult` hat optionale Felder `postalCode`, `city`, `street`; Google Place Details werden mit `address_components` geholt und geparst.  
- `neue_party_page` schreibt `location_zip`, `location_city`, `location_street` ins `partyData`, wenn sie vom Google-Result gesetzt sind.  
- Party-Card (`SettingsPartyCard`) erhält optional `locationZip` und `locationCity`; Anzeige: **„Name · PLZ Ort“** (z. B. „Mündlich Bar · 10115 Berlin“), falls PLZ/Ort vorhanden.
