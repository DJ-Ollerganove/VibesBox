const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Firebase Admin initialisieren (nur einmal)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const MANUAL_PARTY_ID = 'manual';

// Setzt alle offenen Wünsche (pending) einer beendeten Party auf "not_played"
exports.closePendingWishesForEndedParties = functions.pubsub
  .schedule('every 1 hours') // stündlich
  .timeZone('Europe/Berlin')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    let updated = 0;

    try {
      // Finde beendete Partys
      const endedPartiesSnap = await db
        .collection('parties')
        .where('end_date', '<', now)
        .get();

      if (endedPartiesSnap.empty) {
        console.log('Keine beendeten Partys gefunden.');
        return null;
      }

      console.log(`Beendete Partys: ${endedPartiesSnap.size}`);

      // Für jede beendete Party: pending-Wünsche auf not_played setzen
      const BATCH_LIMIT = 450; // etwas Puffer unter 500
      let batch = db.batch();
      let ops = 0;

      for (const partyDoc of endedPartiesSnap.docs) {
        const partyId = partyDoc.id;

        // Manuelle Wunschbox nicht anfassen
        if (partyId === MANUAL_PARTY_ID) {
          continue;
        }

        const wishesSnap = await db
          .collection('wishes')
          .where('status', '==', 'pending')
          .where('party_id', '==', partyId)
          .get();

        if (wishesSnap.empty) {
          continue;
        }

        console.log(
          `  Party ${partyId} -> offene Wünsche: ${wishesSnap.size}`
        );

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
      }

      if (ops > 0) {
        await batch.commit();
      }

      console.log(
        `Fertig. Aktualisierte Wünsche: ${updated} (Status -> not_played)`
      );
      return null;
    } catch (err) {
      console.error('Fehler beim Aktualisieren der Wünsche:', err);
      throw err;
    }
  });


