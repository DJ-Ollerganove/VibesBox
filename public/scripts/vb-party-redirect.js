/**
 * Root → /vb/: Party-Join-Code aus URL sofort in /vb/ öffnen (kein Check auf der Landingpage).
 * Inline im <head> der Root vor schweren Assets einbinden.
 */
(function () {
  'use strict';

  function normalizePartyCode8(raw) {
    if (raw == null) return null;
    var d = String(raw).replace(/[^0-9]/g, '').substring(0, 8);
    return d.length === 8 && /^\d+$/.test(d) ? d : null;
  }

  function extractPartyCodeFromLocation() {
    try {
      var sp = new URLSearchParams(window.location.search || '');
      var fromQ = normalizePartyCode8(sp.get('code'));
      if (fromQ) return fromQ;
    } catch (e0) {}

    try {
      var rawHash = window.location.hash || '';
      if (rawHash) {
        var hash = rawHash.replace(/^#/, '');
        var qi = hash.indexOf('?');
        var qPart = qi >= 0 ? hash.substring(qi + 1) : (hash.indexOf('code=') !== -1 ? hash : '');
        if (qPart) {
          var hp = new URLSearchParams(qPart);
          var fromH = normalizePartyCode8(hp.get('code'));
          if (fromH) return fromH;
        }
      }
    } catch (e1) {}

    var path = (window.location.pathname || '').replace(/^\/+|\/+$/g, '');
    var parts = path.split('/');
    var partyIdx = parts.indexOf('party');
    if (partyIdx !== -1 && parts[partyIdx + 1]) {
      return normalizePartyCode8(parts[partyIdx + 1]);
    }
    var pIdx = parts.indexOf('p');
    if (pIdx !== -1 && parts[pIdx + 1]) {
      return normalizePartyCode8(parts[pIdx + 1]);
    }
    return null;
  }

  function readLangForVb() {
    try {
      var sp = new URLSearchParams(window.location.search || '');
      var l = (sp.get('lang') || '').trim().toLowerCase().split('-')[0];
      if (l && l !== 'ar') return l;
    } catch (eL) {}
    try {
      var stored = (localStorage.getItem('pwa_language') || localStorage.getItem('language') || '').trim().split('-')[0].toLowerCase();
      if (stored && stored !== 'ar') return stored;
    } catch (eS) {}
    return '';
  }

  window.vbBuildWishboxUrlWithPartyCode = function (code, langOpt) {
    var c = normalizePartyCode8(code);
    if (!c) return '/vb/';
    var lang = langOpt || readLangForVb();
    var q = new URLSearchParams();
    q.set('code', c);
    if (lang) q.set('lang', lang);
    return '/vb/?' + q.toString();
  };

  var pathname = (window.location.pathname || '').toLowerCase();
  if (pathname.indexOf('/vb') !== -1) return;

  var code = extractPartyCodeFromLocation();
  if (!code) return;

  try {
    sessionStorage.setItem('vb_session_party_code', code);
    sessionStorage.setItem('vb_pending_join_code', code);
  } catch (eStore) {}

  var lang = readLangForVb();
  try {
    if (lang && typeof window.setVbPreferredLangForSession === 'function') {
      window.setVbPreferredLangForSession(lang);
    }
  } catch (eLang) {}

  window.location.replace(window.vbBuildWishboxUrlWithPartyCode(code, lang));
})();
