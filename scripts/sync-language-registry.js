#!/usr/bin/env node
/**
 * Quelle: l10n/languages.json
 * Erzeugt: PWA locale map, Sprachcodes, pwa-languages.json (Metadaten)
 * Danach: dart run tool/generate_language_registry.dart
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const lib = require('./pwa-lang-lib');

const ROOT = path.join(__dirname, '..');
const REGISTRY_PATH = path.join(ROOT, 'l10n/languages.json');
const PWA_META_PATH = path.join(ROOT, 'public/vb/babel/pwa-languages.json');
const GEN_DIR = path.join(ROOT, 'public/vb/scripts/generated');

function readRegistry() {
  return JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf8'));
}

function writePwaMeta(registry) {
  const languages = registry.languages
    .filter((e) => e.appMenu !== false)
    .map(({ code, name, icon, langKey }) => ({ code, name, icon, langKey }));
  const meta = {
    sourceLanguage: registry.sourceLanguage || 'de',
    excludeFromMenu: registry.excludeFromMenu || [],
    languages,
  };
  fs.writeFileSync(PWA_META_PATH, JSON.stringify(meta, null, 2) + '\n', 'utf8');
  console.log('  ✓ public/vb/babel/pwa-languages.json');
}

function writeGeneratedJs(registry) {
  fs.mkdirSync(GEN_DIR, { recursive: true });
  const map = {};
  const opts = {};
  const codes = [];
  const allowed = {};
  for (const e of registry.languages) {
    if (!e.code || !e.intl_locale) {
      console.warn('  ⚠ Eintrag ohne code/intl_locale übersprungen:', e);
      continue;
    }
    map[e.code] = e.intl_locale;
    const entry = {};
    if (e.hour12 === true) entry.hour12 = true;
    if (e.time_style) entry.time_style = String(e.time_style);
    if (e.time_suffix != null && String(e.time_suffix).length > 0) {
      entry.time_suffix = String(e.time_suffix);
    } else if (Object.prototype.hasOwnProperty.call(e, 'time_suffix')) {
      entry.time_suffix = '';
    }
    opts[e.code] = entry;
    if (e.appMenu !== false) {
      codes.push(e.code);
      allowed[e.code] = 1;
    }
  }

  const localeMapJs = `/** AUTO-GENERIERT — nicht bearbeiten. Quelle: l10n/languages.json · node scripts/sync-language-registry.js */
(function () {
  'use strict';
  window.PARTY_LOCALE_MAP = ${JSON.stringify(map, null, 2)};
})();
`;
  fs.writeFileSync(path.join(GEN_DIR, 'party-locale-map.js'), localeMapJs, 'utf8');
  console.log('  ✓ public/vb/scripts/generated/party-locale-map.js');

  const optsJs = `/** AUTO-GENERIERT — nicht bearbeiten. Quelle: l10n/languages.json */
(function () {
  'use strict';
  window.PARTY_LOCALE_OPTS = ${JSON.stringify(opts, null, 2)};
})();
`;
  fs.writeFileSync(path.join(GEN_DIR, 'party-locale-opts.js'), optsJs, 'utf8');
  console.log('  ✓ public/vb/scripts/generated/party-locale-opts.js');

  const codesJs = `/** AUTO-GENERIERT — nicht bearbeiten. Quelle: l10n/languages.json */
(function () {
  'use strict';
  window.PWA_STATIC_LANG_CODES = ${JSON.stringify(codes)};
  window.PWA_ALLOWED_LANG = ${JSON.stringify(allowed)};
})();
`;
  fs.writeFileSync(path.join(GEN_DIR, 'pwa-lang-codes.js'), codesJs, 'utf8');
  console.log('  ✓ public/vb/scripts/generated/pwa-lang-codes.js');
}

/** Inline-Fallback in party_shared.js mit Registry synchron halten. */
/** Gemini Grüße-Übersetzung: Sprachcodes + Labels aus derselben Quelle wie App/PWA. */
function writeGreetingLanguagesJs(registry) {
  const outDir = path.join(ROOT, 'functions/generated');
  fs.mkdirSync(outDir, { recursive: true });
  const codes = [];
  const labels = {};
  for (const e of registry.languages) {
    if (!e.code || !e.name) {
      console.warn('  ⚠ Gruß-Sprache ohne code/name übersprungen:', e);
      continue;
    }
    codes.push(e.code);
    labels[e.code] = String(e.name);
  }
  const content = `'use strict';
