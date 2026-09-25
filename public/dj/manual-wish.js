/**
 * DJ-Browser: manueller Wunsch (Offen-Tab) — Parität zu lib/pages/manual_wish_page.dart
 */
(function (global) {
  const SPOTIFY_FUNCTION_URL =
    'https://us-central1-dj-ollerganove.cloudfunctions.net/searchSpotifyTracks';

  let deps = null;
  let duplicateThreshold = 0.85;
  let wishboxSuggestionsEnabled = true;
  let artistDebounce = null;
  let titleDebounce = null;
  let titleSearchAbortController = null;
  let artistSearchId = 0;
  let titleSearchId = 0;
  let selectedArtist = null;
  let selectedTrack = null;
  let saving = false;

  function sanitizeInput(text) {
    return String(text || '')
      .replace(/[<>]/g, '')
      .trim();
  }

  function resolvePartyOwnerUid(party, ownerUidFallback) {
    const fromParty = String(
      party?.created_by || party?.djId || party?.dj_code || party?.uid || '',
    ).trim();
    if (fromParty) return fromParty;
    return String(ownerUidFallback || '').trim();
  }

  function stringSimilarity(str1, str2) {
    if (!str1 || !str2) return 0;
    if (str1 === str2) return 1;
    const longer = str1.length > str2.length ? str1 : str2;
    const shorter = str1.length > str2.length ? str2 : str1;
    if (!longer.length) return 1;
    let matches = 0;
    const longerLower = longer.toLowerCase();
    const shorterLower = shorter.toLowerCase();
    for (let i = 0; i < shorterLower.length; i++) {
      if (longerLower.includes(shorterLower[i])) matches++;
    }
    if (longerLower.includes(shorterLower) || shorterLower.includes(longerLower)) {
      return Math.max(0.7, matches / longer.length);
    }
    return matches / longer.length;
  }

  function normalizeForDuplicate(title, artist, ignoredKeywords) {
    const wg = global.DjWishGrouping;
    const norm = wg && wg.normalizeTextForDuplicateCheck
      ? wg.normalizeTextForDuplicateCheck.bind(wg)
      : (text) => String(text || '').trim().toLowerCase();
    return {
      title: norm(title, ignoredKeywords),
      artist: norm(artist, ignoredKeywords),
    };
  }

  function combinedSimilarity(titleSim, artistSim, hasTitle, hasArtist) {
    if (hasTitle && hasArtist) return Math.min(titleSim, artistSim);
    if (hasTitle) return titleSim;
    if (hasArtist) return artistSim;
    return (titleSim + artistSim) / 2;
  }

  async function loadOwnerSuggestionSetting(ownerUid) {
    wishboxSuggestionsEnabled = true;
    const uid = String(ownerUid || '').trim();
    if (!uid) return;
    try {
      const snap = await global.djGetDoc(
        global.djDoc(
          global.djFirebaseDb,
          'users',
          uid,
          'guest_live',
          'wishbox',
        ),
      );
      const data = snap.exists() ? snap.data() : null;
      wishboxSuggestionsEnabled = data?.wishbox_suggestions_enabled !== false;
    } catch (e) {
      console.warn('[dj-manual-wish] suggestion settings', e);
    }
    applySuggestionsUi();
  }

  function applySuggestionsUi() {
    const hint = document.getElementById('dj-manual-suggestions-hint');
    if (hint) {
      hint.hidden = !wishboxSuggestionsEnabled;
      if (wishboxSuggestionsEnabled && deps) {
        hint.textContent = deps.t('suggestions_auto_appear');
      }
    }
    if (!wishboxSuggestionsEnabled) {
      ['dj-manual-artist-suggestions', 'dj-manual-title-suggestions'].forEach((id) => {
        const el = document.getElementById(id);
        if (!el) return;
        el.innerHTML = '';
        el.hidden = true;
      });
    }
  }

  async function loadDuplicateThreshold() {
    duplicateThreshold = 0.85;
    try {
      const snap = await global.djGetDoc(
        global.djDoc(global.djFirebaseDb, 'party_settings', 'current'),
      );
      if (snap.exists()) {
        const raw = snap.data()?.duplicate_threshold;
        if (typeof raw === 'number' && !Number.isNaN(raw)) {
          duplicateThreshold = Math.min(0.98, Math.max(0.5, raw));
        }
      }
    } catch (e) {
      console.warn('[dj-manual-wish] duplicate threshold', e);
    }
  }

  async function checkIfSongWasPlayed(title, artist, partyId, ignoredKeywords) {
    if (!partyId) return false;
    const { title: nt, artist: na } = normalizeForDuplicate(title, artist, ignoredKeywords);
    if (!nt && !na) return false;
    const threshold = duplicateThreshold;

    const logHit = (source, matchTitle, matchArtist, sim, docId, sessionId) => {
      const msg =
        `[DUP] HIT source=${source} party=${partyId} thr=${threshold.toFixed(2)} ` +
        `sim=${(sim * 100).toFixed(1)}% query="${title}" / "${artist}" ` +
        `match="${matchTitle}" / "${matchArtist}" doc=${docId || '-'} session=${sessionId || '-'}`;
      console.warn(msg);
    };

    try {
      let sessions = await global.djGetDocs(
        global.djQuery(
          global.djCollection(global.djFirebaseDb, 'music_history'),
          global.djWhere('party_id', '==', partyId),
        ),
      );
      if (sessions.empty) {
        sessions = await global.djGetDocs(
          global.djQuery(
            global.djCollection(global.djFirebaseDb, 'music_history'),
            global.djWhere('partyId', '==', partyId),
          ),
        );
      }
      for (const sessionDoc of sessions.docs) {
        const tracksSnap = await global.djGetDocs(
          global.djCollection(
            global.djFirebaseDb,
            'music_history',
            sessionDoc.id,
            'tracks',
          ),
        );
        for (const trackDoc of tracksSnap.docs) {
          const td = trackDoc.data() || {};
          const tt = normalizeForDuplicate(td.title || '', ignoredKeywords).title;
          const ta = normalizeForDuplicate(td.artist || '', ignoredKeywords).artist;
          if (!tt && !ta) continue;
          const ts = nt && tt ? stringSimilarity(nt, tt) : 0;
          const as = na && ta ? stringSimilarity(na, ta) : 0;
          const sim = combinedSimilarity(ts, as, nt && tt, na && ta);
          if (sim >= threshold) {
            logHit('music_history', td.title || '', td.artist || '', sim, trackDoc.id, sessionDoc.id);
            return true;
          }
        }
      }
    } catch (e) {
      console.warn('[dj-manual-wish] history check', e);
    }

    try {
      const playedSnap = await global.djGetDocs(
        global.djQuery(
          global.djCollection(global.djFirebaseDb, 'parties', partyId, 'wishes'),
          global.djWhere('status', '==', 'played'),
        ),
      );
      for (const wishDoc of playedSnap.docs) {
        const wd = wishDoc.data() || {};
        const wt = normalizeForDuplicate(wd.title || wd.song || '', ignoredKeywords).title;
        const wa = normalizeForDuplicate(wd.artist || '', ignoredKeywords).artist;
        if (!wt && !wa) continue;
        const ts = nt && wt ? stringSimilarity(nt, wt) : 0;
        const as = na && wa ? stringSimilarity(na, wa) : 0;
        const sim = combinedSimilarity(ts, as, nt && wt, na && wa);
        if (sim >= threshold) {
          logHit('played_wish', wd.title || wd.song || '', wd.artist || '', sim, wishDoc.id, '');
          return true;
        }
      }
    } catch (e) {
      console.warn('[dj-manual-wish] played wishes check', e);
    }
    return false;
  }

  async function checkIfSongInOpenWishes(title, artist, partyId, ignoredKeywords, spotifyId) {
    if (!partyId) return false;
    const { title: nt, artist: na } = normalizeForDuplicate(title, artist, ignoredKeywords);
    const threshold = duplicateThreshold;
    const minTitleArtist = Math.min(0.85, threshold);
    const titleThreshold = threshold * 0.8;
    const artistThreshold = threshold * 0.8;

    let pendingSnap;
    try {
      pendingSnap = await global.djGetDocs(
        global.djQuery(
          global.djCollection(global.djFirebaseDb, 'parties', partyId, 'wishes'),
          global.djWhere('status', '==', 'pending'),
          global.djOrderBy('createdAt', 'desc'),
        ),
      );
    } catch (e) {
      console.warn('[dj-manual-wish] pending query', e);
      return false;
    }

    const sid = String(spotifyId || '').trim();
    if (sid) {
      for (const docSnap of pendingSnap.docs) {
        const data = docSnap.data() || {};
        if (data.is_duplicate === true) continue;
        if (data.spotify_id === sid) {
          console.warn(
            `[DUP] HIT source=open_wish_spotify party=${partyId} ` +
              `query="${title}" / "${artist}" match="${data.title || ''}" / "${data.artist || ''}" ` +
              `doc=${docSnap.id}`,
          );
          return true;
        }
      }
    }

    let bestSimilarity = 0;
    let bestDoc = null;
    let bestData = null;
    for (const docSnap of pendingSnap.docs) {
      const data = docSnap.data() || {};
      if (data.is_duplicate === true) continue;
      const et = normalizeForDuplicate(data.title || data.song || '', ignoredKeywords).title;
      const ea = normalizeForDuplicate(data.artist || '', ignoredKeywords).artist;
      const ts = nt && et ? stringSimilarity(nt, et) : 0;
      const as = na && ea ? stringSimilarity(na, ea) : 0;
      let combined = 0;
      if (nt && na) combined = ts * 0.7 + as * 0.3;
      else if (nt) combined = ts;
      else if (na) combined = as;
      else continue;
      const titleMatch = ts >= titleThreshold;
      const artistMatch = as >= artistThreshold;
      const combinedMatch = combined >= threshold;
      const titleArtistMin = ts >= minTitleArtist && as >= minTitleArtist;
      const isDup =
        titleArtistMin && ((titleMatch && artistMatch) || combinedMatch) && combined > bestSimilarity;
      if (isDup) {
        bestSimilarity = combined;
        bestDoc = docSnap.id;
        bestData = data;
      }
    }
    if (bestSimilarity > 0 && bestData) {
      console.warn(
        `[DUP] HIT source=open_wish party=${partyId} thr=${threshold.toFixed(2)} ` +
          `sim=${(bestSimilarity * 100).toFixed(1)}% query="${title}" / "${artist}" ` +
          `match="${bestData.title || bestData.song || ''}" / "${bestData.artist || ''}" ` +
          `doc=${bestDoc}`,
      );
      return true;
    }
    return false;
  }

  async function searchSpotify(query, searchType, listEl, loadingEl, onSelect, options) {
    if (!wishboxSuggestionsEnabled) return;
    const q = String(query || '').trim();
    if (q.length < 2) {
      loadingEl.hidden = true;
      listEl.hidden = true;
      listEl.innerHTML = '';
      return;
    }
    loadingEl.hidden = false;
    listEl.hidden = true;
    listEl.innerHTML = '';
    const url = `${SPOTIFY_FUNCTION_URL}?q=${encodeURIComponent(q)}&type=${searchType}`;
    try {
      const headers = {};
      if (typeof global.getFirebaseAppCheckToken === 'function') {
        try {
          const token = await Promise.race([
            global.getFirebaseAppCheckToken(false),
            new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 3000)),
          ]);
          if (token) headers['X-Firebase-AppCheck'] = token;
        } catch (_) { /* optional */ }
      }
      const response = await fetch(url, { headers, signal: options?.signal });
      if (!response.ok) throw new Error(String(response.status));
      const data = await response.json();
      const resultType = data.resultType || (searchType === 'artist' ? 'artist' : 'track');
      const artists = data.artists || [];
      const tracks = data.tracks || [];
      listEl.innerHTML = '';
      if (options?.catalogHint) {
        const hint = document.createElement('div');
        hint.className = 'dj-manual-suggestion-hint';
        hint.textContent = options.catalogHint;
        listEl.appendChild(hint);
      }
      if (resultType === 'artist' && artists.length) {
        artists.slice(0, 20).forEach((artist) => {
          const item = document.createElement('button');
          item.type = 'button';
          item.className = 'dj-manual-suggestion-item';
          item.textContent = artist.name || '';
          item.addEventListener('click', () => onSelect(artist));
          listEl.appendChild(item);
        });
        listEl.hidden = false;
      } else if (resultType === 'track' && tracks.length) {
        tracks.slice(0, 20).forEach((track) => {
          const item = document.createElement('button');
          item.type = 'button';
          item.className = 'dj-manual-suggestion-item';
          const title = document.createElement('span');
          title.className = 'dj-manual-suggestion-title';
          title.textContent = track.name || '';
          const sub = document.createElement('span');
          sub.className = 'dj-manual-suggestion-sub';
          sub.textContent = track.artists || '';
          item.appendChild(title);
          item.appendChild(sub);
          item.addEventListener('click', () => onSelect(track));
          listEl.appendChild(item);
        });
        listEl.hidden = false;
      }
    } catch (e) {
      if (e.name !== 'AbortError') console.warn('[dj-manual-wish] spotify', e);
    } finally {
      loadingEl.hidden = true;
    }
  }

  function resetForm() {
    if (titleSearchAbortController) {
      titleSearchAbortController.abort();
      titleSearchAbortController = null;
    }
    selectedArtist = null;
    selectedTrack = null;
    const artistInput = document.getElementById('dj-manual-artist');
    const titleInput = document.getElementById('dj-manual-title');
    const greetingInput = document.getElementById('dj-manual-greeting');
    const artistList = document.getElementById('dj-manual-artist-suggestions');
    const titleList = document.getElementById('dj-manual-title-suggestions');
    if (artistInput) artistInput.value = '';
    if (titleInput) titleInput.value = '';
    if (greetingInput) greetingInput.value = '';
    if (artistList) {
      artistList.innerHTML = '';
      artistList.hidden = true;
    }
    if (titleList) {
      titleList.innerHTML = '';
      titleList.hidden = true;
    }
  }

  function closeDialog() {
    const overlay = document.getElementById('dj-manual-overlay');
    if (overlay) overlay.hidden = true;
    document.body.classList.remove('dj-manual-open');
    resetForm();
  }

  async function showDuplicateDialog(inHistory, inOpen) {
    const t = deps.t;
    let msg;
    if (inHistory && inOpen) msg = t('manual_wish_duplicate_history_and_open');
    else if (inHistory) msg = t('manual_wish_duplicate_history_only');
    else msg = t('manual_wish_duplicate_open_only');
    return deps.showConfirm(msg, {
      confirmLabel: t('submit_wish'),
      cancelLabel: t('cancel'),
      variant: 'play',
    });
  }

  async function saveManualWish() {
    if (saving) return;
    const t = deps.t;
    const st = deps.getState();
    const partyId = st.partyId;
    if (!partyId) return;

    const artistInput = document.getElementById('dj-manual-artist');
    const titleInput = document.getElementById('dj-manual-title');
    const greetingInput = document.getElementById('dj-manual-greeting');
    const artist = sanitizeInput(artistInput?.value);
    const title = sanitizeInput(titleInput?.value);
    let greeting = sanitizeInput(greetingInput?.value);
    if (greeting.length > 160) {
      deps.showToast(t('wish_greeting_max_chars_error'), '#ff8800');
      return;
    }
    if (!artist || !title) {
      deps.showToast(t('wish_title_or_artist_required'), '#ff8800');
      return;
    }

    const ignoredKeywords = st.ignoredKeywords || null;
    const spotifyId = selectedTrack?.id || selectedTrack?.spotify_id || null;

    await loadDuplicateThreshold();
    const inHistory = await checkIfSongWasPlayed(title, artist, partyId, ignoredKeywords);
    const inOpen = await checkIfSongInOpenWishes(
      title,
      artist,
      partyId,
      ignoredKeywords,
      spotifyId,
    );
    if (inHistory || inOpen) {
      console.warn(
        `[DUP] manual_wish dialog party=${partyId} inHistory=${inHistory} inOpen=${inOpen} ` +
          `query="${title}" / "${artist}"`,
      );
      const force = await showDuplicateDialog(inHistory, inOpen);
      if (!force) return;
    }

    saving = true;
    const saveBtn = document.getElementById('dj-manual-save');
    if (saveBtn) saveBtn.disabled = true;

    try {
      const createManual = window.djHttpsCallable('createDjBrowserManualWish');
      const result = await createManual({
        title,
        artist,
        greeting,
        spotifyId: spotifyId ? String(spotifyId) : '',
      });
      const line = result.data?.line || `${artist} – ${title}`;
      deps.showToast(t('manual_wish_saved_snack', { line }), '#2e7d32');
      closeDialog();
    } catch (e) {
      console.error('[dj-manual-wish] save', e);
      const msg = e?.message || String(e);
      deps.showToast(`${t('error')}: ${msg}`, '#c62828');
    } finally {
      saving = false;
      if (saveBtn) saveBtn.disabled = false;
    }
  }

  function bindFormHandlers() {
    const artistInput = document.getElementById('dj-manual-artist');
    const titleInput = document.getElementById('dj-manual-title');
    const artistList = document.getElementById('dj-manual-artist-suggestions');
    const titleList = document.getElementById('dj-manual-title-suggestions');
    const artistLoading = document.getElementById('dj-manual-artist-loading');
    const titleLoading = document.getElementById('dj-manual-title-loading');
    if (!artistInput || !titleInput) return;

    const onTrackSelected = (track) => {
      titleInput.value = track.name || '';
      artistInput.value = track.artists || artistInput.value;
      selectedTrack = track;
      selectedArtist = {
        id: (track.artist_ids && track.artist_ids[0]) || selectedArtist?.id || null,
        name: track.artists || selectedArtist?.name || '',
      };
      if (titleList) titleList.hidden = true;
    };

    artistInput.addEventListener('input', () => {
      if (!wishboxSuggestionsEnabled) return;
      clearTimeout(artistDebounce);
      const query = artistInput.value.trim();
      if (selectedArtist && query !== selectedArtist.name) {
        selectedArtist = null;
        selectedTrack = null;
      }
      if (selectedTrack && query !== selectedTrack.artists) {
        selectedTrack = null;
      }
      if (!query) {
        selectedArtist = null;
        if (artistList) {
          artistList.innerHTML = '';
          artistList.hidden = true;
        }
        return;
      }
      artistDebounce = setTimeout(() => {
        const id = ++artistSearchId;
        searchSpotify(query.replace(/"/g, ''), 'artist', artistList, artistLoading, (artist) => {
          if (id !== artistSearchId) return;
          artistInput.value = artist.name || '';
          selectedArtist = { id: artist.id || null, name: artist.name || '' };
          selectedTrack = null;
          titleInput.value = '';
          if (artistList) artistList.hidden = true;
        });
      }, 500);
    });

    titleInput.addEventListener('input', () => {
      if (!wishboxSuggestionsEnabled) return;
      clearTimeout(titleDebounce);
      if (titleSearchAbortController) {
        titleSearchAbortController.abort();
        titleSearchAbortController = null;
      }
      const query = titleInput.value.trim();
      if (selectedTrack && query !== selectedTrack.name) {
        selectedTrack = null;
      }
      if (!query) {
        if (titleList) {
          titleList.innerHTML = '';
          titleList.hidden = true;
        }
        return;
      }
      titleDebounce = setTimeout(() => {
        const id = ++titleSearchId;
        titleSearchAbortController = new AbortController();
        const signal = titleSearchAbortController.signal;
        let searchQuery = query.replace(/"/g, '');
        if (selectedArtist && selectedArtist.name) {
          const cleanArtist = selectedArtist.name.replace(/"/g, '');
          const cleanTrack = query.replace(/"/g, '');
          searchQuery = `artist:"${cleanArtist}" track:"${cleanTrack}"`;
        }
        searchSpotify(searchQuery, 'track', titleList, titleLoading, (track) => {
          if (id !== titleSearchId) return;
          onTrackSelected(track);
        }, { signal });
      }, 500);
    });

    titleInput.addEventListener('focus', () => {
      if (!wishboxSuggestionsEnabled) return;
      const isEmpty = !titleInput.value || titleInput.value.trim().length === 0;
      if (!isEmpty || !selectedArtist || !selectedArtist.name) return;

      if (titleSearchAbortController) {
        titleSearchAbortController.abort();
      }
      titleSearchAbortController = new AbortController();
      const signal = titleSearchAbortController.signal;

      const cleanArtist = selectedArtist.name.replace(/"/g, '');
      const catalogQuery = `artist:"${cleanArtist}"`;
      const hintText = deps.t('catalog_top_songs', { artist: selectedArtist.name });

      searchSpotify(catalogQuery, 'track', titleList, titleLoading, onTrackSelected, {
        signal,
        catalogHint: hintText,
      });
    });
  }

  function applyLabels() {
    const t = deps.t;
    const titleEl = document.getElementById('dj-manual-title-label');
    const artistEl = document.getElementById('dj-manual-artist-label');
    const greetingEl = document.getElementById('dj-manual-greeting-label');
    const greetingHint = document.getElementById('dj-manual-greeting-hint');
    const cancelBtn = document.getElementById('dj-manual-cancel');
    const saveBtn = document.getElementById('dj-manual-save');
    const heading = document.getElementById('dj-manual-heading');
    if (heading) heading.textContent = t('add_manual_wish');
    if (artistEl) artistEl.textContent = `${t('wish_artist_label')} *`;
    if (titleEl) titleEl.textContent = `${t('wish_title_label')} *`;
    if (greetingEl) greetingEl.textContent = t('wish_greeting_label');
    if (greetingHint) greetingHint.textContent = t('wish_greeting_max_chars');
    if (cancelBtn) cancelBtn.textContent = t('cancel');
    if (saveBtn) saveBtn.textContent = t('submit_wish');
    const addBtn = document.getElementById('dj-manual-add');
    if (addBtn) {
      addBtn.title = t('add_manual_wish');
      addBtn.setAttribute('aria-label', t('add_manual_wish'));
    }
    const closeBtn = document.getElementById('dj-manual-close');
    if (closeBtn) closeBtn.setAttribute('aria-label', t('button_close') || t('dj_browser_confirm_cancel'));
    applySuggestionsUi();
  }

  async function openDialog() {
    const st = deps.getState();
    if (!st.partyId || st.view !== 'box' || st.activeTab !== 'offen') return;
    await loadDuplicateThreshold();
    await loadOwnerSuggestionSetting(st.ownerUid);
    applyLabels();
    resetForm();
    const overlay = document.getElementById('dj-manual-overlay');
    if (overlay) {
      overlay.hidden = false;
      document.body.classList.add('dj-manual-open');
      document.getElementById('dj-manual-artist')?.focus();
    }
  }

  function updateAddButtonVisibility() {
    const btn = document.getElementById('dj-manual-add');
    if (!btn || !deps) return;
    const st = deps.getState();
    const show = st.view === 'box' && st.activeTab === 'offen' && !!st.partyId;
    btn.hidden = !show;
    if (show) applyLabels();
  }

  function init(options) {
    deps = options;
    const overlay = document.getElementById('dj-manual-overlay');
    const closeBtn = document.getElementById('dj-manual-close');
    const cancelBtn = document.getElementById('dj-manual-cancel');
    const saveBtn = document.getElementById('dj-manual-save');
    const addBtn = document.getElementById('dj-manual-add');
    if (closeBtn) closeBtn.addEventListener('click', closeDialog);
    if (cancelBtn) cancelBtn.addEventListener('click', closeDialog);
    if (saveBtn) saveBtn.addEventListener('click', () => saveManualWish());
    if (addBtn) addBtn.addEventListener('click', () => openDialog());
    if (overlay) {
      overlay.addEventListener('click', (ev) => {
        if (ev.target === overlay) closeDialog();
      });
    }
    bindFormHandlers();
    applyLabels();
    updateAddButtonVisibility();
    window.addEventListener('djBrowserLocaleChanged', () => {
      applyLabels();
    });
  }

  global.DjManualWish = {
    init,
    openDialog,
    updateAddButtonVisibility,
  };
})(window);
