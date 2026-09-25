#!/usr/bin/env node
/**
 * DJ-Browser: dj-l10n.js ↔ public/dj/babel/locales/*.json (BabelEdit).
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const REPO_ROOT = path.join(__dirname, '..');
const DJ_L10N_PATH = path.join(REPO_ROOT, 'public/dj/dj-l10n.js');
const DJ_L10N_DATA_PATH = path.join(REPO_ROOT, 'public/dj/l10n-data.js');
const BABEL_LOCALES_DIR = path.join(REPO_ROOT, 'public/dj/babel/locales');

const IIFE_FOOTER = `(function () {
  var FALLBACK_DE = __FALLBACK_DE__;
  var FALLBACK_EN = __FALLBACK_EN__;
  var LOGIN_IDS = {
    'login-subtitle': 'dj_browser_login_subtitle',
    'login-title': 'dj_browser_login_title',
    'login-hint': 'dj_browser_login_hint',
    'login-code-label': 'dj_browser_login_code_label',
    'login-loading-text': 'dj_browser_loading',
  };

  function detectLocale() {
    if (typeof window.getEffectiveLangForMenu === 'function') {
      return window.getEffectiveLangForMenu();
    }
    var L = window.DJ_BROWSER_L10N || {};
    var raw = (navigator.language || 'en').slice(0, 2).toLowerCase();
    if (L[raw]) return raw;
    if (L.en) return 'en';
    if (L.de) return 'de';
    return 'en';
  }

  function translate(key, locale) {
    var L = window.DJ_BROWSER_L10N || {};
    var loc = locale || window.djBrowserLocale || 'en';
    var pack = L[loc] || {};
    if (pack[key]) return pack[key];
    if (L.en && L.en[key]) return L.en[key];
    if (loc === 'de' && FALLBACK_DE[key]) return FALLBACK_DE[key];
    if (FALLBACK_EN[key]) return FALLBACK_EN[key];
    return '';
  }

  function applyLoginLabels(locale) {
    var loc = locale || window.djBrowserLocale || detectLocale();
    Object.keys(LOGIN_IDS).forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.textContent = translate(LOGIN_IDS[id], loc);
    });
    document.documentElement.lang = loc;
    document.title = translate('dj_browser_login_title', loc) + ' DJ';
  }

  window.djBrowserSetLocale = function (code) {
    window.djBrowserLocale = code;
    applyLoginLabels(code);
  };
  window.djBrowserLocale = detectLocale();
  window.djBrowserT = function (key) {
    return translate(key, window.djBrowserLocale);
  };
  window.djBrowserApplyLoginL10n = applyLoginLabels;
  applyLoginLabels(window.djBrowserLocale);
})();
`;

function loadDjL10nBundle() {
  if (!fs.existsSync(DJ_L10N_PATH)) {
    throw new Error(`Fehlt: ${DJ_L10N_PATH}`);
  }
  const src = fs.readFileSync(DJ_L10N_PATH, 'utf8');
  const start = src.indexOf('window.DJ_BROWSER_L10N');
  const iifeStart = start >= 0 ? src.indexOf('(function () {', start) : -1;
  const objSrc = iifeStart > start
    ? `${src.slice(start, iifeStart).trim().replace(/\s+$/, '')};`
    : src;
  const sandbox = { window: {} };
  vm.runInContext(objSrc, vm.createContext(sandbox));
  const data = sandbox.window.DJ_BROWSER_L10N;
  if (!data || typeof data !== 'object') {
    throw new Error('Kein window.DJ_BROWSER_L10N in dj-l10n.js');
  }
  return data;
}

function listLocaleCodes(bundle) {
  return Object.keys(bundle || {}).filter((code) => /^[a-z]{2,3}$/i.test(code)).sort();
}

function mergeWithMaster(master, locale, fillFrom) {
  return { ...fillFrom, ...locale };
}

function writeDjL10nBundle(allLocales) {
  const de = allLocales.de || allLocales.en || {};
  const en = allLocales.en || de;
  const body = [
    '// DJ-Browser Übersetzungen — Quelle für BabelEdit: public/dj/babel/locales/*.json',
    '// Generiert: scripts/dj-lang-import-babel.js',
    `window.DJ_BROWSER_L10N = ${JSON.stringify(allLocales, null, 2)};`,
    IIFE_FOOTER
      .replace('__FALLBACK_DE__', JSON.stringify(de))
      .replace('__FALLBACK_EN__', JSON.stringify(en)),
    '',
  ].join('\n');
  fs.writeFileSync(DJ_L10N_PATH, body, 'utf8');
  fs.writeFileSync(
    DJ_L10N_DATA_PATH,
    `window.DJ_BROWSER_L10N = ${JSON.stringify(allLocales, null, 2)};\n`,
    'utf8',
  );
}

module.exports = {
  REPO_ROOT,
  DJ_L10N_PATH,
  BABEL_LOCALES_DIR,
  loadDjL10nBundle,
  listLocaleCodes,
  mergeWithMaster,
  writeDjL10nBundle,
};
