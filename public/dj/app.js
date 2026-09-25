/**
 * DJ VibesBox Browser — Code-Login + Wunsch-Tabs.
 */

const STORAGE_DEVICE = 'vb_dj_browser_device_id';

const state = {
  view: 'login',
  partyId: null,
  sessionId: null,
  ownerUid: null,
  party: null,
  ownerGraceMinutes: 0,
  graceMinutesFromServer: false,
  activeTab: 'offen',
  showOnlyFavorites: false,
  wishes: [],
  wishesLoading: false,
  /** client_id → true für aktuell gesperrte Gäste dieser Party */
  blockedClientIds: new Set(),
  savedTrackKeys: new Set(),
  ignoredKeywords: null,
  showGreetingTranslations: true,
  greetingTranslationCache: new Map(),
  pinnedKeys: [],
  serverOrderKeys: [],
  serverOrderRev: 0,
  localOrderOverride: null,
  reorderActive: false,
  resultsPerPage: 20,
  currentPage: 1,
  lastRedeemCode: null,
  unsubscribers: [],
  setlistTracks: [],
  setlistTracksRaw: [],
  setlistBusy: false,
  setlistSelectedIndex: null,
  /** true wenn DJ-Blacklist aktiv (wie Flutter-Default, auch vor erstem Snapshot). */
  blacklistEnabled: true,
  blacklistSongCount: 0,
};

const DJ_DEFAULT_RESULTS_PER_PAGE = 20;
const DJ_ALLOWED_RESULTS_PER_PAGE = (() => {
  const list = [];
  for (let n = 10; n <= 150; n += 10) list.push(n);
  return list;
})();

const MAX_PINNED_KEYS = 3;
const GREETING_TR_CACHE_KEY = 'vb_dj_greeting_tr_v1';
const SETLIST_ACTIONS_ARM_MS = 450;
let setlistActionsArmedAt = 0;

let pingTimerId = null;
let bootDone = false;

function t(key, vars) {
  let text;
  if (typeof window.djBrowserT === 'function') {
    text = window.djBrowserT(key);
  } else {
    const map = window.DJ_BROWSER_L10N || {};
    const loc = window.djBrowserLocale || 'en';
    const pack = map[loc] || map.en || {};
    text = pack[key] || (map.en && map.en[key]) || key;
  }
  if (vars && typeof vars === 'object') {
    Object.entries(vars).forEach(([name, value]) => {
      text = text.replace(new RegExp(`\\{${name}\\}`, 'g'), String(value));
    });
  }
  return text;
}

function readActiveDjLangCode() {
  if (typeof window.djBrowserReadActiveLang === 'function') {
    return window.djBrowserReadActiveLang();
  }
  return window.djBrowserLocale || 'en';
}

function djLang() {
  return readActiveDjLangCode();
}

function detectLocale() {
  return djLang();
}

const MANUAL_BY_DJ_MARKER = '__manual_by_dj__';
const FROM_SETLIST_MARKER = '__from_setlist__';

function wisherDisplayName(raw, options = {}) {
  const n = String(raw ?? '').trim();
  if (options.fromSetlist || n === FROM_SETLIST_MARKER) return t('from_setlist');
  if (n === MANUAL_BY_DJ_MARKER) return t('manual_by_dj');
  if (options.isDjWish) return t('manual_by_dj');
  if (!n) return t('no_name');
  const lower = n.toLowerCase();
  const packs = window.DJ_BROWSER_L10N || {};
  for (const code of Object.keys(packs)) {
    const pack = packs[code] || {};
    const noName = String(pack.no_name || '').trim();
    if (noName && noName.toLowerCase() === lower) return t('no_name');
    const fromSetlist = String(pack.from_setlist || '').trim();
    if (fromSetlist && fromSetlist.toLowerCase() === lower) return t('from_setlist');
    const manualByDj = String(pack.manual_by_dj || '').trim();
    if (manualByDj && manualByDj.toLowerCase() === lower) return t('manual_by_dj');
  }
  return n;
}

function djLocaleTag(code) {
  const map = window.PARTY_LOCALE_MAP || {};
  return map[code] || map.en || 'en-US';
}

function djLocaleOpts(code) {
  const opts = (window.PARTY_LOCALE_OPTS && window.PARTY_LOCALE_OPTS[code]) || {};
  if (Object.keys(opts).length) return opts;
  if (code === 'de') return { time_style: 'colon_suffix', time_suffix: ' Uhr' };
  if (code === 'en' || code === 'hi' || code === 'ar') {
    return { hour12: true, time_style: 'intl_12', time_suffix: '' };
  }
  return { time_style: 'colon_suffix', time_suffix: '' };
}

