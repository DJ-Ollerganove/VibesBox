/**
 * Kanonischer Song-Katalog (wunschbox_artist / wunschbox_titel).
 * Speichert u. a. Camelot (8A/9B), Key, BPM, Dauer + Setlisten-Zähler.
 * Kein Spotify-Call — nur Upsert aus App/KI-Metadaten (günstig, skalierbar).
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const CALLABLE_OPTS = {
  region: 'us-central1',
  enforceAppCheck: false,
  memory: '256MiB',
  timeoutSeconds: 60,
  serviceAccount: 'dj-ollerganove@appspot.gserviceaccount.com',
};

const MAX_TRACKS = 80;

function clip(raw, maxLen) {
  const s = String(raw ?? '').trim();
  if (!s) return '';
  return s.length > maxLen ? s.slice(0, maxLen) : s;
}

function normalizeCamelot(raw) {
  const s = String(raw ?? '').trim().toUpperCase().replace(/\s+/g, '');
  if (!/^(1[0-2]|[1-9])[AB]$/.test(s)) return '';
  return s;
}

function normalizeBpm(raw) {
  let n = null;
  if (typeof raw === 'number' && Number.isFinite(raw)) n = raw;
  else if (typeof raw === 'string') {
    const p = Number(String(raw).replace(/[^0-9.]/g, ''));
    if (Number.isFinite(p)) n = p;
  }
  if (n == null) return null;
  const bpm = Math.round(n);
  if (bpm < 60 || bpm > 220) return null;
  return bpm;
}

function durationMsFromLabel(raw) {
  const s = String(raw ?? '').trim();
  if (!s) return null;
  const m = s.match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return null;
  const min = Number(m[1]);
  const sec = Number(m[2]);
  if (!Number.isFinite(min) || !Number.isFinite(sec) || sec > 59) return null;
  const ms = (min * 60 + sec) * 1000;
  if (ms < 30_000 || ms > 3_600_000) return null;
  return ms;
}

function normalizeMarket(raw) {
  return clip(String(raw || '').toLowerCase(), 12);
}

async function enforceUserRateLimit(uid, scope, maxRequests, windowSeconds) {
  const bucket = Math.floor(Date.now() / (windowSeconds * 1000));
  const docId = `${scope}_${uid}_${bucket}`;
  const ref = db.collection('_rate_limits').doc(docId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = snap.exists ? Number(snap.data().count || 0) : 0;
    if (count >= maxRequests) {
      throw new HttpsError('resource-exhausted', 'Zu viele Anfragen. Bitte kurz warten.');
    }
    tx.set(
      ref,
      {
        count: count + 1,
        scope,
        uid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

async function assertDjOrAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  const token = request.auth.token || {};
  let uid = request.auth.uid;
  if (token.role === 'dj_browser') {
    uid = String(token.ownerUid || '').trim();
    if (!uid) {
      throw new HttpsError('failed-precondition', 'DJ-Browser: Besitzer fehlt.');
    }
  }
  const userSnap = await db.collection('users').doc(uid).get();
  const userData = userSnap.data() || {};
  const role = String(userData.role || token.role || '').toLowerCase();
  if (role !== 'dj' && role !== 'admin' && token.role !== 'dj_browser') {
    throw new HttpsError('permission-denied', 'Nur DJ/Admin.');
  }
  return { uid, userData };
}

/**
 * Artist per name_lower finden oder anlegen.
 */
async function upsertArtist(name) {
  const display = clip(name, 200);
  const nameLower = display.toLowerCase();
  if (!nameLower) return null;
  const q = await db
    .collection('wunschbox_artist')
    .where('name_lower', '==', nameLower)
    .limit(1)
    .get();
  if (!q.empty) return q.docs[0].id;
  const ref = await db.collection('wunschbox_artist').add({
    name: display,
    name_lower: nameLower,
    created_at: FieldValue.serverTimestamp(),
    setlist_suggest_count: 0,
    global_wish_count: 0,
  });
  return ref.id;
}

/**
 * Titel upserten inkl. Camelot/Key/BPM/Dauer/Markt.
 * @param {object} opts
 * @param {boolean} opts.countAsSuggested — setlist_suggest_count++
 */
