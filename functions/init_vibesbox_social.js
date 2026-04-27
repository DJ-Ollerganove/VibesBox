/**
 * Einmaliges Initialisierungs-Script: Erstellt das zentrale Social-Media-Dokument
 * für VibesBox unter admin_config/vibesbox_social.
 *
 * Ausführung:
 *   Option A (mit Service Account Key im Projektroot):
 *     node functions/init_vibesbox_social.js   (aus Projektroot)
 *   Option B (Key in functions/):
 *     cd functions && node init_vibesbox_social.js
 *   Option C: GOOGLE_APPLICATION_CREDENTIALS setzen oder gcloud auth application-default login
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function initAdmin() {
  if (admin.apps.length > 0) return;

  const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'dj-ollerganove';

  // 1) Expliziter Service-Account-Key (Projektroot oder functions/; auch .json.json)
  const keyPaths = [
    path.join(__dirname, '..', 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json.json'),
    path.join(__dirname, 'serviceAccountKey.json'),
    path.join(__dirname, 'serviceAccountKey.json.json'),
  ];
  for (const keyPath of keyPaths) {
    if (fs.existsSync(keyPath)) {
      const serviceAccount = require(keyPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id || projectId,
      });
      return;
    }
  }

  // 2) Standard (GOOGLE_APPLICATION_CREDENTIALS / gcloud)
  admin.initializeApp({ projectId });
}

initAdmin();

const db = admin.firestore();

const data = {
  platforms: [
    { id: 'facebook', url: 'https://www.facebook.com/vibesbox.official' },
    { id: 'instagram', url: 'https://www.instagram.com/vibesbox.official' },
  ],
};

async function run() {
  try {
    await db.collection('admin_config').doc('vibesbox_social').set(data);
    console.log('Erfolg: admin_config/vibesbox_social wurde in Firestore angelegt.');
    process.exit(0);
  } catch (e) {
    console.error('Fehler:', e);
    process.exit(1);
  }
}

run();
