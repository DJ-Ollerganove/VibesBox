const admin = require('firebase-admin');

// Firebase Admin initialisieren mit expliziter Projekt-ID
if (!admin.apps.length) {
  // Verwende die Projekt-ID aus der Umgebung oder aus .firebaserc
  // Standard: vibesbox (falls nicht gesetzt)
  const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'vibesbox';
  admin.initializeApp({
    projectId: projectId
  });
}

const db = admin.firestore();

async function queryFirestore() {
  try {
    console.log('='.repeat(80));
    console.log('WUNSCH-ANALYSE: Dokument hU0LgzN2sVwFrwcEg9QC');
    console.log('='.repeat(80));
    
    // 1. Spezifisches Dokument abrufen
    const wishDocRef = db.collection('wishes').doc('hU0LgzN2sVwFrwcEg9QC');
    const wishDoc = await wishDocRef.get();
    
    if (!wishDoc.exists) {
      console.log('❌ Dokument existiert nicht!');
    } else {
      const data = wishDoc.data();
      console.log('✅ Dokument gefunden:');
      console.log('  doc.id:', wishDoc.id);
      console.log('  party_id:', data.party_id || '(nicht gesetzt)');
      console.log('  spotify_id:', data.spotify_id || '(nicht gesetzt)');
      console.log('  title:', data.title || '(nicht gesetzt)');
      console.log('  is_duplicate:', data.is_duplicate !== undefined ? data.is_duplicate : '(nicht gesetzt)');
      console.log('');
      
      // 2. Gegenprüfung: Suche nach gleicher spotify_id ODER gleichem Titel
      const spotifyId = data.spotify_id;
      const title = data.title;
      
      console.log('='.repeat(80));
      console.log('GEGENPRÜFUNG: Suche nach ähnlichen Wünschen');
      console.log('='.repeat(80));
      console.log('Suche nach:');
      console.log('  - spotify_id:', spotifyId || '(keine)');
      console.log('  - title:', title || '(keine)');
      console.log('');
      
      const allWishes = await db.collection('wishes').get();
      const matchingWishes = [];
      
      for (const doc of allWishes.docs) {
        const docData = doc.data();
        let matches = false;
        const reasons = [];
        
        // Prüfe spotify_id
        if (spotifyId && docData.spotify_id === spotifyId) {
          matches = true;
          reasons.push('spotify_id');
        }
        
        // Prüfe Titel (case-insensitive)
        if (title && docData.title && 
            docData.title.toLowerCase().trim() === title.toLowerCase().trim()) {
          matches = true;
          reasons.push('title');
        }
        
        if (matches) {
          matchingWishes.push({
            id: doc.id,
            party_id: docData.party_id || '(nicht gesetzt)',
            createdAt: docData.createdAt ? docData.createdAt.toDate().toISOString() : '(nicht gesetzt)',
            reasons: reasons,
            spotify_id: docData.spotify_id || '(nicht gesetzt)',
            title: docData.title || '(nicht gesetzt)',
            is_duplicate: docData.is_duplicate !== undefined ? docData.is_duplicate : '(nicht gesetzt)'
          });
        }
      }
      
      console.log(`Gefundene Dokumente: ${matchingWishes.length}`);
      console.log('');
      
      for (let i = 0; i < matchingWishes.length; i++) {
        const wish = matchingWishes[i];
        console.log(`--- Dokument ${i + 1} ---`);
        console.log('  doc.id:', wish.id);
        console.log('  party_id:', wish.party_id);
        console.log('  createdAt:', wish.createdAt);
        console.log('  Übereinstimmung durch:', wish.reasons.join(', '));
        console.log('  spotify_id:', wish.spotify_id);
        console.log('  title:', wish.title);
        console.log('  is_duplicate:', wish.is_duplicate);
        console.log('');
      }
      
      // 3. Party-Status abrufen
      const partyId = data.party_id;
      if (partyId) {
        console.log('='.repeat(80));
        console.log('PARTY-STATUS: Dokument cVPlhrPuXVBRyGyuNcDh');
        console.log('='.repeat(80));
        
        const partyDocRef = db.collection('parties').doc('cVPlhrPuXVBRyGyuNcDh');
        const partyDoc = await partyDocRef.get();
        
        if (!partyDoc.exists) {
          console.log('❌ Party-Dokument existiert nicht!');
        } else {
          const partyData = partyDoc.data();
          console.log('✅ Party-Dokument gefunden:');
          console.log('  doc.id:', partyDoc.id);
          
          if (partyData.start_date) {
            const startDate = partyData.start_date.toDate ? partyData.start_date.toDate() : new Date(partyData.start_date);
            console.log('  start_date:', startDate.toISOString());
          } else {
            console.log('  start_date:', '(nicht gesetzt)');
          }
          
          if (partyData.end_date) {
            const endDate = partyData.end_date.toDate ? partyData.end_date.toDate() : new Date(partyData.end_date);
            console.log('  end_date:', endDate.toISOString());
          } else {
            console.log('  end_date:', '(nicht gesetzt)');
          }
          
          console.log('');
          console.log('Zusätzliche Party-Informationen:');
          console.log('  party_name:', partyData.party_name || '(nicht gesetzt)');
          console.log('  status:', partyData.status || '(nicht gesetzt)');
          console.log('  isActive:', partyData.isActive !== undefined ? partyData.isActive : '(nicht gesetzt)');
        }
      } else {
        console.log('⚠️ Keine party_id im Wunsch-Dokument gefunden, kann Party nicht abrufen.');
      }
    }
    
    console.log('='.repeat(80));
    console.log('ABFRAGE ABGESCHLOSSEN');
    console.log('='.repeat(80));
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Fehler:', error);
    process.exit(1);
  }
}

queryFirestore();
