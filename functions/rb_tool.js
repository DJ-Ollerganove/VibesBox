/**
 * Rekordbox-Desktop-Tool: Admin-Pairing (10-stelliger Einmal-Code, 10 Min).
 * Kein Scheduler — Codes laufen über expiresAt ab, alte unused Codes werden beim Neu-Erzeugen revoziert.
 */
const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

const { buildTrackPayload } = require('./saved_tracks');

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const CODE_TTL_MS = 10 * 60 * 1000;
const RATE_WINDOW_MS = 15 * 60 * 1000;
const RATE_MAX_ATTEMPTS = 12;
const COL_CODES = 'rb_tool_codes';
const COL_SESSIONS = 'rb_tool_sessions';
const COL_RATE = 'rb_tool_redeem_rate';
const COL_STATE = 'rb_tool_state';
const COL_LIVE = 'rb_tool_live';
const TEN_DIGIT_RE = /^\d{10}$/;

const CALLABLE_OPTS = {
  region: 'us-central1',
  enforceAppCheck: false,
  serviceAccount: 'dj-ollerganove@appspot.gserviceaccount.com',
};

function normalizeTenDigitCode(raw) {
  if (raw == null) return null;
  const c = String(raw).replace(/\s+/g, '').trim();
  return TEN_DIGIT_RE.test(c) ? c : null;
}

function hashToolCode(code) {
  return crypto.createHash('sha256').update(`rbtool:v1:${code}`).digest('hex');
}

function hashClientIp(rawIp) {
  const ip = String(rawIp || 'unknown').trim() || 'unknown';
  return crypto.createHash('sha256').update(`rbtool-ip:v1:${ip}`).digest('hex').slice(0, 40);
}

function generateTenDigitCode() {
  return String(crypto.randomInt(0, 10000000000)).padStart(10, '0');
}

async function assertCallerAdmin(uid) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists || snap.data()?.admin !== true) {
    throw new HttpsError('permission-denied', 'Nur Admin.');
  }
}

