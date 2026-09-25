#!/usr/bin/env node
/**
 * Nachlaufzeit-Keys aus l10n/app_*.arb → public/dj/babel/locales/*.json
 * Danach: node scripts/dj-lang-import-babel.js
 */
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.join(__dirname, '..');
const ARB_DIR = path.join(REPO_ROOT, 'l10n');
const BABEL_DIR = path.join(REPO_ROOT, 'public/dj/babel/locales');

const GRACE_KEYS = [
  'party_grace_countdown_wishes_still',
  'party_status_grace_period',
  'party_hour',
  'party_hours',
  'party_minute',
  'party_minutes',
  'party_status_less_than_minute',
];

function readArb(code) {
  const file = path.join(ARB_DIR, `app_${code}.arb`);
  if (!fs.existsSync(file)) return {};
  const raw = fs.readFileSync(file, 'utf8');
  const out = {};
  const re = /^\t"([^"@][^"]*)"\s*:\s*"((?:\\.|[^"\\])*)"\s*,?\s*$/gm;
  let m;
  while ((m = re.exec(raw)) !== null) {
    try {
      out[m[1]] = JSON.parse(`"${m[2]}"`);
    } catch {
      /* skip malformed */
    }
  }
  return out;
}

function main() {
  const localeFiles = fs.readdirSync(BABEL_DIR)
    .filter((f) => /^[a-z]{2,3}\.json$/i.test(f));
  let updated = 0;

  for (const file of localeFiles) {
    const code = file.replace(/\.json$/i, '').toLowerCase();
    const jsonPath = path.join(BABEL_DIR, file);
    const locale = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const arb = readArb(code);
    let changed = false;

    for (const key of GRACE_KEYS) {
      const value = arb[key];
      if (typeof value === 'string' && value.length > 0 && locale[key] !== value) {
        locale[key] = value;
        changed = true;
      }
    }

    if (changed) {
      const sorted = Object.fromEntries(
        Object.keys(locale).sort().map((k) => [k, locale[k]]),
      );
      fs.writeFileSync(jsonPath, `${JSON.stringify(sorted, null, 2)}\n`, 'utf8');
      updated += 1;
      console.log(`  ${code}: grace keys aktualisiert`);
    }
  }

  console.log(`sync-dj-party-grace-l10n: ${updated}/${localeFiles.length} Locale-Dateien geändert`);
}

main();
