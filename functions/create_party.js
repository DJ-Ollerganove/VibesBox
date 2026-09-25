/**
 * Party-Erstellung serverseitig (Admin SDK) — umgeht Client-Firestore-Rule-Probleme.
 */
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const PARTY_CODE_LENGTH = 8;
const PLATFORM_ADMIN_UID = 'rtJXMTULzTPUz0xtdQOw9Jm8SGD3';

function normalizePartyCode(raw) {
  const digits = String(raw == null ? '' : raw).replace(/\D/g, '');
  return digits.length === PARTY_CODE_LENGTH ? digits : null;
}

function reviveFirestoreValue(value) {
  if (value == null || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(reviveFirestoreValue);
  if (value instanceof Timestamp) return value;
  const sec =
    value._seconds != null
      ? value._seconds
      : value.seconds != null
        ? value.seconds
        : null;
  const nano =
    value._nanoseconds != null
      ? value._nanoseconds
      : value.nanoseconds != null
        ? value.nanoseconds
        : null;
  // Callable-Payload aus Flutter: { seconds, nanoseconds }
  if (
    sec != null &&
    nano != null &&
    Object.keys(value).every((k) =>
      ['seconds', 'nanoseconds', '_seconds', '_nanoseconds'].includes(k),
    )
  ) {
    return new Timestamp(Number(sec), Number(nano));
  }
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    out[k] = reviveFirestoreValue(v);
  }
  return out;
}

function revivePartyData(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new HttpsError('invalid-argument', 'partyData muss ein Objekt sein');
  }
  return reviveFirestoreValue(raw);
}

function assertPartyOwner(partyData, uid) {
  const owner =
    partyData.created_by ||
    partyData.djId ||
    partyData.dj_code ||
    partyData.uid;
  if (owner !== uid) {
    throw new HttpsError(
      'permission-denied',
      `Party-Besitzer stimmt nicht (${owner} != ${uid})`,
    );
  }
}

async function isCallerAdmin(uid) {
  if (uid === PLATFORM_ADMIN_UID) return true;
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) return false;
  const data = userSnap.data() || {};
  if (data.admin === true) return true;
  const roleId = data.role_id;
  if (roleId && String(roleId).trim() !== '') {
    const roleSnap = await db.collection('roles').doc(String(roleId)).get();
    if (roleSnap.exists && roleSnap.data()?.name === 'Admin') return true;
  }
  return false;
}

async function assertCanManageParty(existing, uid) {
  const owner =
    existing.created_by ||
    existing.djId ||
    existing.dj_code ||
    existing.uid;
  if (owner === uid) return;
  if (await isCallerAdmin(uid)) return;
  throw new HttpsError(
    'permission-denied',
    `Party-Besitzer stimmt nicht (${owner} != ${uid})`,
  );
}

const VENUE_MATCH_RADIUS_M = 50;
const FIXED_CODE_MIN = 99000000;
const FIXED_CODE_MAX = 99999999;

function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

async function findVenueNearCoordinates(latitude, longitude) {
  const latDelta = VENUE_MATCH_RADIUS_M / 111320;
  const minLat = latitude - latDelta;
  const maxLat = latitude + latDelta;
  const snap = await db
    .collection('venues')
    .where('latitude', '>=', minLat)
    .where('latitude', '<=', maxLat)
    .get();
  let closest = null;
  let closestDist = Infinity;
  for (const doc of snap.docs) {
    const data = doc.data();
    const dist = haversineMeters(
      latitude,
      longitude,
      Number(data.latitude),
      Number(data.longitude),
    );
    if (dist <= VENUE_MATCH_RADIUS_M && dist < closestDist) {
      closest = doc;
      closestDist = dist;
    }
  }
  return closest;
}

async function generateFixedPartyCode() {
  for (let attempt = 0; attempt < 30; attempt++) {
    const code = String(
      FIXED_CODE_MIN +
        Math.floor(Math.random() * (FIXED_CODE_MAX - FIXED_CODE_MIN + 1)),
    );
    const venues = await db
      .collection('venues')
      .where('fixed_party_code', '==', code)
      .limit(1)
      .get();
    if (!venues.empty) continue;
    const parties = await db
      .collection('parties')
      .where('party_code', '==', code)
      .limit(1)
      .get();
    if (!parties.empty) continue;
    return code;
  }
  throw new HttpsError('resource-exhausted', 'Kein Festcode verfügbar');
}