/** Uhrzeit nach languages.json — nur expliziter [code], keine versteckten Fallbacks auf DE. */
function formatDjClock(date, langCode) {
  if (!date || !(date instanceof Date) || Number.isNaN(date.getTime())) return '';
  const code = String(langCode || 'de').toLowerCase().split('-')[0];
  const locale = djLocaleTag(code);
  const opts = djLocaleOpts(code);
  const style = opts.time_style || 'colon_suffix';
  const suffix = typeof opts.time_suffix === 'string' ? opts.time_suffix.trim() : '';

  if (style === 'intl_12' || opts.hour12 === true) {
    return new Intl.DateTimeFormat(locale, {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    }).format(date);
  }

  const parts = new Intl.DateTimeFormat(locale, {
    hour: 'numeric',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(date);
  let hour = 0;
  let minute = 0;
  parts.forEach((part) => {
    if (part.type === 'hour') hour = parseInt(part.value, 10);
    if (part.type === 'minute') minute = parseInt(part.value, 10);
  });
  const mm = String(minute).padStart(2, '0');

  if (style === 'fr_h') return `${hour} h ${mm}`;
  if (style === 'h_compact' || style === 'pt_h') return `${hour}h${mm}`;
  if (style === 'ja_kanji') return `${hour}時${mm}分`;

  const clock = new Intl.DateTimeFormat(locale, {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date);
  if (!suffix || clock.includes(suffix)) return clock;
  return `${clock}\u00A0${suffix}`;
}

function partyIntlLocale() {
  return djLocaleTag(djLang());
}

function formatClockWithSuffix(date) {
  return formatDjClock(date, djLang());
}

function formatLocaleDateYmd(date) {
  if (!date || !(date instanceof Date) || Number.isNaN(date.getTime())) return '';
  const locale = partyIntlLocale();
  try {
    return new Intl.DateTimeFormat(locale, {
      day: 'numeric',
      month: 'numeric',
      year: 'numeric',
    }).format(date);
  } catch (e) {
    return date.toLocaleDateString(locale);
  }
}

function formatDjCompactDateTimeLine(date) {
  if (!date || !(date instanceof Date) || Number.isNaN(date.getTime())) return '';
  return `${formatLocaleDateYmd(date)} ${formatDjClock(date, djLang())}`;
}

function formatWishDateTimeLine(date, opts = {}) {
  if (!date || !(date instanceof Date) || Number.isNaN(date.getTime())) return '';
  if (opts.timeOnly) return formatClockWithSuffix(date);
  return formatDjCompactDateTimeLine(date);
}

function greetingTranslationCacheKey(text) {
  const trimmed = String(text || '').trim();
  if (!trimmed || !state.showGreetingTranslations) return null;
  const target = detectLocale();
  const source = detectGreetingSourceForApi(trimmed);
  if (source !== null && source === target) return null;
  return `${trimmed}|${target}|${source || 'auto'}`;
}

function loadGreetingTranslationCache() {
  try {
    const raw = sessionStorage.getItem(GREETING_TR_CACHE_KEY);
    if (!raw) return;
    const obj = JSON.parse(raw);
    if (!obj || typeof obj !== 'object') return;
    Object.entries(obj).forEach(([key, value]) => {
      if (typeof value === 'string' && value.trim()) {
        state.greetingTranslationCache.set(key, value.trim());
      }
    });
  } catch (e) {
    console.warn('[dj-browser] greeting cache load', e);
  }
}

function saveGreetingTranslationCacheEntry(cacheKey, translated) {
  if (!cacheKey || !translated) return;
  state.greetingTranslationCache.set(cacheKey, translated);
  try {
    const obj = {};
    state.greetingTranslationCache.forEach((value, key) => {
      if (value) obj[key] = value;
    });
    sessionStorage.setItem(GREETING_TR_CACHE_KEY, JSON.stringify(obj));
  } catch (e) {
    console.warn('[dj-browser] greeting cache save', e);
  }
}

function peekGreetingTranslation(text) {
  const cacheKey = greetingTranslationCacheKey(text);
  if (!cacheKey) return null;
  const hit = state.greetingTranslationCache.get(cacheKey);
  return hit || null;
}

function normalizeText(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function unescapeHtml(text) {
  if (!text || typeof text !== 'string') return text || '';
  const textarea = document.createElement('textarea');
  textarea.innerHTML = text;
  return textarea.value;
}

function wishesFromFirestoreDocs(docs) {
  return docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .sort((a, b) => {
      const ta = a.createdAt?.toMillis?.() || a.created_at?.toMillis?.() || 0;
      const tb = b.createdAt?.toMillis?.() || b.created_at?.toMillis?.() || 0;
      return tb - ta;
    });
}

function isGuestBlockActive(data) {
  if (!data || typeof data !== 'object') return false;
  const blockStatus = String(data.block_status || '').trim().toLowerCase();
  if (blockStatus === 'party_specific' || blockStatus === 'permanent') return true;
  if (blockStatus === 'temporary') {
    const until = data.blocked_until;
    if (until && typeof until.toDate === 'function') {
      return until.toDate() > new Date();
    }
  }
  return false;
}

function isWishFromBlockedGuest(wish) {
  if (!wish) return false;
  if (wish.rejection_reason === 'user_blocked' || wish.auto_rejected_by_block === true) {
    return true;
  }
  const cid = String(wish.client_id || '').trim();
  return Boolean(cid && state.blockedClientIds.has(cid));
}

function entryHasBlockedGuest(entry) {
  const primary = entry?.wish || entry?.group || {};
  if (isWishFromBlockedGuest(primary)) return true;
  const ids = Array.isArray(entry?.docIds) ? entry.docIds : [];
  for (const id of ids) {
    const w = state.wishes.find((x) => String(x.id) === String(id));
    if (isWishFromBlockedGuest(w)) return true;
  }
  return false;
}

/** Badge auf Abgelehnt-Karten für durch Sperre abgelehnte / gesperrte Gäste. */
function renderGuestBlockedBadge(entry) {
  if (state.activeTab !== 'abgelehnt') return '';
  if (!entryHasBlockedGuest(entry)) return '';
  const label = escapeHtml(t('guest_blocked_badge'));
  return `<span class="wish-guest-blocked-badge" role="status">${label}</span>`;
}

function isWishFromSongBlacklist(wish) {
  if (!wish) return false;
  return wish.auto_rejected_by_blacklist === true ||
    wish.rejection_reason === 'song_blacklist';
}

function parseBlacklistEnabledFromDoc(data) {
  if (!data) return true;
  if (Object.prototype.hasOwnProperty.call(data, 'enabled')) {
    return data.enabled === true;
  }
  const raw = data.entries;
  if (Array.isArray(raw)) {
    for (const item of raw) {
      if (!item || typeof item !== 'object') continue;
      if (String(item.id || '').trim() !== '_vb_prefs') continue;
      if (Object.prototype.hasOwnProperty.call(item, 'enabled')) {
        return item.enabled === true;
      }
    }
  }
  return true;
}

function countSongBlacklistHits() {
  return state.wishes.filter((w) => {
    const status = String(w.status || '').toLowerCase();
    return status === 'rejected' && isWishFromSongBlacklist(w);
  }).length;
}

function parseBlacklistSongCount(data) {
  const raw = data && data.entries;
  if (!Array.isArray(raw)) return 0;
  let n = 0;
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    if (String(item.id || '').trim() === '_vb_prefs') continue;
    const title = String(item.title || '').trim();
    const artist = String(item.artist || '').trim();
    if (title || artist) n += 1;
  }
  return n;
}

function blacklistChipNumber() {
  const hits = countSongBlacklistHits();
  if (hits > 0) return hits;
  return Number(state.blacklistSongCount) || 0;
}

function blacklistChipText() {
  return `BLACKLIST ${blacklistChipNumber()}`;
}

function updateOffenBlacklistChip() {
  const el = document.getElementById('offen-blacklist-chip');
  const row = document.getElementById('offen-blacklist-row');
  if (!el) return;
  const show = state.view === 'box' && state.activeTab === 'offen';
  if (!show) {
    el.hidden = true;
    if (row) row.hidden = true;
    return;
  }
  el.hidden = false;
  el.removeAttribute('hidden');
  if (row) {
    row.hidden = false;
    row.removeAttribute('hidden');
  }
  el.textContent = blacklistChipText();
}

function entryHasSongBlacklist(entry) {
  const primary = entry?.wish || entry?.group || {};
  if (isWishFromSongBlacklist(primary)) return true;
  const ids = Array.isArray(entry?.docIds) ? entry.docIds : [];
  for (const id of ids) {
    const w = state.wishes.find((x) => String(x.id) === String(id));
    if (isWishFromSongBlacklist(w)) return true;
  }
  return false;
}

function renderSongBlacklistBadge(entry) {
  if (state.activeTab !== 'abgelehnt') return '';
  if (!entryHasSongBlacklist(entry)) return '';
  const label = escapeHtml(t('song_blacklist_title'));
  return `<span class="wish-song-blacklist-badge" role="status">${label}</span>`;
}

function renderWishListLoading() {
  const root = document.getElementById('wish-list');
  if (!root) return;
  const loadingLabel = t('dj_browser_loading');
  const existing = root.querySelector('.wish-loading');
  if (existing) {
    const textEl = existing.querySelector('.wish-loading-text');
    if (textEl) textEl.textContent = loadingLabel;
    return;
  }
  root.replaceChildren();
  const wrap = document.createElement('div');
  wrap.className = 'wish-loading';
  wrap.innerHTML =
    '<span class="login-spinner" aria-hidden="true"></span>'
    + `<span class="wish-loading-text">${loadingLabel}</span>`;
  root.appendChild(wrap);
}

function loadSecondaryBoxSettings() {
  return Promise.all([
    loadDuplicateSettings(),
    loadTranslationSettings(),
    loadSavedTracks(),
  ]).then(() => {
    if (state.view !== 'box') return;
    lastWishListKey = '';
    renderWishes(true);
    updateTopBarControls();
  }).catch((e) => {
    console.warn('[dj-browser] secondary settings', e);
  });
}

function parseResultsPerPage(raw) {
  const n = typeof raw === 'number' ? raw : parseInt(String(raw), 10);
  if (DJ_ALLOWED_RESULTS_PER_PAGE.includes(n)) return n;
  return null;
}

async function loadDjResultsPerPage(djId) {
  if (!djId) return DJ_DEFAULT_RESULTS_PER_PAGE;
  try {
    const userSnap = await window.djGetDoc(
      window.djDoc(
        window.djFirebaseDb,
        'users',
        String(djId),
        'settings',
        'results_per_page',
      ),
    );
    if (userSnap.exists()) {
      const parsed = parseResultsPerPage(userSnap.data()?.results_per_page);
      if (parsed != null) return parsed;
    }
    const globalSnap = await window.djGetDoc(
      window.djDoc(window.djFirebaseDb, 'party_settings', 'current'),
    );
    if (globalSnap.exists()) {
      const parsed = parseResultsPerPage(globalSnap.data()?.results_per_page);
      if (parsed != null) return parsed;
    }
  } catch (e) {
    console.warn('[dj-browser] results_per_page', e);
  }
  return DJ_DEFAULT_RESULTS_PER_PAGE;
}

function calculateTotalPages(totalItems, itemsPerPage) {
  const perPage = itemsPerPage || DJ_DEFAULT_RESULTS_PER_PAGE;
  if (totalItems <= 0) return 0;
  return Math.floor((totalItems - 1) / perPage) + 1;
}

function getItemsForPage(allItems, currentPage, itemsPerPage) {
  if (!allItems.length) return [];
  const perPage = itemsPerPage || DJ_DEFAULT_RESULTS_PER_PAGE;
  const page = Math.max(1, currentPage || 1);
  const start = (page - 1) * perPage;
  if (start >= allItems.length) return [];
  const end = Math.min(page * perPage, allItems.length);
  return allItems.slice(start, end);
}

function scrollWishListToTop() {
  const root = document.getElementById('wish-list');
  if (root) root.scrollTop = 0;
}

/** Nach Login / View-Wechsel: Header (Logo, Party) oben sichtbar, nicht erst nach Hochscrollen. */
function scrollAppToTop() {
  try {
    window.scrollTo(0, 0);
  } catch (e) { /* ignore */ }
  document.documentElement.scrollTop = 0;
  document.body.scrollTop = 0;
  const appRoot = document.getElementById('app-root');
  if (appRoot) appRoot.scrollTop = 0;
  scrollWishListToTop();
}

function resetWishListPage() {
  state.currentPage = 1;
  lastWishListKey = '';
  state.setlistSelectedIndex = null;
}

function renderPaginationBar(totalItems) {
  const el = document.getElementById('wish-pagination');
  if (!el) return;
  const perPage = state.resultsPerPage || DJ_DEFAULT_RESULTS_PER_PAGE;
  const totalPages = calculateTotalPages(totalItems, perPage);
  if (state.reorderActive || totalPages <= 1) {
    el.hidden = true;
    el.innerHTML = '';
    return;
  }
  if (state.currentPage > totalPages) state.currentPage = totalPages;
  if (state.currentPage < 1) state.currentPage = 1;
  const page = state.currentPage;
  el.hidden = false;
  el.innerHTML = `
    <button type="button" class="wish-page-btn" data-page="prev"${page <= 1 ? ' disabled' : ''}>
      ${escapeHtml(t('history_page_previous'))}
    </button>
    <span class="wish-page-label">${escapeHtml(t('history_page'))} ${page} / ${totalPages}</span>
    <button type="button" class="wish-page-btn" data-page="next"${page >= totalPages ? ' disabled' : ''}>
      ${escapeHtml(t('history_page_next'))}
    </button>`;
}

let wishPaginationSetup = false;

function setupWishPagination() {
  if (wishPaginationSetup) return;
  wishPaginationSetup = true;
  const el = document.getElementById('wish-pagination');
  if (!el) return;
  el.addEventListener('click', (ev) => {
    const btn = ev.target.closest('[data-page]');
    if (!btn || btn.disabled) return;
    const allGrouped = groupedEntriesForTab();
    const totalPages = calculateTotalPages(
      allGrouped.length,
      state.resultsPerPage || DJ_DEFAULT_RESULTS_PER_PAGE,
    );
    if (btn.dataset.page === 'prev' && state.currentPage > 1) {
      state.currentPage -= 1;
    } else if (btn.dataset.page === 'next' && state.currentPage < totalPages) {
      state.currentPage += 1;
    } else {
      return;
    }
    lastWishListKey = '';
    renderWishes(true);
    scrollWishListToTop();
  });
}

function wishGrouping() {
  return window.DjWishGrouping || null;
}

async function loadDuplicateSettings() {
  const fallback = wishGrouping()?.IGNORED_KEYWORDS_DEFAULT || ['Remix', 'Mix', 'Edit'];
  state.ignoredKeywords = fallback.slice();
  try {
    const ref = window.djDoc(window.djFirebaseDb, 'party_settings', 'current');
    const snap = await window.djGetDoc(ref);
    if (snap.exists()) {
      const data = snap.data() || {};
      if (Array.isArray(data.ignored_keywords) && data.ignored_keywords.length) {
        state.ignoredKeywords = data.ignored_keywords
          .filter((k) => k != null && String(k).trim())
          .map((k) => String(k).trim());
      }
    }
  } catch (e) {
    console.warn('[dj-browser] duplicate settings', e);
  }
}

async function loadTranslationSettings() {
  state.showGreetingTranslations = true;
  const owner = state.ownerUid;
  if (!owner) return;
  try {
    const snap = await window.djGetDoc(window.djDoc(window.djFirebaseDb, 'users', String(owner)));
    if (snap.exists()) {
      const value = snap.data()?.show_greeting_translations;
      if (typeof value === 'boolean') state.showGreetingTranslations = value;
    }
  } catch (e) {
    console.warn('[dj-browser] translation settings', e);
  }
}

function detectGreetingLanguage(text) {
  const s = String(text || '').trim();
  if (!s) return 'de';

  const lower = s.toLowerCase();

  if (/[\u4e00-\u9fff]/.test(s)) return 'zh';
  if (/[а-яё]/i.test(s)) return 'ru';
  if (/[ğĞıİşŞüÜöÖçÇ]/.test(s)) return 'tr';

  const frenchWords = [
    'bonjour', 'salut', 'merci', 'au revoir', 'bonsoir', 'ça va',
    'comment', 'vous', 'êtes', 'français',
  ];
  if (frenchWords.some((word) => lower.includes(word))) return 'fr';

  const spanishWords = [
    'hola', 'gracias', 'adiós', 'por favor', 'buenos días', 'buenas noches',
    'español', 'cómo', 'estás',
  ];
  if (spanishWords.some((word) => lower.includes(word))) return 'es';

  const englishWords = [
    'hello', 'hi', 'hey', 'thank you', 'thanks', 'thank', 'goodbye', 'bye',
    'good morning', 'good evening', 'good night', 'how are you', 'english',
    'please', 'wish', 'wishes', 'song', 'songs', 'play', 'playing', 'love',
    'happy', 'birthday', 'congratulations', 'congrats', 'cheers', 'best',
    'great', 'awesome', 'amazing', 'fantastic', 'wonderful', 'enjoy',
  ];
  if (englishWords.some((word) => lower.includes(word))) return 'en';

  if (!/[äöüÄÖÜß]/.test(s) && /^[a-zA-Z\s.,!?\-'"]+$/.test(s)) {
    if (/\b(the|and|or|but|in|on|at|to|for|of|with|from)\b/i.test(lower)) {
      return 'en';
    }
  }

  if (/[äöüÄÖÜß]/.test(s)) return 'de';

  const germanWords = [
    'hallo', 'guten tag', 'danke', 'tschüss', 'auf wiedersehen', 'wie geht', 'deutsch',
  ];
  if (germanWords.some((word) => lower.includes(word))) return 'de';

  return 'de';
}

/** Quellsprache für Gemini — bei unsicherer Heuristik null (Auto-Erkennung). */
function detectGreetingSourceForApi(text) {
  const s = String(text || '').trim();
  const target = detectLocale();
  const detected = detectGreetingLanguage(s);

  if (detected === target) {
    // Nur-Latin ohne deutsche Umlaute: oft Englisch, nicht sicher „de“.
    if (
      detected === 'de' &&
      /^[a-zA-Z\s.,!?\-'"]+$/.test(s) &&
      !/[äöüÄÖÜß]/.test(s)
    ) {
      return null;
    }
    return detected;
  }
  return detected;
}

async function translateGreetingCached(greeting) {
  const text = String(greeting || '').trim();
  if (!text || !state.showGreetingTranslations) return null;
  const cacheKey = greetingTranslationCacheKey(text);
  if (!cacheKey) return null;
  if (state.greetingTranslationCache.has(cacheKey)) {
    return state.greetingTranslationCache.get(cacheKey);
  }
  try {
    const target = detectLocale();
    const source = detectGreetingSourceForApi(text);
    const fn = window.djHttpsCallable('translateGreeting');
    const result = await fn({
      text: text,
      targetLanguage: target,
      sourceLanguage: source,
    });
    const data = result.data || {};
    const translated = typeof data.translatedText === 'string' ? data.translatedText.trim() : '';
    if (data.skipped === true || !translated || translated === text) {
      return null;
    }
    saveGreetingTranslationCacheEntry(cacheKey, translated);
    return translated;
  } catch (e) {
    console.warn('[dj-browser] greeting translation', e);
    return null;
  }
}

async function enhanceGreetingTranslations(root) {
  if (!state.showGreetingTranslations || !root) return;
  const nodes = root.querySelectorAll('[data-greeting-text]');
  await Promise.all(Array.from(nodes).map(async (node) => {
    const text = node.getAttribute('data-greeting-text') || '';
    const cached = peekGreetingTranslation(text);
    if (cached && !node.nextElementSibling?.classList.contains('wish-greeting-translation')) {
      const tr = document.createElement('p');
      tr.className = 'wish-greeting-translation';
      tr.textContent = cached;
      node.insertAdjacentElement('afterend', tr);
      node.dataset.translationDone = '1';
      return;
    }
    if (node.dataset.translationDone === '1' || node.dataset.translationPending === '1') {
      return;
    }
    node.dataset.translationPending = '1';
    try {
      const translated = await translateGreetingCached(text);
      if (!translated) return;
      if (node.nextElementSibling?.classList.contains('wish-greeting-translation')) return;
      const tr = document.createElement('p');
      tr.className = 'wish-greeting-translation';
      tr.textContent = translated;
      node.insertAdjacentElement('afterend', tr);
      node.dataset.translationDone = '1';
    } finally {
      delete node.dataset.translationPending;
    }
  }));
}

function parsePinnedKeys(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((k) => String(k || '').trim())
    .filter(Boolean)
    .slice(0, MAX_PINNED_KEYS);
}

function isWishPinned(groupKey) {
  const key = String(groupKey || '').trim();
  return key.length > 0 && state.pinnedKeys.includes(key);
}

function wishReorder() {
  return window.DjWishReorder || null;
}

function syncPartyOrderFields(party) {
  const wr = wishReorder();
  if (!party || !wr) return;
  const rawPins = parsePinnedKeys(party.open_wish_pinned_keys);
  state.pinnedKeys = wr.resolveStoredPinKeys(rawPins, groupedEntriesForTabRaw());
  if (!state.reorderActive) {
    state.serverOrderKeys = wr.parseOrderKeys(party.open_wish_order);
  }
  state.serverOrderRev = Number(party.open_wish_order_rev) || 0;
}

async function reloadPartyOrderSyncFields() {
  if (!state.partyId || state.view !== 'box') return;
  try {
    const snap = await window.djGetDoc(
      window.djDoc(window.djFirebaseDb, 'parties', state.partyId),
    );
    if (!snap.exists()) return;
    state.party = snap.data();
    syncPartyOrderFields(state.party);
    lastWishListKey = '';
    renderWishes(true);
  } catch (err) {
    console.warn('[dj-browser] party order resync', err);
  }
}

function setupLiveSyncRecovery() {
  if (setupLiveSyncRecovery._ready) return;
  setupLiveSyncRecovery._ready = true;

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      reloadPartyOrderSyncFields();
    }
  });
  window.addEventListener('focus', () => {
    reloadPartyOrderSyncFields();
  });
  window.addEventListener('pageshow', (ev) => {
    if (ev.persisted) reloadPartyOrderSyncFields();
  });
}

function orderGroupedEntries(entries) {
  const wr = wishReorder();
  if (!wr || state.activeTab !== 'offen' || !entries.length) {
    return entries;
  }
  if (state.showOnlyFavorites) {
    return wr.applyDisplayOrder(entries.map((e) => e.groupKey), entries, state.pinnedKeys);
  }
  if (state.localOrderOverride) {
    return wr.applyDisplayOrder(state.localOrderOverride, entries, state.pinnedKeys);
  }
  return wr.buildServerDisplayOrder(entries, state.serverOrderKeys, state.pinnedKeys);
}

function getCurrentOrderKeysFromEntries(entries) {
  return orderGroupedEntries(entries).map((e) => e.groupKey);
}

async function beginWishReorder(groupKey, orderKeys) {
  state.reorderActive = true;
  state.localOrderOverride = orderKeys.slice();
  return true;
}

function cancelWishReorder() {
  state.reorderActive = false;
  state.localOrderOverride = null;
}

async function commitWishReorder(draggedKey, insertIndex) {
  const wr = wishReorder();
  if (!wr || !state.localOrderOverride) {
    cancelWishReorder();
    return;
  }

  let keys = wr.applyLocalInsertAt(state.localOrderOverride, draggedKey, insertIndex);
  keys = wr.orderWithPinsFirst(keys, state.pinnedKeys);
  const entries = groupedEntriesForTabRaw();
  keys = wr.storageKeysForGroupOrder(keys, entries);

  const ok = await wr.commitWishOrder(state, keys, getFirebaseHelpers());
  state.reorderActive = false;
  state.localOrderOverride = null;

  if (!ok) {
    showToast(t('dj_browser_reorder_save_error'), '#f44336');
    return;
  }

  state.serverOrderKeys = keys.slice();
  lastWishListKey = '';
  renderWishes(true);
}

function getFirebaseHelpers() {
  return {
    djFirebaseDb: window.djFirebaseDb,
    djDoc: window.djDoc,
    djRunTransaction: window.djRunTransaction,
    djDeleteField: window.djDeleteField,
    djServerTimestamp: window.djServerTimestamp,
  };
}

function setupWishReorder() {
  const wr = wishReorder();
  const root = document.getElementById('wish-list');
  if (!wr || !root) return;
  wr.setupWishListReorder(root, {
    isOffenTab: () => state.activeTab === 'offen',
    isFavoritesOnly: () => state.showOnlyFavorites === true,
    isPinned: (key) => isWishPinned(key),
    getOrderKeys: () => {
      const entries = groupedEntriesForTabRaw();
      return state.localOrderOverride || getCurrentOrderKeysFromEntries(entries);
    },
    getPinnedKeys: () => state.pinnedKeys,
    onDragStart: (groupKey, orderKeys) => beginWishReorder(groupKey, orderKeys),
    onDrop: (key, idx) => commitWishReorder(key, idx),
    onCancel: () => cancelWishReorder(),
  });
}

async function toggleWishPin(groupKey) {
  const key = String(groupKey || '').trim();
  if (!key || !state.partyId) {
    showToast(t('wish_anchor_update_error'), '#f44336');
    return;
  }
  if (typeof window.djRunTransaction !== 'function') {
    showToast(t('wish_anchor_update_error'), '#f44336');
    return;
  }

  const ref = window.djDoc(window.djFirebaseDb, 'parties', state.partyId);
  const entries = groupedEntriesForTabRaw();
  const wr = wishReorder();
  let result = 'failed';

  try {
    await window.djRunTransaction(window.djFirebaseDb, async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists()) {
        result = 'failed';
        return;
      }
      const data = snap.data() || {};
      const rawPins = parsePinnedKeys(data.open_wish_pinned_keys);
      let pinGroupKeys = wr
        ? wr.resolveStoredPinKeys(rawPins, entries)
        : rawPins.slice();

      if (pinGroupKeys.includes(key)) {
        pinGroupKeys = pinGroupKeys.filter((k) => k !== key);
        result = 'unpinned';
      } else if (pinGroupKeys.length >= MAX_PINNED_KEYS) {
        result = 'limitReached';
        return;
      } else {
        pinGroupKeys = [key, ...pinGroupKeys.filter((k) => k !== key)];
        result = 'pinned';
      }

      const storagePins = wr
        ? wr.storageKeysForGroupOrder(pinGroupKeys, entries)
        : pinGroupKeys;

      const update = {
        open_wish_pinned_keys: storagePins,
        open_wish_pinned_updated_at: window.djServerTimestamp(),
      };

      tx.update(ref, update);
    });
  } catch (err) {
    console.error('[dj-browser] toggle pin', err);
    result = 'failed';
  }

  if (result === 'limitReached') {
    showToast(t('wish_anchor_limit_snackbar'), '#ff8800');
  } else if (result === 'failed') {
    showToast(t('wish_anchor_update_error'), '#f44336');
  } else {
    if (result === 'pinned') {
      state.pinnedKeys = [key, ...state.pinnedKeys.filter((k) => k !== key)];
    } else if (result === 'unpinned') {
      state.pinnedKeys = state.pinnedKeys.filter((k) => k !== key);
    }
    lastWishListKey = '';
    renderWishes(true);
    if (result === 'pinned') {
      const root = document.getElementById('wish-list');
      if (root) root.scrollTop = 0;
    }
  }
}

