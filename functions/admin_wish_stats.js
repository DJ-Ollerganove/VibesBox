/**
 * Admin-Gesamtstatistik: inkrementelle Zähler in admin_stats/wish_totals
 * und parties/{partyId}/stats/wish_summary (kein Vollscan beim Admin-Dashboard).
 */
const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } =
  require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const GLOBAL_PATH = 'admin_stats/wish_totals';
const BUCKETS = ['played', 'rejected', 'not_played', 'deleted', 'pending'];

function globalRef() {
  return db.doc(GLOBAL_PATH);
}

function partySummaryRef(partyId) {
  return db.doc(`parties/${partyId}/stats/wish_summary`);
}

function nowUnixUtc() {
  return Math.floor(Date.now() / 1000);
}

/** Gleiche Logik wie StatisticsService.loadCurrentlyActivePartyIds (Dart). */
function isPartyActiveNow(partyData) {
  if (!partyData || typeof partyData !== 'object') return false;
  if (
    partyData.lifecycle_status === 'finished' ||
    partyData.lifecycle_status === 'standby' ||
    partyData.finished_at != null
  ) {
    return false;
  }
  const nowUnix = nowUnixUtc();
  const start = partyData.start_time_posix;
  const end = partyData.end_time_posix;
  if (typeof start === 'number' && typeof end === 'number') {
    return nowUnix >= start && nowUnix < end;
  }
  return partyData.isActive === true;
}

/** Bucket ohne Party-Kontext (pending = roher pending-Status). */
function classifyWishBucket(data) {
  if (!data || typeof data !== 'object') return 'deleted';
  if (data.deleted === true) return 'deleted';
  const status = String(data.status == null ? '' : data.status)
    .trim()
    .toLowerCase();
  if (status === 'played') return 'played';
  if (status === 'rejected') return 'rejected';
  if (status === 'not_played' || status === 'notplayed' || status === 'skipped') {
    return 'not_played';
  }
  if (!status || status === 'pending' || status === 'open') return 'pending';
  return 'deleted';
}

function emptyBucketMap() {
  return {
    played: 0,
    rejected: 0,
    not_played: 0,
    deleted: 0,
    pending: 0,
  };
}

function buildGlobalDisplayTotals(raw) {
  const played = raw.played || 0;
  const rejected = raw.rejected || 0;
  const notPlayed = raw.not_played || 0;
  const deleted = raw.deleted || 0;
  const pendingActive = raw.pending_active || 0;
  const pendingInactive = raw.pending_inactive || 0;
  const total = played + rejected + notPlayed + deleted + pendingActive + pendingInactive;
  return {
    total,
    played,
    rejected,
    not_played: notPlayed,
    deleted,
    pending: pendingActive,
    pending_active: pendingActive,
    pending_inactive: pendingInactive,
    pending_total: (raw.pending || 0),
  };
}

async function applyBucketDelta(partyId, partyData, bucket, delta) {
  if (!partyId || !delta) return;
  if (!BUCKETS.includes(bucket)) return;

  const isActive = isPartyActiveNow(partyData);
  const partyUpdate = {
    [bucket]: FieldValue.increment(delta),
    is_party_active: isActive,
    last_updated_at: FieldValue.serverTimestamp(),
  };
  const globalUpdate = {
    [bucket]: FieldValue.increment(delta),
    last_updated_at: FieldValue.serverTimestamp(),
  };

  if (bucket === 'pending') {
    if (isActive) {
      globalUpdate.pending_active = FieldValue.increment(delta);
    } else {
      globalUpdate.pending_inactive = FieldValue.increment(delta);
    }
  }

  const batch = db.batch();
  batch.set(partySummaryRef(partyId), partyUpdate, { merge: true });
  batch.set(globalRef(), globalUpdate, { merge: true });
  await batch.commit();
}

async function applyBucketTransition(partyId, partyData, oldBucket, newBucket) {
  if (oldBucket === newBucket) return;
  if (oldBucket && BUCKETS.includes(oldBucket)) {
    await applyBucketDelta(partyId, partyData, oldBucket, -1);
  }
  if (newBucket && BUCKETS.includes(newBucket)) {
    await applyBucketDelta(partyId, partyData, newBucket, 1);
  }
}

async function loadPartyData(partyId) {
  const snap = await db.collection('parties').doc(partyId).get();
  return snap.exists ? snap.data() : null;
}

