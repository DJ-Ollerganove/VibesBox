import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'shazam_service.dart';
import 'active_party_service.dart';
import '../config/app_config.dart';
import 'user_service.dart';
import '../utils/debug_log.dart';

/// Service für automatischen Start/Stopp der Musikerkennung basierend auf der zentralen Session.
/// Nutzt ausschließlich [UserService].currentUser (Cache) und [ActivePartyService] – keine eigenen users/{uid}.get().
class PartyAutostartService {
  static final PartyAutostartService _instance =
      PartyAutostartService._internal();
  factory PartyAutostartService() => _instance;
  PartyAutostartService._internal();

  final ShazamService _shazamService = ShazamService();
  StreamSubscription<ActivePartyInfo?>? _activePartySubscription;
  void Function()? _userListener;
  bool _isInitialized = false;
  bool _lastPartyStatus = false;
  bool? _lastAutoStartSetting;
  String? _currentDjId;
  bool? _manualRecognitionOverride;

  bool _isLocalSelfContext(User user) {
    final model = UserService().currentUser.value;
    if (model == null || model.id != user.uid) {
      return false;
    }

    final isAdmin = AppConfig.isAdminRole(model);
    if (isAdmin) {
      // Admin darf auf die konfigurierte Admin-DJ-Kontext-ID zeigen.
      return _currentDjId != null && _currentDjId!.isNotEmpty;
    }

    // DJ-Modus: Strikt nur eigene UID als DJ-Kontext.
    return _currentDjId == user.uid;
  }

  /// Verzögerter Nachzug: auf manchen Geräten (z. B. iPad) kommt die Party-Session kurz nach dem Autostart-Init.
  static const Duration _delayedAutostartCatchUpDelay = Duration(seconds: 2);

  void _scheduleDelayedAutostartCatchUp() {
    unawaited(
      Future<void>.delayed(_delayedAutostartCatchUpDelay, () async {
        if (!_isInitialized) return;
        await _delayedAutostartCatchUpAsync();
      }),
    );
  }

