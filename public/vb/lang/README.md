# PWA-Sprachdateien (Runtime)

Die App lädt ausschließlich **`/vb/lang/<code>.js`** (pro Sprache eine Datei, aus `babel/locales/*.json` generiert).

**Übersetzen mit BabelEdit:** siehe **`../babel/README.md`** — dort nur `locales/*.json` bearbeiten, danach:

`node scripts/pwa-lang-import-babel.js`

Dieser Ordner wird vom Import-Skript aus den JSON-Dateien erzeugt.
