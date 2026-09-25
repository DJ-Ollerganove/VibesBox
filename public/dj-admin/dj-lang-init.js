/**
 * DJ-Browser (/dj-admin): Erdkugel + Sprachwechsel (gleiche Logik wie Root-PWA).
 */
(function () {
  'use strict';

  window.onPwaLanguageChanged = function (code) {
    if (typeof window.djBrowserSetLocale === 'function') {
      window.djBrowserSetLocale(code);
    } else {
      window.djBrowserLocale = code;
      if (typeof window.djBrowserApplyLoginL10n === 'function') {
        window.djBrowserApplyLoginL10n(code);
      }
    }
    if (typeof window.djApplyTextDirection === 'function') {
      window.djApplyTextDirection(code);
    } else if (typeof window.djAdminApplyTextDirection === 'function') {
      window.djAdminApplyTextDirection(code);
    } else {
      document.documentElement.lang = code || 'de';
    }
    window.dispatchEvent(
      new CustomEvent('djBrowserLocaleChanged', { detail: { locale: code } })
    );
    if (typeof window.refreshLangMenuChromeLabels === 'function') {
      window.refreshLangMenuChromeLabels();
    }
  };

  function djMenuCurrentLang() {
    if (typeof window.djBrowserReadActiveLang === 'function') {
      return window.djBrowserReadActiveLang();
    }
    if (typeof window.resolveBrowserLanguageForPwa === 'function') {
      return window.resolveBrowserLanguageForPwa();
    }
    return 'en';
  }

  function initDjLangMenu() {
    if (typeof window.buildDatabaseLangMenu !== 'function') return;
    if (!document.getElementById('djLangSwitcher')) return;
    window.buildDatabaseLangMenu('djLangSwitcher', false, djMenuCurrentLang);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      initDjLangMenu();
      if (typeof window.djApplyTextDirection === 'function') {
        window.djApplyTextDirection(djMenuCurrentLang());
      } else if (typeof window.djAdminApplyTextDirection === 'function') {
        window.djAdminApplyTextDirection(djMenuCurrentLang());
      }
    }, { once: true });
  } else {
    initDjLangMenu();
    if (typeof window.djApplyTextDirection === 'function') {
      window.djApplyTextDirection(djMenuCurrentLang());
    } else if (typeof window.djAdminApplyTextDirection === 'function') {
      window.djAdminApplyTextDirection(djMenuCurrentLang());
    }
  }
})();
