/**
 * Impressum / Datenschutz / AGB — gleicher Inhalt wie PWA (public/vb/lang/*.js).
 * Nutzung: Root index.html, delete-account.html
 */
(function () {
  'use strict';

  var COPYRIGHT_FALLBACK = '2026 by VibesBox';

  function getCurrentLegalLang() {
    try {
      if (typeof window.getEffectiveLangForMenu === 'function') {
        return window.getEffectiveLangForMenu();
      }
      var s = window.localStorage.getItem('permanent_user_locale')
        || window.localStorage.getItem('pwa_language')
        || window.localStorage.getItem('language')
        || (navigator.language && navigator.language.split('-')[0])
        || 'en';
      return String(s).trim().split('-')[0].toLowerCase() || 'en';
    } catch (e) {
      return 'en';
    }
  }

  function translationsForLang(lang) {
    var tr = window.translations;
    if (!tr || typeof tr !== 'object') return {};
    return tr[lang] || tr.en || {};
  }

  function copyrightFooterHtml() {
    var text = COPYRIGHT_FALLBACK;
    try {
      text = sessionStorage.getItem('vibesbox_copyright_text') || COPYRIGHT_FALLBACK;
    } catch (e) {}
    return '<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid rgba(212, 131, 77, 0.3); text-align: center; font-size: 0.85rem; color: rgba(255, 255, 255, 0.6);">© ' + text + '</div>';
  }

  /** @param {'impressum'|'datenschutz'|'agb'} type */
  function getVibesBoxLegalContent(type) {
    var lang = getCurrentLegalLang();
    var t = translationsForLang(lang);
    var tDe = translationsForLang('de');
    var title = '';
    var html = '';

    if (type === 'impressum') {
      title = t.imprint_title || translationsForLang('en').imprint_title || 'Imprint';
      if (t.legal_language_notice) {
        html += '<p style="font-weight: bold; margin-bottom: 16px;">' + t.legal_language_notice + '</p>';
      }
      if (tDe.imprint_html_content) html += tDe.imprint_html_content;
    } else if (type === 'datenschutz') {
      title = t.privacy_title || translationsForLang('en').privacy_title || 'Privacy';
      if (t.legal_language_notice) {
        html += '<p style="font-weight: bold; margin-bottom: 16px;">' + t.legal_language_notice + '</p>';
      }
      html += t.privacy_html_content || tDe.privacy_html_content || '';
    } else if (type === 'agb') {
      title = t.terms_title || translationsForLang('en').terms_title || 'Terms';
      html += t.terms_html_content || tDe.terms_html_content || '';
    } else {
      title = type;
      html = '<p></p>';
    }

    html += copyrightFooterHtml();
    return { title: title, html: html };
  }

  function normalizeLegalType(raw) {
    var v = String(raw || '').trim().toLowerCase().replace(/\.html$/i, '');
    if (v === 'dsgvo' || v === 'privacy') return 'datenschutz';
    if (v === 'terms') return 'agb';
    return v;
  }

  function openVibesBoxLegalModal(type) {
    var legalType = normalizeLegalType(type);
    if (legalType !== 'impressum' && legalType !== 'datenschutz' && legalType !== 'agb') return;

    var overlay = document.getElementById('legalOverlay');
    var body = document.getElementById('legalModalBody');
    var titleEl = document.getElementById('legalModalTitle');
    if (!overlay || !body || !titleEl) return;

    var data = getVibesBoxLegalContent(legalType);
    titleEl.textContent = data.title;
    body.innerHTML = data.html;
    body.querySelectorAll('a[href^="http"]').forEach(function (a) {
      a.setAttribute('target', '_blank');
      a.setAttribute('rel', 'noopener noreferrer');
    });
    overlay.classList.add('show');
    overlay.setAttribute('aria-hidden', 'false');
    body.scrollTop = 0;
  }

  function closeVibesBoxLegalModal() {
    var overlay = document.getElementById('legalOverlay');
    if (!overlay) return;
    overlay.classList.remove('show');
    overlay.setAttribute('aria-hidden', 'true');
  }

  function wireLegalLinks() {
    document.querySelectorAll('[data-legal]').forEach(function (a) {
      if (a.getAttribute('data-legal-wired') === '1') return;
      a.setAttribute('data-legal-wired', '1');
      a.addEventListener('click', function (e) {
        e.preventDefault();
        var page = this.getAttribute('data-legal');
        if (!page) return;
        openVibesBoxLegalModal(page);
      });
    });
  }

  function initVibesBoxLegalModal() {
    var overlay = document.getElementById('legalOverlay');
    var closeBtn = document.getElementById('legalModalClose');
    if (!overlay) return;

    wireLegalLinks();

    if (closeBtn && closeBtn.getAttribute('data-legal-close-wired') !== '1') {
      closeBtn.setAttribute('data-legal-close-wired', '1');
      closeBtn.addEventListener('click', closeVibesBoxLegalModal);
    }
    if (overlay.getAttribute('data-legal-overlay-wired') !== '1') {
      overlay.setAttribute('data-legal-overlay-wired', '1');
      overlay.addEventListener('click', function (e) {
        if (e.target === overlay) closeVibesBoxLegalModal();
      });
    }
  }

  window.getVibesBoxLegalContent = getVibesBoxLegalContent;
  window.openVibesBoxLegalModal = openVibesBoxLegalModal;
  window.closeVibesBoxLegalModal = closeVibesBoxLegalModal;
  window.initVibesBoxLegalModal = initVibesBoxLegalModal;

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initVibesBoxLegalModal, { once: true });
  } else {
    initVibesBoxLegalModal();
  }
  window.addEventListener('translationsReady', initVibesBoxLegalModal);
})();
