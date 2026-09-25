import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'
    show FirebaseFunctions, FirebaseFunctionsException;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_scaffold_messenger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'active_party_service.dart';
import 'app_local_notifications.dart';
import 'open_wishes_visibility_service.dart';
import 'party_secure_service.dart';
import 'duplicate_check_service.dart';
import 'dj_setlist_track_actions_service.dart';
import 'history_provider.dart';
import 'pro_feature_guard.dart';
import '../utils/text_utils.dart';
import '../utils/debug_log.dart';
import 'app_diagnostic_log_service.dart';
import 'user_self_settings_service.dart';
import '../utils/pre_wish_helper.dart';
import '../utils/wish_paths.dart';
import '../utils/notification_display_text.dart';
import '../l10n/locale_helper.dart';
import '../utils/ios_stable_device_id.dart';
import '../models/user_model.dart';

/// Status für Shazam-Scanning
enum ShazamScanStatus {
  idle, // Inaktiv
  scanning, // Scan läuft gerade
  success, // Song erfolgreich erkannt
  error, // Fehler aufgetreten
}

enum RecognitionStartOutcome {
  started,
  alreadyRunning,
  blockedByOtherDevice,
  lockAcquireFailed,
  denied,
  failed,
}

enum _RecognitionLockAcquireResult {
  acquired,
  blockedFreshOther,
  firestoreError,
}

/// Service für Shazam-Song-Erkennung mit automatischem Intervall-Scanning
class ShazamService {
  static final ShazamService _instance = ShazamService._internal();
  factory ShazamService() => _instance;

  /// Free-Tarif: fester Abstand zwischen Scans (Sekunden).
  static const int freeScanIntervalSeconds = 180;

  String _prefsKeyFreeLastScan(String uid) =>
      'shazam_free_last_scan_completed_ms_$uid';