async function upsertTitle({
  artistId,
  title,
  camelot,
  musicalKey,
  bpm,
  durationLabel,
  durationMs,
  genre,
  market,
  spotifyId,
  countAsSuggested,
}) {
  const display = clip(title, 200);
  const nameLower = display.toLowerCase();
  if (!artistId || !nameLower) return null;

  const q = await db
    .collection('wunschbox_titel')
    .where('name_lower', '==', nameLower)
    .where('artist_id', '==', artistId)
    .limit(1)
    .get();

  const patch = {};
  if (camelot) patch.camelot = camelot;
  if (musicalKey) patch.musical_key = musicalKey;
  if (bpm != null) patch.bpm = bpm;
  if (durationLabel) patch.duration_label = durationLabel;
  if (durationMs != null) patch.duration_ms = durationMs;
  if (genre) patch.genre_label = genre;
  if (spotifyId) patch.spotify_id = spotifyId;

  if (q.empty) {
    const titleData = {
      name: display,
      name_lower: nameLower,
      artist_id: artistId,
      genre_ids: [],
      global_wish_count: 0,
      setlist_suggest_count: countAsSuggested ? 1 : 0,
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
      ...patch,
    };
    if (market) titleData.markets = [market];
    const ref = await db.collection('wunschbox_titel').add(titleData);
    if (countAsSuggested) {
      await db.collection('wunschbox_artist').doc(artistId).set(
        {
          setlist_suggest_count: FieldValue.increment(1),
          updated_at: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    return ref.id;
  }

  const doc = q.docs[0];
  const data = doc.data() || {};
  const update = { updated_at: FieldValue.serverTimestamp() };

  // Meta nur setzen, wenn bisher leer — verhindert Überschreiben mit schlechteren KI-Werten
  if (camelot && !clip(data.camelot, 8)) update.camelot = camelot;
  if (musicalKey && !clip(data.musical_key || data.key, 12)) {
    update.musical_key = musicalKey;
  }
  if (bpm != null && (data.bpm == null || data.bpm === 0)) update.bpm = bpm;
  if (durationLabel && !clip(data.duration_label, 12)) {
    update.duration_label = durationLabel;
  }
  if (durationMs != null && !data.duration_ms) update.duration_ms = durationMs;
  if (genre && !clip(data.genre_label, 40)) update.genre_label = genre;
  if (spotifyId && !clip(data.spotify_id, 64)) update.spotify_id = spotifyId;
  if (market) update.markets = FieldValue.arrayUnion(market);
  if (countAsSuggested) {
    update.setlist_suggest_count = FieldValue.increment(1);
  }
  if (data.setlist_suggest_count === undefined && !countAsSuggested) {
    update.setlist_suggest_count = 0;
  }

  await doc.ref.update(update);
  if (countAsSuggested) {
    await db.collection('wunschbox_artist').doc(artistId).set(
      {
        setlist_suggest_count: FieldValue.increment(1),
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  return doc.id;
}

function mapIncomingTrack(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const title = clip(raw.title, 200);
  const artist = clip(raw.artist, 200);
  if (!title || !artist) return null;
  const durationLabel = clip(raw.duration || raw.duration_label || '', 12);
  const durationMs =
    typeof raw.duration_ms === 'number' && Number.isFinite(raw.duration_ms)
      ? Math.round(raw.duration_ms)
      : durationMsFromLabel(durationLabel);
  return {
    title,
    artist,
    camelot: normalizeCamelot(raw.camelot),
    musicalKey: clip(raw.key || raw.musicalKey || raw.musical_key || '', 12),
    bpm: normalizeBpm(raw.bpm ?? raw.tempo),
    durationLabel: durationLabel || '',
    durationMs,
    genre: clip(raw.genre || raw.genre_label || '', 40),
    market: normalizeMarket(raw.market || raw.marketId),
    spotifyId: clip(raw.spotify_id || raw.spotifyId || '', 64),
  };
}

async function upsertMusicCatalogTracksHandler(request) {
  const { uid } = await assertDjOrAdmin(request);
  await enforceUserRateLimit(uid, 'upsertMusicCatalogTracks', 30, 60);

  const data = request.data || {};
  const event = clip(data.event || 'setlist_meta', 40);
  const countAsSuggested = event === 'setlist_suggested';
  const rawTracks = Array.isArray(data.tracks) ? data.tracks : [];
  const mapped = [];
  const seen = new Set();
  for (const raw of rawTracks) {
    const t = mapIncomingTrack(raw);
    if (!t) continue;
    const key = `${t.title.toLowerCase()}|${t.artist.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    mapped.push(t);
    if (mapped.length >= MAX_TRACKS) break;
  }

  let upserted = 0;
  for (const t of mapped) {
    const artistId = await upsertArtist(t.artist);
    if (!artistId) continue;
    await upsertTitle({
      artistId,
      title: t.title,
      camelot: t.camelot,
      musicalKey: t.musicalKey,
      bpm: t.bpm,
      durationLabel: t.durationLabel,
      durationMs: t.durationMs,
      genre: t.genre,
      market: t.market,
      spotifyId: t.spotifyId,
      countAsSuggested,
    });
    upserted += 1;
  }

  return {
    ok: true,
    upserted,
    counted: countAsSuggested,
    truncated: rawTracks.length > mapped.length,
  };
}

/**
 * Für saveToMusicDatabase: Meta-Felder nachziehen ohne Setlisten-Zähler.
 */
async function mergeTitleMixMeta(titleRef, existing, meta) {
  if (!titleRef || !meta) return;
  const update = {};
  const camelot = normalizeCamelot(meta.camelot);
  const musicalKey = clip(meta.key || meta.musical_key || meta.musicalKey || '', 12);
  const bpm = normalizeBpm(meta.bpm);
  const durationLabel = clip(meta.duration || meta.duration_label || '', 12);
  const durationMs =
    meta.duration_ms != null
      ? Number(meta.duration_ms)
      : durationMsFromLabel(durationLabel);
  const market = normalizeMarket(meta.market);

  if (camelot && !clip(existing.camelot, 8)) update.camelot = camelot;
  if (musicalKey && !clip(existing.musical_key || existing.key, 12)) {
    update.musical_key = musicalKey;
  }
  if (bpm != null && (existing.bpm == null || existing.bpm === 0)) {
    update.bpm = bpm;
  }
  if (durationLabel && !clip(existing.duration_label, 12)) {
    update.duration_label = durationLabel;
  }
  if (
    durationMs != null &&
    Number.isFinite(durationMs) &&
    !existing.duration_ms
  ) {
    update.duration_ms = Math.round(durationMs);
  }
  if (market) update.markets = FieldValue.arrayUnion(market);

  if (Object.keys(update).length === 0) return;
  update.updated_at = FieldValue.serverTimestamp();
  await titleRef.update(update);
}

function registerMusicCatalogCallables(exports) {
  exports.upsertMusicCatalogTracks = onCall(
    CALLABLE_OPTS,
    upsertMusicCatalogTracksHandler,
  );
}

module.exports = {
  registerMusicCatalogCallables,
  upsertMusicCatalogTracksHandler,
  mergeTitleMixMeta,
  normalizeCamelot,
  normalizeBpm,
  durationMsFromLabel,
};
