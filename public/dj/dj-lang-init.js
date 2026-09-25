/**
 * DJ-Browser (/dj): Erdkugel + Sprachwechsel (gleiche Logik wie Root-PWA).
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
    }
    window.dispatchEvent(
      new CustomEvent('djBrowserLocaleChanged', { detail: { locale: code } })
    );
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
      }
    }, { once: true });
  } else {
    initDjLangMenu();
    if (typeof window.djApplyTextDirection === 'function') {
      window.djApplyTextDirection(djMenuCurrentLang());
    }
  }
})();
