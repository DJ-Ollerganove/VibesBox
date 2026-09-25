# DJ-Browser Übersetzungen (BabelEdit)

| Richtung | Befehl |
|----------|--------|
| **JS → JSON** (zum Übersetzen) | `node scripts/dj-lang-export-babel.js` |
| **JSON → JS** (nach BabelEdit) | `node scripts/dj-lang-import-babel.js` |
| **Nachlaufzeit-Keys aus App-ARB** | `node scripts/sync-dj-party-grace-l10n.js` → danach Import |

- **Quelle im Browser:** `public/dj-admin/dj-l10n.js`
- **Bearbeiten in BabelEdit:** `public/dj-admin/babel/locales/*.json` (Quellsprache: `de.json`)
- Gesamt-Workflow: `./scripts/i18n-export-for-translation.sh` bzw. `./scripts/i18n-sync.sh`
