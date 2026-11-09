import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../widgets/recognition_source_settings_card.dart';
import '../widgets/song_recommendation_settings_card.dart';
import '../widgets/song_blacklist_settings_card.dart';
import '../widgets/custom_page_header.dart';
import '../widgets/settings_choice_row.dart';
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
import '../app_scaffold_messenger.dart';
import '../services/vibesbox_sync_service.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showGreetingTranslations = true;
  bool _wishboxSuggestionsEnabled = true;
  bool _isLoading = true;
  DjRecognitionChoice _inputChoice = DjRecognitionChoice.microphone;
  @override
  void initState() {
    super.initState();
    VibesBoxSyncService.instance.addListener(_onSyncChoiceChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    VibesBoxSyncService.instance.removeListener(_onSyncChoiceChanged);
    super.dispose();
  }

  Future<void> _onSyncChoiceChanged() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;
    final stored = await DjRecognitionChoiceStore.read(uid);
    if (!mounted || stored == null || stored == _inputChoice) return;
    setState(() => _inputChoice = stored);
  }

  Future<void> _applySyncFlag(DjRecognitionChoice choice) async {
    final sync = VibesBoxSyncService.instance;
    if (choice == DjRecognitionChoice.sync && !sync.isVisibleForCurrentUser) {
      return;
    }
    final want = choice == DjRecognitionChoice.sync;
    if (sync.enabled == want) return;
    await sync.setEnabled(want);
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await TranslationSettingsService.isTranslationEnabled();
      final wishboxSuggestions =
          await WishboxSuggestionsSettingsService.isEnabledForDj();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      var inputChoice = DjRecognitionChoice.microphone;
      if (uid != null) {
        final stored = await DjRecognitionChoiceStore.read(uid);
        final sync = VibesBoxSyncService.instance;
        if (stored == null &&
            sync.enabled &&
            sync.isVisibleForCurrentUser) {
          inputChoice = DjRecognitionChoice.sync;
          await DjRecognitionChoiceStore.save(uid, inputChoice);
        } else {
          inputChoice = stored ?? DjRecognitionChoice.microphone;
          await _applySyncFlag(inputChoice);
        }
      }
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
          _inputChoice = inputChoice;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setInputChoice(DjRecognitionChoice choice) async {
    if (choice == _inputChoice) return;
    setState(() => _inputChoice = choice);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await DjRecognitionChoiceStore.save(uid, choice);
    await _applySyncFlag(choice);
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
      showVibesSnackBar(context, 
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
          showVibesSnackBar(context, 
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final isRtl = VbTextDirection.isRtlLanguageCode(locale);
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
              if (user != null)
                ListenableBuilder(
                  listenable: Listenable.merge([
                    UserService().currentUser,
                    UserService().sessionProStatus,
                    VibesBoxSyncService.instance,
                  ]),
                  builder: (context, _) {
                    final djUser = UserService().currentUser.value;
                    final canUse = ProFeatureGuard.canUseMusicRecognitionNow(
                      user: user,
                    );
                    final session = UserService().sessionProStatus.value;
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
                        child: RecognitionSourceSettingsCard(
                          choice: _inputChoice,
                          canUsePremium: canUse,
                          onChoice: (choice) {
                            unawaited(_setInputChoice(choice));
                          },
                        ),
                      ),
                    );
                  },
                ),

              ListenableBuilder(
                listenable: Listenable.merge([
                  UserService().currentUser,
                  VibesBoxSyncService.instance,
                ]),
                builder: (context, _) {
                  final userModel = UserService().currentUser.value;
                  if (user == null || userModel == null) {
                    return const SizedBox.shrink();
                  }
                  if (AppConfig.isGuestRole(userModel)) {
                    return const SizedBox.shrink();
                  }
                  final sourceOn = _inputChoice ==
                          DjRecognitionChoice.microphone ||
                      (_inputChoice == DjRecognitionChoice.sync &&
                          VibesBoxSyncService
                              .instance.isVisibleForCurrentUser);
                  if (!sourceOn) return const SizedBox.shrink();
                  return const SongRecommendationSettingsCard();
                },
              ),

              ValueListenableBuilder<UserModel?>(
                valueListenable: UserService().currentUser,
                builder: (context, userModel, _) {
                  if (user == null || userModel == null) {
                    return const SizedBox.shrink();
                  }
                  if (AppConfig.isGuestRole(userModel)) {
                    return const SizedBox.shrink();
                  }
                  return const SongBlacklistSettingsCard();
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
                            Text(
                              l.settings_section_notifications,
                              style: SettingsType.title.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.start,
                            ),
                            const SizedBox(height: 4),
                            SettingsChoiceRow(
                              title: l.settings_notify_new_wishes,
                              hint: l.translate('info_settings_notify_wishes_body'),
                              value: notifyOn,
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
                            SettingsChoiceRow(
                              title: l.settings_enable_notification_sound,
                              hint: l.translate('info_settings_notify_sound_body'),
                              value: soundOn,
                              enabled: notifyOn,
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
                            if (_inputChoice ==
                                    DjRecognitionChoice.microphone ||
                                (_inputChoice == DjRecognitionChoice.sync &&
                                    VibesBoxSyncService
                                        .instance.isVisibleForCurrentUser))
                              SettingsChoiceRow(
                                title: _inputChoice ==
                                        DjRecognitionChoice.microphone
                                    ? l.translate(
                                        'settings_notify_source_mic_title',
                                      )
                                    : l.translate(
                                        'settings_notify_source_sync_title',
                                      ),
                                hint: _inputChoice ==
                                        DjRecognitionChoice.microphone
                                    ? l.translate(
                                        'settings_notify_source_mic_hint',
                                      )
                                    : l.translate(
                                        'settings_notify_source_sync_hint',
                                      ),
                                value: statusBarOn,
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
                    margin: const EdgeInsets.only(bottom: 16),
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
                            style: SettingsType.title.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SettingsChoiceRow(
                            title: settingsPlainLabel(
                              l.translate('info_settings_wishbox_toggle'),
                            ),
                            hint: l.translate('info_settings_wishbox_toggle_body'),
                            value: _wishboxSuggestionsEnabled,
                            onChanged: _saveWishboxSuggestions,
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
                    margin: const EdgeInsets.only(bottom: 16),
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
                            style: SettingsType.title.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SettingsChoiceRow(
                            title: settingsPlainLabel(
                              l.translate('info_settings_translation_toggle'),
                            ),
                            hint: l.translate(
                              'info_settings_translation_toggle_body',
                            ),
                            value: _showGreetingTranslations,
                            onChanged: _saveSetting,
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
                    title: Text(
                      l.diagnostic_log_title,
                      style: SettingsType.title.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      l.diagnostic_log_settings_subtitle,
                      style: SettingsType.hint,
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
