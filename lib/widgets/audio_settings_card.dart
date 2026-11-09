import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_self_settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/shazam_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../utils/ui_constants.dart';
import '../l10n/app_localizations.dart';
import '../utils/debug_log.dart';
import '../services/dj_pro_session_service.dart';
import 'settings_choice_row.dart';
import '../app_scaffold_messenger.dart';

/// Widget für Audio-Einstellungen (Mikrofon-Empfindlichkeit, Schwellenwert, etc.)
/// Wiederverwendbare Karte für Dashboard-Integration
/// Vollständige Funktionalität aus ShazamSettingsSection übernommen
class AudioSettingsCard extends StatefulWidget {
  const AudioSettingsCard({
    super.key,
    required this.canUsePremium,
    required this.cardBuilder,
    this.embedded = false,
  });

  final bool canUsePremium;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  /// Ohne eigene Überschrift, wenn die Karte unter der Quellen-Auswahl steht.
  final bool embedded;

  @override
  State<AudioSettingsCard> createState() => _AudioSettingsCardState();
}

/// Feste Werte für Free-DJs (Musikererkennung; Intervall = [ShazamService.freeScanIntervalSeconds])
const int _kFreeScanIntervalSeconds = ShazamService.freeScanIntervalSeconds;
const double _kFreeMicSensitivity = 0.7;
const double _kFreeRecognitionThreshold = 0.3; // 30%
const bool _kFreeSmartThresholdEnabled = false;
const bool _kFreeAutoStartRecognition = false;

class _AudioSettingsCardState extends State<AudioSettingsCard> {
  final ShazamService _shazamService = ShazamService();
  int _scanIntervalSeconds = 60; // Standard: 60 Sekunden
  double _micSensitivity = 1.0; // Standard: 1.0 (0.5 bis 2.0)
  double _recognitionThreshold = 0.3; // Standard: 0.3 (0.0 bis 1.0)
  bool _smartThresholdEnabled = false; // Standard: false (manuell)
  bool _autoStartRecognition = false; // Standard: false (manuell)
  bool _isLoading = true;
  /// Aus dem zuletzt geladenen users/{uid}-Dokument ([UserModel.isFree]); nie `currentUser==null` als Free raten.
  bool? _profileIsFree;
  int? _scanIntervalDrag;

  VoidCallback? _subscriptionTierListener;

  // AUTOMATIC GAIN & THRESHOLD MAPPING: Stream-Subscription für automatische Werte-Updates
  StreamSubscription<Map<String, dynamic>>? _autoAdjustSubscription;
  bool _isAutoUpdating = false; // Flag um Endlosschleifen zu vermeiden
  Timer? _autoAdjustUiDebounce;
  static const Duration _autoAdjustDebounceDuration = Duration(milliseconds: 120);
  static const double _autoAdjustUiEpsilon = 0.005;

  String _prefsKey(String uid, String key) => 'audio_settings_${uid}_$key';

