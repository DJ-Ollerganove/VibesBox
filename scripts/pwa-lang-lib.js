#!/usr/bin/env node
/**
 * Gemeinsame Hilfen: PWA lang/*.js ↔ JSON (BabelEdit).
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const REPO_ROOT = path.join(__dirname, '..');
const LANG_JS_DIR = path.join(REPO_ROOT, 'public/vb/lang');
const BABEL_LOCALES_DIR = path.join(REPO_ROOT, 'public/vb/babel/locales');
const META_PATH = path.join(REPO_ROOT, 'public/vb/babel/pwa-languages.json');
const DEFAULT_PWA_JS = path.join(REPO_ROOT, 'public/vb/scripts/default-pwa-languages.js');

const AUTO_LANG_META = {
  pl: { name: 'Polish', icon: 'pl', langKey: 'lang_polish' },
  nl: { name: 'Dutch', icon: 'nl', langKey: 'lang_dutch' },
  ja: { name: 'Japanese', icon: 'ja', langKey: 'lang_japanese' },
  ko: { name: 'Korean', icon: 'ko', langKey: 'lang_korean' },
  sv: { name: 'Swedish', icon: 'sv', langKey: 'lang_swedish' },
  da: { name: 'Danish', icon: 'da', langKey: 'lang_danish' },
  no: { name: 'Norwegian', icon: 'no', langKey: 'lang_norwegian' },
  cs: { name: 'Czech', icon: 'cs', langKey: 'lang_czech' },
  ro: { name: 'Romanian', icon: 'ro', langKey: 'lang_romanian' },
  el: { name: 'Greek', icon: 'el', langKey: 'lang_greek' },
  he: { name: 'Hebrew', icon: 'he', langKey: 'lang_hebrew' },
  ar: { name: 'Arabic', icon: 'ar', langKey: 'lang_arabic' },
  sq: { name: 'Albanian', icon: 'sq', langKey: 'lang_albanian' },
  vi: { name: 'Vietnamese', icon: 'vi', langKey: 'lang_vietnamese' },
  th: { name: 'Thai', icon: 'th', langKey: 'lang_thai' },
};

function readMeta() {
  return JSON.parse(fs.readFileSync(META_PATH, 'utf8'));
}

function writeMeta(meta) {
  fs.writeFileSync(META_PATH, JSON.stringify(meta, null, 2) + '\n', 'utf8');
}

function listLangJsCodes() {
  if (!fs.existsSync(LANG_JS_DIR)) return [];
  return fs
    .readdirSync(LANG_JS_DIR)
    .filter((f) => /^[a-z]{2,3}\.js$/i.test(f))
    .map((f) => f.replace(/\.js$/i, '').toLowerCase());
}

function loadLangJs(code) {
  const filePath = path.join(LANG_JS_DIR, `${code}.js`);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Fehlt: ${filePath}`);
  }
  let src = fs.readFileSync(filePath, 'utf8');
  // Legacy-Zeile „window.lang_xx = lang_xx“ (lang_xx nie als Variable) — würde Objekt überschreiben.
  src = src.replace(/\nif\s*\(\s*typeof\s+window\s*!==\s*['"]undefined['"]\s*\)[\s\S]*$/m, '');
  const sandbox = { window: {} };
  vm.runInContext(src, vm.createContext(sandbox));
  const data = sandbox.window[`lang_${code}`];
  if (!data || typeof data !== 'object') {
    throw new Error(`Kein window.lang_${code} in ${filePath}`);
  }
  return data;
}

function writeLangJs(code, data, orderedKeys) {
  const keys = orderedKeys || Object.keys(data);
  const lines = [
    `// PWA Übersetzungen: ${code}`,
    `// Generiert: scripts/pwa-lang-import-babel.js — in BabelEdit nur public/vb/babel/locales/${code}.json bearbeiten.`,
    `window.lang_${code} = {`,
  ];
  for (const key of keys) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) continue;
    const val = data[key];
    lines.push(`  ${JSON.stringify(key)}: ${JSON.stringify(String(val ?? ''))},`);
  }
  lines.push('};');
  lines.push('');
  const filePath = path.join(LANG_JS_DIR, `${code}.js`);
  fs.writeFileSync(filePath, lines.join('\n'), 'utf8');
}

function sortLanguagesByEnglishName(languages) {
  return [...languages].sort((a, b) =>
    String(a.name || a.code).localeCompare(String(b.name || b.code), 'en'),
  );
}

function ensureMetaEntry(meta, code) {
  const c = code.toLowerCase();
  let entry = meta.languages.find((e) => e.code === c);
  if (entry) return entry;
  const auto = AUTO_LANG_META[c] || {
    name: c.toUpperCase(),
    icon: c,
    langKey: `lang_${c}`,
  };
  entry = { code: c, name: auto.name, icon: auto.icon, langKey: auto.langKey };
  meta.languages.push(entry);
  return entry;
}

function buildLanguageNameKeys(meta) {
  const out = {};
  for (const e of meta.languages) {
    if (e.code && e.langKey) out[e.code] = e.langKey;
  }
  return out;
}

function writeDefaultPwaLanguagesJs(meta) {
  const exclude = new Set(meta.excludeFromMenu || []);
  const sorted = sortLanguagesByEnglishName(meta.languages);
  const nameKeys = buildLanguageNameKeys(meta);
  const lines = [
    '/**',
    ' * Lokale Sprachliste für PWA & Erdkugel-Menü (kein Firestore).',
    ' * AUTO-GENERIERT — nicht von Hand editieren.',
    ' * Quelle: public/vb/babel/pwa-languages.json',
    ' * Erzeugen: node scripts/pwa-lang-sync-registry.js',
    ' */',
    '(function () {',
    '  window.DEFAULT_PWA_LANGUAGES = [',
  ];
  for (const e of sorted) {
    const jsPath = `/vb/lang/${e.code}.js`;
    lines.push(
      `    { code: ${JSON.stringify(e.code)}, name: ${JSON.stringify(e.name)}, icon: ${JSON.stringify(e.icon || e.code)}, js_path: ${JSON.stringify(jsPath)} },`,
    );
  }
  lines.push('  ];');
  lines.push('  var _pwaLangExclude = ' + JSON.stringify([...exclude]) + ';');
  lines.push('  window.pwaAvailableLanguages = window.DEFAULT_PWA_LANGUAGES.filter(function (e) {');
  lines.push('    return e && e.code && _pwaLangExclude.indexOf(e.code) === -1;');
  lines.push('  });');
  lines.push('  window.PWA_LANGUAGE_NAME_KEYS = ' + JSON.stringify(nameKeys, null, 4).replace(/\n/g, '\n  ') + ';');
  lines.push('})();');
  lines.push('');
  fs.writeFileSync(DEFAULT_PWA_JS, lines.join('\n'), 'utf8');
}

function mergeWithMaster(master, locale, fillFrom) {
  const out = { ...fillFrom, ...locale };
  for (const key of Object.keys(master)) {
    if (!Object.prototype.hasOwnProperty.call(out, key)) {
      out[key] = master[key];
    }
  }
  return out;
}

function injectLanguageNameKeys(data, meta) {
  for (const e of meta.languages) {
    if (e.langKey && e.name) {
      data[e.langKey] = e.name;
    }
  }
  return data;
}

module.exports = {
  REPO_ROOT,
  LANG_JS_DIR,
  BABEL_LOCALES_DIR,
  META_PATH,
  readMeta,
  writeMeta,
  listLangJsCodes,
  loadLangJs,
  writeLangJs,
  ensureMetaEntry,
  writeDefaultPwaLanguagesJs,
  mergeWithMaster,
  injectLanguageNameKeys,
  sortLanguagesByEnglishName,
};
