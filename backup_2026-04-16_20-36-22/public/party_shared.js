/**
 * party_shared.js – Zentrale Party-Code-Prüfung für Landingpage (/) und PWA (/vb/)
 * Firestore startet nur in firebase-init.js (memoryLocalCache). Hier nur Warten auf window.firebaseDb*.
 * Von / und /vb/ mit <script src="/party_shared.js"></script> einbindbar (kein type="module" nötig).
 */
(function () {
  'use strict';

  var PARTIES_COLLECTION = 'parties';
  var MESSAGE_KEY_INVALID = 'main_code_error_invalid';
  var MESSAGE_KEY_ENDED = 'party_ended';
  var MESSAGE_KEY_NOT_STARTED = 'party_not_started';
  var MESSAGE_KEY_RATE_LIMIT = 'main_code_error_rate_limit';
  var RATE_LIMIT_MAX_ATTEMPTS = 5;
  var RATE_LIMIT_BLOCK_MS = 30000;
  var STORAGE_KEY_FAIL_COUNT = 'party_shared_fail_count';
  var STORAGE_KEY_BLOCK_UNTIL = 'party_shared_block_until';
  /** Firestore getDocs kann ohne Netzwerk hängen → UI blieb auf „Wird geprüft…“. */
  var PARTY_CODE_CHECK_TIMEOUT_MS = 42000;
  var MESSAGE_KEY_TIMEOUT = 'main_code_error_timeout';

  function withTimeout(promise, ms) {
    var err = new Error('party_code_check_timeout');
    err.code = 'party_code_check_timeout';
    return new Promise(function (resolve, reject) {
      var done = false;
      var t = setTimeout(function () {
        if (!done) {
          done = true;
          reject(err);
        }
      }, ms);
      promise.then(
        function (v) {
          if (done) return;
          done = true;
          clearTimeout(t);
          resolve(v);
        },
        function (e) {
          if (done) return;
          done = true;
          clearTimeout(t);
          reject(e);
        }
      );
    });
  }

  /** pwa_language (de, en, …) → BCP 47 Locale für Intl */
  var PARTY_LOCALE_MAP = { de: 'de-DE', en: 'en-US', fr: 'fr-FR', ru: 'ru-RU', zh: 'zh-CN', es: 'es-ES', tr: 'tr-TR', pt: 'pt-PT' };

  function getPartyLocale(lang) {
    var l = lang;
    if (l == null && typeof window !== 'undefined') {
      if (typeof window.getEffectiveLangForMenu === 'function') {
        try {
          l = window.getEffectiveLangForMenu();
        } catch (e) {
          l = '';
        }
      }
      if (!l && window.localStorage) {
        l = window.localStorage.getItem('pwa_language') || window.localStorage.getItem('language') || '';
      }
    }
    return PARTY_LOCALE_MAP[l] || 'de-DE';
  }

  var FIREBASE_WAIT_MS = 28000;
  var FIREBASE_POLL_MS = 16;

  function hasFirebaseGlobals() {
    return (
      typeof window !== 'undefined' &&
      window.firebaseDb &&
      window.firebaseCollection &&
      window.firebaseQuery &&
      window.firebaseWhere &&
      window.firebaseGetDocs
    );
  }

  var initPromise = null;

  function ensureFirebase() {
    if (hasFirebaseGlobals()) return Promise.resolve();
    if (!initPromise) {
      initPromise = new Promise(function (resolve, reject) {
        var deadline = Date.now() + FIREBASE_WAIT_MS;
        function tick() {
          if (hasFirebaseGlobals()) {
            resolve();
            return;
          }
          if (Date.now() > deadline) {
            reject(new Error('firebase-init.js: Firebase nicht rechtzeitig geladen.'));
            return;
          }
          setTimeout(tick, FIREBASE_POLL_MS);
        }
        tick();
      });
    }
    return initPromise;
  }

  /**
   * Nur Ziffern 0-9, max. 8 Zeichen (XSS/Injection-Schutz). Join nur mit genau 8 Ziffern.
   */
  function normalizePartyCode(code) {
    if (code == null) return '';
    var s = String(code).trim();
    return s.replace(/[^0-9]/g, '').substring(0, 8);
  }

  function isValidJoinDigitLength(len) {
    return len === 8;
  }

  function getRateLimitState() {
    try {
      var count = parseInt(sessionStorage.getItem(STORAGE_KEY_FAIL_COUNT), 10) || 0;
      var blockUntil = parseInt(sessionStorage.getItem(STORAGE_KEY_BLOCK_UNTIL), 10) || 0;
      return { count: count, blockUntil: blockUntil };
    } catch (e) {
      return { count: 0, blockUntil: 0 };
    }
  }

  function setRateLimitState(count, blockUntil) {
    try {
      sessionStorage.setItem(STORAGE_KEY_FAIL_COUNT, String(count));
      sessionStorage.setItem(STORAGE_KEY_BLOCK_UNTIL, String(blockUntil));
    } catch (e) {}
  }

  /**
   * Prüft einen Party-Code gegen Firestore (exakt 8 Ziffern).
   * @param {string} code
   * @returns {Promise<{success: boolean, data?: object, message?: string}>}
   */
  function checkPartyCode(code) {
    var normalized = normalizePartyCode(code);
    if (!isValidJoinDigitLength(normalized.length)) {
      return Promise.resolve({ success: false, messageKey: MESSAGE_KEY_INVALID });
    }

    var now = Date.now();
    var state = getRateLimitState();
    if (state.blockUntil > now) {
      return Promise.resolve({ success: false, messageKey: MESSAGE_KEY_RATE_LIMIT });
    }

    var firestoreLookup = ensureFirebase().then(function () {
      var db = window.firebaseDb;
      var collectionFn = window.firebaseCollection;
      var queryFn = window.firebaseQuery;
      var whereFn = window.firebaseWhere;
      var getDocsFn = window.firebaseGetDocs;

      if (!db || !collectionFn || !queryFn || !whereFn || !getDocsFn) {
        return { success: false, messageKey: MESSAGE_KEY_INVALID };
      }

      var partiesRef = collectionFn(db, PARTIES_COLLECTION);

      function rateLimitFail() {
        var st = getRateLimitState();
        var newCount = st.count + 1;
        var blockUntil = newCount >= RATE_LIMIT_MAX_ATTEMPTS ? now + RATE_LIMIT_BLOCK_MS : 0;
        if (blockUntil) newCount = 0;
        setRateLimitState(newCount, blockUntil);
        return { success: false, messageKey: MESSAGE_KEY_INVALID };
      }

      function processFoundDoc(doc) {
        setRateLimitState(0, 0);
        var data = doc.data();
        var partyId = doc.id;
        var nowDate = new Date();
        var ended = false;

        if (data.lifecycle_status === 'finished' || data.finished_at != null) {
          ended = true;
        } else if (data.status === 'beendet' || data.status === 'ended') {
          ended = true;
        } else if (data.end_date && typeof data.end_date.toDate === 'function') {
          if (nowDate > data.end_date.toDate()) ended = true;
        } else if (data.end_time_posix && typeof data.end_time_posix === 'number') {
          if (nowDate.getTime() > data.end_time_posix * 1000) ended = true;
        }

        if (ended) {
          setRateLimitState(0, 0);
          return { success: false, messageKey: MESSAGE_KEY_ENDED };
        }

        var startDateUtc = null;
        if (data.start_time_posix && typeof data.start_time_posix === 'number') {
          startDateUtc = new Date(data.start_time_posix * 1000);
        } else if (data.start_date && typeof data.start_date.toDate === 'function') {
          startDateUtc = data.start_date.toDate();
        }
        if (startDateUtc && nowDate < startDateUtc) {
          setRateLimitState(0, 0);
          var startPosix = data.start_time_posix;
          if (startPosix == null && data.start_date && typeof data.start_date.toDate === 'function') {
            startPosix = Math.floor(data.start_date.toDate().getTime() / 1000);
          }
          return {
            success: false,
            messageKey: MESSAGE_KEY_NOT_STARTED,
            type: 'future',
            start_time_posix: startPosix || 0,
            timezone_id: data.timezone_id || 'UTC'
          };
        }

        return {
          success: true,
          data: {
            party_id: partyId,
            party_code: data.party_code != null ? String(data.party_code) : normalized,
            party_name: data.party_name || data.partyName || null
          }
        };
      }

      function queryField(field, value) {
        var q = queryFn(partiesRef, whereFn(field, '==', value));
        return getDocsFn(q);
      }

      function firstDoc(snapshot) {
        return snapshot && snapshot.docs.length > 0 ? snapshot.docs[0] : null;
      }

      function lookupFixedPartyCodeField() {
        var num = parseInt(normalized, 10);
        return queryField('fixed_party_code', normalized).then(function (snap) {
          var d = firstDoc(snap);
          if (d) return d;
          var tryNum = !isNaN(num) && (normalized.length === 8 || String(num) === normalized);
          if (!tryNum) return null;
          return queryField('fixed_party_code', num).then(function (snap2) {
            return firstDoc(snap2);
          });
        });
      }

      return queryField('party_code', normalized).then(function (snapshot) {
        var d = firstDoc(snapshot);
        if (d) return processFoundDoc(d);
        var num = parseInt(normalized, 10);
        // Auch Zahl-Vergleich: z. B. Firestore speichert 12345678 als Number, Gast gibt "01234567" ein
        var tryPartyCodeAsNumber = !isNaN(num) && (normalized.length === 8 || String(num) === normalized);
        var afterPartyCodeNum = tryPartyCodeAsNumber
          ? queryField('party_code', num).then(function (snapNum) {
              return firstDoc(snapNum);
            })
          : Promise.resolve(null);
        return afterPartyCodeNum.then(function (d2) {
          if (d2) return processFoundDoc(d2);
          return lookupFixedPartyCodeField().then(function (d4) {
            if (d4) return processFoundDoc(d4);
            return rateLimitFail();
          });
        });
      });
    });

    return withTimeout(firestoreLookup, PARTY_CODE_CHECK_TIMEOUT_MS).catch(function (e) {
      if (e && e.code === 'party_code_check_timeout') {
        if (typeof window !== 'undefined' && window.IS_DEBUG) {
          console.warn('party_shared: Party-Code-Abfrage Zeitüberschreitung (' + PARTY_CODE_CHECK_TIMEOUT_MS + 'ms)');
        }
        return { success: false, messageKey: MESSAGE_KEY_TIMEOUT };
      }
      if (typeof window !== 'undefined' && window.IS_DEBUG) console.error('party_shared: checkPartyCode Fehler', e); else console.error('party_shared: checkPartyCode Fehler');
      return { success: false, messageKey: MESSAGE_KEY_INVALID };
    });
  }

  /**
   * Formatiert UTC Unix-Timestamp in Ortszeit der Party (nur HH:MM, ohne "Uhr").
   * Verwendet Sprache aus lang oder pwa_language (nicht Browsersprache).
   * @param {number} timePosix - UTC Unix-Timestamp in Sekunden
   * @param {string} timezoneId - IANA-Zeitzone (z.B. "Europe/Berlin")
   * @param {string} [lang] - z.B. "de", "en"; fehlt → pwa_language aus localStorage
   * @returns {string} z.B. "20:00"
   */
  function formatPartyLocalTime(timePosix, timezoneId, lang) {
    var locale = getPartyLocale(lang);
    try {
      var utcDate = new Date(timePosix * 1000);
      var formatter = new Intl.DateTimeFormat(locale, {
        timeZone: timezoneId || 'UTC',
        hour: '2-digit',
        minute: '2-digit',
        hour12: locale.startsWith('en')
      });
      return formatter.format(utcDate);
    } catch (e) {
      return new Date(timePosix * 1000).toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit', hour12: locale.startsWith('en') });
    }
  }

  /**
   * Formatiert UTC Unix-Timestamp als lokales Datum (Wochentag, Tag, Monat) in Party-Zeitzone.
   * Nutzt lang bzw. pwa_language – kein Denglisch.
   * @param {number} timePosix - UTC Unix-Timestamp in Sekunden
   * @param {string} timezoneId - IANA-Zeitzone (z.B. "Europe/Berlin")
   * @param {string} [lang] - z.B. "de", "en", "tr"; fehlt → pwa_language
   * @returns {string} z.B. DE "Samstag, 21. Februar", EN "Saturday, February 21", TR "21 Şubat Cumartesi"
   */
  function formatPartyLocalDate(timePosix, timezoneId, lang) {
    var locale = getPartyLocale(lang);
    try {
      var utcDate = new Date(timePosix * 1000);
      var formatter = new Intl.DateTimeFormat(locale, {
        timeZone: timezoneId || 'UTC',
        weekday: 'long',
        day: 'numeric',
        month: 'long'
      });
      return formatter.format(utcDate);
    } catch (e) {
      return new Date(timePosix * 1000).toLocaleDateString(locale, { weekday: 'long', day: 'numeric', month: 'long' });
    }
  }

  /**
   * Kurzes Datum + Uhrzeit (z.B. für History "älter als 7 Tage").
   * @param {Date} date
   * @param {string} [lang] - pwa_language wenn fehlt
   * @returns {string}
   */
  function formatPartyShortDateTime(date, lang) {
    if (!date || !(date instanceof Date)) return '';
    var locale = getPartyLocale(lang);
    try {
      return new Intl.DateTimeFormat(locale, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: locale.startsWith('en')
      }).format(date);
    } catch (e) {
      return date.toLocaleString(locale);
    }
  }

  /**
   * Baut eine lokalisierte Dauer aus Wochen/Tagen/Stunden/Minuten.
   * @param {number} weeks
   * @param {number} days
   * @param {number} hours - Gesamtstunden
   * @param {number} minutesCeil - aufgerundete Gesamtminuten
   * @param {function(string): string} t - Übersetzungsfunktion (z.B. t('time_week'))
   * @returns {string}
   */
  function formatDuration(weeks, days, hours, minutesCeil, t) {
    var fallback = function (key) {
      var de = { time_week: 'Woche', time_weeks: 'Wochen', time_day: 'Tag', time_days: 'Tage', time_hour: 'Stunde', time_hours: 'Stunden', time_minute: 'Minute', time_minutes: 'Minuten' };
      return de[key] || key;
    };
    var T = typeof t === 'function' ? t : fallback;

    if (weeks >= 2) {
      var remainingDays = days - weeks * 7;
      var w = weeks + ' ' + (weeks === 1 ? T('time_week') : T('time_weeks'));
      if (remainingDays === 0) return w;
      return w + ', ' + remainingDays + ' ' + (remainingDays === 1 ? T('time_day') : T('time_days'));
    }
    if (days >= 1) {
      var remainingHours = hours - days * 24;
      var d = days + ' ' + (days === 1 ? T('time_day') : T('time_days'));
      if (remainingHours === 0) return d;
      return d + ', ' + remainingHours + ' ' + (remainingHours === 1 ? T('time_hour') : T('time_hours'));
    }
    if (hours >= 1) {
      var remainingMinutes = minutesCeil - hours * 60;
      if (remainingMinutes < 0) remainingMinutes = 0;
      var h = hours + ' ' + (hours === 1 ? T('time_hour') : T('time_hours'));
      if (remainingMinutes === 0) return h;
      return h + ', ' + remainingMinutes + ' ' + (remainingMinutes === 1 ? T('time_minute') : T('time_minutes'));
    }
    return minutesCeil + ' ' + (minutesCeil === 1 ? T('time_minute') : T('time_minutes'));
  }

  /**
   * Countdown-Text bis zum Party-Start (Landing + VB).
   * Nutzt t() für alle Zeiteinheiten und "party_starts_now"; ohne t Fallback Deutsch.
   * @param {number} startTimePosix - UTC Unix-Timestamp in Sekunden
   * @param {function(string): string} [t] - Übersetzungsfunktion
   * @returns {string}
   */
  function calculateTimeUntilParty(startTimePosix, t) {
    var startMs = startTimePosix * 1000;
    var diffMs = Math.max(0, startMs - Date.now());

    if (diffMs < 60000) {
      return typeof t === 'function' ? (t('party_starts_now') || 'Startet jetzt') : 'Startet jetzt';
    }

    var minutesCeil = Math.ceil(diffMs / (1000 * 60));
    var hours = Math.floor(diffMs / (1000 * 60 * 60));
    var days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    var weeks = Math.floor(days / 7);

    if (days >= 14) {
      var remainingDays = days % 7;
      var T = typeof t === 'function' ? t : function (k) { return { time_week: 'Woche', time_weeks: 'Wochen', time_day: 'Tag', time_days: 'Tage' }[k] || k; };
      return weeks + ' ' + (weeks === 1 ? T('time_week') : T('time_weeks')) + (remainingDays === 0 ? '' : ', ' + remainingDays + ' ' + (remainingDays === 1 ? T('time_day') : T('time_days')));
    }
    if (days >= 1) {
      var remainingHours = Math.ceil((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
      var T = typeof t === 'function' ? t : function (k) { return { time_day: 'Tag', time_days: 'Tage', time_hour: 'Stunde', time_hours: 'Stunden' }[k] || k; };
      return days + ' ' + (days === 1 ? T('time_day') : T('time_days')) + (remainingHours === 0 ? '' : ', ' + remainingHours + ' ' + (remainingHours === 1 ? T('time_hour') : T('time_hours')));
    }
    if (hours >= 1) {
      var remainingMinutes = Math.ceil((diffMs % (1000 * 60 * 60)) / (1000 * 60));
      var T = typeof t === 'function' ? t : function (k) { return { time_hour: 'Stunde', time_hours: 'Stunden', time_minute: 'Minute', time_minutes: 'Minuten' }[k] || k; };
      return hours + ' ' + (hours === 1 ? T('time_hour') : T('time_hours')) + (remainingMinutes === 0 ? '' : ', ' + remainingMinutes + ' ' + (remainingMinutes === 1 ? T('time_minute') : T('time_minutes')));
    }
    var T = typeof t === 'function' ? t : function (k) { return { time_minute: 'Minute', time_minutes: 'Minuten' }[k] || k; };
    return minutesCeil + ' ' + (minutesCeil === 1 ? T('time_minute') : T('time_minutes'));
  }

  if (typeof window !== 'undefined') {
    window.checkPartyCode = checkPartyCode;
    window.getPartyLocale = getPartyLocale;
    window.formatPartyLocalTime = formatPartyLocalTime;
    window.formatPartyLocalDate = formatPartyLocalDate;
    window.formatPartyShortDateTime = formatPartyShortDateTime;
    window.formatDuration = formatDuration;
    window.calculateTimeUntilParty = calculateTimeUntilParty;
  }
})();
