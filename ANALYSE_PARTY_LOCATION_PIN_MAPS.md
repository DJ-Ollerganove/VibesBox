# Analyse: Party erstellen mit Location per Pin – Maps-Link & Berlin

## 1. Location-Auswahl: Wo wird der Pin-Drop verarbeitet?

- **Karten-UI & Pin-Drop:** `lib/pages/location_map_picker_page.dart`
  - `_onMapTap(LatLng position)` (ca. Zeile 165): Reagiert auf Tipp auf die Karte, setzt `_selectedPosition`.
  - Marker ist **draggable**; `onDragEnd` (ca. 242) aktualisiert `_selectedPosition` und lädt Zeitzone.
  - Bestätigung: `_confirmSelection()` (ca. 192) baut ein `LocationResult` mit `latitude`/`longitude` aus `_selectedPosition` und gibt es per `Navigator.pop(context, locationResult)` zurück.

- **Aufruf der Karte:** `lib/pages/neue_party_page.dart`
  - Der Button „Auf Karte wählen“ (Icons.map) steht nur bei **„Anderen Ort suchen“** (`_locationSelectionMode == 'search'`, ca. 2488).
  - Nach Rückkehr von der Karte (ca. 2530–2566): `result` wird in `_selectedGooglePlace` gespeichert; `_locationNameController` und `_currentTimezoneId` werden gesetzt. Es wird **nicht** `_locationSelectionMode` gesetzt – der Modus ist bereits `'search'`, weil der Karten-Button nur in diesem Modus sichtbar ist.

**Fazit:** Pin-Drop wird in **`location_map_picker_page.dart`** verarbeitet; die Rückgabe wird in **`neue_party_page.dart`** in `_selectedGooglePlace` (Typ `LocationResult`) übernommen.

---

## 2. Daten-Mapping: Kommen latitude/longitude ins Party-Dokument?

- **Wo die Variablen gesetzt werden:** `neue_party_page.dart` ca. 1547–1594.
  - Wenn `_locationSelectionMode == 'dropdown'` und `_selectedLocationModel != null`: Koordinaten aus `_selectedLocationModel`.
  - Wenn `_locationSelectionMode == 'search'` und **`_selectedGooglePlace != null`**:  
    `latitude = _selectedGooglePlace!.latitude`, `longitude = _selectedGooglePlace!.longitude` (ca. 1576–1578).
  - Sonst (z. B. „Mein aktueller Standort“): `latitude = null`, `longitude = null`.

- **Schreiben ins Party-Objekt:** Ca. 1782–1786:
  - `if (latitude != null && latitude != 0.0) partyData['latitude'] = latitude;`
  - `if (longitude != null && longitude != 0.0) partyData['longitude'] = longitude;`

- **Persistenz:** `partyData` wird per `FirebaseFirestore.instance.collection('parties').add(partyData)` (ca. 1807–1809) gespeichert.

**Fazit:** Beim Erstellen einer Party mit Ort „Auf Karte wählen“ (Pin-Drop) werden **latitude** und **longitude** aus `_selectedGooglePlace` in `partyData` geschrieben und landen im Firestore-Party-Dokument – sofern der Modus `'search'` ist (was bei Nutzung des Karten-Buttons der Fall ist).

---

## 3. Maps-Link-Logik: Koordinaten vs. Adressname

- **Stelle:** `lib/settings_party_card_widget.dart`, Methode `_openGoogleMaps()` (ca. 907–982).

- **Ablauf:**
  1. **Zuerst Koordinaten:**  
     Wenn `widget.latitude` und `widget.longitude` gesetzt und ungleich 0.0 sind → Links mit Koordinaten:
     - `geo:${latitude},${longitude}?q=...`
     - Fallback z. B. `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}` (Android).
  2. **Fallback Adressname:**  
     `else if (widget.locationName != null && widget.locationName!.isNotEmpty)` → Suche nach Ort mit `query=$encodedName` (z. B. Google Maps Such-URL mit Namen).

**Fazit:** Der Code **prüft zuerst explizit auf Koordinaten**; nur wenn diese fehlen oder 0 sind, wird der **Adress-/Ortsname** für den Maps-Link genutzt. Wenn die Karte „Berlin“ öffnet, obwohl ein anderer Pin gesetzt wurde, liegen entweder keine Koordinaten im Party-Dokument an oder sie kommen beim Auslesen nicht korrekt im Widget an (z. B. Typ beim Lesen aus Firestore).

