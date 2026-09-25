import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Rote Hinweiszeile für DJs, wenn Vorab-Wünsche pausiert sind.
class PreWishesPausedDjBanner extends StatelessWidget {
  const PreWishesPausedDjBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.45),
        border: Border.all(color: Colors.redAccent, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pause_circle_filled,
            color: Colors.red.shade100,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l.pre_wishes_paused_dj_banner,
              style: TextStyle(
                color: Colors.red.shade50,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.4,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
