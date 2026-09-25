#!/usr/bin/env node
/**
 * Importiert public/dj/babel/locales/*.json → public/dj/dj-l10n.js
 */
const fs = require('fs');
const path = require('path');
const lib = require('./dj-lang-lib');

function main() {
  const bundle = lib.loadDjL10nBundle();
  const master = bundle.de || bundle.en || {};
  const codes = new Set([
    ...lib.listLocaleCodes(bundle),
    ...fs.existsSync(lib.BABEL_LOCALES_DIR)
      ? fs.readdirSync(lib.BABEL_LOCALES_DIR)
        .filter((f) => /^[a-z]{2,3}\.json$/i.test(f))
        .map((f) => f.replace(/\.json$/i, '').toLowerCase())
      : [],
  ]);

  const out = {};
  for (const code of [...codes].sort()) {
    const jsonPath = path.join(lib.BABEL_LOCALES_DIR, `${code}.json`);
    if (!fs.existsSync(jsonPath)) {
      out[code] = bundle[code] || master;
      continue;
    }
    const locale = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const fillFrom = code === 'de' ? master : bundle.en || master;
    out[code] = lib.mergeWithMaster(master, locale, fillFrom);
  }

  lib.writeDjL10nBundle(out);
  console.log(`DJ-Import fertig: ${Object.keys(out).length} Sprachen → public/dj/dj-l10n.js`);
}

main();
