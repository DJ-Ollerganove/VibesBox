const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onObjectFinalized } = require('firebase-functions/v2/storage');
const admin = require('firebase-admin');

const db = admin.firestore();
const STORAGE_BUCKET = 'dj-ollerganove.firebasestorage.app';
const MAX_LOGO_BYTES = 2.5 * 1024 * 1024;

/**
 * Wenn die installierte App Storage OK hat, aber users/{uid} per Client
 * permission-denied bekommt: URL trotzdem serverseitig setzen.
 */
async function syncDjLogoUrlFromStorageObject(bucketName, objectPath) {
  const name = String(objectPath || '');
  let uid = null;
  let m = name.match(/^dj_logos\/([^/]+)\.(jpe?g|png)$/i);
  if (m) {
    uid = m[1];
  } else {
    m = name.match(/^dj_logos\/([^/]+)\/logo\.(jpe?g|png)$/i);
    if (m) uid = m[1];
  }
  if (!uid) return null;

  const bucket = admin.storage().bucket(bucketName);
  const file = bucket.file(name);
  const [meta] = await file.getMetadata();
  const metaMap = meta.metadata || {};
  let token = metaMap.firebaseStorageDownloadTokens;
  if (!token) {
    token = crypto.randomUUID();
    await file.setMetadata({
      metadata: {
        ...metaMap,
        firebaseStorageDownloadTokens: token,
      },
    });
  } else if (String(token).includes(',')) {
    token = String(token).split(',')[0].trim();
  }
  const encoded = encodeURIComponent(name);
  const downloadUrl =
    `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}`
    + `?alt=media&token=${token}`;

  await db.collection('users').doc(uid).set(
    {
      dj_logo_url: downloadUrl,
      djLogoUrl: downloadUrl,
    },
    { merge: true },
  );
  return { uid, downloadUrl };
}

const ALLOWED_PATCH_KEYS = new Set([
  'show_greeting_translations',
  'wishbox_suggestions_enabled',
  'grace_period_minutes',
  'mic_sensitivity',
  'recognition_threshold',
  'smart_threshold_enabled',
  'auto_start_recognition',
  'vibesbox_sync_enabled',
  'shazam_scan_interval_seconds',
  'notifyNewWishes',
  'enableNotificationSound',
  'show_status_notification',
  'hasSeenQuickstart',
  'realName',
  'country',
  'birthDate',
  'hasCompletedProfile',
  'alternativeEmail',
  'useAlternativeEmail',
  'displayName',
  'phoneNumber',
  'photoURL',
  'djLogoUrl',
  'dj_logo_url',
  'pendingEmail',
  'email',
  'emailChangeRequestedAt',
  'fcm_token',
  'fcm_token_platform',
  'fcm_token_updated_at',
  'language',
  'selected_language',
  'read_announcements',
  'dj_notif_awaiting_first_device_seed',
  'showLocationOnPdf',
  'showPhoneOnPdf',
  'showEmailOnPdf',
  'showAltEmailOnPdf',
  'last_app_system_locale_tag',
  'song_rec_enabled',
  'song_rec_scope',
  'song_rec_tempo',
  'song_rec_familiarity',
  'song_rec_same_artist',
  'song_rec_count',
]);

function parseTimestampValue(value) {
  if (value instanceof admin.firestore.Timestamp) return value;
  if (value && typeof value === 'object') {
    if (typeof value.seconds === 'number') {
      return new admin.firestore.Timestamp(
        Math.floor(value.seconds),
        Math.floor(value.nanoseconds || 0),
      );
    }
    if (typeof value._seconds === 'number') {
      return new admin.firestore.Timestamp(
        Math.floor(value._seconds),
        Math.floor(value._nanoseconds || 0),
      );
    }
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const d = new Date(value);
    if (!Number.isNaN(d.getTime())) {
      return admin.firestore.Timestamp.fromDate(d);
    }
  }
  return null;
}