async function assertRedeemRateLimit(ipHash) {
  const ref = db.collection(COL_RATE).doc(ipHash);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const windowStart = data?.windowStart?.toMillis?.() || 0;
    let count = Number(data?.count || 0);
    if (!windowStart || now - windowStart > RATE_WINDOW_MS) {
      tx.set(ref, {
        windowStart: Timestamp.fromMillis(now),
        count: 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    if (count >= RATE_MAX_ATTEMPTS) {
      throw new HttpsError('resource-exhausted', 'Zu viele Versuche. Bitte kurz warten.');
    }
    tx.update(ref, {
      count: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

async function revokePendingCodeForOwner(uid) {
  const stateRef = db.collection(COL_STATE).doc(uid);
  const stateSnap = await stateRef.get();
  const pending = String(stateSnap.data()?.pendingCodeHash || '').trim();
  if (!pending) return;
  const codeRef = db.collection(COL_CODES).doc(pending);
  const codeSnap = await codeRef.get();
  if (codeSnap.exists && codeSnap.data()?.used !== true) {
    await codeRef.update({
      revoked: true,
      revokedAt: FieldValue.serverTimestamp(),
      revokeReason: 'replaced',
    });
  }
  await stateRef.set({
    pendingCodeHash: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function deactivateOwnerSessions(ownerUid, reason) {
  const stateSnap = await db.collection(COL_STATE).doc(ownerUid).get();
  const sessionId = String(stateSnap.data()?.activeSessionId || '').trim();
  if (!sessionId) return;
  await db.collection(COL_SESSIONS).doc(sessionId).set({
    active: false,
    endedReason: reason,
    endedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

function createToolCustomToken(sessionId, ownerUid) {
  return admin.auth().createCustomToken(`rbtool_${sessionId}`, {
    role: 'rb_tool',
    sessionId,
    ownerUid,
  });
}

function isCodeExpired(codeData, nowMs = Date.now()) {
  const exp = codeData?.expiresAt?.toMillis?.() || 0;
  return !exp || nowMs > exp;
}

async function createRbToolCodeHandler(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  const uid = request.auth.uid;
  await assertCallerAdmin(uid);
  await revokePendingCodeForOwner(uid);
  await deactivateOwnerSessions(uid, 'new_code');
  await db.collection(COL_LIVE).doc(uid).set({
    connected: false,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  const expiresAt = Timestamp.fromMillis(Date.now() + CODE_TTL_MS);
  let code = null;
  let codeHash = null;
  for (let attempt = 0; attempt < 25; attempt += 1) {
    const candidate = generateTenDigitCode();
    const docId = hashToolCode(candidate);
    const ref = db.collection(COL_CODES).doc(docId);
    const claimed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists && !isCodeExpired(snap.data()) && snap.data()?.used !== true) {
        return false;
      }
      tx.set(ref, {
        createdBy: uid,
        codeHash: docId,
        expiresAt,
        used: false,
        revoked: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (claimed) {
      code = candidate;
      codeHash = docId;
      break;
    }
  }
  if (!code || !codeHash) {
    throw new HttpsError('internal', 'Code konnte nicht erzeugt werden.');
  }

  await db.collection(COL_STATE).doc(uid).set({
    pendingCodeHash: codeHash,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    code,
    expiresAtMillis: expiresAt.toMillis(),
  };
}

async function getRbToolCodeStatusHandler(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  const uid = request.auth.uid;
  await assertCallerAdmin(uid);
  const code = normalizeTenDigitCode(request.data?.code);
  if (!code) {
    throw new HttpsError('invalid-argument', 'Code muss 10 Ziffern haben.');
  }
  const snap = await db.collection(COL_CODES).doc(hashToolCode(code)).get();
  if (!snap.exists || snap.data()?.createdBy !== uid) {
    return { exists: false, used: false, revoked: false, expired: true };
  }
  const data = snap.data();
  return {
    exists: true,
    used: data.used === true,
    revoked: data.revoked === true,
    expired: isCodeExpired(data),
  };
}

async function redeemRbToolCodeHandler(request) {
  const code = normalizeTenDigitCode(request.data?.code);
  if (!code) {
    throw new HttpsError('invalid-argument', 'Code muss 10 Ziffern haben.');
  }
  const rawIp =
    request.rawRequest?.ip ||
    request.rawRequest?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ||
    'unknown';
  await assertRedeemRateLimit(hashClientIp(rawIp));

  const codeRef = db.collection(COL_CODES).doc(hashToolCode(code));
  const codeSnap = await codeRef.get();
  if (!codeSnap.exists) {
    throw new HttpsError('not-found', 'Code ungültig.');
  }
  const codeData = codeSnap.data();
  if (codeData.revoked === true) {
    throw new HttpsError('failed-precondition', 'Code wurde ersetzt. Bitte neuen Code erzeugen.');
  }
  if (isCodeExpired(codeData)) {
    throw new HttpsError('deadline-exceeded', 'Code abgelaufen. Bitte neuen Code erzeugen.');
  }
  const ownerUid = String(codeData.createdBy || '').trim();
  if (!ownerUid) {
    throw new HttpsError('internal', 'Account fehlt am Code.');
  }

  if (codeData.used === true) {
    const existingSessionId = String(codeData.sessionId || '').trim();
    if (!existingSessionId) {
      throw new HttpsError('failed-precondition', 'Code bereits verwendet. Bitte neuen Code erzeugen.');
    }
    const sess = await db.collection(COL_SESSIONS).doc(existingSessionId).get();
    if (!sess.exists || sess.data()?.active !== true) {
      throw new HttpsError('failed-precondition', 'Code bereits verwendet. Bitte neuen Code erzeugen.');
    }
    let customToken;
    try {
      customToken = await createToolCustomToken(existingSessionId, ownerUid);
    } catch (tokenErr) {
      console.error('createCustomToken rb_tool retry:', tokenErr);
      throw new HttpsError('internal', 'Login konnte nicht erstellt werden.');
    }
    return { customToken, sessionId: existingSessionId, ownerUid };
  }

  const sessionId = crypto.randomUUID();
  let customToken;
  try {
    customToken = await createToolCustomToken(sessionId, ownerUid);
  } catch (tokenErr) {
    console.error('createCustomToken rb_tool:', tokenErr);
    throw new HttpsError('internal', 'Login konnte nicht erstellt werden.');
  }

  await deactivateOwnerSessions(ownerUid, 'replaced');

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(codeRef);
    if (!fresh.exists) {
      throw new HttpsError('not-found', 'Code ungültig oder abgelaufen.');
    }
    const cd = fresh.data();
    if (cd.revoked === true || cd.used === true || isCodeExpired(cd)) {
      throw new HttpsError('failed-precondition', 'Code ungültig oder abgelaufen.');
    }
    tx.update(codeRef, {
      used: true,
      usedAt: FieldValue.serverTimestamp(),
      sessionId,
    });
    tx.set(db.collection(COL_SESSIONS).doc(sessionId), {
      ownerUid,
      active: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(db.collection(COL_STATE).doc(ownerUid), {
      pendingCodeHash: FieldValue.delete(),
      activeSessionId: sessionId,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { customToken, sessionId, ownerUid };
}

async function revokeRbToolSessionHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  const token = request.auth.token || {};
  let sessionId = '';
  let ownerUid = '';
  if (token.role === 'rb_tool') {
    sessionId = String(token.sessionId || '').trim();
    ownerUid = String(token.ownerUid || '').trim();
  } else {
    await assertCallerAdmin(request.auth.uid);
    ownerUid = request.auth.uid;
    const state = await db.collection(COL_STATE).doc(ownerUid).get();
    sessionId = String(state.data()?.activeSessionId || '').trim();
    if (!sessionId) {
      const live = await db.collection(COL_LIVE).doc(ownerUid).get();
      sessionId = String(live.data()?.sessionId || '').trim();
    }
  }
  if (!ownerUid) {
    throw new HttpsError('permission-denied', 'Session ungültig.');
  }
  if (sessionId) {
    await db.collection(COL_SESSIONS).doc(sessionId).set({
      active: false,
      endedReason: 'logout',
      endedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    await db.collection(COL_STATE).doc(ownerUid).set({
      activeSessionId: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  const livePatch = {
    connected: false,
    nowPlaying: null,
    decks: [],
    history: [],
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (sessionId) livePatch.sessionId = sessionId;
  await db.collection(COL_LIVE).doc(ownerUid).set(livePatch, { merge: true });
  return { ok: true };
}

function partyMillis(data, posixKey, stampKey) {
  const posix = Number(data?.[posixKey] || 0);
  if (Number.isFinite(posix) && posix > 0) return posix * 1000;
  const stamp = data?.[stampKey];
  if (stamp && typeof stamp.toMillis === 'function') return stamp.toMillis();
  return 0;
}

/** Gleiche Fenster-Regel wie ActivePartyService: Start erreicht, Ende noch nicht. */
function isOwnerPartyRunningNow(data, nowMs) {
  if (!data || typeof data !== 'object') return false;
  if (
    data.lifecycle_status === 'finished' ||
    data.lifecycle_status === 'standby' ||
    data.finished_at != null ||
    data.status === 'beendet' ||
    data.status === 'ended'
  ) {
    return false;
  }
  const nowUnix = Math.floor(nowMs / 1000);
  const startPosix = Number(data.start_time_posix);
  const endPosix = Number(data.end_time_posix);
  if (
    Number.isFinite(startPosix) && startPosix > 0 &&
    Number.isFinite(endPosix) && endPosix > 0
  ) {
    return nowUnix >= startPosix && nowUnix < endPosix;
  }
  const start = partyMillis(data, 'start_time_posix', 'start_date');
  const end = partyMillis(data, 'end_time_posix', 'end_date');
  if (start > 0 && end > 0) return nowMs >= start && nowMs < end;
  return false;
}

function pickOwnerLiveParty(docs, nowMs) {
  let best = null;
  let bestStart = -1;
  docs.forEach((doc) => {
    const data = doc.data() || {};
    if (!isOwnerPartyRunningNow(data, nowMs)) return;
    const start = partyMillis(data, 'start_time_posix', 'start_date');
    if (start >= bestStart) {
      bestStart = start;
      best = doc;
    }
  });
  return best;
}

function compactWishName(x) {
  const direct = String(x.name || x.display_name || x.guest_name || '').trim();
  if (direct) return direct;
  if (typeof x.requested_by === 'string') return x.requested_by.trim();
  if (Array.isArray(x.requested_by)) {
    for (const entry of x.requested_by) {
      const n = String(entry || '').trim();
      if (n) return n;
    }
  }
  return '';
}

function compactWish(doc) {
  const x = doc.data() || {};
  const created = x.createdAt?.toMillis?.() || x.created_at?.toMillis?.() || 0;
  return {
    id: doc.id,
    title: String(x.title || x.song || '').trim(),
    artist: String(x.artist || '').trim(),
    status: String(x.status || 'pending'),
    is_pre_wish: x.is_pre_wish === true,
    pre_wish_published: x.pre_wish_published === true,
    name: compactWishName(x),
    greeting: String(x.greeting || x.gruss || x.message || '').trim(),
    greeting_translation: String(x.greeting_translation || '').trim(),
    greeting_translation_lang: String(x.greeting_translation_lang || '').trim(),
    client_id: String(x.client_id || x.device_id || '').trim(),
    user_id: String(x.user_id || '').trim(),
    createdAtMillis: created,
  };
}

function isUnpublishedPreWish(wish) {
  return wish.is_pre_wish === true && wish.pre_wish_published !== true;
}

async function resolveOwnerLiveParty(ownerUid, cachedPartyId) {
  const nowMs = Date.now();
  if (cachedPartyId) {
    const snap = await db.collection('parties').doc(cachedPartyId).get();
    if (snap.exists && String(snap.data()?.created_by || '') === ownerUid) {
      const picked = pickOwnerLiveParty([snap], nowMs);
      if (picked) return picked;
    }
  }
  const nowUnix = Math.floor(nowMs / 1000);
  let partyDocs = [];
  try {
    const snap = await db.collection('parties')
      .where('created_by', '==', ownerUid)
      .where('start_time_posix', '<=', nowUnix + 120)
      .orderBy('start_time_posix', 'desc')
      .limit(8)
      .get();
    partyDocs = snap.docs;
  } catch (_) {
    const snap = await db.collection('parties')
      .where('created_by', '==', ownerUid)
      .limit(40)
      .get();
    partyDocs = snap.docs;
  }
  return pickOwnerLiveParty(partyDocs, nowMs + 90000);
}

function compactSetlistTracks(data) {
  const raw = Array.isArray(data && data.tracks) ? data.tracks : [];
  const out = [];
  raw.forEach((item, index) => {
    if (!item || typeof item !== 'object' || item.moved === true) return;
    const title = String(item.title || '').trim();
    const artist = String(item.artist || '').trim();
    if (!title || !artist) return;
    out.push({
      index,
      title,
      artist,
      bpm: item.bpm == null ? null : Number(item.bpm),
      camelot: item.camelot == null ? '' : String(item.camelot),
      reason: String(item.reason || ''),
    });
  });
  return out;
}

/** Einmalig: bereits gespielte Titel der Party (music_history). Kein Listener. */
async function loadPartyPlayed(partyId) {
  const [bySnake, byCamel] = await Promise.all([
    db.collection('music_history').where('party_id', '==', partyId).limit(4).get(),
    db.collection('music_history').where('partyId', '==', partyId).limit(4).get(),
  ]);
  const ids = [];
  const seenIds = new Set();
  for (const snap of [bySnake, byCamel]) {
    snap.docs.forEach((doc) => {
      if (seenIds.has(doc.id)) return;
      seenIds.add(doc.id);
      ids.push(doc.id);
    });
  }
  const played = [];
  const seen = new Set();
  for (const id of ids) {
    const tracks = await db.collection('music_history').doc(id).collection('tracks')
      .orderBy('timestamp', 'desc')
      .limit(200)
      .get();
    for (const doc of tracks.docs) {
      const data = doc.data() || {};
      const title = String(data.title || '').trim();
      const artist = String(data.artist || '').trim();
      if (!title) continue;
      const key = `${title.toLowerCase()}|${artist.toLowerCase()}`;
      if (seen.has(key)) continue;
      seen.add(key);
      played.push({
        title: title.slice(0, 200),
        artist: artist.slice(0, 200),
      });
      if (played.length >= 250) return played;
    }
  }
  return played;
}

/** Lesende Wunsch-/Setlist-Ansicht für das Rekordbox-Tool. Kein Sleep, nur aktuelle Party. */
async function getRbToolWishboardHandler(request) {
  const token = request.auth?.token;
  if (!request.auth || token?.role !== 'rb_tool') {
    throw new HttpsError('unauthenticated', 'Tool-Session erforderlich.');
  }
  const sessionId = String(token.sessionId || '').trim();
  const ownerUid = String(token.ownerUid || '').trim();
  if (!sessionId || !ownerUid) {
    throw new HttpsError('permission-denied', 'Session ungültig.');
  }
  const sess = await db.collection(COL_SESSIONS).doc(sessionId).get();
  if (!sess.exists || sess.data()?.active !== true || String(sess.data()?.ownerUid || '') !== ownerUid) {
    throw new HttpsError('permission-denied', 'Session inaktiv.');
  }

  const req = request.data && typeof request.data === 'object' ? request.data : {};
  await touchToolInstall(ownerUid, req.install);
  const includeSetlist = req.includeSetlist !== false;
  const includePre = req.includePre !== false;
  const includeSongRec = req.includeSongRec !== false;
  const partyOnly = req.partyOnly === true;
  const cachedPartyId = String(req.partyId || '').trim();

  const partyDoc = await resolveOwnerLiveParty(ownerUid, cachedPartyId);
  if (!partyDoc) {
    if (req.playedOnly === true) {
      return { partyId: null, partyName: null, played: [], playedOnly: true };
    }
    const empty = {
      partyId: null,
      partyName: null,
      wishes: [],
      setlist: [],
      preOmitted: !includePre,
      setlistOmitted: !includeSetlist,
    };
    const userSnap = await db.collection('users').doc(ownerUid).get();
    const userData = userSnap.exists ? userSnap.data() : null;
    empty.syncSend = userData?.vibesbox_sync_enabled === true;
    empty.showGreetingTranslations = userData?.show_greeting_translations !== false;
    empty.djAdmin = userData?.admin === true;
    if (includeSongRec) {
      empty.songRec = compactSongRec(userData);
    }
    return empty;
  }

  const partyNameEarly = String(partyDoc.data()?.party_name || partyDoc.data()?.partyName || '').trim();
  if (req.playedOnly === true) {
    const played = await loadPartyPlayed(partyDoc.id);
    return {
      partyId: partyDoc.id,
      partyName: partyNameEarly || null,
      played,
      playedOnly: true,
    };
  }
  if (partyOnly) {
    const userSnapOnly = await db.collection('users').doc(ownerUid).get();
    const userOnly = userSnapOnly.exists ? userSnapOnly.data() : null;
    return {
      partyId: partyDoc.id,
      partyName: partyNameEarly || null,
      wishes: [],
      partyOnly: true,
      preOmitted: true,
      setlistOmitted: true,
      syncSend: userOnly?.vibesbox_sync_enabled === true,
      showGreetingTranslations: userOnly?.show_greeting_translations !== false,
      djAdmin: userOnly?.admin === true,
    };
  }

  const wishesRef = db.collection('parties').doc(partyDoc.id).collection('wishes');
  const [wishesSnap, setlistSnap, userSnap, preSnap] = await Promise.all([
    wishesRef.orderBy('createdAt', 'desc').limit(400).get()
      .catch(() => wishesRef.limit(400).get()),
    includeSetlist
      ? db.collection('dj_setlists').doc(partyDoc.id).get()
      : Promise.resolve(null),
    db.collection('users').doc(ownerUid).get(),
    includePre
      ? wishesRef.where('is_pre_wish', '==', true).limit(500).get()
        .catch(() => ({ docs: [] }))
      : Promise.resolve(null),
  ]);

  const byId = new Map();
  wishesSnap.docs.forEach((doc) => {
    const wish = compactWish(doc);
    if (!includePre && isUnpublishedPreWish(wish)) return;
    byId.set(wish.id, wish);
  });
  if (includePre && preSnap && Array.isArray(preSnap.docs)) {
    preSnap.docs.forEach((doc) => {
      const wish = compactWish(doc);
      if (isUnpublishedPreWish(wish)) byId.set(wish.id, wish);
    });
  }

  const wishes = [...byId.values()]
    .sort((a, b) => (b.createdAtMillis || 0) - (a.createdAtMillis || 0));
  const partyName = String(partyDoc.data()?.party_name || partyDoc.data()?.partyName || '').trim();
  const out = {
    partyId: partyDoc.id,
    partyName: partyName || null,
    wishes,
    preOmitted: !includePre,
    setlistOmitted: !includeSetlist,
  };
  if (includeSetlist) {
    out.setlist = compactSetlistTracks(setlistSnap && setlistSnap.exists ? setlistSnap.data() : null);
  }
  const userData = userSnap && userSnap.exists ? userSnap.data() : null;
  out.syncSend = userData?.vibesbox_sync_enabled === true;
  out.showGreetingTranslations = userData?.show_greeting_translations !== false;
  out.djAdmin = userData?.admin === true;
  if (includeSongRec) {
    out.songRec = compactSongRec(userData);
  }
  return out;
}

async function touchToolInstall(ownerUid, raw) {
  if (!raw || typeof raw !== 'object') return;
  try {
    const deviceId = String(raw.deviceId || '').trim();
    const version = String(raw.version || '').trim();
    const os = String(raw.os || '').trim();
    if (!/^[a-zA-Z0-9_-]{8,64}$/.test(deviceId)) return;
    if (!/^\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(version)) return;
    if (!os || os.length > 40) return;
    const platform = os.toLowerCase().startsWith('windows') ? 'windows' : 'macos';
    const id = `${ownerUid}_${deviceId}`.slice(0, 180);
    await db.collection('rb_tool_installs').doc(id).set({
      ownerUid,
      deviceId,
      version,
      os,
      platform,
      lastSeen: FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (_) {}
}

function compactSongRec(data) {
  const scope = String(data?.song_rec_scope || '').trim();
  const familiarity = String(data?.song_rec_familiarity || '').trim();
  const countRaw = Number(data?.song_rec_count);
  const count = Number.isFinite(countRaw)
    ? Math.max(1, Math.min(20, Math.round(countRaw)))
    : 5;
  return {
    enabled: data?.song_rec_enabled !== false,
    scope: ['strict', 'similar', 'bold'].includes(scope) ? scope : 'similar',
    familiarity: ['hits', 'mix'].includes(familiarity) ? familiarity : 'hits',
    allowSameArtist: data?.song_rec_same_artist !== false,
    count,
  };
}

/** Dieselben 4 Felder wie die App (users/{ownerUid}), ein Write nur bei Änderung. */
async function setRbToolSongRecHandler(request) {
  const token = request.auth?.token;
  if (!request.auth || token?.role !== 'rb_tool') {
    throw new HttpsError('unauthenticated', 'Tool-Session erforderlich.');
  }
  const sessionId = String(token.sessionId || '').trim();
  const ownerUid = String(token.ownerUid || '').trim();
  if (!sessionId || !ownerUid) {
    throw new HttpsError('permission-denied', 'Session ungültig.');
  }
  const sess = await db.collection(COL_SESSIONS).doc(sessionId).get();
  if (!sess.exists || sess.data()?.active !== true
      || String(sess.data()?.ownerUid || '') !== ownerUid) {
    throw new HttpsError('permission-denied', 'Session inaktiv.');
  }

  const data = request.data || {};
  if (typeof data.enabled !== 'boolean') {
    throw new HttpsError('invalid-argument', 'enabled muss bool sein');
  }
  if (typeof data.allowSameArtist !== 'boolean') {
    throw new HttpsError('invalid-argument', 'allowSameArtist muss bool sein');
  }
  const scope = String(data.scope || '').trim();
  const familiarity = String(data.familiarity || '').trim();
  if (!['strict', 'similar', 'bold'].includes(scope)) {
    throw new HttpsError('invalid-argument', 'song_rec_scope ungültig');
  }
  if (!['hits', 'mix'].includes(familiarity)) {
    throw new HttpsError('invalid-argument', 'song_rec_familiarity ungültig');
  }
  const countRaw = Number(data.count);
  if (!Number.isFinite(countRaw) || countRaw < 1 || countRaw > 20) {
    throw new HttpsError('invalid-argument', 'count ungültig');
  }
  const count = Math.round(countRaw);

  const patch = {
    song_rec_enabled: data.enabled,
    song_rec_scope: scope,
    song_rec_familiarity: familiarity,
    song_rec_same_artist: data.allowSameArtist,
    song_rec_count: count,
  };
  await db.collection('users').doc(ownerUid).set(patch, { merge: true });
  return compactSongRec(patch);
}

const DEFAULT_IGNORED = ['Remix', 'Mix', 'Edit', 'Radio', 'Club', 'Extended', 'Video', 'Version'];
let matchSettingsCache = { at: 0, threshold: 0.85, ignored: null };

function canonicalDup(s) {
  let t = String(s || '').trim().replace(/\s+/g, ' ').toLowerCase();
  t = t.replace(/ä/g, 'a').replace(/ö/g, 'o').replace(/ü/g, 'u').replace(/ß/g, 'ss');
  t = t.replace(/[^\w\s]/g, '');
  return t.replace(/\s+/g, ' ').trim();
}

function normalizeDup(text, ignored) {
  let s = String(text || '').trim();
  if (!s) return '';
  s = s.replace(/\s*\([^)]*\)\s*/g, ' ');
  s = s.replace(/\s*\[[^\]]*\]\s*/g, ' ');
  const list = ignored && ignored.length ? ignored : DEFAULT_IGNORED;
  const escaped = list
    .map((k) => String(k).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
    .filter(Boolean);
  if (escaped.length) {
    const re = new RegExp('\\s+(' + escaped.join('|') + ')\\s*$', 'i');
    let prev = '';
    while (prev !== s) {
      prev = s;
      s = s.replace(re, ' ').trim();
    }
  }
  return canonicalDup(s);
}

function compareTwoStrings(first, second) {
  const a = String(first || '').replace(/\s+/g, '');
  const b = String(second || '').replace(/\s+/g, '');
  if (a === b) return 1;
  if (a.length < 2 || b.length < 2) return 0;
  const bigrams = new Map();
  for (let i = 0; i < a.length - 1; i++) {
    const bg = a.substring(i, i + 2);
    bigrams.set(bg, (bigrams.get(bg) || 0) + 1);
  }
  let inter = 0;
  for (let i = 0; i < b.length - 1; i++) {
    const bg = b.substring(i, i + 2);
    const count = bigrams.get(bg) || 0;
    if (count > 0) {
      bigrams.set(bg, count - 1);
      inter++;
    }
  }
  return (2 * inter) / (a.length + b.length - 2);
}

async function loadMatchSettings() {
  if (Date.now() - matchSettingsCache.at < 10 * 60 * 1000) return matchSettingsCache;
  try {
    const doc = await db.collection('party_settings').doc('current').get();
    const data = doc.exists ? doc.data() : null;
    const rawT = data && data.duplicate_threshold;
    const threshold = typeof rawT === 'number' && rawT > 0 && rawT <= 1 ? rawT : 0.85;
    const rawI = data && data.ignored_keywords;
    const ignored = Array.isArray(rawI)
      ? rawI.map((x) => String(x || '').trim()).filter(Boolean)
      : null;
    matchSettingsCache = { at: Date.now(), threshold, ignored };
  } catch (_) {
    matchSettingsCache = { at: Date.now(), threshold: 0.85, ignored: null };
  }
  return matchSettingsCache;
}

function wishQueued(data) {
  return data.is_pre_wish === true && data.pre_wish_published !== true;
}

/**
 * Ein Aufruf pro neu erkanntem Titel. Gleiche Schwelle wie die App:
 * Offen, Vorab und Setliste in einem Batch. Kein Poll, keine Min-Instanz.
 */
async function markRbToolRecognizedHandler(request) {
  const token = request.auth?.token;
  if (!request.auth || token?.role !== 'rb_tool') {
    throw new HttpsError('unauthenticated', 'Tool-Session erforderlich.');
  }
  const sessionId = String(token.sessionId || '').trim();
  const ownerUid = String(token.ownerUid || '').trim();
  if (!sessionId || !ownerUid) {
    throw new HttpsError('permission-denied', 'Session ungültig.');
  }
  const sess = await db.collection(COL_SESSIONS).doc(sessionId).get();
  if (!sess.exists || sess.data()?.active !== true || String(sess.data()?.ownerUid || '') !== ownerUid) {
    throw new HttpsError('permission-denied', 'Session inaktiv.');
  }

  const req = request.data && typeof request.data === 'object' ? request.data : {};
  const title = String(req.title || '').trim().slice(0, 200);
  const artist = String(req.artist || '').trim().slice(0, 200);
  if (!title) return { open: 0, pre: 0, setlist: 0, wishIds: [], movedIndexes: [] };

  const partyDoc = await resolveOwnerLiveParty(ownerUid, String(req.partyId || '').trim());
  if (!partyDoc) return { open: 0, pre: 0, setlist: 0, wishIds: [], movedIndexes: [] };

  const settings = await loadMatchSettings();
  const threshold = settings.threshold;
  const ignored = settings.ignored;
  const normTitle = normalizeDup(title, ignored);
  const normArtist = normalizeDup(artist, ignored);
  const wishesRef = db.collection('parties').doc(partyDoc.id).collection('wishes');
  const [openSnap, preSnap, setlistSnap] = await Promise.all([
    wishesRef.where('status', '==', 'pending').limit(200).get(),
    wishesRef.where('status', '==', 'pending').where('is_pre_wish', '==', true).limit(200).get(),
    db.collection('dj_setlists').doc(partyDoc.id).get(),
  ]);

  const wishIds = [];
  const seen = new Set();
  let openCount = 0;
  let preCount = 0;
  const consider = (doc, queuedOnly) => {
    if (seen.has(doc.id)) return;
    const data = doc.data() || {};
    if (String(data.status || 'pending') !== 'pending') return;
    const queued = wishQueued(data);
    if (queuedOnly ? !queued : queued) return;
    const wishTitle = String(data.title || data.song || '').trim();
    const wishArtist = String(data.artist || '').trim();
    if (!wishTitle || !wishArtist) return;
    const avg = (
      compareTwoStrings(normTitle, normalizeDup(wishTitle, ignored)) +
      compareTwoStrings(normArtist, normalizeDup(wishArtist, ignored))
    ) / 2;
    if (avg < threshold) return;
    seen.add(doc.id);
    wishIds.push(doc.id);
    if (queuedOnly) preCount++;
    else openCount++;
  };
  openSnap.docs.forEach((doc) => consider(doc, false));
  preSnap.docs.forEach((doc) => consider(doc, true));

  const movedIndexes = [];
  const rawTracks = setlistSnap.exists && Array.isArray(setlistSnap.data()?.tracks)
    ? setlistSnap.data().tracks.slice()
    : [];
  rawTracks.forEach((item, index) => {
    if (!item || typeof item !== 'object' || item.moved === true) return;
    const trackTitle = String(item.title || '').trim();
    const trackArtist = String(item.artist || '').trim();
    if (!trackTitle || !trackArtist) return;
    const avg = (
      compareTwoStrings(normTitle, normalizeDup(trackTitle, ignored)) +
      compareTwoStrings(normArtist, normalizeDup(trackArtist, ignored))
    ) / 2;
    if (avg < threshold) return;
    movedIndexes.push(index);
  });

  if (!wishIds.length && !movedIndexes.length) {
    return { open: 0, pre: 0, setlist: 0, wishIds: [], movedIndexes: [] };
  }

  const now = FieldValue.serverTimestamp();
  const batch = db.batch();
  wishIds.forEach((id) => {
    batch.update(wishesRef.doc(id), {
      status: 'played',
      auto_recognized: true,
      recognized_at: now,
      played_at: now,
      playedAt: now,
    });
  });
  movedIndexes.forEach((index) => {
    const item = rawTracks[index];
    rawTracks[index] = Object.assign({}, item, { moved: true });
    const wishRef = wishesRef.doc();
    batch.set(wishRef, {
      name: '',
      title: String(item.title || '').trim(),
      artist: String(item.artist || '').trim(),
      status: 'played',
      createdAt: now,
      duplicate_count: 0,
      requested_by: ['__from_setlist__'],
      greetings: [],
      is_duplicate: false,
      is_registered_user: true,
      is_registered_users: {},
      client_id: ownerUid,
      party_id: partyDoc.id,
      dj_id: ownerUid,
      djId: ownerUid,
      isSeen: true,
      is_dj_wish: true,
      from_setlist: true,
      auto_recognized: true,
      playedAt: now,
      played_at: now,
      recognized_at: now,
    });
  });
  if (movedIndexes.length) {
    batch.update(db.collection('dj_setlists').doc(partyDoc.id), { tracks: rawTracks });
  }
  await batch.commit();
  return {
    open: openCount,
    pre: preCount,
    setlist: movedIndexes.length,
    wishIds,
    movedIndexes,
  };
}

function normWishText(raw) {
  return String(raw || '').toLowerCase().replace(/\s+/g, ' ').trim();
}

async function blacklistHas(ownerUid, title, artist) {
  const snap = await db.collection('dj_song_blacklists').doc(ownerUid).get();
  const entries = Array.isArray(snap.data()?.entries) ? snap.data().entries : [];
  const nt = normWishText(title);
  const na = normWishText(artist);
  return entries.some((row) => row && normWishText(row.title) === nt && normWishText(row.artist) === na);
}

async function assertActiveToolOwner(request) {
  const token = request.auth?.token;
  if (!request.auth || token?.role !== 'rb_tool') {
    throw new HttpsError('unauthenticated', 'Tool-Session erforderlich.');
  }
  const sessionId = String(token.sessionId || '').trim();
  const ownerUid = String(token.ownerUid || '').trim();
  if (!sessionId || !ownerUid) {
    throw new HttpsError('permission-denied', 'Session ungültig.');
  }
  const sess = await db.collection(COL_SESSIONS).doc(sessionId).get();
  if (!sess.exists || sess.data()?.active !== true || String(sess.data()?.ownerUid || '') !== ownerUid) {
    throw new HttpsError('permission-denied', 'Session inaktiv.');
  }
  return ownerUid;
}

async function ownedParty(ownerUid, partyId) {
  const id = String(partyId || '').trim();
  if (!id) throw new HttpsError('invalid-argument', 'partyId fehlt.');
  const party = await db.collection('parties').doc(id).get();
  if (!party.exists || String(party.data()?.created_by || '') !== ownerUid) {
    throw new HttpsError('permission-denied', 'Party gehört nicht zu diesem DJ.');
  }
  return party;
}

async function partyWishRefs(partyId, wishIds) {
  const refs = [];
  for (const raw of wishIds.slice(0, 40)) {
    const id = String(raw || '').trim();
    if (!id) continue;
    const ref = db.collection('parties').doc(partyId).collection('wishes').doc(id);
    const snap = await ref.get();
    if (snap.exists) refs.push(snap);
  }
  return refs;
}

async function rbToolWishActionHandler(request) {
  const ownerUid = await assertActiveToolOwner(request);
  const data = request.data && typeof request.data === 'object' ? request.data : {};
  const action = String(data.action || '').trim();
  const party = await ownedParty(ownerUid, data.partyId);
  const partyId = party.id;
  const wishIds = Array.isArray(data.wishIds) ? data.wishIds : [];
  const now = FieldValue.serverTimestamp();
  const wishes = db.collection('parties').doc(partyId).collection('wishes');

  if (action === 'play' || action === 'reject' || action === 'delete') {
    const snaps = await partyWishRefs(partyId, wishIds);
    if (!snaps.length) {
      throw new HttpsError('failed-precondition', 'Wunsch nicht gefunden.');
    }
    const gone = FieldValue.delete();
    const batch = db.batch();
    for (const snap of snaps) {
      if (action === 'delete') {
        batch.delete(snap.ref);
      } else if (action === 'play') {
        batch.update(snap.ref, {
          status: 'played',
          status_changed_at: now,
          playedAt: now,
          played_at: now,
          recognized_at: now,
          rejectedAt: gone,
          rejected_at: gone,
        });
      } else {
        batch.update(snap.ref, {
          status: 'rejected',
          status_changed_at: now,
          rejectedAt: now,
          rejected_at: now,
          playedAt: gone,
          played_at: gone,
        });
      }
    }
    await batch.commit();
    if (action === 'delete') {
      await db.collection('admin_stats').doc('wishes').set({
        deleted_count: FieldValue.increment(snaps.length),
      }, { merge: true });
    }
    return { ok: true, count: snaps.length };
  }

  if (action === 'block') {
    const snaps = await partyWishRefs(partyId, wishIds);
    const clientIds = new Set();
    for (const snap of snaps) {
      const cid = String(snap.data()?.client_id || snap.data()?.device_id || '').trim();
      if (cid) clientIds.add(cid);
    }
    if (!clientIds.size) {
      throw new HttpsError('failed-precondition', 'Gast hat keine Geräte-ID.');
    }
    const batch = db.batch();
    const partyCode = String(party.data()?.party_code || '').trim();
    for (const cid of clientIds) {
      const block = {
        block_status: 'party_specific',
        blocked_at: now,
        dj_id: ownerUid,
        client_id: cid,
        party_id: partyId,
        name: String(snaps[0].data()?.name || '').slice(0, 80),
        source: 'rb_tool',
      };
      if (partyCode) block.party_code = partyCode;
      const uid = String(snaps[0].data()?.user_id || '').trim();
      if (uid) block.user_id = uid;
      batch.set(db.collection('blocked_guests').doc(`${cid}_${partyId}`), block, { merge: true });
      batch.set(db.collection('blocked_devices').doc(cid), {
        block_status: 'permanent',
        blocked_at: now,
        dj_id: ownerUid,
        client_id: cid,
        device_id: cid,
        party_id: partyId,
        source: 'dj_block_guest',
      }, { merge: true });
    }
    await batch.commit();
    for (const cid of clientIds) {
      let found = await wishes.where('client_id', '==', cid).limit(100).get();
      if (found.empty) {
        found = await wishes.where('device_id', '==', cid).limit(100).get();
      }
      const reject = db.batch();
      let n = 0;
      for (const doc of found.docs) {
        if (String(doc.data()?.status || '') === 'rejected') continue;
        reject.update(doc.ref, {
          status: 'rejected',
          rejectedAt: now,
          rejected_at: now,
          rejection_reason: 'user_blocked',
          auto_rejected_by_block: true,
        });
        n += 1;
      }
      if (n) await reject.commit();
    }
    return { ok: true };
  }

  if (action === 'favorite') {
    const snaps = await partyWishRefs(partyId, wishIds);
    if (!snaps.length) throw new HttpsError('failed-precondition', 'Wunsch nicht gefunden.');
    const next = !snaps.some((snap) => snap.data()?.is_favorite === true);
    const batch = db.batch();
    for (const snap of snaps) batch.update(snap.ref, { is_favorite: next });
    await batch.commit();
    return { ok: true, on: next };
  }

  if (action === 'pin') {
    const ids = wishIds.map((id) => String(id || '').trim()).filter(Boolean);
    if (!ids.length) throw new HttpsError('failed-precondition', 'Wunsch nicht gefunden.');
    const raw = Array.isArray(party.data()?.open_wish_pinned_keys)
      ? party.data().open_wish_pinned_keys.map((id) => String(id || '').trim()).filter(Boolean)
      : [];
    const hit = raw.find((id) => ids.includes(id));
    let pins = raw.slice();
    let on = false;
    if (hit) {
      pins = pins.filter((id) => id !== hit);
    } else if (pins.length >= 3) {
      return { ok: true, on: false, limit: true };
    } else {
      pins = [ids[0], ...pins.filter((id) => id !== ids[0])].slice(0, 3);
      on = true;
    }
    await party.ref.set({
      open_wish_pinned_keys: pins,
      open_wish_pinned_updated_at: now,
    }, { merge: true });
    return { ok: true, on, limit: false };
  }

  if (action === 'marks' || action === 'save') {
    const built = buildTrackPayload({
      title: data.title,
      artist: data.artist,
      party_id: partyId,
      source_wish_id: wishIds[0],
    });
    const ref = db.collection('users').doc(ownerUid).collection('saved_tracks').doc(built.docId);
    const existing = await ref.get();
    const listed = await blacklistHas(ownerUid, data.title, data.artist);
    if (action === 'marks') {
      return { ok: true, saved: existing.exists, blacklisted: listed };
    }
    if (existing.exists) {
      await ref.delete();
      return { ok: true, on: false, blacklisted: listed };
    }
    await ref.set(built.payload);
    return { ok: true, on: true, blacklisted: listed };
  }

  if (action === 'blacklist') {
    const title = String(data.title || '').trim().slice(0, 100);
    const artist = String(data.artist || '').trim().slice(0, 100);
    if (!title && !artist) throw new HttpsError('invalid-argument', 'Titel fehlt.');
    const ref = db.collection('dj_song_blacklists').doc(ownerUid);
    const snap = await ref.get();
    const current = snap.data() || {};
    const entries = Array.isArray(current.entries) ? current.entries.slice() : [];
    const nt = normWishText(title);
    const na = normWishText(artist);
    const exists = entries.some((row) => row && normWishText(row.title) === nt && normWishText(row.artist) === na);
    if (exists) {
      const kept = entries.filter((row) => !(row && normWishText(row.title) === nt && normWishText(row.artist) === na));
      await ref.set({
        entries: kept.slice(0, 200),
        enabled: current.enabled !== false,
        updatedAt: now,
      }, { merge: true });
      return { ok: true, on: false };
    }
    entries.push({
      id: `e_${Date.now()}`,
      title,
      artist,
    });
    await ref.set({
      entries: entries.slice(0, 200),
      enabled: current.enabled !== false,
      updatedAt: now,
    }, { merge: true });
    const pending = await wishes.where('status', '==', 'pending').limit(400).get();
    const batch = db.batch();
    let n = 0;
    for (const doc of pending.docs) {
      const row = doc.data() || {};
      if (normWishText(row.title || row.song) !== nt) continue;
      if (na && normWishText(row.artist) !== na) continue;
      batch.update(doc.ref, {
        status: 'rejected',
        rejectedAt: now,
        rejected_at: now,
        rejection_reason: 'song_blacklist',
        auto_rejected_by_blacklist: true,
      });
      n += 1;
    }
    if (n) await batch.commit();
    return { ok: true, on: true, rejected: n };
  }

  if (action === 'move') {
    const direction = data.direction === 'down' ? 1 : -1;
    const anchor = new Set(wishIds.map((id) => String(id || '').trim()).filter(Boolean));
    const pending = await wishes.where('status', '==', 'pending').limit(400).get();
    const groups = [];
    const byKey = new Map();
    for (const doc of pending.docs) {
      const row = doc.data() || {};
      if (row.is_pre_wish === true && row.pre_wish_published !== true) continue;
      const key = `${normWishText(row.title || row.song)}|${normWishText(row.artist)}`;
      let group = byKey.get(key);
      if (!group) {
        group = { key, ids: [] };
        byKey.set(key, group);
        groups.push(group);
      }
      group.ids.push(doc.id);
    }
    const stored = Array.isArray(party.data()?.open_wish_order)
      ? party.data().open_wish_order.map((x) => String(x || '').trim())
      : [];
    const ordered = [];
    const seen = new Set();
    const idToKey = new Map();
    for (const group of groups) {
      for (const id of group.ids) idToKey.set(id, group.key);
    }
    for (const key of stored) {
      const groupKey = byKey.has(key) ? key : idToKey.get(key);
      if (!groupKey || seen.has(groupKey)) continue;
      seen.add(groupKey);
      ordered.push(byKey.get(groupKey));
    }
    for (const group of groups) {
      if (!seen.has(group.key)) ordered.push(group);
    }
    const index = ordered.findIndex((group) => group.ids.some((id) => anchor.has(id)));
    const next = index + direction;
    if (index < 0 || next < 0 || next >= ordered.length) return { ok: true, moved: false };
    const swap = ordered[index];
    ordered[index] = ordered[next];
    ordered[next] = swap;
    const rev = Number(party.data()?.open_wish_order_rev) || 0;
    await party.ref.set({
      open_wish_order: ordered.map((group) => group.ids[0]),
      open_wish_order_rev: rev + 1,
      open_wish_order_updated_at: now,
    }, { merge: true });
    return { ok: true, moved: true };
  }

  throw new HttpsError('invalid-argument', 'Aktion unbekannt.');
}

function registerRbToolCallables(exports) {
  exports.createRbToolCode = onCall(CALLABLE_OPTS, createRbToolCodeHandler);
  exports.getRbToolCodeStatus = onCall(CALLABLE_OPTS, getRbToolCodeStatusHandler);
  exports.redeemRbToolCode = onCall(CALLABLE_OPTS, redeemRbToolCodeHandler);
  exports.revokeRbToolSession = onCall(CALLABLE_OPTS, revokeRbToolSessionHandler);
  exports.getRbToolWishboard = onCall(CALLABLE_OPTS, getRbToolWishboardHandler);
  exports.setRbToolSongRec = onCall(CALLABLE_OPTS, setRbToolSongRecHandler);
  exports.markRbToolRecognized = onCall(CALLABLE_OPTS, markRbToolRecognizedHandler);
  exports.rbToolWishAction = onCall(CALLABLE_OPTS, rbToolWishActionHandler);
}

module.exports = { registerRbToolCallables };
