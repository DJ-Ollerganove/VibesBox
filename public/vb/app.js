    /** Einheitlicher Join-Code (8 Ziffern) in sessionStorage — Root setzt vor URL-Stripping; /vb leitet nur ohne Key nach /. */
    window.vbSessionPartyCodeKey = 'vb_session_party_code';
    window.vbGetSessionPartyCode8 = function vbGetSessionPartyCode8() {
      try {
        if (typeof sessionStorage === 'undefined') return null;
        var v = sessionStorage.getItem(window.vbSessionPartyCodeKey);
        if (!v) return null;
        var d = String(v).replace(/\D/g, '').substring(0, 8);
        return (d.length === 8 && /^\d+$/.test(d)) ? d : null;
      } catch (e) {
        return null;
      }
    };

    /** Party-Code aus ?code=, Pfad (/vb/p/…, /p/… wie Flutter-Deep-Link), Hash oder Session [vb_session_party_code]. */
    window.vbGetPartyCodeFromUrl = function vbGetPartyCodeFromUrl() {
      function persistEightDigits(digits) {
        if (!digits || digits.length !== 8 || typeof sessionStorage === 'undefined') return;
        try {
          sessionStorage.setItem(window.vbSessionPartyCodeKey, digits);
        } catch (eS) {}
      }
      function eightFromSeg(seg) {
        if (seg == null) return null;
        var d = String(seg).replace(/\D/g, '').substring(0, 8);
        return (d.length === 8 && /^\d+$/.test(d)) ? d : null;
      }
      try {
        var sp = new URLSearchParams(window.location.search || '');
        var c = sp.get('code');
        if (c != null && String(c).trim() !== '') {
          var dQ = String(c).replace(/\D/g, '').substring(0, 8);
          if (dQ.length === 8) persistEightDigits(dQ);
          try { if (typeof sessionStorage !== 'undefined') sessionStorage.removeItem('vb_pending_join_code'); } catch (eClr) {}
          return String(c).trim();
        }

        var path = window.location.pathname || '';
        var segments = path.split('/').filter(function (s) { return s.length > 0; });
        var i;
        for (i = 0; i < segments.length - 1; i++) {
          var seg = segments[i].toLowerCase();
          if (seg === 'p' || seg === 'party') {
            var fromPair = eightFromSeg(segments[i + 1]);
            if (fromPair) {
              persistEightDigits(fromPair);
              return fromPair;
            }
          }
        }
        if (segments.length > 0) {
          var lastEight = eightFromSeg(segments[segments.length - 1]);
          if (lastEight) {
            persistEightDigits(lastEight);
            return lastEight;
          }
        }

        var rawHash = window.location.hash || '';
        if (!rawHash) {
          var sOnly = typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : null;
          return sOnly || null;
        }
        var hash = rawHash.replace(/^#/, '');
        var qPart = '';
        var qi = hash.indexOf('?');
        if (qi >= 0) qPart = hash.substring(qi + 1);
        else if (hash.indexOf('code=') !== -1) qPart = hash;
        else {
          var sH0 = typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : null;
          return sH0 || null;
        }
        var hp = new URLSearchParams(qPart);
        c = hp.get('code');
        if (c != null && String(c).trim() !== '') {
          var dH = String(c).replace(/\D/g, '').substring(0, 8);
          if (dH.length === 8) persistEightDigits(dH);
          return String(c).trim();
        }

        try {
          var pth = (window.location.pathname || '').toLowerCase();
          if (pth.indexOf('/vb') !== -1 && typeof sessionStorage !== 'undefined') {
            var pend = sessionStorage.getItem('vb_pending_join_code');
            if (pend != null && String(pend).trim() !== '') return String(pend).trim();
          }
        } catch (ePend) {}
        var sEnd = typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : null;
        return sEnd || null;
      } catch (e) {}
      return typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : null;
    };

    /** Nach Login/Strip: /vb/p/12345678 → /vb/ (damit replaceState nicht den QR-Pfad stehen lässt). */
    window.vbNormalizedWishboxPathname = function vbNormalizedWishboxPathname() {
      try {
        var raw = window.location.pathname || '/';
        var trimmed = raw.replace(/\/+$/, '');
        if (!trimmed) trimmed = '/';
        var stripped = trimmed.replace(/\/(p|party)\/\d{8}$/i, '');
        if (stripped !== trimmed) return (stripped || '/') + '/';
        return raw;
      } catch (e2) {
        return window.location.pathname || '/';
      }
    };

    // ✅ Sofort: Loading-Overlay-Text setzen (QR-Code vs. Standard) – vor allen anderen Aktionen
    (function() {
      window.bodyLoadError = false;
      var codeInUrl = typeof window.vbGetPartyCodeFromUrl === 'function' ? window.vbGetPartyCodeFromUrl() : null;
      var el = document.getElementById('loading-overlay-text');
      var overlay = document.getElementById('loading-overlay');
      if (codeInUrl) {
        if (overlay) overlay.style.display = 'flex';
        if (el) el.textContent = (typeof getTranslation === 'function' ? getTranslation('loading_party_connection') : null) || 'Connecting to the party...';
      } else if (el) {
        if (typeof getTranslation === 'function') el.textContent = getTranslation('loading_data');
        else el.textContent = 'Loading data...';
      }
    })();

    /** /vb/: Nur URL ?lang= spiegelt sich früh in den Speicher (für party_shared Intl u. a.). */
    (function vbMirrorEarlyLanguageToStorage() {
      try {
        if (typeof localStorage === 'undefined') return;
        var fromUrl = (typeof window.readPwaUrlLangParam === 'function') ? window.readPwaUrlLangParam() : '';
        if (fromUrl && typeof window.persistUrlLanguageToAllStorage === 'function') {
          window.persistUrlLanguageToAllStorage(fromUrl);
        }
      } catch (e) {}
    })();

    /** Aktive Sprache: geladenes Paket, sonst nur URL (vb-url-lang.js), Fallback en. */
    window.vbGetResolvedPwaLanguageCode = function vbGetResolvedPwaLanguageCode() {
      try {
        if (typeof window.__vbActiveLang === 'string' && window.__vbActiveLang) return window.__vbActiveLang;
        if (typeof window.vbGetResolvedLangFromUrlOnly === 'function') return window.vbGetResolvedLangFromUrlOnly();
      } catch (e) {}
      return 'en';
    };

    /** Nach Party-Login: Code/Join-Pfad aus URL entfernen, ?lang= / aktive Sprache beibehalten. */
    window.vbReplaceStateStripPartyCodeKeepLang = function vbReplaceStateStripPartyCodeKeepLang() {
      try {
        var path = (typeof window.vbNormalizedWishboxPathname === 'function') ? window.vbNormalizedWishboxPathname() : (window.location.pathname || '/');
        var lang = '';
        if (typeof window.readPwaUrlLangParam === 'function') lang = window.readPwaUrlLangParam();
        if (!lang && typeof window.vbGetResolvedPwaLanguageCode === 'function') lang = window.vbGetResolvedPwaLanguageCode();
        var suffix = lang ? ('?lang=' + encodeURIComponent(lang)) : '';
        window.history.replaceState({}, document.title, path + suffix);
      } catch (e) {
        try {
          window.history.replaceState({}, document.title, (typeof window.vbNormalizedWishboxPathname === 'function' ? window.vbNormalizedWishboxPathname() : window.location.pathname));
        } catch (e2) {}
      }
    };

    /** /vb/: Code aus URL sofort in Session, dann Adresse bereinigen (einheitlich mit Root). */
    (function vbPromotePartyCodeFromUrlToSessionThenStrip() {
      try {
        var p = (window.location.pathname || '').toLowerCase();
        if (p.indexOf('/vb') === -1) return;
        var raw = typeof window.vbGetPartyCodeFromUrl === 'function' ? window.vbGetPartyCodeFromUrl() : null;
        if (!raw) return;
        var digits = String(raw).replace(/\D/g, '').substring(0, 8);
        if (digits.length !== 8 || !/^\d+$/.test(digits)) return;
        if (typeof sessionStorage !== 'undefined') {
          try {
            sessionStorage.setItem(window.vbSessionPartyCodeKey, digits);
          } catch (eS) {}
        }
        if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') {
          window.vbReplaceStateStripPartyCodeKeepLang();
        }
      } catch (ePr) {}
    })();

    /** Boot-Race: checkWishboxStatus erst nach processQRCodeLogin (verhindert parallelen clearPartyData-Redirect). */
    window.__vbDeferWishboxStatusUntilBoot = true;

    function vbIsOnWishboxPath() {
      try {
        return (window.location.pathname || '').toLowerCase().indexOf('/vb') !== -1;
      } catch (e) {
        return false;
      }
    }

    function vbHasPendingJoinCode8() {
      try {
        if (typeof sessionStorage === 'undefined') return false;
        var pend = sessionStorage.getItem('vb_pending_join_code');
        if (pend && String(pend).replace(/\D/g, '').length >= 8) return true;
      } catch (e) {}
      try {
        var ls = localStorage.getItem('pending_party_code');
        if (ls && String(ls).replace(/\D/g, '').length >= 8) return true;
      } catch (e2) {}
      return false;
    }

    /** True wenn Gast gerade per QR/Code joined oder ein Status-Modal/Floor-Picker sichtbar ist. */
    function vbHasAnyJoinFlowSignal() {
      if (typeof window.vbGetSessionPartyCode8 === 'function' && window.vbGetSessionPartyCode8()) return true;
      if (vbHasPendingJoinCode8()) return true;
      if (document.getElementById('partyCodeErrorModalOverlay')) return true;
      if (document.getElementById('vbPartyEndedOverlay')) return true;
      var floorOv = document.getElementById('guestFloorPickerOverlay');
      if (floorOv && floorOv.style.display !== 'none') return true;
      return false;
    }

    function vbGetActiveJoinCode8() {
      try {
        if (typeof window.vbGetSessionPartyCode8 === 'function') {
          var s = window.vbGetSessionPartyCode8();
          if (s) return s;
        }
      } catch (e0) {}
      try {
        var raw = typeof window.vbGetPartyCodeFromUrl === 'function' ? window.vbGetPartyCodeFromUrl() : null;
        if (raw != null && String(raw).trim() !== '') {
          var d = String(raw).replace(/\D/g, '').substring(0, 8);
          if (d.length === 8 && /^\d+$/.test(d)) return d;
        }
      } catch (e1) {}
      return null;
    }

    /** Nur validated*-Felder — Join-Code in Session bleibt erhalten. */
    function vbClearStaleValidatedPartyStorage() {
      try {
        localStorage.removeItem('validatedPartyId');
        localStorage.removeItem('validatedPartyCode');
        localStorage.removeItem('validatedPartyName');
        localStorage.removeItem('currentPartyName');
        sessionStorage.removeItem('validatedPartyId');
        sessionStorage.removeItem('validatedPartyCode');
        sessionStorage.removeItem('validatedPartyName');
        sessionStorage.removeItem('currentPartyName');
      } catch (e) {}
    }

    /** Neuer QR/Session-Code ≠ gespeicherte Party → alte validated*-Daten entfernen (Race vor Auto-Login). */
    function vbClearStaleValidatedPartyIfJoinCodeMismatch() {
      try {
        var join8 = vbGetActiveJoinCode8();
        if (!join8) return false;
        var storedCode = localStorage.getItem('validatedPartyCode') || sessionStorage.getItem('validatedPartyCode');
        var storedEight = storedCode ? String(storedCode).replace(/\D/g, '').substring(0, 8) : '';
        if (storedEight === join8) return false;
        var hasStale = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId') || storedCode;
        if (!hasStale) return false;
        if (window.IS_DEBUG) console.log('vbClearStaleValidatedPartyIfJoinCodeMismatch: neuer Code', join8, '— alte Party-Daten entfernen');
        vbClearStaleValidatedPartyStorage();
        return true;
      } catch (e) {}
      return false;
    }

    function vbMaybeCheckWishboxStatus(options) {
      if (window.__vbDeferWishboxStatusUntilBoot === true) {
        if (window.IS_DEBUG) console.log('vbMaybeCheckWishboxStatus: Boot läuft — überspringe');
        return;
      }
      checkWishboxStatus(options);
    }

    /** Redirect zur Root — auf /vb/ nur bei direktem Besuch ohne Code; nie während Join/Status-Modal. */
    function vbRedirectToRootPwa(reason, force) {
      if (force) {
        window.location.replace('/');
        return;
      }
      if (vbHasAnyJoinFlowSignal()) {
        if (window.IS_DEBUG) console.log('vbRedirectToRootPwa: Join-Signal — kein Redirect (' + (reason || '') + ')');
        if (typeof updateWishboxUI === 'function') updateWishboxUI();
        return;
      }
      var allowLeaveVb = (reason === 'entryGate' || reason === 'bootNoCode');
      if (vbIsOnWishboxPath() && !allowLeaveVb) {
        if (window.IS_DEBUG) console.log('vbRedirectToRootPwa: bleibe auf /vb/ (' + (reason || '') + ')');
        if (typeof updateWishboxUI === 'function') updateWishboxUI();
        return;
      }
      if (window.IS_DEBUG) console.log('vbRedirectToRootPwa:', reason || '(ohne Grund)');
      window.location.replace('/');
    }

    /** Storage + data-i18n / Titel nach Navigation (Header nutzt oft nur localStorage — hier abgleichen). */
    window.vbApplyResolvedLanguageToUi = function vbApplyResolvedLanguageToUi() {
      try {
        var lang = window.vbGetResolvedPwaLanguageCode();
        if (lang && typeof window.persistUrlLanguageToAllStorage === 'function') {
          window.persistUrlLanguageToAllStorage(lang);
        }
        if (typeof window.applyTranslationsAndUI === 'function') {
          window.applyTranslationsAndUI(lang);
        } else if (typeof window.translatePage === 'function') {
          window.translatePage();
        }
        if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
        if (typeof window.updateDrawerCurrentLanguage === 'function') window.updateDrawerCurrentLanguage();
      } catch (e) {}
    };

    if (window.IS_DEBUG) {
      console.log('DEBUG PWA: Storage beim Start', {
        local_validated: localStorage.getItem('validatedPartyId'),
        session_validated: sessionStorage.getItem('validatedPartyId'),
        local_pending: localStorage.getItem('pendingPartyId'),
        all_keys: Object.keys(localStorage)
      });
    }

    // ✅ 200ms-Timeout-Redirect entfernt – Redirect erfolgt erst nach Firebase-Resultat (processQRCodeLogin)

    // Firebase Cloud Function URL
    const SPOTIFY_FUNCTION_URL = 'https://us-central1-dj-ollerganove.cloudfunctions.net/searchSpotifyTracks';
    const PUBLIC_DJ_PROFILE_FUNCTION_URL = 'https://us-central1-dj-ollerganove.cloudfunctions.net/getPublicDjProfile';

    async function fetchPublicDjProfile(uid) {
      const cleanUid = typeof uid === 'string' ? uid.trim() : '';
      if (!cleanUid) return null;

      const response = await fetch(PUBLIC_DJ_PROFILE_FUNCTION_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ uid: cleanUid }),
      });

      if (!response.ok) {
        if (window.IS_DEBUG) console.warn('⚠️ getPublicDjProfile fehlgeschlagen:', response.status);
        return null;
      }

      const data = await response.json();
      return (data && typeof data === 'object') ? data : null;
    }

    function sanitizePartyData(raw) {
      const src = (raw && typeof raw === 'object') ? raw : {};
      const clean = {};

      if (typeof src.party_name === 'string') clean.party_name = src.party_name;
      if (typeof src.party_code === 'string') clean.party_code = src.party_code;
      if (typeof src.dj_logo === 'string') clean.dj_logo = src.dj_logo;
      if (typeof src.lifecycle_status === 'string') clean.lifecycle_status = src.lifecycle_status;

      const startPosix = Number(src.start_time_posix);
      if (Number.isFinite(startPosix) && startPosix > 0) clean.start_time_posix = startPosix;

      const endPosix = Number(src.end_time_posix);
      if (Number.isFinite(endPosix) && endPosix > 0) clean.end_time_posix = endPosix;

      return clean;
    }

    function sanitizeSocialsData(raw) {
      const src = (raw && typeof raw === 'object') ? raw : {};
      const clean = {};

      const orderSource = Array.isArray(src.order) ? src.order : (Array.isArray(src.socialOrder) ? src.socialOrder : []);
      const order = [];
      const seen = {};

      for (let i = 0; i < orderSource.length; i++) {
        const key = String(orderSource[i] || '').trim().toLowerCase();
        if (!key || seen[key]) continue;
        seen[key] = true;
        order.push(key);
      }

      if (Array.isArray(src.platforms)) {
        for (let i = 0; i < src.platforms.length; i++) {
          const entry = src.platforms[i] || {};
          const key = String(entry.id || '').trim().toLowerCase();
          const url = String(entry.url || '').trim();
          if (!key || !(url.startsWith('https://') || url.startsWith('http://'))) continue;
          clean[key] = url;
          if (!seen[key]) {
            seen[key] = true;
            order.push(key);
          }
        }
      }

      const keys = Object.keys(src);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        if (key === 'order' || key === 'socialOrder' || key === 'platforms') continue;
        const val = src[key];
        if (typeof val !== 'string') continue;
        const url = val.trim();
        if (!(url.startsWith('https://') || url.startsWith('http://'))) continue;
        clean[key] = url;
        const normalized = key.trim().toLowerCase();
        if (!seen[normalized]) {
          seen[normalized] = true;
          order.push(normalized);
        }
      }

      clean.order = order;
      return clean;
    }

    function vbReadCachedDjSocials() {
      try {
        var raw = sessionStorage.getItem('currentDjSocials');
        if (!raw) return null;
        var parsed = JSON.parse(raw);
        if (!parsed || typeof parsed !== 'object') return null;
        return sanitizeSocialsData(parsed);
      } catch (e) {
        return null;
      }
    }

    function vbSocialsHaveLinks(socialsData) {
      if (!socialsData) return false;
      var order = socialsData.order || socialsData.socialOrder || [];
      if (order.length > 0) return true;
      return Object.keys(socialsData).some(function (k) {
        return k !== 'order' && k !== 'socialOrder' && socialsData[k];
      });
    }

    async function vbFetchRemoteDjSocials() {
      var uid = (sessionStorage.getItem('validatedPartyDjId') || localStorage.getItem('validatedPartyDjId') || '').trim();
      if (!uid) {
        var validatedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
        if (!validatedPartyId || validatedPartyId === 'manual' || validatedPartyId === '') return null;
        try {
          var partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), validatedPartyId);
          var partyDoc = await window.firebaseGetDoc(partyRef);
          if (!partyDoc.exists()) return null;
          uid = String(partyDoc.data().created_by || '').trim();
          if (uid) {
            sessionStorage.setItem('validatedPartyDjId', uid);
            localStorage.setItem('validatedPartyDjId', uid);
          }
        } catch (eParty) {
          if (window.IS_DEBUG) console.warn('vbFetchRemoteDjSocials party:', eParty);
          return null;
        }
      }
      if (!uid) return null;
      try {
        var socialsRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'social_media_links'), uid);
        var socialsSnap = await window.firebaseGetDoc(socialsRef);
        if (!socialsSnap || !socialsSnap.exists()) return null;
        var socialsData = sanitizeSocialsData(socialsSnap.data());
        try { sessionStorage.setItem('currentDjSocials', JSON.stringify(socialsData)); } catch (eStore) {}
        return socialsData;
      } catch (e) {
        if (window.IS_DEBUG) console.warn('vbFetchRemoteDjSocials:', e);
        return null;
      }
    }

    function vbApplyPartyDjLogo(logoContainer, logoImg, partyData) {
      if (!logoContainer || !logoImg || !partyData) return false;
      var planType = (sessionStorage.getItem('djPlanType') || '').toLowerCase();
      var logoUrl = (planType === 'free') ? 'icon/vibesbox-logo.png' : (partyData.dj_logo || null);
      if (logoUrl) {
        logoImg.src = logoUrl;
        logoImg.style.display = 'block';
        logoContainer.style.display = 'flex';
        return true;
      }
      logoContainer.style.display = 'none';
      return false;
    }
    
    // Debounce Timer
    let titleDebounceTimer = null;
    let artistDebounceTimer = null;
    let titleSearchAbortController = null; // Für Katalog-Modus: abbricht bei neuem Tippen
    
    // ✅ FINALE Globale currentClientId Variable (wird beim Seitenladen initialisiert)
    let currentClientId = null;
    
    // Wunschbox Status
    let isWishboxActive = false;
    let vbFloorPickerOptions = null;
    let vbFloorSelectionActive = false;
    let vbFloorJoinInProgress = false;
    let vbMultiFloorAvailable = false;
    let vbPendingJoinCodeForFloorPick = null;
    let vbFloorEndedRedirectLabel = null;

    function vbIsFloorPickerActive() {
      return vbFloorSelectionActive === true
        || (vbFloorPickerOptions && vbFloorPickerOptions.length > 0);
    }
    let isPreWishMode = false;
    /** Vorab-Wünsche vom DJ pausiert — Wunschbox darf nicht erscheinen (auch nach Poll). */
    let isPreWishesPausedMode = false;
    let isBlocked = false;
    let partyCodeFromUrl = null;
    let blockStatusListeners = []; // Permanente Realtime-Listener für Block-Status
    let blockedByGuestRealtime = false;
    let blockedByDeviceRealtime = false;
    let blockedByUserRealtime = false;
    /** True wenn Firestore-Schreib-/Channel-Fehler (permission / 400) → sofort Sperr-UI wie bei Blockliste */
    let blockedByWriteDenied = false;
    /** False bis checkBlockStatus die ersten getDoc-Reads abgeschlossen hat (kein Formular-Flackern) */
    let wishboxBlockGateResolved = false;
    let isSubmitting = false; // Flag um mehrfaches Absenden zu verhindern
    let prePartyCountdownInterval = null; // Interval für Pre-Party Countdown
    let wishLimitUnsubscribe = null; // ✅ Unsubscribe-Funktion für beide Realtime-Streams (Party + Wünsche)
    let currentPartyStartDate = null; // Start-Datum der aktuellen Party
    /** DJ-Einstellung: Wortvorschläge in der Wunschbox (guest_live/wishbox, Standard an). */
    let wishboxSuggestionsEnabled = true;
    let wishboxGuestLiveUnsub = null;

    function vbParseWishboxSuggestionsEnabled(data) {
      if (!data) return true;
      return data.wishbox_suggestions_enabled !== false;
    }

    function vbApplyWishboxSuggestionsUi(enabled) {
      wishboxSuggestionsEnabled = !!enabled;
      const hint = document.querySelector('.wishbox-suggestions-hint');
      if (hint) hint.style.display = enabled ? '' : 'none';
      if (!enabled) {
        if (titleSuggestions) {
          titleSuggestions.classList.remove('show');
          titleSuggestions.innerHTML = '';
        }
        if (artistSuggestions) {
          artistSuggestions.classList.remove('show');
          artistSuggestions.innerHTML = '';
        }
      }
    }

    function vbUnbindWishboxGuestLiveStream() {
      if (wishboxGuestLiveUnsub) {
        try { wishboxGuestLiveUnsub(); } catch (_) {}
        wishboxGuestLiveUnsub = null;
      }
    }

    function vbBindWishboxFromPartyData(partyData) {
      const djUid = (partyData && typeof partyData.created_by === 'string')
        ? partyData.created_by.trim()
        : '';
      if (!djUid) return;
      try {
        sessionStorage.setItem('validatedPartyDjId', djUid);
        localStorage.setItem('validatedPartyDjId', djUid);
      } catch (_) {}
      vbBindWishboxGuestLiveStream(djUid);
      vbBindSongBlacklistWatch(djUid);
    }

    function vbBindSongBlacklistWatch(djId) {
      if (typeof window.vbStartSongBlacklistWatch !== 'function') return;
      var partyId = '';
      try {
        partyId = sessionStorage.getItem('validatedPartyId') ||
          localStorage.getItem('validatedPartyId') || '';
      } catch (_) {}
      window.vbStartSongBlacklistWatch(djId, partyId, function (state) {
        if (state && state.enabled === false) {
          hideBlacklistErrorIfShowing();
        }
      });
    }

    async function vbBindWishboxGuestLiveStream(djId) {
      const uid = String(djId || '').trim();
      if (!uid || !window.firebaseDb) return;
      vbUnbindWishboxGuestLiveStream();
      try {
        const wishboxRef = window.firebaseDoc(
          window.firebaseCollection(
            window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'users'), uid),
            'guest_live'
          ),
          'wishbox'
        );
        const snap = await window.firebaseGetDoc(wishboxRef);
        vbApplyWishboxSuggestionsUi(vbParseWishboxSuggestionsEnabled(snap.exists() ? snap.data() : null));
        if (typeof window.onSnapshot === 'function') {
          wishboxGuestLiveUnsub = window.onSnapshot(wishboxRef, (live) => {
            vbApplyWishboxSuggestionsUi(vbParseWishboxSuggestionsEnabled(live.exists() ? live.data() : null));
          });
        }
      } catch (e) {
        if (window.IS_DEBUG) console.warn('guest_live/wishbox:', e);
      }
    }

    /**
     * UI-Strings (innerHTML/showError): nutzt window.getTranslation zur Laufzeit.
     * Zweites Argument = englischer Fallback, wenn Übersetzung fehlt (früher war t nie definiert → nur Fallbacks).
     */
    function t(key, enFallback) {
      var lang = window.__vbActiveLang || 'en';
      var bundle = window.translations && window.translations[lang];
      if (!bundle && window['lang_' + lang]) {
        bundle = window['lang_' + lang];
      }
      if (bundle && bundle[key]) return bundle[key];
      if (typeof window.getTranslation === 'function') {
        try {
          var s = window.getTranslation(key);
          if (s != null && String(s) !== '' && s !== key) return s;
        } catch (eT) {}
      }
      return arguments.length >= 2 ? enFallback : undefined;
    }
    
    // Ausgewählter Spotify Track (wenn von Spotify ausgewählt)
    let selectedSpotifyTrack = null;
    // Gewählter Künstler aus Artist-Suche (für abhängige Titelsuche)
    let currentSelectedArtist = null; // { id, name } oder null

    // DOM Elements
    const form = document.getElementById('wishForm');
    const nameInput = document.getElementById('name');
    const titleInput = document.getElementById('title');
    const artistInput = document.getElementById('artist');
    const greetingInput = document.getElementById('greeting');
    const titleSuggestions = document.getElementById('titleSuggestions');
    const artistSuggestions = document.getElementById('artistSuggestions');
    const titleLoading = document.getElementById('titleLoading');
    const artistLoading = document.getElementById('artistLoading');
    const submitBtn = document.getElementById('submitBtn');
    const errorMessage = document.getElementById('errorMessage');
    const successMessage = document.getElementById('successMessage');
    const charCount = document.getElementById('charCount');
    const nameCharCount = document.getElementById('nameCharCount');
    const titleCharCount = document.getElementById('titleCharCount');
    const artistCharCount = document.getElementById('artistCharCount');
    const contactNameCharCount = document.getElementById('contactNameCharCount');
    const contactEmailCharCount = document.getElementById('contactEmailCharCount');
    const contactPhoneCharCount = document.getElementById('contactPhoneCharCount');
    const contactSubjectCharCount = document.getElementById('contactSubjectCharCount');

    // Spotify-Suche für Titel
    titleInput.addEventListener('input', (e) => {
      if (!wishboxSuggestionsEnabled) return;
      const query = e.target.value.trim();

      clearTimeout(titleDebounceTimer);
      if (titleSearchAbortController) {
        titleSearchAbortController.abort();
        titleSearchAbortController = null;
      }

      if (selectedSpotifyTrack && query !== selectedSpotifyTrack.name) {
        selectedSpotifyTrack = null;
      }

      if (query.length === 0) {
        titleSuggestions.classList.remove('show');
        titleSuggestions.innerHTML = '';
        return;
      }

      titleDebounceTimer = setTimeout(async () => {
        titleSearchAbortController = new AbortController();
        const signal = titleSearchAbortController.signal;
        let searchQuery = query;
        if (currentSelectedArtist && currentSelectedArtist.name) {
          const cleanArtist = currentSelectedArtist.name.replace(/"/g, '');
          const cleanTrack = query.replace(/"/g, '');
          searchQuery = `artist:"${cleanArtist}" track:"${cleanTrack}"`;
        }
        await searchSpotify(searchQuery, 'track', titleSuggestions, titleLoading, (track) => {
          titleInput.value = track.name;
          artistInput.value = track.artists;
          selectedSpotifyTrack = track;
          currentSelectedArtist = { id: (track.artist_ids && track.artist_ids[0]) || null, name: track.artists };
          titleSuggestions.classList.remove('show');
        }, { signal });
      }, 500);
    });

    // Katalog-Modus: Fokus auf leeres Titel-Feld + Künstler gewählt → Top-Songs laden
    titleInput.addEventListener('focus', () => {
      if (!wishboxSuggestionsEnabled) return;
      const isEmpty = !titleInput.value || titleInput.value.trim().length === 0;
      if (!isEmpty || !currentSelectedArtist || !currentSelectedArtist.name) return;

      if (titleSearchAbortController) {
        titleSearchAbortController.abort();
      }
      titleSearchAbortController = new AbortController();
      const signal = titleSearchAbortController.signal;

      const cleanArtist = currentSelectedArtist.name.replace(/"/g, '');
      const catalogQuery = `artist:"${cleanArtist}"`;
      let hintText = (typeof getTranslation === 'function' ? getTranslation('catalog_top_songs') : '') || 'Top songs by {artist}';
      if (hintText === 'catalog_top_songs') hintText = 'Top songs by {artist}';
      hintText = hintText.replace('{artist}', currentSelectedArtist.name);

      searchSpotify(catalogQuery, 'track', titleSuggestions, titleLoading, (track) => {
        titleInput.value = track.name;
        artistInput.value = track.artists;
        selectedSpotifyTrack = track;
        currentSelectedArtist = { id: (track.artist_ids && track.artist_ids[0]) || null, name: track.artists };
        titleSuggestions.classList.remove('show');
      }, { signal, catalogHint: hintText });
    });

    // Spotify-Suche für Interpret
    artistInput.addEventListener('input', (e) => {
      if (!wishboxSuggestionsEnabled) return;
      const query = e.target.value.trim();

      clearTimeout(artistDebounceTimer);

      if (currentSelectedArtist && query !== currentSelectedArtist.name) {
        currentSelectedArtist = null;
      }
      if (selectedSpotifyTrack && query !== selectedSpotifyTrack.artists) {
        selectedSpotifyTrack = null;
      }

      if (query.length === 0) {
        artistSuggestions.classList.remove('show');
        artistSuggestions.innerHTML = '';
        currentSelectedArtist = null;
        return;
      }

      artistDebounceTimer = setTimeout(async () => {
        const cleanQuery = query.replace(/"/g, '');
        await searchSpotify(cleanQuery, 'artist', artistSuggestions, artistLoading, (artist) => {
          artistInput.value = artist.name;
          currentSelectedArtist = { id: artist.id || null, name: artist.name };
          selectedSpotifyTrack = null;
          titleInput.value = '';
          artistSuggestions.classList.remove('show');
        });
      }, 500);
    });

    // Spotify: Filter nur in der Cloud Function (searchSpotifyTracks) — keine doppelte Client-Filterung

    // Spotify-Suche Funktion
    // Verarbeitet resultType (artist | track) aus der Cloud Function
    // options: { signal?: AbortSignal, catalogHint?: string } – catalogHint = "Top-Songs von X" im Katalog-Modus
    async function searchSpotify(query, searchType, suggestionsContainer, loadingElement, onSelect, options) {
      if (!wishboxSuggestionsEnabled) return;
      const opts = options || {};
      const signal = opts.signal;
      const catalogHint = opts.catalogHint;
      const normalizedQuery = String(query || '').trim();

      if (normalizedQuery.length < 2) {
        loadingElement.classList.remove('show');
        suggestionsContainer.classList.remove('show');
        suggestionsContainer.innerHTML = '';
        return;
      }

      loadingElement.classList.add('show');
      suggestionsContainer.classList.remove('show');
      suggestionsContainer.innerHTML = '';

      const encodedQ = encodeURIComponent(normalizedQuery);
      const url = `${SPOTIFY_FUNCTION_URL}?q=${encodedQ}&type=${searchType}`;
      if (window.IS_DEBUG) console.log('Spotify Request:', { query, encodedQ, url, searchType, catalogHint: !!catalogHint });

      try {
        const headers = {};
        // Kein X-Client-Id: Rate-Limit nutzt dann IP/UA-Fallback in der Cloud Function; vermeidet CORS-Preflight-Probleme.
        if (typeof window.getFirebaseAppCheckToken === 'function') {
          try {
            const appCheckToken = await Promise.race([
              window.getFirebaseAppCheckToken(false),
              new Promise(function (_, rej) {
                setTimeout(function () { rej(new Error('APP_CHECK_TIMEOUT')); }, 3000);
              }),
            ]);
            if (appCheckToken) {
              headers['X-Firebase-AppCheck'] = appCheckToken;
            }
          } catch (acErr) {
            if (window.IS_DEBUG) console.warn('Spotify: App-Check-Token übersprungen:', acErr && acErr.message);
          }
        }

        // Hinweis: Vorschläge kommen von der Cloud Function searchSpotifyTracks (nicht von Firestore-Regeln für spotify_settings).
        const spotifyFetchTimeoutMs = 25000;
        const abortCtrl = new AbortController();
        var spotifyTid = setTimeout(function () { abortCtrl.abort(); }, spotifyFetchTimeoutMs);
        if (signal) {
          if (signal.aborted) {
            clearTimeout(spotifyTid);
            loadingElement.classList.remove('show');
            return;
          }
          signal.addEventListener('abort', function () {
            clearTimeout(spotifyTid);
            abortCtrl.abort();
          });
        }
        var response;
        try {
          response = await fetch(url, { headers: headers, signal: abortCtrl.signal });
        } finally {
          clearTimeout(spotifyTid);
        }
        if (window.IS_DEBUG) console.log('Spotify Response:', {
          status: response.status,
          statusText: response.statusText,
          ok: response.ok,
          url: response.url
        });

        if (!response.ok) {
          const bodyText = await response.text();
          console.error('Spotify Response Fehler-Body:', bodyText);
          throw new Error('Spotify-Suche fehlgeschlagen: ' + response.status + ' ' + response.statusText);
        }

        const data = await response.json();
        const resultType = data.resultType || (searchType === 'artist' ? 'artist' : 'track');
        const artists = data.artists || [];
        const tracks = data.tracks || [];
        if (window.IS_DEBUG) console.log('Spotify Response Daten:', { resultType, artistCount: artists.length, trackCount: tracks.length });

        if (resultType === 'artist' && artists.length > 0) {
          suggestionsContainer.innerHTML = '';
          const toShow = artists.slice(0, 20);
          toShow.forEach(artist => {
            const item = document.createElement('div');
            item.className = 'suggestion-item';
            const icon = document.createElement('span');
            icon.className = 'icon';
            icon.textContent = '🎤';
            const content = document.createElement('div');
            content.className = 'content';
            const nameDiv = document.createElement('div');
            nameDiv.className = 'title';
            nameDiv.textContent = artist.name || '';
            content.appendChild(nameDiv);
            item.appendChild(icon);
            item.appendChild(content);
            item.addEventListener('click', () => onSelect(artist));
            suggestionsContainer.appendChild(item);
          });
          suggestionsContainer.classList.add('show');
          if (window.IS_DEBUG) console.log('Spotify UI: ' + toShow.length + ' Artists angezeigt');
        } else if (resultType === 'track' && tracks.length > 0) {
          suggestionsContainer.innerHTML = '';
          if (catalogHint) {
            const hintDiv = document.createElement('div');
            hintDiv.className = 'suggestion-catalog-hint';
            hintDiv.textContent = catalogHint;
            suggestionsContainer.appendChild(hintDiv);
          }
          const toShow = tracks.slice(0, 20);
          toShow.forEach(track => {
            const item = document.createElement('div');
            item.className = 'suggestion-item';
            const icon = document.createElement('span');
            icon.className = 'icon';
            icon.textContent = '🎵';
            const content = document.createElement('div');
            content.className = 'content';
            const titleDiv = document.createElement('div');
            titleDiv.className = 'title';
            titleDiv.textContent = track.name || '';
            content.appendChild(titleDiv);
            const subtitleDiv = document.createElement('div');
            subtitleDiv.className = 'subtitle';
            subtitleDiv.textContent = track.artists || '';
            content.appendChild(subtitleDiv);
            item.appendChild(icon);
            item.appendChild(content);
            item.addEventListener('click', () => onSelect(track));
            suggestionsContainer.appendChild(item);
          });
          suggestionsContainer.classList.add('show');
          if (window.IS_DEBUG) console.log('Spotify UI: ' + toShow.length + ' Tracks angezeigt, Container:', suggestionsContainer.id, 'catalogHint:', !!catalogHint);
        } else {
          if (window.IS_DEBUG) console.log('Spotify UI: Keine Ergebnisse zum Anzeigen');
          else console.warn('Spotify-Suche: keine Treffer (API leer oder alles durch Nicht-Musik-Filter entfernt).');
        }
      } catch (error) {
        if (error && error.name === 'AbortError') {
          if (window.IS_DEBUG) console.log('Spotify-Suche abgebrochen (neue Anfrage)');
          return;
        }
        console.error('Spotify-Suche Fehler:', error);
      } finally {
        loadingElement.classList.remove('show');
      }
    }

    // Formular absenden
    function bindWishFormSubmit() {
      if (!form) {
        console.error('❌ wishForm nicht gefunden – Absenden nicht angebunden');
        return;
      }
      if (form.dataset.vbSubmitBound === '1') return;
      form.dataset.vbSubmitBound = '1';
      form.addEventListener('submit', handleWishFormSubmit);
      if (submitBtn) {
        submitBtn.addEventListener('click', function (ev) {
          if (ev.defaultPrevented) return;
          if (typeof form.requestSubmit === 'function') {
            form.requestSubmit();
          } else {
            form.dispatchEvent(new Event('submit', { cancelable: true, bubbles: true }));
          }
        });
      }
    }

    async function handleWishFormSubmit(e) {
      e.preventDefault();
      
      // WICHTIG: Verhindere mehrfaches Absenden
      if (isSubmitting) {
        if (window.IS_DEBUG) console.log('⚠️ Submit bereits in Bearbeitung, ignoriere weiteren Versuch');
        return;
      }
      
      // Prüfe nochmal, ob Wunschbox aktiv ist
      if (!isWishboxActive) {
        showError(t('error_wishbox_inactive', 'The wishbox is currently not active. Please try again later.'));
        return;
      }

      hideError();

      // ✅ Sanitize alle Eingaben VOR der Validierung
      let name = sanitizeInput(nameInput.value.trim());
      let title = sanitizeInput(titleInput.value.trim()).trim();
      let artist = sanitizeInput(artistInput.value.trim()).trim();
      let greeting = sanitizeInput(greetingInput.value.trim()).trim();

      // Zusätzliche Härtung vor dem Speichern in Firestore
      title = sanitizeString(title);
      artist = sanitizeString(artist);
      
      // ✅ Längen-Limits anwenden
      if (title.length > 120) {
        title = title.substring(0, 120);
      }
      if (artist.length > 120) {
        artist = artist.substring(0, 120);
      }
      if (greeting.length > 200) {
        greeting = greeting.substring(0, 200);
      }
      if (name.length > 120) {
        name = name.substring(0, 120);
      }

      if (!name) {
        name = '';
      }
      if (!title || !artist) {
        showError(t('error_wish_title_artist_required', 'Please enter both a title and an artist.'));
        return;
      }
      if (greeting.length > 200) {
        showError(t('error_greeting_max_200', 'The greeting may be at most 200 characters long.'));
        return;
      }
      if (!checkLocalWishCooldown()) {
        showError(t('wish_cooldown_30', 'Please wait 30 seconds between your requests.'));
        return;
      }

      isSubmitting = true;
      submitBtn.disabled = true;
      submitBtn.innerHTML = '<span>⏳</span><span>' + (t('button_sending', 'Sending...')) + '</span>';

      try {
        const partyCodeInput = document.getElementById('partyCodeInput');
        const partyCtx = await resolvePartySubmitContext();
        let currentPartyId = partyCtx.party_id;
        const currentPartyCode = partyCtx.party_code;
        const currentPartyDjId = partyCtx.dj_id || '';
        const blacklistDecision = (typeof window.vbSongBlacklistDecision === 'function')
          ? await window.vbSongBlacklistDecision(currentPartyDjId, title, artist, currentPartyId)
          : { enabled: false, hit: false, guestBlock: false };
        if (blacklistDecision.guestBlock) {
          clearWishFormFields();
          showBlacklistBlockedError();
          resetSubmitButtonAfterError();
          return;
        }
        const blacklistHit = !!blacklistDecision.hit;
        if (partyCodeInput && currentPartyCode && currentPartyCode !== 'manual') {
          partyCodeInput.value = currentPartyCode;
        }
        if (currentPartyId && !validatePartyId(currentPartyId)) {
          console.error('❌ Ungültige Party-ID erkannt, verwende "manual"');
          currentPartyId = 'manual';
        }

        if (isPreWishMode && currentPartyId && currentPartyId !== 'manual' && typeof window.vbIsPreWishWindowOpen === 'function') {
          try {
            const partyRef = window.firebaseDoc(
              window.firebaseCollection(window.firebaseDb, 'parties'),
              currentPartyId,
            );
            const partySnap = await window.firebaseGetDoc(partyRef);
            const partyLive = partySnap.exists() ? partySnap.data() : null;
            if (!partyLive || !(typeof window.vbIsPreWishSubmissionOpen === 'function'
                ? window.vbIsPreWishSubmissionOpen(partyLive)
                : window.vbIsPreWishWindowOpen(partyLive))) {
              if (partyLive && window.vbArePreWishesPaused && window.vbArePreWishesPaused(partyLive)) {
                showError(t('pre_wishes_paused_guest_message', 'Enough advance requests have already been received – no further requests can be submitted for now.'));
              } else {
              showError(t('pre_wish_submit_blocked_deadline', 'Advance requests are only available until 6 hours before the party starts.'));
              }
              isSubmitting = false;
              submitBtn.disabled = false;
              submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
              isPreWishMode = false;
              isWishboxActive = false;
              if (partyLive && typeof window.partyStartDateFromData === 'function') {
                const sd = window.partyStartDateFromData(partyLive);
                if (sd) showPrePartyWaitMode(partyLive.party_name || 'Party', sd);
              }
              return;
            }
          } catch (preWishGateErr) {
            if (window.IS_DEBUG) console.warn('Vorab-Wunsch Fenster-Check:', preWishGateErr);
          }
        }

        if (isPreWishMode) {
          var preLimit = checkPreWishLimitFast(
            typeof partyCtx.pre_wish_limit_per_guest === 'number'
              ? partyCtx.pre_wish_limit_per_guest
              : 0,
          );
          if (!preLimit.allowed) {
            var preMsg = t(
              'pre_wish_limit_reached',
              'You have reached the limit of {limit} advance wishes.',
            ).replace(/\{limit\}/g, String(preLimit.limit || 0));
            showError(preMsg);
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<span>🚫</span><span>' + (t('wish_limit_reached', 'Limit reached')) + '</span>';
            resetSubmitButtonAfterError();
            return;
          }
        } else {
          const limitAllowed = checkWishLimitFast(partyCtx.guest_limit);
          if (!limitAllowed.allowed) {
            const limitMsg = limitAllowed.messageKey
              ? t(limitAllowed.messageKey, typeof limitAllowed.message === 'string' ? limitAllowed.message : '').replace(
                  /\{limit\}/g,
                  String(limitAllowed.limit ?? 2),
                )
              : limitAllowed.message;
            showError(limitMsg);
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<span>🚫</span><span>' + (t('wish_limit_reached', 'Limit reached')) + '</span>';
            resetSubmitButtonAfterError();
            return;
          }
        }
        
        // Prüfe ob Song bereits gespielt wurde (History/Wishes mit Status: played)
        // Normalisiere Titel und Artist für Duplikat-Prüfung
        const normalizedTitle = title.toLowerCase().trim();
        const normalizedArtist = artist.toLowerCase().trim();
        const spotifyId = selectedSpotifyTrack && selectedSpotifyTrack.id ? selectedSpotifyTrack.id : null;
        const pwaWishBrowserLanguage = (navigator.language && navigator.language.split('-')[0].toLowerCase()) || 'unknown';
        const pwaWishClientPlatform = 'web';
        
        if (!currentClientId) {
          currentClientId = await getOrCreateClientId(currentPartyId || 'manual', {
            deferWrites: true,
          });
        } else if (currentPartyId && currentPartyId !== 'manual') {
          void getOrCreateClientId(currentPartyId, { deferWrites: true });
        }
        if (window.IS_DEBUG) console.log('🔑 submitWish: Verwende currentClientId (Fingerprint):', currentClientId);

        let wasPlayed = false;
        let similarWish = null;
        if (currentPartyId && currentPartyId !== 'manual') {
          const checkResults = await Promise.all([
            checkIfSongWasPlayed(title, artist, currentPartyId),
            findSimilarWish(normalizedTitle, normalizedArtist, spotifyId, currentPartyId),
          ]);
          wasPlayed = checkResults[0];
          similarWish = checkResults[1];
        }

        if (wasPlayed) {
          const shouldContinue = await showHistoryDuplicateModal(title, artist);
          if (!shouldContinue) {
            resetSubmitButtonAfterError();
            return;
          }
        }

        if (window.IS_DEBUG) console.log('=== DUPLIKAT-PRÜFUNG STARTET ===');
        
        if (similarWish && !blacklistHit) {
          if (window.IS_DEBUG) console.log('✓✓✓ DUPLIKAT GEFUNDEN! ✓✓✓');
          if (window.IS_DEBUG) console.log('Original-ID: ' + similarWish.id);
          
          // ✅ Modal-Dialog: Song steht bereits auf Wunschliste (mit Titel und Artist)
          const shouldContinue = await showPendingWishDuplicateModal(title, artist);
          
          if (!shouldContinue) {
            resetSubmitButtonAfterError();
            return;
          }
          
          // Echtes Original-Dokument: Wenn Treffer ein Duplikat ist, dessen original_wish_id verwenden
          const actualOriginalId = (similarWish.data.is_duplicate === true && similarWish.data.original_wish_id)
            ? similarWish.data.original_wish_id
            : similarWish.id;
          let originalData = similarWish.data;
          if (actualOriginalId !== similarWish.id) {
            const realOriginalRef = window.vbPartyWishDoc(currentPartyId, actualOriginalId);
            const realOriginalSnap = await window.firebaseGetDoc(realOriginalRef);
            if (realOriginalSnap.exists()) {
              originalData = realOriginalSnap.data();
            }
          }
          
          const originalWishRef = window.vbPartyWishDoc(currentPartyId, actualOriginalId);
          const currentCount = (originalData.duplicate_count || 0);
          const prevRequestedBy = Array.isArray(originalData.requested_by) ? [...originalData.requested_by] : [];
          const prevCreatedAtList = Array.isArray(originalData.createdAt_list) ? [...originalData.createdAt_list] : [];
          const requestedBy = [...prevRequestedBy];
          // ✅ Sanitize Name vor dem Hinzufügen
          const sanitizedName = sanitizeInput(name);
          const originalOwnerName = sanitizeInput(originalData.name || '');
          if (originalOwnerName && !requestedBy.includes(originalOwnerName)) {
            requestedBy.unshift(originalOwnerName);
          }
          if (sanitizedName && !requestedBy.includes(sanitizedName)) {
            requestedBy.push(sanitizedName);
          }

          const baseCreated = originalData.createdAt || null;
          const createdAtList = [];
          for (const person of requestedBy) {
            const idx = prevRequestedBy.indexOf(person);
            if (idx >= 0 && idx < prevCreatedAtList.length && prevCreatedAtList[idx]) {
              createdAtList.push(prevCreatedAtList[idx]);
            } else if (person === originalOwnerName && baseCreated) {
              createdAtList.push(baseCreated);
            } else if (person === sanitizedName) {
              createdAtList.push(window.firebaseTimestamp.now());
            } else if (baseCreated) {
              createdAtList.push(baseCreated);
            } else {
              createdAtList.push(window.firebaseTimestamp.now());
            }
          }
          
          const greetings = Array.isArray(originalData.greetings) ? [...originalData.greetings] : [];
          if (greeting && greeting.trim() && sanitizedName) {
            // ✅ Sanitize Name und Greeting vor dem Hinzufügen
            greetings.push({ name: sanitizedName, greeting: sanitizeInput(greeting) });
          }
          
          const existingIsRegisteredUsers = originalData.is_registered_users || {};
          if (sanitizedName && !existingIsRegisteredUsers[sanitizedName]) {
            existingIsRegisteredUsers[sanitizedName] = false; // PWA = immer Gast
          }
          
          const updateData = {
            duplicate_count: currentCount + 1,
            requested_by: requestedBy,
            createdAt_list: createdAtList,
            greetings: greetings,
            is_registered_users: existingIsRegisteredUsers,
            duplicate_updated_at: window.firebaseServerTimestamp(),
          };
          if (originalData.is_pre_wish === true && originalData.pre_wish_published !== true) {
            updateData.pre_wish_published = true;
          }
          
          try {
            await window.firebaseUpdateDoc(originalWishRef, updateData);
            if (window.IS_DEBUG) console.log('✓✓✓ Ursprünglicher Wunsch erfolgreich aktualisiert! ✓✓✓');
          } catch (error) {
            console.error('Fehler beim Aktualisieren des ursprünglichen Wunsches:', error);
            // Falls Update fehlschlägt, erstelle trotzdem einen neuen Wunsch
          }
          
          // Erstelle trotzdem einen eigenen Wunsch-Eintrag (für User-Sichtbarkeit)
          // ✅ PFlicht-Felder: Stelle sicher, dass client_id und party_id Strings sind
          const wishData = {
            name: name,
            title: title || '',
            artist: artist || '',
            status: 'pending',
            createdAt: window.firebaseServerTimestamp(),
            is_pre_wish: isPreWishMode === true,
            is_duplicate: true,
            original_wish_id: actualOriginalId,
            is_registered_user: false,
            client_id: String(currentClientId || ''), // ✅ EXPLIZIT String, nicht null/undefined
            device_id: String(currentClientId || ''), // ✅ Hardware/Fingerprint-Anker
            party_id: String(currentPartyId || ''), // ✅ EXPLIZIT String, nicht null/undefined
            party_code: currentPartyCode || '',
            dj_id: String(currentPartyDjId || ''),
            djId: String(currentPartyDjId || ''),
            timestamp: window.firebaseServerTimestamp(), // ✅ Pflichtfeld für serverseitige Rule-Prüfung
            isSeen: false, // ✅ FIX: Neuer Wunsch ist ungelesen
            browser_language: pwaWishBrowserLanguage,
            client_platform: pwaWishClientPlatform
          };
          if (blacklistHit && blacklistDecision.enabled) window.vbStampSongBlacklistReject(wishData);
          
          // ✅ DEBUGGING: Logge das komplette wishData Objekt
          if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: client_id Typ:', typeof wishData.client_id, 'Wert:', wishData.client_id);
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: party_id Typ:', typeof wishData.party_id, 'Wert:', wishData.party_id);
          
          // ✅ Spotify-Daten: Nur spotify_id erlaubt (keine zusätzlichen Metadaten)
          if (spotifyId) {
            wishData.spotify_id = spotifyId;
          }
          
          if (greeting) {
            wishData.greeting = greeting;
          }
          
          // ✅ DEBUGGING: Logge das komplette wishData Objekt VOR addDoc
          if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: client_id vorhanden?', 'client_id' in wishData, 'Wert:', wishData.client_id);
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: party_id vorhanden?', 'party_id' in wishData, 'Wert:', wishData.party_id);
          
          try {
          await window.firebaseAddDoc(
            window.vbPartyWishesCollection(currentPartyId),
            wishData
          );
            if (window.IS_DEBUG) console.log('✅ Wunsch erfolgreich in Firestore gespeichert (Duplikat)');
          } catch (error) {
            console.error('❌ FEHLER beim Speichern des Wunsches (Duplikat)');
            if (window.IS_DEBUG) console.error('❌ FEHLER-Details:', { code: error.code, message: error.message });
            showError(t('error_saving_wish', 'Error saving wish. Please try again.'));
            isSubmitting = false;
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
            return;
          }
        } else {
          if (window.IS_DEBUG) console.log('✗✗✗ KEIN DUPLIKAT GEFUNDEN - NEUER WUNSCH WIRD ERSTELLT ✗✗✗');
          
          // Kein Duplikat - erstelle neuen Wunsch
          // ✅ BEREINIGT: Nur erlaubte Felder (keine duplicate_count, requested_by, greetings, is_registered_users)
          const wishData = {
            title: title || '',
            artist: artist || '',
            status: 'pending',
            createdAt: window.firebaseServerTimestamp(),
            is_pre_wish: isPreWishMode === true,
            is_duplicate: false,
            is_registered_user: false,
            client_id: String(currentClientId || ''), // ✅ EXPLIZIT String, nicht null/undefined
            device_id: String(currentClientId || ''), // ✅ Hardware/Fingerprint-Anker
            party_id: String(currentPartyId || ''), // ✅ EXPLIZIT String, nicht null/undefined
            party_code: currentPartyCode || '',
            dj_id: String(currentPartyDjId || ''),
            djId: String(currentPartyDjId || ''),
            timestamp: window.firebaseServerTimestamp(), // ✅ Pflichtfeld für serverseitige Rule-Prüfung
            isSeen: false, // ✅ FIX: Neuer Wunsch ist ungelesen
            browser_language: pwaWishBrowserLanguage,
            client_platform: pwaWishClientPlatform
          };
          if (blacklistHit && blacklistDecision.enabled) window.vbStampSongBlacklistReject(wishData);
          if (name) {
            wishData.name = name;
            wishData.requested_by = [name];
          }
          
          // ✅ Spotify-Daten: Nur spotify_id erlaubt (keine zusätzlichen Metadaten)
          if (selectedSpotifyTrack && selectedSpotifyTrack.id) {
            if (window.IS_DEBUG) console.log('🎵 Spotify Track ausgewählt:', selectedSpotifyTrack);
            wishData.spotify_id = selectedSpotifyTrack.id;
          }
          
          if (greeting) {
            wishData.greeting = greeting;
          }
          
          // ✅ DEBUGGING: Logge das komplette wishData Objekt VOR addDoc
          if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: client_id vorhanden?', 'client_id' in wishData, 'Typ:', typeof wishData.client_id, 'Wert:', wishData.client_id);
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: party_id vorhanden?', 'party_id' in wishData, 'Typ:', typeof wishData.party_id, 'Wert:', wishData.party_id);
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: name vorhanden?', 'name' in wishData, 'Typ:', typeof wishData.name, 'Wert:', wishData.name);
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: title vorhanden?', 'title' in wishData, 'Typ:', typeof wishData.title, 'Wert:', wishData.title);
          if (window.IS_DEBUG) console.log('📋 DEBUGGING: artist vorhanden?', 'artist' in wishData, 'Typ:', typeof wishData.artist, 'Wert:', wishData.artist);
          
          try {
          await window.firebaseAddDoc(
            window.vbPartyWishesCollection(currentPartyId),
            wishData
          );
            if (window.IS_DEBUG) console.log('✅ Wunsch erfolgreich in Firestore gespeichert (Neuer Wunsch)');
          } catch (error) {
            console.error('❌ FEHLER beim Speichern des Wunsches');
            if (window.IS_DEBUG) console.error('❌ FEHLER-Details:', { code: error.code, message: error.message });
            showError(t('error_saving_wish', 'Error saving wish. Please try again.'));
            isSubmitting = false;
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
            return;
          }
        }
        
        // ✅ Erfolgsmeldung anzeigen (sofort, damit User nicht warten muss)
        form.style.display = 'none';
        syncPreWishDisclaimerUi();
        successMessage.classList.add('show');
        var brandingLineOnSuccess = document.getElementById('brandingLine');
        if (brandingLineOnSuccess) {
          brandingLineOnSuccess.style.display = 'none';
          brandingLineOnSuccess.style.visibility = 'hidden';
        }
        var formContainer = document.querySelector('.form-container');
        if (formContainer) formContainer.classList.add('success-open');
        
        // ✅ Erfolgs-Sperre aktivieren: Verhindert, dass Hintergrund-Checks das UI überschreiben
        window.isSuccessActive = true;
        if (window.IS_DEBUG) console.log('✅ Erfolgs-Sperre aktiviert: window.isSuccessActive = true');
        
        // ✅ Konfetti-Icon aktivieren (Animation starten)
        const successCheckmark = document.getElementById('successCheckmark');
        if (successCheckmark) {
          // Reset Animation für erneutes Abspielen
          successCheckmark.style.animation = 'none';
          setTimeout(() => {
            successCheckmark.style.animation = '';
          }, 10);
        }
        
        // ✅ Zeige Lade-Status und verstecke Button-Bereich
        const successActionArea = document.getElementById('successActionArea');
        const successLoading = document.getElementById('successLoading');
        const successButtonContainer = document.getElementById('successButtonContainer');
        const successLimitReached = document.getElementById('successLimitReached');
        
        if (successActionArea) {
          successActionArea.style.display = 'block';
        }
        if (successLoading) {
          successLoading.style.display = 'flex';
        }
        if (successButtonContainer) {
          successButtonContainer.style.display = 'none';
        }
        if (successLimitReached) {
          successLimitReached.style.display = 'none';
        }
        
        if (!isPreWishMode) {
          markLocalWishCooldown();
          if (typeof window.__vbStreamWishCount === 'number') {
            window.__vbStreamWishCount += 1;
          }
          if (window.currentWishStats) {
            window.currentWishStats.current = (window.currentWishStats.current || 0) + 1;
            window.currentWishStats.remaining = Math.max(
              0,
              (window.currentWishStats.limit || 2) - window.currentWishStats.current,
            );
          }
        }

        if (successLoading) {
          successLoading.style.display = 'none';
        }

        if (isPreWishMode) {
          if (successButtonContainer) {
            successButtonContainer.style.display = 'block';
          }
          if (successLimitReached) {
            successLimitReached.style.display = 'none';
          }
        } else {
          const limitInfo = checkWishLimitFast();
          if (limitInfo.allowed) {
            if (successButtonContainer) {
              successButtonContainer.style.display = 'block';
            }
            if (successLimitReached) {
              successLimitReached.style.display = 'none';
            }
          } else {
            if (successButtonContainer) {
              successButtonContainer.style.display = 'none';
            }
            if (successLimitReached) {
              successLimitReached.style.display = 'block';
            }
          }
        }
        
        // ✅ Navigation: Button-Handler für "Weiteren Wunsch senden"
        const sendAnotherBtn = document.getElementById('sendAnotherBtn');
        if (sendAnotherBtn) {
          // Entferne alte Event-Listener (falls vorhanden)
          const newBtn = sendAnotherBtn.cloneNode(true);
          sendAnotherBtn.parentNode.replaceChild(newBtn, sendAnotherBtn);
          
          // Füge neuen Event-Listener hinzu
          newBtn.addEventListener('click', () => {
            // ✅ Erfolgs-Sperre deaktivieren: Erlaube wieder UI-Updates
            window.isSuccessActive = false;
            if (window.IS_DEBUG) console.log('✅ Erfolgs-Sperre deaktiviert: window.isSuccessActive = false');
            
            var formContainer = document.querySelector('.form-container');
            if (formContainer) formContainer.classList.remove('success-open');
            
            // Formular zurücksetzen
            wishForm.reset();
            
            // Erfolgsmeldung verstecken
            successMessage.classList.remove('show');

            // Nicht blind Formular zeigen — Sperre/Pause/Inaktiv hat Vorrang (Realtime)
            if (typeof updateWishboxUI === 'function') {
              updateWishboxUI();
            } else {
              form.style.display = 'block';
            }
            
            // Scroll nach oben
            window.scrollTo({ top: 0, behavior: 'smooth' });
          });
        }
        
        // Wenn Track von Spotify ausgewählt wurde, Musikdatenbank aktualisieren (Fire & Forget)
        // Läuft asynchron im Hintergrund, blockiert nicht die Erfolgsmeldung
        if (selectedSpotifyTrack && selectedSpotifyTrack.id) {
          const djId = currentPartyDjId || null;
          saveToMusicDatabase(selectedSpotifyTrack, title, artist, djId, currentPartyId).catch((error) => {
            console.error('Fehler beim Speichern in Musikdatenbank:', error);
            // Fehler wird nicht dem User angezeigt, da Wunsch bereits gespeichert ist
          });
          // Track-Referenz zurücksetzen
          selectedSpotifyTrack = null;
        }

        currentSelectedArtist = null;

        // Formular zurücksetzen
        form.reset();
        selectedSpotifyTrack = null; // Track-Referenz zurücksetzen
        titleSuggestions.classList.remove('show');
        artistSuggestions.classList.remove('show');
        
        if (!isPreWishMode && currentPartyId !== 'manual') {
          void updateGuestStats(currentPartyId);
          void updatePendingWishesCache(currentPartyId);
        }
        
        // ✅ KEIN automatischer Redirect - User bleibt auf Bestätigungsseite
        // Navigation erfolgt nur über Button "Weiteren Wunsch senden"
          isSubmitting = false; // Flag zurücksetzen, damit neuer Wunsch abgeschickt werden kann
          submitBtn.disabled = false;
          submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
        
      } catch (error) {
        console.error('Fehler beim Absenden:', error);
        showError(t('error_submitting', 'Error submitting. Please try again.'));
        isSubmitting = false; // Flag zurücksetzen bei Fehler
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
      }
    }

    bindWishFormSubmit();

    // Fehlermeldung anzeigen
    // ✅ Modal für History-Duplikat (Song bereits gespielt)
    function showHistoryDuplicateModal(songTitle, songArtist) {
      return new Promise((resolve) => {
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay';
        overlay.id = 'historyDuplicateModal';
        
        const modal = document.createElement('div');
        modal.className = 'modal-content';
        
        const title = t('modal_history_title', 'Song already played');
        let message = t('modal_history_message', 'This song was already played today. Do you still want to request it?');
        // ✅ XSS-Schutz: Dekodieren für Anzeige, dann escapeHtml vor Einbau in HTML
        const decodedTitle = unescapeHtml(songTitle || 'this song');
        const decodedArtist = unescapeHtml(songArtist || 'this artist');
        const safeTitle = typeof escapeHtml === 'function' ? escapeHtml(decodedTitle) : decodedTitle.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        const safeArtist = typeof escapeHtml === 'function' ? escapeHtml(decodedArtist) : decodedArtist.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        message = message.replace(/{title}/g, safeTitle);
        message = message.replace(/{artist}/g, safeArtist);
        
        const sendButton = t('modal_button_send_anyway', 'Send anyway');
        const cancelButton = t('modal_button_cancel', 'Cancel');
        
        modal.innerHTML = `
          <div class="modal-icon">
            <i class="fas fa-music"></i>
          </div>
          <h2 class="modal-title">${title}</h2>
          <p class="modal-message">${message}</p>
          <div class="modal-buttons">
            <button class="modal-button modal-button-success" id="modalHistoryContinueBtn">
              ${sendButton}
            </button>
            <button class="modal-button modal-button-secondary" id="modalHistoryCancelBtn">
              ${cancelButton}
            </button>
          </div>
        `;
        
        overlay.appendChild(modal);
        document.body.appendChild(overlay);
        
        const continueBtn = document.getElementById('modalHistoryContinueBtn');
        const cancelBtn = document.getElementById('modalHistoryCancelBtn');
        
        continueBtn.addEventListener('click', () => {
          overlay.remove();
          resolve(true);
        });
        
        cancelBtn.addEventListener('click', () => {
          overlay.remove();
          resolve(false);
        });
        
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            overlay.remove();
            resolve(false);
          }
        });
        
        const handleEsc = (e) => {
          if (e.key === 'Escape') {
            overlay.remove();
            document.removeEventListener('keydown', handleEsc);
            resolve(false);
          }
        };
        document.addEventListener('keydown', handleEsc);
      });
    }

    // ✅ Modal für Pending-Wish-Duplikat (Song bereits auf Wunschliste)
    function showPendingWishDuplicateModal(songTitle, songArtist) {
      return new Promise((resolve) => {
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay';
        overlay.id = 'pendingWishDuplicateModal';
        
        const modal = document.createElement('div');
        modal.className = 'modal-content';
        
        const title = t('modal_pending_title', 'Song already on wish list');
        let message = t('modal_pending_message', 'This song is already on the wish list. Do you still want to submit your request?');
        // ✅ XSS-Schutz: Dekodieren für Anzeige, dann escapeHtml vor Einbau in HTML
        const decodedTitle = unescapeHtml(songTitle || 'this song');
        const decodedArtist = unescapeHtml(songArtist || 'this artist');
        const safeTitle = typeof escapeHtml === 'function' ? escapeHtml(decodedTitle) : decodedTitle.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        const safeArtist = typeof escapeHtml === 'function' ? escapeHtml(decodedArtist) : decodedArtist.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        message = message.replace(/{title}/g, safeTitle);
        message = message.replace(/{artist}/g, safeArtist);
        
        const sendButton = t('modal_button_send_anyway', 'Send anyway');
        const cancelButton = t('modal_button_cancel', 'Cancel');
        
        modal.innerHTML = `
          <div class="modal-icon">
            <i class="fas fa-list"></i>
          </div>
          <h2 class="modal-title">${title}</h2>
          <p class="modal-message">${message}</p>
          <div class="modal-buttons">
            <button class="modal-button modal-button-success" id="modalPendingContinueBtn">
              ${sendButton}
            </button>
            <button class="modal-button modal-button-secondary" id="modalPendingCancelBtn">
              ${cancelButton}
            </button>
          </div>
        `;
        
        overlay.appendChild(modal);
        document.body.appendChild(overlay);
        
        const continueBtn = document.getElementById('modalPendingContinueBtn');
        const cancelBtn = document.getElementById('modalPendingCancelBtn');
        
        continueBtn.addEventListener('click', () => {
          overlay.remove();
          resolve(true);
        });
        
        cancelBtn.addEventListener('click', () => {
          overlay.remove();
          resolve(false);
        });
        
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            overlay.remove();
            resolve(false);
          }
        });
        
        const handleEsc = (e) => {
          if (e.key === 'Escape') {
            overlay.remove();
            document.removeEventListener('keydown', handleEsc);
            resolve(false);
          }
        };
        document.addEventListener('keydown', handleEsc);
      });
    }

    var lastErrorI18n = null;

    function showBlacklistBlockedError() {
      lastErrorI18n = { kind: 'blacklist' };
      var blockedTitle = t('song_blacklist_guest_blocked_title', 'Request not possible');
      var blockedBody = t(
        'song_blacklist_guest_blocked',
        'This title cannot be requested at this party. Please choose another song.'
      );
      errorMessage.textContent = blockedTitle ? (blockedTitle + ' — ' + blockedBody) : blockedBody;
      errorMessage.classList.add('show');
    }

    function refreshWishErrorI18n() {
      if (!errorMessage || !errorMessage.classList.contains('show')) return;
      if (!lastErrorI18n || lastErrorI18n.kind !== 'blacklist') return;
      var blockedTitle = t('song_blacklist_guest_blocked_title', 'Request not possible');
      var blockedBody = t(
        'song_blacklist_guest_blocked',
        'This title cannot be requested at this party. Please choose another song.'
      );
      errorMessage.textContent = blockedTitle ? (blockedTitle + ' — ' + blockedBody) : blockedBody;
    }
    window.vbRefreshWishErrorI18n = refreshWishErrorI18n;

    function hideBlacklistErrorIfShowing() {
      if (!lastErrorI18n || lastErrorI18n.kind !== 'blacklist') return;
      hideError();
    }

    function clearWishFormFields() {
      selectedSpotifyTrack = null;
      currentSelectedArtist = null;
      if (form) form.reset();
      if (titleInput) titleInput.value = '';
      if (artistInput) artistInput.value = '';
      if (greetingInput) greetingInput.value = '';
      if (nameInput) nameInput.value = '';
      if (titleSuggestions) {
        titleSuggestions.classList.remove('show');
        titleSuggestions.innerHTML = '';
      }
      if (artistSuggestions) {
        artistSuggestions.classList.remove('show');
        artistSuggestions.innerHTML = '';
      }
      if (charCount) charCount.textContent = '0 / 200';
      if (nameCharCount) nameCharCount.textContent = '0 / 120';
      if (titleCharCount) titleCharCount.textContent = '0 / 120';
      if (artistCharCount) artistCharCount.textContent = '0 / 120';
    }

    function showError(message) {
      lastErrorI18n = null;
      errorMessage.textContent = message;
      errorMessage.classList.add('show');
    }

    // Fehlermeldung verstecken
    function hideError() {
      lastErrorI18n = null;
      errorMessage.classList.remove('show');
    }

    // HTML-Escape
    function escapeHtml(text) {
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    }

    // ✅ Zeichenzähler für alle Wunschbox-Felder (mit .trim() für korrekte Zählung)
    // Gruß-Feld
    greetingInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      charCount.textContent = `${length} / 200`;
    });
    charCount.textContent = `${(greetingInput.value || '').trim().length} / 200`;
    
    // Name-Feld
    nameInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      nameCharCount.textContent = `${length} / 120`;
    });
    nameCharCount.textContent = `${(nameInput.value || '').trim().length} / 120`;
    
    // Titel-Feld
    titleInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      titleCharCount.textContent = `${length} / 120`;
    });
    titleCharCount.textContent = `${(titleInput.value || '').trim().length} / 120`;
    
    // Interpret-Feld
    artistInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      artistCharCount.textContent = `${length} / 120`;
    });
    artistCharCount.textContent = `${(artistInput.value || '').trim().length} / 120`;

    // Cookie Banner
    function checkCookieConsent() {
      const cookieConsent = localStorage.getItem('cookieConsent');
      if (!cookieConsent) {
        // Zeige Cookie Banner, wenn noch keine Zustimmung gegeben wurde
        const cookieBanner = document.getElementById('cookieBanner');
        if (cookieBanner) {
          cookieBanner.classList.add('show');
        }
      }
    }

    function acceptCookies() {
      localStorage.setItem('cookieConsent', 'accepted');
      const cookieBanner = document.getElementById('cookieBanner');
      if (cookieBanner) {
        cookieBanner.classList.remove('show');
      }
    }

    function declineCookies() {
      localStorage.setItem('cookieConsent', 'declined');
      const cookieBanner = document.getElementById('cookieBanner');
      if (cookieBanner) {
        cookieBanner.classList.remove('show');
      }
    }

    // Prüfe Cookie-Zustimmung beim Laden der Seite
    checkCookieConsent();

    const VB_WISH_COOLDOWN_MS = 30000;
    let vbPartySubmitCtxCache = null;
    let vbDuplicateSettingsCache = null;
    let vbDuplicateSettingsCacheAt = 0;
    let vbPendingCachePartyId = null;
    let vbHistoryCachePartyId = null;

    function getStoredPartyIdForSubmit() {
      const id = sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId');
      if (id && id !== 'manual' && typeof validatePartyId === 'function' && validatePartyId(id)) {
        return id;
      }
      return null;
    }

    function getStoredPartyCodeForSubmit() {
      const raw = sessionStorage.getItem('validatedPartyCode') || localStorage.getItem('validatedPartyCode');
      if (!raw) return '';
      return String(raw).replace(/\D/g, '').substring(0, 8);
    }

    /** 0 = unbegrenzt, 1–50 = max. Vorab-Wünsche pro Gast (unabhängig von guest_limit_per_hour). */
    function vbPreWishLimitFromParty(data) {
      if (!data || typeof data !== 'object') return 0;
      var v = data.pre_wish_limit_per_guest;
      if (v === null || v === undefined) return 0;
      var n = parseInt(v, 10);
      if (isNaN(n) || n <= 0) return 0;
      return Math.min(50, Math.max(1, n));
    }

    function vbWishCountsAsPreWish(data) {
      return data && data.is_pre_wish === true && data.is_duplicate !== true;
    }

    async function resolvePartySubmitContext() {
      const partyId = getStoredPartyIdForSubmit();
      const partyCode = getStoredPartyCodeForSubmit();
      if (!partyId) {
        return {
          party_id: 'manual',
          party_code: partyCode || 'manual',
          dj_id: (sessionStorage.getItem('validatedPartyDjId') || '').trim(),
          guest_limit: 2,
        };
      }
      if (
        vbPartySubmitCtxCache &&
        vbPartySubmitCtxCache.party_id === partyId &&
        Date.now() - (vbPartySubmitCtxCache.cachedAt || 0) < 300000
      ) {
        return vbPartySubmitCtxCache;
      }
      let djId = (sessionStorage.getItem('validatedPartyDjId') || '').trim();
      let guestLimit = 2;
      try {
        const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId);
        const snap = await window.firebaseGetDoc(partyRef);
        if (snap.exists()) {
          const d = snap.data();
          djId = String(d.created_by || d.djId || d.dj_code || djId || '').trim();
          guestLimit = d.guest_limit_per_hour || 2;
          vbPartySubmitCtxCache = {
            party_id: partyId,
            party_code: partyCode,
            dj_id: djId,
            guest_limit: guestLimit,
            pre_wish_limit_per_guest: vbPreWishLimitFromParty(d),
            cachedAt: Date.now(),
          };
          try {
            sessionStorage.setItem('validatedPartyDjId', djId);
          } catch (eSt) {}
          return vbPartySubmitCtxCache;
        }
      } catch (e) {
        if (window.IS_DEBUG) console.warn('resolvePartySubmitContext:', e);
      }
      vbPartySubmitCtxCache = {
        party_id: partyId,
        party_code: partyCode,
        dj_id: djId,
        guest_limit: guestLimit,
        pre_wish_limit_per_guest: 0,
        cachedAt: Date.now(),
      };
      return vbPartySubmitCtxCache;
    }

    function checkLocalWishCooldown() {
      try {
        const last = parseInt(sessionStorage.getItem('vb_last_wish_sent_ms') || '0', 10);
        if (last > 0 && Date.now() - last < VB_WISH_COOLDOWN_MS) return false;
      } catch (e) {}
      return true;
    }

    function markLocalWishCooldown() {
      try {
        sessionStorage.setItem('vb_last_wish_sent_ms', String(Date.now()));
      } catch (e) {}
    }

    /** Nur normale Gast-Wünsche zählen — keine Vorab-Wünsche, keine Dubletten. */
    function vbWishCountsTowardGuestHourlyLimit(data) {
      if (!data || typeof data !== 'object') return false;
      if (data.is_pre_wish === true) return false;
      if (data.is_duplicate === true) return false;
      return true;
    }

    function checkWishLimitFast(fallbackLimit) {
      const limit =
        window.__vbStreamGuestLimit ??
        window.currentWishStats?.limit ??
        fallbackLimit ??
        vbPartySubmitCtxCache?.guest_limit ??
        2;
      const count = window.__vbStreamWishCount ?? window.currentWishStats?.current ?? 0;
      if (count >= limit) {
        return {
          allowed: false,
          remaining: 0,
          limit: limit,
          messageKey: 'wish_limit_hour_reached',
          message: t(
            'wish_limit_hour_reached',
            'You have already submitted ' + limit + ' wishes this full hour. Please wait until the next full hour.',
          ).replace(/\{limit\}/g, String(limit)),
        };
      }
      return {
        allowed: true,
        remaining: Math.max(0, limit - count),
        limit: limit,
        message: '',
      };
    }

    function checkPreWishLimitFast(partyDataOrLimit) {
      var limit = 0;
      if (partyDataOrLimit && typeof partyDataOrLimit === 'object') {
        limit = vbPreWishLimitFromParty(partyDataOrLimit);
      } else if (typeof partyDataOrLimit === 'number') {
        limit = partyDataOrLimit > 0 ? Math.min(50, partyDataOrLimit) : 0;
      }
      if (limit <= 0) {
        return { allowed: true, remaining: 0, limit: 0 };
      }
      var count = window.__vbStreamPreWishCount ?? window.currentPreWishStats?.current ?? 0;
      if (count >= limit) {
        return {
          allowed: false,
          remaining: 0,
          limit: limit,
          messageKey: 'pre_wish_limit_reached',
        };
      }
      return {
        allowed: true,
        remaining: Math.max(0, limit - count),
        limit: limit,
      };
    }

    function applyPreWishLimitToUI(remaining, limit, allowed) {
      var limitInfoDiv = document.getElementById('wishLimitInfo');
      var limitText = document.getElementById('wishLimitText');
      if (!limitInfoDiv || !limitText) return;
      if (!isPreWishMode || limit <= 0) {
        limitInfoDiv.style.display = 'none';
        return;
      }
      limitInfoDiv.style.display = 'block';
      document.body.classList.add('pre-wish-limit-active');
      var pageWb = document.getElementById('page-wunschbox');
      if (pageWb) pageWb.classList.add('pre-wish-limit-active');
      if (allowed && remaining > 0) {
        limitText.textContent = t(
          'pre_wish_limit_remaining',
          '{remaining} of {limit} advance wishes still possible',
        )
          .replace(/\{remaining\}/g, String(remaining))
          .replace(/\{limit\}/g, String(limit));
      } else {
        limitText.textContent = t(
          'pre_wish_limit_reached',
          'You have reached the limit of {limit} advance wishes.',
        ).replace(/\{limit\}/g, String(limit));
      }
      var submitBtn = document.getElementById('submitBtn');
      if (submitBtn) {
        if (!allowed || remaining <= 0) {
          submitBtn.disabled = true;
          submitBtn.innerHTML = '<span>🚫</span><span>' + (t('wish_limit_reached', 'Limit reached')) + '</span>';
        } else {
          submitBtn.disabled = false;
          submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
        }
      }
    }

    var preWishLimitUnsubscribe = null;

    function subscribePreWishLimitStream(partyId) {
      if (preWishLimitUnsubscribe) {
        preWishLimitUnsubscribe();
        preWishLimitUnsubscribe = null;
      }
      if (wishLimitUnsubscribe) {
        wishLimitUnsubscribe();
        wishLimitUnsubscribe = null;
      }
      if (!partyId || partyId === 'manual') return;
      var limitInfoDiv = document.getElementById('wishLimitInfo');
      var limitText = document.getElementById('wishLimitText');
      if (limitInfoDiv && limitText) {
        limitInfoDiv.style.display = 'block';
        limitText.textContent = t('pre_wish_limit_loading', 'Loading advance wish limit…');
      }
      (async function startPreWishStream() {
        try {
          var cid = await getOrCreateClientId(partyId);
          var partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId);
          var wishesRef = window.vbPartyWishesCollection(partyId);
          var q = window.firebaseQuery(wishesRef, window.firebaseWhere('client_id', '==', cid));
          var preLimit = 0;
          var preCount = 0;
          function flushPre() {
            if (!isPreWishMode) return;
            window.__vbStreamPreWishLimit = preLimit;
            window.__vbStreamPreWishCount = preCount;
            if (!window.currentPreWishStats) window.currentPreWishStats = {};
            window.currentPreWishStats.limit = preLimit;
            window.currentPreWishStats.current = preCount;
            window.currentPreWishStats.remaining = preLimit > 0 ? Math.max(0, preLimit - preCount) : 0;
            if (preLimit <= 0) {
              var limitInfoDiv2 = document.getElementById('wishLimitInfo');
              if (limitInfoDiv2) limitInfoDiv2.style.display = 'none';
              return;
            }
            applyPreWishLimitToUI(
              Math.max(0, preLimit - preCount),
              preLimit,
              preCount < preLimit,
            );
          }
          var unsubPartyPre = window.firebaseOnSnapshot(partyRef, function (snap) {
            if (!isPreWishMode) return;
            if (snap.exists()) {
              preLimit = vbPreWishLimitFromParty(snap.data());
            }
            flushPre();
          });
          var unsubWishesPre = window.firebaseOnSnapshot(q, function (snapshot) {
            if (!isPreWishMode) return;
            preCount = 0;
            snapshot.forEach(function (doc) {
              if (vbWishCountsAsPreWish(doc.data())) preCount++;
            });
            flushPre();
          });
          preWishLimitUnsubscribe = function () {
            if (typeof unsubPartyPre === 'function') unsubPartyPre();
            if (typeof unsubWishesPre === 'function') unsubWishesPre();
            document.body.classList.remove('pre-wish-limit-active');
            var pageWb = document.getElementById('page-wunschbox');
            if (pageWb) pageWb.classList.remove('pre-wish-limit-active');
          };
        } catch (e) {
          if (window.IS_DEBUG) console.warn('subscribePreWishLimitStream:', e);
        }
      })();
    }

    function stopPreWishLimitStream() {
      if (preWishLimitUnsubscribe) {
        preWishLimitUnsubscribe();
        preWishLimitUnsubscribe = null;
      }
    }

    async function getDuplicateSettingsCached() {
      if (vbDuplicateSettingsCache && Date.now() - vbDuplicateSettingsCacheAt < 300000) {
        return vbDuplicateSettingsCache;
      }
      let threshold = 0.95;
      let ignoredKeywords = IGNORED_KEYWORDS_DEFAULT.slice();
      try {
        const settingsRef = window.firebaseDoc(
          window.firebaseCollection(window.firebaseDb, 'party_settings'),
          'current',
        );
        const settingsDoc = await window.firebaseGetDoc(settingsRef);
        if (settingsDoc.exists()) {
          const settingsData = settingsDoc.data();
          if (settingsData.duplicate_threshold != null) {
            threshold = settingsData.duplicate_threshold;
          }
          if (
            settingsData.ignored_keywords != null &&
            Array.isArray(settingsData.ignored_keywords) &&
            settingsData.ignored_keywords.length > 0
          ) {
            ignoredKeywords = settingsData.ignored_keywords
              .filter(function (k) {
                return k != null && String(k).trim();
              })
              .map(function (k) {
                return String(k).trim();
              });
          }
        }
      } catch (e) {
        if (window.IS_DEBUG) console.warn('getDuplicateSettingsCached:', e);
      }
      vbDuplicateSettingsCache = { threshold: threshold, ignoredKeywords: ignoredKeywords };
      vbDuplicateSettingsCacheAt = Date.now();
      return vbDuplicateSettingsCache;
    }

    function warmSubmitCaches(partyId) {
      if (!partyId || partyId === 'manual') return;
      void updatePendingWishesCache(partyId);
      void updateHistoryCache(partyId);
      void getDuplicateSettingsCached();
    }

    function resetSubmitButtonAfterError() {
      isSubmitting = false;
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.innerHTML =
          '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
      }
    }

    // ✅ Prüft Wunsch-Limit für aktuelle Party (direkt aus wishes Collection)
    async function checkWishLimit(partyId) {
      try {
        // Prüfe ob User eingeloggt ist (in PWA sind alle Gäste)
        const isGuest = true; // PWA hat keine Authentifizierung
        
        // Lade Limits aus der Party (mit Fallback auf Defaults)
        let guestLimit = 2; // Standard: 2 Wünsche pro Stunde für Gäste
        
        if (partyId !== 'manual' && partyId) {
          try {
            const partyDoc = await window.firebaseGetDoc(
              window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId)
            );
            
            if (partyDoc.exists()) {
              const data = partyDoc.data();
              guestLimit = data.guest_limit_per_hour || 2;
            }
          } catch (e) {
            console.error('⚠️ Fehler beim Laden der Limits aus Party:', e);
          }
        }
        
        // Berechne die aktuelle volle Stunde (UTC)
        const now = new Date();
        const currentFullHour = new Date(Date.UTC(
          now.getUTCFullYear(),
          now.getUTCMonth(),
          now.getUTCDate(),
          now.getUTCHours()
        ));
        
        // Für Gäste: Verwende currentClientId (falls nicht initialisiert, hole es)
        if (!currentClientId) {
          currentClientId = await getOrCreateClientId(partyId);
        }
        
        // ✅ Zähle Wünsche direkt aus wishes Collection
        // Query: client_id == currentClientId AND party_id == partyId AND createdAt >= currentFullHour
        try {
          const wishesRef = window.vbPartyWishesCollection(partyId);
          const wishesQuery = window.firebaseQuery(
            wishesRef,
            window.firebaseWhere('client_id', '==', currentClientId),
            window.firebaseWhere('createdAt', '>=', window.firebaseTimestamp.fromDate(currentFullHour))
          );
          
          const wishesSnapshot = await window.firebaseGetDocs(wishesQuery);
          let recentWishesCount = 0;
          wishesSnapshot.forEach(function (doc) {
            if (vbWishCountsTowardGuestHourlyLimit(doc.data())) recentWishesCount++;
          });
          
          if (window.IS_DEBUG) console.log(`📊 Gast-Wünsche in dieser vollen Stunde (ohne Vorab): ${recentWishesCount} / ${guestLimit}`);
          
          if (recentWishesCount >= guestLimit) {
          return {
            allowed: false,
              remaining: 0,
              limit: guestLimit,
              messageKey: 'wish_limit_hour_reached',
              message: t('wish_limit_hour_reached', 'You have already submitted ' + guestLimit + ' wishes this full hour. Please wait until the next full hour.').replace(/\{limit\}/g, String(guestLimit))
            };
          }
          
          return {
            allowed: true,
            remaining: guestLimit - recentWishesCount,
            limit: guestLimit,
            message: ''
          };
        } catch (queryError) {
          // ✅ Index-Fehler abfangen (falls Index noch lädt)
          if (queryError.code === 'failed-precondition' || 
              queryError.message?.includes('index') || 
              queryError.message?.includes('Index')) {
            if (window.IS_DEBUG) console.warn('⚠️ Firestore-Index wird noch erstellt. Erlaube Wunsch vorübergehend.');
            // Bei Index-Fehler erlauben (Index wird automatisch erstellt)
            return { allowed: true, remaining: guestLimit, limit: guestLimit, message: '' };
          }
          // Andere Fehler weiterwerfen
          throw queryError;
        }
      } catch (e) {
        console.error('❌ Fehler beim Prüfen des Wunsch-Limits:', e);
        // Bei Fehler erlauben (besser als zu restriktiv zu sein)
        return { allowed: true, remaining: 2, limit: 2, message: '' };
      }
    }
    
  function vbHashFingerprintString(fingerprintString) {
    let hash = 0;
    for (let i = 0; i < fingerprintString.length; i++) {
      const char = fingerprintString.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  }

    /** Schneller Fingerprint (ohne Canvas/WebGL) — deutlich schneller auf Safari/iOS. */
    function createHardwareFingerprint() {
      const components = [];
      if (navigator.userAgent) components.push(navigator.userAgent);
      if (navigator.language) components.push(navigator.language);
      if (navigator.languages && navigator.languages.length > 0) {
        components.push(navigator.languages.join(','));
      }
      if (navigator.platform) components.push(navigator.platform);
      if (navigator.hardwareConcurrency) {
        components.push(navigator.hardwareConcurrency.toString());
      }
      if (navigator.deviceMemory) components.push(navigator.deviceMemory.toString());
      if (screen.width) components.push(screen.width.toString());
      if (screen.height) components.push(screen.height.toString());
      if (screen.colorDepth) components.push(screen.colorDepth.toString());
      try {
        components.push(Intl.DateTimeFormat().resolvedOptions().timeZone);
      } catch (e) {}
      return vbHashFingerprintString(components.join('|'));
    }
    
    // Erstellt clientId basierend auf Hardware-Fingerprint (immer stabil, auch nach Cache-Löschung)
    // Format: fp_xxxxxx (z.B. fp_awxad2)
    // partyId: Optional - wird als last_party_id in guest_fingerprints gespeichert
    async function getOrCreateClientId(partyId = null, options = {}) {
      const deferWrites = options && options.deferWrites === true;
      let clientId = null;
      try {
        const cached = localStorage.getItem('guest_client_id');
        if (cached && String(cached).trim().startsWith('fp_')) {
          clientId = String(cached).trim();
        }
      } catch (eCache) {}

      if (!clientId) {
        let fingerprint;
        try {
          fingerprint = createHardwareFingerprint();
        } catch (e) {
          console.error('❌ KRITISCHER FEHLER: Hardware-Fingerprint konnte nicht berechnet werden:', e);
          throw new Error('Hardware fingerprint could not be calculated. Please update your browser.');
        }
        clientId = 'fp_' + fingerprint;
        try {
          localStorage.setItem('guest_client_id', clientId);
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ localStorage nicht verfügbar (z.B. Inkognito-Modus), aber das ist OK:', e);
        }
      }

      if (deferWrites) {
        void getOrCreateClientId(partyId, { deferWrites: false }).catch((err) => {
          if (window.IS_DEBUG) console.warn('⚠️ Hintergrund guest_fingerprints/Gast-Write:', err);
        });
        return clientId;
      }

      if (window.IS_DEBUG) console.log(`🔍 Attempting to save Fingerprint [${clientId}] to guest_fingerprints...`);
      
      try {
        // Prüfe, ob clientId gültig ist (nicht leer, keine ungültigen Zeichen)
        if (!clientId || clientId.trim() === '') {
          console.error('❌ FEHLER: clientId ist leer oder ungültig!');
          return clientId; // Weiter mit clientId, auch wenn Speicherung fehlschlägt
        }
        
        // Prüfe auf ungültige Zeichen in der Document-ID (Firestore erlaubt keine /, ., etc.)
        const invalidChars = ['/', '.', '\\', '[', ']', '#', '*'];
        const hasInvalidChars = invalidChars.some(char => clientId.includes(char));
        if (hasInvalidChars) {
          if (window.IS_DEBUG) console.error('❌ FEHLER: clientId enthält ungültige Zeichen für Firestore Document-ID:', clientId); else console.error('❌ FEHLER: clientId enthält ungültige Zeichen für Firestore Document-ID.');
          // Ersetze ungültige Zeichen für Document-ID
          const sanitizedId = clientId.replace(/[/\\.\\[\\]#*]/g, '_');
          if (window.IS_DEBUG) console.warn('⚠️ Verwende bereinigte ID für Document-ID:', sanitizedId);
          clientId = sanitizedId;
        }
        
          const fingerprintMappingRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'guest_fingerprints'),
          clientId // Document-ID = Fingerprint (client_id)
        );
        
        if (window.IS_DEBUG) console.log('📝 Erstelle updateData für guest_fingerprints...');
        const updateData = {
          client_id: clientId, // client_id = Fingerprint
                last_seen: window.firebaseTimestamp.now()
        };
        
        // Füge last_party_id hinzu, falls partyId übergeben wurde
        if (partyId && partyId !== 'manual' && partyId !== '') {
          updateData.last_party_id = partyId;
          if (window.IS_DEBUG) console.log('📝 Füge last_party_id hinzu:', partyId);
        }
        
        if (window.IS_DEBUG) console.log('📝 Prüfe, ob Dokument bereits existiert...');
        // Prüfe, ob Dokument existiert
        const mappingDoc = await window.firebaseGetDoc(fingerprintMappingRef);
        
        if (!mappingDoc.exists()) {
          // Neues Dokument: Füge created_at hinzu
          updateData.created_at = window.firebaseTimestamp.now();
          if (window.IS_DEBUG) console.log('✅ Neues guest_fingerprints Dokument wird erstellt:', clientId);
        } else {
          if (window.IS_DEBUG) console.log('✅ guest_fingerprints Dokument existiert bereits, wird aktualisiert:', clientId);
        }
        
        if (window.IS_DEBUG) console.log('💾 Speichere/aktualisiere in Firestore mit Daten:', updateData);
        // Speichere/aktualisiere in Firestore
        await window.firebaseSetDoc(fingerprintMappingRef, updateData, { merge: true });
        if (window.IS_DEBUG) console.log('✅✅✅ ERFOLG: guest_fingerprints erfolgreich gespeichert!', { 
          document_id: clientId, 
            client_id: clientId,
          last_party_id: partyId || 'keine' 
          });
        
        // ✅ NEUE GAST-ZÄHLUNG PRO PARTY: Erstelle/aktualisiere Dokument unter parties/{partyId}/guests/{clientId}
        if (partyId && partyId !== 'manual' && partyId !== '') {
          if (window.IS_DEBUG) console.log("DEBUG: Starte Gast-Zählung für Party:", partyId);
          
          // ✅ DEBUG: Prüfe Firebase-Initialisierung
          if (!window.firebaseDb) {
            console.error("FIREBASE ERROR: window.firebaseDb ist nicht initialisiert!");
            return clientId;
          }
          if (!window.firebaseUpdateDoc) {
            console.error("FIREBASE ERROR: window.firebaseUpdateDoc ist nicht definiert!");
            return clientId;
          }
          if (!window.firebaseIncrement) {
            console.error("FIREBASE ERROR: window.firebaseIncrement ist nicht definiert!");
            return clientId;
          }
          if (window.IS_DEBUG) console.log("DEBUG: Firebase-Checks OK - firebaseDb:", !!window.firebaseDb, "firebaseUpdateDoc:", !!window.firebaseUpdateDoc, "firebaseIncrement:", !!window.firebaseIncrement);
          
          try {
            if (window.IS_DEBUG) console.log(`🔍 Erstelle/aktualisiere Gast-Dokument für Party: ${partyId}`);
            
            // Hole aktuelle Sprache (2-Zeichen-Kürzel) — wie UI: resolve/URL, nicht nur Storage||en
            let currentLang = 'de';
            try {
              currentLang = (typeof window.vbGetResolvedPwaLanguageCode === 'function')
                ? window.vbGetResolvedPwaLanguageCode()
                : ((localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en').trim().toLowerCase() || 'en');
            } catch (e) {
              if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Lesen der Sprache aus localStorage:', e);
            }
            
            // Erstelle Referenz zu parties/{partyId}/guests/{clientId}
            const partyGuestsRef = window.firebaseDoc(
              window.firebaseCollection(
                window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId),
                'guests'
              ),
              clientId
            );
            
            // Prüfe, ob Gast-Dokument bereits existiert
            const guestDoc = await window.firebaseGetDoc(partyGuestsRef);
            const isNewGuest = !guestDoc.exists();
            
            if (window.IS_DEBUG) console.log(`📝 Gast-Dokument existiert bereits: ${!isNewGuest}, ist neuer Gast: ${isNewGuest}`);
            
            // Erstelle/aktualisiere Gast-Dokument mit merge: true (client_id = Doc-ID für Firestore Rules)
            const guestData = {
              client_id: clientId,
              last_seen: window.firebaseTimestamp.now(),
              language: currentLang
            };
            
            const partyRef = window.firebaseDoc(
              window.firebaseCollection(window.firebaseDb, 'parties'),
              partyId
            );

            // Neuer Gast: ein Batch (Gast-Dokument + total_guest_count), damit nicht nur guests/{id} ohne Zähler-Update landet
            if (isNewGuest && typeof window.firebaseWriteBatch === 'function') {
              if (window.IS_DEBUG) console.log('DEBUG: Neuer Gast – writeBatch (guest + total_guest_count)');
              try {
                const batch = window.firebaseWriteBatch(window.firebaseDb);
                batch.set(partyGuestsRef, guestData, { merge: true });
                batch.update(partyRef, { total_guest_count: window.firebaseIncrement(1) });
                await batch.commit();
                if (window.IS_DEBUG) {
                  console.log('✅✅✅ ERFOLG: Batch Gast + total_guest_count committed', { party_id: partyId, client_id: clientId, language: currentLang });
                }
              } catch (batchErr) {
                console.error('FIREBASE ERROR: Gast-Zählung (Batch: guest + total_guest_count)', batchErr && (batchErr.code || batchErr.message || batchErr));
                if (window.IS_DEBUG) console.error('FIREBASE ERROR Details:', { name: batchErr?.name, message: batchErr?.message, code: batchErr?.code });
                if (typeof isFirestoreBlockLikeError === 'function' && isFirestoreBlockLikeError(batchErr) && typeof applyRealtimeBlockState === 'function') {
                  applyRealtimeBlockState(true);
                }
              }
            } else {
              await window.firebaseSetDoc(partyGuestsRef, guestData, { merge: true });
              if (window.IS_DEBUG) {
                console.log('✅✅✅ ERFOLG: Gast-Dokument gespeichert/aktualisiert (kein neuer Gast oder kein Batch)', {
                  party_id: partyId,
                  client_id: clientId,
                  language: currentLang,
                  is_new_guest: isNewGuest
                });
              }
              if (isNewGuest && typeof window.firebaseWriteBatch !== 'function') {
                console.warn('PWA: firebaseWriteBatch fehlt – Fallback update total_guest_count (nicht atomar mit Gast)');
                try {
                  await window.firebaseUpdateDoc(partyRef, { total_guest_count: window.firebaseIncrement(1) });
                } catch (incrementError) {
                  console.error('FIREBASE ERROR: Gast-Zählung (Fallback)', incrementError && (incrementError.code || incrementError.message || incrementError));
                  if (typeof isFirestoreBlockLikeError === 'function' && isFirestoreBlockLikeError(incrementError) && typeof applyRealtimeBlockState === 'function') {
                    applyRealtimeBlockState(true);
                  }
                }
              }
            }
          } catch (guestError) {
            console.error('FIREBASE ERROR: Gast-Dokument');
            if (window.IS_DEBUG) console.error('FIREBASE ERROR Details:', { name: guestError?.name, message: guestError?.message, code: guestError?.code });
            if (typeof isFirestoreBlockLikeError === 'function' && isFirestoreBlockLikeError(guestError) && typeof applyRealtimeBlockState === 'function') {
              applyRealtimeBlockState(true);
            }
          }
        }
        } catch (e) {
          if (window.IS_DEBUG) {
            console.log('DEBUG PWA: guest_fingerprints Fehler', e?.code || e?.message || e);
          }
          if (typeof isFirestoreBlockLikeError === 'function' && isFirestoreBlockLikeError(e) && typeof applyRealtimeBlockState === 'function') {
            applyRealtimeBlockState(true);
          }
        }
      
      return clientId;
    }
    
    // Prüft ob ein Song bereits gespielt wurde (in History oder als gespielter Wunsch)
    // Nutzt string_similarity mit Admin-Threshold
    // ✅ Hilfsfunktionen für String-Vergleich (wiederverwendbar)
    function stringSimilarity(str1, str2) {
      if (!str1 || !str2) return 0.0;
      if (str1 === str2) return 1.0;
      
      const longer = str1.length > str2.length ? str1 : str2;
      const shorter = str1.length > str2.length ? str2 : str1;
      
      if (longer.length === 0) return 1.0;
      
      let matches = 0;
      const longerLower = longer.toLowerCase();
      const shorterLower = shorter.toLowerCase();
      
      for (let i = 0; i < shorterLower.length; i++) {
        if (longerLower.includes(shorterLower[i])) {
          matches++;
        }
      }
      
      if (longerLower.includes(shorterLower) || shorterLower.includes(longerLower)) {
        return Math.max(0.7, matches / longer.length);
      }
      
      return matches / longer.length;
    }

    function normalizeText(text) {
      if (!text) return '';
      return text.toLowerCase()
        .replace(/ä/g, 'a')
        .replace(/ö/g, 'o')
        .replace(/ü/g, 'u')
        .replace(/ß/g, 'ss')
        .replace(/[^\w\s]/g, '')
        .trim();
    }

    // Standardliste für ignorierte Begriffe (Duplikat-Check), wenn in Firestore (party_settings/current.ignored_keywords) fehlt oder leer ist. Abgleich mit DJ-App (Flutter).
    const IGNORED_KEYWORDS_DEFAULT = ['Remix', 'Mix', 'Edit', 'Radio', 'Club', 'Extended', 'Video', 'Version'];

    // ✅ Duplikat-Vergleich (PWA = DJ-App): toLowerCase, Klammern () und [] inkl. Inhalt entfernen, Begriffe aus ignored_keywords am Ende entfernen, Umlaute normalisieren, Sonderzeichen entfernen. Nur für Ähnlichkeitscheck – Anzeige bleibt Original.
    function normalizeTextForDuplicateCheck(text, ignoredKeywords) {
      if (!text || typeof text !== 'string') return '';
      let s = String(text).trim();
      // Runde und eckige Klammern inkl. Inhalt entfernen
      s = s.replace(/\s*\([^)]*\)\s*/g, ' ');
      s = s.replace(/\s*\[[^\]]*\]\s*/g, ' ');
      // Alle Begriffe aus ignored_keywords (oder IGNORED_KEYWORDS_DEFAULT) am Ende des Titels entfernen
      const list = (Array.isArray(ignoredKeywords) && ignoredKeywords.length > 0) ? ignoredKeywords : IGNORED_KEYWORDS_DEFAULT;
      const escaped = list.map(k => String(k).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
      if (escaped) {
        const mixTerms = new RegExp('\\s+(' + escaped + ')\\s*$', 'gi');
        let prev = '';
        while (prev !== s) {
          prev = s;
          s = s.replace(mixTerms, ' ').trim();
        }
      }
      return normalizeText(s); // toLowerCase, Umlaute, Sonderzeichen
    }

    // ✅ Globale Dekodierung von HTML-Entities zu lesbaren Zeichen (z.B. &amp; -> &, &#39; -> ')
    // Sicherheit: Die Daten bleiben in Firestore maskiert, nur die Anzeige wird dekodiert
    function unescapeHtml(text) {
      if (!text || typeof text !== 'string') return text || '';
      // Nutze ein temporäres DOM-Element für sichere Dekodierung
      const textarea = document.createElement('textarea');
      textarea.innerHTML = text;
      return textarea.value;
    }

    // Rückwärtskompatibler Alias (alte Aufrufe bleiben funktionsfähig).
    function decodeHtmlEntities(text) {
      return unescapeHtml(text);
    }

    // Phase 2: begrenzte Firestore-Reads (Start/Dedup; volle Historie-Liste weiter paginiert aus begrenztem Stream pro Session)
    const PWA_FS_RECENT_PLAYED_WISHES = 10;
    const PWA_FS_RECENT_TRACKS_PER_SESSION = 10;
    const PWA_FS_PENDING_WISHES_CAP = 100;
    const PWA_FS_HISTORY_UI_TRACKS_PER_SESSION = 40;

    // ✅ Cache aktualisieren: History-Tracks für aktuelle Party
    async function updateHistoryCache(partyId) {
      if (!partyId || partyId === 'manual' || partyId === '') {
        localHistoryCache = [];
        cachePartyId = null;
        return;
      }
      
      // Nur aktualisieren wenn Party-ID sich geändert hat
      if (vbHistoryCachePartyId === partyId && localHistoryCache.length > 0) {
        return; // Cache ist aktuell
      }
      
        try {
        localHistoryCache = [];
        
        const historySessionsQuery = window.firebaseQuery(
          window.firebaseCollection(window.firebaseDb, 'music_history'),
          window.firebaseWhere('party_id', '==', partyId)
        );
        const historySessionsSnapshot = await window.firebaseGetDocs(historySessionsQuery);

        const sessionDocs = historySessionsSnapshot.docs.slice(0, 4);
        const trackSnaps = await Promise.all(sessionDocs.map(function (sessionDoc) {
          const tracksRef = window.firebaseCollection(
            window.firebaseDb,
            'music_history/' + sessionDoc.id + '/tracks'
          );
          const tracksRecentQ = window.firebaseQuery(
            tracksRef,
            window.firebaseOrderBy('timestamp', 'desc'),
            window.firebaseLimit(PWA_FS_RECENT_TRACKS_PER_SESSION)
          );
          return window.firebaseGetDocs(tracksRecentQ);
        }));

        for (const tracksSnapshot of trackSnaps) {
          for (const trackDoc of tracksSnapshot.docs) {
            const trackData = trackDoc.data();
            localHistoryCache.push({
              title: (trackData.title || '').trim().toLowerCase(),
              artist: (trackData.artist || '').trim().toLowerCase()
            });
          }
        }
        
        // 2. Prüfe in wishes (Status: played, party_id = snake_case)
        const playedWishesQuery = window.firebaseQuery(
          window.vbPartyWishesCollection(partyId),
          window.firebaseWhere('status', '==', 'played'),
          window.firebaseOrderBy('createdAt', 'desc'),
          window.firebaseLimit(PWA_FS_RECENT_PLAYED_WISHES)
        );
        const playedWishesSnapshot = await window.firebaseGetDocs(playedWishesQuery);

        for (const wishDoc of playedWishesSnapshot.docs) {
          const wishData = wishDoc.data();
          localHistoryCache.push({
            title: ((wishData.title || wishData.song || '')).trim().toLowerCase(),
            artist: (wishData.artist || '').trim().toLowerCase()
          });
        }
        
        vbHistoryCachePartyId = partyId;
        cachePartyId = partyId;
        if (window.IS_DEBUG) console.log('✅ History-Cache aktualisiert: ' + localHistoryCache.length + ' Einträge für Party ' + partyId);
      } catch (e) {
        if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Aktualisieren des History-Caches:', e);
      }
    }

    async function checkIfSongWasPlayed(title, artist, partyId) {
      try {
        if (!partyId || partyId === 'manual' || partyId === '') {
          return false; // Keine aktive Party
        }

        const dupSettings = await getDuplicateSettingsCached();
        const threshold = dupSettings.threshold;
        const ignoredKeywords = dupSettings.ignoredKeywords;

        // Normalisiere für Vergleich (Klammern/Mix-Begriffe entfernen wie in DJ-App)
        const normalizedTitle = normalizeTextForDuplicateCheck(title, ignoredKeywords);
        const normalizedArtist = normalizeTextForDuplicateCheck(artist, ignoredKeywords);

        if (!normalizedTitle && !normalizedArtist) {
          return false; // Keine Daten zum Vergleichen
        }

        // ✅ SCHRITT 1: Prüfe zuerst lokalen Cache
        if (vbHistoryCachePartyId === partyId && localHistoryCache.length > 0) {
          for (const cachedTrack of localHistoryCache) {
            if (!cachedTrack.title && !cachedTrack.artist) continue;

            const cachedTitle = normalizeTextForDuplicateCheck(cachedTrack.title, ignoredKeywords);
            const cachedArtist = normalizeTextForDuplicateCheck(cachedTrack.artist, ignoredKeywords);

            let titleSimilarity = 0.0;
            let artistSimilarity = 0.0;

            if (normalizedTitle && cachedTitle) {
              titleSimilarity = stringSimilarity(normalizedTitle, cachedTitle);
            }

            if (normalizedArtist && cachedArtist) {
              artistSimilarity = stringSimilarity(normalizedArtist, cachedArtist);
            }

            const avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

            if (avgSimilarity >= threshold) {
              if (window.IS_DEBUG) console.log('✅ Song bereits in lokalem History-Cache gefunden (Ähnlichkeit: ' + (avgSimilarity * 100).toFixed(1) + '%)');
              return true;
            }
          }
        } else {
          // Kein Cache: nicht beim Absenden blockieren (wird im Hintergrund vorgeladen)
          if (vbHistoryCachePartyId === partyId && localHistoryCache.length > 0) {
            for (const cachedTrack of localHistoryCache) {
              if (!cachedTrack.title && !cachedTrack.artist) continue;

              const cachedTitle = normalizeTextForDuplicateCheck(cachedTrack.title, ignoredKeywords);
              const cachedArtist = normalizeTextForDuplicateCheck(cachedTrack.artist, ignoredKeywords);

              let titleSimilarity = 0.0;
              let artistSimilarity = 0.0;

              if (normalizedTitle && cachedTitle) {
                titleSimilarity = stringSimilarity(normalizedTitle, cachedTitle);
              }

              if (normalizedArtist && cachedArtist) {
                artistSimilarity = stringSimilarity(normalizedArtist, cachedArtist);
              }

              const avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

              if (avgSimilarity >= threshold) {
                if (window.IS_DEBUG) console.log('✅ Song bereits in aktualisiertem History-Cache gefunden (Ähnlichkeit: ' + (avgSimilarity * 100).toFixed(1) + '%)');
                return true;
              }
            }
          }
        }

        if (window.IS_DEBUG) {
          console.log('⚠️ History-Cache leer – „bereits gespielt“-Check übersprungen (wird im Hintergrund geladen)');
        }
        return false;
      } catch (e) {
        console.error('❌ Fehler beim Duplikat-Check:', e);
        return false; // Bei Fehler: Kein Duplikat (sicherer Fallback)
      }
    }

    // ✅ Cache aktualisieren: Offene Wünsche für aktuelle Party
    async function updatePendingWishesCache(partyId) {
      if (!partyId || partyId === 'manual' || partyId === '') {
        localPendingWishesCache = [];
        return;
      }
      
      // Nur aktualisieren wenn Party-ID sich geändert hat
      if (vbPendingCachePartyId === partyId && localPendingWishesCache.length > 0) {
        return; // Cache ist aktuell
      }

      try {
        localPendingWishesCache = [];
        
        const wishesQuery = window.firebaseQuery(
          window.vbPartyWishesCollection(partyId),
          window.firebaseWhere('status', '==', 'pending'),
          window.firebaseOrderBy('createdAt', 'desc'),
          window.firebaseLimit(PWA_FS_PENDING_WISHES_CAP)
        );
        const wishesSnapshot = await window.firebaseGetDocs(wishesQuery);
        
        for (const wishDoc of wishesSnapshot.docs) {
          const wishData = wishDoc.data();
          localPendingWishesCache.push({
            id: wishDoc.id,
            title: ((wishData.title || wishData.song || '')).trim().toLowerCase(),
            artist: (wishData.artist || '').trim().toLowerCase(),
            spotify_id: wishData.spotify_id || null,
            data: wishData
          });
        }
        
        vbPendingCachePartyId = partyId;
        cachePartyId = partyId;
        if (window.IS_DEBUG) console.log('✅ Pending-Wishes-Cache aktualisiert: ' + localPendingWishesCache.length + ' Einträge für Party ' + partyId);
      } catch (e) {
        if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Aktualisieren des Pending-Wishes-Caches:', e);
      }
    }

    // Findet ähnliche Wünsche (Duplikat-Prüfung)
    // Prüft zuerst auf spotify_id (exakte Übereinstimmung), dann auf String-Ähnlichkeit
    // ✅ OPTIMIERT: Prüft zuerst lokalen Cache, dann Firestore
    async function findSimilarWish(normalizedTitle, normalizedArtist, spotifyId, partyId) {
      try {
        if (window.IS_DEBUG) console.log('=== DUPLIKAT-SUCHE STARTET ===');
        if (window.IS_DEBUG) console.log('📋 Party-ID:', partyId);
        
        // SICHERHEITSABFRAGE: Wenn keine gültige party_id vorhanden ist, keine Query starten
        if (!partyId || partyId === 'manual' || partyId === '' || typeof partyId !== 'string') {
          if (window.IS_DEBUG) console.warn('⚠️ Keine gültige party_id vorhanden, überspringe Duplikat-Check');
          return null;
        }
        
        const dupSettings = await getDuplicateSettingsCached();
        const duplicateThreshold = dupSettings.threshold;
        const ignoredKeywords = dupSettings.ignoredKeywords;
        const partyStartDate = null;
        const partyEndDate = null;

        if (window.IS_DEBUG) console.log('📊 Verwendeter Schwellenwert: ' + (duplicateThreshold * 100).toFixed(0) + '%');
        const minTitleArtist = Math.min(0.85, duplicateThreshold);

        if (vbPendingCachePartyId === partyId && localPendingWishesCache.length > 0) {
          if (window.IS_DEBUG) console.log('🔍 Prüfe lokalen Cache (' + localPendingWishesCache.length + ' Einträge)...');
          
          // ZUERST: Prüfe auf exakte spotify_id-Übereinstimmung
          if (spotifyId && spotifyId.trim()) {
            for (const cachedWish of localPendingWishesCache) {
              if (cachedWish.data && cachedWish.data.is_duplicate === true) continue;
              
              if (cachedWish.spotify_id && cachedWish.spotify_id === spotifyId) {
                const createdAt = cachedWish.data.createdAt;
                if (createdAt) {
                  const createdDate = createdAt.toDate();
                  if (partyStartDate && partyEndDate) {
                    if (createdDate < partyStartDate || createdDate >= partyEndDate) {
                      continue;
                    }
                  }
                }
                
                if (window.IS_DEBUG) console.log('✓✓✓ EXAKTE SPOTIFY_ID-ÜBEREINSTIMMUNG IM CACHE GEFUNDEN! ✓✓✓');
                return {
                  id: cachedWish.id,
                  data: cachedWish.data,
                  similarity: 1.0,
                  matchType: 'spotify_id'
                };
              }
            }
          }
          
          // ZWEITENS: Prüfe auf String-Ähnlichkeit (Mix/Remix-Zusätze werden für Vergleich entfernt)
          const normalizedInputTitle = normalizeTextForDuplicateCheck(normalizedTitle, ignoredKeywords);
          const normalizedInputArtist = normalizeTextForDuplicateCheck(normalizedArtist, ignoredKeywords);
          
          let bestSimilarity = 0.0;
          let bestMatch = null;
          
          for (const cachedWish of localPendingWishesCache) {
            if (cachedWish.data && cachedWish.data.is_duplicate === true) continue;
            
            const cachedTitle = normalizeTextForDuplicateCheck(cachedWish.title, ignoredKeywords);
            const cachedArtist = normalizeTextForDuplicateCheck(cachedWish.artist, ignoredKeywords);
            
            if (!cachedTitle && !cachedArtist) continue;
            
            let titleSimilarity = 0.0;
            let artistSimilarity = 0.0;
            
            if (normalizedInputTitle && cachedTitle) {
              titleSimilarity = stringSimilarity(normalizedInputTitle, cachedTitle);
            }
            
            if (normalizedInputArtist && cachedArtist) {
              artistSimilarity = stringSimilarity(normalizedInputArtist, cachedArtist);
            }
            
            const avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;
            // Zusatzbedingung: Titel- und Artist-Match jeweils >= minTitleArtist (von Admin-Schwellenwert begrenzt)
            const titleArtistMin = titleSimilarity >= minTitleArtist && artistSimilarity >= minTitleArtist;
            if (avgSimilarity >= duplicateThreshold && titleArtistMin && avgSimilarity > bestSimilarity) {
              bestSimilarity = avgSimilarity;
              bestMatch = {
                id: cachedWish.id,
                data: cachedWish.data,
                similarity: avgSimilarity,
                matchType: 'string_similarity'
              };
            }
          }
          
          if (bestMatch) {
            if (window.IS_DEBUG) console.log('✅ Ähnlicher Wunsch im lokalen Cache gefunden (Ähnlichkeit: ' + (bestMatch.similarity * 100).toFixed(1) + '%)');
            return bestMatch;
          }
        } else if (window.IS_DEBUG) {
          console.log('⚠️ Pending-Cache leer – Duplikat-Check übersprungen (wird im Hintergrund geladen)');
        }
        return null;
      } catch (e) {
        console.error('FEHLER beim Suchen ähnlicher Wünsche:', e);
        return null;
      }
    }
    
    // Aktualisiert guestStats in Firestore (nur für Gäste)
    async function updateGuestStats(partyId) {
      try {
        if (!currentClientId) {
          currentClientId = await getOrCreateClientId(partyId);
        }
        if (window.IS_DEBUG) console.log('🔑 updateGuestStats: Verwende currentClientId:', currentClientId);
        const guestStatsRef = window.firebaseDoc(
          window.firebaseCollection(
            window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId),
            'guestStats'
          ),
          currentClientId
        );

        // Lade aktuelle Stats
        const statsDoc = await window.firebaseGetDoc(guestStatsRef);
        const now = window.firebaseTimestamp.now();

        let wishes = [];
        if (statsDoc.exists()) {
          const data = statsDoc.data();
          wishes = data.wishes || [];
          if (window.IS_DEBUG) console.log('📝 updateGuestStats: Vorhandene Wünsche:', wishes.length);
        } else {
          if (window.IS_DEBUG) console.log('📝 updateGuestStats: Neue guestStats erstellt für currentClientId:', currentClientId);
        }

        // Füge neuen Wunsch hinzu
        wishes.push({
          timestamp: now
        });
        if (window.IS_DEBUG) console.log('✅ updateGuestStats: Neuer Wunsch hinzugefügt. Neue Anzahl:', wishes.length);

        // Speichere aktualisierte Stats
        await window.firebaseSetDoc(guestStatsRef, {
          wishes: wishes,
          last_updated: now,
          client_id: currentClientId
        }, { merge: true });
        if (window.IS_DEBUG) console.log('💾 updateGuestStats: Stats gespeichert für currentClientId:', currentClientId);
        
        if (window.IS_DEBUG) console.log('✅ guestStats aktualisiert für currentClientId: ' + currentClientId);
      } catch (e) {
        if (window.IS_DEBUG || !e || e.code !== 'permission-denied') {
          console.error('❌ Fehler beim Aktualisieren der guestStats:', e);
        }
        // Fehler nicht fatal - Wunsch wurde bereits gespeichert
      }
    }

    /** Ein Dokument aus `parties` per Join-Code (legacy-tolerant, ohne lifecycle_status-Filter). */
    async function findPartyDocByJoinCode(partyCode) {
      if (!partyCode || partyCode === 'manual') return null;
      const normalized = String(partyCode).trim();
      if (normalized.length !== 8) return null;

      if (typeof window.vbCollectJoinCodePartyDocs === 'function') {
        const allDocs = await window.vbCollectJoinCodePartyDocs(normalized);
        if (!allDocs || allDocs.length === 0) return null;
        if (typeof window.pickBestPartyDocForJoinCode === 'function') {
          return window.pickBestPartyDocForJoinCode(allDocs, new Date());
        }
        return allDocs[0];
      }

      const partiesRef = window.firebaseCollection(window.firebaseDb, 'parties');
      const numericCode = parseInt(partyCode, 10);
      const lifecycleJoin = ['active', 'finished', 'standby', 'upcoming'];
      const seen = new Set();
      const allDocs = [];

      const fetchDocs = async (field, value) => {
        try {
          const q = window.firebaseQuery(
            partiesRef,
            window.firebaseWhere(field, '==', value),
            window.firebaseWhere('lifecycle_status', 'in', lifecycleJoin)
          );
          const snap = await window.firebaseGetDocs(q);
          snap.docs.forEach((d) => {
            if (!seen.has(d.id)) {
              seen.add(d.id);
              allDocs.push(d);
            }
          });
        } catch (errFd) {
          if (window.IS_DEBUG) console.warn('findPartyDocByJoinCode: Query fehlgeschlagen', field, errFd && errFd.code);
        }
      };

      const sameNum = !isNaN(numericCode) && String(numericCode) === String(partyCode).trim();
      await Promise.all([
        fetchDocs('party_code', partyCode),
        sameNum ? fetchDocs('party_code', numericCode) : Promise.resolve(),
        fetchDocs('fixed_party_code', partyCode),
        sameNum ? fetchDocs('fixed_party_code', numericCode) : Promise.resolve(),
      ]);

      if (allDocs.length === 0) return null;
      if (typeof window.pickBestPartyDocForJoinCode === 'function') {
        return window.pickBestPartyDocForJoinCode(allDocs, new Date());
      }
      return allDocs[0];
    }

    function vbFloorDisplayLabel(rawLabel, floorKey) {
      var trimmed = rawLabel != null ? String(rawLabel).trim() : '';
      if (trimmed !== '') return trimmed;
      var key = floorKey != null ? String(floorKey).trim() : '';
      var defKey = (typeof window.VB_DEFAULT_FLOOR_KEY === 'string') ? window.VB_DEFAULT_FLOOR_KEY : 'default';
      if (!key || key === defKey) {
        return t('guest_floor_main_area', 'Main area');
      }
      return key;
    }

    function vbFloorOptionTitle(option) {
      var label = vbFloorDisplayLabel(option.floor_label, option.floor_key);
      var dj = (option.dj_name && String(option.dj_name).trim()) ? String(option.dj_name).trim() : 'DJ';
      var tpl = t('guest_floor_option_label', '{floorLabel} — DJ {djName}');
      return tpl.split('{floorLabel}').join(label).split('{djName}').join(dj);
    }

    var vbPartySessionGeneration = 0;

    function vbClearPartyBrandingCache() {
      try { window.__vbCachedPartyBrandingData = null; } catch (e) {}
    }

    function vbShouldShowFloorPickerForOptions(options) {
      if (typeof window.vbFloorOptionsHaveMultipleDistinctKeys === 'function') {
        return window.vbFloorOptionsHaveMultipleDistinctKeys(options);
      }
      if (!options || options.length <= 1) return false;
      var keys = Object.create(null);
      var defKey = (typeof window.VB_DEFAULT_FLOOR_KEY === 'string') ? window.VB_DEFAULT_FLOOR_KEY : 'default';
      for (var i = 0; i < options.length; i++) {
        var k = options[i].floor_key;
        if (k == null || String(k).trim() === '') k = defKey;
        else k = String(k).trim();
        keys[k] = true;
      }
      return Object.keys(keys).length > 1;
    }

    function vbHasMultipleJoinableFloors(options, currentPartyId) {
      if (!vbShouldShowFloorPickerForOptions(options)) return false;
      if (!currentPartyId) return true;
      var defKey = (typeof window.VB_DEFAULT_FLOOR_KEY === 'string') ? window.VB_DEFAULT_FLOOR_KEY : 'default';
      var currentKey = null;
      var currentListed = false;
      for (var i = 0; i < options.length; i++) {
        if (options[i].party_id === currentPartyId) {
          currentListed = true;
          currentKey = options[i].floor_key;
          if (currentKey == null || String(currentKey).trim() === '') currentKey = defKey;
          else currentKey = String(currentKey).trim();
          break;
        }
      }
      if (!currentListed) return false;
      if (!currentKey) return false;
      for (var j = 0; j < options.length; j++) {
        if (options[j].party_id === currentPartyId) continue;
        var otherKey = options[j].floor_key;
        if (otherKey == null || String(otherKey).trim() === '') otherKey = defKey;
        else otherKey = String(otherKey).trim();
        if (otherKey !== currentKey) return true;
      }
      return false;
    }

    async function vbLoadDjSessionBundle(createdByUid) {
      var uid = String(createdByUid || '').trim();
      if (!uid) return { userData: null, socialsData: null };
      var userPromise = (typeof fetchPublicDjProfile === 'function')
        ? fetchPublicDjProfile(uid).catch(function () { return null; })
        : Promise.resolve(null);
      var socialsPromise = (async function () {
        try {
          if (!window.firebaseDb || typeof window.firebaseDoc !== 'function') return null;
          var socialsRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'social_media_links'),
            uid
          );
          var socialsDoc = await window.firebaseGetDoc(socialsRef);
          if (socialsDoc.exists()) return sanitizeSocialsData(socialsDoc.data());
        } catch (e) {
          if (window.IS_DEBUG) console.warn('vbLoadDjSessionBundle socials:', e);
        }
        return null;
      })();
      var results = await Promise.all([userPromise, socialsPromise]);
      return { userData: results[0], socialsData: results[1] };
    }

    /** DJ-Profil, Socials, Branding, Drawer — atomar für Party (Join + Floor-Wechsel). */
    async function vbHydratePartyDjSession(partyId, partyData, createdByUid) {
      var gen = ++vbPartySessionGeneration;
      var uid = String(createdByUid || '').trim();
      if (uid) {
        try {
          sessionStorage.setItem('validatedPartyDjId', uid);
          localStorage.setItem('validatedPartyDjId', uid);
        } catch (eDj) {}
      }
      var bundle = await vbLoadDjSessionBundle(uid);
      if (gen !== vbPartySessionGeneration) return false;
      var activeId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
      if (!activeId || activeId !== partyId) return false;
      var userData = bundle.userData;
      var socialsData = bundle.socialsData;
      if (userData && userData.displayName) {
        sessionStorage.setItem(
          'currentDjName',
          String(userData.displayName).trim().substring(0, 100)
        );
      }
      var planType = (userData && userData.planType != null && String(userData.planType).trim() !== '')
        ? String(userData.planType).toLowerCase()
        : 'free';
      sessionStorage.setItem('djPlanType', planType);
      if (socialsData) {
        try { sessionStorage.setItem('currentDjSocials', JSON.stringify(socialsData)); } catch (eSoc) {}
      }
      if (partyData && typeof partyData === 'object') {
        window.__vbCachedPartyBrandingData = partyData;
      }
      if (uid && typeof vbBindWishboxGuestLiveStream === 'function') {
        vbBindWishboxGuestLiveStream(uid);
      }
      var djNameFromStorage = sessionStorage.getItem('currentDjName');
      if (djNameFromStorage) updateDrawerDjName(djNameFromStorage);
      if (typeof syncGuestDrawerNav === 'function') syncGuestDrawerNav();
      updateHeaderBranding(userData, socialsData);
      if (typeof updateHeaderBasedOnLoginStatus === 'function') updateHeaderBasedOnLoginStatus();
      if (typeof updatePartyInfoLine === 'function') updatePartyInfoLine();
      if (typeof updateBrandingLine === 'function') await updateBrandingLine(partyData);
      if (typeof updateLogoutButtonVisibility === 'function') updateLogoutButtonVisibility();
      if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
      applyWishboxBrandingFromParty(partyData, planType);
      if (typeof loadDrawerLogo === 'function') loadDrawerLogo();
      if (typeof renderSocialMediaLinks === 'function') {
        var socialPage = document.getElementById('socialMediaPage');
        if (socialPage && socialPage.style.display !== 'none') {
          await renderSocialMediaLinks();
        }
      }
      return true;
    }

    async function vbCollectAllPartyDocsByJoinCode(partyCode) {
      if (!partyCode || partyCode === 'manual') return [];
      var normalized = String(partyCode).replace(/[^0-9]/g, '').substring(0, 8);
      if (normalized.length !== 8) return [];
      if (typeof window.vbCollectJoinCodePartyDocs === 'function') {
        return window.vbCollectJoinCodePartyDocs(normalized);
      }
      var single = await findPartyDocByJoinCode(normalized);
      return single ? [single] : [];
    }

    async function vbEnrichFloorOptionsWithDjNames(options) {
      if (!options || !options.length) return [];
      var out = options.slice();
      await Promise.all(out.map(async function (opt) {
        try {
          var djId = (opt.created_by && String(opt.created_by).trim())
            ? String(opt.created_by).trim()
            : '';
          if (!djId) {
            var partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), opt.party_id);
            var partyDoc = await window.firebaseGetDoc(partyRef);
            if (!partyDoc.exists()) return;
            var data = partyDoc.data();
            djId = (data.created_by || data.dj_code || '').toString().trim();
          }
          if (!djId) return;
          var profile = await fetchPublicDjProfile(djId);
          var name = profile && profile.displayName ? String(profile.displayName).trim() : '';
          if (name) opt.dj_name = name;
        } catch (e) {
          if (window.IS_DEBUG) console.warn('vbEnrichFloorOptionsWithDjNames:', e);
        }
      }));
      return out;
    }

    async function vbListJoinableFloorOptions(joinCode, excludePartyId) {
      var docs = await vbCollectAllPartyDocsByJoinCode(joinCode);
      var now = new Date();
      var isJoinable = typeof window.vbIsPartyGuestJoinable === 'function'
        ? window.vbIsPartyGuestJoinable
        : function () { return false; };
      var options = [];
      var isPublicVenue = typeof window.vbIsPublicVenueParty === 'function'
        ? window.vbIsPublicVenueParty
        : function () { return false; };
      docs.forEach(function (doc) {
        if (excludePartyId && doc.id === excludePartyId) return;
        if (!isJoinable(doc.data(), now)) return;
        if (!isPublicVenue(doc.data())) return;
        if (typeof window.vbFloorOptionFromDoc === 'function') {
          options.push(window.vbFloorOptionFromDoc(doc));
        } else {
          var data = doc.data();
          options.push({
            party_id: doc.id,
            floor_key: (typeof window.vbEffectiveFloorKey === 'function') ? window.vbEffectiveFloorKey(data) : 'default',
            floor_label: (typeof window.vbRawFloorLabel === 'function') ? window.vbRawFloorLabel(data) : 'default',
            party_name: data.party_name || data.partyName || null,
            dj_name: 'DJ'
          });
        }
      });
      options.sort(function (a, b) {
        return String(a.floor_label || '').localeCompare(String(b.floor_label || ''));
      });
      return vbEnrichFloorOptionsWithDjNames(options);
    }

    async function vbRefreshMultiFloorAvailable() {
      var joinCode = vbPendingJoinCodeForFloorPick
        || sessionStorage.getItem('validatedPartyCode')
        || localStorage.getItem('validatedPartyCode')
        || (typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : null);
      var partyId = sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId');
      if (!joinCode || !partyId || partyId === 'manual') {
        vbMultiFloorAvailable = false;
        vbUpdateFloorSwitchButton();
        return;
      }
      var options = await vbListJoinableFloorOptions(joinCode, null);
      vbMultiFloorAvailable = vbHasMultipleJoinableFloors(options, partyId);
      vbUpdateFloorSwitchButton();
    }

    function vbHideFloorPicker() {
      vbFloorSelectionActive = false;
      vbFloorPickerOptions = null;
      vbFloorEndedRedirectLabel = null;
      var overlay = document.getElementById('guestFloorPickerOverlay');
      var opts = document.getElementById('guestFloorPickerOptions');
      var info = document.getElementById('guestFloorPickerInfo');
      if (overlay) overlay.style.display = 'none';
      if (opts) opts.innerHTML = '';
      if (info) {
        info.style.display = 'none';
        info.textContent = '';
      }
    }

    function vbRenderFloorPicker(options, infoMessage) {
      var overlay = document.getElementById('guestFloorPickerOverlay');
      var optsEl = document.getElementById('guestFloorPickerOptions');
      var infoEl = document.getElementById('guestFloorPickerInfo');
      var titleEl = document.getElementById('guestFloorPickerTitle');
      var subtitleEl = document.getElementById('guestFloorPickerSubtitle');
      if (!overlay || !optsEl) return;
      vbFloorPickerOptions = options || [];
      vbFloorSelectionActive = true;
      if (titleEl) titleEl.textContent = t('guest_floor_picker_title', 'Choose a floor');
      if (subtitleEl) subtitleEl.textContent = t('guest_floor_picker_choose', 'Select the floor for your music requests.');
      optsEl.innerHTML = '';
      if (infoMessage && infoEl) {
        infoEl.textContent = infoMessage;
        infoEl.style.display = 'block';
      } else if (infoEl) {
        infoEl.style.display = 'none';
        infoEl.textContent = '';
      }
      vbFloorPickerOptions.forEach(function (option) {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'guest-floor-picker-option';
        btn.textContent = vbFloorOptionTitle(option);
        btn.disabled = vbFloorJoinInProgress;
        btn.addEventListener('click', function () {
          void vbOnFloorOptionSelected(option);
        });
        optsEl.appendChild(btn);
      });
      overlay.style.display = 'flex';
      if (typeof showLoader === 'function') showLoader(false);
      var loadingOverlay = document.getElementById('loading-overlay');
      if (loadingOverlay) loadingOverlay.style.display = 'none';
      var inactive = document.getElementById('wishboxInactiveMessage');
      if (inactive) inactive.style.display = 'none';
    }

    function vbShowFloorPickerLoadingState(message) {
      var overlay = document.getElementById('guestFloorPickerOverlay');
      var optsEl = document.getElementById('guestFloorPickerOptions');
      var titleEl = document.getElementById('guestFloorPickerTitle');
      var subtitleEl = document.getElementById('guestFloorPickerSubtitle');
      if (titleEl) titleEl.textContent = t('guest_floor_picker_title', 'Choose a floor');
      if (subtitleEl) subtitleEl.textContent = t('guest_floor_picker_choose', 'Select the floor for your music requests.');
      if (overlay) overlay.style.display = 'flex';
      if (optsEl) {
        optsEl.innerHTML = '';
        var p = document.createElement('p');
        p.className = 'guest-floor-picker-loading';
        p.textContent = message || t('loading_data', 'Loading data...');
        optsEl.appendChild(p);
      }
      if (typeof showLoader === 'function') showLoader(false);
      var loadingOverlay = document.getElementById('loading-overlay');
      if (loadingOverlay) loadingOverlay.style.display = 'none';
    }

    async function vbShowFloorPickerForJoinCode(joinCode, options, endedFloorLabel) {
      var normalized = String(joinCode || '').replace(/[^0-9]/g, '').substring(0, 8);
      if (normalized.length !== 8) return false;
      if (!vbShouldShowFloorPickerForOptions(options || [])) return false;
      vbPendingJoinCodeForFloorPick = normalized;
      vbFloorSelectionActive = true;
      vbShowFloorPickerLoadingState(t('loading_data', 'Loading data...'));
      try { sessionStorage.setItem(window.vbSessionPartyCodeKey || 'vb_session_party_code', normalized); } catch (e) {}
      var enriched = await vbEnrichFloorOptionsWithDjNames(options || []);
      if (!enriched.length) {
        vbFloorSelectionActive = false;
        vbHideFloorPicker();
        if (typeof showPartyStatusModal === 'function') {
          showPartyStatusModal('invalid', t('party_code_invalid_or_inactive', 'Invalid or inactive party code.'));
        }
        return false;
      }
      vbFloorEndedRedirectLabel = endedFloorLabel || null;
      var info = null;
      if (endedFloorLabel) {
        var floorLabel = vbFloorDisplayLabel(endedFloorLabel, null);
        var tpl = t('guest_floor_ended_redirect_message', 'The party on {floorLabel} has ended. Please choose another floor.');
        info = tpl.split('{floorLabel}').join(floorLabel);
      }
      isWishboxActive = false;
      vbRenderFloorPicker(enriched, info);
      if (typeof updateWishboxUI === 'function') updateWishboxUI();
      return true;
    }

    function vbUpdateFloorSwitchButton() {
      var btn = document.getElementById('guestFloorSwitchBtn');
      if (!btn) return;
      var show = isWishboxActive && vbMultiFloorAvailable && !vbIsFloorPickerActive();
      btn.style.display = show ? 'block' : 'none';
      if (show) btn.textContent = t('guest_floor_switch_button', 'Switch floor');
    }

    async function vbShowFloorSwitchSheet() {
      var joinCode = sessionStorage.getItem('validatedPartyCode')
        || localStorage.getItem('validatedPartyCode')
        || vbPendingJoinCodeForFloorPick
        || (typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : null);
      if (!joinCode) return;
      await vbPrepareForFloorReselection(joinCode);
      var options = await vbListJoinableFloorOptions(joinCode, null);
      var partyId = sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId');
      if (!vbHasMultipleJoinableFloors(options, partyId)) return;
      await vbShowFloorPickerForJoinCode(joinCode, options, null);
    }

    async function vbPrepareForFloorReselection(joinCode) {
      vbPartySessionGeneration++;
      vbClearPartyBrandingCache();
      var normalized = String(joinCode || '').replace(/[^0-9]/g, '').substring(0, 8);
      delete togglePartyPausedOverlay._lastPaused;
      if (typeof clearBlockStatusListeners === 'function') clearBlockStatusListeners();
      if (typeof stopWishLimitStream === 'function') stopWishLimitStream();
      if (typeof stopPreWishLimitStream === 'function') stopPreWishLimitStream();
      if (typeof historyListener !== 'undefined' && historyListener) {
        try { historyListener(); } catch (e) {}
        historyListener = null;
      }
      if (typeof allTracksCache !== 'undefined') {
        allTracksCache.length = 0;
        allTracksCache = [];
      }
      if (typeof currentDjSocials !== 'undefined') currentDjSocials = null;
      localStorage.removeItem('validatedPartyId');
      localStorage.removeItem('validatedPartyName');
      localStorage.removeItem('currentPartyName');
      if (typeof clearSessionPartyData === 'function') clearSessionPartyData();
      try { sessionStorage.removeItem('validatedPartyDjId'); } catch (eDj1) {}
      try { localStorage.removeItem('validatedPartyDjId'); } catch (eDj2) {}
      try { localStorage.removeItem('guest_client_id'); } catch (eGc) {}
      currentClientId = null;
      try { sessionStorage.removeItem('guestPreWishSession'); } catch (e) {}
      if (normalized.length === 8) {
        sessionStorage.setItem('validatedPartyCode', normalized);
        localStorage.setItem('validatedPartyCode', normalized);
        try { sessionStorage.setItem(window.vbSessionPartyCodeKey || 'vb_session_party_code', normalized); } catch (e2) {}
        vbPendingJoinCodeForFloorPick = normalized;
      }
      isWishboxActive = false;
      isBlocked = false;
      blockedByWriteDenied = false;
      blockedByGuestRealtime = false;
      blockedByDeviceRealtime = false;
      blockedByUserRealtime = false;
      wishboxBlockGateResolved = false;
      if (typeof clearPreWishMode === 'function') clearPreWishMode();
      currentPartyStartDate = null;
      if (typeof stopPrePartyCountdown === 'function') stopPrePartyCountdown();
      if (typeof togglePartyPausedOverlay === 'function') togglePartyPausedOverlay(false);
      updateHeaderBranding(null, null);
      updateDrawerDjName('');
      if (typeof loadDrawerLogo === 'function') loadDrawerLogo();
      if (typeof updateHeaderBasedOnLoginStatus === 'function') updateHeaderBasedOnLoginStatus();
      if (typeof updatePartyInfoLine === 'function') updatePartyInfoLine();
      if (typeof updateLogoutButtonVisibility === 'function') updateLogoutButtonVisibility();
      vbMultiFloorAvailable = false;
      vbUpdateFloorSwitchButton();
    }

    async function vbJoinPartyById(partyId, joinCode) {
      if (!partyId || !validatePartyId(partyId)) return false;
      var normalized = String(joinCode || '').replace(/[^0-9]/g, '').substring(0, 8);
      try {
        var partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId);
        var partyDoc = await window.firebaseGetDoc(partyRef);
        if (!partyDoc.exists()) return false;
        var data = partyDoc.data();
        var now = new Date();
        var ended = typeof window.vbIsPartyEnded === 'function' ? window.vbIsPartyEnded(data, now) : false;
        if (ended) return false;
        var se = vbWishboxStartEndFromPartyData(data);
        if (se.startDate && now < se.startDate) {
          if (typeof window.vbIsPreWishWindowOpen === 'function' && window.vbIsPreWishWindowOpen(data, now)) {
            localStorage.setItem('validatedPartyId', partyId);
            sessionStorage.setItem('validatedPartyId', partyId);
            sessionStorage.setItem('validatedPartyCode', normalized);
            localStorage.setItem('validatedPartyCode', normalized);
            showPreWishOrPausedMode(data, data.party_name || 'Party', se.startDate);
            vbRunBlockCheckAfterJoin(partyId);
            vbHideFloorPicker();
            vbPendingJoinCodeForFloorPick = null;
            return true;
          }
          showPrePartyWaitMode(data.party_name || 'Party', se.startDate);
          return true;
        }
        var canonicalCode = data.party_code != null ? String(data.party_code) : normalized;
        var checkResult = {
          success: true,
          data: {
            party_id: partyId,
            party_code: canonicalCode,
            party_name: data.party_name || data.partyName || null,
            party_snapshot: (typeof window.partySnapshotFromData === 'function') ? window.partySnapshotFromData(data) : data
          }
        };
        await vbFinalizePartyJoin(normalized, checkResult);
        vbHideFloorPicker();
        vbPendingJoinCodeForFloorPick = null;
        vbFloorEndedRedirectLabel = null;
        unawaited(vbRefreshMultiFloorAvailable());
        return true;
      } catch (e) {
        if (window.IS_DEBUG) console.warn('vbJoinPartyById:', e);
        return false;
      }
    }

    function unawaited(promise) {
      if (promise && typeof promise.catch === 'function') promise.catch(function () {});
    }

    async function vbOnFloorOptionSelected(option) {
      if (!option || !option.party_id || vbFloorJoinInProgress) return;
      vbFloorJoinInProgress = true;
      var optsEl = document.getElementById('guestFloorPickerOptions');
      if (optsEl) {
        optsEl.querySelectorAll('button').forEach(function (b) { b.disabled = true; });
      }
      try {
        var joinCode = vbPendingJoinCodeForFloorPick
          || sessionStorage.getItem('validatedPartyCode')
          || localStorage.getItem('validatedPartyCode')
          || (typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : '');
        vbFloorSelectionActive = true;
        vbShowFloorPickerLoadingState(t('loading_data', 'Loading data...'));
        var ok = await vbJoinPartyById(option.party_id, joinCode);
        if (!ok && typeof showPartyStatusModal === 'function') {
          showPartyStatusModal('invalid', t('party_code_invalid_or_inactive', 'Invalid or inactive party code.'));
          vbHideFloorPicker();
        } else if (ok) {
          vbRunBlockCheckAfterJoin(option.party_id);
          if (typeof checkWishboxStatus === 'function') {
            checkWishboxStatus({ skipFullBlockRecheck: true });
          }
        }
      } finally {
        vbFloorJoinInProgress = false;
      }
    }

    async function vbTryFloorRedirectAfterPartyEnded(partyData, partyId) {
      if (typeof window.vbIsPublicVenueParty === 'function' && !window.vbIsPublicVenueParty(partyData)) {
        return false;
      }
      var joinCode = sessionStorage.getItem('validatedPartyCode')
        || localStorage.getItem('validatedPartyCode')
        || (partyData && partyData.party_code != null ? String(partyData.party_code) : '')
        || (typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : '');
      var normalized = String(joinCode || '').replace(/[^0-9]/g, '').substring(0, 8);
      if (normalized.length !== 8 || !partyId) return false;
      var options = await vbListJoinableFloorOptions(normalized, partyId);
      if (!options.length) return false;
      var endedKey = (typeof window.vbEffectiveFloorKey === 'function')
        ? window.vbEffectiveFloorKey(partyData)
        : 'default';
      var otherFloors = options.filter(function (o) {
        return (o.floor_key || 'default') !== endedKey;
      });
      if (!otherFloors.length || !vbShouldShowFloorPickerForOptions(otherFloors)) return false;
      var endedLabel = (typeof window.vbRawFloorLabel === 'function') ? window.vbRawFloorLabel(partyData) : null;
      await vbPrepareForFloorReselection(normalized);
      await vbShowFloorPickerForJoinCode(normalized, otherFloors, endedLabel);
      return true;
    }

    async function vbHandleGuestPartyEnded(partyData, partyId) {
      var redirected = await vbTryFloorRedirectAfterPartyEnded(partyData, partyId);
      if (redirected) return;
      runGuestPartyEndedWishboxFlow();
    }

    /** True wenn codeToCheck (8 Ziffern) zur Party passt (party_code / fixed_party_code). */
    function partyDataMatchesJoinCode(data, codeToCheck) {
      if (!data || codeToCheck == null || codeToCheck === '') return false;
      const c = String(codeToCheck).trim();
      const pc = data.party_code;
      if (pc != null && String(pc).trim() === c) return true;
      const nC = parseInt(c, 10);
      if (!isNaN(nC) && pc != null) {
        const nP = parseInt(String(pc), 10);
        if (!isNaN(nP) && nP === nC) return true;
      }
      const fpc = data.fixed_party_code;
      if (fpc != null && String(fpc).trim() === c) return true;
      if (!isNaN(nC) && fpc != null) {
        const nF = parseInt(String(fpc), 10);
        if (!isNaN(nF) && nF === nC) return true;
      }
      return false;
    }

    // Prüft, ob eine aktive Party läuft und gibt Party-ID und Party-Code zurück
    // Basierend auf dem gespeicherten Party-Code
    // Mit konkretem Join-Code: nur findPartyDocByJoinCode (gezielte Queries) — kein getDocs-Scan über alle Partys (Kosten/Latenz).
    async function getActivePartyInfo(partyCode) {
      try {
        const now = new Date();
        const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        const codeNorm = partyCode == null ? '' : String(partyCode).trim();
        const hasConcreteCode = codeNorm !== '' && codeNorm !== 'manual';

        if (hasConcreteCode) {
          if (window.IS_DEBUG) console.log('🔍 Party-Lookup nur per Code (kein Listen-Scan): ' + codeNorm);
          const partyDoc = await findPartyDocByJoinCode(codeNorm);
          if (!partyDoc) {
            if (window.IS_DEBUG) console.log('⚠️ Keine Party mit Code "' + codeNorm + '" gefunden');
            return {
              party_id: 'manual',
              party_code: codeNorm,
              party_name: null
            };
          }
          const data = partyDoc.data();
          const endedByLifecycle = data.lifecycle_status === 'finished' || data.finished_at != null;
          let endedByTime = false;
          if (data.end_date && typeof data.end_date.toDate === 'function' && now > data.end_date.toDate()) endedByTime = true;
          if (endedByLifecycle || endedByTime) {
            if (window.IS_DEBUG) console.log('⚠️ Party mit Code "' + codeNorm + '" ist beendet oder liegt in der Vergangenheit (Lifecycle/Zeitraum)');
            return {
              party_id: 'manual',
              party_code: codeNorm,
              party_name: null
            };
          }
          const partyCodeFromDb = data.party_code;
          const partyName = data.party_name || null;
          const canonical = partyCodeFromDb != null ? String(partyCodeFromDb) : String(codeNorm);
          if (window.IS_DEBUG) console.log('✅ Party gefunden mit Code "' + codeNorm + '": Party-ID ' + partyDoc.id + ', Name: ' + (partyName || 'NICHT GEFUNDEN'));
          return {
            party_id: partyDoc.id,
            party_code: canonical,
            party_name: partyName || null
          };
        }

        // Ohne konkreten Code: eine passende aktive Party aus gefilterter Liste (wie bisher; Regeln partyGuestDiscoveryListAllowed)
        const partiesRef = window.firebaseCollection(window.firebaseDb, 'parties');
        const partiesQuery = window.firebaseQuery(
          partiesRef,
          window.firebaseWhere('status', '==', 'active'),
          window.firebaseWhere('lifecycle_status', 'in', ['active', 'standby', 'upcoming']),
          window.firebaseWhere('end_date', '>=', window.firebaseTimestamp.fromDate(sevenDaysAgo))
        );

        const partiesSnapshot = await window.firebaseGetDocs(partiesQuery);

        for (const partyDoc of partiesSnapshot.docs) {
          const data = partyDoc.data();
          if (data.lifecycle_status === 'finished' || data.finished_at != null) continue;
          const startTimestamp = data.start_date;
          const endTimestamp = data.end_date;
          const partyCodeFromDb = data.party_code;

          if (startTimestamp && endTimestamp) {
            const startDate = startTimestamp.toDate();
            const endDate = endTimestamp.toDate();

            if (now >= startDate && now < endDate) {
              if (!partyCode || partyCode === 'manual' || partyCode == partyCodeFromDb || partyDataMatchesJoinCode(data, partyCode)) {
                const partyName = data.party_name || null;
                if (window.IS_DEBUG) console.log('✅ Aktive Party gefunden: ' + partyDoc.id + ', Party-Code: ' + partyCodeFromDb + ', Name: ' + (partyName || 'NICHT GEFUNDEN'));
                return {
                  party_id: partyDoc.id,
                  party_code: partyCodeFromDb || '',
                  party_name: partyName || null
                };
              }
            }
          }
        }

        if (window.IS_DEBUG) console.log('ℹ️ Keine Party gefunden, verwende Fallback');
        return {
          party_id: 'manual',
          party_code: partyCode || 'manual',
          party_name: null
        };
      } catch (error) {
        console.error('❌ Fehler beim Prüfen der aktiven Party:', error);
        return {
          party_id: 'manual',
          party_code: partyCode || 'manual',
          party_name: null
        };
      }
    }

    function clearBlockStatusListeners() {
      if (!Array.isArray(blockStatusListeners) || blockStatusListeners.length === 0) return;
      blockStatusListeners.forEach((unsubscribe) => {
        try {
          if (typeof unsubscribe === 'function') unsubscribe();
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ clearBlockStatusListeners: Fehler beim Entfernen eines Listeners:', e);
        }
      });
      blockStatusListeners = [];
    }

    /** Firestore Web / Rules: permission-denied, insufficient permissions, ggf. 400er Channel */
    function isFirestoreBlockLikeError(err) {
      if (err == null) return false;
      var code = err.code || '';
      var msg = String(err.message || err || '');
      if (code === 'permission-denied' || code === 'firestore/permission-denied') return true;
      if (/insufficient permissions/i.test(msg)) return true;
      if (/PERMISSION_DENIED/i.test(msg)) return true;
      if (/permission[- ]denied/i.test(msg)) return true;
      if (err.status === 400 && /permission|denied|PERMISSION/i.test(msg)) return true;
      return false;
    }

    /**
     * @param {boolean} [forceBlocked] true: sofort Sperr-UI (z. B. permission-denied beim Fingerprint-Write)
     */
    function applyRealtimeBlockState(forceBlocked) {
      if (forceBlocked === true) {
        blockedByWriteDenied = true;
        wishboxBlockGateResolved = true;
      } else {
        // Nach erfolgreichen Realtime-Reads: keine der drei Quellen meldet Sperre →
        // Schreib-verweigert-Heuristik nicht dauerhaft auf "gesperrt" lassen (sonst kein Entsperren per onSnapshot).
        if (!blockedByGuestRealtime && !blockedByDeviceRealtime && !blockedByUserRealtime) {
          blockedByWriteDenied = false;
        }
      }
      const nextBlocked = !!(blockedByGuestRealtime || blockedByDeviceRealtime || blockedByUserRealtime || blockedByWriteDenied);
      if (isBlocked !== nextBlocked) {
        isBlocked = nextBlocked;
        if (window.IS_DEBUG) {
          console.log('🔄 applyRealtimeBlockState: isBlocked aktualisiert:', {
            blockedByGuestRealtime,
            blockedByDeviceRealtime,
            blockedByUserRealtime,
            blockedByWriteDenied,
            isBlocked
          });
        }
      }
      updateWishboxUI();
    }

    try {
      window.addEventListener('unhandledrejection', function (ev) {
        try {
          var r = ev.reason;
          if (isFirestoreBlockLikeError(r)) {
            ev.preventDefault();
            applyRealtimeBlockState(true);
          }
        } catch (e) {}
      });
    } catch (e) {}

    function isUserBlockedFromData(data) {
      const src = (data && typeof data === 'object') ? data : {};
      const byFlag = src.is_blocked === true;
      const rawStatus = String(src.status || '').trim().toLowerCase();
      const byStatus = rawStatus === 'gesperrt' || rawStatus === 'blocked';
      return byFlag || byStatus;
    }

    function isGuestBlockedFromData(data) {
      const src = (data && typeof data === 'object') ? data : {};
      const blockStatus = String(src.block_status || '').trim().toLowerCase();
      if (blockStatus === 'party_specific' || blockStatus === 'permanent') return true;
      if (blockStatus === 'temporary') {
        const blockedUntil = src.blocked_until;
        if (blockedUntil && typeof blockedUntil.toDate === 'function') {
          const now = new Date();
          const until = blockedUntil.toDate();
          return now < until;
        }
      }
      return false;
    }

    function readStorageValue(key) {
      const fromSession = sessionStorage.getItem(key);
      if (fromSession && String(fromSession).trim() !== '') return String(fromSession).trim();
      const fromLocal = localStorage.getItem(key);
      if (fromLocal && String(fromLocal).trim() !== '') return String(fromLocal).trim();
      return '';
    }

    function resolveCurrentUserUid() {
      const directKeys = [
        'uid',
        'userUid',
        'user_uid',
        'firebaseUid',
        'firebase_uid',
        'validatedUserId',
        'validatedUserUid',
        'guest_uid',
        'registered_uid'
      ];
      for (let i = 0; i < directKeys.length; i++) {
        const val = readStorageValue(directKeys[i]);
        if (val) return val;
      }

      const objectKeys = ['user', 'currentUser', 'guestUser', 'authUser'];
      for (let i = 0; i < objectKeys.length; i++) {
        const raw = readStorageValue(objectKeys[i]);
        if (!raw) continue;
        try {
          const parsed = JSON.parse(raw);
          const uid = String((parsed && (parsed.uid || parsed.userUid || parsed.user_uid)) || '').trim();
          if (uid) return uid;
        } catch (e) {
          // Kein JSON -> ignorieren
        }
      }

      const params = new URLSearchParams(window.location.search);
      const uidFromUrl = String(params.get('uid') || '').trim();
      if (uidFromUrl) return uidFromUrl;
      return '';
    }

    // Prüft Block-Status: zuerst getDoc (kein Formular-Flackern), dann Realtime-Streams
    async function checkBlockStatus() {
      wishboxBlockGateResolved = false;
      blockedByWriteDenied = false;
      try {
        updateWishboxUI();
      } catch (eUI) {}

      try {
        if (window.IS_DEBUG) console.log('checkBlockStatus: Starte Block-Status-Pruefung...');
        try {
          if (!currentClientId) {
            currentClientId = await getOrCreateClientId();
          }
        } catch (e) {
          if (isFirestoreBlockLikeError(e)) {
            applyRealtimeBlockState(true);
            return;
          }
          throw e;
        }
        if (window.IS_DEBUG) console.log('checkBlockStatus: currentClientId:', currentClientId);

        clearBlockStatusListeners();
        blockedByGuestRealtime = false;
        blockedByDeviceRealtime = false;
        blockedByUserRealtime = false;

        const currentPartyId = sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId');
        const userUid = resolveCurrentUserUid();

        const blockInitialReads = [];

        if (userUid) {
          blockInitialReads.push((async () => {
            try {
              const userDocRef0 = window.firebaseDoc(
                window.firebaseCollection(window.firebaseDb, 'users'),
                userUid
              );
              const snapU = await window.firebaseGetDoc(userDocRef0);
              blockedByUserRealtime = snapU.exists() && isUserBlockedFromData(snapU.data());
            } catch (errU) {
              if (isFirestoreBlockLikeError(errU)) applyRealtimeBlockState(true);
              else blockedByUserRealtime = false;
            }
          })());
        }

        function attachUserBlockListener() {
          if (!userUid) return;
          const userDocRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'users'),
            userUid
          );
          const userUnsubscribe = window.firebaseOnSnapshot(userDocRef, (snapshot) => {
            blockedByUserRealtime = snapshot.exists() && isUserBlockedFromData(snapshot.data());
            if (window.IS_DEBUG) {
              console.log('users/{uid} Listener: Block-Status geaendert', {
                uid: userUid,
                exists: snapshot.exists(),
                blockedByUserRealtime
              });
            }
            applyRealtimeBlockState();
          }, (error) => {
            console.error('users/{uid} Listener Fehler:', error);
            if (isFirestoreBlockLikeError(error)) applyRealtimeBlockState(true);
            else {
              blockedByUserRealtime = false;
              applyRealtimeBlockState();
            }
          });
          blockStatusListeners.push(userUnsubscribe);
        }

        if (!currentClientId || currentClientId.trim() === '' || !currentPartyId || currentPartyId === 'manual' || currentPartyId === '') {
          await Promise.all(blockInitialReads);
          wishboxBlockGateResolved = true;
          attachUserBlockListener();
          if (!userUid && window.IS_DEBUG) {
            console.log('checkBlockStatus: Keine UID, users-Stream uebersprungen');
          }
          if (window.IS_DEBUG) console.log('checkBlockStatus: Kein party/client Kontext fuer blocked_guests');
          applyRealtimeBlockState();
          return;
        }
        if (window.IS_DEBUG) console.log('checkBlockStatus: currentPartyId:', currentPartyId);

        const blockedDeviceRef = window.firebaseDoc(
          window.firebaseCollection(window.firebaseDb, 'blocked_devices'),
          currentClientId
        );
        const documentId = `${currentClientId}_${currentPartyId}`;
        const blockedGuestRef = window.firebaseDoc(
          window.firebaseCollection(window.firebaseDb, 'blocked_guests'),
          documentId
        );

        blockInitialReads.push((async () => {
          try {
            const snapD = await window.firebaseGetDoc(blockedDeviceRef);
            blockedByDeviceRealtime = snapD.exists() && isGuestBlockedFromData(snapD.data());
          } catch (errD) {
            if (isFirestoreBlockLikeError(errD)) applyRealtimeBlockState(true);
            else blockedByDeviceRealtime = false;
          }
        })());

        blockInitialReads.push((async () => {
          try {
            const snapG = await window.firebaseGetDoc(blockedGuestRef);
            blockedByGuestRealtime = snapG.exists() && isGuestBlockedFromData(snapG.data());
          } catch (errG) {
            if (isFirestoreBlockLikeError(errG)) applyRealtimeBlockState(true);
            else blockedByGuestRealtime = false;
          }
        })());

        await Promise.all(blockInitialReads);

        wishboxBlockGateResolved = true;
        applyRealtimeBlockState();

        attachUserBlockListener();

        const blockedDeviceUnsubscribe = window.firebaseOnSnapshot(blockedDeviceRef, (snapshot) => {
          blockedByDeviceRealtime = snapshot.exists() && isGuestBlockedFromData(snapshot.data());
          if (window.IS_DEBUG) {
            console.log('blocked_devices Listener:', {
              documentId: currentClientId,
              exists: snapshot.exists(),
              blockedByDeviceRealtime
            });
          }
          applyRealtimeBlockState();
        }, (error) => {
          console.error('blocked_devices Listener Fehler:', error);
          if (isFirestoreBlockLikeError(error)) applyRealtimeBlockState(true);
          else {
            blockedByDeviceRealtime = false;
            applyRealtimeBlockState();
          }
        });
        blockStatusListeners.push(blockedDeviceUnsubscribe);

        const blockedGuestUnsubscribe = window.firebaseOnSnapshot(blockedGuestRef, (snapshot) => {
          blockedByGuestRealtime = snapshot.exists() && isGuestBlockedFromData(snapshot.data());
          if (window.IS_DEBUG) {
            console.log('blocked_guests Listener (primaer):', {
              documentId,
              exists: snapshot.exists(),
              blockedByGuestRealtime
            });
          }
          applyRealtimeBlockState();
        }, (error) => {
          console.error('blocked_guests Listener Fehler (primaer):', error);
          if (isFirestoreBlockLikeError(error)) applyRealtimeBlockState(true);
          else {
            blockedByGuestRealtime = false;
            applyRealtimeBlockState();
          }
        });
        blockStatusListeners.push(blockedGuestUnsubscribe);

        void (async () => {
          try {
            const allBlockedQuery = window.firebaseQuery(
              window.firebaseCollection(window.firebaseDb, 'blocked_guests'),
              window.firebaseWhere('client_id', '==', currentClientId),
              window.firebaseWhere('party_id', '==', currentPartyId)
            );
            const allBlockedSnapshot = await window.firebaseGetDocs(allBlockedQuery);
            if (!allBlockedSnapshot.empty) {
              const firstBlocked = allBlockedSnapshot.docs[0];
              if (firstBlocked.id !== documentId) {
                const fallbackRef = window.firebaseDoc(
                  window.firebaseCollection(window.firebaseDb, 'blocked_guests'),
                  firstBlocked.id
                );
                const fallbackUnsubscribe = window.firebaseOnSnapshot(fallbackRef, (snapshot) => {
                  blockedByGuestRealtime = snapshot.exists() && isGuestBlockedFromData(snapshot.data());
                  if (window.IS_DEBUG) {
                    console.log('blocked_guests Listener (fallback):', {
                      documentId: firstBlocked.id,
                      exists: snapshot.exists(),
                      blockedByGuestRealtime
                    });
                  }
                  applyRealtimeBlockState();
                }, (error) => {
                  console.error('blocked_guests Listener Fehler (fallback):', error);
                  if (isFirestoreBlockLikeError(error)) applyRealtimeBlockState(true);
                  else {
                    blockedByGuestRealtime = false;
                    applyRealtimeBlockState();
                  }
                });
                blockStatusListeners.push(fallbackUnsubscribe);
              }
            }
          } catch (e) {
            if (window.IS_DEBUG) console.log('checkBlockStatus: Fallback-Query fehlgeschlagen:', e);
          }
        })();

        if (window.IS_DEBUG) console.log('checkBlockStatus: Realtime-Listener aktiv');
      } catch (e) {
        console.error('Fehler beim Initialisieren der Block-Status-Listener:', e);
        if (isFirestoreBlockLikeError(e)) applyRealtimeBlockState(true);
        else {
          blockedByGuestRealtime = false;
          blockedByDeviceRealtime = false;
          blockedByUserRealtime = false;
        }
        wishboxBlockGateResolved = true;
        applyRealtimeBlockState();
      }
    }

    // Prüfe Wunschbox-Status
    // options.skipFullBlockRecheck: true = periodischer Poll (z. B. alle 30s) ohne checkBlockStatus,
    // damit wishboxBlockGateResolved nicht zurückgesetzt wird (sonst Loader/Formular-Flackern).
    async function checkWishboxStatus(options) {
      window.bodyLoadError = false;
      try {
        if (window.__vbDeferWishboxStatusUntilBoot === true) {
          if (window.IS_DEBUG) console.log('DEBUG PWA: checkWishboxStatus — Boot läuft, überspringe');
          return;
        }
        if (vbIsFloorPickerActive()) {
          if (window.IS_DEBUG) console.log('DEBUG PWA: checkWishboxStatus — Floor-Auswahl aktiv, überspringe');
          return;
        }

        vbClearStaleValidatedPartyIfJoinCodeMismatch();
        var savedPartyIdLocal = localStorage.getItem('validatedPartyId');
        var savedPartyIdSession = sessionStorage.getItem('validatedPartyId');
        if (window.IS_DEBUG) console.log('DEBUG PWA: checkWishboxStatus partyId local=', savedPartyIdLocal, 'session=', savedPartyIdSession);
        
        if ((!savedPartyIdLocal || savedPartyIdLocal === 'manual' || savedPartyIdLocal === '') &&
            (!savedPartyIdSession || savedPartyIdSession === 'manual' || savedPartyIdSession === '')) {
          if (vbIsFloorPickerActive()) return;
          if (vbHasAnyJoinFlowSignal()) {
            if (window.IS_DEBUG) console.log('DEBUG PWA: Keine Party-ID, Join-Signal — warte auf Auto-Login (kein Inaktiv-UI)');
            return;
          }
          if (window.IS_DEBUG) console.log('DEBUG PWA: Keine Party-ID, breche ab');
          isWishboxActive = false;
          wishboxBlockGateResolved = true;
          blockedByWriteDenied = false;
          updateWishboxUI();
          return;
        }
        
        // ✅ Erfolgs-Sperre: Wenn Erfolgsmeldung aktiv ist, überspringe UI-Updates
        if (window.isSuccessActive) {
          if (window.IS_DEBUG) console.log('✅ checkWishboxStatus: Erfolgsmeldung aktiv, überspringe UI-Updates');
          return;
        }

        const skipBlock = options && options.skipFullBlockRecheck === true;
        if (skipBlock) {
          if (document.getElementById('vbPartyEndedOverlay')) {
            if (window.IS_DEBUG) console.log('checkWishboxStatus: Poll — Party-Ende-Overlay aktiv, überspringe');
            return;
          }
          if (isPreWishesPausedMode
              || (typeof vbIsPrePartyWaitUiActive === 'function' && vbIsPrePartyWaitUiActive())
              || (typeof vbIsFloorPickerActive === 'function' && vbIsFloorPickerActive())
              || document.getElementById('partyCodeErrorModalOverlay')) {
            if (window.IS_DEBUG) console.log('checkWishboxStatus: Poll — Sonderfenster aktiv, überspringe');
            return;
          }
          var pollPauseOv = document.getElementById('partyPausedOverlay');
          if (pollPauseOv && pollPauseOv.style.display === 'flex') {
            if (window.IS_DEBUG) console.log('checkWishboxStatus: Poll — Pause aktiv, überspringe');
            return;
          }
          if (isBlocked) {
            if (window.IS_DEBUG) console.log('checkWishboxStatus: Poll — Gast gesperrt, überspringe');
            return;
          }
        }
        
        // Block-Status: bei vollem Lauf; beim 30s-Poll überspringen (sonst Gate-Reset → Flackern)
        if (!skipBlock) {
          // Prüfe zuerst Block-Status (immer, auch ohne Party-Code)
          if (window.IS_DEBUG) console.log('🔍 checkWishboxStatus: Starte Block-Status-Prüfung...');
          await checkBlockStatus();
        } else if (window.IS_DEBUG) {
          console.log('checkWishboxStatus: periodischer Poll, überspringe checkBlockStatus');
        }

        // NEUE PRIORITÄT: Zuerst localStorage nach party_id prüfen
        const savedPartyId = savedPartyIdLocal || savedPartyIdSession;
        if (savedPartyId && savedPartyId !== 'manual' && savedPartyId !== '') {
          if (window.IS_DEBUG) console.log('✅ Gefundene party_id in localStorage:', savedPartyId);
          
          // ✅ ID-Recovery: Stelle Party-ID in sessionStorage wieder her
          sessionStorage.setItem('validatedPartyId', savedPartyId);
          if (window.IS_DEBUG) console.log('✅ Party-ID in sessionStorage gespeichert');
          
          // ✅ Volle DJ-/Header-Anreicherung nur außerhalb des 30s-Polls (sonst Flackern)
          var vbStatusPartyDoc = null;
          var vbStatusPartyData = null;
          if (!skipBlock) {
          try {
            if (window.IS_DEBUG) console.log('🔍 Lade Party-Daten von Firebase für Party-ID:', savedPartyId);
            const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), savedPartyId);
            const partyDoc = await window.firebaseGetDoc(partyRef);
            
            if (partyDoc.exists()) {
              if (window.IS_DEBUG) console.log('DEBUG PWA: Party-Dokument geladen, partyId=', savedPartyId);
              const partyDataForDj = sanitizePartyData(partyDoc.data());
              vbStatusPartyDoc = partyDoc;
              vbStatusPartyData = partyDataForDj;
              window.__vbCachedPartyBrandingData = partyDataForDj;
              
              // ✅ Wenn Party beendet: sofort Reset und zurück zur Code-Eingabe
              const nowDate = new Date();
              const endedByHelper = typeof window.vbIsPartyEnded === 'function'
                ? window.vbIsPartyEnded(partyDataForDj, nowDate)
                : false;
              const lifecycleStatus = partyDataForDj.lifecycle_status;
              const nowPosix = Math.floor(Date.now() / 1000);
              const endPosix = Number(partyDataForDj.end_time_posix || 0);
              const statusEnded = partyDataForDj.status === 'beendet' || partyDataForDj.status === 'ended';
              if (endedByHelper || lifecycleStatus === 'finished' || statusEnded
                  || (Number.isFinite(endPosix) && endPosix > 0 && nowPosix >= endPosix)) {
                if (window.IS_DEBUG) console.log('⚠️ Party ist beendet (lifecycle_status === finished), Floor-Redirect oder Ausgang');
                if (typeof vbHandleGuestPartyEnded === 'function') {
                  void vbHandleGuestPartyEnded(partyDataForDj, savedPartyId);
                } else if (typeof runGuestPartyEndedWishboxFlow === 'function') {
                  runGuestPartyEndedWishboxFlow();
                }
                return;
              }
              
              if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
              
              // ✅ Stelle party_name wieder her (nur wenn vorhanden)
              const partyName = partyDataForDj.party_name || null; // ✅ Partyname aus Firestore (kein Fallback mehr)
              if (partyName && partyName.trim() !== '' && partyName !== 'Deine Party' && partyName !== 'Your Party') {
                sessionStorage.setItem('validatedPartyName', partyName.trim());
                localStorage.setItem('validatedPartyName', partyName.trim());
                sessionStorage.setItem('currentPartyName', partyName.trim());
                localStorage.setItem('currentPartyName', partyName.trim());
                if (window.IS_DEBUG) console.log('💾 party_name wiederhergestellt in sessionStorage:', partyName.trim());
                if (window.IS_DEBUG) console.log('💾 party_name wiederhergestellt in localStorage:', partyName.trim());
              }
              if (partyDataForDj.start_date && typeof partyDataForDj.start_date.toDate === 'function') {
                persistPartyStartDate(partyDataForDj.start_date.toDate());
              } else if (partyDataForDj.start_time_posix) {
                persistPartyStartDate(new Date(Number(partyDataForDj.start_time_posix) * 1000));
              }
              if (!partyName || partyName.trim() === '' || partyName === 'Deine Party' || partyName === 'Your Party') {
                if (window.IS_DEBUG) console.warn('⚠️ Kein gültiger partyName in Firestore gefunden für Party-ID:', savedPartyId);
                if (window.IS_DEBUG) console.warn('⚠️ Partyname nicht vorhanden');
                // ✅ Lösche alte Werte, falls kein Name vorhanden
                sessionStorage.removeItem('validatedPartyName');
                localStorage.removeItem('validatedPartyName');
              }
              
              // UID nur lokal für Folgeabrufe verwenden, niemals speichern/loggen.
              const createdByUid = (typeof partyDoc.data()?.created_by === 'string')
                ? partyDoc.data().created_by.trim()
                : '';
              
              // ✅ LOG: Gefundene Creator-UID
              if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
              
              if (createdByUid) {
                try {
                  sessionStorage.setItem('validatedPartyDjId', createdByUid);
                  localStorage.setItem('validatedPartyDjId', createdByUid);
                  vbBindWishboxGuestLiveStream(createdByUid);
                  // ✅ LOG: Starte Abfrage für User-ID
                  if (window.IS_DEBUG) console.log('🚀 LOG: Starte Abfrage für User-ID:', createdByUid);
                  if (window.IS_DEBUG) console.log('🚀 LOG: Starte Abfrage für Socials-ID:', createdByUid);
                  
                  // ✅ Schritt C: Nutze created_by als Dokument-ID für parallele Abfragen
                  const [userDocResult, socialsDocResult] = await Promise.all([
                    // Abfrage A: users Collection mit created_by als Dokument-ID
                    (async () => {
                      try {
                        if (window.IS_DEBUG) console.log('🔍 Lade Public DJ-Profil mit UID:', createdByUid);
                        const userData = await fetchPublicDjProfile(createdByUid);
                        if (userData) {
                          if (window.IS_DEBUG) console.log('✅ Public DJ-Profil geladen');
                          return userData;
                        }
                        if (window.IS_DEBUG) console.warn('⚠️ Public DJ-Profil nicht gefunden für UID:', createdByUid);
                        return null;
                      } catch (e) {
                        console.error('❌ Fehler beim Laden des Public DJ-Profils:', e);
                        return null;
                      }
                    })(),
                    // Abfrage B: social_media_links Collection mit created_by als Dokument-ID
                    (async () => {
                      try {
                        if (window.IS_DEBUG) console.log('🔍 Lade Socials-Dokument mit ID:', createdByUid);
                        if (window.IS_DEBUG) console.log('🔍 Collection: social_media_links, Dokument-ID:', createdByUid);
                        const socialsRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'social_media_links'), createdByUid);
                        const socialsDoc = await window.firebaseGetDoc(socialsRef);
                        if (window.IS_DEBUG) console.log('🔍 Socials-Dokument existiert?', socialsDoc.exists());
                        if (socialsDoc.exists()) {
                          const socialsData = sanitizeSocialsData(socialsDoc.data());
                          if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
                          return socialsData;
                        } else {
                          if (window.IS_DEBUG) console.warn('⚠️ Socials-Dokument nicht gefunden für created_by UID:', createdByUid);
                          if (window.IS_DEBUG) console.warn('⚠️ Prüfe: Existiert Dokument social_media_links/' + createdByUid + ' in Firebase?');
                          return null;
                        }
                      } catch (e) {
                        console.error('❌ Fehler beim Laden des Socials-Dokuments:', e);
                        console.error('❌ Fehler-Details:', e.message, e.stack);
                        return null;
                      }
                    })()
                  ]);
                  
                  const userData = userDocResult;
                  const socialsData = socialsDocResult;
                  
                  // ✅ Client-Side Isolation: Nur speichern, wenn validatedPartyId vorhanden ist
                  const validatedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
                  if (!validatedPartyId || validatedPartyId === 'manual' || validatedPartyId === '') {
                    if (window.IS_DEBUG) console.warn('⚠️ Keine validatedPartyId vorhanden - speichere keine DJ-Daten in sessionStorage');
                    return;
                  }
                  
                  // ✅ Session-Sicherung: Speichere den gefundenen Namen und das Social-Media-Objekt
                  if (userData) {
                    const djName = userData.displayName || null;
                    if (djName) {
                      // ✅ XSS-Schutz: Nur Text speichern, keine HTML
                      const sanitizedDjName = String(djName).trim().substring(0, 100); // Max 100 Zeichen
                      sessionStorage.setItem('currentDjName', sanitizedDjName);
                      if (window.IS_DEBUG) console.log('✅ DJ-Name in sessionStorage gespeichert (sanitized):', sanitizedDjName);
                    }
                    // ✅ VibesBox Free Limits: planType für Logo/Social/Kontakt-Einschränkungen
                    const planType = (userData.planType != null && String(userData.planType).trim() !== '') ? String(userData.planType).toLowerCase() : 'free';
                    sessionStorage.setItem('djPlanType', planType);
                    if (typeof syncGuestDrawerNav === 'function') syncGuestDrawerNav();
                  }
                  
                  if (socialsData) {
                    // ✅ XSS-Schutz: Nur JSON-String speichern, keine direkten HTML-Injectionen
                    try {
                      sessionStorage.setItem('currentDjSocials', JSON.stringify(socialsData));
                      if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
                    } catch (e) {
                      console.error('❌ Fehler beim Speichern der Socials-Daten:', e);
                    }
                  }
                  
                  
                  // ✅ UI & Menü: Aktualisiere Hamburger-Menü mit DJ-Namen
                  const djNameFromStorage = sessionStorage.getItem('currentDjName');
                  if (djNameFromStorage) {
                    updateDrawerDjName(djNameFromStorage);
                  }
                  
                  // ✅ Header-Branding: Aktualisiere Header mit DJ-Logo/Name
                  updateHeaderBranding(userData, socialsData);
                  // ✅ Zusätzlich: Aktualisiere Header basierend auf Login-Status
                  updateHeaderBasedOnLoginStatus();
                  // ✅ Aktualisiere Party-Info-Zeile
                  updatePartyInfoLine();
                  // ✅ Aktualisiere Branding-Zeile
                  updateBrandingLine();
                  
                  // ✅ Zeige Logout-Button (Party ist aktiv)
                  updateLogoutButtonVisibility();
                  if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
                  
                } catch (e) {
                  console.error('❌ Fehler bei Triple-Fetch:', e);
                }
              } else {
                if (window.IS_DEBUG) console.warn('⚠️ Kein created_by in Party-Daten gefunden');
              }
              
              await updateHeaderDjName(savedPartyId, partyDataForDj, createdByUid);
              if (window.IS_DEBUG) console.log('✅ DJ-Namen aus localStorage Party-ID geladen');
              // ✅ Aktualisiere Header-Branding nach DJ-Name Laden
              updateHeaderBranding();
              // ✅ Aktualisiere Branding-Zeile
              updateBrandingLine();
            } else {
              if (window.IS_DEBUG) console.warn('⚠️ Party-Dokument existiert nicht in Firebase für ID:', savedPartyId);
              if (vbHasAnyJoinFlowSignal()) {
                vbClearStaleValidatedPartyStorage();
              } else if (typeof clearPartyData === 'function') {
                clearPartyData();
                return;
              }
            }
          } catch (e) {
            console.error('❌ Fehler beim Laden der Party-Daten:', e);
            if (window.IS_DEBUG) console.warn('⚠️ Konnte Party-Daten für DJ-Namen nicht laden:', e);
          }
          }
          
          // Prüfe, ob die Party noch aktiv ist (Party-Doc aus erstem Lauf wiederverwenden)
          try {
            let partyDoc = vbStatusPartyDoc;
            let partyData = vbStatusPartyData;
            if (!partyDoc) {
              const partyRef = window.firebaseDoc(
                window.firebaseCollection(window.firebaseDb, 'parties'),
                savedPartyId
              );
              partyDoc = await window.firebaseGetDoc(partyRef);
              partyData = partyDoc.exists() ? partyDoc.data() : null;
            }
            if (partyDoc.exists()) {
              if (!partyData) partyData = partyDoc.data();
              const lifecycleEarly = partyData.lifecycle_status;
              const nowPosixEarly = Math.floor(Date.now() / 1000);
              const endPosixEarly = Number(partyData.end_time_posix || 0);
              if (lifecycleEarly === 'finished' || (Number.isFinite(endPosixEarly) && endPosixEarly > 0 && nowPosixEarly >= endPosixEarly)) {
                if (window.IS_DEBUG) console.log('⚠️ Party beendet (lifecycle/end_time_posix), Floor-Redirect oder Ausgang');
                if (typeof vbHandleGuestPartyEnded === 'function') {
                  void vbHandleGuestPartyEnded(partyData, partyDoc.id);
                } else if (typeof runGuestPartyEndedWishboxFlow === 'function') {
                  runGuestPartyEndedWishboxFlow();
                }
                return;
              }
              const startTimestamp = partyData.start_date;
              const endTimestamp = partyData.end_date;
              const partyCode = partyData.party_code;
              
              if (startTimestamp && endTimestamp) {
                const startDate = startTimestamp.toDate();
                const endDate = endTimestamp.toDate();
                const now = new Date();
                
                // Prüfe Pre-Party Status (Party startet in der Zukunft)
                if (now < startDate) {
                  if (typeof window.vbIsPreWishWindowOpen === 'function' && window.vbIsPreWishWindowOpen(partyData, now)) {
                    if (window.vbArePreWishesPaused && window.vbArePreWishesPaused(partyData)) {
                      if (skipBlock && isPreWishesPausedMode && currentPartyStartDate && currentPartyStartDate.getTime() === startDate.getTime()) {
                        if (window.IS_DEBUG) console.log('Poll: Vorab pausiert unverändert, kein UI-Reset');
                        return;
                      }
                      if (window.IS_DEBUG) console.log('⏸ Party in der Zukunft – Vorab-Wunschbox pausiert');
                      showPreWishesPausedMode(partyData.party_name || 'Party', startDate);
                    } else {
                    if (skipBlock && isPreWishMode && currentPartyStartDate && currentPartyStartDate.getTime() === startDate.getTime()) {
                      if (window.IS_DEBUG) console.log('Poll: Vorab-Wunschbox unverändert, kein UI-Reset');
                      return;
                    }
                    if (window.IS_DEBUG) console.log('📬 Party in der Zukunft – Vorab-Wunschbox aktiv');
                    showPreWishOrPausedMode(partyData, partyData.party_name || 'Party', startDate);
                    }
                  } else {
                  if (skipBlock) {
                    const preEl = document.getElementById('prePartyWaitMode');
                    if (preEl && preEl.style.display === 'block' && currentPartyStartDate && currentPartyStartDate.getTime() === startDate.getTime()) {
                      if (window.IS_DEBUG) console.log('Poll: Pre-Party unverändert, kein UI-Reset');
                      return;
                    }
                  }
                  if (window.IS_DEBUG) console.log('⏰ Party startet in der Zukunft, zeige Pre-Party Wartemodus');
                  currentPartyStartDate = startDate;
                  persistPartyStartDate(startDate);
                  showPrePartyWaitMode(partyData.party_name || 'Party', startDate);
                  }
                  // URL bereinigen
                  if (window.location.search.includes('code=')) {
                    window.history.replaceState({}, document.title, (typeof window.vbNormalizedWishboxPathname === 'function' ? window.vbNormalizedWishboxPathname() : window.location.pathname));
                    if (window.IS_DEBUG) console.log('🧹 URL bereinigt (Code entfernt)');
                  }
                  return;
                }
                
                // Party ist aktiv nur wenn: jetzt >= Start UND jetzt < Ende UND nicht beendet (lifecycle_status/finished_at)
                const lifecycleStatus = partyData.lifecycle_status || partyData.status;
                const finishedAt = partyData.finished_at;
                const isEnded = lifecycleStatus === 'finished' || finishedAt != null;
                if (!isEnded && now >= startDate && now < endDate) {
                  if (window.IS_DEBUG) console.log('✅ Party aus localStorage ist noch aktiv');
                  const wasWishboxInactive = !isWishboxActive;
                  isWishboxActive = true;
                  clearPreWishMode();
                  currentPartyStartDate = null;
                  stopPrePartyCountdown();
                  const partyCodeInput = document.getElementById('partyCodeInput');
                  if (partyCodeInput) {
                    partyCodeInput.value = partyCode || '';
                  }
                  if (!skipBlock || wasWishboxInactive) {
                    await updateHeaderDjName(partyDoc.id, partyData);
                    updateHeaderBranding();
                  }
                  const isPaused = partyData.is_paused === true;
                  togglePartyPausedOverlay(isPaused);
                  if (isPaused) {
                    if (typeof vbHideWishboxFormChrome === 'function') vbHideWishboxFormChrome();
                  } else if (!skipBlock || wasWishboxInactive) {
                    updateWishboxUI();
                  }
                  // URL bereinigen (falls Code noch drin steht) - NUR wenn nicht bereits von QR-Code-Login verarbeitet
                  if (window.location.search.includes('code=') && !sessionStorage.getItem('qrCodeProcessed')) {
                    window.history.replaceState({}, document.title, (typeof window.vbNormalizedWishboxPathname === 'function' ? window.vbNormalizedWishboxPathname() : window.location.pathname));
                    if (window.IS_DEBUG) console.log('🧹 URL bereinigt (Code entfernt)');
                  }
                  return;
                } else {
                  // Party ist beendet (Zeit abgelaufen oder manuell beendet) – sauberer Logout: alle Gast-Daten löschen
                  if (window.IS_DEBUG) console.log('⚠️ Party ist beendet, lösche alle Session-/Gast-Daten (sauberer Logout)');
                  currentPartyStartDate = null;
                  stopPrePartyCountdown();
                  clearGuestSessionBecausePartyEnded();
                }
              }
            } else {
              if (window.IS_DEBUG) console.warn('⚠️ Party-Dokument fehlt, Storage bereinigen');
              if (vbHasAnyJoinFlowSignal()) {
                vbClearStaleValidatedPartyStorage();
              } else if (typeof clearPartyData === 'function') {
                clearPartyData();
                return;
              }
            }
          } catch (e) {
            if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Prüfen der gespeicherten party_id:', e);
            // Weiter mit normaler Suche
          }
        }

        savedPartyIdLocal = localStorage.getItem('validatedPartyId');
        savedPartyIdSession = sessionStorage.getItem('validatedPartyId');
        var hasValidatedPartyIdAfterStaleClear =
          (savedPartyIdLocal && savedPartyIdLocal !== 'manual' && savedPartyIdLocal !== '') ||
          (savedPartyIdSession && savedPartyIdSession !== 'manual' && savedPartyIdSession !== '');

        // Party-Code aus URL lesen (Query oder Hash, nur wenn keine gültige party_id in localStorage)
        const urlParams = new URLSearchParams(window.location.search);
        let rawCode = typeof window.vbGetPartyCodeFromUrl === 'function' ? window.vbGetPartyCodeFromUrl() : urlParams.get('code');
        if (rawCode) console.log('DEBUG [Auto-Login]: Parameter gefunden (checkWishboxStatus):', rawCode);
        
        // ✅ STRICKTER URL-PARAMETER-SCHUTZ: Nur Zahlen, genau 8 Stellen
        if (rawCode) {
          let digits = rawCode.replace(/[^0-9]/g, '');
          if (digits.length > 8) digits = digits.substring(0, 8);
          const okLen = digits.length === 8;
          if (digits && okLen && /^\d+$/.test(digits)) {
            partyCodeFromUrl = digits;
            if (window.IS_DEBUG) console.log('✅ URL-Parameter validiert (nur Zahlen):', digits);
          } else {
            // Code enthält ungültige Zeichen - ignoriere Parameter
            if (window.IS_DEBUG) console.warn('⚠️ URL-Parameter enthält ungültige Zeichen, ignoriere:', rawCode);
            partyCodeFromUrl = null;
            // Bereinige URL sofort (ungültiger Parameter oder Join-Pfad)
            var cleanPath = (typeof window.vbNormalizedWishboxPathname === 'function') ? window.vbNormalizedWishboxPathname() : (window.location.pathname || '/');
            window.history.replaceState({}, document.title, cleanPath);
          }
        } else {
          partyCodeFromUrl = null;
        }
        
        // Prüfe auch, ob bereits ein Code im versteckten Feld gesetzt ist (von manueller Eingabe)
        const partyCodeInput = document.getElementById('partyCodeInput');
        if (partyCodeInput && !partyCodeInput._vbPendingBound) {
          partyCodeInput._vbPendingBound = true;
          partyCodeInput.addEventListener('input', function () {
            var d = (partyCodeInput.value || '').replace(/[^0-9]/g, '').substring(0, 8);
            if (d.length === 8) {
              try { localStorage.setItem('pending_party_code', d); } catch (e) {}
            }
          });
        }
        const existingCode = partyCodeInput ? partyCodeInput.value : null;
        
        // Prüfe sessionStorage für gespeicherten Code
        const savedCode = sessionStorage.getItem('validatedPartyCode');
        var savedPending = null;
        try { savedPending = localStorage.getItem('pending_party_code'); } catch (e) {}
        
        // Priorität: URL > verstecktes Feld > sessionStorage > pending (8 Ziffern, noch nicht bestätigt)
        const codeToCheck = partyCodeFromUrl || existingCode || savedCode || savedPending;
        
        // Wenn kein Code vorhanden ist, bleibt Wunschbox inaktiv
        // (auch mit manuellem Schalter benötigen wir einen Party-Code)
        if (!codeToCheck) {
          if (hasValidatedPartyIdAfterStaleClear) {
            if (window.IS_DEBUG) console.log('Kein Join-Code, aber validatedPartyId — überspringe Inaktiv-Fallback');
            return;
          }
          if (vbHasAnyJoinFlowSignal()) {
            if (window.IS_DEBUG) console.log('Kein Join-Code im Storage-Feld, Join-Signal aktiv — warte auf Auto-Login');
            return;
          }
          if (window.IS_DEBUG) console.log('Kein Party-Code vorhanden - Wunschbox bleibt inaktiv');
          isWishboxActive = false;
          updateWishboxUI(); // UI wird aktualisiert, Block-Status wurde bereits geprüft
          return;
        }
        
        try {
          const activated = await vbTryActivatePartyByJoinCode(codeToCheck, partyCodeFromUrl);
          if (activated) return;
        } catch (partiesError) {
          if (window.IS_DEBUG) console.log('DEBUG PWA: Join-Code-Lookup', partiesError);
        }

        // Keine aktive Party gefunden - prüfe jetzt den manuellen Schalter
        if (window.IS_DEBUG) console.log('Keine aktive Party gefunden, prüfe manuellen Schalter...');
        
        try {
          // Prüfe manuellen Schalter in party_settings/current
          const settingsRef = window.firebaseDoc(window.firebaseDb, 'party_settings', 'current');
          const settingsDoc = await window.firebaseGetDoc(settingsRef);
          
          if (settingsDoc.exists()) {
            const settingsData = settingsDoc.data();
            const manuallyEnabled = settingsData.wishbox_manually_enabled;
            if (window.IS_DEBUG) console.log('Manueller Schalter Wert:', manuallyEnabled);
            
            if (manuallyEnabled === true) {
              const djCode = settingsData.wishbox_activated_by_dj_code;
              if (window.IS_DEBUG) console.log('🔑 DJ-Code der den Schalter aktiviert hat:', djCode);
              
              if (djCode && codeToCheck) {
                // Prüfe, ob der Party-Code zu einer Party dieses DJs gehört
                if (window.IS_DEBUG) console.log('🔍 Prüfe ob Party-Code "' + codeToCheck + '" zu DJ "' + djCode + '" gehört...');
                
                try {
                  // Suche nach Party per 8-stelligem Code (party_code / fixed_party_code)
                  if (window.IS_DEBUG) console.log('🔍 Suche nach Party mit Code: ' + codeToCheck);
                  const partyDoc = await findPartyDocByJoinCode(codeToCheck);
                  if (window.IS_DEBUG) console.log('📊 Party-Dokument: ' + (partyDoc ? partyDoc.id : 'keins'));
                  
                  let partyBelongsToDj = false;
                  
                  if (partyDoc) {
                    const partyData = partyDoc.data();
                    const resolvedPartyCode = partyData.party_code != null ? String(partyData.party_code) : codeToCheck;
                    const partyCreatedBy = partyData.created_by;
                    
                    if (window.IS_DEBUG) console.log('📋 Party gefunden mit Code "' + codeToCheck + '" (Party-ID: ' + partyDoc.id + ')');
                    if (window.IS_DEBUG) console.log('   Party created_by:', partyCreatedBy);
                    if (window.IS_DEBUG) console.log('   DJ-Code (Schalter):', djCode);
                    
                    // Vergleich: Normalisiere Strings (trim) für exakten Vergleich
                    const normalizedPartyCreatedBy = partyCreatedBy ? String(partyCreatedBy).trim() : '';
                    const normalizedDjCode = djCode ? String(djCode).trim() : '';
                    
                    if (window.IS_DEBUG) console.log('🔍 Vergleich:');
                    if (window.IS_DEBUG) console.log('   Normalisiertes created_by: "' + normalizedPartyCreatedBy + '"');
                    if (window.IS_DEBUG) console.log('   Normalisiertes DJ-Code: "' + normalizedDjCode + '"');
                    if (window.IS_DEBUG) console.log('   Länge created_by: ' + normalizedPartyCreatedBy.length);
                    if (window.IS_DEBUG) console.log('   Länge DJ-Code: ' + normalizedDjCode.length);
                    if (window.IS_DEBUG) console.log('   Identisch? ' + (normalizedPartyCreatedBy === normalizedDjCode));
                    
                    if (normalizedPartyCreatedBy === normalizedDjCode && normalizedPartyCreatedBy.length > 0) {
                      partyBelongsToDj = true;
                      if (window.IS_DEBUG) console.log('✅ Party gehört zu diesem DJ (via created_by)! Wunschbox wird aktiviert.');
                    } else {
                      // Fallback: Prüfe party_status Tabelle (wenn created_by nicht übereinstimmt oder fehlt)
                      if (window.IS_DEBUG) console.log('⚠️ Party created_by passt nicht oder fehlt, prüfe party_status als Fallback...');
                      try {
                        const partyStatusRef = window.firebaseCollection(window.firebaseDb, 'party_status');
                        const partyStatusQuery = window.firebaseQuery(
                          partyStatusRef,
                          window.firebaseWhere('party_code', '==', resolvedPartyCode)
                        );
                        const partyStatusSnapshot = await window.firebaseGetDocs(partyStatusQuery);
                        
                        if (partyStatusSnapshot.docs.length > 0) {
                          const statusData = partyStatusSnapshot.docs[0].data();
                          const statusDjCode = statusData.dj_code;
                          const normalizedStatusDjCode = statusDjCode ? String(statusDjCode).trim() : '';
                          
                          if (window.IS_DEBUG) console.log('   Party-Status dj_code (roh):', statusDjCode);
                          if (window.IS_DEBUG) console.log('   Party-Status dj_code (normalisiert): "' + normalizedStatusDjCode + '"');
                          if (window.IS_DEBUG) console.log('   Vergleich Status-DJ-Code mit Schalter-DJ-Code: ' + (normalizedStatusDjCode === normalizedDjCode));
                          
                          if (normalizedStatusDjCode === normalizedDjCode && normalizedStatusDjCode.length > 0) {
                            partyBelongsToDj = true;
                            if (window.IS_DEBUG) console.log('✅ Party gehört zu diesem DJ (via party_status)! Wunschbox wird aktiviert.');
                          } else {
                            if (window.IS_DEBUG) console.log('❌ Party gehört NICHT zu diesem DJ (auch nicht via party_status).');
                            if (window.IS_DEBUG) console.log('   Erwartet: "' + normalizedDjCode + '"');
                            if (window.IS_DEBUG) console.log('   Gefunden (party_status): "' + normalizedStatusDjCode + '"');
                          }
                        } else {
                          if (window.IS_DEBUG) console.log('❌ Kein party_status Eintrag gefunden für Party-Code: ' + codeToCheck);
                        }
                      } catch (statusError) {
                        console.error('❌ Fehler beim Prüfen von party_status:', statusError);
                      }
                      
                      if (!partyBelongsToDj) {
                        if (window.IS_DEBUG) console.log('❌ Party gehört NICHT zu diesem DJ.');
                        if (window.IS_DEBUG) console.log('   Party created_by: "' + normalizedPartyCreatedBy + '"');
                        if (window.IS_DEBUG) console.log('   Erwarteter DJ-Code: "' + normalizedDjCode + '"');
                      }
                    }
                  
                    if (partyBelongsToDj) {
                      if (window.IS_DEBUG) console.log('✅ Wunschbox ist manuell aktiviert für diesen Party-Code!');
                      isWishboxActive = true;
                      // Setze Party-Code im versteckten Feld
                      if (partyCodeInput) {
                        partyCodeInput.value = resolvedPartyCode;
                      }
                      sessionStorage.setItem('validatedPartyCode', resolvedPartyCode);
                      localStorage.setItem('validatedPartyCode', resolvedPartyCode);
                      try { localStorage.removeItem('pending_party_code'); } catch (e) {}
                      localStorage.setItem('validatedPartyId', partyDoc.id);
                      sessionStorage.setItem('validatedPartyId', partyDoc.id);
                      if (window.IS_DEBUG) console.log('💾 party_id gespeichert in localStorage:', partyDoc.id);
                      if (window.IS_DEBUG) console.log('💾 party_id gespeichert in sessionStorage:', partyDoc.id);
                      const partyName = partyData.party_name || null;
                      if (partyName && partyName.trim() !== '') {
                        sessionStorage.setItem('validatedPartyName', partyName.trim());
                        localStorage.setItem('validatedPartyName', partyName.trim());
                        sessionStorage.setItem('currentPartyName', partyName.trim());
                        localStorage.setItem('currentPartyName', partyName.trim());
                        if (window.IS_DEBUG) console.log('💾 party_name gespeichert in sessionStorage:', partyName.trim());
                        if (window.IS_DEBUG) console.log('💾 party_name gespeichert in localStorage:', partyName.trim());
                      } else {
                        if (window.IS_DEBUG) console.warn('⚠️ Kein partyName in Firestore gefunden für Party-ID:', partyDoc.id);
                      }
                      const isPaused = partyData.is_paused === true;
                      togglePartyPausedOverlay(isPaused);
                      await updateHeaderDjName(partyDoc.id, partyData);
                      updateHeaderBranding();
                      updatePartyInfoLine();
                      vbBindWishboxFromPartyData(partyData);
                      if (partyCodeFromUrl) {
                        window.history.replaceState({}, document.title, (typeof window.vbNormalizedWishboxPathname === 'function' ? window.vbNormalizedWishboxPathname() : window.location.pathname));
                        if (window.IS_DEBUG) console.log('🧹 URL bereinigt (Code entfernt)');
                      }
                      updateWishboxUI();
                      return;
                    }
                  } else {
                    if (window.IS_DEBUG) console.log('❌ Keine Party mit Code "' + codeToCheck + '" gefunden.');
                  }
                  
                  if (!partyBelongsToDj) {
                    if (window.IS_DEBUG) console.log('❌ Party-Code gehört nicht zu diesem DJ - Wunschbox bleibt inaktiv');
                    isWishboxActive = false;
                    updateHeaderDjName(null, null);
                    sessionStorage.removeItem('currentDjName');
                    updateWishboxUI();
                    return;
                  }
                } catch (partyCheckError) {
                  if (window.IS_DEBUG) console.log('DEBUG PWA: Fehler Party-Zugehörigkeit', partyCheckError);
                  isWishboxActive = false;
                  updateWishboxUI();
                  return;
                }
              } else if (!codeToCheck) {
                if (window.IS_DEBUG) console.log('❌ Kein Party-Code vorhanden - Wunschbox bleibt inaktiv');
                isWishboxActive = false;
                updateWishboxUI();
                return;
              } else {
                if (window.IS_DEBUG) console.log('⚠️ Kein DJ-Code gespeichert - Wunschbox bleibt inaktiv');
                isWishboxActive = false;
                updateWishboxUI();
                return;
              }
            } else {
              if (window.IS_DEBUG) console.log('Manueller Schalter ist nicht aktiviert');
            }
          } else {
            if (window.IS_DEBUG) console.log('party_settings/current existiert nicht');
          }
        } catch (settingsError) {
          if (window.IS_DEBUG) console.log('DEBUG PWA: Fehler beim Laden der Settings', settingsError);
        }
        
        // Keine Übereinstimmung gefunden und manueller Schalter nicht aktiv
        if (window.IS_DEBUG) console.log('Keine laufende Party und manueller Schalter nicht aktiv - Wunschbox bleibt inaktiv');
        // Entferne ungültigen Code aus sessionStorage
        sessionStorage.removeItem('validatedPartyCode');
        isWishboxActive = false;
        // ✅ Verstecke DJ-Namen im Header und lösche sessionStorage
        updateHeaderDjName(null, null);
        sessionStorage.removeItem('currentDjName');
        updateWishboxUI();
      } catch (error) {
        if (window.IS_DEBUG) console.log('DEBUG PWA: checkWishboxStatus Fehler', error && error.toString());
        window.bodyLoadError = true;
        try {
          if (typeof updateWishboxUI === 'function') updateWishboxUI();
        } catch (uiErr) {
          var errEl = document.getElementById('bodyLoadError');
          if (errEl) { errEl.style.display = 'block'; }
        }
        try {
          const settingsRef = window.firebaseDoc(window.firebaseDb, 'party_settings', 'current');
          const settingsDoc = await window.firebaseGetDoc(settingsRef);
          if (settingsDoc.exists()) {
            const settingsData = settingsDoc.data();
            if (settingsData.wishbox_manually_enabled === true) {
              // Auch im Fallback: Prüfe DJ-Zugehörigkeit
              const djCode = settingsData.wishbox_activated_by_dj_code;
              const codeToCheck = partyCodeFromUrl || existingCode || savedCode;
              
              if (djCode && codeToCheck) {
                try {
                  const partyDocFb = await findPartyDocByJoinCode(codeToCheck);
                  if (partyDocFb) {
                    const partyData = partyDocFb.data();
                    const resolvedPC = partyData.party_code != null ? String(partyData.party_code) : codeToCheck;
                    const partyCreatedBy = partyData.created_by;
                    
                    if (partyCreatedBy === djCode) {
                      if (window.IS_DEBUG) console.log('DEBUG PWA: Wunschbox manuell aktiviert (Fallback)');
                      window.bodyLoadError = false;
                      isWishboxActive = true;
                      updateWishboxUI();
                      return;
                    } else if (!partyCreatedBy) {
                      // Fallback auf party_status
                      const partyStatusRef = window.firebaseCollection(window.firebaseDb, 'party_status');
                      const partyStatusQuery = window.firebaseQuery(
                        partyStatusRef,
                        window.firebaseWhere('party_code', '==', resolvedPC)
                      );
                      const partyStatusSnapshot = await window.firebaseGetDocs(partyStatusQuery);
                      
                      if (partyStatusSnapshot.docs.length > 0) {
                        const statusData = partyStatusSnapshot.docs[0].data();
                        if (statusData.dj_code === djCode) {
                          if (window.IS_DEBUG) console.log('DEBUG PWA: Wunschbox manuell aktiviert (Fallback party_status)');
                          window.bodyLoadError = false;
                          isWishboxActive = true;
                          updateWishboxUI();
                          return;
                        }
                      }
                    }
                  }
                } catch (e) {
                  if (window.IS_DEBUG) console.log('DEBUG PWA: Fallback-Prüfung Fehler', e);
                }
              }
              
              if (window.IS_DEBUG) console.log('❌ Fallback: Wunschbox bleibt inaktiv (kein passender Party-Code für DJ)');
              isWishboxActive = false;
              updateWishboxUI();
              return;
            }
          }
        } catch (fallbackError) {
          if (window.IS_DEBUG) console.log('DEBUG PWA: Fallback-Check fehlgeschlagen', fallbackError);
        }
        isWishboxActive = false;
        if (typeof updateWishboxUI === 'function') updateWishboxUI();
      }
    }

    // Prüfe manuell eingegebenen Party-Code
    // Zeit-/Countdown-Logik: party_shared.js (formatPartyLocalTime, formatPartyStartAtLine, formatLocaleCompactDateTime, …)

    /** Storage leeren ohne UI-Flash – danach Redirect zur Startseite. */
    function vbClearGuestJoinStorageForHomeRedirect() {
      try {
        localStorage.removeItem('validatedPartyId');
        localStorage.removeItem('validatedPartyCode');
        localStorage.removeItem('validatedPartyName');
        localStorage.removeItem('currentPartyName');
        localStorage.removeItem('pending_party_code');
        localStorage.removeItem('pendingPartyId');
        localStorage.removeItem('guest_client_id');
        localStorage.removeItem('validatedPartyStartMs');
        localStorage.removeItem('validatedPartyDjId');
        localStorage.removeItem('vb_party_floor_key');
      } catch (eLs) {}
      if (typeof clearSessionPartyData === 'function') {
        try { clearSessionPartyData(); } catch (eSs) {}
      }
    }

    /** Party noch nicht gestartet / beendet: Hinweis auf der Startseite zeigen, nicht in der leeren Wunschbox. */
    function vbRedirectHomeWithPartyStatusNotice(type, message, timeInfo) {
      window.__vbLeavingForHomeNotice = true;
      var html = message || '';
      if (timeInfo && type === 'future' && html.indexOf(timeInfo) === -1) {
        var startInText = (typeof t === 'function') ? t('party_start_in', 'Starts in:') : 'Starts in:';
        html += '<br><br><strong>' + startInText + ' ' + (typeof escapeHtml === 'function' ? escapeHtml(String(timeInfo)) : String(timeInfo)) + '</strong>';
      }
      var payload = JSON.stringify({ type: String(type || ''), html: html });
      vbClearGuestJoinStorageForHomeRedirect();
      try { sessionStorage.setItem('vb_party_status_notice', payload); } catch (eN) {}
      window.location.replace('/');
    }
    
    // ✅ Funktion zum Anzeigen des Party-Status-Modals (Drei-Farben-System)
    function showPartyStatusModal(type, message, timeInfo = null) {
      if (type === 'future' || type === 'ended') {
        vbRedirectHomeWithPartyStatusNotice(type, message, timeInfo);
        return;
      }

      // Entferne vorhandenes Modal falls vorhanden
      const existingModal = document.getElementById('partyCodeErrorModalOverlay');
      if (existingModal) {
        existingModal.remove();
      }
      
      // Erstelle Modal-Overlay
      const overlay = document.createElement('div');
      overlay.className = 'party-code-error-modal-overlay';
      overlay.id = 'partyCodeErrorModalOverlay';
      
      // Erstelle Modal-Content mit entsprechender Rahmenfarbe
      const modal = document.createElement('div');
      let modalClass = 'party-code-error-modal-content';
      let iconClass = 'fas fa-info-circle';
      
      if (type === 'invalid' || type === 'ended') {
        // Roter Rahmen für ungültig/beendet
        modalClass += ' error-red';
        iconClass = 'fas fa-exclamation-circle icon-red';
      } else if (type === 'future') {
        // Grüner Rahmen für Zukunft
        modalClass += ' info-green';
        iconClass = 'fas fa-clock icon-green';
      }
      
      modal.className = modalClass;
      
      // Erstelle Nachricht mit optionaler Zeit-Info
      let fullMessage = message;
      if (timeInfo && type === 'future') {
        const startInText = t('party_start_in', 'Starts in:');
        // Zeitinfo wird bereits in der message enthalten sein (mit Ortszeit)
        // Füge nur den Countdown hinzu, falls nicht bereits enthalten
        if (!fullMessage.includes(timeInfo)) {
          fullMessage += '<br><br><strong>' + escapeHtml(startInText) + ' ' + escapeHtml(timeInfo) + '</strong>';
        }
      }
      
      modal.innerHTML = `
        <div class="party-code-error-modal-icon">
          <i class="${iconClass}"></i>
        </div>
        <p class="party-code-error-modal-message">${typeof escapeHtml === 'function' ? escapeHtml(fullMessage) : fullMessage}</p>
        <button class="party-code-error-modal-button" id="partyCodeErrorModalOkBtn">
          ${t('button_ok', 'OK')}
        </button>
      `;
      
      overlay.appendChild(modal);
      document.body.appendChild(overlay);
      
      function closePartyStatusModal() {
        overlay.remove();
      }

      // Event-Handler für OK-Button, Backdrop und Esc
      const okBtn = document.getElementById('partyCodeErrorModalOkBtn');
      okBtn.addEventListener('click', closePartyStatusModal);
      overlay.addEventListener('click', (e) => { if (e.target === overlay) closePartyStatusModal(); });
      function onStatusModalEsc(e) {
        if (e.key === 'Escape') {
          document.removeEventListener('keydown', onStatusModalEsc);
          closePartyStatusModal();
        }
      }
      document.addEventListener('keydown', onStatusModalEsc);
    }

    // Lädt und aktualisiert die Wunsch-Limit-Anzeige
    async function updateWishLimitInfo() {
      try {
        const limitInfoDiv = document.getElementById('wishLimitInfo');
        const limitText = document.getElementById('wishLimitText');
        
        if (!limitInfoDiv || !limitText) return;
        
        // Nur anzeigen, wenn Wunschbox aktiv ist
        if (!isWishboxActive) {
          limitInfoDiv.style.display = 'none';
          return;
        }
        
        // Zeige die Info-Box sofort an (auch während des Ladens)
        limitInfoDiv.style.display = 'block';
        
        // ✅ Sofort Lade-Text anzeigen (lokalisiert)
        limitText.textContent = (t('wish_limit_loading', 'Loading limit information...'));
        
        const partyCodeInput = document.getElementById('partyCodeInput');
        const partyCode = partyCodeInput ? (partyCodeInput.value || 'manual') : 'manual';
        
        // Wenn kein Party-Code vorhanden ist, verstecke die Info
        if (!partyCode || partyCode === 'manual') {
          // Versuche trotzdem Default-Werte anzuzeigen, wenn Box aktiv ist
          limitText.textContent = (t('wish_limit_default', '2 of 2 requests still possible this hour'));
          limitInfoDiv.style.display = 'block';
          return;
        }
        
        const partyInfo = await getActivePartyInfo(partyCode);
        const partyId = partyInfo.party_id;
        
        // Auch wenn partyId 'manual' ist, aber ein Party-Code vorhanden ist, 
        // versuche die Party zu finden (z.B. bei beendeten Partys mit manuellem Schalter)
        let finalPartyId = partyId;
        if (partyId === 'manual' && partyCode && partyCode !== 'manual') {
          try {
            const docLm = await findPartyDocByJoinCode(partyCode);
            if (docLm) {
              finalPartyId = docLm.id;
              if (window.IS_DEBUG) console.log('✅ Party gefunden für Limit-Info: ' + finalPartyId);
            }
          } catch (e) {
            console.error('Fehler beim Suchen der Party für Limit-Info:', e);
          }
        }
        
        if (finalPartyId === 'manual') {
          // Fallback: Zeige Default-Werte an
          limitText.textContent = (t('wish_limit_default', '2 of 2 requests still possible this hour'));
          limitInfoDiv.style.display = 'block';
          return;
        }
        
        // ✅ Lade aktuelle Limit-Informationen direkt aus wishes Collection
        const limitInfo = await checkWishLimit(finalPartyId);
        
        if (limitInfo.allowed) {
          // Zeige verbleibende Wünsche
          const remaining = limitInfo.remaining || 0;
          const limit = limitInfo.limit || 2;
          const limitTextTemplate = (t('wish_limit_remaining', '{remaining} of {limit} requests still possible this hour'));
          limitText.textContent = limitTextTemplate.replace('{remaining}', remaining).replace('{limit}', limit);
          // ✅ Keine Hintergrundfarbe mehr - dezent transparent
          
          // ✅ Button aktivieren, wenn Limit nicht erreicht
          const submitBtn = document.getElementById('submitBtn');
          if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
          }
        } else {
          // Limit erreicht
          const limitReachedText = t('limit_already_used', 'You have already submitted ' + (limitInfo.limit || 2) + ' wishes this full hour.').replace(/\{limit\}/g, String(limitInfo.limit || 2));
          limitText.textContent = limitInfo.message || limitReachedText;
          // ✅ Keine Hintergrundfarbe mehr - dezent transparent
          
          // ✅ Button deaktivieren bei Limit-Erreichung
          const submitBtn = document.getElementById('submitBtn');
          if (submitBtn) {
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<span>🚫</span><span>' + (t('wish_limit_reached', 'Limit reached')) + '</span>';
          }
        }
        limitInfoDiv.style.display = 'block';
      } catch (e) {
        console.error('Fehler beim Laden der Limit-Informationen:', e);
        const limitInfoDiv = document.getElementById('wishLimitInfo');
        if (limitInfoDiv) {
          limitInfoDiv.style.display = 'none';
        }
      }
    }
    
    // ✅ Setzt nur die Limit-Anzeige und den Button-Status (kein Flackern, synchrone UI-Aktualisierung)
    function applyWishLimitToUI(remaining, limit, allowed) {
      const limitInfoDiv = document.getElementById('wishLimitInfo');
      const limitText = document.getElementById('wishLimitText');
      const submitBtn = document.getElementById('submitBtn');
      if (!limitInfoDiv || !limitText) return;
      if (!isWishboxActive || isBlocked || isPreWishesPausedMode
          || (typeof vbIsFloorPickerActive === 'function' && vbIsFloorPickerActive())
          || (typeof vbIsGuestWishboxFormSuppressed === 'function' && vbIsGuestWishboxFormSuppressed())) {
        limitInfoDiv.style.display = 'none';
        if (submitBtn) submitBtn.disabled = true;
        return;
      }
      limitInfoDiv.style.display = 'block';
      if (allowed) {
        // Fall A: Mehrere frei – "X von X Wünschen frei je voller Stunde"
        if (remaining > 1) {
          const tpl = (t('wish_limit_plural', '{remaining} of {limit} wishes free per full hour'));
          limitText.textContent = tpl.replace('{remaining}', remaining).replace('{limit}', limit);
        } else {
          // Fall B: Genau einer frei – "1 von {limit} Wunsch frei je voller Stunde" (l10n)
          var tpl = (t('wish_limit_singular', '1 of {limit} wish free per full hour'));
          limitText.textContent = tpl.replace('{limit}', String(limit));
        }
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
        }
      } else {
        // Fall C: Keiner mehr frei – "Ein weiterer Wunsch ist zur nächsten vollen Stunde möglich."
        limitText.textContent = (t('wish_limit_none', 'Another wish is possible at the next full hour.'));
        if (submitBtn) {
          submitBtn.disabled = true;
          submitBtn.innerHTML = '<span>🚫</span><span>' + (t('wish_limit_reached', 'Limit reached')) + '</span>';
        }
      }
    }
    
    // ✅ Realtime-Stream: onSnapshot auf Party-Dokument (guest_limit_per_hour) + Wünsche – Live-Aktualisierung flackerfrei
    function subscribeWishLimitStream(partyId) {
      if (wishLimitUnsubscribe) {
        wishLimitUnsubscribe();
        wishLimitUnsubscribe = null;
      }
      if (!partyId || partyId === 'manual') return;
      const limitInfoDiv = document.getElementById('wishLimitInfo');
      const limitText = document.getElementById('wishLimitText');
      if (limitInfoDiv && limitText) {
        limitInfoDiv.style.display = 'block';
        limitText.textContent = (t('wish_limit_loading', 'Loading limit information...'));
      }
      (async function startStream() {
        try {
          const cid = await getOrCreateClientId(partyId);
          const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId);
          const wishesRef = window.vbPartyWishesCollection(partyId);
          const q = window.firebaseQuery(
            wishesRef,
            window.firebaseWhere('client_id', '==', cid)
          );
          var guestLimit = 2;
          var wishCount = 0;
          function flush() {
            if (!isWishboxActive) return;
            window.__vbStreamGuestLimit = guestLimit;
            window.__vbStreamWishCount = wishCount;
            if (!window.currentWishStats) window.currentWishStats = {};
            window.currentWishStats.limit = guestLimit;
            window.currentWishStats.current = wishCount;
            window.currentWishStats.remaining = Math.max(0, guestLimit - wishCount);
            var remaining = Math.max(0, guestLimit - wishCount);
            applyWishLimitToUI(remaining, guestLimit, remaining > 0);
          }
          var unsubParty = window.firebaseOnSnapshot(partyRef, function(snap) {
            if (!isWishboxActive) return;
            if (snap.exists()) {
              const partyData = snap.data();
              guestLimit = (partyData.guest_limit_per_hour || 2);
              
              // ✅ PRIORITÄT 1: Prüfe Party-Ende ZUERST (vor Pause)
              const partyStatus = partyData.status || partyData.lifecycle_status || 'active';
              const endTimestamp = partyData.end_date || partyData.endTimePosix;
              const now = new Date();
              
              // Prüfe auf Party-Ende: status oder Zeitstempel
              let isFinished = false;
              if (partyStatus === 'beendet' || partyStatus === 'ended' || partyStatus === 'finished') {
                isFinished = true;
              } else if (endTimestamp) {
                // Prüfe end_date (Firestore Timestamp) oder endTimePosix (Unix)
                let endDate = null;
                if (endTimestamp.toDate) {
                  // Firestore Timestamp
                  endDate = endTimestamp.toDate();
                } else if (typeof endTimestamp === 'number') {
                  // Unix Timestamp (Sekunden)
                  endDate = new Date(endTimestamp * 1000);
                }
                if (endDate && now > endDate) {
                  isFinished = true;
                }
              }
              
              // ✅ Wenn Party beendet: Sofortiger Logout (ohne Verzögerung)
              if (isFinished) {
                if (window.IS_DEBUG) console.log('🔴 Party beendet erkannt – Overlay „Wunschbox beendet“, dann Ausgang');
                togglePartyPausedOverlay(false);
                if (typeof unsubParty === 'function') unsubParty();
                if (typeof unsubWishes === 'function') unsubWishes();
                if (wishLimitUnsubscribe) {
                  wishLimitUnsubscribe();
                  wishLimitUnsubscribe = null;
                }
                if (typeof vbHandleGuestPartyEnded === 'function') {
                  void vbHandleGuestPartyEnded(partyData, partyId);
                } else if (typeof runGuestPartyEndedWishboxFlow === 'function') {
                  runGuestPartyEndedWishboxFlow();
                } else if (typeof runGuestPartyEndedWishboxFlow === 'function') {
                  runGuestPartyEndedWishboxFlow();
                } else if (typeof clearPartyData === 'function') {
                  clearPartyData(true);
                }
                return;
              }
              
              // ✅ PRIORITÄT 2: Pause-Logik (nur wenn Party noch aktiv ist)
              const isPaused = partyData.is_paused === true;
              togglePartyPausedOverlay(isPaused);
            }
            flush();
          }, function(err) {
            if (window.IS_DEBUG) console.warn('Wish-Limit Party-Stream Fehler:', err);
            if (limitText) limitText.textContent = (t('wish_limit_default', '2 of 2 requests still possible this hour'));
          });
          var unsubWishes = window.firebaseOnSnapshot(q, function(snapshot) {
            if (!isWishboxActive) return;
            var now = new Date();
            var currentFullHour = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), now.getUTCHours()));
            var currentFullHourMs = currentFullHour.getTime();
            wishCount = 0;
            snapshot.forEach(function(doc) {
              var d = doc.data();
              if (!vbWishCountsTowardGuestHourlyLimit(d)) return;
              if (!d.createdAt) return;
              var ms = d.createdAt.toMillis ? d.createdAt.toMillis() : (d.createdAt.seconds * 1000);
              if (ms >= currentFullHourMs) wishCount++;
            });
            flush();
          }, function(err) {
            if (window.IS_DEBUG) console.warn('Wish-Limit Wünsche-Stream Fehler:', err);
            if (limitText) limitText.textContent = (t('wish_limit_default', '2 of 2 requests still possible this hour'));
          });
          wishLimitUnsubscribe = function() {
            if (typeof unsubParty === 'function') unsubParty();
            if (typeof unsubWishes === 'function') unsubWishes();
          };
        } catch (e) {
          if (window.IS_DEBUG) console.warn('subscribeWishLimitStream:', e);
          if (limitText) limitText.textContent = (t('wish_limit_default', '2 of 2 requests still possible this hour'));
        }
      })();
    }
    
    function stopWishLimitStream() {
      if (wishLimitUnsubscribe) {
        wishLimitUnsubscribe();
        wishLimitUnsubscribe = null;
      }
      // ✅ Overlay ausblenden, wenn Stream gestoppt wird
      togglePartyPausedOverlay(false);
    }
    
    // ✅ Einfache Pause-Funktion - nur Inline-Anzeige im Content-Bereich
    function togglePartyPausedOverlay(show) {
      if (togglePartyPausedOverlay._lastPaused === show) {
        return;
      }
      const overlay = document.getElementById('partyPausedOverlay');
      const wishForm = document.getElementById('wishForm');
      const brandingLine = document.getElementById('brandingLine');
      const limitInfoDiv = document.getElementById('wishLimitInfo');
      
      if (!overlay) return;
      togglePartyPausedOverlay._lastPaused = show;
      
      if (show) {
        // Overlay einblenden und Wunschbox-Inhalt ausblenden
        overlay.style.display = 'flex';
        
        // Formular und Branding ausblenden
        if (wishForm) wishForm.style.display = 'none';
        if (brandingLine) brandingLine.style.display = 'none';
        if (limitInfoDiv) limitInfoDiv.style.display = 'none';
        
        // Übersetzung aktualisieren
        const pausedText = document.getElementById('partyPausedText');
        if (pausedText) {
          pausedText.textContent = t('party_paused_msg', 'Brief program break: Vibesbox will be back soon for your music requests!');
        }
      } else {
        // Overlay ausblenden und Wunschbox-Inhalt wieder einblenden
        overlay.style.display = 'none';
        
        // Formular und Branding wieder einblenden (falls Wunschbox aktiv ist und kein Erfolgsfenster offen)
        if (isWishboxActive && !window.isSuccessActive
            && !(typeof vbIsGuestWishboxFormSuppressed === 'function' && vbIsGuestWishboxFormSuppressed())) {
          // Sichtbarkeit wie updateWishboxUI (isWishboxActive): #wishForm hat initial visibility:hidden;
          // wenn der erste Lauf bei aktiver Pause früh zurückkam, blieb visibility hidden → nach Ende der Pause nur „schwarze“ Karte.
          if (wishForm) {
            wishForm.style.display = 'block';
            wishForm.style.visibility = 'visible';
          }
          if (brandingLine && typeof updateBrandingLine === 'function') {
            updateBrandingLine();
          }
          if (limitInfoDiv) limitInfoDiv.style.display = 'block';
        }
      }
    }
    
    // Lädt Wunsch-Statistiken (Limit und bereits abgegebene Wünsche)
    // Zählt nur Wünsche seit der letzten vollen Stunde
    async function loadWishStats(partyId) {
      try {
        // Prüfe zuerst, ob partyId gültig ist
        if (!partyId || partyId === 'manual') {
          if (window.IS_DEBUG) console.log('⚠️ loadWishStats: Keine gültige Party-ID, verwende Default-Werte');
          return {
            limit: 2,
            current: 0,
            remaining: 2,
            nextFullHour: new Date()
          };
        }
        
        const isGuest = true; // PWA hat keine Authentifizierung, alle sind Gäste
        
        // Lade Limits aus der Party (mit Fallback auf Defaults)
        let guestLimit = 2; // Standard: 2 Wünsche pro Stunde für Gäste
        let userLimit = 5; // Standard: 5 Wünsche pro Stunde für eingeloggte User
        
        try {
          const partyDoc = await window.firebaseGetDoc(
            window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId)
          );
          
          if (partyDoc.exists()) {
            const data = partyDoc.data();
            guestLimit = data.guest_limit_per_hour || 2;
            userLimit = data.user_limit_per_hour || 5;
          }
        } catch (e) {
          console.error('⚠️ Fehler beim Laden der Limits aus Party:', e);
          // Verwende Default-Werte bei Fehler
        }
        
        const limit = isGuest ? guestLimit : userLimit;
        
        // Berechne die aktuelle volle Stunde (Minuten, Sekunden, Millisekunden auf 0 setzen)
        const now = new Date();
        const currentFullHour = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours());
        const nextFullHour = new Date(currentFullHour.getTime() + 60 * 60 * 1000);
        
        // Für Gäste: Verwende clientId und guestStats
        const clientId = await getOrCreateClientId(partyId);
        if (window.IS_DEBUG) console.log('🔑 updateWishLimitInfo: Verwende clientId:', clientId);

        // Lade guestStats für diese Party und clientId
        if (!partyId || partyId === 'manual') {
          if (window.IS_DEBUG) console.log('⚠️ Keine gültige Party-ID für guestStats, verwende Default-Werte');
          const limitInfoDiv = document.getElementById('wishLimitInfo');
          const limitText = document.getElementById('wishLimitText');
          if (limitText) {
            limitText.textContent = (t('wish_limit_default', '2 of 2 requests still possible this hour'));
          }
          return {
            limit: 2,
            current: 0,
            remaining: 2,
            nextFullHour: new Date()
          };
        }
        
        const guestStatsRef = window.firebaseDoc(
          window.firebaseCollection(
            window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId),
            'guestStats'
          ),
          clientId
        );

        const guestStatsDoc = await window.firebaseGetDoc(guestStatsRef);

        let currentCount = 0;
        if (guestStatsDoc.exists()) {
          const statsData = guestStatsDoc.data();
          const wishes = statsData.wishes || [];
          if (window.IS_DEBUG) console.log('📊 loadWishStats: Gefundene Wünsche insgesamt:', wishes.length);

          // Filtere Wünsche seit der aktuellen vollen Stunde (ohne Vorab)
          currentCount = wishes.filter(wish => {
            if (wish && wish.is_pre_wish === true) return false;
            if (wish && wish.timestamp) {
              const wishTime = wish.timestamp.toDate();
              const isInCurrentHour = wishTime >= currentFullHour && wishTime < nextFullHour;
              if (isInCurrentHour) {
                if (window.IS_DEBUG) console.log('📊 Wunsch in aktueller Stunde gefunden:', wishTime, '(zwischen', currentFullHour, 'und', nextFullHour, ')');
              }
              return isInCurrentHour;
            }
            return false;
          }).length;
          if (window.IS_DEBUG) console.log('📊 loadWishStats: Aktuelle Anzahl Wünsche in dieser vollen Stunde:', currentCount);
        } else {
          if (window.IS_DEBUG) console.log('📊 loadWishStats: Keine guestStats gefunden für clientId:', clientId, '- verwende 0 als aktuellen Count');
          currentCount = 0; // Explizit auf 0 setzen (ist bereits initialisiert, aber für Klarheit)
        }
        
        const remaining = Math.max(0, limit - currentCount);
        
        const stats = {
          limit: limit,
          current: currentCount,
          remaining: remaining,
          nextFullHour: nextFullHour
        };
        
        // Speichere Stats global für optimistische Updates
        window.currentWishStats = stats;
        
        return stats;
      } catch (e) {
        console.error('❌ Fehler beim Laden der Wunsch-Statistiken:', e);
        // Bei Fehler (z.B. Permission-Denied) verwende Default-Werte
        const now = new Date();
        const nextFullHour = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours() + 1);
        
        // Versuche nicht nochmal, wenn es ein Permission-Fehler ist
        if (e.code === 'permission-denied') {
          if (window.IS_DEBUG) console.warn('⚠️ Permission-Denied: Zeige Default-Werte ohne Statistiken');
          return {
            limit: 2,
            current: 0,
            remaining: 2,
            nextFullHour: nextFullHour
          };
        }
        return {
          limit: 2,
          current: 0,
          remaining: 2,
          nextFullHour: nextFullHour
        };
      }
    }

    function hidePreWishBanner() {
      const banner = document.getElementById('preWishBanner');
      if (banner) banner.style.display = 'none';
    }

    function hidePreWishesPausedNotice() {
      isPreWishesPausedMode = false;
      const notice = document.getElementById('preWishesPausedNotice');
      if (notice) notice.style.display = 'none';
    }

    function showPreWishesPausedNotice() {
      hidePreWishBanner();
      const notice = document.getElementById('preWishesPausedNotice');
      const noticeText = document.getElementById('preWishesPausedNoticeText');
      const prePartyDiv = document.getElementById('prePartyWaitMode');
      const inactiveDiv = document.getElementById('wishboxInactiveMessage');
      const wishForm = document.getElementById('wishForm');
      if (prePartyDiv) prePartyDiv.style.display = 'none';
      if (inactiveDiv) inactiveDiv.style.display = 'none';
      if (wishForm) {
        wishForm.style.display = 'none';
        wishForm.style.visibility = 'hidden';
      }
      if (notice) notice.style.display = 'block';
      if (noticeText) {
        noticeText.textContent = t(
          'pre_wishes_paused_guest_message',
          'Enough advance requests have already been received – no further requests can be submitted for now.',
        );
      }
      try { sessionStorage.removeItem('guestPreWishSession'); } catch (e) {}
      isPreWishMode = false;
      isPreWishesPausedMode = true;
      if (typeof stopPreWishLimitStream === 'function') stopPreWishLimitStream();
      if (typeof stopWishLimitStream === 'function') stopWishLimitStream();
      syncPreWishDisclaimerUi();
      syncGuestDrawerNav();
      if (typeof updateHeaderBranding === 'function') updateHeaderBranding();
    }

    /** Vorab-Modus: roten DJ-Disclaimer im Formular/Erfolg ausblenden (nur Vorab-Banner). */
    function isPreWishUiActive() {
      if (isPreWishMode === true) return true;
      try {
        if (sessionStorage.getItem('guestPreWishSession') === '1') return true;
      } catch (e) {}
      const banner = document.getElementById('preWishBanner');
      if (!banner) return false;
      try {
        return banner.style.display !== 'none' && window.getComputedStyle(banner).display !== 'none';
      } catch (e) {
        return banner.style.display !== 'none';
      }
    }

    function syncGuestDrawerNav() {
      const history = document.getElementById('drawer-nav-history');
      const social = document.getElementById('drawer-nav-social-media');
      const kontakt = document.getElementById('drawer-nav-kontakt');
      const validatedPartyId = localStorage.getItem('validatedPartyId') ||
        sessionStorage.getItem('validatedPartyId') || '';
      const hasParty = validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '';
      const plan = (sessionStorage.getItem('djPlanType') || '').toLowerCase().trim();
      // Nur explizit „free“ ausblenden — leerer Plan ≠ Free (sonst fehlen Social/Kontakt bis DJ-Profil lädt).
      const isFreeDj = plan === 'free';
      const preWish = isPreWishUiActive() || isPreWishesPausedMode || vbIsPrePartyWaitUiActive();

      if (history) {
        history.style.display = (hasParty && preWish) ? 'none' : '';
      }
      if (social) {
        social.style.display = (hasParty && preWish && isFreeDj) ? 'none' : '';
      }
      if (kontakt) {
        kontakt.style.display = (hasParty && preWish && isFreeDj) ? 'none' : '';
      }
    }
    window.syncGuestDrawerNav = syncGuestDrawerNav;

    function persistPartyStartDate(date) {
      if (!date || isNaN(date.getTime())) return;
      try {
        const ms = String(date.getTime());
        sessionStorage.setItem('validatedPartyStartMs', ms);
        localStorage.setItem('validatedPartyStartMs', ms);
      } catch (e) {}
    }

    function getStoredPartyStartDate() {
      if (currentPartyStartDate && !isNaN(currentPartyStartDate.getTime())) {
        return currentPartyStartDate;
      }
      try {
        const raw =
          sessionStorage.getItem('validatedPartyStartMs') ||
          localStorage.getItem('validatedPartyStartMs');
        if (raw) {
          const d = new Date(parseInt(raw, 10));
          if (!isNaN(d.getTime())) return d;
        }
      } catch (e) {}
      return null;
    }

    function formatPreWishPartyStartLocalized(date) {
      if (!date || isNaN(date.getTime())) return '';
      if (typeof window.formatLocaleCompactDateTime === 'function') {
        return window.formatLocaleCompactDateTime(date, null, t);
      }
      var loc =
        typeof window.getPartyLocale === 'function'
          ? window.getPartyLocale(
              typeof window.getEffectiveLangForMenu === 'function'
                ? window.getEffectiveLangForMenu()
                : null,
            )
          : 'de-DE';
      return date.toLocaleString(loc);
    }

    function syncPreWishDisclaimerUi() {
      const hide = isPreWishUiActive();
      const intro = document.querySelector('.wishbox-intro-disclaimer');
      const successDisc = document.querySelector('#successMessage .wish-sent-disclaimer');
      const successHeadline = document.querySelector('#successMessage .wish-sent-headline');
      const limitInfoDiv = document.getElementById('wishLimitInfo');
      const pageWunschbox = document.getElementById('page-wunschbox');
      if (document.body) document.body.classList.toggle('pre-wish-mode', hide);
      if (pageWunschbox) pageWunschbox.classList.toggle('pre-wish-mode', hide);
      if (limitInfoDiv) limitInfoDiv.style.display = hide ? 'none' : limitInfoDiv.style.display;
      if (successHeadline) {
        successHeadline.textContent = hide
          ? t('pre_wish_sent_received', 'Your advance music request has been received by the DJ. Thank you.')
          : t('wish_sent_received', 'Your request has been received');
      }
      if (intro) {
        intro.style.display = hide ? 'none' : '';
        if (hide) intro.setAttribute('hidden', '');
        else intro.removeAttribute('hidden');
        intro.setAttribute('aria-hidden', hide ? 'true' : 'false');
      }
      if (successDisc) {
        successDisc.style.display = hide ? 'none' : '';
        if (hide) successDisc.setAttribute('hidden', '');
        else successDisc.removeAttribute('hidden');
        successDisc.setAttribute('aria-hidden', hide ? 'true' : 'false');
      }
      if (typeof updateHeaderBranding === 'function') updateHeaderBranding();
    }
    window.syncPreWishDisclaimerUi = syncPreWishDisclaimerUi;

    function clearPreWishMode() {
      isPreWishMode = false;
      isPreWishesPausedMode = false;
      try { sessionStorage.removeItem('guestPreWishSession'); } catch (e) {}
      if (typeof stopPreWishLimitStream === 'function') stopPreWishLimitStream();
      hidePreWishBanner();
      hidePreWishesPausedNotice();
      syncPreWishDisclaimerUi();
      syncGuestDrawerNav();
    }

    function showPreWishOrPausedMode(partyData, partyName, startDate) {
      if (window.vbArePreWishesPaused && window.vbArePreWishesPaused(partyData)) {
        showPreWishesPausedMode(partyName, startDate);
      } else {
        showPreWishWishboxMode(partyName, startDate);
      }
    }

    function showPreWishWishboxMode(partyName, startDate) {
      isPreWishMode = true;
      isPreWishesPausedMode = false;
      hidePreWishesPausedNotice();
      try { sessionStorage.setItem('guestPreWishSession', '1'); } catch (e) {}
      if (partyName && String(partyName).trim()) {
        const pn = String(partyName).trim();
        try {
          sessionStorage.setItem('validatedPartyName', pn);
          localStorage.setItem('validatedPartyName', pn);
          sessionStorage.setItem('currentPartyName', pn);
          localStorage.setItem('currentPartyName', pn);
        } catch (ePn) {}
      }
      isWishboxActive = true;
      stopPrePartyCountdown();
      currentPartyStartDate = startDate;
      if (startDate) persistPartyStartDate(startDate);
      const prePartyDiv = document.getElementById('prePartyWaitMode');
      const inactiveDiv = document.getElementById('wishboxInactiveMessage');
      const wishForm = document.getElementById('wishForm');
      const banner = document.getElementById('preWishBanner');
      const bannerText = document.getElementById('preWishBannerText');
      if (prePartyDiv) prePartyDiv.style.display = 'none';
      if (inactiveDiv) inactiveDiv.style.display = 'none';
      if (wishForm) wishForm.style.display = 'block';
      if (banner) banner.style.display = 'block';
      if (bannerText) {
        bannerText.textContent = t('pre_wish_banner_body', 'You can send the DJ music requests in advance here.');
      }
      syncPreWishDisclaimerUi();
      syncGuestDrawerNav();
      if (typeof updateHeaderBranding === 'function') updateHeaderBranding();
      if (window.IS_DEBUG) console.log('📬 Vorab-Wunschbox aktiv für', partyName || 'Party');
      if (typeof updateWishboxUI === 'function') updateWishboxUI();
    }

    function showPreWishesPausedMode(partyName, startDate) {
      isWishboxActive = true;
      stopPrePartyCountdown();
      currentPartyStartDate = startDate;
      if (startDate) persistPartyStartDate(startDate);
      if (partyName && String(partyName).trim()) {
        const pn = String(partyName).trim();
        try {
          sessionStorage.setItem('validatedPartyName', pn);
          localStorage.setItem('validatedPartyName', pn);
          sessionStorage.setItem('currentPartyName', pn);
          localStorage.setItem('currentPartyName', pn);
        } catch (ePn) {}
      }
      showPreWishesPausedNotice();
      if (window.IS_DEBUG) console.log('⏸ Vorab-Wunschbox pausiert für', partyName || 'Party');
      if (typeof updateWishboxUI === 'function') updateWishboxUI();
    }

    // Pre-Party Wartemodus Funktionen
    function showPrePartyWaitMode(partyName, startDate) {
      clearPreWishMode();
      isWishboxActive = false;
      if (typeof stopWishLimitStream === 'function') stopWishLimitStream();
      if (typeof stopPreWishLimitStream === 'function') stopPreWishLimitStream();
      const prePartyDiv = document.getElementById('prePartyWaitMode');
      const inactiveDiv = document.getElementById('wishboxInactiveMessage');
      const wishForm = document.getElementById('wishForm');
      
      if (prePartyDiv) {
        prePartyDiv.style.display = 'block';
        const titleElement = document.getElementById('prePartyTitle');
        const subtitleElement = document.getElementById('prePartySubtitle');
        if (titleElement) {
          var titleTpl = t('pre_party_title_with_name', partyName + ' starts soon!');
          titleElement.textContent = titleTpl.indexOf('{name}') !== -1 ? titleTpl.replace('{name}', partyName) : (partyName + ' starts soon!');
        }
        if (subtitleElement) subtitleElement.textContent = t('pre_party_subtitle', 'The wishbox will be unlocked automatically');
      }
      if (inactiveDiv) inactiveDiv.style.display = 'none';
      if (wishForm) {
        wishForm.style.display = 'none';
        wishForm.style.visibility = 'hidden';
      }
      
      // Starte Countdown
      startPrePartyCountdown(startDate);
    }
    
    function startPrePartyCountdown(startDate) {
      stopPrePartyCountdown();
      var countdownElement = document.getElementById('prePartyCountdown');

      function updateCountdown() {
        var nowMs = Date.now();
        var startMs = startDate.getTime();
        var diff = startMs - nowMs;

        if (diff <= 0) {
          stopPrePartyCountdown();
          if (window.IS_DEBUG) console.log('⏰ Countdown erreicht 0, aktiviere Wunschbox automatisch');
          checkWishboxStatus();
          return;
        }
        // Gleiche Zeitbasis wie calculateTimeUntilParty: erst unter 60 Sek "Startet jetzt"
        if (diff < 60000 && countdownElement) {
          countdownElement.textContent = t('party_starts_now', 'Starting now');
          return;
        }

        var days = Math.floor(diff / (1000 * 60 * 60 * 24));
        var hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        var minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
        var seconds = Math.floor((diff % (1000 * 60)) / 1000);

        if (countdownElement) {
          countdownElement.textContent =
            String(days).padStart(2, '0') + ':' +
            String(hours).padStart(2, '0') + ':' +
            String(minutes).padStart(2, '0') + ':' +
            String(seconds).padStart(2, '0');
        }
      }

      updateCountdown();
      prePartyCountdownInterval = setInterval(updateCountdown, 1000);
    }
    
    function stopPrePartyCountdown() {
      if (prePartyCountdownInterval) {
        clearInterval(prePartyCountdownInterval);
        prePartyCountdownInterval = null;
      }
      const prePartyDiv = document.getElementById('prePartyWaitMode');
      if (prePartyDiv) {
        prePartyDiv.style.display = 'none';
      }
      currentPartyStartDate = null;
    }

    function vbIsDomElementVisible(el) {
      if (!el) return false;
      try {
        return el.style.display !== 'none' && window.getComputedStyle(el).display !== 'none';
      } catch (e) {
        return el.style.display !== 'none';
      }
    }

    /** True wenn ein Sonderfenster aktiv ist — Wunschbox-Formular darf dann nie eingeblendet werden. */
    function vbIsGuestWishboxFormSuppressed() {
      if (typeof vbIsPrePartyWaitUiActive === 'function' && vbIsPrePartyWaitUiActive()) return true;
      if (document.getElementById('vbPartyEndedOverlay')) return true;
      if (document.getElementById('partyCodeErrorModalOverlay')) return true;
      var pausedOverlay = document.getElementById('partyPausedOverlay');
      if (pausedOverlay && pausedOverlay.style.display === 'flex') return true;
      var pausedNotice = document.getElementById('preWishesPausedNotice');
      if (pausedNotice && vbIsDomElementVisible(pausedNotice)) return true;
      return false;
    }

    function vbHideWishboxFormChrome() {
      var wf = document.getElementById('wishForm');
      var lim = document.getElementById('wishLimitInfo');
      var bl = document.getElementById('brandingLine');
      if (wf) {
        wf.style.display = 'none';
        wf.style.visibility = 'hidden';
      }
      if (lim) lim.style.display = 'none';
      if (bl) {
        bl.style.display = 'none';
        bl.style.visibility = 'hidden';
      }
      var sb = document.getElementById('submitBtn');
      if (sb) sb.disabled = true;
    }

    function updateWishboxUI() {
      if (window.IS_DEBUG) console.log('DEBUG: UI Update gestartet, Status:', isWishboxActive);
      // Erfolgs-Overlay darf normale Updates blockieren — aber NICHT die Sperr-UI.
      // Sonst bleibt die Wunschbox bis Refresh/„Weiteren Wunsch“ offen, obwohl onSnapshot schon gesperrt hat.
      if (window.isSuccessActive) {
        if (isBlocked) {
          window.isSuccessActive = false;
          var successEl = document.getElementById('successMessage');
          if (successEl) successEl.classList.remove('show');
          var successOpenFc = document.querySelector('.form-container');
          if (successOpenFc) successOpenFc.classList.remove('success-open');
          if (window.IS_DEBUG) {
            console.log('🚫 updateWishboxUI: Sperre während Erfolgsmeldung — Overlay schließen, Block-UI zeigen');
          }
        } else {
          if (window.IS_DEBUG) console.log('DEBUG PWA: updateWishboxUI Erfolgsmeldung aktiv, überspringe');
          return;
        }
      }

      var loadingOverlay = document.getElementById('loading-overlay');
      var bodyLoadErrorEl = document.getElementById('bodyLoadError');
      if (window.bodyLoadError && bodyLoadErrorEl) {
        if (typeof showLoader === 'function') showLoader(false);
        else if (loadingOverlay) loadingOverlay.style.display = 'none';
        var wf = document.getElementById('wishForm');
        if (wf) {
          wf.style.display = 'none';
          wf.style.visibility = 'hidden';
        }
        var inactiveMsg = document.getElementById('wishboxInactiveMessage');
        var blockedMsg = document.getElementById('wishboxBlockedMessage');
        var bl = document.getElementById('brandingLine');
        var limitInfo = document.getElementById('wishLimitInfo');
        if (inactiveMsg) inactiveMsg.style.display = 'none';
        if (blockedMsg) blockedMsg.style.display = 'none';
        if (bl) bl.style.display = 'none';
        if (limitInfo) limitInfo.style.display = 'none';
        bodyLoadErrorEl.style.display = 'block';
        bodyLoadErrorEl.style.visibility = 'visible';
        bodyLoadErrorEl.style.opacity = '1';
        var prePartyDiv = document.getElementById('prePartyWaitMode');
        if (prePartyDiv) prePartyDiv.style.display = 'none';
        if (window.IS_DEBUG) console.log('DEBUG PWA: Body-Ladefehler angezeigt');
        return;
      }
      if (bodyLoadErrorEl) bodyLoadErrorEl.style.display = 'none';

      if (vbIsGuestWishboxFormSuppressed()) {
        if (typeof showLoader === 'function') showLoader(false);
        else if (loadingOverlay) loadingOverlay.style.display = 'none';
        vbHideWishboxFormChrome();
        if (typeof vbIsPrePartyWaitUiActive === 'function' && vbIsPrePartyWaitUiActive()) {
          var inactivePreParty = document.getElementById('wishboxInactiveMessage');
          var blockedPreParty = document.getElementById('wishboxBlockedMessage');
          if (inactivePreParty) inactivePreParty.style.display = 'none';
          if (blockedPreParty) {
            blockedPreParty.style.display = 'none';
            blockedPreParty.style.visibility = 'hidden';
          }
          hidePreWishBanner();
        }
        if (document.getElementById('vbPartyEndedOverlay')) {
          var inactiveEnded = document.getElementById('wishboxInactiveMessage');
          if (inactiveEnded) inactiveEnded.style.display = 'none';
        }
        if (typeof syncGuestDrawerNav === 'function') syncGuestDrawerNav();
        return;
      }

      if (isPreWishesPausedMode) {
        if (typeof showLoader === 'function') showLoader(false);
        else if (loadingOverlay) loadingOverlay.style.display = 'none';
        var noticePaused = document.getElementById('preWishesPausedNotice');
        var wfPaused = document.getElementById('wishForm');
        var bannerPaused = document.getElementById('preWishBanner');
        var inactPaused = document.getElementById('wishboxInactiveMessage');
        var blkPaused = document.getElementById('wishboxBlockedMessage');
        var limPaused = document.getElementById('wishLimitInfo');
        var blPaused = document.getElementById('brandingLine');
        var prePartyPaused = document.getElementById('prePartyWaitMode');
        if (noticePaused) noticePaused.style.display = 'block';
        if (wfPaused) {
          wfPaused.style.display = 'none';
          wfPaused.style.visibility = 'hidden';
        }
        if (bannerPaused) bannerPaused.style.display = 'none';
        if (inactPaused) inactPaused.style.display = 'none';
        if (blkPaused) {
          blkPaused.style.display = 'none';
          blkPaused.style.visibility = 'hidden';
        }
        if (limPaused) limPaused.style.display = 'none';
        if (blPaused) blPaused.style.display = 'none';
        if (prePartyPaused) prePartyPaused.style.display = 'none';
        var sbPaused = document.getElementById('submitBtn');
        if (sbPaused) sbPaused.disabled = true;
        if (typeof stopPreWishLimitStream === 'function') stopPreWishLimitStream();
        if (typeof stopWishLimitStream === 'function') stopWishLimitStream();
        syncGuestDrawerNav();
        if (typeof updateHeaderBranding === 'function') updateHeaderBranding();
        return;
      }

      if (vbIsFloorPickerActive()) {
        vbUpdateFloorSwitchButton();
        var loadingOvFloor = document.getElementById('loading-overlay');
        if (typeof showLoader === 'function') showLoader(false);
        else if (loadingOvFloor) loadingOvFloor.style.display = 'none';
        var wfFloor = document.getElementById('wishForm');
        var blFloor = document.getElementById('brandingLine');
        var limFloor = document.getElementById('wishLimitInfo');
        var inactFloor = document.getElementById('wishboxInactiveMessage');
        var blkFloor = document.getElementById('wishboxBlockedMessage');
        var pauseFloor = document.getElementById('partyPausedOverlay');
        var prePartyFloor = document.getElementById('prePartyWaitMode');
        if (wfFloor) {
          wfFloor.style.display = 'none';
          wfFloor.style.visibility = 'hidden';
        }
        if (blFloor) {
          blFloor.style.display = 'none';
          blFloor.style.visibility = 'hidden';
        }
        if (limFloor) limFloor.style.display = 'none';
        if (inactFloor) inactFloor.style.display = 'none';
        if (blkFloor) {
          blkFloor.style.display = 'none';
          blkFloor.style.visibility = 'hidden';
        }
        if (pauseFloor) pauseFloor.style.display = 'none';
        if (prePartyFloor) prePartyFloor.style.display = 'none';
        hidePreWishBanner();
        return;
      }

      var floorPickerEl = document.getElementById('guestFloorPicker');
      var floorPickerVisible = false;
      vbUpdateFloorSwitchButton();

      // Bis checkBlockStatus die ersten Reads abgeschlossen hat: kein Formular (verhindert Flackern bei Sperre)
      if (!wishboxBlockGateResolved) {
        var wfGate = document.getElementById('wishForm');
        var blGate = document.getElementById('brandingLine');
        var limGate = document.getElementById('wishLimitInfo');
        var inactGate = document.getElementById('wishboxInactiveMessage');
        var blkGate = document.getElementById('wishboxBlockedMessage');
        if (isPreWishMode && isWishboxActive && !isBlocked) {
          if (typeof showLoader === 'function') showLoader(false);
          else if (loadingOverlay) loadingOverlay.style.display = 'none';
          if (wfGate) {
            wfGate.style.display = 'block';
            wfGate.style.visibility = 'visible';
          }
          if (inactGate) inactGate.style.display = 'none';
          if (blkGate) blkGate.style.display = 'none';
          var preWishBannerGate = document.getElementById('preWishBanner');
          if (preWishBannerGate) preWishBannerGate.style.display = 'block';
          if (blGate) blGate.style.visibility = 'visible';
          if (typeof updateBrandingLine === 'function') updateBrandingLine();
          syncPreWishDisclaimerUi();
          syncGuestDrawerNav();
          return;
        }
        if (wfGate) {
          wfGate.style.display = 'none';
          wfGate.style.visibility = 'hidden';
        }
        if (blGate) {
          blGate.style.display = 'none';
          blGate.style.visibility = 'hidden';
        }
        if (limGate) limGate.style.display = 'none';
        if (isBlocked) {
          if (typeof showLoader === 'function') showLoader(false);
          else if (loadingOverlay) loadingOverlay.style.display = 'none';
          if (inactGate) inactGate.style.display = 'none';
          if (blkGate) {
            blkGate.style.display = 'block';
            blkGate.style.visibility = 'visible';
          }
          var sbGate = document.getElementById('submitBtn');
          if (sbGate) sbGate.disabled = true;
          return;
        }
        var storedPartyForLoader = (sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId') || '').trim();
        var hasStoredPartyForLoader = storedPartyForLoader && storedPartyForLoader !== 'manual';
        if (!hasStoredPartyForLoader) {
          if (typeof showLoader === 'function' && !isWishboxActive) showLoader(true);
          else if (!isWishboxActive && loadingOverlay) loadingOverlay.style.display = 'flex';
        }
        if (inactGate) inactGate.style.display = 'none';
        if (blkGate) blkGate.style.display = 'none';
        return;
      }

      if (isWishboxActive && typeof showLoader === 'function') showLoader(false);
      else if (isWishboxActive && loadingOverlay) loadingOverlay.style.display = 'none';
      
      if (isWishboxActive && !isPreWishMode) {
        stopPrePartyCountdown();
      }
      
      if (window.IS_DEBUG) console.log('DEBUG PWA: updateWishboxUI isBlocked:', isBlocked, 'isWishboxActive:', isWishboxActive);
      const wishForm = document.getElementById('wishForm');
      const inactiveMessage = document.getElementById('wishboxInactiveMessage');
      const blockedMessage = document.getElementById('wishboxBlockedMessage');
      const submitBtn = document.getElementById('submitBtn');
      const pausedOverlay = document.getElementById('partyPausedOverlay');

      // Stelle sicher, dass UI immer korrekt gesetzt wird
      const brandingLine = document.getElementById('brandingLine');
      
      // ✅ Sperr-UI VOR Pause: Sonst kehrt der frühe Pause-Return und Realtime-Entsperren
      // (applyRealtimeBlockState → updateWishboxUI) blendet die Block-Nachricht nie aus.
      if (isBlocked) {
        if (typeof showLoader === 'function') showLoader(false);
        else if (loadingOverlay) loadingOverlay.style.display = 'none';
        if (window.IS_DEBUG) console.log('🚫 updateWishboxUI: Gast ist gesperrt, zeige Block-Nachricht');
        // Gast ist gesperrt - zeige Block-Nachricht
        if (wishForm) {
          wishForm.style.display = 'none';
          wishForm.style.visibility = 'hidden';
        }
        if (inactiveMessage) inactiveMessage.style.display = 'none';
        if (blockedMessage) {
          blockedMessage.style.display = 'block';
          blockedMessage.style.visibility = 'visible';
        }
        if (submitBtn) submitBtn.disabled = true;
        if (brandingLine) brandingLine.style.display = 'none'; // ✅ Branding-Zeile verstecken bei Block
        const limitInfoDiv = document.getElementById('wishLimitInfo');
        if (limitInfoDiv) {
          limitInfoDiv.style.display = 'none';
        }
        return;
      }
      
      // ✅ Pause: Formular/Streams nicht doppelt steuern — aber Entsperr-Zustand (kein isBlocked) muss
      // die Block-Nachricht ausblenden, sonst bleibt sie bei is_paused sichtbar.
      const isPaused = pausedOverlay && pausedOverlay.style.display === 'flex';
      if (isPaused) {
        if (blockedMessage) {
          blockedMessage.style.display = 'none';
          blockedMessage.style.visibility = 'hidden';
        }
        if (window.IS_DEBUG) console.log('⏸️ updateWishboxUI: Pause aktiv, überspringe normale UI-Updates');
        return; // Pause-Overlay wird von togglePartyPausedOverlay gesteuert
      }
      
      if (isWishboxActive && !vbIsFloorPickerActive()) {
        // Wunschbox ist aktiv und Gast ist nicht gesperrt
        var floorOverlayEl = document.getElementById('guestFloorPickerOverlay');
        if (floorOverlayEl) floorOverlayEl.style.display = 'none';
        if (wishForm) {
          wishForm.style.display = 'block';
          wishForm.style.visibility = 'visible';
        }
        if (inactiveMessage) inactiveMessage.style.display = 'none';
        // ✅ Branding-Zeile nur bei aktiver Party anzeigen
        if (brandingLine && typeof updateBrandingLine === 'function') {
          updateBrandingLine();
        }
        if (brandingLine) brandingLine.style.visibility = 'visible';
        // ✅ Realtime-Stream für Wunsch-Limit starten (ersetzt Polling, kein Flackern)
        const partyId = sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId');
        if (partyId && partyId !== 'manual') {
          if (isPreWishMode) {
            if (typeof subscribePreWishLimitStream === 'function') {
              subscribePreWishLimitStream(partyId);
            }
          } else {
            if (typeof stopPreWishLimitStream === 'function') stopPreWishLimitStream();
            subscribeWishLimitStream(partyId);
          }
          warmSubmitCaches(partyId);
        }
        else if (typeof stopWishLimitStream === 'function') stopWishLimitStream();
        if (blockedMessage) {
          blockedMessage.style.display = 'none';
          blockedMessage.style.visibility = 'hidden';
        }
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.style.pointerEvents = '';
        }
        isSubmitting = false;
        const limitInfoDiv = document.getElementById('wishLimitInfo');
        if (limitInfoDiv && !isPreWishMode) {
          limitInfoDiv.style.display = 'block';
        }
        const preWishBanner = document.getElementById('preWishBanner');
        if (isPreWishMode) {
          if (preWishBanner) preWishBanner.style.display = 'block';
        } else {
          hidePreWishBanner();
        }
        syncPreWishDisclaimerUi();
        syncGuestDrawerNav();
      } else {
        hidePreWishBanner();
        // Wunschbox ist inaktiv
        if (window.__vbDeferWishboxStatusUntilBoot === true || vbHasAnyJoinFlowSignal()) {
          if (typeof showLoader === 'function') {
            var joinLoaderMsg = (typeof getTranslation === 'function' ? getTranslation('loading_party_connection') : null) || 'Connecting to the party...';
            showLoader(true, joinLoaderMsg);
          } else if (loadingOverlay) loadingOverlay.style.display = 'flex';
          if (inactiveMessage) inactiveMessage.style.display = 'none';
          if (wishForm) {
            wishForm.style.display = 'none';
            wishForm.style.visibility = 'hidden';
          }
          if (blockedMessage) {
            blockedMessage.style.display = 'none';
            blockedMessage.style.visibility = 'hidden';
          }
          return;
        }
        if (typeof showLoader === 'function') showLoader(false);
        else if (loadingOverlay) loadingOverlay.style.display = 'none';
        if (floorPickerVisible || vbIsFloorPickerActive()) {
          if (wishForm) {
            wishForm.style.display = 'none';
            wishForm.style.visibility = 'hidden';
          }
          if (inactiveMessage) inactiveMessage.style.display = 'none';
          if (blockedMessage) {
            blockedMessage.style.display = 'none';
            blockedMessage.style.visibility = 'hidden';
          }
          if (brandingLine) brandingLine.style.display = 'none';
          if (pausedOverlay) pausedOverlay.style.display = 'none';
          return;
        }
        if (wishForm) {
          wishForm.style.display = 'none';
          wishForm.style.visibility = 'hidden';
        }
        if (inactiveMessage) inactiveMessage.style.display = 'block';
        if (blockedMessage) {
          blockedMessage.style.display = 'none';
          blockedMessage.style.visibility = 'hidden';
        }
        if (submitBtn) submitBtn.disabled = true;
        if (brandingLine) brandingLine.style.display = 'none'; // ✅ Branding-Zeile verstecken bei Inaktivität
        // ✅ Pause-Overlay ausblenden, wenn Wunschbox inaktiv ist
        if (pausedOverlay) pausedOverlay.style.display = 'none';
        if (typeof stopWishLimitStream === 'function') stopWishLimitStream();
        const limitInfoDiv = document.getElementById('wishLimitInfo');
        if (limitInfoDiv) {
          limitInfoDiv.style.display = 'none';
        }
      }
      
    }
    
    
    // ✅ Funktion zum Aktualisieren des DJ-Namens im Header
    // ✅ Session-basiert: Extrahiert Namen einmalig beim Login und speichert in sessionStorage
    async function updateHeaderDjName(partyId, partyData, createdByUidOverride) {
      try {
        const headerDjName = document.getElementById('wunschboxHeaderDjName');
        if (!headerDjName) return;
        
        // Wenn keine Party aktiv ist, verstecke DJ-Namen und lösche sessionStorage
        if (!partyId || partyId === 'manual' || !partyData) {
          headerDjName.style.display = 'none';
          sessionStorage.removeItem('currentDjName');
          updateDrawerDjName(null);
          updateLogoutButtonVisibility();
          return;
        }
        
        // ✅ Prüfe zuerst sessionStorage - wenn bereits vorhanden, verwende diesen
        const savedDjName = sessionStorage.getItem('currentDjName');
        if (savedDjName) {
          if (window.IS_DEBUG) console.log('✅ DJ-Name aus sessionStorage geladen:', savedDjName);
          updateDrawerDjName(savedDjName);
          updateHeaderBranding();
          if (typeof updateBrandingLine === 'function') {
            void updateBrandingLine(partyData);
          }
          return;
        }
        
        // ✅ Initialer Speicherpunkt: Extrahiere DJ-Namen beim ersten Login
        if (window.IS_DEBUG) console.log('🔍 Initialer Login: Extrahiere DJ-Namen aus Party-Daten...');
        if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
        
        
        let djName = null;
        
        // ✅ Fallback-Sicherung: Prüfe zuerst dj_name, dann display_name, dann name
        if (partyData.dj_name) {
          djName = partyData.dj_name;
          if (window.IS_DEBUG) console.log('✅ DJ-Name gefunden in dj_name:', djName);
        } else if (partyData.display_name) {
          djName = partyData.display_name;
          if (window.IS_DEBUG) console.log('✅ DJ-Name gefunden in display_name:', djName);
        } else if (partyData.name) {
          djName = partyData.name;
          if (window.IS_DEBUG) console.log('✅ DJ-Name gefunden in name:', djName);
        }
        
        const profileUid = (typeof createdByUidOverride === 'string' && createdByUidOverride.trim() !== '')
          ? createdByUidOverride.trim()
          : ((typeof partyData.created_by === 'string') ? partyData.created_by.trim() : '');

        // Falls kein Name gefunden, lade aus Public-Profil (Hintergrund — blockiert Join nicht)
        if (!djName && profileUid) {
          void fetchPublicDjProfile(profileUid).then(function (userData) {
            if (!userData || !userData.displayName) return;
            var fetchedName = userData.displayName.charAt(0).toUpperCase() + userData.displayName.slice(1);
            var validatedPartyIdCheck2 = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
            if (!validatedPartyIdCheck2 || validatedPartyIdCheck2 === 'manual' || validatedPartyIdCheck2 === '') return;
            var sanitizedFetched = String(fetchedName).trim().substring(0, 100);
            sessionStorage.setItem('currentDjName', sanitizedFetched);
            updateDrawerDjName(sanitizedFetched);
            updateHeaderBranding();
            if (typeof updateBrandingLine === 'function') updateBrandingLine();
            if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
          }).catch(function (e) {
            if (window.IS_DEBUG) console.warn('⚠️ Konnte DJ-Namen nicht aus users Collection laden:', e);
          });
        }
        
        // 4. Falls immer noch kein Name, verwende created_by als Fallback
        if (!djName && profileUid) {
          djName = profileUid.substring(0, 8); // Erste 8 Zeichen der UID
        }
        
        // ✅ Client-Side Isolation: Nur speichern, wenn validatedPartyId vorhanden ist
        const validatedPartyIdCheck = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
        if (!validatedPartyIdCheck || validatedPartyIdCheck === 'manual' || validatedPartyIdCheck === '') {
          if (window.IS_DEBUG) console.warn('⚠️ Keine validatedPartyId vorhanden - speichere keine DJ-Daten in sessionStorage');
          updateDrawerDjName(null);
          return;
        }
        
        // ✅ Session-Storage: Speichere extrahierten Namen sofort in sessionStorage
        if (djName) {
          // ✅ XSS-Schutz: Nur Text speichern, keine HTML
          const sanitizedDjName = String(djName).trim().substring(0, 100); // Max 100 Zeichen
          sessionStorage.setItem('currentDjName', sanitizedDjName);
          if (window.IS_DEBUG) console.log('✅ DJ-Name in sessionStorage gespeichert (sanitized):', sanitizedDjName);
          
          // ✅ UI-Trigger: Rufe sofort updateDrawerDjName() auf, damit der Name erscheint
          updateDrawerDjName(sanitizedDjName);
          if (window.IS_DEBUG) console.log('✅ DJ-Namen im Drawer aktualisiert (sofort nach Speichern):', sanitizedDjName);
          if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
          
          // ✅ Header-Update: Aktualisiere Header sofort nach dem Speichern
          updateHeaderBranding();
          if (typeof updateBrandingLine === 'function') updateBrandingLine();
          if (window.IS_DEBUG) console.log('✅ Header aktualisiert nach DJ-Name Speicherung');
        } else {
          if (window.IS_DEBUG) console.warn('⚠️ Kein DJ-Name gefunden, kann nicht in sessionStorage speichern');
          if (window.IS_DEBUG) console.warn('⚠️ Kein DJ-Name gefunden');
          updateDrawerDjName(null);
          // ✅ Auch Header aktualisieren, falls kein DJ-Name (zeigt dann Fallback)
          updateHeaderBranding();
        }
        
      } catch (e) {
        console.error('❌ Fehler beim Aktualisieren des DJ-Namens:', e);
        const headerDjName = document.getElementById('wunschboxHeaderDjName');
        if (headerDjName) {
          headerDjName.style.display = 'none';
        }
      }
    }
    
    // ✅ Drawer-Menü Funktionen
    function toggleDrawer() {
      if (window.IS_DEBUG) console.log('🔍 toggleDrawer aufgerufen');
      const drawerMenu = document.getElementById('drawerMenu');
      const drawerOverlay = document.getElementById('drawerOverlay');
      const hamburgerBtn = document.getElementById('hamburgerMenuBtn');
      
      if (!drawerMenu || !drawerOverlay || !hamburgerBtn) {
        console.error('❌ Drawer-Elemente nicht gefunden!');
        return;
      }
      
      const isActive = drawerMenu.classList.contains('active');
      if (window.IS_DEBUG) console.log('🔍 Drawer ist aktuell:', isActive ? 'geöffnet' : 'geschlossen');
      
      if (isActive) {
        drawerMenu.classList.remove('active');
        drawerOverlay.classList.remove('active');
        hamburgerBtn.classList.remove('active');
        if (window.IS_DEBUG) console.log('✅ Drawer geschlossen');
      } else {
        drawerMenu.classList.add('active');
        drawerOverlay.classList.add('active');
        hamburgerBtn.classList.add('active');
        // ✅ Lade Logo beim Öffnen des Drawers
        loadDrawerLogo();
        if (window.IS_DEBUG) console.log('✅ Drawer geöffnet');
      }
    }

    function closeDrawer() {
      if (window.IS_DEBUG) console.log('🔍 closeDrawer aufgerufen');
      const drawerMenu = document.getElementById('drawerMenu');
      const drawerOverlay = document.getElementById('drawerOverlay');
      const hamburgerBtn = document.getElementById('hamburgerMenuBtn');
      
      if (drawerMenu && drawerOverlay && hamburgerBtn) {
        drawerMenu.classList.remove('active');
        drawerOverlay.classList.remove('active');
        hamburgerBtn.classList.remove('active');
        if (window.IS_DEBUG) console.log('✅ Drawer geschlossen');
      }
    }

    // ✅ Aktualisiere aktiven Menüpunkt im Drawer
    function updateDrawerActiveItem(activePageId) {
      const drawerItems = document.querySelectorAll('.drawer-menu-item');
      drawerItems.forEach(item => {
        item.classList.remove('active');
        if (item.id === 'drawer-nav-' + activePageId) {
          item.classList.add('active');
        }
      });
    }

    // ✅ Öffne Sprache-Modal (ersetzt Dropdown)
    function openLanguageModal() {
      // Entferne vorhandenes Modal falls vorhanden
      const existingModal = document.getElementById('languageModalOverlay');
      if (existingModal) {
        existingModal.remove();
      }
      
      // Erstelle Modal-Overlay
      const overlay = document.createElement('div');
      overlay.className = 'language-modal-overlay';
      overlay.id = 'languageModalOverlay';
      
      // Erstelle Modal-Content
      const modal = document.createElement('div');
      modal.className = 'language-modal-content';
      
      // Titel
      const title = document.createElement('div');
      title.className = 'language-modal-title';
      // ✅ Hole Übersetzung für "Sprache"
      let languageTitle = t('language', 'Language');
      title.textContent = languageTitle;
      
      // Scroll-Container mit Overlays
      const scrollContainer = document.createElement('div');
      scrollContainer.className = 'language-modal-scroll-container';
      
      // Obere Overlay mit Pfeil (klickbarer Scroll-Button)
      const overlayTop = document.createElement('div');
      overlayTop.className = 'language-modal-scroll-overlay-top';
      overlayTop.id = 'languageModalOverlayTop';
      overlayTop.innerHTML = '<span class="language-modal-scroll-arrow">▲</span>';
      overlayTop.onclick = () => {
        scrollArea.scrollBy({ top: -100, behavior: 'smooth' });
      };
      
      // Untere Overlay mit Pfeil (klickbarer Scroll-Button)
      const overlayBottom = document.createElement('div');
      overlayBottom.className = 'language-modal-scroll-overlay-bottom';
      overlayBottom.id = 'languageModalOverlayBottom';
      overlayBottom.innerHTML = '<span class="language-modal-scroll-arrow">▼</span>';
      overlayBottom.onclick = () => {
        scrollArea.scrollBy({ top: 100, behavior: 'smooth' });
      };
      
      // Scroll-Bereich
      const scrollArea = document.createElement('div');
      scrollArea.className = 'language-modal-scroll-area';
      scrollArea.id = 'languageModalScrollArea';
      
      // Grid für Sprachen
      const grid = document.createElement('div');
      grid.className = 'language-modal-grid';
      grid.id = 'languageModalGrid';
      
      scrollArea.appendChild(grid);
      scrollContainer.appendChild(overlayTop);
      scrollContainer.appendChild(overlayBottom);
      scrollContainer.appendChild(scrollArea);
      
      modal.appendChild(title);
      modal.appendChild(scrollContainer);
      overlay.appendChild(modal);
      document.body.appendChild(overlay);
      
      // ✅ Fülle Grid mit Sprachen
      populateLanguageModalGrid(grid);
      
      // ✅ Scroll-Overlay-Logik
      updateLanguageModalScrollOverlays(scrollArea, overlayTop, overlayBottom);
      scrollArea.addEventListener('scroll', () => {
        updateLanguageModalScrollOverlays(scrollArea, overlayTop, overlayBottom);
      });
      
      // ✅ Click-Outside: Schließe Modal bei Klick außerhalb
      overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
          closeLanguageModal();
        }
      });
      
      // ✅ ESC-Taste: Schließe Modal
      const escHandler = (e) => {
        if (e.key === 'Escape') {
          closeLanguageModal();
          document.removeEventListener('keydown', escHandler);
        }
      };
      document.addEventListener('keydown', escHandler);
    }
    
    // ✅ Schließe Sprache-Modal
    function closeLanguageModal() {
      const modal = document.getElementById('languageModalOverlay');
      if (modal) {
        modal.remove();
      }
    }
    
    function populateLanguageModalGrid(grid) {
      if (!grid) return;
      grid.id = 'languageModalGrid';
      if (typeof window.buildDatabaseLangMenu === 'function') {
        window.buildDatabaseLangMenu('languageModalGrid', true);
      }
    }
    
    // ✅ Aktualisiere Scroll-Overlays (Pfeile oben/unten)
    function updateLanguageModalScrollOverlays(scrollArea, overlayTop, overlayBottom) {
      if (!scrollArea) return;
      
      const scrollTop = scrollArea.scrollTop;
      const scrollHeight = scrollArea.scrollHeight;
      const clientHeight = scrollArea.clientHeight;
      
      // Obere Overlay: sichtbar wenn nach oben gescrollt werden kann
      if (scrollTop > 10) {
        overlayTop.classList.add('visible');
      } else {
        overlayTop.classList.remove('visible');
      }
      
      // Untere Overlay: sichtbar wenn nach unten gescrollt werden kann
      if (scrollTop + clientHeight < scrollHeight - 10) {
        overlayBottom.classList.add('visible');
      } else {
        overlayBottom.classList.remove('visible');
      }
    }

    // ✅ Initialisiere Sprachauswahl im Drawer (nur für updateDrawerCurrentLanguage)
    // ✅ HINWEIS: Die eigentliche Sprachauswahl erfolgt jetzt über das Modal-System
    function initDrawerLanguageSelector() {
      // ✅ Aktualisiere nur die Anzeige der aktuellen Sprache im Menü
      updateDrawerCurrentLanguage();
    }
    
    // ✅ Aktualisiere die Anzeige der aktuellen Sprache im Menü – nie technischen Key anzeigen (Fallback aus window.LANGUAGE_NAMES)
    function updateDrawerCurrentLanguage() {
      const currentLanguageName = document.getElementById('drawerCurrentLanguageName');
      
      if (!currentLanguageName) {
        if (window.IS_DEBUG) console.warn('⚠️ drawerCurrentLanguageName nicht gefunden');
        return;
      }
      
      // Sprach-Name Keys (aus default-pwa-languages.js / pwa-languages.json)
      const languageNameKeys =
        (typeof window.PWA_LANGUAGE_NAME_KEYS === 'object' && window.PWA_LANGUAGE_NAME_KEYS) || {
          de: 'lang_german',
          en: 'lang_english',
          fr: 'lang_french',
          ru: 'lang_russian',
          zh: 'lang_chinese',
          es: 'lang_spanish',
          tr: 'lang_turkish',
          pt: 'lang_portuguese',
          it: 'lang_italian',
          uk: 'lang_ukrainian',
          hi: 'lang_hindi',
          sq: 'lang_albanian',
          vi: 'lang_vietnamese',
          ar: 'lang_arabic',
        };
      
      // Aktuelle Sprache bestimmen
      let currentLang = 'de';
      try {
        currentLang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
      } catch (e) {
        currentLang = 'de';
      }
      
      // Namens-Priorität: Firestore entry.name → Übersetzung → window.LANGUAGE_NAMES (nie Key anzeigen)
      let langName = (window.LANGUAGE_NAMES && window.LANGUAGE_NAMES[currentLang]) || currentLang.toUpperCase();
      const entry = window.pwaAvailableLanguages && window.pwaAvailableLanguages.find(function(e) { return e.code === currentLang; });
      const hasFirestoreName = entry && entry.name != null && String(entry.name).trim() !== '';
      if (hasFirestoreName) {
        langName = String(entry.name).trim();
      } else {
        const nameKey = languageNameKeys[currentLang] || 'lang_german';
        var translated = '';
        if (typeof window.getTranslation === 'function') {
          translated = window.getTranslation(nameKey);
        } else if (typeof window.translations !== 'undefined' && window.translations[currentLang] && window.translations[currentLang][nameKey]) {
          translated = window.translations[currentLang][nameKey];
        } else if (typeof window.translations !== 'undefined' && window.translations['en'] && window.translations['en'][nameKey]) {
          translated = window.translations['en'][nameKey];
        }
        if (translated && translated !== nameKey) langName = translated;
      }
      currentLanguageName.textContent = langName;
      
      if (window.IS_DEBUG) console.log('✅ Aktuelle Sprache im Menü aktualisiert:', currentLang, '→', langName);
    }

    // ✅ Funktion zum Laden des DJ-Logos für Drawer-Menü
    function loadDrawerLogo() {
      const logoContainer = document.getElementById('drawerLogoContainer');
      const logoImg = document.getElementById('drawerDjLogo');
      
      if (!logoContainer || !logoImg) {
        if (window.IS_DEBUG) console.warn('⚠️ Drawer Logo-Container oder Logo-Img nicht gefunden');
        return;
      }

      // ✅ Prüfe Login-Status: Party-ID vorhanden?
      const validatedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
      const isLoggedIn = validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '';
      
      if (!isLoggedIn) {
        logoContainer.style.display = 'none';
        return;
      }

      // ✅ Firebase-Referenz: db.collection('parties').doc(savedPartyId) – Modular API
      const savedPartyId = validatedPartyId;
      if (savedPartyId && savedPartyId !== 'manual' && savedPartyId !== '') {
        try {
          if (!window.firebaseDb || typeof window.firebaseCollection !== 'function' || typeof window.firebaseDoc !== 'function' || typeof window.firebaseGetDoc !== 'function') {
            if (window.IS_DEBUG) console.warn('⚠️ Firebase nicht bereit für loadDrawerLogo');
            logoContainer.style.display = 'none';
            return;
          }
          const partiesRef = window.firebaseCollection(window.firebaseDb, 'parties');
          const partyRef = window.firebaseDoc(partiesRef, savedPartyId);
          window.firebaseGetDoc(partyRef).then((partyDoc) => {
            if (partyDoc.exists()) {
              const partyData = partyDoc.data();
              const planType = (sessionStorage.getItem('djPlanType') || '').toLowerCase();
              const logoUrl = (planType === 'free') ? 'icon/vibesbox-logo.png' : (partyData.dj_logo || null);
              
              if (logoUrl && logoImg) {
                logoImg.src = logoUrl;
                logoImg.style.display = 'block';
                logoContainer.style.display = 'flex';
              } else {
                logoContainer.style.display = 'none';
              }
            } else {
              logoContainer.style.display = 'none';
            }
          }).catch((e) => {
            if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Laden der Party-Daten für Drawer-Logo:', e);
            logoContainer.style.display = 'none';
          });
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Zugriff auf Party-Daten:', e);
          logoContainer.style.display = 'none';
        }
      } else {
        logoContainer.style.display = 'none';
      }
    }

    // ✅ Lightbox-Funktionen für VibesBox Logo
    function openLogoLightbox() {
      const overlay = document.getElementById('logoLightboxOverlay');
      const lightboxImage = document.getElementById('logoLightboxImage');
      const headerLogo = document.getElementById('appHeaderLogo');
      
      if (!overlay || !lightboxImage || !headerLogo) {
        if (window.IS_DEBUG) console.warn('⚠️ Lightbox-Elemente nicht gefunden');
        return;
      }
      
      // ✅ Stelle sicher, dass das Bild geladen ist
      if (headerLogo.src) {
        lightboxImage.src = headerLogo.src;
      }
      
      // ✅ Öffne Lightbox mit Animation
      overlay.classList.add('active');
      // ✅ Verhindere Scrollen im Hintergrund
      document.body.style.overflow = 'hidden';
    }
    
    function closeLogoLightbox() {
      const overlay = document.getElementById('logoLightboxOverlay');
      
      if (!overlay) {
        return;
      }
      
      // ✅ Schließe Lightbox mit Animation
      overlay.classList.remove('active');
      // ✅ Erlaube Scrollen wieder
      document.body.style.overflow = '';
    }
    
    // ✅ ESC-Taste zum Schließen der Lightbox
    document.addEventListener('keydown', function(event) {
      if (event.key === 'Escape') {
        const overlay = document.getElementById('logoLightboxOverlay');
        if (overlay && overlay.classList.contains('active')) {
          closeLogoLightbox();
        }
      }
    });

    /** Hinweis auf der Kontaktseite: Formular geht an den DJ der Party ({djName} in l10n). */
    window.updateContactDjRecipientHint = function updateContactDjRecipientHint() {
      const el = document.getElementById('contactDjRecipientHint');
      if (!el) return;
      const partyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
      const djName = (sessionStorage.getItem('currentDjName') || '').trim();
      const show = !!(partyId && partyId !== 'manual' && partyId !== '' && djName);
      if (!show) {
        el.style.display = 'none';
        el.textContent = '';
        return;
      }
      let template = typeof t === 'function' ? t('contact_dj_recipient_hint', '') : '';
      if (!template || template === 'contact_dj_recipient_hint') {
        if (typeof window.getTranslation === 'function') {
          template = window.getTranslation('contact_dj_recipient_hint');
        }
      }
      if (!template || template === 'contact_dj_recipient_hint') {
        template = 'Send the completed form to {djName} to contact the DJ for this party.';
      }
      const safeDj = typeof escapeHtml === 'function'
        ? escapeHtml(djName)
        : String(djName).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
      el.innerHTML = template.split('{djName}').join('<strong>' + safeDj + '</strong>');
      el.style.display = 'block';
    };

    window.addEventListener('translationsReady', function () {
      if (typeof window.vbRefreshWishErrorI18n === 'function') {
        window.vbRefreshWishErrorI18n();
      }
      if (typeof window.syncPreWishDisclaimerUi === 'function') {
        window.syncPreWishDisclaimerUi();
      }
      if (typeof window.updateContactDjRecipientHint === 'function') {
        window.updateContactDjRecipientHint();
      }
      const socialMediaPage = document.getElementById('page-social-media');
      if (socialMediaPage && socialMediaPage.style.display !== 'none' && typeof renderSocialMediaLinks === 'function') {
        renderSocialMediaLinks();
      }
    });

    // ✅ Aktualisiere DJ-Namen im Drawer
    // ✅ Session-basiert: Liest ausschließlich aus sessionStorage
    function updateDrawerDjName(djName) {
      const drawerDjName = document.getElementById('drawerDjName');
      const drawerMenuTitle = document.getElementById('drawerMenuTitle');
      
      if (!drawerDjName || !drawerMenuTitle) {
        if (window.IS_DEBUG) console.warn('⚠️ drawerDjName oder drawerMenuTitle nicht gefunden');
        return;
      }
      
      // ✅ Aktualisiere "VibesBox" Titel (immer sichtbar)
      drawerMenuTitle.textContent = t('menu_title', 'VibesBox');
      if (drawerMenuTitle.textContent === 'VibesBox' && typeof translations !== 'undefined') {
        const currentLang = localStorage.getItem('pwa_language') || 'en';
        drawerMenuTitle.textContent = translations[currentLang]?.['menu_title'] || 'VibesBox';
      }
      
      // ✅ Session-basiert: Wenn kein Parameter übergeben, lese aus sessionStorage
      if (!djName) {
        djName = sessionStorage.getItem('currentDjName');
      }
      
      // ✅ Zeige DJ-Namen nur wenn vorhanden
      if (djName) {
        // ✅ Hole Übersetzung für "von" aus translations
        let byText = t('menu_by', 'by');
        if ((byText === 'by' || !byText) && typeof translations !== 'undefined') {
          const currentLang = localStorage.getItem('pwa_language') || 'en';
          byText = translations[currentLang]?.['menu_by'] || 'by';
        }
        
        drawerDjName.textContent = byText + ' ' + djName;
        drawerDjName.style.display = 'block';
        if (window.IS_DEBUG) console.log('✅ DJ-Namen im Drawer gesetzt (aus sessionStorage):', byText, djName);
      } else {
        drawerDjName.style.display = 'none';
        if (window.IS_DEBUG) console.log('✅ DJ-Name im Drawer versteckt (kein Name in sessionStorage)');
      }
      
      // ✅ Lade DJ-Logo für Drawer
      loadDrawerLogo();
      
      // ✅ Zeige/Verstecke Logout-Button basierend auf Party-Status
      updateLogoutButtonVisibility();

      if (typeof window.updateContactDjRecipientHint === 'function') {
        window.updateContactDjRecipientHint();
      }
    }
    
    // ✅ Sichtbarkeit des Logout-Buttons („Aus Party ausloggen“)
    function updateLogoutButtonVisibility() {
      const logoutItem = document.getElementById('drawerLogoutItem');
      const partyId = localStorage.getItem('validatedPartyId');
      const djName = sessionStorage.getItem('currentDjName');
      const show = !!(partyId && partyId !== 'manual' && partyId !== '' && djName);
      if (logoutItem) logoutItem.style.display = show ? 'flex' : 'none';
    }
    
    // ✅ Logout-Funktion: Verlässt die Party und setzt alles zurück
    async function logoutFromParty() {
      // ✅ Schließe Drawer-Menü zuerst
      closeDrawer();
      
      // ✅ Hole Übersetzungen für Modal
      let confirmTitle = 'Leave party?';
      let confirmMessage = 'Do you really want to leave the party?';
      let confirmYes = 'Yes';
      let confirmNo = 'No';
      confirmTitle = t('logout_confirm_title', confirmTitle);
      confirmMessage = t('logout_confirm_message', confirmMessage);
      confirmYes = t('logout_confirm_yes', confirmYes);
      confirmNo = t('logout_confirm_no', confirmNo);
      
      // ✅ Zeige Custom Modal (Alarm-Look: Rot)
      return new Promise((resolve) => {
        // Erstelle Modal-Overlay
        const overlay = document.createElement('div');
        overlay.className = 'logout-modal-overlay';
        overlay.id = 'logoutModalOverlay';
        
        // Erstelle Modal-Content
        const modal = document.createElement('div');
        modal.className = 'logout-modal-content';
        
        modal.innerHTML = `
          <div class="logout-modal-icon">
            <i class="fas fa-sign-out-alt"></i>
          </div>
          <h2 class="logout-modal-title">${confirmTitle}</h2>
          <p class="logout-modal-message">${confirmMessage}</p>
          <div class="logout-modal-buttons">
            <button class="logout-modal-button logout-modal-button-yes" id="logoutModalYesBtn">
              ${confirmYes}
            </button>
            <button class="logout-modal-button logout-modal-button-no" id="logoutModalNoBtn">
              ${confirmNo}
            </button>
          </div>
        `;
        
        overlay.appendChild(modal);
        document.body.appendChild(overlay);
        
        // Event-Handler für JA-Button
        const yesBtn = document.getElementById('logoutModalYesBtn');
        yesBtn.addEventListener('click', () => {
          overlay.remove();
          performLogout();
          resolve(true);
        });
        
        // Event-Handler für NEIN-Button
        const noBtn = document.getElementById('logoutModalNoBtn');
        noBtn.addEventListener('click', () => {
          overlay.remove();
          resolve(false);
        });
        
        // Schließe Modal bei Klick außerhalb
        overlay.addEventListener('click', (e) => {
          if (e.target === overlay) {
            overlay.remove();
            resolve(false);
          }
        });
        
        // ESC-Taste schließt Modal
        const handleEsc = (e) => {
          if (e.key === 'Escape') {
            overlay.remove();
            document.removeEventListener('keydown', handleEsc);
            resolve(false);
          }
        };
        document.addEventListener('keydown', handleEsc);
      });
    }
    
    /** Overlay (PWA-Stil wie Party-Code-Modal): Party/Wunschbox beendet, dann [onContinue] (z. B. clearPartyData). */
    function vbEscapeHtmlText(s) {
      return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    function vbBoldPartyEndedName(name) {
      var t = vbEscapeHtmlText(name).replace(/\s+/g, ' ').trim();
      return t ? '<strong class="vb-party-ended-emphasis">' + t + '</strong>' : '';
    }

    function vbFillPartyEndedOverlayBody(partyNameRaw, djNameRaw) {
      var party = (partyNameRaw && String(partyNameRaw).trim()) ? String(partyNameRaw).trim() : '';
      var dj = (djNameRaw && String(djNameRaw).trim()) ? String(djNameRaw).trim() : '';
      if (party.length > 120) party = party.substring(0, 117) + '\u2026';
      if (dj.length > 80) dj = dj.substring(0, 77) + '\u2026';
      var partyBold = party ? vbBoldPartyEndedName(party) : '';
      var djBold = dj ? vbBoldPartyEndedName(dj) : '';
      var tpl;
      if (party && dj) {
        tpl = t('party_ended_wishbox_overlay_body_named_dj', 'Music requests for {party} with {dj} have ended. Thank you for joining us!');
        return tpl.split('{party}').join(partyBold).split('{dj}').join(djBold);
      }
      if (party) {
        tpl = t('party_ended_wishbox_overlay_body_named', 'Music requests for {party} have ended. Thank you for joining us!');
        return tpl.split('{party}').join(partyBold);
      }
      return t('party_ended_wishbox_overlay_body', 'Music requests for this party have ended. Thank you for joining us!');
    }

    function showPartyWishboxEndedOverlay(onContinue, partyNameRaw, djNameRaw) {
      if (document.getElementById('vbPartyEndedOverlay')) return;
      const overlay = document.createElement('div');
      overlay.className = 'party-code-error-modal-overlay';
      overlay.id = 'vbPartyEndedOverlay';
      const modal = document.createElement('div');
      modal.className = 'party-code-error-modal-content';
      const iconWrap = document.createElement('div');
      iconWrap.className = 'party-code-error-modal-icon';
      iconWrap.innerHTML = '<i class="fas fa-compact-disc"></i>';
      const h2 = document.createElement('h2');
      h2.className = 'logout-modal-title';
      h2.textContent = t('party_ended_wishbox_overlay_title', 'Request box closed');
      const p = document.createElement('p');
      p.className = 'party-code-error-modal-message vb-party-ended-overlay-message';
      p.innerHTML = vbFillPartyEndedOverlayBody(partyNameRaw, djNameRaw);
      const btnRow = document.createElement('div');
      btnRow.className = 'logout-modal-buttons';
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'party-code-error-modal-button';
      btn.id = 'vbPartyEndedOverlayCta';
      btn.textContent = t('party_ended_wishbox_overlay_cta', 'Back to home');
      var done = false;
      function finish() {
        if (done) return;
        done = true;
        document.removeEventListener('keydown', onEsc);
        var el = document.getElementById('vbPartyEndedOverlay');
        if (el) el.remove();
        try {
          if (typeof onContinue === 'function') onContinue();
        } catch (eC) {
          console.error(eC);
        }
      }
      function onEsc(e) {
        if (e.key === 'Escape') finish();
      }
      btn.addEventListener('click', function () { finish(); });
      overlay.addEventListener('click', function (e) { if (e.target === overlay) finish(); });
      document.addEventListener('keydown', onEsc);
      btnRow.appendChild(btn);
      modal.appendChild(iconWrap);
      modal.appendChild(h2);
      modal.appendChild(p);
      modal.appendChild(btnRow);
      overlay.appendChild(modal);
      document.body.appendChild(overlay);
    }

    /** Gast: Party zu Ende (Zeit/DJ) – erst Info-Overlay, dann Redirect zur Root-PWA wie [clearPartyData]. */
    function runGuestPartyEndedWishboxFlow() {
      if (document.getElementById('vbPartyEndedOverlay')) return;
      var partyName = (localStorage.getItem('currentPartyName') || localStorage.getItem('validatedPartyName') || sessionStorage.getItem('currentPartyName') || sessionStorage.getItem('validatedPartyName') || '').trim();
      var djName = (sessionStorage.getItem('currentDjName') || localStorage.getItem('currentDjName') || '').trim();
      showPartyWishboxEndedOverlay(function () {
        if (typeof clearPartyData === 'function') {
          clearPartyData(true);
        } else if (typeof updateWishboxUI === 'function') {
          updateWishboxUI();
        }
        try { sessionStorage.setItem('vb_entry_granted', '1'); } catch (eEg) {}
      }, partyName, djName);
    }

    // ✅ Reset bei beendeter Party: löscht party_id/party_name, setzt UI zurück, leitet zur Code-Eingabe
    // skipRedirect=true: Nur Storage leeren und UI zurücksetzen, ohne Redirect (z.B. für QR-Code-Wechsel)
    function clearSessionPartyData() {
      sessionStorage.removeItem('validatedPartyId');
      sessionStorage.removeItem('validatedPartyCode');
      sessionStorage.removeItem('validatedPartyName');
      sessionStorage.removeItem('currentPartyName');
      sessionStorage.removeItem('currentDjName');
      sessionStorage.removeItem('djPlanType');
      sessionStorage.removeItem('currentDjSocials');
      sessionStorage.removeItem('qrCodeProcessed');
      sessionStorage.removeItem('pendingPartyId');
      sessionStorage.removeItem('pendingPartyCode');
      sessionStorage.removeItem('pendingPartyName');
      try { sessionStorage.removeItem('vb_entry_granted'); } catch (eG) {}
      try { sessionStorage.removeItem(window.vbSessionPartyCodeKey || 'vb_session_party_code'); } catch (eVsc) {}
      try { sessionStorage.removeItem('vb_pending_join_code'); } catch (ePj) {}
      try { sessionStorage.removeItem('guestPreWishSession'); } catch (ePw) {}
      try { sessionStorage.removeItem('validatedPartyStartMs'); } catch (ePs) {}
      try { localStorage.removeItem('validatedPartyStartMs'); } catch (ePl) {}
      try { sessionStorage.removeItem('vb_party_floor_key'); } catch (eFk) {}
      try { localStorage.removeItem('vb_party_floor_key'); } catch (eFk2) {}
      try { sessionStorage.removeItem('validatedPartyDjId'); } catch (eDjS) {}
      try { localStorage.removeItem('validatedPartyDjId'); } catch (eDjL) {}
    }

    /** Gast nach Party-Ende: Session leeren, auf /vb/ bleiben (kein Redirect zur Root). */
    function vbGoToRootPwaAfterPartyEnded() {
      if (typeof clearPartyData === 'function') {
        clearPartyData(true);
      } else if (typeof updateWishboxUI === 'function') {
        updateWishboxUI();
      }
      try { sessionStorage.setItem('vb_entry_granted', '1'); } catch (eEg) {}
    }

    /** skipRedirect: nur Storage/UI, kein Redirect. endedNoticeForRoot: legacy (nicht mehr für Code-Overlay). */
    function clearPartyData(skipRedirect, endedNoticeForRoot) {
      var preserveJoin = false;
      var preservedSessionCode = null;
      var preservedPending = null;
      var preservedEntry = null;
      if (typeof vbHasAnyJoinFlowSignal === 'function' && vbHasAnyJoinFlowSignal()) {
        preserveJoin = true;
        if (!skipRedirect) {
          skipRedirect = true;
          if (window.IS_DEBUG) console.log('clearPartyData: Join-Signal — kein Redirect');
        }
        try {
          preservedSessionCode = sessionStorage.getItem(window.vbSessionPartyCodeKey || 'vb_session_party_code');
          preservedPending = sessionStorage.getItem('vb_pending_join_code');
          preservedEntry = sessionStorage.getItem('vb_entry_granted');
        } catch (ePres) {}
      }
      delete togglePartyPausedOverlay._lastPaused;
      if (window.IS_DEBUG) console.log('🧹 clearPartyData: Party beendet – lösche Speicher und setze UI zurück');
      localStorage.removeItem('validatedPartyId');
      localStorage.removeItem('validatedPartyCode');
      localStorage.removeItem('validatedPartyName');
      localStorage.removeItem('currentPartyName');
      try { localStorage.removeItem('pending_party_code'); } catch (e) {}
      try { localStorage.removeItem('guest_client_id'); } catch (e) {}
      clearSessionPartyData();
      if (preserveJoin) {
        try {
          if (preservedSessionCode) sessionStorage.setItem(window.vbSessionPartyCodeKey || 'vb_session_party_code', preservedSessionCode);
          if (preservedPending) sessionStorage.setItem('vb_pending_join_code', preservedPending);
          if (preservedEntry === '1') sessionStorage.setItem('vb_entry_granted', '1');
        } catch (eRestore) {}
      }
      vbHideFloorPicker();
      vbPendingJoinCodeForFloorPick = null;
      vbMultiFloorAvailable = false;
      isWishboxActive = false;
      isBlocked = false;
      blockedByWriteDenied = false;
      blockedByGuestRealtime = false;
      blockedByDeviceRealtime = false;
      blockedByUserRealtime = false;
      wishboxBlockGateResolved = true;
      if (typeof clearBlockStatusListeners === 'function') clearBlockStatusListeners();
      partyCodeFromUrl = null;
      currentPartyStartDate = null;
      if (typeof currentDjSocials !== 'undefined') currentDjSocials = null;
      if (typeof allTracksCache !== 'undefined') { allTracksCache.length = 0; allTracksCache = []; }
      if (typeof historyListener !== 'undefined' && historyListener) { try { historyListener(); } catch (e) {} historyListener = null; }
      updateHeaderBranding(null, null);
      updateDrawerDjName('');
      if (typeof loadDrawerLogo === 'function') loadDrawerLogo();
      if (typeof updateHeaderBasedOnLoginStatus === 'function') updateHeaderBasedOnLoginStatus();
      if (typeof updatePartyInfoLine === 'function') updatePartyInfoLine();
      if (typeof updateWishboxUI === 'function') updateWishboxUI();
      if (typeof stopWishLimitStream === 'function') stopWishLimitStream();
      if (typeof updateLogoutButtonVisibility === 'function') updateLogoutButtonVisibility();
      if (!skipRedirect) {
        if (window.IS_DEBUG) console.log('✅ clearPartyData: Redirect zur Main PWA (Party beendet / unbekannte ID).');
        console.warn('DEBUG [Auto-Login]: Redirect zur Startseite wird ausgelöst! Grund: clearPartyData (Party beendet oder unbekannte ID).');
        if (endedNoticeForRoot === true) {
          try { sessionStorage.setItem('vb_party_ended_notice', '1'); } catch (eN) {}
        }
        vbRedirectToRootPwa('clearPartyData');
      } else if (window.IS_DEBUG) {
        console.log('✅ clearPartyData: Storage geleert (ohne Redirect, z.B. QR-Code-Wechsel).');
      }
    }

    // ✅ Wird aufgerufen, wenn die Party beendet ist (manuell oder Zeit) – löscht alle Gast-Session-Daten (sauberer Logout)
    function clearGuestSessionBecausePartyEnded() {
      runGuestPartyEndedWishboxFlow();
    }

    // ✅ Führt den eigentlichen Logout durch (nach Bestätigung)
    function performLogout() {
      delete togglePartyPausedOverlay._lastPaused;
      if (window.IS_DEBUG) console.log('✅ Logout bestätigt, starte Bereinigung...');
      
      // ✅ Lösche alle Party-bezogenen Keys aus localStorage (gezielt, damit andere Einstellungen erhalten bleiben)
      localStorage.removeItem('validatedPartyId');
      localStorage.removeItem('validatedPartyCode');
      localStorage.removeItem('validatedPartyName');
      localStorage.removeItem('currentPartyName');
      try { localStorage.removeItem('pending_party_code'); } catch (e) {}
      localStorage.removeItem('pendingPartyId');
      if (window.IS_DEBUG) console.log('✅ Party-Daten aus localStorage gelöscht');
      
      // ✅ Lösche nur Party-/Session-Daten (Sprache bleibt erhalten)
      clearSessionPartyData();
      if (window.IS_DEBUG) console.log('✅ Party-/Session-Daten aus sessionStorage gelöscht (Sprache bleibt erhalten)');
      
      // ✅ Setze globale Party-Variablen zurück
      isWishboxActive = false;
      isBlocked = false;
      blockedByWriteDenied = false;
      blockedByGuestRealtime = false;
      blockedByDeviceRealtime = false;
      blockedByUserRealtime = false;
      wishboxBlockGateResolved = true;
      if (typeof clearBlockStatusListeners === 'function') clearBlockStatusListeners();
      partyCodeFromUrl = null;
      currentPartyStartDate = null;
      if (window.IS_DEBUG) console.log('✅ Globale Party-Variablen zurückgesetzt');
      
      // ✅ Vollständiger Daten-Reset: Setze alle DJ-spezifischen Variablen zurück (Memory-Leak-Schutz)
      // Social Media Variablen
      if (typeof currentDjSocials !== 'undefined') {
        currentDjSocials = null;
      }
      // Entferne auch aus sessionStorage
      sessionStorage.removeItem('currentDjSocials');
      
      // History Variablen
      if (typeof allTracksCache !== 'undefined') {
        allTracksCache.length = 0; // Array komplett leeren
        allTracksCache = [];
      }
      if (typeof currentHistoryPage !== 'undefined') {
        currentHistoryPage = 1;
      }
      if (typeof historyListener !== 'undefined' && historyListener) {
        // Stoppe History-Listener falls vorhanden
        try {
          historyListener();
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Stoppen des History-Listeners:', e);
        }
        historyListener = null;
      }
      
      // ✅ Zusätzliche globale Variablen zurücksetzen (falls vorhanden)
      if (typeof tracksPerPage !== 'undefined') {
        tracksPerPage = VB_DEFAULT_RESULTS_PER_PAGE;
      }
      
      if (window.IS_DEBUG) console.log('✅ DJ-spezifische Variablen zurückgesetzt (Socials, History) - Memory-Leak-Schutz aktiv');
      
      // ✅ Header-Säuberung: Verstecke DJ-Branding sofort und leere komplett
      updateHeaderBranding(null, null);
      // ✅ Aktualisiere Header basierend auf Login-Status (zeigt jetzt VibesBox-Text)
      updateHeaderBasedOnLoginStatus();
      // ✅ Verstecke Party-Info-Zeile beim Logout
      updatePartyInfoLine();
      
      // ✅ Stoppe alle aktiven Streams beim Logout
      if (typeof stopWishLimitStream === 'function') {
        stopWishLimitStream();
      }
      
      // ✅ Redirect zur Main PWA nach Logout (Zurück-Button führt nicht in leere Wunschbox)
      if (window.IS_DEBUG) console.log('🔄 Logout: Redirect zur Main PWA...');
      console.warn('DEBUG [Auto-Login]: Redirect zur Startseite wird ausgelöst! Grund: performLogout (User-Logout).');
      window.location.href = '/';
      
      // ✅ Header-Säuberung: Leere Branding-Elemente komplett im DOM
      const headerByText = document.getElementById('headerByText');
      if (headerByText) {
        headerByText.textContent = '';
        headerByText.style.display = 'none';
        headerByText.style.setProperty('display', 'none', 'important');
      }
      
      const headerDjLogo = document.getElementById('headerDjLogo');
      if (headerDjLogo) {
        headerDjLogo.src = '';
        headerDjLogo.style.display = 'none';
        headerDjLogo.style.setProperty('display', 'none', 'important');
      }
      
      const headerDjName = document.getElementById('headerDjName');
      if (headerDjName) {
        headerDjName.textContent = '';
        headerDjName.style.display = 'none';
        headerDjName.style.setProperty('display', 'none', 'important');
      }
      
      // ✅ Header-Säuberung: Rufe auch updateHeaderDjName auf (falls vorhanden)
      if (typeof updateHeaderDjName === 'function') {
        updateHeaderDjName(null, null);
      }
      
      // ✅ UI-Reset: Verstecke DJ-Namen im Drawer
      updateDrawerDjName(null);
      
      // ✅ UI-Reset: Verstecke Logout-Button
      updateLogoutButtonVisibility();
      
      // ✅ Branding-Zeile verstecken beim Logout
      const brandingLine = document.getElementById('brandingLine');
      if (brandingLine) {
        brandingLine.style.display = 'none';
      }
      
      // ✅ Reset State: Setze alle UI-Zustände zurück
      const errorMessage = document.getElementById('errorMessage');
      if (errorMessage) {
        errorMessage.textContent = '';
        errorMessage.style.display = 'none';
      }
      
      const wishForm = document.getElementById('wishForm');
      if (wishForm) {
        wishForm.style.display = 'none';
        wishForm.reset(); // ✅ Formular zurücksetzen
      }
      
      const successMessage = document.getElementById('successMessage');
      if (successMessage) {
        successMessage.style.display = 'none';
        successMessage.classList.remove('show');
      }
      var formContainer = document.querySelector('.form-container');
      if (formContainer) formContainer.classList.remove('success-open');
      
      const blockedMessage = document.getElementById('wishboxBlockedMessage');
      if (blockedMessage) {
        blockedMessage.style.display = 'none';
      }
      
      const prePartyWaitMode = document.getElementById('prePartyWaitMode');
      if (prePartyWaitMode) {
        prePartyWaitMode.style.display = 'none';
        stopPrePartyCountdown();
      }
      
      // ✅ Reset State: Setze Erfolgs-Flag zurück (damit updateWishboxUI() nicht übersprungen wird)
      window.isSuccessActive = false;
      
      // ✅ DOM-Säuberung: Leere Social-Links-Container
      const socialLinksContainer = document.querySelector('.social-links');
      if (socialLinksContainer) {
        socialLinksContainer.innerHTML = '';
        if (window.IS_DEBUG) console.log('✅ Social-Links-Container geleert');
      }
      
      // ✅ DOM-Säuberung: Leere History-Liste
      const historyList = document.getElementById('historyList');
      if (historyList) {
        historyList.innerHTML = '';
        if (window.IS_DEBUG) console.log('✅ History-Liste geleert');
      }
      
      // ✅ DOM-Säuberung: Leere History-Pagination
      const historyPagination = document.getElementById('historyPagination');
      if (historyPagination) {
        historyPagination.innerHTML = '';
        if (window.IS_DEBUG) console.log('✅ History-Pagination geleert');
      }
      
      // ✅ URL bereinigen (falls Party-Code noch in URL steht)
      window.history.replaceState({}, document.title, (typeof window.vbNormalizedWishboxPathname === 'function' ? window.vbNormalizedWishboxPathname() : window.location.pathname));
      
      // ✅ Navigation: Leite zur Startseite (wunschbox) zurück
      // showPage('wunschbox') ruft automatisch updateWishboxUI() auf,
      // welches basierend auf isWishboxActive = false das Eingabefeld anzeigt
      showPage('wunschbox');
      
      if (window.IS_DEBUG) console.log('✅ Logout abgeschlossen, UI zur Eingabemaske gewechselt');
    }
    
    // ✅ Funktion zum Aktualisieren des Header-Brandings (dynamisch basierend auf Login-Status)
    function updateHeaderBranding(userData = null, socialsData = null) {
      const headerVibesboxText = document.getElementById('headerVibesboxText');
      const headerPartyName = document.getElementById('headerPartyName');
      const headerDjInfo = document.getElementById('headerDjInfo');
      const headerByText = document.getElementById('headerByText');
      const headerDjName = document.getElementById('headerDjName');
      const headerPartyInfo = document.getElementById('headerPartyInfo');
      const headerPartyInfoText = document.getElementById('headerPartyInfoText');
      const headerPartyInfoName = document.getElementById('headerPartyInfoName');
      const headerPartyStartRow = document.getElementById('headerPartyStartRow');
      const headerPartyStartLabel = document.getElementById('headerPartyStartLabel');
      const headerPartyStartValue = document.getElementById('headerPartyStartValue');
      const preWishHeader =
        typeof isPreWishUiActive === 'function' && isPreWishUiActive();
      
      if (!headerVibesboxText || !headerPartyName || !headerDjInfo || !headerByText || !headerDjName) {
        if (window.IS_DEBUG) console.warn('⚠️ Header-Elemente nicht gefunden');
        return;
      }
      
      // ✅ Prüfe Login-Status: Party-ID vorhanden?
      const validatedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
      const isLoggedIn = validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '';
      
      // ✅ Prüfe, ob ein DJ-Name im sessionStorage vorhanden ist
      const djName = sessionStorage.getItem('currentDjName');
      const partyName = sessionStorage.getItem('validatedPartyName') || localStorage.getItem('validatedPartyName') || null;
      
      if (window.IS_DEBUG) console.log('🔍 updateHeaderBranding Debug:', {
        isLoggedIn,
        djName,
        validatedPartyId
      });
      
      // ✅ Obere Zeile: Immer "VibesBox" anzeigen (fix)
      headerVibesboxText.style.display = 'block';
      headerPartyName.style.display = 'none'; // ✅ Party-Name wird nicht mehr verwendet
      
      if (isLoggedIn) {
        if (djName) {
          const displayDjName = djName || 'VibesBox DJ';
          let byText = 'von';
          if (typeof window.getTranslation === 'function') {
            byText = window.getTranslation('menu_by') || 'by';
          } else if (typeof window.translations !== 'undefined') {
            const currentLang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
            byText = (window.translations[currentLang] && window.translations[currentLang]['menu_by']) || 'by';
          }
          headerByText.textContent = byText;
          headerDjName.textContent = displayDjName;
          headerDjInfo.style.display = 'flex';
        } else {
          headerDjInfo.style.display = 'none';
        }

        const validPartyName =
          partyName &&
          partyName.trim() !== '' &&
          partyName !== 'Deine Party' &&
          partyName !== 'Your Party';
        if (headerPartyInfo && headerPartyInfoText && headerPartyInfoName && validPartyName) {
          let infoText = preWishHeader
            ? 'Advance requests for the party:'
            : 'You are at the party:';
          const infoKey = preWishHeader ? 'pre_wish_header_for_party' : 'party_info_text';
          try {
            if (typeof window.getTranslation === 'function') {
              infoText = window.getTranslation(infoKey) || infoText;
            } else if (typeof t === 'function') {
              infoText = t(infoKey, infoText);
            } else if (typeof window.translations !== 'undefined') {
              const currentLang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
              infoText = (window.translations[currentLang] && window.translations[currentLang][infoKey]) || infoText;
            }
          } catch (e) {}
          headerPartyInfo.classList.toggle('pre-wish-header', preWishHeader);
          headerPartyInfoText.textContent = (infoText || '').trim();
          headerPartyInfoName.textContent = partyName.trim();
          if (preWishHeader && headerPartyStartRow && headerPartyStartLabel && headerPartyStartValue) {
            const startDate = getStoredPartyStartDate();
            let startLabel = 'Party starts:';
            try {
              if (typeof window.getTranslation === 'function') {
                startLabel = window.getTranslation('pre_wish_party_start_label') || startLabel;
              } else if (typeof t === 'function') {
                startLabel = t('pre_wish_party_start_label', startLabel);
              }
            } catch (eStart) {}
            if (startDate) {
              headerPartyStartLabel.textContent = startLabel;
              headerPartyStartValue.textContent = formatPreWishPartyStartLocalized(startDate);
              headerPartyStartRow.style.display = 'flex';
            } else {
              headerPartyStartRow.style.display = 'none';
            }
          } else if (headerPartyStartRow) {
            headerPartyStartRow.style.display = 'none';
          }
          headerPartyInfo.style.display = 'flex';
        } else if (headerPartyInfo) {
          headerPartyInfo.style.display = 'none';
        }
        if (window.IS_DEBUG) {
          console.log('✅ Header: Party-Info', preWishHeader ? '(Vorab)' : '(live)', validPartyName ? partyName : '—');
        }
      } else {
        headerDjInfo.style.display = 'none';
        if (headerPartyInfo) headerPartyInfo.style.display = 'none';
        if (window.IS_DEBUG) console.log('✅ VibesBox-Text im Header angezeigt (nicht eingeloggt)');
      }
    }
    
    // ✅ Funktion zum Aktualisieren des Headers basierend auf Login-Status
    function updateHeaderBasedOnLoginStatus() {
      // ✅ Rufe updateHeaderBranding auf (ohne Parameter, nutzt sessionStorage)
      updateHeaderBranding();
      // ✅ Aktualisiere auch Party-Info-Zeile
      updatePartyInfoLine();
    }
    
    // ✅ Für Hot-Swap (vb-url-lang.js pwaHotSwapLanguage): Globale Zugriffbarkeit
    window.updateHeaderBranding = updateHeaderBranding;
    window.updateDrawerCurrentLanguage = updateDrawerCurrentLanguage;
    
    /** Wie Flutter [isHttpImageUrl]: nur http(s)-URLs für DJ-Logo in der Wunschbox. */
    function isHttpImageUrl(url) {
      if (typeof url !== 'string') return false;
      const trimmed = url.trim();
      return trimmed.startsWith('http://') || trimmed.startsWith('https://');
    }

    function getWishboxBrandingIntroText() {
      const fallback = 'Send your song request to';
      if (typeof window.getTranslation === 'function') {
        const tr = window.getTranslation('pwa_request_header_text');
        if (tr && tr !== 'pwa_request_header_text') return tr;
      }
      if (typeof window.t === 'function') {
        const tr = window.t('pwa_request_header_text', fallback);
        if (tr && tr !== 'pwa_request_header_text') return tr;
      }
      if (typeof translations !== 'undefined') {
        const lang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'de';
        const tr = translations[lang] && translations[lang]['pwa_request_header_text'];
        if (tr) return tr;
      }
      return fallback;
    }

    function resolveDjNameForWishboxBranding(partyData) {
      let djName = (sessionStorage.getItem('currentDjName') || '').trim();
      if (djName) return djName;
      return vbExtractDjNameFromPartyData(partyData);
    }

    async function ensureDjPlanTypeForBranding(partyData) {
      let plan = (sessionStorage.getItem('djPlanType') || '').toLowerCase().trim();
      if (plan) return plan;
      const uid =
        partyData && typeof partyData.created_by === 'string'
          ? partyData.created_by.trim()
          : '';
      if (!uid || typeof fetchPublicDjProfile !== 'function') return 'free';
      try {
        const userData = await fetchPublicDjProfile(uid);
        plan =
          userData && userData.planType != null && String(userData.planType).trim() !== ''
            ? String(userData.planType).toLowerCase().trim()
            : 'free';
        sessionStorage.setItem('djPlanType', plan);
      } catch (e) {
        plan = 'free';
      }
      return plan;
    }

    function vbExtractDjNameFromPartyData(partyData) {
      if (!partyData || typeof partyData !== 'object') return '';
      var raw = partyData.dj_name || partyData.display_name || partyData.name;
      return raw ? String(raw).trim() : '';
    }

    function vbSetBrandingDjLogo(imgEl, url, djName) {
      if (!imgEl) return;
      if (!isHttpImageUrl(url)) {
        imgEl.style.display = 'none';
        imgEl.removeAttribute('src');
        imgEl.removeAttribute('alt');
        imgEl.onload = null;
        imgEl.onerror = null;
        return;
      }
      imgEl.style.display = 'none';
      imgEl.alt = djName ? ('Logo ' + djName) : 'DJ Logo';
      imgEl.onload = function () {
        imgEl.style.display = 'block';
      };
      imgEl.onerror = function () {
        imgEl.style.display = 'none';
        imgEl.removeAttribute('src');
      };
      imgEl.src = String(url).trim();
    }

    /** Zeile 1: Einleitung, Zeile 2: DJ-Name, Zeile 3: Logo (nur Pro/Trial + dj_logo). */
    function applyWishboxBrandingFromParty(partyData, planType) {
      const brandingHeaderIntro =
        document.getElementById('brandingHeaderIntro') ||
        document.querySelector('#brandingLine .branding-header-text');
      const brandingDjName = document.getElementById('brandingDjName');
      const brandingDjLogo = document.getElementById('brandingDjLogo');

      if (brandingHeaderIntro) {
        brandingHeaderIntro.textContent = getWishboxBrandingIntroText();
        brandingHeaderIntro.style.display = 'block';
        brandingHeaderIntro.style.visibility = 'visible';
      }

      const djName = resolveDjNameForWishboxBranding(partyData);
      if (brandingDjName) {
        if (djName) {
          brandingDjName.textContent = djName;
          brandingDjName.style.display = 'block';
          brandingDjName.style.visibility = 'visible';
        } else {
          brandingDjName.textContent = '';
          brandingDjName.style.display = 'none';
        }
      }

      const plan = (planType || sessionStorage.getItem('djPlanType') || 'free').toLowerCase().trim();
      const showDjLogo = plan !== 'free';
      const djLogoRaw = partyData && partyData.dj_logo;
      vbSetBrandingDjLogo(
        brandingDjLogo,
        showDjLogo && isHttpImageUrl(djLogoRaw) ? djLogoRaw : null,
        djName
      );
    }

    /** Branding vollständig (Name + Plan + Logo + Socials) — vor erster Formular-Anzeige awaiten. */
    async function vbApplyWishboxBrandingReady(partyId, partyData) {
      if (!partyId || !partyData) return;
      var createdByUid = (typeof partyData.created_by === 'string') ? partyData.created_by.trim() : '';
      if (!createdByUid && partyData.dj_code != null) {
        createdByUid = String(partyData.dj_code).trim();
      }
      try {
        await vbHydratePartyDjSession(partyId, partyData, createdByUid);
      } catch (eBr) {
        if (window.IS_DEBUG) console.warn('vbApplyWishboxBrandingReady:', eBr);
        applyWishboxBrandingFromParty(partyData || window.__vbCachedPartyBrandingData || null, sessionStorage.getItem('djPlanType'));
      }
    }

    // ✅ Funktion zum Aktualisieren der Branding-Zeile (ganz oben)
    async function updateBrandingLine(partyDataHint) {
      try {
        const brandingLine = document.getElementById('brandingLine');
        if (!brandingLine) {
          if (window.IS_DEBUG) console.warn('⚠️ Branding-Zeile Element nicht gefunden');
          return;
        }

        if (window.isSuccessActive) {
          brandingLine.style.display = 'none';
          brandingLine.style.visibility = 'hidden';
          return;
        }

        const validatedPartyId =
          localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
        const isLoggedIn = validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '';

        if (!isLoggedIn || !isWishboxActive) {
          brandingLine.style.display = 'none';
          return;
        }

        brandingLine.style.display = 'flex';
        brandingLine.style.visibility = 'visible';

        var hinted = partyDataHint || window.__vbCachedPartyBrandingData || null;
        if (hinted) {
          applyWishboxBrandingFromParty(hinted, sessionStorage.getItem('djPlanType'));
        } else {
          applyWishboxBrandingFromParty(null, sessionStorage.getItem('djPlanType'));
        }

        const savedPartyId = validatedPartyId;
        if (!savedPartyId || savedPartyId === 'manual' || savedPartyId === '') return;

        if (
          !window.firebaseDb ||
          typeof window.firebaseCollection !== 'function' ||
          typeof window.firebaseDoc !== 'function' ||
          typeof window.firebaseGetDoc !== 'function'
        ) {
          void vbWaitForFirebaseReady(10000).then(function () {
            if (isWishboxActive) void updateBrandingLine(hinted);
          });
          return;
        }

        var partyData = hinted;
        if (!partyData) {
          const partyRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'parties'),
            savedPartyId
          );
          const partyDoc = await window.firebaseGetDoc(partyRef);
          if (!partyDoc.exists()) return;
          partyData = partyDoc.data();
          window.__vbCachedPartyBrandingData = partyData;
        }

        const planType = await ensureDjPlanTypeForBranding(partyData);
        applyWishboxBrandingFromParty(partyData, planType);

        if (typeof loadDrawerLogo === 'function') {
          loadDrawerLogo();
        }
      } catch (e) {
        if (window.IS_DEBUG) console.warn('⚠️ Fehler in updateBrandingLine:', e);
        applyWishboxBrandingFromParty(
          partyDataHint || window.__vbCachedPartyBrandingData || null,
          sessionStorage.getItem('djPlanType')
        );
      }
    }
    window.updateBrandingLine = updateBrandingLine;
    
    // ✅ Blaue Trennzeile: nur Sichtbarkeit sichern (kein Text, reines Design-Element 25px)
    function updatePartyInfoLine() {
      try {
        const partyInfoLine = document.getElementById('partyInfoLine');
        if (!partyInfoLine) return;
        partyInfoLine.style.display = 'block';
      } catch (error) {
        console.error('❌ Fehler in updatePartyInfoLine:', error);
        const partyInfoLine = document.getElementById('partyInfoLine');
        if (partyInfoLine) partyInfoLine.style.display = 'block';
      }
    }
    
    // ✅ ID-Recovery: Beim Laden der Seite sofort prüfen und Party-ID wiederherstellen
    function recoverPartyIdFromLocalStorage() {
      const validatedPartyId = localStorage.getItem('validatedPartyId');
      if (validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '') {
        if (window.IS_DEBUG) console.log('✅ ID-Recovery: Gefundene Party-ID im localStorage:', validatedPartyId);
        // ✅ Schreibe sofort in sessionStorage
        sessionStorage.setItem('validatedPartyId', validatedPartyId);
        if (window.IS_DEBUG) console.log('✅ ID-Recovery: Party-ID in sessionStorage gespeichert');
        // ✅ Stelle auch party_name wieder her
        const validatedPartyName = localStorage.getItem('validatedPartyName');
        if (validatedPartyName) {
          sessionStorage.setItem('validatedPartyName', validatedPartyName);
          if (window.IS_DEBUG) console.log('✅ ID-Recovery: Party-Name in sessionStorage gespeichert:', validatedPartyName);
        }
        return validatedPartyId;
      }
      if (window.IS_DEBUG) console.log('⚠️ ID-Recovery: Keine Party-ID im localStorage gefunden');
      return null;
    }
    
    // ✅ ID-Recovery: Stelle Party-ID sofort wieder her
    const recoveredPartyId = recoverPartyIdFromLocalStorage();
    
    // Initialisiere UI sofort beim Laden (bevor Prüfung läuft)
    initDrawerLanguageSelector();
    
    // ✅ Session-basiert: Lade DJ-Namen aus sessionStorage beim Seitenstart
    // Wenn sessionStorage leer ist, wird checkWishboxStatus() den Namen extrahieren
    const savedDjName = sessionStorage.getItem('currentDjName');
    if (savedDjName) {
      if (window.IS_DEBUG) console.log('✅ DJ-Name aus sessionStorage beim Seitenstart geladen:', savedDjName);
      updateDrawerDjName(savedDjName);
      // ✅ Header-Branding: Versuche auch Header zu aktualisieren (falls Daten vorhanden)
      updateHeaderBranding();
      // ✅ Zeige Logout-Button (Party ist aktiv)
      updateLogoutButtonVisibility();
    } else {
      if (window.IS_DEBUG) console.log('🔍 Kein DJ-Name in sessionStorage, warte auf checkWishboxStatus()...');
      updateDrawerDjName(null);
      updateHeaderBranding();
      // ✅ Party-Info-Zeile trotzdem prüfen (falls Party-Name vorhanden)
      updatePartyInfoLine();
      updateLogoutButtonVisibility();
    }
    
    // ✅ Initialisiere Party-Info-Zeile beim Seitenstart
    updatePartyInfoLine();
    // ✅ Initialisiere Branding-Zeile beim Seitenstart (nach Firebase ggf. erneut)
    updateBrandingLine();
    window.addEventListener('firebaseGlobalsReady', function () {
      if (isWishboxActive && typeof updateBrandingLine === 'function') {
        void updateBrandingLine(window.__vbCachedPartyBrandingData || null);
      }
    }, { once: true });
    window.addEventListener('translationsReady', function () {
      if (isWishboxActive && typeof updateBrandingLine === 'function') {
        void updateBrandingLine(window.__vbCachedPartyBrandingData || null);
      }
    });
    
    // ✅ Initial-Check: Zeige standardmäßig Wunschbox-Seite
    // Da beim Start ohne ID isWishboxActive auf false steht, wird updateWishboxUI() 
    // dann korrekt das Eingabefeld (wishboxInactiveMessage) einblenden
    showPage('wunschbox');
    

    // Musikdatenbank: Speichere Track in separaten Collections
    async function saveToMusicDatabase(spotifyTrack, title, artist, djId = null, partyId = null) {
      // Extrahiere Browser-Sprache (z.B. 'de', 'en')
      const browserLanguage = navigator.language ? navigator.language.split('-')[0].toLowerCase() : 'unknown';
      if (window.IS_DEBUG) console.log('💾 saveToMusicDatabase aufgerufen mit:', {
        spotifyTrack: spotifyTrack,
        title: title,
        artist: artist,
        djId: djId
      });
      
      // Validierung: Nur spotify_id, title und artist sind Pflicht
      // duration_ms und genres sind optional
      if (!spotifyTrack.id) {
        if (window.IS_DEBUG) console.log('⚠️ Keine Spotify-ID vorhanden, überspringe Musikdatenbank-Speicherung');
        if (window.IS_DEBUG) console.log('  - spotifyTrack.id:', spotifyTrack.id);
        return;
      }
      
      if (!title || !artist) {
        if (window.IS_DEBUG) console.log('⚠️ Titel oder Artist fehlt, überspringe Musikdatenbank-Speicherung');
        if (window.IS_DEBUG) console.log('  - title:', title);
        if (window.IS_DEBUG) console.log('  - artist:', artist);
        return;
      }
      
      const requestData = {
        spotify_id: spotifyTrack.id,
        title: title,
        artist: artist,
        duration_ms: spotifyTrack.duration_ms || null, // Optional
        genres: spotifyTrack.genres || [], // Optional - Cloud Function holt sie vom Artist falls leer
        artist_ids: spotifyTrack.artist_ids || [], // Artist-IDs für Genre-Abruf in Cloud Function
        dj_id: djId || null, // DJ-ID für Statistik
        browser_language: browserLanguage // Browser-Sprache für Statistik (z.B. 'de', 'en')
      };
      
      if (window.IS_DEBUG) console.log('💾 saveToMusicDatabase: Sende Daten (duration_ms optional):', {
        spotify_id: requestData.spotify_id,
        title: requestData.title,
        artist: requestData.artist,
        duration_ms: requestData.duration_ms,
        genres: requestData.genres
      });
      
      if (window.IS_DEBUG) console.log('📤 Sende Daten an Cloud Function:', requestData);
      
      try {
        // Rufe Cloud Function auf, die die Musikdatenbank-Logik implementiert
        // Nutze die URL aus der Config (falls vorhanden) oder die hardcodierte URL
        const functionUrl = 'https://us-central1-dj-ollerganove.cloudfunctions.net/saveToMusicDatabase';
        const response = await fetch(functionUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(requestData)
        });
        
        if (window.IS_DEBUG) console.log('📥 Cloud Function Response Status:', response.status);
        
        if (!response.ok) {
          const errorText = await response.text();
          console.error('❌ Cloud Function Fehler:', errorText);
          throw new Error('Error saving to music database: ' + errorText);
        }

        const result = await response.json();
        if (window.IS_DEBUG) console.log('✅ Track erfolgreich in Musikdatenbank gespeichert:', result);
        
        // Speichere browser_language im Wunsch-Dokument, falls vorhanden (nur mit party_id-Filter für Security)
        const browserLang = result.browser_language;
        if (browserLang && browserLang !== 'unknown' && partyId && partyId !== 'manual') {
          try {
            const wishesRef = window.vbPartyWishesCollection(partyId);
            const wishesQuery = window.firebaseQuery(
              wishesRef,
              window.firebaseWhere('spotify_id', '==', spotifyTrack.id),
              window.firebaseOrderBy('createdAt', 'desc'),
              window.firebaseLimit(1)
            );
            const wishesSnapshot = await window.firebaseGetDocs(wishesQuery);
            
            if (wishesSnapshot.docs.length > 0) {
              const wishDocRef = window.vbPartyWishDoc(partyId, wishesSnapshot.docs[0].id);
              await window.firebaseSetDoc(wishDocRef, {
                browser_language: browserLang
              }, { merge: true });
              if (window.IS_DEBUG) console.log('✅ browser_language im Wunsch-Dokument gespeichert:', browserLang);
            }
          } catch (e) {
            console.error('⚠️ Fehler beim Speichern von browser_language (nicht kritisch):', e);
          }
        }
      } catch (error) {
        console.error('Fehler beim Speichern in Musikdatenbank:', error);
        throw error;
      }
    }

    function vbLog() {
      if (window.IS_DEBUG && window.console && typeof window.console.log === 'function') {
        var a = Array.prototype.slice.call(arguments);
        a.unshift('DEBUG PWA:');
        window.console.log.apply(window.console, a);
      }
    }

    function vbWishboxTranslationKeyForPartyCheck(messageKey) {
      if (messageKey === 'party_code_ambiguous' || messageKey === (window.MESSAGE_KEY_AMBIGUOUS || '')) {
        return 'party_code_ambiguous';
      }
      const map = {
        main_code_error_invalid: 'party_unknown',
        party_ended: 'party_ended',
        party_not_started: 'party_not_started',
        main_code_error_rate_limit: 'main_code_error_rate_limit',
        main_code_error_timeout: 'error_load_failed_message',
      };
      return map[messageKey] || messageKey || 'party_unknown';
    }

    function vbHasWishboxEntryPermission() {
      try {
        if (typeof window.vbGetSessionPartyCode8 === 'function' && window.vbGetSessionPartyCode8()) {
          return true;
        }
        if (typeof vbHasPendingJoinCode8 === 'function' && vbHasPendingJoinCode8()) {
          return true;
        }
        const vid = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
        if (vid && vid !== 'manual' && vid !== '' && typeof validatePartyId === 'function' && validatePartyId(vid)) {
          return true;
        }
        if (sessionStorage.getItem('vb_entry_granted') === '1') return true;
      } catch (e) {}
      return false;
    }

    async function vbWaitForFirebaseReady(maxMs) {
      const cap = maxMs || 15000;
      if (window.firebaseDb && typeof window.firebaseGetDoc === 'function') return;
      await new Promise((resolve) => {
        if (window.firebaseDb && typeof window.firebaseGetDoc === 'function') {
          resolve();
          return;
        }
        const deadline = Date.now() + cap;
        const onReady = () => resolve();
        window.addEventListener('firebaseGlobalsReady', onReady, { once: true });
        (function tick() {
          if (window.firebaseDb && typeof window.firebaseGetDoc === 'function') {
            resolve();
            return;
          }
          if (Date.now() > deadline) {
            resolve();
            return;
          }
          setTimeout(tick, 16);
        })();
      });
    }

    /** Party nach checkPartyCode in Storage + UI übernehmen (party_snapshot aus checkPartyCode, kein extra getDoc). */
    async function vbFinalizePartyJoin(codeFromUrl, checkResult) {
      const data = checkResult.data;
      const partyId = data.party_id;
      const canonicalPartyCode = (data.party_code != null && String(data.party_code).trim() !== '')
        ? String(data.party_code).trim()
        : codeFromUrl;
      const partyName = data.party_name || null;

      localStorage.setItem('validatedPartyId', partyId);
      sessionStorage.setItem('validatedPartyId', partyId);
      localStorage.setItem('validatedPartyCode', canonicalPartyCode);
      sessionStorage.setItem('validatedPartyCode', canonicalPartyCode);
      try { localStorage.removeItem('pending_party_code'); } catch (e) {}
      try { localStorage.removeItem('pendingPartyId'); } catch (e) {}

      if (partyName && partyName.trim() !== '' && partyName !== 'Deine Party' && partyName !== 'Your Party') {
        sessionStorage.setItem('validatedPartyName', partyName.trim());
        localStorage.setItem('validatedPartyName', partyName.trim());
        sessionStorage.setItem('currentPartyName', partyName.trim());
        localStorage.setItem('currentPartyName', partyName.trim());
      } else {
        sessionStorage.removeItem('validatedPartyName');
        localStorage.removeItem('validatedPartyName');
      }

      const partyCodeInput = document.getElementById('partyCodeInput');
      if (partyCodeInput) partyCodeInput.value = canonicalPartyCode;
      try {
        const cCanon = String(canonicalPartyCode).replace(/\D/g, '').substring(0, 8);
        if (cCanon.length === 8) sessionStorage.setItem('vb_session_party_code', cCanon);
      } catch (eVsc2) {}

      let partyDataResolved = {};
      const snap = data.party_snapshot;
      if (snap && typeof snap === 'object' && Object.keys(snap).length > 0) {
        partyDataResolved = snap;
      } else {
        try {
          const partyRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'parties'),
            partyId,
          );
          const partyDoc = await window.firebaseGetDoc(partyRef);
          if (partyDoc.exists()) partyDataResolved = partyDoc.data();
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ vbFinalizePartyJoin: Party-Dokument optional:', e);
        }
      }

      try {
        var floorKey = (typeof window.vbEffectiveFloorKey === 'function')
          ? window.vbEffectiveFloorKey(partyDataResolved)
          : 'default';
        sessionStorage.setItem('vb_party_floor_key', floorKey);
        localStorage.setItem('vb_party_floor_key', floorKey);
      } catch (eFk) { /* ignore */ }

      var createdByUid = (partyDataResolved.created_by && typeof partyDataResolved.created_by === 'string')
        ? partyDataResolved.created_by.trim()
        : ((partyDataResolved.dj_code != null) ? String(partyDataResolved.dj_code).trim() : '');

      const seJoin = vbWishboxStartEndFromPartyData(partyDataResolved);
      const nowJoin = new Date();
      if (seJoin.startDate && nowJoin < seJoin.startDate
          && typeof window.vbIsPreWishWindowOpen === 'function'
          && window.vbIsPreWishWindowOpen(partyDataResolved, nowJoin)) {
        try { sessionStorage.setItem('guestPreWishSession', '1'); } catch (e) {}
        vbBindWishboxFromPartyData(partyDataResolved);
        if (typeof showLoader === 'function') showLoader(false);
        void vbHydratePartyDjSession(partyId, partyDataResolved, createdByUid).catch(function (ePw) {
          if (window.IS_DEBUG) console.warn('vbFinalizePartyJoin preWish branding:', ePw);
        });
        showPreWishOrPausedMode(partyDataResolved, partyDataResolved.party_name || partyName || 'Party', seJoin.startDate);
        vbRunBlockCheckAfterJoin(partyId);
        return { partyId, canonicalPartyCode, partyDataResolved, preWishMode: true };
      }

      isWishboxActive = true;
      clearPreWishMode();
      vbBindWishboxFromPartyData(partyDataResolved);
      if (typeof showLoader === 'function') showLoader(false);
      const isPaused = partyDataResolved.is_paused === true;
      togglePartyPausedOverlay(isPaused);
      updateWishboxUI();
      void vbHydratePartyDjSession(partyId, partyDataResolved, createdByUid).catch(function (eBr) {
        if (window.IS_DEBUG) console.warn('⚠️ vbFinalizePartyJoin: Branding:', eBr);
      });
      unawaited(vbRefreshMultiFloorAvailable());
      return { partyId, canonicalPartyCode, partyDataResolved };
    }

    function vbWishboxStartEndFromPartyData(data) {
      let startDate = null;
      let endDate = null;
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
      return { startDate, endDate };
    }

    /** Gezielter Join-Code-Lookup statt Scan aller aktiven Partys (schneller, v. a. iOS). */
    async function vbTryActivatePartyByJoinCode(codeToCheck, partyCodeFromUrl) {
      const allDocs = await vbCollectAllPartyDocsByJoinCode(codeToCheck);
      const now = new Date();
      const isJoinable = typeof window.vbIsPartyGuestJoinable === 'function'
        ? window.vbIsPartyGuestJoinable
        : function () { return false; };
      const resolveFn = typeof window.vbResolveJoinCodeLookup === 'function'
        ? window.vbResolveJoinCodeLookup
        : null;
      const resolved = resolveFn
        ? resolveFn(allDocs, now, codeToCheck)
        : { action: 'not_found' };

      if (resolved.action === 'ambiguous') {
        const ambKey = (typeof window.MESSAGE_KEY_AMBIGUOUS === 'string')
          ? window.MESSAGE_KEY_AMBIGUOUS
          : 'party_code_ambiguous';
        if (typeof showPartyStatusModal === 'function') {
          showPartyStatusModal(
            'invalid',
            (typeof getTranslation === 'function' ? getTranslation(ambKey) : null) || ambKey,
          );
        }
        return false;
      }

      if (resolved.action === 'select_floor'
          && resolved.floor_options
          && vbShouldShowFloorPickerForOptions(resolved.floor_options)) {
        await vbShowFloorPickerForJoinCode(codeToCheck, resolved.floor_options, null);
        if (partyCodeFromUrl && !sessionStorage.getItem('qrCodeProcessed')) {
          if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') {
            window.vbReplaceStateStripPartyCodeKeepLang();
          }
        }
        return true;
      }

      const partyDoc = resolved.action === 'join' ? resolved.doc : null;
      if (!partyDoc) return false;

      const data = partyDoc.data();
      const canonicalCode = data.party_code != null ? String(data.party_code) : codeToCheck;

      const endedLifecycle = data.lifecycle_status === 'finished' || data.finished_at != null;
      const endedStatus = data.status === 'beendet' || data.status === 'ended';
      let ended = endedLifecycle || endedStatus;
      const se = vbWishboxStartEndFromPartyData(data);
      if (!ended && se.endDate && now > se.endDate) ended = true;
      if (ended) return false;

      if (se.startDate && now < se.startDate) {
        currentPartyStartDate = se.startDate;
        if (typeof window.vbIsPreWishWindowOpen === 'function' && window.vbIsPreWishWindowOpen(data, now)) {
          showPreWishOrPausedMode(data, data.party_name || 'Party', se.startDate);
        } else {
          showPrePartyWaitMode(data.party_name || 'Party', se.startDate);
        }
        localStorage.setItem('validatedPartyId', partyDoc.id);
        sessionStorage.setItem('validatedPartyId', partyDoc.id);
        sessionStorage.setItem('validatedPartyCode', canonicalCode);
        localStorage.setItem('validatedPartyCode', canonicalCode);
        try { localStorage.removeItem('pending_party_code'); } catch (e) {}
        const partyCodeInput = document.getElementById('partyCodeInput');
        if (partyCodeInput) partyCodeInput.value = canonicalCode;
        if (partyCodeFromUrl && !sessionStorage.getItem('qrCodeProcessed')) {
          if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') {
            window.vbReplaceStateStripPartyCodeKeepLang();
          }
        }
        vbRunBlockCheckAfterJoin(partyDoc.id);
        return true;
      }

      isWishboxActive = true;
      currentPartyStartDate = null;
      stopPrePartyCountdown();
      const partyCodeInput = document.getElementById('partyCodeInput');
      if (partyCodeInput) partyCodeInput.value = canonicalCode;
      sessionStorage.setItem('validatedPartyCode', canonicalCode);
      localStorage.setItem('validatedPartyCode', canonicalCode);
      try { localStorage.removeItem('pending_party_code'); } catch (e) {}
      localStorage.setItem('validatedPartyId', partyDoc.id);
      sessionStorage.setItem('validatedPartyId', partyDoc.id);
      const partyName = data.party_name || 'Your Party';
      sessionStorage.setItem('validatedPartyName', partyName);
      localStorage.setItem('validatedPartyName', partyName);
      sessionStorage.setItem('currentPartyName', partyName);
      localStorage.setItem('currentPartyName', partyName);
      const isPaused = data.is_paused === true;
      togglePartyPausedOverlay(isPaused);
      vbBindWishboxFromPartyData(data);
      if (typeof showLoader === 'function') showLoader(false);
      void vbApplyWishboxBrandingReady(partyDoc.id, data);
      if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
      if (partyCodeFromUrl && !sessionStorage.getItem('qrCodeProcessed')) {
        if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') {
          window.vbReplaceStateStripPartyCodeKeepLang();
        }
      }
      updateWishboxUI();
      unawaited(vbRefreshMultiFloorAvailable());
      return true;
    }

    // ✅ Loader steuerbar: showLoader(true/false [, Text]) – für Party-Validierung (QR, URL, manuell)
    var _loaderLongWaitTimer = null;

    /** Block-Prüfung nach Join im Hintergrund — Loader darf nicht warten. */
    function vbRunBlockCheckAfterJoin(partyId) {
      void (async () => {
        try {
          currentClientId = await getOrCreateClientId(partyId, { deferWrites: true });
          await checkBlockStatus();
        } catch (eJoin) {
          if (window.IS_DEBUG) console.warn('⚠️ Block/Client nach Join:', eJoin);
          wishboxBlockGateResolved = true;
          try { updateWishboxUI(); } catch (eUi) {}
        }
      })();
    }

    function showLoader(show, text) {
      var overlay = document.getElementById('loading-overlay');
      var textEl = document.getElementById('loading-overlay-text');
      if (!overlay) return;
      if (show) {
        overlay.style.display = 'flex';
        if (document.body) document.body.classList.add('loader-active');
        var msg = (text != null && String(text).trim() !== '') ? String(text).trim() : (typeof getTranslation === 'function' ? getTranslation('loading_data') : 'Daten werden geladen...');
        if (textEl) textEl.textContent = msg;
        if (_loaderLongWaitTimer) clearTimeout(_loaderLongWaitTimer);
        _loaderLongWaitTimer = setTimeout(function() {
          _loaderLongWaitTimer = null;
          if (overlay && overlay.style.display === 'flex' && textEl) {
            textEl.textContent = (typeof getTranslation === 'function' ? getTranslation('loading_connection_checking') : null) || 'Checking connection...';
          }
        }, 5000);
      } else {
        overlay.style.display = 'none';
        if (document.body) document.body.classList.remove('loader-active');
        if (_loaderLongWaitTimer) {
          clearTimeout(_loaderLongWaitTimer);
          _loaderLongWaitTimer = null;
        }
      }
    }

    // ✅ QR-Code-Login: URL-Parameter code hat ABSOLUTE Priorität vor Storage (verhindert Redirect-Loop bei neuem QR-Scan)
    async function processQRCodeLogin() {
      var loaderShown = false;
      try {
        const urlParams = new URLSearchParams(window.location.search);
        var partyIdToUse = null;
        var idSourceKey = null;
        let codeFromUrl = null;

        // ✅ Priorität 1 (ABSOLUT): Code aus URL (Query oder Hash) – ausschließlich diesen verwenden
        const rawCode = typeof window.vbGetPartyCodeFromUrl === 'function' ? window.vbGetPartyCodeFromUrl() : urlParams.get('code');
        if (rawCode && typeof rawCode === 'string') {
          // ✅ Nur nackte 8 Ziffern: trim, Leerzeichen/unsichtbare Zeichen entfernen
          const sanitizedCode = String(rawCode).trim().replace(/\s/g, '').replace(/[^\d]/g, '').substring(0, 8);
          const okLen = sanitizedCode.length === 8;
          if (okLen && /^\d+$/.test(sanitizedCode)) {
            codeFromUrl = sanitizedCode;
            if (window.IS_DEBUG) console.log('DEBUG [Auto-Login]: URL-Parameter code hat absolute Priorität. Code:', codeFromUrl);
            try {
              if (typeof sessionStorage !== 'undefined') sessionStorage.setItem('vb_session_party_code', codeFromUrl);
            } catch (eSUrl) {}
            try { if (typeof sessionStorage !== 'undefined') sessionStorage.removeItem('vb_pending_join_code'); } catch (eP2) {}

            // ✅ Cleanup: URL-Code weicht von gespeicherter Party ab → sofort clearPartyData (ohne Redirect)
            var storedCode = localStorage.getItem('validatedPartyCode') || sessionStorage.getItem('validatedPartyCode');
            var storedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
            var storageMatchesUrl = storedCode && storedCode === codeFromUrl;
            if ((storedCode || storedPartyId) && !storageMatchesUrl) {
              if (window.IS_DEBUG) console.log('DEBUG [Auto-Login]: URL-Code weicht von Storage ab – räume alte Party-Daten auf.');
              if (typeof clearPartyData === 'function') clearPartyData(true);
              try {
                if (typeof sessionStorage !== 'undefined' && codeFromUrl) sessionStorage.setItem('vb_session_party_code', codeFromUrl);
              } catch (eRes) {}
            }
          } else {
            if (window.IS_DEBUG) console.warn('⚠️ URL-Parameter code ungültig (kein 8-stelliger Code), ignoriere:', rawCode);
            window.history.replaceState({}, document.title, (typeof window.vbNormalizedWishboxPathname === 'function' ? window.vbNormalizedWishboxPathname() : window.location.pathname));
          }
        }

        function vbStoredPartyId() {
          var fromPending = localStorage.getItem('pendingPartyId');
          var fromSessionValidated = sessionStorage.getItem('validatedPartyId');
          var fromLocalValidated = localStorage.getItem('validatedPartyId');
          if (fromPending && typeof fromPending === 'string' && validatePartyId(fromPending)) return fromPending;
          if (fromSessionValidated && typeof fromSessionValidated === 'string' && validatePartyId(fromSessionValidated)) return fromSessionValidated;
          if (fromLocalValidated && typeof fromLocalValidated === 'string' && validatePartyId(fromLocalValidated)) return fromLocalValidated;
          return '';
        }
        function vbStoredJoinDigits() {
          return String(
            localStorage.getItem('validatedPartyCode') ||
            sessionStorage.getItem('validatedPartyCode') ||
            ''
          ).replace(/\D/g, '').substring(0, 8);
        }

        // Session-Code ist kein neuer QR-Join. Sonst würde jeder Reload checkPartyCode
        // (4 Collection-Queries, Timeout 20s) statt parties/{id} lesen — Overlay „Verbindung wird geprüft“.
        if (!codeFromUrl && !vbStoredPartyId()) {
          var sessOnly = typeof window.vbGetSessionPartyCode8 === 'function' ? window.vbGetSessionPartyCode8() : null;
          if (sessOnly) codeFromUrl = sessOnly;
        }

        if (!codeFromUrl) {
          partyIdToUse = vbStoredPartyId();
          if (partyIdToUse) {
            idSourceKey = 'validatedPartyId (storage)';
          }
        } else if (vbStoredPartyId() && vbStoredJoinDigits() && vbStoredJoinDigits() === String(codeFromUrl)) {
          partyIdToUse = vbStoredPartyId();
          idSourceKey = 'validatedPartyId (same join code)';
        }

        vbLog('processQRCodeLogin Start. ID gelesen aus Key:', idSourceKey || (codeFromUrl ? 'code (URL)' : '(keine)'), 'Wert:', partyIdToUse || (codeFromUrl || '(leer)'));
        loaderShown = true;
        if (!partyIdToUse) {
          var loadingText = (typeof getTranslation === 'function' ? getTranslation('loading_party_connection') : null) || 'Connecting to the party...';
          showLoader(true, loadingText);
        }
        if (partyIdToUse) {
          try {
            if (localStorage.getItem('pendingPartyId') === partyIdToUse) localStorage.removeItem('pendingPartyId');
          } catch (ePendRm) {}
          vbLog('Starte Firestore-Abfrage für Party-ID:', partyIdToUse);
          const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyIdToUse);
          var partyDoc;
          try {
            partyDoc = await window.firebaseGetDoc(partyRef);
          } catch (getDocErr) {
            vbLog('Firestore getDoc Fehler (z.B. Permission Denied):', getDocErr && getDocErr.code, getDocErr && getDocErr.message);
            throw getDocErr;
          }
          vbLog('Snapshot erhalten. Existiert das Dokument?', partyDoc.exists());
          if (!partyDoc.exists()) {
            vbLog('Dokument existiert nicht für Party-ID:', partyIdToUse);
          }
          if (partyDoc.exists()) {
            var partyData = partyDoc.data();
            vbLog('Dokument-Daten (Keys):', partyData ? Object.keys(partyData) : null);
            const partyId = partyDoc.id;
            const partyCodeFromDb = partyData.party_code || '';
            const partyName = (partyData.party_name || partyData.partyName || '').trim() || null;
            const now = new Date();
            let ended = false;
            if (partyData.lifecycle_status === 'finished' || partyData.finished_at != null) ended = true;
            else if (partyData.status === 'beendet' || partyData.status === 'ended') ended = true;
            else if (partyData.end_date && typeof partyData.end_date.toDate === 'function' && now > partyData.end_date.toDate()) ended = true;
            if (ended) {
              showLoader(false);
              loaderShown = false;
              showPartyStatusModal('ended', (typeof getTranslation === 'function' ? getTranslation('party_ended') : null) || 'This party has already ended. Thank you for your visit!');
              return false;
            }
            localStorage.setItem('validatedPartyId', partyId);
            sessionStorage.setItem('validatedPartyId', partyId);
            sessionStorage.setItem('validatedPartyCode', partyCodeFromDb);
            try {
              if (typeof sessionStorage !== 'undefined' && partyCodeFromDb) {
                var pcDb = String(partyCodeFromDb).replace(/\D/g, '').substring(0, 8);
                if (pcDb.length === 8) sessionStorage.setItem('vb_session_party_code', pcDb);
              }
            } catch (eVbsc) {}
            if (partyName && partyName !== 'Deine Party' && partyName !== 'Your Party') {
              sessionStorage.setItem('validatedPartyName', partyName);
              localStorage.setItem('validatedPartyName', partyName);
              sessionStorage.setItem('currentPartyName', partyName);
              localStorage.setItem('currentPartyName', partyName);
            } else {
              sessionStorage.removeItem('validatedPartyName');
              localStorage.removeItem('validatedPartyName');
            }
            const hiddenPartyCodeInput = document.getElementById('partyCodeInput');
            if (hiddenPartyCodeInput) hiddenPartyCodeInput.value = partyCodeFromDb;
            vbBindWishboxFromPartyData(partyData);
            showLoader(false);
            loaderShown = false;
            void vbApplyWishboxBrandingReady(partyId, partyData).catch(function (e) {
              if (window.IS_DEBUG) console.warn('⚠️ Konnte Party-Daten für DJ-Namen nicht laden:', e);
            });
            const seBoot = vbWishboxStartEndFromPartyData(partyData);
            if (seBoot.startDate && now < seBoot.startDate) {
              if (typeof window.vbIsPreWishWindowOpen === 'function' && window.vbIsPreWishWindowOpen(partyData, now)) {
                showPreWishOrPausedMode(partyData, partyName || partyData.party_name || 'Party', seBoot.startDate);
              } else {
                showPrePartyWaitMode(partyName || partyData.party_name || 'Party', seBoot.startDate);
              }
              showLoader(false);
              loaderShown = false;
              vbRunBlockCheckAfterJoin(partyId);
              if (typeof window.vbApplyResolvedLanguageToUi === 'function') window.vbApplyResolvedLanguageToUi();
              return true;
            }
            isWishboxActive = true;
            showLoader(false);
            loaderShown = false;
            updateWishboxUI();
            vbRunBlockCheckAfterJoin(partyId);
            if (typeof window.vbApplyResolvedLanguageToUi === 'function') window.vbApplyResolvedLanguageToUi();
            return true;
          }
        }

        // FALLBACK: Code aus URL (8-stellig) – nutzt urlParams und rawCode von oben
        if (rawCode) console.log('DEBUG [Auto-Login]: Parameter gefunden (processQRCodeLogin):', rawCode);
        if (rawCode) {
          const sanitizedCode = String(rawCode).trim().replace(/\s/g, '').replace(/[^\d]/g, '').substring(0, 8);
          const numericOk = /^\d{8}$/.test(sanitizedCode);
          if (sanitizedCode && numericOk) {
            codeFromUrl = sanitizedCode;
            if (window.IS_DEBUG) console.log('✅ QR-Code-Login: URL-Parameter validiert (nur Zahlen):', sanitizedCode);
          } else {
            console.warn('DEBUG [Auto-Login]: URL-Parameter enthält ungültige Zeichen (keine reine Zahl), ignoriere:', rawCode);
            if (window.IS_DEBUG) console.warn('⚠️ QR-Code-Login: URL-Parameter enthält ungültige Zeichen, ignoriere:', rawCode);
            showLoader(false);
            loaderShown = false;
            window.history.replaceState({}, document.title, (typeof window.vbNormalizedWishboxPathname === 'function' ? window.vbNormalizedWishboxPathname() : window.location.pathname));
            return false;
          }
        }
        
        if (codeFromUrl && codeFromUrl.length === 8) {
          if (typeof window.checkPartyCode !== 'function') {
            showLoader(false);
            loaderShown = false;
            window.bodyLoadError = true;
            if (typeof updateWishboxUI === 'function') updateWishboxUI();
            return false;
          }

          const checkResult = await window.checkPartyCode(codeFromUrl);

          if (checkResult && checkResult.type === 'select_floor'
              && checkResult.floor_options
              && vbShouldShowFloorPickerForOptions(checkResult.floor_options)) {
            showLoader(false);
            loaderShown = false;
            await vbShowFloorPickerForJoinCode(codeFromUrl, checkResult.floor_options, null);
            if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') window.vbReplaceStateStripPartyCodeKeepLang();
            if (typeof window.vbApplyResolvedLanguageToUi === 'function') window.vbApplyResolvedLanguageToUi();
            return true;
          }

          if (checkResult && checkResult.success && checkResult.pre_wish_mode && checkResult.data && checkResult.data.party_id) {
            if (!validatePartyId(checkResult.data.party_id)) {
              showLoader(false);
              loaderShown = false;
              showPartyStatusModal('invalid', (typeof getTranslation === 'function' ? getTranslation('party_unknown') : null) || 'This party is not known. Please check your input.');
              return false;
            }
            await vbFinalizePartyJoin(codeFromUrl, checkResult);
            if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') window.vbReplaceStateStripPartyCodeKeepLang();
            if (typeof window.vbApplyResolvedLanguageToUi === 'function') window.vbApplyResolvedLanguageToUi();
            showLoader(false);
            loaderShown = false;
            return true;
          }

          if (checkResult && checkResult.type === 'future') {
            const langCode = (typeof window.vbGetResolvedPwaLanguageCode === 'function') ? window.vbGetResolvedPwaLanguageCode() : '';
            const tzId = checkResult.timezone_id || 'UTC';
            const startPosix = checkResult.start_time_posix;
            const atLine = (typeof window.formatPartyStartAtLine === 'function')
              ? window.formatPartyStartAtLine(startPosix, tzId, langCode, typeof t === 'function' ? t : getTranslation)
              : '';
            const introFuture = (typeof getTranslation === 'function' ? getTranslation('main_party_not_started_intro') : null) || 'This party has not started yet.';
            const futureMsg = introFuture + '<br><br><strong>' + (typeof escapeHtml === 'function' ? escapeHtml(atLine) : atLine) + '</strong>';
            const countdownStr = (typeof window.calculateTimeUntilParty === 'function' && typeof t === 'function')
              ? window.calculateTimeUntilParty(startPosix, t)
              : '';
            showPartyStatusModal('future', futureMsg, countdownStr);
            return false;
          }

          if (!checkResult || !checkResult.success || !checkResult.data || !checkResult.data.party_id) {
            showLoader(false);
            loaderShown = false;
            if (checkResult && checkResult.type === 'select_floor'
                && checkResult.floor_options
                && vbShouldShowFloorPickerForOptions(checkResult.floor_options)) {
              await vbShowFloorPickerForJoinCode(codeFromUrl, checkResult.floor_options, null);
              if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') window.vbReplaceStateStripPartyCodeKeepLang();
              return true;
            }
            const errKey = vbWishboxTranslationKeyForPartyCheck(checkResult && checkResult.messageKey);
            const modalType = errKey === 'party_ended' ? 'ended' : (errKey === 'party_not_started' ? 'future' : 'invalid');
            showPartyStatusModal(
              modalType,
              (typeof getTranslation === 'function' ? getTranslation(errKey) : null) || errKey,
            );
            if (modalType === 'ended') return false;
            if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') window.vbReplaceStateStripPartyCodeKeepLang();
            return false;
          }

          if (!validatePartyId(checkResult.data.party_id)) {
            showLoader(false);
            loaderShown = false;
            showPartyStatusModal('invalid', (typeof getTranslation === 'function' ? getTranslation('party_unknown') : null) || 'This party is not known. Please check your input.');
            return false;
          }

          const joined = await vbFinalizePartyJoin(codeFromUrl, checkResult);
          vbRunBlockCheckAfterJoin(joined.partyId);

          sessionStorage.setItem('qrCodeProcessed', 'true');
          if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') window.vbReplaceStateStripPartyCodeKeepLang();
          if (typeof window.vbApplyResolvedLanguageToUi === 'function') window.vbApplyResolvedLanguageToUi();
          sessionStorage.removeItem('qrCodeProcessed');
          showLoader(false);
          loaderShown = false;
          return true;
        }
      } catch (error) {
        console.error('DEBUG [Auto-Login]: Fehler bei Validierung:', error);
        if (loaderShown) showLoader(false);
        vbLog('processQRCodeLogin Fehler (Catch):', error && error.code, error && error.message, error && error.toString());
        window.bodyLoadError = true;
        if (typeof updateWishboxUI === 'function') updateWishboxUI();
      }
      if (loaderShown) showLoader(false);
      return false;
    }
    
    async function vbBootWishboxApp() {
      var vbBlockedByEntryGate = false;
      (function vbEnforceSessionEntryGate() {
        try {
          var p = (window.location.pathname || '').toLowerCase();
          if (p.indexOf('/vb') === -1) return;
          if (typeof vbHasWishboxEntryPermission === 'function' && vbHasWishboxEntryPermission()) return;
          vbBlockedByEntryGate = true;
          vbRedirectToRootPwa('entryGate');
        } catch (eGate) {}
      })();
      if (vbBlockedByEntryGate) return;

      vbClearStaleValidatedPartyIfJoinCodeMismatch();

      try {
        currentClientId = await getOrCreateClientId(null, { deferWrites: true });
      } catch (e) {
        console.error('❌ currentClientId (deferred) konnte nicht initialisiert werden:', e);
      }

      // Nur wenn der Nutzer wirklich ohne Party-Link kam: Redirect zur Marketing-Root.
      // Bei ?code= / Hash-Code darf NICHT zu / gewechselt werden (sonst QR-Link im Browser → „fliegt raus“).
      var hadPartyCodeInUrl = (function vbHadPartyCodeInUrlAtBoot() {
        try {
          if (typeof window.vbGetSessionPartyCode8 === 'function' && window.vbGetSessionPartyCode8()) return true;
        } catch (e0) {}
        try {
          if (typeof window.vbGetPartyCodeFromUrl === 'function') {
            var c = window.vbGetPartyCodeFromUrl();
            if (c != null && String(c).trim() !== '') {
              var digits = String(c).trim().replace(/\D/g, '').substring(0, 8);
              if (digits.length === 8) return true;
            }
          }
        } catch (e) {}
        try {
          var sp = new URLSearchParams(window.location.search || '');
          var q = sp.get('code');
          if (q != null && String(q).trim() !== '') return true;
        } catch (e2) {}
        try {
          if ((window.location.pathname || '').toLowerCase().indexOf('/vb') !== -1 && typeof sessionStorage !== 'undefined') {
            var pendBoot = sessionStorage.getItem('vb_pending_join_code');
            if (pendBoot && String(pendBoot).replace(/\D/g, '').length >= 8) return true;
          }
        } catch (e3) {}
        return false;
      })();

      const qrLoginSuccess = await processQRCodeLogin();
      if (window.__vbLeavingForHomeNotice) return;
      if (window.bodyLoadError) {
        vbLog('Ladefehler von processQRCodeLogin, zeige Fehler-UI');
        window.__vbDeferWishboxStatusUntilBoot = false;
        if (typeof updateWishboxUI === 'function') updateWishboxUI();
        return;
      }
      if (!qrLoginSuccess) {
        window.__vbDeferWishboxStatusUntilBoot = false;
        if (hadPartyCodeInUrl || (typeof window.vbGetSessionPartyCode8 === 'function' && window.vbGetSessionPartyCode8())) {
          if (window.IS_DEBUG) console.log('DEBUG PWA: QR-/URL-Code oder vb_session_party_code — Login fehlgeschlagen, bleibe in /vb/ (kein Redirect zu /).');
          if (typeof updateWishboxUI === 'function') updateWishboxUI();
          if (typeof checkWishboxStatus === 'function') checkWishboxStatus();
          return;
        }
        // Kein Session-Code und kein erfolgreicher Auto-Login → zur Hauptseite (Marketing-PWA)
        if (window.IS_DEBUG) console.log('DEBUG PWA: processQRCodeLogin fehlgeschlagen ohne Session-Party-Code, Redirect zu /');
        vbRedirectToRootPwa('bootNoCode');
        return;
      }
      try { sessionStorage.setItem('vb_entry_granted', '1'); } catch (eEg) {}
      window.__vbDeferWishboxStatusUntilBoot = false;
      if (window.IS_DEBUG) console.log('DEBUG PWA: Initial checkWishboxStatus() (nach Login, ohne erneutes Block-Gate)');
      checkWishboxStatus({ skipFullBlockRecheck: true });
      updateHeaderBasedOnLoginStatus();
      updatePartyInfoLine();
    }

    (function vbStartWishboxWhenFirebaseReady() {
      var bootStarted = false;
      function startBoot() {
        if (bootStarted) return;
        bootStarted = true;
        void vbBootWishboxApp();
      }
      if (window.firebaseDb && typeof window.firebaseGetDoc === 'function') {
        startBoot();
        return;
      }
      window.addEventListener('firebaseGlobalsReady', startBoot, { once: true });
      void vbWaitForFirebaseReady(10000).then(startBoot);
    })();
    
    // Prüfe alle 30 Sekunden erneut (Party-Laufzeit/Wunschbox — ohne erneutes Block-Gate)
    setInterval(function () {
      vbMaybeCheckWishboxStatus({ skipFullBlockRecheck: true });
    }, 30000);
    
    // ✅ Limit-Info läuft über Firebase onSnapshot (subscribeWishLimitStream) – kein Polling, kein Flackern
    
    // Prüfe auch bei URL-Änderungen (z.B. wenn Code in URL hinzugefügt wird)
    window.addEventListener('popstate', () => {
      vbMaybeCheckWishboxStatus();
    });
    
    // Prüfe auch wenn Hash oder Query-Parameter sich ändern
    let lastUrl = window.location.href;
    setInterval(() => {
      if (window.location.href !== lastUrl) {
        lastUrl = window.location.href;
        vbMaybeCheckWishboxStatus();
      }
    }, 1000);

    // Kontaktformular
    const contactForm = document.getElementById('contactForm');
    const contactNameInput = document.getElementById('contactName');
    const contactEmailInput = document.getElementById('contactEmail');
    const contactPhoneInput = document.getElementById('contactPhone');
    const contactSubjectInput = document.getElementById('contactSubject');
    const contactMessageInput = document.getElementById('contactMessage');
    const contactSubmitBtn = document.getElementById('contactSubmitBtn');
    const contactErrorMessage = document.getElementById('contactErrorMessage');
    const contactSuccessMessage = document.getElementById('contactSuccessMessage');
    const contactCharCount = document.getElementById('contactCharCount');

    // ✅ Zeichenzähler für alle Kontaktformular-Felder (mit .trim() für korrekte Zählung)
    // Nachricht
    contactMessageInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      contactCharCount.textContent = `${length} / 1500`;
    });
    contactCharCount.textContent = `${(contactMessageInput.value || '').trim().length} / 1500`;
    
    // Name
    contactNameInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      contactNameCharCount.textContent = `${length} / 100`;
    });
    contactNameCharCount.textContent = `${(contactNameInput.value || '').trim().length} / 100`;
    
    // Email
    contactEmailInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      contactEmailCharCount.textContent = `${length} / 200`;
    });
    contactEmailCharCount.textContent = `${(contactEmailInput.value || '').trim().length} / 200`;
    
    // Telefon
    contactPhoneInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      contactPhoneCharCount.textContent = `${length} / 50`;
    });
    contactPhoneCharCount.textContent = `${(contactPhoneInput.value || '').trim().length} / 50`;
    
    // Betreff
    contactSubjectInput.addEventListener('input', (e) => {
      const length = (e.target.value || '').trim().length;
      contactSubjectCharCount.textContent = `${length} / 100`;
    });
    contactSubjectCharCount.textContent = `${(contactSubjectInput.value || '').trim().length} / 100`;

    // Sanitize-Funktion (gegen XSS)
    // ✅ Globale Sanitization-Funktion: Entfernt HTML, Scripts, und verdächtige Zeichen
    function sanitizeInput(input) {
      if (!input || typeof input !== 'string') return '';
      
      // Entferne alle HTML-Tags (inkl. script, iframe, a, img, etc.)
      let sanitized = input
        .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
        .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, '')
        .replace(/<[^>]+>/g, '')
        .replace(/javascript:/gi, '')
        .replace(/on\w+\s*=/gi, '')
        .replace(/data:/gi, '')
        .replace(/vbscript:/gi, '')
        .replace(/onload=/gi, '')
        .replace(/onerror=/gi, '')
        .replace(/onclick=/gi, '')
        .replace(/onmouseover=/gi, '')
        .replace(/onfocus=/gi, '')
        .replace(/onblur=/gi, '')
        .replace(/onchange=/gi, '')
        .replace(/onsubmit=/gi, '')
        .replace(/eval\(/gi, '')
        .replace(/expression\(/gi, '')
        .replace(/import\s+/gi, '')
        .replace(/from\s+/gi, '')
        .replace(/require\(/gi, '')
        .replace(/SELECT\s+/gi, '')
        .replace(/INSERT\s+/gi, '')
        .replace(/UPDATE\s+/gi, '')
        .replace(/DELETE\s+/gi, '')
        .replace(/DROP\s+/gi, '')
        .replace(/UNION\s+/gi, '')
        .replace(/OR\s+1\s*=\s*1/gi, '')
        .replace(/OR\s+'1'\s*=\s*'1'/gi, '')
        .replace(/;\s*DROP\s+TABLE/gi, '')
        .replace(/--/g, '') // SQL-Kommentare
        .replace(/\/\*/g, '') // SQL-Kommentare
        .replace(/\*\//g, '') // SQL-Kommentare
        .trim();
      
      // Escape gefährliche Zeichen
      sanitized = sanitized
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#x27;')
        .replace(/\//g, '&#x2F;');
      
      return sanitized;
    }

    // Entfernt HTML-Tags und verdächtige Script-Zeichen.
    function sanitizeString(str) {
      if (!str || typeof str !== 'string') return '';
      return str
        .replace(/<[^>]*>/g, '')
        .replace(/[<>%/\\;]/g, '')
        .trim();
    }
    
    // ✅ Party-ID-Validierung: Prüft Format (nur alphanumerische Zeichen, keine Scripts)
    function validatePartyId(partyId) {
      if (!partyId || typeof partyId !== 'string') return false;
      // Firestore Document-IDs: alphanumerisch inkl. Bindestrich/Unterstrich (keine /)
      const partyIdPattern = /^[a-zA-Z0-9_-]{1,128}$/;
      if (!partyIdPattern.test(partyId)) {
        if (window.IS_DEBUG) console.warn('⚠️ Ungültige Party-ID erkannt:', partyId);
        return false;
      }
      // Zusätzliche Prüfung: Keine verdächtigen Zeichenketten
      const suspiciousPatterns = [
        /<script/i,
        /javascript:/i,
        /on\w+\s*=/i,
        /eval\(/i,
        /SELECT/i,
        /INSERT/i,
        /UPDATE/i,
        /DELETE/i,
        /DROP/i
      ];
      for (const pattern of suspiciousPatterns) {
        if (pattern.test(partyId)) {
          if (window.IS_DEBUG) console.warn('⚠️ Verdächtige Party-ID erkannt:', partyId);
          return false;
        }
      }
      return true;
    }

    // Sanitize Email
    function sanitizeEmail(email) {
      if (!email) return '';
      return sanitizeInput(email);
    }

    // Kontaktformular absenden
    contactForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      
      const name = sanitizeInput(contactNameInput.value.trim());
      const email = sanitizeEmail(contactEmailInput.value.trim());
      const phone = sanitizeInput(contactPhoneInput.value.replace(/\s+$/, ''));
      const subject = sanitizeInput(contactSubjectInput.value.trim());
      const message = sanitizeInput(contactMessageInput.value.trim());

      // Validierung
      if (!name) {
        showContactError(t('contact_error_name_required', 'Please enter your name.'));
        return;
      }

      if (name.length > 100) {
        showContactError(t('contact_error_name_too_long', 'Name is too long (max. 100 characters).'));
        return;
      }

      if (!email && !phone) {
        showContactError(t('contact_error_email_or_phone_required', 'Please enter email or phone.'));
        return;
      }

      if (email && !email.includes('@')) {
        showContactError(t('contact_error_invalid_email', 'Please enter a valid email address.'));
        return;
      }

      if (subject.length > 200) {
        showContactError(t('contact_error_subject_too_long', 'Subject is too long (max. 200 characters).'));
        return;
      }

      if (!message) {
        showContactError(t('contact_error_message_required', 'Please enter a message.'));
        return;
      }

      if (message.length > 3000) {
        showContactError(t('contact_error_message_too_long', 'The message may not exceed 3000 characters.'));
        return;
      }

      // ✅ PHASE 2: 30-Sekunden-Cooldown-Prüfung (Anti-Hoax-Schutz)
      try {
        // Stelle sicher, dass currentClientId initialisiert ist
        if (!currentClientId) {
          // Für Kontaktformular brauchen wir keine Party-ID, verwende 'manual'
          currentClientId = await getOrCreateClientId('manual');
        }
        
        if (currentClientId) {
          // Erstelle Zeitstempel für 'vor 30 Sekunden'
          const thirtySecondsAgo = new Date(Date.now() - 30000);
          const thirtySecondsAgoTimestamp = window.firebaseTimestamp.fromDate(thirtySecondsAgo);
          
          // Query: Prüfe, ob in den letzten 30 Sekunden bereits eine Nachricht gesendet wurde
          const contactMessagesRef = window.firebaseCollection(window.firebaseDb, 'contact_messages');
          const cooldownQuery = window.firebaseQuery(
            contactMessagesRef,
            window.firebaseWhere('client_id', '==', currentClientId),
            window.firebaseWhere('createdAt', '>=', thirtySecondsAgoTimestamp)
          );
          
          const cooldownSnapshot = await window.firebaseGetDocs(cooldownQuery);
          
          if (!cooldownSnapshot.empty) {
            // Cooldown aktiv - Nachricht blockieren
            if (window.IS_DEBUG) console.warn('⏱️ Cooldown aktiv: Nachricht wurde in den letzten 30 Sekunden bereits gesendet');
            showContactError(t('contact_cooldown_30', 'Please wait 30 seconds between your messages.'));
            contactSubmitBtn.disabled = false;
            contactSubmitBtn.innerHTML = '<span>📤</span><span>' + (t('send_message', 'Send message')) + '</span>';
            return;
          }
          
          if (window.IS_DEBUG) console.log('✅ Cooldown-Prüfung erfolgreich: Keine Nachricht in den letzten 30 Sekunden');
        } else {
          if (window.IS_DEBUG) console.log('⚠️ Keine Client-ID vorhanden, überspringe Cooldown-Prüfung');
        }
      } catch (cooldownError) {
        // Bei Cooldown-Prüfungsfehler: Warnung loggen, aber Nachricht trotzdem erlauben (besser als zu restriktiv)
        if (window.IS_DEBUG) console.warn('⚠️ Fehler bei Cooldown-Prüfung, erlaube Nachricht trotzdem:', cooldownError);
        // Index-Fehler abfangen (falls Index noch lädt)
        if (cooldownError.code === 'failed-precondition' || 
            cooldownError.message?.includes('index') || 
            cooldownError.message?.includes('Index')) {
          if (window.IS_DEBUG) console.warn('⚠️ Firestore-Index wird noch erstellt. Erlaube Nachricht vorübergehend.');
        }
        // Weiter mit normalem Ablauf
      }

      // ✅ SOFORT: Submit-Button deaktivieren und Lade-Status anzeigen
      contactSubmitBtn.disabled = true;
      contactSubmitBtn.innerHTML = '<span>⏳</span><span>' + (t('contact_sending', 'Wird gesendet...')) + '</span>';
      hideContactError();

      try {
        // 1. reCAPTCHA Enterprise Token (action muss mit Cloud Function RECAPTCHA_CONTACT_ACTION übereinstimmen)
        const recaptchaSiteKey = '6LdoeDcsAAAAAIORb90GjRovm2tW5qE4v9q5J-u5';
        let recaptchaToken = null;
        try {
          if (typeof grecaptcha === 'undefined' || !grecaptcha.enterprise || !grecaptcha.enterprise.ready) {
            throw new Error('grecaptcha enterprise nicht geladen');
          }
          if (window.IS_DEBUG) console.log('🔄 reCAPTCHA Enterprise: Token wird generiert...');
          recaptchaToken = await new Promise((resolve, reject) => {
            grecaptcha.enterprise.ready(() => {
              try {
                grecaptcha.enterprise.execute(recaptchaSiteKey, { action: 'submit' })
                  .then((token) => {
                    if (window.IS_DEBUG) console.log('✅ reCAPTCHA Enterprise: Token erhalten', token && token.substring(0, 20) + '...');
                    resolve(token);
                  })
                  .catch(reject);
              } catch (e) {
                reject(e);
              }
            });
          });
        } catch (recaptchaErr) {
          console.warn('reCAPTCHA Enterprise Token fehlgeschlagen:', recaptchaErr && recaptchaErr.message);
          throw new Error(t('contact_error_recaptcha_token_missing', 'reCAPTCHA could not be loaded. Please reload the page.'));
        }
        if (!recaptchaToken || typeof recaptchaToken !== 'string') {
          throw new Error(t('contact_error_recaptcha_token_missing', 'reCAPTCHA token missing. Please reload the page.'));
        }

        // 2. Serverseitige reCAPTCHA-Validierung und Speicherung
        if (window.IS_DEBUG) console.log('🔄 reCAPTCHA Enterprise: Token wird an Server gesendet...');
        const validateResponse = await fetch('https://validaterecaptchaandsavecontact-5yehncoc7a-uc.a.run.app', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            recaptchaToken: recaptchaToken,
            name: name,
            email: email || '',
            phone: phone || '',
            subject: subject || '',
            message: message,
            partyId: localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId') || '', // ✅ Für E-Mail-Versand
            language: localStorage.getItem('pwa_language') || 'en', // ✅ Für Lokalisierung
            client_id: currentClientId || '' // ✅ Für Cooldown-Prüfung
          })
        });

        if (!validateResponse.ok) {
          const errorData = await validateResponse.json().catch(() => ({}));
          console.error('❌ reCAPTCHA v3: Validierung fehlgeschlagen', errorData);
          let msg = errorData.error || t('contact_error_recaptcha_validation_failed', 'reCAPTCHA validation failed. Please try again.');
          if (errorData.code === 'MISSING_TOKEN') {
            msg = t('contact_error_recaptcha_token_missing', msg);
          } else if (
            errorData.code === 'RECAPTCHA_VALIDATION_FAILED' ||
            errorData.code === 'RECAPTCHA_LOW_SCORE'
          ) {
            msg = t('contact_error_recaptcha_validation_failed', msg);
          } else if (errorData.code === 'RECAPTCHA_NOT_CONFIGURED') {
            msg = t('contact_error_sending', msg);
          }
          throw new Error(msg);
        }
        
        const responseData = await validateResponse.json().catch(() => ({}));
        
        // ✅ Prüfe Response-Status: Nur bei Status 200 (Erfolg) Erfolgsmeldung anzeigen
        if (validateResponse.ok && responseData.success === true) {
          if (window.IS_DEBUG) console.log('✅ reCAPTCHA v3: Token erfolgreich validiert und Nachricht gespeichert', responseData);
          if (window.IS_DEBUG) console.log('✅ E-Mail-Versand erfolgt server-seitig über Cloud Function');

          // ✅ Erfolgsmeldung anzeigen (bleibt offen bis manuell geschlossen)
          contactForm.style.display = 'none';
          contactSuccessMessage.classList.add('show');
          
          // ✅ Formular zurücksetzen
          contactForm.reset();
          contactCharCount.textContent = '0 / 1500';
          contactNameCharCount.textContent = '0 / 100';
          contactEmailCharCount.textContent = '0 / 200';
          contactPhoneCharCount.textContent = '0 / 50';
          contactSubjectCharCount.textContent = '0 / 100';
          
          // ✅ Button-Reset: Wird beim Schließen des Modals zurückgesetzt (siehe closeContactSuccessMessage)
        } else {
          // ✅ Server hat Fehler zurückgegeben (z.B. E-Mail-Versand fehlgeschlagen)
          const errorMessage = responseData.message || responseData.error || 'Error submitting. Please try again.';
          throw new Error(errorMessage);
        }
        
      } catch (error) {
        console.error('❌ Fehler beim Absenden:', error);
        showContactError(t('contact_error_sending', 'Error submitting. Please try again.'));
        
        // ✅ Button-Reset bei Fehler: Sofort wieder aktiv
        resetContactSubmitButton();
      }
    });

    // ✅ ENTFERNT: E-Mail-Versand erfolgt jetzt server-seitig über Cloud Function
    // Die Funktion sendEmailViaEmailJS wurde entfernt, da der E-Mail-Versand
    // jetzt vollständig in der Cloud Function validateRecaptchaAndSaveContact
    // erfolgt, um maximale Sicherheit zu gewährleisten.

    // Fehlermeldung für Kontaktformular
    function showContactError(message) {
      contactErrorMessage.textContent = message;
      contactErrorMessage.classList.add('show');
    }

    // ✅ Sicherer Zugriff auf contactErrorMessage (verhindert ReferenceError)
    function hideContactError() {
      const errorEl = document.getElementById('contactErrorMessage');
      if (errorEl) {
        errorEl.classList.remove('show');
      }
    }
    
    // ✅ VibesBox Free: Kontaktformular je nach planType aktivieren oder deaktivieren
    function applyContactFormPlanRestriction() {
      const contactForm = document.getElementById('contactForm');
      if (!contactForm) return;
      const planType = (sessionStorage.getItem('djPlanType') || '').toLowerCase();
      const isFree = planType === 'free';
      const elements = contactForm.querySelectorAll('input, textarea, button');
      for (let i = 0; i < elements.length; i++) {
        const el = elements[i];
        if (el && typeof el.disabled !== 'undefined') el.disabled = isFree;
      }
      const overlayId = 'contactFormFreeOverlay';
      let overlay = document.getElementById(overlayId);
      if (isFree) {
        if (!overlay) {
          const parent = contactForm.parentNode;
          if (parent && !contactForm.classList.contains('contact-form-free-wrapped')) {
            const wrapper = document.createElement('div');
            wrapper.className = 'contact-form-free-wrapper';
            wrapper.style.position = 'relative';
            parent.insertBefore(wrapper, contactForm);
            wrapper.appendChild(contactForm);
            contactForm.classList.add('contact-form-free-wrapped');
          }
          overlay = document.createElement('div');
          overlay.id = overlayId;
          overlay.setAttribute('aria-hidden', 'true');
          overlay.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;';
          contactForm.parentNode.appendChild(overlay);
        }
      } else {
        if (overlay && overlay.parentNode) overlay.parentNode.removeChild(overlay);
        const wrapper = contactForm.parentNode;
        if (wrapper && wrapper.classList && wrapper.classList.contains('contact-form-free-wrapper') && wrapper.parentNode) {
          wrapper.parentNode.insertBefore(contactForm, wrapper);
          wrapper.parentNode.removeChild(wrapper);
          contactForm.classList.remove('contact-form-free-wrapped');
        }
      }
    }

    // ✅ Button-Reset-Funktion für Kontaktformular
    function resetContactSubmitButton() {
      const contactSubmitBtn = document.getElementById('contactSubmitBtn');
      if (contactSubmitBtn) {
        contactSubmitBtn.disabled = false;
        contactSubmitBtn.innerHTML = '<span>📤</span><span>' + (t('send_message', 'Send message')) + '</span>';
      }
    }
    
    // ✅ Erfolgs-Fenster manuell schließen
    function closeContactSuccessMessage() {
      const contactSuccessMessage = document.getElementById('contactSuccessMessage');
      const contactForm = document.getElementById('contactForm');
      
      if (contactSuccessMessage) {
        contactSuccessMessage.classList.remove('show');
      }
      
      if (contactForm) {
        contactForm.style.display = 'block';
      }
      
      // ✅ Button-Reset: Sofort wieder aktiv nach Schließen
      resetContactSubmitButton();
    }

    // History-Funktion: Lädt und zeigt erkannte Songs der aktuellen Party mit Paginierung
    let historyListener = null; // Speichere Listener für Cleanup
    let allTracksCache = []; // Cache für alle Tracks (für Paginierung)
    let currentHistoryPage = 1; // Aktuelle Seite (1-basiert)
    const VB_DEFAULT_RESULTS_PER_PAGE = 20;
    const VB_ALLOWED_RESULTS_PER_PAGE = (function () {
      const list = [];
      for (let n = 10; n <= 150; n += 10) list.push(n);
      return list;
    })();
    let tracksPerPage = VB_DEFAULT_RESULTS_PER_PAGE;

    function vbIsPrePartyWaitUiActive() {
      var prePartyDiv = document.getElementById('prePartyWaitMode');
      if (!prePartyDiv) return false;
      try {
        return prePartyDiv.style.display === 'block'
          || window.getComputedStyle(prePartyDiv).display !== 'none';
      } catch (e) {
        return prePartyDiv.style.display === 'block';
      }
    }

    /** History erst nach Party-Start (nicht Vorab / nicht Pre-Party-Wartezeit). */
    function vbIsGuestHistoryBlocked() {
      if (isPreWishMode || isPreWishesPausedMode) return true;
      if (vbIsPrePartyWaitUiActive()) return true;
      try {
        if (sessionStorage.getItem('guestPreWishSession') === '1') return true;
      } catch (e) {}
      var start = typeof getStoredPartyStartDate === 'function' ? getStoredPartyStartDate() : null;
      if (start && !isNaN(start.getTime()) && new Date() < start) return true;
      return false;
    }

    function vbShowHistoryIdleState() {
      var historyLoading = document.getElementById('historyLoading');
      var historyError = document.getElementById('historyError');
      var historyEmpty = document.getElementById('historyEmpty');
      var historyList = document.getElementById('historyList');
      var historyPagination = document.getElementById('historyPagination');
      if (historyLoading) historyLoading.style.display = 'none';
      if (historyError) historyError.style.display = 'none';
      if (historyList) historyList.innerHTML = '';
      if (historyPagination) {
        historyPagination.innerHTML = '';
        historyPagination.style.display = 'none';
      }
      if (historyEmpty) historyEmpty.style.display = 'block';
    }

    function vbParseResultsPerPage(raw) {
      const n = typeof raw === 'number' ? raw : parseInt(String(raw), 10);
      if (VB_ALLOWED_RESULTS_PER_PAGE.indexOf(n) !== -1) return n;
      return null;
    }

    async function vbLoadDjResultsPerPage(djId) {
      if (!djId) return VB_DEFAULT_RESULTS_PER_PAGE;
      try {
        const userRef = window.firebaseDoc(
          window.firebaseDb,
          'users',
          String(djId),
          'settings',
          'results_per_page'
        );
        const userSnap = await window.firebaseGetDoc(userRef);
        if (userSnap.exists()) {
          const parsed = vbParseResultsPerPage(userSnap.data()?.results_per_page);
          if (parsed != null) return parsed;
        }
        const globalRef = window.firebaseDoc(window.firebaseDb, 'party_settings', 'current');
        const globalSnap = await window.firebaseGetDoc(globalRef);
        if (globalSnap.exists()) {
          const parsed = vbParseResultsPerPage(globalSnap.data()?.results_per_page);
          if (parsed != null) return parsed;
        }
      } catch (e) {
        if (window.IS_DEBUG) console.warn('vbLoadDjResultsPerPage:', e);
      }
      return VB_DEFAULT_RESULTS_PER_PAGE;
    }
    
    // ✅ Lokale Caches für Validierung (Performance-Optimierung)
    let localHistoryCache = []; // Cache für History-Tracks der aktuellen Party (für Duplikat-Prüfung)
    let localPendingWishesCache = []; // Cache für offene Wünsche der aktuellen Party (für Duplikat-Prüfung)
    let cachePartyId = null; // Party-ID für die Caches
    
    async function loadHistory(page = 1) {
      // ✅ Sicherheitsabfrage: Wenn keine Party-ID vorhanden ist, sofort abbrechen
      const validatedPartyId = localStorage.getItem('validatedPartyId');
      const validatedPartyIdSession = sessionStorage.getItem('validatedPartyId');
      const hasPartyId = (validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '') ||
                         (validatedPartyIdSession && validatedPartyIdSession !== 'manual' && validatedPartyIdSession !== '');
      
      if (!hasPartyId) {
        if (window.IS_DEBUG) console.log('⚠️ loadHistory: Keine Party-ID vorhanden, breche ab');
        vbShowHistoryIdleState();
        return;
      }

      if (vbIsGuestHistoryBlocked()) {
        if (window.IS_DEBUG) console.log('⚠️ loadHistory: Vorab/Pre-Party — leere History ohne Ladebalken');
        if (historyListener) {
          try {
            if (typeof historyListener === 'function') historyListener();
            else if (historyListener.unsubscribe) historyListener.unsubscribe();
            if (historyListener.trackListeners) {
              historyListener.trackListeners.forEach(function (u) {
                if (typeof u === 'function') u();
              });
            }
          } catch (eHist) {}
          historyListener = null;
        }
        allTracksCache = [];
        vbShowHistoryIdleState();
        return;
      }
      
      if (window.IS_DEBUG) console.log('🚀 PWA-DEBUG: loadHistory() aufgerufen mit page=' + page);
      if (window.IS_DEBUG) console.log('🚀 PWA-DEBUG: Stack-Trace:', new Error().stack);
      
      // Verstecke alle Zustände
      const historyLoading = document.getElementById('historyLoading');
      const historyError = document.getElementById('historyError');
      const historyEmpty = document.getElementById('historyEmpty');
      const historyList = document.getElementById('historyList');
      const historyErrorText = document.getElementById('historyErrorText');
      
      if (!historyLoading || !historyError || !historyEmpty || !historyList) {
        console.error('❌ PWA-ERROR: History-Elemente nicht gefunden');
        console.error('❌ PWA-ERROR: historyLoading=' + historyLoading + ', historyError=' + historyError + ', historyEmpty=' + historyEmpty + ', historyList=' + historyList);
        return;
      }
      
      if (window.IS_DEBUG) console.log('✅ PWA-DEBUG: Alle History-Elemente gefunden');
      
      // Zeige Loading
      historyLoading.style.display = 'block';
      historyError.style.display = 'none';
      historyEmpty.style.display = 'none';
      historyList.innerHTML = '';
      
      try {
        const currentPartyId =
          (validatedPartyIdSession && validatedPartyIdSession !== 'manual'
            ? validatedPartyIdSession
            : validatedPartyId) || '';

        if (!currentPartyId || currentPartyId === 'manual') {
          if (window.IS_DEBUG) console.warn('⚠️ PWA-WARNING: Keine gültige party_id - zeige leere History');
          historyLoading.style.display = 'none';
          historyEmpty.style.display = 'block';
          return;
        }

        let djId = (
          sessionStorage.getItem('validatedPartyDjId') ||
          localStorage.getItem('validatedPartyDjId') ||
          ''
        ).trim();

        const partyDocRef = window.firebaseDoc(window.firebaseDb, 'parties', currentPartyId);
        const partyDoc = await window.firebaseGetDoc(partyDocRef);
        if (!partyDoc.exists()) {
          console.error('❌ PWA-ERROR: Party-Dokument nicht gefunden für ID: ' + currentPartyId);
          historyLoading.style.display = 'none';
          historyEmpty.style.display = 'block';
          return;
        }
        const partyData = partyDoc.data() || {};
        if (!djId) {
          djId = String(partyData.created_by || '').trim();
        }
        if (djId) {
          try {
            sessionStorage.setItem('validatedPartyDjId', djId);
            localStorage.setItem('validatedPartyDjId', djId);
          } catch (eStoreDj) {}
        }

        if (!djId) {
          console.error('❌ PWA-ERROR: djId fehlt - kann History nicht laden');
          historyLoading.style.display = 'none';
          historyEmpty.style.display = 'block';
          return;
        }

        const seLive = typeof vbWishboxStartEndFromPartyData === 'function'
          ? vbWishboxStartEndFromPartyData(partyData)
          : { startDate: null };
        if (seLive.startDate && new Date() < seLive.startDate) {
          if (window.IS_DEBUG) console.log('⚠️ loadHistory: Party noch nicht gestartet');
          historyLoading.style.display = 'none';
          historyEmpty.style.display = 'block';
          return;
        }

        void updateHistoryCache(currentPartyId);

        tracksPerPage = VB_DEFAULT_RESULTS_PER_PAGE;
        void vbLoadDjResultsPerPage(djId).then(function (n) {
          if (typeof n === 'number' && n !== tracksPerPage) {
            tracksPerPage = n;
            if (allTracksCache.length > 0) renderHistoryPage();
          }
        });
        
        // Stoppe alten Listener falls vorhanden
        if (historyListener) {
          // Stoppe Haupt-Listener (wenn es eine Funktion ist oder ein Objekt mit unsubscribe)
          if (typeof historyListener === 'function') {
            historyListener();
          } else if (typeof historyListener.unsubscribe === 'function') {
            historyListener.unsubscribe();
          }
          // Stoppe alle Track-Listener
          if (historyListener.trackListeners && Array.isArray(historyListener.trackListeners)) {
            historyListener.trackListeners.forEach(unsubscribe => {
              if (typeof unsubscribe === 'function') {
                unsubscribe();
              }
            });
          }
          historyListener = null;
        }
        
        // Reset Cache und Seite
        allTracksCache = [];
        currentHistoryPage = page;

        const sessionsRef = window.firebaseCollection(window.firebaseDb, 'music_history');
        if (window.IS_DEBUG) console.log('DEBUG [DJ-History]: Suche mit ID-Typ:', typeof currentPartyId, 'Wert:', currentPartyId);
        const sessionsQuery = window.firebaseQuery(
          sessionsRef,
          window.firebaseWhere('djId', '==', djId),
          window.firebaseWhere('party_id', '==', currentPartyId)
        );

        if (window.IS_DEBUG) console.log('📊 PWA-DEBUG: Query erstellt mit djId=' + djId + ', partyId=' + currentPartyId);

        const listenerWrapper = {
          unsubscribe: null,
          trackListeners: []
        };

        listenerWrapper.unsubscribe = window.firebaseOnSnapshot(sessionsQuery, async (sessionsSnapshot) => {
          try {
            const snapshotSize = typeof sessionsSnapshot.size === 'number'
              ? sessionsSnapshot.size
              : (sessionsSnapshot.docs && sessionsSnapshot.docs.length);
            console.log('DEBUG [DJ-History]: Snapshot erhalten, Dokumente:', snapshotSize);
            if (window.IS_DEBUG) console.log('📊 PWA-DEBUG: Gefundene Sessions: ' + sessionsSnapshot.docs.length);

            if (listenerWrapper.trackListeners.length > 0) {
              listenerWrapper.trackListeners.forEach(unsubscribe => {
                if (typeof unsubscribe === 'function') unsubscribe();
              });
              listenerWrapper.trackListeners = [];
            }

            let tracksLoaded = 0;
            let previousTrackCount = allTracksCache.length;

            const validSessions = sessionsSnapshot.docs.filter(sessionDoc => {
              const sessionData = sessionDoc.data();
              const sessionDjId = sessionData.djId;
              const sessionPartyId = sessionData.party_id || sessionData.partyId;
              return sessionDjId === djId && sessionPartyId === currentPartyId;
            }).sort(function (a, b) {
              const ta = a.data().startTime && a.data().startTime.toMillis
                ? a.data().startTime.toMillis()
                : 0;
              const tb = b.data().startTime && b.data().startTime.toMillis
                ? b.data().startTime.toMillis()
                : 0;
              return tb - ta;
            }).slice(0, 3);
            const totalSessions = validSessions.length;

            if (totalSessions === 0) {
              if (window.IS_DEBUG) console.warn('⚠️ PWA-WARNING: Keine passenden Sessions für djId=' + djId + ', partyId=' + currentPartyId);
              allTracksCache = [];
              renderHistoryPage();
              historyLoading.style.display = 'none';
              const historyEmptyEl = document.getElementById('historyEmpty');
              if (historyEmptyEl) historyEmptyEl.style.display = 'block';
              return;
            }

            const updateTracksAndRender = () => {
              allTracksCache.sort((a, b) => b.timestamp - a.timestamp);
              previousTrackCount = allTracksCache.length;
              renderHistoryPage();
              historyLoading.style.display = 'none';
            };

            validSessions.forEach(sessionDoc => {
              const sessionId = sessionDoc.id;
              if (window.IS_DEBUG) console.log('🔍 PWA-DEBUG: Session ' + sessionId);

              const tracksRef = window.firebaseCollection(
                window.firebaseDb,
                `music_history/${sessionId}/tracks`
              );

              const tracksQuery = window.firebaseQuery(
                tracksRef,
                window.firebaseOrderBy('timestamp', 'desc'),
                window.firebaseLimit(PWA_FS_HISTORY_UI_TRACKS_PER_SESSION)
              );

              const trackUnsubscribe = window.firebaseOnSnapshot(tracksQuery, (tracksSnapshot) => {
                if (window.IS_DEBUG) console.log('📥 PWA-DEBUG: Tracks Session ' + sessionId + ': ' + tracksSnapshot.docs.length);

                allTracksCache = allTracksCache.filter(t => t.sessionId !== sessionId);

                tracksSnapshot.docs.forEach(trackDoc => {
                  const trackData = trackDoc.data();
                  const timestamp = trackData.timestamp;

                  if (timestamp) {
                    const trackTitle = (trackData.title || '').trim().toLowerCase();
                    const trackArtist = (trackData.artist || '').trim().toLowerCase();

                    if (trackTitle || trackArtist) {
                      if (!localHistoryCache.find(t => t.title === trackTitle && t.artist === trackArtist)) {
                        localHistoryCache.push({
                          title: trackTitle,
                          artist: trackArtist
                        });
                      }
                    }

                    allTracksCache.push({
                      id: trackDoc.id,
                      sessionId: sessionId,
                      title: unescapeHtml(trackData.title || ''),
                      artist: unescapeHtml(trackData.artist || ''),
                      bpm: trackData.bpm,
                      camelot: trackData.camelot || '',
                      durationSec: trackData.durationSec || null,
                      timestamp: timestamp.toDate ? timestamp.toDate() : new Date(timestamp.seconds * 1000)
                    });
                  }
                });

                tracksLoaded++;
                updateTracksAndRender();
              }, (trackError) => {
                console.error('❌ PWA-ERROR: Fehler beim Laden der Tracks aus Session:', sessionId, trackError);
                tracksLoaded++;
                updateTracksAndRender();
              });

              listenerWrapper.trackListeners.push(trackUnsubscribe);
            });

          } catch (error) {
            console.error('Fehler beim Verarbeiten der History:', error);
            historyLoading.style.display = 'none';
            historyError.style.display = 'block';
            historyErrorText.textContent = t('history_error', 'Error loading history');
            historyEmpty.style.display = 'none';
          }
        }, (error) => {
          console.error('Fehler beim History-Listener:', error);
          console.log('DEBUG [DJ-History]: Listener-Fehler (Permission?):', error && error.code, error && error.message);
          historyLoading.style.display = 'none';
          historyError.style.display = 'block';
          historyErrorText.textContent = t('history_error', 'Error loading history');
          historyEmpty.style.display = 'none';
        });

        historyListener = listenerWrapper;

      } catch (error) {
        console.error('Fehler beim Laden der History:', error);
        historyLoading.style.display = 'none';
        historyError.style.display = 'block';
        historyErrorText.textContent = t('history_error', 'Error loading history');
        historyEmpty.style.display = 'none';
      }
    }
    
    // Rendert die History-Seite mit Paginierung
    function renderHistoryPage() {
      const historyList = document.getElementById('historyList');
      const historyEmpty = document.getElementById('historyEmpty');
      const historyError = document.getElementById('historyError');
      const historyPagination = document.getElementById('historyPagination');
      
      if (!historyList) return;
      
      // Prüfe ob Tracks vorhanden
      if (allTracksCache.length === 0) {
        const historyLoadingEl = document.getElementById('historyLoading');
        if (historyLoadingEl) historyLoadingEl.style.display = 'none';
        historyEmpty.style.display = 'block';
        historyList.innerHTML = '';
        historyPagination.style.display = 'none';
        historyError.style.display = 'none';
        return;
      }
      
      historyEmpty.style.display = 'none';
      historyError.style.display = 'none';
      
      // Berechne Paginierung
      const totalPages = Math.ceil(allTracksCache.length / tracksPerPage);
      const startIndex = (currentHistoryPage - 1) * tracksPerPage;
      const endIndex = Math.min(startIndex + tracksPerPage, allTracksCache.length);
      const pageTracks = allTracksCache.slice(startIndex, endIndex);
      
      // Rendere Tracks der aktuellen Seite
      historyList.innerHTML = '';
      
      pageTracks.forEach(track => {
        const item = document.createElement('div');
        item.className = 'history-item';
        
        const content = document.createElement('div');
        content.className = 'history-item-content';
        const titleDiv = document.createElement('div');
        titleDiv.className = 'history-item-title';
        titleDiv.textContent = track.title || '';
        const artistDiv = document.createElement('div');
        artistDiv.className = 'history-item-artist';
        artistDiv.textContent = track.artist || '';
        const metaBits = [];
        if (track.durationSec && Number(track.durationSec) > 0) {
          const dur = Math.round(Number(track.durationSec));
          const mm = Math.floor(dur / 60);
          const ss = String(dur % 60).padStart(2, '0');
          metaBits.push(mm + ':' + ss);
        }
        if (track.bpm && Number(track.bpm) > 0) {
          const bpmNum = Number(track.bpm);
          metaBits.push((Math.abs(bpmNum - Math.round(bpmNum)) < 0.05 ? String(Math.round(bpmNum)) : bpmNum.toFixed(1)) + ' BPM');
        }
        if (track.camelot) metaBits.push(String(track.camelot));
        const timeDiv = document.createElement('div');
        timeDiv.className = 'history-item-time';
        timeDiv.textContent = formatTime(track.timestamp);
        
        content.appendChild(titleDiv);
        content.appendChild(artistDiv);
        if (metaBits.length) {
          const metaDiv = document.createElement('div');
          metaDiv.className = 'history-item-meta';
          metaDiv.textContent = metaBits.join(' · ');
          content.appendChild(metaDiv);
        }
        content.appendChild(timeDiv);
        item.appendChild(content);
        historyList.appendChild(item);
      });
      
      // Rendere Paginierung
      renderHistoryPagination(totalPages);
    }
    
    // Rendert die Paginierungs-Navigation
    function renderHistoryPagination(totalPages) {
      const historyPagination = document.getElementById('historyPagination');
      if (!historyPagination) return;
      
      if (totalPages <= 1) {
        historyPagination.style.display = 'none';
        return;
      }
      
      historyPagination.style.display = 'flex';
      historyPagination.innerHTML = '';
      
      // Zurück-Button
      const prevButton = document.createElement('button');
      prevButton.className = 'history-pagination-button';
      prevButton.textContent = t('history_pagination_prev', 'Zurück');
      prevButton.disabled = currentHistoryPage === 1;
      prevButton.onclick = () => {
        if (currentHistoryPage > 1) {
          currentHistoryPage--;
          renderHistoryPage();
          // Nach oben scrollen
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }
      };
      historyPagination.appendChild(prevButton);
      
      // Seitenzahlen
      const maxVisiblePages = 5;
      let startPage = Math.max(1, currentHistoryPage - Math.floor(maxVisiblePages / 2));
      let endPage = Math.min(totalPages, startPage + maxVisiblePages - 1);
      
      // Anpassen wenn am Ende
      if (endPage - startPage < maxVisiblePages - 1) {
        startPage = Math.max(1, endPage - maxVisiblePages + 1);
      }
      
      // Erste Seite + Ellipsis
      if (startPage > 1) {
        const firstButton = document.createElement('button');
        firstButton.className = 'history-pagination-button';
        firstButton.textContent = '1';
        firstButton.onclick = () => {
          currentHistoryPage = 1;
          renderHistoryPage();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        };
        historyPagination.appendChild(firstButton);
        
        if (startPage > 2) {
          const ellipsis = document.createElement('span');
          ellipsis.className = 'history-pagination-ellipsis';
          ellipsis.textContent = '...';
          historyPagination.appendChild(ellipsis);
        }
      }
      
      // Seitenzahlen
      for (let i = startPage; i <= endPage; i++) {
        const pageButton = document.createElement('button');
        pageButton.className = 'history-pagination-button' + (i === currentHistoryPage ? ' active' : '');
        pageButton.textContent = i.toString();
        pageButton.onclick = () => {
          currentHistoryPage = i;
          renderHistoryPage();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        };
        historyPagination.appendChild(pageButton);
      }
      
      // Ellipsis + Letzte Seite
      if (endPage < totalPages) {
        if (endPage < totalPages - 1) {
          const ellipsis = document.createElement('span');
          ellipsis.className = 'history-pagination-ellipsis';
          ellipsis.textContent = '...';
          historyPagination.appendChild(ellipsis);
        }
        
        const lastButton = document.createElement('button');
        lastButton.className = 'history-pagination-button';
        lastButton.textContent = totalPages.toString();
        lastButton.onclick = () => {
          currentHistoryPage = totalPages;
          renderHistoryPage();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        };
        historyPagination.appendChild(lastButton);
      }
      
      // Weiter-Button
      const nextButton = document.createElement('button');
      nextButton.className = 'history-pagination-button';
      nextButton.textContent = t('history_pagination_next', 'Weiter');
      nextButton.disabled = currentHistoryPage === totalPages;
      nextButton.onclick = () => {
        if (currentHistoryPage < totalPages) {
          currentHistoryPage++;
          renderHistoryPage();
          // Nach oben scrollen
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }
      };
      historyPagination.appendChild(nextButton);
      
      // Info-Text
      const info = document.createElement('span');
      info.className = 'history-pagination-info';
      const startTrack = (currentHistoryPage - 1) * tracksPerPage + 1;
      const endTrack = Math.min(currentHistoryPage * tracksPerPage, allTracksCache.length);
      info.textContent = `${startTrack}-${endTrack} ${t('history_pagination_of', 'of')} ${allTracksCache.length}`;
      historyPagination.appendChild(info);
    }
    
    // Formatiert Zeit (z.B. "vor 5 Minuten" oder lokalisierte Datum+Uhrzeit)
    function formatTime(date) {
      if (!date || !(date instanceof Date)) {
        return '';
      }
      
      const now = new Date();
      const diffMs = now - date;
      const diffMins = Math.floor(diffMs / 60000);
      const diffHours = Math.floor(diffMs / 3600000);
      const diffDays = Math.floor(diffMs / 86400000);
      const lang = typeof localStorage !== 'undefined' ? (localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en') : 'en';

      if (diffMins < 1) {
        return t('history_just_now', 'just now');
      } else if (diffMins < 60) {
        const template = t('history_minutes_ago', '${diffMins} minutes ago');
        return template.replace(/\${diffMins}/g, diffMins);
      } else if (diffHours < 24) {
        const template = t('history_hours_ago', '${diffHours} hours ago');
        return template.replace(/\${diffHours}/g, diffHours);
      } else if (diffDays < 7) {
        const template = t('history_days_ago', '${diffDays} days ago');
        return template.replace(/\${diffDays}/g, diffDays);
      } else {
        if (typeof window.formatPartyShortDateTime === 'function') {
          return window.formatPartyShortDateTime(date, lang, t);
        }
        const locale = typeof window.getPartyLocale === 'function' ? window.getPartyLocale(lang) : 'de-DE';
        const h12 = typeof window.partyHour12 === 'function' ? window.partyHour12(lang) : /^en/i.test(locale);
        return new Intl.DateTimeFormat(locale, { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: h12 }).format(date);
      }
    }
    
    // Escaped HTML-Zeichen
    function escapeHtml(text) {
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    }

    // Seiten-Navigation
    function showPage(pageId) {
      if (window.IS_DEBUG) console.log('🔍 PWA-DEBUG: showPage aufgerufen mit pageId=' + pageId);

      var preWishNavBlock = false;
      try {
        preWishNavBlock = (typeof isPreWishUiActive === 'function' && isPreWishUiActive()) ||
          sessionStorage.getItem('guestPreWishSession') === '1' ||
          isPreWishesPausedMode ||
          (typeof vbIsPrePartyWaitUiActive === 'function' && vbIsPrePartyWaitUiActive());
      } catch (e) {}
      if (pageId === 'history' && preWishNavBlock) {
        showPage('wunschbox');
        return;
      }
      
      // ✅ Stream aufräumen: Beim Verlassen der Wunschbox Limit-Realtime-Listener stoppen
      if (pageId !== 'wunschbox' && typeof stopWishLimitStream === 'function') {
        stopWishLimitStream();
      }
      
      // ✅ Navigations-Check: Prüfe, ob Party-ID vorhanden ist für DJ-spezifische Seiten
      const validatedPartyId = localStorage.getItem('validatedPartyId');
      const validatedPartyIdSession = sessionStorage.getItem('validatedPartyId');
      const hasPartyId = (validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '') ||
                         (validatedPartyIdSession && validatedPartyIdSession !== 'manual' && validatedPartyIdSession !== '');
      
      // ✅ Alle DJ-spezifischen Seiten blockieren, wenn keine Party-ID vorhanden ist
      const djSpecificPages = ['kontakt', 'socials', 'social-media', 'history'];
      
      if (djSpecificPages.includes(pageId) && !hasPartyId) {
        if (typeof window.vbGetSessionPartyCode8 === 'function' && window.vbGetSessionPartyCode8()) {
          if (window.IS_DEBUG) console.log('⚠️ DJ-Seite ohne Party-ID, aber vb_session_party_code — Wunschbox statt Root.');
          showPage('wunschbox');
          return;
        }
        if (window.IS_DEBUG) console.log('⚠️ Keine Party-ID vorhanden - zeige Info-Screen für:', pageId);
        showNoPartyInfoScreen(pageId);
        return;
      }
      
      // ✅ PRIORITÄT: Wenn Wunschbox ausgewählt wird, Erfolgsmeldung sofort schließen
      if (pageId === 'wunschbox') {
        if (window.IS_DEBUG) console.log('✅ Wunschbox ausgewählt - schließe Erfolgsmeldung');
        
        // Erfolgs-Sperre aufheben + CSS-Klasse entfernen (Formular wieder sichtbar)
        window.isSuccessActive = false;
        var formContainer = document.querySelector('.form-container');
        if (formContainer) formContainer.classList.remove('success-open');
        if (window.IS_DEBUG) console.log('✅ Erfolgs-Sperre deaktiviert: window.isSuccessActive = false');
        
        // Erfolgsmeldung ausblenden
        const successMessage = document.getElementById('successMessage');
        if (successMessage) {
          successMessage.classList.remove('show');
          if (window.IS_DEBUG) console.log('✅ Erfolgsmeldung ausgeblendet');
        }
        
        
        // Formular zurücksetzen (falls vorhanden)
        const wishForm = document.getElementById('wishForm');
        if (wishForm) {
          wishForm.reset();
          // Zeichenzähler zurücksetzen
          const charCount = document.getElementById('charCount');
          const nameCharCount = document.getElementById('nameCharCount');
          const titleCharCount = document.getElementById('titleCharCount');
          const artistCharCount = document.getElementById('artistCharCount');
          if (charCount) charCount.textContent = '0 / 200';
          if (nameCharCount) nameCharCount.textContent = '0 / 100';
          if (titleCharCount) titleCharCount.textContent = '0 / 100';
          if (artistCharCount) artistCharCount.textContent = '0 / 100';
        }
        
        // Limit-Anzeige läuft über subscribeWishLimitStream in updateWishboxUI – kein updateWishLimitInfo
      }
      
      // Alle Seiten verstecken
      document.querySelectorAll('.page').forEach(page => {
        page.style.display = 'none';
      });
      
      // ✅ Alle Drawer-Menüpunkte deaktivieren
      document.querySelectorAll('.drawer-menu-item').forEach(item => {
        item.classList.remove('active');
      });
      
      // Gewählte Seite anzeigen
      const selectedPage = document.getElementById(`page-${pageId}`);
      if (selectedPage) {
        selectedPage.style.display = 'block';
      }
      
      // Wunschbox: vollständiger Status inkl. Block-Gate (kein Formular vor Freigabe)
      if (pageId === 'wunschbox' && !window.__vbDeferWishboxStatusUntilBoot) {
        checkWishboxStatus();
      }
      
      // ✅ Drawer-Menüpunkt aktivieren
      let drawerNavLink = document.getElementById(`drawer-nav-${pageId}`);
      
      // Wenn Impressum, DSGVO oder AGB, aktiviere "Über VibesBox" Link
      if (pageId === 'impressum' || pageId === 'dsgvo' || pageId === 'agb') {
        drawerNavLink = document.getElementById('drawer-nav-ueber');
      }
      
      if (drawerNavLink) {
        drawerNavLink.classList.add('active');
      }
      
      // ✅ Aktualisiere aktiven Menüpunkt (AGB/Impressum/DSGVO → Über)
      const effectiveNavId = (pageId === 'impressum' || pageId === 'dsgvo' || pageId === 'agb') ? 'ueber' : pageId;
      updateDrawerActiveItem(effectiveNavId);
      
      if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
      
      // Nach oben scrollen
      window.scrollTo({ top: 0, behavior: 'smooth' });
      
      // Kontaktformular zurücksetzen, wenn Kontaktseite verlassen wird
      if (pageId !== 'kontakt') {
        const contactForm = document.getElementById('contactForm');
        if (contactForm) {
          contactForm.reset();
          const contactCharCount = document.getElementById('contactCharCount');
          const contactNameCharCount = document.getElementById('contactNameCharCount');
          const contactEmailCharCount = document.getElementById('contactEmailCharCount');
          const contactPhoneCharCount = document.getElementById('contactPhoneCharCount');
          const contactSubjectCharCount = document.getElementById('contactSubjectCharCount');
          const contactSuccessMessage = document.getElementById('contactSuccessMessage');
          
          if (contactCharCount) contactCharCount.textContent = '0 / 3000';
          if (contactNameCharCount) contactNameCharCount.textContent = '0 / 100';
          if (contactEmailCharCount) contactEmailCharCount.textContent = '0 / 200';
          if (contactPhoneCharCount) contactPhoneCharCount.textContent = '0 / 50';
          if (contactSubjectCharCount) contactSubjectCharCount.textContent = '0 / 100';
          contactForm.style.display = 'block';
          if (contactSuccessMessage) contactSuccessMessage.classList.remove('show');
          
          // ✅ Absichern: Prüfe ob hideContactError existiert
          if (typeof hideContactError === 'function') {
            hideContactError();
          }
        }
      }
      
      // Impressum-Content dynamisch laden
      if (pageId === 'impressum') {
        updateImprintContent();
      }
      // Datenschutz-Content dynamisch laden
      if (pageId === 'dsgvo') {
        updatePrivacyContent();
      }
      // AGB-Content dynamisch laden (l10n, externe Links target="_blank")
      if (pageId === 'agb') {
        updateTermsContent();
      }
      
      // History-Seite laden wenn History angezeigt wird
      if (pageId === 'history') {
        if (window.IS_DEBUG) console.log('✅ PWA-DEBUG: History-Seite erkannt - rufe loadHistory(1) auf');
        currentHistoryPage = 1; // Reset auf Seite 1 beim Anzeigen der History
        loadHistory(1).catch(error => {
          console.error('❌ PWA-ERROR: Fehler beim Laden der History:', error);
          if (window.IS_DEBUG) console.error('❌ PWA-ERROR: Stack-Trace:', error.stack);
        });
      }
      
      // ✅ Social-Media-Seite: Rendere Social-Links dynamisch
      if (pageId === 'social-media') {
        renderSocialMediaLinks();
      }
      
      // ✅ Kontakt-Seite: VibesBox Free – Formular deaktivieren + Overlay
      if (pageId === 'kontakt' && typeof applyContactFormPlanRestriction === 'function') {
        applyContactFormPlanRestriction();
      }
      if (pageId === 'kontakt' && typeof window.updateContactDjRecipientHint === 'function') {
        window.updateContactDjRecipientHint();
      }
    }
    
    // ✅ Seite ohne Party-ID: Direktzugriff ohne Login → zur Main-PWA
    function showNoPartyInfoScreen(pageId) {
      if (typeof window.vbGetSessionPartyCode8 === 'function' && window.vbGetSessionPartyCode8()) {
        if (window.IS_DEBUG) console.log('🔒 vb_session_party_code gesetzt — kein Redirect zur Root (pageId=' + (pageId || '') + ').');
        showPage('wunschbox');
        return;
      }
      if (vbIsOnWishboxPath()) {
        if (window.IS_DEBUG) console.log('🔒 Keine Party-ID auf /vb/ — Wunschbox statt Root (pageId=' + (pageId || '') + ').');
        showPage('wunschbox');
        return;
      }
      if (window.IS_DEBUG) console.log('🔒 Keine Party-ID – Umleitung zur Main PWA.');
      console.warn('DEBUG [Auto-Login]: Redirect zur Startseite wird ausgelöst! Grund: showNoPartyInfoScreen (keine Party-ID, pageId=' + (pageId || '') + ').');
      vbRedirectToRootPwa('showNoPartyInfoScreen');
    }
    
    // ✅ Funktion zum Laden des DJ-Logos für Social-Media-Seite
    function loadSocialMediaLogo(logoContainer, logoImg) {
      if (!logoContainer || !logoImg) {
        if (window.IS_DEBUG) console.warn('⚠️ Logo-Container oder Logo-Img nicht gefunden');
        return;
      }

      // ✅ Prüfe Login-Status: Party-ID vorhanden?
      const validatedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
      const isLoggedIn = validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '';
      
      if (!isLoggedIn) {
        logoContainer.style.display = 'none';
        return;
      }

      const cachedPartyData = window.__vbCachedPartyBrandingData;
      if (cachedPartyData && vbApplyPartyDjLogo(logoContainer, logoImg, cachedPartyData)) {
        return;
      }

      // ✅ Fallback: Party-Daten für dj_logo (nur wenn kein Cache)
      const savedPartyId = validatedPartyId;
      if (savedPartyId && savedPartyId !== 'manual' && savedPartyId !== '') {
        try {
          const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), savedPartyId);
          window.firebaseGetDoc(partyRef).then((partyDoc) => {
            if (partyDoc.exists()) {
              const partyData = partyDoc.data();
              window.__vbCachedPartyBrandingData = partyData;
              vbApplyPartyDjLogo(logoContainer, logoImg, partyData);
            } else {
              logoContainer.style.display = 'none';
            }
          }).catch((e) => {
            if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Laden der Party-Daten für Social-Media-Logo:', e);
            logoContainer.style.display = 'none';
          });
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Zugriff auf Party-Daten:', e);
          logoContainer.style.display = 'none';
        }
      } else {
        logoContainer.style.display = 'none';
      }
    }
    
    /** In der Party: kein VibesBox-Fallback – Hinweis, dass der DJ (noch) keine Social-Links hat / Free-Plan. */
    function showDjSocialLinksUnavailable(container, emptyMessage) {
      if (!container || !emptyMessage) return;
      container.innerHTML = '';
      const introEl = document.getElementById('socialMediaIntroduction');
      if (introEl) introEl.style.display = 'none';
      emptyMessage.style.display = 'block';
      const messageElement = emptyMessage.querySelector('h2');
      if (!messageElement) return;
      messageElement.removeAttribute('data-i18n');
      const rawDj = (sessionStorage.getItem('currentDjName') || '').trim();
      let fallbackDj = typeof t === 'function' ? t('social_media_dj_fallback_name', '') : '';
      if (!fallbackDj || fallbackDj === 'social_media_dj_fallback_name') {
        fallbackDj = typeof getTranslation === 'function' ? getTranslation('social_media_dj_fallback_name') : '';
      }
      if (!fallbackDj) fallbackDj = 'the DJ';
      const displayName = rawDj || fallbackDj;
      let template = typeof t === 'function' ? t('social_media_dj_no_links', '') : '';
      if (!template || template === 'social_media_dj_no_links') {
        template = typeof getTranslation === 'function' ? getTranslation('social_media_dj_no_links') : '';
      }
      if (!template) {
        template = 'Unfortunately, {djName} has not added any social media links yet.';
      }
      messageElement.textContent = template.replace(/\{djName\}/g, displayName);
    }

    /** VibesBox-Standardkanäle: ohne Party, oder in Party mit Free-DJ — nicht für Pro/Trial-Gäste in Party. */
    function renderVibesboxFallbackSocial(container, emptyMessage) {
      if (!container) return;
      if (emptyMessage) emptyMessage.style.display = 'none';
      container.innerHTML = '';

      const intro = document.createElement('p');
      intro.className = 'vibesbox-social-fallback-intro';
      let introText = 'Folge VibesBox für Updates und neue Features:';
      if (typeof getTranslation === 'function') {
        introText = getTranslation('vibesbox_social_intro') || introText;
      } else if (typeof translations !== 'undefined') {
        const currentLang = localStorage.getItem('pwa_language') || 'en';
        introText = translations[currentLang]?.['vibesbox_social_intro'] || introText;
      }
      intro.textContent = introText;
      intro.style.cssText = 'color: rgba(255,255,255,0.95); text-align: center; font-size: 16px; font-weight: 600; margin: 0 0 20px 0; padding: 0 12px; line-height: 1.35;';
      container.appendChild(intro);

      const items = [
        { className: 'instagram', icon: '<i class="fab fa-instagram"></i>', url: 'https://www.instagram.com/vibesbox.app/', labelKey: 'vibesbox_social_instagram_label', labelFallback: '@vibesbox.app' },
        { className: 'facebook', icon: '<i class="fab fa-facebook"></i>', url: 'https://www.facebook.com/vibesbox.app', labelKey: 'vibesbox_social_facebook_label', labelFallback: 'VibesBox' },
        { className: 'website', icon: '<i class="fas fa-globe"></i>', url: 'https://www.vibesbox.app/', labelKey: 'vibesbox_social_website_label', labelFallback: 'www.vibesbox.app' }
      ];

      items.forEach(function (item) {
        let label = item.labelFallback;
        if (typeof getTranslation === 'function') {
          label = getTranslation(item.labelKey) || label;
        } else if (typeof translations !== 'undefined') {
          const currentLang = localStorage.getItem('pwa_language') || 'en';
          label = translations[currentLang]?.[item.labelKey] || label;
        }
        const link = document.createElement('a');
        link.href = item.url;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        link.className = 'social-link ' + item.className;
        const iconDiv = document.createElement('div');
        iconDiv.className = 'social-icon';
        iconDiv.innerHTML = item.icon;
        const contentDiv = document.createElement('div');
        contentDiv.className = 'social-content';
        const titleDiv = document.createElement('div');
        titleDiv.className = 'social-title';
        titleDiv.textContent = label;
        contentDiv.appendChild(titleDiv);
        link.appendChild(iconDiv);
        link.appendChild(contentDiv);
        container.appendChild(link);
      });
    }

    // ✅ Funktion zum dynamischen Rendern der Social-Media-Links – 100% DJ-bezogen aus social_media_links
    async function renderSocialMediaLinks() {
      if (window.IS_DEBUG) console.log('🔗 Rendere Social-Media-Links (DJ-Daten)...');
      
      const container = document.getElementById('socialLinksContainer');
      const emptyMessage = document.getElementById('socialLinksEmpty');
      const logoContainer = document.getElementById('socialMediaLogoContainer');
      const logoImg = document.getElementById('socialMediaDjLogo');
      
      if (!container || !emptyMessage) {
        console.error('❌ Social-Links-Container nicht gefunden');
        return;
      }
      
      // ✅ Leere Container zuerst
      container.innerHTML = '';
      emptyMessage.style.display = 'none';
      
      // ✅ Lade und zeige DJ-Logo (wie in Wunschbox) – für alle (Free + Pro)
      loadSocialMediaLogo(logoContainer, logoImg);
      
      const validatedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
      const inParty = !!(validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '');
      const isFreeDj = (sessionStorage.getItem('djPlanType') || '').toLowerCase() === 'free';

      if (inParty && isFreeDj) {
        if (window.IS_DEBUG) console.log('Free-DJ-Party: VibesBox-Kanäle (kein DJ-Channel-Fallback)');
        renderVibesboxFallbackSocial(container, emptyMessage);
        return;
      }

      // ✅ Datenquelle: zuerst Session-Cache (beim Join/Vorab bereits geladen), sonst 1× Remote
      let socialsData = vbReadCachedDjSocials();
      if (!socialsData || !vbSocialsHaveLinks(socialsData)) {
        if (window.IS_DEBUG) console.log('🔗 Social-Cache leer — lade remote…');
        const remoteSocials = await vbFetchRemoteDjSocials();
        if (remoteSocials) socialsData = remoteSocials;
      } else if (window.IS_DEBUG) {
        console.log('✅ DJ-Social aus Session-Cache:', socialsData.order || []);
      }
      
      // ✅ Pro/Trial in Party ohne Links → Hinweis; ohne Party → VibesBox (Free-DJ-Party bereits oben)
      const order = socialsData && (socialsData.order || socialsData.socialOrder) ? socialsData.order || socialsData.socialOrder : [];
      const hasLinks = vbSocialsHaveLinks(socialsData);
      
      if (!socialsData || !hasLinks) {
        if (window.IS_DEBUG) console.log(inParty ? '⚠️ Keine DJ-Social-Links – Hinweis für Party-Gast (Pro/Trial)' : '⚠️ Keine Party – VibesBox-Fallback');
        const introElEarly = document.getElementById('socialMediaIntroduction');
        if (introElEarly) introElEarly.style.display = 'none';
        if (inParty) {
          showDjSocialLinksUnavailable(container, emptyMessage);
        } else {
          renderVibesboxFallbackSocial(container, emptyMessage);
        }
        return;
      }
      
      // ✅ Plattform-Konfiguration (Icons, Klassen, Übersetzungen) mit flexiblen Keywords
      const platformConfig = {
        'instagram': {
          icon: '<i class="fab fa-instagram"></i>',
          class: 'instagram',
          key: 'platform_instagram',
          color: '#E4405F',
          keywords: ['instagram', 'insta', 'ig']
        },
        'facebook': {
          icon: '<i class="fab fa-facebook"></i>',
          class: 'facebook',
          key: 'platform_facebook',
          color: '#1877F2',
          keywords: ['facebook', 'fb', 'face']
        },
        'tiktok': {
          icon: '<i class="fab fa-tiktok"></i>',
          class: 'tiktok',
          key: 'platform_tiktok',
          color: '#000000',
          keywords: ['tiktok', 'tt', 'tik']
        },
        'youtube': {
          icon: '<i class="fab fa-youtube"></i>',
          class: 'youtube',
          key: 'platform_youtube',
          color: '#FF0000',
          keywords: ['youtube', 'yt', 'tube']
        },
        'spotify': {
          icon: '<i class="fab fa-spotify"></i>',
          class: 'spotify',
          key: 'platform_spotify',
          color: '#1DB954',
          keywords: ['spotify', 'spot']
        },
        'soundcloud': {
          icon: '<i class="fab fa-soundcloud"></i>',
          class: 'soundcloud',
          key: 'platform_soundcloud',
          color: '#FF5500',
          keywords: ['soundcloud', 'sc', 'sound']
        },
        'whatsapp': {
          icon: '<i class="fab fa-whatsapp"></i>',
          class: 'whatsapp',
          key: 'platform_whatsapp',
          color: '#25D366',
          keywords: ['whatsapp', 'wa', 'whats']
        },
        'website': {
          icon: '<i class="fas fa-globe"></i>',
          class: 'website',
          key: 'platform_website',
          color: '#667eea',
          keywords: ['website', 'web', 'site', 'url', 'homepage']
        }
      };
      
      // ✅ URL-Sanitizing: Nur https:// URLs erlauben
      function sanitizeUrl(url) {
        if (!url || typeof url !== 'string') return null;
        const trimmedUrl = url.trim();
        if (trimmedUrl.startsWith('https://')) {
          return trimmedUrl;
        }
        if (trimmedUrl.startsWith('http://')) {
          return trimmedUrl.replace('http://', 'https://');
        }
        return null;
      }
      
      // ✅ WhatsApp-Spezialfall: Formatiere Nummer zu wa.me Link
      function formatWhatsAppUrl(value) {
        if (!value || typeof value !== 'string') return null;
        const trimmed = value.trim();
        
        if (trimmed.startsWith('https://wa.me/') || trimmed.startsWith('http://wa.me/')) {
          return sanitizeUrl(trimmed);
        }
        
        const numbersOnly = trimmed.replace(/[^0-9]/g, '');
        if (numbersOnly.length >= 8) {
          return `https://wa.me/${numbersOnly}`;
        }
        
        if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
          return sanitizeUrl(trimmed);
        }
        
        return null;
      }
      
      // ✅ Flexibler Key-Matcher: Findet Plattform basierend auf Key-Name
      function matchPlatform(key) {
        const keyLower = key.toLowerCase();
        
        for (const [platform, config] of Object.entries(platformConfig)) {
          for (const keyword of config.keywords) {
            if (keyLower.includes(keyword)) {
              return platform;
            }
          }
        }
        
        return null;
      }
      
      // ✅ order bereits oben deklariert (Zeile ~6707) – keine Doppeldeklaration
      if (window.IS_DEBUG) console.log('✅ Order-Array gefunden:', order);
      
      const renderedPlatforms = new Set(); // Verhindert Duplikate
      const processedKeys = new Set(); // Trackt verarbeitete Keys
      
      // ✅ Schritt 1: Loop durch order-Array (Master-Liste)
      order.forEach((platformId) => {
        if (!platformId || typeof platformId !== 'string') {
          if (window.IS_DEBUG) console.log('DEBUG: Überspringe ungültigen order-Eintrag:', platformId);
          return;
        }
        
        const platformIdLower = platformId.toLowerCase();
        if (window.IS_DEBUG) console.log('DEBUG: Verarbeite order-Eintrag:', platformIdLower);
        
        // ✅ Finde passenden Key im socialsData-Objekt
        let matchingKey = null;
        let urlValue = null;
        
        // ✅ Suche exakten Match zuerst
        if (socialsData[platformIdLower]) {
          matchingKey = platformIdLower;
          urlValue = socialsData[platformIdLower];
        } else {
          // ✅ Suche mit flexiblen Varianten (z.B. instagram_url, instagramUrl, instagram)
          for (const key in socialsData) {
            if (key === 'order' || key === 'socialOrder') continue;
            
            const keyLower = key.toLowerCase();
            // ✅ Prüfe, ob Key die Plattform-ID enthält
            if (keyLower.includes(platformIdLower) || platformIdLower.includes(keyLower)) {
              matchingKey = key;
              urlValue = socialsData[key];
              break;
            }
          }
        }
        
        if (!matchingKey || !urlValue) {
          if (window.IS_DEBUG) console.log('DEBUG: Kein Link gefunden für order-Eintrag:', platformIdLower);
          return;
        }
        
        // ✅ Prüfe, ob Wert eine gültige URL ist
        if (typeof urlValue !== 'string' || !urlValue.trim()) {
          if (window.IS_DEBUG) console.log('DEBUG: Kein gültiger String-Wert für:', matchingKey);
          return;
        }
        
        const trimmed = urlValue.trim();
        const isUrl = trimmed.startsWith('http://') || trimmed.startsWith('https://');
        const isWhatsAppNumber = platformIdLower.includes('whatsapp') && /^[0-9+\s\-()]+$/.test(trimmed) && trimmed.length >= 8;
        
        if (!isUrl && !isWhatsAppNumber) {
          if (window.IS_DEBUG) console.log('DEBUG: Wert ist weder URL noch WhatsApp-Nummer für:', matchingKey);
          return;
        }
        
        // ✅ Finde passende Plattform durch flexibles Key-Matching
        const platform = matchPlatform(matchingKey) || matchPlatform(platformIdLower);
        
        if (!platform) {
          if (window.IS_DEBUG) console.warn('⚠️ Keine Plattform für Key gefunden:', matchingKey, 'oder', platformIdLower);
          return;
        }
        
        // ✅ Verhindere Duplikate
        if (renderedPlatforms.has(platform)) {
          if (window.IS_DEBUG) console.log('DEBUG: Plattform [' + platform + '] bereits gerendert, überspringe');
          return;
        }
        
        const config = platformConfig[platform];
        if (!config) {
          if (window.IS_DEBUG) console.warn('⚠️ Keine Config für Plattform:', platform);
          return;
        }
        
        // ✅ URL-Verarbeitung
        let sanitizedUrl = null;
        if (platform === 'whatsapp') {
          sanitizedUrl = formatWhatsAppUrl(urlValue);
        } else {
          const trimmed = urlValue.trim();
          if (trimmed.startsWith('https://')) {
            sanitizedUrl = trimmed;
          } else if (trimmed.startsWith('http://')) {
            sanitizedUrl = trimmed.replace('http://', 'https://');
          } else {
            sanitizedUrl = 'https://' + trimmed;
          }
        }
        
        if (!sanitizedUrl) {
          if (window.IS_DEBUG) console.warn('⚠️ URL konnte nicht verarbeitet werden für:', matchingKey);
          return;
        }
        
        // ✅ Erstelle Link-Element
        const link = document.createElement('a');
        link.href = sanitizedUrl;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        link.className = `social-link ${config.class}`;
        
        // ✅ Hole Übersetzung für Plattform-Name
        let platformName = t(config.key, platform);
        if (platformName === platform && typeof translations !== 'undefined') {
          const currentLang = localStorage.getItem('pwa_language') || 'en';
          platformName = translations[currentLang]?.[config.key] || platform;
        }
        
        // ✅ Erstelle Icon
        const iconDiv = document.createElement('div');
        iconDiv.className = 'social-icon';
        iconDiv.innerHTML = config.icon;
        
        // ✅ Erstelle Content
        const contentDiv = document.createElement('div');
        contentDiv.className = 'social-content';
        
        const titleDiv = document.createElement('div');
        titleDiv.className = 'social-title';
        titleDiv.textContent = platformName;
        
        contentDiv.appendChild(titleDiv);
        
        link.appendChild(iconDiv);
        link.appendChild(contentDiv);
        
        container.appendChild(link);
        renderedPlatforms.add(platform);
        processedKeys.add(matchingKey);
        
        if (window.IS_DEBUG) console.log('✅ Link gerendert (order): [' + platform + '] für Key [' + matchingKey + '] → ' + sanitizedUrl.substring(0, 50) + '...');
      });
      
      // ✅ Schritt 2: Füge Links hinzu, die im Objekt sind, aber nicht im order-Array stehen
      Object.keys(socialsData).forEach((key) => {
        // ✅ Überspringe order-Arrays und bereits verarbeitete Keys
        if (key === 'order' || key === 'socialOrder' || processedKeys.has(key)) {
          return;
        }
        
        const value = socialsData[key];
        
        if (!value || typeof value !== 'string' || !value.trim()) {
          return;
        }
        
        const trimmed = value.trim();
        const isUrl = trimmed.startsWith('http://') || trimmed.startsWith('https://');
        const isWhatsAppNumber = key.toLowerCase().includes('whatsapp') && /^[0-9+\s\-()]+$/.test(trimmed) && trimmed.length >= 8;
        
        if (!isUrl && !isWhatsAppNumber) {
          return;
        }
        
        // ✅ Finde passende Plattform
        const platform = matchPlatform(key);
        
        if (!platform || renderedPlatforms.has(platform)) {
          return;
        }
        
        const config = platformConfig[platform];
        if (!config) {
          return;
        }
        
        // ✅ URL-Verarbeitung
        let sanitizedUrl = null;
        if (platform === 'whatsapp') {
          sanitizedUrl = formatWhatsAppUrl(value);
        } else {
          if (trimmed.startsWith('https://')) {
            sanitizedUrl = trimmed;
          } else if (trimmed.startsWith('http://')) {
            sanitizedUrl = trimmed.replace('http://', 'https://');
          } else {
            sanitizedUrl = 'https://' + trimmed;
          }
        }
        
        if (!sanitizedUrl) {
          return;
        }
        
        // ✅ Erstelle Link-Element
        const link = document.createElement('a');
        link.href = sanitizedUrl;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        link.className = `social-link ${config.class}`;
        
        // ✅ Hole Übersetzung
        let platformName = t(config.key, platform);
        if (platformName === platform && typeof translations !== 'undefined') {
          const currentLang = localStorage.getItem('pwa_language') || 'en';
          platformName = translations[currentLang]?.[config.key] || platform;
        }
        
        // ✅ Erstelle Icon
        const iconDiv = document.createElement('div');
        iconDiv.className = 'social-icon';
        iconDiv.innerHTML = config.icon;
        
        // ✅ Erstelle Content
        const contentDiv = document.createElement('div');
        contentDiv.className = 'social-content';
        
        const titleDiv = document.createElement('div');
        titleDiv.className = 'social-title';
        titleDiv.textContent = platformName;
        
        contentDiv.appendChild(titleDiv);
        
        link.appendChild(iconDiv);
        link.appendChild(contentDiv);
        
        container.appendChild(link);
        renderedPlatforms.add(platform);
        
        if (window.IS_DEBUG) console.log('✅ Link gerendert (zusätzlich): [' + platform + '] für Key [' + key + '] → ' + sanitizedUrl.substring(0, 50) + '...');
      });
      
      // ✅ Falls keine gültigen Links gefunden wurden → Party: Hinweis, sonst VibesBox-Fallback
      if (renderedPlatforms.size === 0) {
        if (window.IS_DEBUG) console.log(inParty ? '⚠️ Keine gültigen DJ-URLs – Hinweis für Party-Gast' : '⚠️ Keine gültigen Links – VibesBox-Fallback');
        const introductionElement = document.getElementById('socialMediaIntroduction');
        if (introductionElement) {
          introductionElement.style.display = 'none';
        }
        if (inParty) {
          showDjSocialLinksUnavailable(container, emptyMessage);
        } else {
          renderVibesboxFallbackSocial(container, emptyMessage);
        }
      } else {
        if (window.IS_DEBUG) console.log('✅ Social-Media-Links gerendert:', renderedPlatforms.size, 'Links:', Array.from(renderedPlatforms).join(', '));
        
        // ✅ Zeige Einführungs-Text mit DJ-Namen
        const introductionElement = document.getElementById('socialMediaIntroduction');
        if (introductionElement) {
          // ✅ Hole DJ-Namen aus sessionStorage
          const djName = sessionStorage.getItem('currentDjName') || 'den DJ';
          
          // ✅ Hole Übersetzung
          let introductionText = t('dj_links_connect', 'Vernetze Dich mit {djName}.');
          if (introductionText === 'Vernetze Dich mit {djName}.' && typeof translations !== 'undefined') {
            const currentLang = localStorage.getItem('pwa_language') || 'en';
            introductionText = translations[currentLang]?.['dj_links_connect'] || introductionText;
          }
          
          // ✅ Ersetze Platzhalter {djName} mit tatsächlichem DJ-Namen; XSS-Schutz für DJ-Namen
          const safeDjName = typeof escapeHtml === 'function' ? escapeHtml(djName) : String(djName).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
          const finalText = introductionText.replace('{djName}', `<strong>${safeDjName}</strong>`);
          introductionElement.innerHTML = finalText;
          introductionElement.style.display = 'block';
          
          if (window.IS_DEBUG) console.log('✅ Social-Media-Einführung angezeigt für:', djName);
        }
      }
    }
    
    // ✅ Funktion zum Anzeigen der Fallback-Meldung (L10n-Key: no_social_links_provided oder no_socials_available)
    function showSocialLinksEmpty(emptyMessage, l10nKey) {
      if (!emptyMessage) return;
      
      emptyMessage.style.display = 'block';
      
      const key = l10nKey || 'no_social_links_provided';
      const fallback = key === 'no_social_links_provided' ? 'Keine Social Media Links hinterlegt' : 'Keine Social-Media-Links verfügbar';
      
      const messageElement = emptyMessage.querySelector('h2[data-i18n]');
      if (messageElement) {
        let message = (typeof getTranslation === 'function' ? getTranslation(key) : null) || fallback;
        const djName = sessionStorage.getItem('currentDjName');
        if (djName && message.includes('{djName}')) {
          message = message.replace('{djName}', djName);
        }
        messageElement.textContent = message;
      }
    }
    
    // Copyright-Text aus Firestore laden (nur einmal beim App-Start)
    const COPYRIGHT_STORAGE_KEY = 'vibesbox_copyright_text';
    const COPYRIGHT_FALLBACK = '2026 by VibesBox';
    
    // Copyright-Text aus Session Storage abrufen (gecacht)
    function getCopyrightText() {
      try {
        return sessionStorage.getItem(COPYRIGHT_STORAGE_KEY) || COPYRIGHT_FALLBACK;
      } catch (e) {
        return COPYRIGHT_FALLBACK;
      }
    }
    
    // Copyright-Text einmalig beim App-Start aus Firestore laden
    async function initCopyrightText() {
      // Prüfe ob bereits im Session Storage vorhanden
      if (sessionStorage.getItem(COPYRIGHT_STORAGE_KEY)) {
        return; // Bereits geladen, kein erneuter Fetch
      }
      
      try {
        if (!window.firebaseDb || !window.firebaseGetDoc || !window.firebaseDoc) {
          sessionStorage.setItem(COPYRIGHT_STORAGE_KEY, COPYRIGHT_FALLBACK);
          return;
        }
        
        const settingsRef = window.firebaseDoc(window.firebaseDb, 'settings', 'global_config');
        const settingsSnap = await window.firebaseGetDoc(settingsRef);
        
        if (settingsSnap.exists()) {
          const data = settingsSnap.data();
          if (data.copyright_text) {
            sessionStorage.setItem(COPYRIGHT_STORAGE_KEY, data.copyright_text);
            return;
          }
        }
      } catch (error) {
        console.error('Fehler beim Laden des Copyright-Texts:', error);
      }
      
      // Fallback setzen
      sessionStorage.setItem(COPYRIGHT_STORAGE_KEY, COPYRIGHT_FALLBACK);
    }

    // Funktion zum Aktualisieren des Impressum-Contents
    function updateImprintContent() {
      const contentDiv = document.getElementById('imprint-content');
      if (!contentDiv) return;
      
      // Sprache bestimmen
      let lang = 'en';
      try {
        lang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
      } catch (e) {
        lang = 'en';
      }
      
      const langTranslations = translations[lang] || translations['en'] || translations['de'] || {};
      
      let htmlContent = '';
      
      // Sprachhinweis oben hinzufügen (übersetzt)
      if (langTranslations['legal_language_notice']) {
        htmlContent += '<p style="font-weight: bold; margin-bottom: 16px;">' + langTranslations['legal_language_notice'] + '</p>';
      }
      
      // HTML-Content hinzufügen (immer deutsch, unabhängig von der gewählten Sprache)
      const deTranslations = translations['de'] || {};
      if (deTranslations['imprint_html_content']) {
        htmlContent += deTranslations['imprint_html_content'];
      }
      
      // Copyright-Zeile am Ende hinzufügen (aus Session Storage)
      const copyrightText = getCopyrightText();
      htmlContent += '<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid rgba(255, 165, 0, 0.3); text-align: center; font-size: 11px; color: rgba(255, 255, 255, 0.6);">© ' + copyrightText + '</div>';
      
      contentDiv.innerHTML = htmlContent;
      // Externe Links: neuer Tab, PWA bleibt im Vordergrund
      contentDiv.querySelectorAll('a[href^="http"]').forEach(function(a) {
        a.setAttribute('target', '_blank');
        a.setAttribute('rel', 'noopener noreferrer');
      });
    }

    // Datenschutz-Content laden (immer deutsch, mit übersetztem Hinweis oben)
    function updatePrivacyContent() {
      const contentDiv = document.getElementById('privacy-content');
      if (!contentDiv) return;
      
      // Sprache bestimmen für Hinweis
      let lang = 'en';
      try {
        lang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
      } catch (e) {
        lang = 'en';
      }
      
      const langTranslations = translations[lang] || translations['en'] || translations['de'] || {};
      
      let htmlContent = '';
      
      // ✅ Sprachhinweis oben hinzufügen (übersetzt) - BEIBEHALTEN wie vorher
      if (langTranslations['legal_language_notice']) {
        htmlContent += '<p style="font-weight: bold; margin-bottom: 16px;">' + langTranslations['legal_language_notice'] + '</p>';
      }
      
      // ✅ Datenschutz-Text aus Übersetzungen laden (sprachabhängig)
      const privacyText = langTranslations['privacy_html_content'] || translations['de']['privacy_html_content'] || '';
      htmlContent += privacyText;
      
      // Copyright-Zeile am Ende hinzufügen (aus Session Storage)
      const copyrightText = getCopyrightText();
      htmlContent += '<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid rgba(255, 165, 0, 0.3); text-align: center; font-size: 11px; color: rgba(255, 255, 255, 0.6);">© ' + copyrightText + '</div>';
      
      contentDiv.innerHTML = htmlContent;
      // Externe Links: neuer Tab, PWA bleibt im Vordergrund
      contentDiv.querySelectorAll('a[href^="http"]').forEach(function(a) {
        a.setAttribute('target', '_blank');
        a.setAttribute('rel', 'noopener noreferrer');
      });
    }

    // AGB-Content aus l10n laden, externe Links target="_blank"
    function updateTermsContent() {
      const contentDiv = document.getElementById('terms-content');
      if (!contentDiv) return;
      let lang = 'en';
      try {
        lang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
      } catch (e) {
        lang = 'en';
      }
      const langTranslations = (typeof translations !== 'undefined' && translations[lang]) ? translations[lang] : (typeof translations !== 'undefined' ? (translations['en'] || translations['de'] || {}) : {});
      let htmlContent = (langTranslations && langTranslations['terms_html_content']) ? langTranslations['terms_html_content'] : '';
      
      // Copyright-Zeile am Ende hinzufügen (aus Session Storage)
      const copyrightText = getCopyrightText();
      htmlContent += '<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid rgba(255, 165, 0, 0.3); text-align: center; font-size: 11px; color: rgba(255, 255, 255, 0.6);">© ' + copyrightText + '</div>';
      
      contentDiv.innerHTML = htmlContent;
      contentDiv.querySelectorAll('a[href^="http"]').forEach(function(a) {
        a.setAttribute('target', '_blank');
        a.setAttribute('rel', 'noopener noreferrer');
      });
    }

    // Warte auf Firebase-Initialisierung
    window.addEventListener('load', () => {
      // Service Worker registrieren
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/vb/service-worker.js', { scope: '/vb/', updateViaCache: 'none' })
          .then(reg => {
            if (window.IS_DEBUG) console.log('Service Worker registriert');
            // Prüfe regelmäßig auf Updates
            reg.addEventListener('updatefound', () => {
              const newWorker = reg.installing;
              newWorker.addEventListener('statechange', () => {
                if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                  // Neue Version verfügbar - Seite neu laden
                  if (window.IS_DEBUG) console.log('Neue Version verfügbar - Seite wird neu geladen');
                  window.location.reload();
                }
              });
            });
            // Prüfe sofort auf Updates
            reg.update();
          })
          .catch(err => { if (window.IS_DEBUG) console.log('Service Worker Fehler:', err); });
        
        // Entferne alle alten Service Worker Registrierungen
        navigator.serviceWorker.getRegistrations().then((registrations) => {
          for (let registration of registrations) {
            if (registration.active && registration.active.scriptURL.includes('vb/service-worker.js')) {
              registration.update(); // Aktualisiere sofort
            }
          }
        });
      }
      
      // Prüfe ob Firebase geladen ist und initialisiere Copyright-Text (try-catch: Fehler blockieren nicht den App-Start)
      const checkFirebase = setInterval(() => {
        if (window.firebaseDb) {
          clearInterval(checkFirebase);
          if (window.IS_DEBUG) console.log('Firebase initialisiert');
          try { initCopyrightText(); } catch (e) { if (window.IS_DEBUG) console.warn('initCopyrightText Fehler:', e); }
        }
      }, 100);
      
      // Timeout nach 5 Sekunden
      setTimeout(() => {
        clearInterval(checkFirebase);
        if (!sessionStorage.getItem(COPYRIGHT_STORAGE_KEY)) {
          try { initCopyrightText(); } catch (e) { if (window.IS_DEBUG) console.warn('initCopyrightText Fehler:', e); }
        }
      }, 5000);
    });


    // Sprachauswahl Funktionen
    function toggleLanguageDropdown() {
      const dropdown = document.getElementById('languageSelector');
      if (dropdown) {
        dropdown.classList.toggle('show');
      }
    }

    // Schließe Dropdown wenn außerhalb geklickt wird
    document.addEventListener('click', function(event) {
      const selector = document.querySelector('.language-selector');
      const dropdown = document.getElementById('languageSelector');
      if (selector && dropdown && !selector.contains(event.target)) {
        dropdown.classList.remove('show');
      }
      
      // ✅ Alte Dropdown-Logik entfernt - Modal-System verwendet jetzt Click-Outside Handler
    });

    // Initialisiere Sprache beim Laden
    // ✅ visibilitychange-Listener für sofortige Status-Validierung beim Tab-Wechsel
    document.addEventListener('visibilitychange', async function() {
      if (document.visibilityState === 'visible') {
        // ✅ Kein automatisches Schließen des Bestätigungsfensters – es bleibt offen, bis der User "Weiteren Wunsch senden" klickt (z-index sorgt für korrekte Darstellung)
        // Tab wurde wieder aktiv - sofort Status prüfen
        const partyId = sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId');
        if (partyId && partyId !== 'manual' && isWishboxActive) {
          try {
            const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyId);
            const partyDoc = await window.firebaseGetDoc(partyRef);
            if (partyDoc.exists()) {
              const partyData = partyDoc.data();
              
              // ✅ PRIORITÄT 1: Prüfe Party-Ende ZUERST (ohne Verzögerung)
              const partyStatus = partyData.status || partyData.lifecycle_status || 'active';
              const endTimestamp = partyData.end_date || partyData.endTimePosix;
              const now = new Date();
              
              let isFinished = false;
              if (partyStatus === 'beendet' || partyStatus === 'ended' || partyStatus === 'finished') {
                isFinished = true;
              } else if (endTimestamp) {
                let endDate = null;
                if (endTimestamp.toDate) {
                  endDate = endTimestamp.toDate();
                } else if (typeof endTimestamp === 'number') {
                  endDate = new Date(endTimestamp * 1000);
                }
                if (endDate && now > endDate) {
                  isFinished = true;
                }
              }
              
              // ✅ Wenn Party beendet: Redirect zur Root-PWA mit Hinweis (clearPartyData setzt vb_party_ended_notice)
              if (isFinished) {
                if (window.IS_DEBUG) console.log('🔴 visibilitychange: Party beendet erkannt - Floor-Redirect oder Ausgang');
                console.warn('DEBUG [Auto-Login]: Party beendet erkannt (visibilitychange).');
                if (typeof vbHandleGuestPartyEnded === 'function') {
                  void vbHandleGuestPartyEnded(partyData, partyId);
                } else if (typeof runGuestPartyEndedWishboxFlow === 'function') runGuestPartyEndedWishboxFlow();
                else if (typeof clearPartyData === 'function') clearPartyData(true);
                return;
              }
              
              // ✅ PRIORITÄT 2: Pause-Prüfung (nur wenn Party noch aktiv)
              const isPaused = partyData.is_paused === true;
              togglePartyPausedOverlay(isPaused);
            }
          } catch (e) {
            if (window.IS_DEBUG) console.warn('Fehler bei visibilitychange Status-Prüfung:', e);
          }
        }
      }
    });

    document.addEventListener('DOMContentLoaded', function() {
      var floorSwitchBtn = document.getElementById('guestFloorSwitchBtn');
      if (floorSwitchBtn && !floorSwitchBtn._vbFloorBound) {
        floorSwitchBtn._vbFloorBound = true;
        floorSwitchBtn.addEventListener('click', function () {
          void vbShowFloorSwitchSheet();
        });
      }
      if (typeof initLanguage === 'function') {
        initLanguage();
        updateLanguageSelector();
        // ✅ Aktualisiere auch die Anzeige im Drawer-Menü
        if (typeof updateDrawerCurrentLanguage === 'function') {
          updateDrawerCurrentLanguage();
        }
        // ✅ Aktualisiere Menü-Titel nach Sprachwechsel (aus sessionStorage)
        if (typeof updateDrawerDjName === 'function') {
          updateDrawerDjName(null); // null = liest aus sessionStorage
        }
        // ✅ Placeholder für Wunschbox-Felder sofort beim Laden setzen
        if (typeof updateWishboxPlaceholders === 'function') {
          updateWishboxPlaceholders();
        }
      }
    });

    // Überschreibe changeLanguage um auch den Sprachnamen zu aktualisieren
    const originalChangeLanguage = window.changeLanguage;
    if (typeof originalChangeLanguage === 'function') {
      window.changeLanguage = async function(lang) {
        originalChangeLanguage(lang);
        const dropdown = document.getElementById('languageSelector');
        if (dropdown) {
          dropdown.classList.remove('show');
        }
        // Impressum-Content aktualisieren, wenn Seite sichtbar ist
        const impressumPage = document.getElementById('page-impressum');
        if (impressumPage && impressumPage.style.display !== 'none') {
          updateImprintContent();
        }
        // Datenschutz-Content aktualisieren, wenn Seite sichtbar ist
        const privacyPage = document.getElementById('page-dsgvo');
        if (privacyPage && privacyPage.style.display !== 'none') {
          updatePrivacyContent();
        }
        // AGB-Content aktualisieren, wenn Seite sichtbar ist
        const agbPage = document.getElementById('page-agb');
        if (agbPage && agbPage.style.display !== 'none') {
          updateTermsContent();
        }
        // ✅ Wunsch-Limit-Info sofort aktualisieren, wenn Wunschbox aktiv ist
        const wishForm = document.getElementById('wishForm');
        if (wishForm && wishForm.style.display !== 'none' && typeof updateWishLimitInfo === 'function') {
          if (window.IS_DEBUG) console.log('✅ Sprache geändert - aktualisiere Wunsch-Limit-Info sofort');
          updateWishLimitInfo();
        }
        // ✅ Party-Info-Zeile sofort aktualisieren (Übersetzung reagiert sofort)
        if (typeof updatePartyInfoLine === 'function') {
          if (window.IS_DEBUG) console.log('✅ Sprache geändert - aktualisiere Party-Info-Zeile sofort');
          updatePartyInfoLine();
        }
        // ✅ Placeholder für Wunschbox-Felder sofort aktualisieren
        if (typeof updateWishboxPlaceholders === 'function') {
          updateWishboxPlaceholders();
        }
        if (typeof window.updateContactDjRecipientHint === 'function') {
          window.updateContactDjRecipientHint();
        }
        const socialMediaPage = document.getElementById('page-social-media');
        if (socialMediaPage && socialMediaPage.style.display !== 'none' && typeof renderSocialMediaLinks === 'function') {
          renderSocialMediaLinks();
        }
        
        if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
        
        // ✅ Sprach-Sync: Aktualisiere language im Gast-Dokument, falls Party aktiv ist
        const currentPartyId = localStorage.getItem('validatedPartyId');
        if (currentPartyId && currentPartyId !== 'manual' && currentPartyId !== '' && currentClientId) {
          try {
            const partyGuestsRef = window.firebaseDoc(
              window.firebaseCollection(
                window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), currentPartyId),
                'guests'
              ),
              currentClientId
            );
            
            await window.firebaseUpdateDoc(partyGuestsRef, {
              language: lang
            });
            
            if (window.IS_DEBUG) console.log('✅ Sprache im Gast-Dokument aktualisiert:', { 
              party_id: currentPartyId,
              client_id: currentClientId,
              language: lang
            });
          } catch (langUpdateError) {
            if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Aktualisieren der Sprache im Gast-Dokument (nicht kritisch):', langUpdateError);
          }
        }
      };
    }