function dedupeKey(title, artist) {
  return `${normalizeText(title)}|${normalizeText(artist)}`;
}

function isTrackSaved(wish) {
  const title = wish.title || wish.song_title || '';
  const artist = wish.artist || wish.song_artist || '';
  return state.savedTrackKeys.has(dedupeKey(title, artist));
}


function tsToDate(ts) {
  if (!ts) return null;
  if (typeof ts.toDate === 'function') return ts.toDate();
  if (typeof ts.seconds === 'number') return new Date(ts.seconds * 1000);
  if (typeof ts._seconds === 'number') return new Date(ts._seconds * 1000);
  if (ts instanceof Date) return ts;
  return null;
}


function formatWaitParensLive(fromDate) {
  const elapsed = formatOpenWaitElapsed(fromDate);
  return elapsed ? ` (${elapsed})` : '';
}

function formatWaitParensMinutes(fromDate, toDate) {
  const mins = elapsedCalendarMinutes(fromDate, toDate);
  if (mins <= 0) return '';
  return ` (${mins} ${t('minutes_short')})`;
}

function formatPlayedStatusTimeLine(entry, submittedOpt) {
  const submitted = submittedOpt || resolveOldestWishDate(entry);
  const wish = entry.wish || {};
  const played = resolveWishStatusDate(wish, [
    'played_at',
    'playedAt',
    'recognized_at',
    'status_changed_at',
  ]);
  if (!played) return escapeHtml(formatWishDateTimeLine(submitted));
  const waitPart = formatWaitParensMinutes(submitted, played);
  const sameDay = submitted.toDateString() === played.toDateString();
  const left = formatWishDateTimeLine(submitted);
  const right = (sameDay ? formatClockWithSuffix(played) : formatWishDateTimeLine(played)) + waitPart;
  return `${escapeHtml(left)} – <span class="wish-time-accent played">${escapeHtml(right)}</span>`;
}

function formatRejectedStatusTimeLine(entry, submittedOpt) {
  const submitted = submittedOpt || resolveOldestWishDate(entry);
  const wish = entry.wish || {};
  const rejected = resolveWishStatusDate(wish, [
    'rejected_at',
    'rejectedAt',
    'status_changed_at',
  ]);
  if (!rejected) return escapeHtml(formatWishDateTimeLine(submitted));
  const waitPart = formatWaitParensMinutes(submitted, rejected);
  const sameDay = submitted.toDateString() === rejected.toDateString();
  const left = formatWishDateTimeLine(submitted);
  const right = (sameDay ? formatClockWithSuffix(rejected) : formatWishDateTimeLine(rejected)) + waitPart;
  return `${escapeHtml(left)} – <span class="wish-time-accent rejected">${escapeHtml(right)}</span>`;
}

function resolveWishStatusDate(wish, fieldNames) {
  for (const field of fieldNames) {
    const date = tsToDate(wish[field]);
    if (date) return date;
  }
  return null;
}

function elapsedCalendarMinutes(from, to) {
  const start = new Date(
    from.getFullYear(),
    from.getMonth(),
    from.getDate(),
    from.getHours(),
    from.getMinutes(),
  );
  const end = new Date(
    to.getFullYear(),
    to.getMonth(),
    to.getDate(),
    to.getHours(),
    to.getMinutes(),
  );
  return Math.max(0, Math.floor((end.getTime() - start.getTime()) / 60000));
}

function formatOpenWaitElapsed(wishDate) {
  const elapsed = elapsedCalendarMinutes(wishDate, new Date());
  if (elapsed <= 0) return t('history_time_just_now');
  if (elapsed < 60) {
    return t('wish_since_minutes').replace('{min}', String(elapsed));
  }
  return t('wish_since_hours_minutes')
    .replace('{hours}', String(Math.floor(elapsed / 60)))
    .replace('{min}', String(elapsed % 60));
}

function resolveOldestWishDate(entry) {
  const group = entry.group || {};
  const wish = entry.wish || {};
  const ts = group.oldest_createdAt || group.createdAt || wish.createdAt || wish.created_at;
  return tsToDate(ts) || new Date(0);
}

let waitTimeTimer = null;

function updateOpenWaitTimes() {
  if (state.activeTab !== 'offen') return;
  document.querySelectorAll('.wish-wisher-time[data-wait-from]').forEach((el) => {
    const iso = el.getAttribute('data-wait-from');
    const waitEl = el.querySelector('.wish-wait-paren');
    if (!iso || !waitEl) return;
    const from = new Date(iso);
    if (Number.isNaN(from.getTime())) return;
    waitEl.textContent = formatWaitParensLive(from);
  });
}

function startWaitTimeTicker() {
  updateOpenWaitTimes();
  if (waitTimeTimer) return;
  waitTimeTimer = setInterval(updateOpenWaitTimes, 60000);
}

function stopWaitTimeTicker() {
  if (waitTimeTimer) {
    clearInterval(waitTimeTimer);
    waitTimeTimer = null;
  }
}

function formatPartyEndLine(party, graceMinutes) {
  const end = partyEndDate(party);
  const label = t('party_end_label');
  if (!end) {
    return `${label} ${t('party_running_still')}`;
  }
  const endFormatted = `${formatLocaleDateYmd(end)} ${t('party_time_at')} ${formatClockWithSuffix(end)}`;
  const now = Date.now();
  if (now >= end.getTime() && shouldShowOpenWishes(party, graceMinutes ?? 0)) {
    return `${t('party_status_grace_period')} · ${label} ${endFormatted}`;
  }
  return `${label} ${endFormatted}`;
}

function formatGraceCountdownLine(graceMinutes) {
  const end = partyEndDate(state.party);
  if (!end || !shouldShowOpenWishes(state.party, graceMinutes)) return null;
  const now = Date.now();
  const endMs = end.getTime();
  if (now < endMs) return null;
  const remainingSec = Math.max(
    0,
    Math.floor((endMs + Math.max(0, graceMinutes) * 60 * 1000 - now) / 1000),
  );
  if (remainingSec <= 0) return null;
  const prefix = t('party_grace_countdown_wishes_still');
  if (remainingSec <= 60) {
    return `${prefix} ${remainingSec}s`;
  }
  const totalMinutes = Math.floor((remainingSec + 59) / 60);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  const hourStr = hours === 1 ? t('party_hour') : t('party_hours');
  const minuteStr = minutes === 1 ? t('party_minute') : t('party_minutes');
  if (hours === 0) {
    return `${prefix} ${minutes} ${minuteStr}`;
  }
  if (minutes === 0) {
    return `${prefix} ${hours} ${hourStr}`;
  }
  return `${prefix} ${hours} ${hourStr} ${minutes} ${minuteStr}`;
}

let graceCountdownTimerId = null;
let graceExpiredHandling = false;

function clearGraceCountdownTimer() {
  if (graceCountdownTimerId != null) {
    clearInterval(graceCountdownTimerId);
    graceCountdownTimerId = null;
  }
}

/** Nachlaufzeit vorbei — abmelden und Seite neu laden (Login-Ansicht). */
async function handleGracePeriodExpired() {
  if (graceExpiredHandling) return;
  graceExpiredHandling = true;
  clearGraceCountdownTimer();
  cleanupListeners();
  try {
    await window.djSignOut(window.djFirebaseAuth);
  } catch (e) { /* ignore */ }
  window.location.replace('/dj');
}

function scheduleGraceCountdownTimer() {
  clearGraceCountdownTimer();
  if (state.view !== 'box' || !state.party) return;
  const end = partyEndDate(state.party);
  if (!end || !state.ownerGraceMinutes) return;
  const graceEndMs = end.getTime() + state.ownerGraceMinutes * 60 * 1000;
  if (Date.now() >= graceEndMs) {
    if (isPartyClosed(state.party, state.ownerGraceMinutes)) {
      void handleGracePeriodExpired();
    }
    return;
  }
  // Läuft ab jetzt bis Nachlaufzeit-Ende — auch vor regulärem Party-Ende,
  // damit die Anzeige beim Übergang automatisch umschaltet.
  graceCountdownTimerId = setInterval(() => {
    if (state.view !== 'box' || !state.party) {
      clearGraceCountdownTimer();
      return;
    }
    updatePartyHeader();
    if (Date.now() >= graceEndMs) {
      clearGraceCountdownTimer();
      if (isPartyClosed(state.party, state.ownerGraceMinutes)) {
        void handleGracePeriodExpired();
      }
    }
  }, 1000);
}

function updatePartyHeader() {
  const titleEl = document.getElementById('party-title');
  const endEl = document.getElementById('party-end-line');
  const graceEl = document.getElementById('party-grace-line');
  if (!state.party || !titleEl || !endEl) return;
  titleEl.textContent = state.party.party_name || state.party.name || 'VibesBox';
  endEl.textContent = formatPartyEndLine(state.party, state.ownerGraceMinutes);
  const graceLine = formatGraceCountdownLine(state.ownerGraceMinutes);
  if (graceEl) {
    if (graceLine) {
      graceEl.textContent = graceLine;
      graceEl.hidden = false;
    } else {
      graceEl.textContent = '';
      graceEl.hidden = true;
    }
  }
  scheduleGraceCountdownTimer();
}

