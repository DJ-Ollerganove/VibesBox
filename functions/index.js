const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Firebase Admin initialisieren (nur einmal)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Spotify API Konfiguration
// Funktion, um Credentials sicher zu laden (config() ist nur beim Function-Aufruf verfügbar)
function getSpotifyCredentials() {
  try {
    const config = functions.config();
    if (config && config.spotify) {
      return {
        clientId: config.spotify.client_id,
        clientSecret: config.spotify.client_secret,
      };
    }
  } catch (e) {
    console.log('functions.config() nicht verfügbar, versuche process.env');
  }
  
  // Fallback auf process.env (wird aus .env geladen beim Deployment)
  return {
    clientId: process.env.SPOTIFY_CLIENT_ID,
    clientSecret: process.env.SPOTIFY_CLIENT_SECRET,
  };
}
const SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token';
const SPOTIFY_API_BASE = 'https://api.spotify.com/v1';

// Spotify Token Cache (um API-Calls zu reduzieren)
let spotifyTokenCache = {
  token: null,
  expiresAt: null,
};

// Zugriffstoken für Spotify API holen
async function getSpotifyToken() {
  // Prüfe ob Token noch gültig ist
  if (spotifyTokenCache.token && spotifyTokenCache.expiresAt && Date.now() < spotifyTokenCache.expiresAt) {
    return spotifyTokenCache.token;
  }

  // Lade Credentials beim Token-Abruf
  const credentials = getSpotifyCredentials();
  const clientId = credentials.clientId;
  const clientSecret = credentials.clientSecret;

  if (!clientId || !clientSecret) {
    throw new Error('Spotify Credentials fehlen! Bitte in Firebase Functions Config setzen.');
  }

  try {
    const response = await axios.post(
      SPOTIFY_TOKEN_URL,
      'grant_type=client_credentials',
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`
        }
      }
    );
    
    // Cache Token (mit 5 Minuten Puffer vor Ablauf)
    const expiresIn = (response.data.expires_in || 3600) * 1000; // in Millisekunden
    spotifyTokenCache = {
      token: response.data.access_token,
      expiresAt: Date.now() + expiresIn - (5 * 60 * 1000), // 5 Minuten Puffer
    };
    
    return spotifyTokenCache.token;
  } catch (error) {
    console.error('Fehler beim Abrufen des Spotify-Tokens:', error.message);
    throw error;
  }
}

// Spotify Track-Suche als Cloud Function (öffentlich aufrufbar)
exports.searchSpotifyTracks = functions.https.onRequest(async (req, res) => {
  // CORS Header setzen
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    // Query-Parameter holen
    const query = req.query.q || req.body.q;
    const searchType = req.query.type || req.body.type || 'track'; // 'track', 'artist' oder 'both'

    if (!query || query.trim().length === 0) {
      res.status(400).json({ error: 'Query-Parameter "q" ist erforderlich' });
      return;
    }

    // Credentials werden beim Token-Abruf geprüft

    // Token holen
    const accessToken = await getSpotifyToken();

    let tracks = [];

    // Wenn nach Artists gesucht werden soll
    if (searchType === 'artist' || searchType === 'both') {
      // Zuerst nach Artists suchen
      const artistResponse = await axios.get(`${SPOTIFY_API_BASE}/search`, {
        params: {
          q: query.trim(),
          type: 'artist',
          limit: 5, // Max 5 Artists
          market: 'DE',
        },
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });

      // Für jeden gefundenen Artist die Top-Tracks holen
      const artistPromises = artistResponse.data.artists.items.slice(0, 2).map(async (artist) => {
        try {
          const topTracksResponse = await axios.get(
            `${SPOTIFY_API_BASE}/artists/${artist.id}/top-tracks`,
            {
              params: {
                market: 'DE',
              },
              headers: {
                'Authorization': `Bearer ${accessToken}`
              }
            }
          );

          // Formatiere die Top-Tracks dieses Artists (mehr Tracks pro Artist)
          return topTracksResponse.data.tracks.slice(0, 10).map(track => ({
            id: track.id,
            name: track.name,
            artists: track.artists.map(a => a.name).join(', '),
            album: track.album.name,
            previewUrl: track.preview_url,
            externalUrls: track.external_urls,
          }));
        } catch (error) {
          console.error(`Fehler beim Abrufen der Top-Tracks für Artist ${artist.name}:`, error.message);
          return [];
        }
      });

      const artistTracksArrays = await Promise.all(artistPromises);
      tracks = tracks.concat(...artistTracksArrays);
    }

    // Wenn auch nach Tracks gesucht werden soll (oder nur nach Tracks)
    if (searchType === 'track' || searchType === 'both') {
      const trackResponse = await axios.get(`${SPOTIFY_API_BASE}/search`, {
        params: {
          q: query.trim(),
          type: 'track',
          limit: 20, // Max 20 Ergebnisse
          market: 'DE', // Deutschland als Standard-Markt
        },
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });

      // Ergebnisse formatieren
      const trackResults = trackResponse.data.tracks.items.map(track => ({
        id: track.id,
        name: track.name,
        artists: track.artists.map(artist => artist.name).join(', '),
        album: track.album.name,
        previewUrl: track.preview_url,
        externalUrls: track.external_urls,
      }));

      // Duplikate entfernen (basierend auf Track-ID) und zusammenführen
      const existingIds = new Set(tracks.map(t => t.id));
      tracks = tracks.concat(trackResults.filter(t => !existingIds.has(t.id)));
    }

    // Duplikate entfernen (falls welche durch beide Suchen hinzugekommen sind)
    const uniqueTracks = [];
    const seenIds = new Set();
    for (const track of tracks) {
      if (!seenIds.has(track.id)) {
        seenIds.add(track.id);
        uniqueTracks.push(track);
      }
    }

    res.json({
      tracks: uniqueTracks.slice(0, 20), // Max 20 Ergebnisse insgesamt
      total: uniqueTracks.length,
    });
  } catch (error) {
    console.error('Fehler bei der Spotify-Suche:', error);
    console.error('Error details:', {
      message: error.message,
      response: error.response?.data,
      status: error.response?.status,
    });
    res.status(500).json({ 
      error: 'Fehler bei der Spotify-Suche',
      message: error.message,
      details: error.response?.data || 'Keine Details verfügbar'
    });
  }
});

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