async function resolveOrCreateVenueAdmin(venueInput, uid) {
  const name = String(venueInput.name || '').trim();
  const address =
    venueInput.address != null ? String(venueInput.address).trim() : '';
  const latitude = Number(venueInput.latitude);
  const longitude = Number(venueInput.longitude);
  const timezoneId = String(venueInput.timezoneId || '').trim();
  const placeId =
    venueInput.placeId != null ? String(venueInput.placeId).trim() : '';

  if (!name || !timezoneId || Number.isNaN(latitude) || Number.isNaN(longitude)) {
    throw new HttpsError('invalid-argument', 'Venue-Daten unvollständig');
  }

  if (placeId) {
    const byPlace = await db
      .collection('venues')
      .where('place_id', '==', placeId)
      .limit(1)
      .get();
    if (!byPlace.empty) return byPlace.docs[0].id;
  }

  const near = await findVenueNearCoordinates(latitude, longitude);
  if (near) return near.id;

  const fixedCode = await generateFixedPartyCode();
  const now = FieldValue.serverTimestamp();
  const ref = await db.collection('venues').add({
    name,
    ...(address ? { address } : {}),
    latitude,
    longitude,
    timezone_id: timezoneId,
    fixed_party_code: fixedCode,
    ...(placeId ? { place_id: placeId } : {}),
    floors: [],
    created_by: uid,
    created_at: now,
    updated_at: now,
  });
  return ref.id;
}

function applyPublicVenueToPatch(patch, venueInput, venueId) {
  patch.venue_id = venueId;
  if (venueInput.noFloor === true) {
    patch.floor_key = FieldValue.delete();
    patch.floor_label = FieldValue.delete();
    return;
  }
  const floorKey =
    venueInput.floorKey != null ? String(venueInput.floorKey).trim() : '';
  if (floorKey) {
    patch.floor_key = floorKey;
  }
  const floorLabel =
    venueInput.floorLabel != null ? String(venueInput.floorLabel).trim() : '';
  if (floorLabel) {
    patch.floor_label = floorLabel;
  }
  if (venueInput.isCoVenueDj === true) {
    patch.is_co_venue_dj = true;
  } else if (venueInput.isCoVenueDj === false) {
    patch.is_co_venue_dj = FieldValue.delete();
  }
}

async function queryPartiesByJoinCode(joinCode) {
  const queries = [joinCode];
  const asInt = parseInt(joinCode, 10);
  if (!Number.isNaN(asInt)) queries.push(asInt);

  for (const value of queries) {
    const snap = await db
      .collection('parties')
      .where('party_code', '==', value)
      .limit(5)
      .get();
    if (!snap.empty) return snap.docs;
  }
  return [];
}

async function assertVenueSharedCodeAllowed(joinCode, venueId, locationId) {
  const trimmedVenue =
    venueId != null && String(venueId).trim() !== ''
      ? String(venueId).trim()
      : null;

  if (trimmedVenue) {
    const queries = [joinCode];
    const asInt = parseInt(joinCode, 10);
    if (!Number.isNaN(asInt)) queries.push(asInt);

    for (const value of queries) {
      const snap = await db
        .collection('venues')
        .where('fixed_party_code', '==', value)
        .limit(5)
        .get();
      for (const doc of snap.docs) {
        if (doc.id !== trimmedVenue) {
          throw new HttpsError(
            'failed-precondition',
            `Code ${joinCode} ist an Venue ${doc.id} gebunden`,
          );
        }
      }
    }
    return;
  }

  const docs = await queryPartiesByJoinCode(joinCode);
  if (docs.length === 0) return;

  const trimmedLocation =
    locationId != null && String(locationId).trim() !== ''
      ? String(locationId).trim()
      : null;

  for (const doc of docs) {
    const data = doc.data();
    if (data.party_type !== 'public') {
      throw new HttpsError(
        'failed-precondition',
        `Code ${joinCode} bereits privat vergeben`,
      );
    }
    const otherVenue = data.venue_id;
    if (
      trimmedLocation &&
      data.location_id &&
      String(data.location_id).trim() !== '' &&
      String(data.location_id).trim() !== trimmedLocation
    ) {
      throw new HttpsError(
        'failed-precondition',
        `Code ${joinCode} an anderer Location`,
      );
    }
    if (!trimmedLocation && otherVenue) {
      throw new HttpsError(
        'failed-precondition',
        `Code ${joinCode} an anderem Venue`,
      );
    }
  }
}

