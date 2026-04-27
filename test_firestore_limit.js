/**
 * ✅ TEST-SCRIPT: Simuliert Limit-Überschreitung für Firestore Rules
 * 
 * Dieses Script testet, ob die Firestore Security Rules korrekt
 * mit permission-denied antworten, wenn das Cooldown-Limit überschritten wird.
 * 
 * Verwendung:
 * node test_firestore_limit.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json'); // ⚠️ Service Account Key benötigt

// Initialisiere Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testCooldownLimit() {
  console.log('🧪 TEST: Cooldown-Limit-Überschreitung\n');
  
  const testClientId = 'test_client_' + Date.now();
  const testPartyId = 'test_party_123';
  
  try {
    // ✅ SCHRITT 1: Erstelle ersten Wunsch (sollte erfolgreich sein)
    console.log('📝 Schritt 1: Erstelle ersten Wunsch...');
    const wish1 = await db.collection('wishes').add({
      name: 'Test Gast',
      title: 'Test Song 1',
      artist: 'Test Artist',
      status: 'pending',
      client_id: testClientId,
      party_id: testPartyId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Erster Wunsch erstellt: ' + wish1.id);
    
    // ✅ SCHRITT 2: Aktualisiere last_actions (simuliert Cooldown)
    console.log('\n📝 Schritt 2: Aktualisiere last_actions (Cooldown-Tracking)...');
    await db.collection('last_actions').doc(testClientId).set({
      last_wish_timestamp: admin.firestore.FieldValue.serverTimestamp(),
      client_id: testClientId,
      party_id: testPartyId
    });
    console.log('✅ last_actions aktualisiert');
    
    // ✅ SCHRITT 3: Versuche sofort zweiten Wunsch (sollte fehlschlagen)
    console.log('\n📝 Schritt 3: Versuche sofort zweiten Wunsch (sollte permission-denied)...');
    try {
      const wish2 = await db.collection('wishes').add({
        name: 'Test Gast',
        title: 'Test Song 2',
        artist: 'Test Artist',
        status: 'pending',
        client_id: testClientId,
        party_id: testPartyId,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log('❌ FEHLER: Zweiter Wunsch wurde erstellt, obwohl Cooldown aktiv sein sollte!');
      console.log('   Wunsch-ID: ' + wish2.id);
    } catch (error) {
      if (error.code === 'permission-denied') {
        console.log('✅ ERFOLG: permission-denied erhalten (wie erwartet)');
        console.log('   Fehlermeldung: ' + error.message);
      } else {
        console.log('⚠️ UNERWARTETER FEHLER: ' + error.code);
        console.log('   Fehlermeldung: ' + error.message);
      }
    }
    
    // ✅ SCHRITT 4: Warte 31 Sekunden und versuche erneut (sollte erfolgreich sein)
    console.log('\n📝 Schritt 4: Warte 31 Sekunden...');
    await new Promise(resolve => setTimeout(resolve, 31000));
    
    // Aktualisiere last_actions mit neuer Zeit
    await db.collection('last_actions').doc(testClientId).update({
      last_wish_timestamp: admin.firestore.Timestamp.fromMillis(Date.now() - 31000)
    });
    
    console.log('📝 Schritt 5: Versuche dritten Wunsch nach Cooldown (sollte erfolgreich sein)...');
    try {
      const wish3 = await db.collection('wishes').add({
        name: 'Test Gast',
        title: 'Test Song 3',
        artist: 'Test Artist',
        status: 'pending',
        client_id: testClientId,
        party_id: testPartyId,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log('✅ ERFOLG: Dritter Wunsch nach Cooldown erstellt: ' + wish3.id);
    } catch (error) {
      console.log('❌ FEHLER: Dritter Wunsch wurde nicht erstellt');
      console.log('   Fehlercode: ' + error.code);
      console.log('   Fehlermeldung: ' + error.message);
    }
    
    // ✅ AUFRÄUMEN: Lösche Test-Daten
    console.log('\n🧹 Aufräumen: Lösche Test-Daten...');
    await wish1.delete();
    await db.collection('last_actions').doc(testClientId).delete();
    console.log('✅ Test-Daten gelöscht');
    
    console.log('\n✅ TEST ABGESCHLOSSEN');
    
  } catch (error) {
    console.error('❌ KRITISCHER FEHLER:', error);
  }
}

// ✅ HINWEIS: Dieses Script verwendet Admin SDK, daher umgeht es die Security Rules
// Für echte Tests der Security Rules muss ein Client-SDK verwendet werden
console.log('⚠️ HINWEIS: Dieses Script verwendet Admin SDK und umgeht Security Rules.');
console.log('   Für echte Rule-Tests verwende die Firebase Client SDK.\n');

testCooldownLimit();
