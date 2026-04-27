# PWA Deployment & Produktion

## Produktions-Sicherheit (Live-Betrieb)

- **IS_DEBUG:** In `public/vb/index.html` ist `window.IS_DEBUG = false` gesetzt. Nur wenn `IS_DEBUG === true`, werden `console.log`, `console.debug`, `console.info` und `console.warn` ausgegeben.
- **console.error:** Kritische Fehler werden nur mit kurzer Meldung geloggt; Details (Stacks, Objekte) nur bei `IS_DEBUG`. Keine sensiblen Daten (UIDs, Party-IDs, client_id) in der Konsole.
- Zum Testen: In der Browser-Konsole `window.IS_DEBUG = true` setzen und Seite neu laden.

## Minifizierung (empfohlen für nächste Deployments)

Um die Lesbarkeit des Codes für Dritte weiter zu erschweren:

1. **Build-Schritt einrichten (optional):**  
   Vor `firebase deploy --only hosting` die JS-Dateien minifizieren:
   - z.B. mit **Terser**: `npx terser public/vb/translations.js -o public/vb/translations.min.js -c -m` und im HTML `translations.min.js` einbinden.
   - Für **inline Scripts** in `index.html`: Build-Pipeline (z.B. Vite, Rollup) mit Terser-Plugin oder manuell kritische Blöcke minifizieren.

2. **Firebase Hosting:**  
   Deployed Dateien werden unverändert ausgeliefert. Minifizierte Versionen müssen vor dem Deploy erzeugt und im Projekt abgelegt werden.

3. **Service Worker:**  
   `public/vb/service-worker.js` kann ebenfalls mit Terser minifiziert werden; danach Cache-Version (CACHE_NAME) ggf. erhöhen.
