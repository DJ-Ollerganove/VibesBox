#!/usr/bin/env node
/**
 * Exportiert public/dj/dj-l10n.js → public/dj/babel/locales/*.json (für BabelEdit).
 */
const fs = require('fs');
const path = require('path');
const lib = require('./dj-lang-lib');

function main() {
  fs.mkdirSync(lib.BABEL_LOCALES_DIR, { recursive: true });
  const bundle = lib.loadDjL10nBundle();
  const codes = lib.listLocaleCodes(bundle);
  let count = 0;
  for (const code of codes) {
    const data = bundle[code];
    if (!data || typeof data !== 'object') continue;
    const outPath = path.join(lib.BABEL_LOCALES_DIR, `${code}.json`);
    fs.writeFileSync(outPath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
    count += 1;
    console.log('  ✓', outPath);
  }
  console.log(`\nDJ-Export fertig: ${count} Dateien nach public/dj/babel/locales/`);
  console.log('BabelEdit: Ordner „public/dj/babel/locales“, Quellsprache de.json.');
}

main();
