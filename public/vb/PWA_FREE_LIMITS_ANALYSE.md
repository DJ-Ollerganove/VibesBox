# PWA (public/) – Analyse für VibesBox Free Limits

## 1. Daten-Abruf

**Zuständige Datei:** `public/index.html` (alles in einer Datei).

- **Firebase-Initialisierung:** Zeilen 19–51 (ES-Module-Import von Firebase App + Firestore, `initializeApp`, `getFirestore`, globale `window.*`-Hilfen für `getDoc`, `getDocs`, `onSnapshot` usw.).
- **Party laden:** 
  - `getDoc(parties/{partyId})` u. a. in:
    - **5738–5741:** Nach Session-Recovery (savedPartyId aus sessionStorage) – lädt Party-Dokument für DJ-Namen/Party-Name.
    - **5909–5913, 5028–5032, 4440–4446, 8439–8444:** weitere Stellen für Party-Daten.
- **DJ-Daten:** Direkt nach dem Party-Load (ab **5765**) wird `created_by` aus den Party-Daten gelesen; mit dieser UID werden **parallel** zwei Dokumente geladen:
  - **5783–5806:** `getDoc(users/{createdByUid})` → `userData` (displayName, …).
  - **5812–5831:** `getDoc(social_media_links/{createdByUid})` → `socialsData`.
- **Speicherung:** DJ-Name in `sessionStorage.currentDjName`, Social-Daten in `sessionStorage.currentDjSocials`. **`planType` aus dem User-Dokument wird aktuell weder gelesen noch gespeichert.**

---

## 2. DJ-Plan Identifikation

- **Ja**, das User-Dokument des DJs wird geladen: `users/{createdByUid}` mit `createdByUid = partyDataForDj.created_by` (Zeilen 5768–5790).
- **Verbindung:** `party.created_by` (oder ggf. `party.dj_code`) → eine UID → gleiche ID für `users/{uid}` und `social_media_links/{uid}`.
- **Fehlend:** Aus `userData` wird **nicht** `planType` (bzw. `planType`) ausgelesen und nirgends abgelegt.  
  **Empfehlung:** Direkt nach dem Laden von `userData` (z. B. Zeile 5835) `planType` auswerten und z. B. in `sessionStorage.setItem('djPlanType', (userData.planType || 'free').toLowerCase())` speichern, damit alle nachfolgenden PWA-Stellen darauf zugreifen können.

---

## 3. Logo-Rendering

| Ort | Element / Funktion | Aktuelles Verhalten | Anpassung für planType === 'free' |
|-----|--------------------|----------------------|-----------------------------------|
| **App-Header (links)** | `<img id="appHeaderLogo">` (Zeile 2751) | Immer `icon/vibesbox-logo.png` – wird im Code **nicht** auf DJ-Logo umgestellt. | Keine Änderung nötig (bleibt VibesBox). |
| **Branding-Zeile (Wunschbox)** | `updateBrandingLine()` (ca. 8412–8468), `#brandingDjLogo` | Lädt Party per `getDoc(parties/…)`, setzt `brandingDjLogo.src = partyData.dj_logo`. | Wenn `sessionStorage.djPlanType === 'free'`: `brandingDjLogo.src = 'icon/vibesbox-logo.png'` (oder ausblenden und nur Text zeigen). |
| **Drawer-Menü** | `loadDrawerLogo()` (ca. 7770–7818), `#drawerDjLogo` | Lädt Party, setzt `logoImg.src = partyData.dj_logo`. | Wenn Free: Logo auf `icon/vibesbox-logo.png` setzen oder Container ausblenden. |
| **Social-Media-Seite** | `loadSocialMediaLogo()` (ca. 10050–10098), `#socialMediaDjLogo` | Lädt Party, setzt `logoImg.src = partyData.dj_logo`. | Wenn Free: VibesBox-Logo anzeigen oder Logo-Container ausblenden. |

**Weiche:** An allen Stellen, an denen aktuell `partyData.dj_logo` (oder aus Cache/Session abgeleitet) für ein DJ-Logo genutzt wird, zuerst `sessionStorage.getItem('djPlanType')` prüfen; bei `'free'` stattdessen `icon/vibesbox-logo.png` verwenden bzw. Anzeige anpassen.

---

## 4. Social Media & Kontaktformular

**Social Media:**

- **Seite:** `#page-social-media` (ab Zeile 3036).
- **Struktur:**  
  - Logo-Container: `#socialMediaLogoContainer`, `#socialMediaDjLogo` (3040–3041).  
  - Links-Container: `#socialLinksContainer` (3046).  
  - Leer-Zustand: `#socialLinksEmpty` (3049).
