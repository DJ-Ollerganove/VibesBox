const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const crypto = require('crypto');
const cors = require('cors')({
  origin: true,
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Firebase-AppCheck',
    'X-Client-Id',
    'x-client-id',
  ],
});
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');

// Secrets (2nd Gen / Secret Manager)
const SPOTIFY_CLIENT_ID = defineSecret('SPOTIFY_CLIENT_ID');
const SPOTIFY_CLIENT_SECRET = defineSecret('SPOTIFY_CLIENT_SECRET');
/** Google Cloud API-Key mit aktivierter „reCAPTCHA Enterprise API“ (Assessments). */
const RECAPTCHA_ENTERPRISE_API_KEY = defineSecret('RECAPTCHA_ENTERPRISE_API_KEY');
const EMAILJS_PRIVATE_KEY = defineSecret('EMAILJS_PRIVATE_KEY');
const REVENUECAT_WEBHOOK_SECRET = defineSecret('REVENUECAT_WEBHOOK_SECRET');
const APPLE_DEVELOPER_TOKEN = defineSecret('APPLE_DEVELOPER_TOKEN');

// Firebase Admin initialisieren (nur einmal)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const MASTER_ADMIN_UID = 'rtJXMTULzTPUz0xtdQOw9Jm8SGD3';

/**
 * EmailJS Service-/Template-ID und Public Key (kein Private Key).
 * Reihenfolge: `process.env.EMAILJS_*` (Console / .env), sonst Legacy
 * `firebase functions:config:set emailjs.*` → `functions.config().emailjs`.
 */
function getEmailJsPublicIds() {
  let serviceId = (process.env.EMAILJS_SERVICE_ID || '').trim();
  let templateId = (process.env.EMAILJS_TEMPLATE_ID || '').trim();
  let publicKey = (process.env.EMAILJS_PUBLIC_KEY || '').trim();
  if (serviceId && templateId && publicKey) {
    return { serviceId, templateId, publicKey };
  }
  try {
    const ej = functions.config().emailjs || {};
    serviceId = serviceId || String(ej.service_id || ej.serviceId || '').trim();
    templateId = templateId || String(ej.template_id || ej.templateId || '').trim();
    publicKey = publicKey || String(ej.public_key || ej.publicKey || '').trim();
  } catch (_) {
    // z. B. 2nd Gen ohne Runtime Config
  }
  return {
    serviceId: serviceId.trim(),
    templateId: templateId.trim(),
    publicKey: publicKey.trim(),
  };
}

/** reCAPTCHA Enterprise: Schwellwert riskAnalysis.score (0.0–1.0). */
const RECAPTCHA_V3_MIN_SCORE = 0.3;

const RECAPTCHA_ENTERPRISE_PROJECT_ID = 'dj-ollerganove';
/** Öffentlicher Site-Key (Enterprise) – muss zu [event.siteKey] im Assessment passen. */
const RECAPTCHA_ENTERPRISE_SITE_KEY =
  '6LdoeDcsAAAAAIORb90GjRovm2tW5qE4v9q5J-u5';
/**
 * Muss mit PWA grecaptcha.enterprise.execute(..., { action: '...' }) übereinstimmen.
 */
const RECAPTCHA_CONTACT_ACTION = 'submit';

/**
 * Muss mit lib/config/app_config.dart [contactAppSecurityKey] / --dart-define übereinstimmen.
 * Überschreiben: Firebase Console → Functions → [Parameter] oder Projekt-.env für Functions.
 * Default identisch zur App, damit Deploy ohne Zusatzkonfiguration funktioniert.
 */
const CONTACT_APP_GUEST_SECURITY_KEY = defineString(
  'CONTACT_APP_GUEST_SECURITY_KEY',
  { default: 'vb-app-guest-2024-secure-key' },
);

function isTrustedAppGuestContactRequest(req, body, guestSecurityKey) {
  if (!body || String(body.source || '').trim() !== 'app_guest') return false;
  const k = String(req.headers['x-app-security-key'] || '').trim();
  return k === guestSecurityKey;
}

/**
 * reCAPTCHA Enterprise: projects.assessments (nicht mehr siteverify).
 * @returns {Promise<{ ok: boolean, data?: object, score?: number, error?: string }>}
 */
async function verifyRecaptchaEnterpriseAssessment(
  token,
  expectedAction,
  apiKey,
  userIp,
) {
  if (!token || typeof token !== 'string' || !apiKey) {
    return { ok: false, error: 'missing_input' };
  }
  const action =
    typeof expectedAction === 'string' && expectedAction.trim()
      ? expectedAction.trim()
      : RECAPTCHA_CONTACT_ACTION;
  const url =
    `https://recaptchaenterprise.googleapis.com/v1/projects/${RECAPTCHA_ENTERPRISE_PROJECT_ID}/assessments?key=` +
    encodeURIComponent(apiKey);
  const event = {
    token: token.trim(),
    siteKey: RECAPTCHA_ENTERPRISE_SITE_KEY,
    expectedAction: action,
  };
  if (userIp && userIp !== 'unknown') {
    event.userIpAddress = userIp;
  }
  try {
    const recaptchaResponse = await axios.post(
      url,
      { event },
      {
        headers: { 'Content-Type': 'application/json' },
        timeout: 15000,
      },
    );
    const data = recaptchaResponse.data;
    const tp = data.tokenProperties || {};
    const ra = data.riskAnalysis || {};
    const score = typeof ra.score === 'number' ? ra.score : null;

    if (tp.valid !== true) {
      return {
        ok: false,
        data,
        error: 'invalid_token',
        invalidReason: tp.invalidReason,
      };
    }
    if (score === null || score < RECAPTCHA_V3_MIN_SCORE) {
      return { ok: false, data, error: 'low_score', score };
    }
    if (tp.action && tp.action !== action) {
      console.warn(
        'reCAPTCHA Enterprise: action mismatch, expected',
        action,
        'got',
        tp.action,
      );
      return { ok: false, data, error: 'action_mismatch' };
    }
    return { ok: true, data, score };
  } catch (e) {
    const detail = e.response?.data
      ? JSON.stringify(e.response.data).slice(0, 500)
      : e.message || 'network';
    console.warn('reCAPTCHA Enterprise assessment error:', detail);
    return { ok: false, error: detail };
  }
}

function getBearerToken(req) {
  const authHeader = (req.headers.authorization || '').trim();
  if (!authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.substring('Bearer '.length).trim();
  return token || null;
}


async function requireAuthenticatedRequest(req, res) {
  const idToken = getBearerToken(req);
  if (!idToken) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    req.auth = decoded;
    return decoded;
  } catch (e) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
}

async function requireMasterAdminFromIdToken(req, res) {
  const idToken = getBearerToken(req);
  if (!idToken) {
    res.status(401).json({ error: 'Authentifizierung erforderlich (Bearer ID Token).' });
    return null;
  }
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
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

async function requireAppCheckRequest(req, res) {
  const appCheckToken = (req.headers['x-firebase-appcheck'] || '').toString().trim();
  if (!appCheckToken) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  try {
    const claims = await admin.appCheck().verifyToken(appCheckToken);
    req.appCheck = claims;
    return claims;
  } catch (e) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
}

function sendInternalError(res, message = 'Ein interner Fehler ist aufgetreten.') {
  res.status(500).json({ error: message });
}

// Stichtag-Logik für usedPartySlots (identisch zu Dart LimitService)
function getAnchorDayFromUserData(data) {
  if (!data) return 1;
  let anchor = null;
  const fp = data.free_period_start;
  if (fp && fp.toDate) {
    anchor = fp.toDate();
  } else if (data.created_at && data.created_at.toDate) {
    anchor = data.created_at.toDate();
  }
  if (!anchor) return 1;
  const day = anchor.getUTCDate();
  if (day < 1) return 1;
  if (day > 31) return 31;
  return day;
}

function stichtagForMonth(year, month, anchorDay) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (anchorDay <= lastDay) {
    return new Date(Date.UTC(year, month - 1, anchorDay));
  }
  if (month === 12) {
    return new Date(Date.UTC(year + 1, 0, 1));
  }
  return new Date(Date.UTC(year, month, 1));
}

function nextStichtag(zielDate, anchorDay) {
  const y = zielDate.getUTCFullYear();
  const m = zielDate.getUTCMonth() + 1;
  let stichtag = stichtagForMonth(y, m, anchorDay);
  if (stichtag > zielDate) return stichtag;
  if (m === 12) {
    return stichtagForMonth(y + 1, 1, anchorDay);
  }
  return stichtagForMonth(y, m + 1, anchorDay);
}

function previousStichtag(date, anchorDay) {
  const y = date.getUTCFullYear();
  const m = date.getUTCMonth() + 1;
  const prevM = m === 1 ? 12 : m - 1;
  const prevY = m === 1 ? y - 1 : y;
  return stichtagForMonth(prevY, prevM, anchorDay);
}

function getAbrechnungsZeitraum(zielDate, anchorDay) {
  const next = nextStichtag(zielDate, anchorDay);
  const periodEnd = new Date(next.getTime() - 1000);
  const periodStart = previousStichtag(next, anchorDay);
  return { start: periodStart, end: periodEnd };
}

async function enforceUserRateLimit(uid, scope, maxRequests, windowSeconds = 60) {
  const nowMs = Date.now();
  const bucket = Math.floor(nowMs / (windowSeconds * 1000));
  const docId = `${scope}_${uid}_${bucket}`;
  const ref = db.collection('last_actions').doc(docId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const currentCount = snap.exists ? Number(snap.data()?.count || 0) : 0;
    if (currentCount >= maxRequests) {
      throw new Error('RATE_LIMIT_EXCEEDED');
    }
    tx.set(ref, {
      uid,
      scope,
      bucket,
      count: currentCount + 1,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: admin.firestore.Timestamp.fromMillis(nowMs + (windowSeconds * 2000)),
    }, { merge: true });
  });
}

async function tryResolveUidFromBearer(req) {
  const idToken = getBearerToken(req);
  if (!idToken) return null;
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    return decoded?.uid || null;
  } catch (e) {
    return null;
  }
}

function resolveRateLimitIdentity(req, uid) {
  if (uid) return `uid:${uid}`;
  const clientIdHeader = (req.headers['x-client-id'] || '').toString().trim();
  if (clientIdHeader) return `cid:${clientIdHeader.slice(0, 80)}`;
  const ip = ((req.headers['x-forwarded-for'] || '').toString().split(',')[0] || req.ip || '').trim();
  const ua = (req.headers['user-agent'] || '').toString().trim();
  const fallback = crypto.createHash('sha256').update(`${ip}|${ua}`).digest('hex').slice(0, 24);
  return `anon:${fallback}`;
}

