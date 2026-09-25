import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_scaffold_messenger.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../services/active_party_service.dart';
import '../services/party_autostart_service.dart';
import '../services/shazam_service.dart';
import '../services/vibesbox_sync_service.dart';
import '../utils/camelot_helper.dart';
import '../utils/ios_microphone_settings.dart';
import '../services/user_service.dart';
import '../utils/party_helper.dart';
import '../utils/role_helper.dart' show hasRole, hasAnyRole;
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';
import '../services/song_recommendation_service.dart';
import '../services/song_recommendation_settings_service.dart';
import '../services/pro_feature_guard.dart';
import 'song_recommendation_edge_panel.dart';

/// Persistent Footer für Musikerkennung
/// Zeigt aktuelles Ergebnis und Switch zum Aktivieren/Deaktivieren
class ShazamFooter extends StatefulWidget {
  const ShazamFooter({super.key});

  @override
  State<ShazamFooter> createState() => _ShazamFooterState();
}

class _ShazamFooterState extends State<ShazamFooter> {
  final ShazamService _shazamService = ShazamService();
  bool _isEnabled = false;
  Map<String, dynamic>? _currentSong;
  StreamSubscription<ShazamScanStatus>? _statusSubscription;
  StreamSubscription<Map<String, dynamic>?>? _resultSubscription;
  StreamSubscription<Map<String, String>>? _wishMatchSubscription;
  bool _isDJOrAdmin = false;
  bool _isCheckingRole = true;
  bool _isScanning = false;
  bool _isTestMode = false; // True wenn keine aktive Party (Testmodus)
  final OverlayPortalController _recOverlay = OverlayPortalController();
  final GlobalKey _footerBarKey = GlobalKey();
  double _recOverlayBottom = 80;
  (String, String)? _dismissedRecSeed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      if (l10n != null) {
        unawaited(
          _shazamService.setNotificationStrings(
            l10n.status_notification_title,
            l10n.status_notification_listening,
            l10n.recognition_success,
          ),
        );
      }
    }
  }

  void _onRecognitionActiveNotifier() {
    if (!mounted) return;
    final active = _shazamService.recognitionActiveNotifier.value;
    if (_isEnabled == active) return;
    setState(() {
      _isEnabled = active;
    });
    if (!active && !VibesBoxSyncService.instance.enabled) {
      SongRecommendationService.instance.clearRuntimeCaches();
      if (_recOverlay.isShowing) {
        _recOverlay.hide();
      }
    }
  }

  void _onVibesBoxSyncChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onRecSettingsChanged() {
    if (!mounted) return;
    // Nur UI neu bauen (Panel an/aus) — kein OpenAI-Prefetch mehr.
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _isEnabled = _shazamService.isEnabled; // Lokale Kopie für Fehlerpfade in _onSwitchChanged
    _currentSong = _shazamService.lastResult;
    unawaited(SongRecommendationSettingsService.instance.ensureLoaded());
    SongRecommendationSettingsService.instance.notifier.addListener(
      _onRecSettingsChanged,
    );
    _shazamService.recognitionActiveNotifier.addListener(
      _onRecognitionActiveNotifier,
    );
    VibesBoxSyncService.instance.addListener(_onVibesBoxSyncChanged);
    
    // Höre auf Status-Updates
    _statusSubscription = _shazamService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isScanning = (status == ShazamScanStatus.scanning);
        });
      }
    });
    
    // Höre auf Ergebnis-Updates
    _resultSubscription = _shazamService.resultStream.listen((result) {
      if (!mounted || result == null) return;
      final err = result['error'] as String?;
      if (err == 'FREE_SCAN_COOLDOWN' || err == 'NEXT_SCAN_COUNTDOWN') {
        return;
      }
      // APP_CHECK_INVALID: globale orangefarbene SnackBar in [ShazamService] (root ScaffoldMessenger).
      // Fehler-Payloads: Songzeile nicht überschreiben (Titel bleibt „klebend“).
      if (err != null && err.isNotEmpty) {
        return;
      }
      setState(() {
        _currentSong = result;
      });
      // Wunsch-Abgleich nur in ShazamService (_checkAndUpdateWishes) —
      // kein zweiter Pending-Query im Footer.
    });

    // RMS nur über StreamBuilder unten (kein zweites Abo auf rmsStream).

    // Höre auf automatisch verschobene Wünsche (für Snackbar-Benachrichtigung)
    _wishMatchSubscription = _shazamService.wishMatchStream.listen((match) {
      if (mounted && context.mounted) {
        final title = match['title'] ?? '';
        final artist = match['artist'] ?? '';
        final l10n = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(l10n.shazamSongMoved(title, artist)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    
    ActivePartyService.storedSessionNotifier.addListener(_onStoredPartySessionChanged);
    _loadActiveParty();
    _checkUserRole();
  }

  void _onStoredPartySessionChanged() {
    unawaited(_loadActiveParty());
  }
  
  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isDJOrAdmin = false;
            _isCheckingRole = false;
          });
        }
        return;
      }
      final isDJOrAdmin = await _checkIfUserIsDJOrAdmin(user);
      if (mounted) {
        setState(() {
          _isDJOrAdmin = isDJOrAdmin;
          _isCheckingRole = false;
        });
      }
    } catch (e) {
      debugLog('ShazamFooter Rolle: $e');
      if (mounted) {
        setState(() {
          _isDJOrAdmin = true;
          _isCheckingRole = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _shazamService.recognitionActiveNotifier.removeListener(
      _onRecognitionActiveNotifier,
    );
    VibesBoxSyncService.instance.removeListener(_onVibesBoxSyncChanged);
    SongRecommendationSettingsService.instance.notifier.removeListener(
      _onRecSettingsChanged,
    );
    ActivePartyService.storedSessionNotifier.removeListener(
      _onStoredPartySessionChanged,
    );
    _statusSubscription?.cancel();
    _resultSubscription?.cancel();
    _wishMatchSubscription?.cancel();
    if (_recOverlay.isShowing) {
      _recOverlay.hide();
    }
    super.dispose();
  }

  Future<void> _loadActiveParty() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final partyData = await party_dj_check();
      if (mounted) {
        final pid = partyData['party_id'];
        setState(() {
          _isTestMode =
              pid == null || pid.isEmpty || pid == 'manual';
        });
      }
    } catch (e) {
      debugLog('Fehler beim Laden der aktiven Party: $e');
    }
  }

  Future<void> _onSwitchChanged(bool value) async {
    if (VibesBoxSyncService.instance.enabled) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Zurück setzen wenn kein User
      if (mounted) {
        setState(() {
          _isEnabled = false;
        });
      }
      return;
    }
    
    // Prüfe Rolle
    final isAdmin = isAdminUser(user);
    final isDJ = await hasRole(user, 'DJ');
    
    if (!isAdmin && !isDJ) {
      // Zurück setzen wenn keine Berechtigung
      if (mounted) {
        setState(() {
          _isEnabled = false;
        });
      }
      return;
    }
    
    // DJ-Testmodus: Erlaube Start auch ohne Party (nur für DJ/Admin)
    // Es wird keine SnackBar mehr angezeigt, da Testmodus erlaubt ist
    
    // ✅ TEST-MODUS: Pro/Premium-Guard deaktiviert - immer erlaubt
    // ✅ ORIGINAL-CODE (auskommentiert für später):
    /*
    // Wenn aktivieren: Pro/Premium-Guard (Musikerkennung nur für Pro/Premium oder Admin)
    if (value) {
      final allowed = await ProFeatureGuard.canUseMusicRecognition(user: user);
      if (!allowed) {
        if (mounted) {
          setState(() {
            _isEnabled = false;
          });
        }
        if (context.mounted) {
          await PremiumFeatureDialog.show(context);
        }
        return;
      }
    }
    */

    // Wenn aktivieren: Permission-Guard
    if (value) {
      debugLog('🎤 Prüfe Mikrofon-Berechtigung...');
      var permissionStatus = await Permission.microphone.status;
      debugLog('🎤 Mikrofon-Berechtigung Status: $permissionStatus');
      
      if (!permissionStatus.isGranted) {
        debugLog('🔐 Fordere Mikrofon-Berechtigung an...');
        permissionStatus = await Permission.microphone.request();
        debugLog('🎤 Mikrofon-Berechtigung nach Anfrage: $permissionStatus');
        
        if (!permissionStatus.isGranted) {
          debugLog('❌ Mikrofon-Berechtigung verweigert');
          // Switch zurück auf false
          if (mounted) {
            setState(() {
              _isEnabled = false;
            });
            
            // Zeige Dialog für Einstellungen
            final l10nDlg = AppLocalizations.of(context)!;
            final shouldOpenSettings = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                title: Text(l10nDlg.shazam_dialog_microphone_title),
                content: Text(l10nDlg.shazam_dialog_microphone_body),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    child: Text(l10nDlg.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    child: Text(l10nDlg.permission_open_settings),
                  ),
                ],
              ),
            );
            
            if (shouldOpenSettings == true) {
              await openIosMicrophonePrivacyOrAppSettings();
            }
          }
          return; // Beende hier - Switch bleibt auf false
        }
      }
      
      debugLog('✅ Mikrofon-Berechtigung vorhanden, starte Musikerkennung...');
    }
    
    // Wenn alles OK: Logik ausführen (setState wurde bereits im onChanged-Handler aufgerufen)
    if (value) {
      final outcome = await PartyAutostartService().setManualRecognitionEnabled(true);
      if (outcome == RecognitionStartOutcome.blockedByOtherDevice) {
        if (mounted) {
          setState(() {
            _isEnabled = false;
          });
        }
        if (context.mounted) {
          final takeover = await _showRecognitionLockedDialog();
          if (takeover == true && context.mounted) {
            try {
              await _shazamService.forceClearRecognitionLockForCurrentParty();
              final retry = await PartyAutostartService()
                  .setManualRecognitionEnabled(true);
              if (retry == RecognitionStartOutcome.started ||
                  retry == RecognitionStartOutcome.alreadyRunning) {
                if (mounted) {
                  setState(() => _isEnabled = _shazamService.isEnabled);
                }
                return;
              }
              if (retry == RecognitionStartOutcome.blockedByOtherDevice &&
                  context.mounted) {
                await _showRecognitionLockedDialog();
              }
            } catch (e) {
              debugLog('⚠️ Recognition-Lock Übernahme fehlgeschlagen: $e');
            }
          }
        }
        return;
      }
      if (outcome == RecognitionStartOutcome.lockAcquireFailed) {
        if (mounted) {
          setState(() {
            _isEnabled = false;
          });
        }
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          showRootVibesSnackBar(
            SnackBar(
              content: Text(l10n.recognition_lock_acquire_failed),
              backgroundColor: UIConstants.appOrange,
              behavior: SnackBarBehavior.floating,
            ),
            tag: 'ShazamFooter',
          );
        }
        return;
      }
      debugLog('✅ startAutoScanning() aufgerufen, isEnabled: ${_shazamService.isEnabled}');
    } else {
      debugLog('🛑 Stoppe Musikerkennung...');
      await PartyAutostartService().setManualRecognitionEnabled(false);
      SongRecommendationService.instance.clearRuntimeCaches();
      if (_recOverlay.isShowing) {
        _recOverlay.hide();
      }
      debugLog('✅ Musikerkennung gestoppt');
    }
  }

  Future<bool?> _showRecognitionLockedDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = VbTextDirection.isRtl(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: UIConstants.appOrange, width: 1.8),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.recognition_lock_dialog_title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.redAccent,
                      tooltip: l10n.close,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.recognition_lock_dialog_body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                  ),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: UIConstants.appOrange,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(l10n.recognition_lock_takeover_button),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  (String, String)? get _recognizedTitleArtist {
    final title = ((_currentSong?['title'] as String?) ?? '').trim();
    final artist = ((_currentSong?['artist'] as String?) ?? '').trim();
    if (title.isEmpty || artist.isEmpty || title == '-' || artist == '-') {
      return null;
    }
    return (title, artist);
  }

  bool get _showRecPanel {
    // Eigene Suche nur bei aktiver Musikerkennung. Sync darf die Liste zeigen.
    if (!_isEnabled && !VibesBoxSyncService.instance.enabled) return false;
    final recognized = _recognizedTitleArtist;
    if (recognized == null) return false;
    if (!SongRecommendationSettingsService.instance.notifier.value.enabled) {
      return false;
    }
    if (_dismissedRecSeed != null &&
        _dismissedRecSeed!.$1 == recognized.$1 &&
        _dismissedRecSeed!.$2 == recognized.$2) {
      return false;
    }
    return true;
  }

  void _scheduleRecOverlayLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box =
          _footerBarKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final h = box.size.height;
      if ((h - _recOverlayBottom).abs() > 0.5) {
        setState(() => _recOverlayBottom = h);
      }
    });
  }

  Widget _buildRecOverlay(BuildContext context) {
    return ValueListenableBuilder<SessionProStatus?>(
      valueListenable: UserService().sessionProStatus,
      builder: (context, _, __) {
        return ValueListenableBuilder<SongRecommendationSettings>(
      valueListenable: SongRecommendationSettingsService.instance.notifier,
      builder: (context, _, __) {
        if (!ProFeatureGuard.canUseProExclusiveNow()) {
          return const SizedBox.shrink();
        }
        if (!_showRecPanel) return const SizedBox.shrink();
        final recognized = _recognizedTitleArtist;
        if (recognized == null) return const SizedBox.shrink();
        return SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                bottom: _recOverlayBottom,
                child: Material(
                  type: MaterialType.transparency,
                  child: SongRecommendationEdgePanel(
                    key: ValueKey('${recognized.$1}|${recognized.$2}'),
                    seedTitle: recognized.$1,
                    seedArtist: recognized.$2,
                    seedBpm: (_currentSong?['bpm'] as num?)?.toDouble(),
                    seedCamelot:
                        ((_currentSong?['camelot'] as String?) ?? '').trim(),
                    useExternalSource: VibesBoxSyncService.instance.enabled,
                    externalItems: VibesBoxSyncService.instance.suggestions,
                    externalLoading:
                        VibesBoxSyncService.instance.suggestionsLoading,
                    onDismissPermanently: () {
                      if (!mounted) return;
                      setState(() => _dismissedRecSeed = recognized);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
      },
    );
  }

  /// Zeile 2: zuletzt erkanntes Stück (Titel und/oder Interpret wie Benachrichtigungszeile).
  String _songStatusLine(AppLocalizations l10n) {
    if (VibesBoxSyncService.instance.enabled &&
        (_currentSong?['idle'] == true ||
            ShazamService.formatRecognizedTrackLabel(
                  ((_currentSong?['title'] as String?) ?? '').trim(),
                  ((_currentSong?['artist'] as String?) ?? '').trim(),
                ) ==
                null)) {
      return l10n.vibesbox_sync_no_song;
    }
    final artist = ((_currentSong?['artist'] as String?) ?? '').trim();
    final title = ((_currentSong?['title'] as String?) ?? '').trim();
    final line = ShazamService.formatRecognizedTrackLabel(title, artist);
    if (line != null) {
      final bits = <String>[line];
      final bpm = CamelotHelper.formatBpm(_currentSong?['bpm'] as num?);
      if (bpm != null) bits.add(bpm);
      final camelot = ((_currentSong?['camelot'] as String?) ?? '').trim();
      if (camelot.isNotEmpty) bits.add(camelot);
      return bits.join(' · ');
    }
    if (_isScanning) {
      return l10n.recognition_running;
    }
    return l10n.music_recognition_none_found;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    
    // Footer nur für DJ/Admin anzeigen
    if (_isCheckingRole) {
      // Während der Prüfung nichts anzeigen (oder einen kleinen Platzhalter)
      return const SizedBox.shrink();
    }
    
    if (!_isDJOrAdmin) {
      return const SizedBox.shrink();
    }
    
    final isAdmin = user != null ? isAdminUser(user) : false;
    // DJ-Testmodus: Erlaube Toggle auch ohne aktive Party (für DJ/Admin)
    final canToggle = user != null && (isAdmin || _isDJOrAdmin);
    
    // RTL-Erkennung
    final isRtl = VbTextDirection.isRtl(context);

    _scheduleRecOverlayLayout();
    if (!_recOverlay.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_recOverlay.isShowing) {
          _recOverlay.show();
        }
      });
    }
        
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: OverlayPortal(
        controller: _recOverlay,
        overlayLocation: OverlayChildLocation.rootOverlay,
        overlayChildBuilder: _buildRecOverlay,
        child: SafeArea(
          key: _footerBarKey,
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ValueListenableBuilder<bool>(
              valueListenable: _shazamService.recognitionActiveNotifier,
              builder: (context, isRecognitionActive, child) {
                final syncOn = VibesBoxSyncService.instance.enabled;
                if (syncOn) {
                  return IgnorePointer(
                    ignoring: true,
                    child: Container(
                      height: 3,
                      width: double.infinity,
                      color: VibesBoxSyncService.instance.connected
                          ? UIConstants.appOrange
                          : Colors.grey[700],
                    ),
                  );
                }
                return IgnorePointer(
                  ignoring: true,
                  child: isRecognitionActive
                      ? StreamBuilder<double>(
                          stream: _shazamService.rmsStream,
                          builder: (context, snapshot) {
                            final rmsValue = snapshot.data ?? 0.0;
                            final visualLevel = (rmsValue *
                                    ShazamService.rmsVisualBoostFactor)
                                .clamp(0.0, 1.0);
                            final barWidth =
                                MediaQuery.of(context).size.width * visualLevel;
                            Color barColor;
                            if (_isTestMode) {
                              barColor = Colors.cyanAccent;
                            } else if (visualLevel < 0.5) {
                              barColor = Colors.green;
                            } else if (visualLevel < 0.8) {
                              barColor = Colors.yellow;
                            } else {
                              barColor = Colors.red;
                            }

                            return RepaintBoundary(
                              child: Stack(
                              children: [
                                Container(
                                  height: 3,
                                  width: double.infinity,
                                  color: Colors.grey[900],
                                ),
                                Container(
                                  height: 3,
                                  width: barWidth > 0 ? barWidth : 0.0,
                                  color: visualLevel > 0.01
                                      ? barColor
                                      : Colors.grey[700],
                                ),
                              ],
                            ),
                            );
                          },
                        )
                      : Container(
                          height: 3,
                          width: double.infinity,
                          color: Colors.grey[700],
                        ),
                );
              },
            ),
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 5, 12, 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                image: const DecorationImage(
                  image: AssetImage('assets/images/header_bg.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  colorFilter: ColorFilter.mode(
                    Colors.black54,
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        _shazamService.recognitionActiveNotifier,
                    builder: (context, isRecognitionActive, _) {
                      final syncOn = VibesBoxSyncService.instance.enabled;
                      if (syncOn) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          textDirection:
                              isRtl ? TextDirection.rtl : TextDirection.ltr,
                          children: [
                            Expanded(
                              child: Text(
                                l10n.vibesbox_sync_title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                textDirection: isRtl
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        textDirection:
                            isRtl ? TextDirection.rtl : TextDirection.ltr,
                        children: [
                          Theme(
                            data: Theme.of(context).copyWith(
                              switchTheme: SwitchThemeData(
                                thumbColor: WidgetStateProperty.resolveWith(
                                  (states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.white;
                                    }
                                    return Colors.grey.shade400;
                                  },
                                ),
                                trackColor: WidgetStateProperty.resolveWith(
                                  (states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return UIConstants.appOrange;
                                    }
                                    return Colors.grey.shade800;
                                  },
                                ),
                              ),
                            ),
                            child: Transform.scale(
                              scale: 0.78,
                              alignment: isRtl
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: MusikerkennungSwitch(
                                // Wichtig: nicht nur recognitionActiveNotifier — der bleibt bei
                                // Geräte-Sperre false, während der Switch intern kurz „an“ springt.
                                // [_isEnabled] wird bei blockiertem Start u. a. wieder auf false gesetzt.
                                initialValue: _isEnabled,
                                canToggle: canToggle,
                                onChanged: (bool value) async {
                                  setState(() => _isEnabled = value);
                                  await _onSwitchChanged(value);
                                  if (mounted) {
                                    setState(
                                      () => _isEnabled =
                                          _shazamService.isEnabled,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.music_recognition,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                              textDirection: isRtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Row(
                    textDirection:
                        isRtl ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      Expanded(
                        child: Text(
                          _songStatusLine(l10n),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 12,
                                height: 1.2,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                          textDirection: isRtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (_isTestMode) ...[
                    const SizedBox(height: 3),
                    Text(
                      l10n.music_recognition_test_mode_no_save_hint,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            height: 1.15,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                      textDirection:
                          isRtl ? TextDirection.rtl : TextDirection.ltr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<bool> _checkIfUserIsDJOrAdmin(User user) async {
    if (isAdminUser(user)) return true;
    return await hasAnyRole(user, ['DJ', 'Admin']);
  }
  
  bool isAdminUser(User user) {
    final current = UserService().currentUser.value;
    return current != null && current.id == user.uid && AppConfig.isAdminRole(current);
  }
  
}

/// Isolierter Switch für Musikerkennung - verhindert Rebuilds durch StreamBuilder
class MusikerkennungSwitch extends StatefulWidget {
  final bool initialValue;
  final bool canToggle;
  final ValueChanged<bool> onChanged;

  const MusikerkennungSwitch({
    super.key,
    required this.initialValue,
    required this.canToggle,
    required this.onChanged,
  });

  @override
  State<MusikerkennungSwitch> createState() => _MusikerkennungSwitchState();
}

class _MusikerkennungSwitchState extends State<MusikerkennungSwitch> {
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialValue;
  }

  @override
  void didUpdateWidget(MusikerkennungSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wenn sich initialValue geändert hat (z. B. Party-Ende → Notifier false), State anpassen und neu bauen
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() {
        _isEnabled = widget.initialValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nur der Switch selbst - Icon und Text sind jetzt in der Row des Footers
    return Switch(
      value: _isEnabled,
      onChanged: widget.canToggle
          ? (bool value) {
              setState(() {
                _isEnabled = value;
              });
              widget.onChanged(value);
            }
          : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
