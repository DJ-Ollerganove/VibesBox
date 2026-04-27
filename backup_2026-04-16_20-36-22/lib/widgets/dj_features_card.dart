import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Dritte Sektion der Feature-Übersicht: DJ-Features mit orangefarbener Umrandung und DJ-Icon.
/// Responsive: Volle Breite, unter der Vergleichstabelle (Free/Pro) sauber untereinander.
class DjFeaturesCard extends StatelessWidget {
  const DjFeaturesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UIConstants.appOrange, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: UIConstants.appOrange, size: 28),
                const SizedBox(width: 10),
                Text(
                  l.feature_dj_title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _featureRow(context, l.feature_dj_control),
            _featureRow(context, l.feature_dj_management),
            _featureRow(context, l.feature_dj_recognition),
            _featureRow(context, l.feature_dj_wishbox),
            _featureRow(context, l.feature_dj_branding),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: UIConstants.appOrange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