function sanitizePatch(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new HttpsError('invalid-argument', 'patch ungültig');
  }
  const patch = {};
  for (const [key, value] of Object.entries(raw)) {
    if (!ALLOWED_PATCH_KEYS.has(key)) continue;
    if (key === 'grace_period_minutes') {
      const n = Number(value);
      if (!Number.isFinite(n) || n < 0 || n > 120 || n % 10 !== 0) {
        throw new HttpsError('invalid-argument', 'grace_period_minutes ungültig');
      }
      patch[key] = n;
      continue;
    }
    if (key === 'mic_sensitivity') {
      const n = Number(value);
      if (!Number.isFinite(n) || n < 0.5 || n > 2.0) {
        throw new HttpsError('invalid-argument', 'mic_sensitivity ungültig');
      }
      patch[key] = n;
      continue;
    }
    if (key === 'recognition_threshold') {
      const n = Number(value);
      if (!Number.isFinite(n) || n < 0 || n > 1) {
        throw new HttpsError('invalid-argument', 'recognition_threshold ungültig');
      }
      patch[key] = n;
      continue;
    }
    if (key === 'shazam_scan_interval_seconds') {
      const n = Number(value);
      if (!Number.isFinite(n) || n < 15 || n > 300) {
        throw new HttpsError('invalid-argument', 'shazam_scan_interval_seconds ungültig');
      }
      patch[key] = Math.round(n);
      continue;
    }
    if (
      key === 'smart_threshold_enabled'
      || key === 'auto_start_recognition'
      || key === 'vibesbox_sync_enabled'
      || key === 'show_greeting_translations'
      || key === 'wishbox_suggestions_enabled'
      || key === 'notifyNewWishes'
      || key === 'enableNotificationSound'
      || key === 'show_status_notification'
      || key === 'hasSeenQuickstart'
      || key === 'hasCompletedProfile'
      || key === 'useAlternativeEmail'
      || key === 'dj_notif_awaiting_first_device_seed'
      || key === 'showLocationOnPdf'
      || key === 'showPhoneOnPdf'
      || key === 'showEmailOnPdf'
      || key === 'showAltEmailOnPdf'
      || key === 'song_rec_enabled'
      || key === 'song_rec_same_artist'
    ) {
      if (typeof value !== 'boolean') {
        throw new HttpsError('invalid-argument', `${key} muss bool sein`);
      }
      patch[key] = value;
      continue;
    }
    if (key === 'song_rec_scope') {
      const v = String(value || '').trim();
      if (v !== 'strict' && v !== 'similar' && v !== 'bold') {
        throw new HttpsError('invalid-argument', 'song_rec_scope ungültig');
      }
      patch[key] = v;
      continue;
    }
    if (key === 'song_rec_tempo') {
      const v = String(value || '').trim();
      if (
        v !== 'exact'
        && v !== 'bpm10'
        && v !== 'bpm20'
        && v !== 'bpm30'
        && v !== 'bpm40'
        && v !== 'over40'
      ) {
        throw new HttpsError('invalid-argument', 'song_rec_tempo ungültig');
      }
      patch[key] = v;
      continue;
    }
    if (key === 'song_rec_familiarity') {
      const v = String(value || '').trim();
      if (v !== 'hits' && v !== 'mix') {
        throw new HttpsError('invalid-argument', 'song_rec_familiarity ungültig');
      }
      patch[key] = v;
      continue;
    }
    if (key === 'song_rec_count') {
      const n = Number(value);
      if (!Number.isFinite(n) || n < 1 || n > 20 || n % 1 !== 0) {
        throw new HttpsError('invalid-argument', 'song_rec_count ungültig');
      }
      patch[key] = n;
      continue;
    }
    if (key === 'alternativeEmail' || key === 'pendingEmail') {
      if (key === 'alternativeEmail' && (value == null || value === '')) {
        patch[key] = admin.firestore.FieldValue.delete();
        continue;
      }
      const email = String(value || '').trim().toLowerCase().slice(0, 100);
      if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new HttpsError('invalid-argument', `${key} ungültig`);
      }
      if (/[<>]/.test(email) || /javascript\s*:/i.test(email)) {
        throw new HttpsError('invalid-argument', `${key} ungültig`);
      }
      patch[key] = email;
      continue;
    }
    if (key === 'displayName') {
      const name = String(value || '').trim().slice(0, 50);
      if (!name) {
        throw new HttpsError('invalid-argument', 'displayName ungültig');
      }
      patch[key] = name;
      continue;
    }
    if (key === 'realName') {
      if (value == null || value === '') {
        patch[key] = admin.firestore.FieldValue.delete();
        continue;
      }
      const name = String(value).trim().slice(0, 80);
      if (!name) {
        patch[key] = admin.firestore.FieldValue.delete();
        continue;
      }
      patch[key] = name;
      continue;
    }
    if (key === 'phoneNumber' || key === 'country') {
      if (value == null || value === '') {
        patch[key] = admin.firestore.FieldValue.delete();
        continue;
      }
      if (key === 'country') {
        const code = String(value).trim().toUpperCase().slice(0, 4);
        if (!/^[A-Z]{2}$/.test(code) && !/^[A-Z]{2,4}$/.test(code)) {
          throw new HttpsError('invalid-argument', 'country ungültig');
        }
        patch[key] = code;
        continue;
      }
      patch[key] = String(value).trim().slice(0, 40);
      continue;
    }
    if (key === 'email') {
      const email = String(value || '').trim().toLowerCase().slice(0, 100);
      if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new HttpsError('invalid-argument', 'email ungültig');
      }
      if (/[<>]/.test(email) || /javascript\s*:/i.test(email)) {
        throw new HttpsError('invalid-argument', 'email ungültig');
      }
      patch[key] = email;
      continue;
    }
    if (key === 'emailChangeRequestedAt') {
      const ts = parseTimestampValue(value);
      if (!ts) {
        throw new HttpsError('invalid-argument', 'emailChangeRequestedAt ungültig');
      }
      patch[key] = ts;
      continue;
    }
    if (key === 'last_app_system_locale_tag') {
      const tag = String(value || '').trim().slice(0, 80);
      if (!tag) {
        throw new HttpsError('invalid-argument', 'last_app_system_locale_tag ungültig');
      }
      patch[key] = tag;
      continue;
    }
    if (key === 'photoURL' || key === 'djLogoUrl' || key === 'dj_logo_url') {
      // Leer/null = Feld löschen (Profilbild / Logo entfernen)
      if (value == null || value === '') {
        patch[key] = admin.firestore.FieldValue.delete();
        continue;
      }
      // Firebase Storage Download-URLs können >300 Zeichen sein
      const url = String(value).trim().slice(0, 2048);
      if (!/^https?:\/\//i.test(url)) {
        throw new HttpsError('invalid-argument', `${key} ungültig`);
      }
      patch[key] = url;
      continue;
    }
    if (key === 'fcm_token') {
      const token = String(value || '').trim().slice(0, 4096);
      if (!token) {
        throw new HttpsError('invalid-argument', 'fcm_token ungültig');
      }
      patch[key] = token;
      // Serverzeit setzen, wenn Client kein Timestamp mitschickt
      if (!('fcm_token_updated_at' in patch)) {
        patch.fcm_token_updated_at = admin.firestore.FieldValue.serverTimestamp();
      }
      continue;
    }
    if (key === 'fcm_token_platform') {
      const p = String(value || '').trim().toLowerCase();
      if (p !== 'ios' && p !== 'android' && p !== 'web') {
        throw new HttpsError('invalid-argument', 'fcm_token_platform ungültig');
      }
      patch[key] = p;
      continue;
    }
    if (key === 'fcm_token_updated_at') {
      const ts = parseTimestampValue(value);
      if (!ts) {
        throw new HttpsError('invalid-argument', 'fcm_token_updated_at ungültig');
      }
      patch[key] = ts;
      continue;
    }
    if (key === 'language' || key === 'selected_language') {
      const code = String(value || '').trim().toLowerCase().slice(0, 12);
      if (!/^[a-z]{2,3}$/.test(code)) {
        throw new HttpsError('invalid-argument', `${key} ungültig`);
      }
      patch[key] = code;
      continue;
    }
    if (key === 'read_announcements') {
      if (!Array.isArray(value) || value.length > 200) {
        throw new HttpsError('invalid-argument', 'read_announcements ungültig');
      }
      patch[key] = value.map((v) => String(v || '').trim().slice(0, 120)).filter(Boolean);
      continue;
    }
    if (key === 'birthDate') {
      if (value == null || value === '') {
        patch[key] = admin.firestore.FieldValue.delete();
        continue;
      }
      const ts = parseTimestampValue(value);
      if (!ts) {
        throw new HttpsError('invalid-argument', 'birthDate ungültig');
      }
      const d = ts.toDate();
      const now = new Date();
      if (d.getTime() > now.getTime()) {
        throw new HttpsError('invalid-argument', 'birthDate in der Zukunft');
      }
      let age = now.getFullYear() - d.getFullYear();
      const m = now.getMonth() - d.getMonth();
      if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age -= 1;
      if (age < 10) {
        throw new HttpsError('invalid-argument', 'Mindestalter 10 Jahre');
      }
      patch[key] = ts;
      continue;
    }
  }
  if (Object.keys(patch).length === 0) {
    throw new HttpsError('invalid-argument', 'patch leer oder keine erlaubten Felder');
  }
  return patch;
}

