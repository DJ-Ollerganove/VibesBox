require('dotenv').config();
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Spotify API Konfiguration
const SPOTIFY_CLIENT_ID = process.env.SPOTIFY_CLIENT_ID;
const SPOTIFY_CLIENT_SECRET = process.env.SPOTIFY_CLIENT_SECRET;
const SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token';
const SPOTIFY_API_BASE = 'https://api.spotify.com/v1';

// Dateipfade
const WUENSHE_FILE = path.join(__dirname, 'wuensche.txt');
const ERGEBNIS_FILE = path.join(__dirname, 'ergebnis.csv');

// Zugriffstoken für Spotify API holen
async function getSpotifyToken() {
  try {
    const response = await axios.post(
      SPOTIFY_TOKEN_URL,
      'grant_type=client_credentials',
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Basic ${Buffer.from(`${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`).toString('base64')}`
        }
      }
    );
    return response.data.access_token;
  } catch (error) {
    console.error('Fehler beim Abrufen des Spotify-Tokens:', error.message);
    throw error;
  }
}

// Song über Spotify API suchen
async function searchSong(query, accessToken) {
  try {
    const response = await axios.get(`${SPOTIFY_API_BASE}/search`, {
      params: {
        q: query,
        type: 'track',
        limit: 1
      },
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });

    const tracks = response.data.tracks.items;
    if (tracks.length === 0) {
      return null;
    }

    return tracks[0];
  } catch (error) {
    console.error(`Fehler bei der Suche nach "${query}":`, error.message);
    return null;
  }
}

// Artist-Informationen (inkl. Genres) abrufen
async function getArtistInfo(artistId, accessToken) {
  try {
    const response = await axios.get(`${SPOTIFY_API_BASE}/artists/${artistId}`, {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });
    return response.data;
  } catch (error) {
    console.error(`Fehler beim Abrufen der Artist-Informationen für ${artistId}:`, error.message);
    return null;
  }
}

// CSV-Escape-Funktion
function escapeCsv(value) {
  if (value === null || value === undefined) {
    return '';
  }
  const stringValue = String(value);
  // Wenn das Feld Kommas, Zeilenumbrüche oder Anführungszeichen enthält, muss es in Anführungszeichen gesetzt werden
  if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
    return `"${stringValue.replace(/"/g, '""')}"`;
  }
  return stringValue;
}

// Hauptfunktion
async function main() {
  // Prüfe ob Umgebungsvariablen gesetzt sind
  if (!SPOTIFY_CLIENT_ID || !SPOTIFY_CLIENT_SECRET) {
    console.error('Fehler: SPOTIFY_CLIENT_ID und SPOTIFY_CLIENT_SECRET müssen in der .env-Datei gesetzt sein.');
    process.exit(1);
  }

  // Prüfe ob wuensche.txt existiert
  if (!fs.existsSync(WUENSHE_FILE)) {
    console.error(`Fehler: Die Datei "${WUENSHE_FILE}" wurde nicht gefunden.`);
    process.exit(1);
  }

  console.log('Lade Spotify-Zugriffstoken...');
  const accessToken = await getSpotifyToken();

  // Datei einlesen
  console.log(`Lese Datei "${WUENSHE_FILE}"...`);
  const fileContent = fs.readFileSync(WUENSHE_FILE, 'utf-8');
  const lines = fileContent.split('\n').map(line => line.trim()).filter(line => line.length > 0);

  console.log(`Gefunden: ${lines.length} Zeilen`);

  // CSV-Header schreiben
  const csvRows = [];
  csvRows.push('Songname,Artist,Genres');

  // Für jede Zeile Song suchen und Daten sammeln
  for (let i = 0; i < lines.length; i++) {
    const query = lines[i];
    console.log(`[${i + 1}/${lines.length}] Suche: "${query}"`);

    try {
      // Song suchen
      const track = await searchSong(query, accessToken);

      if (!track) {
        console.log(`  → Kein Ergebnis gefunden`);
        csvRows.push(`${escapeCsv(query)},,`);
        continue;
      }

      const songName = track.name;
      const artistName = track.artists.map(a => a.name).join(', ');
      const artistIds = track.artists.map(a => a.id);

      console.log(`  → Gefunden: "${songName}" von ${artistName}`);

      // Genres von allen Artists sammeln
      const allGenres = new Set();
      for (const artistId of artistIds) {
        const artistInfo = await getArtistInfo(artistId, accessToken);
        if (artistInfo && artistInfo.genres) {
          artistInfo.genres.forEach(genre => allGenres.add(genre));
        }
      }
      const genres = Array.from(allGenres).join('; ');

      console.log(`  → Genres: ${genres || 'N/A'}`);

      // In CSV-Zeile schreiben
      csvRows.push(`${escapeCsv(songName)},${escapeCsv(artistName)},${escapeCsv(genres)}`);

      // Kurze Pause, um Rate Limits zu vermeiden
      await new Promise(resolve => setTimeout(resolve, 100));

    } catch (error) {
      console.error(`  → Fehler: ${error.message}`);
      csvRows.push(`${escapeCsv(query)},,`);
    }
  }

  // CSV-Datei schreiben
  console.log(`\nSchreibe Ergebnisse in "${ERGEBNIS_FILE}"...`);
  fs.writeFileSync(ERGEBNIS_FILE, csvRows.join('\n'), 'utf-8');
  console.log('Fertig!');
}

// Skript ausführen
main().catch(error => {
  console.error('Unerwarteter Fehler:', error);
  process.exit(1);
});
























