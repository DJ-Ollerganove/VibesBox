import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../widgets/audio_settings_card.dart';
import '../widgets/custom_page_header.dart';
import '../services/pro_feature_guard.dart';
import '../services/shazam_service.dart';
import '../services/translation_settings_service.dart';
import '../services/wishbox_suggestions_settings_service.dart';
import '../widgets/text_scale_settings_section.dart';
import '../widgets/results_per_page_settings_section.dart';
import '../widgets/grace_period_settings_section.dart';
import '../services/dj_wish_fcm_service.dart';
import '../services/dj_wish_notification_service.dart';
import '../services/user_service.dart';
import '../services/dj_device_notification_prefs_service.dart';
import '../helpers/security_helper.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../pages/diagnostic_log_page.dart';
import '../services/app_diagnostic_log_service.dart';
import '../utils/ui_constants.dart';
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showGreetingTranslations = true;
  bool _wishboxSuggestionsEnabled = true;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await TranslationSettingsService.isTranslationEnabled();
      final wishboxSuggestions =
          await WishboxSuggestionsSettingsService.isEnabledForDj();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final guestSnap =
            await WishboxSuggestionsSettingsService.guestLiveRef(uid).get();
        if (!guestSnap.exists) {
          await WishboxSuggestionsSettingsService.setEnabledForDj(
            wishboxSuggestions,
            userId: uid,
          );
        }
      }
      if (mounted) {
        setState(() {
          _showGreetingTranslations = enabled;
          _wishboxSuggestionsEnabled = wishboxSuggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(bool value) async {
    try {
      await TranslationSettingsService.setTranslationEnabled(value);
      if (mounted) setState(() => _showGreetingTranslations = value);
    } catch (e) {
      // Fehlerhandling
    }
  }

  Future<void> _saveWishboxSuggestions(bool value) async {
    try {
      await WishboxSuggestionsSettingsService.setEnabledForDj(value);
      if (mounted) setState(() => _wishboxSuggestionsEnabled = value);
    } catch (_) {}
  }

  /// Gleicher Präfix wie [AudioSettingsCard] / [ShazamSettingsSection] für Offline-Cache.
  String _audioSettingsPrefsKey(String uid, String key) =>
      'audio_settings_${uid}_$key';

  Future<void> _writeDjDeviceNotificationFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    final installId =
        await DjDeviceNotificationPrefsService.getOrCreateInstallId();
    final ref = DjDeviceNotificationPrefsService.deviceDocRef(uid, installId);
    await ref.set(
      SecurityHelper.sanitizeMap({
        ...fields,
        'platform': DjDeviceNotificationPrefsService.platformTag(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      SetOptions(merge: true),
    );
  }

  Future<void> _persistShowStatusNotification(
    BuildContext context,
    String uid,
    bool enabled,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        _audioSettingsPrefsKey(uid, 'show_status_notification'),
        enabled,
      );
      await _writeDjDeviceNotificationFields(uid, {
        'show_status_notification': enabled,
      });
      await ShazamService().setShowStatusNotificationEnabled(enabled);
    } catch (e) {
      if (!context.mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.error_saving} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onShowStatusNotificationToggle(
    BuildContext context,
    String uid,
    bool enabled,
  ) async {
    if (enabled) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        status = await Permission.notification.request();
      }
      if (!status.isGranted) {
        if (context.mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.notification_permission_required),
              backgroundColor: Colors.orange,
            ),
          );
        }
        if (context.mounted) {
          await _persistShowStatusNotification(context, uid, false);
        }
        return;
      }
    }
    if (context.mounted) {
      await _persistShowStatusNotification(context, uid, enabled);
    }
  }

  /// Fließtext strikt am Start (links in LTR), Switch am Ende (rechts in LTR).
  Widget _djNotifySwitchRow({
    required bool isRtl,
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required Color labelColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  label,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: UIConstants.appOrange,
              activeTrackColor: UIConstants.appOrange.withValues(alpha: 0.42),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(locale);
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator(color: Colors.orange)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomPageHeader(
                icon: Icons.settings,
                title: l.settings_title,
              ),
              const SizedBox(height: 24),
              // Zelle 1: Audio/Mikrofon
              if (user != null)
                ValueListenableBuilder<SessionProStatus?>(
                  valueListenable: UserService().sessionProStatus,
                  builder: (context, session, _) {
                    return ValueListenableBuilder<UserModel?>(
                      valueListenable: UserService().currentUser,
                      builder: (context, djUser, _) {
                        final canUse = ProFeatureGuard.canUseMusicRecognitionNow(
                          user: user,
                        );
                        return Container(
                          key: ValueKey(
                            '${djUser?.planType}_${djUser?.trialUntil?.millisecondsSinceEpoch}_${session?.isActive}',
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange, width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: AudioSettingsCard(
                              canUsePremium: canUse,
                              cardBuilder: (context, child) => child,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

              TextScaleSettingsSection(textDirectionRtl: isRtl),

              // DJ: Treffer pro Seite (Listen-Paginierung)
              ValueListenableBuilder<UserModel?>(
                valueListenable: UserService().currentUser,
                builder: (context, userModel, _) {
                  if (user == null || userModel == null) {
                    return const SizedBox.shrink();
                  }
                  if (AppConfig.isGuestRole(userModel)) {
                    return const SizedBox.shrink();
                  }
                  return ResultsPerPageSettingsSection(textDirectionRtl: isRtl);
                },
              ),

              // DJ: Nachlaufzeit Wunschliste
              ValueListenableBuilder<UserModel?>(
                valueListenable: UserService().currentUser,
                builder: (context, userModel, _) {
                  if (user == null || userModel == null) {
                    return const SizedBox.shrink();
                  }
                  if (AppConfig.isGuestRole(userModel)) {
                    return const SizedBox.shrink();
                  }
                  return GracePeriodSettingsSection(textDirectionRtl: isRtl);
                },
              ),

              // DJ: Benachrichtigungen — pro Installation unter users/{uid}/dj_device_prefs
              if (user != null)
                ValueListenableBuilder<UserModel?>(
                  valueListenable: UserService().currentUser,
                  builder: (context, djUser, _) {
                    if (djUser == null || djUser.id != user.uid) {
                      return const SizedBox.shrink();
                    }
                    final notifyOn = djUser.notifyNewWishes;
                    final soundOn = djUser.enableNotificationSound;
                    final statusBarOn = djUser.showStatusNotification;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.topStart,
                              child: Text(
                                l.settings_section_notifications,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.start,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _djNotifySwitchRow(
                              isRtl: isRtl,
                              label: l.settings_notify_new_wishes,
                              value: notifyOn,
                              labelColor: Colors.white70,
                              onChanged: (v) {
                                unawaited((() async {
                                  final u =
                                      FirebaseAuth.instance.currentUser;
                                  if (u == null) return;
                                  final wasOff = !notifyOn;
                                  if (v && wasOff) {
                                    await DjWishNotificationService
                                        .requestNotificationPermissionIfNeeded();
                                  }
                                  await _writeDjDeviceNotificationFields(
                                    u.uid,
                                    {'notifyNewWishes': v},
                                  );
                                  if (v) {
                                    unawaited(
                                      DjWishFcmService.instance
                                          .syncTokenForCurrentUserIfEligible(),
                                    );
                                  }
                                })());
                              },
                            ),
                            _djNotifySwitchRow(
                              isRtl: isRtl,
                              label: l.settings_enable_notification_sound,
                              value: soundOn,
                              labelColor: notifyOn
                                  ? Colors.white70
                                  : Colors.white38,
                              onChanged: notifyOn
                                  ? (v) {
                                      unawaited((() async {
                                        final u = FirebaseAuth
                                            .instance.currentUser;
                                        if (u == null) return;
                                        final wasSoundOff = !soundOn;
                                        if (v && wasSoundOff) {
                                          await DjWishNotificationService
                                              .requestNotificationPermissionIfNeeded();
                                        }
                                        await _writeDjDeviceNotificationFields(
                                          u.uid,
                                          {
                                            'enableNotificationSound': v,
                                          },
                                        );
                                      })());
                                    }
                                  : null,
                            ),
                            _djNotifySwitchRow(
                              isRtl: isRtl,
                              label: l.status_notification_enabled,
                              value: statusBarOn,
                              labelColor: Colors.white70,
                              onChanged: (v) {
                                unawaited((() async {
                                  final u =
                                      FirebaseAuth.instance.currentUser;
                                  if (u == null) return;
                                  await _onShowStatusNotificationToggle(
                                    context,
                                    u.uid,
                                    v,
                                  );
                                })());
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Directionality(
                                textDirection: isRtl
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    l.shazamBackgroundHint,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // Zelle: Wunschbox-Wortvorschläge — nur DJ/Admin/Location.
              ValueListenableBuilder<UserModel?>(
                valueListenable: UserService().currentUser,
                builder: (context, userModel, _) {
                  final authUser = FirebaseAuth.instance.currentUser;
                  if (authUser == null || userModel == null) {
                    return const SizedBox.shrink();
                  }
                  if (AppConfig.isGuestRole(userModel)) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: isRtl
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.settings_wishbox_suggestions_title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l.settings_wishbox_suggestions_subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            value: _wishboxSuggestionsEnabled,
                            activeThumbColor: Colors.orange,
                            onChanged: _saveWishboxSuggestions,
                            controlAffinity: isRtl
                                ? ListTileControlAffinity.leading
                                : ListTileControlAffinity.trailing,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Zelle: Grüße übersetzen — nur DJ/Admin/Location, nicht Gastkonten.
              ValueListenableBuilder<UserModel?>(
                valueListenable: UserService().currentUser,
                builder: (context, userModel, _) {
                  final authUser = FirebaseAuth.instance.currentUser;
                  if (authUser == null || userModel == null) {
                    return const SizedBox.shrink();
                  }
                  if (AppConfig.isGuestRole(userModel)) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: isRtl
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.translation_settings_title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l.translation_settings_description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            value: _showGreetingTranslations,
                            activeThumbColor: Colors.orange,
                            onChanged: _saveSetting,
                            controlAffinity: isRtl
                                ? ListTileControlAffinity.leading
                                : ListTileControlAffinity.trailing,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Admin-DJ: Geräte-Diagnose (Abstürze, Shazam, Lifecycle)
              if (user != null &&
                  AppDiagnosticLogService.canAccessDiagnosticUi())
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 1.5),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.bug_report_outlined,
                      color: Colors.orange,
                    ),
                    title: const Text(
                      'Diagnose-Log',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Fehler & Ereignisse auf diesem Gerät protokollieren',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DiagnosticLogPage(),
                        ),
                      );
                    },
                  ),
                ),

              // Schwarzer Leerraum am Ende (verhindert Ankleben an Navigation)
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
