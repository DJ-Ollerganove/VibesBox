const https = require('https');

const url = 'https://us-central1-dj-ollerganove.cloudfunctions.net/deleteEndedParties';

https.get(url, (res) => {
  let data = '';

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    console.log('Response:', data);
    try {
      const json = JSON.parse(data);
      console.log('\n✅ Ergebnis:');
      console.log('   Message:', json.message);
      console.log('   Gelöscht:', json.deleted, 'Partys');
      if (json.parties && json.parties.length > 0) {
        console.log('\n   Gelöschte Partys:');
        json.parties.forEach((party, index) => {
          console.log(`   ${index + 1}. ${party.name} (ID: ${party.id})`);
        });
      }
    } catch (e) {
      console.log('Response (als Text):', data);
    }
  });
}).on('error', (err) => {
  console.error('Fehler:', err.message);
});












