function showToast(message, color) {
  let el = document.getElementById('dj-toast');
  if (!el) {
    el = document.createElement('div');
    el.id = 'dj-toast';
    el.className = 'dj-toast';
    document.body.appendChild(el);
  }
  el.textContent = message;
  el.style.background = color || '#333';
  el.hidden = false;
  clearTimeout(showToast._timer);
  showToast._timer = setTimeout(() => {
    el.hidden = true;
  }, 2600);
}

let confirmDialogPromise = null;

function showDjConfirm(message, options = {}) {
  if (confirmDialogPromise) return confirmDialogPromise;

  const overlay = document.getElementById('dj-confirm-overlay');
  const dialog = document.getElementById('dj-confirm-dialog');
  const textEl = document.getElementById('dj-confirm-text');
  const trackEl = document.getElementById('dj-confirm-track');
  const trackTitleEl = document.getElementById('dj-confirm-track-title');
  const trackArtistEl = document.getElementById('dj-confirm-track-artist');
  const cancelBtn = document.getElementById('dj-confirm-cancel');
  const okBtn = document.getElementById('dj-confirm-ok');
  if (!overlay || !dialog || !textEl || !cancelBtn || !okBtn) {
    return Promise.resolve(window.confirm(String(message || '')));
  }

  textEl.textContent = String(message || '');
  const title = String(options.title || '').trim();
  const artist = String(options.artist || '').trim();
  if (trackEl && trackTitleEl && trackArtistEl && (title || artist)) {
    trackTitleEl.textContent = title || '—';
    trackArtistEl.textContent = artist;
    trackArtistEl.hidden = !artist;
    trackEl.hidden = false;
  } else if (trackEl) {
    trackEl.hidden = true;
    if (trackTitleEl) trackTitleEl.textContent = '';
    if (trackArtistEl) trackArtistEl.textContent = '';
  }
  cancelBtn.textContent = options.cancelLabel || t('dj_browser_confirm_cancel');
  okBtn.textContent = options.confirmLabel || t('dj_browser_confirm_ok');
  okBtn.className = 'dj-confirm-btn dj-confirm-btn-ok';
  if (options.variant) {
    okBtn.classList.add(`dj-confirm-btn-${options.variant}`);
  }

  overlay.hidden = false;
  document.body.classList.add('dj-confirm-open');

  confirmDialogPromise = new Promise((resolve) => {
    const cleanup = (result) => {
      overlay.hidden = true;
      document.body.classList.remove('dj-confirm-open');
      cancelBtn.removeEventListener('click', onCancel);
      okBtn.removeEventListener('click', onOk);
      overlay.removeEventListener('click', onOverlay);
      dialog.removeEventListener('click', stopPropagation);
      document.removeEventListener('keydown', onKey);
      confirmDialogPromise = null;
      resolve(result);
    };
    const onCancel = () => cleanup(false);
    const onOk = () => cleanup(true);
    const onOverlay = (ev) => {
      if (ev.target === overlay) onCancel();
    };
    const stopPropagation = (ev) => ev.stopPropagation();
    const onKey = (ev) => {
      if (ev.key === 'Escape') onCancel();
    };
    cancelBtn.addEventListener('click', onCancel);
    okBtn.addEventListener('click', onOk);
    overlay.addEventListener('click', onOverlay);
    dialog.addEventListener('click', stopPropagation);
    document.addEventListener('keydown', onKey);
    cancelBtn.focus();
  });

  return confirmDialogPromise;
}

async function loadSavedTracks() {
  try {
    const listFn = window.djHttpsCallable('manageSavedTrack');
    const result = await listFn({ action: 'list' });
    const tracks = (result.data && result.data.tracks) || [];
    state.savedTrackKeys = new Set(
      tracks.map((track) => dedupeKey(track.title, track.artist)),
    );
  } catch (e) {
    console.error('[dj-browser] saved tracks', e);
    state.savedTrackKeys = new Set();
  }
}

function getDeviceId() {
  try {
    let id = localStorage.getItem(STORAGE_DEVICE);
    if (!id) {
      id = crypto.randomUUID();
      localStorage.setItem(STORAGE_DEVICE, id);
    }
    return id;
  } catch (e) {
    return crypto.randomUUID();
  }
}

function showView(name) {
  state.view = name;
  document.body.classList.toggle('dj-box-active', name === 'box');
  const bootEl = document.getElementById('view-boot');
  if (bootEl) bootEl.hidden = name !== 'boot';
  document.getElementById('view-login').hidden = name !== 'login';
  document.getElementById('view-message').hidden = name !== 'message';
  document.getElementById('view-box').hidden = name !== 'box';
  updateTopBarControls();
  updateOffenBlacklistChip();
  if (window.DjManualWish) window.DjManualWish.updateAddButtonVisibility();
  if (name === 'box') {
    scrollAppToTop();
    requestAnimationFrame(scrollAppToTop);
  }
}

function setBootLoadingText() {
  const el = document.getElementById('boot-loading-text');
  if (el) el.textContent = t('dj_browser_loading');
}

function showMessage(text) {
  document.getElementById('message-text').textContent = text;
  showView('message');
}

function cleanupListeners() {
  stopWaitTimeTicker();
  clearGraceCountdownTimer();
  state.unsubscribers.forEach((fn) => {
    try { fn(); } catch (e) { /* ignore */ }
  });
  state.unsubscribers = [];
  if (pingTimerId != null) {
    clearInterval(pingTimerId);
    pingTimerId = null;
  }
}

function parsePartyDate(raw) {
  if (raw == null) return null;
  if (raw instanceof Date) {
    return Number.isNaN(raw.getTime()) ? null : raw;
  }
  if (typeof raw.toDate === 'function') {
    const d = raw.toDate();
    return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
  }
  if (typeof raw === 'object') {
    const sec = raw.seconds ?? raw._seconds;
    if (sec != null) {
      const ms = Number(sec) * 1000
        + Number(raw.nanoseconds ?? raw._nanoseconds ?? 0) / 1e6;
      const d = new Date(ms);
      return Number.isNaN(d.getTime()) ? null : d;
    }
  }
  if (typeof raw === 'number') {
    const d = raw > 1e12 ? new Date(raw) : new Date(raw * 1000);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof raw === 'string') {
    const d = new Date(raw);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/** Spätestes Ende — end_date, end_time_posix und finished_at können auseinanderlaufen. */
function partyEffectiveEndDate(party) {
  if (!party) return null;
  const candidates = [];
  const fromEnd = parsePartyDate(party.end_date ?? party.endDate);
  if (fromEnd) candidates.push(fromEnd);
  const posix = party.end_time_posix;
  if (posix != null && !Number.isNaN(Number(posix))) {
    candidates.push(new Date(Number(posix) * 1000));
  }
  const finished = parsePartyDate(party.finished_at);
  if (finished) candidates.push(finished);
  if (candidates.length === 0) return null;
  return new Date(Math.max(...candidates.map((d) => d.getTime())));
}

function partyEndDate(party) {
  return partyEffectiveEndDate(party);
}

/** Wie Flutter ActivePartyService — Party läuft noch im Posix-Fenster. */
function isPartyRunningByPosixWindow(party, nowMs = Date.now()) {
  if (!party) return false;
  if (party.lifecycle_status === 'finished' || party.finished_at) return false;
  if (party.lifecycle_status === 'standby') return false;
  const startPosix = party.start_time_posix;
  const endPosix = party.end_time_posix;
  if (startPosix == null || endPosix == null) return false;
  const start = Number(startPosix);
  const end = Number(endPosix);
  if (Number.isNaN(start) || Number.isNaN(end)) return false;
  const nowUnix = Math.floor(nowMs / 1000);
  return nowUnix >= start && nowUnix < end;
}

function wishesManuallyHidden(party) {
  return party?.wishes_manually_hidden === true;
}

function isWithinGracePeriod(nowMs, endMs, graceMinutes) {
  const grace = Math.max(0, Number(graceMinutes || 0));
  if (grace <= 0) return false;
  return nowMs < endMs + grace * 60 * 1000;
}

/** Wie Flutter PartyGracePeriodHelper.shouldShowOpenWishes — Nachlaufzeit zählt mit. */
function shouldShowOpenWishes(party, graceMinutes, nowMs = Date.now()) {
  if (isPartyRunningByPosixWindow(party, nowMs)) return true;
  const end = partyEffectiveEndDate(party);
  if (!end) return false;
  if (wishesManuallyHidden(party)) return false;
  const endMs = end.getTime();
  if (nowMs < endMs) return true;
  return isWithinGracePeriod(nowMs, endMs, graceMinutes);
}

function isPartyClosed(party, graceMinutes) {
  if (!party) return true;
  if (wishesManuallyHidden(party)) return true;
  if (isPartyRunningByPosixWindow(party)) return false;
  const end = partyEffectiveEndDate(party);
  if (!end) {
    if (party.lifecycle_status === 'finished' || party.finished_at) return true;
    const status = String(party.status || '').toLowerCase();
    return status === 'beendet' || status === 'ended';
  }
  return !shouldShowOpenWishes(party, graceMinutes);
}

async function endSession(reasonKey) {
  cleanupListeners();
  state.partyId = null;
  state.sessionId = null;
  state.ownerUid = null;
  state.party = null;
  state.ownerGraceMinutes = 0;
  state.graceMinutesFromServer = false;
  state.wishes = [];
  state.savedTrackKeys = new Set();
  state.blacklistEnabled = true;
  state.blacklistSongCount = 0;
  state._blacklistWatchUid = null;
  lastWishListKey = '';
  lastWishListTab = '';
  updateOffenBlacklistChip();
  try {
    await window.djSignOut(window.djFirebaseAuth);
  } catch (e) { /* ignore */ }
  showMessage(t(reasonKey));
}

function waitForAuthReady() {
  return new Promise((resolve) => {
    if (!window.djFirebaseAuth) {
      resolve(null);
      return;
    }
    const unsub = window.djOnAuthStateChanged(window.djFirebaseAuth, (user) => {
      unsub();
      resolve(user);
    });
  });
}

async function restoreDjSession(user) {
  const tokenResult = await user.getIdTokenResult();
  const claims = tokenResult.claims || {};
  if (claims.role !== 'dj_browser') return false;
  const partyId = String(claims.partyId || '').trim();
  const sessionId = String(claims.sessionId || '').trim();
  if (!partyId || !sessionId) return false;

  const sessionSnap = await window.djGetDoc(
    window.djDoc(window.djFirebaseDb, 'dj_browser_sessions', sessionId),
  );
  if (!sessionSnap.exists() || sessionSnap.data()?.active !== true) return false;
  if (String(sessionSnap.data()?.partyId || '').trim() !== partyId) return false;

  const sessionData = sessionSnap.data() || {};
  const graceFromSession = parseGraceMinutesValue(sessionData.ownerGraceMinutes);
  await afterLogin(partyId, sessionId, claims.ownerUid, {
    ownerGraceMinutes: graceFromSession,
    graceMinutesFromServer: graceFromSession != null,
  });
  return true;
}

function wishMatchesTab(wish, tab) {
  const status = String(wish.status || 'pending');
  const isPre = wish.is_pre_wish === true;
  const published = wish.pre_wish_published === true;
  if (tab === 'vorab') {
    return status === 'pending' && isPre && !published;
  }
  if (tab === 'offen') {
    return status === 'pending' && (!isPre || published);
  }
  if (tab === 'gespielt') return status === 'played';
  if (tab === 'abgelehnt') return status === 'rejected';
  return false;
}

let lastTabsKey = '';
let lastWishListKey = '';
let lastWishListTab = '';

function isDjDocumentRtl() {
  if (typeof window.djIsRtlLocale === 'function') {
    return window.djIsRtlLocale(readActiveDjLangCode());
  }
  return document.documentElement.getAttribute('dir') === 'rtl';
}

function hasQueuedPreWishes() {
  return state.wishes.some((w) => wishMatchesTab(w, 'vorab'));
}

function hasSetlistTracks() {
  return Array.isArray(state.setlistTracksRaw) && state.setlistTracksRaw.length > 0;
}

function syncHiddenTabs() {
  if (state.activeTab === 'vorab' && !hasQueuedPreWishes()) {
    state.activeTab = 'offen';
    state.showOnlyFavorites = false;
  }
  if (state.activeTab === 'setlist' && !hasSetlistTracks()) {
    state.activeTab = 'offen';
    state.showOnlyFavorites = false;
  }
}

function tabsLayoutKey() {
  return [
    state.activeTab,
    state.showOnlyFavorites ? '1' : '0',
    hasQueuedPreWishes() ? '1' : '0',
    hasSetlistTracks() ? '1' : '0',
    window.djBrowserLocale || 'en',
  ].join('|');
}

function updateFavoritesHeader() {
  const header = document.getElementById('favorites-view-header');
  const tabBar = document.getElementById('tab-bar');
  if (!header || !tabBar) return;
  const show = state.view === 'box' && state.showOnlyFavorites;
  header.hidden = !show;
  tabBar.hidden = show;
  if (!show) return;
  const titleEl = document.getElementById('favorites-view-title');
  const backEl = document.getElementById('favorites-view-back');
  if (titleEl) titleEl.textContent = t('favorites_page_title');
  if (backEl) backEl.textContent = t('back');
}

let favoritesHeaderSetup = false;

function setupFavoritesHeader() {
  if (favoritesHeaderSetup) return;
  favoritesHeaderSetup = true;
  const backEl = document.getElementById('favorites-view-back');
  if (!backEl) return;
  backEl.addEventListener('click', () => {
    if (!state.showOnlyFavorites) return;
    state.showOnlyFavorites = false;
    resetWishListPage();
    updateFavoritesHeader();
    updateTopBarControls();
    renderTabs(true);
    renderWishes(true);
  });
}

function renderTabs(force) {
  syncHiddenTabs();
  const key = tabsLayoutKey();
  const bar = document.getElementById('tab-bar');
  const tabDir = isDjDocumentRtl() ? 'rtl' : 'ltr';
  if (bar) bar.setAttribute('dir', tabDir);
  if (!force && key === lastTabsKey && bar.childElementCount > 0) {
    bar.querySelectorAll('.tab-btn').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.tab === state.activeTab);
    });
    updateOffenBlacklistChip();
    return;
  }
  lastTabsKey = key;
  bar.innerHTML = '';
  const tabs = [];
  if (hasSetlistTracks()) {
    tabs.push({ id: 'setlist', label: t('dj_setlist_tab') });
  }
  if (hasQueuedPreWishes()) {
    tabs.push({ id: 'vorab', label: t('dj_browser_tab_vorab') });
  }
  tabs.push(
    { id: 'offen', label: t('dj_browser_tab_offen') },
    { id: 'gespielt', label: t('dj_browser_tab_gespielt') },
    { id: 'abgelehnt', label: t('dj_browser_tab_abgelehnt') },
  );
  if (!tabs.some((x) => x.id === state.activeTab)) {
    state.activeTab = tabs[0].id;
  }
  tabs.forEach((tab) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.dataset.tab = tab.id;
    btn.className = 'tab-btn' + (state.activeTab === tab.id ? ' active' : '');
    btn.textContent = tab.label;
    btn.addEventListener('click', () => {
      if (state.activeTab === tab.id) return;
      state.activeTab = tab.id;
      state.showOnlyFavorites = false;
      resetWishListPage();
      renderTabs(true);
      updateFavoritesHeader();
      updateTopBarControls();
      renderWishes(true);
    });
    bar.appendChild(btn);
  });
  updateFavoritesHeader();
  updateTopBarControls();
  updateOffenBlacklistChip();
  if (window.DjManualWish) window.DjManualWish.updateAddButtonVisibility();
}