function computePeriodSlotKey(partyStartDate, anchorDay) {
  const { start } = getAbrechnungsZeitraum(partyStartDate, anchorDay);
  const y = start.getUTCFullYear();
  const m = String(start.getUTCMonth() + 1).padStart(2, '0');
  const d = String(start.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function toBase64Url(inputBufferOrString) {
  const b64 = Buffer.from(inputBufferOrString).toString('base64');
  return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

// Konvertiert ECDSA-Signatur von DER in JOSE (R||S), wie für JWT/ES256 gefordert.
function derToJoseEcdsaSignature(derSignature, size = 32) {
  const der = Buffer.from(derSignature);
  if (der.length < 8 || der[0] !== 0x30) {
    throw new Error('Ungültige DER-Signatur (kein SEQUENCE).');
  }

  let offset = 2;
  if (der[1] & 0x80) {
    const lengthBytes = der[1] & 0x7f;
    offset = 2 + lengthBytes;
  }

  if (der[offset] !== 0x02) {
    throw new Error('Ungültige DER-Signatur (R fehlt).');
  }
  const rLength = der[offset + 1];
  const r = der.slice(offset + 2, offset + 2 + rLength);
  offset = offset + 2 + rLength;

  if (der[offset] !== 0x02) {
    throw new Error('Ungültige DER-Signatur (S fehlt).');
  }
  const sLength = der[offset + 1];
  const s = der.slice(offset + 2, offset + 2 + sLength);

  const rTrimmed = r.length > size ? r.slice(r.length - size) : r;
  const sTrimmed = s.length > size ? s.slice(s.length - size) : s;

  const rPadded = Buffer.concat([Buffer.alloc(size - rTrimmed.length, 0), rTrimmed]);
  const sPadded = Buffer.concat([Buffer.alloc(size - sTrimmed.length, 0), sTrimmed]);

  return Buffer.concat([rPadded, sPadded]);
}

function buildAppleDeveloperToken(privateKey, keyId, teamId, expiresInSeconds = 1800) {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'ES256',
    kid: keyId,
    typ: 'JWT',
  };
  const payload = {
    iss: teamId,
    iat: now,
    exp: now + expiresInSeconds,
  };

  const encodedHeader = toBase64Url(JSON.stringify(header));
  const encodedPayload = toBase64Url(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const signer = crypto.createSign('SHA256');
  signer.update(unsignedToken);
  signer.end();

  const derSignature = signer.sign(privateKey);
  const joseSignature = derToJoseEcdsaSignature(derSignature, 32);
  const encodedSignature = toBase64Url(joseSignature);

  return {
    token: `${unsignedToken}.${encodedSignature}`,
    issuedAt: now,
    expiresAt: now + expiresInSeconds,
  };
}

// Hilfsfunktion: Extrahiert Browser-Sprache aus Request
// Die PWA sendet navigator.language im Request-Body
function getBrowserLanguage(req) {
  try {
    // Browser-Sprache kommt aus dem Request-Body (von PWA gesendet)
    const browserLanguage = req.body?.browser_language || req.body?.app_language || null;
    
    if (browserLanguage && typeof browserLanguage === 'string') {
      // Extrahiere nur den Sprachcode (z.B. 'de' aus 'de-DE')
      const langCode = browserLanguage.split('-')[0].toLowerCase();
      return langCode;
    }
    
    return 'unknown';
  } catch (error) {
    console.error('⚠️ Fehler beim Extrahieren der Browser-Sprache:', error);
    return 'unknown';
  }
}

/** Fallback wie AppConfig.adminEmail — Empfänger für Kontext ohne Party/DJ. */
const ADMIN_CONTACT_FALLBACK_EMAIL = 'info@vibesbox.app';

/**
 * Löst Party → DJ-Kontakt-E-Mail serverseitig (Admin SDK). Kein Client-Lesezugriff auf users nötig.
 * @returns {Promise<{ toEmail: string, partyId: string|null, partyCode: string|null, partyName: string|null, djUserId: string|null }>}
 */
async function resolveContactRecipientDetails({ partyId, partyCode }) {
  const pid = partyId && typeof partyId === 'string' ? partyId.trim() : '';
  const pcode = partyCode && typeof partyCode === 'string' ? partyCode.trim() : '';

  let partySnap = null;
  let resolvedPartyId = null;

  if (pid && pid !== 'manual') {
    const s = await db.collection('parties').doc(pid).get();
    if (s.exists) {
      partySnap = s;
      resolvedPartyId = s.id;
    }
  }
  if (!partySnap && pcode && pcode !== 'manual') {
    const q = await db.collection('parties').where('party_code', '==', pcode).limit(1).get();
    if (!q.empty) {
      partySnap = q.docs[0];
      resolvedPartyId = partySnap.id;
    }
  }

  if (!partySnap || !partySnap.exists) {
    return {
      toEmail: ADMIN_CONTACT_FALLBACK_EMAIL,
      partyId: resolvedPartyId,
      partyCode: pcode || null,
      partyName: null,
      djUserId: null,
    };
  }

  const d = partySnap.data() || {};
  const partyName = d.party_name || d.name || null;
  const partyCodeOut = d.party_code || pcode || null;
  const djUserId = d.dj_code || d.created_by || null;

  if (!djUserId || djUserId === 'manual') {
    return {
      toEmail: ADMIN_CONTACT_FALLBACK_EMAIL,
      partyId: resolvedPartyId,
      partyCode: partyCodeOut,
      partyName,
      djUserId: djUserId || null,
    };
  }

  const djIdStr = String(djUserId);
  const userSnap = await db.collection('users').doc(djIdStr).get();
  if (!userSnap.exists) {
    return {
      toEmail: ADMIN_CONTACT_FALLBACK_EMAIL,
      partyId: resolvedPartyId,
      partyCode: partyCodeOut,
      partyName,
      djUserId: djIdStr,
    };
  }

  const u = userSnap.data() || {};
  let toEmail = ADMIN_CONTACT_FALLBACK_EMAIL;
  if (u.useAlternativeEmail === true && u.alternativeEmail && String(u.alternativeEmail).trim()) {
    toEmail = String(u.alternativeEmail).trim();
  } else if (u.email && String(u.email).trim()) {
    toEmail = String(u.email).trim();
  } else if (u.userEmail && String(u.userEmail).trim()) {
    toEmail = String(u.userEmail).trim();
  }

  return {
    toEmail,
    partyId: resolvedPartyId,
    partyCode: partyCodeOut,
    partyName,
    djUserId: djIdStr,
  };
}

const MANUAL_PARTY_ID = 'manual';

// Shazam Proxy: Reiner Apple-Pass-Through mit Secret-Token.
exports.shazamProxy = onRequest({ memory: '256MB', secrets: [APPLE_DEVELOPER_TOKEN], enforceAppCheck: false }, async (req, res) => {
  cors(req, res, async () => {
    console.log('Anfrage erhalten. Header vorhanden:', !!req.headers.authorization);

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST' && req.method !== 'GET') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    try {
      const auth = await requireAuthenticatedRequest(req, res);
      console.log('Auth-Check erfolgreich:', !!req.auth);
      if (!auth || !req.auth) {
        console.error('KEINE AUTH: User ist nicht eingeloggt');
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }

      try {
        await enforceUserRateLimit(req.auth.uid, 'shazamProxy', 45, 60);
      } catch (limitErr) {
        if (limitErr && limitErr.message === 'RATE_LIMIT_EXCEEDED') {
          res.status(429).json({ error: 'Zu viele Musikerkennungs-Anfragen. Bitte kurz warten.' });
          return;
        }
        throw limitErr;
      }

      const payload = req.method === 'GET' ? req.query : (req.body || {});
      const signature = payload?.signature;

      if (typeof signature !== 'string' || signature.length === 0) {
        res.status(400).json({ error: 'Ungültige Anfrage' });
        return;
      }

      const developerToken = (process.env.APPLE_DEVELOPER_TOKEN || '').trim();
      if (!developerToken) {
        console.error('❌ shazamProxy: APPLE_DEVELOPER_TOKEN fehlt oder ist leer.');
        res.status(500).json({ error: 'Interner Serverfehler' });
        return;
      }

      // Token-Diagnose: Prefix + Länge (niemals den ganzen Token loggen)
      const tokenParts = developerToken.split('.');
      let tokenInfo = { length: developerToken.length, parts: tokenParts.length };
      if (tokenParts.length === 3) {
        try {
          const payload64 = tokenParts[1].replace(/-/g, '+').replace(/_/g, '/');
          const pad = payload64.length % 4 === 0 ? '' : '='.repeat(4 - (payload64.length % 4));
          const decoded = JSON.parse(Buffer.from(payload64 + pad, 'base64').toString('utf8'));
          tokenInfo.iss = decoded.iss;
          tokenInfo.sub = decoded.sub;
          tokenInfo.iat = decoded.iat;
          tokenInfo.exp = decoded.exp;
          tokenInfo.kid = tokenParts[0] ? JSON.parse(Buffer.from(tokenParts[0].replace(/-/g, '+').replace(/_/g, '/') + '==', 'base64').toString('utf8')).kid : null;
          tokenInfo.expired = decoded.exp ? decoded.exp < Math.floor(Date.now() / 1000) : 'unknown';
        } catch (_) { /* ignore decode errors */ }
      }
      console.log('🔑 Token-Diagnose:', tokenInfo);
      console.log('📦 Request:', { signatureLength: signature.length, method: req.method });

      const signatureBuffer = Buffer.from(signature, 'base64');
      console.log('📦 Signature decoded:', { base64Len: signature.length, rawBytes: signatureBuffer.length });

      const appleResponse = await axios.post(
        'https://amp-api.music.apple.com/v1/identify',
        signatureBuffer,
        {
          headers: {
            Authorization: `Bearer ${developerToken}`,
            'Content-Type': 'application/octet-stream',
          },
          timeout: 30000,
          maxBodyLength: 10 * 1024 * 1024,
          maxContentLength: 10 * 1024 * 1024,
          validateStatus: () => true,
        },
      );

      const appleData = appleResponse?.data ?? {};
      const appleStatus = Number(appleResponse?.status ?? 500);

      if (appleStatus >= 400) {
        console.error('Apple API Fehler (Status ' + appleStatus + '):', JSON.stringify(appleData));
        console.error('Apple Response Headers:', JSON.stringify(appleResponse?.headers || {}));
      }

      res.status(appleStatus).json(appleData);
    } catch (err) {
      console.error('❌ shazamProxy Fehler:', err);
      res.status(500).json({ error: 'Interner Serverfehler' });
    }
  });
});

// Liefert nur öffentliche DJ-Profilfelder (Whitelist), niemals vollständiges users-Dokument.
exports.getPublicDjProfile = onRequest({ memory: '128MB' }, async (req, res) => {
  cors(req, res, async () => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'GET' && req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    try {
      const rawUid = req.method === 'GET' ? req.query?.uid : req.body?.uid;
      const uid = typeof rawUid === 'string' ? rawUid.trim() : '';

      // Defensive Validation gegen Path-Manipulation.
      if (!uid || !/^[A-Za-z0-9_-]{6,128}$/.test(uid)) {
        res.status(400).json({ error: 'Ungültige uid' });
        return;
      }

      const userSnap = await db.collection('users').doc(uid).get();
      if (!userSnap.exists) {
        res.status(404).json({ error: 'Profil nicht gefunden' });
        return;
      }

      const userData = userSnap.data() || {};
      const displayName =
        (typeof userData.displayName === 'string' && userData.displayName.trim() !== '' ? userData.displayName.trim() : null)
        || (typeof userData.display_name === 'string' && userData.display_name.trim() !== '' ? userData.display_name.trim() : null)
        || (typeof userData.name === 'string' && userData.name.trim() !== '' ? userData.name.trim() : null);

      const planType = (typeof userData.planType === 'string' && userData.planType.trim() !== '')
        ? userData.planType.trim().toLowerCase()
        : 'free';

      const profilePic =
        (typeof userData.profilePic === 'string' && userData.profilePic.trim() !== '' ? userData.profilePic.trim() : null)
        || (typeof userData.profile_pic === 'string' && userData.profile_pic.trim() !== '' ? userData.profile_pic.trim() : null)
        || (typeof userData.photoURL === 'string' && userData.photoURL.trim() !== '' ? userData.photoURL.trim() : null)
        || (typeof userData.avatarUrl === 'string' && userData.avatarUrl.trim() !== '' ? userData.avatarUrl.trim() : null);

      res.status(200).json({
        uid,
        displayName: displayName || null,
        planType,
        profilePic: profilePic || null,
      });
    } catch (error) {
      console.error('❌ getPublicDjProfile Fehler:', error);
      res.status(500).json({ error: 'Interner Serverfehler' });
    }
  });
});

/**
 * Einmal-/Wartungs-Backfill: `parties.dj_plan_type` aus `users/{djUid}.planType` (Fallback `free`).
 * Nur **Master-Admin** (Bearer ID Token). Optional `?dryRun=true` nur Zählen, kein Write.
 * Aufruf: GET/POST `.../backfillPartyDjPlanType?dryRun=true` mit `Authorization: Bearer <idToken>`.
 */
exports.backfillPartyDjPlanType = onRequest(
  {
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 540,
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (!(await requireMasterAdminFromIdToken(req, res))) return;

    const dryRun =
      String(req.query?.dryRun || req.body?.dryRun || '')
        .toLowerCase() === 'true';

    let lastDoc = null;
    let totalScanned = 0;
    let totalWouldUpdate = 0;
    let totalAlreadyOk = 0;
    let totalNoDjUid = 0;

    try {
      while (true) {
        let q = db
          .collection('parties')
          .orderBy(admin.firestore.FieldPath.documentId())
          .limit(200);
        if (lastDoc) {
          q = q.startAfter(lastDoc);
        }
        const snap = await q.get();
        if (snap.empty) break;

        lastDoc = snap.docs[snap.docs.length - 1];
        const batch = db.batch();
        let batchWrites = 0;

        for (const doc of snap.docs) {
          totalScanned += 1;
          const d = doc.data() || {};
          const rawDj =
            d.dj_code != null && String(d.dj_code).trim() !== ''
              ? String(d.dj_code).trim()
              : d.created_by != null && String(d.created_by).trim() !== ''
                ? String(d.created_by).trim()
                : '';
          if (!rawDj || rawDj === 'manual') {
            totalNoDjUid += 1;
            continue;
          }

          const userSnap = await db.collection('users').doc(rawDj).get();
          let planType = 'free';
          if (userSnap.exists) {
            const pt = userSnap.data()?.planType;
            planType =
              typeof pt === 'string' && pt.trim()
                ? pt.trim().toLowerCase()
                : 'free';
          }

          const cur = d.dj_plan_type;
          const curNorm =
            typeof cur === 'string' ? cur.trim().toLowerCase() : '';
          if (curNorm === planType) {
            totalAlreadyOk += 1;
            continue;
          }

          totalWouldUpdate += 1;
          if (!dryRun) {
            batch.update(doc.ref, { dj_plan_type: planType });
            batchWrites += 1;
          }
        }

        if (!dryRun && batchWrites > 0) {
          await batch.commit();
        }
      }

      res.status(200).json({
        ok: true,
        dryRun,
        totalScanned,
        totalWouldUpdate,
        totalAlreadyOk,
        totalNoDjUid,
        message: dryRun
          ? 'Dry-Run: keine Schreibvorgänge.'
          : 'Backfill abgeschlossen.',
      });
    } catch (e) {
      console.error('backfillPartyDjPlanType:', e);
      res.status(500).json({
        ok: false,
        error: e.message || 'internal',
      });
    }
  },
);

// Setzt alle offenen Wünsche (pending) einer beendeten Party auf "not_played"
// Wird aufgerufen, wenn die Statistik für eine beendete Party angezeigt wird
exports.closePendingWishesForEndedParty = functions.https.onRequest(async (req, res) => {
  const now = admin.firestore.Timestamp.now();
  let updated = 0;

  try {
    if (!(await requireMasterAdminFromIdToken(req, res))) return;

    // Party-ID aus Query-Parameter oder Body holen
    const partyId = req.query.partyId || req.body.partyId;

    if (!partyId) {
      res.status(400).json({ error: 'partyId ist erforderlich' });
      return;
    }

    // Manuelle Wunschbox nicht anfassen
    if (partyId === MANUAL_PARTY_ID) {
      res.json({ message: 'Manuelle Wunschbox wird nicht verarbeitet', updated: 0 });
      return;
    }

    // Prüfe ob Party existiert und beendet ist
    const partyDoc = await db.collection('parties').doc(partyId).get();
    
    if (!partyDoc.exists) {
      res.status(404).json({ error: 'Party nicht gefunden' });
      return;
    }

    const partyData = partyDoc.data();
    const endDate = partyData?.end_date;

    if (!endDate || endDate.toMillis() >= now.toMillis()) {
      // Party ist noch nicht beendet
      res.json({ message: 'Party ist noch nicht beendet', updated: 0 });
      return;
    }

    // Finde pending-Wünsche für diese Party
    const wishesSnap = await db
      .collection('wishes')
      .where('status', '==', 'pending')
      .where('party_id', '==', partyId)
      .get();

    if (wishesSnap.empty) {
      res.json({ message: 'Keine pending-Wünsche gefunden', updated: 0 });
      return;
    }

    console.log(`Party ${partyId} -> offene Wünsche: ${wishesSnap.size}`);

    // Batch-Update für alle pending-Wünsche
    const BATCH_LIMIT = 450; // etwas Puffer unter 500
    let batch = db.batch();
    let ops = 0;

    for (const wishDoc of wishesSnap.docs) {
      batch.update(wishDoc.ref, {
        status: 'not_played',
        status_changed_at: now,
        status_reason: 'party_ended',
      });
      ops++;
      updated++;

      // Batch commit, wenn Limit erreicht
      if (ops >= BATCH_LIMIT) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    if (ops > 0) {
      await batch.commit();
    }

    console.log(`Fertig. Aktualisierte Wünsche: ${updated} (Status -> not_played)`);
    res.json({ message: 'Wünsche aktualisiert', updated: updated });
  } catch (err) {
    console.error('Fehler beim Aktualisieren der Wünsche:', err);
    sendInternalError(res);
  }
});

// --- Spotify-Suche: keine Hörspiele/Podcasts (Firestore admin_config/spotify_settings + 24h-RAM-Cache) ---
const SPOTIFY_DEFAULT_BLACKLIST_LOWER = [
  'hörspiel',
  'hörbuch',
  'podcast',
  'tkkg',
  'audiobook',
  'die drei ???',
  'bibi blocksberg',
  'storytelling',
];
const SPOTIFY_SETTINGS_TTL_MS = 24 * 60 * 60 * 1000;
const SPOTIFY_DEFAULT_MAX_MS = 15 * 60 * 1000;

/** @type {{ loadedAt: number, maxMs: number, blacklistLower: string[] }} */
let spotifyFilterRam = {
  loadedAt: 0,
  maxMs: SPOTIFY_DEFAULT_MAX_MS,
  blacklistLower: [...SPOTIFY_DEFAULT_BLACKLIST_LOWER],
};

async function loadSpotifyFilterSettings() {
  const now = Date.now();
  if (
    spotifyFilterRam.loadedAt > 0 &&
    now - spotifyFilterRam.loadedAt < SPOTIFY_SETTINGS_TTL_MS
  ) {
    return spotifyFilterRam;
  }
  const fallback = {
    loadedAt: now,
    maxMs: SPOTIFY_DEFAULT_MAX_MS,
    blacklistLower: [...SPOTIFY_DEFAULT_BLACKLIST_LOWER],
  };
  try {
    const snap = await db.collection('admin_config').doc('spotify_settings').get();
    if (!snap.exists) {
      spotifyFilterRam = fallback;
      return spotifyFilterRam;
    }
    const d = snap.data() || {};
    const raw = d.search_blacklist;
    let blacklistLower = fallback.blacklistLower;
    if (Array.isArray(raw)) {
      blacklistLower = raw
        .map((x) => (x == null ? '' : String(x).toLowerCase().trim()))
        .filter((s) => s.length > 0);
    }
    const maxRaw = d.max_song_duration_ms;
    let maxMs = fallback.maxMs;
    if (typeof maxRaw === 'number' && maxRaw >= 60000 && maxRaw <= 3600000) {
      maxMs = maxRaw;
    }
    spotifyFilterRam = { loadedAt: now, maxMs, blacklistLower };
    return spotifyFilterRam;
  } catch (e) {
    console.error('loadSpotifyFilterSettings:', e);
    spotifyFilterRam = fallback;
    return spotifyFilterRam;
  }
}

const SPOTIFY_BAD_GENRE_SUBSTRINGS = [
  "children's story",
  'childrens story',
  'audiobook',
  'storytelling',
];

function _spotifyHaystackHasNonMusicKeywords(haystackLower, blacklistLower) {
  for (let i = 0; i < blacklistLower.length; i++) {
    if (haystackLower.includes(blacklistLower[i])) return true;
  }
  if (/\bfolge\b/i.test(haystackLower)) return true;
  return false;
}

function _spotifyGenresIndicateNonMusic(genresLower) {
  for (let i = 0; i < genresLower.length; i++) {
    const g = genresLower[i];
    for (let j = 0; j < SPOTIFY_BAD_GENRE_SUBSTRINGS.length; j++) {
      if (g.includes(SPOTIFY_BAD_GENRE_SUBSTRINGS[j])) return true;
    }
  }
  return false;
}

function isNonMusicSpotifyTrack(track, filterSettings) {
  if (!track) return true;
  const maxMs = filterSettings.maxMs;
  if (typeof track.duration_ms === 'number' && track.duration_ms > maxMs) {
    return true;
  }
  const title = (track.name || '').toLowerCase();
  const albumName =
    track.album && track.album.name ? String(track.album.name).toLowerCase() : '';
  let artistsStr = '';
  if (track.artists && Array.isArray(track.artists)) {
    artistsStr = track.artists
      .map((a) => (a && a.name ? String(a.name).toLowerCase() : ''))
      .join(' ');
  }
  const haystack = `${title} ${albumName} ${artistsStr}`;
  if (_spotifyHaystackHasNonMusicKeywords(haystack, filterSettings.blacklistLower)) return true;

  const genresLower = [];
  if (track.album && Array.isArray(track.album.genres)) {
    track.album.genres.forEach((g) => {
      if (g) genresLower.push(String(g).toLowerCase());
    });
  }
  if (track.artists && Array.isArray(track.artists)) {
    track.artists.forEach((a) => {
      if (a && Array.isArray(a.genres)) {
        a.genres.forEach((g) => {
          if (g) genresLower.push(String(g).toLowerCase());
        });
      }
    });
  }
  if (genresLower.length > 0 && _spotifyGenresIndicateNonMusic(genresLower)) return true;
  return false;
}

function isNonMusicSpotifyArtist(artist, filterSettings) {
  if (!artist || !artist.name) return true;
  return _spotifyHaystackHasNonMusicKeywords(
    String(artist.name).toLowerCase(),
    filterSettings.blacklistLower,
  );
}

// Sucht Tracks oder Artists über die Spotify API
// Query-Parameter: q (Suchbegriff oder erweiterte Syntax: artist:"Name" track:"Titel"), type (artist | track)
// Rückgabe: { resultType: 'artist'|'track', artists?: [...], tracks?: [...] }
// MEMORY: 256MB reicht aus (geoip-lite entfernt, aber volle Musik-Details zurück)
exports.searchSpotifyTracks = onRequest({
  memory: '256MB',
  secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET],
  enforceAppCheck: false,
}, async (req, res) => {
  // CORS-Header IMMER setzen (auch bei Fehlern)
  const setCorsHeaders = () => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, X-Firebase-AppCheck, X-Client-Id, x-client-id'
    );
  };
  
  // WICHTIG: CORS-Header IMMER setzen, auch bei Fehlern
  setCorsHeaders();

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // ABSOLUTER TRY-CATCH um die gesamte Funktion
  try {
    const uid = await tryResolveUidFromBearer(req);
    const identity = resolveRateLimitIdentity(req, uid);

    try {
      await enforceUserRateLimit(identity, 'searchSpotifyTracks', 60, 60);
    } catch (limitError) {
      if (limitError && limitError.message === 'RATE_LIMIT_EXCEEDED') {
        setCorsHeaders();
        res.status(429).json({ error: 'Zu viele Suchanfragen. Bitte kurz warten.' });
        return;
      }
      throw limitError;
    }

    const query = req.query.q || req.body.q;
    let searchType = (req.query.type || req.body.type || 'track').toString().toLowerCase().trim();
    // Nur artist oder track — Spotify /v1/search: niemals show, episode o. Ä.
    if (searchType !== 'artist' && searchType !== 'track') {
      searchType = 'track';
    }

    if (!query || query.trim().length < 2) {
      setCorsHeaders();
      res.status(400).json({ error: 'Mindestens 2 Zeichen erforderlich.' });
      return;
    }

    const spotifyFilterSettings = await loadSpotifyFilterSettings();

    console.log('🔍 Spotify-Suche gestartet:', { query, searchType, uid: uid || 'anonymous' });

    // Spotify API Credentials aus Secret Manager (2nd Gen)
    // .trim() verhindert 400 bei versehentlichen Leerzeichen/Zeilenumbrüchen im Secret
    const clientId = (SPOTIFY_CLIENT_ID.value() || '').trim();
    const clientSecret = (SPOTIFY_CLIENT_SECRET.value() || '').trim();

    if (!clientId || !clientSecret) {
      console.error('❌ Spotify Credentials fehlen');
      setCorsHeaders();
      res.status(500).json({ error: 'Spotify API Credentials nicht konfiguriert' });
      return;
    }

    // Spotify Access Token holen – Endpunkt und Format laut Spotify Docs
    let accessToken;
    try {
      console.log('🔑 Starte Token-Holung...');
      const tokenResponse = await axios.post(
        'https://accounts.spotify.com/api/token',
        'grant_type=client_credentials',
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Basic ' + Buffer.from(clientId + ':' + clientSecret).toString('base64')
          },
          timeout: 10000 // 10 Sekunden Timeout
        }
      );
      
      if (!tokenResponse || !tokenResponse.data) {
        throw new Error('Ungültige Token-Response von Spotify');
      }
      
      accessToken = tokenResponse.data.access_token;
      
      if (!accessToken || typeof accessToken !== 'string' || accessToken.trim() === '') {
        throw new Error('Kein Access Token in Response erhalten');
      }
      
      console.log('✅ Access Token erhalten (Länge:', accessToken.length, ')');
    } catch (tokenError) {
      console.error('❌ FEHLER beim Holen des Access Tokens:');
      console.error('   Error Message:', tokenError.message);
      console.error('   Error Stack:', tokenError.stack);
      if (tokenError.response) {
        console.error('   Response Status:', tokenError.response.status);
        console.error('   Response Data:', JSON.stringify(tokenError.response.data, null, 2));
      }
      setCorsHeaders();
      res.status(500).json({ error: 'Ein interner Fehler ist aufgetreten.' });
      return;
    }

    // Spotify API Search: genau ein type (track | artist), keine Multi-Type-Listen
    const searchUrl = `https://api.spotify.com/v1/search?q=${encodeURIComponent(query)}&type=${searchType}&limit=20`;
    let searchResponse;
    try {
      searchResponse = await axios.get(searchUrl, {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });
      console.log('✅ Spotify API Response erhalten');
    } catch (searchError) {
      console.error('❌ Fehler bei Spotify API Search:', searchError);
      if (searchError.response) {
        console.error('   Status:', searchError.response.status);
        console.error('   Data:', searchError.response.data);
      }
      setCorsHeaders();
      res.status(500).json({ error: 'Ein interner Fehler ist aufgetreten.' });
      return;
    }

    // Response-Struktur prüfen
    if (!searchResponse || !searchResponse.data) {
      console.warn('⚠️ Keine Response-Daten von Spotify');
      setCorsHeaders();
      res.json({ resultType: searchType, [searchType === 'artist' ? 'artists' : 'tracks']: [] });
      return;
    }

    // ========== type === 'artist' ==========
    if (searchType === 'artist') {
      const artists = [];
      const rawItems = searchResponse.data.artists?.items;

      if (!rawItems || !Array.isArray(rawItems)) {
        console.warn('⚠️ Keine artists in Response:', Object.keys(searchResponse.data));
        setCorsHeaders();
        res.json({ resultType: 'artist', artists: [] });
        return;
      }

      console.log(`📊 Verarbeite ${rawItems.length} Artists von Spotify`);

      for (let i = 0; i < rawItems.length; i++) {
        const artist = rawItems[i];
        try {
          if (!artist || !artist.id || !artist.name) continue;
          if (isNonMusicSpotifyArtist(artist, spotifyFilterSettings)) continue;

          const formattedArtist = {
            id: String(artist.id),
            name: String(artist.name).trim(),
            images: Array.isArray(artist.images) ? artist.images : []
          };
          artists.push(formattedArtist);
        } catch (err) {
          console.warn(`⚠️ Artist ${i} übersprungen:`, err.message);
        }
      }

      console.log(`✅ ${artists.length} Artists erfolgreich formatiert`);
      setCorsHeaders();
      res.json({ resultType: 'artist', artists });
      return;
    }

    // ========== type === 'track' ==========
    // Erweiterte Suchsyntax (z.B. artist:"Name" track:"Titel") wird im q-Parameter durchgereicht
    const tracks = [];
    const trackItems = searchResponse.data.tracks?.items;

    if (!trackItems || !Array.isArray(trackItems)) {
      console.warn('⚠️ Keine tracks in Response:', Object.keys(searchResponse.data));
      setCorsHeaders();
      res.json({ resultType: 'track', tracks: [] });
      return;
    }

    console.log(`📊 Verarbeite ${trackItems.length} Tracks von Spotify`);

    for (let i = 0; i < trackItems.length; i++) {
      const track = trackItems[i];

      try {
        if (!track) {
          console.warn(`⚠️ Track ${i} ist null oder undefined`);
          continue;
        }

        if (!track.artists || !Array.isArray(track.artists) || track.artists.length === 0) {
          console.warn(`⚠️ Track ${i} (${track.id || 'unbekannt'}) hat keine gültigen artists`);
          continue;
        }

        if (isNonMusicSpotifyTrack(track, spotifyFilterSettings)) {
          continue;
        }

        const artistNames = track.artists
          .filter(a => a != null && typeof a === 'object' && a.name != null)
          .map(a => String(a.name).trim())
          .filter(name => name.length > 0);

        if (artistNames.length === 0) continue;

        const artists = artistNames.join(', ');

        let artistIds = [];
        try {
          if (track.artists && Array.isArray(track.artists)) {
            artistIds = track.artists
              .filter(a => a != null && typeof a === 'object' && a.id != null && typeof a.id === 'string')
              .map(a => String(a.id).trim())
              .filter(id => id.length > 0);
          }
        } catch (artistIdError) {
          console.warn(`⚠️ Artist-ID-Extraktion fehlgeschlagen für Track ${i}`);
        }

        const genresOut = [];
        if (track.album && Array.isArray(track.album.genres)) {
          track.album.genres.forEach((g) => {
            if (g) genresOut.push(String(g));
          });
        }
        if (track.artists && Array.isArray(track.artists)) {
          track.artists.forEach((a) => {
            if (a && Array.isArray(a.genres)) {
              a.genres.forEach((g) => {
                if (g) genresOut.push(String(g));
              });
            }
          });
        }

        const albumName =
          track.album && track.album.name ? String(track.album.name) : '';

        const formattedTrack = {
          id: track.id ? String(track.id) : null,
          name: track.name ? String(track.name) : '',
          artists,
          artist_ids: artistIds,
          album: albumName,
          duration_ms: (typeof track.duration_ms === 'number') ? track.duration_ms : null,
          genres: genresOut,
        };
        tracks.push(formattedTrack);
      } catch (trackError) {
        console.warn(`⚠️ Fehler beim Verarbeiten von Track ${i}:`, trackError.message);
      }
    }

    console.log(`✅ ${tracks.length} Tracks erfolgreich formatiert`);
    setCorsHeaders();
    res.json({ resultType: 'track', tracks });
    
  } catch (err) {
    // ABSOLUTER FEHLER-HANDLER - Logge ALLES
    console.error('❌❌❌ KRITISCHER FEHLER bei Spotify-Suche ❌❌❌');
    console.error('   Error Message:', err.message);
    console.error('   Error Name:', err.name);
    console.error('   Error Stack:', err.stack);
    if (err.response) {
      console.error('   Response Status:', err.response.status);
      console.error('   Response Headers:', JSON.stringify(err.response.headers, null, 2));
      console.error('   Response Data:', JSON.stringify(err.response.data, null, 2));
    }
    if (err.request) {
      console.error('   Request Config:', JSON.stringify(err.config, null, 2));
    }
    
    // WICHTIG: CORS-Header IMMER setzen, auch im Fehlerfall
    setCorsHeaders();
    
    // Sende IMMER eine gültige JSON-Response
    try {
      res.status(500).json({ error: 'Ein interner Fehler ist aufgetreten.' });
    } catch (responseError) {
      // Falls auch das Senden der Response fehlschlägt, logge es
      console.error('❌ FEHLER beim Senden der Error-Response:', responseError);
      // Versuche es nochmal mit send() statt json()
      try {
        res.status(500).send(JSON.stringify({
          error: 'Ein interner Fehler ist aufgetreten.'
        }));
      } catch (finalError) {
        console.error('❌ ABSOLUTER FEHLER: Response konnte überhaupt nicht gesendet werden:', finalError);
      }
    }
  }
});

