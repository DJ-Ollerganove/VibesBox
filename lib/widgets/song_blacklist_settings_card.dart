import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../models/dj_song_blacklist_prefs.dart';
import '../services/dj_song_blacklist_service.dart';
import '../utils/firebase_error_message.dart';
import '../utils/ui_constants.dart';
import 'settings_help_dialog.dart';
import 'settings_info_icon_button.dart';

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.translate('song_blacklist_settings_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: prefs.enabled,
                      activeThumbColor: UIConstants.appOrange,
                      activeTrackColor:
                          UIConstants.appOrange.withValues(alpha: 0.42),
                      onChanged: _saving
                          ? null
                          : (v) => _apply(prefs.copyWith(enabled: v)),
                    ),
                    SettingsInfoIconButton(
                      tooltip: l.settings_help_tooltip,
                      onPressed: () => showSettingsHelpFromL10n(
                        context,
                        titleKey: 'song_blacklist_settings_title',
                        introKey: 'info_settings_blacklist_intro',
                        bullets: const [
                          (
                            'info_settings_blacklist_enabled',
                            'info_settings_blacklist_enabled_body',
                          ),
                          (
                            'info_settings_blacklist_reject',
                            'info_settings_blacklist_reject_body',
                          ),
                          (
                            'info_settings_blacklist_block',
                            'info_settings_blacklist_block_body',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  l.translate('song_blacklist_settings_enable_hint'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (prefs.enabled) ...[
                  const SizedBox(height: 10),
                  _ModeTile(
                    selected: !prefs.guestBlock,
                    title: l.translate('song_blacklist_mode_reject'),
                    hint: l.translate('song_blacklist_mode_reject_hint'),
                    onTap: _saving
                        ? null
                        : () => _apply(prefs.copyWith(guestBlock: false)),
                  ),
                  const SizedBox(height: 6),
                  _ModeTile(
                    selected: prefs.guestBlock,
                    title: l.translate('song_blacklist_mode_block'),
                    hint: l.translate('song_blacklist_mode_block_hint'),
                    onTap: _saving
                        ? null
                        : () => _apply(prefs.copyWith(guestBlock: true)),
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

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.selected,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? UIConstants.appOrange.withValues(alpha: 0.14)
          : const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? UIConstants.appOrange : Colors.white54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