---

## 4. Berlin-Fallback: Warum landet der User in Berlin?

- **Initiale Kartenposition (ohne übergebene Koordinaten):**  
  `lib/pages/location_map_picker_page.dart` (ca. 39–42):  
  Wenn `initialLatitude`/`initialLongitude` nicht übergeben werden, wird  
  `_selectedPosition = const LatLng(52.5200, 13.4050)` (Berlin) gesetzt.  
  Wer also die Karte öffnet und **ohne Verschieben des Pins** bestätigt, bekommt bewusst Berlin als Ort.

- **Party-Cleanup (fehlende Koordinaten werden überschrieben):**  
  `lib/services/party_cleanup_service.dart` (ca. 36–82):
  - `defaultLatitude = 52.5200`, `defaultLongitude = 13.4050` (Berlin).
  - Wenn `latitude == null || latitude == 0.0` → Party wird mit `latitude: defaultLatitude` aktualisiert.
  - Wenn `longitude == null || longitude == 0.0` → Party wird mit `longitude: defaultLongitude` aktualisiert.

**Fazit:** „Berlin“ kommt entweder von der **Standard-Startposition** der Karte (Pin nicht bewegt) oder vom **Party-Cleanup**, der fehlende oder 0-Koordinaten durch Berlin ersetzt. Wenn der Nutzer einen anderen Pin gesetzt hat, die Koordinaten aber im Firestore nicht ankommen oder beim Lesen verloren gehen, setzt der Cleanup später Berlin – dann erscheint Berlin auch im Maps-Link.

---

## 5. Warum die Pin-Koordinaten nicht im Maps-Link ankommen können

Mögliche Ursachen:

1. **Koordinaten werden beim Lesen aus Firestore nicht korrekt übernommen**  
   Firestore liefert Zahlen als `num` (z. B. `int` oder `double`). Ein festes `data['latitude'] as double?` kann bei `int` zu Laufzeitfehlern oder falscher Verarbeitung führen. **Empfehlung:** überall `(data['latitude'] as num?)?.toDouble()` (und analog für `longitude`) verwenden, wo Partydaten aus Firestore gelesen werden (z. B. Party-Verwaltung, Home-DJ, Edit-Dialog).

2. **Party-Cleanup überschreibt fehlende Werte**  
   Wenn eine Party einmal ohne oder mit 0-Koordinaten gespeichert wurde (z. B. alter Pfad, frühere Version), schreibt der Cleanup Berlin in `latitude`/`longitude`. Danach zeigt der Maps-Link Berlin, auch wenn der User später nur die Anzeige/Karte mit anderem Pin kennt.

3. **Pin nicht bewegt**  
   Wenn die Karte mit Berlin-Start geöffnet und sofort bestätigt wird, ist das gespeicherte Ergebnis bewusst Berlin.

---

## 6. Kurzüberblick

| Thema | Datei / Stelle |
|-------|----------------|
| Pin-Drop verarbeiten | `location_map_picker_page.dart`: `_onMapTap`, draggable Marker, `_confirmSelection` → `LocationResult` |
| Aufruf Karte / Speicherung Ergebnis | `neue_party_page.dart`: Karten-Button nur bei `_locationSelectionMode == 'search'`, Ergebnis in `_selectedGooglePlace` |
| latitude/longitude ins Party-Dokument | `neue_party_page.dart`: aus `_selectedGooglePlace` in `partyData`, dann `collection('parties').add(partyData)` |
| Google-Maps-Link (Koordinaten vs. Name) | `settings_party_card_widget.dart`: `_openGoogleMaps()` – zuerst Koordinaten, sonst Adressname |
| Berlin Standard-Karte | `location_map_picker_page.dart`: `LatLng(52.5200, 13.4050)` wenn keine initialen Koordinaten |
| Berlin bei fehlenden Daten | `party_cleanup_service.dart`: `defaultLatitude`/`defaultLongitude` → Update bei null/0 |

Empfohlene Maßnahme: Beim Auslesen von Partydaten aus Firestore **latitude/longitude** einheitlich mit `(data['...'] as num?)?.toDouble()` sichern, damit Koordinaten aus dem Pin-Drop zuverlässig bis in den Maps-Link durchgereicht werden.