- **Rendering:** `renderSocialMediaLinks()` (ca. 10101): liest `sessionStorage.currentDjSocials`, baut die Link-Liste auf; `loadSocialMediaLogo()` wird vorher aufgerufen.
- **Free-Logik:** Wenn `djPlanType === 'free'`: gesamte Sektion ausblenden (z. B. `#page-social-media` Inhalt ersetzen durch Hinweis „Nur für VibesBox Pro sichtbar“) oder `socialLinksContainer` leer lassen und nur eine Meldung anzeigen. Zusätzlich Logo wie unter Punkt 3 behandeln.

**Kontaktformular:**

- **Seite:** `#page-kontakt` (ab Zeile 3088).
- **Formular:** `#contactForm` (3095) mit Feldern contactName, contactEmail, contactPhone, contactSubject, contactMessage und Submit-Button (3145).
- **Submit:** `contactForm.addEventListener('submit', …)` (ca. 9076).
- **Free-Logik:** Wenn `djPlanType === 'free'`:  
  - Formular optisch sichtbar lassen, aber alle Inputs/Textarea und den Submit-Button auf `disabled` setzen und z. B. ein Overlay (oder eine umschließende div mit `pointer-events: none`) darüber legen, damit keine Interaktion möglich ist. Optional kurzer Hinweis „Nur für VibesBox Pro verfügbar“.

---

## 5. Technologie

- **Reines JavaScript**, keine Frameworks (kein Vue/React).
- **Eine zentrale Datei:** `public/index.html` enthält HTML, CSS und den gesamten App-JS-Code inline.
- **Weitere Dateien:**  
  - `translations.js` – Übersetzungen (i18n).  
  - `styles/theme.js` – Theme.  
  - `service-worker.js` – PWA-SW.  
  - `manifest.json`, `robots.txt`, ggf. Bilder.
- **Kein Build-Step** für die PWA im public-Ordner; Änderungen direkt in `index.html` (und ggf. `translations.js`) vornehmen.

---

## 6. Dateistruktur (relevant für Free-Limits)

```
public/
├── index.html          ← Alle Firebase-/Party-/DJ-/UI-Logik, Logo, Social, Kontakt
├── translations.js     ← Nur Texte (optional: neue Keys für Free-Hinweise)
├── styles/theme.js
├── service-worker.js
├── manifest.json
└── icon/
    └── vibesbox-logo.png   ← Standard-Logo (bereits vorhanden)
```

---

## 7. Stellen für planType-Logik (Injection Points)

| Nr | Stelle (Datei, ungefähre Zeile) | Aktion |
|----|--------------------------------|--------|
| 1 | **index.html** – nach dem Laden von `userData` (nach 5834, wo `userData`/`socialsData` gesetzt werden) | `planType` aus `userData` lesen und in `sessionStorage.setItem('djPlanType', …)` speichern; bei Logout/Session-Clear `djPlanType` entfernen. |
| 2 | **updateBrandingLine()** (ca. 8437–8462) | Vor Setzen von `brandingDjLogo.src`: wenn `sessionStorage.djPlanType === 'free'`, `src = 'icon/vibesbox-logo.png'` (oder nur Text, kein DJ-Logo). |
| 3 | **loadDrawerLogo()** (ca. 7788–7810) | Wenn `djPlanType === 'free'`: `logoImg.src = 'icon/vibesbox-logo.png'` und Container anzeigen, oder Container ausblenden. |
| 4 | **loadSocialMediaLogo()** (ca. 10065–10082) | Wenn Free: VibesBox-Logo setzen oder Container ausblenden. |
| 5 | **renderSocialMediaLinks()** (ca. 10101) | Ganz am Anfang: wenn `sessionStorage.djPlanType === 'free'`: gesamte Social-Links-Sektion ausblenden und ggf. nur Hinweis „Nur für VibesBox Pro sichtbar“ anzeigen; sonst wie bisher rendern. |
| 6 | **Kontakt-Seite anzeigen** (z. B. bei `showPage('kontakt')` oder wenn `#page-kontakt` sichtbar wird) | Wenn `djPlanType === 'free'`: alle Inputs/Textarea/Button in `#contactForm` auf `disabled` setzen und Overlay mit `pointer-events: none` über das Formular legen (oder Wrapper mit Klasse für dezente Opacity). |
| 7 | **performLogout()** (ca. 8151) | `sessionStorage.removeItem('djPlanType')` (und ggf. weitere Session-Keys) ausführen, damit beim nächsten Login der Plan wieder frisch geladen wird. |

Damit sind Daten-Abruf, DJ-Plan-Identifikation, Logo-Rendering, Social Media und Kontaktformular sowie die Technologie und die konkreten Stellen für die planType-Logik beschrieben.
