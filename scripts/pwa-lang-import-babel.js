#!/usr/bin/env node
/**
 * Importiert public/vb/babel/locales/*.json → public/vb/lang/*.js
 * und aktualisiert Registry + default-pwa-languages.js.
 */
const fs = require('fs');
const path = require('path');
const lib = require('./pwa-lang-lib');

function listLocaleJsonCodes() {
  if (!fs.existsSync(lib.BABEL_LOCALES_DIR)) return [];
  return fs
    .readdirSync(lib.BABEL_LOCALES_DIR)
    .filter((f) => /^[a-z]{2,3}\.json$/i.test(f))
    .map((f) => f.replace(/\.json$/i, '').toLowerCase());
}

function main() {
  const meta = lib.readMeta();
  const source = meta.sourceLanguage || 'de';
  const jsonCodes = listLocaleJsonCodes();
  if (!jsonCodes.includes(source)) {
    console.error(`Quellsprache ${source}.json fehlt in public/vb/babel/locales/`);
    process.exit(1);
  }

  const masterPath = path.join(lib.BABEL_LOCALES_DIR, `${source}.json`);
  const master = JSON.parse(fs.readFileSync(masterPath, 'utf8'));
  const masterKeys = Object.keys(master);

  let fillFrom = {};
  if (jsonCodes.includes('en')) {
    fillFrom = JSON.parse(
      fs.readFileSync(path.join(lib.BABEL_LOCALES_DIR, 'en.json'), 'utf8'),
    );
  }

  for (const code of jsonCodes.sort()) {
    lib.ensureMetaEntry(meta, code);
  }
  lib.writeMeta(meta);
  lib.injectLanguageNameKeys(master, meta);

  for (const code of jsonCodes.sort()) {
    const jsonPath = path.join(lib.BABEL_LOCALES_DIR, `${code}.json`);
    let locale = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    locale = lib.mergeWithMaster(master, locale, fillFrom);
    locale = lib.injectLanguageNameKeys(locale, meta);
    lib.writeLangJs(code, locale, masterKeys);
    console.log('  ✓ lang/' + code + '.js');
  }

  lib.writeDefaultPwaLanguagesJs(meta);
  console.log('  ✓ public/vb/scripts/default-pwa-languages.js');

  const missing = masterKeys.filter((k) => {
    for (const code of jsonCodes) {
      const p = path.join(lib.BABEL_LOCALES_DIR, `${code}.json`);
      const o = JSON.parse(fs.readFileSync(p, 'utf8'));
      if (o[k] === undefined || o[k] === '') return true;
    }
    return false;
  });
  if (missing.length) {
    console.warn('\n⚠ Fehlende/leere Keys (Stichprobe):', missing.slice(0, 8).join(', '));
    if (missing.length > 8) console.warn(`  … und ${missing.length - 8} weitere`);
  }

  console.log('\nImport fertig. Danach: firebase deploy --only hosting');
}

main();
