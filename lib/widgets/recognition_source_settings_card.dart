import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/dj_recognition_choice.dart';
import '../services/vibesbox_sync_service.dart';
import 'audio_settings_card.dart';
import 'settings_choice_row.dart';
import 'vibesbox_sync_settings_section.dart';

export '../services/dj_recognition_choice.dart';

/// Eine Karte: Quelle oben, darunter nur die passende Einstellung.
class RecognitionSourceSettingsCard extends StatelessWidget {
  const RecognitionSourceSettingsCard({
    super.key,
    required this.choice,
    required this.canUsePremium,
    required this.onChoice,
  });

  final DjRecognitionChoice choice;
  final bool canUsePremium;
  final ValueChanged<DjRecognitionChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final syncAllowed = VibesBoxSyncService.instance.isVisibleForCurrentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.translate('settings_input_title'),
          style: SettingsType.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(l.translate('settings_input_hint'), style: SettingsType.hint),
        SettingsChoiceRow(
          value: choice == DjRecognitionChoice.microphone,
          title: l.translate('settings_input_mic'),
          onChanged: (_) => onChoice(DjRecognitionChoice.microphone),
        ),
        SettingsChoiceRow(
          value: choice == DjRecognitionChoice.sync,
          title: l.translate('settings_input_sync'),
          hint: choice == DjRecognitionChoice.sync && !syncAllowed
              ? l.translate('settings_input_sync_locked')
              : null,
          onChanged: (_) => onChoice(DjRecognitionChoice.sync),
        ),
        SettingsChoiceRow(
          value: choice == DjRecognitionChoice.none,
          title: l.translate('settings_input_none'),
          onChanged: (_) => onChoice(DjRecognitionChoice.none),
        ),
        if (choice == DjRecognitionChoice.microphone)
          AudioSettingsCard(
            canUsePremium: canUsePremium,
            embedded: true,
            cardBuilder: (context, child) => child,
          ),
        if (choice == DjRecognitionChoice.sync && syncAllowed)
          const VibesBoxSyncSettingsSection(
            showTitle: false,
            showEnableSwitch: false,
          ),
      ],
    );
  }
}
