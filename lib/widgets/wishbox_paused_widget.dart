import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Hinweis für Gäste, wenn der DJ die Wunschbox pausiert hat (PWA: partyPausedOverlay).
class WishboxPausedWidget extends StatelessWidget {
  const WishboxPausedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFB300), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_filled, size: 48, color: Colors.amber.shade800),
          const SizedBox(height: 12),
          Text(
            l10n.wishbox_paused,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.amber.shade900,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.wishbox_paused_guest_message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5D4037),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
