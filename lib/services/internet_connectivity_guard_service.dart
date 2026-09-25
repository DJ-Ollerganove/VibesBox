import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_navigator_keys.dart';
import '../l10n/app_localizations.dart';
import '../l10n/text_direction_helper.dart';
import '../utils/debug_log.dart';
import '../utils/ui_constants.dart';
import 'party_autostart_service.dart';
import 'shazam_service.dart';

/// Überwacht echte Internet-Erreichbarkeit (WLAN **oder** Mobilfunk mit Daten)
/// und zeigt bei Offline ein blockierendes Popup; pausiert dabei Musikerkennung.
class InternetConnectivityGuardService with WidgetsBindingObserver {
  InternetConnectivityGuardService._();

  static final InternetConnectivityGuardService instance =
      InternetConnectivityGuardService._();

  /// Primär ein schneller Captive-Check; Fallbacks nur wenn nötig.
  static const _probePrimary = 'https://www.gstatic.com/generate_204';
  static const _probeFallbacks = <String>[
    'https://connectivitycheck.gstatic.com/generate_204',
    'https://firebase.googleapis.com/',
  ];

  static const _pollWhenOnline = Duration(seconds: 20);
  static const _pollWhenOffline = Duration(seconds: 5);

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  bool _started = false;
  bool _dialogVisible = false;
  bool _checking = false;
  bool _wasRecognitionEnabled = false;
  bool _handlingTransition = false;
  Duration _currentPollInterval = _pollWhenOffline;
  int _stableOnlineHits = 0;
  int _offlineHits = 0;
  DateTime? _lastResumedAt;
  BuildContext? _dialogContext;

  /// Einmal nach App-Start (nach erstem Frame mit Navigator).
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _lastResumedAt = DateTime.now();

    unawaited(_evaluateAndApply());

    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      _stableOnlineHits = 0;
      _setPollInterval(_pollWhenOffline);
      unawaited(_evaluateAndApply());
    });

    _setPollInterval(_pollWhenOffline);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastResumedAt = DateTime.now();
      return;
    }
    // Display aus / App im Hintergrund: kein Offline-Dialog, kein pop() auf den Navigator.
  }

  bool get _inResumeGrace {
    final t = _lastResumedAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(seconds: 4);
  }

  void _setPollInterval(Duration interval) {
    if (_pollTimer != null && _currentPollInterval == interval) return;
    _currentPollInterval = interval;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_evaluateAndApply());
    });
  }

  Future<void> _evaluateAndApply({bool force = false}) async {
    if (_checking) return;
    final life = WidgetsBinding.instance.lifecycleState;
    if (!force &&
        (life == AppLifecycleState.paused ||
            life == AppLifecycleState.hidden ||
            life == AppLifecycleState.inactive)) {
      return;
    }
    _checking = true;
    try {
      final online = await hasUsableInternet();
      if (online) {
        _offlineHits = 0;
        _stableOnlineHits++;
        if (_stableOnlineHits >= 2) {
          _setPollInterval(_pollWhenOnline);
        }
      } else {
        _stableOnlineHits = 0;
        _offlineHits++;
        _setPollInterval(_pollWhenOffline);
        // Beim Aufwachen ist das Funkmodul oft 1–2 s tot. Nicht sofort Offline.
        if (!force && isOnline.value && (_inResumeGrace || _offlineHits < 2)) {
          debugLog(
            'InternetGuard: Offline-Probe ignoriert '
            '(grace=$_inResumeGrace hits=$_offlineHits)',
          );
          return;
        }
      }
      if (!force && online == isOnline.value) return;
      isOnline.value = online;
      if (online) {
        await _onOnline();
      } else {
        await _onOffline();
      }
    } finally {
      _checking = false;
    }
  }

  /// Link-Layer (WLAN/Mobilfunk/Ethernet) **und** echte Erreichbarkeit.
  Future<bool> hasUsableInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasLink = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn ||
            r == ConnectivityResult.other,
      );
      if (!hasLink) return false;
    } catch (e) {
      debugLog('InternetGuard: connectivity check failed: $e');
      // Fallback: trotzdem Reachability prüfen.
    }
    return _probeReachability();
  }

  Future<bool> _probeReachability() async {
    if (await _probeOne(_probePrimary)) return true;
    // Stabil online: kein teurer Multi-Fallback bei einem Fehlschlag.
    if (isOnline.value && _stableOnlineHits >= 2) return false;
    for (final url in _probeFallbacks) {
      if (await _probeOne(url)) return true;
    }
    return false;
  }

  Future<bool> _probeOne(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      // 204 = generate_204 OK; 2xx/3xx/401/403 = Host erreichbar.
      return res.statusCode > 0 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onOffline() async {
    if (_handlingTransition) return;
    _handlingTransition = true;
    try {
      await _pauseBackgroundWork();
      await _showOfflineDialogIfNeeded();
    } finally {
      _handlingTransition = false;
    }
  }

  Future<void> _onOnline() async {
    if (_handlingTransition) return;
    _handlingTransition = true;
    try {
      await _dismissOfflineDialogIfNeeded();
      await _resumeBackgroundWork();
    } finally {
      _handlingTransition = false;
    }
  }

  Future<void> _pauseBackgroundWork() async {
    try {
      final shazam = ShazamService();
      if (shazam.isEnabled) {
        _wasRecognitionEnabled = true;
        debugLog('InternetGuard: Musikerkennung pausieren (offline)');
        await PartyAutostartService().stopRecognitionNow();
      }
    } catch (e) {
      debugLog('InternetGuard: Pause fehlgeschlagen: $e');
    }
  }

  Future<void> _resumeBackgroundWork() async {
    if (!_wasRecognitionEnabled) return;
    _wasRecognitionEnabled = false;
    try {
      debugLog('InternetGuard: Musikerkennung fortsetzen (online)');
      await PartyAutostartService().setManualRecognitionEnabled(true);
    } catch (e) {
      debugLog('InternetGuard: Resume fehlgeschlagen: $e');
    }
  }

  Future<void> _showOfflineDialogIfNeeded() async {
    if (_dialogVisible) return;
    final ctx = appRootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    _dialogVisible = true;
    _dialogContext = null;
    debugLog('InternetGuard: Offline-Dialog anzeigen');

    // ignore: unawaited_futures — Dialog bleibt bis Online/Dismiss.
    showDialog<void>(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) {
        _dialogContext = dialogCtx;
        final l10n = AppLocalizations.of(dialogCtx)!;
        final isRtl = VbTextDirection.isRtl(dialogCtx);
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: UIConstants.appOrange, width: 1.8),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Directionality(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: UIConstants.appOrange,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.offline_dialog_title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.offline_dialog_body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final ok = await hasUsableInternet();
                        if (!ok) return;
                        isOnline.value = true;
                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                        }
                        await _resumeBackgroundWork();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: UIConstants.appOrange,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(l10n.offline_dialog_retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _dialogVisible = false;
      _dialogContext = null;
    });
  }

  Future<void> _dismissOfflineDialogIfNeeded() async {
    if (!_dialogVisible) return;
    final ctx = _dialogContext;
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx, rootNavigator: true).pop();
      return;
    }
    // Dialog noch nicht im Stack: kein nav.pop() — das würde die aktuelle Seite schließen.
    _dialogVisible = false;
    _dialogContext = null;
  }
}
