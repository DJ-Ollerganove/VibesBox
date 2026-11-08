(function () {
  var SYNC_LANG_ASSET_V = '20261108sync2';
  var syncVersions = { windows: '', mac: '' };

  function packFor(lang) {
    var all = window.translations || {};
    return all[lang] || all.en || {};
  }

  function currentLang() {
    if (typeof window.getEffectiveLangForMenu === 'function') return window.getEffectiveLangForMenu();
    return 'en';
  }

  function renderVersions() {
    var tpl = packFor(currentLang()).sync_page_version || 'Version {version}';
    function set(id, num) {
      var el = document.getElementById(id);
      if (!el) return;
      el.textContent = String(tpl).replace('{version}', num || '…');
    }
    set('win-ver', syncVersions.windows);
    set('mac-ver', syncVersions.mac);
  }

  function applySyncPage() {
    var lang = currentLang();
    if (typeof window.pwaApplyTextDirection === 'function') window.pwaApplyTextDirection(lang);
    var t = packFor(lang);
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      if (key && t[key] != null && t[key] !== '') el.textContent = t[key];
    });
    document.querySelectorAll('[data-i18n-alt]').forEach(function (el) {
      var key = el.getAttribute('data-i18n-alt');
      if (key && t[key] != null && t[key] !== '') el.setAttribute('alt', t[key]);
    });
    var meta = document.querySelector('meta[name="description"]');
    if (meta && t.sync_page_meta_description) meta.setAttribute('content', t.sync_page_meta_description);
    if (t.sync_page_title) document.title = t.sync_page_title;
    renderVersions();
    var label = t.select_language || '';
    var sw = document.getElementById('langSwitcher');
    if (sw && label) sw.setAttribute('aria-label', label);
    if (typeof window.buildDatabaseLangMenu === 'function') {
      window.buildDatabaseLangMenu('langSwitcher', false);
    }
    var btn = document.getElementById('mainLangBtn');
    if (btn && label) btn.setAttribute('aria-label', label);
    if (typeof window.refreshLangMenuChromeLabels === 'function') window.refreshLangMenuChromeLabels();
  }

  window.updateMainContent = applySyncPage;
  window.translatePage = applySyncPage;
  window.getTranslation = function (key) {
    var t = packFor(currentLang());
    if (key && t[key] != null && t[key] !== '') return t[key];
    var en = (window.translations && window.translations.en) || {};
    if (key && en[key] != null && en[key] !== '') return en[key];
    return '';
  };

  function finishLang(langCode) {
    var obj = window['lang_' + langCode];
    if (!window.translations) window.translations = {};
    if (obj) window.translations[langCode] = obj;
  }

  function loadLangScript(langCode, onDone) {
    if (window.translations && window.translations[langCode]) {
      if (onDone) onDone();
      return;
    }
    if (window['lang_' + langCode]) {
      finishLang(langCode);
      if (onDone) onDone();
      return;
    }
    var script = document.createElement('script');
    script.src = '/vb/lang/' + langCode + '.js?v=' + SYNC_LANG_ASSET_V;
    script.onload = function () {
      finishLang(langCode);
      if (onDone) onDone();
    };
    script.onerror = function () {
      if (onDone) onDone(new Error('lang'));
    };
    document.head.appendChild(script);
  }

  window.loadRootLanguage = function (lang, onDone) {
    if (!onDone) onDone = function () {};
    loadLangScript(lang, function (err) { onDone(err); });
  };

  function codes() {
    var list = window.pwaAvailableLanguages && window.pwaAvailableLanguages.length
      ? window.pwaAvailableLanguages
      : (window.DEFAULT_PWA_LANGUAGES || []);
    return list.map(function (e) { return e.code; }).filter(Boolean);
  }

  function boot() {
    var list = codes();
    var initial = (typeof window.resolvePwaLanguage === 'function')
      ? window.resolvePwaLanguage(list)
      : 'en';
    loadLangScript(initial, function (err) {
      if (err && initial !== 'en') {
        loadLangScript('en', function () { applySyncPage(); });
        return;
      }
      applySyncPage();
    });
  }

  if (document.getElementById('win-ver')) {
    fetch('/sync/version.json?_=' + Date.now(), { cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .then(function (v) {
        if (v && v.windows) syncVersions.windows = String(v.windows);
        if (v && v.mac) syncVersions.mac = String(v.mac);
        renderVersions();
      })
      .catch(function () { renderVersions(); });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