function hasOpenFavoriteWishes() {
  return state.wishes.some((w) => wishMatchesTab(w, 'offen') && w.is_favorite === true);
}

function updateTopBarControls() {
  const btn = document.getElementById('dj-favorites-filter');
  if (!btn) return;
  const showOnOffen = state.view === 'box' && state.activeTab === 'offen';
  btn.hidden = !showOnOffen;
  if (!showOnOffen) return;
  const hasFavs = hasOpenFavoriteWishes();
  btn.classList.toggle('active', state.showOnlyFavorites);
  btn.classList.toggle('has-favorites', hasFavs);
  btn.title = state.showOnlyFavorites
    ? `${t('favorites_page_title')} (${t('dj_browser_tab_offen')})`
    : t('favorites_page_title');
  btn.setAttribute('aria-label', btn.title);
  btn.innerHTML = iconHeartSvg();
}

let topBarControlsSetup = false;

function setupTopBarControls() {
  if (topBarControlsSetup) return;
  topBarControlsSetup = true;
  const btn = document.getElementById('dj-favorites-filter');
  if (!btn) return;
  btn.addEventListener('click', () => {
    if (state.activeTab !== 'offen') return;
    state.showOnlyFavorites = !state.showOnlyFavorites;
    resetWishListPage();
    lastWishListKey = '';
    updateFavoritesHeader();
    updateTopBarControls();
    renderTabs(true);
    renderWishes(true);
  });
}

function groupedEntriesForTabRaw() {
  const wg = wishGrouping();
  if (!wg) {
    return filteredWishesForTab().map((wish) => ({
      groupKey: String(wish.id),
      docIds: [String(wish.id)],
      primaryId: String(wish.id),
      group: {
        title: wish.title || wish.song_title || '',
        artist: wish.artist || wish.song_artist || '',
        is_favorite: wish.is_favorite === true,
        requested_by: [wish.display_name || wish.guest_name || wish.name || ''],
        greetings: [],
        createdAt: wish.createdAt || wish.created_at,
        createdAt_list: [wish.createdAt || wish.created_at],
        wish_total_count: 1,
      },
      sortMs: 0,
      wish: wish,
    }));
  }

  const tabMatches = state.wishes.filter((w) => wishMatchesTab(w, state.activeTab));
  const primary = wg.withoutDuplicateShadowDocuments(tabMatches);
  let primaryFiltered = primary;
  if (state.activeTab === 'offen' && state.showOnlyFavorites) {
    primaryFiltered = primary.filter((w) => w.is_favorite === true);
  }
  primaryFiltered.sort((a, b) => {
    const ta = a.createdAt?.toMillis?.() || a.created_at?.toMillis?.() || 0;
    const tb = b.createdAt?.toMillis?.() || b.created_at?.toMillis?.() || 0;
    return tb - ta;
  });

  // Shadows behalten status "pending" — für Zeiten ALLE Party-Wünsche nutzen,
  // nicht nur den aktuellen Tab (sonst fehlen Zeiten in Gespielt/Abgelehnt).
  const grouped = wg.groupWishesForDisplay(
    primaryFiltered,
    state.wishes,
    state.partyId,
    state.ignoredKeywords || wg.IGNORED_KEYWORDS_DEFAULT,
  );

  return grouped.map((entry) => ({
    ...entry,
    wish: state.wishes.find((w) => String(w.id) === String(entry.primaryId)) || {
      id: entry.primaryId,
      ...entry.group,
    },
  }));
}

function groupedEntriesForTab() {
  return orderGroupedEntries(groupedEntriesForTabRaw());
}

function wishCardRenderKey(entry) {
  const group = entry.group || {};
  const docIds = (entry.docIds || []).join(',');
  return [
    entry.groupKey,
    docIds,
    group.is_favorite === true ? '1' : '0',
    group.auto_recognized === true ? '1' : '0',
    isTrackSaved(entry.wish || group) ? '1' : '0',
    group.title || '',
    group.artist || '',
    (group.requested_by || []).join('|'),
    (group.createdAt_list || []).map((ts) => {
      const d = tsToDate(ts);
      return d ? String(d.getTime()) : '';
    }).join(','),
    (group.greetings || []).map((g) => `${g.name}:${g.greeting}`).join('|'),
    state.activeTab,
    state.showOnlyFavorites ? '1' : '0',
    state.showGreetingTranslations ? '1' : '0',
    isWishPinned(entry.groupKey) ? '1' : '0',
    state.pinnedKeys.join(','),
    entryHasBlockedGuest(entry) ? '1' : '0',
    djLang(),
  ].join('\u001f');
}

function filteredWishesForTab() {
  let list = state.wishes.filter((w) => wishMatchesTab(w, state.activeTab));
  if (state.activeTab === 'offen' && state.showOnlyFavorites) {
    list = list.filter((w) => w.is_favorite === true);
  }
  return list;
}

function setlistTracksFromDoc(data) {
  const raw = Array.isArray(data && data.tracks) ? data.tracks : [];
  state.setlistTracksRaw = raw;
  const out = [];
  raw.forEach((item, index) => {
    if (!item || typeof item !== 'object') return;
    if (item.moved === true) return;
    const title = String(item.title || '').trim();
    const artist = String(item.artist || '').trim();
    if (!title || !artist) return;
    const i18n = item.reason_i18n && typeof item.reason_i18n === 'object'
      ? item.reason_i18n
      : {};
    out.push({
      title,
      artist,
      reason: String(item.reason || ''),
      reason_i18n: i18n,
      duration: item.duration,
      genre: item.genre,
      bpm: item.bpm,
      camelot: item.camelot,
      raw: item,
      index,
    });
  });
  return out;
}

function setlistReasonText(track) {
  const code = String(djLang() || 'de').split('-')[0];
  const localized = String((track.reason_i18n && track.reason_i18n[code]) || '').trim();
  if (localized) return localized;
  return String(track.reason || '').trim();
}

function setlistMixMeta(track) {
  const parts = [];
  const duration = String(track.duration || '').trim();
  if (duration) parts.push(duration);
  const bpm = Number(track.bpm);
  if (Number.isFinite(bpm) && bpm >= 60 && bpm <= 220) parts.push(`${Math.round(bpm)} BPM`);
  const genre = String(track.genre || '').trim();
  if (genre) parts.push(genre);
  const camelot = String(track.camelot || '').trim();
  if (camelot) parts.push(camelot);
  return parts.join('  ·  ');
}

function persistSetlistRawTracks(rawTracks) {
  return window.djUpdateDoc(
    window.djDoc(window.djFirebaseDb, 'dj_setlists', state.partyId),
    {
      tracks: rawTracks,
      targetCount: rawTracks.length,
      updatedAt: window.djServerTimestamp(),
    },
  );
}

function remainingSetlistRaw(removeIndex) {
  return (state.setlistTracksRaw || []).filter((_, i) => i !== removeIndex);
}

function markSetlistMovedRaw(index) {
  return (state.setlistTracksRaw || []).map((item, i) => {
    if (i !== index) return item;
    return { ...(item && typeof item === 'object' ? item : {}), moved: true };
  });
}

async function syncSetlistLibrary() {
  try {
    const fn = window.djHttpsCallable('djBrowserSyncSetlistLibrary');
    await fn({});
  } catch (err) {
    console.warn('[dj-browser] setlist library sync', err);
  }
}

async function createSetlistWish(track, markPlayed) {
  const createManual = window.djHttpsCallable('createDjBrowserManualWish');
  await createManual({
    title: track.title,
    artist: track.artist,
    greeting: '',
    spotifyId: '',
    fromSetlist: true,
    markPlayed: !!markPlayed,
  });
}

async function onSetlistAction(btn, action) {
  if (action === 'setlist-select') {
    const idx = Number(btn.getAttribute('data-index'));
    if (!Number.isFinite(idx)) return;
    state.setlistSelectedIndex = state.setlistSelectedIndex === idx ? null : idx;
    if (state.setlistSelectedIndex != null) {
      setlistActionsArmedAt = Date.now() + SETLIST_ACTIONS_ARM_MS;
    }
    lastWishListKey = '';
    renderSetlistList(true);
    return;
  }
  if (Date.now() < setlistActionsArmedAt) return;
  if (state.setlistBusy) return;
  const index = Number(btn.getAttribute('data-index'));
  const track = state.setlistTracks.find((tr) => tr.index === index);
  if (!track) return;

  if (action === 'setlist-delete') {
    const ok = await showDjConfirm(
    t('dj_setlist_delete_track_body_saved', { title: track.title, artist: track.artist }),
      {
        variant: 'delete',
        title: track.title,
        artist: track.artist,
        confirmLabel: t('dj_browser_action_delete'),
      },
    );
    if (!ok) return;
  } else if (action === 'setlist-open') {
    const ok = await showDjConfirm(
      t('dj_setlist_move_to_open_body', { title: track.title, artist: track.artist }),
      {
        title: track.title,
        artist: track.artist,
        confirmLabel: t('dj_setlist_move_to_open'),
      },
    );
    if (!ok) return;
  } else if (action === 'setlist-play') {
    const ok = await showDjConfirm(
      t('dj_setlist_mark_played_body', { title: track.title, artist: track.artist }),
      {
        title: track.title,
        artist: track.artist,
        confirmLabel: t('dj_setlist_mark_played_title'),
      },
    );
    if (!ok) return;
  }

  state.setlistBusy = true;
  try {
    if (action === 'setlist-open') {
      await createSetlistWish(track, false);
      await persistSetlistRawTracks(markSetlistMovedRaw(index));
      showToast(t('dj_setlist_moved_to_open'), '#4caf50');
    } else if (action === 'setlist-play') {
      await createSetlistWish(track, true);
      await persistSetlistRawTracks(markSetlistMovedRaw(index));
      showToast(t('dj_setlist_marked_played'), '#4caf50');
    } else if (action === 'setlist-delete') {
      await persistSetlistRawTracks(remainingSetlistRaw(index));
      await syncSetlistLibrary();
      showToast(t('dj_setlist_track_deleted'), '#4caf50');
    }
    state.setlistSelectedIndex = null;
  } catch (err) {
    console.error('[dj-browser] setlist action', err);
    showToast(
      t('dj_setlist_action_failed', { error: err?.message || String(err) }),
      '#f44336',
    );
  } finally {
    state.setlistBusy = false;
  }
}

function renderSetlistList(force) {
  const root = document.getElementById('wish-list');
  if (!root) return;
  lastWishListTab = 'setlist';
  const tracks = state.setlistTracks;
  if (!tracks.length) {
    renderPaginationBar(0);
    root.replaceChildren();
    const empty = document.createElement('p');
    empty.className = 'wish-empty';
    empty.textContent = t('dj_setlist_empty_party');
    root.appendChild(empty);
    lastWishListKey = 'setlist-empty';
    return;
  }
  const totalPages = calculateTotalPages(
    tracks.length,
    state.resultsPerPage || DJ_DEFAULT_RESULTS_PER_PAGE,
  );
  if (state.currentPage > totalPages) state.currentPage = totalPages || 1;
  const pageItems = getItemsForPage(
    tracks,
    state.currentPage,
    state.resultsPerPage,
  );
  renderPaginationBar(tracks.length);
  const listKey = `setlist|${state.currentPage}|${tracks.map((tr) => `${tr.index}:${tr.title}|${tr.artist}`).join('\u001e')}|${state.setlistSelectedIndex}|${djLang()}`;
  if (!force && listKey === lastWishListKey) return;
  lastWishListKey = listKey;
  const busy = state.setlistBusy ? ' is-busy' : '';
  root.replaceChildren();
  pageItems.forEach((track, i) => {
    const selected = state.setlistSelectedIndex === track.index;
    const reason = setlistReasonText(track);
    const meta = setlistMixMeta(track);
    const perPage = state.resultsPerPage || DJ_DEFAULT_RESULTS_PER_PAGE;
    const number = (Math.max(1, state.currentPage) - 1) * perPage + i + 1;
    const wrap = document.createElement('div');
    wrap.innerHTML = `
      <article class="wish-card setlist${selected ? ' is-selected' : ''}${busy}" data-action="setlist-select" data-index="${track.index}">
        <div class="wish-badge-row">
          <div class="wish-music-block">
            <div class="wish-title-row">
              <h2 class="wish-title">${number}. ${escapeHtml(track.title)} – ${escapeHtml(track.artist)}</h2>
            </div>
            ${meta ? `<p class="setlist-meta">${escapeHtml(meta)}</p>` : ''}
            ${reason ? `<p class="setlist-reason">${escapeHtml(reason)}</p>` : ''}
          </div>
        </div>
        ${selected ? `
        <div class="setlist-actions">
          <button type="button" class="icon-btn setlist-act-open" data-action="setlist-open" data-index="${track.index}" title="${escapeHtml(t('dj_setlist_move_to_open'))}" aria-label="${escapeHtml(t('dj_setlist_move_to_open'))}">${iconQueueSvg()}</button>
          <button type="button" class="icon-btn setlist-act-play" data-action="setlist-play" data-index="${track.index}" title="${escapeHtml(t('dj_browser_action_play'))}" aria-label="${escapeHtml(t('dj_browser_action_play'))}">${iconCheckSvg()}</button>
          <button type="button" class="icon-btn setlist-act-delete" data-action="setlist-delete" data-index="${track.index}" title="${escapeHtml(t('dj_browser_action_delete'))}" aria-label="${escapeHtml(t('dj_browser_action_delete'))}">${iconTrashSvg()}</button>
        </div>` : ''}
      </article>`;
    root.appendChild(wrap.firstElementChild);
  });
}

