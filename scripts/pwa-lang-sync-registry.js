#!/usr/bin/env node
/** Nur Registry → default-pwa-languages.js (ohne JSON-Import). */
const lib = require('./pwa-lang-lib');

const meta = lib.readMeta();
for (const code of lib.listLangJsCodes()) {
  lib.ensureMetaEntry(meta, code);
}
lib.writeMeta(meta);
lib.writeDefaultPwaLanguagesJs(meta);
console.log('✓ default-pwa-languages.js aus pwa-languages.json erzeugt');
