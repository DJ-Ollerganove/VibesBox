/**
 * party_shared.js – Zentrale Party-Code-Prüfung für die Wunschbox-PWA (/vb/)
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
  /** Gesamtfrist inkl. ensureFirebase; Join-Queries laufen parallel (nicht nacheinander). */
  var PARTY_CODE_CHECK_TIMEOUT_MS = 20000;
  var MESSAGE_KEY_TIMEOUT = 'main_code_error_timeout';
  /** Vorab-Wünsche schließen spätestens diese Stunden vor Partybeginn. */
  var PRE_WISH_CLOSE_HOURS = 6;

  /**
   * Vorab-Farben – eine Quelle (Flutter: UIConstants.colorPreWish = #7986CB).
   * PWA: CSS --pre-wish-* in styles/main.css
   */
  var VB_PRE_WISH = {
    primary: '#7986CB',
    text: '#E8EAF6',
    gradientEnd: '#764BA2',
    bgSubtle: 'rgba(121, 134, 203, 0.15)',
    border: 'rgba(121, 134, 203, 0.45)',
    shadow: 'rgba(121, 134, 203, 0.3)'
  };
  window.VB_PRE_WISH = VB_PRE_WISH;

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

  /** pwa_language (de, en, …) → BCP 47 für Intl — aus l10n/languages.json (generated/party-locale-map.js) */
  var PARTY_LOCALE_MAP = (typeof window !== 'undefined' && window.PARTY_LOCALE_MAP) ? window.PARTY_LOCALE_MAP : {
    de: 'de-DE',
    en: 'en-US',
    fr: 'fr-FR',
    ru: 'ru-RU',
    zh: 'zh-CN',
    es: 'es-ES',
    tr: 'tr-TR',
    pt: 'pt-PT',
    it: 'it-IT',
    uk: 'uk-UA',
    hi: 'hi-IN',
    sq: 'sq-AL',
    vi: 'vi-VN',
    ja: 'ja-JP',
    el: 'el-GR',
    nl: 'nl-NL',
    pl: 'pl-PL',
    cs: 'cs-CZ',
    ar: 'ar'
  };

  function getPartyLangCode(lang) {
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
    return (l || 'de').toString().toLowerCase().split('-')[0];
  }

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
    var code = getPartyLangCode(l);
    return PARTY_LOCALE_MAP[code] || 'de-DE';
  }

  /** Optionen aus l10n/languages.json (generated/party-locale-opts.js). */
  function partyLocaleOpt(lang) {
    var code = getPartyLangCode(lang);
    var opts = (typeof window !== 'undefined' && window.PARTY_LOCALE_OPTS) ? window.PARTY_LOCALE_OPTS : {};
    return opts[code] || {};
  }

  /** 12-Stunden-Uhr (nur z. B. en). */
  function partyHour12(lang) {
    var o = partyLocaleOpt(lang);
    if (typeof o.hour12 === 'boolean') return o.hour12;
    return /^en/i.test(getPartyLocale(lang));
  }

  /** Text nach der Uhrzeit (z. B. DE „ Uhr“) — Quelle: languages.json → PARTY_LOCALE_OPTS. */
  function partyTimeSuffix(lang) {
    var o = partyLocaleOpt(lang);
    if (typeof o.time_suffix === 'string') return o.time_suffix.trim();
    return '';
  }

  function partyTimeStyle(lang) {
    var o = partyLocaleOpt(lang);
    return (o.time_style && String(o.time_style)) || 'colon_suffix';
  }

  /** Stunde/Minute (24h-Ziffern) in optionaler Zeitzone. */
  function clockParts24(date, locale, timeZoneId) {
    var opts = {
      hour: 'numeric',
      minute: '2-digit',
      hour12: false
    };
    if (timeZoneId) opts.timeZone = timeZoneId;
    var parts = new Intl.DateTimeFormat(locale, opts).formatToParts(date);
    var hour = 0;
    var minute = 0;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].type === 'hour') hour = parseInt(parts[i].value, 10);
      if (parts[i].type === 'minute') minute = parseInt(parts[i].value, 10);
    }
    return { hour: hour, minute: minute };
  }

  function appendTimeSuffix(clock, suffix) {
    var s = (suffix || '').trim();
    if (!s || clock.indexOf(s) !== -1) return clock;
    return clock + '\u00A0' + s;
  }

  /**
   * Uhrzeit nach languages.json (time_style, time_suffix, hour12).
   * @param {Date} date
   * @param {string} [lang]
   * @param {string} [timeZoneId]
   * @param {boolean} [withSuffix]
   */
  function formatClockForLang(date, lang, timeZoneId, withSuffix) {
    if (!date || !(date instanceof Date) || isNaN(date.getTime())) return '';
    if (withSuffix === undefined) withSuffix = true;
    var locale = getPartyLocale(lang);
    var style = partyTimeStyle(lang);
    var suffix = partyTimeSuffix(lang);

    if (style === 'intl_12' && partyHour12(lang)) {
      var iOpts = {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      };
      if (timeZoneId) iOpts.timeZone = timeZoneId;
      return new Intl.DateTimeFormat(locale, iOpts).format(date);
    }

    var p = clockParts24(date, locale, timeZoneId);
    var h = p.hour;
    var m = String(p.minute).padStart(2, '0');

    if (style === 'fr_h') {
      return h + ' h ' + m;
    }
    if (style === 'h_compact' || style === 'pt_h') {
      return h + 'h' + m;
    }
    if (style === 'ja_kanji') {
      return h + '\u6642' + m + '\u5206';
    }

    var colonOpts = {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    };
    if (timeZoneId) colonOpts.timeZone = timeZoneId;
    var clock = new Intl.DateTimeFormat(locale, colonOpts).format(date);
    if (!withSuffix || !suffix) return clock;
    return appendTimeSuffix(clock, suffix);
  }

  /** Muss zur Root-Wartezeit passen (index.html rootUrlPartyBootstrap); sonst hängt UI unnötig. */
  var FIREBASE_WAIT_MS = 10000;
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
        var settled = false;
        function finishOk() {
          if (settled) return;
          settled = true;
          resolve();
        }
        function finishErr() {
          if (settled) return;
          settled = true;
          reject(new Error('firebase-init.js: Firebase nicht rechtzeitig geladen.'));
        }
        if (typeof window !== 'undefined') {
          window.addEventListener('firebaseGlobalsReady', function () {
            if (hasFirebaseGlobals()) finishOk();
          }, { once: true });
        }
        var deadline = Date.now() + FIREBASE_WAIT_MS;
        function tick() {
          if (hasFirebaseGlobals()) {
            finishOk();
            return;
          }
          if (Date.now() > deadline) {
            finishErr();
            return;
          }
          setTimeout(tick, FIREBASE_POLL_MS);
        }
        tick();
      });
    }
    return initPromise;
  }

  /** Serialisierbare Party-Felder aus Firestore (kein zweites getDoc beim Join nötig). */
  function partySnapshotFromData(data) {
    if (!data || typeof data !== 'object') return {};
    var snap = {};
    var strKeys = [
      'party_name', 'partyName', 'party_code', 'fixed_party_code', 'dj_name', 'display_name', 'name',
      'created_by', 'timezone_id', 'lifecycle_status', 'status', 'dj_logo'
    ];
    for (var i = 0; i < strKeys.length; i++) {
      var k = strKeys[i];
      if (data[k] != null) snap[k] = data[k];
    }
    if (data.is_paused === true) snap.is_paused = true;
    if (data.allow_pre_wishes === true) snap.allow_pre_wishes = true;
    if (typeof data.start_time_posix === 'number') snap.start_time_posix = data.start_time_posix;
    if (typeof data.end_time_posix === 'number') snap.end_time_posix = data.end_time_posix;
    if (data.start_date && typeof data.start_date.toDate === 'function') {
      snap.start_time_posix = Math.floor(data.start_date.toDate().getTime() / 1000);
    }
    if (data.end_date && typeof data.end_date.toDate === 'function') {
      snap.end_time_posix = Math.floor(data.end_date.toDate().getTime() / 1000);
    }
    if (data.finished_at != null) snap.finished_at = data.finished_at;
    return snap;
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

  /**
   * Mehrere Party-Dokumente können denselben Join-Code haben (z. B. Location + fixed_party_code).
   * Priorität: gerade laufend → nächste zukünftige (frühester Start) → zuletzt beendete (für Meldung/Join-Fallback).
   * Zeitfenster wie processFoundDoc: start_time_posix / start_date, end_time_posix / end_date.
   * @param {Array} docs Firestore QuerySnapshot.docs
   * @param {Date} [nowDate]
   * @returns {object|null} ein doc oder null
   */
  function pickBestPartyDocForJoinCode(docs, nowDate) {
    if (!docs || docs.length === 0) return null;
    if (docs.length === 1) return docs[0];

    var now = nowDate instanceof Date ? nowDate : new Date();

    /** Gleiche Zeitquellen wie checkPartyCode / processFoundDoc (posix bevorzugt wo sinnvoll). */
    function getStartEndDates(data) {
      var startDate = null;
      var endDate = null;
      if (data.start_time_posix && typeof data.start_time_posix === 'number') {
        startDate = new Date(data.start_time_posix * 1000);
      } else if (data.start_date && typeof data.start_date.toDate === 'function') {
        startDate = data.start_date.toDate();
      }
      if (data.end_time_posix && typeof data.end_time_posix === 'number') {
        endDate = new Date(data.end_time_posix * 1000);
      } else if (data.end_date && typeof data.end_date.toDate === 'function') {
        endDate = data.end_date.toDate();
      }
      return { startDate: startDate, endDate: endDate };
    }

    function classify(doc) {
      var data = doc.data();
      var se = getStartEndDates(data);
      var startDate = se.startDate;
      var endDate = se.endDate;

      var endedByLifecycle = data.lifecycle_status === 'finished' || data.finished_at != null;
      var endedByStatus = data.status === 'beendet' || data.status === 'ended';
      var ended = endedByLifecycle || endedByStatus;
      if (!ended && endDate && now > endDate) ended = true;

      var startMs = startDate ? startDate.getTime() : 0;
      var endMs = endDate ? endDate.getTime() : 0;

      if (ended) return { tier: 'past', startMs: startMs, endMs: endMs };

      if (startDate && endDate) {
        if (now >= startDate && now < endDate) return { tier: 'running', startMs: startMs, endMs: endMs };
        if (now < startDate) return { tier: 'future', startMs: startMs, endMs: endMs };
        if (now >= endDate) return { tier: 'past', startMs: startMs, endMs: endMs };
      }

      if (startDate && !endDate) {
        if (now < startDate) return { tier: 'future', startMs: startMs, endMs: endMs };
        if (!ended) return { tier: 'running', startMs: startMs, endMs: endMs };
        return { tier: 'past', startMs: startMs, endMs: endMs };
      }

      if (!startDate && endDate) {
        if (!ended && now < endDate) return { tier: 'running', startMs: startMs, endMs: endMs };
        if (now >= endDate) return { tier: 'past', startMs: startMs, endMs: endMs };
        return { tier: 'unknown', startMs: startMs, endMs: endMs };
      }

      return { tier: 'unknown', startMs: startMs, endMs: endMs };
    }

    var items = docs.map(function (doc) {
      var c = classify(doc);
      return { doc: doc, tier: c.tier, startMs: c.startMs, endMs: c.endMs };
    });

    var running = items.filter(function (x) {
      return x.tier === 'running';
    });
    if (running.length) {
      running.sort(function (a, b) {
        return a.startMs - b.startMs;
      });
      return running[0].doc;
    }

    var future = items.filter(function (x) {
      return x.tier === 'future';
    });
    if (future.length) {
      future.sort(function (a, b) {
        return a.startMs - b.startMs;
      });
      return future[0].doc;
    }

    var unknown = items.filter(function (x) {
      return x.tier === 'unknown';
    });
    if (unknown.length) {
      unknown.sort(function (a, b) {
        return (b.endMs || b.startMs) - (a.endMs || a.startMs);
      });
      return unknown[0].doc;
    }

    var past = items.filter(function (x) {
      return x.tier === 'past';
    });
    if (past.length) {
      past.sort(function (a, b) {
        return (b.endMs || 0) - (a.endMs || 0);
      });
      return past[0].doc;
    }

    return docs[0];
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

  function partyStartDateFromData(data) {
    if (!data) return null;
    if (data.start_time_posix && typeof data.start_time_posix === 'number') {
      return new Date(data.start_time_posix * 1000);
    }
    if (data.start_date && typeof data.start_date.toDate === 'function') {
      return data.start_date.toDate();
    }
    return null;
  }

  function vbPreWishDeadlineMs(startDateUtc) {
    return startDateUtc.getTime() - PRE_WISH_CLOSE_HOURS * 60 * 60 * 1000;
  }

  function vbIsPreWishWindowOpen(data, nowDate) {
    if (!data || data.allow_pre_wishes !== true) return false;
    var start = partyStartDateFromData(data);
    if (!start) return false;
    var now = nowDate || new Date();
    if (now >= start) return false;
    return now.getTime() <= vbPreWishDeadlineMs(start);
  }

  var VB_DEFAULT_FLOOR_KEY = 'default';

  function vbEffectiveFloorKey(data) {
    if (!data) return VB_DEFAULT_FLOOR_KEY;
    var key = data.floor_key;
    if (key == null || String(key).trim() === '') return VB_DEFAULT_FLOOR_KEY;
    return String(key).trim();
  }

  function vbRawFloorLabel(data) {
    if (!data) return VB_DEFAULT_FLOOR_KEY;
    var explicit = data.floor_label;
    if (explicit != null && String(explicit).trim() !== '') return String(explicit).trim();
    var key = vbEffectiveFloorKey(data);
    return key === VB_DEFAULT_FLOOR_KEY ? VB_DEFAULT_FLOOR_KEY : key;
  }

  function vbPartyStartEndDates(data) {
    var startDate = null;
    var endDate = null;
    if (data.start_time_posix && typeof data.start_time_posix === 'number') {
      startDate = new Date(data.start_time_posix * 1000);
    } else if (data.start_date && typeof data.start_date.toDate === 'function') {
      startDate = data.start_date.toDate();
    }
    if (data.end_time_posix && typeof data.end_time_posix === 'number') {
      endDate = new Date(data.end_time_posix * 1000);
    } else if (data.end_date && typeof data.end_date.toDate === 'function') {
      endDate = data.end_date.toDate();
    }
    return { startDate: startDate, endDate: endDate };
  }

  function vbIsPartyEnded(data, nowDate) {
    if (!data) return true;
    var now = nowDate instanceof Date ? nowDate : new Date();
    if (data.lifecycle_status === 'finished' || data.finished_at != null) return true;
    if (data.status === 'beendet' || data.status === 'ended') return true;
    var se = vbPartyStartEndDates(data);
    return se.endDate != null && now > se.endDate;
  }

  /** Gast darf beitreten (laufend, nicht standby/beendet). */
  function vbIsPartyGuestJoinable(data, nowDate) {
    if (!data || vbIsPartyEnded(data, nowDate)) return false;
    if (data.lifecycle_status === 'standby') return false;
    var now = nowDate instanceof Date ? nowDate : new Date();
    var se = vbPartyStartEndDates(data);
    if (se.startDate && se.endDate) {
      return now >= se.startDate && now < se.endDate;
    }
    if (se.startDate && !se.endDate) {
      return now >= se.startDate;
    }
    if (se.endDate) {
      return now < se.endDate;
    }
    return data.lifecycle_status === 'active' || data.lifecycle_status == null;
  }

  function vbFloorOptionFromDoc(doc) {
    var data = doc.data();
    return {
      party_id: doc.id,
      floor_key: vbEffectiveFloorKey(data),
      floor_label: vbRawFloorLabel(data),
      party_name: data.party_name || data.partyName || null,
      dj_name: 'DJ'
    };
  }

  function collectJoinCodePartyDocs(normalized) {
    var db = window.firebaseDb;
    var collectionFn = window.firebaseCollection;
    var queryFn = window.firebaseQuery;
    var whereFn = window.firebaseWhere;
    var getDocsFn = window.firebaseGetDocs;
    if (!db || !collectionFn || !queryFn || !whereFn || !getDocsFn) {
      return Promise.resolve([]);
    }
    var partiesRef = collectionFn(db, PARTIES_COLLECTION);

    function queryField(field, value) {
      var q = queryFn(partiesRef, whereFn(field, '==', value));
      return getDocsFn(q);
    }

    function safeQueryDocs(field, value) {
      return queryField(field, value)
        .then(function (snap) {
          return snap && snap.docs ? snap.docs.slice() : [];
        })
        .catch(function () {
          return [];
        });
    }

    function mergeUniqueById(docArrays) {
      var seen = Object.create(null);
      var out = [];
      docArrays.forEach(function (docs) {
        if (!docs) return;
        for (var i = 0; i < docs.length; i++) {
          var doc = docs[i];
          if (!doc || !doc.id) continue;
          if (!seen[doc.id]) {
            seen[doc.id] = true;
            out.push(doc);
          }
        }
      });
      return out;
    }

    var num = parseInt(normalized, 10);
    var tryPartyCodeAsNumber = !isNaN(num) && String(num) === normalized;
    var pA = safeQueryDocs('party_code', normalized);
    var pB = tryPartyCodeAsNumber ? safeQueryDocs('party_code', num) : Promise.resolve([]);
    var pC = safeQueryDocs('fixed_party_code', normalized);
    var pD = tryPartyCodeAsNumber ? safeQueryDocs('fixed_party_code', num) : Promise.resolve([]);
    return Promise.all([pA, pB, pC, pD]).then(function (arrays) {
      return mergeUniqueById(arrays);
    });
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

        var startDateUtc = partyStartDateFromData(data);
        if (startDateUtc && nowDate < startDateUtc) {
          setRateLimitState(0, 0);
          var startPosix = data.start_time_posix;
          if (startPosix == null && data.start_date && typeof data.start_date.toDate === 'function') {
            startPosix = Math.floor(data.start_date.toDate().getTime() / 1000);
          }
          if (vbIsPreWishWindowOpen(data, nowDate)) {
            return {
              success: true,
              pre_wish_mode: true,
              data: {
                party_id: partyId,
                party_code: data.party_code != null ? String(data.party_code) : normalized,
                party_name: data.party_name || data.partyName || null,
                start_time_posix: startPosix || 0,
                timezone_id: data.timezone_id || 'UTC',
                allow_pre_wishes: true,
                party_snapshot: partySnapshotFromData(data)
              }
            };
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
            party_name: data.party_name || data.partyName || null,
            party_snapshot: partySnapshotFromData(data)
          }
        };
      }

      function queryField(field, value) {
        var q = queryFn(partiesRef, whereFn(field, '==', value));
        return getDocsFn(q);
      }

      /** Einzelne Join-Queries dürfen nicht die ganze Prüfung killen (z. B. permission-denied auf einem Index). */
      function safeQueryDocs(field, value) {
        return queryField(field, value)
          .then(function (snap) {
            return snap && snap.docs ? snap.docs.slice() : [];
          })
          .catch(function (err) {
            if (typeof window !== 'undefined' && window.IS_DEBUG) {
              console.warn('party_shared: Join-Code-Query fehlgeschlagen:', field, err && err.code);
            }
            return [];
          });
      }

      function mergeUniqueById(docArrays) {
        var seen = Object.create(null);
        var out = [];
        docArrays.forEach(function (docs) {
          if (!docs) return;
          for (var i = 0; i < docs.length; i++) {
            var doc = docs[i];
            if (!doc || !doc.id) continue;
            if (!seen[doc.id]) {
              seen[doc.id] = true;
              out.push(doc);
            }
          }
        });
        return out;
      }

      return collectJoinCodePartyDocs(normalized).then(function (allDocs) {
        if (!allDocs || allDocs.length === 0) return rateLimitFail();
        var nowDate = new Date();
        var joinable = allDocs.filter(function (doc) {
          return vbIsPartyGuestJoinable(doc.data(), nowDate);
        });
        if (joinable.length > 1) {
          setRateLimitState(0, 0);
          var floorOptions = joinable.map(vbFloorOptionFromDoc);
          floorOptions.sort(function (a, b) {
            return String(a.floor_label || '').localeCompare(String(b.floor_label || ''));
          });
          return {
            success: false,
            type: 'select_floor',
            join_code: normalized,
            floor_options: floorOptions
          };
        }
        if (joinable.length === 1) {
          return processFoundDoc(joinable[0]);
        }
        var best = pickBestPartyDocForJoinCode(allDocs, nowDate);
        if (!best) return rateLimitFail();
        return processFoundDoc(best);
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
    try {
      var utcDate = new Date(timePosix * 1000);
      return formatClockForLang(utcDate, lang, timezoneId || 'UTC', false);
    } catch (e) {
      return '';
    }
  }

  /** Lokale Uhrzeit (ohne Zeitzone) — languages.json time_style. */
  function formatLocaleClock(date, lang) {
    return formatClockForLang(date, lang, null, false);
  }

  /**
   * Datum (yMd) in Party-Zeitzone — wie Flutter [FormattingUtils.formatDateForLocale].
   */
  function formatPartyLocalDateYmd(timePosix, timezoneId, lang) {
    var locale = getPartyLocale(lang);
    try {
      var utcDate = new Date(timePosix * 1000);
      return new Intl.DateTimeFormat(locale, {
        timeZone: timezoneId || 'UTC',
        day: 'numeric',
        month: 'numeric',
        year: 'numeric'
      }).format(utcDate);
    } catch (e) {
      return new Date(timePosix * 1000).toLocaleDateString(locale);
    }
  }

  function formatPartyLocalTimeWithSuffix(timePosix, timezoneId, lang, t) {
    try {
      var utcDate = new Date(timePosix * 1000);
      var style = partyTimeStyle(lang);
      if (style === 'fr_h' || style === 'h_compact' || style === 'pt_h' || style === 'ja_kanji') {
        return formatClockForLang(utcDate, lang, timezoneId || 'UTC', false);
      }
      return formatClockForLang(utcDate, lang, timezoneId || 'UTC', true);
    } catch (e) {
      return '';
    }
  }

  /**
   * Wie Flutter party_start_at: {date} + {time} (inkl. time_suffix, z. B. DE „ Uhr“).
   */
  function formatPartyStartAtLine(timePosix, timezoneId, lang, t) {
    var dateStr = formatPartyLocalDateYmd(timePosix, timezoneId, lang);
    var timeStr = formatPartyLocalTimeWithSuffix(timePosix, timezoneId, lang, t);
    var tpl = '';
    if (typeof t === 'function') {
      tpl = (t('party_start_at', '') || '').trim();
    }
    if (tpl) {
      return String(tpl).replace(/\{date\}/g, dateStr).replace(/\{time\}/g, timeStr);
    }
    var fallback = (typeof t === 'function' && t('main_party_starts_at', '')) || 'Starts at {time}';
    return String(fallback).replace(/\{time\}/g, timeStr);
  }

  /**
   * Uhrzeit + optionales time_suffix (z. B. DE „ Uhr“).
   */
  function formatLocaleClockWithSuffix(date, lang, t) {
    void t;
    var style = partyTimeStyle(lang);
    if (style === 'fr_h' || style === 'h_compact' || style === 'pt_h' || style === 'ja_kanji' || style === 'intl_12') {
      return formatClockForLang(date, lang, null, false);
    }
    return formatClockForLang(date, lang, null, true);
  }

  /**
   * Kompakte Zeile Datum + Uhrzeit (z. B. Vorab-Header) — wie Flutter formatCompactDateTimeLine.
   */
  function formatLocaleCompactDateTime(date, lang, t) {
    if (!date || !(date instanceof Date) || isNaN(date.getTime())) return '';
    var locale = getPartyLocale(lang);
    var datePart;
    try {
      datePart = new Intl.DateTimeFormat(locale, {
        day: 'numeric',
        month: 'numeric',
        year: 'numeric'
      }).format(date);
    } catch (e) {
      datePart = date.toLocaleDateString(locale);
    }
    return datePart + ' ' + formatLocaleClockWithSuffix(date, lang, t);
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
  function formatPartyShortDateTime(date, lang, t) {
    void t;
    if (!date || !(date instanceof Date)) return '';
    var locale = getPartyLocale(lang);
    var datePart;
    try {
      datePart = new Intl.DateTimeFormat(locale, {
        day: 'numeric',
        month: 'numeric',
        year: 'numeric'
      }).format(date);
    } catch (e) {
      datePart = date.toLocaleDateString(locale);
    }
    return datePart + ' ' + formatLocaleClockWithSuffix(date, lang, null);
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

  /** Wünsche unter parties/{partyId}/wishes (keine Root-Collection mehr). */
  function vbPartyWishesCollection(partyId) {
    if (!hasFirebaseGlobals() || !partyId || partyId === 'manual' || partyId === 'manuell') {
      return null;
    }
    var partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, PARTIES_COLLECTION), partyId);
    return window.firebaseCollection(partyRef, 'wishes');
  }

  function vbPartyWishDoc(partyId, wishId) {
    var col = vbPartyWishesCollection(partyId);
    if (!col || !wishId) return null;
    return window.firebaseDoc(col, wishId);
  }

  if (typeof window !== 'undefined') {
    window.vbPartyWishesCollection = vbPartyWishesCollection;
    window.vbPartyWishDoc = vbPartyWishDoc;
    window.checkPartyCode = checkPartyCode;
    window.vbCollectJoinCodePartyDocs = collectJoinCodePartyDocs;
    window.vbIsPartyGuestJoinable = vbIsPartyGuestJoinable;
    window.vbIsPartyEnded = vbIsPartyEnded;
    window.vbEffectiveFloorKey = vbEffectiveFloorKey;
    window.vbRawFloorLabel = vbRawFloorLabel;
    window.VB_DEFAULT_FLOOR_KEY = VB_DEFAULT_FLOOR_KEY;
    window.vbFloorOptionFromDoc = vbFloorOptionFromDoc;
    window.partySnapshotFromData = partySnapshotFromData;
    window.pickBestPartyDocForJoinCode = pickBestPartyDocForJoinCode;
    window.getPartyLocale = getPartyLocale;
    window.partyHour12 = partyHour12;
    window.formatClockForLang = formatClockForLang;
    window.formatPartyLocalTime = formatPartyLocalTime;
    window.formatPartyLocalTimeWithSuffix = formatPartyLocalTimeWithSuffix;
    window.formatPartyLocalDateYmd = formatPartyLocalDateYmd;
    window.formatPartyStartAtLine = formatPartyStartAtLine;
    window.formatPartyLocalDate = formatPartyLocalDate;
    window.formatPartyShortDateTime = formatPartyShortDateTime;
    window.formatLocaleClock = formatLocaleClock;
    window.formatLocaleClockWithSuffix = formatLocaleClockWithSuffix;
    window.formatLocaleCompactDateTime = formatLocaleCompactDateTime;
    window.formatDuration = formatDuration;
    window.calculateTimeUntilParty = calculateTimeUntilParty;
    window.vbIsPreWishWindowOpen = vbIsPreWishWindowOpen;
    window.vbPreWishDeadlineMs = vbPreWishDeadlineMs;
    window.partyStartDateFromData = partyStartDateFromData;
    window.PRE_WISH_CLOSE_HOURS = PRE_WISH_CLOSE_HOURS;
  }
})();
