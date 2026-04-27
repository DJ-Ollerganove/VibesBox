# Identifikations-Datenstrukturen - Übersicht

## 1. Collection: `guest_fingerprints`

### Zweck
Mapping-Tabelle zwischen Hardware-Fingerprint (Hash) und `client_id` für persistente Gast-Identifikation.

### Dokument-Struktur

**Document-ID:** `fingerprint` (Hash-String, z.B. `"a3f5b2c1"`)

**Felder:**

```json
{
  "client_id": "guest_fp_a3f5b2c1_1704067200000_abc123",
  "fingerprint": "a3f5b2c1",
  "created_at": Timestamp,
  "last_seen": Timestamp
}
```

### Beispiel-Dokument

```json
{
  "client_id": "guest_fp_a3f5b2c1_1704067200000_abc123",
  "fingerprint": "a3f5b2c1",
  "created_at": {
    "_seconds": 1704067200,
    "_nanoseconds": 0
  },
  "last_seen": {
    "_seconds": 1704067800,
    "_nanoseconds": 0
  }
}
```

### Feld-Beschreibung

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `client_id` | String | Eindeutige Client-ID (Format: `guest_fp_{fingerprint}_{timestamp}_{uuid}`) |
| `fingerprint` | String | Hardware-Fingerprint-Hash (nur Hash, keine sensiblen Daten!) |
| `created_at` | Timestamp | Erstellungszeitpunkt des Mappings |
| `last_seen` | Timestamp | Letzter Zugriff (wird bei jedem Login aktualisiert) |

---

## 2. Collection: `wishes`

### Zweck
Speichert alle Musikwünsche von Gästen.

### Dokument-Struktur

**Document-ID:** Auto-generiert (Firestore)

**Felder (nach Fix):**

```json
{
  "name": "Max Mustermann",
  "title": "Song Titel",
  "artist": "Künstler Name",
  "status": "pending",
  "createdAt": Timestamp,
  "duplicate_count": 0,
  "requested_by": ["Max Mustermann"],
  "greetings": [{"name": "Max Mustermann", "greeting": "Hallo DJ!"}],
  "is_duplicate": false,
  "is_registered_user": false,
  "is_registered_users": {"Max Mustermann": false},
  "client_id": "guest_fp_a3f5b2c1_1704067200000_abc123",  // ✅ NEU
  "party_id": "cVPlhrPuXVBRyGyuNcDh",
  "party_code": "ABC123",
  "spotify_id": "4iV5W9uYEdYUVa79Axb7Rh",
  "duration_ms": 257360,
  "genres": ["pop", "rock"]
}
```

### Beispiel-Dokument (Neuer Wunsch)

```json
{
  "name": "Max Mustermann",
  "title": "Die kleine Kneipe",
  "artist": "Peter Alexander",
  "status": "pending",
  "createdAt": {
    "_seconds": 1704067200,
    "_nanoseconds": 0
  },
  "duplicate_count": 0,
  "requested_by": ["Max Mustermann"],
  "greetings": [],
  "is_duplicate": false,
  "is_registered_user": false,
  "is_registered_users": {
    "Max Mustermann": false
  },
  "client_id": "guest_fp_a3f5b2c1_1704067200000_abc123",
  "party_id": "cVPlhrPuXVBRyGyuNcDh",
  "party_code": "ABC123"
}
```

### Beispiel-Dokument (Duplikat)

```json
{
  "name": "Anna Schmidt",
  "title": "Die kleine Kneipe",
  "artist": "Peter Alexander",
  "status": "pending",
  "createdAt": {
    "_seconds": 1704067300,
    "_nanoseconds": 0
  },
  "is_duplicate": true,
  "original_wish_id": "hU0LgzN2sVwFrwcEg9QC",
  "is_registered_user": false,
  "client_id": "guest_fp_x9k2m4p7_1704067300000_def456",  // ✅ NEU
  "party_id": "cVPlhrPuXVBRyGyuNcDh",
  "party_code": "ABC123"
}
```

### Feld-Beschreibung (Identifikation)

| Feld | Typ | Beschreibung | Verknüpfung |
|------|-----|--------------|-------------|
| `client_id` | String | Eindeutige Client-ID des Gasts | ✅ Entspricht `client_id` in `guest_fingerprints` |
| `name` | String | Anzeigename des Gasts | - |
| `party_id` | String | Lange Party-ID (Dokument-ID) | - |
| `party_code` | String | 6-stelliger Party-Code | - |

**WICHTIG:** Die `client_id` im Wunsch entspricht **exakt** dem Feld `client_id` in `guest_fingerprints`!

---

## 3. Collection: `blocked_guests`

### Zweck
Speichert gesperrte Gäste (Blacklist).

### Dokument-Struktur

**Document-ID:** `client_id` (wenn vorhanden) oder `name` (Fallback)

