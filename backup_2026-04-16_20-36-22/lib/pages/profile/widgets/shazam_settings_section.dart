import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../../services/shazam_service.dart';
import '../../../services/user_service.dart';
import '../../../models/user_model.dart';
import '../../../utils/ui_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/debug_log.dart';

/// Widget für Shazam-Einstellungen (Intervall und Mikrofon-Empfindlichkeit)
class ShazamSettingsSection extends StatefulWidget {
  const ShazamSettingsSection({
    super.key,
    required this.canUsePremium,
  });

  final bool canUsePremium;

  @override
  State<ShazamSettingsSection> createState() => _ShazamSettingsSectionState();
}

class _ShazamSettingsSectionState extends State<ShazamSettingsSection> {
  final ShazamService _shazamService = ShazamService();
  int _scanIntervalSeconds = 60; // Standard: 60 Sekunden
  double _micSensitivity = 1.0; // Standard: 1.0 (0.5 bis 2.0)
  double _recognitionThreshold = 0.3; // Standard: 0.3 (0.0 bis 1.0)
  bool _smartThresholdEnabled = false; // Standard: false (manuell)
  bool _autoStartRecognition = false; // Standard: false (manuell)
  bool _showStatusNotification = false; // Standard: false
  bool _isLoading = true;
  bool? _profileIsFree;
  int? _scanIntervalDrag;
  
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
    bool? showStatusNotification,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (smartThresholdEnabled != null) {
      await prefs.setBool(_prefsKey(uid, 'smart_threshold_enabled'), smartThresholdEnabled);
    }
    if (autoStartRecognition != null) {
      await prefs.setBool(_prefsKey(uid, 'auto_start_recognition'), autoStartRecognition);
    }
    if (showStatusNotification != null) {
      await prefs.setBool(_prefsKey(uid, 'show_status_notification'), showStatusNotification);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // AUTOMATIC GAIN & THRESHOLD MAPPING: Höre auf automatische Werte-Updates
    debugLog('🎧 ShazamSettingsSection: Abonniere autoAdjustStream...');
    _autoAdjustSubscription = _shazamService.autoAdjustStream.listen(
      (values) {
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
        debugLog("❌ autoAdjustStream Fehler in ShazamSettingsSection: $error");
        debugLog("❌ autoAdjustStream Fehler in ShazamSettingsSection: $error");
      },
      cancelOnError: false, // Stream bleibt aktiv auch bei Fehlern
    );
    debugLog('✅ ShazamSettingsSection: autoAdjustStream abonniert');
  }
  
  @override
  void dispose() {
    _autoAdjustSubscription?.cancel();
    _autoAdjustUiDebounce?.cancel();
    super.dispose();
  }

