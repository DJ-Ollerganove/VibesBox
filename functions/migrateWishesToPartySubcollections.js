/**
 * Einmalige Migration: wishes/{id} → parties/{party_id}/wishes/{id}
 * Kopiert alle Felder 1:1, verifiziert Zählung, löscht Root-wishes optional.
 *
 * Voraussetzung:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/pfad/serviceAccount.json
 *   export GOOGLE_CLOUD_PROJECT=dj-ollerganove
 *
 * Dry-run (nur zählen, nichts schreiben):
 *   node functions/migrateWishesToPartySubcollections.js --dry-run
 *
 * Kopieren:
 *   node functions/migrateWishesToPartySubcollections.js
 *
 * Kopieren + Root-Collection leeren:
 *   node functions/migrateWishesToPartySubcollections.js --delete-source
 */
const admin = require('firebase-admin');

try {
  admin.app();
} catch (e) {
  admin.initializeApp({ projectId: process.env.GOOGLE_CLOUD_PROJECT || 'dj-ollerganove' });
}

const db = admin.firestore();
const BATCH_SIZE = 400;
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const DELETE_SOURCE = args.includes('--delete-source');

function normalizePartyId(raw) {
  if (raw == null) return '';
  const s = String(raw).trim();
  if (!s || s === 'manual' || s === 'manuell') return '';
  return s;
}

async function partyExists(partyId) {
  const snap = await db.collection('parties').doc(partyId).get();
  return snap.exists;
}

async function main() {
  console.log('=== Migration wishes → parties/{partyId}/wishes ===');
  console.log('Dry-run:', DRY_RUN);
  console.log('Delete source after copy:', DELETE_SOURCE);

  const sourceSnap = await db.collection('wishes').get();
  const totalSource = sourceSnap.size;
  console.log('Root wishes gefunden:', totalSource);

  const skipped = [];
  const byParty = new Map();
  for (const doc of sourceSnap.docs) {
    const data = doc.data();
    const partyId = normalizePartyId(data.party_id || data.partyId);
    if (!partyId) {
      skipped.push({ id: doc.id, reason: 'missing_party_id' });
      continue;
    }
    if (!(await partyExists(partyId))) {
      skipped.push({ id: doc.id, reason: 'party_not_found', partyId });
      continue;
    }
    if (!byParty.has(partyId)) byParty.set(partyId, []);
    byParty.get(partyId).push({ id: doc.id, data });
  }

  let copied = 0;
  for (const [partyId, items] of byParty.entries()) {
    console.log(`Party ${partyId}: ${items.length} Wünsche`);
    if (DRY_RUN) {
      copied += items.length;
      continue;
    }
    let batch = db.batch();
    let ops = 0;
    for (const item of items) {
      const destRef = db.collection('parties').doc(partyId).collection('wishes').doc(item.id);
      batch.set(destRef, item.data, { merge: false });
      ops++;
      copied++;
      if (ops >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  let destCount = 0;
  if (!DRY_RUN) {
    const cg = await db.collectionGroup('wishes').get();
    destCount = cg.size;
  }

  console.log('\n=== Ergebnis ===');
  console.log('Quelle (root):', totalSource);
  console.log('Kopiert:', copied);
  console.log('Übersprungen:', skipped.length);
  if (skipped.length > 0) {
    console.log('Beispiele übersprungen:', skipped.slice(0, 10));
  }
  if (!DRY_RUN) {
    console.log('Ziel (collectionGroup wishes):', destCount);
    if (destCount < copied) {
      console.error('WARNUNG: Ziel-Zähler kleiner als kopiert — prüfen!');
      process.exit(1);
    }
  }

  if (DELETE_SOURCE && !DRY_RUN) {
    console.log('\nLösche Root-Collection wishes …');
    let deleted = 0;
    while (true) {
      const page = await db.collection('wishes').limit(BATCH_SIZE).get();
      if (page.empty) break;
      const batch = db.batch();
      for (const d of page.docs) batch.delete(d.ref);
      await batch.commit();
      deleted += page.size;
      console.log('  gelöscht:', deleted);
    }
    const remain = await db.collection('wishes').get();
    console.log('Verbleibend in root wishes:', remain.size);
    if (remain.size > 0) process.exit(1);
  }

  console.log('\nFertig.');
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