async function createPartySecureHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const data = request.data || {};

  const mode = String(data.mode || '').trim();
  const partyId = String(data.partyId || '').trim();
  const partyCode = normalizePartyCode(data.partyCode);
  const partyData = revivePartyData(data.partyData);
  const venueId = data.venueId;
  const locationId = data.locationId;

  if (!partyId) {
    throw new HttpsError('invalid-argument', 'partyId fehlt');
  }
  if (!partyCode) {
    throw new HttpsError('invalid-argument', 'Ungültiger partyCode');
  }
  assertPartyOwner(partyData, uid);

  const partyRef = db.collection('parties').doc(partyId);

  if (mode === 'venue_shared') {
    await assertVenueSharedCodeAllowed(partyCode, venueId, locationId);
    await partyRef.set(partyData);
    return { partyId, partyCode, mode };
  }

  if (mode === 'global_index') {
    const partyType = String(partyData.party_type || 'private');
    if (partyType !== 'private' && partyType !== 'public') {
      throw new HttpsError('invalid-argument', 'Ungültiger party_type');
    }
    const indexRef = db.collection('party_code_index').doc(partyCode);
    await db.runTransaction(async (txn) => {
      const indexSnap = await txn.get(indexRef);
      if (indexSnap.exists) {
        throw new HttpsError('already-exists', `Code ${partyCode} vergeben`);
      }
      txn.set(indexRef, {
        party_id: partyId,
        party_type: partyType,
        scope: 'global',
        created_by: uid,
        created_at: FieldValue.serverTimestamp(),
      });
      txn.set(partyRef, partyData);
    });
    return { partyId, partyCode, mode };
  }

  throw new HttpsError('invalid-argument', `Unbekannter mode: ${mode}`);
}

function revivePatch(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new HttpsError('invalid-argument', 'patch muss ein Objekt sein');
  }
  const revived = reviveFirestoreValue(raw);
  const patch = {};
  for (const [key, value] of Object.entries(revived)) {
    if (value === null) {
      patch[key] = FieldValue.delete();
    } else {
      patch[key] = value;
    }
  }
  return patch;
}

function repairLegacyFieldsInPatch(existing, patch) {
  // Nur reparieren, wenn der Client dj_logo nicht selbst setzt (sonst Upload überschreiben).
  if (!('dj_logo' in patch)) {
    const logo = existing.dj_logo;
    if (logo != null && String(logo).length > 2048) {
      patch.dj_logo = String(logo).substring(0, 2048);
    }
  }
  for (const field of ['active_recognition_device', 'open_wish_sort_lock_device_id']) {
    const raw = existing[field];
    if (typeof raw === 'string' && raw.length > 128) {
      patch[field] = raw.substring(0, 128);
    }
  }
  if ('open_wish_order' in patch) {
    patch.open_wish_order_updated_at = FieldValue.serverTimestamp();
  }
  if ('open_wish_pinned_keys' in patch) {
    patch.open_wish_pinned_updated_at = FieldValue.serverTimestamp();
  }
  return patch;
}

function partyStartDateMs(existing) {
  const ts = existing.start_date;
  if (ts && typeof ts.toDate === 'function') {
    return ts.toDate().getTime();
  }
  const posix = existing.start_time_posix;
  if (typeof posix === 'number' && posix > 0) {
    return posix * 1000;
  }
  return null;
}

function isWithinPreWishConfigWindow(existing) {
  const startMs = partyStartDateMs(existing);
  if (startMs == null) return false;
  const nowMs = Date.now();
  if (nowMs >= startMs) return false;
  const deadlineMs = startMs - 6 * 60 * 60 * 1000;
  return nowMs <= deadlineMs;
}

