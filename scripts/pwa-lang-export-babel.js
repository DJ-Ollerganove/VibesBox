#!/usr/bin/env node
/**
 * Exportiert public/vb/lang/*.js → public/vb/babel/locales/*.json (für BabelEdit).
 */
const fs = require('fs');
const path = require('path');
const lib = require('./pwa-lang-lib');

function main() {
  fs.mkdirSync(lib.BABEL_LOCALES_DIR, { recursive: true });
  const meta = lib.readMeta();
  const codes = new Set([
    ...lib.listLangJsCodes(),
    ...meta.languages.map((e) => e.code),
  ]);
  let count = 0;
  for (const code of [...codes].sort()) {
    try {
      const data = lib.loadLangJs(code);
      const outPath = path.join(lib.BABEL_LOCALES_DIR, `${code}.json`);
      fs.writeFileSync(outPath, JSON.stringify(data, null, 2) + '\n', 'utf8');
      count++;
      console.log('  ✓', outPath);
    } catch (e) {
      console.warn('  ⚠', code, e.message);
    }
  }
  console.log(`\nExport fertig: ${count} Dateien nach public/vb/babel/locales/`);
  console.log('BabelEdit: Ordner „locales“ öffnen, Quellsprache Deutsch (de.json).');
}

main();
