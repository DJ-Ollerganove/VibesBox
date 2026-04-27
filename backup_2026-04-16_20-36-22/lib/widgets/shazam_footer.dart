import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../services/party_autostart_service.dart';
import '../services/shazam_service.dart';
import '../services/user_service.dart';
import '../utils/party_helper.dart';
import '../utils/role_helper.dart' show hasRole, hasAnyRole;
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';

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
  bool? _isMatchedWithWish;
  String? _currentPartyId;
  StreamSubscription<ShazamScanStatus>? _statusSubscription;
  StreamSubscription<Map<String, dynamic>?>? _resultSubscription;
  StreamSubscription<double>? _rmsSubscription;
  StreamSubscription<Map<String, String>>? _wishMatchSubscription;
  bool _isDJOrAdmin = false;
  bool _isCheckingRole = true;
  double _currentRms = 0.0;
  bool _isScanning = false;
  bool _isTestMode = false; // True wenn keine aktive Party (Testmodus)

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

  @override
  void initState() {
    super.initState();
    _isEnabled = _shazamService.isEnabled; // Lokale Kopie für Fehlerpfade in _onSwitchChanged
    _currentSong = _shazamService.lastResult;
    
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
      // Fehler-Payloads: Songzeile nicht überschreiben (Titel bleibt „klebend“).
      if (err != null && err.isNotEmpty) {
        return;
      }
      setState(() {
        _currentSong = result;
      });
      if (!_isTestMode) {
        _checkMatchWithWishes(result);
      }
    });

    
    // Höre auf RMS-Werte für kompakte Pegelanzeige (immer aktiv, auch wenn nicht gescannt wird)
    _rmsSubscription = _shazamService.rmsStream.listen(
      (rms) {
        if (mounted) {
          setState(() {
            _currentRms = rms.clamp(0.0, 1.0);
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _currentRms = 0.0;
          });
        }
      },
      cancelOnError: false,
    );
    
    // Höre auf automatisch verschobene Wünsche (für Snackbar-Benachrichtigung)
    _wishMatchSubscription = _shazamService.wishMatchStream.listen((match) {
      if (mounted && context.mounted) {
        final title = match['title'] ?? '';
        final artist = match['artist'] ?? '';
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shazamSongMoved(title, artist)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    
    _loadActiveParty();
    _checkUserRole();
  }
  
  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isDJOrAdmin = await _checkIfUserIsDJOrAdmin(user);
      if (mounted) {
        setState(() {
          _isDJOrAdmin = isDJOrAdmin;
          _isCheckingRole = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isDJOrAdmin = false;
          _isCheckingRole = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _statusSubscription?.cancel();
    _resultSubscription?.cancel();
    _rmsSubscription?.cancel();
    _wishMatchSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveParty() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final partyData = await party_dj_check();
      if (mounted) {
        setState(() {
          _currentPartyId = partyData['party_id'];
          _isTestMode = (_currentPartyId == null || (_currentPartyId as String).isEmpty);
        });
      }
    } catch (e) {
      debugLog('Fehler beim Laden der aktiven Party: $e');
    }
  }

  Future<void> _checkMatchWithWishes(Map<String, dynamic> song) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final songTitle = song['title'] as String?;
      final songArtist = song['artist'] as String?;

      if (songTitle == null || songArtist == null) return;

      final wishesSnapshot = await FirebaseFirestore.instance
          .collection('wishes')
          .where('status', isEqualTo: 'open')
          .get();

      bool isMatched = false;
      for (var doc in wishesSnapshot.docs) {
        final wishData = doc.data();
        final wishTitle = (wishData['title'] as String?)?.toLowerCase() ?? '';
        final wishArtist = (wishData['artist'] as String?)?.toLowerCase() ?? '';

        final songTitleLower = songTitle.toLowerCase();
        final songArtistLower = songArtist.toLowerCase();

        if (wishTitle == songTitleLower && wishArtist == songArtistLower) {
          isMatched = true;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _isMatchedWithWish = isMatched;
        });
      }
    } catch (e) {
      debugLog('Fehler beim Prüfen der Wünsche: $e');
      if (mounted) {
        setState(() {
          _isMatchedWithWish = false;
        });
      }
    }
  }
  
  Future<void> _onSwitchChanged(bool value) async {
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
              await openAppSettings();
            }
          }
          return; // Beende hier - Switch bleibt auf false
        }
      }
      
      debugLog('✅ Mikrofon-Berechtigung vorhanden, starte Musikerkennung...');
    }
    
    // Wenn alles OK: Logik ausführen (setState wurde bereits im onChanged-Handler aufgerufen)
    if (value) {
      await PartyAutostartService().setManualRecognitionEnabled(true);
      debugLog('✅ startAutoScanning() aufgerufen, isEnabled: ${_shazamService.isEnabled}');
    } else {
      debugLog('🛑 Stoppe Musikerkennung...');
      await PartyAutostartService().setManualRecognitionEnabled(false);
      debugLog('✅ Musikerkennung gestoppt');
    }
  }
  
  /// Zeile 2: zuletzt erkanntes `Titel - Interpret` bleibt stehen (Cooldown/Scan ändern das nicht).
  String _songStatusLine(AppLocalizations l10n) {
    final artist = ((_currentSong?['artist'] as String?) ?? '').trim();
    final title = ((_currentSong?['title'] as String?) ?? '').trim();
    if (title.isNotEmpty && artist.isNotEmpty) {
      return '$title - $artist';
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
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
        
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _shazamService.recognitionActiveNotifier,
              builder: (context, isRecognitionActive, child) {
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

                            return Stack(
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
              padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
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
                              scale: 0.88,
                              alignment: isRtl
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: MusikerkennungSwitch(
                                initialValue: isRecognitionActive,
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.music_recognition,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                              textDirection: isRtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _songStatusLine(l10n),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 13.5,
                          height: 1.3,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                    textDirection:
                        isRtl ? TextDirection.rtl : TextDirection.ltr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
