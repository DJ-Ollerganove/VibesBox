const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Firebase Admin initialisieren (nur einmal)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const MANUAL_PARTY_ID = 'manual';

// Setzt alle offenen Wünsche (pending) einer beendeten Party auf "not_played"
// Wird aufgerufen, wenn die Statistik für eine beendete Party angezeigt wird
exports.closePendingWishesForEndedParty = functions.https.onRequest(async (req, res) => {
  const now = admin.firestore.Timestamp.now();
  let updated = 0;

  try {
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
    res.status(500).json({ error: err.message });
  }
});