/** AUTO-GENERIERT — nicht bearbeiten. Quelle: l10n/languages.json · node scripts/sync-language-registry.js */

const GREETING_LANGUAGE_CODES = Object.freeze(${JSON.stringify(codes, null, 2)});

const GREETING_LANG_LABELS = Object.freeze(${JSON.stringify(labels, null, 2)});

const _greetingLangSet = new Set(GREETING_LANGUAGE_CODES);

/** Aliase → kanonischer Code (wie LocaleHelper.mapToSupportedOrEnglish). */
const GREETING_LANG_ALIASES = Object.freeze({
  ua: 'uk',
  al: 'sq',
  jp: 'ja',
  gr: 'el',
  cz: 'cs',
});

const _PREFIX_CANONICAL = [
  'zh', 'es', 'tr', 'pt', 'it', 'uk', 'hi', 'sq', 'vi', 'ja', 'el', 'nl', 'pl', 'cs',
];

/**
 * Normalisiert App-/Geräte-Locale auf einen Eintrag aus languages.json.
 * Unbekannt → en (Fallback für Gemini-Prompt).
 * @param {string} code
 * @returns {string}
 */
function normalizeGreetingLang(code) {
  const raw = String(code || '')
    .toLowerCase()
    .trim()
    .split(/[-_]/)[0];
  if (!raw) return 'en';
  if (raw === 'ar' || raw.startsWith('ar')) return 'en';
  let canonical = GREETING_LANG_ALIASES[raw] || raw;
  for (const prefix of _PREFIX_CANONICAL) {
    if (canonical.startsWith(prefix) && _greetingLangSet.has(prefix)) {
      return prefix;
    }
  }
  if (_greetingLangSet.has(canonical)) return canonical;
  return 'en';
}

module.exports = {
  GREETING_LANGUAGE_CODES,
  GREETING_LANG_LABELS,
  normalizeGreetingLang,
};
`;
  fs.writeFileSync(path.join(outDir, 'greeting_languages.js'), content, 'utf8');
  console.log('  ✓ functions/generated/greeting_languages.js (Gemini Grüße)');
}

function writePartySharedLocaleFallback(registry) {
  const sharedPath = path.join(ROOT, 'public/party_shared.js');
  let content = fs.readFileSync(sharedPath, 'utf8');
  const entries = registry.languages
    .filter((e) => e.code && e.intl_locale)
    .map((e) => `    ${e.code}: '${e.intl_locale}'`)
    .join(',\n');
  const block = `var PARTY_LOCALE_MAP = (typeof window !== 'undefined' && window.PARTY_LOCALE_MAP) ? window.PARTY_LOCALE_MAP : {\n${entries}\n  };`;
  const re = /var PARTY_LOCALE_MAP = \(typeof window[\s\S]*?\};\n\n  function getPartyLangCode/;
  if (!re.test(content)) {
    console.warn('  ⚠ party_shared.js: PARTY_LOCALE_MAP-Block nicht gefunden');
    return;
  }
  content = content.replace(re, `${block}\n\n  function getPartyLangCode`);
  fs.writeFileSync(sharedPath, content, 'utf8');
  console.log('  ✓ public/party_shared.js (PARTY_LOCALE_MAP Fallback)');
}

function main() {
  if (!fs.existsSync(REGISTRY_PATH)) {
    console.error('Fehlt:', REGISTRY_PATH);
    process.exit(1);
  }
  const registry = readRegistry();
  console.log('=== Sprach-Registry → PWA/JS ===');
  writePwaMeta(registry);
  lib.writeDefaultPwaLanguagesJs(JSON.parse(fs.readFileSync(PWA_META_PATH, 'utf8')));
  console.log('  ✓ public/vb/scripts/default-pwa-languages.js');
  writeGeneratedJs(registry);
  writeGreetingLanguagesJs(registry);
  writePartySharedLocaleFallback(registry);
  console.log('=== Sprach-Registry → Dart ===');
  execSync('dart run tool/generate_language_registry.dart', {
    cwd: ROOT,
    stdio: 'inherit',
  });
  console.log('\nRegistry-Sync fertig.');
}

main();
