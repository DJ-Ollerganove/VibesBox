/**
 * lang_menu_shared.js – Gemeinsame Sprachmenü-Logik für Landing (/) und PWA (/vb/)
 * Daten ausschließlich aus window.pwaAvailableLanguages (z. B. default-pwa-languages.js), kein Firestore.
 * Stellt bereit: window.getEffectiveLangForMenu(), window.buildDatabaseLangMenu(containerId, isModal)
 */
(function () {
  'use strict';

  var PERMANENT_LOCALE_KEY = 'permanent_user_locale';
  /** Session: von Root (/) mitgegebene Sprache für /vb/ — gleiche Browser-Sitzung, auch ohne ?lang= in jeder Navigation. */
  var VB_ENTRY_LANG_KEY = 'vb_entry_lang';
  /** Muss mit default-pwa-languages.js übereinstimmen — URL-Sprache gilt auch wenn codes noch leer. */
  var STATIC_PWA_LANG_CODES = ['de', 'en', 'fr', 'ru', 'zh', 'es', 'tr', 'pt', 'it', 'uk'];
  var REGION_TO_LANG = { de: 'de', at: 'de', ch: 'de', fr: 'fr', es: 'es', it: 'it', ru: 'ru', tr: 'tr', pt: 'pt', br: 'pt', zh: 'zh', cn: 'zh', tw: 'zh', ua: 'uk', ar: 'ar', sa: 'ar', eg: 'ar' };

  function setVbPreferredLangForSession(code) {
    if (!code) return;
    try {
      var c = String(code).trim().toLowerCase();
      if (c && c !== 'ar') window.sessionStorage.setItem(VB_ENTRY_LANG_KEY, c);
    } catch (e) {}
  }

  function normalizeUrlLangCode(raw) {
    var v = String(raw || '').trim().toLowerCase();
    if (!v || v === 'ar') return '';
    if (v.length > 2 && v.charAt(2) === '-') v = v.slice(0, 2);
    return v;
  }

  /**
   * Sprache primär aus der URL: ?lang= / &lang= in search und hash (inkl. #/?lang=de),
   * optional locale=. Case-insensitive Parametername per Regex.
   */
  function readPwaUrlLangParam() {
    try {
      var sp = new URLSearchParams(window.location.search || '');
      var v = normalizeUrlCodeFromParams(sp);
      if (v) return v;
      var combined = (window.location.search || '') + (window.location.hash || '');
      var m = /[?&#]lang=([a-z]{2})(?:-[a-z0-9]+)?/i.exec(combined);
      if (!m) m = /[?&#]locale=([a-z]{2})(?:-[a-z0-9]+)?/i.exec(combined);
      if (m) {
        v = normalizeUrlLangCode(m[1]);
        if (v) return v;
      }
      var hash = (window.location.hash || '').replace(/^#/, '');
      var qm = hash.indexOf('?');
      if (qm >= 0) {
        var hp = new URLSearchParams(hash.substring(qm + 1));
        v = normalizeUrlCodeFromParams(hp);
        if (v) return v;
      }
    } catch (e) {}
    return '';
  }

  function normalizeUrlCodeFromParams(params) {
    if (!params || typeof params.get !== 'function') return '';
    var v = normalizeUrlLangCode(params.get('lang') || params.get('locale') || '');
    return v;
  }

  function urlLangSupportedForPwa(code, codes) {
    if (!code) return false;
    if (codes.indexOf(code) !== -1) return true;
    return STATIC_PWA_LANG_CODES.indexOf(code) !== -1;
  }

  /** Damit deferred app.js (|| 'en') nicht gewinnt, bevor startVBPageInit läuft. */
  function persistUrlLanguageToAllStorage(code) {
    var c = normalizeUrlLangCode(code);
    if (!c) return;
    var codes = effectiveCodesForMenu();
    if (!urlLangSupportedForPwa(c, codes)) return;
    try {
      window.localStorage.removeItem('pwa_language_manual');
      window.sessionStorage.removeItem('pwa_language_manual');
    } catch (m) {}
    try {
      window.localStorage.setItem('pwa_language', c);
      window.localStorage.setItem('language', c);
      window.localStorage.setItem('selected_language', c);
      window.localStorage.setItem('user_language', c);
      window.localStorage.setItem('app_locale', c);
      window.localStorage.setItem(PERMANENT_LOCALE_KEY, c);
      window.sessionStorage.setItem('pwa_language', c);
      window.sessionStorage.setItem('selected_language', c);
      window.sessionStorage.setItem('language', c);
      window.sessionStorage.setItem('user_language', c);
      window.sessionStorage.setItem('app_locale', c);
    } catch (e) {}
    setVbPreferredLangForSession(c);
  }

  /** Gleiche Logik wie lang-loader.js (Root lädt nur dieses Script, ohne lang-loader). Region vor Primärsprache (z. B. en-DE → de). */
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

  /** Nur gültige manuelle Wahl (Erdkugel), nicht alter Auto-Speicher ohne Flag. */
  function readManualStoredLanguageIfValid(codes) {
    if (!isManualLanguageLocked()) return '';
    var s = readStoredLanguage();
    if (s === 'ar') return '';
    if (s && codes.indexOf(s) !== -1) return s;
    return '';
  }

  /** Nur LocalStorage: Root-PWA schreibt hier zuerst — vor Browser & vor vb_entry_lang. */
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

  /**
   * Priorität: (1) Live-URL ?lang= — absolut: wenn unterstützt, sofort Return + Speicher spiegeln.
   * Kein Zwischenschritt (kein __pwaCapturedUrlLang, kein manueller Override vor URL).
   * Danach: Manual → LocalStorage Root → vb_entry → Spiegel → Browsersprache (nur wenn in codes).
   * Ohne URL, ohne Speicher: nicht unterstützte Browsersprache (z. B. it) → en, niemals de als automatischen Ersatz.
   */
  function resolvePwaLanguage(codes) {
    var live = readPwaUrlLangParam();
    if (live === 'ar') live = '';
    if (live && urlLangSupportedForPwa(live, codes)) {
      persistUrlLanguageToAllStorage(live);
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

  function persistLanguageSelection(code) {
    try {
      window.localStorage.setItem(PERMANENT_LOCALE_KEY, code);
      window.sessionStorage.setItem('pwa_language', code);
      window.sessionStorage.setItem('selected_language', code);
      window.sessionStorage.setItem('language', code);
      window.sessionStorage.setItem('user_language', code);
      window.sessionStorage.setItem('app_locale', code);
      window.localStorage.setItem('selected_language', code);
      window.localStorage.setItem('pwa_language', code);
      window.localStorage.setItem('language', code);
      window.localStorage.setItem('user_language', code);
      window.localStorage.setItem('app_locale', code);
      window.localStorage.setItem('pwa_language_manual', '1');
      window.sessionStorage.setItem('pwa_language_manual', '1');
      setVbPreferredLangForSession(code);
    } catch (e) {}
  }

  function effectiveCodesForMenu() {
    var list = window.pwaAvailableLanguages && window.pwaAvailableLanguages.length ? window.pwaAvailableLanguages : [];
    list = list.filter(function (e) { return e && e.code && e.code !== 'ar'; });
    if (list.length) return list.map(function (e) { return e.code; });
    var d = window.DEFAULT_PWA_LANGUAGES;
    if (d && d.length) return d.map(function (e) { return e.code; });
    return ['en', 'de', 'fr', 'ru', 'zh', 'es', 'tr', 'pt', 'it', 'uk'];
  }

  function getEffectiveLangForMenu() {
    return resolvePwaLanguage(effectiveCodesForMenu());
  }

  function getFlagIconId(entry) {
    if (!entry) return 'globe';
    var iconRaw = entry.icon != null ? String(entry.icon).trim() : '';
    return iconRaw !== '' ? iconRaw : (entry.code ? String(entry.code).trim() : 'globe');
  }

  /** Baut das Sprachmenü aus window.pwaAvailableLanguages. containerId = z. B. 'langSwitcher' (Root) oder 'languageModalGrid' (VB Modal). isModal = true im Drawer/Modal. */
  function buildDatabaseLangMenu(containerId, isModal) {
    var list = window.pwaAvailableLanguages;
    if (!list || !list.length) return;
    list = list.filter(function (e) { return e && e.code && e.code !== 'ar'; });
    if (!list.length) return;
    list = list.slice().sort(function (a, b) {
      var na = (a.name != null ? String(a.name) : '').trim();
      var nb = (b.name != null ? String(b.name) : '').trim();
      return na.localeCompare(nb, 'en', { sensitivity: 'base' });
    });
    var container = document.getElementById(containerId);
    if (!container) return;
    container.innerHTML = '';
    var current = getEffectiveLangForMenu();

    function addOption(entry, parent, optionClass, nameClass) {
      var code = entry.code;
      var displayName = (entry.name != null && String(entry.name).trim() !== '') ? String(entry.name).trim() : code;
      var option = document.createElement('button');
      option.type = 'button';
      option.setAttribute('role', 'menuitem');
      option.className = optionClass + (code === current ? ' active' : '');
      option.setAttribute('data-lang', code);
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
        var code = this.getAttribute('data-lang');
        e.stopPropagation();
        persistLanguageSelection(code);
        parent.querySelectorAll('.main-lang-option, .language-modal-option').forEach(function (o) { o.classList.remove('active'); });
        this.classList.add('active');
        if (!isModal) {
          var drop = document.getElementById('mainLangDropdown');
          if (drop) drop.classList.remove('show');
          var btn = document.getElementById('mainLangBtn');
          if (btn) btn.setAttribute('aria-expanded', 'false');
        }
        var apply = function () {
          if (typeof window.updateMainContent === 'function') window.updateMainContent();
          if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
          if (typeof window.translatePage === 'function') window.translatePage();
          if (typeof window.updateHeaderBranding === 'function') window.updateHeaderBranding();
          if (typeof window.updateDrawerCurrentLanguage === 'function') window.updateDrawerCurrentLanguage();
        };
        if (typeof window.loadRootLanguage === 'function') {
          window.loadRootLanguage(code, function () { apply(); });
        } else if (typeof window.pwaHotSwapLanguage === 'function' && window.pwaAvailableLanguages) {
          var ent = window.pwaAvailableLanguages.find(function (e) { return e.code === code; });
          window.pwaHotSwapLanguage(code, ent && ent.js_path, function () { apply(); });
        } else {
          apply();
        }
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

  /** Root: Erdkugel (#langSwitcher) sobald DOM bereit – nur window.pwaAvailableLanguages, ohne Firebase. */
  function initLangSwitcherWhenDomReady() {
    function run() {
      var list = window.pwaAvailableLanguages;
      if (!list || !list.length) return;
      if (!document.getElementById('langSwitcher')) return;
      buildDatabaseLangMenu('langSwitcher', false);
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', run, { once: true });
    } else {
      run();
    }
  }

  if (typeof window !== 'undefined') {
    window.readPwaUrlLangParam = readPwaUrlLangParam;
    window.persistUrlLanguageToAllStorage = persistUrlLanguageToAllStorage;
    try {
      var _seed = readPwaUrlLangParam();
      if (_seed && _seed !== 'ar') {
        var _codesBoot = effectiveCodesForMenu();
        if (urlLangSupportedForPwa(_seed, _codesBoot)) {
          persistUrlLanguageToAllStorage(_seed);
        }
      }
    } catch (eSeed) {}
    window.resolvePwaLanguage = resolvePwaLanguage;
    window.getEffectiveLangForMenu = getEffectiveLangForMenu;
    window.setVbPreferredLangForSession = setVbPreferredLangForSession;
    window.buildDatabaseLangMenu = buildDatabaseLangMenu;
    if (typeof window.pickBestLangFromNavigatorCodes !== 'function') {
      window.pickBestLangFromNavigatorCodes = pickBestLangFromNavigatorCodesLocal;
    }
    initLangSwitcherWhenDomReady();
  }
})();
