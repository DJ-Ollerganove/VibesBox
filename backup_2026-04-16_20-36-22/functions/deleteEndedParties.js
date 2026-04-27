const admin = require('firebase-admin');

// Initialisiere Firebase Admin (falls noch nicht initialisiert)
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'dj-ollerganove', // Firebase Projekt-ID
  });
}

const db = admin.firestore();

async function deleteEndedParties() {
  try {
    console.log('🔍 Suche nach beendeten Partys...');
    
    const now = admin.firestore.Timestamp.now();
    const partiesRef = db.collection('parties');
    
    // Lade alle Partys
    const snapshot = await partiesRef.get();
    
    if (snapshot.empty) {
      console.log('✅ Keine Partys in der Datenbank gefunden.');
      return;
    }
    
    console.log(`📊 Gefundene Partys insgesamt: ${snapshot.size}`);
    
    const endedParties = [];
    const batch = db.batch();
    let deleteCount = 0;
    
    snapshot.forEach((doc) => {
      const data = doc.data();
      const endDate = data.end_date;
      
      if (endDate && endDate.toMillis() < now.toMillis()) {
        endedParties.push({
          id: doc.id,
          name: data.party_name || 'Unbenannte Party',
          endDate: endDate.toDate().toLocaleString('de-DE'),
        });
        batch.delete(doc.ref);
        deleteCount++;
      }
    });
    
    if (endedParties.length === 0) {
      console.log('✅ Keine beendeten Partys gefunden.');
      return;
    }
    
    console.log(`\n🗑️  Gefundene beendete Partys (${endedParties.length}):`);
    endedParties.forEach((party, index) => {
      console.log(`   ${index + 1}. ${party.name} (ID: ${party.id}) - Ende: ${party.endDate}`);
    });
    
    // Lösche alle beendeten Partys
    if (deleteCount > 0) {
      await batch.commit();
      console.log(`\n✅ ${deleteCount} beendete Partys wurden erfolgreich gelöscht!`);
    } else {
      console.log('\n⚠️  Keine Partys zum Löschen gefunden.');
    }
    
  } catch (error) {
    console.error('❌ Fehler beim Löschen der beendeten Partys:', error);
    throw error;
  }
}

// Führe die Funktion aus
deleteEndedParties()
  .then(() => {
    console.log('\n✨ Fertig!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Fehler:', error);
    process.exit(1);
  });












