function sanitizeDeviceKey(raw) {
  const key = String(raw || '').trim().replace(/\./g, '_');
  if (!key || key.length > 128) {
    throw new HttpsError('invalid-argument', 'deviceKey ungültig');
  }
  return key;
}

function sanitizeDevicePayload(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new HttpsError('invalid-argument', 'payload ungültig');
  }
  const appVersion = String(raw.app_version || '').trim();
  const deviceModel = String(raw.device_model || '').trim();
  const platform = String(raw.platform || '').trim().toLowerCase();
  if (!appVersion || appVersion.length > 40) {
    throw new HttpsError('invalid-argument', 'app_version ungültig');
  }
  if (!deviceModel || deviceModel.length > 120) {
    throw new HttpsError('invalid-argument', 'device_model ungültig');
  }
  if (platform !== 'ios' && platform !== 'android') {
    throw new HttpsError('invalid-argument', 'platform ungültig');
  }
  const osVersion = String(raw.os_version || '').trim();
  if (!osVersion || osVersion.length > 40) {
    throw new HttpsError('invalid-argument', 'os_version ungültig');
  }
  const payload = {
    app_version: appVersion,
    device_model: deviceModel,
    os_version: osVersion,
    platform,
    last_seen: admin.firestore.FieldValue.serverTimestamp(),
  };
  const code = String(raw.device_model_code || '').trim();
  if (code && code.length <= 40) payload.device_model_code = code;
  const locale = String(raw.system_locale_tag || '').trim();
  if (locale && locale.length <= 80) payload.system_locale_tag = locale;
  const appLanguage = String(raw.app_language || '').trim().toLowerCase();
  if (appLanguage && appLanguage.length <= 12) payload.app_language = appLanguage;
  const versionName = String(raw.version_name || '').trim();
  if (versionName && versionName.length <= 40) payload.version_name = versionName;
  const buildNumber = String(raw.build_number || '').trim();
  if (buildNumber && buildNumber.length <= 20) payload.build_number = buildNumber;
  return payload;
}

async function logUserDeviceTelemetryHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const deviceKey = sanitizeDeviceKey((request.data || {}).deviceKey);
  const payload = sanitizeDevicePayload((request.data || {}).payload);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const update = {
    [`devices.${deviceKey}`]: payload,
    app_version: payload.app_version,
    platform: payload.platform,
    device_model: payload.device_model,
    os_version: payload.os_version,
    app_version_updated_at: now,
    last_seen: now,
  };
  if (payload.device_model_code) {
    update.device_model_code = payload.device_model_code;
  }
  if (payload.system_locale_tag) {
    update.last_app_system_locale_tag = payload.system_locale_tag;
  }
  // Alle Geräte-Einträge bleiben erhalten (Admin soll Historie sehen).
  await db.collection('users').doc(uid).set(update, { merge: true });
  return { ok: true, deviceKey };
}

async function recordUserLoginActivityHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const body = request.data || {};
  const email = String(body.email || '').trim().slice(0, 100);
  const displayName = String(body.displayName || '').trim().slice(0, 50);
  const seedCreatedAt = body.seedCreatedAt === true;

  const ref = db.collection('users').doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const prev = snap.exists ? snap.data() : {};
    let count = 0;
    if (typeof prev.loginCount === 'number' && Number.isFinite(prev.loginCount)) {
      count = Math.max(0, Math.floor(prev.loginCount));
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    const patch = {
      loginCount: count + 1,
      lastLogin: now,
      previousLogin: prev.lastLogin || null,
    };
    if (email) patch.email = email;
    if (displayName) patch.displayName = displayName;
    if (seedCreatedAt && !prev.created_at) {
      patch.created_at = now;
    }
    tx.set(ref, patch, { merge: true });
  });
  return { ok: true };
}

async function patchUserSelfSettingsHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const patch = sanitizePatch((request.data || {}).patch);
  await db.collection('users').doc(uid).set(patch, { merge: true });
  return { ok: true, keys: Object.keys(patch) };
}

/**
 * DJ-Logo serverseitig speichern (Admin SDK).
 * Umgeht Client-Storage-Rules / App-Check — Ursache für firebase_storage/unauthorized.
 */
