import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import '../models/playlist_model.dart';
import '../services/active_party_service.dart';
import '../services/duplicate_check_service.dart';
import '../services/music_history_session_resolver.dart';
import '../services/shazam_service.dart';
import '../services/user_service.dart';
import '../utils/history_last_track_dedup.dart';
import '../utils/party_helper.dart';
import '../utils/debug_log.dart';

/// Service für Musik-History-Management
/// Lauscht passiv auf Musikerkennung und speichert erkannte Songs automatisch
/// Session ist an die aktive Party gebunden, nicht an den Musikerkennungs-Schalter
class HistoryProvider {
  static final HistoryProvider _instance = HistoryProvider._internal();
  factory HistoryProvider() => _instance;
  HistoryProvider._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ShazamService _shazamService = ShazamService();
  
  StreamSubscription<Map<String, dynamic>?>? _shazamSubscription;
  StreamSubscription<ShazamScanStatus>? _statusSubscription;
  StreamSubscription<QuerySnapshot>? _partiesSubscription;
  StreamSubscription<ActivePartyInfo?>? _activePartyInfoSubscription;
  StreamSubscription<QuerySnapshot>? _tracksSubscription;
  final StreamController<List<Map<String, dynamic>>> _tracksController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final List<Map<String, dynamic>> _accumulatedTracksForStream = [];
  String? _lastTracksSessionId;
  String? _currentSessionId;
  String? _currentPartyId;
  String? _currentPartyName;
  bool _isRecording = false;
  bool _isProcessingTrack = false; // Lock um Race Conditions zu vermeiden
  bool _isHistoryListening = false; // ✅ EFFIZIENZ: Flag ob History-Streams aktiv sind
  // Caching entfernt: Threshold wird jetzt bei jedem Scan frisch aus der DB geladen
  bool get _isAdminMode => AppConfig.isAdminRole(UserService().currentUser.value);

  bool _coreShazamListenersAttached = false;
  String? _partiesStreamBoundUid;
  bool _partiesStreamPermissionDeniedLogged = false;

  /// Initialisiert den Provider und beginnt mit dem Monitoring.
  /// Kern-Listener (Shazam) nur einmal; Party-Stream pro Firebase-UID (erneut bei Account-Wechsel).
  void initialize() {
    final user = FirebaseAuth.instance.currentUser;

    if (!_coreShazamListenersAttached) {
      _coreShazamListenersAttached = true;
      _statusSubscription = _shazamService.statusStream.listen((_) {
        _checkAndUpdateSession();
      });

      _shazamSubscription = _shazamService.resultStream.listen((result) {
        final err = result?['error'] as String?;
        if (err == 'FREE_SCAN_COOLDOWN' ||
            err == 'NEXT_SCAN_COUNTDOWN' ||
            err == 'PRO_REQUIRED') {
          return;
        }
        if (_shouldRecord()) {
          _handleNewTrack(result);
        } else if (_isSuccessfulSongPayload(result)) {
          final title = result?['title'] as String? ?? '';
          final artist = result?['artist'] as String? ?? '';
          debugLog(
            'Song erkannt: $title — $artist, wird aber nicht gespeichert (keine aktive Party)',
          );
        }
      });
    }

    if (_partiesStreamBoundUid != user?.uid) {
      _partiesStreamBoundUid = user?.uid;
      _partiesStreamPermissionDeniedLogged = false;
      _partiesSubscription?.cancel();
      _partiesSubscription = null;
      if (user != null) {
        _partiesSubscription = _firestore
            .collection('parties')
            .where('created_by', isEqualTo: user.uid)
            .snapshots()
            .listen(
          (snapshot) {
            _updateActiveParty(snapshot.docs);
          },
          onError: (Object e, StackTrace _) {
            if (_partiesStreamPermissionDeniedLogged) return;
            final msg = e.toString().toLowerCase();
            if (msg.contains('permission')) {
              _partiesStreamPermissionDeniedLogged = true;
              debugLog(
                'HistoryProvider: parties-Stream permission-denied (einmal): $e',
              );
            }
          },
        );
      }
    }

    _checkAndUpdateSession();

    if (!_tracksController.isClosed) {
      _tracksController.add([]);
    }
  }
  
  /// ✅ EFFIZIENZ: Startet History-Streams nur on-demand (z.B. beim Öffnen der History-Seite)
  /// Wird NICHT automatisch beim App-Start aufgerufen
  void startHistoryListening() {
    if (_isHistoryListening) {
      // Streams laufen bereits
      return;
    }
    _isHistoryListening = true;
    _updateTracksStream();
  }
  
  /// ✅ EFFIZIENZ: Stoppt History-Streams (z.B. beim Schließen der History-Seite)
  void stopHistoryListening() {
    _isHistoryListening = false;
    _activePartyInfoSubscription?.cancel();
    _activePartyInfoSubscription = null;
    _tracksSubscription?.cancel();
    _tracksSubscription = null;
    _accumulatedTracksForStream.clear();
    _lastTracksSessionId = null;
  }

