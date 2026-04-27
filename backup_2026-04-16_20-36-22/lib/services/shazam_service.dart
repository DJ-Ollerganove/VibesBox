import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'active_party_service.dart';
import 'duplicate_check_service.dart';
import 'pro_feature_guard.dart';
import '../utils/text_utils.dart';
import '../utils/debug_log.dart';

/// Status für Shazam-Scanning
enum ShazamScanStatus {
  idle, // Inaktiv
  scanning, // Scan läuft gerade
  success, // Song erfolgreich erkannt
  error, // Fehler aufgetreten
}

/// Service für Shazam-Song-Erkennung mit automatischem Intervall-Scanning
class ShazamService {
  static final ShazamService _instance = ShazamService._internal();
  factory ShazamService() => _instance;

  /// Free-Tarif: fester Abstand zwischen Scans (Sekunden).
  static const int freeScanIntervalSeconds = 180;

  String _prefsKeyFreeLastScan(String uid) =>
      'shazam_free_last_scan_completed_ms_$uid';
  bool _autoAdjustStreamInitialized =
      false; // Flag um sicherzustellen, dass Stream nur einmal initialisiert wird

  ShazamService._internal() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
    // Initialisiere autoAdjustStream sofort beim ersten App-Start (ohne await, läuft im Hintergrund)
    // Die Subscription bleibt dauerhaft bestehen für diesen Test
    _initAutoAdjustStream()
        .then((_) {
          _autoAdjustStreamInitialized = true;
        })
        .catchError((error) {
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
  String?
  _lastNotificationText; // Zuletzt in der Statusleiste angezeigter Inhalt
  int _scanIntervalSeconds = 60; // Standard: 60 Sekunden
  int _currentInterval =
      60; // Aktuell verwendetes Intervall (für sofortige Updates)
  double _micSensitivity = 1.0; // Standard: 1.0 (0.5 bis 2.0)
  double _recognitionThreshold =
      0.3; // Standard: 0.3 (0.0 bis 1.0) - Schwellenwert für Scan-Start
  bool _smartThresholdEnabled = false; // Standard: false (manuell)
  /// Free-DJ: planType aus users-Dokument; bei 'free' festes Intervall [freeScanIntervalSeconds].
  String _userPlanType = 'free';
  StreamSubscription<DocumentSnapshot>?
  _settingsSubscription; // Listener für Intervall-Änderungen
  bool _isRestartingTimer = false; // Lock um Race Conditions zu vermeiden
  bool _isUpdating =
      false; // Lock um zu verhindern, dass während des Resets zwei Scans gleichzeitig starten

  // Kurzlebiger Apple-Token aus Cloud Function (30 Min gültig).
  // Nach 25 Minuten wird automatisch ein frischer Token geholt.
  String? _currentToken;
  DateTime? _currentTokenFetchedAt;
  static const Duration _tokenRefreshWindow = Duration(minutes: 25);

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

  // Getter
  ShazamScanStatus get status => _status;
  Map<String, dynamic>? get lastResult => _lastResult;
  bool get isEnabled => _isEnabled;
  int get scanIntervalSeconds => _scanIntervalSeconds;

  /// Free-DJ: fest 3 Minuten; sonst gespeichertes Intervall (Pro/Trial/Admin).
  int get effectiveScanIntervalSeconds =>
      _userPlanType == 'free' ? freeScanIntervalSeconds : _scanIntervalSeconds;
  double get micSensitivity => _micSensitivity;
  double get recognitionThreshold => _recognitionThreshold;
  bool get showStatusNotificationEnabled => _showStatusNotification;

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

  String? _currentRecognizedSongLabel() {
    final title = (_lastResult?['title'] as String?)?.trim() ?? '';
    final artist = (_lastResult?['artist'] as String?)?.trim() ?? '';
    if (title.isEmpty || artist.isEmpty) return null;
    if (title == '-' || artist == '-') return null;
    return '$title - $artist';
  }

  String getLocalizedCurrentStatus() {
    if (_status == ShazamScanStatus.scanning) {
      return _getNotificationRunning();
    }
    final songLabel = _currentRecognizedSongLabel();
    if (songLabel != null) {
      return _getNotificationSuccessFormat().replaceFirst('%s', songLabel);
    }
    return _lastNotificationText ?? _getNotificationRunning();
  }

  Future<void> _updateNotificationContent(
    String contentText, {
    String? navigationTarget,
  }) async {
    if (!_showStatusNotification) return;
    _lastNotificationText = contentText;
    try {
      await _channel.invokeMethod<void>(_methodUpdateRecognitionNotification, {
        'notificationTitle': _getNotificationTitle(),
        'contentText': contentText,
        'navigationTarget': navigationTarget,
      });
    } catch (e) {
      debugLog('⚠️ Notification-Update fehlgeschlagen: $e');
    }
  }

  /// Direkter Echtzeit-Push für Locale-Wechsel (entkoppelt vom recognize()-Zyklus).
  Future<void> pushLocalizedNotificationContentNow() async {
    if (!_isEnabled || !_showStatusNotification) return;
    final contentText = getLocalizedCurrentStatus();
    _lastNotificationText = contentText;
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
  StreamSubscription<Map<String, double>>?
  _autoAdjustStreamSubscription; // Einziger Listener auf EventChannel
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
      _autoAdjustStreamSubscription = _autoAdjustStream!.listen(
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
    _performScan();
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
      _currentInterval = effectiveScanIntervalSeconds;
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
          _currentInterval = freeScanIntervalSeconds;
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

    if (_isEnabled) {
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

  Future<void> _startForegroundServiceIfNeeded() async {
    if (_foregroundServiceRunning) return;
    try {
      await _channel.invokeMethod<void>(_methodStartScanning, {
        'showStatusNotification': _showStatusNotification,
        'notificationTitle': _getNotificationTitle(),
        'notificationListening': _getNotificationRunning(),
      });
      _foregroundServiceRunning = true;
      debugLog('✅ Foreground Service gestartet (Statuszeile aktiv)');
    } catch (e) {
      debugLog('❌ Fehler beim Starten des Foreground Service: $e');
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
    debugLog('✅ Foreground Service gestoppt (Statuszeile aus)');
  }

  Future<void> _updateNotificationVisibility(
    bool visible, {
    String? contentText,
  }) async {
    final effectiveText = contentText ?? getLocalizedCurrentStatus();
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

  /// Speichert die Scan-Intervall-Einstellung im User-Profil
  Future<void> saveScanInterval(int seconds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _scanIntervalSeconds = seconds;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'shazam_scan_interval_seconds': seconds},
      );
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
    _currentInterval = seconds;

    // Auto-Resume: Timer sofort zurücksetzen und neu starten (falls aktiv)
    if (wasEnabled) {
      debugLog(
        '🔄 Auto-Resume: Timer wird mit neuem Intervall ($seconds Sek.) neu gestartet...',
      );

      // Stoppe aktuellen Scan (nur der laufende Scan, nicht der Service)
      try {
        await _channel.invokeMethod<void>('stopCurrentScan');
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
      _performScan();

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
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'mic_sensitivity': sensitivity})
        .catchError((e) {
          debugLog('⚠️ Fehler beim Speichern der Sensitivity in Firestore: $e');
          // Weiter machen, auch wenn Firestore-Speicherung fehlschlägt
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
      await _channel.invokeMethod<void>('stopCurrentScan');

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

  /// Lädt den Apple-Token ausschließlich über die Cloud Function
  /// `getAppleMusicToken` und nutzt einen 25-Minuten-Cache.
  Future<String> _getToken() async {
    final cachedToken = _getCachedAppleToken();
    if (cachedToken != null) {
      return cachedToken;
    }

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

    _currentToken = token;
    _currentTokenFetchedAt = DateTime.now();
    return token;
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'mic_sensitivity': sensitivity},
      );

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
      await _channel.invokeMethod<void>('stopCurrentScan');
      debugLog('✅ Aktueller Scan gestoppt');
    } catch (e) {
      debugLog('⚠️ Fehler beim Stoppen des aktuellen Scans: $e');
      // Weiter machen, auch wenn Stop fehlschlägt
    }

    // Warte kurz, damit Native-Seite sauber aufräumen kann
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Startet das automatische Scanning mit dem konfigurierten Intervall
  Future<void> startAutoScanning() async {
    if (_isEnabled) {
      debugLog('⚠️ startAutoScanning: Service ist bereits aktiv');
      return; // Bereits aktiv
    }
    final owner = FirebaseAuth.instance.currentUser;
    if (owner == null) {
      debugLog(
        '⚠️ startAutoScanning: Kein eingeloggter User – Foreground Service wird nicht gestartet',
      );
      return;
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
      return;
    }

    debugLog('🚀 Starte Shazam Auto-Scanning...');

    // Einstellungen früh laden, bevor über Notification-Sichtbarkeit entschieden wird.
    await loadScanInterval();

    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      _serviceOwnerUid = null;
      debugLog(
        '⚠️ ShazamService: Mikrofon nicht gewährt – startAutoScanning abgebrochen '
        '(kein Aufruf von startForegroundService / kein Crash)',
      );
      return;
    }
    // Nach dem frühen UI-Trigger hier nur noch final synchronisieren.
    if (!_showStatusNotification) {
      await _updateNotificationVisibility(false);
    }
    // Während des Betriebs: jeder Timer-Tick ruft [_performScan] auf.

    // WICHTIG: Initialisiere autoAdjustStream FRÜH, damit die Verbindung steht bevor Android sendet
    _initAutoAdjustStream();

    _currentInterval = effectiveScanIntervalSeconds;
    debugLog(
      '📋 Geladenes Scan-Intervall: ${effectiveScanIntervalSeconds}s (Free: ${_userPlanType == 'free'})',
    );
    debugLog('🎤 Geladene Mikrofon-Empfindlichkeit: $_micSensitivity');
    _isEnabled = true;
    recognitionActiveNotifier.value = true;

    // Aktiviere Wakelock (verhindert, dass Bildschirm ausgeht und App schläft)
    try {
      await WakelockPlus.enable();
      debugLog('🔋 Wakelock aktiviert - App bleibt aktiv');
    } catch (e) {
      debugLog('⚠️ Fehler beim Aktivieren des Wakelocks: $e');
    }

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
    _performScan();

    // Starte Timer für periodische Scans
    _startTimer();
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
    _nextScanAllowedAt = null;
    _isEnabled = false;
    _serviceOwnerUid = null;
    recognitionActiveNotifier.value = false;

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
    _isRestartingTimer = false;
    debugLog('⏹️ Timer gestoppt');

    // Harte Stop-Sequenz: erst Notification sicher ausblenden (mit Retry), dann Service stoppen.
    await _updateNotificationVisibility(
      false,
      contentText: _getNotificationRunning(),
    );

    // Stoppe Android Foreground Service
    await _stopForegroundServiceIfRunning();

    if (_status != ShazamScanStatus.idle) {
      _status = ShazamScanStatus.idle;
      _statusController.add(_status);
    }

    debugLog('✅ Shazam Auto-Scanning gestoppt');
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
        _resultController.add({
          'title': '',
          'artist': '',
          'error': 'TOKEN_ERROR',
          'error_message': 'Lizenz-Fehler: Token konnte nicht geladen werden.',
        });
        _updateStatus(ShazamScanStatus.error);
        _handleNoMatchOrError();
        return;
      }

      // Debug: Zeige Token-Länge (aber nicht den Inhalt aus Sicherheitsgründen)
      final previewLength = token.length > 10 ? 10 : token.length;
      debugLog(
        '🔑 Token geladen: Länge=${token.length}, Start=${token.substring(0, previewLength)}...',
      );

      // WICHTIG: Stelle sicher, dass die Daten-Brücke steht, bevor der Scan startet
      await _initAutoAdjustStream();

      // Führe Shazam-Scan durch (Free-DJ: intelligente Steuerung immer false)
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('recognize', {
            'token': token,
            'mic_sensitivity': _micSensitivity,
            'recognition_threshold': _recognitionThreshold,
            'smart_threshold_enabled': effectiveSmartThresholdEnabled,
          });

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
            debugLog('❌ Shazam Token-Fehler: $errorMessage');
            debugLog('💡 Bitte prüfe die Cloud Function getAppleMusicToken.');
            _updateStatus(ShazamScanStatus.error);
            _handleNoMatchOrError();
            return;
          }

          // Sichere Null-Werte-Behandlung
          final title = result['title'] as String? ?? '';
          final artist = result['artist'] as String? ?? '';

          // Prüfe ob wirklich ein Match gefunden wurde (nicht leer)
          if (title.isNotEmpty && artist.isNotEmpty) {
            final songData = {'title': title, 'artist': artist};

            _lastResult = songData;
            _updateStatus(ShazamScanStatus.success);
            final successText = _getNotificationSuccessFormat().replaceFirst(
              '%s',
              '$title - $artist',
            );
            if (_showStatusNotification) {
              await _updateNotificationContent(
                successText,
                navigationTarget: _navigationTargetHistory,
              );
            }
            _resultController.add(songData);

            // Song wird über resultStream an HistoryProvider weitergegeben
            // (Speicherung + Last-Track-Dedup: music_history/.../tracks, siehe HistoryLastTrackDedup)
            // Prüfe und aktualisiere Wünsche automatisch (nur wenn aktive Party existiert)
            final hasActiveParty = await _hasActiveParty();
            if (hasActiveParty) {
              await _checkAndUpdateWishes(title, artist);
            } else {
              debugLog(
                '🧪 Testmodus: Song erkannt, aber keine aktive Party: $title - $artist',
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
      }
    } catch (e) {
      debugLog('Fehler beim Shazam-Scan: $e');
      _updateStatus(ShazamScanStatus.error);
      _handleNoMatchOrError();
    }
  }

  /// Prüft ob eine aktive Party existiert (nur zentrale Session)
  Future<bool> _hasActiveParty() async {
    try {
      final partyId = ActivePartyService.currentPartyId;
      return partyId != null && partyId.isNotEmpty;
    } catch (e) {
      debugLog('⚠️ Fehler beim Prüfen der aktiven Party: $e');
      return false;
    }
  }

  /// Prüft erkannte Songs gegen Wunschliste und aktualisiert Status automatisch
  /// Nutzt duplicate_threshold für Ähnlichkeitsprüfung
  Future<void> _checkAndUpdateWishes(String title, String artist) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Aktive Party-ID nur aus zentraler Session
      final partyId = ActivePartyService.currentPartyId;
      if (partyId == null || partyId.isEmpty) {
        return; // Keine aktive Party
      }

      // Lade duplicate_threshold aus Admin-Einstellungen
      double threshold = 0.85; // Fallback
      try {
        final settingsDoc = await FirebaseFirestore.instance
            .collection('party_settings')
            .doc('current')
            .get();

        if (settingsDoc.exists) {
          final settingsData = settingsDoc.data() as Map<String, dynamic>?;
          final thresholdValue = settingsData?['duplicate_threshold'];
          if (thresholdValue != null) {
            if (thresholdValue is double) {
              threshold = thresholdValue;
            } else if (thresholdValue is num) {
              threshold = thresholdValue.toDouble();
            }
            debugLog(
              '🔍 Wunsch-Abgleich mit Threshold: ${(threshold * 100).toStringAsFixed(1)}%',
            );
          }
        }
      } catch (e) {
        debugLog(
          '⚠️ Fehler beim Laden des Schwellenwerts für Wunsch-Abgleich: $e',
        );
      }

      // Lade pending Wünsche für die aktive Party
      final wishesSnapshot = await FirebaseFirestore.instance
          .collection('wishes')
          .where('party_id', isEqualTo: partyId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (wishesSnapshot.docs.isEmpty) {
        return; // Keine pending Wünsche
      }

      // Gleiche Normalisierung wie Gruppierung/Duplikat-Check (NFC, Whitespace, Klammern, Mix-Begriffe)
      final ignored = DuplicateCheckService.getCachedIgnoredKeywords();
      final normalizedTitle = normalizeTextForDuplicateCheck(title, ignored);
      final normalizedArtist = normalizeTextForDuplicateCheck(artist, ignored);

      // Prüfe jeden pending Wunsch
      for (final wishDoc in wishesSnapshot.docs) {
        final wishData = wishDoc.data() as Map<String, dynamic>;
        final wishTitle = (wishData['title'] as String? ?? '').trim();
        final wishArtist = (wishData['artist'] as String? ?? '').trim();

        if (wishTitle.isEmpty || wishArtist.isEmpty) continue;

        final canonWishTitle = normalizeTextForDuplicateCheck(wishTitle, ignored);
        final canonWishArtist = normalizeTextForDuplicateCheck(wishArtist, ignored);

        // Berechne Ähnlichkeit mit string_similarity (beide Seiten gleich normalisiert)
        final titleSimilarity = StringSimilarity.compareTwoStrings(
          normalizedTitle,
          canonWishTitle,
        );
        final artistSimilarity = StringSimilarity.compareTwoStrings(
          normalizedArtist,
          canonWishArtist,
        );

        // Durchschnittliche Ähnlichkeit
        final avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

        // Wenn Ähnlichkeit >= Threshold: Match gefunden
        if (avgSimilarity >= threshold) {
          debugLog(
            '✅ Wunsch-Match gefunden: "$wishTitle - $wishArtist" (Ähnlichkeit: ${(avgSimilarity * 100).toStringAsFixed(1)}%, Threshold: ${(threshold * 100).toStringAsFixed(1)}%)',
          );

          // Aktualisiere Status von pending zu played
          await wishDoc.reference.update({
            'status': 'played',
            'auto_recognized': true, // Kennzeichnung für automatische Erkennung
            'recognized_at':
                FieldValue.serverTimestamp(), // Zeitstempel der Erkennung
            'played_at': FieldValue.serverTimestamp(),
            'playedAt': FieldValue.serverTimestamp(),
          });

          // Sende Benachrichtigung an Stream (für Snackbar im Footer)
          if (!_wishMatchController.isClosed) {
            _wishMatchController.add({
              'title': wishTitle,
              'artist': wishArtist,
            });
          }

          // Nur ersten Match verarbeiten (um mehrere Updates zu vermeiden)
          break;
        }
      }
    } catch (e) {
      debugLog('❌ Fehler beim Abgleich mit Wunschliste: $e');
      // Fehler nicht weiterwerfen, damit Scan weiterläuft
    }
  }

  /// Holt den Apple Developer Token aus dem Cache (maximal 25 Minuten alt).
  /// Gibt null zurück, wenn Cache leer oder zu alt ist.
  String? _getCachedAppleToken() {
    if (_currentToken == null || _currentTokenFetchedAt == null) {
      return null; // Kein Token im Cache
    }

    final cacheAge = DateTime.now().difference(_currentTokenFetchedAt!);
    if (cacheAge >= _tokenRefreshWindow) {
      // Cache abgelaufen - zurücksetzen
      _currentToken = null;
      _currentTokenFetchedAt = null;
      return null;
    }

    // Token ist im Cache und noch gültig
    return _currentToken;
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
    // TEST: Entferne cancel() für autoAdjustStream, damit die Verbindung niemals unterbrochen wird
    // _autoAdjustStreamSubscription?.cancel();
    // _autoAdjustStreamSubscription = null;
    // _autoAdjustStream = null;
    if (!_autoAdjustUiController.isClosed) _autoAdjustUiController.close();
    _statusController.close();
    _resultController.close();
    _wishMatchController.close();
    _notificationNavigationController.close();
  }
}
