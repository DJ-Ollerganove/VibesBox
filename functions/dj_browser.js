/**
 * DJ VibesBox im Browser — Einmal-Codes, Single-Session, Custom-Token-Auth.
 */
const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const functions = require('firebase-functions');

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const CODE_TTL_MS = 10 * 60 * 1000;
const DEFAULT_GRACE_MINUTES = 30;
/** Nach 24h darf derselbe 6-stellige Code wieder vergeben werden. */
const CODE_RETENTION_MS = 24 * 60 * 60 * 1000;
const RATE_WINDOW_MS = 15 * 60 * 1000;
const RATE_MAX_ATTEMPTS = 12;
const COL_CODES = 'dj_browser_codes';
const COL_SESSIONS = 'dj_browser_sessions';
const COL_RATE = 'dj_browser_redeem_rate';
const MANUAL_BY_DJ_MARKER = '__manual_by_dj__';
const FROM_SETLIST_MARKER = '__from_setlist__';

const SIX_DIGIT_RE = /^\d{6}$/;

function normalizeSixDigitCode(raw) {
  if (raw == null) return null;
  const c = String(raw).trim();
  return SIX_DIGIT_RE.test(c) ? c : null;
}

function hashBrowserCode(code) {
  return crypto.createHash('sha256').update(`djbrowser:v1:${code}`).digest('hex');
}

function hashClientIp(rawIp) {
  const ip = String(rawIp || 'unknown').trim() || 'unknown';
  return crypto.createHash('sha256').update(`djbrowser-ip:v1:${ip}`).digest('hex').slice(0, 40);
}

