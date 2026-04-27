# PWA-Sprachdateien (dynamisches Laden)

Jede Datei exportiert ein Objekt `lang_XX` (z. B. `lang_de`, `lang_en`) mit denselben Keys wie in der monolithischen `translations.js`. Die Keys sind in allen Dateien identisch.

- **Pfad (relativ zu vb/):** `lang/de.js`, `lang/en.js`, …
- **settings/languages:** Pro Sprache kann `js_url` den relativen Pfad angeben (z. B. `lang/de.js`) für das dynamische Laden.

Erzeugt mit `node extract-langs.js` aus `../translations.js`.
