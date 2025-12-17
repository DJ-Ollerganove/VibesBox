// Einfaches Skript zum Löschen beendeter Partys
// Verwendung: firebase firestore:delete --recursive --yes parties/{partyId}
// Oder manuell über Firebase Console

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Sie müssen diese Datei erstellen

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'dj-ollerganove',
});

const db = admin.firestore();

async function deleteEndedParties() {
  try {
    console.log('🔍 Suche nach beendeten Partys...');
    
    const now = admin.firestore.Timestamp.now();
    const partiesRef = db.collection('parties');
    
    const snapshot = await partiesRef.get();
    
    if (snapshot.empty) {
      console.log('✅ Keine Partys gefunden.');
      return;
    }
    
    console.log(`📊 Gefundene Partys: ${snapshot.size}`);
    
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
    
    if (deleteCount > 0) {
      await batch.commit();
      console.log(`\n✅ ${deleteCount} beendete Partys wurden gelöscht!`);
    }
    
  } catch (error) {
    console.error('❌ Fehler:', error);
    throw error;
  }
}

deleteEndedParties()
  .then(() => {
    console.log('\n✨ Fertig!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Fehler:', error);
    process.exit(1);
  });




















