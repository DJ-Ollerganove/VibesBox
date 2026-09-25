/**
 * Nur /dj-admin: Arabisch im Erdkugel-Menü + eigene Locale-Speicherung.
 * Produktiv-PWA (/dj/, /vb/) bleibt unverändert.
 */
(function () {
  'use strict';

  var AR_ENTRY = { code: 'ar', name: 'Arabic', icon: 'ar', js_path: '/vb/lang/ar.js' };
  var DJ_ADMIN_LOCALE_KEY = 'dj_admin_locale';
  var DJ_ADMIN_LOCALE_MANUAL_KEY = 'dj_admin_locale_manual';

  function menuLanguages() {
    var base = (window.pwaAvailableLanguages || []).filter(function (e) {
      return e && e.code;
    });
    if (!base.some(function (e) { return e.code === 'ar'; })) {
      base = base.concat([AR_ENTRY]);
    }
    return typeof window.sortLanguageMenuList === 'function'
      ? window.sortLanguageMenuList(base)
      : base.slice();
  }

  function menuCodes() {
    return menuLanguages().map(function (e) { return e.code; });
  }

  function getFlagIconId(entry) {
    if (!entry) return 'globe';
    var iconRaw = entry.icon != null ? String(entry.icon).trim() : '';
    return iconRaw !== '' ? iconRaw : (entry.code ? String(entry.code).trim() : 'globe');
  }

  function isManualLocked() {
    try {
      return window.localStorage.getItem(DJ_ADMIN_LOCALE_MANUAL_KEY) === '1'
        || window.sessionStorage.getItem(DJ_ADMIN_LOCALE_MANUAL_KEY) === '1';
    } catch (e) {
      return false;
    }
  }

  function readStoredDjAdminLocale() {
    try {
      var keys = [DJ_ADMIN_LOCALE_KEY];
      for (var i = 0; i < keys.length; i++) {
        var local = (window.localStorage.getItem(keys[i]) || '').trim().toLowerCase();
        if (local) return local;
        var session = (window.sessionStorage.getItem(keys[i]) || '').trim().toLowerCase();
        if (session) return session;
      }
    } catch (e) {}
    return '';
  }

  function persistDjAdminLocale(code) {
    var c = String(code || '').trim().toLowerCase();
    if (!c) return;
    try {
      window.localStorage.setItem(DJ_ADMIN_LOCALE_KEY, c);
      window.sessionStorage.setItem(DJ_ADMIN_LOCALE_KEY, c);
      window.localStorage.setItem(DJ_ADMIN_LOCALE_MANUAL_KEY, '1');
      window.sessionStorage.setItem(DJ_ADMIN_LOCALE_MANUAL_KEY, '1');
    } catch (e) {}
  }

  function resolveDjAdminLanguage() {
    var codes = menuCodes();
    if (!codes.length) return 'en';

    if (typeof window.readPwaUrlLangParam === 'function') {
      var live = window.readPwaUrlLangParam();
      if (live && codes.indexOf(live) !== -1) {
        persistDjAdminLocale(live);
        return live;
      }
    }

    if (isManualLocked()) {
      var manual = readStoredDjAdminLocale();
      if (manual && codes.indexOf(manual) !== -1) return manual;
    }

    var stored = readStoredDjAdminLocale();
    if (stored && codes.indexOf(stored) !== -1) return stored;

    var pick = typeof window.pickBestLangFromNavigatorCodes === 'function'
      ? window.pickBestLangFromNavigatorCodes(codes)
      : '';
    if (pick && codes.indexOf(pick) !== -1) return pick;

    if (codes.indexOf('en') !== -1) return 'en';
    return codes[0];
  }

  function buildDjAdminLangMenu(containerId, isModal, resolveCurrentLang) {
    var list = menuLanguages();
    if (!list.length) return;
    var container = document.getElementById(containerId);
    if (!container) return;
    container.innerHTML = '';
    var current = typeof resolveCurrentLang === 'function'
      ? resolveCurrentLang()
      : resolveDjAdminLanguage();

    function addOption(entry, parent, optionClass, nameClass) {
      var code = entry.code;
      var displayName = (entry.name != null && String(entry.name).trim() !== '')
        ? String(entry.name).trim()
        : code;
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
      var flagHref = '/vb/assets/flags.svg?v=2#flag-' + getFlagIconId(entry);
      use.setAttribute('href', flagHref);
      use.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', flagHref);
      svg.appendChild(use);
      flagWrap.appendChild(svg);
      var nameSpan = document.createElement('span');
      nameSpan.className = nameClass || 'main-lang-name';
      nameSpan.textContent = displayName;
      option.appendChild(flagWrap);
      option.appendChild(nameSpan);
      option.addEventListener('click', function (e) {
        var picked = this.getAttribute('data-lang');
        e.stopPropagation();
        persistDjAdminLocale(picked);
        window.djBrowserLocale = picked;
        if (typeof window.djBrowserSetLocale === 'function') {
          window.djBrowserSetLocale(picked);
        } else if (typeof window.djBrowserApplyLoginL10n === 'function') {
          window.djBrowserApplyLoginL10n(picked);
        }
        if (typeof window.djAdminApplyTextDirection === 'function') {
          window.djAdminApplyTextDirection(picked);
        }
        var menuRoot = typeof window.langMenuRootFromElement === 'function'
          ? window.langMenuRootFromElement(this)
          : parent;
        (menuRoot || parent).querySelectorAll('.main-lang-option, .language-modal-option').forEach(function (o) {
          o.classList.remove('active');
        });
        this.classList.add('active');
        if (!isModal) {
          var drop = document.getElementById('mainLangDropdown');
          if (drop) drop.classList.remove('show');
          var btn = document.getElementById('mainLangBtn');
          if (btn) btn.setAttribute('aria-expanded', 'false');
        }
        if (typeof window.onPwaLanguageChanged === 'function') {
          window.onPwaLanguageChanged(picked);
        }
        if (isModal && typeof window.closeLanguageModal === 'function') window.closeLanguageModal();
        if (isModal && typeof window.closeDrawer === 'function') window.closeDrawer();
      });
      parent.appendChild(option);
    }

    if (isModal) {
      if (typeof window.fillLanguageMenuColumns === 'function') {
        window.fillLanguageMenuColumns(container, list, function (entry, col) {
          addOption(entry, col, 'language-modal-option', 'language-name');
        });
      } else {
        list.forEach(function (entry) {
          addOption(entry, container, 'language-modal-option', 'language-name');
        });
      }
      return;
    }

    var wrap = document.createElement('div');
    wrap.className = 'main-lang-wrap';
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'main-lang-btn';
    btn.id = 'mainLangBtn';
    btn.setAttribute('aria-label', (typeof window.pwaSelectLanguageLabel === 'function') ? window.pwaSelectLanguageLabel() : (typeof window.djBrowserT === 'function' ? window.djBrowserT('select_language') : 'Select language'));
    btn.setAttribute('aria-haspopup', 'true');
    btn.setAttribute('aria-expanded', 'false');
    btn.textContent = '\uD83C\uDF10';
    var dropdown = document.createElement('div');
    dropdown.className = 'main-lang-dropdown';
    dropdown.id = 'mainLangDropdown';
    dropdown.setAttribute('role', 'menu');
    if (typeof window.fillLanguageMenuColumns === 'function') {
      window.fillLanguageMenuColumns(dropdown, list, function (entry, col) {
        addOption(entry, col, 'main-lang-option', 'main-lang-name');
      });
    } else {
      list.forEach(function (entry) {
        addOption(entry, dropdown, 'main-lang-option', 'main-lang-name');
      });
    }
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

  var readPwaUrlLangParamOrig = window.readPwaUrlLangParam;

  function readDjAdminUrlLang() {
    try {
      var sp = new URLSearchParams(window.location.search || '');
      var v = (sp.get('lang') || sp.get('locale') || '').trim().toLowerCase();
      if (v.length > 2 && v.charAt(2) === '-') v = v.slice(0, 2);
      if (v === 'ar') return 'ar';
      if (typeof readPwaUrlLangParamOrig === 'function') {
        return readPwaUrlLangParamOrig();
      }
    } catch (e) {}
    return '';
  }

  window.buildDatabaseLangMenu = buildDjAdminLangMenu;
  window.readPwaUrlLangParam = readDjAdminUrlLang;
  window.getEffectiveLangForMenu = resolveDjAdminLanguage;
  window.getPwaEffectiveLangCodes = menuCodes;
  window.resolveBrowserLanguageForPwa = function () {
    return resolveDjAdminLanguage();
  };
  window.djBrowserReadActiveLang = resolveDjAdminLanguage;

  if (typeof window.djApplyTextDirection === 'function') {
    var bootLang = resolveDjAdminLanguage();
    if (document.body) {
      window.djApplyTextDirection(bootLang);
    } else {
      document.addEventListener('DOMContentLoaded', function () {
        window.djApplyTextDirection(resolveDjAdminLanguage());
      }, { once: true });
    }
  }
})();