// Speichert Musikdaten in die Musikdatenbank (wunschbox_titel, wunschbox_artist, wunschbox_genres Collections)
// Body: { spotify_id, title, artist, duration_ms, genres[], dj_id, browser_language }
// MEMORY: 256MB reicht jetzt aus (geoip-lite entfernt)
exports.saveToMusicDatabase = onRequest({
  memory: '256MB',
  secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET],
  enforceAppCheck: false,
}, async (req, res) => {
  // CORS-Header setzen
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Firebase-AppCheck, X-Client-Id, x-client-id'
  );

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const uid = await tryResolveUidFromBearer(req);
    const identity = resolveRateLimitIdentity(req, uid);
    try {
      await enforceUserRateLimit(identity, 'saveToMusicDatabase', 60, 60);
    } catch (limitError) {
      if (limitError && limitError.message === 'RATE_LIMIT_EXCEEDED') {
        res.status(429).json({ error: 'Zu viele Anfragen. Bitte kurz warten.' });
        return;
      }
      throw limitError;
    }

    const { spotify_id, title, artist, duration_ms, genres, dj_id, artist_ids } = req.body;

    if (!title || !artist) {
      res.status(400).json({ error: 'title und artist sind erforderlich' });
      return;
    }

    if (!dj_id || dj_id.trim() === '') {
      console.log('⚠️ saveToMusicDatabase: dj_id fehlt, überspringe Statistik-Update');
    }

    // Bestimme Browser-Sprache aus Request
    const browserLanguage = getBrowserLanguage(req);
    console.log('🌐 Browser-Sprache:', browserLanguage);

    // Hole Genres vom Artist, falls nicht vorhanden
    let finalGenres = genres || [];
    console.log('🎵 Genre-Check: genres=', genres, 'artist_ids=', artist_ids, 'spotify_id=', spotify_id);
    
    if ((!finalGenres || finalGenres.length === 0) && artist_ids && Array.isArray(artist_ids) && artist_ids.length > 0 && spotify_id) {
      console.log('🔍 Sammle Genres für Artist:', artist_ids[0]);
      try {
        // Spotify API Credentials aus Secret Manager (2nd Gen), .trim() gegen Leerzeichen/Newlines
        const clientId = (SPOTIFY_CLIENT_ID.value() || '').trim();
        const clientSecret = (SPOTIFY_CLIENT_SECRET.value() || '').trim();
        
        if (!clientId || !clientSecret) {
          console.log('⚠️ Spotify Credentials fehlen, kann Genres nicht holen');
          // Kein Fehler werfen, einfach ohne Genres weitermachen
        } else {
          console.log('🔑 Spotify Credentials vorhanden, hole Access Token...');
          const axios = require('axios');
          
          let accessToken = null;
          try {
            const tokenResponse = await axios.post(
              'https://accounts.spotify.com/api/token',
              'grant_type=client_credentials',
              {
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Authorization': 'Basic ' + Buffer.from(clientId + ':' + clientSecret).toString('base64')
                },
                timeout: 10000
              }
            );
            
            if (!tokenResponse || !tokenResponse.data || !tokenResponse.data.access_token) {
              throw new Error('Kein Access Token in Response erhalten');
            }
            
            accessToken = tokenResponse.data.access_token;
            console.log('✅ Access Token erhalten, hole Artist-Daten für:', artist_ids[0]);
          } catch (tokenError) {
            console.error('❌ Fehler beim Holen des Access Tokens:', tokenError.message);
            if (tokenError.response) {
              console.error('   Token Response Status:', tokenError.response.status);
              console.error('   Token Response Data:', tokenError.response.data);
            }
            // Kein Fehler werfen, einfach ohne Genres weitermachen
            accessToken = null;
          }
          
          if (accessToken) {
            try {
              // Hole Genres vom ersten Artist
              const artistResponse = await axios.get(`https://api.spotify.com/v1/artists/${artist_ids[0]}`, {
                headers: {
                  'Authorization': `Bearer ${accessToken}`
                },
                timeout: 10000 // 10 Sekunden Timeout
              });
              
              console.log('📥 Artist-Response erhalten:', {
                artistId: artist_ids[0],
                hasGenres: !!(artistResponse.data && artistResponse.data.genres),
                genresCount: artistResponse.data?.genres?.length || 0
              });
              
              if (artistResponse.data && artistResponse.data.genres && Array.isArray(artistResponse.data.genres) && artistResponse.data.genres.length > 0) {
                finalGenres = artistResponse.data.genres;
                console.log('✅ Genres vom Artist geholt:', finalGenres.length, 'Genres');
              } else {
                console.log('⚠️ Artist hat keine Genres:', artistResponse.data?.name || 'Unbekannt');
                // Kein Fehler, einfach ohne Genres weitermachen
              }
            } catch (artistError) {
              console.error('❌ Fehler beim Holen der Artist-Daten:', artistError.message);
              if (artistError.response) {
                console.error('   Artist Response Status:', artistError.response.status);
                console.error('   Artist Response Data:', artistError.response.data);
              }
              // Kein Fehler werfen, einfach ohne Genres weitermachen
            }
          }
        }
      } catch (e) {
        console.error('⚠️ Unerwarteter Fehler beim Genre-Holen (nicht kritisch):', e.message);
        console.error('   Error Stack:', e.stack);
        if (e.response) {
          console.error('   Response Status:', e.response.status);
          console.error('   Response Data:', e.response.data);
        }
        // Kein Fehler werfen, einfach ohne Genres weitermachen
      }
    } else {
      if (finalGenres && finalGenres.length > 0) {
        console.log('✅ Genres bereits vorhanden:', finalGenres.length, 'Genres');
      } else {
        console.log('⚠️ Keine Genres vorhanden und keine artist_ids zum Holen');
      }
    }

    console.log('💾 saveToMusicDatabase aufgerufen:', { spotify_id, title, artist, duration_ms, genres: finalGenres, dj_id, browser_language: browserLanguage });

    // Normalisiere Strings (lowercase für bessere Suche)
    const normalizedTitle = title.trim().toLowerCase();
    const normalizedArtist = artist.trim().toLowerCase();

    // 1. Prüfe ob Artist bereits existiert in wunschbox_artist
    const artistQuery = await db.collection('wunschbox_artist')
      .where('name_lower', '==', normalizedArtist)
      .limit(1)
      .get();

    let artistId;
    if (artistQuery.empty) {
      // Erstelle neuen Artist
      const artistRef = await db.collection('wunschbox_artist').add({
        name: artist.trim(),
        name_lower: normalizedArtist,
        created_at: admin.firestore.FieldValue.serverTimestamp()
      });
      artistId = artistRef.id;
      console.log('✅ Neuer Artist gespeichert:', artist.trim(), artistId);
    } else {
      artistId = artistQuery.docs[0].id;
      console.log('✅ Artist existiert bereits:', artist.trim(), artistId);
    }

    // 3. Prüfe Genres durch, speichere fehlende in wunschbox_genres
    const genreIds = [];
    if (finalGenres && Array.isArray(finalGenres) && finalGenres.length > 0) {
      for (const genreName of finalGenres) {
        if (!genreName || genreName.trim() === '') continue;
        
        const normalizedGenre = genreName.trim().toLowerCase();
        const genreQuery = await db.collection('wunschbox_genres')
          .where('name_lower', '==', normalizedGenre)
          .limit(1)
          .get();

        if (genreQuery.empty) {
          // Erstelle neues Genre
          const genreRef = await db.collection('wunschbox_genres').add({
            name: genreName.trim(),
            name_lower: normalizedGenre,
            created_at: admin.firestore.FieldValue.serverTimestamp()
          });
          genreIds.push(genreRef.id);
          console.log('✅ Neues Genre gespeichert:', genreName.trim(), genreRef.id);
        } else {
          genreIds.push(genreQuery.docs[0].id);
          console.log('✅ Genre existiert bereits:', genreName.trim(), genreQuery.docs[0].id);
        }
      }
    }

    // 2. Prüfe ob Titel bereits existiert in wunschbox_titel (Kombination aus name_lower + artist_id)
    const titleQuery = await db.collection('wunschbox_titel')
      .where('name_lower', '==', normalizedTitle)
      .where('artist_id', '==', artistId)
      .limit(1)
      .get();

    let titleId;
    let isNewTitle = false;
    if (titleQuery.empty) {
      // Erstelle neuen Titel
      isNewTitle = true;
      const titleData = {
        name: title.trim(),
        name_lower: normalizedTitle,
        artist_id: artistId,
        genre_ids: genreIds, // Speichere Genre-IDs direkt im Titel
        global_wish_count: 0, // Initialisiere globalen Counter
        created_at: admin.firestore.FieldValue.serverTimestamp()
      };
      
      // Füge Spotify-Daten hinzu, falls vorhanden (duration_ms ist optional)
      if (spotify_id) {
        titleData.spotify_id = spotify_id;
      }
      if (duration_ms != null && duration_ms !== undefined) {
        titleData.duration_ms = duration_ms;
      }
      
      const titleRef = await db.collection('wunschbox_titel').add(titleData);
      titleId = titleRef.id;
      console.log('✅ Neuer Titel gespeichert:', title.trim(), titleId, 'mit Genre-IDs:', genreIds);
    } else {
      titleId = titleQuery.docs[0].id;
      const titleDoc = titleQuery.docs[0];
      const titleData = titleDoc.data();
      const updateData = {};
      
      // Aktualisiere Genre-IDs, falls neue Genres hinzugekommen sind
      const existingGenreIds = titleData.genre_ids || [];
      const mergedGenreIds = [...new Set([...existingGenreIds, ...genreIds])]; // Vereinige Arrays ohne Duplikate
      if (JSON.stringify(mergedGenreIds.sort()) !== JSON.stringify(existingGenreIds.sort())) {
        updateData.genre_ids = mergedGenreIds;
        console.log('✅ Genre-IDs aktualisiert:', existingGenreIds, '->', mergedGenreIds);
      }
      
      // Aktualisiere Titel mit Spotify-Daten, falls vorhanden und noch nicht gesetzt
      if (spotify_id && !titleData.spotify_id) {
        updateData.spotify_id = spotify_id;
      }
      if (duration_ms != null && duration_ms !== undefined && !titleData.duration_ms) {
        updateData.duration_ms = duration_ms;
      }
      
      // Initialisiere global_wish_count falls nicht vorhanden
      if (titleData.global_wish_count === undefined) {
        updateData.global_wish_count = 0;
      }
      
      if (Object.keys(updateData).length > 0) {
        await titleDoc.ref.update(updateData);
        console.log('✅ Titel aktualisiert:', titleId);
      } else {
        console.log('✅ Titel existiert bereits:', title.trim(), titleId);
      }
    }

    // 4. Statistik-Updates (nur wenn dj_id vorhanden)
    if (dj_id && dj_id.trim() !== '') {
      try {
        // Globaler Counter: Erhöhe in wunschbox_artist
        const artistRef = db.collection('wunschbox_artist').doc(artistId);
        const artistDoc = await artistRef.get();
        if (artistDoc.exists) {
          const artistData = artistDoc.data();
          if (artistData && artistData.global_wish_count === undefined) {
            await artistRef.set({ global_wish_count: 0 }, { merge: true });
          }
          await artistRef.update({
            global_wish_count: admin.firestore.FieldValue.increment(1)
          });
        } else {
          await artistRef.set({ global_wish_count: 1 }, { merge: true });
        }
        console.log('✅ Globaler Counter für Artist erhöht:', artistId);

        // Globaler Counter: Erhöhe in wunschbox_titel
        const titleRef = db.collection('wunschbox_titel').doc(titleId);
        await titleRef.update({
          global_wish_count: admin.firestore.FieldValue.increment(1)
        });
        console.log('✅ Globaler Counter für Titel erhöht:', titleId);

        // DJ-spezifischer Counter: stats_per_dj Sub-Collection in wunschbox_artist
        console.log('📊 Starte DJ-spezifisches Statistik-Update für Artist:', artistId, 'DJ:', dj_id);
        try {
          const artistStatsRef = artistRef.collection('stats_per_dj').doc(dj_id);
          const artistStatsDoc = await artistStatsRef.get();
          if (artistStatsDoc.exists) {
            await artistStatsRef.update({
              wish_count: admin.firestore.FieldValue.increment(1)
            });
            console.log('✅ DJ-spezifischer Counter für Artist erhöht (Update):', artistId, 'DJ:', dj_id);
          } else {
            await artistStatsRef.set({
              wish_count: 1,
              updated_at: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log('✅ DJ-spezifischer Counter für Artist erstellt (Neu):', artistId, 'DJ:', dj_id);
          }
        } catch (artistStatsError) {
          console.error('⚠️ Fehler beim DJ-spezifischen Statistik-Update für Artist:', artistStatsError);
          console.error('   Artist ID:', artistId, 'DJ ID:', dj_id);
          throw artistStatsError; // Wirf den Fehler weiter, damit er im äußeren catch gefangen wird
        }

        // DJ-spezifischer Counter: stats_per_dj Sub-Collection in wunschbox_titel
        console.log('📊 Starte DJ-spezifisches Statistik-Update für Titel:', titleId, 'DJ:', dj_id);
        try {
          const titleStatsRef = titleRef.collection('stats_per_dj').doc(dj_id);
          const titleStatsDoc = await titleStatsRef.get();
          if (titleStatsDoc.exists) {
            await titleStatsRef.update({
              wish_count: admin.firestore.FieldValue.increment(1)
            });
            console.log('✅ DJ-spezifischer Counter für Titel erhöht (Update):', titleId, 'DJ:', dj_id);
          } else {
            await titleStatsRef.set({
              wish_count: 1,
              updated_at: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log('✅ DJ-spezifischer Counter für Titel erstellt (Neu):', titleId, 'DJ:', dj_id);
          }
        } catch (titleStatsError) {
          console.error('⚠️ Fehler beim DJ-spezifischen Statistik-Update für Titel:', titleStatsError);
          console.error('   Titel ID:', titleId, 'DJ ID:', dj_id);
          throw titleStatsError; // Wirf den Fehler weiter, damit er im äußeren catch gefangen wird
        }

        // Browser-Sprache-spezifischer Counter: stats_per_language Sub-Collection in wunschbox_artist
        if (browserLanguage && browserLanguage !== 'unknown') {
          console.log('📊 Starte Sprach-spezifisches Statistik-Update für Artist:', artistId, 'Sprache:', browserLanguage);
          try {
            const artistLanguageStatsRef = artistRef.collection('stats_per_language').doc(browserLanguage);
            const artistLanguageStatsDoc = await artistLanguageStatsRef.get();
            if (artistLanguageStatsDoc.exists) {
              await artistLanguageStatsRef.update({
                wish_count: admin.firestore.FieldValue.increment(1)
              });
              console.log('✅ Sprach-spezifischer Counter für Artist erhöht (Update):', artistId, 'Sprache:', browserLanguage);
            } else {
              await artistLanguageStatsRef.set({
                wish_count: 1,
                updated_at: admin.firestore.FieldValue.serverTimestamp()
              });
              console.log('✅ Sprach-spezifischer Counter für Artist erstellt (Neu):', artistId, 'Sprache:', browserLanguage);
            }
          } catch (artistLanguageStatsError) {
            console.error('⚠️ Fehler beim Sprach-spezifischen Statistik-Update für Artist:', artistLanguageStatsError);
            console.error('   Artist ID:', artistId, 'Sprache:', browserLanguage);
            // Sprach-Statistik-Fehler sind nicht kritisch, wir werfen nicht weiter
          }
        }

        // Browser-Sprache-spezifischer Counter: stats_per_language Sub-Collection in wunschbox_titel
        if (browserLanguage && browserLanguage !== 'unknown') {
          console.log('📊 Starte Sprach-spezifisches Statistik-Update für Titel:', titleId, 'Sprache:', browserLanguage);
          try {
            const titleLanguageStatsRef = titleRef.collection('stats_per_language').doc(browserLanguage);
            const titleLanguageStatsDoc = await titleLanguageStatsRef.get();
            if (titleLanguageStatsDoc.exists) {
              await titleLanguageStatsRef.update({
                wish_count: admin.firestore.FieldValue.increment(1)
              });
              console.log('✅ Sprach-spezifischer Counter für Titel erhöht (Update):', titleId, 'Sprache:', browserLanguage);
            } else {
              await titleLanguageStatsRef.set({
                wish_count: 1,
                updated_at: admin.firestore.FieldValue.serverTimestamp()
              });
              console.log('✅ Sprach-spezifischer Counter für Titel erstellt (Neu):', titleId, 'Sprache:', browserLanguage);
            }
          } catch (titleLanguageStatsError) {
            console.error('⚠️ Fehler beim Sprach-spezifischen Statistik-Update für Titel:', titleLanguageStatsError);
            console.error('   Titel ID:', titleId, 'Sprache:', browserLanguage);
            // Sprach-Statistik-Fehler sind nicht kritisch, wir werfen nicht weiter
          }
        }
      } catch (statsError) {
        console.error('❌ KRITISCHER Fehler beim Statistik-Update:', statsError);
        console.error('   Error Message:', statsError.message);
        console.error('   Error Stack:', statsError.stack);
        // Wir werfen den Fehler weiter, damit er im äußeren catch gefangen wird
        throw statsError;
      }
    }

    console.log('✅ saveToMusicDatabase erfolgreich abgeschlossen');
    res.json({
      success: true,
      titleId: titleId,
      artistId: artistId,
      genreIds: genreIds,
      browser_language: browserLanguage // Rückgabe für Speicherung im Wunsch-Dokument
    });
  } catch (err) {
    console.error('❌ Fehler beim Speichern in Musikdatenbank:', err);
    console.error('   Error Message:', err.message);
    console.error('   Error Stack:', err.stack);
    if (err.response) {
      console.error('   Response Status:', err.response.status);
      console.error('   Response Data:', JSON.stringify(err.response.data, null, 2));
    }
    // CORS-Header auch im Fehlerfall setzen
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, X-Firebase-AppCheck, X-Client-Id, x-client-id'
    );
    res.status(500).json({ error: 'Ein interner Fehler ist aufgetreten.' });
  }
});

