import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'utils/debug_log.dart';

// Test Page - Zeigt alle Daten aus der Musikdatenbank an
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    debugLog('🔍 Test-Seite wurde initialisiert');
    // Test-Zugriff auf Firestore
    _testFirestoreAccess();
  }

  Future<void> _testFirestoreAccess() async {
    try {
      debugLog('🔍 Teste Firestore-Zugriff auf titles...');
      final titlesSnapshot = await FirebaseFirestore.instance
          .collection('titles')
          .limit(1)
          .get();
      debugLog('✅ Firestore-Zugriff erfolgreich! Anzahl Titel: ${titlesSnapshot.docs.length}');
      
      debugLog('🔍 Teste Firestore-Zugriff auf genres...');
      final genresSnapshot = await FirebaseFirestore.instance
          .collection('genres')
          .limit(1)
          .get();
      debugLog('✅ Firestore-Zugriff erfolgreich! Anzahl Genres: ${genresSnapshot.docs.length}');
      
      debugLog('🔍 Teste Firestore-Zugriff auf artists...');
      final artistsSnapshot = await FirebaseFirestore.instance
          .collection('artists')
          .limit(1)
          .get();
      debugLog('✅ Firestore-Zugriff erfolgreich! Anzahl Artists: ${artistsSnapshot.docs.length}');
    } catch (e, stackTrace) {
      debugLog('❌ Firestore-Zugriff Fehler: $e');
      debugLog('❌ Stack Trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugLog('🔍 Test-Seite build() aufgerufen');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Test - Musikdatenbank',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Tabs für Titel, Genres, Artists und Datenbankstruktur
            Row(
              children: [
                Expanded(
                  child: _buildTabButton('Titel', 0, Icons.music_note),
                ),
                Expanded(
                  child: _buildTabButton('Genres', 1, Icons.category),
                ),
                Expanded(
                  child: _buildTabButton('Artists', 2, Icons.person),
                ),
                Expanded(
                  child: _buildTabButton('DB-Struktur', 3, Icons.storage),
                ),
              ],
            ),
            const Divider(height: 1),
            // Content basierend auf ausgewähltem Tab
            Expanded(
              child: _selectedTab == 0
                  ? _buildTitlesTab()
                  : _selectedTab == 1
                      ? _buildGenresTab()
                      : _selectedTab == 2
                          ? _buildArtistsTab()
                          : _buildDatabaseStructureTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitlesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('titles')
          .snapshots(),
      builder: (context, snapshot) {
        debugLog('📊 Test-Seite - Titel Stream Status: ${snapshot.connectionState}');
        debugLog('📊 Test-Seite - Hat Daten: ${snapshot.hasData}');
        debugLog('📊 Test-Seite - Hat Fehler: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugLog('❌ Test-Seite - Fehler: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          debugLog('📊 Test-Seite - Anzahl Titel: ${snapshot.data!.docs.length}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Fehler: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Keine Titel in der Musikdatenbank gefunden',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        final titles = snapshot.data!.docs;
        
        // Sortiere clientseitig nach createdAt (fallback wenn kein createdAt vorhanden)
        titles.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'] as Timestamp?;
          final bCreated = bData['createdAt'] as Timestamp?;
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return bCreated.compareTo(aCreated); // Descending
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: titles.length,
          itemBuilder: (context, index) {
            final titleDoc = titles[index];
            final titleData = titleDoc.data() as Map<String, dynamic>;
            
            return _MusicDatabaseCard(
              titleDocId: titleDoc.id,
              titleData: titleData,
            );
          },
        );
      },
    );
  }

  Widget _buildGenresTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('genres')
          .snapshots(),
      builder: (context, snapshot) {
        debugLog('📊 Test-Seite - Genres Stream Status: ${snapshot.connectionState}');
        debugLog('📊 Test-Seite - Genres Hat Daten: ${snapshot.hasData}');
        debugLog('📊 Test-Seite - Genres Hat Fehler: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugLog('❌ Test-Seite - Genres Fehler: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          debugLog('📊 Test-Seite - Anzahl Genres: ${snapshot.data!.docs.length}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Fehler: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Keine Genres gefunden',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        final genres = snapshot.data!.docs;
        
        // Sortiere clientseitig nach Name
        genres.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = (aData['name'] as String? ?? '').toLowerCase();
          final bName = (bData['name'] as String? ?? '').toLowerCase();
          return aName.compareTo(bName);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final genreDoc = genres[index];
            final genreData = genreDoc.data() as Map<String, dynamic>;
            final genreName = genreData['name'] as String? ?? 'Unbekannt';
            final createdAt = genreData['createdAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: Icon(Icons.category, color: Colors.purple[700]),
                ),
                title: Text(
                  genreName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: createdAt != null
                    ? Text('Erstellt: ${_formatDateTime(createdAt.toDate())}')
                    : null,
                trailing: Text(
                  'ID: ${genreDoc.id}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArtistsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artists')
          .snapshots(),
      builder: (context, snapshot) {
        debugLog('📊 Test-Seite - Artists Stream Status: ${snapshot.connectionState}');
        debugLog('📊 Test-Seite - Artists Hat Daten: ${snapshot.hasData}');
        debugLog('📊 Test-Seite - Artists Hat Fehler: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugLog('❌ Test-Seite - Artists Fehler: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          debugLog('📊 Test-Seite - Anzahl Artists: ${snapshot.data!.docs.length}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Fehler: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Keine Artists gefunden',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        final artists = snapshot.data!.docs;
        
        // Sortiere clientseitig nach Name
        artists.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = (aData['name'] as String? ?? '').toLowerCase();
          final bName = (bData['name'] as String? ?? '').toLowerCase();
          return aName.compareTo(bName);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artistDoc = artists[index];
            final artistData = artistDoc.data() as Map<String, dynamic>;
            final artistName = artistData['name'] as String? ?? 'Unbekannt';
            final createdAt = artistData['createdAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Icon(Icons.person, color: Colors.orange[700]),
                ),
                title: Text(
                  artistName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: createdAt != null
                    ? Text('Erstellt: ${_formatDateTime(createdAt.toDate())}')
                    : null,
                trailing: Text(
                  'ID: ${artistDoc.id}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDatabaseStructureTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datenbankstruktur',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Übersicht aller Collections und deren Felder',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Users Collection
          _buildCollectionCard(
            'users',
            'Benutzer',
            Icons.person,
            Colors.blue,
            [
              {'name': 'email', 'type': 'String', 'required': 'Ja', 'description': 'Email-Adresse des Users'},
              {'name': 'displayName', 'type': 'String', 'required': 'Nein', 'description': 'Anzeigename des Users'},
              {'name': 'loginCount', 'type': 'int', 'required': 'Ja', 'description': 'Anzahl der Logins'},
              {'name': 'lastLogin', 'type': 'Timestamp', 'required': 'Ja', 'description': 'Letzter Login-Zeitpunkt'},
              {'name': 'role_id', 'type': 'String', 'required': 'Nein', 'description': 'Referenz zur roles-Collection (Gast/DJ/Admin)'},
              {'name': 'created_at', 'type': 'Timestamp', 'required': 'Nein', 'description': 'Erstellungsdatum (bei Registrierung)'},
              {'name': 'last_viewed_wishes_at', 'type': 'Timestamp', 'required': 'Nein', 'description': 'Letzter Zeitpunkt, an dem Wünsche als gesehen markiert wurden'},
              {'name': 'photoURL', 'type': 'String', 'required': 'Nein', 'description': 'URL zum Profilbild'},
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Wishes Collection
          _buildCollectionCard(
            'wishes',
            'Wünsche',
            Icons.music_note,
            Colors.green,
            [
              {'name': 'name', 'type': 'String', 'required': 'Ja', 'description': 'Name des Wunschenden'},
              {'name': 'title', 'type': 'String', 'required': 'Ja', 'description': 'Titel des Musikwunsches'},
              {'name': 'artist', 'type': 'String', 'required': 'Ja', 'description': 'Interpret des Musikwunsches'},
              {'name': 'status', 'type': 'String', 'required': 'Ja', 'description': 'Status: pending, played, rejected, not_played, etc.'},
              {'name': 'createdAt', 'type': 'Timestamp', 'required': 'Ja', 'description': 'Erstellungszeitpunkt'},
              {'name': 'duplicate_count', 'type': 'int', 'required': 'Nein', 'description': 'Anzahl der Duplikate (bei mehrfachen Wünschen)'},
              {'name': 'requested_by', 'type': 'List<String>', 'required': 'Nein', 'description': 'Liste aller Namen, die diesen Wunsch gewünscht haben'},
              {'name': 'greetings', 'type': 'List<Map>', 'required': 'Nein', 'description': 'Liste von Grußnachrichten [{name, greeting}]'},
              {'name': 'is_duplicate', 'type': 'bool', 'required': 'Nein', 'description': 'Flag ob dies ein Duplikat ist'},
              {'name': 'original_wish_id', 'type': 'String', 'required': 'Nein', 'description': 'ID des ursprünglichen Wunsches (bei Duplikaten)'},
              {'name': 'is_registered_user', 'type': 'bool', 'required': 'Nein', 'description': 'Ob der Wunschende ein registrierter User ist'},
              {'name': 'is_registered_users', 'type': 'Map<String, bool>', 'required': 'Nein', 'description': 'Map von Namen zu Registrierungsstatus'},
              {'name': 'greeting', 'type': 'String', 'required': 'Nein', 'description': 'Einzelne Grußnachricht (optional, falls vorhanden)'},
              {'name': 'party_id', 'type': 'String', 'required': 'Ja', 'description': 'Referenz zur parties-Collection (ID des Party-Dokuments)'},
              {'name': 'party_code', 'type': 'String', 'required': 'Ja', 'description': '4-stelliger Party-Code'},
              {'name': 'dj_code', 'type': 'String', 'required': 'Ja', 'description': 'User-ID des DJs (Direkter Bezug)'},
              {'name': 'notified_via_push', 'type': 'bool', 'required': 'Nein', 'description': 'Ob dieser Wunsch bereits per Push-Benachrichtigung gesendet wurde'},
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Parties Collection
          _buildCollectionCard(
            'parties',
            'Partys',
            Icons.event,
            Colors.orange,
            [
              {'name': 'party_name', 'type': 'String', 'required': 'Ja', 'description': 'Name der Party'},
              {'name': 'start_date', 'type': 'Timestamp', 'required': 'Ja', 'description': 'Startdatum und -zeit'},
              {'name': 'end_date', 'type': 'Timestamp', 'required': 'Ja', 'description': 'Enddatum und -zeit'},
              {'name': 'created_at', 'type': 'Timestamp', 'required': 'Ja', 'description': 'Erstellungszeitpunkt'},
              {'name': 'party_code', 'type': 'String', 'required': 'Ja', 'description': '4-stelliger Party-Code (1000-9999)'},
              {'name': 'party_type', 'type': 'String', 'required': 'Ja', 'description': 'Typ: private oder public'},
              {'name': 'created_by', 'type': 'String', 'required': 'Ja', 'description': 'User-ID des erstellenden DJs'},
              {'name': 'created_by_email', 'type': 'String', 'required': 'Nein', 'description': 'Email des erstellenden DJs'},
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Party Status Collection
          _buildCollectionCard(
            'party_status',
            'Party-Status',
            Icons.info,
            Colors.purple,
            [
              {'name': 'party_code', 'type': 'String', 'required': 'Ja', 'description': '4-stelliger Party-Code'},
              {'name': 'dj_code', 'type': 'String', 'required': 'Ja', 'description': 'User-ID des DJ-Users'},
              {'name': 'status', 'type': 'bool', 'required': 'Ja', 'description': 'true = aktiv, false = inaktiv'},
              {'name': 'created_at', 'type': 'Timestamp', 'required': 'Ja', 'description': 'Erstellungszeitpunkt'},
              {'name': 'party_id', 'type': 'String', 'required': 'Ja', 'description': 'Referenz zur parties-Collection (Dokument-ID)'},
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Roles Collection
          _buildCollectionCard(
            'roles',
            'Rollen',
            Icons.badge,
            Colors.indigo,
            [
              {'name': 'name', 'type': 'String', 'required': 'Ja', 'description': 'Rollenname: Gast, DJ oder Admin'},
              {'name': 'level', 'type': 'int', 'required': 'Ja', 'description': 'Hierarchie-Level: 1 (Gast), 2 (DJ), 3 (Admin)'},
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Party Settings Collection
          _buildCollectionCard(
            'party_settings',
            'Party-Einstellungen',
            Icons.settings,
            Colors.teal,
            [
              {'name': 'wishbox_manually_enabled', 'type': 'bool', 'required': 'Nein', 'description': 'Manueller Schalter für Wunschbox (Dokument: current)'},
            ],
            note: 'Collection enthält ein Dokument mit ID "current" für aktuelle Einstellungen',
          ),
          
          const SizedBox(height: 16),
          
          // Contact Messages Collection
          _buildCollectionCard(
            'contact_messages',
            'Kontaktnachrichten',
            Icons.email,
            Colors.red,
            [
              {'name': 'name', 'type': 'String', 'required': 'Ja', 'description': 'Name des Absenders'},
              {'name': 'email', 'type': 'String', 'required': 'Ja', 'description': 'Email des Absenders'},
              {'name': 'phone', 'type': 'String', 'required': 'Nein', 'description': 'Telefonnummer (optional)'},
              {'name': 'subject', 'type': 'String', 'required': 'Ja', 'description': 'Betreff der Nachricht'},
              {'name': 'message', 'type': 'String', 'required': 'Ja', 'description': 'Nachrichtentext'},
              {'name': 'createdAt', 'type': 'Timestamp', 'required': 'Ja', 'description': 'Erstellungszeitpunkt'},
              {'name': 'read', 'type': 'bool', 'required': 'Ja', 'description': 'Ob die Nachricht gelesen wurde'},
              {'name': 'userId', 'type': 'String', 'required': 'Nein', 'description': 'User-ID des Absenders (falls eingeloggt)'},
              {'name': 'userEmail', 'type': 'String', 'required': 'Nein', 'description': 'Email des Absenders (falls eingeloggt)'},
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Zusätzliche Collections (Musikdatenbank)
          _buildCollectionCard(
            'titles',
            'Titel (Musikdatenbank)',
            Icons.music_video,
            Colors.pink,
            [
              {'name': 'title', 'type': 'String', 'required': 'Ja', 'description': 'Titel des Liedes'},
              {'name': 'artist_id', 'type': 'String', 'required': 'Nein', 'description': 'Referenz zur artists-Collection'},
              {'name': 'genre_ids', 'type': 'List<String>', 'required': 'Nein', 'description': 'Referenzen zur genres-Collection'},
              {'name': 'spotify_id', 'type': 'String', 'required': 'Nein', 'description': 'Spotify Track ID'},
              {'name': 'duration_ms', 'type': 'int', 'required': 'Nein', 'description': 'Dauer in Millisekunden'},
              {'name': 'createdAt', 'type': 'Timestamp', 'required': 'Nein', 'description': 'Erstellungszeitpunkt'},
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildCollectionCard(
            'genres',
            'Genres (Musikdatenbank)',
            Icons.category,
            Colors.deepPurple,
            [
              {'name': 'name', 'type': 'String', 'required': 'Ja', 'description': 'Name des Genres'},
              {'name': 'createdAt', 'type': 'Timestamp', 'required': 'Nein', 'description': 'Erstellungszeitpunkt'},
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildCollectionCard(
            'artists',
            'Artists (Musikdatenbank)',
            Icons.person_outline,
            Colors.amber,
            [
              {'name': 'name', 'type': 'String', 'required': 'Ja', 'description': 'Name des Künstlers'},
              {'name': 'createdAt', 'type': 'Timestamp', 'required': 'Nein', 'description': 'Erstellungszeitpunkt'},
            ],
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(String collectionName, String displayName, IconData icon, Color color, List<Map<String, String>> fields, {String? note}) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          'Collection: $collectionName',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        children: [
          if (note != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Felder:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...fields.map((field) => _buildFieldRow(
                  field['name']!,
                  field['type']!,
                  field['required']!,
                  field['description']!,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String fieldName, String fieldType, String required, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fieldName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fieldType,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[900],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: required == 'Ja' ? Colors.red[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  required == 'Ja' ? 'Pflicht' : 'Optional',
                  style: TextStyle(
                    fontSize: 11,
                    color: required == 'Ja' ? Colors.red[900] : Colors.green[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}

// Widget für einzelne Musikdatenbank-Karte
class _MusicDatabaseCard extends StatelessWidget {
  final String titleDocId;
  final Map<String, dynamic> titleData;

  const _MusicDatabaseCard({
    required this.titleDocId,
    required this.titleData,
  });

  @override
  Widget build(BuildContext context) {
    final title = titleData['title'] as String? ?? 'Kein Titel';
    final artistId = titleData['artist_id'] as String?;
    final genreIds = titleData['genre_ids'] as List<dynamic>? ?? [];
    final spotifyId = titleData['spotify_id'] as String?;
    final durationMs = titleData['duration_ms'] as int?;
    final createdAt = titleData['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.music_note, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Spotify ID: ${spotifyId ?? "N/A"}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _loadRelatedData(artistId, genreIds),
            builder: (context, snapshot) {
              final artistName = snapshot.data?['artist'] as String?;
              final genres = snapshot.data?['genres'] as List<String>? ?? [];

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titel-Dokument ID
                    _buildFieldRow('Dokument ID', titleDocId, Icons.description),
                    
                    // Titel
                    _buildFieldRow('Titel', title, Icons.music_note),
                    
                    // Artist
                    if (artistName != null && artistName.isNotEmpty)
                      _buildFieldRow('Artist', artistName, Icons.person),
                    if (artistId != null)
                      _buildFieldRow('Artist ID', artistId, Icons.link),
                    
                    // Spotify
                    if (spotifyId != null && spotifyId.isNotEmpty)
                      _buildFieldRow('Spotify ID', spotifyId, Icons.music_video),
                    
                    // Dauer
                    if (durationMs != null)
                      _buildFieldRow('Dauer', _formatDuration(durationMs), Icons.timer),
                    
                    // Genres
                    if (genres.isNotEmpty) ...[
                      _buildFieldRow('Genres', genres.join(', '), Icons.category),
                      _buildFieldRow('Genre IDs', genreIds.join(', '), Icons.tag),
                    ] else if (genreIds.isNotEmpty) ...[
                      _buildFieldRow('Genre IDs (Namen fehlen)', genreIds.join(', '), Icons.tag),
                    ],
                    
                    // Erstellt am
                    if (createdAt != null)
                      _buildFieldRow('Erstellt am', _formatDateTime(createdAt.toDate()), Icons.access_time),
                    
                    const Divider(height: 24),
                    
                    // Alle weiteren Felder
                    ...titleData.entries.where((entry) {
                      final key = entry.key;
                      return !['title', 'artist_id', 'genre_ids', 'spotify_id', 'duration_ms', 'createdAt'].contains(key);
                    }).map((entry) => _buildFieldRow(
                      entry.key,
                      entry.value.toString(),
                      Icons.data_object,
                    )),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Lädt verknüpfte Daten (Artist und Genres)
  Future<Map<String, dynamic>> _loadRelatedData(String? artistId, List<dynamic> genreIds) async {
    try {
      String? artistName;
      List<String> genreNames = [];

      // Lade Artist-Name
      if (artistId != null) {
        final artistDoc = await FirebaseFirestore.instance
            .collection('artists')
            .doc(artistId)
            .get();
        if (artistDoc.exists) {
          artistName = artistDoc.data()?['name'] as String?;
          debugLog('✅ Artist gefunden: $artistName (ID: $artistId)');
        } else {
          debugLog('⚠️ Artist-Dokument existiert nicht: $artistId');
        }
      }

      // Lade Genre-Namen
      if (genreIds.isNotEmpty) {
        debugLog('🔍 Lade ${genreIds.length} Genres...');
        final genrePromises = genreIds.map((genreId) async {
          final genreDoc = await FirebaseFirestore.instance
              .collection('genres')
              .doc(genreId.toString())
              .get();
          if (genreDoc.exists) {
            final genreName = genreDoc.data()?['name'] as String?;
            debugLog('✅ Genre gefunden: $genreName (ID: $genreId)');
            return genreName;
          }
          debugLog('⚠️ Genre-Dokument existiert nicht: $genreId');
          return null;
        });
        
        final genreResults = await Future.wait(genrePromises);
        genreNames = genreResults.whereType<String>().toList();
        debugLog('📊 Gefundene Genres: $genreNames');
      }

      return {
        'artist': artistName,
        'genres': genreNames,
      };
    } catch (e, stackTrace) {
      debugLog('❌ Fehler beim Laden der verknüpften Daten: $e');
      debugLog('❌ Stack Trace: $stackTrace');
      return {};
    }
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String _formatDuration(int durationMs) {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildFieldRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