  Future<void> _delayedAutostartCatchUpAsync() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      if (!_isInitialized) return;
      if (_shazamService.isEnabled) return;
      final stored = ActivePartyService.getStoredSession();
      if (stored == null) return;
      debugLog(
        'PartyAutostartService: Nachzug nach ${_delayedAutostartCatchUpDelay.inSeconds}s — Party aktiv, Erkennung noch aus → Autostart prüfen.',
      );
      await _startRecognitionIfAllowed();
    } catch (e) {
      debugLog('PartyAutostartService: Nachzug Autostart: $e');
    }
  }

  /// Initialisiert Listener (einmal pro Prozess). Keine Firestore-get auf users – Einstellungen aus [UserModel].
  Future<void> initialize() async {
    if (_isInitialized) {
      await reconcileAfterResume();
      _scheduleDelayedAutostartCatchUp();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final currentUserModel = UserService().currentUser.value;
    final effectiveDjId = await AppConfig.getEffectiveDjId(
      currentUserModel,
      user.uid,
    );
    _currentDjId = effectiveDjId ?? user.uid;
    _isInitialized = true;
    // Nur bei echtem Prozess-Neustart zurücksetzen: Manual-Override ist session-lokal.
    _manualRecognitionOverride = null;

    _lastAutoStartSetting = currentUserModel?.autoStartRecognition ?? false;

    _attachUserCacheListener();
    _setupSessionListener();
    _evaluateStoredSessionOnce();

    await reconcileAfterResume();
    _scheduleDelayedAutostartCatchUp();
    unawaited(_releaseStaleRecognitionLockIfIdle());
  }

  /// Nach App-Resume: Session + Autostart aus Cache prüfen (ohne Cold-Start-Sperre).
  Future<void> reconcileAfterResume() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_isInitialized) {
      await initialize();
      return;
    }

    _lastAutoStartSetting =
        UserService().currentUser.value?.autoStartRecognition ?? false;

    final stored = ActivePartyService.getStoredSession();
    final isPartyActive = stored != null;
    if (isPartyActive != _lastPartyStatus) {
      _lastPartyStatus = isPartyActive;
      if (isPartyActive) {
        await _startRecognitionIfAllowed();
      } else {
        await _stopRecognitionAfterPartyEnded();
      }
    } else if (isPartyActive) {
      // Bei Resume nie die letzte manuelle Session-Entscheidung überschreiben.
      await _startRecognitionIfAllowed();
    }
    unawaited(_releaseStaleRecognitionLockIfIdle());
  }

  void _attachUserCacheListener() {
    if (_userListener != null) {
      UserService().currentUser.removeListener(_userListener!);
    }
    _userListener = () {
      final m = UserService().currentUser.value;
      final auto = m?.autoStartRecognition ?? false;
      if (_lastAutoStartSetting == auto) return;
      _lastAutoStartSetting = auto;
      if (!auto && _lastPartyStatus) {
        _stopRecognition();
      } else if (auto && _lastPartyStatus) {
        _startRecognitionIfAllowed();
      }
    };
    UserService().currentUser.addListener(_userListener!);
  }

  void _evaluateStoredSessionOnce() {
    final stored = ActivePartyService.getStoredSession();
    final isPartyActive = stored != null;
    if (isPartyActive && !_lastPartyStatus) {
      _lastPartyStatus = true;
      _startRecognitionIfAllowed();
    }
  }

  void _setupSessionListener() {
    final effectiveDjId = _currentDjId;
    if (effectiveDjId == null) {
      return;
    }

    _activePartySubscription?.cancel();
    _activePartySubscription =
        ActivePartyService.getActivePartyInfoStream(effectiveDjId).listen((
          ActivePartyInfo? info,
        ) {
          final isPartyActive = info != null;
          if (_lastPartyStatus != isPartyActive) {
            _lastPartyStatus = isPartyActive;

            if (isPartyActive) {
              _startRecognitionIfAllowed();
            } else {
              unawaited(_stopRecognitionAfterPartyEnded());
            }
          }
        });
  }

  /// Beim Wechsel auf „keine Party“: Autostart stoppen, aber manuell eingeschaltete Erkennung laufen lassen (Test ohne Party).
  Future<void> _stopRecognitionAfterPartyEnded() async {
    if (_manualRecognitionOverride == true) {
      debugLog(
        'PartyAutostartService: Keine aktive Party – Musikerkennung bleibt an (manueller Modus / Test ohne Party).',
      );
      return;
    }
    await _stopRecognition();
  }

  /// Autostart nur wenn [UserModel.autoStartRecognition] im UserService-Cache true ist.
  Future<void> _startRecognitionIfAllowed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_isLocalSelfContext(user)) {
      return;
    }

    // Session-Override hat Vorrang vor AutoStart-Setting aus dem Profil.
    if (_manualRecognitionOverride == false) {
      return;
    }
    if (_manualRecognitionOverride == true) {
      await _startRecognition();
      return;
    }

    final autoStart =
        UserService().currentUser.value?.autoStartRecognition ?? false;

    if (autoStart) {
      await _startRecognition();
    }
  }

  Future<RecognitionStartOutcome> _startRecognition() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_isLocalSelfContext(user)) {
      return RecognitionStartOutcome.denied;
    }
    if (_shazamService.isExternalRecognitionSourceActive) {
      return RecognitionStartOutcome.denied;
    }
    if (_shazamService.isEnabled) {
      return RecognitionStartOutcome.alreadyRunning;
    }
    final mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      debugLog(
        'PartyAutostartService: Musikerkennung nicht gestartet — Mikrofon nicht erlaubt (Status: $mic).',
      );
      return RecognitionStartOutcome.denied;
    }
    try {
      final outcome = await _shazamService.startAutoScanning();
      switch (outcome) {
        case RecognitionStartOutcome.blockedByOtherDevice:
          debugLog(
            'PartyAutostartService: Autostart blockiert — Musikerkennung läuft schon auf einem anderen Gerät '
            '(oder alter Lock). Bitte dort ausschalten oder ein paar Minuten warten.',
          );
          break;
        case RecognitionStartOutcome.lockAcquireFailed:
          debugLog(
            'PartyAutostartService: Autostart fehlgeschlagen (Lock/Firestore). Kurz warten und App wieder öffnen.',
          );
          break;
        case RecognitionStartOutcome.denied:
          debugLog(
            'PartyAutostartService: Musikerkennung nicht gestartet (z. B. Pro/Mikrofon).',
          );
          break;
        case RecognitionStartOutcome.failed:
          debugLog(
            'PartyAutostartService: startAutoScanning ist mit Fehler ausgegangen.',
          );
          break;
        case RecognitionStartOutcome.started:
        case RecognitionStartOutcome.alreadyRunning:
          break;
      }
      return outcome;
    } catch (e) {
      debugLog(
        '❌ PartyAutostartService: Fehler beim Starten der Musikerkennung: $e',
      );
      return RecognitionStartOutcome.failed;
    }
  }

  Future<void> stopRecognitionNow() async {
    await _stopRecognition();
  }

  /// Manuelle Benutzerentscheidung in der laufenden App-Session.
  /// Bleibt bei Resume erhalten und wird erst beim echten App-Neustart zurückgesetzt.
  Future<RecognitionStartOutcome> setManualRecognitionEnabled(bool enabled) async {
    _manualRecognitionOverride = enabled;
    if (enabled) {
      return await _startRecognition();
    } else {
      await _stopRecognition();
      return RecognitionStartOutcome.denied;
    }
  }

  Future<void> _releaseStaleRecognitionLockIfIdle() async {
    if (_shazamService.isEnabled) return;
    try {
      await _shazamService.releaseRecognitionDeviceLockIfHeld();
    } catch (e) {
      debugLog(
        'PartyAutostartService: Zombie-Recognition-Lock konnte nicht freigegeben werden: $e',
      );
    }
  }

  Future<void> _stopRecognition() async {
    try {
      if (_shazamService.isEnabled) {
        await _shazamService.stopAutoScanning();
      } else {
        await _shazamService.releaseRecognitionDeviceLockIfHeld();
      }
    } catch (e) {
      debugLog(
        '❌ PartyAutostartService: Fehler beim Stoppen der Musikerkennung: $e',
      );
    }
  }

  void dispose() {
    _activePartySubscription?.cancel();
    _activePartySubscription = null;
    if (_userListener != null) {
      UserService().currentUser.removeListener(_userListener!);
      _userListener = null;
    }
    _isInitialized = false;
    _currentDjId = null;
    _manualRecognitionOverride = null;
  }
}
