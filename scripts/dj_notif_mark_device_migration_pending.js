#!/usr/bin/env node
/**
 * Einmal-Migration: setzt für alle DJ-User `dj_notif_awaiting_first_device_seed: true`.
 * Beim **ersten** App-Start nach App-Update kopiert die App die bisherigen Root-Felder
 * (`notifyNewWishes`, `enableNotificationSound`, `show_status_notification`) nach
 * `users/{uid}/dj_device_prefs/{installId}` und setzt das Flag auf false.
 * Weitere Geräte ohne Flag erhalten beim ersten Start ein **Default**-Geräte-Dokument.
 *
 * Ausführung (Admin / Service Account mit Firestore-Rechten):
 *
 *   cd functions && node ../scripts/dj_notif_mark_device_migration_pending.js
 *
 * Voraussetzung: `firebase-admin` ist in `functions/node_modules` installiert
 * (`npm install` im Ordner `functions`). Auth z. B. via
 * `export GOOGLE_APPLICATION_CREDENTIALS=/pfad/zu/serviceAccount.json`
 * oder `gcloud auth application-default login`.
 *
 * Projekt-ID: automatisch aus `.firebaserc` (default) im Repo-Root, sonst eine von
 * `GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`, `FIREBASE_PROJECT_ID`, `GCP_PROJECT`.
 */

const fs = require('fs');
const path = require('path');
const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));

function resolveProjectId() {
  const fromEnv =
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT_ID ||
    process.env.GCP_PROJECT;
  if (fromEnv && String(fromEnv).trim()) {
    return String(fromEnv).trim();
  }
  try {
    const rcPath = path.join(__dirname, '../.firebaserc');
    const rc = JSON.parse(fs.readFileSync(rcPath, 'utf8'));
    const def = rc.projects && rc.projects.default;
    if (def && String(def).trim()) {
      return String(def).trim();
    }
  } catch (_) {
    /* .firebaserc fehlt oder ungültig */
  }
  return null;
}

const projectId = resolveProjectId();
if (!projectId) {
  // eslint-disable-next-line no-console
  console.error(
    'Keine Firebase-Projekt-ID: lege .firebaserc mit "projects.default" an ' +
      'oder setze z. B. export GOOGLE_CLOUD_PROJECT=dj-ollerganove',
  );
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();
const FIELD = 'dj_notif_awaiting_first_device_seed';

function isDjLike(data) {
  if (!data || typeof data !== 'object') return false;
  const role = String(data.role || '').trim().toLowerCase();
  if (role === 'dj') return true;
  if (data.notifyNewWishes !== undefined && data.notifyNewWishes !== null) {
    return true;
  }
  if (data.show_status_notification !== undefined && data.show_status_notification !== null) {
    return true;
  }
  return false;
}

async function main() {
  const pageSize = 400;
  let lastId = null;
  let scanned = 0;
  let updated = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    let q = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastId) {
      q = q.startAfter(lastId);
    }
    const snap = await q.get();
    if (snap.empty) break;
    const batch = db.batch();
    let batchUpdates = 0;
    for (const doc of snap.docs) {
      scanned += 1;
      const d = doc.data();
      if (!isDjLike(d)) continue;
      if (d[FIELD] === true) continue;
      batch.update(doc.ref, {[FIELD]: true});
      batchUpdates += 1;
      updated += 1;
    }
    if (batchUpdates > 0) {
      await batch.commit();
    }
    lastId = snap.docs[snap.docs.length - 1].id;
    if (snap.size < pageSize) break;
  }
  // eslint-disable-next-line no-console
  console.log(`Fertig. User-Dokumente gescannt: ${scanned}, mit ${FIELD}=true gesetzt: ${updated}`);
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});
