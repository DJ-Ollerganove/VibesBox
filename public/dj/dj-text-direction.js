/**
 * Schreibrichtung für DJ-PWAs (/dj/, /dj-admin/) — Quelle: l10n/languages.json → PARTY_LOCALE_OPTS.text_direction
 */
(function () {
  'use strict';

  function normalizeCode(code) {
    return String(code || '').trim().toLowerCase().split('-')[0] || 'de';
  }

  function textDirectionForCode(code) {
    var c = normalizeCode(code);
    // Harte Fallbacks — auch wenn PARTY_LOCALE_OPTS noch nicht geladen ist
    if (c === 'ar' || c === 'he' || c === 'fa' || c === 'ur') return 'rtl';
    if (typeof window.partyTextDirection === 'function') {
      return window.partyTextDirection(c);
    }
    var opts = (window.PARTY_LOCALE_OPTS && window.PARTY_LOCALE_OPTS[c]) || {};
    return opts.text_direction === 'rtl' ? 'rtl' : 'ltr';
  }

  function applyDjTextDirection(code) {
    var lang = normalizeCode(code);
    var dir = textDirectionForCode(lang);
    var isRtl = dir === 'rtl';
    document.documentElement.setAttribute('dir', dir);
    document.documentElement.lang = lang;
    document.documentElement.classList.toggle('dj-rtl-active', isRtl);
    document.documentElement.classList.toggle('dj-admin-ar', lang === 'ar');
    if (isRtl && !document.getElementById('pwa-rtl-font')) {
      var link = document.createElement('link');
      link.id = 'pwa-rtl-font';
      link.rel = 'stylesheet';
      link.href = 'https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap';
      document.head.appendChild(link);
    }
    if (isRtl) {
      document.documentElement.style.fontFamily = "'Cairo', 'Noto Sans Arabic', Tahoma, sans-serif";
      if (document.body) document.body.style.fontFamily = "'Cairo', 'Noto Sans Arabic', Tahoma, sans-serif";
    } else {
      document.documentElement.style.fontFamily = '';
      if (document.body) document.body.style.fontFamily = '';
    }
    if (document.body) {
      document.body.setAttribute('dir', dir);
      document.body.classList.toggle('dj-rtl-active', isRtl);
      document.body.classList.toggle('dj-admin-rtl', isRtl);
      document.body.classList.toggle('dj-admin-ar', lang === 'ar');
    }
    ['app-root', 'view-login', 'view-box', 'view-boot', 'view-message', 'tab-bar', 'wish-list', 'login-form'].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.setAttribute('dir', dir);
    });
    // RTL-Hinweis-Badge entfernt (nicht mehr anzeigen, falls altes HTML gecacht)
    var badge = document.getElementById('dj-rtl-badge');
    if (badge) {
      badge.hidden = true;
      badge.setAttribute('hidden', '');
      badge.style.display = 'none';
    }
  }

  window.djTextDirectionFor = textDirectionForCode;
  window.djApplyTextDirection = applyDjTextDirection;
  window.djIsRtlLocale = function (code) {
    return textDirectionForCode(code) === 'rtl';
  };
  // dj-admin bootstrap alias
  window.djAdminApplyTextDirection = applyDjTextDirection;
  window.djAdminTextDirectionFor = textDirectionForCode;
  window.djAdminIsRtlLocale = window.djIsRtlLocale;

  function readEarlyLangCode() {
    try {
      var sp = new URLSearchParams(window.location.search || '');
      var l = (sp.get('lang') || '').trim().toLowerCase().split('-')[0];
      if (l) return l;
    } catch (e0) {}
    try {
      var keys = ['pwa_language', 'language', 'dj_admin_locale'];
      for (var i = 0; i < keys.length; i++) {
        var v = (localStorage.getItem(keys[i]) || sessionStorage.getItem(keys[i]) || '').trim().toLowerCase().split('-')[0];
        if (v) return v;
      }
    } catch (e1) {}
    return '';
  }

  var early = readEarlyLangCode();
  if (early) applyDjTextDirection(early);
})();
