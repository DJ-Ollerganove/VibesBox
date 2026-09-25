const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const db = admin.firestore();

function cleanText(raw, maxLen) {
  const s = String(raw ?? '').trim();
  if (!s || s.length > maxLen) return '';
  return s;
}

function dedupeKey(title, artist) {
  const norm = (x) =>
    String(x ?? '')
      .trim()
      .toLowerCase()
      .replace(/\s+/g, ' ');
  return `${norm(title)}|${norm(artist)}`;
}

function documentIdFor(title, artist) {
  const key = dedupeKey(title, artist);
  if (key.length <= 150) {
    return key.replace(/[/\s.]/g, '_');
  }
  const digest = Buffer.from(key, 'utf8').toString('base64url');
  const compact = digest.replace(/[^a-zA-Z0-9]/g, '');
  return `k_${compact.substring(0, 120)}`;
}

function serializeTrack(doc) {
  const d = doc.data() || {};
  const tsMillis = (ts) => {
    if (!ts) return null;
    if (typeof ts.toMillis === 'function') return ts.toMillis();
    return null;
  };
  return {
    id: doc.id,
    title: d.title || '',
    artist: d.artist || '',
    party_id: d.party_id || null,
    source_wish_id: d.source_wish_id || null,
    bookmarked_at: tsMillis(d.bookmarked_at) || Date.now(),
  };
}

function buildTrackPayload(data) {
  const title = cleanText(data.title, 300);
  const artist = cleanText(data.artist, 300);
  if (!title && !artist) {
    throw new HttpsError('invalid-argument', 'title oder artist erforderlich');
  }
  const payload = {
    title,
    artist,
    bookmarked_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  const partyId = cleanText(data.party_id, 120);
  if (partyId) payload.party_id = partyId;
  const wishId = cleanText(data.source_wish_id, 120);
  if (wishId) payload.source_wish_id = wishId;
  return { docId: documentIdFor(title, artist), payload };
}

const SAVED_TRACKS_CALLABLE_OPTS = {
  region: 'us-central1',
  enforceAppCheck: false,
  serviceAccount: 'dj-ollerganove@appspot.gserviceaccount.com',
};

function resolveSavedTracksOwnerUid(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const token = request.auth.token || {};
  if (token.role === 'dj_browser') {
    const ownerUid = String(token.ownerUid || '').trim();
    if (!ownerUid) {
      throw new HttpsError('failed-precondition', 'DJ-Browser: Besitzer fehlt.');
    }
    return ownerUid;
  }
  return request.auth.uid;
}

async function manageSavedTrackHandler(request) {
  const uid = resolveSavedTracksOwnerUid(request);
  const data = request.data || {};
  const action = String(data.action || '').trim();

  if (action === 'list') {
    const snap = await db
      .collection('users')
      .doc(uid)
      .collection('saved_tracks')
      .get();
    const tracks = snap.docs.map(serializeTrack);
    tracks.sort((a, b) => (b.bookmarked_at || 0) - (a.bookmarked_at || 0));
    return { ok: true, tracks };
  }

  if (action === 'add') {
    const { docId, payload } = buildTrackPayload(data.track || data);
    const ref = db.collection('users').doc(uid).collection('saved_tracks').doc(docId);
    const existing = await ref.get();
    if (existing.exists) {
      return { ok: true, alreadyExists: true, docId };
    }
    await ref.set(payload);
    return { ok: true, docId };
  }

  if (action === 'remove') {
    const title = cleanText(data.title, 300);
    const artist = cleanText(data.artist, 300);
    if (!title && !artist) {
      throw new HttpsError('invalid-argument', 'title oder artist erforderlich');
    }
    const docId = documentIdFor(title, artist);
    await db
      .collection('users')
      .doc(uid)
      .collection('saved_tracks')
      .doc(docId)
      .delete();
    return { ok: true, docId };
  }

  throw new HttpsError('invalid-argument', 'action ungültig');
}

function registerSavedTracksCallables(exports) {
  exports.manageSavedTrack = onCall(
    SAVED_TRACKS_CALLABLE_OPTS,
    manageSavedTrackHandler,
  );
}

module.exports = {
  registerSavedTracksCallables,
  manageSavedTrackHandler,
  buildTrackPayload,
};
