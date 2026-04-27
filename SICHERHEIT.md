# Sicherheitsanalyse – Landingpage & PWA (VibesBox)

## Gefundene Schwachstellen und umgesetzte Maßnahmen

### 1. Input-Validierung (Client)

| Schwachstelle | Status | Maßnahme |
|---------------|--------|----------|
| **Landingpage:** URL-Parameter `?code=` wurde ungeprüft an `/vb/?code=...` weitergeleitet (XSS/Injection möglich). | Behoben | `code` wird auf nur Ziffern (0–9) und max. 6 Zeichen begrenzt; bei ungültigem Wert keine Weiterleitung. |
| **Landingpage:** Overlay-Eingabe ohne Längenbegrenzung und ohne Bereinigung. | Behoben | `maxlength="6"`, `pattern="[0-9]{6}"`, `inputmode="numeric"`; bei Eingabe und vor Prüfung: nur Ziffern, genau 6 Zeichen. |
| **PWA (vb/index.html):** Party-Code manuell – bereits eingeschränkt. | Bestätigt | `sanitizePartyCode()` (nur Ziffern, max. 6), `pattern="[0-9]{6}"`, `validatePartyId()` für Party-IDs. |

**Hinweis:** Party-Code ist einheitlich **6 Ziffern** (0–9), keine Buchstaben/Sonderzeichen (XSS-Schutz).

---

### 2. Brute-Force / Rate Limiting

| Schwachstelle | Status | Maßnahme |
|---------------|--------|----------|
| Keine Begrenzung bei falschen Party-Codes (Brute-Force möglich). | Behoben | In **party_shared.js**: Nach 5 Fehlversuchen in Folge wird die Abfrage für 30 Sekunden blockiert (lokal im Browser, `sessionStorage`). Meldung: *„Zu viele Fehlversuche. Bitte in 30 Sekunden erneut versuchen.“* |
| Firestore: Rate Limiting pro IP serverseitig. | Nicht umgesetzt | Firestore Security Rules können keine Ratenbegrenzung pro IP. Dafür wären **App Check** und/oder eine **Cloud Function** (Proxy mit Rate Limit) nötig. |

---

### 3. Firestore Security Rules

| Punkt | Status | Anmerkung |
|-------|--------|-----------|
| **parties:** `allow read: if true` – jeder kann Partys lesen. | Bewusst so | Gäste müssen Partys per `party_code`-Abfrage lesen können. Firestore-Regeln können Abfragen nicht so einschränken, dass nur „ein Dokument mit diesem party_code“ gelesen wird. |
| **parties:** Schreibrechte nur mit Kenntnis des Codes? | Nein | Schreiben nur für **authentifizierte** Nutzer (Admin oder DJ Level 2/3). Kenntnis eines Party-Codes allein gibt **keine** Schreibrechte. |
| Regel-Kommentar | Ergänzt | In **firestore.rules** bei `parties` ergänzt: Lesezugriff für Gäste (Party-Code-Prüfung), Schreibrechte nur für Auth. |

---

### 4. Firebase Authentication / Anonymous Login

| Punkt | Status | Anmerkung |
|-------|--------|-----------|
| Anonymer Gast-Login | Nicht eingeführt | Aktuell **kein** anonymes Login für Gäste. Gäste nutzen die App ohne `request.auth`. |
| Regel-Verschärfung `request.auth != null` für parties | Nicht umgesetzt | Würde **anonymen Login** für alle Gäste erfordern (z. B. `signInAnonymously()` vor Party-Code-Prüfung). Optional später einplanbar. |

---

### 5. Header & PWA-Sicherheit

| Schwachstelle | Status | Maßnahme |
|---------------|--------|----------|
| Keine Sicherheits-Header in **firebase.json**. | Behoben | Für `**` gesetzt: **X-Content-Type-Options: nosniff**, **X-Frame-Options: DENY**, **Referrer-Policy: strict-origin-when-cross-origin**, **Permissions-Policy** (geolocation, microphone, camera deaktiviert). |
| **party_shared.js** enthält sensible Keys? | Nein | Es wird nur die **öffentliche Firebase-Client-Konfiguration** (apiKey, authDomain, projectId, …) verwendet – keine Admin-Keys, keine Service-Account-Daten. |

**Hinweis:** Eine strenge **Content-Security-Policy (CSP)** wurde nicht gesetzt, da die Seite Inline-Skripte und externe Skripte (z. B. reCAPTCHA, Firebase) nutzt. CSP würde `unsafe-inline` oder Nonces erfordern und sollte bei Bedarf schrittweise eingeführt werden.

---

### 6. Geänderte Dateien (Überblick)

- **public/index.html** – URL-Code bereinigen; Overlay: 6 Ziffern, Eingabe-Filter, Validierung vor Prüfung.
- **public/party_shared.js** – Party-Code auf 6 Ziffern normalisieren; Rate Limit (5 Fehlversuche → 30 s Sperre); nur öffentliche Firebase-Config.
- **public/vb/index.html** – Bereits strikte Validierung (sanitizePartyCode, pattern, validatePartyId); keine Änderung nötig.
- **firestore.rules** – Kommentar bei `parties` ergänzt (Lesen für Gäste, Schreiben nur Auth).
- **firebase.json** – Sicherheits-Header für alle ausgelieferten Dateien ergänzt.

---

*Stand: Februar 2025*