// Aktualisiert Party-Codes für bestehende Partys
// Kann verwendet werden, um Party-Codes zu migrieren oder zu aktualisieren
exports.updatePartyCodes = functions.https.onRequest(async (req, res) => {
  // CORS-Header setzen
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    if (!(await requireMasterAdminFromIdToken(req, res))) return;

    const { partyId, newPartyCode } = req.body;

    if (!partyId || !newPartyCode) {
      res.status(400).json({ error: 'partyId und newPartyCode sind erforderlich' });
      return;
    }

    // Prüfe ob Party existiert
    const partyRef = db.collection('parties').doc(partyId);
    const partyDoc = await partyRef.get();

    if (!partyDoc.exists) {
      res.status(404).json({ error: 'Party nicht gefunden' });
      return;
    }

    const oldPartyCode = partyDoc.data()?.party_code;

    // Aktualisiere Party-Code in parties Collection
    await partyRef.update({
      party_code: newPartyCode,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });

    // Aktualisiere auch party_status Collection
    const partyStatusQuery = await db.collection('party_status')
      .where('party_id', '==', partyId)
      .get();

    const batch = db.batch();
    partyStatusQuery.docs.forEach(doc => {
      batch.update(doc.ref, {
        party_code: newPartyCode,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    await batch.commit();

    res.json({
      success: true,
      message: 'Party-Code aktualisiert',
      partyId: partyId,
      oldPartyCode: oldPartyCode,
      newPartyCode: newPartyCode
    });
  } catch (err) {
    console.error('Fehler beim Aktualisieren des Party-Codes:', err);
    sendInternalError(res);
  }
});

/** EmailJS: gleiche Label-Sets wie Kontakt-Template (validateRecaptcha) + Auth-spezifische Texte. */
function normalizeEmailJsLocale(locale) {
  if (!locale || typeof locale !== 'string') return 'de';
  const langCode = locale.toLowerCase().split('-')[0];
  const supportedLangs = ['de', 'en', 'fr', 'ru', 'zh', 'es', 'tr', 'pt'];
  return supportedLangs.includes(langCode) ? langCode : 'de';
}

/**
 * Kontakt/Support (validateRecaptcha): Nutzernachricht für EmailJS `message` in doppelte Anführungszeichen setzen
 * (`"…"`), damit das Template mit `{{message}}` klar vom HTML der Registrierungs-Mails unterscheidbar ist.
 * Registrierung/Auth: `message` wird nicht gewrappt — vollständiger HTML-String (Button #FF8C00, schwarzer Text, 8px Radius).
 */
function wrapContactUserMessageForEmailJs(userMessage) {
  const s = userMessage == null ? '' : String(userMessage).trim();
  return '"' + s + '"';
}

function getEmailJsContactTranslations() {
  return {
    de: {
      app_name: 'VibesBox',
      mail_contact_header: 'Neue Kontaktanfrage',
      mail_contact_subject_line: 'Kontaktanfrage über VibesBox',
      mail_contact_intro_text: 'Du hast eine neue Kontaktanfrage über VibesBox erhalten:',
      label_message: 'Nachricht',
      label_sender: 'Absender',
      label_phone: 'Telefon',
      label_role: 'Rolle',
      label_party: 'Party',
      label_date: 'Datum',
      label_reply_button: 'Antworten',
      mail_footer_automated: 'Diese E-Mail wurde automatisch über <a href="https://vibesbox.app"><b>VibesBox.App</b></a> generiert.',
      no_email_provided: 'Keine E-Mail angegeben',
      guest: 'Gast',
      auth_mail_header: 'VibesBox – Konto',
      auth_mail_intro: 'Du hast eine Aktion für dein VibesBox-Konto angefordert:',
      auth_role: 'Konto',
      registration_header: 'Deine Registrierung bei VibesBox',
      role_guest_access: 'Gastzugang',
      registration_role_dj: 'DJ-Zugang',
      auth_email_datetime_suffix: ' Uhr',
    },
    en: {
      app_name: 'VibesBox',
      mail_contact_header: 'New Contact Request',
      mail_contact_subject_line: 'Contact Request via VibesBox',
      mail_contact_intro_text: 'You have received a new contact request via VibesBox:',
      label_message: 'Message',
      label_sender: 'Sender',
      label_phone: 'Phone',
      label_role: 'Role',
      label_party: 'Party',
      label_date: 'Date',
      label_reply_button: 'Reply',
      mail_footer_automated: 'This email was automatically generated via <a href="https://vibesbox.app"><b>VibesBox.App</b></a>.',
      no_email_provided: 'No email provided',
      guest: 'Guest',
      auth_mail_header: 'VibesBox – Account',
      auth_mail_intro: 'You requested an action for your VibesBox account:',
      auth_role: 'Account',
      registration_header: 'Your registration at VibesBox',
      role_guest_access: 'Guest access',
      registration_role_dj: 'DJ access',
      auth_email_datetime_suffix: '',
    },
    fr: {
      app_name: 'VibesBox',
      mail_contact_header: 'Nouvelle demande de contact',
      mail_contact_subject_line: 'Demande de contact via VibesBox',
      mail_contact_intro_text: 'Vous avez reçu une nouvelle demande de contact via VibesBox:',
      label_message: 'Message',
      label_sender: 'Expéditeur',
      label_phone: 'Téléphone',
      label_role: 'Rôle',
      label_party: 'Fête',
      label_date: 'Date',
      label_reply_button: 'Répondre',
      mail_footer_automated: 'Cet e-mail a été généré automatiquement via <a href="https://vibesbox.app"><b>VibesBox.App</b></a>.',
      no_email_provided: 'Aucun e-mail fourni',
      guest: 'Invité',
      auth_mail_header: 'VibesBox – Compte',
      auth_mail_intro: 'Vous avez demandé une action pour votre compte VibesBox :',
      auth_role: 'Compte',
      registration_header: 'Votre inscription sur VibesBox',
      role_guest_access: 'Accès invité',
      registration_role_dj: 'Accès DJ',
      auth_email_datetime_suffix: '',
    },
    ru: {
      app_name: 'VibesBox',
      mail_contact_header: 'Новый запрос на связь',
      mail_contact_subject_line: 'Запрос на связь через VibesBox',
      mail_contact_intro_text: 'Вы получили новый запрос на связь через VibesBox:',
      label_message: 'Сообщение',
      label_sender: 'Отправитель',
      label_phone: 'Телефон',
      label_role: 'Роль',
      label_party: 'Вечеринка',
      label_date: 'Дата',
      label_reply_button: 'Ответить',
      mail_footer_automated: 'Это письмо было автоматически создано через <a href="https://vibesbox.app"><b>VibesBox.App</b></a>.',
      no_email_provided: 'Электронная почта не указана',
      guest: 'Гость',
      auth_mail_header: 'VibesBox – Аккаунт',
      auth_mail_intro: 'Вы запросили действие для своей учётной записи VibesBox:',
      auth_role: 'Аккаунт',
      registration_header: 'Ваша регистрация в VibesBox',
      role_guest_access: 'Гостевой доступ',
      registration_role_dj: 'Доступ DJ',
      auth_email_datetime_suffix: '',
    },
    zh: {
      app_name: 'VibesBox',
      mail_contact_header: '新的联系请求',
      mail_contact_subject_line: '通过VibesBox的联系请求',
      mail_contact_intro_text: '您通过VibesBox收到了一条新的联系请求:',
      label_message: '消息',
      label_sender: '发件人',
      label_phone: '电话',
      label_role: '角色',
      label_party: '派对',
      label_date: '日期',
      label_reply_button: '回复',
      mail_footer_automated: '此电子邮件是通过<a href="https://vibesbox.app"><b>VibesBox.App</b></a>自动生成的。',
      no_email_provided: '未提供电子邮件',
      guest: '客人',
      auth_mail_header: 'VibesBox – 账户',
      auth_mail_intro: '您请求对 VibesBox 账户执行操作：',
      auth_role: '账户',
      registration_header: '您在 VibesBox 的注册',
      role_guest_access: '访客访问',
      registration_role_dj: 'DJ 访问',
      auth_email_datetime_suffix: '',
    },
    es: {
      app_name: 'VibesBox',
      mail_contact_header: 'Nueva solicitud de contacto',
      mail_contact_subject_line: 'Solicitud de contacto a través de VibesBox',
      mail_contact_intro_text: 'Has recibido una nueva solicitud de contacto a través de VibesBox:',
      label_message: 'Mensaje',
      label_sender: 'Remitente',
      label_phone: 'Teléfono',
      label_role: 'Rol',
      label_party: 'Fiesta',
      label_date: 'Fecha',
      label_reply_button: 'Responder',
      mail_footer_automated: 'Este correo electrónico fue generado automáticamente a través de <a href="https://vibesbox.app"><b>VibesBox.App</b></a>.',
      no_email_provided: 'No se proporcionó correo electrónico',
      guest: 'Invitado',
      auth_mail_header: 'VibesBox – Cuenta',
      auth_mail_intro: 'Has solicitado una acción para tu cuenta de VibesBox:',
      auth_role: 'Cuenta',
      registration_header: 'Tu registro en VibesBox',
      role_guest_access: 'Acceso de invitado',
      registration_role_dj: 'Acceso DJ',
      auth_email_datetime_suffix: '',
    },
    tr: {
      app_name: 'VibesBox',
      mail_contact_header: 'Yeni İletişim Talebi',
      mail_contact_subject_line: 'VibesBox üzerinden İletişim Talebi',
      mail_contact_intro_text: 'VibesBox üzerinden yeni bir iletişim talebi aldınız:',
      label_message: 'Mesaj',
      label_sender: 'Gönderen',
      label_phone: 'Telefon',
      label_role: 'Rol',
      label_party: 'Parti',
      label_date: 'Tarih',
      label_reply_button: 'Yanıtla',
      mail_footer_automated: 'Bu e-posta <a href="https://vibesbox.app"><b>VibesBox.App</b></a> aracılığıyla otomatik olarak oluşturulmuştur.',
      no_email_provided: 'E-posta sağlanmadı',
      guest: 'Misafir',
      auth_mail_header: 'VibesBox – Hesap',
      auth_mail_intro: 'VibesBox hesabınız için bir işlem talep ettiniz:',
      auth_role: 'Hesap',
      registration_header: 'VibesBox kaydınız',
      role_guest_access: 'Misafir erişimi',
      registration_role_dj: 'DJ erişimi',
      auth_email_datetime_suffix: '',
    },
    pt: {
      app_name: 'VibesBox',
      mail_contact_header: 'Nova Solicitação de Contato',
      mail_contact_subject_line: 'Solicitação de Contato via VibesBox',
      mail_contact_intro_text: 'Você recebeu uma nova solicitação de contato via VibesBox:',
      label_message: 'Mensagem',
      label_sender: 'Remetente',
      label_phone: 'Telefone',
      label_role: 'Função',
      label_party: 'Festa',
      label_date: 'Data',
      label_reply_button: 'Responder',
      mail_footer_automated: 'Este e-mail foi gerado automaticamente via <a href="https://vibesbox.app"><b>VibesBox.App</b></a>.',
      no_email_provided: 'Nenhum e-mail fornecido',
      guest: 'Convidado',
      auth_mail_header: 'VibesBox – Conta',
      auth_mail_intro: 'Você solicitou uma ação para a sua conta VibesBox:',
      auth_role: 'Conta',
      registration_header: 'O seu registo na VibesBox',
      role_guest_access: 'Acesso de convidado',
      registration_role_dj: 'Acesso DJ',
      auth_email_datetime_suffix: '',
    },
  };
}

// Validiert reCAPTCHA Token, speichert Kontaktnachricht in Firestore und sendet E-Mail
// Body: { recaptchaToken, name, email, phone, subject, message, partyId, client_id }
exports.validateRecaptchaAndSaveContact = onRequest(
  { secrets: [RECAPTCHA_ENTERPRISE_API_KEY, EMAILJS_PRIVATE_KEY] },
  async (req, res) => {
  // CORS wie cors({ origin: true }): Browser-Origin spiegeln (hilft bei fetch + credentials / „Failed to fetch“)
  if (req.headers.origin) {
    res.set('Access-Control-Allow-Origin', req.headers.origin);
    res.set('Access-Control-Allow-Credentials', 'true');
    res.set('Vary', 'Origin');
  } else {
    res.set('Access-Control-Allow-Origin', '*');
  }
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-App-Security-Key');

  // ✅ CORS-Preflight (OPTIONS) behandeln
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  // ✅ Minimales Logging
  console.log('✅ Anfrage erhalten - Methode:', req.method);

  try {
    // ✅ Body parsen (Cloud Run/Firebase liefert teils leeres req.body – dann rawBody nutzen)
    let body = req.body;
    if (!body || typeof body !== 'object') body = {};
    const bodyKeys = Object.keys(body);
    if (bodyKeys.length === 0 && req.rawBody) {
      try {
        const raw = req.rawBody;
        const str = Buffer.isBuffer(raw) ? raw.toString('utf8') : String(raw);
        if (str && str.trim()) body = JSON.parse(str);
      } catch (e) {
        console.warn('Body-Parse aus rawBody fehlgeschlagen:', e.message);
      }
    }
    if (!body || typeof body !== 'object') body = {};
    console.log('Body-Keys angekommen:', Object.keys(body).join(', ') || '(leer)');

    // ✅ Body-Daten extrahieren (recipientEmail = feste Empfänger-Adresse z.B. von Landingpage)
    const { recaptchaToken, gRecaptchaResponse, name, email, phone, subject, message, partyId, language, client_id, recipientEmail: bodyRecipientEmail, source } = body;
    const recaptchaTokenValue = gRecaptchaResponse || recaptchaToken;
    const isAppGuest = (source && String(source).trim() === 'app_guest');

    // ✅ Rate Limiting: max. 5 Kontaktanfragen pro Stunde pro IP (Spam-Schutz)
    const clientIp = (req.headers['x-forwarded-for'] || req.connection?.remoteAddress || req.socket?.remoteAddress || '').split(',')[0].trim() || 'unknown';
    const ipHash = crypto.createHash('sha256').update(clientIp).digest('hex').substring(0, 32);
    const rateLimitRef = db.collection('contact_rate_limit').doc(ipHash);
    const rateLimitSnap = await rateLimitRef.get();
    const now = admin.firestore.Timestamp.now();
    const oneHourAgo = new Date(now.toMillis() - 60 * 60 * 1000);
    const oneHourAgoTs = admin.firestore.Timestamp.fromDate(oneHourAgo);
    let timestamps = (rateLimitSnap.exists && rateLimitSnap.data().timestamps) ? rateLimitSnap.data().timestamps.filter(t => t.toMillis() >= oneHourAgoTs.toMillis()) : [];
    if (timestamps.length >= 5) {
      console.log('Rate limit überschritten für IP-Hash:', ipHash);
      return res.status(429).json({ error: 'Zu viele Anfragen. Bitte maximal 5 Nachrichten pro Stunde senden.' });
    }

    const guestKey = CONTACT_APP_GUEST_SECURITY_KEY.value();
    const trustedAppGuest = isTrustedAppGuestContactRequest(req, body, guestKey);
    const enterpriseApiKey = RECAPTCHA_ENTERPRISE_API_KEY.value();
    console.log(
      'RECAPTCHA Enterprise API-Key gesetzt:',
      !!enterpriseApiKey,
      '| trustedAppGuest:',
      trustedAppGuest,
    );

    if (!trustedAppGuest) {
      if (!recaptchaTokenValue || typeof recaptchaTokenValue !== 'string') {
        console.warn('400: reCAPTCHA Token fehlt (kein app_guest Bypass)');
        return res.status(400).json({ error: 'reCAPTCHA Token fehlt', code: 'MISSING_TOKEN' });
      }
      if (!enterpriseApiKey) {
        console.error('RECAPTCHA_ENTERPRISE_API_KEY nicht gesetzt — Kontakt abgelehnt');
        return res.status(503).json({
          error: 'Server-Konfiguration unvollständig (reCAPTCHA Enterprise)',
          code: 'RECAPTCHA_NOT_CONFIGURED',
        });
      }
      const verifyResult = await verifyRecaptchaEnterpriseAssessment(
        recaptchaTokenValue,
        RECAPTCHA_CONTACT_ACTION,
        enterpriseApiKey,
        clientIp,
      );
      if (!verifyResult.ok) {
        if (verifyResult.error === 'low_score') {
          console.warn('reCAPTCHA Enterprise Score zu niedrig:', verifyResult.score);
          return res.status(400).json({
            error: 'reCAPTCHA-Score zu niedrig',
            code: 'RECAPTCHA_LOW_SCORE',
            score: verifyResult.score,
          });
        }
        console.warn(
          'reCAPTCHA Enterprise Validierung fehlgeschlagen:',
          verifyResult.error,
          verifyResult.invalidReason || '',
        );
        return res.status(400).json({
          error: 'reCAPTCHA Validierung fehlgeschlagen',
          code: 'RECAPTCHA_VALIDATION_FAILED',
        });
      }
      console.log('reCAPTCHA OK, Score:', verifyResult.score);
    } else {
      console.log('Kontakt: app_guest mit gültigem X-App-Security-Key — reCAPTCHA übersprungen');
    }

    // ✅ Speichern / E-Mail
    if (!name || !message) {
      const missing = []; if (!name) missing.push('name'); if (!message) missing.push('message');
      console.warn('400: Name oder Nachricht fehlt –', missing.join(', '));
      return res.status(400).json({ error: 'Name und Nachricht sind erforderlich', code: 'MISSING_FIELDS', missing });
    }

    const contactData = {
      name: name.trim(),
      email: email ? email.trim() : '',
      phone: phone ? phone.trim() : '',
      subject: subject ? subject.trim() : '',
      message: message.trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      client_id: client_id || '',
      partyId: partyId || ''
    };

    // ✅ App-Guest: Kein Firestore-Write (datenbankschonend) – nur E-Mail-Versand
    // ✅ PWA/Landing: Firestore + E-Mail wie bisher
    let firestoreSaved = false;
    let emailSent = false;
    
    if (!isAppGuest) {
      try {
        await db.collection('contacts').add(contactData);
        firestoreSaved = true;
        console.log('✅ Firestore: Kontaktnachricht erfolgreich gespeichert');
      } catch (firestoreError) {
        console.error('❌ Firestore: Fehler beim Speichern', firestoreError);
        return res.status(500).json({
          error: 'Ein interner Fehler ist aufgetreten.'
        });
      }
    } else {
      console.log('App-Guest: Firestore-Write übersprungen (datenbankschonend)');
    }
    timestamps = [...timestamps, now].filter(t => t.toMillis() >= oneHourAgoTs.toMillis());
    await rateLimitRef.set({ timestamps, updatedAt: now }, { merge: true });

    // ✅ LOKALISIERUNG: Lade Übersetzungen basierend auf language
    const langCode = (language && typeof language === 'string') ? language.toLowerCase().split('-')[0] : 'de';
    const supportedLangs = ['de', 'en', 'fr', 'ru', 'zh', 'es', 'tr', 'pt'];
    const finalLang = supportedLangs.includes(langCode) ? langCode : 'de';
    
    const translations = getEmailJsContactTranslations();
    const t = translations[finalLang] || translations.de;

    // ✅ SERVER-SIDE E-MAIL-VERSAND: Empfänger aus Request (Landingpage) oder aus Party/User (VR-Seite)
    let recipientEmail = (bodyRecipientEmail && typeof bodyRecipientEmail === 'string' && bodyRecipientEmail.trim().length > 0)
      ? bodyRecipientEmail.trim()
      : null;
    let partyName = null;
    
    if (partyId && partyId !== 'manual' && partyId.trim() !== '') {
      try {
        // 1. Lade Party-Dokument
        const partyDoc = await db.collection('parties').doc(partyId).get();
        
        if (!partyDoc.exists) {
          // Party nicht gefunden, kein E-Mail-Versand möglich
        } else {
          const partyData = partyDoc.data();
          partyName = partyData.party_name || partyData.name || 'Unbekannte Party';
          const createdByUid = partyData.created_by;
          
          if (createdByUid) {
            // 2. Lade User-Dokument
            const userDoc = await db.collection('users').doc(createdByUid).get();
            
            if (userDoc.exists) {
              const userData = userDoc.data();
              
              // ✅ Robustes Auslesen der Kontakt-E-Mail
              const useAlternativeEmail = userData.useAlternativeEmail === true;
              const alternativeEmail = userData.alternativeEmail;
              
              if (useAlternativeEmail && alternativeEmail && typeof alternativeEmail === 'string' && alternativeEmail.trim().length > 0) {
                recipientEmail = alternativeEmail.trim();
              } else {
                recipientEmail = userData.email || userData.userEmail || null;
                if (recipientEmail) {
                  recipientEmail = recipientEmail.trim();
                }
              }
            }
          }
        }
      } catch (emailLookupError) {
        console.error('Fehler:', emailLookupError.message);
      }
    }

    // ✅ App-Guest: Immer info@vibesbox.app (Datenbankschonender Weg ohne Firestore)
    if (isAppGuest) {
      recipientEmail = 'info@vibesbox.app';
      console.log('App-Guest: Zustellung an info@vibesbox.app');
    }
    // ✅ Landingpage: Ohne partyId und ohne recipientEmail im Body → Standard-Empfänger info@vibesbox.app
    else if (!recipientEmail) {
      recipientEmail = 'info@vibesbox.app';
      console.log('Keine Empfänger-E-Mail aus Party/User/Body – verwende Standard (Landingpage):', recipientEmail);
    }

    // ✅ E-Mail-Daten zusammenbauen (Empfänger jetzt immer gesetzt)
    if (recipientEmail) {
      // ✅ EmailJS API aufrufen (Server-Side mit Private Key)
      const {
        serviceId: emailJSServiceId,
        templateId: emailJSTemplateId,
        publicKey: emailJSPublicKey,
      } = getEmailJsPublicIds();
      if (!emailJSServiceId || !emailJSTemplateId) {
        return res.status(500).json({
          error:
            'EMAILJS_SERVICE_ID oder EMAILJS_TEMPLATE_ID fehlt (Env oder functions:config emailjs.*)',
        });
      }
      console.log('DEBUG: Service ID / Template ID gesetzt:', !!emailJSServiceId, !!emailJSTemplateId);

      if (!emailJSPublicKey) {
        return res.status(500).json({
          error: 'EMAILJS_PUBLIC_KEY fehlt (Env oder functions:config emailjs.public_key)',
        });
      }
      // ✅ Private Key ausschließlich aus Secret Manager (2nd Gen)
      const rawKey = EMAILJS_PRIVATE_KEY.value();
      const cleanKey = rawKey ? rawKey.replace(/[\r\n\t]/g, '').trim() : '';
      console.log('EMAILJS Private Key gesetzt:', !!rawKey, 'Länge nach Reinigung:', cleanKey.length);
      if (!cleanKey) {
        return res.status(500).json({ error: 'EmailJS Private Key nicht konfiguriert' });
      }

      // ✅ USER_EMAIL Fallback-Logik: Prüfe Gast-E-Mail vor dem Zusammenbauen von template_params
      // Wenn email leer ist oder gleich dem Platzhalter-Text, verwende DJ-E-Mail
      let userEmailForTemplate;
      const emailTrimmed = email ? email.trim() : '';
      const noEmailPlaceholder = t.no_email_provided; // Lokalisierter Platzhalter-Text
      
      if (emailTrimmed.length > 0 && emailTrimmed !== noEmailPlaceholder) {
        // Gast hat eine E-Mail eingegeben (und es ist nicht der Platzhalter-Text)
        userEmailForTemplate = emailTrimmed;
        console.log('✅ USER_EMAIL: Verwende Gast-E-Mail:', userEmailForTemplate);
      } else {
        // Feld ist leer oder enthält nur Platzhalter-Text -> Fallback auf DJ-E-Mail
        userEmailForTemplate = recipientEmail || 'ollerganove@gmail.com';
        console.log('✅ USER_EMAIL: Verwende DJ-E-Mail (Fallback):', userEmailForTemplate);
      }
      
      // Für Display-Zwecke (falls benötigt)
      const userEmailForDisplay = (emailTrimmed.length > 0 && emailTrimmed !== noEmailPlaceholder) 
        ? emailTrimmed 
        : t.no_email_provided;
      
      // ✅ Datum/Uhrzeit formatieren (sprachabhängig, DE: „… Uhr“ via i18n-Suffix)
      const now = new Date();
      const dateFormatted = formatEmailJsDateTime(now, finalLang, t);
      
      // ✅ Betreff formatieren (mit lokalisiertem Text)
      const mailSubject = subject && subject.trim().length > 0 
        ? subject.trim() 
        : `${t.mail_contact_subject_line} - ${name ? name.trim() : 'Unbekannt'}`;

      const templateParams = {
        // ✅ Basis-Parameter (Pflichtfeld: to_email MUSS gesetzt sein!)
        to_email: recipientEmail || 'ollerganove@gmail.com', // ✅ Fallback für Sicherheit
        user_name: name ? name.trim() : 'Unbekannt',
        user_email: userEmailForTemplate, // ✅ Gast-E-Mail oder DJ-E-Mail (Fallback)
        phone_info: phone && phone.trim().length > 0 ? phone.trim() : t.no_email_provided,
        mail_subject: mailSubject,
        message: wrapContactUserMessageForEmailJs(message),
        role: t.guest,
        party_info: partyName || 'Unbekannte Party',
        created_at: dateFormatted,
        
        // ✅ Lokalisierte Labels und Texte (alle 15+ Variablen)
        app_name: t.app_name,
        mail_contact_header: t.mail_contact_header,
        mail_contact_subject_line: t.mail_contact_subject_line,
        mail_contact_intro_text: t.mail_contact_intro_text,
        label_message: t.label_message,
        label_sender: t.label_sender,
        label_phone: t.label_phone,
        label_role: t.label_role,
        label_party: t.label_party,
        label_date: t.label_date,
        label_reply_button: t.label_reply_button,
        mail_footer_automated: t.mail_footer_automated,
        no_email_provided: t.no_email_provided,
        user_email_display: userEmailForDisplay,
        show_party_row: '1',
      };
      
      // ✅ Pflichtfeld-Check: Stelle sicher, dass to_email im templateParams enthalten ist
      if (!templateParams.to_email || templateParams.to_email.trim() === '') {
        templateParams.to_email = recipientEmail; // ✅ Fallback: Verwende recipientEmail
      }
      
      const emailData = {
        service_id: emailJSServiceId,
        template_id: emailJSTemplateId,
        user_id: emailJSPublicKey, // ✅ Public Key (UserID) - nicht geheim
        accessToken: cleanKey, // ✅ Private Key als accessToken für Server-Autorisierung (bereinigt: keine Zeilenumbrüche)
        template_params: templateParams // ✅ Vollständiges Objekt mit allen 23 Variablen (user_email enthält Gast-E-Mail oder DJ-E-Mail als Fallback)
      };

      // ✅ Echter E-Mail-Versand
      console.log('Versand startet für:', recipientEmail);
      console.log('DEBUG: Template Params Anzahl:', Object.keys(emailData.template_params).length);
      console.log('DEBUG: to_email Wert:', emailData.template_params.to_email);
      
      try {
        const emailResponse = await axios.post(
          'https://api.emailjs.com/api/v1.0/email/send',
          emailData,
          {
            headers: {
              'Content-Type': 'application/json'
            },
            timeout: 10000
          }
        );

        if (emailResponse.status === 200) {
          emailSent = true;
          console.log('✅ EmailJS: E-Mail erfolgreich versendet (Status 200)');
          // ✅ NUR wenn Firestore UND EmailJS erfolgreich: Status 200 zurückgeben
          return res.status(200).json({ 
            success: true, 
            message: 'Kontaktnachricht erfolgreich gespeichert und E-Mail versendet' 
          });
        } else {
          console.error('❌ EmailJS: Ungültiger Status', emailResponse.status);
          return res.status(500).json({ 
            success: false, 
            error: 'E-Mail-Versand fehlgeschlagen',
            message: 'Die Nachricht wurde gespeichert, aber die E-Mail konnte nicht versendet werden. Bitte versuche es erneut.' 
          });
        }
      } catch (emailErr) {
        // ✅ Vollständiges Error-Logging für Firebase Console (inkl. Stack)
        const status = emailErr.response?.status;
        const data = emailErr.response?.data;
        console.error('❌ EmailJS Error Message:', emailErr.message);
        console.error('❌ EmailJS Error Stack:', emailErr.stack);
        console.error('❌ EmailJS Response Status:', status);
        console.error('❌ EmailJS Response Data:', JSON.stringify(data || null));
        let hint = '';
        if (status === 401) hint = 'EmailJS: Private Key ungültig (Secret Manager prüfen).';
        else if (status === 403) hint = 'EmailJS: Zugriff verweigert (Service/Template/Key).';
        else if (status === 422 || status === 400) hint = 'EmailJS: Template/Parameter fehlerhaft.';
        else if (emailErr.code === 'ECONNREFUSED' || emailErr.code === 'ETIMEDOUT') hint = 'EmailJS: Netzwerk/Timeout.';
        else {
          const msg = (data && (data.message || data.error || data.text)) ? String(data.message || data.error || data.text).slice(0, 120) : '';
          hint = status ? 'EmailJS HTTP ' + status + (msg ? ': ' + msg : '') : (emailErr.message ? 'Fehler: ' + String(emailErr.message).slice(0, 80) : 'Firebase Console → Functions → Logs prüfen.');
        }
        return res.status(500).json({ 
          success: false,
          error: 'E-Mail-Versand fehlgeschlagen',
          message: 'Die Nachricht wurde gespeichert, aber die E-Mail konnte nicht versendet werden. Bitte versuche es erneut.',
          hint: hint
        });
      }
    } else {
      // ✅ Keine Empfänger-E-Mail gefunden -> Status 500
      return res.status(500).json({ 
        success: false,
        error: 'Keine Empfänger-E-Mail gefunden',
        message: 'Die Nachricht konnte nicht versendet werden, da keine Empfänger-E-Mail gefunden wurde.' 
      });
    }
  } catch (err) {
    console.error('validateRecaptchaAndSaveContact Fehler:', err);
    console.error('validateRecaptchaAndSaveContact Stack:', err.stack);
    sendInternalError(res);
  }
});

// ==========================================
// SPRACH-STATISTIK (Main PWA + VB PWA)
// ==========================================
// Erfasst Gerätesprache pro Aufruf (1x pro Gerät/Tag via localStorage-Spamschutz clientseitig).
// Collection: language_stats, Dokument-ID = Sprachkürzel (z.B. de, en).
exports.recordLanguageHit = onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  try {
    const body = req.method === 'POST' && req.body ? req.body : {};
    let languageCode = (body.languageCode || body.language_code || req.query.languageCode || req.query.lang || '').toString().trim();
    if (!languageCode && req.method === 'GET' && req.query) {
      languageCode = (req.query.lang || req.query.languageCode || '').toString().trim();
    }
    const languageName = (body.languageName || body.language_name || '').toString().trim() || null;

    if (!languageCode) {
      return res.status(400).json({ error: 'languageCode fehlt' });
    }
    const normalized = languageCode.split('-')[0].toLowerCase().replace(/[^a-z]/g, '');
    if (normalized.length !== 2) {
      return res.status(400).json({ error: 'languageCode muss 2 Zeichen haben (z.B. de, en)' });
    }

    const ref = db.collection('language_stats').doc(normalized);
    const update = {
      count: admin.firestore.FieldValue.increment(1),
      last_hit: admin.firestore.FieldValue.serverTimestamp()
    };
    if (languageName) update.language_name = languageName;
    await ref.set(update, { merge: true });

    return res.status(200).json({ success: true, language: normalized });
  } catch (err) {
    console.error('recordLanguageHit Fehler:', err);
    return res.status(500).json({ error: 'Ein interner Fehler ist aufgetreten.' });
  }
});

// ==========================================
// EINMALIGES BEREINIGUNGS-SKRIPT
// ==========================================
// Scant alle music_history Dokumente und setzt isActive=false für alte Sessions
// Wird einmalig aufgerufen, um die Datenbank zu bereinigen
exports.cleanupOldMusicHistorySessions = functions.https.onRequest(async (req, res) => {
  const now = admin.firestore.Timestamp.now();
  let scanned = 0;
  let updated = 0;

  try {
    if (!(await requireAppCheckRequest(req, res))) return;
    if (!(await requireMasterAdminFromIdToken(req, res))) return;

    console.log('[CLEANUP] Starte Bereinigung alter music_history Sessions...');
    
    // Lade ALLE music_history Dokumente (ohne Filter)
    const sessionsSnap = await db.collection('music_history').get();
    console.log(`[CLEANUP] Gefunden: ${sessionsSnap.size} Sessions zum Prüfen`);

    let batch = db.batch();
    let batchOps = 0;
    const BATCH_LIMIT = 450;

    for (const sessionDoc of sessionsSnap.docs) {
      scanned++;
      const sessionData = sessionDoc.data();
      const isActive = sessionData.isActive === true;
      const startTime = sessionData.startTime;

      // Nur Dokumente mit isActive=true bearbeiten
      if (!isActive) continue;

      // Prüfe ob startTime in der Vergangenheit liegt
      if (startTime) {
        const startDate = startTime.toDate();
        const nowDate = now.toDate();
        
        // Wenn startTime in der Vergangenheit liegt, setze isActive=false
        if (startDate < nowDate) {
          batch.update(sessionDoc.ref, {
            isActive: false,
            cleaned_at: now,
          });
          batchOps++;
          updated++;

          console.log(`[CLEANUP] Session ${sessionDoc.id}: isActive=false gesetzt (startTime: ${startDate} < now: ${nowDate})`);

          // Batch commit, wenn Limit erreicht
          if (batchOps >= BATCH_LIMIT) {
            await batch.commit();
            batch = db.batch();
            batchOps = 0;
            console.log(`[CLEANUP] Batch committed. Fortsetzung...`);
          }
        }
      }
    }

    // Finale Batch-Commit
    if (batchOps > 0) {
      await batch.commit();
    }

    console.log(`[CLEANUP] Fertig. Gescannt: ${scanned}, Aktualisiert: ${updated}`);
    res.json({ 
      success: true, 
      message: 'Bereinigung abgeschlossen',
      scanned: scanned,
      updated: updated 
    });
  } catch (err) {
    console.error('[CLEANUP] Fehler beim Bereinigen:', err);
    sendInternalError(res);
  }
});

// ==========================================
// SCHEDULED FUNCTION: PARTY TIMEOUT CHECK (OPTIMIERT)
// ==========================================
// Läuft alle 5 Minuten und setzt isActive=false für Sessions ohne Heartbeat (>10 Min)
// MEMORY: 512MB für große Datenmengen
// FIX: Prüft Wert-Änderung vor Update, verhindert Endlosschleife, Limit auf Query
exports.partyTimeoutCheck = functions.runWith({ memory: '512MB', timeoutSeconds: 540 }).pubsub.schedule('every 5 minutes').onRun(async (context) => {
  const now = admin.firestore.Timestamp.now();
  const tenMinutesAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 10 * 60 * 1000);

  try {
    console.log('[PARTY-TIMEOUT] Starte Party-Timeout-Check (läuft alle 5 Min)...');
    
    // ✅ MEMORY-FIX: Limit auf Query setzen (max 1000 Dokumente pro Durchlauf)
    // ✅ Verhindert Memory Overflow bei vielen Sessions
    const MAX_SESSIONS_PER_RUN = 1000;
    
    // Query: Alle aktiven Sessions (mit Limit)
    const activeSessionsSnap = await db
      .collection('music_history')
      .where('isActive', '==', true)
      .limit(MAX_SESSIONS_PER_RUN)
      .get();
    
    console.log(`[PARTY-TIMEOUT] Gefunden: ${activeSessionsSnap.size} aktive Sessions zum Prüfen (Limit: ${MAX_SESSIONS_PER_RUN})`);

    // ✅ ENDLOSSCHLEIFEN-FIX: Sammle nur Dokumente, die wirklich geändert werden müssen
    const expiredDocs = [];
    for (const doc of activeSessionsSnap.docs) {
      const sessionData = doc.data();
      const lastHeartbeat = sessionData.last_heartbeat;
      const currentIsActive = sessionData.isActive;
      
      // ✅ WICHTIG: Prüfe, ob isActive bereits false ist (verhindert doppelte Updates)
      if (currentIsActive === false) {
        console.log(`[PARTY-TIMEOUT] Session ${doc.id}: isActive bereits false, überspringe`);
        continue;
      }
      
      // Wenn kein last_heartbeat vorhanden ist, gilt als abgelaufen
      if (!lastHeartbeat) {
        expiredDocs.push(doc);
        console.log(`[PARTY-TIMEOUT] Session ${doc.id}: kein last_heartbeat -> abgelaufen`);
        continue;
      }
      
      // Prüfe ob last_heartbeat älter als 10 Minuten ist
      const heartbeatDate = lastHeartbeat.toDate();
      const tenMinutesAgoDate = tenMinutesAgo.toDate();
      
      if (heartbeatDate < tenMinutesAgoDate) {
        expiredDocs.push(doc);
        console.log(`[PARTY-TIMEOUT] Session ${doc.id}: last_heartbeat ${heartbeatDate} ist älter als 10 Min -> abgelaufen`);
      }
    }

    if (expiredDocs.length === 0) {
      console.log('[PARTY-TIMEOUT] ✅ Keine abgelaufenen Sessions gefunden');
      return null;
    }

    // ✅ BATCH-UPDATE: Nur Dokumente aktualisieren, die wirklich geändert werden müssen
    let batch = db.batch();
    const BATCH_LIMIT = 450;
    let batchOps = 0;
    let updated = 0;

    for (const doc of expiredDocs) {
      // ✅ ENDLOSSCHLEIFEN-FIX: Prüfe nochmal, ob isActive wirklich true ist
      // (könnte zwischenzeitlich von anderer Funktion geändert worden sein)
      const docData = await doc.ref.get();
      if (!docData.exists) {
        console.log(`[PARTY-TIMEOUT] Session ${doc.id}: Dokument existiert nicht mehr, überspringe`);
        continue;
      }
      
      const currentData = docData.data();
      if (currentData.isActive === false) {
        console.log(`[PARTY-TIMEOUT] Session ${doc.id}: isActive bereits false (zwischenzeitlich geändert), überspringe`);
        continue;
      }
      
      // ✅ WERT-ÄNDERUNGS-PRÜFUNG: Nur updaten, wenn sich der Wert wirklich ändert
      batch.update(doc.ref, {
        isActive: false,
        heartbeat_timeout: now,
      });
      batchOps++;
      updated++;

      // Batch commit, wenn Limit erreicht
      if (batchOps >= BATCH_LIMIT) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
        console.log(`[PARTY-TIMEOUT] Batch committed (${updated}/${expiredDocs.length}). Fortsetzung...`);
      }
    }

    // Finale Batch-Commit
    if (batchOps > 0) {
      await batch.commit();
    }

    console.log(`[PARTY-TIMEOUT] ✅ Fertig. ${updated} von ${expiredDocs.length} Sessions auf isActive=false gesetzt`);
    return null;
  } catch (err) {
    console.error('[PARTY-TIMEOUT] ❌ Fehler beim Cleanup:', err);
    console.error('   Error Message:', err.message);
    console.error('   Error Stack:', err.stack);
    throw err;
  }
});