/** Firestore Timestamp / Legacy-Objekt → Date (wie Client [ProFreeCheck]). */
function userDateField(raw) {
  if (raw == null) return null;
  if (typeof raw.toDate === 'function') {
    try {
      const d = raw.toDate();
      return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
    } catch (_) {
      return null;
    }
  }
  if (typeof raw.toMillis === 'function') {
    const d = new Date(raw.toMillis());
    return Number.isNaN(d.getTime()) ? null : d;
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

function hasActivePaidStoreSubscription(data, nowMs = Date.now()) {
  if (!data || data.isPro !== true) return false;
  const trialUntil = userDateField(data.trialUntil);
  if (data.planType === 'trial' && trialUntil && trialUntil.getTime() > nowMs) {
    return false;
  }
  if (data.planType === 'dj_b2b' && data.djB2bDaysConsumptionActive === true) {
    return false;
  }
  const proUntil = userDateField(data.proUntil);
  if (!proUntil || proUntil.getTime() <= nowMs) return false;
  if (proUntil.getFullYear() >= 2099) return true;
  const provider = String(data.lastPaymentProvider || '').trim();
  if (provider === 'RevenueCat') return true;
  const plan = String(data.planType || '').trim().toLowerCase();
  return plan === 'pro' || plan === 'pro_life';
}

/**
 * Pro-Zugang für Browser-Code — spiegelt Client [ProFreeCheck.determineStatus].isActive:
 * Admin, Pro Life, Store-Pro, planType pro/pro_life, Trial, DJ B2B.
 */
function isCallerPro(userData, nowMs = Date.now()) {
  if (!userData) return false;
  if (userData.admin === true) return true;

  const plan = String(userData.planType || '').trim().toLowerCase();
  const proUntil = userDateField(userData.proUntil);
  const trialUntil = userDateField(userData.trialUntil);

  // Pro Life (Lifetime): Jahr >= 2099 — auch wenn isPro-Flag fehlt/inkonsistent
  if (proUntil && proUntil.getFullYear() >= 2099) return true;
  if (plan === 'pro_life' && proUntil && proUntil.getTime() > nowMs) return true;

  if (hasActivePaidStoreSubscription(userData, nowMs)) return true;

  // Aktives Trial
  if (plan === 'trial' && trialUntil && trialUntil.getTime() > nowMs) {
    return true;
  }

  // DJ B2B-Verbrauch (Client: isDjB2bActive → Pro-Features)
  if (
    plan === 'dj_b2b'
    && userData.djB2bDaysConsumptionActive === true
    && Number(userData.djB2bDaysAvailable || 0) > 0
  ) {
    return true;
  }

  // Admin-/manuelles Pro: gültiges proUntil, auch wenn lastPaymentProvider fehlt
  if (proUntil && proUntil.getTime() > nowMs) {
    if (userData.isPro === true) return true;
    if (plan === 'pro' || plan === 'pro_life') return true;
  }

  return false;
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

function shouldShowOpenWishesForDj(party, graceMinutes, nowMs = Date.now()) {
  if (isPartyRunningByPosixWindow(party, nowMs)) return true;
  const end = partyEffectiveEndDate(party);
  if (!end) return false;
  if (wishesManuallyHidden(party)) return false;
  const endMs = end.getTime();
  if (nowMs < endMs) return true;
  const grace = Math.max(0, Number(graceMinutes || 0));
  if (grace <= 0) return false;
  return nowMs < endMs + grace * 60 * 1000;
}

function isPartyClosedForDjBrowser(party, ownerGraceMinutes) {
  if (!party) return true;
  if (wishesManuallyHidden(party)) return true;
  if (isPartyRunningByPosixWindow(party)) return false;
  const end = partyEffectiveEndDate(party);
  if (!end) {
    if (party.lifecycle_status === 'finished' || party.finished_at) return true;
    const status = String(party.status || '').toLowerCase();
    return status === 'beendet' || status === 'ended';
  }
  return !shouldShowOpenWishesForDj(party, ownerGraceMinutes);
}

function buildPartyAccessMeta(party, graceMinutes) {
  const end = partyEffectiveEndDate(party);
  const graceEndsAtMillis = end
    ? end.getTime() + Math.max(0, Number(graceMinutes || 0)) * 60 * 1000
    : null;
  return {
    ownerGraceMinutes: graceMinutes,
    graceEndsAtMillis,
  };
}

function parseGraceMinutesValue(raw) {
  if (typeof raw === 'number' && raw >= 0 && raw <= 120) return raw;
  const num = Number(raw);
  if (!Number.isNaN(num) && num >= 0 && num <= 120) return num;
  return null;
}

async function loadOwnerGraceMinutes(party) {
  const owner =
    party?.created_by ||
    party?.djId ||
    party?.dj_code ||
    party?.uid;
  if (!owner) return DEFAULT_GRACE_MINUTES;
  const userRef = db.collection('users').doc(String(owner));
  const snap = await userRef.get();
  if (snap.exists) {
    const fromRoot = parseGraceMinutesValue(snap.data()?.grace_period_minutes);
    if (fromRoot != null) return fromRoot;
  }
  const legacySnap = await userRef.collection('settings').doc('grace_period').get();
  if (legacySnap.exists) {
    const fromLegacy = parseGraceMinutesValue(
      legacySnap.data()?.grace_period_minutes,
    );
    if (fromLegacy != null) return fromLegacy;
  }
  return DEFAULT_GRACE_MINUTES;
}

function assertPartyOwner(party, uid) {
  const owner =
    party.created_by ||
    party.djId ||
    party.dj_code ||
    party.uid;
  if (owner !== uid) {
    throw new HttpsError('permission-denied', 'Nicht der Party-Besitzer.');
  }
}

async function assertCallerPro(uid) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError('permission-denied', 'Benutzer nicht gefunden.');
  }
  if (!isCallerPro(snap.data())) {
    throw new HttpsError('permission-denied', 'VibesBox Pro erforderlich.');
  }
}

async function revokeUnusedCodesForParty(partyId, uid) {
  const snap = await db
    .collection(COL_CODES)
    .where('partyId', '==', partyId)
    .where('createdBy', '==', uid)
    .where('used', '==', false)
    .where('revoked', '==', false)
    .get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((d) => {
    batch.update(d.ref, {
      revoked: true,
      revokedAt: FieldValue.serverTimestamp(),
      revokeReason: 'replaced',
    });
  });
  await batch.commit();
}

async function deactivatePartyBrowserSessions(partyId, reason) {
  const snap = await db
    .collection(COL_SESSIONS)
    .where('partyId', '==', partyId)
    .where('active', '==', true)
    .get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((d) => {
    batch.update(d.ref, {
      active: false,
      endedReason: reason,
      endedAt: FieldValue.serverTimestamp(),
    });
  });
  await batch.commit();
}

async function assertRedeemRateLimit(ipHash) {
  const ref = db.collection(COL_RATE).doc(ipHash);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : {};
    const windowStart = data.windowStart?.toMillis?.() || 0;
    let count = Number(data.count || 0);
    if (now - windowStart > RATE_WINDOW_MS) {
      count = 0;
    }
    if (count >= RATE_MAX_ATTEMPTS) {
      throw new HttpsError(
        'resource-exhausted',
        'Zu viele Versuche. Bitte später erneut.',
      );
    }
    tx.set(
      ref,
      {
        count: count + 1,
        windowStart:
          now - windowStart > RATE_WINDOW_MS
            ? Timestamp.fromMillis(now)
            : data.windowStart || Timestamp.fromMillis(now),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

function generateSixDigitCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

function codeDocCreatedAtMs(data) {
  if (!data) return 0;
  return data.createdAt?.toMillis?.() || 0;
}

/** Code-Slot nach 24h freigeben (Recycling der 6-stelligen Zahlen). */
function isCodeDocReclaimable(data, nowMs = Date.now()) {
  const createdAt = codeDocCreatedAtMs(data);
  if (!createdAt) return true;
  return nowMs - createdAt >= CODE_RETENTION_MS;
}

async function tryClaimCodeSlot(candidate, partyId, uid, expiresAt) {
  const docId = hashBrowserCode(candidate);
  const ref = db.collection(COL_CODES).doc(docId);
  const nowMs = Date.now();

  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists && !isCodeDocReclaimable(snap.data(), nowMs)) {
      return false;
    }
    tx.set(ref, {
      partyId,
      createdBy: uid,
      codeHash: docId,
      expiresAt,
      used: false,
      revoked: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  });

  return { claimed, ref };
}

async function cleanupExpiredDjBrowserCodes() {
  const cutoff = Timestamp.fromMillis(Date.now() - CODE_RETENTION_MS);
  let deleted = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection(COL_CODES)
      .where('createdAt', '<', cutoff)
      .orderBy('createdAt')
      .limit(500);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < 500) break;
  }

  if (deleted > 0) {
    console.log(`[dj-browser] cleanup: deleted ${deleted} code doc(s) older than 24h`);
  }
  return deleted;
}

async function createDjBrowserCodeHandler(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  const uid = request.auth.uid;
  const partyId = String(request.data?.partyId || '').trim();
  if (!partyId) {
    throw new HttpsError('invalid-argument', 'partyId fehlt.');
  }

  await assertCallerPro(uid);
  const partySnap = await db.collection('parties').doc(partyId).get();
  if (!partySnap.exists) {
    throw new HttpsError('not-found', 'Party nicht gefunden.');
  }
  const party = partySnap.data();
  assertPartyOwner(party, uid);
  const grace = await loadOwnerGraceMinutes(party);
  if (isPartyClosedForDjBrowser(party, grace)) {
    throw new HttpsError('failed-precondition', 'Party ist beendet.');
  }

  await revokeUnusedCodesForParty(partyId, uid);

  const expiresAt = Timestamp.fromMillis(Date.now() + CODE_TTL_MS);
  let code = null;
  let codeRef = null;
  for (let attempt = 0; attempt < 25; attempt += 1) {
    const candidate = generateSixDigitCode();
    const result = await tryClaimCodeSlot(candidate, partyId, uid, expiresAt);
    if (result.claimed) {
      code = candidate;
      codeRef = result.ref;
      break;
    }
  }
  if (!code || !codeRef) {
    throw new HttpsError('internal', 'Code konnte nicht erzeugt werden.');
  }

  return {
    code,
    expiresAtMillis: expiresAt.toMillis(),
    url: 'https://www.vibesbox.app/dj',
  };
}

async function revokeDjBrowserCodeHandler(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  const uid = request.auth.uid;
  const partyId = String(request.data?.partyId || '').trim();
  const code = normalizeSixDigitCode(request.data?.code);
  if (!partyId || !code) {
    throw new HttpsError('invalid-argument', 'partyId oder Code ungültig.');
  }

  const codeRef = db.collection(COL_CODES).doc(hashBrowserCode(code));
  const snap = await codeRef.get();
  if (!snap.exists) return { ok: true };
  const data = snap.data();
  if (data.createdBy !== uid || data.partyId !== partyId) {
    throw new HttpsError('permission-denied', 'Kein Zugriff auf diesen Code.');
  }
  if (data.used === true) return { ok: true };
  await codeRef.update({
    revoked: true,
    revokedAt: FieldValue.serverTimestamp(),
    revokeReason: 'dj_revoked',
  });
  return { ok: true };
}

async function createDjBrowserCustomToken(sessionId, partyId, ownerUid) {
  return admin.auth().createCustomToken(`djbrowser_${sessionId}`, {
    role: 'dj_browser',
    partyId,
    sessionId,
    ownerUid,
  });
}

function codeExpiresAtMs(codeData) {
  return codeData?.expiresAt?.toMillis?.() || 0;
}

function isCodeExpired(codeData, nowMs = Date.now()) {
  const exp = codeExpiresAtMs(codeData);
  return !exp || nowMs > exp;
}

function linkedSessionId(codeData) {
  return String(
    codeData?.sessionId || codeData?.pendingSessionId || '',
  ).trim();
}

async function tryIdempotentRedeemFromCode(codeData, partyId, ownerUid) {
  const sessionId = linkedSessionId(codeData);
  if (!sessionId || isCodeExpired(codeData)) return null;

  const sessionSnap = await db.collection(COL_SESSIONS).doc(sessionId).get();
  if (!sessionSnap.exists || sessionSnap.data()?.active !== true) return null;
  if (String(sessionSnap.data()?.partyId || '').trim() !== partyId) return null;

  const partySnap = await db.collection('parties').doc(partyId).get();
  if (!partySnap.exists) {
    throw new HttpsError('not-found', 'Party nicht gefunden.');
  }
  const party = partySnap.data();
  const grace = await loadOwnerGraceMinutes(party);
  if (isPartyClosedForDjBrowser(party, grace)) {
    throw new HttpsError('failed-precondition', 'Party zu Ende.');
  }

  let customToken;
  try {
    customToken = await createDjBrowserCustomToken(sessionId, partyId, ownerUid);
  } catch (tokenErr) {
    console.error('createCustomToken dj_browser (idempotent):', tokenErr);
    throw new HttpsError('internal', 'Login konnte nicht erstellt werden.');
  }

  return {
    customToken,
    sessionId,
    partyId,
    ownerUid,
    ...buildPartyAccessMeta(party, grace),
  };
}

async function redeemDjBrowserCodeHandler(request) {
  const code = normalizeSixDigitCode(request.data?.code);
  if (!code) {
    throw new HttpsError('invalid-argument', 'Code muss 6 Ziffern haben.');
  }
  const deviceId = String(request.data?.deviceId || '').trim().slice(0, 128) || null;
  const rawIp =
    request.rawRequest?.ip ||
    request.rawRequest?.headers?.['x-forwarded-for']?.split?.(',')?.[0]?.trim?.() ||
    'unknown';
  const ipHash = hashClientIp(rawIp);
  await assertRedeemRateLimit(ipHash);

  const codeRef = db.collection(COL_CODES).doc(hashBrowserCode(code));
  const codeSnap = await codeRef.get();
  if (!codeSnap.exists) {
    throw new HttpsError('not-found', 'Code ungültig oder abgelaufen.');
  }
  const codeData = codeSnap.data();
  if (codeData.revoked === true) {
    throw new HttpsError('failed-precondition', 'Code ungültig oder abgelaufen.');
  }
  if (isCodeExpired(codeData)) {
    throw new HttpsError('deadline-exceeded', 'Code ungültig oder abgelaufen.');
  }

  const partyId = String(codeData.partyId || '').trim();
  if (!partyId) {
    throw new HttpsError('internal', 'Party fehlt am Code.');
  }
  const ownerUid = String(codeData.createdBy || '').trim();
  if (!ownerUid) {
    throw new HttpsError('internal', 'Party-Besitzer fehlt am Code.');
  }

  if (codeData.used === true || codeData.pendingSessionId) {
    const idempotent = await tryIdempotentRedeemFromCode(codeData, partyId, ownerUid);
    if (idempotent) return idempotent;
    if (codeData.used === true) {
      throw new HttpsError('failed-precondition', 'Code ungültig oder abgelaufen.');
    }
    const staleSessionId = linkedSessionId(codeData);
    if (staleSessionId) {
      await db.collection(COL_SESSIONS).doc(staleSessionId).update({
        active: false,
        endedReason: 'replaced',
        endedAt: FieldValue.serverTimestamp(),
      }).catch(() => {});
    }
    await codeRef.update({
      pendingSessionId: FieldValue.delete(),
      pendingAt: FieldValue.delete(),
      pendingDeviceId: FieldValue.delete(),
    });
  }

  const partySnap = await db.collection('parties').doc(partyId).get();
  if (!partySnap.exists) {
    throw new HttpsError('not-found', 'Party nicht gefunden.');
  }
  const party = partySnap.data();
  const grace = await loadOwnerGraceMinutes(party);
  if (isPartyClosedForDjBrowser(party, grace)) {
    throw new HttpsError('failed-precondition', 'Party zu Ende.');
  }

  const sessionId = crypto.randomUUID();
  const sessionRef = db.collection(COL_SESSIONS).doc(sessionId);

  let customToken;
  try {
    customToken = await createDjBrowserCustomToken(sessionId, partyId, ownerUid);
  } catch (tokenErr) {
    console.error('createCustomToken dj_browser:', tokenErr);
    throw new HttpsError('internal', 'Login konnte nicht erstellt werden.');
  }

  await deactivatePartyBrowserSessions(partyId, 'replaced');

  const accessMeta = buildPartyAccessMeta(party, grace);

  await db.runTransaction(async (tx) => {
    const freshCode = await tx.get(codeRef);
    if (!freshCode.exists) {
      throw new HttpsError('not-found', 'Code ungültig oder abgelaufen.');
    }
    const cd = freshCode.data();
    if (cd.revoked === true) {
      throw new HttpsError('failed-precondition', 'Code ungültig oder abgelaufen.');
    }
    if (cd.used === true) {
      throw new HttpsError('failed-precondition', 'Code ungültig oder abgelaufen.');
    }
    if (isCodeExpired(cd)) {
      throw new HttpsError('deadline-exceeded', 'Code ungültig oder abgelaufen.');
    }
    tx.update(codeRef, {
      pendingSessionId: sessionId,
      pendingAt: FieldValue.serverTimestamp(),
      pendingDeviceId: deviceId,
      sessionId,
      redeemIpHash: ipHash,
    });
    tx.set(sessionRef, {
      partyId,
      createdBy: cd.createdBy,
      active: true,
      deviceId,
      createdAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      ownerGraceMinutes: accessMeta.ownerGraceMinutes,
      graceEndsAtMillis: accessMeta.graceEndsAtMillis,
    });
  });

  return {
    customToken,
    sessionId,
    partyId,
    ownerUid,
    ...accessMeta,
  };
}

async function confirmDjBrowserRedeemHandler(request) {
  const sessionId = String(request.auth?.token?.sessionId || '').trim();
  if (request.auth?.token?.role !== 'dj_browser' || !sessionId) {
    throw new HttpsError('permission-denied', 'Keine Browser-Session.');
  }
  const code = normalizeSixDigitCode(request.data?.code);
  if (!code) {
    throw new HttpsError('invalid-argument', 'Code fehlt.');
  }

  const codeRef = db.collection(COL_CODES).doc(hashBrowserCode(code));
  const codeSnap = await codeRef.get();
  if (!codeSnap.exists) {
    throw new HttpsError('not-found', 'Code nicht gefunden.');
  }
  const cd = codeSnap.data();
  const linked = linkedSessionId(cd);
  if (linked !== sessionId) {
    throw new HttpsError('permission-denied', 'Code passt nicht zur Session.');
  }
  if (cd.used === true) {
    return { ok: true, alreadyUsed: true };
  }

  await codeRef.update({
    used: true,
    usedAt: FieldValue.serverTimestamp(),
    pendingSessionId: FieldValue.delete(),
    pendingAt: FieldValue.delete(),
    pendingDeviceId: FieldValue.delete(),
  });
  return { ok: true, alreadyUsed: false };
}

async function getDjBrowserCodeStatusHandler(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  const uid = request.auth.uid;
  const partyId = String(request.data?.partyId || '').trim();
  const code = normalizeSixDigitCode(request.data?.code);
  if (!partyId || !code) {
    throw new HttpsError('invalid-argument', 'partyId oder Code ungültig.');
  }

  const partySnap = await db.collection('parties').doc(partyId).get();
  if (!partySnap.exists) {
    throw new HttpsError('not-found', 'Party nicht gefunden.');
  }
  assertPartyOwner(partySnap.data(), uid);

  const codeRef = db.collection(COL_CODES).doc(hashBrowserCode(code));
  const codeSnap = await codeRef.get();
  if (!codeSnap.exists) {
    return {
      exists: false,
      used: false,
      pending: false,
      revoked: true,
      expired: true,
    };
  }

  const cd = codeSnap.data();
  if (String(cd.partyId || '').trim() !== partyId || String(cd.createdBy || '').trim() !== uid) {
    throw new HttpsError('permission-denied', 'Kein Zugriff auf diesen Code.');
  }

  const expired = isCodeExpired(cd);
  return {
    exists: true,
    used: cd.used === true,
    pending: !!cd.pendingSessionId && cd.used !== true,
    revoked: cd.revoked === true,
    expired,
  };
}

function resolvePartyOwnerUid(party, tokenOwnerUid) {
  const fromParty = String(
    party?.created_by || party?.djId || party?.dj_code || party?.uid || '',
  ).trim();
  if (fromParty) return fromParty;
  return String(tokenOwnerUid || '').trim();
}

function sanitizeWishText(raw, maxLen) {
  const s = String(raw || '').replace(/[<>]/g, '').trim();
  if (!s) return '';
  return s.length > maxLen ? s.slice(0, maxLen) : s;
}

async function assertDjBrowserSession(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  const token = request.auth.token || {};
  if (token.role !== 'dj_browser') {
    throw new HttpsError('permission-denied', 'Keine Browser-Session.');
  }
  const sessionId = String(token.sessionId || '').trim();
  const partyId = String(token.partyId || '').trim();
  if (!sessionId || !partyId) {
    throw new HttpsError('permission-denied', 'Keine Browser-Session.');
  }
  const sessionSnap = await db.collection(COL_SESSIONS).doc(sessionId).get();
  if (!sessionSnap.exists || sessionSnap.data()?.active !== true) {
    throw new HttpsError('failed-precondition', 'Session beendet.');
  }
  if (String(sessionSnap.data()?.partyId || '').trim() !== partyId) {
    throw new HttpsError('permission-denied', 'Session passt nicht zur Party.');
  }
  return {
    sessionId,
    partyId,
    ownerUid: String(token.ownerUid || '').trim(),
  };
}

async function createDjBrowserManualWishHandler(request) {
  const { partyId, ownerUid } = await assertDjBrowserSession(request);

  const partySnap = await db.collection('parties').doc(partyId).get();
  if (!partySnap.exists) {
    throw new HttpsError('not-found', 'Party nicht gefunden.');
  }
  const party = partySnap.data();
  const grace = await loadOwnerGraceMinutes(party);
  if (isPartyClosedForDjBrowser(party, grace)) {
    throw new HttpsError('failed-precondition', 'Party zu Ende.');
  }

  const title = sanitizeWishText(request.data?.title, 100);
  const artist = sanitizeWishText(request.data?.artist, 100);
  const greeting = sanitizeWishText(request.data?.greeting, 160);
  const spotifyId = sanitizeWishText(request.data?.spotifyId, 120);

  if (!title || !artist) {
    throw new HttpsError('invalid-argument', 'Titel und Interpret erforderlich.');
  }

  const djId = resolvePartyOwnerUid(party, ownerUid);
  if (!djId) {
    throw new HttpsError('failed-precondition', 'DJ-ID der Party fehlt.');
  }

  const fromSetlist = request.data?.fromSetlist === true;
  const markPlayed = request.data?.markPlayed === true;
  const requesterMarker = fromSetlist ? FROM_SETLIST_MARKER : MANUAL_BY_DJ_MARKER;

  const wishData = {
    name: '',
    title,
    artist,
    status: markPlayed ? 'played' : 'pending',
    createdAt: FieldValue.serverTimestamp(),
    duplicate_count: 0,
    requested_by: [requesterMarker],
    greetings: greeting ? [{ name: requesterMarker, greeting }] : [],
    is_duplicate: false,
    is_registered_user: true,
    is_registered_users: {},
    client_id: request.auth.uid,
    party_id: partyId,
    dj_id: djId,
    djId,
    isSeen: fromSetlist || markPlayed,
    is_dj_wish: true,
  };
  if (fromSetlist) wishData.from_setlist = true;
  if (markPlayed) {
    wishData.playedAt = FieldValue.serverTimestamp();
    wishData.played_at = FieldValue.serverTimestamp();
  }
  if (spotifyId) wishData.spotify_id = spotifyId;

  const ref = await db.collection('parties').doc(partyId).collection('wishes').add(wishData);
  return {
    wishId: ref.id,
    line: `${artist} – ${title}`,
  };
}

async function pingDjBrowserSessionHandler(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
  }
  const sessionId = String(request.auth.token?.sessionId || '').trim();
  if (!sessionId || request.auth.token?.role !== 'dj_browser') {
    throw new HttpsError('permission-denied', 'Keine Browser-Session.');
  }
  const ref = db.collection(COL_SESSIONS).doc(sessionId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.active !== true) {
    throw new HttpsError('failed-precondition', 'Session beendet.');
  }
  await ref.update({ lastSeenAt: FieldValue.serverTimestamp() });
  return { ok: true };
}

