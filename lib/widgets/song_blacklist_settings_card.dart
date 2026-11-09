import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../models/dj_song_blacklist_prefs.dart';
import '../services/dj_song_blacklist_service.dart';
import '../utils/firebase_error_message.dart';
import 'settings_choice_row.dart';

/// DJ-Einstellungen: Blacklist ein/aus und Abgelehnt vs. beim Absenden blocken.
class SongBlacklistSettingsCard extends StatefulWidget {
  const SongBlacklistSettingsCard({super.key});

  @override
  State<SongBlacklistSettingsCard> createState() =>
      _SongBlacklistSettingsCardState();
}

class _SongBlacklistSettingsCardState extends State<SongBlacklistSettingsCard> {
  bool _saving = false;

  Future<void> _apply(DjSongBlacklistPrefs next) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await DjSongBlacklistService.instance.saveSettings(
        djId: uid,
        enabled: next.enabled,
        guestBlock: next.guestBlock,
      );
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(
            l.tp('song_blacklist_save_failed', {
              'error': formatFirebaseErrorDetail(e),
            }),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final l = AppLocalizations.of(context)!;
    if (uid.isEmpty) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<DjSongBlacklistPrefs>(
      valueListenable: DjSongBlacklistService.instance.prefsNotifier,
      builder: (context, prefs, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.translate('song_blacklist_settings_title'),
                  style: SettingsType.title.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SettingsChoiceRow(
                  value: prefs.enabled,
                  enabled: !_saving,
                  title: settingsPlainLabel(
                    l.translate('info_settings_blacklist_enabled'),
                  ),
                  hint: l.translate('info_settings_blacklist_enabled_body'),
                  onChanged: _saving
                      ? null
                      : (v) => _apply(prefs.copyWith(enabled: v)),
                ),
                if (prefs.enabled) ...[
                  SettingsChoiceRow(
                    value: !prefs.guestBlock,
                    enabled: !_saving,
                    title: l.translate('song_blacklist_mode_reject'),
                    hint: l.translate('info_settings_blacklist_reject_body'),
                    onChanged: _saving
                        ? null
                        : (_) {
                            if (!prefs.guestBlock) return;
                            _apply(prefs.copyWith(guestBlock: false));
                          },
                  ),
                  SettingsChoiceRow(
                    value: prefs.guestBlock,
                    enabled: !_saving,
                    title: l.translate('song_blacklist_mode_block'),
                    hint: l.translate('info_settings_blacklist_block_body'),
                    onChanged: _saving
                        ? null
                        : (_) {
                            if (prefs.guestBlock) return;
                            _apply(prefs.copyWith(guestBlock: true));
                          },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
