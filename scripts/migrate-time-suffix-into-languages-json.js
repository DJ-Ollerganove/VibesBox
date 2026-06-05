#!/usr/bin/env node
/**
 * Einmalig / bei Bedarf: time_suffix aus app_*.arb → l10n/languages.json
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const REGISTRY_PATH = path.join(ROOT, 'l10n/languages.json');
const ARB_DIR = path.join(ROOT, 'l10n');

function readArbTimeSuffix(code) {
  const arbPath = path.join(ARB_DIR, `app_${code}.arb`);
  if (!fs.existsSync(arbPath)) return '';
  const raw = fs.readFileSync(arbPath, 'utf8');
  const m = raw.match(/"time_suffix"\s*:\s*"((?:\\.|[^"\\])*)"/);
  if (!m) return '';
  return JSON.parse(`"${m[1]}"`);
}

const registry = JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf8'));
for (const lang of registry.languages) {
  const code = lang.code;
  if (!code) continue;
  lang.time_suffix = readArbTimeSuffix(code);
}
fs.writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2) + '\n', 'utf8');
console.log('✓ time_suffix in l10n/languages.json aus ARB übernommen');
