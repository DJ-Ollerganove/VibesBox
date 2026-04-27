// Skript zum Erstellen des settings/global_config Dokuments in Firestore
// Ausführen mit: node create_settings_document.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Firebase Admin SDK Key

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createSettingsDocument() {
  try {
    const settingsRef = db.collection('settings').doc('global_config');
    
    await settingsRef.set({
      copyright_text: '2026 by VibesBox',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Settings-Dokument erfolgreich erstellt!');
    console.log('Collection: settings');
    console.log('Dokument-ID: global_config');
    console.log('Feld: copyright_text = "2026 by VibesBox"');
  } catch (error) {
    console.error('❌ Fehler beim Erstellen des Dokuments:', error);
  } finally {
    process.exit(0);
  }
}

createSettingsDocument();
