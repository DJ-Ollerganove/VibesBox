# Security-Audit-Bericht – VibesBox (Main PWA, VB PWA, Cloud Functions)

**Datum:** Februar 2026  
**Umfang:** Main PWA (`public/index.html`), VB PWA (`public/vb/index.html`), Cloud Functions (`functions/`), Firestore Rules (`firestore.rules`).  
**Hinweis:** Es wurden keine Code-Änderungen vorgenommen; der Bericht dient ausschließlich der Dokumentation von Schwachstellen und Empfehlungen.

---

## 1. Input Validation & Sanitization (XSS)

### 1.1 Kontaktformular (Main PWA & VB PWA)

| Aspekt | Befund |
|--------|--------|
| **Vor dem Versand** | In beiden PWAs werden alle Felder (name, email, phone, subject, message) durch `sanitizeInput()` bzw. `sanitizeEmail()` gefiltert: HTML-Tags, `javascript:`, Event-Handler, SQL-ähnliche Muster werden entfernt; anschließend werden `&`, `<`, `>`, `"`, `'`, `/` escaped. |
| **Cloud Function** | `validateRecaptchaAndSaveContact` speichert `name`, `email`, `phone`, `subject`, `message` nach `.trim()` ohne zusätzliche serverseitige Sanitization. Die Daten stammen aus dem Client – ein kompromittierter oder manipulierter Client könnte theoretisch andere Inhalte senden. |
| **E-Mail-Versand** | Die Inhalte werden in EmailJS-Template-Parameter eingebaut. EmailJS rendert Templates serverseitig; ob dort HTML escaped wird, hängt vom Template ab. Empfehlung: In der Cloud Function vor dem Speichern und vor dem E-Mail-Versand eine strikte Zeichen-/Längenprüfung und ggf. HTML-Escaping durchführen. |

**Risiko:** Gering (Client-Sanitization vorhanden, aber keine serverseitige Absicherung).

---

### 1.2 Wunschbox (VB PWA)

| Aspekt | Befund |
|--------|--------|
| **Eingabe vor Firestore** | Titel, Artist, Name, Greeting werden durch `sanitizeInput()` gefiltert, bevor sie an Firestore gehen. |
| **Firestore Rules** | `wishes`: Es sind nur erlaubte Keys und Längen (z. B. title ≤ 200, name ≤ 50, greeting ≤ 200) erzwungen; kein explizites Verbot von HTML/Script-Strings. Gespeicherte Werte können also prinzipiell Zeichenketten mit `<`, `>` etc. enthalten. |
| **Anzeige** | History-Liste: `track.title` und `track.artist` werden mit `escapeHtml()` in `item.innerHTML` eingebaut – **sauber**. Spotify-Vorschläge: `escapeHtml(track.name)` und `escapeHtml(track.artists)` – **sauber**. |

**Risiko:** Gering, solange alle Anzeigen von User-Daten über `escapeHtml()` laufen.

---

### 1.3 Modals mit Song-Titel/Artist (VB PWA) – **höheres Risiko**

| Stelle | Befund |
|--------|--------|
| **History-Duplikat-Modal** (ca. Zeile 4126) | `modal.innerHTML = \`...<h2 class="modal-title">${title}</h2><p class="modal-message">${message}</p>...\``. Hier ist `title` der übersetzte Modal-Titel (i18n), `message` wird aus einer Übersetzungsvorlage gebaut und enthält `decodedTitle` und `decodedArtist` – **nach** `decodeHtmlEntities(songTitle)` bzw. `decodeHtmlEntities(songArtist)`. |
| **decodeHtmlEntities** | Dekodiert nur HTML-Entities (z. B. `&amp;` → `&`). **Escaped keine Tags.** Wenn `songTitle` z. B. `<img src=x onerror="alert(1)">` enthält, landet das unverändert im `innerHTML` und kann ausgeführt werden. |
| **Pending-Duplikat-Modal** (ca. Zeile 4197) | Gleiche Konstruktion: `decodedTitle`/`decodedArtist` werden in `message` eingesetzt und dann in `modal.innerHTML` geschrieben – **ohne** `escapeHtml()`. |

**Risiko:** **Hoch.** Ein gespeicherter Wunsch mit bösartigem Titel/Artist (z. B. nach Umgehung der Client-Sanitization oder durch einen älteren Client) kann bei Anzeige im Modal zu XSS führen.  
**Empfehlung:** Vor dem Einsetzen in `message` und vor jeder `innerHTML`-Zuweisung `escapeHtml(decodedTitle)` und `escapeHtml(decodedArtist)` verwenden (bzw. durchgängig `textContent`/sichere DOM-APIs nutzen).

---

### 1.4 Weitere innerHTML-Nutzung