function iconQueueSvg() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v2H3v-2zm19.5-4.5L17 16l-2.5-2.5 1.41-1.41L17 13.17l3.09-3.09 1.41 1.42z"/></svg>';
}

function iconCheckSvg() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 1 0 .01 20.01A10 10 0 0 0 12 2zm-1.2 14.2-4-4 1.4-1.4 2.6 2.58 6-6.02 1.4 1.42-7.4 7.42z"/></svg>';
}

function iconTrashSvg() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>';
}

function iconHeadsetSvg() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 1a9 9 0 0 0-9 9v7a3 3 0 0 0 3 3h3v-8H5v-2a7 7 0 0 1 14 0v2h-4v8h3a3 3 0 0 0 3-3v-7a9 9 0 0 0-9-9z"/></svg>';
}

function wishOriginIconHtml(group, wish) {
  const fromSetlist = group?.from_setlist === true || wish?.from_setlist === true
    || (Array.isArray(group?.requested_by) && group.requested_by.includes(FROM_SETLIST_MARKER))
    || (Array.isArray(wish?.requested_by) && wish.requested_by.includes(FROM_SETLIST_MARKER));
  const isDjWish = group?.is_dj_wish === true || wish?.is_dj_wish === true;
  if (fromSetlist) {
    return `<span class="wish-origin-icon wish-origin-setlist" aria-hidden="true">${iconQueueSvg()}</span>`;
  }
  if (isDjWish) {
    return `<span class="wish-origin-icon wish-origin-dj" aria-hidden="true">${iconHeadsetSvg()}</span>`;
  }
  return '';
}

function renderWishes(force) {
  const root = document.getElementById('wish-list');
  if (!root) return;
  if (state.reorderActive) return;
  if (state.activeTab === 'setlist') {
    renderSetlistList(force);
    return;
  }
  if (lastWishListTab === 'setlist' || lastWishListTab !== state.activeTab) {
    root.replaceChildren();
    lastWishListKey = '';
    lastWishListTab = state.activeTab;
  }
  if (state.wishesLoading && !state.wishes.length) {
    renderWishListLoading();
    updateOffenBlacklistChip();
    return;
  }
  const allGrouped = groupedEntriesForTab();
  const useFullList = state.reorderActive;
  let grouped = allGrouped;
  if (!useFullList && allGrouped.length) {
    const totalPages = calculateTotalPages(
      allGrouped.length,
      state.resultsPerPage || DJ_DEFAULT_RESULTS_PER_PAGE,
    );
    if (state.currentPage > totalPages) state.currentPage = totalPages || 1;
    grouped = getItemsForPage(
      allGrouped,
      state.currentPage,
      state.resultsPerPage,
    );
  }
  renderPaginationBar(allGrouped.length);

  const listKey = `${state.activeTab}|` + grouped.map((entry) => wishCardRenderKey(entry)).join('\u001e')
    + `\u001e${state.currentPage}\u001e${state.resultsPerPage}`;
  if (!force && listKey === lastWishListKey) {
    if (state.activeTab === 'offen') updateOpenWaitTimes();
    updateOffenBlacklistChip();
    return;
  }
  lastWishListKey = listKey;

  if (!grouped.length) {
    stopWaitTimeTicker();
    renderPaginationBar(allGrouped.length);
    let empty = root.querySelector('.wish-empty');
    if (!empty) {
      root.replaceChildren();
      empty = document.createElement('p');
      empty.className = 'wish-empty';
      root.appendChild(empty);
    }
    empty.textContent = t('dj_browser_no_wishes');
    updateOffenBlacklistChip();
    return;
  }

  const empty = root.querySelector('.wish-empty');
  if (empty) empty.remove();

  root.querySelector('.wish-reorder-hint')?.remove();

  const seen = new Set();
  const frag = document.createDocumentFragment();

  grouped.forEach((entry) => {
    seen.add(entry.groupKey);
    const renderKey = wishCardRenderKey(entry);
    const selector = `[data-group-key="${CSS.escape(String(entry.groupKey))}"]`;
    let card = root.querySelector(selector);
    if (card && card.dataset.renderKey === renderKey) return;

    const wrap = document.createElement('div');
    wrap.innerHTML = renderWishCard(entry).trim();
    const next = wrap.firstElementChild;
    if (!next) return;
    next.dataset.groupKey = entry.groupKey;
    next.dataset.renderKey = renderKey;
    next.dataset.docIds = (entry.docIds || []).join(',');

    if (card) {
      card.replaceWith(next);
    } else {
      frag.appendChild(next);
    }
  });

  root.querySelectorAll('[data-group-key]').forEach((el) => {
    if (!seen.has(el.dataset.groupKey)) el.remove();
  });

  if (frag.childNodes.length) root.appendChild(frag);

  grouped.forEach((entry, index) => {
    const card = root.querySelector(`[data-group-key="${CSS.escape(String(entry.groupKey))}"]`);
    const at = root.children[index];
    if (card && at !== card) root.insertBefore(card, at || null);
  });

  enhanceGreetingTranslations(root);
  if (state.activeTab === 'offen') {
    startWaitTimeTicker();
  } else {
    stopWaitTimeTicker();
  }
  updateOffenBlacklistChip();
}

function escapeHtml(s) {
  return String(s || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function iconHeartSvg() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>';
}

function iconBookmarkSvg() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 2h12a1 1 0 0 1 1 1v19.08a.92.92 0 0 1-1.43.76L12 18.06l-5.57 4.78A.92.92 0 0 1 5 22.08V3a1 1 0 0 1 1-1z"/></svg>';
}

function iconAnchorSvg(outlined) {
  const strokeW = outlined ? '2' : '2.35';
  return `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="${strokeW}" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="3"/><line x1="12" y1="8" x2="12" y2="22"/><path d="M5 12H2a10 10 0 0 0 20 0h-3"/></svg>`;
}

function iconCopySvg() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
}

function iconAutoRecognizedSvg() {
  return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m19 9 1.25-2.75L23 5l-2.75-1.25L19 1l-1.25 2.75L15 5l2.75 1.25L19 9zm-7.5 0L11 6.25 8.5 5 11 3.75 11.5 1 14 2.75 16.5 1 17 3.75 19.5 5 17 6.25 16.5 9 14 7.25 11.5 9zM19 15.5l-1.25 2.75L15 19.5l2.75 1.25L19 23.5l1.25-2.75L23 19.5l-2.75-1.25L19 15.5z"/></svg>';
}

function renderAutoRecognizedBadge(group, tab) {
  if (group.auto_recognized !== true) return '';
  const tip = escapeHtml(t('automatically_recognized'));
  const tabClass = tab === 'gespielt' ? ' gespielt-tab' : '';
  return `<span class="wish-auto-recognized${tabClass}" role="img" aria-label="${tip}" title="${tip}">${iconAutoRecognizedSvg()}</span>`;
}

function wishCopyPlainText(artist, title) {
  const parts = [String(artist || '').trim(), String(title || '').trim()].filter(Boolean);
  return parts.join(' ').replace(/\s+/g, ' ');
}

async function copyTextToClipboard(text) {
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const ta = document.createElement('textarea');
  ta.value = text;
  ta.setAttribute('readonly', '');
  ta.style.position = 'fixed';
  ta.style.left = '-9999px';
  document.body.appendChild(ta);
  ta.select();
  document.execCommand('copy');
  document.body.removeChild(ta);
}

function renderWishCardTools(entry) {
  const tab = state.activeTab;
  const wish = entry.wish || {};
  const group = entry.group || {};
  const groupKeyRaw = String(entry.groupKey || '');
  const groupKeyAttr = escapeHtml(groupKeyRaw);
  const id = escapeHtml(String(entry.primaryId || wish.id || ''));
  const parts = [];

  if (tab === 'offen') {
    const favActive = group.is_favorite === true || wish.is_favorite === true;
    parts.push(
      `<button type="button" class="icon-btn icon-favorite${favActive ? ' active' : ''}" data-action="favorite" data-id="${id}" aria-label="${escapeHtml(t('free_feature_favorites_title'))}" title="${escapeHtml(t('free_feature_favorites_title'))}">${iconHeartSvg()}</button>`,
    );
  }

  if (tab === 'offen' || tab === 'gespielt' || tab === 'abgelehnt') {
    const saved = isTrackSaved(wish);
    const tip = saved ? t('saved_tracks_remove_tooltip') : t('saved_tracks_bookmark_tooltip');
    parts.push(
      `<button type="button" class="icon-btn icon-bookmark${saved ? ' active' : ''}" data-action="bookmark" data-id="${id}" aria-label="${escapeHtml(tip)}" title="${escapeHtml(tip)}">${iconBookmarkSvg()}</button>`,
    );
  }

  if (tab === 'offen') {
    const pinned = isWishPinned(entry.groupKey);
    const anchorTip = pinned ? t('wish_anchor_remove_tooltip') : t('wish_anchor_tooltip');
    parts.push(
      `<button type="button" class="icon-btn icon-anchor${pinned ? ' active' : ''}" data-action="pin" data-group-key="${groupKeyAttr}" aria-label="${escapeHtml(anchorTip)}" title="${escapeHtml(anchorTip)}">${iconAnchorSvg(!pinned)}</button>`,
    );
  }

  if (tab === 'vorab') {
    parts.push(
      `<button type="button" class="wish-tool-btn btn-publish" data-action="publish" data-id="${id}">${escapeHtml(t('dj_browser_action_publish'))}</button>`,
    );
  } else if (tab === 'offen') {
    parts.push(
      `<button type="button" class="wish-tool-btn btn-play" data-action="play" data-id="${id}">${escapeHtml(t('dj_browser_action_play'))}</button>`,
      `<button type="button" class="wish-tool-btn btn-reject" data-action="reject" data-id="${id}">${escapeHtml(t('dj_browser_action_reject'))}</button>`,
      `<button type="button" class="wish-tool-btn btn-delete" data-action="delete" data-id="${id}">${escapeHtml(t('dj_browser_action_delete'))}</button>`,
    );
  } else if (tab === 'abgelehnt') {
    if (!entryHasBlockedGuest(entry)) {
      parts.push(
        `<button type="button" class="wish-tool-btn btn-restore" data-action="restore" data-id="${id}">${escapeHtml(t('back_to_open'))}</button>`,
      );
    }
  }

  if (!parts.length) return '';
  return `<div class="wish-card-tools">${parts.join('')}</div>`;
}

function renderWisherTimeHtml(entry, wisher, wisherIndex) {
  const tab = state.activeTab;
  const wisherDate = tsToDate(wisher.createdAt);
  if (!wisherDate) return '';

  // Pro Wünscher eigene Einreichzeit (nicht nur Index 0 / oldest).
  if (tab === 'gespielt') {
    return `<p class="wish-wisher-time">${formatPlayedStatusTimeLine(entry, wisherDate)}</p>`;
  }
  if (tab === 'abgelehnt') {
    return `<p class="wish-wisher-time">${formatRejectedStatusTimeLine(entry, wisherDate)}</p>`;
  }
  if (tab === 'offen') {
    const base = formatClockWithSuffix(wisherDate);
    const waitPart = formatWaitParensLive(wisherDate);
    return `<p class="wish-wisher-time" data-wait-from="${escapeHtml(wisherDate.toISOString())}">${escapeHtml(base)}<span class="wish-wait-paren">${escapeHtml(waitPart)}</span></p>`;
  }

  const line = formatWishDateTimeLine(wisherDate);
  return line ? `<p class="wish-wisher-time">${escapeHtml(line)}</p>` : '';
}

function renderWishersBlock(group, entry) {
  const wg = wishGrouping();
  const isDjWish = entry?.wish?.is_dj_wish === true || group?.is_dj_wish === true;
  const fromSetlist = entry?.wish?.from_setlist === true || group?.from_setlist === true;
  const wishers = wg
    ? wg.buildWishersList(group, t('no_name'))
    : [];
  if (!wishers.length) return '';

  const rows = wishers.map((wisher, index) => {
    const timeHtml = renderWisherTimeHtml(entry, wisher, index);
    const greetingHtml = wisher.greeting
      ? `<p class="wish-greeting-text" data-greeting-text="${escapeHtml(wisher.greeting)}">${escapeHtml(unescapeHtml(wisher.greeting))}</p>`
      : '';
    const cachedTranslation = wisher.greeting ? peekGreetingTranslation(wisher.greeting) : null;
    const translationHtml = cachedTranslation
      ? `<p class="wish-greeting-translation">${escapeHtml(cachedTranslation)}</p>`
      : '';
    const displayName = wisherDisplayName(wisher.rawName, { isDjWish, fromSetlist });
    return `
      <div class="wish-wisher-row">
        <p class="wish-wisher-name">${escapeHtml(unescapeHtml(displayName))}</p>
        ${timeHtml}
        ${greetingHtml}
        ${translationHtml}
      </div>`;
  }).join('');

  return `<div class="wish-wishers">${rows}</div>`;
}