// ==========================================
// STICHTAG-LOGIK (usedPartySlots – Abrechnungszeitraum)
// Identisch zur Dart-Logik in LimitService
// ==========================================
function getAnchorDayFromUserData(userData) {
  if (!userData) return 1;
  let anchorMs = null;
  const fp = userData.free_period_start;
  if (fp && typeof fp.toMillis === 'function') anchorMs = fp.toMillis();
  else {
    const ca = userData.created_at;
    if (ca && typeof ca.toMillis === 'function') anchorMs = ca.toMillis();
  }
  if (anchorMs == null) return 1;
  const d = new Date(anchorMs);
  let day = d.getUTCDate();
  if (day < 1) return 1;
  if (day > 31) return 31;
  return day;
}

function stichtagForMonth(year, month, anchorDay) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (anchorDay <= lastDay) {
    return new Date(Date.UTC(year, month - 1, anchorDay));
  }
  if (month === 12) return new Date(Date.UTC(year + 1, 0, 1));
  return new Date(Date.UTC(year, month, 1));
}

function nextStichtag(zielDate, anchorDay) {
  const y = zielDate.getUTCFullYear();
  const m = zielDate.getUTCMonth() + 1;
  let stichtag = stichtagForMonth(y, m, anchorDay);
  if (stichtag.getTime() > zielDate.getTime()) return stichtag;
  if (m === 12) return stichtagForMonth(y + 1, 1, anchorDay);
  return stichtagForMonth(y, m + 1, anchorDay);
}