function assertPreWishPartyPatch(existing, patch) {
  if ('allow_pre_wishes' in patch) {
    if (existing.allow_pre_wishes === true && patch.allow_pre_wishes === false) {
      throw new HttpsError(
        'permission-denied',
        'Vorab-Wünsche können nicht deaktiviert werden',
      );
    }
    if (patch.allow_pre_wishes === true && existing.allow_pre_wishes !== true) {
      if (!isWithinPreWishConfigWindow(existing)) {
        throw new HttpsError(
          'failed-precondition',
          'Vorab-Wünsche können nur bis 6 Stunden vor Partybeginn aktiviert werden',
        );
      }
    }
  }
  if ('pre_wish_limit_per_guest' in patch && !isWithinPreWishConfigWindow(existing)) {
    throw new HttpsError(
      'failed-precondition',
      'Vorab-Einstellungen sind nur bis 6 Stunden vor Partybeginn änderbar',
    );
  }
  if ('pre_wishes_paused' in patch && typeof patch.pre_wishes_paused !== 'boolean') {
    throw new HttpsError('invalid-argument', 'pre_wishes_paused muss bool sein');
  }
}

async function updatePartySecureHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const partyId = String((request.data || {}).partyId || '').trim();
  if (!partyId) {
    throw new HttpsError('invalid-argument', 'partyId fehlt');
  }

  const patch = revivePatch((request.data || {}).patch || {});
  if (Object.keys(patch).length === 0) {
    throw new HttpsError('invalid-argument', 'patch leer');
  }

  const partyRef = db.collection('parties').doc(partyId);
  const snap = await partyRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Party nicht gefunden');
  }
  const existing = snap.data() || {};
  await assertCanManageParty(existing, uid);
  assertPreWishPartyPatch(existing, patch);
  repairLegacyFieldsInPatch(existing, patch);

  if (
    Object.prototype.hasOwnProperty.call(patch, 'created_by') &&
    uid !== PLATFORM_ADMIN_UID &&
    String(patch.created_by || '') !== String(existing.created_by || '')
  ) {
    throw new HttpsError(
      'permission-denied',
      'created_by darf nicht geändert werden',
    );
  }

  const publicVenue = (request.data || {}).publicVenue;
  if (publicVenue && typeof publicVenue === 'object') {
    const venueInput = reviveFirestoreValue(publicVenue);
    const venueId = await resolveOrCreateVenueAdmin(venueInput, uid);
    applyPublicVenueToPatch(patch, venueInput, venueId);
  }

  await partyRef.update(patch);
  return { partyId };
}

const RECOGNITION_LEASE_STALE_MS = 6 * 60 * 1000;

function normalizeRecognitionDeviceId(raw) {
  const trimmed = String(raw == null ? '' : raw).trim();
  if (!trimmed) return 'device_unknown';
  return trimmed.length <= 128 ? trimmed : trimmed.substring(0, 128);
}

function isRecognitionLeaseStale(lastSeen) {
  if (lastSeen == null) return true;
  const ms =
    typeof lastSeen.toMillis === 'function'
      ? lastSeen.toMillis()
      : (lastSeen._seconds || 0) * 1000;
  const diff = Date.now() - ms;
  if (diff < 0) return true;
  return diff > RECOGNITION_LEASE_STALE_MS;
}

function legacyRecognitionFieldFixes(existing) {
  const fixes = {};
  for (const field of ['active_recognition_device', 'open_wish_sort_lock_device_id']) {
    const raw = existing[field];
    if (typeof raw !== 'string') continue;
    const trimmed = raw.trim();
    if (!trimmed) {
      fixes[field] = null;
    } else if (trimmed.length > 128) {
      fixes[field] = trimmed.substring(0, 128);
    }
  }
  return fixes;
}

/** Atomare Musikerkennungs-Sperre (Admin SDK) — umgeht Client-Rule-Probleme. */
async function acquireRecognitionLockHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const partyId = String((request.data || {}).partyId || '').trim();
  const deviceId = normalizeRecognitionDeviceId((request.data || {}).deviceId);
  if (!partyId) {
    throw new HttpsError('invalid-argument', 'partyId fehlt');
  }

  const partyRef = db.collection('parties').doc(partyId);
  const pre = await partyRef.get();
  if (!pre.exists) {
    return { status: 'acquired' };
  }
  await assertCanManageParty(pre.data() || {}, uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(partyRef);
    if (!snap.exists) {
      return { status: 'acquired' };
    }
    const data = snap.data() || {};
    const activeRaw = String(data.active_recognition_device || '').trim();
    const lastSeen = data.active_recognition_last_seen;

    const claimLock = () => {
      tx.set(
        partyRef,
        {
          ...legacyRecognitionFieldFixes(data),
          active_recognition_device: deviceId,
          active_recognition_last_seen: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    };

    if (!activeRaw || activeRaw === deviceId) {
      claimLock();
      return { status: 'acquired' };
    }
    if (isRecognitionLeaseStale(lastSeen)) {
      claimLock();
      return { status: 'acquired' };
    }
    return { status: 'blocked', otherDevice: activeRaw };
  });
}

