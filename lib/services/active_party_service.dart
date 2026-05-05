import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../helpers/security_helper.dart';
import 'user_service.dart';
import '../utils/debug_log.dart';
import '../utils/party_helper.dart';

/// Ergebnis-Objekt für aktive Party-Informationen
class ActivePartyInfo {
  final String partyId;
  final String? partyCode;
  final String? sessionId;
  final String? partyName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;

  const ActivePartyInfo({
    required this.partyId,
    this.partyCode,
    this.sessionId,
    this.partyName,
    this.startDate,
    this.endDate,
    this.status,
  });
}

/// Service zum Finden der aktiven Party für einen DJ
/// Verwaltet Heartbeat, SharedPreferences-Cache und Auto-Resume
class ActivePartyService {
  static Map<String, dynamic> _sanitizeWriteMap(Map<String, dynamic> map) =>
      SecurityHelper.sanitizeMap(map);
  static const String _prefsKeyPartyId = 'active_party_id';
  static const String _prefsKeyPartyCode = 'active_party_code';
  static const String _prefsKeyLastHeartbeat = 'last_heartbeat_timestamp';
  static const String _prefsKeyLastActivePartyId = 'last_active_party_id';
  static const String _prefsKeyPartyName = 'session_party_name';
  static const String _prefsKeyStartDate = 'session_start_date_millis';
  static const String _prefsKeyEndDate = 'session_end_date_millis';
  static const String _prefsKeyPartyStatus = 'session_party_status';
  static Timer? _heartbeatTimer;
  static StreamController<ActivePartyInfo?>? _activePartyController;
  static StreamSubscription<ActivePartyInfo?>? _partyInfoSubscription;
  static String?
  _currentHeartbeatSessionId; // Verhindert mehrfaches Starten des Heartbeats für dieselbe Session
  static String?
  _currentHeartbeatPartyId; // Aktuelle Party-ID für die der Heartbeat läuft (lange ID)
  static String?
  _currentHeartbeatDjId; // Aktuelle DJ-ID für die der Heartbeat läuft
  /// Letzter vom Stream emittierter Wert – für Replay bei neuem Abonnenten (BehaviorSubject-Logik ohne rxdart)
  static ActivePartyInfo? _lastEmittedPartyInfo;

  /// Zentrale gespeicherte Session für die UI: Wenn gesetzt, ist die Party aktiv (kein Zeit-Check in der UI).
  static ActivePartyInfo? _storedSessionInfo;

  /// Notifier für UI: 6 Seiten (Offen, Gespielt, Abgelehnt, Favoriten, Gesperrt, History) nutzen nur diese Session-Daten.
  static final ValueNotifier<ActivePartyInfo?> storedSessionNotifier =
      ValueNotifier<ActivePartyInfo?>(null);

  /// Notifier für UI: pulsierender Punkt nur sichtbar, wenn true. Bei stopHeartbeat() sofort false.
  static final ValueNotifier<bool> heartbeatActiveNotifier =
      ValueNotifier<bool>(false);

  /// Optional: nach erfolgreichem Session-Heartbeat (`music_history.last_heartbeat`).
  /// Wird von [ShazamService] gesetzt, um `parties.active_recognition_last_seen` zu pingen (ohne Zirkelimport).
  static void Function()? onAfterSessionHeartbeat;
  static Set<String> seenWishIds =
      {}; // Set der bereits gesehenen Wunsch-IDs (für NEU-Badge)
  static String?
  _lastSavedPartyId; // Letzte Party-ID, für die die IDs gespeichert wurden
  static Set<String> _lastSavedIds =
      {}; // Letzte gespeicherte IDs (für Vergleich)
  static bool _isInitialized =
      false; // Verhindert Überschreibung durch altes Laden
  static final Map<String, Stream<ActivePartyInfo?>> _streamCache = {};
  static String? _streamCacheKey;
  /// Re-Auswertung „läuft die Party jetzt?“ ohne neues Firestore-Dokument (nur [DateTime.now]).
  static const Duration _kActivePartyWallClockPoll = Duration(seconds: 10);
  /// Letzte UID, für die [initialize] Party-Listener gestartet hat (nach Logout zurücksetzen).
  static String? _initializeBootstrapKey;

  /// Nächster Party-Start (zeitlich früheste start_date > jetzt unter nicht beendeten Partys).
  /// Wird vom zentralen Parties-Listener sofort aktualisiert (auch bei neuer Party vor bereits geplanter).
  static DateTime? _nextStartDate;
  static final ValueNotifier<DateTime?> nextStartDateNotifier =
      ValueNotifier<DateTime?>(null);

  /// Aktuelle aktive Party-ID aus der zentralen Session (für Shazam/Autostart etc.).
  /// null, wenn keine Party aktiv oder Session gelöscht wurde.
  static String? get currentPartyId => _currentHeartbeatPartyId;