| Stelle | Befund |
|--------|--------|
| **Main PWA – Legal-Modal** | `legalModalBody.innerHTML = data.html` – Inhalt kommt aus `getLegalContent(type)` (translations/statisches HTML). Kein Nutzer-Input. |
| **Main PWA – Overlay-Fehler** | `codeOverlayError.innerHTML = msg` – `msg` wird aus Übersetzungskeys und `formatPartyLocalTime`/`calculateTimeUntilParty` gebaut, kein direktes Nutzer-Input. |
| **VB – Social/Impressum/Privacy** | `contentDiv.innerHTML = htmlContent` – Aufbau aus Übersetzungen und ggf. DJ-Namen. Siehe unten. |
| **VB – introductionElement** | `introductionElement.innerHTML = finalText.replace(djName, \`<strong>${djName}</strong>\`)`. `djName` kommt aus Firestore (Party/User). Wenn ein DJ-Name bösartiges HTML enthält, wäre XSS möglich. **Empfehlung:** `djName` vor der Einsetzung mit `escapeHtml(djName)` escapen. |

**Risiko:** Gering bei Legal/Overlay; **mittel** bei DJ-Namen in `introductionElement`, wenn DJ-Namen nicht vertrauenswürdig sind.

---

## 2. URL-Sicherheit (Injection)

### 2.1 Parameter `?code=`

| PWA | Verarbeitung |
|-----|--------------|
| **Main** | `raw = urlParams.get('code')` → `code = raw.replace(/[^0-9]/g, '').substring(0, 6)`. Nur Ziffern, max. 6 Zeichen. Redirect: `/vb/?code=` + code (und ggf. `&lang=`). |
| **VB** | Zwei Stellen: (1) Beim Laden: `rawCode = urlParams.get('code')` → `sanitizedCode = rawCode.replace(/[^0-9]/g, '')`, dann Regex `/^\d+$/`. Nur wenn rein numerisch, wird der Code verwendet. (2) QR-Code-Login: gleiche Logik. Ungültige Zeichen führen zu `replaceState` und Verwerfen des Parameters. |

**Bewertung:** Kein SQL/NoSQL, da keine Abfrage-Strings aus dem Parameter gebaut werden. Party-Zugehörigkeit wird über Firestore-Query `party_code == normalized` ermittelt; der Code wird nur als Vergleichswert genutzt. **Risiko: Gering.**

---

### 2.2 Parameter `?lang=`

| PWA | Verarbeitung |
|-----|--------------|
| **Main** | Wird nicht aus der URL gelesen (Sprache aus localStorage). |
| **VB** | Frühes Skript: `langParam = params.get('lang')`, dann `SUPPORTED_LANGS.indexOf(langParam) !== -1`. Nur erlaubte Werte (`de`, `en`, …) werden in `pwa_language`/`language` geschrieben. |

**Bewertung:** Whitelist, keine Injection-Gefahr. **Risiko: Gering.**

---

### 2.3 Party-ID (pendingPartyId, validatedPartyId)

| Aspekt | Befund |
|--------|--------|
| **VB – validatePartyId()** | Prüft Format: nur alphanumerisch, Länge 1–50, keine verdächtigen Muster (`<script>`, `javascript:`, etc.). |
| **Verwendung** | `pendingPartyId` aus localStorage wird nur genutzt, wenn `validatePartyId(pendingPartyId)` true ist. Party-Dokument wird per `parties/{partyId}` gelesen – Firestore verwendet die ID als Dokument-Pfad, keine Query-String-Injection. |

**Bewertung:** **Risiko: Gering.**

---

## 3. Client-seitige Manipulation (Konsole)

### 3.1 Globale Variablen/Funktionen

| Objekt | Zweck | Manipulierbar? |
|--------|--------|----------------|
| **window.checkPartyCode, formatPartyLocalTime, getPartyLocale, …** (party_shared.js) | Gemeinsame Logik für Main und VB. | Ja. Ein Angreifer könnte z. B. `checkPartyCode` ersetzen und andere Party-Daten zurückgeben. Die eigentliche Autorisierung liegt bei Firestore (Lesen von `parties` ist für alle erlaubt; Schreiben von `wishes` nur unter Rules). |
| **window.firebaseDb, firebaseCollection, …** | Firebase-API. | Ja. Direkte Firestore-Zugriffe aus der Konsole sind möglich, unterliegen aber den **Firestore Security Rules**. |
| **window.mainT, getMainLang, updateMainContent** (Main) | Übersetzung und UI-Update. | Nur UI/Sprache, keine sensiblen Daten. |
| **window.currentWishStats, isSuccessActive** (VB) | UI-Zustand. | Kann UI beeinflussen, nicht direkt Zugriff auf andere Partys. |
| **localStorage/sessionStorage** | validatedPartyId, pendingPartyId, pwa_language, etc. | Vollständig vom Client änderbar. Die App vertraut darauf für „aktuelle Party“. Wer eine andere Party-ID setzt, sieht nur Daten, die die **Firestore Rules** für diese Party freigeben (z. B. wishes mit dieser party_id lesbar). |

