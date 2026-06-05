#!/usr/bin/env node
/**
 * PWA: party_start_at aus l10n/app_*.arb + time_format_clock auf "{time}" (wie App, ohne Extra-Wörter).
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const BABEL_DIR = path.join(ROOT, 'public/vb/babel/locales');
const ARB_DIR = path.join(ROOT, 'l10n');

function readArbString(code, key) {
  const arbPath = path.join(ARB_DIR, `app_${code}.arb`);
  if (!fs.existsSync(arbPath)) return null;
  const raw = fs.readFileSync(arbPath, 'utf8');
  const re = new RegExp(`"${key}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`);
  const m = raw.match(re);
  if (!m) return null;
  return JSON.parse(`"${m[1]}"`);
}

const files = fs.readdirSync(BABEL_DIR).filter((f) => f.endsWith('.json'));
for (const file of files) {
  const code = file.replace(/\.json$/, '');
  const jsonPath = path.join(BABEL_DIR, file);
  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  const partyStartAt = readArbString(code, 'party_start_at');
  if (partyStartAt) {
    data.party_start_at = partyStartAt;
  }
  const timeSuffix = readArbString(code, 'time_suffix');
  if (timeSuffix !== null) {
    data.time_suffix = timeSuffix;
  }
  data.time_format_clock = '{time}';
  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2) + '\n', 'utf8');
  console.log('  ✓', file, partyStartAt ? '+ party_start_at' : '(party_start_at fehlt in ARB)');
}

console.log('\nAls Nächstes: node scripts/pwa-lang-import-babel.js');