  /// Liest die zuletzt in SharedPreferences gespeicherte lange party_id (Fallback für Pages).
  /// Key: last_active_party_id.
  static Future<String?> getLastActivePartyIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKeyLastActivePartyId);
  }

  /// Zentrale Wahrheit: Gibt die gespeicherte Session synchron aus dem Speicher zurück.
  /// Die 6 Seiten (Offen, Gespielt, Abgelehnt, Favoriten, Gesperrt, History) prüfen nur: wenn getStoredSession() != null, ist die Party aktiv.
  static ActivePartyInfo? getStoredSession() => _storedSessionInfo;

  /// Schreibt alle Session-Felder (Name, Start, Ende, Status) sofort in SharedPreferences und in den Speicher.
  /// Wird im Stream aufgerufen, sobald eine Party als "laufend" erkannt wird oder sich Daten in Firestore ändern.
  static Future<void> _updatePersistentSession(ActivePartyInfo info) async {
    _storedSessionInfo = info;
    storedSessionNotifier.value = info;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyLastActivePartyId, info.partyId);
      if (info.partyName != null && info.partyName!.isNotEmpty) {
        await prefs.setString(_prefsKeyPartyName, info.partyName!);
      }
      if (info.startDate != null) {
        await prefs.setInt(
          _prefsKeyStartDate,
          info.startDate!.millisecondsSinceEpoch,
        );
      }
      if (info.endDate != null) {
        await prefs.setInt(
          _prefsKeyEndDate,
          info.endDate!.millisecondsSinceEpoch,
        );
      }
      if (info.status != null && info.status!.isNotEmpty) {
        await prefs.setString(_prefsKeyPartyStatus, info.status!);
      }
      if (info.sessionId != null) {
        await prefs.setString(_prefsKeyPartyId, info.sessionId!);
      }
    } catch (e) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ⚠️ Fehler beim Speichern der Session in Prefs: $e',
      );
    }
  }

  /// Lädt die gespeicherten seenWishIds für eine spezifische Party
  /// Wird nur einmal ausgeführt, um zu verhindern, dass neue 'Gesehen'-Markierungen überschrieben werden
  static Future<void> loadSeenWishIds(String partyId) async {
    // Nur einmalig laden - verhindert Überschreibung während der Laufzeit
    if (_isInitialized) {
      return;
    }

    if (partyId.isEmpty) {
      seenWishIds.clear();
      _lastSavedPartyId = null;
      _lastSavedIds.clear();
      _isInitialized = true;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'seen_wishes_$partyId';
      final savedIdsJson = prefs.getString(storageKey);

      if (savedIdsJson != null && savedIdsJson.isNotEmpty) {
        final savedIds = (jsonDecode(savedIdsJson) as List<dynamic>)
            .map((e) => e.toString())
            .toSet();
        seenWishIds = savedIds;
        _lastSavedPartyId = partyId;
        _lastSavedIds = Set<String>.from(seenWishIds);
        debugLog(
          '✅ SeenWishIds geladen für Party $partyId: ${seenWishIds.length} IDs',
        );
      } else {
        seenWishIds.clear();
        _lastSavedPartyId = partyId;
        _lastSavedIds.clear();
        debugLog('ℹ️ Keine gespeicherten SeenWishIds für Party $partyId gefunden');
      }

      _isInitialized = true;
    } catch (e) {
      debugLog('⚠️ Fehler beim Laden der SeenWishIds für Party $partyId: $e');
      seenWishIds.clear();
      _lastSavedPartyId = null;
      _lastSavedIds.clear();
      _isInitialized = true;
    }
  }

  /// Speichert die seenWishIds für eine spezifische Party (nur wenn sich etwas geändert hat)
  static Future<void> saveSeenWishIds(String partyId) async {
    if (partyId.isEmpty) {
      return;
    }

    // Prüfe ob sich etwas geändert hat
    if (_lastSavedPartyId == partyId &&
        _lastSavedIds.length == seenWishIds.length &&
        _lastSavedIds.every((id) => seenWishIds.contains(id)) &&
        seenWishIds.every((id) => _lastSavedIds.contains(id))) {
      // Keine Änderungen - kein Speichern nötig
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'seen_wishes_$partyId';
      final idsList = seenWishIds.toList();
      final idsJson = jsonEncode(idsList);

      await prefs.setString(storageKey, idsJson);
      _lastSavedPartyId = partyId;
      _lastSavedIds = Set<String>.from(seenWishIds);
      debugLog(
        '✅ SeenWishIds gespeichert für Party $partyId: ${seenWishIds.length} IDs',
      );
    } catch (e) {
      debugLog('⚠️ Fehler beim Speichern der SeenWishIds für Party $partyId: $e');
    }
  }

  /// Löscht die gespeicherten seenWishIds für eine spezifische Party
  static Future<void> clearSeenWishIds(String partyId) async {
    if (partyId.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'seen_wishes_$partyId';
      await prefs.remove(storageKey);

      // Wenn es die aktuelle Party war, leere auch den Speicher
      if (_lastSavedPartyId == partyId) {
        seenWishIds.clear();
        _lastSavedPartyId = null;
        _lastSavedIds.clear();
      }

      debugLog('✅ SeenWishIds gelöscht für Party $partyId');
    } catch (e) {
      debugLog('⚠️ Fehler beim Löschen der SeenWishIds für Party $partyId: $e');
    }
  }

  /// Berechnet die effektive DJ-ID
  /// Wenn Admin eingeloggt ist, verwendet adminDjId (rtJXMTULzTPUz0xtdQOw9Jm8SGD3)
  /// Sonst die übergebene djId oder die aktuelle User-ID
  static String _getEffectiveDjId(String? djId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return djId ?? '';
    }

    final current = UserService().currentUser.value;
    final isAdmin =
        current != null &&
        current.id == user.uid &&
        AppConfig.isAdminRole(current);

    // Wenn Admin: Verwende adminDjId, unabhängig von der übergebenen djId
    if (isAdmin && AppConfig.adminDjId != null) {
      debugLog(
        '🔧 ActivePartyService: Admin erkannt, erzwinge adminDjId: ${AppConfig.adminDjId}',
      );
      return AppConfig.adminDjId!;
    }

    // Normaler User: Verwende übergebene djId oder User-ID
    return djId ?? user.uid;
  }

  /// Einheitliche Definition „Party läuft jetzt“ (Stream, [getActivePartyInfo], Validierung, Heartbeat).
  ///
  /// Zwingend: `start_date` und `end_date` vorhanden und `DateTime.now()` liegt im halb-offenen
  /// Intervall \[start, end) (nach Start, vor Ende – volle Uhrzeit aus Firestore-Timestamp).
  ///
  /// Zusätzlich: mindestens eines von
  /// `lifecycle_status == 'active'`, `status == 'active'`, `isActive == true`.
  ///
  /// Außerhalb des Zeitfensters: immer **false**, unabhängig von Lifecycle/Legacy (kein Frühstart).
  /// `finished`, `standby` oder `finished_at` gesetzt: immer **false**.
  static bool _isPartyDocumentRunningNow(
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final lifecycleStatus = data['lifecycle_status'] as String?;
    final finishedAt = data['finished_at'];
    if (lifecycleStatus == 'finished' ||
        lifecycleStatus == 'standby' ||
        finishedAt != null) {
      return false;
    }

    final startTimestamp = data['start_date'] as Timestamp?;
    final endTimestamp = data['end_date'] as Timestamp?;
    if (startTimestamp == null || endTimestamp == null) {
      return false;
    }
    final startDate = startTimestamp.toDate();
    final endDate = endTimestamp.toDate();
    final inTimeWindow =
        !effectiveNow.isBefore(startDate) && effectiveNow.isBefore(endDate);
    if (!inTimeWindow) {
      return false;
    }

    final status = data['status'] as String?;
    final isActiveFlag = data['isActive'] as bool? ?? false;
    return lifecycleStatus == 'active' || status == 'active' || isActiveFlag;
  }

  /// Prüft [partyId] in Firestore: gehört [effectiveDjId] (`created_by`) und erfüllt [_isPartyDocumentRunningNow].
  /// Wird beim App-Start und bei Resume verwendet, um „Geister-Partys“ aus lokalem Cache zu vermeiden.
  static Future<bool> validateStoredPartyAgainstFirebase(
    String partyId,
    String effectiveDjId,
  ) async {
    if (partyId.isEmpty || effectiveDjId.isEmpty) return false;
    try {
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();
      if (!partyDoc.exists) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ❌ validateStoredParty: Dokument fehlt ($partyId)',
        );
        return false;
      }
      final data = partyDoc.data() as Map<String, dynamic>;
      final createdBy = data['created_by'] as String?;
      if (createdBy != effectiveDjId) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ❌ validateStoredParty: created_by passt nicht (Party: $createdBy, DJ: $effectiveDjId)',
        );
        return false;
      }

      if (!_isPartyDocumentRunningNow(data)) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ❌ validateStoredParty: nicht im Zeitfenster oder keine aktiven Flags ($partyId)',
        );
        return false;
      }
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ✅ validateStoredParty: Party gültig aktiv ($partyId)',
      );
      return true;
    } catch (e) {
      debugLog('[ACTIVE-PARTY-SERVICE] ⚠️ validateStoredPartyAgainstFirebase: $e');
      return false;
    }
  }

  /// Nur [true], wenn eine lokale Session mit gültiger Party-ID existiert und Firebase dieselbe Party noch als aktiv bestätigt.
  static Future<bool> isPartyActuallyActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final effectiveDjId = _getEffectiveDjId(user.uid);
    if (effectiveDjId.isEmpty) return false;
    final local = _storedSessionInfo ?? storedSessionNotifier.value;
    if (local == null || local.partyId.isEmpty) return false;
    return validateStoredPartyAgainstFirebase(local.partyId, effectiveDjId);
  }

  /// Kurzer Check nach [AppLifecycleState.resumed]: hängende UI durch veraltete lokale Session bereinigen.
  static Future<void> refreshPartyTruthOnResume() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final effectiveDjId = _getEffectiveDjId(user.uid);
    if (effectiveDjId.isEmpty) return;
    final local = _storedSessionInfo ?? storedSessionNotifier.value;
    if (local == null || local.partyId.isEmpty) return;
    final ok = await validateStoredPartyAgainstFirebase(
      local.partyId,
      effectiveDjId,
    );
    if (!ok) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] 📱 Resume: gespeicherte Party ungültig – clearLocalSession()',
      );
      await clearLocalSession();
    }
  }

  /// Initialisiert den Service beim App-Start.
  /// Lädt `last_active_party_id` aus Prefs nur, wenn [validateStoredPartyAgainstFirebase] die Party bestätigt.
  /// Keine manuellen Flags: Session wird ausschließlich aus Firestore-Wahrheit abgeleitet
  /// (parties: start_date, end_date, lifecycle_status, finished_at).
  /// Startet sofort den Parties-Listener; beim ersten Snapshot wird geprüft, ob eine Party
  /// laut aktueller Uhrzeit aktiv ist – falls ja, wird die Session sofort gesetzt (Wiederaufnahme).
  static Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _initializeBootstrapKey = null;
      return;
    }

    if (_initializeBootstrapKey == user.uid && _partyInfoSubscription != null) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] initialize übersprungen (bereits aktiv für ${user.uid})',
      );
      return;
    }
    _initializeBootstrapKey = user.uid;

    debugLog('[ACTIVE-PARTY-SERVICE] Initialisiere Service ');

    final effectiveDjId = _getEffectiveDjId(user.uid);

    // Prefs nur nach Firebase-Validierung in die UI übernehmen (keine „Geister-Party“ beim Start).
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPartyId = prefs.getString(_prefsKeyLastActivePartyId);
      if (lastPartyId != null && lastPartyId.isNotEmpty) {
        if (effectiveDjId.isEmpty) {
          debugLog(
            '[ACTIVE-PARTY-SERVICE] ⚠️ Party in Prefs, aber keine effektive DJ-ID – Session verworfen',
          );
          await clearLocalSession();
        } else {
          final firebaseOk = await validateStoredPartyAgainstFirebase(
            lastPartyId,
            effectiveDjId,
          );
          if (!firebaseOk) {
            debugLog(
              '[ACTIVE-PARTY-SERVICE] ❌ Gespeicherte Party $lastPartyId ist in Firebase nicht aktiv – clearLocalSession()',
            );
            await clearLocalSession();
          } else {
            _currentHeartbeatPartyId = lastPartyId;
            debugLog(
              '[ACTIVE-PARTY-SERVICE] 💾 Session aus Prefs übernommen (Firebase bestätigt aktiv): $lastPartyId',
            );
            final partyCode = prefs.getString(_prefsKeyPartyCode);
            final partyName = prefs.getString(_prefsKeyPartyName);
            final startMillis = prefs.getInt(_prefsKeyStartDate);
            final endMillis = prefs.getInt(_prefsKeyEndDate);
            final status = prefs.getString(_prefsKeyPartyStatus);
            final sessionId = prefs.getString(_prefsKeyPartyId);
            _storedSessionInfo = ActivePartyInfo(
              partyId: lastPartyId,
              partyCode: partyCode,
              sessionId: sessionId,
              partyName: partyName,
              startDate: startMillis != null
                  ? DateTime.fromMillisecondsSinceEpoch(startMillis)
                  : null,
              endDate: endMillis != null
                  ? DateTime.fromMillisecondsSinceEpoch(endMillis)
                  : null,
              status: status ?? 'laufend',
            );
            storedSessionNotifier.value = _storedSessionInfo;
          }
        }
      }
    } catch (e) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ⚠️ Fehler beim Laden/Validieren von last_active_party_id: $e',
      );
    }

    // EINMALIGES CLEANUP: Setze alte Sessions auf isActive=false (nur beim Start)
    await _performOneTimeCleanup(user.uid);

    if (effectiveDjId.isEmpty) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] Keine effektive DJ-ID – überspringe Session-Listener',
      );
      return;
    }

    // App-Start-Check / Wiederaufnahme: Parties-Listener sofort starten.
    // Erster Snapshot entscheidet rein aus Firestore (start_date, end_date, lifecycle_status).
    _partyInfoSubscription?.cancel();
    _partyInfoSubscription = getActivePartyInfoStream(effectiveDjId).listen((
      ActivePartyInfo? info,
    ) {
      if (info != null) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] Session aktiv (Party: ${info.partyId}) – aus Firestore ermittelt',
        );
      }
    });
    debugLog(
      '[ACTIVE-PARTY-SERVICE] Parties-Listener gestartet für DJ $effectiveDjId – Zustand nur aus Firestore',
    );
  }

  /// Legt eine music_history-Session an, falls noch keine für diese Party existiert.
  /// Wird aufgerufen, wenn der Stream eine aktive Party findet, aber keine Session.
  /// Gibt die Session-ID zurück oder null bei Fehler.
  static Future<String?> _ensureMusicHistorySession({
    required String djId,
    required String partyId,
    required String partyName,
  }) async {
    if (partyId.isEmpty || partyId == 'manual') return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != djId) return null;

    try {
      // Prüfe erneut, ob eine Session existiert (Race-Condition mit HistoryProvider)
      final existing = await FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: djId)
          .where('party_id', isEqualTo: partyId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return existing.docs.first.id;

      final sessionData = {
        'djId': djId,
        'party_id': partyId,
        'partyName': partyName,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'isActive': true,
      };
      final sessionRef = await FirebaseFirestore.instance
          .collection('music_history')
          .add(_sanitizeWriteMap(sessionData));
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ✅ music_history-Session erstellt für Party $partyId: ${sessionRef.id}',
      );
      return sessionRef.id;
    } catch (e) {
      debugLog('[ACTIVE-PARTY-SERVICE] ⚠️ Fehler beim Erstellen der Session: $e');
      return null;
    }
  }

  /// Startet den Heartbeat-Timer für eine Session
  /// Sendet alle 2 Minuten einen Heartbeat an Firestore
  /// WICHTIG: Verhindert mehrfaches Starten für dieselbe Session (gegen Endlosschleife)
  static Future<void> _startHeartbeat(String sessionId) async {
    // KRITISCH: Verhindere mehrfaches Starten für dieselbe Session
    if (_currentHeartbeatSessionId == sessionId &&
        _heartbeatTimer != null &&
        _heartbeatTimer!.isActive) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] 🔇 Heartbeat für Session $sessionId läuft bereits - überspringe Start',
      );
      return;
    }

    // Stoppe alten Timer falls vorhanden (nur wenn andere Session)
    if (_currentHeartbeatSessionId != null &&
        _currentHeartbeatSessionId != sessionId) {
      _heartbeatTimer?.cancel();
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ⏹️ Alten Heartbeat gestoppt (Session: $_currentHeartbeatSessionId)',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Lade Session-Daten, um Party-ID und DJ-ID zu speichern
    try {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('music_history')
          .doc(sessionId)
          .get();

      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        // WICHTIG: Verwende 'party_id' (lange ID), nicht 'partyCode'
        final partyId =
            sessionData['party_id'] as String? ??
            sessionData['partyId'] as String?;
        final djId = sessionData['djId'] as String?;

        // Speichere Party-ID und DJ-ID für Validierung
        _currentHeartbeatPartyId = partyId;
        _currentHeartbeatDjId = djId;

        debugLog(
          '[ACTIVE-PARTY-SERVICE] 💾 Heartbeat-Daten gespeichert: Party-ID=$partyId, DJ-ID=$djId',
        );
      }
    } catch (e) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ⚠️ Fehler beim Laden der Session-Daten: $e',
      );
    }

    // Merke aktuelle Session
    _currentHeartbeatSessionId = sessionId;
    heartbeatActiveNotifier.value = true;

    debugLog('[ACTIVE-PARTY-SERVICE] ▶️ Starte Heartbeat für Session: $sessionId');

    // Sofortigen Heartbeat senden (ohne await, damit Stream nicht blockiert wird)
    _sendHeartbeat(sessionId).catchError((e) {
      debugLog('[ACTIVE-PARTY-SERVICE] ❌ Fehler beim ersten Heartbeat: $e');
    });

    // Timer für regelmäßigen Heartbeat (alle 2 Minuten)
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      // Prüfe nochmals, ob Session noch aktiv ist und Party noch aktiv ist
      if (_currentHeartbeatSessionId == sessionId) {
        // Validiere, ob Party noch aktiv ist
        final isValid = await _validateHeartbeatParty();
        if (isValid) {
          await _sendHeartbeat(sessionId);
        } else {
          debugLog(
            '[ACTIVE-PARTY-SERVICE] 🔇 Heartbeat-Timer gestoppt (Party nicht mehr aktiv oder nicht mehr für diesen DJ)',
          );
          timer.cancel();
          stopHeartbeat();
        }
      } else {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] 🔇 Heartbeat-Timer gestoppt (Session geändert)',
        );
        timer.cancel();
      }
    });
  }

  /// Sendet einen Heartbeat an Firestore
  static Future<void> _sendHeartbeat(String sessionId) async {
    try {
      final now = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('music_history')
          .doc(sessionId)
          .update(_sanitizeWriteMap({'last_heartbeat': now, 'isActive': true}));

      // Speichere lokal für Auto-Resume (UTC für 10-Min-Vergleich)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyPartyId, sessionId);
      await prefs.setInt(
        _prefsKeyLastHeartbeat,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      // Lange party_id zusätzlich sichern (Fallback für Pages / Tab-Wechsel)
      if (_currentHeartbeatPartyId != null &&
          _currentHeartbeatPartyId!.isNotEmpty) {
        await prefs.setString(
          _prefsKeyLastActivePartyId,
          _currentHeartbeatPartyId!,
        );
      }

      debugLog(
        '[ACTIVE-PARTY-SERVICE] ✅ Heartbeat gesendet für Session: $sessionId',
      );

      try {
        onAfterSessionHeartbeat?.call();
      } catch (e) {
        debugLog('[ACTIVE-PARTY-SERVICE] ⚠️ onAfterSessionHeartbeat: $e');
      }
    } catch (e) {
      debugLog('[ACTIVE-PARTY-SERVICE] ❌ Fehler beim Senden des Heartbeats: $e');
    }
  }

  /// Validiert Heartbeat-Party: gleiche Regel wie [_isPartyDocumentRunningNow] (Zeitfenster + aktive Flags).
  static Future<bool> _validateHeartbeatParty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugLog('[ACTIVE-PARTY-SERVICE] ❌ Validierung fehlgeschlagen: Kein User');
      return false;
    }

    final currentDjId = user.uid;
    final partyId = _currentHeartbeatPartyId;
    final heartbeatDjId = _currentHeartbeatDjId;

    // Prüfe 1: DJ-ID muss übereinstimmen
    if (heartbeatDjId != currentDjId) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ❌ Validierung fehlgeschlagen: DJ-ID stimmt nicht überein (Heartbeat: $heartbeatDjId, Aktuell: $currentDjId)',
      );
      return false;
    }

    // Prüfe 2: Party-ID muss vorhanden sein (lange ID, nicht Party-Code)
    if (partyId == null || partyId.isEmpty) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ❌ Validierung fehlgeschlagen: Keine Party-ID',
      );
      return false;
    }

    // Prüfe 3: Party muss existieren und aktiv sein
    try {
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();

      if (!partyDoc.exists) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ❌ Validierung fehlgeschlagen: Party existiert nicht (ID: $partyId)',
        );
        return false;
      }

      final partyData = partyDoc.data() as Map<String, dynamic>;

      final djId = partyData['djId'] as String?;
      final createdBy = partyData['created_by'] as String?;

      // Prüfe 4: Party muss dem aktuellen DJ gehören
      if (djId != currentDjId && createdBy != currentDjId) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ❌ Validierung fehlgeschlagen: Party gehört nicht diesem DJ (Party-DJ: $djId/$createdBy, Aktuell: $currentDjId)',
        );
        return false;
      }

      if (!_isPartyDocumentRunningNow(partyData)) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ❌ Validierung fehlgeschlagen: nicht im Zeitfenster oder keine aktiven Flags (Heartbeat)',
        );
        return false;
      }

      debugLog(
        '[ACTIVE-PARTY-SERVICE] ✅ Validierung erfolgreich: Party $partyId ist aktiv für DJ $currentDjId',
      );
      return true;
    } catch (e) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ❌ Validierung fehlgeschlagen: Fehler beim Prüfen der Party: $e',
      );
      return false;
    }
  }

  /// Stoppt den Heartbeat-Timer und setzt _currentHeartbeatPartyId auf null.
  /// Sollte nur aufgerufen werden bei: (1) explizitem Party-Ende (lifecycle_status == 'finished'),
  /// (2) aktivem Ausloggen des DJ, (3) Validierungsfehler im Timer (_validateHeartbeatParty).
  static void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _currentHeartbeatSessionId = null;
    _currentHeartbeatPartyId = null;
    _currentHeartbeatDjId = null;
    heartbeatActiveNotifier.value = false;
    debugLog('[ACTIVE-PARTY-SERVICE] ⏹️ Heartbeat gestoppt');
  }

  /// Bereinigt lokale Cache-Daten (Session + Heartbeat-Timestamp + last_active_party_id + gespeicherte Session-Felder).
  /// Manueller Kill-Switch: Bei manueller Party-Beendigung werden alle Session-Variablen restlos aus Prefs und Speicher gelöscht.
  /// Nur aufrufen bei explizitem Party-Ende oder DJ-Ausloggen – nicht beim Zeitfenster-Check (parties end_date).
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyPartyId);
    await prefs.remove(_prefsKeyPartyCode);
    await prefs.remove(_prefsKeyLastHeartbeat);
    await prefs.remove(_prefsKeyLastActivePartyId);
    await prefs.remove(_prefsKeyPartyName);
    await prefs.remove(_prefsKeyStartDate);
    await prefs.remove(_prefsKeyEndDate);
    await prefs.remove(_prefsKeyPartyStatus);
    _lastEmittedPartyInfo = null;
    _storedSessionInfo = null;
    storedSessionNotifier.value = null;
    stopHeartbeat();
    debugLog(
      '[ACTIVE-PARTY-SERVICE] Cache gelöscht (Session-Variablen restlos entfernt)',
    );
  }

  /// Wie clearCache(); Name für Klarheit: veraltete lokale Session zwangsweise löschen.
  static Future<void> clearLocalSession() async {
    await clearCache();
  }

  /// Prüft in Firestore, ob die Party noch aktiv ist (kein lifecycle_status "finished", kein finished_at).
  /// Gibt false zurück, wenn die Party beendet ist oder das Dokument fehlt.
  static Future<bool> _isPartyStillActiveInFirestore(String partyId) async {
    try {
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();
      if (!partyDoc.exists) return false;
      final data = partyDoc.data() as Map<String, dynamic>? ?? {};
      final lifecycleStatus = data['lifecycle_status'] as String?;
      final finishedAt = data['finished_at'];
      if (lifecycleStatus == 'finished') {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ❌ Party $partyId ist beendet (lifecycle_status: finished)',
        );
        return false;
      }
      if (finishedAt != null) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ❌ Party $partyId hat finished_at gesetzt – gilt als beendet',
        );
        return false;
      }
      return true;
    } catch (e) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ⚠️ _isPartyStillActiveInFirestore Fehler: $e',
      );
      return false;
    }
  }

  /// Einmaliges Cleanup: Setzt alte Sessions auf isActive=false
  /// Prüft nur Sessions des aktuellen Users
  static Future<void> _performOneTimeCleanup(String djId) async {
    try {
      if (UserService().currentUser.value == null) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] 🧹 Einmaliges Cleanup übersprungen (kein UserModel)',
        );
        return;
      }

      debugLog(
        '[ACTIVE-PARTY-SERVICE] 🧹 Starte einmaliges Cleanup für UID: $djId',
      );

      final now = DateTime.now();

      // Lade alle aktiven Sessions des Users
      final sessionsSnap = await FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: djId)
          .where('isActive', isEqualTo: true)
          .get();

      if (sessionsSnap.docs.isEmpty) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ✅ Keine aktiven Sessions gefunden - Cleanup nicht nötig',
        );
        return;
      }

      debugLog(
        '[ACTIVE-PARTY-SERVICE] Gefunden: ${sessionsSnap.docs.length} aktive Sessions zum Prüfen',
      );

      int updated = 0;
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int batchOps = 0;
      const BATCH_LIMIT = 450;

      for (final doc in sessionsSnap.docs) {
        final sessionData = doc.data();
        final startTime = sessionData['startTime'] as Timestamp?;

        // Prüfe ob startTime in der Vergangenheit liegt
        if (startTime != null) {
          final startDate = startTime.toDate();

          // Wenn startTime in der Vergangenheit liegt, setze isActive=false
          if (startDate.isBefore(now)) {
            batch.update(
              doc.reference,
              _sanitizeWriteMap({
                'isActive': false,
                'cleaned_at': FieldValue.serverTimestamp(),
              }),
            );
            batchOps++;
            updated++;

            if (batchOps >= BATCH_LIMIT) {
              await batch.commit();
              batch = FirebaseFirestore.instance.batch();
              batchOps = 0;
            }
          }
        }
      }

      // Finale Batch-Commit
      if (batchOps > 0) {
        await batch.commit();
      }

      if (updated > 0) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ✅ Cleanup abgeschlossen: $updated Sessions auf isActive=false gesetzt',
        );
      } else {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ✅ Cleanup abgeschlossen: Keine alten Sessions gefunden',
        );
      }
    } catch (e) {
      debugLog('[ACTIVE-PARTY-SERVICE] ⚠️ Fehler beim einmaligen Cleanup: $e');
      // Fehler nicht fatal - App kann weiter starten
    }
  }

  /// Baut [ActivePartyInfo] inkl. music_history / Heartbeat – gleiche Logik wie der Parties-Stream.
  static Future<ActivePartyInfo?> _materializeActivePartyForDj(
    String effectiveDjId,
    String activePartyId,
    Map<String, dynamic> partyData,
  ) async {
    final partyCode = partyData['party_code'] as String?;
    final String? partyName =
        (partyData['party_name'] ?? partyData['name'] ?? partyData['title'])
            as String?;
    final startTimestamp = partyData['start_date'] as Timestamp?;
    final endTimestamp = partyData['end_date'] as Timestamp?;
    final DateTime? startDate = startTimestamp?.toDate();
    final DateTime? endDate = endTimestamp?.toDate();

    debugLog(
      'ANALYSE [History-Fetch]: Suche mit party_id = $activePartyId und djId = $effectiveDjId',
    );
    debugLog(
      'ANALYSE [Auth]: Eingeloggte UID ist = ${FirebaseAuth.instance.currentUser?.uid}',
    );
    QuerySnapshot<Map<String, dynamic>> sessionQuery;
    try {
      sessionQuery = await FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: effectiveDjId)
          .where('party_id', isEqualTo: activePartyId)
          .limit(1)
          .get();
      if (sessionQuery.docs.isEmpty) {
        sessionQuery = await FirebaseFirestore.instance
            .collection('music_history')
            .where('djId', isEqualTo: effectiveDjId)
            .where('partyId', isEqualTo: activePartyId)
            .limit(1)
            .get();
      }
    } catch (e) {
      debugLog('ANALYSE [History-Error]: Firebase meldet folgenden Fehler: $e');
      if (e.toString().contains('index') || e.toString().contains('Index')) {
        debugLog(
          'ANALYSE [Index-Check]: Fehler enthält Index-Hinweis – prüfe ob Link zur Index-Erstellung in der Fehlermeldung steht.',
        );
      }
      return null;
    }

    debugLog(
      'ANALYSE [History-Data]: Empfangen wurden ${sessionQuery.docs.length} Dokumente (getActivePartyInfo / materialize)',
    );
    String? sessionId;
    if (sessionQuery.docs.isNotEmpty) {
      sessionId = sessionQuery.docs.first.id;
      try {
        await _startHeartbeat(sessionId!);
      } catch (e) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ⚠️ Fehler beim Starten des Heartbeats: $e',
        );
      }
    } else {
      sessionId = await _ensureMusicHistorySession(
        djId: effectiveDjId,
        partyId: activePartyId,
        partyName: partyName ?? 'Unbenannte Party',
      );
      if (sessionId != null) {
        try {
          await _startHeartbeat(sessionId);
        } catch (e) {
          debugLog(
            '[ACTIVE-PARTY-SERVICE] ⚠️ Fehler beim Heartbeat nach Session-Erstellung: $e',
          );
        }
      }
    }

    loadSeenWishIds(activePartyId).catchError((e) {
      debugLog('[ACTIVE-PARTY-SERVICE] ⚠️ Fehler beim Laden der SeenWishIds: $e');
    });

    return ActivePartyInfo(
      partyId: activePartyId,
      partyCode: partyCode,
      sessionId: sessionId,
      partyName: partyName != null && partyName.isNotEmpty ? partyName : null,
      startDate: startDate,
      endDate: endDate,
      status: 'laufend',
    );
  }

  /// Lädt die aktive Party-ID für einen DJ (einmalige Abfrage, **dieselbe** Aktiv-Logik wie der Stream).
  /// Gibt null zurück, wenn keine aktive Party gefunden wurde
  static Future<ActivePartyInfo?> getActivePartyInfo(String? djId) async {
    try {
      final effectiveDjId = _getEffectiveDjId(djId);
      final now = DateTime.now();

      debugLog('[DEBUG] ========== ACTIVE-PARTY-SERVICE ==========');
      debugLog(
        'ANALYSE [Auth]: Eingeloggte UID ist = ${FirebaseAuth.instance.currentUser?.uid}',
      );
      debugLog('[DEBUG] Effective DJ ID: $effectiveDjId');
      debugLog('[DEBUG] ===========================================');

      debugLog('[DEBUG] Prüfe parties Collection nach created_by: $effectiveDjId');
      final partiesSnapshot = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: effectiveDjId)
          .get();
      debugLog(
        '[DEBUG] Firebase meldet Dokumente gefunden in parties (created_by): ${partiesSnapshot.docs.length}',
      );

      debugLog(
        '[DEBUG] Prüfe ${partiesSnapshot.docs.length} Party-Dokumente (Zeitfenster + aktive Flags)...',
      );
      for (final partyDoc in partiesSnapshot.docs) {
        final partyData = partyDoc.data();
        if (!_isPartyDocumentRunningNow(partyData, now: now)) continue;

        final partyId = partyDoc.id;
        debugLog(
          '✅ ActivePartyService: Aktive Party gefunden: $partyId (getActivePartyInfo)',
        );
        final info = await _materializeActivePartyForDj(
          effectiveDjId,
          partyId,
          partyData,
        );
        if (info != null) {
          await _updatePersistentSession(info);
          return info;
        }
      }

      debugLog(
        '[DEBUG] ❌ ActivePartyService: Keine aktive Party gefunden für DJ $effectiveDjId',
      );
      await clearCache();
      return null;
    } catch (e) {
      debugLog('ANALYSE [History-Error]: Firebase meldet folgenden Fehler: $e');
      if (e.toString().contains('index') || e.toString().contains('Index')) {
        debugLog(
          'ANALYSE [Index-Check]: Fehler enthält Index-Hinweis – prüfe ob Link zur Index-Erstellung in der Fehlermeldung steht.',
        );
      }
      debugLog('❌ ActivePartyService: Fehler beim Finden der aktiven Party: $e');
      return null;
    }
  }

  /// Lädt nur die aktive Party-ID (vereinfachte Methode)
  /// Gibt null zurück, wenn keine aktive Party gefunden wurde
  static Future<String?> getActivePartyId(String? djId) async {
    final info = await getActivePartyInfo(djId);
    return info?.partyId;
  }

  /// Stream für aktive Party-Informationen (Echtzeit-Updates)
  /// Ein Stream pro effectiveDjId (Singleton-Pattern), verhindert Mehrfach-Abos auf Firestore.
  static Stream<ActivePartyInfo?> getActivePartyInfoStream(String? djId) {
    try {
      final effectiveDjId = _getEffectiveDjId(djId);
      if (effectiveDjId.isEmpty) return Stream.value(null);

      if (_streamCache[effectiveDjId] != null &&
          _streamCacheKey == effectiveDjId) {
        return _streamCache[effectiveDjId]!;
      }
      _streamCacheKey = effectiveDjId;
      _streamCache[effectiveDjId] = _createActivePartyInfoStream(effectiveDjId);
      return _streamCache[effectiveDjId]!;
    } catch (e) {
      debugLog(
        '❌ ActivePartyService: Fehler beim Erstellen des Active-Party-Streams: $e',
      );
      return Stream.value(null);
    }
  }

  /// Wertet den Parties-[snapshot] mit aktueller Uhrzeit aus.
  ///
  /// Ohne neues Firestore-Write ändert sich nur [DateTime.now] – der reine
  /// `.snapshots()`-Stream feuert dann nicht. Deshalb zusätzlich
  /// [_kActivePartyWallClockPoll] im zentralen Stream.
  static Future<ActivePartyInfo?> _resolveActivePartyFromPartiesSnapshot(
    QuerySnapshot<Object?> snapshot,
    String effectiveDjId,
  ) async {
    final now2 = DateTime.now();
    String? activePartyId;
    DateTime? nextStart;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lifecycleStatus = data['lifecycle_status'] as String?;
      final finishedAt = data['finished_at'];
      if (lifecycleStatus == 'finished' ||
          lifecycleStatus == 'standby' ||
          finishedAt != null) {
        continue;
      }

      final startTimestamp = data['start_date'] as Timestamp?;
      final endTimestamp = data['end_date'] as Timestamp?;
      if (startTimestamp != null && endTimestamp != null) {
        final startDate = startTimestamp.toDate();
        if (startDate.isAfter(now2)) {
          if (nextStart == null || startDate.isBefore(nextStart)) {
            nextStart = startDate;
          }
        }
      }

      if (activePartyId == null &&
          _isPartyDocumentRunningNow(data, now: now2)) {
        activePartyId = doc.id;
        break;
      }
    }

    _nextStartDate = nextStart;
    nextStartDateNotifier.value = nextStart;

    final wasActivePartyId = _currentHeartbeatPartyId;
    if (wasActivePartyId != null && activePartyId != wasActivePartyId) {
      final partyNowFinished = snapshot.docs.any((d) {
        if (d.id != wasActivePartyId) return false;
        final data = d.data() as Map<String, dynamic>;
        return data['lifecycle_status'] == 'finished' ||
            data['finished_at'] != null;
      });
      if (partyNowFinished) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] ⏹️ Party $wasActivePartyId beendet (lifecycle/finished_at) – Session sofort löschen',
        );
        final sessionIdToDeactivate = _currentHeartbeatSessionId;
        await clearLocalSession();
        if (sessionIdToDeactivate != null) {
          try {
            await FirebaseFirestore.instance
                .collection('music_history')
                .doc(sessionIdToDeactivate)
                .update(_sanitizeWriteMap({'isActive': false}));
          } catch (e) {
            debugLog(
              '[ACTIVE-PARTY-SERVICE] ⚠️ music_history isActive=false nicht gesetzt: $e',
            );
          }
        }
        _lastEmittedPartyInfo = null;
        return null;
      }
    }

    if (activePartyId == null) {
      if (wasActivePartyId != null ||
          _storedSessionInfo != null ||
          storedSessionNotifier.value != null) {
        debugLog(
          '[ACTIVE-PARTY-SERVICE] Keine aktive Party (Zeitfenster/Flags) – clearLocalSession()',
        );
        await clearLocalSession();
      }
      _lastEmittedPartyInfo = null;
      return null;
    }

    final partyDoc = snapshot.docs.firstWhere((d) => d.id == activePartyId);
    final partyData = partyDoc.data() as Map<String, dynamic>;
    final info = await _materializeActivePartyForDj(
      effectiveDjId,
      activePartyId,
      partyData,
    );
    if (info == null) {
      _lastEmittedPartyInfo = null;
      return null;
    }
    _lastEmittedPartyInfo = info;
    await _updatePersistentSession(info);
    return info;
  }

  /// Zentraler Stream: Firestore-Listener auf parties (created_by == djId)
  /// **plus** periodische Re-Auswertung mit [DateTime.now], damit beim Start/Ende
  /// der Party (ohne Feldänderung in Firestore) die UI umschaltet.
  static Stream<ActivePartyInfo?> _createActivePartyInfoStream(
    String effectiveDjId,
  ) {
    QuerySnapshot<Object?>? latestSnapshot;
    StreamSubscription<QuerySnapshot<Object?>>? fsSub;
    Timer? wallClockTimer;
    var resolutionGen = 0;
    late final StreamController<ActivePartyInfo?> out;

    Future<void> scheduleResolve() async {
      final g = ++resolutionGen;
      final snap = latestSnapshot;
      if (snap == null) {
        return;
      }
      final result =
          await _resolveActivePartyFromPartiesSnapshot(snap, effectiveDjId);
      if (g != resolutionGen || out.isClosed) {
        return;
      }
      out.add(result);
    }

    out = StreamController<ActivePartyInfo?>.broadcast(
      onListen: () {
        fsSub ??= FirebaseFirestore.instance
            .collection('parties')
            .where('created_by', isEqualTo: effectiveDjId)
            .snapshots()
            .listen((snap) {
          latestSnapshot = snap;
          scheduleResolve();
        });
        wallClockTimer ??= Timer.periodic(_kActivePartyWallClockPoll, (_) {
          if (latestSnapshot != null) {
            scheduleResolve();
          }
        });
      },
      onCancel: () {
        wallClockTimer?.cancel();
        wallClockTimer = null;
        fsSub?.cancel();
        fsSub = null;
        latestSnapshot = null;
      },
    );

    return out
        .stream
        .distinct((prev, next) {
          if (prev == null && next == null) return true;
          if (prev == null || next == null) return false;
          return prev.partyId == next.partyId &&
              prev.sessionId == next.sessionId &&
              prev.partyName == next.partyName &&
              prev.startDate == next.startDate &&
              prev.endDate == next.endDate;
        })
        .asBroadcastStream();
  }

  /// Stream für aktive Party-ID (vereinfachte Methode)
  /// Gibt null zurück, wenn keine aktive Party gefunden wurde
  /// OPTIMIERT: Nutzt distinct() um nur bei partyId-Änderungen zu feuern (kein Flackern bei Heartbeat-Updates)
  static Stream<String?> getActivePartyIdStream(String? djId) {
    return getActivePartyInfoStream(
      djId,
    ).map((info) => info?.partyId).distinct();
  }

  /// Prüft ob aktuell ein Heartbeat aktiv ist
  /// Validiert zusätzlich, ob die Party noch aktiv ist und dem aktuellen DJ gehört
  static bool get isHeartbeatActive {
    // Basis-Prüfung: Timer muss aktiv sein
    if (_heartbeatTimer == null || !_heartbeatTimer!.isActive) {
      return false;
    }

    // Zusätzliche Validierung: Party-ID und DJ-ID müssen vorhanden sein
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    final currentDjId = user.uid;
    final partyId = _currentHeartbeatPartyId;
    final heartbeatDjId = _currentHeartbeatDjId;

    // Prüfe: Party-ID muss vorhanden sein (lange ID, nicht Party-Code)
    if (partyId == null || partyId.isEmpty) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ⚠️ isHeartbeatActive: Keine Party-ID gespeichert',
      );
      return false;
    }

    // Prüfe: DJ-ID muss übereinstimmen
    if (heartbeatDjId != currentDjId) {
      debugLog(
        '[ACTIVE-PARTY-SERVICE] ⚠️ isHeartbeatActive: DJ-ID stimmt nicht überein (Heartbeat: $heartbeatDjId, Aktuell: $currentDjId)',
      );
      return false;
    }

    // Timer ist aktiv UND Party-ID/DJ-ID sind korrekt
    return true;
  }
}