  ShazamService._internal() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
    ActivePartyService.onAfterSessionHeartbeat = () {
      ShazamService().pingRecognitionLeaseFromPartyHeartbeat();
    };
    // Initialisiere autoAdjustStream sofort beim ersten App-Start (ohne await, läuft im Hintergrund)
    // Die Subscription bleibt dauerhaft bestehen für diesen Test
    _initAutoAdjustStream().catchError((error) {
      debugLog('⚠️ Fehler beim Initialisieren von autoAdjustStream: $error');
    });
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == _nativeMethodNotificationNavigationTarget) {
      final args = call.arguments as Map<dynamic, dynamic>?;
      final target = args?['target'] as String?;
      _emitNotificationNavigationTarget(target);
      if (target == _navigationTargetHistory) {
        try {
          await _channel.invokeMethod<void>(
            _methodClearPendingNavigationTarget,
          );
        } catch (_) {}
      }
    }
  }

  static const MethodChannel _channel = MethodChannel('shazam_channel');
  static const EventChannel _rmsEventChannel = EventChannel(
    'dj_og_app/rms_stream',
  );
  static const EventChannel _autoAdjustEventChannel = EventChannel(
    'com.vibesbox.dj/auto_adjust',
  ); // AUTOMATIC GAIN & THRESHOLD MAPPING

  /// Zentraler Visual-Boost-Faktor für RMS-Pegelanzeige (Footer, Audio-Einstellungen, Profil).
  /// Reduziert von 5.0 auf 2.5 für realistischere Anzeige.
  static const double rmsVisualBoostFactor = 2.5;

  // MethodChannel-Methoden für Foreground Service
  static const String _methodStartScanning = 'startScanning';
  static const String _methodStopScanning = 'stopScanning';
  static const String _methodStopCurrentScan = 'stopCurrentScan';
  static const String _methodUpdateRecognitionNotification =
      'updateRecognitionNotification';
  static const String _methodUpdateNotificationContent =
      'updateNotificationContent';
  static const String _methodUpdateNotificationVisibility =
      'updateNotificationVisibility';
  static const String _methodConsumePendingNavigationTarget =
      'consumePendingNavigationTarget';
  static const String _methodClearPendingNavigationTarget =
      'clearPendingNavigationTarget';
  static const String _nativeMethodNotificationNavigationTarget =
      'onNotificationNavigationTarget';
  static const String _navigationTargetHistory = 'history';

  /// Lokalisierte Texte für die Statusleisten-Notification (von UI gesetzt)
  String? _notificationTitle;
  String? _notificationRunning;
  String? _notificationSuccessFormat;

  Timer? _scanTimer;
  ShazamScanStatus _status = ShazamScanStatus.idle;
  Map<String, dynamic>? _lastResult;
  bool _isEnabled = false;
  String?
  _serviceOwnerUid; // Lokale Geräte-Session: Service darf nur für diese UID laufen
  bool _showStatusNotification = false; // Default für neue DJs
  bool _foregroundServiceRunning = false;
  bool _foregroundServicePrimedInForeground = false;
  String?
  _lastNotificationText; // Zuletzt in der Statusleiste angezeigter Inhalt
  int _scanIntervalSeconds = 60; // Standard: 60 Sekunden
  double _micSensitivity = 1.0; // Standard: 1.0 (0.5 bis 2.0)
  double _recognitionThreshold =
      0.3; // Standard: 0.3 (0.0 bis 1.0) - Schwellenwert für Scan-Start
  bool _smartThresholdEnabled = false; // Standard: false (manuell)
  /// Free-DJ: planType aus users-Dokument; bei 'free' festes Intervall [freeScanIntervalSeconds].
  String _userPlanType = 'free';
  StreamSubscription<DocumentSnapshot>?
  _settingsSubscription; // Listener für Intervall-Änderungen
  /// Verhindert parallele [_performScan]-Läufe: sonst setzt ein zweiter Lauf sofort
  /// „Höre zu…“ und überschreibt die Erfolgszeile, bevor sie sichtbar wird.
  bool _performScanInFlight = false;
  String? _localRecognitionDeviceId;
  String? _activeRecognitionDeviceOwnerId;
  bool _ownsRecognitionLock = false;
  String? _lockedRecognitionPartyId;
  /// Ab wann ein fremder Lock als verwaist gilt (dann darf ein anderes Gerät starten).
  /// Muss **länger** sein als der maximale Abstand zwischen zwei Lease-Pings eines
  /// laufenden Dienstes (Scan-Ende pingt; Free bis 3 Min, Intervall bis 5 Min),
  /// sonst riskiert man Fremdübernahme bei Netz-Aussetzern.
  static const int _recognitionDeviceIdMaxLen = 128;

  // Kurzlebiger Apple-JWT nur über Callable getAppleMusicToken (~30 Min); Cache 25 Min / expiresAt.
  // Cache: bevorzugt Ablaufzeit [expiresAt] vom Server; sonst Fallback 25 Min ab Fetch.
  String? _currentToken;
  DateTime? _currentTokenFetchedAt;
  /// UTC-Zeitpunkt, zu dem das JWT laut Server abläuft (Unix exp aus Callable).
  DateTime? _currentTokenExpiresAtUtc;
  static const Duration _tokenRefreshWindow = Duration(minutes: 25);
  /// Vor JWT-Ablauf neu holen (Puffer gegen Uhrzeit/Netz).
  static const Duration _tokenRefreshSafetyMargin = Duration(minutes: 3);

  /// Shazam Native: ~8 s Aufnahme + Netz/ShazamKit — ohne Timeout kann Dart ewig warten.
  static const Duration _recognizeInvokeTimeout = Duration(seconds: 45);

  // Streams für Status-Updates
  final _statusController = StreamController<ShazamScanStatus>.broadcast();
  final _resultController = StreamController<Map<String, dynamic>?>.broadcast();

  // Gemeinsamer RMS-Stream (einmal erstellt, gecacht für mehrere Listener)
  Stream<double>? _rmsStream;

  /// Notifier für UI: Schieberegler/Footer auf „Aus“, sobald beim Party-Ende stopAutoScanning aufgerufen wird.
  final ValueNotifier<bool> recognitionActiveNotifier = ValueNotifier<bool>(
    false,
  );

  /// Nächster erlaubter Scan (interne Sperre, kein Footer-Countdown).
  DateTime? _nextScanAllowedAt;

  /// VibesBox Sync: Mikrofon-Erkennung bleibt aus, Ergebnisse kommen vom Tool.
  bool _externalRecognitionSourceActive = false;
  String? _lastHistoryPersistedKey;

  // Getter
  ShazamScanStatus get status => _status;
  Map<String, dynamic>? get lastResult => _lastResult;
  bool get isEnabled => _isEnabled;
  bool get isExternalRecognitionSourceActive =>
      _externalRecognitionSourceActive;

  void setExternalRecognitionSourceActive(bool active) {
    unawaited(setExternalRecognitionSourceActiveAsync(active));
  }

  /// Hält den Android-Foreground-Service, damit History-Writes auch im
  /// Hintergrund durchgehen (wie bei aktiver Mikrofon-Erkennung).
  Future<void> setExternalRecognitionSourceActiveAsync(bool active) async {
    final wasActive = _externalRecognitionSourceActive;
    _externalRecognitionSourceActive = active;
    if (active) {
      await _setNativeSyncKeepalivePref(true);
      await _ensureExternalRecognitionKeepalive();
      return;
    }
    await _setNativeSyncKeepalivePref(false);
    if (wasActive && !_isEnabled) {
      await _updateNotificationVisibility(
        false,
        contentText: _getNotificationRunning(),
      );
      await _stopForegroundServiceIfRunning();
    }
  }

  /// Native onResume darf den Sync-FGS nicht stoppen, nur weil die Mic-Leiste aus ist.
  Future<void> _setNativeSyncKeepalivePref(bool active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vb_sync_keepalive', active);
    } catch (e) {
      debugLog('⚠️ vb_sync_keepalive Pref: $e');
    }
  }

  int get scanIntervalSeconds => _scanIntervalSeconds;
  String? get activeRecognitionDeviceOwnerId => _activeRecognitionDeviceOwnerId;

  /// Free-DJ: fest 3 Minuten; sonst gespeichertes Intervall (Pro/Trial/Admin).
  int get effectiveScanIntervalSeconds =>
      _userPlanType == 'free' ? freeScanIntervalSeconds : _scanIntervalSeconds;
  double get micSensitivity => _micSensitivity;
  double get recognitionThreshold => _recognitionThreshold;
  bool get showStatusNotificationEnabled => _showStatusNotification;

  /// Synchronisiert die Statusleisten-Option aus [UserModel] (Geräte-gemergte Werte aus [UserService]).
  Future<void> syncShowStatusNotificationFromUserModel(UserModel user) async {
    final auth = FirebaseAuth.instance.currentUser;
    if (auth == null || auth.uid != user.id) return;
    final next = user.showStatusNotification;
    if (next == _showStatusNotification) return;
    await setShowStatusNotificationEnabled(next);
  }

  /// Free-DJ: Intelligente Steuerung hart auf false (auch wenn DB anders steht).
  bool get effectiveSmartThresholdEnabled =>
      _userPlanType == 'free' ? false : _smartThresholdEnabled;

  // Streams
  Stream<ShazamScanStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>?> get resultStream => _resultController.stream;

  // Stream für Benachrichtigungen über automatisch verschobene Wünsche
  final _wishMatchController =
      StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get wishMatchStream =>
      _wishMatchController.stream;
  final _notificationNavigationController =
      StreamController<String>.broadcast();
  Stream<String> get notificationNavigationStream =>
      _notificationNavigationController.stream;

  /// Setzt die lokalisierten Notification-Texte (von UI mit BuildContext aufrufen).
  /// Bei aktivem Scanning wird die Statusleiste sofort auf die neue Sprache aktualisiert.
  Future<void> setNotificationStrings(
    String title,
    String running,
    String successFormat,
  ) async {
    final changed =
        _notificationTitle != title ||
        _notificationRunning != running ||
        _notificationSuccessFormat != successFormat;
    _notificationTitle = title;
    _notificationRunning = running;
    _notificationSuccessFormat = successFormat;

    if (!changed) return;

    if (_isEnabled && _showStatusNotification) {
      final immediateText = getLocalizedCurrentStatus();
      unawaited(
        _updateNotificationVisibility(true, contentText: immediateText),
      );
      unawaited(pushLocalizedNotificationContentNow());
    }
  }

  String _getNotificationTitle() =>
      _notificationTitle ?? 'VibesBox Musikerkennung';
  String _getNotificationRunning() =>
      _notificationRunning ?? 'Musikerkennung läuft...';
  String _getNotificationSuccessFormat() =>
      _notificationSuccessFormat ?? 'Erkannt: %s';

  /// Anzeige für Statuszeile/Footer/Benachrichtigung: Titel und/oder Interpret (Shazam liefert nicht immer beides).
  static String? formatRecognizedTrackLabel(String title, String artist) {
    final t = decodeNotificationDisplayText(title.trim());
    final a = decodeNotificationDisplayText(artist.trim());
    if (t.isEmpty && a.isEmpty) return null;
    if (t == '-' && a == '-') return null;
    if (t.isNotEmpty && a.isNotEmpty) return '$t - $a';
    if (t.isNotEmpty) return t;
    return a;
  }

  String? _currentRecognizedSongLabel() {
    return formatRecognizedTrackLabel(
      (_lastResult?['title'] as String?)?.trim() ?? '',
      (_lastResult?['artist'] as String?)?.trim() ?? '',
    );
  }

  String getLocalizedCurrentStatus() {
    if (_isEnabled && _status == ShazamScanStatus.scanning) {
      return _getNotificationRunning();
    }
    final songLabel = _currentRecognizedSongLabel();
    if (songLabel != null) {
      return _getNotificationSuccessFormat().replaceFirst('%s', songLabel);
    }
    // Sync ersetzt das Mikrofon: keine „Höre gerade zu“-Meldung ohne Song.
    if (_externalRecognitionSourceActive && !_isEnabled) return '';
    return _lastNotificationText ?? _getNotificationRunning();
  }

  Future<void> _updateNotificationContent(
    String contentText, {
    String? navigationTarget,
  }) async {
    if (!_showStatusNotification && !_externalRecognitionSourceActive) return;
    final displayText = decodeNotificationDisplayText(contentText);
    if (displayText.isEmpty && _externalRecognitionSourceActive && !_isEnabled) {
      _lastNotificationText = '';
      if (Platform.isIOS) {
        await cancelShazamStatusNotification();
        return;
      }
    }
    _lastNotificationText = displayText;
    if (Platform.isIOS) {
      await showOrUpdateShazamStatusNotification(
        title: _getNotificationTitle(),
        body: displayText,
        payload: navigationTarget == _navigationTargetHistory
            ? 'shazam_history'
            : null,
      );
      return;
    }
    try {
      await _channel.invokeMethod<void>(_methodUpdateRecognitionNotification, {
        'notificationTitle': _getNotificationTitle(),
        'contentText': displayText,
        'navigationTarget': navigationTarget,
      });
    } catch (e) {
      debugLog('⚠️ Notification-Update fehlgeschlagen: $e');
    }
  }

  /// Direkter Echtzeit-Push für Locale-Wechsel (entkoppelt vom recognize()-Zyklus).
  Future<void> pushLocalizedNotificationContentNow() async {
    if (!_isEnabled || !_showStatusNotification) return;
    final contentText = decodeNotificationDisplayText(
      getLocalizedCurrentStatus(),
    );
    _lastNotificationText = contentText;
    if (Platform.isIOS) {
      await showOrUpdateShazamStatusNotification(
        title: _getNotificationTitle(),
        body: contentText,
      );
      return;
    }
    try {
      await _channel.invokeMethod<void>(_methodUpdateNotificationContent, {
        'notificationTitle': _getNotificationTitle(),
        'contentText': contentText,
      });
    } catch (e) {
      debugLog('⚠️ updateNotificationContent fehlgeschlagen: $e');
    }
  }

  void _emitNotificationNavigationTarget(String? target) {
    if (target == _navigationTargetHistory &&
        !_notificationNavigationController.isClosed) {
      _notificationNavigationController.add(target!);
    }
  }

  /// Tap auf iOS-Shazam-Status-Notification → History-Tab.
  void navigateToHistoryFromNotificationTap() {
    _emitNotificationNavigationTarget(_navigationTargetHistory);
  }

  Future<String?> consumePendingNavigationTarget() async {
    try {
      return await _channel.invokeMethod<String>(
        _methodConsumePendingNavigationTarget,
      );
    } catch (e) {
      debugLog('⚠️ Konnte Pending-Navigation-Target nicht lesen: $e');
      return null;
    }
  }

  /// Gemeinsamer RMS-Stream für Footer und Profil (als Broadcast-Stream)
  Stream<double> get rmsStream {
    _rmsStream ??= _rmsEventChannel.receiveBroadcastStream().cast<double>();
    return _rmsStream!;
  }

  // AUTOMATIC GAIN & THRESHOLD MAPPING: Stream für automatisch berechnete Werte
  Stream<Map<String, double>>? _autoAdjustStream;
  /// Broadcast-Stream für UI: Jedes Auto-Adjust-Update wird hier weitergeleitet, damit Slider etc. live mitgehen
  final StreamController<Map<String, double>> _autoAdjustUiController =
      StreamController<Map<String, double>>.broadcast();

  /// Initialisiert den autoAdjustStream frühzeitig, damit die Verbindung steht bevor Android sendet
  /// Wartet auf den Handshake mit Android, bevor es zurückkehrt
  Future<void> _initAutoAdjustStream() async {
    if (_autoAdjustStream == null) {
      debugLog('🔌 Initialisiere autoAdjustStream (EventChannel)...');
      _autoAdjustStream = _autoAdjustEventChannel
          .receiveBroadcastStream()
          .cast<Map<dynamic, dynamic>>()
          .map((data) {
            // Nur Pakete mit beiden Feldern verarbeiten (Handshake o.ä. ignorieren)
            if (!data.containsKey('mic_sensitivity') ||
                !data.containsKey('recognition_threshold')) {
              return null;
            }
            return {
              'mic_sensitivity': (data['mic_sensitivity'] as num).toDouble(),
              'recognition_threshold': (data['recognition_threshold'] as num)
                  .toDouble(),
            };
          })
          .where((data) => data != null)
          .cast<Map<String, double>>()
          .handleError((error) {
            debugLog('❌ autoAdjustStream Fehler: $error');
            // Stream bleibt aktiv auch bei Fehlern
          }, test: (error) => true);
      debugLog('✅ autoAdjustStream initialisiert');

      // Einziger Listener auf EventChannel: Werte übernehmen und an UI weiterleiten
      debugLog('🚀 Flutter: EventChannel-Stream wird jetzt abonniert...');
      // Subscription absichtlich nicht gehalten (dispose cancel ist bewusst auskommentiert).
      _autoAdjustStream!.listen(
        (data) {
          final sens = data['mic_sensitivity'];
          final thresh = data['recognition_threshold'];
          if (sens != null && sens >= 0.5 && sens <= 2.0) {
            _micSensitivity = sens;
            // Sicherheitsnetz: Auto-Adjust-Wert direkt wieder an Native geben,
            // falls dort zwischenzeitlich ein alter Wert aktiv ist.
            _channel
                .invokeMethod<void>('setMicSensitivity', {'sensitivity': sens})
                .catchError((error) {
                  debugLog(
                    '⚠️ Auto-Adjust: setMicSensitivity fehlgeschlagen: $error',
                  );
                });
          }
          if (thresh != null && thresh >= 0.0 && thresh <= 1.0) {
            _recognitionThreshold = thresh;
          }
          debugLog(
            '📡 autoAdjustStream: Werte übernommen -> _micSensitivity=$_micSensitivity, _recognitionThreshold=$_recognitionThreshold',
          );
          // UI sofort benachrichtigen, damit Slider/Anzeige live mitgehen
          if (!_autoAdjustUiController.isClosed) {
            _autoAdjustUiController.add(data);
          }
        },
        onError: (error) {
          debugLog('❌ autoAdjustStream Dummy-Listener Fehler: $error');
        },
        cancelOnError: false,
      );
      debugLog(
        '✅ Flutter: EventChannel-Stream abonniert - warte auf Handshake mit Android...',
      );

      await Future.delayed(const Duration(milliseconds: 300));
      debugLog('✅ Flutter: Handshake abgeschlossen - Verbindung steht!');
    } else {
      debugLog('✅ autoAdjustStream bereits initialisiert');
    }
  }

  /// Stream für UI: Jedes empfangene Auto-Adjust-Update (mic_sensitivity, recognition_threshold) wird hier ausgesendet.
  /// audio_settings_card (und andere) können darauf hören und Slider live aktualisieren.
  Stream<Map<String, double>> get autoAdjustStream {
    _initAutoAdjustStream();
    return _autoAdjustUiController.stream;
  }

  /// Prüft den Status der Mikrofon-Berechtigung (ohne Anfrage)
  /// Wird nur intern verwendet, um den Status zu prüfen
  Future<bool> checkMicrophonePermission() async {
    try {
      final permissionStatus = await Permission.microphone.status;
      return permissionStatus.isGranted;
    } catch (e) {
      debugLog('Fehler beim Prüfen der Mikrofon-Berechtigung: $e');
      return false;
    }
  }

  Future<void> _persistLastFreeScanCompleted(DateTime t) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefsKeyFreeLastScan(uid), t.millisecondsSinceEpoch);
  }

  /// Jitter 0–3999 ms. Admin (`userModel` / `AppConfig.isAdminRole`): 0 ms via [ProFeatureGuard.isAdmin].
  int _scalingJitterMilliseconds() {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null && ProFeatureGuard.isAdmin(u)) {
      return 0;
    }
    return Random().nextInt(4000);
  }

  Future<void> _runPeriodicScanWithScalingJitter(int jitterMs) async {
    if (!_isEnabled) return;
    if (jitterMs > 0) {
      await Future.delayed(Duration(milliseconds: jitterMs));
      if (!_isEnabled) return;
    }
    await _performScan();
  }

  /// Nach abgeschlossenem Scan: interne nächste Scan-Zeit (Free: 3 min ab jetzt, wie [freeScanIntervalSeconds]).
  Future<void> _armNextScanDeadlineAfterScanCompleted() async {
    if (!_isEnabled) return;
    if (_userPlanType == 'free') {
      _nextScanAllowedAt =
          DateTime.now().add(const Duration(seconds: freeScanIntervalSeconds));
      return;
    }
    final sec = effectiveScanIntervalSeconds;
    if (sec <= 0) {
      _nextScanAllowedAt = null;
    } else {
      _nextScanAllowedAt = DateTime.now().add(Duration(seconds: sec));
    }
  }

  /// Nach Trial-/Pro-Downgrade: Free-Limit sofort (nächster Scan frühestens nach Cooldown).
  Future<void> onDowngradedToFreeTier() async {
    await _persistLastFreeScanCompleted(DateTime.now());
    await loadScanInterval();
    if (_isEnabled && _userPlanType == 'free') {
      _scanTimer?.cancel();
      _scanTimer = null;
      _startTimer();
      unawaited(_armNextScanDeadlineAfterScanCompleted());
    }
  }

  /// Lädt die Scan-Intervall-Einstellung aus dem User-Profil.
  /// Free-DJ: Intervall fest [freeScanIntervalSeconds], intelligente Steuerung immer false.
  Future<void> loadScanInterval() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        _userPlanType =
            (data?['planType'] as String?)?.trim().toLowerCase() ?? 'free';

        final interval = data?['shazam_scan_interval_seconds'] as int?;
        if (interval != null && interval > 0 && _userPlanType != 'free') {
          _scanIntervalSeconds = interval;
        }
        if (_userPlanType == 'free') {
          _scanIntervalSeconds = freeScanIntervalSeconds;
          _smartThresholdEnabled = false;
        }

        // Lade auch Mikrofon-Empfindlichkeit (Free-DJ: Wert wird geladen, Nutzung in UI eingeschränkt)
        final sensitivity = data?['mic_sensitivity'] as num?;
        if (sensitivity != null) {
          final sensitivityValue = sensitivity.toDouble();
          if (sensitivityValue >= 0.5 && sensitivityValue <= 2.0) {
            _micSensitivity = sensitivityValue;
          }
        }

        // Lade Schwellenwert für Musikerkennung
        final threshold = data?['recognition_threshold'] as num?;
        if (threshold != null) {
          final thresholdValue = threshold.toDouble();
          if (thresholdValue >= 0.0 && thresholdValue <= 1.0) {
            _recognitionThreshold = thresholdValue;
          }
        }

        // Lade Smart-Threshold Einstellung (Free-DJ: hart false)
        if (_userPlanType != 'free') {
          final smartThreshold = data?['smart_threshold_enabled'] as bool?;
          if (smartThreshold != null) {
            _smartThresholdEnabled = smartThreshold;
          } else {
            _smartThresholdEnabled = false;
          }
        }

        final statusNotification = data?['show_status_notification'] as bool?;
        _showStatusNotification = statusNotification ?? false;
      }
    } catch (e) {
      debugLog('Fehler beim Laden des Scan-Intervalls: $e');
    }
  }

  Future<void> setShowStatusNotificationEnabled(
    bool enabled, {
    bool applyRuntime = true,
  }) async {
    _showStatusNotification = enabled;
    if (!applyRuntime) return;

    if (Platform.isIOS && enabled) {
      await ensureIosNotificationPermission();
    }

    if (_isEnabled || _externalRecognitionSourceActive) {
      // Sofortige Live-Reaktion an Android (ohne Scan-Neustart).
      await _updateNotificationVisibility(enabled);
      if (enabled) {
        // Erzwingt sofortiges Aufpoppen auch wenn der Laufzeitstatus inkonsistent war.
        _foregroundServiceRunning = false;
        await _startForegroundServiceIfNeeded();
        await _updateNotificationContent(getLocalizedCurrentStatus());
      }
    } else if (!enabled) {
      await _updateNotificationVisibility(false);
    }
  }

  /// Scans sind im Hintergrund erlaubt, wenn der FGS zuvor im Vordergrund erfolgreich gestartet wurde.
  /// Frischer FGS-Start bleibt auf [resumed] begrenzt (Android 14/15 Restriktionen).
  bool _lifecycleAllowsMicrophoneWork() {
    final s = WidgetsBinding.instance.lifecycleState;
    if (s == AppLifecycleState.resumed) return true;
    return _foregroundServicePrimedInForeground && _foregroundServiceRunning;
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    if (_foregroundServiceRunning) return;
    if (!_lifecycleAllowsMicrophoneWork()) {
      debugLog(
        '⚠️ Foreground Service nicht gestartet: AppLifecycleState ist nicht resumed '
        '(${WidgetsBinding.instance.lifecycleState})',
      );
      return;
    }
    try {
      final started = await _channel.invokeMethod<bool>(_methodStartScanning, {
        'showStatusNotification': _isEnabled
            ? _showStatusNotification
            : _externalRecognitionSourceActive &&
                getLocalizedCurrentStatus().isNotEmpty,
        'useMicrophone': _isEnabled,
        'notificationTitle': _getNotificationTitle(),
        'notificationListening': _isEnabled
            ? _getNotificationRunning()
            : getLocalizedCurrentStatus(),
      });
      if (started == true) {
        _foregroundServiceRunning = true;
        if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          _foregroundServicePrimedInForeground = true;
        }
        debugLog('✅ Foreground Service gestartet (Statuszeile aktiv)');
      } else {
        _foregroundServiceRunning = false;
        debugLog(
          '⚠️ Foreground Service wurde nicht gestartet '
          '(Start vom OS blockiert oder Berechtigung fehlt).',
        );
      }
    } catch (e) {
      debugLog('❌ Fehler beim Starten des Foreground Service: $e');
      _foregroundServiceRunning = false;
    }
  }

  Future<void> _stopForegroundServiceIfRunning() async {
    // Absichtlich ohne _foregroundServiceRunning-Guard:
    // Nach langer Background-Zeit kann der native Service noch laufen,
    // obwohl unser lokales Flag bereits false ist.
    await _invokeMethodWithTimeoutRetry<void>(
      _methodStopScanning,
      timeout: const Duration(seconds: 2),
      retries: 1,
      retryDelay: const Duration(milliseconds: 150),
    );
    _foregroundServiceRunning = false;
    _foregroundServicePrimedInForeground = false;
    debugLog('✅ Foreground Service gestoppt (Statuszeile aus)');
  }

  Future<void> _updateNotificationVisibility(
    bool visible, {
    String? contentText,
  }) async {
    final effectiveText = decodeNotificationDisplayText(
      contentText ?? getLocalizedCurrentStatus(),
    );
    if (Platform.isIOS) {
      if (!_showStatusNotification || !visible) {
        await cancelShazamStatusNotification();
        return;
      }
      await showOrUpdateShazamStatusNotification(
        title: _getNotificationTitle(),
        body: effectiveText,
      );
      return;
    }
    await _invokeMethodWithTimeoutRetry<void>(
      _methodUpdateNotificationVisibility,
      arguments: {
        'visible': visible,
        'notificationTitle': _getNotificationTitle(),
        'notificationListening': effectiveText,
      },
      timeout: const Duration(seconds: 2),
      retries: visible ? 0 : 1,
      retryDelay: const Duration(milliseconds: 120),
    );
  }

  Future<T?> _invokeMethodWithTimeoutRetry<T>(
    String method, {
    Map<String, dynamic>? arguments,
    Duration timeout = const Duration(seconds: 2),
    int retries = 0,
    Duration retryDelay = const Duration(milliseconds: 120),
  }) async {
    int attempt = 0;
    Object? lastError;
    while (attempt <= retries) {
      try {
        final call = _channel.invokeMethod<T>(method, arguments);
        final result = await call.timeout(timeout);
        return result;
      } catch (e) {
        lastError = e;
        if (attempt >= retries) break;
        debugLog(
          '⚠️ MethodChannel $method Timeout/Fehler '
          '(Versuch ${attempt + 1}/${retries + 1}) – retry...',
        );
        await Future.delayed(retryDelay);
      }
      attempt++;
    }
    debugLog('❌ MethodChannel $method endgültig fehlgeschlagen: $lastError');
    return null;
  }

  /// Nach [AppLifecycleState.resumed]: FGS nachziehen, wenn Erkennung aktiv war, Start im Hintergrund aber ausgelassen wurde.
  Future<void> syncForegroundAfterAppResumed() async {
    if (!_isEnabled && !_externalRecognitionSourceActive) return;
    if (!_showStatusNotification && !_externalRecognitionSourceActive) return;
    if (!_lifecycleAllowsMicrophoneWork()) return;
    try {
      if (_externalRecognitionSourceActive && !_isEnabled) {
        await _ensureExternalRecognitionKeepalive();
      } else {
        await _startForegroundServiceIfNeeded();
        if (_showStatusNotification) {
          await _updateNotificationContent(getLocalizedCurrentStatus());
        }
      }
    } catch (e) {
      debugLog('⚠️ syncForegroundAfterAppResumed: $e');
    }
  }

  /// Sync ohne Mikrofon: die Leiste gibt es nur, solange ein Song da ist.
  Future<void> _ensureExternalRecognitionKeepalive() async {
    if (!_externalRecognitionSourceActive || _isEnabled) return;
    final text = getLocalizedCurrentStatus();
    if (text.isEmpty) {
      try {
        await _updateNotificationVisibility(false);
        await _stopForegroundServiceIfRunning();
      } catch (e) {
        debugLog('⚠️ VibesBox Sync Leiste aus: $e');
      }
      return;
    }
    if (Platform.isIOS) {
      await ensureIosNotificationPermission();
    }
    try {
      await _startForegroundServiceIfNeeded();
      await _updateNotificationVisibility(true, contentText: text);
      await _updateNotificationContent(text);
    } catch (e) {
      debugLog('⚠️ VibesBox Sync Keepalive: $e');
    }
  }

  /// Speichert die Scan-Intervall-Einstellung im User-Profil
  Future<void> saveScanInterval(int seconds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _scanIntervalSeconds = seconds;
      await UserSelfSettingsService.instance.write({
        'shazam_scan_interval_seconds': seconds,
      });
    } catch (e) {
      debugLog('Fehler beim Speichern des Scan-Intervalls: $e');
      rethrow;
    }
  }

  /// Speichert Scan-Intervall mit Auto-Resume (Timer wird sofort neu gestartet).
  /// Free-DJ: Intervall wird auf [freeScanIntervalSeconds] erzwungen.
  Future<void> saveScanIntervalWithRestart(int seconds) async {
    if (_userPlanType == 'free') {
      seconds = freeScanIntervalSeconds;
    }
    final wasEnabled = _isEnabled;

    // Speichere neuen Wert
    await saveScanInterval(seconds);

    // Auto-Resume: Timer sofort zurücksetzen und neu starten (falls aktiv)
    if (wasEnabled) {
      debugLog(
        '🔄 Auto-Resume: Timer wird mit neuem Intervall ($seconds Sek.) neu gestartet...',
      );

      // Stoppe aktuellen Scan (nur der laufende Scan, nicht der Service)
      try {
        await _channel.invokeMethod<void>(_methodStopCurrentScan);
        debugLog('✅ Aktueller Scan gestoppt');
      } catch (e) {
        debugLog('⚠️ Fehler beim Stoppen des aktuellen Scans: $e');
        // Weiter machen, auch wenn Stop fehlschlägt
      }

      // Timer sofort zurücksetzen und neu starten (OHNE startAutoScanning aufzurufen)
      _scanTimer?.cancel();
      _scanTimer = null;
      _startTimer();

      // Führe sofort einen neuen Scan aus (mit neuem Intervall)
      debugLog('🎵 Führe sofortigen Scan mit neuem Intervall aus...');
      await _performScan();

      debugLog(
        '✅ Auto-Resume abgeschlossen - Timer läuft mit $seconds Sek. Intervall',
      );
    }
  }

  /// Speichert Mikrofon-Empfindlichkeit mit Hard-Stop & Restart
  /// Aktualisiert die Mikrofon-Empfindlichkeit OHNE Stream-Unterbrechung
  /// Die Sensitivity wird sofort an MainActivity weitergegeben und wirkt live
  /// Bei Fehler: Auto-Resume mit schnellem Re-Connect
  Future<void> updateMicSensitivityLive(double sensitivity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (sensitivity < 0.5 || sensitivity > 2.0) {
      throw Exception('Sensitivity muss zwischen 0.5 und 2.0 liegen');
    }

    final wasEnabled = _isEnabled;

    // Aktualisiere Wert sofort (ohne Hard-Stop)
    _micSensitivity = sensitivity;

    // Speichere in Firestore (async, blockiert nicht)
    UserSelfSettingsService.instance
        .write({'mic_sensitivity': sensitivity})
        .catchError((e) {
          debugLog('⚠️ Fehler beim Speichern der Sensitivity in Firestore: $e');
        });

    // Sende SOFORT an MainActivity (ohne Stream-Unterbrechung)
    // MainActivity wendet die Sensitivity direkt auf den laufenden Audio-Buffer an
    try {
      await _channel.invokeMethod<void>('setMicSensitivity', {
        'sensitivity': sensitivity,
      });
      debugLog(
        '✅ Sensitivity live aktualisiert: $sensitivity (Stream läuft weiter)',
      );
    } catch (e) {
      debugLog('❌ Fehler beim Aktualisieren der Sensitivity: $e');
      // Falls MainActivity nicht erreichbar ist, versuche schnellen Re-Connect
      if (wasEnabled) {
        debugLog('🔄 Auto-Resume: Versuche schnellen Re-Connect (< 100ms)...');
        await _quickReconnectForSensitivity();
      }
    }
  }

  /// Intelligente Anpassung: Status an Android senden.
  /// Free-DJ: wird hart auf false gehalten (ignoriert value).
  Future<void> setSmartThresholdEnabled(bool value) async {
    if (_userPlanType == 'free') value = false;
    _smartThresholdEnabled = value;
    try {
      await _channel.invokeMethod<void>('setSmartThresholdEnabled', {
        'enabled': value,
      });
    } catch (e) {
      debugLog('Fehler beim Senden von Smart-Threshold an Android: $e');
    }
  }

  /// Schneller Re-Connect für Sensitivity-Änderung (< 100ms)
  /// Auto-Resume: Startet Scan sofort neu, ohne den Service zu unterbrechen
  Future<void> _quickReconnectForSensitivity() async {
    try {
      // Stoppe nur den aktuellen Scan (nicht den gesamten Service)
      await _channel.invokeMethod<void>(_methodStopCurrentScan);

      // Warte minimal (< 50ms)
      await Future.delayed(const Duration(milliseconds: 50));

      // Starte Scan sofort neu (mit neuer Sensitivity)
      await _channel.invokeMethod<void>('recognize', {
        'token': await _getToken(),
        'mic_sensitivity': _micSensitivity,
      });

      debugLog('✅ Auto-Resume: Schneller Re-Connect abgeschlossen (< 100ms)');
    } catch (e) {
      debugLog('❌ Fehler beim schnellen Re-Connect: $e');
      // Falls Re-Connect fehlschlägt, versuche normalen Restart
      if (_isEnabled) {
        debugLog('🔄 Fallback: Starte normalen Restart...');
        // Temporär _isEnabled auf false setzen, damit startAutoScanning funktioniert
        final wasEnabled = _isEnabled;
        _isEnabled = false;
        await Future.delayed(const Duration(milliseconds: 50));
        _isEnabled = wasEnabled;
        await startAutoScanning();
      }
    }
  }

  /// Stabiler Marker in Exceptions / Stream-Payload (nicht lokalisiert).
  static const String _appCheckInvalidCode = 'APP_CHECK_INVALID';

  static String _tokenFetchErrorUserMessage(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) {
      s = s.substring('Exception: '.length).trim();
    }
    return s;
  }

  /// Lädt den Apple-JWT ausschließlich über [getAppleMusicToken] (30-Minuten-Ticket vom Server, Key nur in Secrets).
  Future<String> _getToken() async {
    final cachedToken = _getCachedAppleToken();
    if (cachedToken != null) {
      return cachedToken;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception(
        'Musikerkennung: Bitte anmelden (keine Sitzung).',
      );
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('getAppleMusicToken');
      final result = await callable.call();
      final data = Map<String, dynamic>.from(
        (result.data as Map?) ?? const <String, dynamic>{},
      );
      final token = (data['token'] as String?)?.trim() ?? '';
      if (token.isEmpty) {
        throw Exception('Token aus getAppleMusicToken ist leer');
      }

      _applyAppleTokenFromCallable(data, token);
      return token;
    } on FirebaseFunctionsException catch (e) {
      debugLog(
        '🔒 getAppleMusicToken: code=${e.code} message=${e.message}',
      );
      if (e.code == 'unauthenticated') {
        throw Exception(
          'Musikerkennung: Bitte neu anmelden (Sitzung nicht mehr gültig).',
        );
      }
      if (e.code == 'permission-denied') {
        final m = e.message ?? '';
        if (m.toLowerCase().contains('app check') ||
            m.contains('App Check')) {
          throw Exception(_appCheckInvalidCode);
        }
        throw Exception(
          m.isNotEmpty
              ? m
              : 'Musikerkennung: Zugriff verweigert (Rolle/DJ).',
        );
      }
      if (e.code == 'failed-precondition' || e.code == 'invalid-argument') {
        final m = e.message ?? '';
        throw Exception(
          m.isNotEmpty
              ? m
              : 'Musikerkennung: Server-Konfiguration (Apple-Secrets prüfen).',
        );
      }
      rethrow;
    }
  }

  /// Übernimmt Antwort von [getAppleMusicToken]: JWT + optionales [expiresAt] (Unix-Sekunden).
  void _applyAppleTokenFromCallable(Map<String, dynamic> data, String token) {
    _currentToken = token;
    _currentTokenFetchedAt = DateTime.now();
    final expUtc = _parseExpiresAtUnixSeconds(data['expiresAt']);
    _currentTokenExpiresAtUtc = expUtc;
    if (expUtc != null) {
      debugLog(
        '🔑 Apple-JWT: expiresAt=${expUtc.toIso8601String()} (Server), '
        'Cache erneuern ${_tokenRefreshSafetyMargin.inMinutes} Min vor Ablauf',
      );
    } else {
      debugLog(
        '🔑 Apple-JWT: kein expiresAt in Antwort — Fallback-Cache ${_tokenRefreshWindow.inMinutes} Min',
      );
    }
  }

  /// [expiresAt] aus Callable: Unix-Sekunden (JWT exp).
  DateTime? _parseExpiresAtUnixSeconds(dynamic raw) {
    if (raw == null) return null;
    final sec = switch (raw) {
      final int i => i,
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };
    if (sec == null || sec <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
  }

  void _clearAppleTokenCache() {
    _currentToken = null;
    _currentTokenFetchedAt = null;
    _currentTokenExpiresAtUtc = null;
  }

  Future<void> saveMicSensitivityWithRestart(double sensitivity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (sensitivity < 0.5 || sensitivity > 2.0) {
      throw Exception('Sensitivity muss zwischen 0.5 und 2.0 liegen');
    }

    final wasEnabled = _isEnabled;

    // Hard-Stop: Stoppe aktuellen Scan sofort
    if (wasEnabled) {
      debugLog('🛑 Hard-Stop: Stoppe aktuellen Scan für Sensitivity-Änderung...');
      await _hardStopCurrentScan();
    }

    // Speichere neuen Wert
    try {
      _micSensitivity = sensitivity;
      await UserSelfSettingsService.instance.write({
        'mic_sensitivity': sensitivity,
      });

      // Sende sofort an MainActivity
      await _channel.invokeMethod<void>('setMicSensitivity', {
        'sensitivity': sensitivity,
      });
    } catch (e) {
      debugLog('Fehler beim Speichern der Sensitivity: $e');
      rethrow;
    }

    // Restart: Starte mit neuer Sensitivity sofort neu
    if (wasEnabled) {
      debugLog('🚀 Restart: Starte Scan mit neuer Sensitivity ($sensitivity)...');
      await startAutoScanning();
    }
  }

  /// Hard-Stop: Stoppt aktuellen Scan sofort
  Future<void> _hardStopCurrentScan() async {
    // Stoppe Timer
    _scanTimer?.cancel();
    _scanTimer = null;

    // Stoppe aktuellen Scan über MethodChannel (falls aktiv)
    try {
      await _channel.invokeMethod<void>(_methodStopCurrentScan);
      debugLog('✅ Aktueller Scan gestoppt');
    } catch (e) {
      debugLog('⚠️ Fehler beim Stoppen des aktuellen Scans: $e');
      // Weiter machen, auch wenn Stop fehlschlägt
    }

    // Warte kurz, damit Native-Seite sauber aufräumen kann
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Startet das automatische Scanning mit dem konfigurierten Intervall.
  /// Vor Start wird pro Party ein exklusiver Geräte-Lock geprüft.
  Future<RecognitionStartOutcome> startAutoScanning() async {
    if (_externalRecognitionSourceActive) {
      debugLog(
        'VibesBox Sync aktiv — Mikrofon-Erkennung wird nicht gestartet.',
      );
      return RecognitionStartOutcome.denied;
    }
    if (_isEnabled) {
      debugLog('⚠️ startAutoScanning: Service ist bereits aktiv');
      return RecognitionStartOutcome.alreadyRunning;
    }
    final owner = FirebaseAuth.instance.currentUser;
    if (owner == null) {
      debugLog(
        '⚠️ startAutoScanning: Kein eingeloggter User – Foreground Service wird nicht gestartet',
      );
      return RecognitionStartOutcome.denied;
    }
    _serviceOwnerUid = owner.uid;

    // High-priority UI-Reaktion: Statusleiste sofort triggern, ohne auf Firestore/Init zu warten.
    if (_showStatusNotification) {
      final immediateText = getLocalizedCurrentStatus();
      unawaited(_startForegroundServiceIfNeeded());
      unawaited(
        _updateNotificationVisibility(true, contentText: immediateText),
      );
      unawaited(_updateNotificationContent(immediateText));
    }

    // Kein Gast: Musikerkennung für Free (mit Limit), Pro/Trial, Admin
    final allowed = await ProFeatureGuard.canUseMusicRecognition();
    if (!allowed) {
      debugLog('🔒 Musikerkennung gesperrt: Anmeldung oder Berechtigung fehlt.');
      _resultController.add({
        'title': '',
        'artist': '',
        'error': 'PRO_REQUIRED',
        'error_message': 'Musikerkennung ist nur mit Pro/Premium verfügbar.',
      });
      _updateStatus(ShazamScanStatus.error);
      return RecognitionStartOutcome.denied;
    }

    debugLog('🚀 Starte Shazam Auto-Scanning...');
    diagLog('SHAZAM', 'Auto-Scanning start (Intervall ${effectiveScanIntervalSeconds}s)');

    // Einstellungen früh laden, bevor über Notification-Sichtbarkeit entschieden wird.
    await loadScanInterval();

    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      _serviceOwnerUid = null;
      debugLog(
        '⚠️ ShazamService: Mikrofon nicht gewährt – startAutoScanning abgebrochen '
        '(kein Aufruf von startForegroundService / kein Crash)',
      );
      return RecognitionStartOutcome.denied;
    }
    // Nach dem frühen UI-Trigger hier nur noch final synchronisieren.
    if (!_showStatusNotification) {
      await _updateNotificationVisibility(false);
    }
    // Während des Betriebs: jeder Timer-Tick ruft [_performScan] auf.

    final lockResult = await _acquireRecognitionDeviceLock();
    if (lockResult == _RecognitionLockAcquireResult.blockedFreshOther) {
      _serviceOwnerUid = null;
      unawaited(_rollbackEarlyRecognitionUi());
      return RecognitionStartOutcome.blockedByOtherDevice;
    }
    if (lockResult == _RecognitionLockAcquireResult.firestoreError) {
      _serviceOwnerUid = null;
      unawaited(_rollbackEarlyRecognitionUi());
      return RecognitionStartOutcome.lockAcquireFailed;
    }

    final historyPartyId = _resolveRecognitionLockPartyId();
    if (historyPartyId != null && historyPartyId.isNotEmpty) {
      unawaited(HistoryProvider().ensureSessionForParty(historyPartyId));
    }

    // WICHTIG: Initialisiere autoAdjustStream FRÜH, damit die Verbindung steht bevor Android sendet
    _initAutoAdjustStream();

    debugLog(
      '📋 Geladenes Scan-Intervall: ${effectiveScanIntervalSeconds}s (Free: ${_userPlanType == 'free'})',
    );
    debugLog('🎤 Geladene Mikrofon-Empfindlichkeit: $_micSensitivity');
    _isEnabled = true;
    recognitionActiveNotifier.value = true;

    // Wakelock nur während des eigentlichen Scans (~8s), nicht die ganze Session.
    // Foreground Service hält den Prozess zwischen den Intervallen am Leben.
    if (_showStatusNotification) {
      await _updateNotificationContent(getLocalizedCurrentStatus());
    }
    try {
      await _channel.invokeMethod<void>('setMicSensitivity', {
        'sensitivity': _micSensitivity,
      });
    } catch (e) {
      debugLog('❌ Fehler beim Setzen der Mikrofon-Empfindlichkeit: $e');
    }

    // Führe ersten Scan sofort aus
    debugLog('🎵 Führe ersten Scan sofort aus...');
    await _performScan();

    // Starte Timer für periodische Scans
    _startTimer();
    return RecognitionStartOutcome.started;
  }

  /// Startet den Timer für periodische Scans
  void _startTimer() {
    // Stoppe alten Timer falls vorhanden
    _scanTimer?.cancel();
    _scanTimer = null;

    // Free-DJ: fest 3 Min.; sonst gewähltes Intervall
    final intervalToUse = effectiveScanIntervalSeconds;

    debugLog('⏱️ Shazam-Timer gestartet mit Intervall: $intervalToUse Sekunden');

    // Starte neuen Timer
    _scanTimer = Timer.periodic(Duration(seconds: intervalToUse), (_) async {
      debugLog('⏱️ Timer-Tick: Führe Scan durch (Intervall: $intervalToUse Sek.)');

      final now = DateTime.now();
      if (_nextScanAllowedAt != null && now.isBefore(_nextScanAllowedAt!)) {
        if (_status != ShazamScanStatus.idle) {
          _updateStatus(ShazamScanStatus.idle);
        }
        return;
      }

      // Skalierungs-Optimierung: Zufällige Verzögerung (Jitter) 0–4 s; Admin ohne Jitter.
      final jitterMs = _scalingJitterMilliseconds();
      if (jitterMs > 0) {
        debugLog('⏳ Skalierungs-Schutz: Warte ${jitterMs}ms vor Scan...');
      }
      await _runPeriodicScanWithScalingJitter(jitterMs);
    });
  }

  /// Stoppt das automatische Scanning
  Future<void> stopAutoScanning() async {
    debugLog('🛑 Stoppe Shazam Auto-Scanning...');
    diagLog('SHAZAM', 'Auto-Scanning Stopp');
    // Zuerst nativen Lauf abbrechen, damit `recognize` nicht offen bleibt und
    // [_performScanInFlight] zuverlässig frei wird.
    try {
      await _invokeMethodWithTimeoutRetry<void>(
        _methodStopCurrentScan,
        timeout: const Duration(seconds: 3),
        retries: 1,
        retryDelay: const Duration(milliseconds: 150),
      );
    } catch (e) {
      debugLog('⚠️ stopCurrentScan beim Gesamtstopp: $e');
    }
    await Future.delayed(const Duration(milliseconds: 150));
    _nextScanAllowedAt = null;
    _isEnabled = false;
    _serviceOwnerUid = null;
    recognitionActiveNotifier.value = false;
    await _releaseRecognitionDeviceLock();

    // Deaktiviere Wakelock
    try {
      await WakelockPlus.disable();
      debugLog('🔋 Wakelock deaktiviert');
    } catch (e) {
      debugLog('⚠️ Fehler beim Deaktivieren des Wakelocks: $e');
    }

    // Stoppe Settings-Listener
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    debugLog('👂 Settings-Listener gestoppt');

    // Stoppe Timer
    _scanTimer?.cancel();
    _scanTimer = null;
    debugLog('⏹️ Timer gestoppt');

    // VibesBox Sync braucht denselben Android-FGS weiter, sonst blockiert
    // das OS History-Writes sobald die App im Hintergrund ist.
    if (_externalRecognitionSourceActive) {
      await _ensureExternalRecognitionKeepalive();
    } else {
      await _updateNotificationVisibility(
        false,
        contentText: _getNotificationRunning(),
      );
      await _stopForegroundServiceIfRunning();
    }

    if (_status != ShazamScanStatus.idle) {
      _status = ShazamScanStatus.idle;
      _statusController.add(_status);
    }

    debugLog('✅ Shazam Auto-Scanning gestoppt');
  }

  Future<void> _rollbackEarlyRecognitionUi() async {
    if (!_showStatusNotification) return;
    try {
      await _updateNotificationVisibility(
        false,
        contentText: _getNotificationRunning(),
      );
      await _stopForegroundServiceIfRunning();
    } catch (e) {
      debugLog('⚠️ Rollback Recognition-UI nach Lock-Fehler: $e');
    }
  }

  /// Wird vom [ActivePartyService]-Heartbeat (~2 min) aufgerufen: hält die Lease „frisch“.
  void pingRecognitionLeaseFromPartyHeartbeat() {
    unawaited(_pingRecognitionLeaseFromPartyHeartbeatAsync());
  }

  Future<void> _pingRecognitionLeaseFromPartyHeartbeatAsync() async {
    if (!_isEnabled || !_ownsRecognitionLock) return;
    final partyId =
        _lockedRecognitionPartyId ?? _resolveRecognitionLockPartyId();
    if (partyId == null || partyId.isEmpty || partyId == 'manual') return;
    final deviceId = await _getRecognitionDeviceId();
    await PartySecureService.instance.pingRecognitionLock(
      partyId: partyId,
      deviceId: deviceId,
    );
  }

  static String _normalizeRecognitionDeviceId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'device_unknown';
    if (trimmed.length <= _recognitionDeviceIdMaxLen) return trimmed;
    return trimmed.substring(0, _recognitionDeviceIdMaxLen);
  }

  Future<String> _getRecognitionDeviceId() async {
    if (_localRecognitionDeviceId != null && _localRecognitionDeviceId!.isNotEmpty) {
      return _localRecognitionDeviceId!;
    }
    const fallback = 'device_unknown';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = (prefs.getString('recognition_device_id') ?? '').trim();
      if (cached.isNotEmpty && cached != fallback) {
        final normalized = _normalizeRecognitionDeviceId(cached);
        _localRecognitionDeviceId = normalized;
        if (normalized != cached) {
          await prefs.setString('recognition_device_id', normalized);
        }
        return normalized;
      }

      final plugin = DeviceInfoPlugin();
      String resolved = fallback;
      if (kIsWeb) {
        resolved = 'web_recognition_device';
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        resolved = (info.id).trim();
        if (resolved.isEmpty) {
          resolved = info.fingerprint.trim();
        }
      } else if (Platform.isIOS) {
        resolved = await getStableIosDeviceId(
          mirrorPrefsKey: 'recognition_device_id',
          fallback: fallback,
        );
      }
      resolved = _normalizeRecognitionDeviceId(
        resolved.isEmpty ? fallback : resolved,
      );
      await prefs.setString('recognition_device_id', resolved);
      _localRecognitionDeviceId = resolved;
      return resolved;
    } catch (e) {
      debugLog('⚠️ Ermittlung recognition_device_id fehlgeschlagen: $e');
      _localRecognitionDeviceId = fallback;
      return fallback;
    }
  }

  /// Party-ID-Kandidaten: Visibility (Offen-Tab) zuerst, dann Heartbeat.
  static List<String> _recognitionLockPartyIdCandidates() {
    final ids = <String>[];
    void add(String? id) {
      if (id == null || id.isEmpty || id == 'manual') return;
      if (!ids.contains(id)) ids.add(id);
    }

    add(OpenWishesVisibilityService.visibilityNotifier.value?.partyId);
    add(ActivePartyService.currentPartyId);
    return ids;
  }

  static String? _resolveRecognitionLockPartyId() {
    final candidates = _recognitionLockPartyIdCandidates();
    return candidates.isEmpty ? null : candidates.first;
  }

  void _clearLocalRecognitionLockState() {
    _activeRecognitionDeviceOwnerId = null;
    _ownsRecognitionLock = false;
    _lockedRecognitionPartyId = null;
  }

  void _applyRecognitionLockAcquireState({
    required _RecognitionLockAcquireResult result,
    required String partyId,
    required String deviceId,
    String? conflictingDevice,
  }) {
    if (result == _RecognitionLockAcquireResult.acquired) {
      _ownsRecognitionLock = true;
      _lockedRecognitionPartyId = partyId;
      _activeRecognitionDeviceOwnerId = deviceId;
    } else {
      _ownsRecognitionLock = false;
      _lockedRecognitionPartyId = null;
      final other = conflictingDevice?.trim();
      _activeRecognitionDeviceOwnerId =
          (other != null && other.isNotEmpty) ? other : null;
    }
  }

  Future<_RecognitionLockAcquireResult> _acquireRecognitionDeviceLock() async {
    final partyIds = _recognitionLockPartyIdCandidates();
    if (partyIds.isEmpty) {
      _clearLocalRecognitionLockState();
      return _RecognitionLockAcquireResult.acquired;
    }

    final deviceId = await _getRecognitionDeviceId();
    _RecognitionLockAcquireResult? blockedResult;
    String? blockedOther;

    for (final partyId in partyIds) {
      final result = await PartySecureService.instance.acquireRecognitionLock(
        partyId: partyId,
        deviceId: deviceId,
      );
      switch (result.status) {
        case RecognitionLockAcquireStatus.acquired:
          _applyRecognitionLockAcquireState(
            result: _RecognitionLockAcquireResult.acquired,
            partyId: partyId,
            deviceId: deviceId,
          );
          return _RecognitionLockAcquireResult.acquired;
        case RecognitionLockAcquireStatus.blocked:
          blockedResult = _RecognitionLockAcquireResult.blockedFreshOther;
          blockedOther = result.otherDevice;
          _applyRecognitionLockAcquireState(
            result: blockedResult,
            partyId: partyId,
            deviceId: deviceId,
            conflictingDevice: blockedOther,
          );
          return blockedResult;
        case RecognitionLockAcquireStatus.error:
          diagLog(
            'SHAZAM',
            'Recognition-Lock Fehler für partyId=$partyId — nächster Kandidat',
          );
          continue;
      }
    }

    _clearLocalRecognitionLockState();
    diagLog(
      'SHAZAM',
      'Recognition-Lock endgültig fehlgeschlagen (partyIds=$partyIds)',
    );
    return _RecognitionLockAcquireResult.firestoreError;
  }

  /// Gibt unsere Geräte-Sperre frei — auch wenn [stopAutoScanning] nicht lief.
  Future<void> releaseRecognitionDeviceLockIfHeld() async {
    await _releaseRecognitionDeviceLock();
  }

  /// Entfernt die Party-Sperre vollständig (DJ übernimmt auf diesem Gerät).
  Future<void> forceClearRecognitionLockForCurrentParty() async {
    final partyId = _resolveRecognitionLockPartyId();
    if (partyId == null || partyId.isEmpty || partyId == 'manual') return;
    final deviceId = await _getRecognitionDeviceId();
    await PartySecureService.instance.releaseRecognitionLock(
      partyId: partyId,
      deviceId: deviceId,
      force: true,
    );
    _clearLocalRecognitionLockState();
  }

  Future<void> _releaseRecognitionDeviceLock() async {
    final partyId = _lockedRecognitionPartyId ?? _resolveRecognitionLockPartyId();
    if (partyId == null || partyId.isEmpty || partyId == 'manual') {
      _clearLocalRecognitionLockState();
      return;
    }
    final deviceId = await _getRecognitionDeviceId();
    await PartySecureService.instance.releaseRecognitionLock(
      partyId: partyId,
      deviceId: deviceId,
    );
    _clearLocalRecognitionLockState();
  }

  /// Führt einen einzelnen Scan durch
  Future<void> _performScan() async {
    if (!_isEnabled) return;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (_serviceOwnerUid == null ||
        currentUid == null ||
        currentUid != _serviceOwnerUid) {
      debugLog(
        '⚠️ _performScan: UID-Kontext geändert oder ungültig – stoppe lokalen Service-Schutz',
      );
      await stopAutoScanning();
      return;
    }

    if (!_lifecycleAllowsMicrophoneWork()) {
      debugLog(
        '⏭️ _performScan übersprungen: App nicht im Vordergrund (resumed). '
        'State=${WidgetsBinding.instance.lifecycleState}',
      );
      if (_status != ShazamScanStatus.idle) {
        _updateStatus(ShazamScanStatus.idle);
      }
      return;
    }

    // Session/Login: Free bleibt erlaubt (Limit im Service)
    final allowed = await ProFeatureGuard.canUseMusicRecognition();
    if (!allowed) {
      debugLog(
        '🔒 Musikerkennung während Betrieb gesperrt (kein Zugriff). Stoppe Service.',
      );
      _resultController.add({
        'title': '',
        'artist': '',
        'error': 'PRO_REQUIRED',
        'error_message': 'Musikerkennung ist nur mit Pro/Premium verfügbar.',
      });
      _updateStatus(ShazamScanStatus.error);
      await stopAutoScanning();
      return;
    }

    final now = DateTime.now();
    if (_nextScanAllowedAt != null && now.isBefore(_nextScanAllowedAt!)) {
      if (_status != ShazamScanStatus.idle) {
        _updateStatus(ShazamScanStatus.idle);
      }
      return;
    }

    if (_performScanInFlight) {
      debugLog(
        '⏭️ _performScan übersprungen: vorheriger Lauf noch aktiv '
        '(verhindert, dass „Höre zu…“ die Erkennungszeile überschreibt).',
      );
      return;
    }
    _performScanInFlight = true;
    var heldWakeLock = false;
    try {
      _updateStatus(ShazamScanStatus.scanning);
      if (_showStatusNotification) {
        await _updateNotificationContent(getLocalizedCurrentStatus());
      }

      // Prüfe Mikrofon-Berechtigung
      var permissionStatus = await Permission.microphone.status;
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.microphone.request();
      }

      if (!permissionStatus.isGranted) {
        _updateStatus(ShazamScanStatus.error);
        _handleNoMatchOrError();
        return;
      }

      String token;
      try {
        token = await _getToken();
      } catch (e) {
        debugLog('⚠️ Fehler beim Laden des Tokens über Cloud Function: $e');
        final msg = _tokenFetchErrorUserMessage(e);
        final isAppCheckMsg = msg == _appCheckInvalidCode;
        _resultController.add({
          'title': '',
          'artist': '',
          'error': isAppCheckMsg ? 'APP_CHECK_INVALID' : 'TOKEN_ERROR',
          'error_message': isAppCheckMsg
              ? _appCheckInvalidCode
              : (msg.isNotEmpty
                  ? msg
                  : 'Lizenz-Fehler: Token konnte nicht geladen werden.'),
        });
        _updateStatus(ShazamScanStatus.error);
        _handleNoMatchOrError();
        if (isAppCheckMsg) {
          _showGlobalAppCheckSnack();
          await stopAutoScanning();
        }
        return;
      }

      // Kein JWT-Inhalt oder Präfix in Logs (nur Hinweis, dass der Abruf geklappt hat).
      debugLog('🔑 Apple-Token für Shazam aus Callable geladen.');

      // WICHTIG: Stelle sicher, dass die Daten-Brücke steht, bevor der Scan startet
      await _initAutoAdjustStream();

      // Display/CPU wach nur während Native-Recognize (~8s).
      try {
        await WakelockPlus.enable();
        heldWakeLock = true;
      } catch (e) {
        debugLog('⚠️ Wakelock während Scan: $e');
      }

      // Führe Shazam-Scan durch (Free-DJ: intelligente Steuerung immer false)
      Map<dynamic, dynamic>? result;
      // Party-Kontext **unmittelbar vor** Native-Recognize: verhindert Wunsch-Schreibungen,
      // wenn erst während des Scans eine Party „dazukommt“ (langer ShazamKit-Lauf).
      String? partyIdWhenNativeRecognizeStarted;
      try {
        partyIdWhenNativeRecognizeStarted = _resolveShazamWishPartyId();
        result = await _channel
            .invokeMethod<Map<dynamic, dynamic>>('recognize', {
              'token': token,
              'mic_sensitivity': _micSensitivity,
              'recognition_threshold': _recognitionThreshold,
              'smart_threshold_enabled': effectiveSmartThresholdEnabled,
            })
            .timeout(_recognizeInvokeTimeout);
      } on TimeoutException catch (_) {
        debugLog(
          '⏱️ recognize-Timeout (${_recognizeInvokeTimeout.inSeconds}s) – '
          'Native-Scan abbrechen',
        );
        try {
          await _invokeMethodWithTimeoutRetry<void>(
            _methodStopCurrentScan,
            timeout: const Duration(seconds: 3),
            retries: 1,
            retryDelay: const Duration(milliseconds: 150),
          );
        } catch (e) {
          debugLog('⚠️ stopCurrentScan nach Timeout: $e');
        }
        await Future.delayed(const Duration(milliseconds: 150));
        result = null;
      }

      if (_userPlanType == 'free') {
        await _persistLastFreeScanCompleted(DateTime.now());
      }

      try {
        if (result != null) {
          // Prüfe auf Token-Fehler
          final error = result['error'] as String?;
          if (error == 'INVALID_SIGNATURE') {
            final errorMessage =
                result['error_message'] as String? ??
                'Apple Developer Token ungültig oder abgelaufen';
            debugLog('❌ Shazam: $errorMessage');
            // iOS: ShazamKit-Fehler 202 — fast immer fehlende App-ID-Capability, nicht das Music-JWT.
            if (!kIsWeb && Platform.isIOS) {
              debugLog(
                '💡 iOS: developer.apple.com → Identifiers → diese App-ID → Capability „ShazamKit“ '
                'einschalten → Xcode Signing/Provisioning neu ziehen. Ohne Entitlement erkennt '
                'ShazamKit keine Songs.',
              );
              _showGlobalSnack(errorMessage, backgroundColor: Colors.red.shade900);
              _updateStatus(ShazamScanStatus.error);
              _handleNoMatchOrError();
              return;
            }
            debugLog('💡 Android: Apple-Music-Developer-Token prüfen (Callable getAppleMusicToken).');
            _clearAppleTokenCache();
            _updateStatus(ShazamScanStatus.error);
            _handleNoMatchOrError();
            return;
          }
          if (error == 'PERMISSION_DENIED') {
            final msg =
                result['error_message'] as String? ??
                'Mikrofon-Berechtigung verweigert (iOS).';
            debugLog('❌ Musikerkennung: $msg');
            _updateStatus(ShazamScanStatus.error);
            _handleNoMatchOrError();
            return;
          }

          // Sichere Null-Werte-Behandlung (mindestens Titel oder Interpret nötig für Anzeige)
          final title = result['title'] as String? ?? '';
          final artist = result['artist'] as String? ?? '';

          final label = formatRecognizedTrackLabel(title, artist);
          if (label != null) {
            final songData = {'title': title, 'artist': artist};

            _lastResult = songData;
            _updateStatus(ShazamScanStatus.success);
            final successText = _getNotificationSuccessFormat().replaceFirst(
              '%s',
              label,
            );
            if (_showStatusNotification) {
              await _updateNotificationContent(
                successText,
                navigationTarget: _navigationTargetHistory,
              );
            }
            _resultController.add(songData);

            unawaited(
              HistoryProvider().recordRecognizedTrack(
                title: title,
                artist: artist,
                partyId: partyIdWhenNativeRecognizeStarted,
              ),
            );

            // Wunsch-Abgleich nur mit vollständigen Metadaten (Titel + Interpret).
            // Zusätzlich: Party muss schon **vor** Native-Recognize bestanden haben und unverändert
            // geblieben sein; plus Firestore-Lauf-Check (keine Zuordnung zu später gestarteter Party).
            final boundParty = partyIdWhenNativeRecognizeStarted;
            final resolvedNow = _resolveShazamWishPartyId();
            final hasStablePartyContext =
                boundParty != null &&
                boundParty.isNotEmpty &&
                boundParty != 'manual' &&
                resolvedNow != null &&
                boundParty == resolvedNow &&
                title.trim().isNotEmpty &&
                artist.trim().isNotEmpty;

            if (hasStablePartyContext) {
              final runningOk =
                  await ActivePartyService.isPartyIdRunningNowForCurrentDj(
                    boundParty,
                  );
              if (runningOk) {
                await _checkAndUpdateWishes(title, artist, partyId: boundParty);
              } else {
                debugLog(
                  'Musikerkennung: kein Wunsch-Abgleich – Party läuft laut Firestore nicht '
                  'oder Kontext ungültig (partyId=$boundParty, Label: $label)',
                );
              }
            } else if (boundParty == null ||
                boundParty.isEmpty ||
                boundParty == 'manual') {
              debugLog(
                '🧪 Testmodus: Song erkannt ohne Party-Kontext zum Scan-Start: $label',
              );
            } else if (title.trim().isNotEmpty && artist.trim().isNotEmpty) {
              debugLog(
                'Musikerkennung: kein Wunsch-Abgleich – Party-Kontext hat sich während des Scans '
                'geändert (Start: $boundParty, jetzt: $resolvedNow, Label: $label)',
              );
            }

            // Setze Status nach kurzer Zeit wieder auf idle, damit Pegelanzeige zurückfällt
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isEnabled && _status == ShazamScanStatus.success) {
                _updateStatus(ShazamScanStatus.idle);
              }
            });
          } else {
            // Kein Match oder leere Werte - behandle wie NoMatch
            _handleNoMatchOrError();
          }
        } else {
          // Kein Ergebnis - behandle wie NoMatch
          _handleNoMatchOrError();
        }
      } finally {
        unawaited(_armNextScanDeadlineAfterScanCompleted());
        // Lease unabhängig vom Party-Heartbeat frisch halten (verhindert
        // Fremdübernahme nach nur wenigen Minuten ohne Session-Heartbeat).
        unawaited(_pingRecognitionLeaseFromPartyHeartbeatAsync());
      }
    } catch (e, st) {
      debugLog('Fehler beim Shazam-Scan: $e');
      diagLog('SHAZAM', 'Scan-Fehler: $e\n$st');
      _updateStatus(ShazamScanStatus.error);
      _handleNoMatchOrError();
    } finally {
      if (heldWakeLock) {
        try {
          await WakelockPlus.disable();
        } catch (e) {
          debugLog('⚠️ Wakelock nach Scan: $e');
        }
      }
      _performScanInFlight = false;
    }
  }

  /// Track aus VibesBox Sync (Rekordbox-Tool) — gleicher Pfad wie Mikrofon-Erkennung:
  /// Footer, History, 5 Vorschläge, Offen / Vorab / Setlisten.
  /// Gibt true zurück, wenn der Track in der History steht (oder schon stand).
  Future<bool> ingestExternalRecognition({
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    String? musicalKey,
    int? durationSec,
  }) async {
    final t = title.trim();
    final a = artist.trim();
    final label = formatRecognizedTrackLabel(t, a);
    if (label == null) return false;

    final songData = <String, dynamic>{
      'title': t,
      'artist': a,
      if (bpm != null) 'bpm': bpm,
      if (camelot != null && camelot.isNotEmpty) 'camelot': camelot,
      if (musicalKey != null && musicalKey.isNotEmpty) 'key': musicalKey,
      if (durationSec != null && durationSec > 0) 'durationSec': durationSec,
      'source': 'vibesbox_sync',
    };

    final prevTitle = (_lastResult?['title'] as String?)?.trim();
    final prevArtist = (_lastResult?['artist'] as String?)?.trim();
    final sameTrack = prevTitle == t && prevArtist == a;
    _lastResult = songData;
    _updateStatus(ShazamScanStatus.success);
    _resultController.add(songData);

    unawaited(_ensureExternalRecognitionKeepalive());

    final historyKey = '${t.toLowerCase()}|${a.toLowerCase()}';
    var saved = _lastHistoryPersistedKey == historyKey;
    if (!saved) {
      final partyId = _resolveShazamWishPartyId();
      saved = await HistoryProvider().recordRecognizedTrack(
        title: t,
        artist: a,
        partyId: partyId,
        bpm: bpm,
        camelot: camelot,
        key: musicalKey,
        durationSec: durationSec,
        source: 'vibesbox_sync',
      );
      if (saved) {
        _lastHistoryPersistedKey = historyKey;
      } else {
        diagLog(
          'HISTORY',
          'VibesBox Sync: History-Write fehlgeschlagen '
          'title=$t artist=$a party=${partyId ?? "null"}',
        );
      }
    }

    if (sameTrack) return saved;

    final partyId = _resolveShazamWishPartyId();
    if (partyId == null ||
        partyId.isEmpty ||
        partyId == 'manual' ||
        t.isEmpty ||
        a.isEmpty) {
      return saved;
    }
    final runningOk =
        await ActivePartyService.isPartyIdRunningNowForCurrentDj(partyId);
    if (runningOk) {
      await _checkAndUpdateWishes(t, a, partyId: partyId);
    }
    return saved;
  }

  /// VibesBox Sync: kein laufender Track (10 Min. ohne neuen Eintrag oder Tool idle).
  void clearExternalRecognition() {
    const idle = <String, dynamic>{
      'title': '',
      'artist': '',
      'source': 'vibesbox_sync',
      'idle': true,
    };
    _lastResult = idle;
    _lastHistoryPersistedKey = null;
    _updateStatus(ShazamScanStatus.idle);
    _resultController.add(idle);
    if (_externalRecognitionSourceActive && !_isEnabled) {
      unawaited(_ensureExternalRecognitionKeepalive());
    }
  }

  /// Party-ID für Wunsch-Abgleich (Offen + Vorab): Heartbeat, Visibility, Session.
  static String? _resolveShazamWishPartyId() {
    final heartbeat = ActivePartyService.currentPartyId;
    if (heartbeat != null && heartbeat.isNotEmpty && heartbeat != 'manual') {
      return heartbeat;
    }
    final fromVisibility = OpenWishesVisibilityService.resolveDjWishPartyId();
    if (fromVisibility != null && fromVisibility.isNotEmpty) {
      return fromVisibility;
    }
    final stored = ActivePartyService.getStoredSession()?.partyId;
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  static String _wishTitleFromData(Map<String, dynamic> data) {
    final title = (data['title'] as String? ?? '').trim();
    if (title.isNotEmpty) return title;
    return (data['song'] as String? ?? '').trim();
  }

  static String _wishArtistFromData(Map<String, dynamic> data) {
    return (data['artist'] as String? ?? '').trim();
  }

  /// Prüft erkannte Songs gegen Wunschliste und aktualisiert Status automatisch.
  /// Alle Treffer aus allen Quellen im selben Scan:
  /// Offen (inkl. Duplikate) + Vorab + noch offene DJ-Setlist-Tracks.
  Future<void> _checkAndUpdateWishes(
    String title,
    String artist, {
    required String partyId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (partyId.isEmpty || partyId == 'manual') {
        return;
      }

      final threshold = await _loadWishMatchThreshold();
      final ignored = DuplicateCheckService.getCachedIgnoredKeywords();
      final normalizedTitle = normalizeTextForDuplicateCheck(title, ignored);
      final normalizedArtist = normalizeTextForDuplicateCheck(artist, ignored);

      final openSnapshot = await WishPaths.partyWishes(partyId)
          .where('status', isEqualTo: 'pending')
          .limit(200)
          .get();

      final openHits = await _tryMatchRecognizedSongInDocs(
        openSnapshot.docs,
        normalizedTitle: normalizedTitle,
        normalizedArtist: normalizedArtist,
        ignored: ignored,
        threshold: threshold,
        includeQueuedPreWish: false,
      );

      // Gleiche Query wie Tab „Vorab“ (is_pre_wish + pending).
      var preHits = 0;
      final preSnapshot = await WishPaths.partyWishes(partyId)
          .where('status', isEqualTo: 'pending')
          .where('is_pre_wish', isEqualTo: true)
          .limit(200)
          .get();

      if (preSnapshot.docs.isNotEmpty) {
        preHits = await _tryMatchRecognizedSongInDocs(
          preSnapshot.docs,
          normalizedTitle: normalizedTitle,
          normalizedArtist: normalizedArtist,
          ignored: ignored,
          threshold: threshold,
          includeQueuedPreWish: true,
        );
      }

      // Unabhängig von Wunsch-Treffern: Setliste ebenfalls vollständig abarbeiten.
      var setlistHits = 0;
      if (ProFeatureGuard.canUseProExclusiveNow()) {
        setlistHits = await DjSetlistTrackActionsService.instance
            .markRecognizedMatchesPlayed(
          partyId: partyId,
          normalizedTitle: normalizedTitle,
          normalizedArtist: normalizedArtist,
          ignored: ignored,
          threshold: threshold,
          similarity: StringSimilarity.compareTwoStrings,
          normalize: normalizeTextForDuplicateCheck,
        );
      }

      final total = openHits + preHits + setlistHits;
      if (total > 0) {
        debugLog(
          'Musikerkennung: $total Treffer → played '
          '(offen=$openHits, vorab=$preHits, setlist=$setlistHits, party=$partyId)',
        );
        diagLog(
          'SHAZAM',
          'Match-Batch: total=$total offen=$openHits vorab=$preHits '
          'setlist=$setlistHits party=$partyId',
        );
      }
    } catch (e) {
      debugLog('❌ Fehler beim Abgleich mit Wunschliste: $e');
      diagLog('SHAZAM', 'Wunsch-Abgleich fehlgeschlagen (party=$partyId): $e');
    }
  }

  Future<double> _loadWishMatchThreshold() async {
    double threshold = 0.85;
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .get();

      if (settingsDoc.exists) {
        final thresholdValue = settingsDoc.data()?['duplicate_threshold'];
        if (thresholdValue is double) {
          threshold = thresholdValue;
        } else if (thresholdValue is num) {
          threshold = thresholdValue.toDouble();
        }
        debugLog(
          '🔍 Wunsch-Abgleich mit Threshold: ${(threshold * 100).toStringAsFixed(1)}%',
        );
      }
    } catch (e) {
      debugLog(
        '⚠️ Fehler beim Laden des Schwellenwerts für Wunsch-Abgleich: $e',
      );
    }
    return threshold;
  }

  /// [includeQueuedPreWish] false = nur Offen-Tab; true = nur reine Vorab-Queue.
  /// Verschiebt **alle** Treffer inkl. `is_duplicate` in einem Batch.
  /// Rückgabe: Anzahl aktualisierter Docs (0 = kein Treffer).
  Future<int> _tryMatchRecognizedSongInDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String normalizedTitle,
    required String normalizedArtist,
    required List<String> ignored,
    required double threshold,
    required bool includeQueuedPreWish,
  }) async {
    final matches =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final wishDoc in docs) {
      final wishData = wishDoc.data();

      final isQueued = PreWishHelper.isQueuedPreWish(wishData);
      if (includeQueuedPreWish) {
        if (!isQueued) continue;
      } else if (isQueued) {
        continue;
      }

      final wishTitle = _wishTitleFromData(wishData);
      final wishArtist = _wishArtistFromData(wishData);
      if (wishTitle.isEmpty || wishArtist.isEmpty) continue;

      final canonWishTitle = normalizeTextForDuplicateCheck(wishTitle, ignored);
      final canonWishArtist =
          normalizeTextForDuplicateCheck(wishArtist, ignored);

      final titleSimilarity = StringSimilarity.compareTwoStrings(
        normalizedTitle,
        canonWishTitle,
      );
      final artistSimilarity = StringSimilarity.compareTwoStrings(
        normalizedArtist,
        canonWishArtist,
      );
      final avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

      if (avgSimilarity < threshold) continue;
      matches.add(wishDoc);
    }

    if (matches.isEmpty) return 0;

    debugLog(
      '✅ Wunsch-Match (${includeQueuedPreWish ? 'Vorab' : 'Offen'}): '
      '${matches.length} Eintrag/Einträge → played',
    );

    final batch = FirebaseFirestore.instance.batch();
    for (final wishDoc in matches) {
      batch.update(wishDoc.reference, {
        'status': 'played',
        'auto_recognized': true,
        'recognized_at': FieldValue.serverTimestamp(),
        'played_at': FieldValue.serverTimestamp(),
        'playedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    if (!_wishMatchController.isClosed) {
      final first = matches.first.data();
      _wishMatchController.add({
        'title': _wishTitleFromData(first),
        'artist': _wishArtistFromData(first),
      });
    }
    return matches.length;
  }

  /// Gibt gecachtes JWT zurück, solange es laut Serverablauf (oder Fallback 25 min) noch gültig ist.
  String? _getCachedAppleToken() {
    if (_currentToken == null || _currentTokenFetchedAt == null) {
      return null;
    }

    final nowUtc = DateTime.now().toUtc();

    if (_currentTokenExpiresAtUtc != null) {
      final renewAfter = _currentTokenExpiresAtUtc!.subtract(
        _tokenRefreshSafetyMargin,
      );
      if (!nowUtc.isBefore(renewAfter)) {
        debugLog(
          '🔑 Apple-JWT-Cache: abgelaufen oder ${_tokenRefreshSafetyMargin.inMinutes} min vor exp — Refresh',
        );
        _clearAppleTokenCache();
        return null;
      }
      return _currentToken;
    }

    final cacheAge = DateTime.now().difference(_currentTokenFetchedAt!);
    if (cacheAge >= _tokenRefreshWindow) {
      _clearAppleTokenCache();
      return null;
    }

    return _currentToken;
  }

  void _showGlobalSnack(String message, {Color backgroundColor = Colors.deepOrange}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showRootVibesSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 10),
        ),
        tag: 'ShazamService',
      );
    });
  }

  /// Orangefarbene SnackBar über den root-[ScaffoldMessenger] (sichtbar auf jedem Tab).
  void _showGlobalAppCheckSnack() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = LocaleHelper.mapToSupportedOrEnglish(
        LocaleHelper.localeNotifier.value.languageCode,
      );
      final t = LocaleHelper.getTranslations(Locale(lang));
      final message = LocaleHelper.tr(t, 'shazam_app_check_invalid_snackbar');
      showRootVibesSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade900,
          duration: const Duration(seconds: 8),
        ),
        tag: 'ShazamAppCheck',
      );
    });
  }

  /// Behandelt NoMatch oder Fehler - setzt neutrale Werte
  void _handleNoMatchOrError() {
    final neutralData = {'title': '-', 'artist': '-'};
    _lastResult = neutralData;
    _updateStatus(ShazamScanStatus.idle);
    _resultController.add(neutralData);
  }

  void _updateStatus(ShazamScanStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
    }
  }

  /// Bereinigt Ressourcen
  void dispose() {
    stopAutoScanning();
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    // autoAdjustStream: bewusst ohne cancel(), Verbindung soll dauerhaft bestehen.
    if (!_autoAdjustUiController.isClosed) _autoAdjustUiController.close();
    _statusController.close();
    _resultController.close();
    _wishMatchController.close();
    _notificationNavigationController.close();
  }
}
