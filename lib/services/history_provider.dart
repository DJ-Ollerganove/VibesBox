import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/playlist_model.dart';
import '../services/active_party_service.dart';
import '../services/duplicate_check_service.dart';
import '../services/open_wishes_visibility_service.dart';
import '../services/shazam_service.dart';
import '../services/user_service.dart';
import '../utils/party_helper.dart';
import '../utils/text_utils.dart';
import '../utils/debug_log.dart';
import 'app_diagnostic_log_service.dart';
import 'music_history_secure_service.dart';
import 'history_save_log_service.dart';

/// Service für Musik-History-Management
/// Lauscht passiv auf Musikerkennung und speichert erkannte Songs automatisch
/// Session ist an die aktive Party gebunden, nicht an den Musikerkennungs-Schalter
class HistoryProvider {
  static final HistoryProvider _instance = HistoryProvider._internal();
  factory HistoryProvider() => _instance;
  HistoryProvider._internal();

  /// Inkrementiert nach jedem erfolgreichen Track-Write — History-Tab lauscht darauf.
  static final ValueNotifier<int> tracksRevision = ValueNotifier(0);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  void Function()? _storedSessionPartyListener;
  void Function()? _visibilityPartyListener;
  StreamSubscription<ActivePartyInfo?>? _activePartyInfoSubscription;
  StreamSubscription<QuerySnapshot>? _tracksSubscription;
  final StreamController<List<Map<String, dynamic>>> _tracksController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final List<Map<String, dynamic>> _accumulatedTracksForStream = [];
  String? _lastTracksSessionId;

  /// RAM-Deckel für den Live-History-Stream (Firestore/DB bleiben vollständig).
  static const int _maxAccumulatedTracksInRam = 600;

  void _trimAccumulatedTracksRam() {
    if (_accumulatedTracksForStream.length <= _maxAccumulatedTracksInRam) {
      return;
    }
    _accumulatedTracksForStream.removeRange(
      _maxAccumulatedTracksInRam,
      _accumulatedTracksForStream.length,
    );
  }

  String? _currentSessionId;
  String? _currentPartyId;
  String? _currentPartyName;
  bool _isRecording = false;
  bool _isProcessingTrack = false; // Lock um Race Conditions zu vermeiden
  bool _recordSaveInFlight = false;
  /// Temporärer Session-Speicher: zuletzt **in die DB geschriebener** Song (normalisierter Schlüssel).
  /// Gleicher Song → kein erneuter Write; anderer Song → Write und Slot ersetzen. Kein Firestore-Read pro Treffer.
  String? _lastDbWriteScopeSessionId;
  String? _lastDbWrittenNormKey;
  bool _isHistoryListening = false; // ✅ EFFIZIENZ: Flag ob History-Streams aktiv sind
  // Caching entfernt: Threshold wird jetzt bei jedem Scan frisch aus der DB geladen
  bool get _isAdminMode => AppConfig.isAdminRole(UserService().currentUser.value);

  bool _initialized = false;
  String? _partiesStreamBoundUid;