async function djBrowserSyncSetlistLibraryHandler(request) {
  const { partyId, ownerUid } = await assertDjBrowserSession(request);
  if (!ownerUid) {
    throw new HttpsError('failed-precondition', 'DJ-ID fehlt.');
  }
  const partySnap = await db.collection('dj_setlists').doc(partyId).get();
  const raw = partySnap.exists ? (partySnap.data()?.tracks || []) : [];
  const tracks = Array.isArray(raw)
    ? raw.map((item) => {
        if (!item || typeof item !== 'object') return item;
        const copy = { ...item };
        delete copy.moved;
        return copy;
      })
    : [];
  const libLegacy = await db
    .collection('users')
    .doc(ownerUid)
    .collection('dj_setlists')
    .where('partyId', '==', partyId)
    .get();
  const libMulti = await db
    .collection('users')
    .doc(ownerUid)
    .collection('dj_setlists')
    .where('partyIds', 'array-contains', partyId)
    .get();
  const batch = db.batch();
  const seen = new Set();
  let n = 0;
  const apply = (doc) => {
    if (seen.has(doc.id)) return;
    seen.add(doc.id);
    batch.update(doc.ref, {
      tracks,
      targetCount: tracks.length,
      updatedAt: FieldValue.serverTimestamp(),
    });
    n += 1;
  };
  libLegacy.forEach(apply);
  libMulti.forEach(apply);
  if (n > 0) await batch.commit();
  return { ok: true, lists: n };
}

