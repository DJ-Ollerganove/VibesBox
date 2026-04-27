/**
 * VibesBox /vb/ — gleiche Auflösung wie lang_menu_shared.js:
 * (1) Live-URL ?lang= absolut, (2) Manual, (3) Speicher, (4) Browsersprache nur wenn unterstützt,
 * (5) Fallback en (niemals de als automatischer Ersatz bei unbekannter Browser-Sprache).
 */
(function () {
  'use strict';

  var DEFAULT_LANG = 'en';
  var ALLOWED = { de: 1, en: 1, fr: 1, ru: 1, zh: 1, es: 1, tr: 1, pt: 1, it: 1, uk: 1, hi: 1 };
  var STATIC_PWA_LANG_CODES = ['en', 'de', 'fr', 'ru', 'zh', 'es', 'tr', 'pt', 'it', 'uk', 'hi'];
  var REGION_TO_LANG = { de: 'de', at: 'de', ch: 'de', fr: 'fr', es: 'es', it: 'it', ru: 'ru', tr: 'tr', pt: 'pt', br: 'pt', zh: 'zh', cn: 'zh', tw: 'zh', ua: 'uk', in: 'hi', ar: 'ar', sa: 'ar', eg: 'ar' };
  var PERMANENT_LOCALE_KEY = 'permanent_user_locale';
  var VB_ENTRY_LANG_KEY = 'vb_entry_lang';
  var LANGUAGE_NAMES = { de: 'German', en: 'English', fr: 'French', ru: 'Russian', zh: 'Chinese', es: 'Spanish', tr: 'Turkish', pt: 'Portuguese', it: 'Italian', uk: 'Ukrainian', hi: 'Hindi' };

  window.IS_DEBUG = new URLSearchParams(window.location.search || '').get('x') === '99';

  function normalizeCode(raw) {
    if (!raw) return '';
    var v = String(raw).trim().toLowerCase();
    if (!v || v === 'ar') return '';
    if (v.length > 2 && v.charAt(2) === '-') v = v.slice(0, 2);
    return ALLOWED[v] ? v : '';
  }

  function urlLangSupportedForPwa(code, codes) {
    if (!code) return false;
    if (codes.indexOf(code) !== -1) return true;
    return STATIC_PWA_LANG_CODES.indexOf(code) !== -1;
  }

  function effectiveCodes() {
    var list = window.pwaAvailableLanguages && window.pwaAvailableLanguages.length ? window.pwaAvailableLanguages : [];
    list = list.filter(function (e) { return e && e.code && e.code !== 'ar'; });
    if (list.length) return list.map(function (e) { return e.code; });
    var d = window.DEFAULT_PWA_LANGUAGES;
    if (d && d.length) return d.map(function (e) { return e.code; });
    return STATIC_PWA_LANG_CODES.slice();
  }

  function readStoredLanguage() {
    var candidates = [];
    try {
      candidates.push((window.localStorage.getItem('pwa_language') || '').trim());
      candidates.push((window.localStorage.getItem('language') || '').trim());
      candidates.push((window.localStorage.getItem(PERMANENT_LOCALE_KEY) || '').trim());
      candidates.push((window.sessionStorage.getItem('pwa_language') || '').trim());
      candidates.push((window.sessionStorage.getItem('selected_language') || '').trim());
      candidates.push((window.sessionStorage.getItem('user_language') || '').trim());
      candidates.push((window.sessionStorage.getItem('app_locale') || '').trim());
      candidates.push((window.sessionStorage.getItem('language') || '').trim());
      candidates.push((window.localStorage.getItem('selected_language') || '').trim());
      candidates.push((window.localStorage.getItem('user_language') || '').trim());
      candidates.push((window.localStorage.getItem('app_locale') || '').trim());
    } catch (e) {}
    for (var i = 0; i < candidates.length; i++) {
      if (candidates[i]) return candidates[i];
    }
    return '';
  }

  function isManualLanguageLocked() {
    try {
      return window.localStorage.getItem('pwa_language_manual') === '1' || window.sessionStorage.getItem('pwa_language_manual') === '1';
    } catch (e) {
      return false;
    }
  }

  function readManualStoredLanguageIfValid(codes) {
    if (!isManualLanguageLocked()) return '';
    var s = readStoredLanguage();
    if (s === 'ar') return '';
    if (s && codes.indexOf(s) !== -1) return s;
    return '';
  }

  function readLocalStorageRootLanguage(codes) {
    try {
      var keys = ['pwa_language', 'language', PERMANENT_LOCALE_KEY];
      for (var i = 0; i < keys.length; i++) {
        var v = (window.localStorage.getItem(keys[i]) || '').trim();
        if (v && v !== 'ar' && codes.indexOf(v) !== -1) return v;
      }
    } catch (e) {}
    return '';
  }

  function pickBestLangFromNavigatorCodesLocal(codes) {
    var langs = [];
    try {
      if (typeof navigator.languages !== 'undefined' && navigator.languages && navigator.languages.length) {
        langs = Array.prototype.slice.call(navigator.languages);
      } else {
        langs = [navigator.language || navigator.userLanguage || ''];
      }
    } catch (e) {
      langs = [navigator.language || ''];
    }
    for (var i = 0; i < langs.length; i++) {
      var raw = String(langs[i] || '').toLowerCase();
      if (!raw) continue;
      var primary = raw.split('-')[0];
      var region = raw.indexOf('-') !== -1 ? raw.split('-').slice(1).join('-') : '';
      var code = primary;
      if (region && REGION_TO_LANG[region] && codes.indexOf(REGION_TO_LANG[region]) !== -1) code = REGION_TO_LANG[region];
      if (codes.indexOf(code) !== -1) return code;
    }
    return '';
  }

  if (typeof window.pickBestLangFromNavigatorCodes !== 'function') {
    window.pickBestLangFromNavigatorCodes = pickBestLangFromNavigatorCodesLocal;
  }

  function resolvePwaLanguageImpl(codes) {
    var live = readUrlLang();
    if (live === 'ar') live = '';
    if (live && urlLangSupportedForPwa(live, codes)) {
      window.persistUrlLanguageToAllStorage(live);
      return live;
    }

    var manual = readManualStoredLanguageIfValid(codes);
    if (manual) return manual;

    var fromLocalRoot = readLocalStorageRootLanguage(codes);
    if (fromLocalRoot) return fromLocalRoot;

    try {
      var fromRoot = (window.sessionStorage.getItem(VB_ENTRY_LANG_KEY) || '').trim().toLowerCase();
      if (fromRoot === 'ar') fromRoot = '';
      if (fromRoot && codes.indexOf(fromRoot) !== -1) return fromRoot;
    } catch (e) {}

    var autoStored = readStoredLanguage();
    if (autoStored && autoStored !== 'ar' && codes.indexOf(autoStored) !== -1) {
      return autoStored;
    }

    var browserPick =
      typeof window.pickBestLangFromNavigatorCodes === 'function'
        ? window.pickBestLangFromNavigatorCodes(codes)
        : pickBestLangFromNavigatorCodesLocal(codes);
    if (browserPick) return browserPick;

    if (codes.indexOf('en') !== -1) return 'en';
    return codes[0] || 'en';
  }

  function readUrlLang() {
    try {
      var sp = new URLSearchParams(window.location.search || '');
      var v = normalizeCode(sp.get('lang') || sp.get('locale') || '');
      if (v) return v;
      var combined = (window.location.search || '') + (window.location.hash || '');
      var m = /[?&#]lang=([a-z]{2})(?:-[a-z0-9]+)?/i.exec(combined);
      if (m) {
        v = normalizeCode(m[1]);
        if (v) return v;
      }
      m = /[?&#]locale=([a-z]{2})/i.exec(combined);
      if (m) {
        v = normalizeCode(m[1]);
        if (v) return v;
      }
      var hash = (window.location.hash || '').replace(/^#/, '');
      var qm = hash.indexOf('?');
      if (qm >= 0) {
        var hp = new URLSearchParams(hash.substring(qm + 1));
        v = normalizeCode(hp.get('lang') || hp.get('locale') || '');
        if (v) return v;
      }
    } catch (e) {}
    return '';
  }

  function resolvedLangForUi() {
    return window.__vbActiveLang || resolvePwaLanguageImpl(effectiveCodes());
  }

  window.readPwaUrlLangParam = readUrlLang;
  /** Vollständige Kette (URL zuerst); für vbGetResolvedPwaLanguageCode in app.js. */
  window.vbGetResolvedLangFromUrlOnly = function () {
    return resolvePwaLanguageImpl(effectiveCodes());
  };

  window.resolvePwaLanguage = function (codes) {
    var c = codes && codes.length ? codes : effectiveCodes();
    return resolvePwaLanguageImpl(c);
  };

  window.getEffectiveLangForMenu = function () {
    return resolvedLangForUi();
  };

  window.persistUrlLanguageToAllStorage = function (code) {
    var c = normalizeCode(code);
    if (!c) return;
    var codes = effectiveCodes();
    if (!urlLangSupportedForPwa(c, codes)) return;
    try {
      window.localStorage.removeItem('pwa_language_manual');
      window.sessionStorage.removeItem('pwa_language_manual');
    } catch (m) {}
    try {
      localStorage.setItem('pwa_language', c);
      localStorage.setItem('language', c);
      localStorage.setItem('permanent_user_locale', c);
      localStorage.setItem('selected_language', c);
      localStorage.setItem('user_language', c);
      localStorage.setItem('app_locale', c);
      sessionStorage.setItem('pwa_language', c);
      sessionStorage.setItem('language', c);
      sessionStorage.setItem('selected_language', c);
      sessionStorage.setItem('user_language', c);
      sessionStorage.setItem('app_locale', c);
    } catch (e) {}
    try {
      sessionStorage.setItem(VB_ENTRY_LANG_KEY, c);
    } catch (e2) {}
  };

  window.setVbPreferredLangForSession = function (code) {
    var c = normalizeCode(code);
    if (!c) return;
    try {
      sessionStorage.setItem('vb_entry_lang', c);
    } catch (e) {}
  };

  if (!window.translations) window.translations = {};

  function syncStorageToLang(code) {
    window.persistUrlLanguageToAllStorage(code);
    window.setVbPreferredLangForSession(code);
  }

  window.getTranslation = function (key) {
    var lang = resolvedLangForUi();
    var tr = window.translations || {};
    if (tr[lang] && tr[lang][key]) return tr[lang][key];
    if (tr[DEFAULT_LANG] && tr[DEFAULT_LANG][key]) return tr[DEFAULT_LANG][key];
    if (tr.de && tr.de[key]) return tr.de[key];
    return key || '';
  };

  window.translatePage = function () {
    try {
      var gt = window.getTranslation;
      document.querySelectorAll('[data-i18n]').forEach(function (el) {
        var key = el.getAttribute('data-i18n');
        if (!key) return;
        var tag = (el.tagName || '').toUpperCase();
        if (tag === 'INPUT' || tag === 'TEXTAREA') {
          el.placeholder = gt(key) || '';
        } else {
          el.textContent = gt(key) || '';
        }
      });
      document.querySelectorAll('[data-i18n-aria-label]').forEach(function (ael) {
        var akey = ael.getAttribute('data-i18n-aria-label');
        if (akey) {
          var atxt = gt(akey);
          if (atxt) ael.setAttribute('aria-label', atxt);
        }
      });
      document.querySelectorAll('[data-i18n-placeholder]').forEach(function (pel) {
        var pkey = pel.getAttribute('data-i18n-placeholder');
        if (pkey) {
          var ptxt = gt(pkey);
          if (ptxt) pel.setAttribute('placeholder', ptxt);
        }
      });
      document.documentElement.lang = resolvedLangForUi();
    } catch (e) {
      if (window.IS_DEBUG) console.warn('translatePage', e);
    }
  };

  window.updatePageTitle = function () {
    if (!window.translations || !window.__vbActiveLang) return;
    var lang = window.__vbActiveLang;
    var tmap = window.translations[lang] || window.translations[DEFAULT_LANG] || {};
    var inParty = !!(sessionStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyCode'));
    var djName = (sessionStorage.getItem('currentDjName') || '').trim();
    var title;
    if (inParty && djName) {
      title = (tmap.title_vb_party || 'VibesBox – {djName}').replace(/\{djName\}/g, djName);
    } else if (inParty) {
      title = tmap.title_vb_live || 'VibesBox – Live';
    } else {
      title = tmap.title_vb_join || 'VibesBox – Join the Party';
    }
    document.title = title;
  };

  window.applyTranslationsAndUI = function (code) {
    if (code && normalizeCode(code)) window.__vbActiveLang = normalizeCode(code);
    if (!window.__vbActiveLang) window.__vbActiveLang = resolvePwaLanguageImpl(effectiveCodes());
    syncStorageToLang(window.__vbActiveLang);
    window.translatePage();
    window.updatePageTitle();
    if (typeof window.updateDrawerCurrentLanguage === 'function') window.updateDrawerCurrentLanguage();
    window.dispatchEvent(new Event('translationsReady'));
  };

  function injectLangScript(code, onDone) {
    var url = '/vb/lang/' + code + '.js';
    var sel = 'script[data-vb-lang="' + code + '"]';
    var existing = document.head.querySelector(sel);
    if (existing && window['lang_' + code]) {
      window.translations[code] = window['lang_' + code];
      if (onDone) onDone(null);
      return;
    }
    if (existing && !window['lang_' + code]) {
      existing.addEventListener('load', function () {
        var obj = window['lang_' + code];
        if (obj) window.translations[code] = obj;
        if (onDone) onDone(obj ? null : new Error('empty'));
      });
      existing.addEventListener('error', function () {
        if (onDone) onDone(new Error('err'));
      });
      setTimeout(function () {
        if (window['lang_' + code]) return;
        var obj = window['lang_' + code];
        if (obj) window.translations[code] = obj;
        if (onDone) onDone(obj ? null : new Error('empty'));
      }, 0);
      return;
    }
    var s = document.createElement('script');
    s.src = url + (window.IS_DEBUG ? '?v=' + Date.now() : '');
    s.async = true;
    s.setAttribute('data-vb-lang', code);
    s.onload = function () {
      var obj = window['lang_' + code];
      if (obj) window.translations[code] = obj;
      if (onDone) onDone(obj ? null : new Error('empty'));
    };
    s.onerror = function () {
      if (onDone) onDone(new Error('err'));
    };
    document.head.appendChild(s);
  }

  window.pwaHotSwapLanguage = function (langCode, jsPath, onDone) {
    var code = normalizeCode(langCode);
    if (!code) {
      if (onDone) onDone();
      return;
    }
    injectLangScript(code, function (err) {
      if (err) {
        if (window.IS_DEBUG) console.warn('vb-url-lang: Paket', code, err);
        if (onDone) onDone(err);
        return;
      }
      window.__vbActiveLang = code;
      syncStorageToLang(code);
      try {
        var u = new URL(window.location.href);
        u.searchParams.set('lang', code);
        window.history.replaceState({}, document.title, u.pathname + u.search + u.hash);
      } catch (e2) {}
      window.applyTranslationsAndUI(code);
      if (onDone) onDone();
    });
  };

  function logVisit(code) {
    try {
      var today = new Date();
      var key = 'language_stats_date';
      var ds = today.getFullYear() + '-' + String(today.getMonth() + 1).padStart(2, '0') + '-' + String(today.getDate()).padStart(2, '0');
      if (localStorage.getItem(key) === ds) return;
      localStorage.setItem(key, ds);
      var langName = LANGUAGE_NAMES[code] || code;
      fetch('https://us-central1-dj-ollerganove.cloudfunctions.net/recordLanguageHit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ languageCode: code, languageName: langName, source: 'vb' })
      }).catch(function () {});
    } catch (e) {}
  }

  function finishInit(code) {
    window.__vbActiveLang = code;
    var obj = window['lang_' + code];
    if (obj) window.translations[code] = obj;
    syncStorageToLang(code);
    window.translatePage();
    window.updatePageTitle();
    if (typeof window.updateDrawerCurrentLanguage === 'function') window.updateDrawerCurrentLanguage();
    window.dispatchEvent(new Event('translationsReady'));
    logVisit(code);
  }

  function runInit() {
    var want = resolvePwaLanguageImpl(effectiveCodes());
    injectLangScript(want, function (err) {
      if (!err && window['lang_' + want]) {
        finishInit(want);
        return;
      }
      if (want !== DEFAULT_LANG) {
        injectLangScript(DEFAULT_LANG, function (e2) {
          finishInit(DEFAULT_LANG);
        });
      } else {
        finishInit(DEFAULT_LANG);
      }
    });
  }

  window.startVBPageInit = function () {
    runInit();
  };

  function getFlagIconId(entry) {
    if (!entry) return 'globe';
    var iconRaw = entry.icon != null ? String(entry.icon).trim() : '';
    return iconRaw !== '' ? iconRaw : (entry.code ? String(entry.code).trim() : 'globe');
  }

  function buildDatabaseLangMenu(containerId, isModal) {
    var list = window.pwaAvailableLanguages;
    if (!list || !list.length) return;
    list = list.filter(function (e) { return e && e.code && e.code !== 'ar'; });
    if (!list.length) return;
    var container = document.getElementById(containerId);
    if (!container) return;
    container.innerHTML = '';
    var current = resolvedLangForUi();

    function addOption(entry, parent, optionClass, nameClass) {
      var c = entry.code;
      var displayName = (entry.name != null && String(entry.name).trim() !== '') ? String(entry.name).trim() : c;
      var option = document.createElement('button');
      option.type = 'button';
      option.setAttribute('role', 'menuitem');
      option.className = optionClass + (c === current ? ' active' : '');
      option.setAttribute('data-lang', c);
      var flagWrap = document.createElement('span');
      flagWrap.className = isModal ? 'language-flag' : 'main-lang-flag';
      var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('viewBox', '0 0 640 480');
      svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
      svg.setAttribute('aria-hidden', 'true');
      var use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
      use.setAttribute('href', '/vb/assets/flags.svg#flag-' + getFlagIconId(entry));
      svg.appendChild(use);
      flagWrap.appendChild(svg);
      var nameSpan = document.createElement('span');
      nameSpan.className = nameClass || 'main-lang-name';
      nameSpan.textContent = displayName;
      option.appendChild(flagWrap);
      option.appendChild(nameSpan);
      option.addEventListener('click', function (e) {
        var lc = this.getAttribute('data-lang');
        e.stopPropagation();
        parent.querySelectorAll('.main-lang-option, .language-modal-option').forEach(function (o) { o.classList.remove('active'); });
        this.classList.add('active');
        if (!isModal) {
          var drop = document.getElementById('mainLangDropdown');
          if (drop) drop.classList.remove('show');
          var btn = document.getElementById('mainLangBtn');
          if (btn) btn.setAttribute('aria-expanded', 'false');
        }
        var ent = window.pwaAvailableLanguages && window.pwaAvailableLanguages.find(function (x) { return x.code === lc; });
        window.pwaHotSwapLanguage(lc, ent && ent.js_path, function () {
          if (typeof window.updateMainContent === 'function') window.updateMainContent();
          if (typeof window.updateHeaderBranding === 'function') window.updateHeaderBranding();
        });
        if (isModal && typeof window.closeLanguageModal === 'function') window.closeLanguageModal();
        if (isModal && typeof window.closeDrawer === 'function') window.closeDrawer();
      });
      parent.appendChild(option);
    }

    if (isModal) {
      list.forEach(function (entry) { addOption(entry, container, 'language-modal-option', 'language-name'); });
    } else {
      var wrap = document.createElement('div');
      wrap.className = 'main-lang-wrap';
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'main-lang-btn';
      btn.id = 'mainLangBtn';
      btn.setAttribute('aria-label', 'Sprache wählen');
      btn.setAttribute('aria-haspopup', 'true');
      btn.setAttribute('aria-expanded', 'false');
      btn.textContent = '\uD83C\uDF10';
      var dropdown = document.createElement('div');
      dropdown.className = 'main-lang-dropdown';
      dropdown.id = 'mainLangDropdown';
      dropdown.setAttribute('role', 'menu');
      list.forEach(function (entry) { addOption(entry, dropdown, 'main-lang-option', 'main-lang-name'); });
      function removeOutsideListener() {
        if (wrap._outsideClick) {
          document.removeEventListener('click', wrap._outsideClick);
          wrap._outsideClick = null;
        }
      }
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        var isOpen = dropdown.classList.toggle('show');
        btn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
        if (isOpen) {
          removeOutsideListener();
          wrap._outsideClick = function (ev) {
            if (!wrap.contains(ev.target)) {
              dropdown.classList.remove('show');
              btn.setAttribute('aria-expanded', 'false');
              removeOutsideListener();
            }
          };
          setTimeout(function () { document.addEventListener('click', wrap._outsideClick); }, 0);
        } else {
          removeOutsideListener();
        }
      });
      wrap.appendChild(btn);
      wrap.appendChild(dropdown);
      container.appendChild(wrap);
    }
  }

  window.buildDatabaseLangMenu = buildDatabaseLangMenu;

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', runInit, { once: true });
  } else {
    runInit();
  }
})();