  Future<void> _saveLocalTogglePrefs({
    required String uid,
    bool? smartThresholdEnabled,
    bool? autoStartRecognition,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (smartThresholdEnabled != null) {
      await prefs.setBool(_prefsKey(uid, 'smart_threshold_enabled'), smartThresholdEnabled);
    }
    if (autoStartRecognition != null) {
      await prefs.setBool(_prefsKey(uid, 'auto_start_recognition'), autoStartRecognition);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // AUTOMATIC GAIN & THRESHOLD MAPPING: Höre auf automatische Werte-Updates
    debugLog('🎧 AudioSettingsCard: Abonniere autoAdjustStream...');
    _autoAdjustSubscription = _shazamService.autoAdjustStream.listen(
      (values) {
        if (UserService().currentUser.value?.isFree ?? true) return; // Free-DJ: keine automatischen Updates
        if (!mounted || _isAutoUpdating) return;
        final nextSensitivity = (values['mic_sensitivity'] ?? _micSensitivity)
            .clamp(0.5, 2.0);
        final nextThreshold = (values['recognition_threshold'] ?? _recognitionThreshold)
            .clamp(0.0, 1.0);
        final hasMeaningfulChange =
            (nextSensitivity - _micSensitivity).abs() >= _autoAdjustUiEpsilon ||
            (nextThreshold - _recognitionThreshold).abs() >= _autoAdjustUiEpsilon;
        if (!hasMeaningfulChange) return;

        _autoAdjustUiDebounce?.cancel();
        _autoAdjustUiDebounce = Timer(_autoAdjustDebounceDuration, () {
          if (!mounted) return;
          _isAutoUpdating = true;
          setState(() {
            _micSensitivity = nextSensitivity;
            _recognitionThreshold = nextThreshold;
          });
          _isAutoUpdating = false;
        });
      },
      onError: (error) {
        debugLog("❌ autoAdjustStream Fehler in AudioSettingsCard: $error");
      },
      cancelOnError: false,
    );
    // Beim Öffnen der Karte mit aktuellem Service-Wert synchronisieren (falls Automatik schon lief)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _micSensitivity = _shazamService.micSensitivity;
          _recognitionThreshold = _shazamService.recognitionThreshold;
        });
      }
    });
    debugLog('✅ AudioSettingsCard: autoAdjustStream abonniert');
    _subscriptionTierListener = _onSubscriptionTierChanged;
    UserService().currentUser.addListener(_subscriptionTierListener!);
    UserService().sessionProStatus.addListener(_subscriptionTierListener!);
  }

  void _onSubscriptionTierChanged() {
    if (!mounted) return;
    final wasFree = _profileIsFree == true;
    final next = DjProSessionService.instance.isFreeDj;
    setState(() => _profileIsFree = next);
    if (wasFree && !next) {
      unawaited(_shazamService.loadScanInterval());
    }
  }

  @override
  void dispose() {
    if (_subscriptionTierListener != null) {
      UserService().currentUser.removeListener(_subscriptionTierListener!);
      UserService().sessionProStatus.removeListener(_subscriptionTierListener!);
    }
    _autoAdjustSubscription?.cancel();
    _autoAdjustUiDebounce?.cancel();
    if (_profileIsFree == true) {
      unawaited(_persistFreeScanIntervalOnly());
    }
    super.dispose();
  }

  Future<void> _writeUserSetting(Map<String, dynamic> fields) async {
    await UserSelfSettingsService.instance.write(fields);
  }

  /// Lädt die Audio-Einstellungen aus Firestore
  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1) Lokale Persistenz zuerst laden (schneller, offline-sicher)
      final prefs = await SharedPreferences.getInstance();
      final localSmart = prefs.getBool(_prefsKey(user.uid, 'smart_threshold_enabled'));
      final localAutoStart = prefs.getBool(_prefsKey(user.uid, 'auto_start_recognition'));
      final localStatusNotification = prefs.getBool(_prefsKey(user.uid, 'show_status_notification'));
      final hasLocalSmart = localSmart != null;
      final hasLocalAutoStart = localAutoStart != null;
      if (localSmart != null) _smartThresholdEnabled = localSmart;
      if (localAutoStart != null) _autoStartRecognition = localAutoStart;
      var statusNotifForService = localStatusNotification ?? false;

      // 2) Firestore als Source of Truth laden und lokalen Cache aktualisieren
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        _profileIsFree = DjProSessionService.instance.isFreeDj;

        // Lade Scan-Intervall (Firestore liefert oft int; Cloud Console / Legacy auch num/double)
        final rawInterval = data?['shazam_scan_interval_seconds'];
        int? interval;
        if (rawInterval is int) {
          interval = rawInterval;
        } else if (rawInterval is num) {
          interval = rawInterval.round();
        }
        if (interval != null && interval >= 30 && interval <= 300) {
          _scanIntervalSeconds = interval;
        }
        
        // Lade Mikrofon-Empfindlichkeit
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
        
        // Lade Smart-Threshold Einstellung
        final smartThreshold = data?['smart_threshold_enabled'] as bool?;
        if (smartThreshold != null) {
          if (!hasLocalSmart) {
            _smartThresholdEnabled = smartThreshold;
            await _saveLocalTogglePrefs(
              uid: user.uid,
              smartThresholdEnabled: smartThreshold,
            );
          } else if (smartThreshold != localSmart) {
            // Lokale Nutzereinstellung nicht überschreiben; stattdessen Firestore nachziehen.
            await _writeUserSetting({
              'smart_threshold_enabled': localSmart!,
            });
          }
        }
        
        // Lade Autostart-Einstellung
        final autoStart = data?['auto_start_recognition'] as bool?;
        if (autoStart != null) {
          if (!hasLocalAutoStart) {
            _autoStartRecognition = autoStart;
            await _saveLocalTogglePrefs(
              uid: user.uid,
              autoStartRecognition: autoStart,
            );
          } else if (autoStart != localAutoStart) {
            // Lokale Nutzereinstellung nicht überschreiben; stattdessen Firestore nachziehen.
            await _writeUserSetting({
              'auto_start_recognition': localAutoStart!,
            });
          }
        }

        // Firestore / gemergtes UserModel: Statuszeilen-Schalter (pro Gerät via UserService)
        final merged = UserService().currentUser.value;
        if (merged != null && merged.id == user.uid) {
          statusNotifForService = merged.showStatusNotification;
          final prefsWrite = await SharedPreferences.getInstance();
          await prefsWrite.setBool(
            _prefsKey(user.uid, 'show_status_notification'),
            merged.showStatusNotification,
          );
        } else {
          final statusNotification = data?['show_status_notification'] as bool?;
          if (statusNotification != null) {
            statusNotifForService = statusNotification;
            final prefsWrite = await SharedPreferences.getInstance();
            await prefsWrite.setBool(
              _prefsKey(user.uid, 'show_status_notification'),
              statusNotification,
            );
          }
        }
      } else {
        _profileIsFree = DjProSessionService.instance.isFreeDj;
      }
      await _shazamService.setShowStatusNotificationEnabled(
        statusNotifForService,
        applyRuntime: false,
      );
      // Free-DJ: festes Scan-Intervall + Smart aus; nur wenn Profil wirklich Free ist (nicht bei transient null-Cache).
      if (_profileIsFree == true) {
        _scanIntervalSeconds = _kFreeScanIntervalSeconds;
        _smartThresholdEnabled = _kFreeSmartThresholdEnabled;
        await _saveLocalTogglePrefs(
          uid: user.uid,
          smartThresholdEnabled: _kFreeSmartThresholdEnabled,
        );
        unawaited(_persistFreeScanIntervalOnly());
      }
      await _shazamService.loadScanInterval();
    } catch (e) {
      debugLog('Fehler beim Laden der Audio-Einstellungen: $e');
    } finally {
      _profileIsFree ??= DjProSessionService.instance.isFreeDj;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Free: nur 5-Min-Intervall + Smart aus in Firestore (kein Überschreiben von Mikro/Schwellenwert).
  Future<void> _persistFreeScanIntervalOnly() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _writeUserSetting({
        'shazam_scan_interval_seconds': _kFreeScanIntervalSeconds,
        'smart_threshold_enabled': _kFreeSmartThresholdEnabled,
      });
      await _shazamService.saveScanIntervalWithRestart(_kFreeScanIntervalSeconds);
      _shazamService.setSmartThresholdEnabled(_kFreeSmartThresholdEnabled);
      if (mounted) {
        setState(() {
          _scanIntervalSeconds = _kFreeScanIntervalSeconds;
          _smartThresholdEnabled = _kFreeSmartThresholdEnabled;
        });
      }
    } catch (e) {
      debugLog('Fehler beim Speichern des Free-Scan-Intervalls: $e');
    }
  }

  /// Speichert das Scan-Intervall mit Hard-Stop & Restart ([saveScanIntervalWithRestart] schreibt `users/{uid}`).
  /// [true] nur nach erfolgreichem Firestore-/Service-Update.
  Future<bool> _saveScanInterval(int seconds) async {
    if (_profileIsFree == true) {
      await _persistFreeScanIntervalOnly();
      return false;
    }
    try {
      await _shazamService.saveScanIntervalWithRestart(seconds);
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).clearSnackBars();
        showVibesSnackBar(context, 
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.scan_interval_set(_formatInterval(l, seconds)),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${l.error_saving} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Aktualisiert die Mikrofon-Empfindlichkeit live (ohne Stream-Unterbrechung)
  Future<void> _updateMicSensitivityLive(double sensitivity) async {
    try {
      await _shazamService.updateMicSensitivityLive(sensitivity);
      // Keine SnackBar, da Update live und unsichtbar erfolgt
    } catch (e) {
      // Bei Fehler: Fallback auf Hard-Stop & Restart
      final l = AppLocalizations.of(context)!;
      debugLog('${l.live_update_failed_fallback} $e');
      try {
        await _shazamService.saveMicSensitivityWithRestart(sensitivity);
      } catch (e2) {
        if (mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text('${l.error_saving} $e2'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  /// Stellt sicher, dass Shazam nach Slider-Änderung automatisch weiterläuft
  Future<void> _ensureAutoResume() async {
      try {
        final l = AppLocalizations.of(context)!;
        final isShazamActive = _shazamService.isEnabled;
        if (isShazamActive) {
          debugLog(l.auto_resume_check_active);
        }
      } catch (e) {
        final l = AppLocalizations.of(context)!;
        debugLog('${l.auto_resume_check_error} $e');
      }
  }
  
  /// Speichert die Mikrofon-Empfindlichkeit ohne Snackbar (für automatische Updates)
  // AUTOMATIC GAIN & THRESHOLD MAPPING: Silent-Version für automatische Updates
  Future<void> _saveMicSensitivitySilent(double sensitivity) async {
    try {
      await _shazamService.saveMicSensitivityWithRestart(sensitivity);
      // Keine Snackbar bei automatischen Updates
    } catch (e) {
      debugLog('Fehler beim Speichern der Mikrofon-Empfindlichkeit (automatisch): $e');
    }
  }
  
  /// Speichert die Mikrofon-Empfindlichkeit mit Hard-Stop & Restart (wie Scan-Intervall)
  Future<void> _saveMicSensitivity(double sensitivity) async {
    try {
      await _shazamService.saveMicSensitivityWithRestart(sensitivity);
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).clearSnackBars();
        showVibesSnackBar(context, 
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.mic_sensitivity_set(sensitivity.toStringAsFixed(1)),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${l.error_saving} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Formatiert Sekunden in lesbares Format
  String _formatInterval(AppLocalizations l, int seconds) {
    if (seconds < 60) {
      return l.audio_format_seconds_only(seconds);
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return l.audio_format_minutes_only(minutes);
    }
    return l.audio_format_minutes_seconds(minutes, remainingSeconds);
  }

  /// Speichert den Schwellenwert ohne Snackbar (für automatische Updates)
  // AUTOMATIC GAIN & THRESHOLD MAPPING: Silent-Version für automatische Updates
  Future<void> _saveRecognitionThresholdSilent(double threshold) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await _writeUserSetting({'recognition_threshold': threshold});
      // Keine Snackbar bei automatischen Updates
    } catch (e) {
      debugLog('Fehler beim Speichern des Schwellenwerts (automatisch): $e');
    }
  }
  
  /// Speichert den Schwellenwert für Musikerkennung in Firestore
  Future<void> _saveRecognitionThreshold(double threshold) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await _writeUserSetting({'recognition_threshold': threshold});
      
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).clearSnackBars();
        showVibesSnackBar(context, 
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.threshold_set((threshold * 100).toStringAsFixed(0)),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${l.error_saving} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Speichert die Smart-Threshold Einstellung in Firestore und synchronisiert den nativen Dienst danach.
  Future<bool> _saveSmartThresholdEnabled(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      await _saveLocalTogglePrefs(
        uid: user.uid,
        smartThresholdEnabled: enabled,
      );
      await _writeUserSetting({'smart_threshold_enabled': enabled});
      await _shazamService.setSmartThresholdEnabled(enabled);

      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).clearSnackBars();
        showVibesSnackBar(context, 
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    enabled
                        ? (l.smart_threshold_enabled_saved)
                        : (l.smart_threshold_disabled_saved),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      debugLog('Fehler beim Speichern der Smart-Threshold Einstellung: $e');
      if (mounted) {
        final lErr = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${lErr.error_saving} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
  
  /// Speichert die Autostart-Einstellung in Firestore.
  Future<bool> _saveAutoStartRecognition(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      await _saveLocalTogglePrefs(
        uid: user.uid,
        autoStartRecognition: enabled,
      );
      await _writeUserSetting({'auto_start_recognition': enabled});

      if (mounted) {
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(enabled
                ? (l.autostart_enabled_message)
                : (l.autostart_disabled_message)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      debugLog('Fehler beim Speichern der Autostart-Einstellung: $e');
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${l.error_saving} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isFree = _profileIsFree ?? DjProSessionService.instance.isFreeDj;
    /// Nur Intervall-Wahl sperren; Mikrofon/Schwellenwert bleiben für Free nutzbar.
    final intervalLocked = isFree;
    final effectiveScanInterval = intervalLocked
        ? _kFreeScanIntervalSeconds
        : (_scanIntervalDrag ?? _scanIntervalSeconds);
    final effectiveMicSensitivity = _micSensitivity;
    final effectiveThreshold = _recognitionThreshold;
    final effectiveSmartThreshold =
        isFree ? _kFreeSmartThresholdEnabled : _smartThresholdEnabled;
    final effectiveAutoStart = _autoStartRecognition;
    if (_isLoading) {
      return widget.cardBuilder(
        context,
        const Center(child: CircularProgressIndicator()),
      );
    }

    return widget.cardBuilder(
      context,
      Padding(
        padding: widget.embedded
            ? EdgeInsets.zero
            : const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded)
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.mic,
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.audio_settings_title,
                    style: SettingsType.title.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
            if (!widget.embedded) const SizedBox(height: 16),

            // Scan-Intervall Regler
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${l.scan_interval_label} ${_formatInterval(l, effectiveScanInterval)}',
                    style: SettingsType.title.copyWith(
                      color: intervalLocked ? Colors.white38 : Colors.white,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SettingsCompactSlider(
              value: effectiveScanInterval.toDouble().clamp(30, 300),
              min: 30,
              max: 300,
              divisions: 27,
              label: _formatInterval(l, effectiveScanInterval),
              onChanged: intervalLocked
                  ? null
                  : (value) {
                      setState(() {
                        _scanIntervalDrag = value.round();
                      });
                    },
              onChangeEnd: intervalLocked
                  ? null
                  : (value) async {
                      final target = value.round().clamp(30, 300);
                      if (!mounted) return;
                      setState(() => _scanIntervalDrag = null);
                      final ok = await _saveScanInterval(target);
                      if (!mounted) return;
                      if (ok) {
                        setState(() {
                          _scanIntervalSeconds = target;
                        });
                        await _ensureAutoResume();
                      }
                    },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '30 ${l.interval_seconds_short}',
                  style: TextStyle(
                    color: intervalLocked ? Colors.white30 : const Color(0xFFC4C4C4),
                    fontSize: SettingsType.hintSize,
                  ),
                ),
                Text(
                  '5 ${l.interval_minutes_short}',
                  style: SettingsType.scaleEnd.copyWith(
                    color: intervalLocked ? Colors.white30 : SettingsType.scaleEnd.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.info_scan_interval_description,
              style: SettingsType.hint.copyWith(
                color: intervalLocked ? Colors.white30 : SettingsType.hint.color,
              ),
            ),
            const SizedBox(height: 16),
            
            // Mikrofon-Empfindlichkeit Regler
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${l.mic_sensitivity_label} ${effectiveMicSensitivity.toStringAsFixed(1)}',
                    style: SettingsType.title,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SettingsCompactSlider(
              value: effectiveMicSensitivity,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: effectiveMicSensitivity.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _micSensitivity = value;
                });
                _updateMicSensitivityLive(value);
              },
              onChangeEnd: (value) {
                _saveMicSensitivity(value);
                _ensureAutoResume();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.sensitivity_low, style: SettingsType.scaleEnd),
                Text(l.sensitivity_high, style: SettingsType.scaleEnd),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.info_mic_sensitivity_description, style: SettingsType.hint),
            const SizedBox(height: 16),
            
            // Pegelanzeige-Balken (zwischen Empfindlichkeit und Schwellenwert)
            StreamBuilder<double>(
              stream: _shazamService.rmsStream, // Verwende gemeinsamen Stream aus ShazamService
              builder: (context, snapshot) {
                final rmsValue = snapshot.data ?? 0.0;
                
                // Visual Boost: Zentraler Faktor aus ShazamService
                final visualLevel = (rmsValue * ShazamService.rmsVisualBoostFactor).clamp(0.0, 1.0);
                
                final screenWidth = MediaQuery.of(context).size.width;
                final barWidth = screenWidth * 0.8; // 80% der Bildschirmbreite
                final filledWidth = barWidth * visualLevel;
                final thresholdPosition = barWidth * effectiveThreshold;
                
                // Test-Farbe: Colors.blue für bessere Sichtbarkeit beim Debugging
                Color barColor;
                if (snapshot.hasData) {
                  barColor = Colors.blue; // Test-Farbe für Debugging
                } else {
                  barColor = Colors.grey[300]!; // Grau wenn keine Daten
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.microphone_level_label,
                      style: SettingsType.title,
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 15, // Feste Höhe: 15px
                      width: barWidth,
                      child: Stack(
                        clipBehavior: Clip.none, // Wichtig: Verhindert Abschneiden
                        children: [
                          // Hintergrund (grauer Hintergrund)
                          Container(
                            height: 15,
                            width: barWidth,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Gefüllter Teil (Farbe je nach Pegel) - IMMER rendern
                          // Breite ZWINGEND basierend auf snapshot.data setzen
                          Container(
                            height: 15,
                            width: snapshot.hasData 
                                ? filledWidth.clamp(0.0, barWidth) 
                                : 0.0, // Keine Breite wenn keine Daten
                            decoration: BoxDecoration(
                              color: snapshot.hasData 
                                  ? barColor 
                                  : Colors.grey[300], // Grau wenn keine Daten
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Schwellenwert-Markierung (vertikale Linie über den Balken) - SCHWARZER STRICH
                          PositionedDirectional(
                            start: thresholdPosition.clamp(0.0, barWidth - 2), // Use PositionedDirectional for RTL
                            child: Container(
                              width: 2,
                              height: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Schwellenwert für Musikerkennung Regler
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${l.recognition_threshold_label} ${(effectiveThreshold * 100).toStringAsFixed(0)}%',
                    style: SettingsType.title,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SettingsCompactSlider(
              value: effectiveThreshold,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(effectiveThreshold * 100).toStringAsFixed(0)}%',
              onChanged: (value) {
                setState(() {
                  _recognitionThreshold = value;
                });
              },
              onChangeEnd: (value) {
                _saveRecognitionThreshold(value);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.threshold_low, style: SettingsType.scaleEnd),
                Text(l.threshold_high, style: SettingsType.scaleEnd),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.info_recognition_threshold_description,
              style: SettingsType.hint,
            ),
            SettingsChoiceRow(
              value: effectiveSmartThreshold,
              title: l.smart_threshold_label,
              hint: l.info_smart_threshold_description,
              enabled: !isFree,
              onChanged: isFree
                  ? null
                  : (value) async {
                      final ok = await _saveSmartThresholdEnabled(value);
                      if (mounted && ok) {
                        setState(() => _smartThresholdEnabled = value);
                      }
                    },
            ),
            SettingsChoiceRow(
              value: effectiveAutoStart,
              title: l.auto_start_recognition_label,
              hint: l.auto_start_recognition_description,
              onChanged: (value) async {
                final ok = await _saveAutoStartRecognition(value);
                if (mounted && ok) {
                  setState(() => _autoStartRecognition = value);
                }
              },
            ),
            if (intervalLocked) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/paywall'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: UIConstants.appOrange.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.music_recognition_free_mode_interval_hint,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