const onPartyUpdatedEndBrowserSessions = onDocumentUpdated(
  'parties/{partyId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after) return;
    const partyId = event.params.partyId;
    const grace = await loadOwnerGraceMinutes(after);
    const wasClosed = isPartyClosedForDjBrowser(before, grace);
    const isClosed = isPartyClosedForDjBrowser(after, grace);
    if (!wasClosed && isClosed) {
      await deactivatePartyBrowserSessions(partyId, 'party_ended');
    }
  },
);

/** Gen-2-Default (compute@developer) hat oft kein signBlob — App-Engine-SA nutzen. */
const DJ_BROWSER_CALLABLE_OPTS = {
  region: 'us-central1',
  enforceAppCheck: false,
  serviceAccount: 'dj-ollerganove@appspot.gserviceaccount.com',
};

function registerDjBrowserSchedules(target) {
  target.djBrowserCodeCleanup = functions
    .runWith({ memory: '256MB', timeoutSeconds: 540 })
    .pubsub.schedule('every 24 hours')
    .timeZone('Europe/Berlin')
    .onRun(async () => {
      await cleanupExpiredDjBrowserCodes();
      return null;
    });
}

function registerDjBrowserCallables(exports) {
  exports.createDjBrowserCode = onCall(
    DJ_BROWSER_CALLABLE_OPTS,
    createDjBrowserCodeHandler,
  );
  exports.revokeDjBrowserCode = onCall(
    DJ_BROWSER_CALLABLE_OPTS,
    revokeDjBrowserCodeHandler,
  );
  exports.redeemDjBrowserCode = onCall(
    DJ_BROWSER_CALLABLE_OPTS,
    redeemDjBrowserCodeHandler,
  );
  exports.confirmDjBrowserRedeem = onCall(
    DJ_BROWSER_CALLABLE_OPTS,
    confirmDjBrowserRedeemHandler,
  );
  exports.getDjBrowserCodeStatus = onCall(
    DJ_BROWSER_CALLABLE_OPTS,
    getDjBrowserCodeStatusHandler,
  );
  exports.pingDjBrowserSession = onCall(
    DJ_BROWSER_CALLABLE_OPTS,
    pingDjBrowserSessionHandler,
  );
  exports.createDjBrowserManualWish = onCall(
    DJ_BROWSER_CALLABLE_OPTS,
    createDjBrowserManualWishHandler,
  );
  exports.djBrowserSyncSetlistLibrary = onCall(
    DJ_BROWSER_CALLABLE_OPTS,
    djBrowserSyncSetlistLibraryHandler,
  );
  exports.onPartyUpdatedEndBrowserSessions = onPartyUpdatedEndBrowserSessions;
}

module.exports = {
  registerDjBrowserCallables,
  registerDjBrowserSchedules,
  cleanupExpiredDjBrowserCodes,
  hashBrowserCode,
  normalizeSixDigitCode,
  isPartyClosedForDjBrowser,
  isCodeDocReclaimable,
  CODE_RETENTION_MS,
};
