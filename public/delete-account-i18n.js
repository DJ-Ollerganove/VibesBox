/**
 * delete-account-i18n.js – gleiche Sprach-Pipeline wie Root (index): /vb/lang/*.js + getEffectiveLangForMenu.
 */
(function () {
  'use strict';
  try {
    var u = new URLSearchParams(window.location.search || '');
    window.IS_DEBUG = u.get('x') === '99';
  } catch (e) {
    window.IS_DEBUG = false;
  }

  function normalizeLangScriptPath(url) {
    try {
      var s = String(url || '').split('?')[0];
      if (s.indexOf('://') >= 0) {
        var a = document.createElement('a');
        a.href = s;
        return a.pathname || s;
      }
      return s;
    } catch (e2) {
      return String(url || '').split('?')[0];
    }
  }

  function findExistingLangScript(normalizedPath) {
    var scripts = document.head.querySelectorAll('script[src]');
    for (var i = 0; i < scripts.length; i++) {
      var src = scripts[i].getAttribute('src') || '';
      if (normalizeLangScriptPath(src) === normalizedPath) return scripts[i];
    }
    return null;
  }

  function loadLangScript(langCode, onDone, jsPath) {
    var bust = window.IS_DEBUG ? ('?v=' + Date.now()) : '';
    var scriptUrl = (jsPath && (jsPath.indexOf('/') !== -1 || jsPath.indexOf('.js') !== -1))
      ? (jsPath.indexOf('?') !== -1 ? jsPath : jsPath + bust)
      : '/vb/lang/' + langCode + '.js' + bust;
    var normPath = normalizeLangScriptPath(scriptUrl);
    function finishOk() {
      var obj = window['lang_' + langCode];
      if (!window.translations) window.translations = {};
      if (obj) window.translations[langCode] = obj;
      if (onDone) onDone();
    }
    var existing = findExistingLangScript(normPath);
    if (existing) {
      if (window['lang_' + langCode]) {
        finishOk();
        return;
      }
      existing.addEventListener('load', finishOk);
      existing.addEventListener('error', function () {
        if (onDone) onDone(new Error('Failed to load (existing tag): ' + normPath));
      });
      return;
    }
    var script = document.createElement('script');
    script.src = scriptUrl;
    script.onload = finishOk;
    script.onerror = function () {
      console.error('[i18n] Sprachdatei nicht geladen: ' + scriptUrl);
      if (onDone) onDone(new Error('Failed to load ' + scriptUrl));
    };
    document.head.appendChild(script);
  }

  function codesList() {
    var list = window.pwaAvailableLanguages && window.pwaAvailableLanguages.length ? window.pwaAvailableLanguages : [];
    return list.length ? list.map(function (e) { return e.code; })
      : ((window.DEFAULT_PWA_LANGUAGES && window.DEFAULT_PWA_LANGUAGES.length)
        ? window.DEFAULT_PWA_LANGUAGES.map(function (e) { return e.code; })
        : ['en', 'de', 'fr', 'ru', 'zh', 'es', 'tr', 'pt', 'it', 'uk', 'hi']);
  }

  function syncDeleteAccountDom(lang) {
    var t = (window.translations && window.translations[lang]) || (window.translations && window.translations['de']) || (window.translations && window.translations['en']) || {};
    if (lang) document.documentElement.lang = lang;
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      if (!key) return;
      if (t[key] != null && t[key] !== '') el.textContent = t[key];
    });
    document.querySelectorAll('[data-i18n-html]').forEach(function (el) {
      var key = el.getAttribute('data-i18n-html');
      if (!key) return;
      if (t[key] != null) el.innerHTML = t[key];
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(function (el) {
      var key = el.getAttribute('data-i18n-placeholder');
      if (!key) return;
      if (t[key] != null && t[key] !== '') el.placeholder = t[key];
    });
    document.querySelectorAll('[data-aria-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-aria-i18n');
      if (key && t[key] != null && t[key] !== '') el.setAttribute('aria-label', t[key]);
    });
    var mt = t['delete_account_meta_title'];
    if (mt != null && String(mt).trim() !== '') {
      var s = String(mt).trim();
      document.title = s.indexOf('VibesBox') !== -1 ? s : (s + ' – VibesBox');
    }
    var md = t['delete_account_meta_description'];
    var mEl = document.querySelector('meta[name="description"]');
    if (mEl && md != null && String(md).trim() !== '') mEl.setAttribute('content', String(md).trim());
  }

  window.updateMainContent = function () {
    var lang = (typeof window.getEffectiveLangForMenu === 'function') ? window.getEffectiveLangForMenu() : 'de';
    syncDeleteAccountDom(lang);
  };

  window.updatePageTitle = function () {
    window.updateMainContent();
  };

  window.getTranslation = function (key) {
    var lang = (typeof window.getEffectiveLangForMenu === 'function') ? window.getEffectiveLangForMenu() : 'de';
    var t = (window.translations && window.translations[lang]) || (window.translations && window.translations['de']) || {};
    return t[key] != null ? t[key] : key;
  };

  window.loadRootLanguage = function (lang, onDone) {
    if (!onDone) onDone = function () {};
    if (window.translations && window.translations[lang]) {
      onDone();
      return;
    }
    var jsPath = null;
    var plist = window.pwaAvailableLanguages && window.pwaAvailableLanguages.length ? window.pwaAvailableLanguages : (window.DEFAULT_PWA_LANGUAGES || []);
    var entry = plist.find(function (e) { return e.code === lang; });
    if (entry && entry.js_path) jsPath = entry.js_path;
    loadLangScript(lang, onDone, jsPath);
  };

  function startInit() {
    var codes = codesList();
    var initialLang = (typeof window.resolvePwaLanguage === 'function')
      ? window.resolvePwaLanguage(codes)
      : ((codes.indexOf('en') !== -1) ? 'en' : (codes[0] || 'en'));
    var list = window.pwaAvailableLanguages && window.pwaAvailableLanguages.length ? window.pwaAvailableLanguages : [];
    var forPath = list.length ? list : (window.DEFAULT_PWA_LANGUAGES || []);
    var pathEntry = forPath.find(function (e) { return e.code === initialLang; });
    var jsPath = (pathEntry && pathEntry.js_path) ? pathEntry.js_path : null;

    function finishBoot() {
      window.updateMainContent();
      if (typeof window.buildDatabaseLangMenu === 'function' && document.getElementById('langSwitcher')) {
        window.buildDatabaseLangMenu('langSwitcher', false);
      }
      try {
        window.dispatchEvent(new Event('translationsReady'));
      } catch (e3) {}
    }

    loadLangScript(initialLang, function (err) {
      if (err) {
        var fb = codes.indexOf('en') !== -1 ? 'en' : (codes[0] || 'en');
        loadLangScript(fb, function () {
          finishBoot();
        }, null);
        return;
      }
      finishBoot();
    }, jsPath);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startInit, { once: true });
  } else {
    startInit();
  }
})();