**Felder:**

```json
{
  "block_status": "temporary" | "permanent",
  "blocked_at": Timestamp,
  "blocked_by": "dj@example.com",
  "blocked_by_dj": "dj@example.com",
  "name": "Max Mustermann",
  "client_id": "guest_fp_a3f5b2c1_1704067200000_abc123",  // ✅ WICHTIG
  "user_id": "firebase_user_uid",  // Optional (nur bei eingeloggten Usern)
  "party_id": "cVPlhrPuXVBRyGyuNcDh",
  "party_code": "ABC123",
  "blocked_until": Timestamp  // Nur bei temporary
}
```

### Beispiel-Dokument (Temporäre Sperre)

```json
{
  "block_status": "temporary",
  "blocked_at": {
    "_seconds": 1704067200,
    "_nanoseconds": 0
  },
  "blocked_by": "dj@example.com",
  "blocked_by_dj": "dj@example.com",
  "name": "Max Mustermann",
  "client_id": "guest_fp_a3f5b2c1_1704067200000_abc123",
  "party_id": "cVPlhrPuXVBRyGyuNcDh",
  "party_code": "ABC123",
  "blocked_until": {
    "_seconds": 1704070800,
    "_nanoseconds": 0
  }
}
```

### Beispiel-Dokument (Dauerhafte Sperre)

```json
{
  "block_status": "permanent",
  "blocked_at": {
    "_seconds": 1704067200,
    "_nanoseconds": 0
  },
  "blocked_by": "dj@example.com",
  "blocked_by_dj": "dj@example.com",
  "name": "Max Mustermann",
  "client_id": "guest_fp_a3f5b2c1_1704067200000_abc123",
  "party_id": "cVPlhrPuXVBRyGyuNcDh",
  "party_code": "ABC123"
}
```

### Feld-Beschreibung

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `block_status` | String | `"temporary"` oder `"permanent"` |
| `blocked_at` | Timestamp | Zeitpunkt der Sperre |
| `blocked_by` | String | E-Mail des DJs, der gesperrt hat |
| `blocked_by_dj` | String | E-Mail des DJs (Duplikat für Klarheit) |
| `name` | String | Anzeigename des gesperrten Gasts |
| `client_id` | String | **WICHTIG:** Client-ID des Gasts (für PWA-Erkennung) |
| `user_id` | String? | Optional: Firebase User-ID (nur bei eingeloggten Usern) |
| `party_id` | String? | Lange Party-ID (für Filterung) |
| `party_code` | String? | 6-stelliger Party-Code (für Kompatibilität) |
| `blocked_until` | Timestamp? | Nur bei `temporary`: Ablaufzeitpunkt |

---

## 4. Hardware-Daten: Was wird gespeichert?

### ❌ NICHT gespeichert (nur lokal verwendet)

Die folgenden Hardware-Daten werden **NUR lokal** zum Berechnen des Fingerprint-Hash verwendet und **NIEMALS** in der Datenbank gespeichert:

- `navigator.userAgent` (Browser-String)
- `navigator.language` (Sprache)
- `navigator.languages` (Sprachliste)
- `navigator.platform` (Plattform)
- `navigator.hardwareConcurrency` (CPU-Kerne)
- `navigator.deviceMemory` (RAM)
- `screen.width` (Bildschirmbreite)
- `screen.height` (Bildschirmhöhe)
- `screen.colorDepth` (Farbtiefe)
- `screen.pixelDepth` (Pixel-Tiefe)
- `Intl.DateTimeFormat().resolvedOptions().timeZone` (Zeitzone)
- Canvas-Fingerprint (Base64-String)
- WebGL-Renderer-Info (GPU-Details)

### ✅ Gespeichert (nur Hash)

**Nur der Hash-Wert** wird gespeichert:

- `fingerprint` (String): Hash-Wert, z.B. `"a3f5b2c1"`

**Hash-Generierung:**

```javascript
// Alle Hardware-Komponenten werden kombiniert
const fingerprintString = components.join('|');

// Hash wird berechnet
let hash = 0;
for (let i = 0; i < fingerprintString.length; i++) {
  const char = fingerprintString.charCodeAt(i);
  hash = ((hash << 5) - hash) + char;
  hash = hash & hash;
}

// Nur der Hash wird zurückgegeben
return Math.abs(hash).toString(36);
```

**Sicherheit:** Keine sensiblen Hardware-Daten werden direkt gespeichert, nur ein nicht-reversibler Hash!

---

## 5. Datenfluss-Diagramm