function renderWishCard(entry) {
  const group = entry.group || {};
  const wish = entry.wish || {};
  const rawTitle = String(unescapeHtml(group.title || wish.title || wish.song_title || '—')).trim();
  const rawArtist = String(unescapeHtml(group.artist || wish.artist || wish.song_artist || '')).trim();
  const title = escapeHtml(rawTitle || '—');
  const artist = escapeHtml(rawArtist);
  const copyText = wishCopyPlainText(rawArtist, rawTitle);
  const copyTip = escapeHtml(t('dj_browser_copy_track_tooltip'));
  const copyBtn = copyText
    ? `<button type="button" class="icon-btn icon-copy" data-action="copy-track" data-copy-text="${escapeHtml(copyText)}" aria-label="${copyTip}" title="${copyTip}">${iconCopySvg()}</button>`
    : '';
  const tabClass = state.activeTab;
  const wg = wishGrouping();
  const total = wg ? wg.wishTotalCount(group) : 1;
  const badge = total > 1
    ? `<span class="wish-count-badge" aria-label="${total}">${total}</span>`
    : '';
  const autoRecognizedBadge = renderAutoRecognizedBadge(group, state.activeTab);
  const guestBlockedBadge = renderGuestBlockedBadge(entry);
  const songBlacklistBadge = renderSongBlacklistBadge(entry);
  const wishersBlock = renderWishersBlock(group, entry);
  const pinnedClass = isWishPinned(entry.groupKey) ? ' pinned' : '';
  const draggableClass =
    state.activeTab === 'offen' && !state.showOnlyFavorites && !isWishPinned(entry.groupKey)
      ? ' draggable-wish'
      : '';
  const showDragHandle = draggableClass !== '';
  const dragTip = escapeHtml(t('drag_to_reorder_hint'));
  const toolsHtml = renderWishCardTools(entry);
  const originIcon = wishOriginIconHtml(group, wish);
  const inner = `
      <div class="wish-badge-row">
        ${copyBtn}
        ${badge}
        ${autoRecognizedBadge}
        <div class="wish-music-block">
          <div class="wish-title-row">
            ${originIcon}
            <h2 class="wish-title">${title}</h2>
            ${toolsHtml}
          </div>
          <p class="wish-artist">${artist}</p>
          ${guestBlockedBadge}
          ${songBlacklistBadge}
        </div>
      </div>
      ${wishersBlock}`;

  if (state.activeTab === 'offen') {
    const handle = showDragHandle
      ? `<div class="wish-drag-handle" role="button" tabindex="-1" aria-label="${dragTip}" title="${dragTip}"></div>`
      : '';
    return `
    <article class="wish-card ${tabClass}${pinnedClass}${draggableClass}" data-wish-id="${escapeHtml(String(entry.primaryId || ''))}">
      <div class="wish-card-layout${showDragHandle ? '' : ' no-handle'}">
        ${handle}
        <div class="wish-card-inner">${inner}</div>
      </div>
    </article>`;
  }

  return `
    <article class="wish-card ${tabClass}${pinnedClass}${draggableClass}" data-wish-id="${escapeHtml(String(entry.primaryId || ''))}">
      ${inner}
    </article>`;
}

async function toggleFavorite(wishId) {
  const ref = window.djDoc(window.djFirebaseDb, 'parties', state.partyId, 'wishes', wishId);
  const snap = await window.djGetDoc(ref);
  if (!snap.exists()) return;
  const current = snap.data()?.is_favorite === true;
  await window.djUpdateDoc(ref, { is_favorite: !current });
}

async function toggleBookmark(wish) {
  const title = String(wish.title || wish.song_title || '').trim();
  const artist = String(wish.artist || wish.song_artist || '').trim();
  const key = dedupeKey(title, artist);
  const manage = window.djHttpsCallable('manageSavedTrack');
  if (state.savedTrackKeys.has(key)) {
    await manage({ action: 'remove', title, artist });
    state.savedTrackKeys.delete(key);
    showToast(t('saved_tracks_removed_snackbar'), '#4caf50');
  } else {
    const result = await manage({
      action: 'add',
      track: {
        title,
        artist,
        party_id: state.partyId,
        source_wish_id: wish.id,
      },
    });
    state.savedTrackKeys.add(key);
    const already = result.data && result.data.alreadyExists === true;
    showToast(
      already ? t('saved_tracks_already_saved_snackbar') : t('saved_tracks_added_snackbar'),
      already ? '#ff8800' : '#4caf50',
    );
  }
  lastWishListKey = '';
  renderWishes(true);
}

async function onWishAction(ev) {
  const btn = ev.currentTarget;
  const action = btn.getAttribute('data-action');
  if (!action || !state.partyId) return;
  if (action.startsWith('setlist-')) {
    await onSetlistAction(btn, action);
    return;
  }
  const id = btn.getAttribute('data-id');
  if (action !== 'pin' && action !== 'copy-track' && !id) return;

  if (action === 'copy-track') {
    const text = btn.getAttribute('data-copy-text') || '';
    if (!text.trim()) return;
    try {
      await copyTextToClipboard(text);
      showToast(t('dj_browser_copy_track_ok'), '#4caf50');
    } catch (err) {
      console.error('[dj-browser] copy-track', err);
      showToast(t('dj_browser_copy_track_error'), '#f44336');
    }
    return;
  }
  const card = btn.closest('[data-doc-ids]');
  const docIds = card && card.dataset.docIds
    ? card.dataset.docIds.split(',').filter(Boolean)
    : (id ? [id] : []);

  if (action === 'favorite') {
    try {
      await toggleFavorite(id);
    } catch (err) {
      console.error('[dj-browser] favorite', err);
      showToast(t('favorite_status_update_error'), '#f44336');
    }
    return;
  }

  if (action === 'pin') {
    const groupKey = btn.getAttribute('data-group-key');
    if (!groupKey) return;
    await toggleWishPin(groupKey);
    return;
  }

  if (action === 'bookmark') {
    const wish = state.wishes.find((w) => String(w.id) === String(id));
    if (!wish) return;
    try {
      await toggleBookmark(wish);
    } catch (err) {
      console.error('[dj-browser] bookmark', err);
      showToast(t('saved_tracks_save_error'), '#f44336');
    }
    return;
  }

  try {
    if (action === 'play' || action === 'reject' || action === 'delete' || action === 'restore') {
      const cardRoot = btn.closest('.wish-card') || card;
      const titleEl = cardRoot && cardRoot.querySelector('.wish-title');
      const artistEl = cardRoot && cardRoot.querySelector('.wish-artist');
      let confirmMessage;
      let confirmOptions;
      if (action === 'restore') {
        confirmMessage = `${t('confirm_reopen_title')}\n\n${t('confirm_reopen_message')}`;
        confirmOptions = {
          variant: action,
          title: titleEl ? titleEl.textContent.trim() : '',
          artist: artistEl ? artistEl.textContent.trim() : '',
          cancelLabel: t('confirm_reopen_no'),
          confirmLabel: t('confirm_reopen_yes'),
        };
      } else {
        const messageKey = action === 'play'
          ? 'dj_browser_confirm_play'
          : action === 'reject'
            ? 'dj_browser_confirm_reject'
            : 'dj_browser_confirm_delete';
        confirmMessage = t(messageKey);
        confirmOptions = {
          variant: action,
          title: titleEl ? titleEl.textContent.trim() : '',
          artist: artistEl ? artistEl.textContent.trim() : '',
        };
      }
      const confirmed = await showDjConfirm(confirmMessage, confirmOptions);
      if (!confirmed) return;
    }

    if (action === 'play') {
      const now = window.djServerTimestamp();
      await Promise.all(docIds.map((docId) => window.djUpdateDoc(
        window.djDoc(window.djFirebaseDb, 'parties', state.partyId, 'wishes', docId),
        {
          status: 'played',
          playedAt: now,
          played_at: now,
          rejectedAt: null,
          rejected_at: null,
        },
      )));
    } else if (action === 'reject') {
      const now = window.djServerTimestamp();
      await Promise.all(docIds.map((docId) => window.djUpdateDoc(
        window.djDoc(window.djFirebaseDb, 'parties', state.partyId, 'wishes', docId),
        {
          status: 'rejected',
          rejectedAt: now,
          rejected_at: now,
          playedAt: null,
          played_at: null,
        },
      )));
    } else if (action === 'publish') {
      await window.djUpdateDoc(
        window.djDoc(window.djFirebaseDb, 'parties', state.partyId, 'wishes', id),
        {
          pre_wish_published: true,
          status: 'pending',
        },
      );
    } else if (action === 'restore') {
      const blockedDocs = docIds.filter((docId) => {
        const w = state.wishes.find((x) => String(x.id) === String(docId));
        return isWishFromBlockedGuest(w);
      });
      if (blockedDocs.length > 0) {
        showToast(t('guest_blocked_badge'), '#f44336');
        return;
      }
      const del = window.djDeleteField();
      await Promise.all(docIds.map((docId) => window.djUpdateDoc(
        window.djDoc(window.djFirebaseDb, 'parties', state.partyId, 'wishes', docId),
        {
          status: 'pending',
          playedAt: del,
          played_at: del,
          rejectedAt: del,
          rejected_at: del,
          rejection_reason: del,
          auto_rejected_by_block: del,
        },
      )));
      const idSet = new Set(docIds.map(String));
      state.wishes = state.wishes.map((w) => {
        if (!idSet.has(String(w.id))) return w;
        return {
          ...w,
          status: 'pending',
          playedAt: null,
          played_at: null,
          rejectedAt: null,
          rejected_at: null,
          rejection_reason: null,
          auto_rejected_by_block: null,
        };
      });
      lastWishListKey = '';
      state.activeTab = 'offen';
      renderTabs(true);
      updateFavoritesHeader();
      updateTopBarControls();
      renderWishes(true);
      showToast(t('wish_restored_count', { count: docIds.length }), '#4caf50');
    } else if (action === 'delete') {
      await Promise.all(docIds.map((docId) => window.djDeleteDoc(
        window.djDoc(window.djFirebaseDb, 'parties', state.partyId, 'wishes', docId),
      )));
    }
  } catch (err) {
    console.error('[dj-browser] wish action', err);
  }
}

function updatePausedBanner() {
  const el = document.getElementById('pre-wish-paused-banner');
  const show = state.party?.allow_pre_wishes === true && state.party?.pre_wishes_paused === true;
  el.hidden = !show;
  el.textContent = t('dj_browser_pre_wishes_paused');
}

function watchSongBlacklistIfNeeded() {
  if (state._blacklistWatchUid) return;
  const uid = String(
    state.ownerUid
    || state.party?.created_by
    || state.party?.djId
    || state.party?.dj_id
    || '',
  ).trim();
  if (!uid) return;
  state._blacklistWatchUid = uid;
  const blacklistRef = window.djDoc(
    window.djFirebaseDb,
    'dj_song_blacklists',
    uid,
  );
  const unsubBlacklist = window.djOnSnapshot(
    blacklistRef,
    (snap) => {
      state.blacklistEnabled = parseBlacklistEnabledFromDoc(
        snap.exists() ? snap.data() : null,
      );
      state.blacklistSongCount = parseBlacklistSongCount(
        snap.exists() ? snap.data() : null,
      );
      updateOffenBlacklistChip();
    },
    (err) => console.error('[dj-browser] song blacklist', err),
  );
  state.unsubscribers.push(() => {
    try { unsubBlacklist(); } catch (e) { /* ignore */ }
    state._blacklistWatchUid = null;
  });
}

