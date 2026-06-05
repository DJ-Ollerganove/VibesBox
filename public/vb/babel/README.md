# PWA-Übersetzungen mit BabelEdit

**App (Flutter):** siehe `l10n/README.md` im Projektroot (`*.arb`).

**Du übersetzt nur hier:** `locales/*.json` (in BabelEdit).

**Technik (Skripte, Menü, `lang/*.js`):** nach dem Speichern in BabelEdit einmal im Projektroot:

```bash
node scripts/pwa-lang-import-babel.js
firebase deploy --only hosting
```

## BabelEdit einrichten (einmalig)

1. BabelEdit → **Neues Projekt** → Format **JSON** (flache Keys).
2. Ordner: **`public/vb/babel/locales`**
3. **Quellsprache:** Deutsch (`de.json`).
4. Weitere Sprachen = je eine `xx.json` (z. B. `en.json`, `fr.json`).

## Neue Sprache

1. In BabelEdit: Sprache hinzufügen (z. B. `pl.json`) – am besten von `en.json` kopieren.
2. Übersetzen.
3. `node scripts/pwa-lang-import-babel.js` (trägt Sprache ins Menü ein, erzeugt `lang/pl.js`).

Optional vorher in `pwa-languages.json` eintragen (Anzeigename, Flagge); sonst macht das Import-Skript einen Vorschlag.

## JSON aus bestehenden JS-Dateien holen

```bash
node scripts/pwa-lang-export-babel.js
```

Die PWA lädt ausschließlich **`lang/*.js`** (aus `locales/*.json` erzeugt). Die frühere Monolith-Datei `translations.js` wurde entfernt.