**Bewertung:** Sensible Logik („welche Party darf ich sehen?“) wird durch **Firestore Rules** begrenzt. Client-Manipulation kann nur innerhalb der durch die Rules erlaubten Lese-/Schreibzugriffe wirken. **Risiko: Mittel** (sauberer wäre weniger globale API; Änderung wäre refactoring, kein akuter Fix).

---

## 4. Firestore Security Rules

### 4.1 Übersicht

| Collection / Pfad | Lesen | Schreiben | Anmerkung |
|-------------------|--------|-----------|-----------|
| **parties** | `allow read: if true` | create/update/delete nur auth + Admin/DJ. | Jeder kann jede Party lesen (nötig für Code-Lookup). |
| **wishes** | `allow read: if true` | create nur mit party_id-Existenz, Zeitfenster, Feldvalidierung; update eingeschränkt; delete nur Admin/DJ. | **Lesen für alle** – jede Person kann alle Wünsche aller Partys lesen. Datenschutz-/Vertraulichkeitsrisiko. |
| **contact_messages** | Nur Admin (info@dj-ollerganove.de). | create mit Feldvalidierung (Keys, Längen); update/delete nur Admin. | Gut abgeschirmt. |
| **contacts** | In den Rules **nicht** definiert. | Default: verweigert. | Cloud Function schreibt per Admin SDK in `contacts` (bypass Rules). Wenn es keine Regel für `contacts` gibt, können Clients weder lesen noch schreiben. **Inkonsistenz:** Rules nennen `contact_messages`, Code nutzt `contacts` – klären, welche Collection tatsächlich genutzt wird. |
| **parties/{id}/guests** | `allow read: if true` | create/update: true; delete nur Admin. | Jeder kann alle Gäste aller Partys lesen. |
| **parties/{id}/guestStats** | `allow read: if true` | create/update: true. | Gleich. |
| **requests** | read: true | create: true, update eingeschränkt. | Sehr offen. |
| **users** | read: true | create/update/delete nur eigenes Dokument oder Admin. | Öffentliches Lesen für DJ-Namen etc. |
| **referral_codes** | read: true | create nur auth. | Codes prüfbar. |

### 4.2 Kritische Punkte

- **wishes:** Lesezugriff für alle bedeutet: Jeder kann alle Wunsch-Listen (inkl. Titel, Künstler, Namen) aller Partys abfragen. **Hohes Risiko** für Vertraulichkeit und DSGVO, wenn Wünsche personenbezogen sind.
- **parties/{id}/guests und guestStats:** `read: if true` – gleiche Problematik wie wishes.
- **contacts vs. contact_messages:** Cloud Function schreibt in `contacts`; Rules beschreiben `contact_messages`. Entweder Collection umbenennen oder Rules an die tatsächlich genutzte Collection anpassen, damit kein falsches Sicherheitsgefühl entsteht.

**Empfehlung (konzeptionell):**  
- Lesezugriff auf `wishes` und auf `guests`/`guestStats` auf Anfragen beschränken, die **nur** die aktuelle `party_id` (oder eine vom Nutzer nachgewiesene Party) betreffen. Das erfordert z. B. token-basierte oder regelbasierte Einschränkung (z. B. nur Dokumente, deren `party_id` in einer erlaubten Liste steht – in Firestore ohne Auth schwer abbildbar). Alternativ: Lesezugriff auf Wünsche/Gäste nur über Cloud Functions (aufrufbar mit Session/Token) statt direkt vom Client.

---

## 5. Cloud Function Security

### 5.1 validateRecaptchaAndSaveContact

| Aspekt | Befund |
|--------|--------|
| **reCAPTCHA** | Token wird serverseitig mit Google prüft. Ohne gültigen Token wird 400 zurückgegeben. |
| **Validierung** | Name und message Pflicht; keine Längenbegrenzung in der Function (Firestore Rules für `contact_messages` begrenzen: name ≤ 100, message ≤ 1500, subject ≤ 100, email/phone ≤ 100). Wenn die Function in `contacts` schreibt und es dafür keine Rules gibt, gelten nur die in der Function geprüften Bedingungen. |
| **Rate Limiting** | **Kein** serverseitiges Rate Limiting. Ein Angreifer kann viele gültige reCAPTCHA-Tokens (z. B. über automatisierte Browser) erzeugen und die Function massenhaft aufrufen → Spam, Speicherlast, E-Mail-Flut. |
| **Payload** | Body wird direkt aus `req.body` übernommen. Keine strikte Schema-Prüfung (z. B. nur string-Typen, max. Längen). Sehr große Bodies könnten Ressourcen belasten. |