function previousStichtag(date, anchorDay) {
  const y = date.getUTCFullYear();
  const m = date.getUTCMonth() + 1;
  const prevM = m === 1 ? 12 : m - 1;
  const prevY = m === 1 ? y - 1 : y;
  return stichtagForMonth(prevY, prevM, anchorDay);
}

function getAbrechnungsZeitraum(zielDate, anchorDay) {
  const next = nextStichtag(zielDate, anchorDay);
  const periodEnd = new Date(next.getTime() - 1000);
  const periodStart = previousStichtag(next, anchorDay);
  return { start: periodStart, end: periodEnd };
}

function computePeriodSlotKey(partyStartDate, anchorDay) {
  const { start } = getAbrechnungsZeitraum(partyStartDate, anchorDay);
  const y = start.getUTCFullYear();
  const m = String(start.getUTCMonth() + 1).padStart(2, '0');
  const d = String(start.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// ==========================================
// STICHTAG-LOGIK (usedPartySlots) – identisch zu Dart LimitService
// ==========================================
function getAnchorDayFromUserData(userData) {
  if (!userData) return 1;
  let anchor = null;
  if (userData.free_period_start && userData.free_period_start.toDate) {
    anchor = userData.free_period_start.toDate();
  } else if (userData.created_at && userData.created_at.toDate) {
    anchor = userData.created_at.toDate();
  }
  if (!anchor || !(anchor instanceof Date)) return 1;
  const day = anchor.getUTCDate();
  if (day < 1) return 1;
  if (day > 31) return 31;
  return day;
}

function stichtagForMonth(year, month, anchorDay) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (anchorDay <= lastDay) {
    return new Date(Date.UTC(year, month - 1, anchorDay));
  }
  if (month === 12) return new Date(Date.UTC(year + 1, 0, 1));
  return new Date(Date.UTC(year, month, 0));
}

function nextStichtag(zielDate, anchorDay) {
  const y = zielDate.getUTCFullYear();
  const m = zielDate.getUTCMonth() + 1;
  let stichtag = stichtagForMonth(y, m, anchorDay);
  if (stichtag > zielDate) return stichtag;
  if (m === 12) return stichtagForMonth(y + 1, 1, anchorDay);
  return stichtagForMonth(y, m + 1, anchorDay);
}

function previousStichtag(date, anchorDay) {
  const y = date.getUTCFullYear();
  const m = date.getUTCMonth() + 1;
  const prevYear = m === 1 ? y - 1 : y;
  const prevMonth = m === 1 ? 12 : m - 1;
  return stichtagForMonth(prevYear, prevMonth, anchorDay);
}

function getAbrechnungsZeitraum(zielDate, anchorDay) {
  const next = nextStichtag(zielDate, anchorDay);
  const periodEnd = new Date(next.getTime() - 1000);
  const periodStart = previousStichtag(next, anchorDay);
  return { start: periodStart, end: periodEnd };
}

function computePeriodSlotKey(partyStartDate, anchorDay) {
  const period = getAbrechnungsZeitraum(partyStartDate, anchorDay);
  const d = period.start;
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

// ==========================================
// STICHTAG-HILFSFUNKTIONEN (identisch zu Dart LimitService)
// ==========================================
// Berechnet den Perioden-Slot-Key (YYYY-MM-DD) für usedPartySlots.
// anchorDay: 1-31 aus free_period_start oder created_at des Users.
function getAnchorDayFromUserData(userData) {
  if (!userData) return 1;
  let anchor = null;
  const fp = userData.free_period_start;
  if (fp && fp.toMillis) {
    anchor = fp.toDate();
  } else {
    const ca = userData.created_at;
    if (ca && ca.toMillis) anchor = ca.toDate();
  }
  if (!anchor) return 1;
  const day = anchor.getUTCDate();
  if (day < 1) return 1;
  if (day > 31) return 31;
  return day;
}

function stichtagForMonth(year, month, anchorDay) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (anchorDay <= lastDay) {
    return new Date(Date.UTC(year, month - 1, anchorDay));
  }
  if (month === 12) {
    return new Date(Date.UTC(year + 1, 0, 1));
  }
  return new Date(Date.UTC(year, month, 1));
}

function nextStichtag(zielDate, anchorDay) {
  const y = zielDate.getUTCFullYear();
  const m = zielDate.getUTCMonth() + 1;
  let stichtag = stichtagForMonth(y, m, anchorDay);
  if (stichtag > zielDate) return stichtag;
  if (m === 12) {
    return stichtagForMonth(y + 1, 1, anchorDay);
  }
  return stichtagForMonth(y, m + 1, anchorDay);
}

function previousStichtag(nextStichtagDate, anchorDay) {
  const d = new Date(nextStichtagDate);
  d.setUTCDate(0); // Letzter Tag des Vormonats
  const prevMonth = d.getUTCMonth() + 1;
  const prevYear = d.getUTCFullYear();
  return stichtagForMonth(prevYear, prevMonth, anchorDay);
}

function computePeriodSlotKey(partyStartDate, anchorDay) {
  const next = nextStichtag(partyStartDate, anchorDay);
  const periodStart = previousStichtag(next, anchorDay);
  const y = periodStart.getUTCFullYear();
  const m = periodStart.getUTCMonth() + 1;
  const day = periodStart.getUTCDate();
  return `${y}-${String(m).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

// ==========================================
// STICHTAG-HELPERS (identisch zu LimitService / getAbrechnungsZeitraum)
// ==========================================
function getAnchorDayFromUserData(userData) {
  if (!userData) return 1;
  let anchor = null;
  const fp = userData.free_period_start;
  if (fp && fp.toDate) anchor = fp.toDate();
  else if (userData.created_at && userData.created_at.toDate) anchor = userData.created_at.toDate();
  if (!anchor) return 1;
  const day = anchor.getDate ? anchor.getDate() : anchor.getUTCDate();
  if (day < 1) return 1;
  if (day > 31) return 31;
  return day;
}

function stichtagForMonth(year, month, anchorDay) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (anchorDay <= lastDay) {
    return new Date(Date.UTC(year, month - 1, anchorDay));
  }
  if (month === 12) return new Date(Date.UTC(year + 1, 0, 1));
  return new Date(Date.UTC(year, month, 1));
}

function nextStichtag(zielDate, anchorDay) {
  let y = zielDate.getUTCFullYear(), m = zielDate.getUTCMonth() + 1, d = zielDate.getUTCDate();
  let stichtag = stichtagForMonth(y, m, anchorDay);
  if (stichtag.getTime() > zielDate.getTime()) return stichtag;
  if (m === 12) return stichtagForMonth(y + 1, 1, anchorDay);
  return stichtagForMonth(y, m + 1, anchorDay);
}

function previousStichtag(nextStichtagDate, anchorDay) {
  const d = new Date(nextStichtagDate);
  d.setUTCMonth(d.getUTCMonth() - 1);
  const y = d.getUTCFullYear(), m = d.getUTCMonth() + 1;
  return stichtagForMonth(y, m, anchorDay);
}

function computePeriodSlotKey(partyStartDate, anchorDay) {
  const next = nextStichtag(partyStartDate, anchorDay);
  const periodStart = previousStichtag(next, anchorDay);
  const y = periodStart.getUTCFullYear();
  const mo = String(periodStart.getUTCMonth() + 1).padStart(2, '0');
  const day = String(periodStart.getUTCDate()).padStart(2, '0');
  return `${y}-${mo}-${day}`;
}

// ==========================================
// STICHTAG-LOGIK (identisch zu Dart LimitService)
// ==========================================
/** Anker-Tag (1–31) aus User-Daten (free_period_start oder created_at). */
function getAnchorDayFromUserData(userData) {
  if (!userData) return 1;
  let anchor = null;
  const fp = userData.free_period_start;
  if (fp && typeof fp.toDate === 'function') {
    anchor = fp.toDate();
  } else if (userData.created_at && typeof userData.created_at.toDate === 'function') {
    anchor = userData.created_at.toDate();
  }
  if (!anchor) return 1;
  const day = anchor.getUTCDate();
  if (day < 1) return 1;
  if (day > 31) return 31;
  return day;
}
/** Stichtag für einen Monat (JS Date, UTC). */
function stichtagForMonth(year, month, anchorDay) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (anchorDay <= lastDay) {
    return new Date(Date.UTC(year, month - 1, anchorDay));
  }
  if (month === 12) return new Date(Date.UTC(year + 1, 0, 1));
  return new Date(Date.UTC(year, month, 1));
}
/** Nächster Stichtag streng nach date. */
function nextStichtag(date, anchorDay) {
  const y = date.getUTCFullYear();
  const m = date.getUTCMonth() + 1;
  let stichtag = stichtagForMonth(y, m, anchorDay);
  if (stichtag > date) return stichtag;
  if (m === 12) return stichtagForMonth(y + 1, 1, anchorDay);
  return stichtagForMonth(y, m + 1, anchorDay);
}
/** Perioden-Start für ein Datum (Stichtag). */
function previousStichtag(date, anchorDay) {
  const y = date.getUTCFullYear();
  const m = date.getUTCMonth() + 1;
  const prevM = m === 1 ? 12 : m - 1;
  const prevY = m === 1 ? y - 1 : y;
  return stichtagForMonth(prevY, prevM, anchorDay);
}
/** Berechnet period.start (Date) für das Datum. */
function getPeriodStartForDate(date, anchorDay) {
  const next = nextStichtag(date, anchorDay);
  return previousStichtag(next, anchorDay);
}
/** Slot-Key "YYYY-MM-DD" aus Partystart + User anchorDay. */
function computePeriodSlotKey(partyStartDate, anchorDay) {
  const start = getPeriodStartForDate(partyStartDate, anchorDay);
  const y = start.getUTCFullYear();
  const m = String(start.getUTCMonth() + 1).padStart(2, '0');
  const d = String(start.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// Stichtag-Logik für usedPartySlots (identisch zu LimitService.getAbrechnungsZeitraum)
function getAnchorDayFromUserData(userData) {
  if (!userData) return 1;
  let anchor = null;
  const fp = userData.free_period_start;
  if (fp && fp.toDate) anchor = fp.toDate();
  else if (userData.created_at && userData.created_at.toDate) anchor = userData.created_at.toDate();
  if (!anchor) return 1;
  const day = anchor.getDate();
  if (day < 1) return 1;
  if (day > 31) return 31;
  return day;
}

function stichtagForMonth(year, month, anchorDay) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (anchorDay <= lastDay) return new Date(Date.UTC(year, month - 1, anchorDay));
  if (month === 12) return new Date(Date.UTC(year + 1, 0, 1));
  return new Date(Date.UTC(year, month, 1));
}

function nextStichtag(zielDate, anchorDay) {
  const y = zielDate.getUTCFullYear(), m = zielDate.getUTCMonth() + 1;
  let stichtag = stichtagForMonth(y, m, anchorDay);
  if (stichtag > zielDate) return stichtag;
  if (m === 12) return stichtagForMonth(y + 1, 1, anchorDay);
  return stichtagForMonth(y, m + 1, anchorDay);
}

function computePeriodSlotKey(partyStartDate, anchorDay) {
  const next = nextStichtag(partyStartDate, anchorDay);
  const prevY = next.getUTCMonth() === 0 ? next.getUTCFullYear() - 1 : next.getUTCFullYear();
  const prevM = next.getUTCMonth() === 0 ? 12 : next.getUTCMonth();
  const periodStart = stichtagForMonth(prevY, prevM, anchorDay);
  const y = periodStart.getUTCFullYear();
  const m = String(periodStart.getUTCMonth() + 1).padStart(2, '0');
  const d = String(periodStart.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// ==========================================
// SCHEDULED FUNCTION: PARTY STATUS CHECK
// ==========================================
// Läuft jede Minute und setzt lifecycle_status auf 'finished' für Partys,
// deren endTimePosix (Unix-Timestamp in Sekunden) überschritten wurde
// MEMORY: 512MB für große Datenmengen
// WICHTIG: Für diese Query ist ein Composite Index erforderlich:
// Collection: parties
// Fields: lifecycle_status (Ascending), end_time_posix (Ascending)
// Erstelle diesen Index in der Firebase Console unter Firestore > Indexes
exports.checkPartyStatus = functions.runWith({ memory: '512MB', timeoutSeconds: 540 }).pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const now = Date.now(); // Aktuelle Zeit in Millisekunden
  const nowSeconds = Math.floor(now / 1000); // Aktuelle Zeit in Sekunden (Unix-Timestamp)
  
  try {
    console.log('[PARTY-STATUS-CHECK] Starte Party-Status-Check (läuft jede Minute)...');
    console.log(`[PARTY-STATUS-CHECK] Aktuelle Zeit (Unix Sekunden): ${nowSeconds}`);
    
    // OPTIMIERTE Query: Filtert direkt nach aktiven UND abgelaufenen Partys
    // Dies reduziert die Lesekosten drastisch, da nur fällige Partys geladen werden
    const activePartiesSnap = await db
      .collection('parties')
      .where('lifecycle_status', '==', 'active')
      .where('end_time_posix', '<=', nowSeconds)
      .get();
    
    console.log(`[PARTY-STATUS-CHECK] Gefunden: ${activePartiesSnap.size} fällige Partys (bereits gefiltert)`);
    
    if (activePartiesSnap.empty) {
      console.log('[PARTY-STATUS-CHECK] ✅ Keine fälligen Partys gefunden');
      return null;
    }
    
    // Sammle Partys, die beendet werden müssen
    // HINWEIS: Die Query filtert bereits nach end_time_posix <= nowSeconds,
    // daher müssen wir hier nur noch prüfen, ob end_time_posix vorhanden ist
    // (für den Fall, dass noch alte Test-Daten ohne Zeitstempel existieren)
    const finishedParties = [];
    for (const doc of activePartiesSnap.docs) {
      const partyData = doc.data();
      const endTimePosix = partyData.end_time_posix;
      
      // Prüfe ob endTimePosix vorhanden ist (Fallback für alte Daten ohne Zeitstempel)
      if (endTimePosix == null || endTimePosix === undefined) {
        console.log(`[PARTY-STATUS-CHECK] ⚠️ Party ${doc.id}: end_time_posix fehlt, überspringe`);
        continue;
      }
      
      // Alle Dokumente in dieser Liste sind bereits abgelaufen (durch Query gefiltert)
      finishedParties.push(doc);
      const endDate = new Date(endTimePosix * 1000); // Konvertiere Sekunden zu Millisekunden für Date
      console.log(`[PARTY-STATUS-CHECK] Party ${doc.id} (${partyData.party_name || 'Unbekannt'}): endTimePosix ${endTimePosix} (${endDate.toISOString()}) -> wird beendet`);
    }
    
    if (finishedParties.length === 0) {
      console.log('[PARTY-STATUS-CHECK] ✅ Keine Partys müssen beendet werden');
      return null;
    }
    
    console.log(`[PARTY-STATUS-CHECK] ${finishedParties.length} Partys müssen beendet werden`);
    
    // Batch-Update für alle zu beendenden Partys
    let batch = db.batch();
    const BATCH_LIMIT = 450; // Firestore Batch-Limit ist 500, wir nutzen 450 als Puffer
    let batchOps = 0;
    let updated = 0;
    
    for (const doc of finishedParties) {
      // Prüfe nochmal, ob Party noch aktiv ist (könnte zwischenzeitlich geändert worden sein)
      const docData = await doc.ref.get();
      if (!docData.exists) {
        console.log(`[PARTY-STATUS-CHECK] Party ${doc.id}: Dokument existiert nicht mehr, überspringe`);
        continue;
      }
      
      const currentData = docData.data();
      if (currentData.lifecycle_status !== 'active') {
        console.log(`[PARTY-STATUS-CHECK] Party ${doc.id}: lifecycle_status bereits ${currentData.lifecycle_status}, überspringe`);
        continue;
      }
      
      // Setze lifecycle_status auf 'finished'
      // WICHTIG: Nur lifecycle_status ändern, keine anderen Felder berühren
      batch.update(doc.ref, {
        lifecycle_status: 'finished',
        finished_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      batchOps++;
      updated++;

      // Free-DJ usedPartySlots: Stichtag-Slot (period.start "YYYY-MM-DD") dauerhaft markieren (fälschungssicher)
      const createdBy = currentData.created_by;
      if (createdBy) {
        try {
          let partyStartMs = null;
          const startPosix = currentData.start_time_posix ?? currentData.start_time_posix_seconds;
          if (startPosix != null && typeof startPosix === 'number') {
            partyStartMs = startPosix * 1000;
          } else if (currentData.start_date && currentData.start_date.toMillis) {
            partyStartMs = currentData.start_date.toMillis();
          }
          if (partyStartMs != null) {
            const userRef = db.collection('users').doc(createdBy);
            const userSnap = await userRef.get();
            if (userSnap.exists) {
              const planType = (userSnap.data()?.planType || 'free').toString().trim().toLowerCase();
              if (planType === 'free') {
                const startDate = new Date(partyStartMs);
                const anchorDay = getAnchorDayFromUserData(userSnap.data());
                const periodSlotKey = computePeriodSlotKey(startDate, anchorDay);
                await userRef.update({
                  usedPartySlots: admin.firestore.FieldValue.arrayUnion(periodSlotKey),
                });
                console.log(`[PARTY-STATUS-CHECK] Party ${doc.id}: usedPartySlots ergänzt (${periodSlotKey})`);
              }
            }
          }
        } catch (err) {
          console.warn(`[PARTY-STATUS-CHECK] usedPartySlots Update für ${doc.id} fehlgeschlagen:`, err);
        }
      }

      // Batch commit, wenn Limit erreicht
      if (batchOps >= BATCH_LIMIT) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
        console.log(`[PARTY-STATUS-CHECK] Batch committed (${updated}/${finishedParties.length}). Fortsetzung...`);
      }
    }
    
    // Finale Batch-Commit
    if (batchOps > 0) {
      await batch.commit();
    }
    
    console.log(`[PARTY-STATUS-CHECK] ✅ Fertig. ${updated} von ${finishedParties.length} Partys auf 'finished' gesetzt`);
    return null;
  } catch (err) {
    console.error('[PARTY-STATUS-CHECK] ❌ Fehler beim Party-Status-Check:', err);
    console.error('   Error Message:', err.message);
    console.error('   Error Stack:', err.stack);
    throw err;
  }
});

// ==========================================
// CALLABLE: Gesicherter Token-Automat für Apple Music/Shazam
// ==========================================
// - Nur für eingeloggte Nutzer (context.auth != null)
// - Private Key ausschließlich aus Secret Manager
// - Token-Gültigkeit exakt 30 Minuten (1800 Sekunden)
exports.getAppleMusicToken = functions.runWith({
  secrets: ['APPLE_PRIVATE_KEY', 'APPLE_KEY_ID', 'APPLE_TEAM_ID'],
}).https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }

  const privateKeyRaw = (process.env.APPLE_PRIVATE_KEY || '').trim();
  const keyId = (process.env.APPLE_KEY_ID || '').trim();
  const teamId = (process.env.APPLE_TEAM_ID || '').trim();

  if (!privateKeyRaw) {
    throw new functions.https.HttpsError('failed-precondition', 'APPLE_PRIVATE_KEY is not configured.');
  }
  if (!keyId || !teamId) {
    throw new functions.https.HttpsError('failed-precondition', 'APPLE_KEY_ID or APPLE_TEAM_ID is missing.');
  }

  try {
    const privateKey = privateKeyRaw.replace(/\\n/g, '\n');
    const result = buildAppleDeveloperToken(privateKey, keyId, teamId, 1800);
    return {
      token: result.token,
      issuedAt: result.issuedAt,
      expiresAt: result.expiresAt,
      expiresInSeconds: 1800,
    };
  } catch (err) {
    console.error('❌ getAppleMusicToken: token generation failed:', err);
    throw new functions.https.HttpsError('internal', 'Token generation failed.');
  }
});

// ==========================================
// CALLABLE: Admin setzt Passwort eines Nutzers (Firebase Auth)
// ==========================================
// Prüft users/{callerUid}.admin === true, dann admin.auth().updateUser(targetUid, { password })
// Aufruf aus der App nur mit eingeloggtem Admin; targetUid und newPassword werden übergeben.
exports.changeUserPassword = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Nur angemeldete Nutzer dürfen diese Funktion aufrufen.');
  }
  const callerUid = context.auth.uid;

  const userDoc = await db.collection('users').doc(callerUid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Nutzerdokument nicht gefunden.');
  }
  const userData = userDoc.data();
  const isAdmin = userData && userData.admin === true;
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Nur Admins dürfen Passwörter anderer Nutzer setzen.');
  }

  const { targetUid, newPassword } = data;
  if (!targetUid || typeof targetUid !== 'string' || targetUid.trim() === '') {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid ist erforderlich.');
  }
  if (!newPassword || typeof newPassword !== 'string' || newPassword.trim() === '') {
    throw new functions.https.HttpsError('invalid-argument', 'newPassword ist erforderlich.');
  }
  if (newPassword.length < 6) {
    throw new functions.https.HttpsError('invalid-argument', 'Passwort muss mindestens 6 Zeichen haben.');
  }

  try {
    await admin.auth().updateUser(targetUid.trim(), { password: newPassword });
    console.log('✅ Admin-Passwort-Änderung: Nutzer', targetUid, '– Passwort aktualisiert.');
    return { success: true };
  } catch (err) {
    console.error('❌ changeUserPassword Fehler:', err.message);
    throw new functions.https.HttpsError('internal', 'Ein interner Fehler ist aufgetreten.');
  }
});

// ==========================================
// CALLABLE (einmalig): Alle Auth-User mit E-Mail auf emailVerified=true setzen
// ==========================================
// Sicherheit: Nur context.auth.uid === Secret MASSVERIFY_ADMIN_UID (Firebase Auth UID).
// Vor Deploy Secret im Projekt anlegen und Version setzen (s. Etappe-A-Dokumentation / gcloud).
// Logs: Anzahl gesetzter Verifizierungen + gescannte User
exports.massVerifyExistingUsers = functions.runWith({
  secrets: ['MASSVERIFY_ADMIN_UID'],
}).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Nur angemeldete Nutzer dürfen diese Funktion aufrufen.',
    );
  }
  const allowedUid = (process.env.MASSVERIFY_ADMIN_UID || '').trim();
  if (!allowedUid) {
    console.error('[massVerify] MASSVERIFY_ADMIN_UID fehlt (Secret Manager).');
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Server: MASSVERIFY_ADMIN_UID ist nicht gesetzt. Secret und Deploy prüfen.',
    );
  }
  if (context.auth.uid !== allowedUid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Nur der konfigurierte Administrator darf diese Migration ausführen.',
    );
  }

  let nextPageToken;
  let verifiedCount = 0;
  let scannedCount = 0;
  let alreadyVerifiedOrNoEmail = 0;
  let errorCount = 0;

  try {
    do {
      const listResult = await admin.auth().listUsers(1000, nextPageToken);
      for (const userRecord of listResult.users) {
        scannedCount++;
        if (!userRecord.email) {
          alreadyVerifiedOrNoEmail++;
          continue;
        }
        if (userRecord.emailVerified === true) {
          alreadyVerifiedOrNoEmail++;
          continue;
        }
        try {
          await admin.auth().updateUser(userRecord.uid, { emailVerified: true });
          verifiedCount++;
          console.log(
            `[massVerify] OK uid=${userRecord.uid} email=${userRecord.email}`,
          );
        } catch (e) {
          errorCount++;
          console.error(
            `[massVerify] Fehler uid=${userRecord.uid}:`,
            e && e.message ? e.message : e,
          );
        }
      }
      nextPageToken = listResult.pageToken;
    } while (nextPageToken);

    console.log(
      `[massVerify] Fertig. emailVerified gesetzt: ${verifiedCount} | gescannt: ${scannedCount} | übersprungen (schon ok / keine E-Mail): ${alreadyVerifiedOrNoEmail} | Fehler: ${errorCount}`,
    );

    return {
      success: true,
      verifiedCount,
      scannedCount,
      skippedCount: alreadyVerifiedOrNoEmail,
      errorCount,
    };
  } catch (err) {
    console.error('[massVerify] Schwerer Fehler:', err);
    throw new functions.https.HttpsError(
      'internal',
      'Ein interner Fehler ist aufgetreten.',
    );
  }
});

// ==========================================
// REVENUECAT WEBHOOK
// ==========================================
// Empfängt Events von RevenueCat und synchronisiert den Pro-Status + Finanz-Logbuch
// URL: https://us-central1-<PROJECT-ID>.cloudfunctions.net/revenueCatWebhook
exports.revenueCatWebhook = functions.runWith({ secrets: [REVENUECAT_WEBHOOK_SECRET] }).https.onRequest(async (req, res) => {
  cors(req, res, async () => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    try {
      // RevenueCat sendet beim Speichern teils leere Test-Pings ohne Body.
      if (!req.body || Object.keys(req.body).length === 0) {
        res.status(200).send('VibesBox Webhook is alive');
        return;
      }

      const incomingSecret = getBearerToken(req);
      const expectedSecret = (REVENUECAT_WEBHOOK_SECRET.value() || '').trim();
      if (!incomingSecret || !expectedSecret || incomingSecret !== expectedSecret) {
        console.error('Sicherheits-Alarm: Falsches Secret.');
        res.status(403).json({ error: 'Forbidden' });
        return;
      }

      const event = req.body && req.body.event;

      if (!event) {
        console.warn('⚠️ RevenueCat Webhook: Kein Event-Objekt im Body gefunden.');
        res.status(400).json({ error: 'Missing event object' });
        return;
      }

    const {
      app_user_id,
      type,
      price,
      price_in_purchased_currency,
      currency,
      country_code,
      transaction_id,
      expiration_at_ms,
      purchased_at_ms
    } = event;

    // Wir erwarten die Firebase UID als app_user_id
    if (!app_user_id || typeof app_user_id !== 'string') {
      console.warn('⚠️ RevenueCat Webhook: Keine gültige app_user_id erhalten.');
      res.status(400).json({ error: 'Invalid app_user_id' });
      return;
    }

    console.log(`Webhook Event: ${type} für User ${app_user_id}`);

    // 1. Prüfen, ob User existiert
    const userRef = db.collection('users').doc(app_user_id);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      console.error(`❌ RevenueCat Webhook: User ${app_user_id} nicht in Firestore gefunden.`);
      // Wir antworten trotzdem mit 200, damit RevenueCat nicht retried (User könnte gelöscht sein)
      res.status(200).json({ message: 'User not found, processing skipped' });
      return;
    }

    const now = admin.firestore.Timestamp.now();

    // 2. Status-Update (proUntil)
    // Wir aktualisieren proUntil, wenn expiration_at_ms vorhanden ist.
    // Bei CANCELLATION oder EXPIRATION könnte das Datum in der Vergangenheit liegen, das ist okay.
    if (expiration_at_ms) {
      const expirationDate = admin.firestore.Timestamp.fromMillis(Number(expiration_at_ms));
      
      // Update User
      // Wir setzen isPro auf true, wenn das Datum in der Zukunft liegt
      const isPro = expirationDate.toMillis() > now.toMillis();
      
      await userRef.update({
        proUntil: expirationDate,
        isPro: isPro,
        lastPaymentProvider: 'RevenueCat', // Info-Feld
        updated_at: now
      });
      console.log(`✅ User ${app_user_id}: proUntil aktualisiert auf ${expirationDate.toDate().toISOString()} (isPro: ${isPro})`);
    }

    // 3. Logbuch-Eintrag & Finanz-Berechnung
    // Nur bei relevanten Events (Kauf, Erneuerung)
    // Wir ignorieren Events ohne Preis/Transaktion (z.B. Test-Events oder reine Status-Änderungen ohne Umsatz)
    const RELEVANT_TYPES = ['INITIAL_PURCHASE', 'RENEWAL', 'NON_RENEWING_PURCHASE', 'PRODUCT_CHANGE'];
    
    // Fix: Nutze price_in_purchased_currency statt price, da price falsche Steueraufschläge enthalten kann
    const amountGross = price_in_purchased_currency != null ? Number(price_in_purchased_currency) : (price != null ? Number(price) : 0);

    if (RELEVANT_TYPES.includes(type) && amountGross > 0) {
      // Berechnungs-Logik gemäß Anweisung:
      // amountGross = price_in_purchased_currency
      // vatAmount = amountGross - (amountGross / 1.19)
      // netPayout = (amountGross - vatAmount) * 0.85
      
      const vatRate = 0.19; // Pauschal 19% MwSt herausrechnen
      const netBeforeTax = amountGross / 1.19;
      const vatAmount = amountGross - netBeforeTax;
      
      const netPayout = (amountGross - vatAmount) * 0.85;

      // History-Eintrag erstellen
      // ID ist die transaction_id (Vermeidung von Duplikaten)
      const historyId = transaction_id || `${type}_${Date.now()}`;
      const historyRef = userRef.collection('history').doc(historyId);
      
      const historyData = {
        id: historyId,
        timestamp: purchased_at_ms ? admin.firestore.Timestamp.fromMillis(Number(purchased_at_ms)) : now,
        createdAt: now,
        type: type, // 'INITIAL_PURCHASE', 'RENEWAL', etc.
        source: 'REVENUECAT',
        transactionId: transaction_id || '',
        amountGross: amountGross,
        currency: currency || 'USD',
        countryCode: country_code || 'UNK',
        vatRate: vatRate,
        vatAmount: Number(vatAmount.toFixed(2)), // Auf 2 Dezimalstellen runden
        netPayout: Number(netPayout.toFixed(2)), // Auf 2 Dezimalstellen runden
        eventData: event // Optional: Das ganze Event zur Sicherheit speichern (oder weglassen um Platz zu sparen)
      };

      await historyRef.set(historyData, { merge: true });
      console.log(`✅ History-Eintrag erstellt: ${historyId} für User ${app_user_id}. Gross: ${amountGross}, NetPayout: ${netPayout.toFixed(2)}`);
    }

    // 4. Referral-Bonus-Check
    // Wenn der User geworben wurde, erhält der Werber 30 Tage Pro
    const userRefDoc = await userRef.get();
    const userData = userRefDoc.data();
    const referredByUid = userData ? userData.referredBy : null;

    if (referredByUid) {
      // Prüfe, ob für diesen User schon einmal ein Bonus vergeben wurde (optional, um Missbrauch zu vermeiden)
      // Wir prüfen einfach, ob es einen History-Eintrag vom Typ REFERRAL_BONUS mit description "Bonus for user [app_user_id]" gibt
      // Aber hier machen wir es einfach: Jeder Kauf löst Bonus aus (oder nur der erste? Anforderung sagt: "bei einem Kauf")
      // Wir machen es bei jedem Kauf/Verlängerung, um Anreize zu schaffen.
      
      if (RELEVANT_TYPES.includes(type)) {
        const referrerRef = db.collection('users').doc(referredByUid);
        const referrerDoc = await referrerRef.get();
        
        if (referrerDoc.exists) {
          const referrerData = referrerDoc.data();
          let currentProUntil = referrerData.proUntil ? referrerData.proUntil.toDate() : new Date();
          
          // Wenn Pro schon abgelaufen ist, starte ab jetzt
          if (currentProUntil < new Date()) {
            currentProUntil = new Date();
          }
          
          // Addiere 30 Tage
          const bonusDays = 30;
          const newProUntil = new Date(currentProUntil.getTime() + (bonusDays * 24 * 60 * 60 * 1000));
          
          await referrerRef.update({
            proUntil: admin.firestore.Timestamp.fromDate(newProUntil),
            isPro: true,
            updated_at: now
          });
          
          // History Eintrag für den Werber
          const bonusHistoryId = `referral_${app_user_id}_${Date.now()}`;
          await referrerRef.collection('history').doc(bonusHistoryId).set({
            id: bonusHistoryId,
            timestamp: now,
            createdAt: now,
            type: 'REFERRAL_BONUS',
            source: 'SYSTEM',
            amountGross: 0,
            currency: 'EUR',
            description: `Bonus für geworbenen User: ${app_user_id}`,
            bonusDays: bonusDays
          });
          
          console.log(`🎁 Referral Bonus: User ${referredByUid} erhielt 30 Tage Pro für Kauf von ${app_user_id}`);
        }
      }
    }

      res.status(200).json({ success: true });
    } catch (err) {
      console.error('❌ Fehler im RevenueCat Webhook:', err);
      sendInternalError(res);
    }
  });
});

// ==========================================
// CALLABLE: Auth-E-Mails (Verifizierung / Passwort) via EmailJS — Links von Firebase Admin
// ==========================================
const AUTH_EMAIL_CONTINUE_URL =
  'https://vibesbox.app/vb/verify.html?firebaseAuth=1';

/** Firebase Auth liefert Links auf *.firebaseapp.com; öffentliche Domain für E-Mail-CTA. */
const AUTH_EMAIL_ACTION_LINK_ORIGIN = 'https://www.vibesbox.app';

/** Firestore role_id für „Gast“ (muss mit App/AppConfig.guestRoleId übereinstimmen). */
const GUEST_ROLE_FIRESTORE_ID = 'pDdn6KeANmiMs7p9Oh8Z';

/**
 * Baut den in der Mail verwendeten Link: exakt
 * `https://www.vibesbox.app/verify?oobCode=…` — App (App Links) + PWA /verify; kein __/auth/action.
 */
function buildAppEmailVerificationLinkFromFirebaseLink(firebaseLink) {
  if (!firebaseLink || typeof firebaseLink !== 'string') return firebaseLink;
  try {
    const u = new URL(firebaseLink);
    const oobCode = u.searchParams.get('oobCode');
    if (!oobCode) {
      console.error(
        'buildAppEmailVerificationLinkFromFirebaseLink: oobCode fehlt:',
        firebaseLink.substring(0, 200),
      );
      return firebaseLink;
    }
    const out =
      'https://www.vibesbox.app/verify?oobCode=' +
      encodeURIComponent(oobCode);
    console.log('sendAuthEmail: App-Verifizierungslink (Vorschau):', out.substring(0, 120));
    return out;
  } catch (e) {
    console.warn('buildAppEmailVerificationLinkFromFirebaseLink:', e.message || e);
    return firebaseLink;
  }
}

/**
 * Ersetzt die Host-URL von Firebase-Default-Domains durch www.vibesbox.app,
 * behält Pfad + Query (z. B. /__/auth/action?mode=verifyEmail&…) bei.
 */
function rewriteFirebaseAuthHandlerLinkToPublicDomain(link) {
  if (!link || typeof link !== 'string') return link;
  let out = link;
  try {
    const u = new URL(link);
    const isFirebaseHost =
      u.hostname.endsWith('firebaseapp.com') || u.hostname.endsWith('.web.app');
    if (isFirebaseHost) {
      out = `${AUTH_EMAIL_ACTION_LINK_ORIGIN}${u.pathname}${u.search}${u.hash}`;
    }
  } catch (e) {
    console.warn('rewriteFirebaseAuthHandlerLinkToPublicDomain:', e.message || e);
    // Fallback: String-Ersetzung (seltene Host-Varianten)
    if (/firebaseapp\.com|\.web\.app/i.test(link)) {
      out = link.replace(
        /^https?:\/\/[^/]+/i,
        AUTH_EMAIL_ACTION_LINK_ORIGIN,
      );
    }
  }
  if (out !== link) {
    console.log(
      'sendAuthEmail: Verifizierungs-Link auf www.vibesbox.app umgeschrieben (Vorschau):',
      out.substring(0, 160),
    );
  } else if (/\/__\/auth\/action/i.test(link)) {
    console.log(
      'sendAuthEmail: Link ohne Umschreibung (Host evtl. schon custom):',
      link.substring(0, 120),
    );
  }
  return out;
}

function pickBcp47ForEmailJs(lang) {
  const m = {
    de: 'de-DE',
    en: 'en-GB',
    fr: 'fr-FR',
    ru: 'ru-RU',
    zh: 'zh-CN',
    es: 'es-ES',
    tr: 'tr-TR',
    pt: 'pt-BR',
  };
  return m[lang] || 'de-DE';
}

/** Datum/Uhrzeit für E-Mail-Footer; sprachabhängig + Suffix (z. B. „ Uhr“ für DE). */
function formatEmailJsDateTime(now, lang, t) {
  const bcp = pickBcp47ForEmailJs(lang);
  const s = new Intl.DateTimeFormat(bcp, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(now);
  const suffix =
    t && typeof t.auth_email_datetime_suffix === 'string'
      ? t.auth_email_datetime_suffix
      : '';
  return `${s}${suffix}`;
}

function resolveAuthEmailRegistrationRoleLabel(registrationRoleId, t) {
  const raw =
    registrationRoleId != null ? String(registrationRoleId).trim() : '';
  const lower = raw.toLowerCase();
  // App sendet oft Anzeigenamen („Gast“/„DJ“); Gast-role_id aus Firestore ebenfalls.
  if (raw === GUEST_ROLE_FIRESTORE_ID) return t.role_guest_access;
  if (lower === 'gast' || lower === 'guest') return t.role_guest_access;
  if (raw.length > 0) return t.registration_role_dj;
  return t.auth_role;
}

async function assertAuthEmailRateLimit(docId, max) {
  const ref = db.collection('auth_email_rate_limits').doc(docId);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const prev = snap.exists ? (snap.data().count || 0) : 0;
    if (prev >= max) {
      throw new HttpsError(
        'resource-exhausted',
        'Zu viele Anfragen. Bitte später erneut versuchen.',
      );
    }
    transaction.set(
      ref,
      {
        count: prev + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

/**
 * Kontakt-Empfänger (E-Mail + Party-Metadaten) nur serverseitig — ersetzt Client-Lesezugriff auf users.
 * Auth: Firebase-User ODER appSecurityKey (wie Kontaktformular-Gast).
 */
exports.resolveContactRecipient = onCall(
  { region: 'us-central1', timeoutSeconds: 30 },
  async (request) => {
    const data = request.data || {};
    const uid = request.auth?.uid || null;
    const key = typeof data.appSecurityKey === 'string' ? data.appSecurityKey.trim() : '';
    if (!uid && key !== CONTACT_APP_GUEST_SECURITY_KEY.value()) {
      throw new HttpsError(
        'permission-denied',
        'Nur für eingeloggte Nutzer oder die App (Sicherheitsschlüssel) erlaubt.',
      );
    }

    const hour = Math.floor(Date.now() / 3600000);
    const rateSalt = uid
      ? `u_${uid}`
      : crypto
          .createHash('sha256')
          .update(`${data.partyId || ''}|${data.partyCode || ''}|${key}`)
          .digest('hex')
          .slice(0, 32);
    await assertAuthEmailRateLimit(`resolve_contact_${rateSalt}_${hour}`, 80);

    const partyId = typeof data.partyId === 'string' ? data.partyId.trim() : '';
    const partyCode = typeof data.partyCode === 'string' ? data.partyCode.trim() : '';

    if (
      (!partyId || partyId === 'manual') &&
      (!partyCode || partyCode === 'manual')
    ) {
      return {
        success: true,
        toEmail: ADMIN_CONTACT_FALLBACK_EMAIL,
        partyId: null,
        partyCode: null,
        partyName: null,
        djUserId: null,
      };
    }

    const r = await resolveContactRecipientDetails({ partyId, partyCode });
    return { success: true, ...r };
  },
);

/**
 * Auth-E-Mails (Callable sendAuthEmail): `message` unverändert an EmailJS — bei Verifizierung vollständiges HTML
 * aus der App (Button, Fallback-Link, l10n inkl. confirm_email_button). Kein Anführungszeichen-Wrapping.
 * Kontakt/Support nutzt stattdessen wrapContactUserMessageForEmailJs.
 */
async function sendAuthEmailViaEmailJS({
  toEmail,
  userName,
  subject,
  message,
  locale,
  registrationRoleId,
  introStyle,
}) {
  console.log('Versuche E-Mail zu senden via EmailJS/SMTP...');
  const {
    serviceId: emailJSServiceId,
    templateId: emailJSTemplateId,
    publicKey: emailJSPublicKey,
  } = getEmailJsPublicIds();
  if (!emailJSServiceId || !emailJSTemplateId || !emailJSPublicKey) {
    throw new HttpsError(
      'failed-precondition',
      'EmailJS-Konfiguration unvollständig (Env EMAILJS_* oder functions:config emailjs.*).',
    );
  }
  const rawKey = EMAILJS_PRIVATE_KEY.value();
  const cleanKey = rawKey ? rawKey.replace(/[\r\n\t]/g, '').trim() : '';
  if (!cleanKey) {
    throw new HttpsError('failed-precondition', 'E-Mail-Versand nicht konfiguriert.');
  }
  const lang = normalizeEmailJsLocale(locale);
  const translations = getEmailJsContactTranslations();
  const t = translations[lang] || translations.de;
  const now = new Date();
  const dateFormatted = formatEmailJsDateTime(now, lang, t);
  const mailSubject = subject;
  const introText =
    introStyle === 'registration'
      ? t.registration_header
      : t.auth_mail_intro;
  const roleLabel = resolveAuthEmailRegistrationRoleLabel(registrationRoleId, t);
  const templateParams = {
    to_email: toEmail,
    user_name: userName ? userName.trim() : 'Unbekannt',
    user_email: toEmail,
    phone_info: '—',
    mail_subject: mailSubject,
    message: message, // Auth: HTML (Verifizierung) oder Plaintext (Passwort) — niemals wie Kontakt quoten
    role: roleLabel,
    party_info: '',
    created_at: dateFormatted,
    app_name: t.app_name,
    mail_contact_header: t.auth_mail_header,
    mail_contact_subject_line: mailSubject,
    mail_contact_intro_text: introText,
    label_message: t.label_message,
    label_sender: t.label_sender,
    label_phone: t.label_phone,
    label_role: t.label_role,
    label_party: '',
    label_date: t.label_date,
    label_reply_button: t.label_reply_button,
    mail_footer_automated: t.mail_footer_automated,
    no_email_provided: t.no_email_provided,
    user_email_display: toEmail,
    /** Auth: Party-Zeile aus; Verifizierung: Template `{{{message}}}` für HTML */
    show_party_row: '0',
  };
  if (!templateParams.to_email || templateParams.to_email.trim() === '') {
    templateParams.to_email = toEmail;
  }
  const emailData = {
    service_id: emailJSServiceId,
    template_id: emailJSTemplateId,
    user_id: emailJSPublicKey,
    accessToken: cleanKey,
    template_params: templateParams,
  };
  let emailResponse;
  try {
    emailResponse = await axios.post(
      'https://api.emailjs.com/api/v1.0/email/send',
      emailData,
      {
        headers: { 'Content-Type': 'application/json' },
        timeout: 20000,
      },
    );
  } catch (err) {
    const status = err.response?.status;
    const body =
      typeof err.response?.data === 'string'
        ? err.response.data
        : err.response?.data != null
          ? JSON.stringify(err.response.data)
          : '';
    console.error('EmailJS sendAuthEmail axios error', status, body || err.message);
    const hint =
      status === 400
        ? 'EmailJS hat die Anfrage abgelehnt (IDs, Template oder Key prüfen).'
        : 'E-Mail-Versand fehlgeschlagen (Netzwerk oder EmailJS). Bitte später erneut versuchen.';
    throw new HttpsError('internal', hint);
  }
  if (emailResponse.status !== 200) {
    console.log('Mail-Versand Status:', false);
    throw new HttpsError('internal', 'E-Mail konnte nicht gesendet werden.');
  }
  console.log('Mail-Versand Status:', true);
}

exports.sendAuthEmail = onCall(
  {
    region: 'us-central1',
    enforceAppCheck: true,
    secrets: [EMAILJS_PRIVATE_KEY, RECAPTCHA_ENTERPRISE_API_KEY],
    timeoutSeconds: 60,
  },
  async (request) => {
    console.log('--- START REGISTRATION FUNCTION ---');
    const data = request.data || {};
    const recaptchaTok =
      typeof data.recaptchaToken === 'string' ? data.recaptchaToken.trim() : '';
    const apiKey = RECAPTCHA_ENTERPRISE_API_KEY.value();
    if (!apiKey) {
      console.error('sendAuthEmail: RECAPTCHA_ENTERPRISE_API_KEY fehlt');
      throw new HttpsError(
        'failed-precondition',
        'Server-Konfiguration unvollständig (reCAPTCHA Enterprise).',
      );
    }
    if (!recaptchaTok) {
      throw new HttpsError('invalid-argument', 'reCAPTCHA-Token erforderlich.');
    }
    const vr = await verifyRecaptchaEnterpriseAssessment(
      recaptchaTok,
      RECAPTCHA_CONTACT_ACTION,
      apiKey,
      null,
    );
    if (!vr.ok) {
      console.warn('sendAuthEmail: reCAPTCHA fehlgeschlagen:', vr.error);
      throw new HttpsError(
        'invalid-argument',
        vr.error === 'low_score'
          ? 'reCAPTCHA-Score zu niedrig.'
          : 'reCAPTCHA-Validierung fehlgeschlagen.',
      );
    }
    console.log('sendAuthEmail: reCAPTCHA OK, Score:', vr.score);
    console.log(
      'Empfangene Daten:',
      JSON.stringify({
        type: data.type,
        email: typeof data.email === 'string' ? data.email : null,
        role: data.role != null ? data.role : null,
        userName: typeof data.userName === 'string' ? data.userName : null,
        locale: typeof data.locale === 'string' ? data.locale : null,
        hasIdToken: typeof data.idToken === 'string' && data.idToken.length > 0,
      }),
    );
    const type = data.type;
    const subject =
      typeof data.subject === 'string' ? data.subject.trim() : '';
    const bodyTemplate =
      typeof data.bodyTemplate === 'string' ? data.bodyTemplate : '';
    let userName =
      typeof data.userName === 'string' ? data.userName.trim() : '';
    const locale =
      typeof data.locale === 'string' && data.locale.trim().length > 0
        ? data.locale.trim()
        : 'de';

    if (subject.length === 0 || subject.length > 300) {
      throw new HttpsError('invalid-argument', 'Ungültiger Betreff.');
    }
    if (
      bodyTemplate.length === 0 ||
      bodyTemplate.length > 16000 ||
      !bodyTemplate.includes('{link}')
    ) {
      throw new HttpsError(
        'invalid-argument',
        'Text muss den Platzhalter {link} enthalten.',
      );
    }

    const actionCodeSettings = {
      url: AUTH_EMAIL_CONTINUE_URL,
      handleCodeInApp: false,
    };

    const hour = Math.floor(Date.now() / 3600000);

    if (type === 'verification') {
      const idToken = data.idToken;
      if (!idToken || typeof idToken !== 'string') {
        throw new HttpsError('unauthenticated', 'idToken fehlt.');
      }
      let decoded;
      try {
        decoded = await admin.auth().verifyIdToken(idToken);
      } catch (e) {
        console.error('sendAuthEmail verifyIdToken:', e.message || e);
        throw new HttpsError('unauthenticated', 'Ungültiges Token.');
      }
      const email = decoded.email;
      console.log(
        'Nach idToken (ohne Passwort):',
        JSON.stringify({ email, uid: decoded.uid, role: data.role != null ? data.role : null }),
      );
      if (!email) {
        throw new HttpsError('failed-precondition', 'Keine E-Mail im Konto.');
      }
      const uid = decoded.uid;
      await assertAuthEmailRateLimit(`verify_${uid}_${hour}`, 8);

      let link = await admin.auth().generateEmailVerificationLink(
        email,
        actionCodeSettings,
      );
      link = buildAppEmailVerificationLinkFromFirebaseLink(link);
      const displayName =
        userName || email.split('@')[0];
      const body = bodyTemplate
        .replace(/\{userName\}/g, displayName)
        .replace(/\{link\}/g, link);
      const registrationRoleId =
        data.role != null ? String(data.role).trim() : '';
      await sendAuthEmailViaEmailJS({
        toEmail: email,
        userName: displayName,
        subject,
        message: body,
        locale,
        registrationRoleId,
        introStyle: 'registration',
      });
      return { success: true };
    }

    if (type === 'passwordReset') {
      const emailRaw = data.email;
      if (!emailRaw || typeof emailRaw !== 'string' || emailRaw.trim() === '') {
        throw new HttpsError('invalid-argument', 'E-Mail fehlt.');
      }
      const email = emailRaw.trim().toLowerCase();
      const emailHash = crypto
        .createHash('sha256')
        .update(email)
        .digest('hex')
        .slice(0, 40);
      await assertAuthEmailRateLimit(`pwd_${emailHash}_${hour}`, 6);

      let userRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email);
      } catch (e) {
        if (e.code === 'auth/user-not-found') {
          return { success: true, sent: false };
        }
        throw e;
      }
      if (!userName) {
        userName =
          (userRecord.displayName && userRecord.displayName.trim()) ||
          email.split('@')[0];
      }
      let link = await admin.auth().generatePasswordResetLink(
        email,
        actionCodeSettings,
      );
      link = rewriteFirebaseAuthHandlerLinkToPublicDomain(link);
      const body = bodyTemplate
        .replace(/\{userName\}/g, userName)
        .replace(/\{link\}/g, link);
      await sendAuthEmailViaEmailJS({
        toEmail: email,
        userName,
        subject,
        message: body,
        locale,
        registrationRoleId: '',
        introStyle: 'account_action',
      });
      return { success: true, sent: true };
    }

    throw new HttpsError('invalid-argument', 'Unbekannter Typ.');
  },
);

/**
 * Geräte-Sperr-Fusion: Nach Login prüft die App blocked_devices/{deviceClientId}.
 * Liegt eine aktive Sperre vor, wird users/{uid} serverseitig dauerhaft gesperrt
 * und ein Audit-Eintrag für den DJ geschrieben.
 */
function isBlockedDeviceEntryActive(data) {
  if (!data || typeof data !== 'object') return false;
  const blockStatus = String(data.block_status || '')
    .trim()
    .toLowerCase();
  if (
    blockStatus === 'party_specific' ||
    blockStatus === 'permanent' ||
    blockStatus === 'active' ||
    blockStatus === 'blocked'
  ) {
    return true;
  }
  if (blockStatus === 'temporary' && data.blocked_until) {
    const u = data.blocked_until;
    if (u && typeof u.toMillis === 'function') {
      return Date.now() < u.toMillis();
    }
  }
  if (!blockStatus) {
    return true;
  }
  return false;
}

exports.applyDeviceBlockFusion = onCall(
  { region: 'us-central1', timeoutSeconds: 30 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Anmeldung erforderlich.');
    }
    const body = request.data || {};
    const deviceClientId =
      typeof body.deviceClientId === 'string'
        ? body.deviceClientId.trim()
        : '';
    if (
      !deviceClientId ||
      !/^(fp_|app_)[A-Za-z0-9_-]{6,220}$/.test(deviceClientId)
    ) {
      throw new HttpsError(
        'invalid-argument',
        'deviceClientId fehlt oder ungültig.',
      );
    }

    const blockedRef = db.collection('blocked_devices').doc(deviceClientId);
    const blockedSnap = await blockedRef.get();
    if (!blockedSnap.exists) {
      return { fused: false, reason: 'no_device_block_doc' };
    }
    const bData = blockedSnap.data() || {};
    if (!isBlockedDeviceEntryActive(bData)) {
      return { fused: false, reason: 'device_not_active' };
    }

    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    const uData = userSnap.exists ? userSnap.data() || {} : {};
    if (uData.is_blocked === true) {
      return { fused: false, reason: 'user_already_blocked' };
    }

    const st = String(uData.status || '')
      .trim()
      .toLowerCase();
    if (st === 'gesperrt' || st === 'blocked') {
      return { fused: false, reason: 'user_already_blocked_status' };
    }

    const displayNameRaw =
      uData.displayName ||
      uData.realName ||
      (request.auth.token && request.auth.token.email) ||
      'Unbekannt';
    const displayName = String(displayNameRaw).trim().slice(0, 120);

    const djId =
      typeof bData.dj_id === 'string' ? bData.dj_id.trim() : '';

    await userRef.set(
      {
        is_blocked: true,
        status: 'gesperrt',
        device_block_fusion: true,
        device_block_fusion_at: admin.firestore.FieldValue.serverTimestamp(),
        device_block_fusion_device_id: deviceClientId,
      },
      { merge: true },
    );

    const logRef = db.collection('block_device_fusion_log').doc();
    await logRef.set({
      dj_id: djId || null,
      linked_uid: uid,
      device_client_id: deviceClientId,
      display_name: displayName,
      message_de: `Gesperrtes Gerät wurde mit Account ${displayName.slice(0, 80)} verknüpft und ebenfalls gesperrt.`,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      party_id:
        typeof bData.party_id === 'string' ? bData.party_id : null,
    });

    return { fused: true };
  },
);

