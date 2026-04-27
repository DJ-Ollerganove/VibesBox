    /** Party-Code aus ?code= oder Hash (#code= / #...?code=) – QR-Links liefern teils nur den Hash. */
    window.vbGetPartyCodeFromUrl = function vbGetPartyCodeFromUrl() {
      try {
        var sp = new URLSearchParams(window.location.search || '');
        var c = sp.get('code');
        if (c != null && String(c).trim() !== '') return String(c).trim();
        var rawHash = window.location.hash || '';
        if (!rawHash) return null;
        var hash = rawHash.replace(/^#/, '');
        var qPart = '';
        var qi = hash.indexOf('?');
        if (qi >= 0) qPart = hash.substring(qi + 1);
        else if (hash.indexOf('code=') !== -1) qPart = hash;
        else return null;
        var hp = new URLSearchParams(qPart);
        c = hp.get('code');
        if (c != null && String(c).trim() !== '') return String(c).trim();
      } catch (e) {}
      return null;
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
        if (fromUrl && fromUrl !== 'ar' && typeof window.persistUrlLanguageToAllStorage === 'function') {
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

    /** Nach Party-Login: Code aus URL entfernen, ?lang= aus URL / aktive Sprache beibehalten. */
    window.vbReplaceStateStripPartyCodeKeepLang = function vbReplaceStateStripPartyCodeKeepLang() {
      try {
        var path = window.location.pathname || '/';
        var lang = '';
        if (typeof window.readPwaUrlLangParam === 'function') lang = window.readPwaUrlLangParam();
        if (!lang && typeof window.vbGetResolvedPwaLanguageCode === 'function') lang = window.vbGetResolvedPwaLanguageCode();
        if (lang === 'ar') lang = '';
        var suffix = lang ? ('?lang=' + encodeURIComponent(lang)) : '';
        window.history.replaceState({}, document.title, path + suffix);
      } catch (e) {
        try {
          window.history.replaceState({}, document.title, window.location.pathname);
        } catch (e2) {}
      }
    };

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
    
    // Debounce Timer
    let titleDebounceTimer = null;
    let artistDebounceTimer = null;
    let titleSearchAbortController = null; // Für Katalog-Modus: abbricht bei neuem Tippen
    
    // ✅ FINALE Globale currentClientId Variable (wird beim Seitenladen initialisiert)
    let currentClientId = null;
    
    // Wunschbox Status
    let isWishboxActive = false;
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

    /**
     * UI-Strings (innerHTML/showError): nutzt window.getTranslation zur Laufzeit.
     * Zweites Argument = englischer Fallback, wenn Übersetzung fehlt (früher war t nie definiert → nur Fallbacks).
     */
    function t(key, enFallback) {
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
          const appCheckToken = await window.getFirebaseAppCheckToken(false);
          if (appCheckToken) {
            headers['X-Firebase-AppCheck'] = appCheckToken;
          }
        }

        const fetchOpts = signal ? { signal, headers } : { headers };
        const response = await fetch(url, fetchOpts);
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
    form.addEventListener('submit', async (e) => {
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
      
      // SOFORT Flag setzen und Button deaktivieren (vor Validierung!)
      isSubmitting = true;
      submitBtn.disabled = true;
      submitBtn.innerHTML = '<span>⏳</span><span>' + (t('button_sending', 'Sending...')) + '</span>';
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

      // ✅ PHASE 2: 30-Sekunden-Cooldown-Prüfung (Anti-Hoax-Schutz)
      try {
        const partyCodeInputForCooldown = document.getElementById('partyCodeInput');
        let partyCodeForCooldown = partyCodeInputForCooldown ? (partyCodeInputForCooldown.value || 'manual') : 'manual';
        if (!partyCodeForCooldown || partyCodeForCooldown === 'manual') {
          const stored = sessionStorage.getItem('validatedPartyCode') || localStorage.getItem('validatedPartyCode');
          if (stored && stored.trim() !== '') partyCodeForCooldown = (stored == null ? '' : String(stored).replace(/[^0-9]/g, '').substring(0, 8));
        }
        let partyInfoForCooldown = null;
        const savedId = sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId');
        if ((!partyCodeForCooldown || partyCodeForCooldown === 'manual') && savedId && savedId !== 'manual' && validatePartyId(savedId)) {
          const ref = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), savedId);
          const doc = await window.firebaseGetDoc(ref);
          if (doc.exists()) {
            const d = doc.data();
            if (d.lifecycle_status !== 'finished' && d.finished_at == null) partyInfoForCooldown = { party_id: doc.id, party_code: d.party_code || '', party_name: d.party_name || null };
          }
        }
        if (!partyInfoForCooldown) partyInfoForCooldown = await getActivePartyInfo(partyCodeForCooldown === 'manual' ? partyCodeForCooldown : (partyCodeForCooldown == null ? '' : String(partyCodeForCooldown).replace(/[^0-9]/g, '').substring(0, 8)));
        // Stelle sicher, dass currentClientId initialisiert ist
        if (!currentClientId) {
          currentClientId = await getOrCreateClientId(partyInfoForCooldown.party_id || 'manual');
        }
        const currentPartyId = partyInfoForCooldown.party_id;
        
        if (currentPartyId && currentPartyId !== 'manual' && currentClientId) {
          // Erstelle Zeitstempel für 'vor 30 Sekunden'
          const thirtySecondsAgo = new Date(Date.now() - 30000);
          const thirtySecondsAgoTimestamp = window.firebaseTimestamp.fromDate(thirtySecondsAgo);
          
          // Query: Prüfe, ob in den letzten 30 Sekunden bereits ein Wunsch gesendet wurde
          const wishesRef = window.firebaseCollection(window.firebaseDb, 'wishes');
          const cooldownQuery = window.firebaseQuery(
            wishesRef,
            window.firebaseWhere('client_id', '==', currentClientId),
            window.firebaseWhere('party_id', '==', currentPartyId),
            window.firebaseWhere('createdAt', '>=', thirtySecondsAgoTimestamp)
          );
          
          const cooldownSnapshot = await window.firebaseGetDocs(cooldownQuery);
          
          if (!cooldownSnapshot.empty) {
            // Cooldown aktiv - Wunsch blockieren
            if (window.IS_DEBUG) console.warn('⏱️ Cooldown aktiv: Wunsch wurde in den letzten 30 Sekunden bereits gesendet');
            showError(t('wish_cooldown_30', 'Please wait 30 seconds between your requests.'));
            isSubmitting = false;
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
            return;
          }
          
          if (window.IS_DEBUG) console.log('✅ Cooldown-Prüfung erfolgreich: Kein Wunsch in den letzten 30 Sekunden');
        } else {
          if (window.IS_DEBUG) console.log('⚠️ Keine Party-ID oder Client-ID vorhanden, überspringe Cooldown-Prüfung');
        }
      } catch (cooldownError) {
        // Bei Cooldown-Prüfungsfehler: Warnung loggen, aber Wunsch trotzdem erlauben (besser als zu restriktiv)
        if (window.IS_DEBUG) console.warn('⚠️ Fehler bei Cooldown-Prüfung, erlaube Wunsch trotzdem:', cooldownError);
        // Index-Fehler abfangen (falls Index noch lädt)
        if (cooldownError.code === 'failed-precondition' || 
            cooldownError.message?.includes('index') || 
            cooldownError.message?.includes('Index')) {
          if (window.IS_DEBUG) console.warn('⚠️ Firestore-Index wird noch erstellt. Erlaube Wunsch vorübergehend.');
        }
        // Weiter mit normalem Ablauf
      }

      // Validierung
      if (!name) {
        showError(t('error_wish_name_required', 'Please enter your name.'));
        isSubmitting = false;
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
        return;
      }

      if (!title || !artist) {
        showError(t('error_wish_title_artist_required', 'Please enter both a title and an artist.'));
        isSubmitting = false;
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
        return;
      }

      if (greeting.length > 200) {
        showError(t('error_greeting_max_200', 'The greeting may be at most 200 characters long.'));
        isSubmitting = false;
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
        return;
      }

      try {
        // Party-Code aus verstecktem Feld lesen (wird von checkWishboxStatus/processQRCodeLogin gesetzt)
        const partyCodeInput = document.getElementById('partyCodeInput');
        let partyCode = partyCodeInput ? (partyCodeInput.value || 'manual') : 'manual';
        // ✅ FIX nach Umzug nach /vb/: Fallback auf Storage, wenn User von Landing (pendingPartyId) kam und Feld leer ist
        if (!partyCode || partyCode === 'manual') {
          const storedCode = sessionStorage.getItem('validatedPartyCode') || localStorage.getItem('validatedPartyCode');
          if (storedCode && storedCode.trim() !== '') {
            partyCode = (storedCode == null ? '' : String(storedCode).replace(/[^0-9]/g, '').substring(0, 8));
            if (partyCodeInput) partyCodeInput.value = partyCode;
            if (window.IS_DEBUG) console.log('✅ submitWish: Party-Code aus Storage übernommen (validatedPartyCode):', partyCode);
          }
        }
        // ✅ Wenn immer noch kein Code: Party-ID direkt aus Storage (Landing setzt nur pendingPartyId → validatedPartyId)
        let partyInfo = null;
        const savedPartyId = sessionStorage.getItem('validatedPartyId') || localStorage.getItem('validatedPartyId');
        if ((!partyCode || partyCode === 'manual') && savedPartyId && savedPartyId !== 'manual' && validatePartyId(savedPartyId)) {
          const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), savedPartyId);
          const partyDoc = await window.firebaseGetDoc(partyRef);
          if (partyDoc.exists()) {
            const d = partyDoc.data();
            if (d.lifecycle_status !== 'finished' && d.finished_at == null) {
              partyInfo = { party_id: partyDoc.id, party_code: d.party_code || '', party_name: d.party_name || null };
              if (partyCodeInput) partyCodeInput.value = d.party_code || '';
              if (window.IS_DEBUG) console.log('✅ submitWish: Party-Info aus Storage (validatedPartyId) geladen:', partyInfo.party_id);
            }
          }
        }
        if (!partyInfo) {
          if (partyCode !== 'manual') partyCode = (partyCode == null ? '' : String(partyCode).replace(/[^0-9]/g, '').substring(0, 8));
          partyInfo = await getActivePartyInfo(partyCode);
        }
        let currentPartyId = partyInfo.party_id;
        const currentPartyCode = partyInfo.party_code;
        
        // ✅ Validiere Party-ID (verhindert XSS/Injection über Party-ID)
        if (currentPartyId && !validatePartyId(currentPartyId)) {
          console.error('❌ Ungültige Party-ID erkannt, verwende "manual"');
          currentPartyId = 'manual';
        }

        let currentPartyDjId = null;
        if (currentPartyId && currentPartyId !== 'manual') {
          const currentPartyRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'parties'),
            currentPartyId
          );
          const currentPartySnap = await window.firebaseGetDoc(currentPartyRef);
          currentPartyDjId = currentPartySnap.exists()
            ? String(currentPartySnap.data()?.created_by || '').trim()
            : '';
          if (!currentPartyDjId) {
            showError('Could not determine the party DJ ID.');
            isSubmitting = false;
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
            return;
          }
        }
        
        // ✅ Prüfe Wunsch-Limit
        const limitAllowed = await checkWishLimit(currentPartyId);
        if (!limitAllowed.allowed) {
          const limitMsg = limitAllowed.messageKey
            ? t(limitAllowed.messageKey, typeof limitAllowed.message === 'string' ? limitAllowed.message : '').replace(/\{limit\}/g, String(limitAllowed.limit ?? 2))
            : limitAllowed.message;
          showError(limitMsg);
          isSubmitting = false;
          submitBtn.disabled = true; // ✅ Button deaktivieren bei Limit-Erreichung
          submitBtn.innerHTML = '<span>🚫</span><span>' + (t('wish_limit_reached', 'Limit reached')) + '</span>';
          // Aktualisiere Limit-Info
          await updateWishLimitInfo();
          return;
        }
        
        // Prüfe ob Song bereits gespielt wurde (History/Wishes mit Status: played)
        // Normalisiere Titel und Artist für Duplikat-Prüfung
        const normalizedTitle = title.toLowerCase().trim();
        const normalizedArtist = artist.toLowerCase().trim();
        const spotifyId = selectedSpotifyTrack && selectedSpotifyTrack.id ? selectedSpotifyTrack.id : null;
        
        // ✅ WICHTIG: Stelle sicher, dass currentClientId initialisiert ist
        if (!currentClientId) {
          if (window.IS_DEBUG) console.warn('⚠️ currentClientId nicht initialisiert, berechne jetzt...');
          currentClientId = await getOrCreateClientId(currentPartyId);
        } else {
          // Aktualisiere last_party_id in guest_fingerprints, falls partyId vorhanden
          if (currentPartyId && currentPartyId !== 'manual') {
            try {
              await getOrCreateClientId(currentPartyId); // Aktualisiert last_party_id
            } catch (e) {
              if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Aktualisieren von last_party_id (nicht kritisch):', e);
            }
          }
        }
        if (window.IS_DEBUG) console.log('🔑 submitWish: Verwende currentClientId (Fingerprint):', currentClientId);
        
        // ✅ SCHRITT 1: Prüfe History (Song bereits gespielt)
        if (currentPartyId && currentPartyId !== 'manual') {
          // Cache aktualisieren falls nötig
          await updateHistoryCache(currentPartyId);
          
          const wasPlayed = await checkIfSongWasPlayed(title, artist, currentPartyId);
          
          if (wasPlayed) {
            // Modal-Dialog: Song wurde bereits gespielt (mit Titel und Artist)
            const shouldContinue = await showHistoryDuplicateModal(title, artist);
            
            if (!shouldContinue) {
              // Benutzer hat abgebrochen
              isSubmitting = false;
              submitBtn.disabled = false;
              submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
              return;
            }
          }
        }
        
        // ✅ SCHRITT 2: Prüfe offene Wünsche (Duplikat-Prüfung)
        if (window.IS_DEBUG) console.log('=== DUPLIKAT-PRÜFUNG STARTET ===');
        if (window.IS_DEBUG) console.log('Eingabe: Titel="' + title + '", Artist="' + artist + '"');
        if (window.IS_DEBUG) console.log('Normalisiert: Titel="' + normalizedTitle + '", Artist="' + normalizedArtist + '"');
        if (spotifyId) {
          if (window.IS_DEBUG) console.log('Spotify ID: ' + spotifyId);
        }
        
        if (currentPartyId && currentPartyId !== 'manual') {
          // Cache aktualisieren falls nötig
          await updatePendingWishesCache(currentPartyId);
        }
        
        const similarWish = await findSimilarWish(normalizedTitle, normalizedArtist, spotifyId, currentPartyId);
        
        if (similarWish) {
          if (window.IS_DEBUG) console.log('✓✓✓ DUPLIKAT GEFUNDEN! ✓✓✓');
          if (window.IS_DEBUG) console.log('Original-ID: ' + similarWish.id);
          
          // ✅ Modal-Dialog: Song steht bereits auf Wunschliste (mit Titel und Artist)
          const shouldContinue = await showPendingWishDuplicateModal(title, artist);
          
          if (!shouldContinue) {
            // Benutzer hat abgebrochen
            isSubmitting = false;
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<span>📤</span><span>' + (t('submit_wish', 'Send request')) + '</span>';
            return;
          }
          
          // ✅ Benutzer möchte trotzdem senden - Duplikat wird aktualisiert (wie bisher)
          
          // Echtes Original-Dokument: Wenn Treffer ein Duplikat ist, dessen original_wish_id verwenden
          const actualOriginalId = (similarWish.data.is_duplicate === true && similarWish.data.original_wish_id)
            ? similarWish.data.original_wish_id
            : similarWish.id;
          let originalData = similarWish.data;
          if (actualOriginalId !== similarWish.id) {
            const realOriginalRef = window.firebaseDoc(
              window.firebaseCollection(window.firebaseDb, 'wishes'),
              actualOriginalId
            );
            const realOriginalSnap = await window.firebaseGetDoc(realOriginalRef);
            if (realOriginalSnap.exists()) {
              originalData = realOriginalSnap.data();
            }
          }
          
          const originalWishRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'wishes'),
            actualOriginalId
          );
          const currentCount = (originalData.duplicate_count || 0);
          const requestedBy = Array.isArray(originalData.requested_by) ? [...originalData.requested_by] : [];
          // ✅ Sanitize Name vor dem Hinzufügen
          const sanitizedName = sanitizeInput(name);
          if (sanitizedName && !requestedBy.includes(sanitizedName)) {
            requestedBy.push(sanitizedName);
          }
          
          const greetings = Array.isArray(originalData.greetings) ? [...originalData.greetings] : [];
          if (greeting && greeting.trim()) {
            // ✅ Sanitize Name und Greeting vor dem Hinzufügen
            greetings.push({ name: sanitizedName, greeting: sanitizeInput(greeting) });
          }
          
          const existingIsRegisteredUsers = originalData.is_registered_users || {};
          if (!existingIsRegisteredUsers[name]) {
            existingIsRegisteredUsers[name] = false; // PWA = immer Gast
          }
          
          const updateData = {
            duplicate_count: currentCount + 1,
            requested_by: requestedBy,
            greetings: greetings,
            is_registered_users: existingIsRegisteredUsers
          };
          
          try {
            await window.firebaseUpdateDoc(originalWishRef, updateData);
            if (window.IS_DEBUG) console.log('✓✓✓ Ursprünglicher Wunsch erfolgreich aktualisiert! ✓✓✓');
          } catch (error) {
            console.error('Fehler beim Aktualisieren des ursprünglichen Wunsches:', error);
            // Falls Update fehlschlägt, erstelle trotzdem einen neuen Wunsch
          }
          
          // Erstelle trotzdem einen eigenen Wunsch-Eintrag (für User-Sichtbarkeit)
          // ✅ Stelle sicher, dass currentClientId gesetzt ist
          if (!currentClientId) {
            console.error('❌ KRITISCHER FEHLER: currentClientId ist nicht initialisiert!');
            currentClientId = await getOrCreateClientId(currentPartyId);
          }
          
          // ✅ PFlicht-Felder: Stelle sicher, dass client_id und party_id Strings sind
          const wishData = {
            name: name,
            title: title || '',
            artist: artist || '',
            status: 'pending',
            createdAt: window.firebaseServerTimestamp(),
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
            isSeen: false // ✅ FIX: Neuer Wunsch ist ungelesen
          };
          
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
            window.firebaseCollection(window.firebaseDb, 'wishes'),
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
          
          // ✅ WICHTIG: Stelle sicher, dass currentClientId bereits initialisiert ist
          if (!currentClientId) {
            console.error('❌ KRITISCHER FEHLER: currentClientId ist nicht initialisiert!');
            // Fallback: Initialisiere currentClientId erneut
            currentClientId = await getOrCreateClientId(currentPartyId);
            if (window.IS_DEBUG) console.warn('⚠️ Verwende Fallback currentClientId:', currentClientId);
          }
          
          // Kein Duplikat - erstelle neuen Wunsch
          // ✅ BEREINIGT: Nur erlaubte Felder (keine duplicate_count, requested_by, greetings, is_registered_users)
          const wishData = {
            name: name,
            title: title || '',
            artist: artist || '',
            status: 'pending',
            createdAt: window.firebaseServerTimestamp(),
            is_duplicate: false,
            is_registered_user: false,
            client_id: String(currentClientId || ''), // ✅ EXPLIZIT String, nicht null/undefined
            device_id: String(currentClientId || ''), // ✅ Hardware/Fingerprint-Anker
            party_id: String(currentPartyId || ''), // ✅ EXPLIZIT String, nicht null/undefined
            party_code: currentPartyCode || '',
            dj_id: String(currentPartyDjId || ''),
            djId: String(currentPartyDjId || ''),
            timestamp: window.firebaseServerTimestamp(), // ✅ Pflichtfeld für serverseitige Rule-Prüfung
            isSeen: false // ✅ FIX: Neuer Wunsch ist ungelesen
          };
          
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
            window.firebaseCollection(window.firebaseDb, 'wishes'),
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
        successMessage.classList.add('show');
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
        
        // ✅ Prüfe Limit im Hintergrund (BEVOR Button angezeigt wird)
        const limitInfo = await checkWishLimit(currentPartyId);
        
        // ✅ Verstecke Lade-Status
        if (successLoading) {
          successLoading.style.display = 'none';
        }
        
        // ✅ Zeige Button oder Limit-Text basierend auf Ergebnis
        if (limitInfo.allowed && limitInfo.remaining > 0) {
          // Noch Wünsche frei - zeige Button
          if (successButtonContainer) {
            successButtonContainer.style.display = 'block';
          }
          if (successLimitReached) {
            successLimitReached.style.display = 'none';
          }
        } else {
          // Limit erreicht - zeige Text
          if (successButtonContainer) {
            successButtonContainer.style.display = 'none';
          }
          if (successLimitReached) {
            successLimitReached.style.display = 'block';
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
            
            // Formular wieder anzeigen
            form.style.display = 'block';
            
            // ✅ Limit wird durch onSnapshot-Stream aktuell gehalten – kein updateWishLimitInfo nötig
            
            // Scroll nach oben
            window.scrollTo({ top: 0, behavior: 'smooth' });
          });
        }
        
        // Wenn Track von Spotify ausgewählt wurde, Musikdatenbank aktualisieren (Fire & Forget)
        // Läuft asynchron im Hintergrund, blockiert nicht die Erfolgsmeldung
        if (selectedSpotifyTrack && selectedSpotifyTrack.id) {
          // Hole DJ-ID aus der Party-Dokumentation
          let djId = null;
          try {
            if (currentPartyId && currentPartyId !== 'manual') {
              const partyDocRef = window.firebaseDoc(window.firebaseDb, 'parties', currentPartyId);
              const partyDoc = await window.firebaseGetDoc(partyDocRef);
              if (partyDoc.exists()) {
                const partyData = partyDoc.data();
                djId = partyData.dj_code || partyData.created_by || null;
                if (window.IS_DEBUG) console.log('✅ DJ-ID aus Party geholt:', djId);
              }
            }
          } catch (e) {
            console.error('⚠️ Fehler beim Holen der DJ-ID (nicht kritisch):', e);
          }
          
          // Rufe asynchron auf, ohne await - User bekommt sofort Bestätigung (partyId für Security: wishes-Query nur mit party_id)
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
        
        // Aktualisiere guestStats (nur für Gäste, nur wenn Party-ID vorhanden)
        // In der PWA sind alle Benutzer Gäste (keine Authentifizierung)
        if (currentPartyId !== 'manual') {
          await updateGuestStats(currentPartyId);
          // Erhöhe lokale Stats sofort (optimistische Aktualisierung)
          if (typeof window.currentWishStats !== 'undefined' && window.currentWishStats) {
            window.currentWishStats.current = (window.currentWishStats.current || 0) + 1;
            window.currentWishStats.remaining = Math.max(0, (window.currentWishStats.limit || 2) - window.currentWishStats.current);
          }
          // ✅ Limit-Anzeige aktualisiert sich über onSnapshot-Stream – kein Polling nach Submit
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
    });

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

    function showError(message) {
      errorMessage.textContent = message;
      errorMessage.classList.add('show');
    }

    // Fehlermeldung verstecken
    function hideError() {
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
          const wishesRef = window.firebaseCollection(window.firebaseDb, 'wishes');
          const wishesQuery = window.firebaseQuery(
            wishesRef,
            window.firebaseWhere('client_id', '==', currentClientId),
            window.firebaseWhere('party_id', '==', partyId),
            window.firebaseWhere('createdAt', '>=', window.firebaseTimestamp.fromDate(currentFullHour))
          );
          
          const wishesSnapshot = await window.firebaseGetDocs(wishesQuery);
          const recentWishesCount = wishesSnapshot.size;
          
          if (window.IS_DEBUG) console.log(`📊 Gast-Wünsche in dieser vollen Stunde: ${recentWishesCount} / ${guestLimit}`);
          
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
    
    // Erstellt einen Hardware-Fingerprint für persistente Identifikation
    function createHardwareFingerprint() {
      const components = [];
      
      // Browser-Eigenschaften
      if (navigator.userAgent) components.push(navigator.userAgent);
      if (navigator.language) components.push(navigator.language);
      if (navigator.languages && navigator.languages.length > 0) {
        components.push(navigator.languages.join(','));
      }
      if (navigator.platform) components.push(navigator.platform);
      if (navigator.hardwareConcurrency) components.push(navigator.hardwareConcurrency.toString());
      if (navigator.deviceMemory) components.push(navigator.deviceMemory.toString());
      
      // Bildschirm-Eigenschaften
      if (screen.width) components.push(screen.width.toString());
      if (screen.height) components.push(screen.height.toString());
      if (screen.colorDepth) components.push(screen.colorDepth.toString());
      if (screen.pixelDepth) components.push(screen.pixelDepth.toString());
      
      // Zeitzone
      try {
        components.push(Intl.DateTimeFormat().resolvedOptions().timeZone);
      } catch (e) {}
      
      // Canvas-Fingerprint (sehr zuverlässig, aber optional)
      try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        if (ctx) {
          ctx.textBaseline = 'top';
          ctx.font = '14px Arial';
          ctx.fillText('Hardware fingerprint 🔒', 2, 2);
          components.push(canvas.toDataURL());
        }
      } catch (e) {
        // Canvas nicht verfügbar, überspringen
      }
      
      // WebGL-Fingerprint (optional)
      try {
        const gl = document.createElement('canvas').getContext('webgl');
        if (gl) {
          const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
          if (debugInfo) {
            components.push(gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL));
            components.push(gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL));
          }
        }
      } catch (e) {
        // WebGL nicht verfügbar, überspringen
      }
      
      // Kombiniere alle Komponenten und erstelle Hash
      const fingerprintString = components.join('|');
      
      // Einfacher Hash (für Konsistenz)
      let hash = 0;
      for (let i = 0; i < fingerprintString.length; i++) {
        const char = fingerprintString.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash; // Convert to 32bit integer
      }
      
      return Math.abs(hash).toString(36);
    }
    
    // Erstellt clientId basierend auf Hardware-Fingerprint (immer stabil, auch nach Cache-Löschung)
    // Format: fp_xxxxxx (z.B. fp_awxad2)
    // partyId: Optional - wird als last_party_id in guest_fingerprints gespeichert
    async function getOrCreateClientId(partyId = null) {
      // HARDWARE-FIRST: Immer zuerst Hardware-Fingerprint berechnen
      if (window.IS_DEBUG) console.log('🔧 Berechne Hardware-Fingerprint...');
      
      let fingerprint;
      try {
        fingerprint = createHardwareFingerprint();
        if (window.IS_DEBUG) console.log('🔑 Hardware-Fingerprint berechnet:', fingerprint);
      } catch (e) {
        console.error('❌ KRITISCHER FEHLER: Hardware-Fingerprint konnte nicht berechnet werden:', e);
        // KEIN Fallback mehr - Hardware-Fingerprint ist Pflicht
        throw new Error('Hardware fingerprint could not be calculated. Please update your browser.');
      }
      
      // Präfix fp_ hinzufügen für saubere IDs in der Datenbank
      let clientId = 'fp_' + fingerprint;
      if (window.IS_DEBUG) console.log('✅ Finale clientId (mit Präfix):', clientId);
      
      // Optional: Speichere in localStorage für schnelleren Zugriff (aber nicht kritisch)
      try {
        localStorage.setItem('guest_client_id', clientId);
      } catch (e) {
        if (window.IS_DEBUG) console.warn('⚠️ localStorage nicht verfügbar (z.B. Inkognito-Modus), aber das ist OK:', e);
      }
      
      // WICHTIG: Immer in Firestore speichern/aktualisieren
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
      if (cachePartyId === partyId && localHistoryCache.length > 0) {
        return; // Cache ist aktuell
      }
      
      try {
        localHistoryCache = [];
        
        // 1. Prüfe in music_history – Filter: party_id (mit Unterstrich)
        const historySessionsQuery = window.firebaseQuery(
          window.firebaseCollection(window.firebaseDb, 'music_history'),
          window.firebaseWhere('party_id', '==', partyId)
        );
        const historySessionsSnapshot = await window.firebaseGetDocs(historySessionsQuery);

        for (const sessionDoc of historySessionsSnapshot.docs) {
          const tracksRef = window.firebaseCollection(
            window.firebaseDb,
            'music_history/' + sessionDoc.id + '/tracks'
          );
          const tracksRecentQ = window.firebaseQuery(
            tracksRef,
            window.firebaseOrderBy('timestamp', 'desc'),
            window.firebaseLimit(PWA_FS_RECENT_TRACKS_PER_SESSION)
          );
          const tracksSnapshot = await window.firebaseGetDocs(tracksRecentQ);

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
          window.firebaseCollection(window.firebaseDb, 'wishes'),
          window.firebaseWhere('party_id', '==', partyId),
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

        // Lade duplicate_threshold und ignored_keywords aus party_settings/current (Abgleich mit DJ-App)
        let threshold = 0.85; // Fallback
        let ignoredKeywords = IGNORED_KEYWORDS_DEFAULT.slice();
        try {
          const settingsRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'party_settings'),
            'current'
          );
          const settingsDoc = await window.firebaseGetDoc(settingsRef);
          if (settingsDoc.exists()) {
            const settingsData = settingsDoc.data();
            if (settingsData.duplicate_threshold != null) {
              threshold = settingsData.duplicate_threshold;
            }
            if (settingsData.ignored_keywords != null && Array.isArray(settingsData.ignored_keywords) && settingsData.ignored_keywords.length > 0) {
              ignoredKeywords = settingsData.ignored_keywords.filter(k => k != null && String(k).trim()).map(k => String(k).trim());
            }
          }
        } catch (e) {
          if (window.IS_DEBUG) console.log('⚠️ Konnte Schwellenwert nicht laden, verwende Standard: 85%');
        }

        // Normalisiere für Vergleich (Klammern/Mix-Begriffe entfernen wie in DJ-App)
        const normalizedTitle = normalizeTextForDuplicateCheck(title, ignoredKeywords);
        const normalizedArtist = normalizeTextForDuplicateCheck(artist, ignoredKeywords);

        if (!normalizedTitle && !normalizedArtist) {
          return false; // Keine Daten zum Vergleichen
        }

        // ✅ SCHRITT 1: Prüfe zuerst lokalen Cache
        if (cachePartyId === partyId && localHistoryCache.length > 0) {
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
          // Cache aktualisieren wenn nötig
          await updateHistoryCache(partyId);
          // Nach Cache-Update nochmal prüfen
          if (cachePartyId === partyId && localHistoryCache.length > 0) {
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

        // ✅ SCHRITT 2: Fallback auf Firestore (nur wenn Cache leer oder nicht aktuell)
        // Dies sollte selten vorkommen, da Cache normalerweise aktuell ist
        if (window.IS_DEBUG) console.log('⚠️ Fallback auf Firestore für History-Check (Cache nicht verfügbar)');
        
        // 1. Prüfe in music_history (History) – Filter: party_id
        try {
          const historySessionsQuery = window.firebaseQuery(
            window.firebaseCollection(window.firebaseDb, 'music_history'),
            window.firebaseWhere('party_id', '==', partyId)
          );
          const historySessionsSnapshot = await window.firebaseGetDocs(historySessionsQuery);

          for (const sessionDoc of historySessionsSnapshot.docs) {
            const tracksRef = window.firebaseCollection(
              window.firebaseDb,
              'music_history/' + sessionDoc.id + '/tracks'
            );
            const tracksRecentQ = window.firebaseQuery(
              tracksRef,
              window.firebaseOrderBy('timestamp', 'desc'),
              window.firebaseLimit(PWA_FS_RECENT_TRACKS_PER_SESSION)
            );
            const tracksSnapshot = await window.firebaseGetDocs(tracksRecentQ);

            for (const trackDoc of tracksSnapshot.docs) {
              const trackData = trackDoc.data();
              const trackTitle = normalizeTextForDuplicateCheck(trackData.title || '', ignoredKeywords);
              const trackArtist = normalizeTextForDuplicateCheck(trackData.artist || '', ignoredKeywords);

              if (!trackTitle && !trackArtist) continue;

              let titleSimilarity = 0.0;
              let artistSimilarity = 0.0;

              if (normalizedTitle && trackTitle) {
                titleSimilarity = stringSimilarity(normalizedTitle, trackTitle);
              }

              if (normalizedArtist && trackArtist) {
                artistSimilarity = stringSimilarity(normalizedArtist, trackArtist);
              }

              const avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

              if (avgSimilarity >= threshold) {
                if (window.IS_DEBUG) console.log('✅ Song bereits in History gefunden (Firestore) (Ähnlichkeit: ' + (avgSimilarity * 100).toFixed(1) + '%)');
                return true;
              }
            }
          }
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Prüfen der History:', e);
        }

        // 2. Prüfe in wishes (Status: played)
        try {
          const playedWishesQuery = window.firebaseQuery(
            window.firebaseCollection(window.firebaseDb, 'wishes'),
            window.firebaseWhere('party_id', '==', partyId),
            window.firebaseWhere('status', '==', 'played'),
            window.firebaseOrderBy('createdAt', 'desc'),
            window.firebaseLimit(PWA_FS_RECENT_PLAYED_WISHES)
          );
          const playedWishesSnapshot = await window.firebaseGetDocs(playedWishesQuery);

          for (const wishDoc of playedWishesSnapshot.docs) {
            const wishData = wishDoc.data();
            const wishTitle = normalizeTextForDuplicateCheck(wishData.title || wishData.song || '', ignoredKeywords);
            const wishArtist = normalizeTextForDuplicateCheck(wishData.artist || '', ignoredKeywords);

            if (!wishTitle && !wishArtist) continue;

            let titleSimilarity = 0.0;
            let artistSimilarity = 0.0;

            if (normalizedTitle && wishTitle) {
              titleSimilarity = stringSimilarity(normalizedTitle, wishTitle);
            }

            if (normalizedArtist && wishArtist) {
              artistSimilarity = stringSimilarity(normalizedArtist, wishArtist);
            }

            const avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

            if (avgSimilarity >= threshold) {
              if (window.IS_DEBUG) console.log('✅ Song bereits als gespielter Wunsch gefunden (Firestore): "' + wishTitle + ' - ' + wishArtist + '" (Ähnlichkeit: ' + (avgSimilarity * 100).toFixed(1) + '%)');
              return true;
            }
          }
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Prüfen der gespielten Wünsche:', e);
        }

        return false; // Song wurde nicht gefunden
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
      if (cachePartyId === partyId && localPendingWishesCache.length > 0) {
        return; // Cache ist aktuell
      }
      
      try {
        localPendingWishesCache = [];
        
        const wishesQuery = window.firebaseQuery(
          window.firebaseCollection(window.firebaseDb, 'wishes'),
          window.firebaseWhere('party_id', '==', partyId),
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
        
        // Lade Schwellenwert und ignorierte Begriffe aus party_settings/current
        let duplicateThreshold = 0.95; // Standard: 95%
        let ignoredKeywords = IGNORED_KEYWORDS_DEFAULT.slice();
        try {
          const settingsRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'party_settings'),
            'current'
          );
          const settingsDoc = await window.firebaseGetDoc(settingsRef);
          if (settingsDoc.exists()) {
            const settingsData = settingsDoc.data();
            if (settingsData.duplicate_threshold != null) {
              duplicateThreshold = settingsData.duplicate_threshold;
            }
            if (settingsData.ignored_keywords != null && Array.isArray(settingsData.ignored_keywords) && settingsData.ignored_keywords.length > 0) {
              ignoredKeywords = settingsData.ignored_keywords.filter(k => k != null && String(k).trim()).map(k => String(k).trim());
            }
          }
        } catch (e) {
          if (window.IS_DEBUG) console.log('⚠️ Konnte Schwellenwert nicht laden, verwende Standard: 95%');
        }
        
        if (window.IS_DEBUG) console.log('📊 Verwendeter Schwellenwert: ' + (duplicateThreshold * 100).toFixed(0) + '%');
        // Mindest-Ähnlichkeit für Titel/Artist (Zusatz-Check): max. 0.85, aber nie höher als Admin-Schwellenwert (Master-Kontrolle)
        const minTitleArtist = Math.min(0.85, duplicateThreshold);
        
        // Hole Party-Informationen für Zeitraum-Prüfung
        let partyStartDate = null;
        let partyEndDate = null;
        try {
          const partyRef = window.firebaseDoc(
            window.firebaseCollection(window.firebaseDb, 'parties'),
            partyId
          );
          const partyDoc = await window.firebaseGetDoc(partyRef);
          
          if (partyDoc.exists()) {
            const partyData = partyDoc.data();
            const startTimestamp = partyData.start_date;
            const endTimestamp = partyData.end_date;
            
            if (startTimestamp && endTimestamp) {
              partyStartDate = startTimestamp.toDate();
              partyEndDate = endTimestamp.toDate();
              if (window.IS_DEBUG) console.log('📅 Party-Zeitraum: ' + partyStartDate + ' bis ' + partyEndDate);
            }
          }
        } catch (e) {
          if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Laden der Party-Informationen:', e);
        }
        
        // ✅ SCHRITT 1: Prüfe zuerst lokalen Cache
        if (cachePartyId === partyId && localPendingWishesCache.length > 0) {
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
        } else {
          // Cache aktualisieren wenn nötig
          await updatePendingWishesCache(partyId);
          // Nach Cache-Update nochmal prüfen (gleiche Logik wie oben)
          if (cachePartyId === partyId && localPendingWishesCache.length > 0) {
            if (window.IS_DEBUG) console.log('🔍 Prüfe aktualisierten Cache (' + localPendingWishesCache.length + ' Einträge)...');
            
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
                  
                  if (window.IS_DEBUG) console.log('✓✓✓ EXAKTE SPOTIFY_ID-ÜBEREINSTIMMUNG IM AKTUALISIERTEN CACHE GEFUNDEN! ✓✓✓');
                  return {
                    id: cachedWish.id,
                    data: cachedWish.data,
                    similarity: 1.0,
                    matchType: 'spotify_id'
                  };
                }
              }
            }
            
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
              if (window.IS_DEBUG) console.log('✅ Ähnlicher Wunsch im aktualisierten Cache gefunden (Ähnlichkeit: ' + (bestMatch.similarity * 100).toFixed(1) + '%)');
              return bestMatch;
            }
          }
        }
        
        // ✅ SCHRITT 2: Fallback auf Firestore (nur wenn Cache leer oder nicht aktuell)
        if (window.IS_DEBUG) console.log('⚠️ Fallback auf Firestore für Pending-Wishes-Check (Cache nicht verfügbar)');
        
        const wishesRef = window.firebaseCollection(window.firebaseDb, 'wishes');
        let wishesQuery;
        
        try {
          wishesQuery = window.firebaseQuery(
            wishesRef,
            window.firebaseWhere('party_id', '==', partyId),
            window.firebaseWhere('status', '==', 'pending'),
            window.firebaseOrderBy('createdAt', 'desc'),
            window.firebaseLimit(PWA_FS_PENDING_WISHES_CAP)
          );
          if (window.IS_DEBUG) console.log('✅ Query erstellt mit party_id:', partyId);
        } catch (queryError) {
          console.error('❌ Fehler beim Erstellen der Query:', queryError);
          return null;
        }
        
        let wishesSnapshot;
        try {
          wishesSnapshot = await window.firebaseGetDocs(wishesQuery);
          if (window.IS_DEBUG) console.log('✅ Query ausgeführt, ' + wishesSnapshot.docs.length + ' Dokumente gefunden');
        } catch (fetchError) {
          console.error('❌ Fehler beim Ausführen der Query:', fetchError);
          return null;
        }
        
        if (window.IS_DEBUG) console.log('Anzahl zu prüfender Wünsche: ' + wishesSnapshot.docs.length);
        
        // ZUERST: Prüfe auf exakte spotify_id-Übereinstimmung (höchste Priorität)
        if (spotifyId && spotifyId.trim()) {
          if (window.IS_DEBUG) console.log('=== PRÜFE SPOTIFY_ID: ' + spotifyId + ' ===');
          for (const doc of wishesSnapshot.docs) {
            const data = doc.data();
            
            if (data.is_duplicate === true) continue;
            
            const existingSpotifyId = data.spotify_id;
            if (existingSpotifyId && existingSpotifyId === spotifyId) {
              const createdAt = data.createdAt;
              if (!createdAt) continue;
              
              const createdDate = createdAt.toDate();
              
              if (partyStartDate && partyEndDate) {
                if (createdDate < partyStartDate || createdDate >= partyEndDate) {
                  continue;
                }
              }
              
              if (window.IS_DEBUG) console.log('✓✓✓ EXAKTE SPOTIFY_ID-ÜBEREINSTIMMUNG GEFUNDEN (Firestore)! ✓✓✓');
              return {
                id: doc.id,
                data: data,
                similarity: 1.0,
                matchType: 'spotify_id'
              };
            }
          }
          if (window.IS_DEBUG) console.log('✗ Keine spotify_id-Übereinstimmung gefunden, prüfe String-Ähnlichkeit...');
        }
        
        // ZWEITENS: Prüfe auf String-Ähnlichkeit (für manuell eingegebene Wünsche; Mix/Remix-Zusätze werden für Vergleich entfernt)
        let bestSimilarity = 0.0;
        let bestMatch = null;
        
        const normalizedInputTitle = normalizeTextForDuplicateCheck(normalizedTitle, ignoredKeywords);
        const normalizedInputArtist = normalizeTextForDuplicateCheck(normalizedArtist, ignoredKeywords);
        
        for (const doc of wishesSnapshot.docs) {
          const data = doc.data();
          
          // Überspringe Duplikate (nur Original-Wünsche prüfen)
          if (data.is_duplicate === true) {
            continue;
          }
          
          // Prüfe, ob der Wunsch innerhalb der Party-Zeit erstellt wurde
          const createdAt = data.createdAt;
          if (!createdAt) {
            continue;
          }
          
          const createdDate = createdAt.toDate();
          
          // Wenn Party-Zeitraum vorhanden, prüfe ob Wunsch innerhalb liegt
          if (partyStartDate && partyEndDate) {
            if (createdDate < partyStartDate || createdDate >= partyEndDate) {
              continue;
            }
          }
          
          const existingTitle = normalizeTextForDuplicateCheck(data.title || data.song || '', ignoredKeywords);
          const existingArtist = normalizeTextForDuplicateCheck(data.artist || '', ignoredKeywords);
          
          // VERGLEICHS-DETAILS: Logge Titel aus DB
          if (window.IS_DEBUG) console.log(`🔍 VERGLEICH [${doc.id}]: Prüfe "${normalizedInputTitle}" (${normalizedInputArtist}) gegen DB: "${data.title || '(kein Titel)'}" (${data.artist || '(kein Artist)'})`);
          
          // Berechne Ähnlichkeit für Titel und Artist
          let titleSimilarity = 0.0;
          let artistSimilarity = 0.0;
          
          if (normalizedInputTitle && existingTitle) {
            titleSimilarity = stringSimilarity(normalizedInputTitle, existingTitle);
          }
          
          if (normalizedInputArtist && existingArtist) {
            artistSimilarity = stringSimilarity(normalizedInputArtist, existingArtist);
          }
          
          // Kombinierte Ähnlichkeit
          let combinedSimilarity = 0.0;
          if (normalizedInputTitle && normalizedInputArtist) {
            // Beide Felder vorhanden - gewichteter Durchschnitt
            combinedSimilarity = (titleSimilarity * 0.7 + artistSimilarity * 0.3);
          } else if (normalizedInputTitle) {
            // Nur Titel vorhanden
            combinedSimilarity = titleSimilarity;
          } else if (normalizedInputArtist) {
            // Nur Artist vorhanden
            combinedSimilarity = artistSimilarity;
          }
          
          // VERGLEICHS-DETAILS: Logge berechnete Werte
          if (window.IS_DEBUG) console.log(`  📊 titleSimilarity: ${titleSimilarity.toFixed(4)}, artistSimilarity: ${artistSimilarity.toFixed(4)}, combinedSimilarity: ${combinedSimilarity.toFixed(4)}`);
          if (window.IS_DEBUG) console.log(`  📊 duplicateThreshold: ${duplicateThreshold.toFixed(4)} (${(duplicateThreshold * 100).toFixed(0)}%), titleThreshold: ${(duplicateThreshold * 0.7).toFixed(4)} (${(duplicateThreshold * 0.7 * 100).toFixed(0)}%)`);
          
          // ✅ VERSCHÄRFTER Schwellenwert für Duplikat-Erkennung
          // Ein Song ist nur dann ein Duplikat, wenn:
          // 1. BEIDE (Titel UND Artist) sehr ähnlich sind (>= 80% des Schwellenwerts) UND kombinierte Ähnlichkeit >= Schwellenwert
          // ODER
          // 2. Kombinierte Ähnlichkeit >= Schwellenwert (sehr hohe Gesamtähnlichkeit)
          const titleThreshold = duplicateThreshold * 0.8; // 80% des Schwellenwerts für Titel (verschärft)
          const artistThreshold = duplicateThreshold * 0.8; // 80% des Schwellenwerts für Artist (verschärft)
          
          // ✅ LOGIK-FIX: Prüfe BEIDE Bedingungen explizit
          const titleMatch = titleSimilarity >= titleThreshold;
          const artistMatch = artistSimilarity >= artistThreshold;
          const combinedMatch = combinedSimilarity >= duplicateThreshold;
          const bestMatchCondition = combinedSimilarity > bestSimilarity;
          // Zusatzbedingung: Titel- und Artist-Match jeweils >= minTitleArtist (von Admin-Schwellenwert begrenzt, Master-Kontrolle)
          const titleArtistMin = titleSimilarity >= minTitleArtist && artistSimilarity >= minTitleArtist;
          
          // ✅ STRENGE BEDINGUNG: (Titel UND Artist jeweils >= minTitleArtist) UND ((Titel/Artist ähnlich) ODER kombinierte Ähnlichkeit >= Schwellenwert)
          const isDuplicate = titleArtistMin && ((titleMatch && artistMatch) || combinedMatch) && bestMatchCondition;
          
          // ✅ DETAILLIERTES LOGGING für Debugging
          if (window.IS_DEBUG) console.log(`  📊 THRESHOLD-VERGLEICH:`);
          if (window.IS_DEBUG) console.log(`     - titleSimilarity: ${titleSimilarity.toFixed(4)} vs titleThreshold: ${titleThreshold.toFixed(4)} → ${titleMatch ? '✅ ERFÜLLT' : '❌ NICHT ERFÜLLT'}`);
          if (window.IS_DEBUG) console.log(`     - artistSimilarity: ${artistSimilarity.toFixed(4)} vs artistThreshold: ${artistThreshold.toFixed(4)} → ${artistMatch ? '✅ ERFÜLLT' : '❌ NICHT ERFÜLLT'}`);
          if (window.IS_DEBUG) console.log(`     - combinedSimilarity: ${combinedSimilarity.toFixed(4)} vs duplicateThreshold: ${duplicateThreshold.toFixed(4)} → ${combinedMatch ? '✅ ERFÜLLT' : '❌ NICHT ERFÜLLT'}`);
          if (window.IS_DEBUG) console.log(`     - combinedSimilarity > bestSimilarity: ${combinedSimilarity.toFixed(4)} > ${bestSimilarity.toFixed(4)} → ${bestMatchCondition ? '✅ ERFÜLLT' : '❌ NICHT ERFÜLLT'}`);
          if (window.IS_DEBUG) console.log(`     - FINALE ENTSCHEIDUNG: (titleMatch && artistMatch) || combinedMatch = (${titleMatch} && ${artistMatch}) || ${combinedMatch} = ${(titleMatch && artistMatch) || combinedMatch}`);
          if (window.IS_DEBUG) console.log(`     - GESAMT-BEDINGUNG: ${isDuplicate ? '✅ DUPLIKAT ERKANNT' : '❌ KEIN DUPLIKAT'}`);
          
          if (isDuplicate) {
            bestSimilarity = combinedSimilarity;
            bestMatch = {
              id: doc.id,
              data: data,
              similarity: combinedSimilarity,
              titleSimilarity: titleSimilarity,
              artistSimilarity: artistSimilarity,
              matchType: 'string_similarity'
            };
            // MATCH-ENTSCHEIDUNG: Detailliertes Log
            if (window.IS_DEBUG) console.log(`🎯 TREFFER: Vergleiche "${normalizedTitle}" (${normalizedArtist}) mit "${data.title || '(kein Titel)'}" (${data.artist || '(kein Artist)'}) - Ergebnis: ${combinedSimilarity.toFixed(4)} (${(combinedSimilarity * 100).toFixed(2)}%)`);
            if (window.IS_DEBUG) console.log(`  ✅ DUPLIKAT ERKANNT: Ähnlichkeit: ${combinedSimilarity.toFixed(4)}`);
          } else {
            if (window.IS_DEBUG) console.log(`  ❌ KEIN DUPLIKAT: Bedingungen nicht erfüllt`);
          }
        }
        
        if (bestMatch) {
          if (window.IS_DEBUG) console.log('✓✓✓ DUPLIKAT BESTÄTIGT! ID: ' + bestMatch.id + ', Ähnlichkeit: ' + bestMatch.similarity);
          if (window.IS_DEBUG) console.log(`📌 FINALES MATCH: doc.id="${bestMatch.id}", title="${bestMatch.data.title || '(kein Titel)'}", artist="${bestMatch.data.artist || '(kein Artist)'}", matchType="${bestMatch.matchType}"`);
        } else {
          if (window.IS_DEBUG) console.log('✗ Kein Duplikat gefunden');
          if (window.IS_DEBUG) console.log('📌 FINALE ENTSCHEIDUNG: Kein Match gefunden - Wunsch wird als NEU markiert');
        }
        
        return bestMatch;
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

    /** Ein Dokument aus `parties` per Join-Code: party_code / fixed_party_code (nur 8-stellig). */
    async function findPartyDocByJoinCode(partyCode) {
      if (!partyCode || partyCode === 'manual') return null;
      const partiesRef = window.firebaseCollection(window.firebaseDb, 'parties');
      const numericCode = parseInt(partyCode, 10);
      // Align mit firestore.rules partyGuestJoinCodeListAllowed (kein anonymes List ohne lifecycle-Filter)
      const lifecycleJoin = ['active', 'finished', 'standby'];
      const tryField = async (field, value) => {
        const q = window.firebaseQuery(
          partiesRef,
          window.firebaseWhere(field, '==', value),
          window.firebaseWhere('lifecycle_status', 'in', lifecycleJoin)
        );
        const snap = await window.firebaseGetDocs(q);
        return snap.docs.length > 0 ? snap.docs[0] : null;
      };
      let doc = await tryField('party_code', partyCode);
      if (doc) return doc;
      if (!isNaN(numericCode)) {
        doc = await tryField('party_code', numericCode);
        if (doc) return doc;
      }
      doc = await tryField('fixed_party_code', partyCode);
      if (doc) return doc;
      if (!isNaN(numericCode)) {
        doc = await tryField('fixed_party_code', numericCode);
        if (doc) return doc;
      }
      return null;
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
    async function getActivePartyInfo(partyCode) {
      try {
        const now = new Date();
        const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        
        // Wenn ein spezifischer Party-Code übergeben wurde, suche direkt danach
        if (partyCode && partyCode !== 'manual') {
          if (window.IS_DEBUG) console.log('🔍 Suche direkt nach Party-Code: ' + partyCode);
          const partyDoc = await findPartyDocByJoinCode(partyCode);
          if (partyDoc) {
            const data = partyDoc.data();
            if (data.lifecycle_status === 'finished' || data.finished_at != null) {
              if (window.IS_DEBUG) console.log('⚠️ Party mit Code "' + partyCode + '" ist beendet (lifecycle_status/finished_at)');
            } else {
              const partyCodeFromDb = data.party_code;
              const partyName = data.party_name || null;
              const canonical = partyCodeFromDb != null ? String(partyCodeFromDb) : String(partyCode);
              if (window.IS_DEBUG) console.log('✅ Party gefunden mit Code "' + partyCode + '": Party-ID ' + partyDoc.id + ', Name: ' + (partyName || 'NICHT GEFUNDEN'));
              return {
                party_id: partyDoc.id,
                party_code: canonical,
                party_name: partyName || null
              };
            }
          } else if (window.IS_DEBUG) console.log('⚠️ Keine Party mit Code "' + partyCode + '" gefunden');
        }
        
        // Lade Partys mit gleichen Filtern wie checkWishboxStatus / firestore.rules partyGuestDiscoveryListAllowed
        const partiesRef = window.firebaseCollection(window.firebaseDb, 'parties');
        const partiesQuery = window.firebaseQuery(
          partiesRef,
          window.firebaseWhere('status', '==', 'active'),
          window.firebaseWhere('lifecycle_status', 'in', ['active', 'standby']),
          window.firebaseWhere('end_date', '>=', window.firebaseTimestamp.fromDate(sevenDaysAgo))
        );
        
        const partiesSnapshot = await window.firebaseGetDocs(partiesQuery);
        
        // Zuerst prüfe, ob eine aktive Party läuft
        for (const partyDoc of partiesSnapshot.docs) {
          const data = partyDoc.data();
          if (data.lifecycle_status === 'finished' || data.finished_at != null) continue;
          const startTimestamp = data.start_date;
          const endTimestamp = data.end_date;
          const partyCodeFromDb = data.party_code;
          
          if (startTimestamp && endTimestamp) {
            const startDate = startTimestamp.toDate();
            const endDate = endTimestamp.toDate();
            
            // Prüfe ob Party aktiv ist (jetzt >= Start UND jetzt < Ende)
            if (now >= startDate && now < endDate) {
              // Wenn kein Party-Code übergeben wurde oder der Party-Code / Kurz-Code übereinstimmt
              if (!partyCode || partyCode === 'manual' || partyCode == partyCodeFromDb || partyDataMatchesJoinCode(data, partyCode)) {
                const partyName = data.party_name || null; // ✅ Partyname aus Firestore (kein Fallback mehr)
                if (window.IS_DEBUG) console.log('✅ Aktive Party gefunden: ' + partyDoc.id + ', Party-Code: ' + partyCodeFromDb + ', Name: ' + (partyName || 'NICHT GEFUNDEN'));
                return {
                  party_id: partyDoc.id,
                  party_code: partyCodeFromDb || '',
                  party_name: partyName || null // ✅ Partyname hinzufügen (null wenn nicht vorhanden)
                };
              }
            }
          }
        }
        
        // Keine aktive Party gefunden - wenn ein Code übergeben wurde, erneut inkl. Kurz-Code-Felder (auch älter als 7 Tage)
        if (partyCode && partyCode !== 'manual') {
          if (window.IS_DEBUG) console.log('ℹ️ Keine aktive Party gefunden, verwende übergebenen Party-Code: ' + partyCode);
          try {
            const partyDoc = await findPartyDocByJoinCode(partyCode);
            if (partyDoc) {
              const data = partyDoc.data();
              if (data.lifecycle_status === 'finished' || data.finished_at != null) {
                if (window.IS_DEBUG) console.log('⚠️ Party mit Code "' + partyCode + '" ist beendet, wird nicht als aktiv zurückgegeben');
              } else {
                const partyName = data.party_name || null;
                const canonical = data.party_code != null ? String(data.party_code) : String(partyCode);
                if (window.IS_DEBUG) console.log('✅ Party gefunden (auch wenn beendet): Party-ID ' + partyDoc.id + ', Name: ' + (partyName || 'NICHT GEFUNDEN'));
                return {
                  party_id: partyDoc.id,
                  party_code: canonical,
                  party_name: partyName || null
                };
              }
            }
          } catch (e) {
            console.error('Fehler bei zweiter Party-Suche:', e);
          }
        }
        
        // Fallback: Verwende übergebenen Code oder 'manual'
        if (window.IS_DEBUG) console.log('ℹ️ Keine Party gefunden, verwende Fallback');
        return {
          party_id: 'manual',
          party_code: partyCode || 'manual',
          party_name: null // ✅ Kein Fallback-Partyname mehr
        };
      } catch (error) {
        console.error('❌ Fehler beim Prüfen der aktiven Party:', error);
        // Fallback bei Fehler
        return {
          party_id: 'manual',
          party_code: partyCode || 'manual',
          party_name: null // ✅ Kein Fallback-Partyname mehr
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
        const savedPartyIdLocal = localStorage.getItem('validatedPartyId');
        const savedPartyIdSession = sessionStorage.getItem('validatedPartyId');
        if (window.IS_DEBUG) console.log('DEBUG PWA: checkWishboxStatus partyId local=', savedPartyIdLocal, 'session=', savedPartyIdSession);
        
        if ((!savedPartyIdLocal || savedPartyIdLocal === 'manual' || savedPartyIdLocal === '') &&
            (!savedPartyIdSession || savedPartyIdSession === 'manual' || savedPartyIdSession === '')) {
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
        
        // Block-Status: bei vollem Lauf; beim 30s-Poll überspringen (sonst Gate-Reset → Flackern)
        const skipBlock = options && options.skipFullBlockRecheck === true;
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
          if (!skipBlock) {
          try {
            if (window.IS_DEBUG) console.log('🔍 Lade Party-Daten von Firebase für Party-ID:', savedPartyId);
            const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), savedPartyId);
            const partyDoc = await window.firebaseGetDoc(partyRef);
            
            if (partyDoc.exists()) {
              if (window.IS_DEBUG) console.log('DEBUG PWA: Party-Dokument geladen, partyId=', savedPartyId);
              const partyDataForDj = sanitizePartyData(partyDoc.data());
              
              // ✅ Wenn Party beendet: sofort Reset und zurück zur Code-Eingabe
              const lifecycleStatus = partyDataForDj.lifecycle_status;
              const nowPosix = Math.floor(Date.now() / 1000);
              const endPosix = Number(partyDataForDj.end_time_posix || 0);
              if (lifecycleStatus === 'finished' || (Number.isFinite(endPosix) && endPosix > 0 && nowPosix >= endPosix)) {
                if (window.IS_DEBUG) console.log('⚠️ Party ist beendet (lifecycle_status === finished), clearPartyData und Zurück zur Code-Eingabe');
                if (typeof clearPartyData === 'function') clearPartyData();
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
              } else {
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
              if (typeof clearPartyData === 'function') clearPartyData();
              return;
            }
          } catch (e) {
            console.error('❌ Fehler beim Laden der Party-Daten:', e);
            if (window.IS_DEBUG) console.warn('⚠️ Konnte Party-Daten für DJ-Namen nicht laden:', e);
          }
          }
          
          // Prüfe, ob die Party noch aktiv ist
          try {
            const partyRef = window.firebaseDoc(
              window.firebaseCollection(window.firebaseDb, 'parties'),
              savedPartyId
            );
            const partyDoc = await window.firebaseGetDoc(partyRef);
            if (partyDoc.exists()) {
              const partyData = partyDoc.data();
              const lifecycleEarly = partyData.lifecycle_status;
              const nowPosixEarly = Math.floor(Date.now() / 1000);
              const endPosixEarly = Number(partyData.end_time_posix || 0);
              if (lifecycleEarly === 'finished' || (Number.isFinite(endPosixEarly) && endPosixEarly > 0 && nowPosixEarly >= endPosixEarly)) {
                if (window.IS_DEBUG) console.log('⚠️ Party beendet (lifecycle/end_time_posix), clearPartyData');
                if (typeof clearPartyData === 'function') clearPartyData();
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
                  if (skipBlock) {
                    const preEl = document.getElementById('prePartyWaitMode');
                    if (preEl && preEl.style.display === 'block' && currentPartyStartDate && currentPartyStartDate.getTime() === startDate.getTime()) {
                      if (window.IS_DEBUG) console.log('Poll: Pre-Party unverändert, kein UI-Reset');
                      return;
                    }
                  }
                  if (window.IS_DEBUG) console.log('⏰ Party startet in der Zukunft, zeige Pre-Party Wartemodus');
                  currentPartyStartDate = startDate;
                  showPrePartyWaitMode(partyData.party_name || 'Party', startDate);
                  // URL bereinigen
                  if (window.location.search.includes('code=')) {
                    window.history.replaceState({}, document.title, window.location.pathname);
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
                  if (!skipBlock || wasWishboxInactive) {
                    updateWishboxUI();
                  }
                  // URL bereinigen (falls Code noch drin steht) - NUR wenn nicht bereits von QR-Code-Login verarbeitet
                  if (window.location.search.includes('code=') && !sessionStorage.getItem('qrCodeProcessed')) {
                    window.history.replaceState({}, document.title, window.location.pathname);
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
              if (window.IS_DEBUG) console.warn('⚠️ Party-Dokument fehlt, clearPartyData');
              if (typeof clearPartyData === 'function') clearPartyData();
              return;
            }
          } catch (e) {
            if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Prüfen der gespeicherten party_id:', e);
            // Weiter mit normaler Suche
          }
        }
        
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
            // Bereinige URL sofort (entferne ungültigen Parameter)
            window.history.replaceState({}, document.title, window.location.pathname);
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
          if (window.IS_DEBUG) console.log('Kein Party-Code vorhanden - Wunschbox bleibt inaktiv');
          isWishboxActive = false;
          updateWishboxUI(); // UI wird aktualisiert, Block-Status wurde bereits geprüft
          return;
        }
        
        const now = new Date();
        const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        
        // Prüfe, ob eine Party aktiv ist
        let foundActiveParty = false;
        try {
          const partiesRef = window.firebaseCollection(window.firebaseDb, 'parties');
          // Align mit firestore.rules partyGuestDiscoveryListAllowed
          const partiesQuery = window.firebaseQuery(
            partiesRef,
            window.firebaseWhere('status', '==', 'active'),
            window.firebaseWhere('lifecycle_status', 'in', ['active', 'standby']),
            window.firebaseWhere('end_date', '>=', window.firebaseTimestamp.fromDate(sevenDaysAgo))
          );
          const partiesSnapshot = await window.firebaseGetDocs(partiesQuery);
          
          for (const partyDoc of partiesSnapshot.docs) {
            const data = partyDoc.data();
            const startTimestamp = data.start_date;
            const endTimestamp = data.end_date;
            const partyCode = data.party_code;
            const partyStatus = data.status || 'active'; // Fallback auf 'active' wenn nicht gesetzt
            
            // Nur Partys mit Status "active" verarbeiten
            if (partyStatus !== 'active') {
              if (window.IS_DEBUG) console.log('⚠️ Party hat nicht den Status "active":', partyStatus);
              continue;
            }
            
            if (startTimestamp && endTimestamp) {
              const startDate = startTimestamp.toDate();
              const endDate = endTimestamp.toDate();
              
                // Prüfe, ob Party-Code (8 Ziffern) mit URL/Eingabe übereinstimmt
                if (partyDataMatchesJoinCode(data, codeToCheck)) {
                const canonicalCode = data.party_code != null ? String(data.party_code) : codeToCheck;
                // Prüfe Pre-Party Status (Party startet in der Zukunft)
                if (now < startDate) {
                  if (window.IS_DEBUG) console.log('⏰ Party startet in der Zukunft, zeige Pre-Party Wartemodus');
                  currentPartyStartDate = startDate;
                  showPrePartyWaitMode(data.party_name || 'Party', startDate);
                  // Speichere party_id in localStorage UND sessionStorage
                  localStorage.setItem('validatedPartyId', partyDoc.id);
                  sessionStorage.setItem('validatedPartyId', partyDoc.id);
                  sessionStorage.setItem('validatedPartyCode', canonicalCode);
                  localStorage.setItem('validatedPartyCode', canonicalCode);
                  try { localStorage.removeItem('pending_party_code'); } catch (e) {}
                  // ✅ Speichere Partyname in sessionStorage und localStorage
                  const partyName = data.name || 'Your Party'; // ✅ Partyname mit Fallback
                  sessionStorage.setItem('validatedPartyName', partyName);
                  localStorage.setItem('validatedPartyName', partyName);
                  if (window.IS_DEBUG) console.log('💾 party_name gespeichert in sessionStorage:', partyName);
                  if (window.IS_DEBUG) console.log('💾 party_name gespeichert in localStorage:', partyName);
                  
                  if (partyCodeInput) {
                    partyCodeInput.value = canonicalCode;
                  }
                  // URL bereinigen - NUR wenn nicht bereits von QR-Code-Login verarbeitet
                  if (partyCodeFromUrl && !sessionStorage.getItem('qrCodeProcessed')) {
                    window.history.replaceState({}, document.title, window.location.pathname);
                    if (window.IS_DEBUG) console.log('🧹 URL bereinigt (Code entfernt)');
                  }
                  return;
                }
                
                // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende
                if (now >= startDate && now < endDate) {
                  if (window.IS_DEBUG) console.log('DEBUG PWA: Body-Stream OK, Party aktiv, partyId=', partyDoc.id);
                  isWishboxActive = true;
                  foundActiveParty = true;
                  currentPartyStartDate = null;
                  stopPrePartyCountdown();
                  // Setze Party-Code im versteckten Feld
                  if (partyCodeInput) {
                    partyCodeInput.value = canonicalCode;
                  }
                  // Speichere validierten Code in sessionStorage (für Rückwärtskompatibilität)
                  sessionStorage.setItem('validatedPartyCode', canonicalCode);
                  localStorage.setItem('validatedPartyCode', canonicalCode);
                  try { localStorage.removeItem('pending_party_code'); } catch (e) {}
                  // WICHTIG: Speichere die lange party_id in localStorage UND sessionStorage
                  localStorage.setItem('validatedPartyId', partyDoc.id);
                  sessionStorage.setItem('validatedPartyId', partyDoc.id);
                  if (window.IS_DEBUG) console.log('💾 party_id gespeichert in localStorage:', partyDoc.id);
                  if (window.IS_DEBUG) console.log('💾 party_id gespeichert in sessionStorage:', partyDoc.id);
                  // ✅ Speichere Partyname in sessionStorage und localStorage
                  const partyName = data.party_name || 'Your Party'; // ✅ Partyname mit Fallback
                  sessionStorage.setItem('validatedPartyName', partyName);
                  localStorage.setItem('validatedPartyName', partyName);
                  sessionStorage.setItem('currentPartyName', partyName);
                  localStorage.setItem('currentPartyName', partyName);
                  if (window.IS_DEBUG) console.log('💾 party_name gespeichert in sessionStorage:', partyName);
                  
                  // ✅ Prüfe Pause-Status beim Initialisieren
                  const isPaused = data.is_paused === true;
                  togglePartyPausedOverlay(isPaused);
                  if (window.IS_DEBUG) console.log('💾 party_name gespeichert in localStorage:', partyName);
                  // ✅ Lade DJ-Namen für Header-Anzeige
                  await updateHeaderDjName(partyDoc.id, data);
                  // ✅ Aktualisiere Header-Branding nach DJ-Name Laden
                  updateHeaderBranding();
                  // ✅ Aktualisiere Party-Info-Zeile
                  updatePartyInfoLine();
                  if (typeof window.updatePageTitle === 'function') window.updatePageTitle();
                  // URL bereinigen (Code entfernen) - NUR wenn nicht bereits von QR-Code-Login verarbeitet
                  if (partyCodeFromUrl && !sessionStorage.getItem('qrCodeProcessed')) {
                    window.history.replaceState({}, document.title, window.location.pathname);
                    if (window.IS_DEBUG) console.log('🧹 URL bereinigt (Code entfernt)');
                  }
                  updateWishboxUI();
                  return;
                }
              }
            }
          }
        } catch (partiesError) {
          if (window.IS_DEBUG) console.log('DEBUG PWA: Fehler beim Laden der Partys', partiesError);
          foundActiveParty = false;
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
                      if (partyCodeFromUrl) {
                        window.history.replaceState({}, document.title, window.location.pathname);
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
    // Zeit-/Countdown-Logik: window.formatPartyLocalTime (nur HH:MM), window.calculateTimeUntilParty(ts, t), window.formatDuration(…, t) aus party_shared.js.
    // Uhr-Anzeige: t('time_format_clock').replace('{time}', window.formatPartyLocalTime(…))
    
    // ✅ Funktion zum Anzeigen des Party-Status-Modals (Drei-Farben-System)
    function showPartyStatusModal(type, message, timeInfo = null) {
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
          fullMessage += '<br><br><strong>' + startInText + ' ' + timeInfo + '</strong>';
        }
      }
      
      modal.innerHTML = `
        <div class="party-code-error-modal-icon">
          <i class="${iconClass}"></i>
        </div>
        <p class="party-code-error-modal-message">${fullMessage}</p>
        <button class="party-code-error-modal-button" id="partyCodeErrorModalOkBtn">
          ${t('button_ok', 'OK')}
        </button>
      `;
      
      overlay.appendChild(modal);
      document.body.appendChild(overlay);
      
      // Event-Handler für OK-Button
      const okBtn = document.getElementById('partyCodeErrorModalOkBtn');
      okBtn.addEventListener('click', () => overlay.remove());
      overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
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
      if (!isWishboxActive) {
        limitInfoDiv.style.display = 'none';
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
          const wishesRef = window.firebaseCollection(window.firebaseDb, 'wishes');
          const q = window.firebaseQuery(
            wishesRef,
            window.firebaseWhere('client_id', '==', cid),
            window.firebaseWhere('party_id', '==', partyId)
          );
          var guestLimit = 2;
          var wishCount = 0;
          function flush() {
            if (!isWishboxActive) return;
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
                if (window.IS_DEBUG) console.log('🔴 Party beendet erkannt - führe sofortigen Logout durch');
                // Overlay entfernen
                togglePartyPausedOverlay(false);
                // Streams sofort stoppen (bevor Logout)
                if (typeof unsubParty === 'function') unsubParty();
                if (typeof unsubWishes === 'function') unsubWishes();
                if (wishLimitUnsubscribe) {
                  wishLimitUnsubscribe();
                  wishLimitUnsubscribe = null;
                }
                // Cache-Bereinigung VOR performLogout (doppelte Sicherheit)
                localStorage.removeItem('validatedPartyId');
                localStorage.removeItem('validatedPartyCode');
                localStorage.removeItem('validatedPartyName');
                clearSessionPartyData();
                // Sofortiger Logout ohne Bestätigung (führt auch Redirect durch)
                performLogout();
                // performLogout() führt bereits Redirect durch, aber als Fallback:
                // UI zurücksetzen (falls Redirect verzögert wird)
                updateWishboxUI();
                return; // Wichtig: Keine weitere Ausführung
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
        if (isWishboxActive && !window.isSuccessActive) {
          if (wishForm) wishForm.style.display = 'block';
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

          // Filtere Wünsche seit der aktuellen vollen Stunde
          currentCount = wishes.filter(wish => {
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

    // Pre-Party Wartemodus Funktionen
    function showPrePartyWaitMode(partyName, startDate) {
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
      if (wishForm) wishForm.style.display = 'none';
      
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

    function updateWishboxUI() {
      if (window.IS_DEBUG) console.log('DEBUG: UI Update gestartet, Status:', isWishboxActive);
      if (window.isSuccessActive) {
        if (window.IS_DEBUG) console.log('DEBUG PWA: updateWishboxUI Erfolgsmeldung aktiv, überspringe');
        return;
      }

      var loadingOverlay = document.getElementById('loading-overlay');
      var bodyLoadErrorEl = document.getElementById('bodyLoadError');
      if (window.bodyLoadError && bodyLoadErrorEl) {
        if (loadingOverlay) loadingOverlay.style.display = 'none';
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

      // Bis checkBlockStatus die ersten Reads abgeschlossen hat: kein Formular (verhindert Flackern bei Sperre)
      if (!wishboxBlockGateResolved) {
        var wfGate = document.getElementById('wishForm');
        var blGate = document.getElementById('brandingLine');
        var limGate = document.getElementById('wishLimitInfo');
        var inactGate = document.getElementById('wishboxInactiveMessage');
        var blkGate = document.getElementById('wishboxBlockedMessage');
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
          if (loadingOverlay) loadingOverlay.style.display = 'none';
          if (inactGate) inactGate.style.display = 'none';
          if (blkGate) {
            blkGate.style.display = 'block';
            blkGate.style.visibility = 'visible';
          }
          var sbGate = document.getElementById('submitBtn');
          if (sbGate) sbGate.disabled = true;
          return;
        }
        if (loadingOverlay) loadingOverlay.style.display = 'flex';
        if (inactGate) inactGate.style.display = 'none';
        if (blkGate) blkGate.style.display = 'none';
        return;
      }

      if (isWishboxActive && loadingOverlay) loadingOverlay.style.display = 'none';
      
      if (isWishboxActive) {
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
      
      // ✅ Prüfe Pause-Status: Wenn Pause aktiv ist, überspringe normale UI-Updates
      const isPaused = pausedOverlay && pausedOverlay.style.display === 'flex';
      if (isPaused) {
        if (window.IS_DEBUG) console.log('⏸️ updateWishboxUI: Pause aktiv, überspringe UI-Updates');
        return; // Pause-Overlay wird von togglePartyPausedOverlay gesteuert
      }
      
      if (isBlocked) {
        if (loadingOverlay) loadingOverlay.style.display = 'none';
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
      } else if (isWishboxActive) {
        // Wunschbox ist aktiv und Gast ist nicht gesperrt
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
        if (partyId && partyId !== 'manual') subscribeWishLimitStream(partyId);
        else if (typeof stopWishLimitStream === 'function') stopWishLimitStream();
        if (blockedMessage) blockedMessage.style.display = 'none';
        if (submitBtn) submitBtn.disabled = false;
        // Limit-Anzeige läuft ausschließlich über subscribeWishLimitStream (onSnapshot), kein zusätzliches updateWishLimitInfo
        const limitInfoDiv = document.getElementById('wishLimitInfo');
        if (limitInfoDiv) {
          limitInfoDiv.style.display = 'block';
        }
      } else {
        // Wunschbox ist inaktiv
        if (loadingOverlay) loadingOverlay.style.display = 'none';
        if (wishForm) {
          wishForm.style.display = 'none';
          wishForm.style.visibility = 'hidden';
        }
        if (inactiveMessage) inactiveMessage.style.display = 'block';
        if (blockedMessage) blockedMessage.style.display = 'none';
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

        // Falls kein Name gefunden, lade aus Public-Profil
        if (!djName && profileUid) {
          try {
              const userData = await fetchPublicDjProfile(profileUid);
              if (userData && userData.displayName) {
                djName = userData.displayName;
                // ✅ Formatierung: Erster Buchstabe groß
                djName = djName.charAt(0).toUpperCase() + djName.slice(1);
              }
          } catch (e) {
            if (window.IS_DEBUG) console.warn('⚠️ Konnte DJ-Namen nicht aus users Collection laden:', e);
          }
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
      let languageTitle = t('language', 'Sprache');
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
      
      // Sprach-Name Keys im translations-Objekt (Fallback verhindert Key-Anzeige, wenn Übersetzung noch lädt)
      const languageNameKeys = {
        'de': 'lang_german',
        'en': 'lang_english',
        'fr': 'lang_french',
        'ru': 'lang_russian',
        'zh': 'lang_chinese',
        'es': 'lang_spanish',
        'tr': 'lang_turkish',
        'pt': 'lang_portuguese',
        'it': 'lang_italian',
        'uk': 'lang_ukrainian'
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
        } else if (typeof window.translations !== 'undefined' && window.translations['de'] && window.translations['de'][nameKey]) {
          translated = window.translations['de'][nameKey];
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

    // ✅ Funktion zum Aktualisieren des Seitentitels im Header
    function updatePageTitle(pageId) {
      const pageTitleElement = document.getElementById('current-page-title');
      if (!pageTitleElement) {
        if (window.IS_DEBUG) console.warn('⚠️ current-page-title Element nicht gefunden');
        return;
      }

      // ✅ Mapping von pageId zu Übersetzungsschlüsseln
      const pageTitleMap = {
        'wunschbox': 'nav_vibesbox',
        'history': 'nav_history',
        'social-media': 'nav_social_media',
        'kontakt': 'nav_contact',
        'ueber': 'nav_about',
        'impressum': 'nav_about', // Impressum zeigt auch "Über VibesBox"
        'dsgvo': 'nav_about',
        'agb': 'nav_about'
      };

      const translationKey = pageTitleMap[pageId];
      if (!translationKey) {
        // ✅ Fallback: Wenn keine Übersetzung gefunden, verstecke Titel
        pageTitleElement.textContent = '';
        return;
      }

      // ✅ Lade Übersetzung aus translations.js
      let titleText = t(translationKey, '') || '';
      if (!titleText && typeof translations !== 'undefined') {
        const currentLang = localStorage.getItem('pwa_language') || 'en';
        titleText = translations[currentLang]?.[translationKey] || '';
      }

      // ✅ Setze Titel-Text
      if (titleText) {
        pageTitleElement.textContent = titleText;
      } else {
        pageTitleElement.textContent = '';
      }
    }

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
    }

    function clearPartyData(skipRedirect) {
      delete togglePartyPausedOverlay._lastPaused;
      if (window.IS_DEBUG) console.log('🧹 clearPartyData: Party beendet – lösche Speicher und setze UI zurück');
      localStorage.removeItem('validatedPartyId');
      localStorage.removeItem('validatedPartyCode');
      localStorage.removeItem('validatedPartyName');
      localStorage.removeItem('currentPartyName');
      try { localStorage.removeItem('pending_party_code'); } catch (e) {}
      try { localStorage.removeItem('guest_client_id'); } catch (e) {}
      clearSessionPartyData();
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
        window.location.replace('/');
      } else if (window.IS_DEBUG) {
        console.log('✅ clearPartyData: Storage geleert (ohne Redirect, z.B. QR-Code-Wechsel).');
      }
    }

    // ✅ Wird aufgerufen, wenn die Party beendet ist (manuell oder Zeit) – löscht alle Gast-Session-Daten (sauberer Logout)
    function clearGuestSessionBecausePartyEnded() {
      clearPartyData();
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
        // Konstante, muss nicht zurückgesetzt werden
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
      window.history.replaceState({}, document.title, window.location.pathname);
      
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
      
      if (isLoggedIn && djName) {
        // ✅ Eingeloggt: Zeige "von DJ-Name" darunter (DJ-Name fett via CSS) – nutzt aktiv window.getTranslation/window.translations
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
        // ✅ Party-Info-Zeile im Header (unter "von DJ-Name"): grün, Party-Name fett
        if (headerPartyInfo && headerPartyInfoText && headerPartyInfoName && partyName && partyName.trim() !== '' && partyName !== 'Deine Party' && partyName !== 'Your Party') {
          let infoText = 'Du bist bei der Party:';
          try {
            if (typeof window.getTranslation === 'function') {
              infoText = window.getTranslation('party_info_text') || infoText;
            } else if (typeof window.translations !== 'undefined') {
              const currentLang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
              infoText = (window.translations[currentLang] && window.translations[currentLang]['party_info_text']) || infoText;
            }
          } catch (e) {}
          headerPartyInfoText.textContent = (infoText || 'You are at the party:').trim();
          headerPartyInfoName.textContent = partyName.trim();
          headerPartyInfo.style.display = 'flex';
        } else {
          if (headerPartyInfo) headerPartyInfo.style.display = 'none';
        }
        if (window.IS_DEBUG) console.log('✅ Header: VibesBox (oben), "von ' + displayDjName + '" (unten), Party-Info bei Bedarf angezeigt');
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
    
    // ✅ Funktion zum Aktualisieren der Branding-Zeile (ganz oben)
    function updateBrandingLine() {
      try {
        const brandingLine = document.getElementById('brandingLine');
        const brandingDjLogo = document.getElementById('brandingDjLogo');
        const brandingDjName = document.getElementById('brandingDjName');
        
        if (!brandingLine) {
          if (window.IS_DEBUG) console.warn('⚠️ Branding-Zeile Element nicht gefunden');
          return;
        }
        
        // ✅ Prüfe Login-Status: Party-ID vorhanden?
        const validatedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
        const isLoggedIn = validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '';
        
        // ✅ Branding-Zeile nur anzeigen, wenn eingeloggt UND Wunschbox aktiv ist
        if (!isLoggedIn || !isWishboxActive) {
          // ✅ Nicht eingeloggt oder Wunschbox inaktiv: Verstecke Branding-Zeile
          brandingLine.style.display = 'none';
          return;
        }
        
        // ✅ Eingeloggt UND Wunschbox aktiv: Zeige Branding-Zeile
        brandingLine.style.display = 'block';
        
        // ✅ Lade Party-Daten für dj_logo
        const savedPartyId = validatedPartyId;
        if (savedPartyId && savedPartyId !== 'manual' && savedPartyId !== '') {
          try {
            const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), savedPartyId);
            window.firebaseGetDoc(partyRef).then((partyDoc) => {
              if (partyDoc.exists()) {
                const partyData = partyDoc.data();
                const djLogoRaw = partyData.dj_logo;
                const djLogo =
                  typeof djLogoRaw === 'string' && djLogoRaw.trim()
                    ? djLogoRaw.trim()
                    : null;
                const djName = (sessionStorage.getItem('currentDjName') || '').trim();

                if (brandingDjName) {
                  if (djName) {
                    brandingDjName.textContent = djName;
                    brandingDjName.style.display = 'block';
                  } else {
                    brandingDjName.textContent = '';
                    brandingDjName.style.display = 'none';
                  }
                }
                if (brandingDjLogo) {
                  if (djLogo) {
                    brandingDjLogo.src = djLogo;
                    brandingDjLogo.alt = djName ? ('Logo ' + djName) : 'DJ Logo';
                    brandingDjLogo.style.display = 'block';
                  } else {
                    brandingDjLogo.removeAttribute('src');
                    brandingDjLogo.removeAttribute('alt');
                    brandingDjLogo.style.display = 'none';
                  }
                }

                if (typeof loadDrawerLogo === 'function') {
                  loadDrawerLogo();
                }
              }
            }).catch((e) => {
              if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Laden der Party-Daten für Branding-Zeile:', e);
              const djName = (sessionStorage.getItem('currentDjName') || '').trim();
              if (brandingDjName) {
                if (djName) {
                  brandingDjName.textContent = djName;
                  brandingDjName.style.display = 'block';
                } else {
                  brandingDjName.textContent = '';
                  brandingDjName.style.display = 'none';
                }
              }
              if (brandingDjLogo) {
                brandingDjLogo.removeAttribute('src');
                brandingDjLogo.style.display = 'none';
              }
            });
          } catch (e) {
            if (window.IS_DEBUG) console.warn('⚠️ Fehler beim Zugriff auf Party-Daten:', e);
          }
        }
      } catch (e) {
        console.error('❌ Fehler in updateBrandingLine:', e);
      }
    }
    
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
    // ✅ Initialisiere Branding-Zeile beim Seitenstart
    updateBrandingLine();
    
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
            const wishesRef = window.firebaseCollection(window.firebaseDb, 'wishes');
            const wishesQuery = window.firebaseQuery(
              wishesRef,
              window.firebaseWhere('party_id', '==', partyId),
              window.firebaseWhere('spotify_id', '==', spotifyTrack.id),
              window.firebaseOrderBy('createdAt', 'desc'),
              window.firebaseLimit(1)
            );
            const wishesSnapshot = await window.firebaseGetDocs(wishesQuery);
            
            if (wishesSnapshot.docs.length > 0) {
              const wishDocRef = window.firebaseDoc(window.firebaseDb, 'wishes', wishesSnapshot.docs[0].id);
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

    // ✅ Loader steuerbar: showLoader(true/false [, Text]) – für Party-Validierung (QR, URL, manuell)
    var _loaderLongWaitTimer = null;
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

            // ✅ Cleanup: URL-Code weicht von gespeicherter Party ab → sofort clearPartyData (ohne Redirect)
            var storedCode = localStorage.getItem('validatedPartyCode') || sessionStorage.getItem('validatedPartyCode');
            var storedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
            var storageMatchesUrl = storedCode && storedCode === codeFromUrl;
            if ((storedCode || storedPartyId) && !storageMatchesUrl) {
              if (window.IS_DEBUG) console.log('DEBUG [Auto-Login]: URL-Code weicht von Storage ab – räume alte Party-Daten auf.');
              if (typeof clearPartyData === 'function') clearPartyData(true);
            }
          } else {
            if (window.IS_DEBUG) console.warn('⚠️ URL-Parameter code ungültig (kein 8-stelliger Code), ignoriere:', rawCode);
            window.history.replaceState({}, document.title, window.location.pathname);
          }
        }

        // ✅ Priorität 2: NUR wenn KEIN code in der URL – Party-ID aus Storage verwenden (validatedPartyId oder pendingPartyId)
        if (!codeFromUrl) {
          var fromPending = localStorage.getItem('pendingPartyId');
          var fromSessionValidated = sessionStorage.getItem('validatedPartyId');
          var fromLocalValidated = localStorage.getItem('validatedPartyId');
          if (fromPending && typeof fromPending === 'string' && validatePartyId(fromPending)) {
            partyIdToUse = fromPending;
            idSourceKey = 'pendingPartyId (localStorage)';
          } else if (fromSessionValidated && typeof fromSessionValidated === 'string' && validatePartyId(fromSessionValidated)) {
            partyIdToUse = fromSessionValidated;
            idSourceKey = 'validatedPartyId (sessionStorage)';
          } else if (fromLocalValidated && typeof fromLocalValidated === 'string' && validatePartyId(fromLocalValidated)) {
            partyIdToUse = fromLocalValidated;
            idSourceKey = 'validatedPartyId (localStorage)';
          }
        }

        vbLog('processQRCodeLogin Start. ID gelesen aus Key:', idSourceKey || (codeFromUrl ? 'code (URL)' : '(keine)'), 'Wert:', partyIdToUse || (codeFromUrl || '(leer)'));
        var loadingText = (typeof getTranslation === 'function' ? getTranslation('loading_party_connection') : null) || 'Connecting to the party...';
        showLoader(true, loadingText);
        loaderShown = true;
        if (partyIdToUse) {
          if (idSourceKey === 'pendingPartyId (localStorage)') localStorage.removeItem('pendingPartyId');
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
            try {
              await updateHeaderDjName(partyId, partyData);
              updateHeaderBranding();
              updatePartyInfoLine();
            } catch (e) { if (window.IS_DEBUG) console.warn('⚠️ Konnte Party-Daten für DJ-Namen nicht laden:', e); }
            isWishboxActive = true;
            showLoader(false);
            loaderShown = false;
            updateWishboxUI();
            await checkWishboxStatus();
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
            window.history.replaceState({}, document.title, window.location.pathname);
            return false;
          }
        }
        
        console.log('DEBUG [Auto-Login]: reCAPTCHA wird beim Auto-Login per QR/URL-Code nicht verwendet (nur für Kontaktformular).');
        if (codeFromUrl && codeFromUrl.length === 8) {
          if (window.IS_DEBUG) console.log('🔍 QR-Code-Login: Code gefunden:', codeFromUrl);
          console.log('DEBUG [Auto-Login]: Starte Validierung für:', codeFromUrl);
          
          await new Promise(resolve => setTimeout(resolve, 500));
          
          // ✅ Debug-Logging vor Firestore-Abfrage
          console.log('DEBUG [QR-Login]: Versuche Code:', codeFromUrl, 'Typ:', typeof codeFromUrl);
          // ✅ Zentrale Party-Code-Prüfung (party_shared.js)
          let partyInfo = await getActivePartyInfo(codeFromUrl);
          console.log('DEBUG [QR-Login]: getActivePartyInfo verarbeitet');
          if (!partyInfo || typeof partyInfo !== 'object' || !partyInfo.party_id || partyInfo.party_id === 'manual') {
            console.warn('DEBUG [Auto-Login]: Redirect/Abbruch – Grund: getActivePartyInfo lieferte keine gültige Party (invalid/unknown).');
            showLoader(false);
            loaderShown = false;
            showPartyStatusModal('invalid', (typeof getTranslation === 'function' ? getTranslation('party_unknown') : null) || 'This party is not known. Please check your input.');
            window.history.replaceState({}, document.title, window.location.pathname);
            return false;
          }
          const canonicalPartyCode = (partyInfo.party_code && String(partyInfo.party_code).trim() !== '') ? String(partyInfo.party_code).trim() : codeFromUrl;
          // ✅ Prüfe Future (noch nicht gestartet) oder Beendet – einmalig Party-Dokument laden
          try {
            const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyInfo.party_id);
            const partyDoc = await window.firebaseGetDoc(partyRef);
            if (partyDoc.exists()) {
              const partyData = partyDoc.data();
              const startTimestamp = partyData.start_date;
              const endTimestamp = partyData.end_date;
              const lifecycleStatus = partyData.lifecycle_status || partyData.status;
              const finishedAt = partyData.finished_at;
              const now = new Date();
              if (lifecycleStatus === 'finished' || finishedAt != null) {
                console.warn('DEBUG [Auto-Login]: Redirect/Abbruch – Grund: Party bereits beendet (lifecycle_status/finished_at).');
                showLoader(false);
                loaderShown = false;
                showPartyStatusModal('ended', (typeof getTranslation === 'function' ? getTranslation('party_ended') : null) || 'This party has already ended. Thank you for your visit!');
                window.history.replaceState({}, document.title, window.location.pathname);
                return false;
              }
              if (startTimestamp && endTimestamp) {
                const startDate = startTimestamp.toDate();
                const endDate = endTimestamp.toDate();
                if (now < startDate) {
                  localStorage.setItem('validatedPartyId', partyInfo.party_id);
                  sessionStorage.setItem('validatedPartyId', partyInfo.party_id);
                  localStorage.setItem('validatedPartyCode', canonicalPartyCode);
                  try { localStorage.removeItem('pending_party_code'); } catch (e) {}
                  sessionStorage.setItem('validatedPartyCode', canonicalPartyCode);
                  const hiddenPartyCodeInput = document.getElementById('partyCodeInput');
                  if (hiddenPartyCodeInput) hiddenPartyCodeInput.value = canonicalPartyCode;
                  isWishboxActive = true;
                  updateWishboxUI();
                  await checkWishboxStatus();
                  showPartyStatusModal('future', (typeof getTranslation === 'function' ? getTranslation('party_starts_soon') : null) || 'Party starts soon.');
                  if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') window.vbReplaceStateStripPartyCodeKeepLang();
                  else window.history.replaceState({}, document.title, window.location.pathname);
                  if (typeof window.vbApplyResolvedLanguageToUi === 'function') window.vbApplyResolvedLanguageToUi();
                  return true;
                }
              }
            }
          } catch (e) {
            if (window.IS_DEBUG) console.warn('⚠️ processQRCodeLogin: Fehler beim Prüfen Party-Zeitraum:', e);
          }
          // ✅ Validiere Party-ID (verhindert XSS/Injection)
              if (!validatePartyId(partyInfo.party_id)) {
                console.error('❌ QR-Code-Login: Ungültige Party-ID erkannt:', partyInfo.party_id);
                console.warn('DEBUG [Auto-Login]: Redirect/Abbruch – Grund: validatePartyId fehlgeschlagen (ungültige Party-ID).');
                showLoader(false);
                loaderShown = false;
                showPartyStatusModal('invalid', (typeof getTranslation === 'function' ? getTranslation('party_unknown') : null) || 'This party is not known. Please check your input.');
                window.history.replaceState({}, document.title, window.location.pathname);
                return false;
              }
              
              if (window.IS_DEBUG) console.log('✅ QR-Code-Login: Party-ID gefunden:', partyInfo.party_id);
              
              // Speichere Party-ID und Code in localStorage UND sessionStorage
              localStorage.setItem('validatedPartyId', partyInfo.party_id);
              sessionStorage.setItem('validatedPartyId', partyInfo.party_id);
              localStorage.setItem('validatedPartyCode', canonicalPartyCode);
              try { localStorage.removeItem('pending_party_code'); } catch (e) {}
              sessionStorage.setItem('validatedPartyCode', canonicalPartyCode);
              // ✅ Speichere Partyname in sessionStorage und localStorage
              const partyName = partyInfo.party_name || null;
              if (partyName && partyName.trim() !== '' && partyName !== 'Deine Party' && partyName !== 'Your Party') {
                sessionStorage.setItem('validatedPartyName', partyName.trim());
                localStorage.setItem('validatedPartyName', partyName.trim());
                sessionStorage.setItem('currentPartyName', partyName.trim());
                localStorage.setItem('currentPartyName', partyName.trim());
                if (window.IS_DEBUG) console.log('💾 party_name gespeichert in sessionStorage:', partyName.trim());
                if (window.IS_DEBUG) console.log('💾 party_name gespeichert in localStorage:', partyName.trim());
              } else {
                if (window.IS_DEBUG) console.warn('⚠️ Kein gültiger partyName von getActivePartyInfo erhalten');
                sessionStorage.removeItem('validatedPartyName');
                localStorage.removeItem('validatedPartyName');
              }
              
              // Setze Code im versteckten Feld
              const partyCodeInput = document.getElementById('partyCodeInput');
              if (partyCodeInput) {
                partyCodeInput.value = canonicalPartyCode;
              }
              
              // ✅ Lade Party-Daten für DJ-Namen
              try {
                const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), partyInfo.party_id);
                const partyDoc = await window.firebaseGetDoc(partyRef);
                if (partyDoc.exists()) {
                  const partyData = partyDoc.data();
                  await updateHeaderDjName(partyInfo.party_id, partyData);
                  // ✅ Aktualisiere Header-Branding nach DJ-Name Laden
                  updateHeaderBranding();
                  // ✅ Aktualisiere Party-Info-Zeile
                  updatePartyInfoLine();
                }
              } catch (e) {
                if (window.IS_DEBUG) console.warn('⚠️ Konnte Party-Daten für DJ-Namen nicht laden:', e);
              }
              
              // Aktiviere Wunschbox
              isWishboxActive = true;
              
              // Aktualisiere UI
              updateWishboxUI();
              
              // Markiere QR-Code als verarbeitet (verhindert doppelte URL-Bereinigung)
              sessionStorage.setItem('qrCodeProcessed', 'true');
              
              // URL bereinigen: Party-Code weg, ?lang= bleibt (Sprache bleibt stabil)
              if (typeof window.vbReplaceStateStripPartyCodeKeepLang === 'function') window.vbReplaceStateStripPartyCodeKeepLang();
              else window.history.replaceState({}, document.title, window.location.pathname);
              if (window.IS_DEBUG) console.log('🧹 QR-Code-Login: URL bereinigt (Code entfernt)');
              
              // Rufe checkWishboxStatus auf für vollständige Initialisierung
              await checkWishboxStatus();
              if (typeof window.vbApplyResolvedLanguageToUi === 'function') window.vbApplyResolvedLanguageToUi();
              
              // Entferne Flag nach erfolgreicher Verarbeitung
              sessionStorage.removeItem('qrCodeProcessed');
              
          showLoader(false);
          loaderShown = false;
          return true; // Login erfolgreich
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
    
    // ✅ FINALE INITIALISIERUNG: currentClientId beim Seitenladen sofort berechnen
    // Prüfe Wunschbox-Status beim Laden der Seite
    // Warte kurz, damit Firebase initialisiert ist
    // WICHTIG: UI ist bereits auf "geschlossen" gesetzt, wird nur geöffnet wenn Code gültig ist
    setTimeout(async () => {
      // ✅ KRITISCH: Initialisiere currentClientId SOFORT beim Seitenladen
      try {
        if (window.IS_DEBUG) console.log('🔧 Initial: Berechne currentClientId beim Seitenladen...');
        currentClientId = await getOrCreateClientId(null);
        if (window.IS_DEBUG) console.log('✅ Initial: currentClientId erfolgreich initialisiert:', currentClientId);
      } catch (e) {
        console.error('❌ KRITISCHER FEHLER: currentClientId konnte nicht initialisiert werden:', e);
        // Versuche es erneut
        try {
          currentClientId = await getOrCreateClientId(null);
          if (window.IS_DEBUG) console.log('✅ Initial: currentClientId nach Fehler erfolgreich initialisiert:', currentClientId);
        } catch (e2) {
          console.error('❌ KRITISCHER FEHLER: currentClientId konnte auch nach Wiederholung nicht initialisiert werden:', e2);
        }
      }
      
      const qrLoginSuccess = await processQRCodeLogin();
      if (window.bodyLoadError) {
        vbLog('Ladefehler von processQRCodeLogin, zeige Fehler-UI');
        if (typeof updateWishboxUI === 'function') updateWishboxUI();
        return;
      }
      if (!qrLoginSuccess) {
        // ✅ Erst nach Firebase-Resultat: Kein gültiger Login (kein Code, keine Session) → Redirect zur Startseite
        if (window.IS_DEBUG) console.log('DEBUG PWA: processQRCodeLogin fehlgeschlagen, Redirect zu /');
        window.location.replace('/');
        return;
      }
      // ✅ Login erfolgreich: Loader wird von updateWishboxUI ausgeblendet (isWishboxActive = true)
      if (window.IS_DEBUG) console.log('DEBUG PWA: Initial checkWishboxStatus()');
      checkWishboxStatus();
      // ✅ Aktualisiere Header basierend auf Login-Status beim Seitenladen
      updateHeaderBasedOnLoginStatus();
      // ✅ Aktualisiere Party-Info-Zeile beim Seitenladen
      updatePartyInfoLine();
      
    }, 500);
    
    // Prüfe alle 30 Sekunden erneut (Party-Laufzeit/Wunschbox — ohne erneutes Block-Gate)
    setInterval(function () {
      checkWishboxStatus({ skipFullBlockRecheck: true });
    }, 30000);
    
    // ✅ Limit-Info läuft über Firebase onSnapshot (subscribeWishLimitStream) – kein Polling, kein Flackern
    
    // Prüfe auch bei URL-Änderungen (z.B. wenn Code in URL hinzugefügt wird)
    window.addEventListener('popstate', () => {
      checkWishboxStatus();
    });
    
    // Prüfe auch wenn Hash oder Query-Parameter sich ändern
    let lastUrl = window.location.href;
    setInterval(() => {
      if (window.location.href !== lastUrl) {
        lastUrl = window.location.href;
        checkWishboxStatus();
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
          let msg = errorData.error || 'Fehler bei der Validierung';
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
    const tracksPerPage = 10; // Anzahl Songs pro Seite
    
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
        const historyList = document.getElementById('historyList');
        if (historyList) {
          historyList.innerHTML = '';
        }
        const historyPagination = document.getElementById('historyPagination');
        if (historyPagination) {
          historyPagination.innerHTML = '';
        }
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
        // Party-Code aus verstecktem Feld lesen
        const partyCodeInput = document.getElementById('partyCodeInput');
        const partyCode = partyCodeInput ? (partyCodeInput.value || 'manual') : 'manual';
        
        if (window.IS_DEBUG) console.log('🔍 PWA-DEBUG: partyCode aus Input: ' + partyCode);
        
        if (!partyCode || partyCode === 'manual') {
          if (window.IS_DEBUG) console.warn('⚠️ PWA-WARNING: Kein Party-Code gefunden - zeige leere History');
          // Keine aktive Party - zeige leere History
          historyLoading.style.display = 'none';
          historyEmpty.style.display = 'block';
          return;
        }
        
        // Hole Party-Info um party_id zu bekommen
        if (window.IS_DEBUG) console.log('🔍 PWA-DEBUG: Rufe getActivePartyInfo() auf...');
        const partyInfo = await getActivePartyInfo(partyCode);
        const currentPartyId = partyInfo.party_id;
        
        if (window.IS_DEBUG) console.log('🔍 PWA-DEBUG: getActivePartyInfo() zurückgegeben: party_id=' + currentPartyId);
        if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
        
        if (!currentPartyId || currentPartyId === 'manual') {
          if (window.IS_DEBUG) console.warn('⚠️ PWA-WARNING: Keine gültige party_id - zeige leere History');
          // Keine aktive Party - zeige leere History
          historyLoading.style.display = 'none';
          historyEmpty.style.display = 'block';
          return;
        }
        
        // ✅ Aktualisiere History-Cache beim Laden der History-Seite
        await updateHistoryCache(currentPartyId);
        
        // DEBUG-LOGGING: Zeige partyId
        if (window.IS_DEBUG) console.log('🔍 PWA-DEBUG: currentPartyId=' + currentPartyId);
        
        // Lade Party-Dokument direkt, um created_by (djId) zu bekommen
        let djId = null;
        try {
          const partyDocRef = window.firebaseDoc(window.firebaseDb, 'parties', currentPartyId);
          const partyDoc = await window.firebaseGetDoc(partyDocRef);
          if (partyDoc.exists()) {
            const partyData = partyDoc.data();
            djId = partyData.created_by;
            if (window.IS_DEBUG) console.log('🔍 PWA-DEBUG: djId=' + djId);
            if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
            
            if (!djId || djId === '') {
              console.error('❌ PWA-ERROR: djId konnte nicht aus created_by extrahiert werden!');
              console.error('❌ PWA-ERROR: Party-Basisdaten unvollständig');
            }
          } else {
            console.error('❌ PWA-ERROR: Party-Dokument nicht gefunden für ID: ' + currentPartyId);
          }
        } catch (e) {
          console.error('❌ PWA-ERROR: Fehler beim Laden des Party-Dokuments:', e);
        }
        
        // VALIDIERUNG: Stelle sicher, dass djId vorhanden ist
        if (!djId || djId === '') {
          console.error('❌ PWA-ERROR: djId fehlt - kann History nicht laden');
          historyLoading.style.display = 'none';
          historyEmpty.style.display = 'block';
          return;
        }
        
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
        
        // Erstelle Snapshot Listener für Sessions dieser Party
        const sessionsRef = window.firebaseCollection(window.firebaseDb, 'music_history');
        // STRICT ISOLATION: Filtere nach djId UND partyId (lange ID)
        // WICHTIG: isActive Filter entfernt - wir wollen ALLE Songs der Party sehen
        if (!currentPartyId || currentPartyId === 'manual' || currentPartyId === '') {
          if (window.IS_DEBUG) console.warn('⚠️ Keine gültige party_id für Sessions-Query');
          return;
        }
        
        // Filter: party_id (mit Unterstrich) – Collection music_history, Sub-Collection tracks
        console.log('DEBUG [DJ-History]: Suche mit ID-Typ:', typeof currentPartyId, 'Wert:', currentPartyId);
        const sessionsQuery = window.firebaseQuery(
          sessionsRef,
          window.firebaseWhere('djId', '==', djId),
          window.firebaseWhere('party_id', '==', currentPartyId)
        );
        
        if (window.IS_DEBUG) console.log('📊 PWA-DEBUG: Query erstellt mit djId=' + djId + ', partyId=' + currentPartyId);
        
        // Erstelle Wrapper-Objekt für Listener-Management
        const listenerWrapper = {
          unsubscribe: null,
          trackListeners: []
        };
        
        listenerWrapper.unsubscribe = window.firebaseOnSnapshot(sessionsQuery, async (sessionsSnapshot) => {
          try {
            // DEBUG-LOGGING: Zeige Anzahl gefundener Sessions
            const snapshotSize = typeof sessionsSnapshot.size === 'number' ? sessionsSnapshot.size : (sessionsSnapshot.docs && sessionsSnapshot.docs.length);
            console.log('DEBUG [DJ-History]: Snapshot erhalten, Dokumente:', snapshotSize);
            if (window.IS_DEBUG) console.log('📊 PWA-DEBUG: Gefundene Sessions: ' + sessionsSnapshot.docs.length);
            if (sessionsSnapshot.docs.length > 0) {
              const firstSession = sessionsSnapshot.docs[0];
              if (window.IS_DEBUG) console.log('📊 PWA-DEBUG: Erste Session-ID: ' + firstSession.id);
              if (window.IS_DEBUG) console.log('✅ Basisdaten geladen');
            }
            
            // Stoppe alte Track-Listener falls vorhanden (bei Session-Update)
            if (listenerWrapper.trackListeners.length > 0) {
              listenerWrapper.trackListeners.forEach(unsubscribe => {
                if (typeof unsubscribe === 'function') {
                  unsubscribe();
                }
              });
              listenerWrapper.trackListeners = [];
            }
            
            // Sammle alle Tracks und erstelle Realtime-Listener
            let tracksLoaded = 0;
            const totalSessions = sessionsSnapshot.docs.length;
            let previousTrackCount = allTracksCache.length; // Speichere vorherige Anzahl für Neuerkennung
            
            // Wenn keine Sessions vorhanden, zeige leere History
            if (totalSessions === 0) {
              if (window.IS_DEBUG) console.warn('⚠️ PWA-WARNING: Keine Sessions gefunden für djId=' + djId + ', partyId=' + currentPartyId);
              historyLoading.style.display = 'none';
              const historyEmpty = document.getElementById('historyEmpty');
              if (historyEmpty) {
                historyEmpty.style.display = 'block';
              }
              return;
            }
            
            // Funktion zum Laden und Anzeigen der Tracks
            const updateTracksAndRender = () => {
              // Sortiere alle Tracks nach Timestamp (neueste zuerst)
              allTracksCache.sort((a, b) => b.timestamp - a.timestamp);
              
              // Prüfe ob neuer Song hinzugekommen ist
              const newTrackAdded = allTracksCache.length > previousTrackCount;
              
              // Wenn neuer Song hinzugekommen ist und wir auf Seite 1 sind, bleibe auf Seite 1
              // (Neue Songs erscheinen oben, daher bleibt Seite 1 korrekt)
              // Wenn wir auf einer anderen Seite sind, bleibe dort (Benutzer kann selbst wechseln)
              if (newTrackAdded && currentHistoryPage === 1) {
                // Bleibe auf Seite 1 - neuer Song erscheint oben
                // currentHistoryPage bleibt 1
              }
              
              // Aktualisiere vorherige Anzahl für nächsten Vergleich
              previousTrackCount = allTracksCache.length;
              
              // Rendere die aktuelle Seite
              renderHistoryPage();
              
              // Verstecke Loading nach erstem vollständigen Rendering
              if (tracksLoaded >= totalSessions) {
                historyLoading.style.display = 'none';
              }
            };
            
            // Erstelle onSnapshot-Listener für Tracks jeder Session
            sessionsSnapshot.docs.forEach(sessionDoc => {
              const sessionId = sessionDoc.id;
              const sessionData = sessionDoc.data();
              const sessionDjId = sessionData.djId;
              const sessionPartyId = sessionData.party_id || sessionData.partyId;
              
              // DEBUG-LOGGING: Zeige Session-Details
              if (window.IS_DEBUG) console.log('🔍 PWA-DEBUG: Session ' + sessionId + ': djId=' + sessionDjId + ', party_id=' + sessionPartyId);
              
              // SICHERHEITS-PRÜFUNG: Nur Sessions mit korrekter djId und party_id
              if (sessionDjId !== djId || sessionPartyId !== currentPartyId) {
                if (window.IS_DEBUG) console.warn('⚠️ PWA-WARNING: Session ' + sessionId + ' übersprungen (djId oder party_id stimmt nicht)');
                return;
              }
              
              const tracksRef = window.firebaseCollection(
                window.firebaseDb,
                `music_history/${sessionId}/tracks`
              );
              
              // Neueste Tracks zuerst; Cap pro Session reduziert erste Snapshot-Payload
              const tracksQuery = window.firebaseQuery(
                tracksRef,
                window.firebaseOrderBy('timestamp', 'desc'),
                window.firebaseLimit(PWA_FS_HISTORY_UI_TRACKS_PER_SESSION)
              );
              
              // Verwende onSnapshot für Realtime-Updates der Tracks
              const trackUnsubscribe = window.firebaseOnSnapshot(tracksQuery, (tracksSnapshot) => {
                if (window.IS_DEBUG) console.log('📥 PWA-DEBUG: Lade Tracks für Session ' + sessionId + '...');
                if (window.IS_DEBUG) console.log('📊 PWA-DEBUG: Session ' + sessionId + ' hat ' + tracksSnapshot.docs.length + ' Tracks');
                
                // Entferne alte Tracks dieser Session
                allTracksCache = allTracksCache.filter(t => t.sessionId !== sessionId);
                
                // Füge neue Tracks hinzu
                tracksSnapshot.docs.forEach(trackDoc => {
                  const trackData = trackDoc.data();
                  const timestamp = trackData.timestamp;
                  
                  if (timestamp) {
                    const trackTitle = (trackData.title || '').trim().toLowerCase();
                    const trackArtist = (trackData.artist || '').trim().toLowerCase();
                    
                    // ✅ Aktualisiere History-Cache beim Laden
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
                      timestamp: timestamp.toDate ? timestamp.toDate() : new Date(timestamp.seconds * 1000)
                    });
                  }
                });
                
                if (window.IS_DEBUG) console.log('✅ PWA-DEBUG: Insgesamt ' + allTracksCache.length + ' Tracks im Cache');
                
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
        
        // Speichere Listener-Wrapper
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
        const timeDiv = document.createElement('div');
        timeDiv.className = 'history-item-time';
        timeDiv.textContent = formatTime(track.timestamp);
        
        content.appendChild(titleDiv);
        content.appendChild(artistDiv);
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
          return window.formatPartyShortDateTime(date, lang);
        }
        const locale = typeof window.getPartyLocale === 'function' ? window.getPartyLocale(lang) : 'en-US';
        return new Intl.DateTimeFormat(locale, { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: locale.startsWith('en') }).format(date);
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
      if (pageId === 'wunschbox') {
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
      
      // ✅ Aktualisiere Seitentitel im Header
      updatePageTitle(pageId);
      
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
    }
    
    // ✅ Seite ohne Party-ID: Direktzugriff ohne Login → zur Main-PWA
    function showNoPartyInfoScreen(pageId) {
      if (window.IS_DEBUG) console.log('🔒 Keine Party-ID – Umleitung zur Main PWA.');
      console.warn('DEBUG [Auto-Login]: Redirect zur Startseite wird ausgelöst! Grund: showNoPartyInfoScreen (keine Party-ID, pageId=' + (pageId || '') + ').');
      window.location.replace('/');
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

      // ✅ Lade Party-Daten für dj_logo (wie in Wunschbox)
      const savedPartyId = validatedPartyId;
      if (savedPartyId && savedPartyId !== 'manual' && savedPartyId !== '') {
        try {
          const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), savedPartyId);
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
    
    /** VibesBox-Standardkanäle, wenn der DJ keine eigenen Links hat (Parität zur Flutter-Gast-App). */
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
      
      // ✅ Datenquelle: DJ / Host aus Firestore – social_media_links/{createdByUid}
      // Leer → VibesBox-Standardkanäle (wie Flutter-Gast-App)
      let socialsData = null;
      const validatedPartyId = localStorage.getItem('validatedPartyId') || sessionStorage.getItem('validatedPartyId');
      
      if (validatedPartyId && validatedPartyId !== 'manual' && validatedPartyId !== '') {
        try {
          const partyRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'parties'), validatedPartyId);
          const partyDoc = await window.firebaseGetDoc(partyRef);
          const createdByUid = partyDoc.exists() ? (partyDoc.data().created_by || null) : null;
          
          if (createdByUid) {
            const socialsRef = window.firebaseDoc(window.firebaseCollection(window.firebaseDb, 'social_media_links'), createdByUid);
            const socialsSnap = await window.firebaseGetDoc(socialsRef);
            if (socialsSnap && socialsSnap.exists()) {
              socialsData = socialsSnap.data();
              // ✅ Unterstütze auch platforms-Array (wie admin_config) für Kompatibilität
              if (socialsData.platforms && Array.isArray(socialsData.platforms) && socialsData.platforms.length > 0) {
                const converted = { order: [] };
                socialsData.platforms.forEach(function(p) {
                  var id = (p.id || '').toLowerCase().trim();
                  var url = (p.url || '').trim();
                  if (id && url && (url.indexOf('http://') === 0 || url.indexOf('https://') === 0)) {
                    converted[id] = url;
                    converted.order.push(id);
                  }
                });
                socialsData = converted;
              }
              if (window.IS_DEBUG) console.log('✅ DJ-Social aus social_media_links geladen:', socialsData.order || []);
            }
          }
        } catch (e) {
          if (window.IS_DEBUG) console.warn('social_media_links load failed', e);
        }
      }
      
      // ✅ Kein Fallback: Wenn leer oder Free ohne Links → leeres Objekt, zeige L10n-Hinweis
      const order = socialsData && (socialsData.order || socialsData.socialOrder) ? socialsData.order || socialsData.socialOrder : [];
      const hasLinks = order.length > 0 || (socialsData && Object.keys(socialsData).some(k => k !== 'order' && k !== 'socialOrder' && socialsData[k]));
      
      if (!socialsData || !hasLinks) {
        if (window.IS_DEBUG) console.log('⚠️ Keine DJ-Social-Links – zeige VibesBox-Fallback');
        const introElEarly = document.getElementById('socialMediaIntroduction');
        if (introElEarly) introElEarly.style.display = 'none';
        renderVibesboxFallbackSocial(container, emptyMessage);
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
      
      // ✅ Falls keine gültigen Links gefunden wurden → VibesBox-Fallback
      if (renderedPlatforms.size === 0) {
        if (window.IS_DEBUG) console.log('⚠️ Keine gültigen DJ-Social-Links – VibesBox-Fallback');
        const introductionElement = document.getElementById('socialMediaIntroduction');
        if (introductionElement) {
          introductionElement.style.display = 'none';
        }
        renderVibesboxFallbackSocial(container, emptyMessage);
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
          const finalText = introductionText.replace('{djName}', djName);
          introductionElement.innerHTML = finalText.replace(djName, `<strong>${safeDjName}</strong>`);
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
      let lang = 'de';
      try {
        lang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
      } catch (e) {
        lang = 'de';
      }
      
      const langTranslations = translations[lang] || translations['de'];
      
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
      let lang = 'de';
      try {
        lang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
      } catch (e) {
        lang = 'de';
      }
      
      const langTranslations = translations[lang] || translations['de'];
      
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
      let lang = 'de';
      try {
        lang = localStorage.getItem('pwa_language') || localStorage.getItem('language') || 'en';
      } catch (e) {
        lang = 'de';
      }
      const langTranslations = (typeof translations !== 'undefined' && translations[lang]) ? translations[lang] : (typeof translations !== 'undefined' ? translations['de'] : {});
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
              
              // ✅ Wenn Party beendet: Sofortiger Redirect zur Main PWA (replace verhindert Zurück-Button)
              if (isFinished) {
                if (window.IS_DEBUG) console.log('🔴 visibilitychange: Party beendet erkannt - Redirect zur Main PWA');
                console.warn('DEBUG [Auto-Login]: Redirect zur Startseite wird ausgelöst! Grund: visibilitychange – Party beendet erkannt.');
                localStorage.removeItem('validatedPartyId');
                localStorage.removeItem('validatedPartyCode');
                localStorage.removeItem('validatedPartyName');
                clearSessionPartyData();
                window.location.replace('/');
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
        
        // ✅ Seitentitel aktualisieren (für Sprachwechsel)
        const currentPage = document.querySelector('.page[style*="display: block"]');
        if (currentPage) {
          const pageId = currentPage.id.replace('page-', '');
          if (typeof updatePageTitle === 'function') {
            updatePageTitle(pageId);
          }
        }
        
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
