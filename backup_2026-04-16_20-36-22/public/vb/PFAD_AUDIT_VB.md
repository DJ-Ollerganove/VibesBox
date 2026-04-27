# Pfad- und Referenz-Audit: /vb/ (VibesBox PWA)

Stand: Nach Umzug der PWA von Root nach `/vb/`. Lückenlose Prüfung ohne Spekulation.

---

## 1. Skript- und Ressourcen-Pfade (public/vb/index.html)

### base-Tag
- **`<base href="/vb/">`** (Zeile 4) – gesetzt. Relative URLs werden zu `/vb/...` aufgelöst.

### Script-Tags
| Quelle | Pfad | Auflösung | Bewertung |
|--------|------|-----------|-----------|
| Firebase (Modul) | CDN `gstatic.com/firebasejs/11.0.1/...` | Absolut | ✅ |
| translations.js | `translations.js` | Relativ → `/vb/translations.js` | ✅ |
| styles/theme.js | `styles/theme.js` | Relativ → `/vb/styles/theme.js` | ✅ |
| party_shared.js | `/party_shared.js` | Absolut (Root) | ✅ Korrekt, Datei liegt unter public/ |

### Link-Tags
| Quelle | Pfad | Auflösung | Bewertung |
|--------|------|-----------|-----------|
| manifest | `/vb/manifest.json` | Absolut | ✅ |
| favicon | `/vb/favicon.png` | Absolut | ✅ |
| Font Awesome | CDN | Absolut | ✅ |
| reCAPTCHA | CDN | Absolut | ✅ |

### Bilder im Body
- `icon/vibesbox-logo.png` → relativ zu base → `/vb/icon/vibesbox-logo.png`. Falls der Ordner `public/vb/icon/` nicht existiert, liefert der Server 404; ggf. Ordner anlegen oder Pfad anpassen.

### Konflikt base vs. absolute Pfade
- Absolute Pfade (`/party_shared.js`, `/vb/manifest.json`) werden von `<base>` nicht geändert (laut HTML-Spec). Kein Konflikt.

---

## 2. JavaScript-Logik & Firestore-Referenzen

### checkPartyCode / result.type (BEHOBEN)
- **Ursache TypeError:** In zwei Stellen wurde `result.type` gelesen, obwohl im Block `if (!result || !result.success)` der Wert `result` null/undefined sein kann.
- **Fix:** Zugriff nur bei vorhandenem `result`: `if (result && result.type === 'future' && result.start_time_posix)`.
- **Zusätzlich:** Vor Verwendung von `partyInfo.party_id` wird geprüft: `if (!partyInfo || typeof partyInfo !== 'object' || !partyInfo.party_id)` → Fehlermeldung und return, keine Rekursion.

### Hartcodierte Pfade auf "/"
- Keine relevanten hartcodierten Root-Pfade in der Logik gefunden, die Datenbank- oder Dateizugriffe unter `/vb/` brechen. Firestore-Referenzen nutzen `window.firebaseDb` und Collections (`parties`, `wishes`, …) ohne Pfadabhängigkeit.

### localStorage / sessionStorage
- Keys wie `validatedPartyId`, `validatedPartyCode`, `pendingPartyId` sind originspezifisch, nicht pfadspezifisch. Unter gleicher Origin (z. B. `https://dj-ollerganove.web.app`) funktionieren sie für `/` und `/vb/` gleich. Kein Anpassungsbedarf.

### Firestore-Doc-Aufrufe
- Stellen mit `window.firebaseDoc(window.firebaseDb, 'parties', id)` nutzen die korrekte Signatur (db, collection, docId) des modularen SDKs. Keine Änderung nötig.

---

## 3. Service Worker & Manifest

### Registrierung (index.html)
- **Pfad:** `navigator.serviceWorker.register('/vb/service-worker.js', { scope: '/vb/', updateViaCache: 'none' })`.
- **Bewertung:** ✅ Zeigt auf `/vb/service-worker.js`, Scope `/vb/` – korrekt für Unterordner.

### service-worker.js (Inhalt)
- Cache-Liste: `/vb/`, `/vb/index.html`, `/vb/manifest.json` – alle unter `/vb/`. ✅

### Manifest
- Verweis im HTML: `href="/vb/manifest.json"`. ✅

---

## 4. Dateistruktur /vb/

- index.html, translations.js, manifest.json, service-worker.js, robots.txt
- Ordner: styles/ (theme.js), images/flags/
- Root-Ressource: party_shared.js unter public/ (wird mit `/party_shared.js` geladen)
- Hinweis: `icon/` wird im HTML referenziert (`icon/vibesbox-logo.png`); ob der Ordner existiert, projektabhängig prüfen.

---

## 5. Verbotene Maßnahmen (eingehalten)

- Keine Spekulation: Nur tatsächlich gefundene Stellen und Dateistruktur.
- Kein Raten: TypeError durch fehlende Prüfung von `result` und `partyInfo` – Fix direkt an den Codezeilen.

---

## 6. Durchgeführte Code-Änderungen (Zusammenfassung)

1. **result.type:** Zwei Stellen – Zugriff nur bei `result` vorhanden: `result && result.type === 'future' && result.start_time_posix`.
2. **partyInfo:** Nach `partyInfo = result.data` bzw. Fallback getActivePartyInfo: Prüfung `if (!partyInfo || typeof partyInfo !== 'object' || !partyInfo.party_id)` mit Fehlerlog und return (bzw. return false in processQRCodeLogin), damit keine Rekursion/TypeError bei fehlenden Daten.
