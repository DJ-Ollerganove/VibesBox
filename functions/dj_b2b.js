/**
 * DJ B2B — Werber-System (Codes, Trial 7/2, Ledger, Webhook-Hooks).
 */
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const functions = require('firebase-functions');

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const DJ_B2B_CODE_RE = /^DJ\d{6}$/;
const BONUS_DAYS = 14;
const HOLD_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
const PURCHASE_RELEVANT_TYPES = [
  'INITIAL_PURCHASE',
  'RENEWAL',
  'NON_RENEWING_PURCHASE',
  'PRODUCT_CHANGE',
];
const REFUND_TYPES = ['CANCELLATION', 'REFUND', 'BILLING_ISSUE'];

function normalizeDjB2bCode(raw) {
  if (raw == null) return null;
  const c = String(raw).trim().toUpperCase();
  return DJ_B2B_CODE_RE.test(c) ? c : null;
}

function dateKeyLocal(d) {
  const x = d instanceof Date ? d : new Date(d);
  const y = x.getFullYear();
  const m = String(x.getMonth() + 1).padStart(2, '0');
  const day = String(x.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** Trial-Ende: N Tage ab [from], auf nächste volle Stunde gerundet. */
function computeTrialEndRoundedToNextHour(from, dayCount) {
  const base = from instanceof Date ? from : new Date(from);
  const plus = new Date(base.getTime() + dayCount * 24 * 60 * 60 * 1000);
  if (
    plus.getMinutes() === 0 &&
    plus.getSeconds() === 0 &&
    plus.getMilliseconds() === 0
  ) {
    return plus;
  }
  return new Date(
    plus.getFullYear(),
    plus.getMonth(),
    plus.getDate(),
    plus.getHours() + 1,
    0,
    0,
    0,
  );
}

function ledgerDefaults(data) {
  return {
    lifetime: Number(data?.djB2bDaysLifetimeEarned || 0),
    pending: Number(data?.djB2bDaysPendingHold || 0),
    available: Number(data?.djB2bDaysAvailable || 0),
    consumptionActive: data?.djB2bDaysConsumptionActive === true,
    lastConsumedDate:
      typeof data?.djB2bDaysLastConsumedDate === 'string'
        ? data.djB2bDaysLastConsumedDate
        : null,
  };
}

function hasActivePaidStoreSubscription(data, nowMs = Date.now()) {
  if (!data || data.isPro !== true) return false;
  const trialUntil = data.trialUntil?.toDate?.();
  if (data.planType === 'trial' && trialUntil && trialUntil.getTime() > nowMs) {
    return false;
  }
  if (data.planType === 'dj_b2b' && data.djB2bDaysConsumptionActive === true) {
    return false;
  }
  const proUntil = data.proUntil?.toDate?.();
  if (!proUntil || proUntil.getTime() <= nowMs) return false;
  if (proUntil.getFullYear() >= 2099) return true;
  const provider = String(data.lastPaymentProvider || '').trim();
  if (provider === 'RevenueCat') return true;
  return data.planType === 'pro';
}

function anonymizedReferralLabel(index) {
  return `DJ #${index + 1}`;
}

async function assertCallerIsAdminOrDj(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  const uid = request.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError('permission-denied', 'User document not found.');
  }
  const userData = userSnap.data();
  if (userData && userData.admin === true) return;
  const roleId =
    userData && userData.role_id != null ? String(userData.role_id).trim() : '';
  if (!roleId) {
    throw new HttpsError('permission-denied', 'Admin or DJ role required.');
  }
  const roleSnap = await db.collection('roles').doc(roleId).get();
  if (!roleSnap.exists) {
    throw new HttpsError('permission-denied', 'Admin or DJ role required.');
  }
  const roleName = roleSnap.data()?.name;
  const n = typeof roleName === 'string' ? roleName.trim() : '';
  if (n === 'Admin' || n === 'DJ') return;
  throw new HttpsError('permission-denied', 'Admin or DJ role required.');
}

async function resolveReferrerUidFromCode(code) {
  const normalized = normalizeDjB2bCode(code);
  if (!normalized) return null;
  const doc = await db.collection('referral_codes').doc(normalized).get();
  if (!doc.exists) return null;
  const uid = doc.data()?.uid;
  return typeof uid === 'string' && uid.length > 0 ? uid : null;
}

async function allocateNextDjB2bCode(tx) {
  const counterRef = db.collection('admin_config').doc('dj_b2b_counter');
  const counterSnap = await tx.get(counterRef);
  let next = 1;
  if (counterSnap.exists) {
    next = Number(counterSnap.data()?.next || 1);
    if (!Number.isFinite(next) || next < 1) next = 1;
  }
  let code = '';
  for (let i = 0; i < 20; i++) {
    const candidate = `DJ${String(next).padStart(6, '0')}`;
    const codeRef = db.collection('referral_codes').doc(candidate);
    const codeSnap = await tx.get(codeRef);
    if (!codeSnap.exists) {
      code = candidate;
      tx.set(counterRef, { next: next + 1, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      tx.set(codeRef, {
        uid: null,
        reserved: true,
        created_at: FieldValue.serverTimestamp(),
      });
      break;
    }
    next += 1;
  }
  if (!code) throw new Error('Could not allocate unique DJ B2B code.');
  return code;
}

async function ensureDjB2bCodeForUid(uid) {
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'User not found.');
  }
  const data = userSnap.data() || {};
  const existing = normalizeDjB2bCode(data.djB2bCode);
  if (existing) return existing;

  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(userRef);
    if (!fresh.exists) throw new HttpsError('not-found', 'User not found.');
    const d = fresh.data() || {};
    const again = normalizeDjB2bCode(d.djB2bCode);
    if (again) return again;

    const code = await allocateNextDjB2bCode(tx);
    tx.set(
      userRef,
      {
        djB2bCode: code,
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.set(
      db.collection('referral_codes').doc(code),
      {
        uid,
        created_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return code;
  });
}

async function linkReferralOnUser({
  referredUid,
  referrerUid,
  code,
  source,
  activateSevenDayTrial,
}) {
  if (referredUid === referrerUid) {
    throw new HttpsError('invalid-argument', 'Self-referral not allowed.');
  }

  const referredRef = db.collection('users').doc(referredUid);
  const referrerRef = db.collection('users').doc(referrerUid);

  return db.runTransaction(async (tx) => {
    const [referredSnap, referrerSnap] = await Promise.all([
      tx.get(referredRef),
      tx.get(referrerRef),
    ]);
    if (!referredSnap.exists) {
      throw new HttpsError('not-found', 'User not found.');
    }
    if (!referrerSnap.exists) {
      throw new HttpsError('not-found', 'Referrer not found.');
    }

    const referredData = referredSnap.data() || {};
    if (referredData.referredByUid) {
      throw new HttpsError('failed-precondition', 'Referral already redeemed.');
    }
    // Trial-Sperre nur wenn wirklich 7-Tage-Trial aktiviert wird.
    // Direktkauf mit Werbercode (ohne Testphase) muss trotzdem verknüpfen können.
    if (activateSevenDayTrial && referredData.trialUsed === true) {
      throw new HttpsError('failed-precondition', 'Trial already used.');
    }

    const now = new Date();
    const trialDays = activateSevenDayTrial ? 7 : 0;
    const update = {
      referredByUid: referrerUid,
      referredByCode: code,
      referralCapturedAt: FieldValue.serverTimestamp(),
      referralRedeemedAt: FieldValue.serverTimestamp(),
      referralSource: source || 'manual',
      updated_at: FieldValue.serverTimestamp(),
    };

    if (activateSevenDayTrial) {
      const trialUntil = computeTrialEndRoundedToNextHour(now, trialDays);
      update.trialUntil = Timestamp.fromDate(trialUntil);
      update.trialUsed = true;
      update.planType = 'trial';
      update.isPro = true;
      update.proUntil = Timestamp.fromDate(trialUntil);
      update.trialDaysGranted = trialDays;
      update.trialUsedDjB2bCode = code;
    }

    tx.set(referredRef, update, { merge: true });

    const referrerData = referrerSnap.data() || {};
    const nextIndex = Number(referrerData.djB2bReferralCount || 0);
    tx.set(
      referrerRef,
      { djB2bReferralCount: nextIndex + 1 },
      { merge: true },
    );

    tx.set(referrerRef.collection('dj_b2b_referrals').doc(referredUid), {
      referredUid,
      index: nextIndex,
      label: anonymizedReferralLabel(nextIndex),
      registeredAt: FieldValue.serverTimestamp(),
      codeUsed: code,
      paymentStatus: 'none',
      bonusStatus: 'none',
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return { trialDays, trialUntil: activateSevenDayTrial ? update.trialUntil : null };
  });
}

async function redeemDjB2bCodeLogic(uid, rawCode, source, { activateTrial = false } = {}) {
  const code = normalizeDjB2bCode(rawCode);
  if (!code) {
    throw new HttpsError('invalid-argument', 'Invalid DJ B2B code.');
  }
  const referrerUid = await resolveReferrerUidFromCode(code);
  if (!referrerUid) {
    throw new HttpsError('not-found', 'Code not found.');
  }
  return linkReferralOnUser({
    referredUid: uid,
    referrerUid,
    code,
    source: source || 'manual',
    activateSevenDayTrial: activateTrial,
  });
}

async function getDjB2bOverviewLogic(uid) {
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'User not found.');
  }
  const data = userSnap.data() || {};
  const ledger = ledgerDefaults(data);
  const code = normalizeDjB2bCode(data.djB2bCode) || null;

  const referralsSnap = await userRef
    .collection('dj_b2b_referrals')
    .orderBy('index', 'asc')
    .limit(100)
    .get();

  const referrals = referralsSnap.docs.map((doc) => {
    const r = doc.data();
    return {
      id: doc.id,
      label: r.label || anonymizedReferralLabel(Number(r.index || 0)),
      registeredAt: r.registeredAt?.toDate?.()?.toISOString?.() || null,
      paymentStatus: r.paymentStatus || 'none',
      bonusStatus: r.bonusStatus || 'none',
      firstPaymentAt: r.firstPaymentAt?.toDate?.()?.toISOString?.() || null,
      bonusReleasedAt: r.bonusReleasedAt?.toDate?.()?.toISOString?.() || null,
    };
  });

  const nowMs = Date.now();
  const paidSubActive = hasActivePaidStoreSubscription(data, nowMs);

  return {
    code,
    inviteUrl: code ? `https://vibesbox.app/invite/${code}` : null,
    ledger,
    referralCount: Number(data.djB2bReferralCount || 0),
    referrals,
    planType: data.planType || 'free',
    trialUntil: data.trialUntil?.toDate?.()?.toISOString?.() || null,
    proUntil: data.proUntil?.toDate?.()?.toISOString?.() || null,
    isPro: data.isPro === true,
    paidSubscriptionActive: paidSubActive,
    store: data.lastPaymentStore || data.store || null,
    lastPaymentProvider: data.lastPaymentProvider || null,
    referredByCode: normalizeDjB2bCode(data.referredByCode) || null,
    trialUsed: data.trialUsed === true,
  };
}

async function startDjB2bConsumptionLogic(uid) {
  const userRef = db.collection('users').doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError('not-found', 'User not found.');
    const data = snap.data() || {};
    if (hasActivePaidStoreSubscription(data)) {
      throw new HttpsError(
        'failed-precondition',
        'Paid subscription active — cancel in store first.',
      );
    }
    const ledger = ledgerDefaults(data);
    if (ledger.available <= 0) {
      throw new HttpsError('failed-precondition', 'No DJ B2B days available.');
    }
    if (ledger.consumptionActive) {
      return { alreadyActive: true };
    }
    tx.set(
      userRef,
      {
        djB2bDaysConsumptionActive: true,
        planType: 'dj_b2b',
        isPro: true,
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { alreadyActive: false };
  });
}

async function stopDjB2bConsumptionLogic(uid) {
  const userRef = db.collection('users').doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError('not-found', 'User not found.');
    const data = snap.data() || {};
    const ledger = ledgerDefaults(data);
    const update = {
      djB2bDaysConsumptionActive: false,
      updated_at: FieldValue.serverTimestamp(),
    };
    if (data.planType === 'dj_b2b') {
      if (hasActivePaidStoreSubscription(data)) {
        update.planType = 'pro';
      } else if (ledger.available <= 0) {
        update.planType = 'free';
        update.isPro = false;
      } else {
        update.planType = 'free';
        update.isPro = false;
      }
    }
    tx.set(userRef, update, { merge: true });
    return { ok: true };
  });
}

async function activateDjTrialLogic(uid, rawCode) {
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) throw new HttpsError('not-found', 'User not found.');
  const data = userSnap.data() || {};
  if (data.trialUsed === true) {
    throw new HttpsError('failed-precondition', 'Trial already used.');
  }

  const normalizedCode = normalizeDjB2bCode(rawCode);
  const alreadyReferred = !!(
    data.referredByUid
    || normalizeDjB2bCode(data.referredByCode)
  );

  // Noch nicht verknüpft + Code → Redeem inkl. 7-Tage-Trial
  if (normalizedCode && !alreadyReferred) {
    return redeemDjB2bCodeLogic(uid, normalizedCode, 'trial', { activateTrial: true });
  }

  // Bereits bei Registrierung/Link verknüpft → 7 Tage; sonst 2 Tage ohne Code
  const trialDays = alreadyReferred ? 7 : 2;
  const now = new Date();
  const trialUntil = computeTrialEndRoundedToNextHour(now, trialDays);
  const update = {
    trialUntil: Timestamp.fromDate(trialUntil),
    trialUsed: true,
    planType: 'trial',
    isPro: true,
    proUntil: Timestamp.fromDate(trialUntil),
    trialDaysGranted: trialDays,
    updated_at: FieldValue.serverTimestamp(),
  };
  const existingCode = normalizeDjB2bCode(data.referredByCode);
  if (existingCode) {
    update.trialUsedDjB2bCode = existingCode;
  }
  await userRef.set(update, { merge: true });
  return { trialDays, trialUntil: Timestamp.fromDate(trialUntil) };
}

