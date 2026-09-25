/**
 * Sprachmenü: alphabetisch, Spalten à 5; horizontal wischbar mit Fade + Pfeilen.
 */
(function () {
  'use strict';

  window.LANG_MENU_ROWS_PER_COLUMN = 5;

  /** Wurzel des Sprachmenüs (alle Spalten), nicht nur eine Spalte. */
  window.langMenuRootFromElement = function (el) {
    if (!el) return null;
    return (
      el.closest('.main-lang-dropdown') ||
      el.closest('#languageModalGrid') ||
      el.closest('.language-modal-grid') ||
      (function () {
        var wrap = el.closest('.lang-menu-scroll-wrap');
        return wrap ? wrap.parentElement : null;
      })()
    );
  };

  /** Genau eine Sprache als aktiv markieren (orange). */
  window.setLanguageMenuActive = function (fromEl, code) {
    var root = window.langMenuRootFromElement(fromEl);
    if (!root || !code) return;
    root.querySelectorAll('.main-lang-option, .language-modal-option').forEach(function (o) {
      var match = o.getAttribute('data-lang') === code;
      if (match) o.classList.add('active');
      else o.classList.remove('active');
    });
  };

  window.sortLanguageMenuList = function (list) {
    return list.slice().sort(function (a, b) {
      var na = (a.name != null ? String(a.name) : '').trim();
      var nb = (b.name != null ? String(b.name) : '').trim();
      return na.localeCompare(nb, 'en', { sensitivity: 'base' });
    });
  };

  window.splitLanguageMenuColumns = function (list, rowsPerColumn) {
    var n = rowsPerColumn || window.LANG_MENU_ROWS_PER_COLUMN || 5;
    var cols = [];
    for (var i = 0; i < list.length; i += n) {
      cols.push(list.slice(i, i + n));
    }
    return cols;
  };

  function swipeHintLabel() {
    if (typeof window.djBrowserT === 'function') {
      var dj = window.djBrowserT('lang_menu_swipe_hint');
      if (dj) return dj;
    }
    if (typeof window.partyT === 'function') {
      var pwa = window.partyT('lang_menu_swipe_hint');
      if (pwa) return pwa;
    }
    try {
      var lang = (window.localStorage && window.localStorage.getItem('pwa_language')) ||
        (window.localStorage && window.localStorage.getItem('language')) ||
        (window.localStorage && window.localStorage.getItem('dj_admin_locale')) || 'de';
      if (String(lang).toLowerCase().indexOf('de') === 0) {
        return 'Nach links oder rechts wischen';
      }
    } catch (e) {}
    return 'Swipe left or right for more languages';
  }

  function scrollChevronLabel(side) {
    var key = side === 'left' ? 'lang_menu_scroll_left' : 'lang_menu_scroll_right';
    if (typeof window.djBrowserT === 'function') {
      var dj = window.djBrowserT(key);
      if (dj) return dj;
    }
    if (typeof window.partyT === 'function') {
      var pwa = window.partyT(key);
      if (pwa) return pwa;
    }
    return side === 'left' ? 'Scroll left' : 'Scroll right';
  }

  window.langMenuSwipeHintLabel = swipeHintLabel;

  function refreshLangMenuChromeLabels() {
    document.querySelectorAll('.lang-menu-scroll-hint').forEach(function (hint) {
      hint.textContent = swipeHintLabel();
    });
    document.querySelectorAll('.lang-menu-scroll-chevron--left').forEach(function (btn) {
      btn.setAttribute('aria-label', scrollChevronLabel('left'));
    });
    document.querySelectorAll('.lang-menu-scroll-chevron--right').forEach(function (btn) {
      btn.setAttribute('aria-label', scrollChevronLabel('right'));
    });
  }

  window.refreshLangMenuChromeLabels = refreshLangMenuChromeLabels;

  function updateLangMenuScrollHints(scrollArea) {
    if (!scrollArea || !scrollArea.parentElement) return;
    var root = scrollArea.parentElement;
    var max = scrollArea.scrollWidth - scrollArea.clientWidth;
    var canScroll = max > 12;
    var sl = scrollArea.scrollLeft;
    var left = sl > 8;
    var right = sl < max - 8;
    root.classList.toggle('lang-menu-scroll--scrollable', canScroll);
    root.classList.toggle('lang-menu-scroll--at-start', !left);
    root.classList.toggle('lang-menu-scroll--at-end', !right);
    var hint = root.querySelector('.lang-menu-scroll-hint');
    if (hint) hint.style.display = canScroll ? '' : 'none';
  }

  window.updateLangMenuScrollHints = updateLangMenuScrollHints;

  function attachScrollChrome(parent, columnsEl) {
    var shell = document.createElement('div');
    shell.className = 'lang-menu-scroll-wrap';

    var fadeL = document.createElement('div');
    fadeL.className = 'lang-menu-scroll-fade lang-menu-scroll-fade--left';
    fadeL.setAttribute('aria-hidden', 'true');

    var fadeR = document.createElement('div');
    fadeR.className = 'lang-menu-scroll-fade lang-menu-scroll-fade--right';
    fadeR.setAttribute('aria-hidden', 'true');

    var chevL = document.createElement('button');
    chevL.type = 'button';
    chevL.className = 'lang-menu-scroll-chevron lang-menu-scroll-chevron--left';
    chevL.setAttribute('aria-label', scrollChevronLabel('left'));
    chevL.innerHTML = '&#8249;';

    var chevR = document.createElement('button');
    chevR.type = 'button';
    chevR.className = 'lang-menu-scroll-chevron lang-menu-scroll-chevron--right';
    chevR.setAttribute('aria-label', scrollChevronLabel('right'));
    chevR.innerHTML = '&#8250;';

    var scrollArea = document.createElement('div');
    scrollArea.className = 'lang-menu-scroll-area';
    scrollArea.setAttribute('tabindex', '0');
    scrollArea.appendChild(columnsEl);

    var hint = document.createElement('div');
    hint.className = 'lang-menu-scroll-hint';
    hint.textContent = swipeHintLabel();

    chevL.addEventListener('click', function (e) {
      e.stopPropagation();
      scrollArea.scrollBy({ left: -160, behavior: 'smooth' });
    });
    chevR.addEventListener('click', function (e) {
      e.stopPropagation();
      scrollArea.scrollBy({ left: 160, behavior: 'smooth' });
    });

    scrollArea.addEventListener('scroll', function () {
      updateLangMenuScrollHints(scrollArea);
    });

    shell.appendChild(fadeL);
    shell.appendChild(fadeR);
    shell.appendChild(chevL);
    shell.appendChild(chevR);
    shell.appendChild(scrollArea);
    parent.appendChild(shell);
    parent.appendChild(hint);

    function refresh() {
      updateLangMenuScrollHints(scrollArea);
    }
    if (typeof requestAnimationFrame === 'function') {
      requestAnimationFrame(refresh);
      requestAnimationFrame(refresh);
    } else {
      setTimeout(refresh, 0);
      setTimeout(refresh, 120);
    }
    if (typeof ResizeObserver !== 'undefined') {
      try {
        var ro = new ResizeObserver(refresh);
        ro.observe(scrollArea);
      } catch (e) {}
    }
    window.addEventListener('resize', refresh);
  }

  /** @param {function(entry, columnEl): void} addOptionToColumn */
  window.fillLanguageMenuColumns = function (parent, list, addOptionToColumn) {
    if (!parent || !list || !list.length) return;
    var columnsWrap = document.createElement('div');
    columnsWrap.className = 'lang-menu-columns';
    var columns = window.splitLanguageMenuColumns(list);
    columns.forEach(function (colEntries) {
      var col = document.createElement('div');
      col.className = 'lang-menu-column';
      colEntries.forEach(function (entry) {
        addOptionToColumn(entry, col);
      });
      columnsWrap.appendChild(col);
    });
    var peek = document.createElement('div');
    peek.className = 'lang-menu-scroll-peek';
    peek.setAttribute('aria-hidden', 'true');
    columnsWrap.appendChild(peek);
    attachScrollChrome(parent, columnsWrap);
  };
})();
