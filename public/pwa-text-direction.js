/**
 * Schreibrichtung für Root-, Wunschbox- und gemeinsame PWA-Seiten.
 * Quelle: l10n/languages.json → PARTY_LOCALE_OPTS.text_direction (Fallback: ar/he/fa/ur).
 */
(function () {
  'use strict';

  function normalizeCode(code) {
    return String(code || '').trim().toLowerCase().split(/[-_]/)[0] || '';
  }

  function textDirectionForCode(code) {
    var c = normalizeCode(code);
    if (c === 'ar' || c === 'he' || c === 'fa' || c === 'ur') return 'rtl';
    if (typeof window.partyTextDirection === 'function') {
      return window.partyTextDirection(c);
    }
    var opts = (window.PARTY_LOCALE_OPTS && window.PARTY_LOCALE_OPTS[c]) || {};
    return opts.text_direction === 'rtl' ? 'rtl' : 'ltr';
  }

  function ensureRtlFont(isRtl) {
    var existing = document.getElementById('pwa-rtl-font');
    if (!isRtl) return;
    if (existing) return;
    var link = document.createElement('link');
    link.id = 'pwa-rtl-font';
    link.rel = 'stylesheet';
    link.href = 'https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap';
    document.head.appendChild(link);
  }

  function applyPwaTextDirection(code) {
    var lang = normalizeCode(code) || 'en';
    var dir = textDirectionForCode(lang);
    var isRtl = dir === 'rtl';
    var html = document.documentElement;
    html.setAttribute('dir', dir);
    html.lang = lang || html.lang || 'en';
    html.classList.toggle('pwa-rtl', isRtl);
    if (document.body) {
      document.body.setAttribute('dir', dir);
      document.body.classList.toggle('pwa-rtl', isRtl);
    }
    ensureRtlFont(isRtl);
  }

  window.pwaTextDirectionFor = textDirectionForCode;
  window.pwaApplyTextDirection = applyPwaTextDirection;
  window.pwaIsRtlLocale = function (code) {
    return textDirectionForCode(code) === 'rtl';
  };

  function readEarlyLangCode() {
    try {
      var sp = new URLSearchParams(window.location.search || '');
      var l = (sp.get('lang') || sp.get('locale') || '').trim().toLowerCase().split(/[-_]/)[0];
      if (l) return l;
    } catch (e0) {}
    try {
      var stored = (localStorage.getItem('pwa_language') || localStorage.getItem('language') || '').trim().toLowerCase().split(/[-_]/)[0];
      if (stored) return stored;
    } catch (e1) {}
    return '';
  }

  var early = readEarlyLangCode();
  if (early) applyPwaTextDirection(early);
})();
