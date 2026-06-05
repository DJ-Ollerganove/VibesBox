#!/usr/bin/env node
/**
 * Quelle: l10n/languages.json (time_suffix pro Sprache)
 * Ziele: l10n/app_*.arb, public/vb/babel/locales/*.json → danach pwa-lang-import
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const REGISTRY_PATH = path.join(ROOT, 'l10n/languages.json');
const ARB_DIR = path.join(ROOT, 'l10n');
const BABEL_DIR = path.join(ROOT, 'public/vb/babel/locales');

function upsertArbKey(filePath, key, value) {
  if (!fs.existsSync(filePath)) return false;
  let raw = fs.readFileSync(filePath, 'utf8');
  const escaped = JSON.stringify(value).slice(1, -1);
  const line = `\t"${key}": "${escaped}",`;
  const re = new RegExp(`"${key}"\\s*:\\s*"(?:\\\\.|[^"\\\\])*"\\s*,?`, 'm');
  if (re.test(raw)) {
    raw = raw.replace(re, `"${key}": "${escaped}",`);
  } else {
    const insertRe = /(\n\s*"@@locale"\s*:\s*"[^"]+"\s*,?\n)/;
    if (insertRe.test(raw)) {
      raw = raw.replace(insertRe, `$1${line}\n`);
    } else {
      raw = raw.replace(/\{\s*\n/, `{\n${line}\n`);
    }
  }
  fs.writeFileSync(filePath, raw, 'utf8');
  return true;
}

const registry = JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf8'));
let arbCount = 0;
let jsonCount = 0;

for (const lang of registry.languages) {
  const code = lang.code;
  if (!code || !Object.prototype.hasOwnProperty.call(lang, 'time_suffix')) continue;
  const suffix = lang.time_suffix == null ? '' : String(lang.time_suffix);

  const arbPath = path.join(ARB_DIR, `app_${code}.arb`);
  if (upsertArbKey(arbPath, 'time_suffix', suffix)) arbCount++;

  const jsonPath = path.join(BABEL_DIR, `${code}.json`);
  if (fs.existsSync(jsonPath)) {
    const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    data.time_suffix = suffix;
    data.time_format_clock = '{time}';
    fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2) + '\n', 'utf8');
    jsonCount++;
  }
}

console.log(`✓ time_suffix → ${arbCount} ARB, ${jsonCount} babel JSON`);
execSync('node scripts/pwa-lang-import-babel.js', { cwd: ROOT, stdio: 'inherit' });