async function uploadDjLogoSecureHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const body = request.data || {};
  const rawB64 = String(body.imageBase64 || '')
    .replace(/^data:image\/[a-zA-Z0-9.+-]+;base64,/, '')
    .trim();
  if (!rawB64 || rawB64.length < 32) {
    throw new HttpsError('invalid-argument', 'Bild fehlt');
  }
  // Base64 ist ~4/3 der Binary-Größe
  if (rawB64.length > Math.ceil(MAX_LOGO_BYTES * 1.4) + 64) {
    throw new HttpsError('invalid-argument', 'Bild zu groß');
  }

  let buffer;
  try {
    buffer = Buffer.from(rawB64, 'base64');
  } catch (_) {
    throw new HttpsError('invalid-argument', 'Bild ungültig');
  }
  if (!buffer.length || buffer.length > MAX_LOGO_BYTES) {
    throw new HttpsError('invalid-argument', 'Bild zu groß');
  }

  let ext = String(body.extension || 'jpg').toLowerCase().replace(/[^a-z]/g, '');
  if (ext === 'jpeg') ext = 'jpg';
  if (ext !== 'jpg' && ext !== 'png') ext = 'jpg';
  let contentType = String(body.contentType || '').toLowerCase().trim();
  if (contentType !== 'image/png' && contentType !== 'image/jpeg') {
    contentType = ext === 'png' ? 'image/png' : 'image/jpeg';
  }

  const token = crypto.randomUUID();
  const objectPath = `dj_logos/${uid}/logo.${ext}`;
  const bucket = admin.storage().bucket(STORAGE_BUCKET);
  const file = bucket.file(objectPath);
  await file.save(buffer, {
    resumable: false,
    metadata: {
      contentType,
      cacheControl: 'public, max-age=31536000',
      metadata: {
        firebaseStorageDownloadTokens: token,
      },
    },
  });

  const encoded = encodeURIComponent(objectPath);
  const downloadUrl =
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encoded}`
    + `?alt=media&token=${token}`;

  await db.collection('users').doc(uid).set(
    {
      dj_logo_url: downloadUrl,
      djLogoUrl: downloadUrl,
    },
    { merge: true },
  );

  return { ok: true, downloadUrl, path: objectPath };
}

async function deleteDjLogoSecureHandler(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  }
  const uid = request.auth.uid;
  const bucket = admin.storage().bucket(STORAGE_BUCKET);
  const candidates = [
    `dj_logos/${uid}/logo.jpg`,
    `dj_logos/${uid}/logo.png`,
    `dj_logos/${uid}.jpg`,
    `dj_logos/${uid}.png`,
  ];
  await Promise.all(
    candidates.map(async (p) => {
      try {
        await bucket.file(p).delete({ ignoreNotFound: true });
      } catch (_) {
        /* ignore */
      }
    }),
  );
  await db.collection('users').doc(uid).set(
    {
      dj_logo_url: admin.firestore.FieldValue.delete(),
      djLogoUrl: admin.firestore.FieldValue.delete(),
    },
    { merge: true },
  );
  return { ok: true };
}

function registerUserSelfSettingsCallables(exports) {
  exports.patchUserSelfSettings = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    patchUserSelfSettingsHandler,
  );
  exports.uploadDjLogoSecure = onCall(
    {
      region: 'us-central1',
      enforceAppCheck: false,
      // Base64-Logo bis ~2.5MB Binary
      memory: '512MiB',
      timeoutSeconds: 60,
    },
    uploadDjLogoSecureHandler,
  );
  exports.deleteDjLogoSecure = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    deleteDjLogoSecureHandler,
  );
  exports.logUserDeviceTelemetry = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    logUserDeviceTelemetryHandler,
  );
  exports.recordUserLoginActivity = onCall(
    { region: 'us-central1', enforceAppCheck: false },
    recordUserLoginActivityHandler,
  );

  // Bucket liegt in EU — Trigger muss dieselbe Region haben.
  exports.onDjLogoObjectFinalized = onObjectFinalized(
    {
      bucket: STORAGE_BUCKET,
      region: 'europe-west1',
      memory: '256MiB',
    },
    async (event) => {
      const objectPath = event.data.name;
      if (!objectPath || !String(objectPath).startsWith('dj_logos/')) {
        return;
      }
      try {
        await syncDjLogoUrlFromStorageObject(event.data.bucket, objectPath);
      } catch (e) {
        console.error('onDjLogoObjectFinalized failed', objectPath, e);
        throw e;
      }
    },
  );
}

module.exports = {
  registerUserSelfSettingsCallables,
  patchUserSelfSettingsHandler,
  uploadDjLogoSecureHandler,
  deleteDjLogoSecureHandler,
  logUserDeviceTelemetryHandler,
  recordUserLoginActivityHandler,
  sanitizePatch,
  sanitizeDevicePayload,
  syncDjLogoUrlFromStorageObject,
};
