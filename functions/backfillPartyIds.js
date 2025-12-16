const admin = require('firebase-admin');

// Initialisiere Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'dj-ollerganove',
  });
}

const db = admin.firestore();

async function backfillPartyIds() {
  try {
    console.log('🔄 Starte Backfill: Setze party_id für alte Wünsche ohne Kennung...');
    
    // Hole alle Wünsche ohne party_id
    const wishesSnapshot = await db
      .collection('wishes')
      .where('party_id', '==', null)
      .get();
    
    // Falls die Query nicht funktioniert (weil party_id nicht existiert), hole alle Wünsche
    let allWishes;
    if (wishesSnapshot.empty) {
      console.log('⚠️  Query mit null-Filter ergab keine Ergebnisse, lade alle Wünsche...');
      allWishes = await db.collection('wishes').get();
    } else {
      allWishes = wishesSnapshot;
    }
    
    console.log(`📊 Gefundene Wünsche: ${allWishes.size}`);
    
    const BATCH_SIZE = 450;
    let batch = db.batch();
    let batchCount = 0;
    let updated = 0;
    let skipped = 0;
    
    for (const doc of allWishes.docs) {
      const data = doc.data();
      
      // Überspringe Wünsche, die bereits eine party_id haben
      if (data.party_id) {
        skipped++;
        continue;
      }
      
      // Setze party_id auf 'manual' für alle alten Wünsche ohne Kennung
      batch.update(doc.ref, {
        party_id: 'manual',
        party_code: 'manual',
        backfilled_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      batchCount++;
      updated++;
      
      // Commit Batch wenn Limit erreicht
      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        console.log(`✅ Batch mit ${batchCount} Updates committed`);
        batch = db.batch();
        batchCount = 0;
      }
    }
    
    // Commit verbleibender Updates
    if (batchCount > 0) {
      await batch.commit();
      console.log(`✅ Letzter Batch mit ${batchCount} Updates committed`);
    }
    
    console.log('\n=== Backfill abgeschlossen ===');
    console.log(`✅ Aktualisiert: ${updated} Wünsche`);
    console.log(`⏭️  Übersprungen (hatten bereits party_id): ${skipped}`);
    console.log(`📊 Gesamt: ${allWishes.size}`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Fehler beim Backfill:', error);
    process.exit(1);
  }
}

// Führe Backfill aus
backfillPartyIds();