async function onPartyActiveStateChange(partyId, wasActive, isActive) {
  if (wasActive === isActive) return;

  const summaryRef = partySummaryRef(partyId);
  const summarySnap = await summaryRef.get();
  const pending = summarySnap.exists ? summarySnap.data().pending || 0 : 0;

  const batch = db.batch();
  batch.set(
    summaryRef,
    {
      is_party_active: isActive,
      last_updated_at: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  if (pending > 0) {
    const globalUpdate = { last_updated_at: FieldValue.serverTimestamp() };
    if (wasActive && !isActive) {
      globalUpdate.pending_active = FieldValue.increment(-pending);
      globalUpdate.pending_inactive = FieldValue.increment(pending);
    } else if (!wasActive && isActive) {
      globalUpdate.pending_active = FieldValue.increment(pending);
      globalUpdate.pending_inactive = FieldValue.increment(-pending);
    }
    batch.set(globalRef(), globalUpdate, { merge: true });
  }

  await batch.commit();
}

async function subtractPartySummaryFromGlobal(partyId) {
  const summarySnap = await partySummaryRef(partyId).get();
  if (!summarySnap.exists) return;

  const d = summarySnap.data() || {};
  const globalUpdate = { last_updated_at: FieldValue.serverTimestamp() };
  let hasDelta = false;

  for (const bucket of BUCKETS) {
    const v = d[bucket] || 0;
    if (v) {
      globalUpdate[bucket] = FieldValue.increment(-v);
      hasDelta = true;
    }
  }

  const pending = d.pending || 0;
  if (pending > 0) {
    hasDelta = true;
    if (d.is_party_active === true) {
      globalUpdate.pending_active = FieldValue.increment(-pending);
    } else {
      globalUpdate.pending_inactive = FieldValue.increment(-pending);
    }
  }

  const batch = db.batch();
  if (hasDelta) {
    batch.set(globalRef(), globalUpdate, { merge: true });
  }
  batch.delete(partySummaryRef(partyId));
  await batch.commit();
}

async function fullRecount() {
  const partiesSnap = await db.collection('parties').get();
  const activeByParty = new Map();
  for (const partyDoc of partiesSnap.docs) {
    activeByParty.set(partyDoc.id, isPartyActiveNow(partyDoc.data()));
  }

  const globalRaw = {
    ...emptyBucketMap(),
    pending_active: 0,
    pending_inactive: 0,
  };
  const partySummaries = new Map();
  const seenPaths = new Set();

  const ingestWish = (partyId, data) => {
    if (!partyId) return;
    const bucket = classifyWishBucket(data);
    const isActive = activeByParty.get(partyId) === true;

    if (!partySummaries.has(partyId)) {
      partySummaries.set(partyId, {
        ...emptyBucketMap(),
        is_party_active: isActive,
      });
    }
    const ps = partySummaries.get(partyId);
    ps[bucket] += 1;
    globalRaw[bucket] += 1;

    if (bucket === 'pending') {
      if (isActive) globalRaw.pending_active += 1;
      else globalRaw.pending_inactive += 1;
    }
  };

  for (const partyDoc of partiesSnap.docs) {
    const wishesSnap = await partyDoc.ref.collection('wishes').get();
    for (const wishDoc of wishesSnap.docs) {
      seenPaths.add(wishDoc.ref.path);
      ingestWish(partyDoc.id, wishDoc.data());
    }
  }

  try {
    const cgSnap = await db.collectionGroup('wishes').get();
    for (const wishDoc of cgSnap.docs) {
      if (seenPaths.has(wishDoc.ref.path)) continue;
      const parts = wishDoc.ref.path.split('/');
      const partiesIdx = parts.indexOf('parties');
      if (partiesIdx < 0 || partiesIdx + 1 >= parts.length) continue;
      const partyId = parts[partiesIdx + 1];
      ingestWish(partyId, wishDoc.data());
      seenPaths.add(wishDoc.ref.path);
    }
  } catch (e) {
    console.warn('admin_wish_stats fullRecount collectionGroup:', e);
  }

  try {
    const rootSnap = await db.collection('wishes').get();
    for (const wishDoc of rootSnap.docs) {
      const partyId = wishDoc.data()?.party_id;
      if (typeof partyId === 'string' && partyId.trim()) {
        ingestWish(partyId.trim(), wishDoc.data());
      }
    }
  } catch (e) {
    console.warn('admin_wish_stats fullRecount root wishes:', e);
  }

  const now = FieldValue.serverTimestamp();
  const batchLimit = 450;
  let batch = db.batch();
  let ops = 0;

  for (const [partyId, summary] of partySummaries.entries()) {
    batch.set(
      partySummaryRef(partyId),
      {
        played: summary.played,
        rejected: summary.rejected,
        not_played: summary.not_played,
        deleted: summary.deleted,
        pending: summary.pending,
        is_party_active: summary.is_party_active === true,
        last_updated_at: now,
      },
      { merge: true },
    );
    ops += 1;
    if (ops >= batchLimit) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  batch.set(
    globalRef(),
    {
      played: globalRaw.played,
      rejected: globalRaw.rejected,
      not_played: globalRaw.not_played,
      deleted: globalRaw.deleted,
      pending: globalRaw.pending,
      pending_active: globalRaw.pending_active,
      pending_inactive: globalRaw.pending_inactive,
      last_updated_at: now,
      last_full_recount_at: now,
    },
    { merge: true },
  );
  ops += 1;

  if (ops > 0) await batch.commit();

  const display = buildGlobalDisplayTotals(globalRaw);
  return {
    parties: partySummaries.size,
    wishes: display.total,
    ...display,
  };
}

const onAdminWishStatsCreated = onDocumentCreated(
  {
    document: 'parties/{partyId}/wishes/{wishId}',
    region: 'us-central1',
  },
  async (event) => {
    const partyId = event.params.partyId;
    const data = event.data?.data();
    if (!data) return;
    try {
      const partyData = await loadPartyData(partyId);
      const bucket = classifyWishBucket(data);
      await applyBucketDelta(partyId, partyData, bucket, 1);
    } catch (e) {
      console.error('onAdminWishStatsCreated:', partyId, e);
    }
  },
);

const onAdminWishStatsUpdated = onDocumentUpdated(
  {
    document: 'parties/{partyId}/wishes/{wishId}',
    region: 'us-central1',
  },
  async (event) => {
    const partyId = event.params.partyId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;
    try {
      const partyData = await loadPartyData(partyId);
      const oldBucket = classifyWishBucket(before);
      const newBucket = classifyWishBucket(after);
      await applyBucketTransition(partyId, partyData, oldBucket, newBucket);
    } catch (e) {
      console.error('onAdminWishStatsUpdated:', partyId, e);
    }
  },
);

const onAdminWishStatsDeleted = onDocumentDeleted(
  {
    document: 'parties/{partyId}/wishes/{wishId}',
    region: 'us-central1',
  },
  async (event) => {
    const partyId = event.params.partyId;
    const data = event.data?.data();
    if (!data) return;
    try {
      const partyData = await loadPartyData(partyId);
      const bucket = classifyWishBucket(data);
      await applyBucketDelta(partyId, partyData, bucket, -1);
    } catch (e) {
      console.error('onAdminWishStatsDeleted:', partyId, e);
    }
  },
);

const onAdminWishStatsPartyUpdated = onDocumentUpdated(
  {
    document: 'parties/{partyId}',
    region: 'us-central1',
  },
  async (event) => {
    const partyId = event.params.partyId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;
    try {
      const wasActive = isPartyActiveNow(before);
      const isActive = isPartyActiveNow(after);
      await onPartyActiveStateChange(partyId, wasActive, isActive);
    } catch (e) {
      console.error('onAdminWishStatsPartyUpdated:', partyId, e);
    }
  },
);

const onAdminWishStatsPartyDeleted = onDocumentDeleted(
  {
    document: 'parties/{partyId}',
    region: 'us-central1',
  },
  async (event) => {
    const partyId = event.params.partyId;
    try {
      await subtractPartySummaryFromGlobal(partyId);
    } catch (e) {
      console.error('onAdminWishStatsPartyDeleted:', partyId, e);
    }
  },
);

const MASTER_ADMIN_UID = 'rtJXMTULzTPUz0xtdQOw9Jm8SGD3';

async function requireMasterAdminFromIdToken(req, res) {
  const header = String(req.headers.authorization || '');
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) {
    res.status(401).json({ error: 'Authentifizierung erforderlich (Bearer ID Token).' });
    return null;
  }
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    if (!decoded || decoded.uid !== MASTER_ADMIN_UID) {
      res.status(403).json({ error: 'Forbidden: Nur Master-Admin erlaubt.' });
      return null;
    }
    return decoded;
  } catch (e) {
    res.status(401).json({ error: 'Ungültiges Auth-Token.' });
    return null;
  }
}

function registerAdminWishStatsCallables(target) {
  target.backfillAdminWishStats = onRequest(
    { region: 'us-central1', memory: '1GiB', timeoutSeconds: 540 },
    async (req, res) => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }
      if (!(await requireMasterAdminFromIdToken(req, res))) return;
      try {
        const result = await fullRecount();
        res.status(200).json({ ok: true, ...result });
      } catch (e) {
        console.error('backfillAdminWishStats:', e);
        res.status(500).json({ ok: false, error: String(e.message || e) });
      }
    },
  );
}

function registerAdminWishStatsSchedules(target) {
  target.adminWishStatsWeeklyRecount = functions
    .runWith({ memory: '1GB', timeoutSeconds: 540 })
    .pubsub.schedule('every 168 hours')
    .timeZone('Europe/Berlin')
    .onRun(async () => {
      const result = await fullRecount();
      console.log('adminWishStatsWeeklyRecount:', result);
      return null;
    });
}

module.exports = {
  onAdminWishStatsCreated,
  onAdminWishStatsUpdated,
  onAdminWishStatsDeleted,
  onAdminWishStatsPartyUpdated,
  onAdminWishStatsPartyDeleted,
  registerAdminWishStatsCallables,
  registerAdminWishStatsSchedules,
  fullRecount,
};