```
┌─────────────────────────────────────────────────────────────┐
│ 1. GAST ÖFFNET PWA                                          │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. createHardwareFingerprint()                              │
│    - Sammelt Hardware-Daten (lokal)                         │
│    - Erstellt Hash (z.B. "a3f5b2c1")                        │
│    - ❌ Keine Daten werden gespeichert                       │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. getOrCreateClientId()                                     │
│    - Prüft localStorage                                      │
│    - Sucht in guest_fingerprints nach Hash                  │
│    - Erstellt neue clientId falls nicht gefunden            │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. guest_fingerprints Collection                            │
│    Document-ID: "a3f5b2c1" (Hash)                          │
│    {                                                         │
│      client_id: "guest_fp_a3f5b2c1_1704067200000_abc123",  │
│      fingerprint: "a3f5b2c1",                               │
│      created_at: Timestamp,                                 │
│      last_seen: Timestamp                                   │
│    }                                                         │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. GAST SCHICKT WUNSCH AB                                    │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. wishes Collection                                        │
│    Document-ID: Auto-generiert                              │
│    {                                                         │
│      name: "Max Mustermann",                                │
│      title: "Song Titel",                                    │
│      artist: "Künstler",                                     │
│      client_id: "guest_fp_a3f5b2c1_1704067200000_abc123",  │
│      party_id: "cVPlhrPuXVBRyGyuNcDh",                      │
│      party_code: "ABC123",                                   │
│      ...                                                     │
│    }                                                         │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. DJ SPERRT GAST                                            │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ 8. blocked_guests Collection                                │
│    Document-ID: "guest_fp_a3f5b2c1_1704067200000_abc123"   │
│    {                                                         │
│      block_status: "temporary",                             │
│      blocked_at: Timestamp,                                 │
│      blocked_by: "dj@example.com",                          │
│      name: "Max Mustermann",                                │
│      client_id: "guest_fp_a3f5b2c1_1704067200000_abc123",  │
│      party_id: "cVPlhrPuXVBRyGyuNcDh",                      │
│      blocked_until: Timestamp                               │
│    }                                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Übersichtstabelle: Identifikations-Felder

| Collection | Document-ID | Feld `client_id` | Feld `name` | Feld `party_id` | Verknüpfung |
|------------|-------------|------------------|-------------|-----------------|-------------|
| **guest_fingerprints** | `fingerprint` (Hash) | ✅ Ja (Format: `guest_fp_{hash}_{timestamp}_{uuid}`) | ❌ Nein | ❌ Nein | Mapping: Hash → client_id |
| **wishes** | Auto-generiert | ✅ Ja (seit Fix) | ✅ Ja | ✅ Ja | Verknüpfung: `client_id` aus `guest_fingerprints` |
| **blocked_guests** | `client_id` (wenn vorhanden) oder `name` | ✅ Ja (wenn vorhanden) | ✅ Ja | ✅ Ja | Verknüpfung: `client_id` aus `wishes` |

---

## 7. Sicherheits-Hinweise

### ✅ Datenschutz-konform

- **Keine sensiblen Hardware-Daten** werden direkt gespeichert
- **Nur Hash-Werte** werden in `guest_fingerprints` gespeichert
- Hardware-Daten werden **nur lokal** verwendet und **nie übertragen**

### ⚠️ Gespeicherte Daten

- `client_id`: Eindeutige ID (kann nicht auf Hardware zurückgeführt werden)
- `fingerprint`: Hash-Wert (nicht reversibel)
- `name`: Anzeigename (vom Gast eingegeben)
- `party_id` / `party_code`: Party-Identifikation

### 🔒 Empfehlungen

- `client_id` sollte **nicht** als personenbezogenes Datum betrachtet werden (anonyme ID)
- `name` ist **personenbezogen** (vom Gast eingegeben)
- `blocked_guests` enthält **personenbezogene Daten** (Name + Sperr-Status)

---

## 8. Flutter-App (Gast-Bereich)

### Identifikation

**Methode:** `_getOrCreateClientId()` in `lib/pages/wishes_page.dart`

**Format:** `app_{deviceId}_{uuid}`

**Beispiele:**
- Android: `app_9774d56d_550e8400-e29b-41d4-a716-446655440000`
- iOS: `app_12345678_550e8400-e29b-41d4-a716-446655440000`
- Web: `app_web_1704067200000_550e8400-e29b-41d4-a716-446655440000`

**Speicherung:**
- `SharedPreferences`: `guest_client_id`
- Firestore: `wishes.client_id`

---

## Zusammenfassung

✅ **Hardware-Daten:** Werden **NUR lokal** verwendet, **NICHT** in DB gespeichert  
✅ **Hash-Wert:** Wird in `guest_fingerprints` gespeichert (nicht reversibel)  
✅ **client_id:** Wird in `wishes` und `blocked_guests` gespeichert  
✅ **Verknüpfung:** `wishes.client_id` = `guest_fingerprints.client_id` = `blocked_guests.client_id`  
✅ **Sicherheit:** Keine sensiblen Hardware-Details in der Datenbank!
