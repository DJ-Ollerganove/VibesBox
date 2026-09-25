import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';
import '../widgets/text_scale_settings_section.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

/// Gast-Einstellungen (lokal via SharedPreferences).
class GuestSettingsPage extends StatelessWidget {
  const GuestSettingsPage({super.key});

  static bool _isRtl(BuildContext context) {
    return VbTextDirection.isRtl(context);
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