  /// Initialisiert den Provider und beginnt mit dem Monitoring.
  /// Kern-Listener (Shazam) nur einmal; Party-Stream pro Firebase-UID (erneut bei Account-Wechsel).
  void initialize() {
    final user = FirebaseAuth.instance.currentUser;

    if (_partiesStreamBoundUid != user?.uid) {
      _partiesStreamBoundUid = user?.uid;
      if (_storedSessionPartyListener != null) {
        ActivePartyService.storedSessionNotifier
            .removeListener(_storedSessionPartyListener!);
        _storedSessionPartyListener = null;
      }
      if (user != null) {
        void syncFromStoredSession() {
          unawaited(_checkAndUpdateSession());
        }

        _storedSessionPartyListener = syncFromStoredSession;
        ActivePartyService.storedSessionNotifier
            .addListener(_storedSessionPartyListener!);
        syncFromStoredSession();
      } else {
        _currentPartyId = null;
        _currentPartyName = null;
      }
    }

    if (_visibilityPartyListener != null) {
      OpenWishesVisibilityService.visibilityNotifier
          .removeListener(_visibilityPartyListener!);
    }
    _visibilityPartyListener = () {
      unawaited(_checkAndUpdateSession());
    };
    OpenWishesVisibilityService.visibilityNotifier
        .addListener(_visibilityPartyListener!);

    _checkAndUpdateSession();

    if (!_tracksController.isClosed) {
      _tracksController.add([]);
    }

    _initialized = true;
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

  /// Party-ID für Speichern: Hint → Visibility → Stored → Heartbeat → party_dj_check.
  Future<String?> _resolvePartyIdForMusicHistory({String? hint}) async {
    if (hint != null && hint.isNotEmpty && hint != 'manual') {
      return hint;
    }

    final fromVisibility = OpenWishesVisibilityService.resolveDjWishPartyId();
    if (fromVisibility != null &&
        fromVisibility.isNotEmpty &&
        fromVisibility != 'manual') {
      return fromVisibility;
    }

    final stored = ActivePartyService.getStoredSession()?.partyId;
    if (stored != null && stored.isNotEmpty && stored != 'manual') {
      return stored;
    }

    final heartbeat = ActivePartyService.currentPartyId;
    if (heartbeat != null &&
        heartbeat.isNotEmpty &&
        heartbeat != 'manual') {
      return heartbeat;
    }

    final partyInfo = await party_dj_check();
    final fromCheck = partyInfo['party_id'];
    if (fromCheck != null &&
        fromCheck.isNotEmpty &&
        fromCheck != 'manual') {
      return fromCheck;
    }
    return null;
  }

  /// Legt eine neue music_history-Session an (djId = auth.uid, schreibbar).
  Future<String?> _createFreshSessionForParty(String partyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || partyId.isEmpty || partyId == 'manual') {
      return null;
    }

    try {
      final partyDoc =
          await _firestore.collection('parties').doc(partyId).get();
      if (!partyDoc.exists) {
        diagLog('HISTORY', 'Session: Party-Dokument fehlt ($partyId)');
        return null;
      }
      final partyName =
          (partyDoc.data()?['party_name'] as String?) ?? 'Party';
      final sessionRef = await _firestore.collection('music_history').add({
        'djId': user.uid,
        'party_id': partyId,
        'partyName': partyName,
        'startTime': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      _currentSessionId = sessionRef.id;
      _currentPartyId = partyId;
      _currentPartyName = partyName;
      _isRecording = true;
      diagLog('HISTORY', 'Session neu ${sessionRef.id} party=$partyId');
      return sessionRef.id;
    } catch (e) {
      diagLog('HISTORY', 'Session create FEHLER: $e party=$partyId');
      debugLog('History._createFreshSessionForParty: $e');
      return null;
    }
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

    final activePartyId = await _resolvePartyIdForMusicHistory();
    final isPartyActive =
        activePartyId != null && activePartyId.isNotEmpty;

    if (isPartyActive) {
      debugLog(
        '✅ HistoryProvider: Aktive Party-ID für Session: $activePartyId',
      );
    } else {
      debugLog('⚠️ HistoryProvider: Keine aktive Party für History-Session');
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

    final effectiveDjId = ActivePartyService.effectiveDjIdForCurrentUser();
    if (effectiveDjId.isEmpty) return;

    if (_currentSessionId != null && _currentPartyId != partyId) {
      await _stopSession();
    }

    try {
      var existingSession = await _firestore
          .collection('music_history')
          .where('party_id', isEqualTo: partyId)
          .limit(5)
          .get();

      if (existingSession.docs.isEmpty) {
        existingSession = await _firestore
            .collection('music_history')
            .where('partyId', isEqualTo: partyId)
            .limit(5)
            .get();
      }

      if (existingSession.docs.isNotEmpty) {
        final owned = existingSession.docs.where((doc) {
          final dj = doc.data()['djId'] as String?;
          // Nur eigene Session — sonst Track-Write (session.djId == auth.uid) scheitert.
          return dj == user.uid;
        }).toList();
        if (owned.isNotEmpty) {
          _currentSessionId = owned.first.id;
          _currentPartyId = partyId;
          _currentPartyName = partyName;
          _isRecording = true;
          debugLog(
            '✅ HistoryProvider: Wiederverwendung Session $_currentSessionId für $partyId',
          );
          return;
        }
      }
    } catch (e) {
      debugLog('Fehler beim Prüfen existierender Session: $e');
    }

    // Kein Dokument für diese Party — neu anlegen
    try {
      if (partyId.isEmpty || partyId == 'manual') {
        debugLog('❌ HistoryProvider: Kann Session nicht starten – ungültige partyId: "$partyId"');
        return;
      }

      if (user.uid.isEmpty) {
        debugLog('❌ HistoryProvider: Kann Session nicht starten – user.uid ist leer.');
        return;
      }
      
      debugLog('✅ HistoryProvider: Starte Session für Party-ID (lange ID): $partyId');
      
      final sessionData = {
        'djId': user.uid,
        'party_id': partyId,
        'partyName': partyName,
        'startTime': FieldValue.serverTimestamp(),
        'isActive': true,
      };
      
      debugLog('📝 HistoryProvider: Session-Daten: $sessionData');
      
      final sessionRef = await _firestore.collection('music_history').add(sessionData).catchError((e) {
        debugLog('❌ FIRESTORE ERROR (Session create): $e');
        debugLog('   → Exakter Fehlergrund: ${e.toString()}');
        if (e.toString().toLowerCase().contains('permission') || e.toString().toLowerCase().contains('denied')) {
          debugLog('   → PERMISSION_DENIED: Security Rules blockieren Erstellung in music_history (Top-Level)');
          debugLog('   → Regel prüft: request.auth != null && request.resource.data.djId == request.auth.uid');
        }
        throw e;
      });

      _currentSessionId = sessionRef.id;
      _currentPartyId = partyId;
      _currentPartyName = partyName;
      _isRecording = true;
      
      debugLog('✅ HistoryProvider: Session erstellt - Session-ID: $_currentSessionId, Party-ID: $_currentPartyId');
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

  /// Session für [partyId] sicherstellen (Schreiben erkannter Songs + History-Anzeige).
  Future<void> ensureSessionForParty(String partyId) async {
    if (!_initialized) {
      initialize();
    }
    if (partyId.isEmpty || partyId == 'manual') return;
    if (_currentPartyId == partyId &&
        _currentSessionId != null &&
        _currentSessionId!.isNotEmpty) {
      return;
    }
    try {
      final partyDoc =
          await _firestore.collection('parties').doc(partyId).get();
      if (!partyDoc.exists) return;
      final partyName =
          (partyDoc.data()?['party_name'] as String?) ?? 'Unbenannte Party';
      _currentPartyId = partyId;
      _currentPartyName = partyName;
      await _startSession(partyId, partyName);
    } catch (e) {
      debugLog('HistoryProvider.ensureSessionForParty: $e');
    }
  }

  /// Öffentlicher Einstieg: erkannten Song in music_history/{session}/tracks speichern.
  /// true = in der History (neu oder schon vorhanden), false = Write nicht gelungen.
  Future<bool> recordRecognizedTrack({
    required String title,
    required String artist,
    String? partyId,
    double? bpm,
    String? camelot,
    String? key,
    int? durationSec,
    String? source,
  }) async {
    if (!_initialized) {
      initialize();
    }

    final trimmedTitle = title.trim();
    final trimmedArtist = artist.trim();
    HistorySaveLogService.log(
      'START',
      'title=$trimmedTitle artist=$trimmedArtist hintParty=${partyId ?? "null"}',
    );

    if (ShazamService.formatRecognizedTrackLabel(trimmedTitle, trimmedArtist) ==
        null) {
      HistorySaveLogService.log('SKIP', 'Ungültiger Song-Payload');
      return false;
    }

    if (_recordSaveInFlight) {
      HistorySaveLogService.log('SKIP', 'Paralleler Write blockiert');
      return false;
    }
    _recordSaveInFlight = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      HistorySaveLogService.log(
        'AUTH',
        user == null ? 'NULL' : 'uid=${user.uid}',
      );
      if (user == null) {
        return false;
      }

      final resolvedPartyId =
          await _resolvePartyIdForMusicHistory(hint: partyId);
      HistorySaveLogService.log(
        'PARTY',
        resolvedPartyId ?? 'NULL (keine Party gefunden)',
      );
      if (resolvedPartyId == null ||
          resolvedPartyId.isEmpty ||
          resolvedPartyId == 'manual') {
        return false;
      }

      _currentPartyId = resolvedPartyId;

      final saveTitle = trimmedTitle.isEmpty ? '-' : trimmedTitle;
      final saveArtist = trimmedArtist.isEmpty ? '-' : trimmedArtist;

      await DuplicateCheckService.ensurePartySettingsLoaded();
      final ignored = DuplicateCheckService.getCachedIgnoredKeywords();
      final normKey = _songNormKeyForSessionDedup(
        TrackEntry(
          title: saveTitle,
          artist: saveArtist,
          timestamp: DateTime.now(),
        ),
        ignored,
      );

      var sessionId = _currentSessionId;
      if (sessionId == null ||
          sessionId.isEmpty ||
          _currentPartyId != resolvedPartyId) {
        sessionId = await _ensureWritableSessionIdForParty(resolvedPartyId);
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        await _hydrateLastDbWrittenNormKey(sessionId);
      }

      if (normKey.isNotEmpty && _lastDbWrittenNormKey == normKey) {
        HistorySaveLogService.log('SKIP', 'Gleicher Song wie zuletzt');
        return true;
      }

      try {
        final result = await MusicHistorySecureService.saveTrack(
          partyId: resolvedPartyId,
          title: saveTitle,
          artist: saveArtist,
          bpm: bpm,
          camelot: camelot,
          key: key,
          durationSec: durationSec,
          source: source,
        );
        _currentSessionId = result.sessionId;
        _currentPartyId = resolvedPartyId;
        _isRecording = true;
        if (normKey.isNotEmpty) {
          _lastDbWrittenNormKey = normKey;
        }
        await ActivePartyService.applyMusicHistorySessionId(
          partyId: resolvedPartyId,
          sessionId: result.sessionId,
        );
        tracksRevision.value++;
        HistorySaveLogService.log(
          'OK',
          'Callable → session=${result.sessionId} track=${result.trackId}',
        );
        return true;
      } catch (e) {
        HistorySaveLogService.log(
          'CALLABLE_FALLBACK',
          'Client-Write versuchen: $e',
        );
      }

      if (sessionId == null || sessionId.isEmpty) {
        sessionId = await _ensureWritableSessionIdForParty(resolvedPartyId);
      }
      sessionId ??= await _createFreshSessionForParty(resolvedPartyId);
      HistorySaveLogService.log('SESSION', sessionId ?? 'NULL');
      if (sessionId == null || sessionId.isEmpty) {
        return false;
      }

      final track = TrackEntry(
        title: saveTitle,
        artist: saveArtist,
        timestamp: DateTime.now(),
        bpm: bpm,
        camelot: camelot,
        key: key,
        durationSec: durationSec,
        source: source,
      );
      return await _checkAndAddTrack(
        track,
        sessionId: sessionId,
        partyId: resolvedPartyId,
      );
    } finally {
      _recordSaveInFlight = false;
    }
  }

  /// Session mit djId == auth.uid (Firestore-Schreibrechte für tracks).
  Future<String?> _ensureWritableSessionIdForParty(String partyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || partyId.isEmpty || partyId == 'manual') {
      return null;
    }

    try {
      for (final partyField in ['party_id', 'partyId']) {
        var snapshot = await _firestore
            .collection('music_history')
            .where('djId', isEqualTo: user.uid)
            .where(partyField, isEqualTo: partyId)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final id = snapshot.docs.first.id;
          _currentSessionId = id;
          _currentPartyId = partyId;
          _isRecording = true;
          return id;
        }
      }
    } catch (e) {
      debugLog('History._ensureWritableSessionIdForParty lookup: $e');
    }

    await ensureSessionForParty(partyId);
    return _currentSessionId ?? await _createFreshSessionForParty(partyId);
  }

  /// Schreibt nur, wenn der Treffer **nicht** dem zuletzt in die DB geschriebenen Song entspricht
  /// ([DuplicateCheckService]-Normalisierung wie bisher). Sonst nur Log — **kein** Firestore-Read pro Scan.
  Future<bool> _checkAndAddTrack(
    TrackEntry newTrack, {
    required String sessionId,
    required String partyId,
  }) async {
    if (sessionId.isEmpty) return false;

    // Verhindere gleichzeitige Verarbeitung (Lock)
    if (_isProcessingTrack) {
      debugLog('Track wird bereits verarbeitet, überspringe: ${newTrack.title} - ${newTrack.artist}');
      return false;
    }

    _isProcessingTrack = true;

    try {
      _syncLastDbWriteScopeForSession(sessionId);
      await DuplicateCheckService.ensurePartySettingsLoaded();
      final ignored = DuplicateCheckService.getCachedIgnoredKeywords();
      await _hydrateLastDbWrittenNormKey(sessionId);
      final normKey = _songNormKeyForSessionDedup(newTrack, ignored);

      if (normKey.isNotEmpty && _lastDbWrittenNormKey == normKey) {
        debugLog(
          'History: gleicher Song wie zuletzt in DB geschrieben — überspringe Write '
          '— „${newTrack.title}“ — „${newTrack.artist}“',
        );
        return true;
      }

      final written = await addTrackToSession(
        sessionId: sessionId,
        partyId: partyId,
        track: newTrack,
      );
      if (written && normKey.isNotEmpty) {
        _lastDbWrittenNormKey = normKey;
      }
      return written;
    } catch (e) {
      debugLog('Fehler bei History-Write-Vorbereitung: $e');
      await DuplicateCheckService.ensurePartySettingsLoaded();
      final ignored = DuplicateCheckService.getCachedIgnoredKeywords();
      final normKey = _songNormKeyForSessionDedup(newTrack, ignored);
      if (normKey.isNotEmpty && _lastDbWrittenNormKey == normKey) {
        return true;
      }
      final written = await addTrackToSession(
        sessionId: sessionId,
        partyId: partyId,
        track: newTrack,
      );
      if (written && normKey.isNotEmpty) {
        _lastDbWrittenNormKey = normKey;
      }
      return written;
    } finally {
      _isProcessingTrack = false;
    }
  }

  void _syncLastDbWriteScopeForSession(String sessionId) {
    if (sessionId.isEmpty) return;
    if (_lastDbWriteScopeSessionId != sessionId) {
      _lastDbWriteScopeSessionId = sessionId;
      _lastDbWrittenNormKey = null;
    }
  }

  /// Nach App-Neustart: letzten History-Track der Session laden, damit
  /// derselbe Song nicht noch einmal geschrieben wird.
  Future<void> _hydrateLastDbWrittenNormKey(String sessionId) async {
    if (sessionId.isEmpty) return;
    if (_lastDbWriteScopeSessionId == sessionId &&
        _lastDbWrittenNormKey != null) {
      return;
    }
    try {
      final snap = await _firestore
          .collection('music_history')
          .doc(sessionId)
          .collection('tracks')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      _syncLastDbWriteScopeForSession(sessionId);
      if (snap.docs.isEmpty) {
        HistorySaveLogService.log('HYDRATE', 'session=$sessionId leer');
        return;
      }
      await DuplicateCheckService.ensurePartySettingsLoaded();
      final ignored = DuplicateCheckService.getCachedIgnoredKeywords();
      final last = TrackEntry.fromFirestore(snap.docs.first.data());
      final key = _songNormKeyForSessionDedup(last, ignored);
      _lastDbWrittenNormKey = key.isEmpty ? null : key;
      HistorySaveLogService.log(
        'HYDRATE',
        'session=$sessionId last="${last.title}" — "${last.artist}"',
      );
    } catch (e) {
      debugLog('History._hydrateLastDbWrittenNormKey: $e');
    }
  }

  String _songNormKeyForSessionDedup(TrackEntry t, List<String> ignored) {
    final nt = normalizeTextForDuplicateCheck(t.title, ignored);
    final na = normalizeTextForDuplicateCheck(t.artist, ignored);
    if (nt.isEmpty && na.isEmpty) return '';
    return '$nt\x1f$na';
  }

  /// Fügt einen Track zur Session hinzu (explizite IDs — kein Race mit Session-Stop).
  Future<bool> addTrackToSession({
    required String sessionId,
    required String partyId,
    required TrackEntry track,
    bool allowSessionRetry = true,
  }) async {
    if (sessionId.isEmpty) {
      debugLog('❌ HistoryProvider: ABBRUCH – sessionId leer.');
      return false;
    }
    if (partyId.isEmpty || partyId == 'manual') {
      debugLog('❌ HistoryProvider: ABBRUCH – party_id ungültig ($partyId).');
      return false;
    }

    final path = 'music_history/$sessionId/tracks';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      debugLog('❌ HistoryProvider: ABBRUCH – Kein eingeloggter User.');
      return false;
    }

    try {
      Future<DocumentReference<Map<String, dynamic>>> write(bool extras) {
        return _firestore
            .collection('music_history')
            .doc(sessionId)
            .collection('tracks')
            .add(track.toFirestore(includeMixMeta: extras));
      }

      DocumentReference<Map<String, dynamic>> docRef;
      try {
        docRef = await write(true);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('permission') || msg.contains('denied')) {
          docRef = await write(false);
        } else {
          rethrow;
        }
      }

      debugLog('✅ HistoryProvider: Track gespeichert: ${track.title} - ${track.artist}');
      debugLog('   → Pfad: $path | Document-ID: ${docRef.id} | Party: $partyId');
      diagLog(
        'HISTORY',
        'Track OK: ${track.title} — ${track.artist} → $path',
      );
      tracksRevision.value++;
      return true;
    } catch (e, stackTrace) {
      final err = e.toString().toLowerCase();
      if (allowSessionRetry &&
          (err.contains('permission') || err.contains('denied'))) {
        diagLog('HISTORY', 'Track PERMISSION_DENIED session=$sessionId — neue Session');
        final freshSessionId = await _createFreshSessionForParty(partyId);
        if (freshSessionId != null && freshSessionId != sessionId) {
          return addTrackToSession(
            sessionId: freshSessionId,
            partyId: partyId,
            track: track,
            allowSessionRetry: false,
          );
        }
      }
      debugLog('❌ HistoryProvider: Fehler beim Speichern: $e');
      debugLog('   → Stack: $stackTrace');
      diagLog('HISTORY', 'Track FEHLER: $e party=$partyId session=$sessionId');
      return false;
    }
  }