async function processDjB2bPurchaseBonus(appUserId, eventType, transactionId, purchasedAtMs) {
  if (!PURCHASE_RELEVANT_TYPES.includes(eventType)) return;

  const userRef = db.collection('users').doc(appUserId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) return;
  const userData = userSnap.data() || {};
  const referrerUid = userData.referredByUid || userData.referredBy;
  if (!referrerUid || typeof referrerUid !== 'string') return;

  const referralRef = db
    .collection('users')
    .doc(referrerUid)
    .collection('dj_b2b_referrals')
    .doc(appUserId);
  const referralSnap = await referralRef.get();
  const referralData = referralSnap.exists ? referralSnap.data() : {};

  if (referralData.bonusStatus === 'released' || referralData.bonusStatus === 'pending') {
    if (eventType !== 'INITIAL_PURCHASE') return;
    if (referralData.bonusStatus === 'pending') return;
  }

  const purchasedAt = purchasedAtMs
    ? Timestamp.fromMillis(Number(purchasedAtMs))
    : Timestamp.now();
  const releaseAt = Timestamp.fromMillis(purchasedAt.toMillis() + HOLD_DAYS_MS);

  const referrerRef = db.collection('users').doc(referrerUid);

  await db.runTransaction(async (tx) => {
    const refSnap = await tx.get(referrerRef);
    if (!refSnap.exists) return;
    const refData = refSnap.data() || {};
    const ledger = ledgerDefaults(refData);

    if (eventType === 'INITIAL_PURCHASE') {
      tx.set(
        referrerRef,
        {
          djB2bDaysPendingHold: ledger.pending + BONUS_DAYS,
          djB2bDaysLifetimeEarned: ledger.lifetime + BONUS_DAYS,
          updated_at: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(
        referralRef,
        {
          referredUid: appUserId,
          paymentStatus: 'paid',
          bonusStatus: 'pending',
          firstPaymentAt: purchasedAt,
          bonusReleaseAt: releaseAt,
          bonusTransactionId: transactionId || null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  });
}

async function processDjB2bRefund(appUserId) {
  const userRef = db.collection('users').doc(appUserId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) return;
  const userData = userSnap.data() || {};
  const referrerUid = userData.referredByUid || userData.referredBy;
  if (!referrerUid) return;

  const referralRef = db
    .collection('users')
    .doc(referrerUid)
    .collection('dj_b2b_referrals')
    .doc(appUserId);
  const referralSnap = await referralRef.get();
  if (!referralSnap.exists) return;
  const referralData = referralSnap.data() || {};
  if (referralData.bonusStatus === 'none' || referralData.bonusStatus === 'revoked') return;

  const referrerRef = db.collection('users').doc(referrerUid);

  await db.runTransaction(async (tx) => {
    const refSnap = await tx.get(referrerRef);
    if (!refSnap.exists) return;
    const refData = refSnap.data() || {};
    const ledger = ledgerDefaults(refData);

    const updates = { updated_at: FieldValue.serverTimestamp() };
    if (referralData.bonusStatus === 'pending') {
      updates.djB2bDaysPendingHold = Math.max(0, ledger.pending - BONUS_DAYS);
      updates.djB2bDaysLifetimeEarned = Math.max(0, ledger.lifetime - BONUS_DAYS);
    } else if (referralData.bonusStatus === 'released') {
      updates.djB2bDaysAvailable = Math.max(0, ledger.available - BONUS_DAYS);
      updates.djB2bDaysLifetimeEarned = Math.max(0, ledger.lifetime - BONUS_DAYS);
    }

    tx.set(referrerRef, updates, { merge: true });
    tx.set(
      referralRef,
      {
        bonusStatus: 'revoked',
        paymentStatus: 'refunded',
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

async function releaseDueDjB2bBonuses() {
  const now = Timestamp.now();
  const snap = await db.collectionGroup('dj_b2b_referrals')
    .where('bonusStatus', '==', 'pending')
    .where('bonusReleaseAt', '<=', now)
    .limit(200)
    .get();

  for (const doc of snap.docs) {
    const data = doc.data();
    const referrerUid = doc.ref.parent.parent.id;
    const referredUid = doc.id;
    const referrerRef = db.collection('users').doc(referrerUid);

    await db.runTransaction(async (tx) => {
      const freshReferral = await tx.get(doc.ref);
      if (!freshReferral.exists) return;
      const r = freshReferral.data();
      if (r.bonusStatus !== 'pending') return;
      const releaseAt = r.bonusReleaseAt?.toMillis?.() || 0;
      if (releaseAt > now.toMillis()) return;

      const refSnap = await tx.get(referrerRef);
      if (!refSnap.exists) return;
      const refData = refSnap.data() || {};
      const ledger = ledgerDefaults(refData);

      tx.set(
        referrerRef,
        {
          djB2bDaysPendingHold: Math.max(0, ledger.pending - BONUS_DAYS),
          djB2bDaysAvailable: ledger.available + BONUS_DAYS,
          updated_at: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(
        doc.ref,
        {
          bonusStatus: 'released',
          bonusReleasedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      console.log(`DJ B2B bonus released: referrer=${referrerUid} referred=${referredUid}`);
    });
  }
}

async function consumeDjB2bDailyDays() {
  const snap = await db.collection('users')
    .where('djB2bDaysConsumptionActive', '==', true)
    .limit(500)
    .get();

  const today = dateKeyLocal(new Date());

  for (const doc of snap.docs) {
    const data = doc.data();
    const ledger = ledgerDefaults(data);
    if (ledger.lastConsumedDate === today) continue;
    if (hasActivePaidStoreSubscription(data)) {
      if (data.djB2bDaysConsumptionActive === true) {
        await doc.ref.set(
          { djB2bDaysConsumptionActive: false, updated_at: FieldValue.serverTimestamp() },
          { merge: true },
        );
      }
      continue;
    }
    if (ledger.available <= 0) {
      await doc.ref.set(
        {
          djB2bDaysConsumptionActive: false,
          planType: 'free',
          isPro: false,
          updated_at: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      continue;
    }

    const nextAvailable = ledger.available - 1;
    const update = {
      djB2bDaysAvailable: nextAvailable,
      djB2bDaysLastConsumedDate: today,
      updated_at: FieldValue.serverTimestamp(),
    };
    if (nextAvailable <= 0) {
      update.djB2bDaysConsumptionActive = false;
      update.planType = 'free';
      update.isPro = false;
    } else {
      update.planType = 'dj_b2b';
      update.isPro = true;
    }
    await doc.ref.set(update, { merge: true });
  }
}

async function runDjB2bDailyMaintenance() {
  await releaseDueDjB2bBonuses();
  await consumeDjB2bDailyDays();
}

function registerDjB2bCallables(target) {
  target.ensureDjB2bCode = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    async (request) => {
      if (!request.auth) throw new HttpsError('unauthenticated', 'Auth required.');
      await assertCallerIsAdminOrDj(request);
      const code = await ensureDjB2bCodeForUid(request.auth.uid);
      return { code, inviteUrl: `https://vibesbox.app/invite/${code}` };
    },
  );

  target.redeemDjB2bCode = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    async (request) => {
      if (!request.auth) throw new HttpsError('unauthenticated', 'Auth required.');
      const code = request.data?.code;
      const activateTrial = request.data?.activateTrial === true;
      const source = request.data?.source || 'manual';
      return redeemDjB2bCodeLogic(request.auth.uid, code, source, { activateTrial });
    },
  );

  target.activateDjTrial = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    async (request) => {
      if (!request.auth) throw new HttpsError('unauthenticated', 'Auth required.');
      const code = request.data?.b2bCode || request.data?.code || null;
      return activateDjTrialLogic(request.auth.uid, code);
    },
  );

  target.getDjB2bOverview = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    async (request) => {
      if (!request.auth) throw new HttpsError('unauthenticated', 'Auth required.');
      await assertCallerIsAdminOrDj(request);
      return getDjB2bOverviewLogic(request.auth.uid);
    },
  );

  target.startDjB2bConsumption = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    async (request) => {
      if (!request.auth) throw new HttpsError('unauthenticated', 'Auth required.');
      await assertCallerIsAdminOrDj(request);
      return startDjB2bConsumptionLogic(request.auth.uid);
    },
  );

  target.stopDjB2bConsumption = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    async (request) => {
      if (!request.auth) throw new HttpsError('unauthenticated', 'Auth required.');
      await assertCallerIsAdminOrDj(request);
      return stopDjB2bConsumptionLogic(request.auth.uid);
    },
  );
}

function registerDjB2bSchedules(target) {
  target.djB2bDailyMaintenance = functions
    .runWith({ memory: '256MB', timeoutSeconds: 540 })
    .pubsub.schedule('every 24 hours')
    .timeZone('Europe/Berlin')
    .onRun(async () => {
      await runDjB2bDailyMaintenance();
      return null;
    });
}

async function backfillDjB2bCodesLogic(limit = 500) {
  const snap = await db.collection('users').limit(limit).get();
  let created = 0;
  let skipped = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const roleId = data.role_id;
    if (!roleId) {
      skipped += 1;
      continue;
    }
    const roleSnap = await db.collection('roles').doc(String(roleId)).get();
    const roleName = roleSnap.data()?.name;
    if (roleName !== 'DJ' && roleName !== 'Admin' && data.admin !== true) {
      skipped += 1;
      continue;
    }
    if (normalizeDjB2bCode(data.djB2bCode)) {
      skipped += 1;
      continue;
    }
    await ensureDjB2bCodeForUid(doc.id);
    created += 1;
  }
  return { created, skipped, scanned: snap.size };
}

module.exports = {
  registerDjB2bCallables,
  registerDjB2bSchedules,
  processDjB2bPurchaseBonus,
  processDjB2bRefund,
  ensureDjB2bCodeForUid,
  backfillDjB2bCodesLogic,
  normalizeDjB2bCode,
  REFUND_TYPES,
};
