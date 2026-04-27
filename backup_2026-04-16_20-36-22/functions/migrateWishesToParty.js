const admin = require('firebase-admin');

// Initialisiere Firebase Admin
// Versuche zuerst Application Default Credentials zu verwenden
let app;
try {
  app = admin.app();
} catch (e) {
  // App existiert noch nicht, initialisiere sie
  admin.initializeApp({
    projectId: 'dj-ollerganove',
  });
  app = admin.app();
}

const db = admin.firestore();

async function migrateWishesToParty() {
  try {
    console.log('Starte Migration: Setze alle bestehenden Wünsche auf "manuell"...');
    
    // Hole alle Wünsche
    const wishesSnapshot = await db.collection('wishes').get();
    
    console.log(`Gefundene Wünsche: ${wishesSnapshot.size}`);
    
    let updated = 0;
    let errors = 0;
    
    // Batch-Update für alle Wünsche
    const batch = db.batch();
    let batchCount = 0;
    const BATCH_SIZE = 500; // Firestore Batch-Limit
    
    for (const doc of wishesSnapshot.docs) {
      try {
        // Prüfe, ob party_id bereits existiert
        const data = doc.data();
        if (!data.party_id) {
          // Setze party_id auf "manuell" für alle bestehenden Wünsche
          batch.update(doc.ref, {
            party_id: 'manuell',
            party_type: 'manuell', // Zusätzliches Feld für Klarheit
          });
          batchCount++;
          updated++;
          
          // Firestore erlaubt max 500 Operationen pro Batch
          if (batchCount >= BATCH_SIZE) {
            await batch.commit();
            console.log(`Batch mit ${batchCount} Updates committed`);
            batchCount = 0;
          }
        } else {
          console.log(`Wunsch ${doc.id} hat bereits party_id: ${data.party_id}`);
        }
      } catch (error) {
        console.error(`Fehler beim Update von Wunsch ${doc.id}:`, error);
        errors++;
      }
    }
    
    // Commit verbleibender Updates
    if (batchCount > 0) {
      await batch.commit();
      console.log(`Letzter Batch mit ${batchCount} Updates committed`);
    }
    
    console.log('\n=== Migration abgeschlossen ===');
    console.log(`Erfolgreich aktualisiert: ${updated}`);
    console.log(`Fehler: ${errors}`);
    console.log(`Gesamt: ${wishesSnapshot.size}`);
    
    process.exit(0);
  } catch (error) {
    console.error('Fehler bei der Migration:', error);
    process.exit(1);
  }
}

// Führe Migration aus
migrateWishesToParty();












