  /// Fügt einen Track zur aktuellen Session hinzu
  Future<bool> addTrackToCurrentSession(TrackEntry track) async {
    if (_currentSessionId == null || _currentSessionId!.isEmpty) {
      debugLog('❌ HistoryProvider: ABBRUCH – sessionId ist null oder leer.');
      return false;
    }
    if (_currentPartyId == null || _currentPartyId!.isEmpty || _currentPartyId == 'manual') {
      debugLog('❌ HistoryProvider: ABBRUCH – party_id ungültig ($_currentPartyId).');
      return false;
    }
    return addTrackToSession(
      sessionId: _currentSessionId!,
      partyId: _currentPartyId!,
      track: track,
    );
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
        _trimAccumulatedTracksRam();
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
        _trimAccumulatedTracksRam();
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
    if (_storedSessionPartyListener != null) {
      ActivePartyService.storedSessionNotifier
          .removeListener(_storedSessionPartyListener!);
      _storedSessionPartyListener = null;
    }
    if (_visibilityPartyListener != null) {
      OpenWishesVisibilityService.visibilityNotifier
          .removeListener(_visibilityPartyListener!);
      _visibilityPartyListener = null;
    }
    _activePartyInfoSubscription?.cancel();
    _tracksSubscription?.cancel();
    _tracksController.close();
    _activePartyInfoSubscription = null;
    _tracksSubscription = null;
  }
}