**Risiko:** **Hoch** bzgl. Rate Limiting / Missbrauch; **mittel** bzgl. Input (Längen/Zeichensatz nicht serverseitig erzwungen, wenn Collection abweicht).

---

### 5.2 Weitere Functions (kurz)

| Function | Rate Limit | Input |
|----------|------------|--------|
| **searchSpotifyTracks** | Keins. | Query-Länge nur durch „trim().length > 0“. Typ und Query werden an Spotify weitergegeben – kein Firestore-Input. |
| **saveToMusicDatabase** | Keins. | Body-Felder (title, artist, …) werden genutzt; keine maximale Body-Größe. |
| **closePendingWishesForEndedParty** | Keins. | partyId aus Query/Body – keine Auth; jeder kann mit beliebiger partyId aufrufen und die Function auslösen. Kein Datenleck, aber Ressourcenverbrauch. |
| **recordLanguageHit** | Keins. | languageCode auf 2 Zeichen normalisiert. Sehr leicht, viele Hits zu erzeugen. |
| **updatePartyCodes** | – | Nur mit Authorization-Header (prinzipiell geschützt). |

**Empfehlung:** Für öffentlich aufrufbare Endpoints (Kontakt, Sprach-Hit, ggf. Party-Status) Rate Limiting pro IP oder pro reCAPTCHA-/Client-ID einführen (z. B. Firebase App Check + Limits oder eigener Redis/Memory-Counter).

---

## 6. Zusammenfassung: Geringes vs. hohes Risiko

### Geringes Risiko (sauberer arbeiten)

- **Kontaktformular:** Serverseitig in der Cloud Function Längen und Zeichentypen prüfen sowie ggf. HTML-Escaping für E-Mail-Template; gleiche Limits wie in den Firestore Rules.
- **Firestore:** Klarheit schaffen zwischen `contacts` und `contact_messages`; eine Collection festlegen und Rules sowie Code darauf ausrichten.
- **Globale APIs:** Weniger sensible Funktionen auf `window` exponieren; kritische Pfade nur über klar dokumentierte Schnittstellen aufrufbar machen.
- **DJ-Name in VB:** Bei `introductionElement.innerHTML = ... replace(djName, ...)` den DJ-Namen mit `escapeHtml(djName)` escapen.
- **closePendingWishesForEndedParty / recordLanguageHit:** Optional Auth oder strikteres Rate Limiting, um Ressourcenmissbrauch zu begrenzen.

### Hohes Risiko (akuter Handlungsbedarf)

1. **XSS in Modals (VB PWA):** In den Duplikat-Modals (History/Pending) werden `decodedTitle` und `decodedArtist` ohne HTML-Escaping in `innerHTML` eingebaut. **Maßnahme:** Vor der Einsetzung in `message` und in alle `innerHTML`-Zuweisungen, in die Titel/Artist fließen, `escapeHtml(...)` verwenden (oder Inhalte nur per `textContent`/DOM setzen).
2. **Firestore: wishes/guests lesbar für alle:** Jeder kann alle Wünsche und Gäste aller Partys lesen. **Maßnahme:** Konzept für einschränkenden Lesezugriff (z. B. nur über Cloud Functions mit Party-Berechtigung oder restriktivere Rules mit Auth/Kontext).
3. **Cloud Function validateRecaptchaAndSaveContact:** Kein Rate Limiting → Spam und E-Mail-Missbrauch möglich. **Maßnahme:** Rate Limiting pro IP und/oder pro client_id (z. B. max. 5–10 Anfragen pro Stunde pro IP) implementieren.

---

## 7. Kurz-Checkliste

| Prüfpunkt | Status |
|-----------|--------|
| Kontaktformular-Input clientseitig sanitized | ✅ |
| Kontaktformular serverseitig validiert/escaped | ⚠️ eingeschränkt |
| Wunschbox-Input clientseitig sanitized | ✅ |
| Wunschbox-Anzeige (History, Vorschläge) mit escapeHtml | ✅ |
| Modals mit Song-Titel/Artist mit escapeHtml | ❌ (XSS-Risiko) |
| URL-Parameter code/lang strikt validiert | ✅ |
| partyId-Validierung (Format/Whitelist) | ✅ |
| Firestore: wishes/guests nur für berechtigte Party | ❌ (read: true) |
| Firestore: contact_messages vs. contacts konsistent | ⚠️ prüfen |
| Cloud Function Kontakt: Rate Limiting | ❌ |
| Cloud Function Kontakt: reCAPTCHA | ✅ |
| Sensible Variablen nicht global zugreifbar | ⚠️ (Firebase-API global, durch Rules abgesichert) |

---

*Ende des Berichts. Keine Code-Änderungen vorgenommen.*
