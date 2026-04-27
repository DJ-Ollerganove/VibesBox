import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';
import '../widgets/text_scale_settings_section.dart';

/// Gast-Einstellungen (lokal via [TextScaleService] / SharedPreferences).
/// Aktuell nur Schriftgröße — später erweiterbar.
class GuestSettingsPage extends StatelessWidget {
  const GuestSettingsPage({super.key});

  static bool _isRtl(BuildContext context) {
    return ['ar', 'he', 'fa', 'ur']
        .contains(Localizations.localeOf(context).languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = _isRtl(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: UIConstants.appBarForegroundColor,
        iconTheme: UIConstants.appBarIconTheme,
        titleTextStyle: UIConstants.appBarTitleTextStyle,
        title: Text(l.settings_title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextScaleSettingsSection(textDirectionRtl: isRtl),
        ],
      ),
    );
  }
}
