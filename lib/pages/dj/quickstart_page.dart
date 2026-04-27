import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/custom_page_header.dart';

/// DJ-Quickstart-Guide: kompakte Übersicht zentraler Funktionen (ohne Rahmen um Fließtext).
class QuickstartPage extends StatelessWidget {
  const QuickstartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur']
        .contains(Localizations.localeOf(context).languageCode);

    Widget section(String title, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment:
              isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomPageHeader(
              icon: Icons.rocket_launch_outlined,
              title: l.dj_quickstart_title,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    section(l.dj_quickstart_h1_music, l.dj_quickstart_p_music),
                    section(
                        l.dj_quickstart_h1_checkin, l.dj_quickstart_p_checkin),
                    section(l.dj_quickstart_h1_recognition,
                        l.dj_quickstart_p_recognition),
                    section(l.dj_quickstart_h1_i18n, l.dj_quickstart_p_i18n),
                    section(l.dj_quickstart_h1_notifications,
                        l.dj_quickstart_p_notifications),
                    section(l.dj_quickstart_h1_multidevice,
                        l.dj_quickstart_p_multidevice),
                    section(l.dj_quickstart_h1_stability,
                        l.dj_quickstart_p_stability),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