  /// Aktualisiert die aktive Party basierend auf Party-Dokumenten
  void _updateActiveParty(List<QueryDocumentSnapshot> partyDocs) {
    try {
      final now = DateTime.now();
      String? activePartyId;
      String? activePartyName;

      // Finde aktive Party
      for (final partyDoc in partyDocs) {
        final data = partyDoc.data() as Map<String, dynamic>;
        final startTimestamp = data['start_date'] as Timestamp?;
        final endTimestamp = data['end_date'] as Timestamp?;

        if (startTimestamp != null && endTimestamp != null) {
          final startDate = startTimestamp.toDate();
          final endDate = endTimestamp.toDate();

          // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende
          if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
            activePartyId = partyDoc.id;
            activePartyName = data['party_name'] as String? ?? 'Unbenannte Party';
            break;
          }
        }
      }

      // Aktualisiere Party-Info
      final partyChanged = _currentPartyId != activePartyId;
      _currentPartyId = activePartyId;
      _currentPartyName = activePartyName;

      // Tracks-Stream wird über ActivePartyService.getActivePartyInfoStream gesteuert (sessionId);
      // bei Session-Wechsel schwenkt der Stream automatisch um.

      // Prüfe ob Session gestartet/gestoppt werden muss
      _checkAndUpdateSession();
    } catch (e) {
      debugLog('Fehler beim Aktualisieren der aktiven Party: $e');
    }
  }

  /// Prüft ob aktuell aufgenommen werden soll
  /// WICHTIG: Diese Funktion entscheidet, ob Songs in Firestore gespeichert werden
  /// Test-Modus: Wenn keine Session aktiv ist, werden Songs NUR im UI angezeigt, NICHT gespeichert
  bool _shouldRecord() {
    // Speichern nur wenn: Session aktiv ist UND Party-ID gültig ist
    // Session ist an Party gebunden, nicht an Musikerkennung
    return _isRecording &&
        _currentSessionId != null &&
        _currentPartyId != null &&
        _currentPartyId != 'manual' &&
        _currentPartyId!.isNotEmpty;
  }

  /// Erkennt gültigen Treffer für UI/Test-Modus-Log (ohne Error-Payload).
  bool _isSuccessfulSongPayload(Map<String, dynamic>? result) {
    if (result == null) return false;
    final err = result['error'] as String?;
    if (err != null && err.isNotEmpty) return false;
    final title = (result['title'] as String? ?? '').trim();
    final artist = (result['artist'] as String? ?? '').trim();
    if (title.isEmpty || artist.isEmpty) return false;
    if (title == '-' && artist == '-') return false;
    return true;
  }

  /// Prüft Party-Status und aktualisiert Session entsprechend
  /// Session ist an Party gebunden, nicht an Musikerkennung
  Future<void> _checkAndUpdateSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (_isRecording) {
        await _stopSession();
      }
      _currentPartyId = null;
      _currentPartyName = null;
      return;
    }

    // Prüfe aktive Party
    final partyInfo = await party_dj_check();
    final activePartyId = partyInfo['party_id']; // party_dj_check() gibt 'party_id' zurück
    final isPartyActive = activePartyId != null && activePartyId != 'manual';
    
    // VALIDIERUNG: Stelle sicher, dass party_dj_check() die lange ID liefert
    if (activePartyId != null && activePartyId != 'manual') {
      debugLog('✅ HistoryProvider: Aktive Party-ID (lange ID) von party_dj_check(): $activePartyId');
    } else {
      debugLog('⚠️ HistoryProvider: Keine aktive Party gefunden oder Party-ID ist "manual"');
    }

    // Session ist an Party gebunden, nicht an Musikerkennung
    // Sobald Party aktiv ist, muss Session laufen (auch wenn Musikerkennung aus ist)
    if (isPartyActive && activePartyId != null) {
      try {
        final partyDoc = await _firestore.collection('parties').doc(activePartyId).get();
        if (partyDoc.exists) {
          final partyData = partyDoc.data();
          final partyName = partyData?['party_name'] as String? ?? 'Unbenannte Party';
          
          // Prüfe ob Party gewechselt hat (vor dem Setzen von _currentPartyId)
          final partyChanged = _currentPartyId != activePartyId;
          
          // Setze Party-Info
          _currentPartyId = activePartyId;
          _currentPartyName = partyName;
          
          // Session starten/fortsetzen wenn Party aktiv ist (unabhängig von Musikerkennung)
          // Wenn Party gewechselt hat oder keine Session läuft: neue Session starten
          if (partyChanged || !_isRecording) {
            await _startSession(activePartyId, partyName);
          }
        }
      } catch (e) {
        debugLog('Fehler beim Laden der Party: $e');
      }
    } else {
      // Wenn Party nicht aktiv: Session stoppen und Party-Info löschen
      if (_isRecording) {
        await _stopSession();
      }
      _currentPartyId = null;
      _currentPartyName = null;
    }
  }

  /// Startet eine neue Session automatisch
  Future<void> _startSession(String partyId, String partyName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Stoppe alte Session falls vorhanden
    if (_currentSessionId != null && _currentSessionId != partyId) {
      await _stopSession();
    }

    if (partyId.isEmpty || partyId == 'manual') {
      debugLog('❌ HistoryProvider: Kann Session nicht starten – ungültige partyId: "$partyId"');
      return;
    }
    if (user.uid.isEmpty) {
      debugLog('❌ HistoryProvider: Kann Session nicht starten – user.uid ist leer.');
      return;
    }

    try {
      final sessionId = await MusicHistorySessionResolver.ensureSession(
        firestore: _firestore,
        djId: user.uid,
        partyId: partyId,
        partyName: partyName,
      );
      if (sessionId == null) {
        debugLog('❌ HistoryProvider: ensureSession lieferte null für Party $partyId');
        return;
      }
      _currentSessionId = sessionId;
      _currentPartyId = partyId;
      _currentPartyName = partyName;
      _isRecording = true;
      await ActivePartyService.applyMusicHistorySessionId(sessionId);
      debugLog(
        '✅ HistoryProvider: Session für Party $partyId: $_currentSessionId',
      );
    } catch (e) {
      debugLog('❌ Fehler beim Starten der Session: $e');
      debugLog('   Stack Trace: ${StackTrace.current}');
    }
  }

  /// Stoppt die aktuelle Session
  /// SICHERHEITS-PRÜFUNG: Stellt sicher, dass nur die Session der aktuellen Party-ID gestoppt wird
  Future<void> _stopSession() async {
    if (_currentSessionId == null) return;

    // SICHERHEITS-PRÜFUNG: Prüfe ob Session zur aktuellen Party gehört
    try {
      final sessionDoc = await _firestore.collection('music_history').doc(_currentSessionId).get();
      
      if (!sessionDoc.exists) {
        debugLog('⚠️ HistoryProvider: Session $_currentSessionId existiert nicht mehr');
        _currentSessionId = null;
        _currentPartyId = null;
        _currentPartyName = null;
        _isRecording = false;
        return;
      }
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>?;
      // Migration: Beim Auslesen party_id und partyId prüfen
      final sessionPartyId = sessionData?['party_id'] as String? ?? sessionData?['partyId'] as String?;
      
      // STRICT ISOLATION: Nur Session der aktuellen Party-ID stoppen
      if (_currentPartyId != null && sessionPartyId != _currentPartyId) {
        debugLog('🚫 PARTY-FILTER: Session $_currentSessionId gehört zu Party "$sessionPartyId", erwartet "$_currentPartyId" - Stoppen verweigert');
        // Setze nur die lokalen Variablen zurück, aber stoppe die Session nicht
        _currentSessionId = null;
        _currentPartyId = null;
        _currentPartyName = null;
        _isRecording = false;
        return;
      }
      
      // Session gehört zur aktuellen Party - sicher stoppen
      _isRecording = false;
      
      await _firestore.collection('music_history').doc(_currentSessionId).update({
        'endTime': FieldValue.serverTimestamp(),
        'isActive': false,
      });
      
      debugLog('✅ HistoryProvider: Session $_currentSessionId für Party $_currentPartyId gestoppt');
    } catch (e) {
      debugLog('❌ Fehler beim Stoppen der Session: $e');
    }

    _currentSessionId = null;
    _currentPartyId = null;
    _currentPartyName = null;
  }

  /// Behandelt einen neu erkannten Track
  void _handleNewTrack(Map<String, dynamic>? result) {
    if (!_shouldRecord() || result == null) return;

    final title = result['title'] as String? ?? '';
    final artist = result['artist'] as String? ?? '';
    
    // Nur speichern wenn Titel und Artist nicht leer sind
    if (title.isNotEmpty && artist.isNotEmpty && title != '-' && artist != '-') {
      final newTrack = TrackEntry(
        title: title,
        artist: artist,
        timestamp: DateTime.now(),
      );
      
      // Prüfe auf Duplikat
      _checkAndAddTrack(newTrack);
    }
  }

  /// Prüft gegen den **letzten** Track der aktuellen Session (Party-History):
  /// [normalizeTextForDuplicateCheck] + Durchschnitts-Ähnlichkeit ≥ 90 % und
  /// Abstand &lt; [HistoryLastTrackDedup.minGapBeforeRepeatSameSong] → kein Schreiben.
  /// Ablauf: zuerst nur letzten Eintrag laden → dann Dedup (ohne vorherige Keyword-/Settings-Arbeit).
  Future<void> _checkAndAddTrack(TrackEntry newTrack) async {
    if (_currentSessionId == null) return;

    // Verhindere gleichzeitige Verarbeitung (Lock)
    if (_isProcessingTrack) {
      debugLog('Track wird bereits verarbeitet, überspringe: ${newTrack.title} - ${newTrack.artist}');
      return;
    }

    _isProcessingTrack = true;

    try {
      final tracksRef = _firestore
          .collection('music_history')
          .doc(_currentSessionId)
          .collection('tracks');

      // 1) Zuerst nur den jüngsten Track — gleicher Song in kurzem Abstand (strengerer Match s. HistoryLastTrackDedup)
      final lastTrack = await _fetchNewestTrackForSession(tracksRef);

      if (lastTrack != null) {
        await DuplicateCheckService.ensurePartySettingsLoaded();
        final ignored = DuplicateCheckService.getCachedIgnoredKeywords();

        final minSim = DuplicateCheckService.getCachedDuplicateThresholdOrFallback();
        final analysis = HistoryLastTrackDedup.analyzeRapidRepeatOfLast(
          newTitle: newTrack.title,
          newArtist: newTrack.artist,
          lastTitle: lastTrack.title,
          lastArtist: lastTrack.artist,
          lastTimestamp: lastTrack.timestamp,
          ignoredKeywords: ignored,
          similarityMin: minSim,
        );

        if (analysis.shouldSkip) {
          debugLog(
            'History: Dublette ignoriert (${(analysis.avgSimilarity * 100).toStringAsFixed(0)}% eff. Match, '
            '${analysis.elapsedSinceLast.inSeconds}s seit letztem Eintrag < '
            '${HistoryLastTrackDedup.minGapBeforeRepeatSameSong.inSeconds}s) '
            '— „${newTrack.title}“ — „${newTrack.artist}“',
          );
          return;
        }
      }

      await addTrackToCurrentSession(newTrack);
    } catch (e) {
      debugLog('Fehler bei Duplikat-Prüfung: $e');
      await addTrackToCurrentSession(newTrack);
    } finally {
      _isProcessingTrack = false;
    }
  }

  /// Ein Firestore-Read für den neuesten Track (orderBy+limit), Fallback ohne Index.
  Future<TrackEntry?> _fetchNewestTrackForSession(
    CollectionReference<Map<String, dynamic>> tracksRef,
  ) async {
    try {
      final lastSnap = await tracksRef
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (lastSnap.docs.isEmpty) return null;
      return TrackEntry.fromFirestore(lastSnap.docs.first.data());
    } catch (e) {
      debugLog(
        '⚠️ HistoryProvider: letzter Track per orderBy nicht lesbar ($e), Fallback vollständiges Laden',
      );
      final all = await tracksRef.get(
        const GetOptions(source: Source.serverAndCache),
      );
      if (all.docs.isEmpty) return null;
      final sortedDocs = all.docs.toList()
        ..sort((a, b) {
          final dataA = a.data();
          final dataB = b.data();
          final tsA = dataA['timestamp'] as Timestamp?;
          final tsB = dataB['timestamp'] as Timestamp?;
          if (tsA == null && tsB == null) return 0;
          if (tsA == null) return 1;
          if (tsB == null) return -1;
          return tsB.compareTo(tsA);
        });
      return TrackEntry.fromFirestore(sortedDocs.first.data());
    }
  }

  /// Fügt einen Track zur aktuellen Session hinzu
  /// WICHTIG: Pfad ist music_history/{sessionId}/tracks (Top-Level-Collection, NICHT unter parties!)
  /// Erfolgs-Log erst nach Server-Quittung; Pfad- und Auth-Validierung vor dem Schreiben
  Future<void> addTrackToCurrentSession(TrackEntry track) async {
    // Pfad-Kontrolle: Leere/null sessionId oder party_id verhindern Schreiben
    if (_currentSessionId == null || _currentSessionId!.isEmpty) {
      debugLog('❌ HistoryProvider: ABBRUCH – sessionId ist null oder leer. Pfad music_history/{sessionId}/tracks kann nicht gebaut werden.');
      return;
    }
    if (_currentPartyId == null || _currentPartyId!.isEmpty || _currentPartyId == 'manual') {
      debugLog('❌ HistoryProvider: ABBRUCH – party_id ungültig ($_currentPartyId). Schreiben ohne gültige Party verhindert.');
      return;
    }

    final path = 'music_history/$_currentSessionId/tracks';
    final user = FirebaseAuth.instance.currentUser;

    // Berechtigungs-Check: Auth muss vorhanden sein (Firestore Rules prüfen djId == request.auth.uid)
    if (user == null || user.uid.isEmpty) {
      debugLog('❌ HistoryProvider: ABBRUCH – Kein eingeloggter User Firestore blockiert Schreibzugriff.');
      return;
    }

    try {
      final docRef = await _firestore
          .collection('music_history')
          .doc(_currentSessionId)
          .collection('tracks')
          .add(track.toFirestore())
          .catchError((e, st) {
        debugLog('❌ FIRESTORE ERROR (catchError): $e');
        debugLog('   → Vollständige Fehlermeldung: ${e.toString()}');
        if (e.toString().toLowerCase().contains('permission') || e.toString().toLowerCase().contains('denied')) {
          debugLog('   → PERMISSION_DENIED: Security Rules blockieren Schreibzugriff auf $path');
          debugLog('   → Regel prüft: request.auth.uid == session.djId. Auth/Session-Abgleich');
        }
        if (st != null) debugLog('   → Stack: $st');
        throw e;
      });

      // Erfolgsmeldung erst nach Empfang der Referenz (Write wurde quittiert)
      debugLog('✅ HistoryProvider: Track gespeichert (Write quittiert): ${track.title} - ${track.artist}');
      debugLog('   → Pfad: $path | Document-ID: ${docRef.id} | Party: $_currentPartyId');

      // Optional: Server-Verifikation (Prüfung, ob Dok auf Server angekommen ist)
      try {
        final serverDoc = await docRef.get(const GetOptions(source: Source.server));
        if (serverDoc.exists) {
          debugLog('   → SERVER BESTÄTIGT: Dokument auf Firestore-Server vorhanden.');
        } else {
          debugLog('   ⚠️ WARNUNG: Dokument nach Write auf Server nicht gefunden (evtl. Offline-Cache/Pending).');
        }
      } catch (verifyErr) {
        debugLog('   ⚠️ Server-Verifikation fehlgeschlagen: $verifyErr');
      }
    } catch (e, stackTrace) {
      debugLog('❌ HistoryProvider: Fehler beim Speichern des Tracks: $e');
      debugLog('   → Exakter Fehlergrund: ${e.toString()}');
      if (e.toString().toLowerCase().contains('permission') || e.toString().toLowerCase().contains('denied')) {
        debugLog('   → PERMISSION_DENIED: Cloud lehnt Zugriff ab. Prüfe Firestore Rules für music_history/{sessionId}/tracks.');
        // Optional: role_id aus users/{uid} laden (Firestore Rules prüfen role_id NICHT für music_history)
        try {
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          final roleId = userDoc.data()?['role_id'];
          debugLog('   → Debug: users.role_id (Rules: auth.uid + djId)');
        } catch (_) {}
      }
      debugLog('   → Stack: $stackTrace');
    }
  }

  /// Lädt die aktuelle aktive Party (nicht nur Session)
  /// Gibt Party-Info zurück, wenn eine Party aktiv ist
  Future<Map<String, String?>?> getCurrentParty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // Prüfe aktive Party direkt
    final partyInfo = await party_dj_check();
    final activePartyId = partyInfo['party_id'];
    
    if (activePartyId == null || activePartyId == 'manual') {
      return null;
    }

    try {
      final partyDoc = await _firestore.collection('parties').doc(activePartyId).get();
      if (partyDoc.exists) {
        final partyData = partyDoc.data();
        final partyName = partyData?['party_name'] as String? ?? 'Unbenannte Party';
        
        // Setze Party-Info
        _currentPartyId = activePartyId;
        _currentPartyName = partyName;
        
        return {
          'partyId': activePartyId,
          'partyName': partyName,
        };
      }
    } catch (e) {
      debugLog('Fehler beim Laden der Party: $e');
    }

    return null;
  }

  /// Lädt die aktuelle aktive Session
  Future<MusicSession?> getCurrentSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final query = await _firestore
          .collection('music_history')
          .where('djId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final session = MusicSession.fromFirestore(query.docs.first);
      _currentSessionId = session.id;
      
      // Lade Party-Info (Migration: party_id und partyId)
      final data = query.docs.first.data();
      final partyId = data['party_id'] as String? ?? data['partyId'] as String?;
      if (partyId != null) {
        _currentPartyId = partyId; // Wichtig: Setze _currentPartyId für getCurrentPartyTracks()
        final partyDoc = await _firestore.collection('parties').doc(partyId).get();
        if (partyDoc.exists) {
          final partyData = partyDoc.data();
          _currentPartyName = partyData?['party_name'] as String?;
        }
      }

      return session;
    } catch (e) {
      debugLog('Fehler beim Laden der aktuellen Session: $e');
      return null;
    }
  }

  /// Lädt alle Tracks der aktuellen Session
  Stream<List<TrackEntry>> getCurrentSessionTracks() {
    if (_currentSessionId == null) {
      return Stream.value([]);
    }

    // ✅ FIX: includeMetadataChanges entfernt - verhindert Endlosschleife durch Metadaten-Updates
    // orderBy entfernt - kann ohne Index blockieren, Sortierung erfolgt clientseitig
    return _firestore
        .collection('music_history')
        .doc(_currentSessionId)
        .collection('tracks')
        .snapshots() // ✅ Nur echte Dokument-Änderungen, keine Metadaten-Updates
        .map((snapshot) {
          final tracks = snapshot.docs
              .map((doc) {
                final docData = doc.data();
                if (docData == null) return null;
                return TrackEntry.fromFirestore(docData as Map<String, dynamic>);
              })
              .whereType<TrackEntry>() // Entferne null-Werte
              .toList();
          // Clientseitige Sortierung nach timestamp (descending)
          tracks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return tracks;
        });
  }

  /// Lädt alle Tracks der aktuellen Party (alle Sessions dieser Party)
  /// Gibt eine Liste von Maps zurück mit: 'track', 'sessionId', 'trackId'
  Stream<List<Map<String, dynamic>>> getCurrentPartyTracks() {
    return _tracksController.stream;
  }

  /// Aktualisiert den Tracks-Stream: hört auf music_history/{currentSessionId}/tracks.
  /// currentSessionId kommt aus ActivePartyService; bei Session-Wechsel schwenkt der Stream um.
  /// Tracks-Stream: docChanges mit Upsert pro trackId (kein Listen-clear) — weniger Flackern, keine Dubletten-Zeilen.
  void _updateTracksStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!_tracksController.isClosed) _tracksController.add([]);
      return;
    }

    _activePartyInfoSubscription?.cancel();
    _tracksSubscription?.cancel();
    _accumulatedTracksForStream.clear();
    _lastTracksSessionId = null;
    if (!_tracksController.isClosed) _tracksController.add([]);

    _activePartyInfoSubscription = ActivePartyService.getActivePartyInfoStream(user.uid).listen((ActivePartyInfo? info) {
      final sessionId = info?.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        _tracksSubscription?.cancel();
        _tracksSubscription = null;
        _accumulatedTracksForStream.clear();
        _lastTracksSessionId = null;
        if (!_tracksController.isClosed) _tracksController.add([]);
        return;
      }

      if (sessionId == _lastTracksSessionId) return;
      _tracksSubscription?.cancel();
      _accumulatedTracksForStream.clear();
      _lastTracksSessionId = sessionId;

      _tracksSubscription = _firestore
          .collection('music_history')
          .doc(sessionId)
          .collection('tracks')
          .snapshots()
          .listen((QuerySnapshot snapshot) {
        for (final change in snapshot.docChanges) {
          final doc = change.doc;
          final id = doc.id;
          if (change.type == DocumentChangeType.removed) {
            _accumulatedTracksForStream.removeWhere((e) => e['trackId'] == id);
            continue;
          }
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            final raw = doc.data();
            if (raw == null) continue;
            final data = raw as Map<String, dynamic>;
            _accumulatedTracksForStream.removeWhere((e) => e['trackId'] == id);
            _accumulatedTracksForStream.add({
              'track': TrackEntry.fromFirestore(data),
              'sessionId': sessionId,
              'trackId': id,
            });
          }
        }
        _accumulatedTracksForStream.sort((a, b) {
          final tA = a['track'] as TrackEntry;
          final tB = b['track'] as TrackEntry;
          return tB.timestamp.compareTo(tA.timestamp);
        });
        if (!_tracksController.isClosed) {
          _tracksController.add(List<Map<String, dynamic>>.from(_accumulatedTracksForStream));
        }
      }, onError: (e) {
        if (!_tracksController.isClosed) _tracksController.add([]);
      });
    }, onError: (e) {
      if (!_tracksController.isClosed) _tracksController.add([]);
    });
  }

  // ✅ EFFIZIENZ: Debouncing für _loadAllTracks() - verhindert zu häufige Aufrufe
  DateTime? _lastLoadAllTracksCall;
  static const Duration _loadAllTracksDebounceDuration = Duration(seconds: 2);

  /// Lädt alle Tracks neu (wird aufgerufen wenn sich Tracks ändern)
  /// ✅ EFFIZIENZ: Debouncing - max. 1x alle 2 Sekunden
  /// Zweistufiger Abruf: Erst mit orderBy, dann ohne orderBy als Fallback
  Future<void> _loadAllTracks({bool useOrderBy = true}) async {
    // ✅ Debouncing: Prüfe ob letzter Aufruf weniger als 2 Sekunden her ist
    final now = DateTime.now();
    if (_lastLoadAllTracksCall != null) {
      final timeSinceLastCall = now.difference(_lastLoadAllTracksCall!);
      if (timeSinceLastCall < _loadAllTracksDebounceDuration) {
        // Zu früh - ignoriere diesen Aufruf
        return;
      }
    }
    _lastLoadAllTracksCall = now;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!_tracksController.isClosed) _tracksController.add([]);
      return;
    }

    try {
      // Wenn wir bereits auf eine Session hören: nur diese Session nachladen (z. B. Retry)
      if (_lastTracksSessionId != null) {
        final tracksSnapshot = await _firestore
            .collection('music_history')
            .doc(_lastTracksSessionId)
            .collection('tracks')
            .get(const GetOptions(source: Source.serverAndCache));
        _accumulatedTracksForStream.clear();
        for (final trackDoc in tracksSnapshot.docs) {
          final trackData = trackDoc.data();
          if (trackData != null) {
            _accumulatedTracksForStream.add({
              'track': TrackEntry.fromFirestore(trackData as Map<String, dynamic>),
              'sessionId': _lastTracksSessionId,
              'trackId': trackDoc.id,
            });
          }
        }
        _accumulatedTracksForStream.sort((a, b) {
          final tA = a['track'] as TrackEntry;
          final tB = b['track'] as TrackEntry;
          return tB.timestamp.compareTo(tA.timestamp);
        });
        if (!_tracksController.isClosed) {
          _tracksController.add(List<Map<String, dynamic>>.from(_accumulatedTracksForStream));
        }
        return;
      }

      if (_currentPartyId == null) {
        if (!_tracksController.isClosed) _tracksController.add([]);
        return;
      }

      Query sessionsQuery = _firestore.collection('music_history');
      if (!_isAdminMode) {
        sessionsQuery = sessionsQuery.where('djId', isEqualTo: user.uid);
      }
      final sessionsSnapshot = await sessionsQuery
          .get(const GetOptions(source: Source.serverAndCache));

      // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still

      final allTracks = <Map<String, dynamic>>[];
      
      for (final sessionDoc in sessionsSnapshot.docs) {
        final sessionDataRaw = sessionDoc.data();
        final sessionData = sessionDataRaw is Map<String, dynamic>
            ? sessionDataRaw
            : <String, dynamic>{};
        final partyId = sessionData['party_id'] as String? ?? sessionData['partyId'] as String?;
        
        if (partyId != _currentPartyId) {
          continue;
        }
        
        // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
        
        try {
          QuerySnapshot tracksSnapshot;
          
          if (useOrderBy) {
            // STUFE 1: Versuche mit orderBy (sortiert)
            try {
              tracksSnapshot = await _firestore
                  .collection('music_history')
                  .doc(sessionDoc.id)
                  .collection('tracks')
                  .orderBy('timestamp', descending: true)
                  .get(const GetOptions(source: Source.serverAndCache));
              
              // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
            } catch (orderByError) {
              // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
              
              // STUFE 2: Fallback ohne orderBy
              tracksSnapshot = await _firestore
                  .collection('music_history')
                  .doc(sessionDoc.id)
                  .collection('tracks')
                  .get(const GetOptions(source: Source.serverAndCache));
              
              // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
            }
          } else {
            // Direkt ohne orderBy (Retry-Modus)
            tracksSnapshot = await _firestore
                .collection('music_history')
                .doc(sessionDoc.id)
                  .collection('tracks')
                  .get(const GetOptions(source: Source.serverAndCache));
            
            // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
          }
          
          for (final trackDoc in tracksSnapshot.docs) {
            final trackData = trackDoc.data();
            if (trackData != null) {
              final track = TrackEntry.fromFirestore(trackData as Map<String, dynamic>);
              allTracks.add({
                'track': track,
                'sessionId': sessionDoc.id,
                'trackId': trackDoc.id,
              });
            }
          }
        } catch (e) {
          // ✅ EFFIZIENZ: Fehler-Logs entfernt - Konsole bleibt still
          // Bei Fehler: Leere Liste für diese Session (nicht abbrechen)
        }
      }
      
      // Clientseitige Sortierung nach timestamp (descending) - auch wenn ohne orderBy geladen
      allTracks.sort((a, b) {
        final trackA = a['track'] as TrackEntry;
        final trackB = b['track'] as TrackEntry;
        return trackB.timestamp.compareTo(trackA.timestamp);
      });
      
      // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
      
      // Nur senden wenn Controller noch offen ist
      if (!_tracksController.isClosed) {
        _tracksController.add(allTracks);
      }
      // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
    } catch (e, stackTrace) {
      // ✅ EFFIZIENZ: Fehler-Logs entfernt - Konsole bleibt still
      
      // Retry ohne orderBy wenn noch nicht versucht
      if (useOrderBy) {
        // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
        await _loadAllTracks(useOrderBy: false);
      } else {
        // Auch Retry fehlgeschlagen - sende leere Liste
        if (!_tracksController.isClosed) {
          _tracksController.add([]);
        }
      }
    }
  }

  /// Löscht einen Track komplett aus der Datenbank
  /// SICHERHEITS-PRÜFUNG: Session muss zur aktuellen Party gehören (party_id aus Session = ActivePartyService.partyId)
  Future<bool> deleteTrack(String sessionId, String trackId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final sessionDoc = await _firestore
          .collection('music_history')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        debugLog('❌ Session nicht gefunden: $sessionId');
        return false;
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>?;
      // Feld-Konsistenz: immer party_id (mit Unterstrich) aus dem Session-Dokument lesen
      final sessionPartyId = sessionData?['party_id'] as String? ?? sessionData?['partyId'] as String?;

      final activeParty = await ActivePartyService.getActivePartyInfo(user.uid);
      final expectedPartyId = activeParty?.partyId;

      if (expectedPartyId == null || expectedPartyId.isEmpty) {
        debugLog('❌ Keine aktive Party (ActivePartyService) – Löschen verweigert');
        return false;
      }
      if (sessionPartyId != expectedPartyId) {
        debugLog('🚫 PARTY-FILTER: Session $sessionId gehört zu Party "$sessionPartyId", erwartet "$expectedPartyId" - Löschen verweigert');
        return false;
      }

      await _firestore
          .collection('music_history')
          .doc(sessionId)
          .collection('tracks')
          .doc(trackId)
          .delete();
      debugLog('✅ Track gelöscht: Session $sessionId, Track $trackId');
      // UI wird über den tracks-Snapshots-Stream aktualisiert (DocumentChangeType.removed)

      return true;
    } catch (e) {
      debugLog('❌ Fehler beim Löschen des Tracks: $e');
      return false;
    }
  }
  
  /// Löscht eine komplette Session (Playlist) mit allen Tracks
  /// SICHERHEITS-PRÜFUNG: Nur Sessions der aktuellen Party können gelöscht werden
  Future<bool> deleteSession(String sessionId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugLog('❌ Kein User eingeloggt');
        return false;
      }
      
      // Prüfe, ob die Session dem User gehört
      final sessionDoc = await _firestore
          .collection('music_history')
          .doc(sessionId)
          .get();
      
      if (!sessionDoc.exists) {
        debugLog('❌ Session nicht gefunden: $sessionId');
        return false;
      }
      
      final sessionData = sessionDoc.data();
      final djId = sessionData?['djId'] as String?;
      // Feld-Konsistenz: party_id (mit Unterstrich) aus dem Session-Dokument
      final sessionPartyId = sessionData?['party_id'] as String? ?? sessionData?['partyId'] as String?;

      if (djId != user.uid) {
        debugLog('❌ Session gehört nicht zum aktuellen User');
        return false;
      }

      final activeParty = await ActivePartyService.getActivePartyInfo(user.uid);
      final expectedPartyId = activeParty?.partyId;
      if (expectedPartyId == null || expectedPartyId.isEmpty) {
        debugLog('❌ Keine aktive Party (ActivePartyService) – Löschen verweigert');
        return false;
      }
      if (sessionPartyId != expectedPartyId) {
        debugLog('🚫 PARTY-FILTER: Session $sessionId gehört zu Party "$sessionPartyId", erwartet "$expectedPartyId" - Löschen verweigert');
        return false;
      }

      // Lösche alle Tracks der Session zuerst
      final tracksSnapshot = await _firestore
          .collection('music_history')
          .doc(sessionId)
          .collection('tracks')
          .get();
      
      final batch = _firestore.batch();
      for (final trackDoc in tracksSnapshot.docs) {
        batch.delete(trackDoc.reference);
      }
      await batch.commit();
      
      // Lösche die Session selbst
      await _firestore
          .collection('music_history')
          .doc(sessionId)
          .delete();
      
      debugLog('✅ Session gelöscht: $sessionId (${tracksSnapshot.docs.length} Tracks)');
      
      return true;
    } catch (e) {
      debugLog('❌ Fehler beim Löschen der Session: $e');
      return false;
    }
  }

  /// Lädt alle vergangenen Sessions des DJs
  Stream<List<MusicSession>> getArchivedSessions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    Query query = _firestore.collection('music_history');
    if (!_isAdminMode) {
      query = query.where('djId', isEqualTo: user.uid);
    }
    return query
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs
              .map((doc) => MusicSession.fromFirestore(doc))
              .where((session) => !session.isActive) // Clientseitig filtern
              .toList();
          // Clientseitig sortieren nach startTime
          sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
          return sessions;
        });
  }

  /// Lädt alle Tracks einer Session
  Future<List<Map<String, dynamic>>> getSessionTracks(String sessionId) async {
    try {
      // WICHTIG: orderBy entfernt - kann ohne Index blockieren
      // Sortierung erfolgt clientseitig
      final snapshot = await _firestore
          .collection('music_history')
          .doc(sessionId)
          .collection('tracks')
          .get(const GetOptions(source: Source.serverAndCache));

      final tracks = snapshot.docs
          .map((doc) {
                final docData = doc.data();
                if (docData == null) return null;
                return {
                  'track': TrackEntry.fromFirestore(docData as Map<String, dynamic>),
                  'trackId': doc.id,
                };
              })
          .whereType<Map<String, dynamic>>() // Entferne null-Werte
          .toList();
      
      // Clientseitige Sortierung nach timestamp (descending)
      tracks.sort((a, b) {
        final trackA = a['track'] as TrackEntry;
        final trackB = b['track'] as TrackEntry;
        return trackB.timestamp.compareTo(trackA.timestamp);
      });
      
      return tracks;
    } catch (e) {
      debugLog('Fehler beim Laden der Session-Tracks: $e');
      return [];
    }
  }

  /// Retry-Methode: Lädt Tracks ohne orderBy (wird nach Timeout aufgerufen)
  void retryLoadTracksWithoutOrderBy() {
    // ✅ EFFIZIENZ: Debug-Logs entfernt - Konsole bleibt still
    _loadAllTracks(useOrderBy: false);
  }

  /// Prüft ob aktuell eine Session aktiv ist
  bool get isRecording => _isRecording && _currentSessionId != null;

  /// Gibt die aktuelle Session-ID zurück
  String? get currentSessionId => _currentSessionId;

  /// Gibt den Partynamen der aktuellen Session zurück
  String? get currentPartyName => _currentPartyName;

  /// Stream für aktive Party (für UI)
  Stream<Map<String, String?>?> getCurrentPartyStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    Query partiesQuery = _firestore.collection('parties');
    if (!_isAdminMode) {
      partiesQuery = partiesQuery.where('created_by', isEqualTo: user.uid);
    }
    return partiesQuery
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          
          // Finde aktive Party
          for (final partyDoc in snapshot.docs) {
            final dataRaw = partyDoc.data();
            final data = dataRaw is Map<String, dynamic>
                ? dataRaw
                : <String, dynamic>{};
            final startTimestamp = data['start_date'] as Timestamp?;
            final endTimestamp = data['end_date'] as Timestamp?;

            if (startTimestamp != null && endTimestamp != null) {
              final startDate = startTimestamp.toDate();
              final endDate = endTimestamp.toDate();

              if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
                final partyName = data['party_name'] as String? ?? 'Unbenannte Party';
                _currentPartyId = partyDoc.id;
                _currentPartyName = partyName;
                return {
                  'partyId': partyDoc.id,
                  'partyName': partyName,
                };
              }
            }
          }
          
          // Keine aktive Party
          _currentPartyId = null;
          _currentPartyName = null;
          return null;
        });
  }

  /// Bereinigt Ressourcen
  void dispose() {
    _shazamSubscription?.cancel();
    _statusSubscription?.cancel();
    _partiesSubscription?.cancel();
    _activePartyInfoSubscription?.cancel();
    _tracksSubscription?.cancel();
    _tracksController.close();
    _shazamSubscription = null;
    _statusSubscription = null;
    _partiesSubscription = null;
    _activePartyInfoSubscription = null;
    _tracksSubscription = null;
  }
}