async function releaseRecognitionLockHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const partyId = String((request.data || {}).partyId || '').trim();
  const deviceId = normalizeRecognitionDeviceId((request.data || {}).deviceId);
  const force = !!(request.data || {}).force;
  if (!partyId) {
    throw new HttpsError('invalid-argument', 'partyId fehlt');
  }

  const partyRef = db.collection('parties').doc(partyId);
  const snap = await partyRef.get();
  if (!snap.exists) {
    return { status: 'released' };
  }
  await assertCanManageParty(snap.data() || {}, uid);

  const activeRaw = String((snap.data() || {}).active_recognition_device || '').trim();
  if (!force && activeRaw !== deviceId) {
    return { status: 'unchanged' };
  }

  await partyRef.update({
    active_recognition_device: null,
    active_recognition_last_seen: null,
  });
  return { status: 'released' };
}

async function pingRecognitionLockHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const partyId = String((request.data || {}).partyId || '').trim();
  const deviceId = normalizeRecognitionDeviceId((request.data || {}).deviceId);
  if (!partyId) {
    throw new HttpsError('invalid-argument', 'partyId fehlt');
  }

  const partyRef = db.collection('parties').doc(partyId);
  const pre = await partyRef.get();
  if (!pre.exists) {
    return { status: 'ignored' };
  }
  await assertCanManageParty(pre.data() || {}, uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(partyRef);
    if (!snap.exists) {
      return { status: 'ignored' };
    }
    const data = snap.data() || {};
    const activeRaw = String(data.active_recognition_device || '').trim();
    if (activeRaw !== deviceId) {
      return { status: 'ignored' };
    }
    tx.set(
      partyRef,
      {
        ...legacyRecognitionFieldFixes(data),
        active_recognition_last_seen: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { status: 'pong' };
  });
}

function cleanHistoryTrackText(raw, maxLen) {
  const s = String(raw == null ? '' : raw).trim();
  if (!s) return '';
  return s.length <= maxLen ? s : s.substring(0, maxLen);
}

function historyTrackIdentity(title, artist) {
  return `${String(title || '').trim().toLowerCase()}|${String(artist || '').trim().toLowerCase()}`;
}

function optionalHistoryTrackMeta(data) {
  const out = {};
  const bpm = Number(data && data.bpm);
  if (Number.isFinite(bpm) && bpm > 0 && bpm <= 400) {
    out.bpm = Math.round(bpm * 10) / 10;
  }
  const camelot = String((data && data.camelot) || '').trim().toUpperCase();
  if (/^(1[0-2]|[1-9])[AB]$/.test(camelot)) {
    out.camelot = camelot;
  }
  const key = cleanHistoryTrackText((data && data.key) || '', 24);
  if (key && key !== '-') out.key = key;
  const durationSec = Number(data && data.durationSec);
  if (Number.isFinite(durationSec) && durationSec >= 1 && durationSec <= 86400) {
    out.durationSec = Math.round(durationSec);
  }
  const source = String((data && data.source) || '').trim();
  if (source && source.length <= 40) out.source = source;
  return out;
}

/** Session-Docs für DJ+Party laden (party_id und Legacy partyId). */
async function listMusicHistorySessionsForParty(uid, partyId) {
  const bySnake = await db
    .collection('music_history')
    .where('djId', '==', uid)
    .where('party_id', '==', partyId)
    .limit(20)
    .get();
  const seen = new Set(bySnake.docs.map((d) => d.id));
  const out = bySnake.docs.slice();
  const byCamel = await db
    .collection('music_history')
    .where('djId', '==', uid)
    .where('partyId', '==', partyId)
    .limit(20)
    .get();
  for (const d of byCamel.docs) {
    if (!seen.has(d.id)) {
      seen.add(d.id);
      out.push(d);
    }
  }
  return out;
}

/**
 * Session mit dem neuesten Track bevorzugen (sonst neueste startTime).
 * Verhindert Writes in eine leere Heartbeat-Session während Tracks woanders liegen.
 */