function startPartyWatchers() {
  watchSongBlacklistIfNeeded();
  const partyRef = window.djDoc(window.djFirebaseDb, 'parties', state.partyId);
  const unsubParty = window.djOnSnapshot(partyRef, async (snap) => {
    if (!snap.exists()) {
      await handleGracePeriodExpired();
      return;
    }
    const prevAllowPre = state.party?.allow_pre_wishes === true;
    const prevPinAt = state.party?.open_wish_pinned_updated_at;
    const prevOrderAt = state.party?.open_wish_order_updated_at;
    state.party = snap.data();
    syncPartyOrderFields(state.party);
    watchSongBlacklistIfNeeded();
    const pinChanged = JSON.stringify(prevPinAt) !== JSON.stringify(state.party.open_wish_pinned_updated_at);
    const orderChanged = JSON.stringify(prevOrderAt) !== JSON.stringify(state.party.open_wish_order_updated_at);
    updatePartyHeader();
    updatePausedBanner();
    const nextAllowPre = state.party?.allow_pre_wishes === true;
    if (prevAllowPre !== nextAllowPre) {
      renderTabs(true);
    }
    if (prevAllowPre !== nextAllowPre || pinChanged || orderChanged) {
      lastWishListKey = '';
      renderWishes(true);
    }
    if (!state.graceMinutesFromServer) {
      state.ownerGraceMinutes = await loadOwnerGrace(state.party);
    }
    if (isPartyClosed(state.party, state.ownerGraceMinutes)) {
      await handleGracePeriodExpired();
    }
  });
  state.unsubscribers.push(unsubParty);

  const sessionRef = window.djDoc(window.djFirebaseDb, 'dj_browser_sessions', state.sessionId);
  const unsubSession = window.djOnSnapshot(sessionRef, async (snap) => {
    if (!snap.exists() || snap.data()?.active !== true) {
      await endSession('dj_browser_session_replaced');
    }
  });
  state.unsubscribers.push(unsubSession);

  const wishesRef = window.djCollection(window.djFirebaseDb, 'parties', state.partyId, 'wishes');
  const unsubWishes = window.djOnSnapshot(
    wishesRef,
    (snap) => {
      state.wishes = wishesFromFirestoreDocs(snap.docs);
      state.wishesLoading = false;
      if (state.party) syncPartyOrderFields(state.party);
      lastWishListKey = '';
      renderTabs();
      renderWishes(true);
      updateTopBarControls();
    },
    (err) => console.error('[dj-browser] wishes', err),
  );
  state.unsubscribers.push(unsubWishes);

  const setlistRef = window.djDoc(window.djFirebaseDb, 'dj_setlists', state.partyId);
  const unsubSetlist = window.djOnSnapshot(
    setlistRef,
    (snap) => {
      state.setlistTracks = setlistTracksFromDoc(snap.exists() ? snap.data() : null);
      if (
        state.setlistSelectedIndex != null
        && !state.setlistTracks.some((tr) => tr.index === state.setlistSelectedIndex)
      ) {
        state.setlistSelectedIndex = null;
      }
      lastWishListKey = '';
      renderTabs();
      renderWishes(true);
      updateTopBarControls();
    },
    (err) => console.error('[dj-browser] setlist', err),
  );
  state.unsubscribers.push(unsubSetlist);

  watchSongBlacklistIfNeeded();

  const blockedGuestsQ = window.djQuery(
    window.djCollection(window.djFirebaseDb, 'blocked_guests'),
    window.djWhere('party_id', '==', state.partyId),
  );
  const unsubBlockedGuests = window.djOnSnapshot(
    blockedGuestsQ,
    (snap) => {
      const fromGuests = new Set();
      snap.docs.forEach((d) => {
        const data = d.data() || {};
        if (!isGuestBlockActive(data)) return;
        const cid = String(data.client_id || '').trim();
        if (cid) fromGuests.add(cid);
      });
      state._blockedFromGuests = fromGuests;
      const fromDevices = state._blockedFromDevices || new Set();
      state.blockedClientIds = new Set([...fromGuests, ...fromDevices]);
      lastWishListKey = '';
      renderWishes(true);
    },
    (err) => console.error('[dj-browser] blocked_guests', err),
  );
  state.unsubscribers.push(unsubBlockedGuests);

  const blockedDevicesQ = window.djQuery(
    window.djCollection(window.djFirebaseDb, 'blocked_devices'),
    window.djWhere('party_id', '==', state.partyId),
  );
  const unsubBlockedDevices = window.djOnSnapshot(
    blockedDevicesQ,
    (snap) => {
      const fromDevices = new Set();
      snap.docs.forEach((d) => {
        const data = d.data() || {};
        if (!isGuestBlockActive(data)) return;
        const cid = String(data.client_id || data.device_id || d.id || '').trim();
        if (cid) fromDevices.add(cid);
      });
      state._blockedFromDevices = fromDevices;
      const fromGuests = state._blockedFromGuests || new Set();
      state.blockedClientIds = new Set([...fromGuests, ...fromDevices]);
      lastWishListKey = '';
      renderWishes(true);
    },
    (err) => console.error('[dj-browser] blocked_devices', err),
  );
  state.unsubscribers.push(unsubBlockedDevices);
}

const DEFAULT_GRACE_MINUTES = 30;

function parseGraceMinutesValue(raw) {
  if (typeof raw === 'number' && raw >= 0 && raw <= 120) return raw;
  const num = Number(raw);
  if (!Number.isNaN(num) && num >= 0 && num <= 120) return num;
  return null;
}

async function loadOwnerGrace(party) {
  const owner = party.created_by || party.djId || party.dj_code || party.uid;
  if (!owner) return DEFAULT_GRACE_MINUTES;
  try {
    const userRef = window.djDoc(window.djFirebaseDb, 'users', String(owner));
    const snap = await window.djGetDoc(userRef);
    if (snap.exists()) {
      const g = snap.data()?.grace_period_minutes;
      const fromRoot = typeof g === 'number' ? g : Number(g);
      if (!Number.isNaN(fromRoot) && fromRoot >= 0 && fromRoot <= 120) return fromRoot;
    }
    const legacyRef = window.djDoc(
      window.djFirebaseDb,
      'users',
      String(owner),
      'settings',
      'grace_period',
    );
    const legacySnap = await window.djGetDoc(legacyRef);
    if (legacySnap.exists()) {
      const lg = legacySnap.data()?.grace_period_minutes;
      const fromLegacy = typeof lg === 'number' ? lg : Number(lg);
      if (!Number.isNaN(fromLegacy) && fromLegacy >= 0 && fromLegacy <= 120) {
        return fromLegacy;
      }
    }
  } catch (e) {
    /* fallback */
  }
  return DEFAULT_GRACE_MINUTES;
}

async function afterLogin(partyId, sessionId, ownerUid, accessMeta = {}) {
  state.partyId = partyId;
  state.sessionId = sessionId;
  state.ownerUid = ownerUid || null;
  state.wishes = [];
  state.wishesLoading = true;
  state.currentPage = 1;
  state.graceMinutesFromServer = accessMeta.graceMinutesFromServer === true;
  cleanupListeners();

  const partyRef = window.djDoc(window.djFirebaseDb, 'parties', partyId);
  const wishesRef = window.djCollection(window.djFirebaseDb, 'parties', partyId, 'wishes');

  let partySnap;
  let wishesSnap = null;
  try {
    [partySnap, wishesSnap] = await Promise.all([
      window.djGetDoc(partyRef),
      window.djGetDocs(wishesRef).catch((e) => {
        console.warn('[dj-browser] initial wishes', e);
        return null;
      }),
    ]);
  } catch (e) {
    console.error('[dj-browser] afterLogin load', e);
    state.wishesLoading = false;
    await endSession('dj_browser_error_network');
    return;
  }

  if (!partySnap.exists()) {
    state.wishesLoading = false;
    await handleGracePeriodExpired();
    return;
  }

  state.party = partySnap.data();
  syncPartyOrderFields(state.party);
  if (wishesSnap) {
    state.wishes = wishesFromFirestoreDocs(wishesSnap.docs);
  }
  state.wishesLoading = false;

  const graceFromMeta = parseGraceMinutesValue(accessMeta.ownerGraceMinutes);
  if (graceFromMeta != null) {
    state.ownerGraceMinutes = graceFromMeta;
  } else {
    state.ownerGraceMinutes = await loadOwnerGrace(state.party);
  }

  if (!accessMeta.skipClosedCheck && isPartyClosed(state.party, state.ownerGraceMinutes)) {
    await handleGracePeriodExpired();
    return;
  }

  updatePartyHeader();
  updatePausedBanner();
  state.resultsPerPage = await loadDjResultsPerPage(state.ownerUid);
  showView('box');
  startPartyWatchers();
  setupLiveSyncRecovery();
  renderTabs(true);
  lastWishListKey = '';
  renderWishes(true);
  setupWishListActions();
  setupWishPagination();
  setupTopBarControls();
  setupFavoritesHeader();
  setupWishReorder();
  updateTopBarControls();
  updateFavoritesHeader();
  loadSecondaryBoxSettings();
  scrollAppToTop();
  requestAnimationFrame(scrollAppToTop);

  if (state.lastRedeemCode) {
    try {
      const confirmFn = window.djHttpsCallable('confirmDjBrowserRedeem');
      await confirmFn({ code: state.lastRedeemCode });
    } catch (e) {
      console.warn('[dj-browser] confirm redeem', e);
    }
    state.lastRedeemCode = null;
  }

  try {
    const ping = window.djHttpsCallable('pingDjBrowserSession');
    if (pingTimerId != null) clearInterval(pingTimerId);
    pingTimerId = setInterval(() => ping().catch(() => {}), 60000);
  } catch (e) { /* ignore */ }
}

function redeemErrorMessage(err) {
  const code = String(err?.code || '');
  const msg = String(err?.message || '');
  if (code.includes('resource-exhausted')) {
    return t('dj_browser_error_rate_limit');
  }
  if (msg.includes('Party zu Ende') || code.includes('failed-precondition') && msg.includes('Party')) {
    return t('dj_browser_party_ended');
  }
  if (
    code.includes('unavailable')
    || code.includes('internal')
    || code.includes('network')
    || code.includes('deadline-exceeded')
  ) {
    if (msg.includes('Login konnte nicht')) return t('dj_browser_error_network');
  }
  if (code.includes('not-found') || code.includes('failed-precondition') || code.includes('invalid-argument')) {
    return t('dj_browser_code_invalid');
  }
  if (!navigator.onLine) return t('dj_browser_error_network');
  return t('dj_browser_code_invalid');
}

async function redeemCode(code) {
  const errEl = document.getElementById('login-error');
  errEl.hidden = true;
  showView('login');
  setLoginLoading(true);
  state.lastRedeemCode = code;
  try {
    const redeem = window.djHttpsCallable('redeemDjBrowserCode');
    const result = await redeem({ code, deviceId: getDeviceId() });
    const data = result.data || {};
    const token = data.customToken;
    const partyId = data.partyId;
    const sessionId = data.sessionId;
    if (!token || !partyId || !sessionId) {
      throw new Error('invalid response');
    }
    await window.djSignInWithCustomToken(window.djFirebaseAuth, token);
    const graceFromRedeem = parseGraceMinutesValue(data.ownerGraceMinutes);
    await afterLogin(partyId, sessionId, data.ownerUid, {
      ownerGraceMinutes: graceFromRedeem,
      graceMinutesFromServer: graceFromRedeem != null,
      skipClosedCheck: true,
    });
  } catch (e) {
    state.lastRedeemCode = null;
    throw e;
  } finally {
    setLoginLoading(false);
  }
}

function applyLoginL10n() {
  if (typeof window.djBrowserApplyLoginL10n === 'function') {
    window.djBrowserApplyLoginL10n(window.djBrowserLocale);
  }
}

function applyUiL10n() {
  if (typeof window.djApplyTextDirection === 'function') {
    window.djApplyTextDirection(readActiveDjLangCode());
  }
  applyLoginL10n();
  setBootLoadingText();
  if (state.view === 'box') {
    lastTabsKey = '';
    lastWishListKey = '';
    updatePartyHeader();
    updatePausedBanner();
    updateTopBarControls();
    updateFavoritesHeader();
    renderTabs(true);
    renderWishes(true);
    renderPaginationBar(groupedEntriesForTab().length);
  }
}

window.addEventListener('djBrowserLocaleChanged', applyUiL10n);

function setLoginLoading(active) {
  const input = document.getElementById('code-input');
  const loading = document.getElementById('login-loading');
  if (input) input.disabled = active;
  if (loading) loading.hidden = !active;
}

let loginSubmitting = false;
let loginSetupDone = false;
let wishListActionsSetup = false;

function setupWishListActions() {
  if (wishListActionsSetup) return;
  wishListActionsSetup = true;
  const root = document.getElementById('wish-list');
  if (!root) return;
  root.addEventListener('click', (ev) => {
    const btn = ev.target.closest('[data-action]');
    if (!btn || !root.contains(btn)) return;
    onWishAction({ currentTarget: btn });
  });
}

function setupLogin() {
  if (loginSetupDone) return;
  loginSetupDone = true;
  const input = document.getElementById('code-input');
  const form = document.getElementById('login-form');
  const errEl = document.getElementById('login-error');

  input.addEventListener('input', () => {
    if (loginSubmitting) return;
    input.value = input.value.replace(/\D/g, '').slice(0, 6);
    errEl.hidden = true;
    if (input.value.length === 6) {
      form.requestSubmit();
    }
  });

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    if (loginSubmitting) return;
    const code = input.value.trim();
    if (code.length !== 6) return;
    loginSubmitting = true;
    try {
      await redeemCode(code);
    } catch (e) {
      console.error('[dj-browser] login', e);
      errEl.textContent = redeemErrorMessage(e);
      errEl.hidden = false;
      input.value = '';
      input.disabled = false;
      input.focus();
    } finally {
      loginSubmitting = false;
      setLoginLoading(false);
    }
  });

  input.focus();
}

function boot() {
  if (bootDone) return;
  bootDone = true;
  loadGreetingTranslationCache();
  applyLoginL10n();
  setBootLoadingText();
  setupWishListActions();
  setupWishPagination();
  setupTopBarControls();
  setupFavoritesHeader();
  setupWishReorder();
  if (window.DjManualWish) {
    window.DjManualWish.init({
      getState: () => state,
      t,
      showToast,
      showConfirm: showDjConfirm,
    });
  }
  showView('boot');

  if (window.djFirebaseInitFailed) {
    showView('login');
    setupLogin();
    const errEl = document.getElementById('login-error');
    if (errEl) {
      errEl.textContent = t('dj_browser_error_network');
      errEl.hidden = false;
    }
    return;
  }

  waitForAuthReady()
    .then(async (user) => {
      if (user) {
        try {
          if (await restoreDjSession(user)) return;
          await window.djSignOut(window.djFirebaseAuth);
        } catch (e) {
          console.error('[dj-browser] restore session', e);
          try {
            await window.djSignOut(window.djFirebaseAuth);
          } catch (signOutErr) { /* ignore */ }
        }
      }
      showView('login');
      setupLogin();
    })
    .catch((e) => {
      console.error('[dj-browser] boot', e);
      showView('login');
      setupLogin();
    });
}

if (window.djFirebaseAuth || window.djFirebaseInitFailed) {
  boot();
} else {
  window.addEventListener('djFirebaseReady', boot, { once: true });
}