  /// Lädt die Shazam-Einstellungen aus Firestore
  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final localSmart = prefs.getBool(_prefsKey(user.uid, 'smart_threshold_enabled'));
      final localAutoStart = prefs.getBool(_prefsKey(user.uid, 'auto_start_recognition'));
      final localStatusNotification = prefs.getBool(_prefsKey(user.uid, 'show_status_notification'));
      final hasLocalSmart = localSmart != null;
      final hasLocalAutoStart = localAutoStart != null;
      if (localSmart != null) _smartThresholdEnabled = localSmart;
      if (localAutoStart != null) _autoStartRecognition = localAutoStart;
      if (localStatusNotification != null) _showStatusNotification = localStatusNotification;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final model = UserModel.fromFirestore(userDoc);
        _profileIsFree = model.isFree;

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
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
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
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'auto_start_recognition': localAutoStart!,
            });
          }
        }

        final statusNotification = data?['show_status_notification'] as bool?;
        if (statusNotification != null) {
          _showStatusNotification = statusNotification;
          await _saveLocalTogglePrefs(
            uid: user.uid,
            showStatusNotification: statusNotification,
          );
        }
      } else {
        _profileIsFree = UserService().currentUser.value?.isFree ?? true;
      }
      await _shazamService.setShowStatusNotificationEnabled(
        _showStatusNotification,
        applyRuntime: false,
      );
      await _shazamService.loadScanInterval();
    } catch (e) {
      debugLog('Fehler beim Laden der Shazam-Einstellungen: $e');
    } finally {
      _profileIsFree ??= UserService().currentUser.value?.isFree ?? true;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Speichert das Scan-Intervall mit Hard-Stop & Restart (inkl. Firestore via ShazamService).
  Future<bool> _saveScanInterval(int seconds) async {
    if (_profileIsFree == true) return false;
    try {
      await _shazamService.saveScanIntervalWithRestart(seconds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan-Intervall auf ${_formatInterval(seconds)} gesetzt'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
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
      debugLog('⚠️ Live-Update fehlgeschlagen, verwende Hard-Stop & Restart: $e');
      try {
        await _shazamService.saveMicSensitivityWithRestart(sensitivity);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Speichern: $e2'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  /// Stellt sicher, dass Shazam nach Slider-Änderung automatisch weiterläuft
  /// Dies ist ein Sicherheitsnetz, falls der Auto-Resume in den Service-Methoden fehlgeschlagen ist
  Future<void> _ensureAutoResume() async {
    try {
      // Prüfe ob Shazam aktiv sein sollte
      final isShazamActive = _shazamService.isEnabled;
      if (isShazamActive) {
        // Der Auto-Resume sollte bereits in saveScanIntervalWithRestart und updateMicSensitivityLive erfolgen
        // Dies ist nur ein zusätzlicher Check für den Fall, dass etwas schiefgelaufen ist
        // Keine Aktion nötig, da die Service-Methoden bereits Auto-Resume implementieren
        debugLog('✅ Auto-Resume-Check: Shazam ist aktiv');
      }
    } catch (e) {
      debugLog('⚠️ Fehler beim Auto-Resume-Check: $e');
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
  
  /// Speichert die Mikrofon-Empfindlichkeit mit Hard-Stop & Restart (Fallback)
  Future<void> _saveMicSensitivity(double sensitivity) async {
    try {
      await _shazamService.saveMicSensitivityWithRestart(sensitivity);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mikrofon-Empfindlichkeit auf ${sensitivity.toStringAsFixed(1)} gesetzt',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Formatiert Sekunden in lesbares Format
  String _formatInterval(int seconds) {
    if (seconds < 60) {
      return '$seconds Sek.';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '$minutes Min.';
      } else {
        return '$minutes Min. $remainingSeconds Sek.';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isFree = _profileIsFree ?? UserService().currentUser.value?.isFree ?? false;
    final intervalLocked = isFree;
    final scanSliderValue = intervalLocked
        ? _shazamService.effectiveScanIntervalSeconds
        : (_scanIntervalDrag ?? _scanIntervalSeconds);
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Überschrift mit Info-Icon
            Row(
              children: [
                Icon(
                  Icons.music_note,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Musikerkennung-Einstellungen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  iconSize: 20,
                  color: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Informationen zur Musikerkennung',
                  onPressed: () => _showInfoDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Scan-Intervall (Free: fest 3 Min., nicht änderbar)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Scan-Intervall: ${_formatInterval(scanSliderValue)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: intervalLocked ? Colors.grey : null,
                        ),
                  ),
                ),
                if (intervalLocked)
                  Icon(
                    Icons.lock_outline,
                    color: UIConstants.appOrange.withValues(alpha: 0.85),
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
                  value: scanSliderValue.toDouble().clamp(30, 300),
                  min: 30,
                  max: 300,
                  divisions: 27, // 30, 40, 50, ..., 300 (10 Sekunden Schritte)
                  label: _formatInterval(scanSliderValue),
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
                          if (mounted && ok) {
                            setState(() => _scanIntervalSeconds = target);
                            await _ensureAutoResume();
                          }
                        },
                ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '30 Sek.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '5 Min.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Mikrofon-Empfindlichkeit Regler
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mikrofon-Empfindlichkeit: ${_micSensitivity.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
                  value: _micSensitivity,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15, // 0.5, 0.6, 0.7, ..., 2.0 (0.1 Schritte)
                  label: _micSensitivity.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _micSensitivity = value;
                    });
                    // Live-Update: Sensitivity sofort ohne Stream-Unterbrechung
                    _updateMicSensitivityLive(value);
                  },
                  onChangeEnd: (value) {
                    _ensureAutoResume();
                  },
                ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0.5 (Niedrig)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '2.0 (Hoch)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Pegelanzeige-Balken (zwischen Empfindlichkeit und Schwellenwert)
            StreamBuilder<double>(
              stream: _shazamService.rmsStream, // Verwende gemeinsamen Stream aus ShazamService
              builder: (context, snapshot) {
                // Debug: Prüfe ob Daten ankommen
                debugLog('📊 PROFIL-LOG: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, data=${snapshot.data}');
                
                final rmsValue = snapshot.data ?? 0.0;
                
                // Visual Boost: Zentraler Faktor aus ShazamService
                final visualLevel = (rmsValue * ShazamService.rmsVisualBoostFactor).clamp(0.0, 1.0);
                
                final screenWidth = MediaQuery.of(context).size.width;
                final barWidth = screenWidth * 0.8; // 80% der Bildschirmbreite
                final filledWidth = barWidth * visualLevel;
                final thresholdPosition = barWidth * _recognitionThreshold;
                
                // Test-Farbe: Colors.blue für bessere Sichtbarkeit beim Debugging
                // Später zurück auf die Grün-Rot-Logik
                Color barColor;
                // TEMPORÄR: Test-Farbe für Debugging
                if (snapshot.hasData) {
                  barColor = Colors.blue; // Test-Farbe für Debugging
                } else {
                  barColor = Colors.grey[300]!; // Grau wenn keine Daten
                }
                
                // Original-Farbe-Logik (auskommentiert für Debugging)
                // if (visualLevel < 0.5) {
                //   barColor = Colors.green; // Grün (leise)
                // } else if (visualLevel < 0.8) {
                //   barColor = Colors.yellow; // Gelb (mittel)
                // } else {
                //   barColor = Colors.red; // Rot (laut)
                // }
                
                // Debug: Zeige berechnete Werte
                if (snapshot.hasData) {
                  debugLog('🎨 Profil: rmsValue=${rmsValue.toStringAsFixed(3)}, visualLevel=${visualLevel.toStringAsFixed(3)}, filledWidth=${filledWidth.toStringAsFixed(1)}');
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mikrofon-Pegel:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
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
                          // Schwellenwert-Markierung (vertikale Linie über den Balken)
                          Positioned(
                            left: thresholdPosition.clamp(0.0, barWidth - 2), // Sicherstellen, dass innerhalb des Balkens
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
            const SizedBox(height: 32),
            
            // Schwellenwert für Musikerkennung Regler
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Schwellenwert: ${(_recognitionThreshold * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
                  value: _recognitionThreshold,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20, // 0%, 5%, 10%, ..., 100% (5% Schritte)
                  label: '${(_recognitionThreshold * 100).toStringAsFixed(0)}%',
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
                Text(
                  '0% (Niedrig)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '100% (Hoch)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Intelligente Anpassung Checkbox (im UI deaktiviert; Free-DJ: nur Anzeige)
            Row(
              children: [
                Checkbox(
                  value: _smartThresholdEnabled,
                  onChanged: isFree ? null : (v) {},
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Intelligente Anpassung',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        isFree
                            ? (l.music_recognition_pro_only_notice)
                            : 'Funktion derzeit deaktiviert (Deaktiviert)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
                  ],
            ),
            if (intervalLocked) ...[
              const SizedBox(height: 10),
              Text(
                l.music_recognition_free_mode_interval_hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      height: 1.25,
                    ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Autostart: bleibt für Free-DJ aktiv und bedienbar
            // Autostart: Musikerkennung bei Party-Beginn automatisch starten (persönliche Einstellung)
            Row(
              children: [
                Switch(
                  value: _autoStartRecognition,
                  onChanged: (bool value) async {
                    final ok = await _saveAutoStartRecognition(value);
                    if (mounted && ok) {
                      setState(() => _autoStartRecognition = value);
                    }
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Musikerkennung automatisch starten, wenn Party aktiv',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Startet die Musikerkennung automatisch, sobald eine deiner Partys in der Cloud aktiv wird',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _showStatusNotification,
                  onChanged: (bool value) {
                    _onStatusNotificationSwitchChanged(value);
                  },
                ),
                Expanded(
                  child: Text(
                    l.status_notification_enabled,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// Speichert den Schwellenwert für Musikerkennung in Firestore
  /// Speichert den Schwellenwert ohne Snackbar (für automatische Updates)
  // AUTOMATIC GAIN & THRESHOLD MAPPING: Silent-Version für automatische Updates
  Future<void> _saveRecognitionThresholdSilent(double threshold) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'recognition_threshold': threshold,
      });
      // Keine Snackbar bei automatischen Updates
    } catch (e) {
      debugLog('Fehler beim Speichern des Schwellenwerts (automatisch): $e');
    }
  }
  
  Future<void> _saveRecognitionThreshold(double threshold) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'recognition_threshold': threshold,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Schwellenwert auf ${(threshold * 100).toStringAsFixed(0)}% gesetzt',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Speichert die Smart-Threshold Einstellung in Firestore
  Future<void> _saveSmartThresholdEnabled(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await _saveLocalTogglePrefs(
        uid: user.uid,
        smartThresholdEnabled: enabled,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'smart_threshold_enabled': enabled,
      });
      
      // Keine SnackBar, da dies eine Hintergrund-Einstellung ist
    } catch (e) {
      debugLog('Fehler beim Speichern der Smart-Threshold Einstellung: $e');
    }
  }
  
  /// Speichert die Autostart-Einstellung in Firestore
  Future<bool> _saveAutoStartRecognition(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await _saveLocalTogglePrefs(
        uid: user.uid,
        autoStartRecognition: enabled,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'auto_start_recognition': enabled,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled
                ? 'Autostart aktiviert: Musikerkennung startet automatisch bei aktiver Party'
                : 'Autostart deaktiviert'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      debugLog('Fehler beim Speichern der Autostart-Einstellung: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _saveShowStatusNotification(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _saveLocalTogglePrefs(
        uid: user.uid,
        showStatusNotification: enabled,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'show_status_notification': enabled,
      });
      await _shazamService.setShowStatusNotificationEnabled(enabled);
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.error_saving} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onStatusNotificationSwitchChanged(bool enabled) async {
    if (enabled) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        status = await Permission.notification.request();
      }
      if (!status.isGranted) {
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          setState(() => _showStatusNotification = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l.notification_permission_required,
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        await _saveShowStatusNotification(false);
        return;
      }
    }

    if (mounted) {
      setState(() => _showStatusNotification = enabled);
    }
    await _saveShowStatusNotification(enabled);
  }
  
  /// Zeigt Info-Dialog zur Musikerkennung
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Musikerkennung'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'So funktioniert die Musikerkennung:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoBullet(
                  context,
                  'Scan-Vorgang:',
                  'Sobald die Musikerkennung startet, hört das System immer für exakt 8 Sekunden zu. Dies erkennst du deutlich am farbigen Ausschlag des Pegels unten im Footer oder im Profil. Nach den 8 Sekunden schaltet sich das Mikrofon automatisch wieder ab, um Ressourcen zu sparen.',
                ),
                const SizedBox(height: 12),
                _buildInfoBullet(
                  context,
                  'Scan-Intervall:',
                  'Legt fest, wie oft automatisch nach Musik gesucht wird. Während dieser Zeit ist das Mikrofon inaktiv.',
                ),
                const SizedBox(height: 12),
                _buildInfoBullet(
                  context,
                  'Mikrofon-Empfindlichkeit:',
                  'Erhöht oder verringert die Empfindlichkeit des Mikrofons. Bei leiser Musik sollte der Wert erhöht werden.',
                ),
                const SizedBox(height: 12),
                _buildInfoBullet(
                  context,
                  'Schwellenwert:',
                  'Der Mindestlautstärkepegel, der erreicht werden muss, bevor ein Scan durchgeführt wird. Verhindert, dass bei zu leiser Musik unnötig gescannt wird.',
                ),
                const SizedBox(height: 12),
                _buildInfoBullet(
                  context,
                  'Intelligente Anpassung:',
                  'Passt den Schwellenwert automatisch an die Umgebung an (5-45%). Hilft besonders in leisen Umgebungen, verhindert aber Übersteuerung in lauten Clubs.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Verstanden'),
            ),
          ],
        );
      },
    );
  }
  
  /// Hilfsmethode für Info-Bullet-Points
  Widget _buildInfoBullet(BuildContext context, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