async function pickMusicHistorySessionId(sessionDocs) {
  if (!sessionDocs.length) return null;
  let bestWithTracks = null;
  let bestTrackMs = -1;
  for (const d of sessionDocs) {
    const tracks = await d.ref.collection('tracks').limit(25).get();
    if (tracks.empty) continue;
    let latest = 0;
    for (const t of tracks.docs) {
      const ts = t.data().timestamp;
      const ms =
        ts && typeof ts.toMillis === 'function'
          ? ts.toMillis()
          : (ts && ts._seconds != null ? ts._seconds * 1000 : 0);
      if (ms > latest) latest = ms;
    }
    if (latest >= bestTrackMs) {
      bestTrackMs = latest;
      bestWithTracks = d.id;
    }
  }
  if (bestWithTracks) return bestWithTracks;

  let bestId = sessionDocs[0].id;
  let bestStart = -1;
  for (const d of sessionDocs) {
    const st = d.data().startTime;
    const ms =
      st && typeof st.toMillis === 'function'
        ? st.toMillis()
        : (st && st._seconds != null ? st._seconds * 1000 : 0);
    if (ms >= bestStart) {
      bestStart = ms;
      bestId = d.id;
    }
  }
  return bestId;
}

/** Erkannten Song in music_history/{session}/tracks — Admin SDK, zuverlässig. */
async function saveMusicHistoryTrackSecureHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const payload = request.data || {};
  const partyId = String(payload.partyId || '').trim();
  const title = cleanHistoryTrackText(payload.title, 100) || '-';
  const artist = cleanHistoryTrackText(payload.artist, 100) || '-';
  const meta = optionalHistoryTrackMeta(payload);

  if (!partyId || partyId === 'manual') {
    throw new HttpsError('invalid-argument', 'partyId fehlt oder ungültig');
  }
  if (title === '-' && artist === '-') {
    throw new HttpsError('invalid-argument', 'Titel und Interpret fehlen');
  }

  const partyRef = db.collection('parties').doc(partyId);
  const partySnap = await partyRef.get();
  if (!partySnap.exists) {
    throw new HttpsError('not-found', 'Party nicht gefunden');
  }
  const partyData = partySnap.data() || {};
  await assertCanManageParty(partyData, uid);
  const partyName = String(partyData.party_name || partyData.name || 'Party').trim()
    || 'Party';

  const sessions = await listMusicHistorySessionsForParty(uid, partyId);
  let sessionId = await pickMusicHistorySessionId(sessions);

  if (!sessionId) {
    const sessionRef = await db.collection('music_history').add({
      djId: uid,
      party_id: partyId,
      partyName,
      startTime: FieldValue.serverTimestamp(),
      isActive: true,
    });
    sessionId = sessionRef.id;
  }

  const lastSnap = await db
    .collection('music_history')
    .doc(sessionId)
    .collection('tracks')
    .orderBy('timestamp', 'desc')
    .limit(1)
    .get();
  if (!lastSnap.empty) {
    const last = lastSnap.docs[0].data() || {};
    if (
      historyTrackIdentity(last.title, last.artist)
      === historyTrackIdentity(title, artist)
    ) {
      return {
        partyId,
        sessionId,
        trackId: lastSnap.docs[0].id,
        title,
        artist,
      };
    }
  }

  const trackRef = await db
    .collection('music_history')
    .doc(sessionId)
    .collection('tracks')
    .add({
      title,
      artist,
      timestamp: FieldValue.serverTimestamp(),
      ...meta,
    });

  return {
    partyId,
    sessionId,
    trackId: trackRef.id,
    title,
    artist,
  };
}

function registerCreatePartyCallables(exports) {
  exports.createPartySecure = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    createPartySecureHandler,
  );
  exports.updatePartySecure = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    updatePartySecureHandler,
  );
  exports.acquireRecognitionLockSecure = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    acquireRecognitionLockHandler,
  );
  exports.releaseRecognitionLockSecure = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    releaseRecognitionLockHandler,
  );
  exports.pingRecognitionLockSecure = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    pingRecognitionLockHandler,
  );
  exports.saveMusicHistoryTrackSecure = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    saveMusicHistoryTrackSecureHandler,
  );
}

module.exports = {
  registerCreatePartyCallables,
  createPartySecureHandler,
  updatePartySecureHandler,
  acquireRecognitionLockHandler,
  releaseRecognitionLockHandler,
  pingRecognitionLockHandler,
  saveMusicHistoryTrackSecureHandler,
};
