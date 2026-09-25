import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'settings_help_dialog.dart';

/// VibesBox-Hilfe-Dialog zur Musikerkennung.
Future<void> showMusicRecognitionInfoDialog(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  await showSettingsHelpDialog(
    context,
    title: l.info_music_recognition_title,
    intro: l.info_music_recognition_intro,
    bullets: [
      SettingsHelpBullet(
        title: l.info_scan_process,
        body: l.info_scan_process_description,
      ),
      SettingsHelpBullet(
        title: l.info_scan_interval,
        body: l.info_scan_interval_description,
      ),
      SettingsHelpBullet(
        title: l.info_mic_sensitivity,
        body: l.info_mic_sensitivity_description,
      ),
      SettingsHelpBullet(
        title: l.info_recognition_threshold,
        body: l.info_recognition_threshold_description,
      ),
      SettingsHelpBullet(
        title: l.info_smart_threshold,
        body: l.info_smart_threshold_description,
      ),
      SettingsHelpBullet(
        title: l.info_auto_start_recognition_info,
        body: l.info_auto_start_recognition_info_description,
        icon: Icons.bolt,
      ),
    ],
  );
}
