#!/usr/bin/env node
/**
 * Setzt time_style, hour12, time_suffix in l10n/languages.json.
 * Fokus: 18 Menü-Sprachen. `ar` bleibt vorbereitet, Einbau ins Menü später.
 * Quelle: Recherche (RAE, OQLF, GOST/ISO, nationale Typografie).
 */
const fs = require('fs');
const path = require('path');

const REGISTRY = path.join(__dirname, '../l10n/languages.json');

/** @type {Record<string, { time_style: string, hour12?: boolean, time_suffix?: string }>} */
const RULES = {
  de: { time_style: 'colon_suffix', time_suffix: ' Uhr' },
  nl: { time_style: 'colon_suffix', time_suffix: ' uur' },
  en: { time_style: 'intl_12', hour12: true },
  hi: { time_style: 'intl_12', hour12: true },
  ar: { time_style: 'intl_12', hour12: true },
  fr: { time_style: 'fr_h' },
  pt: { time_style: 'h_compact' },
  it: { time_style: 'h_compact' },
  es: { time_style: 'colon_suffix', time_suffix: ' h' },
  ru: { time_style: 'colon_suffix' },
  uk: { time_style: 'colon_suffix' },
  pl: { time_style: 'colon_suffix' },
  cs: { time_style: 'colon_suffix' },
  el: { time_style: 'colon_suffix' },
  tr: { time_style: 'colon_suffix' },
  sq: { time_style: 'colon_suffix' },
  vi: { time_style: 'colon_suffix' },
  zh: { time_style: 'colon_suffix' },
  ja: { time_style: 'ja_kanji' },
};

const registry = JSON.parse(fs.readFileSync(REGISTRY, 'utf8'));
for (const lang of registry.languages) {
  const code = lang.code;
  if (!code || !RULES[code]) continue;
  const r = RULES[code];
  lang.time_style = r.time_style;
  lang.time_suffix = r.time_suffix ?? '';
  if (r.hour12) lang.hour12 = true;
  else delete lang.hour12;
}
fs.writeFileSync(REGISTRY, JSON.stringify(registry, null, 2) + '\n', 'utf8');
console.log('✓ languages.json: alle', Object.keys(RULES).length, 'Sprachen mit Zeit-Regeln');
