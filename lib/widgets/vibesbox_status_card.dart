import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Wiederverwendbare VibesBox-Status-Karte mit Schieberegler
/// 
/// Diese Karte ermöglicht es, die VibesBox (Gäste-Wünsche) manuell ein- und auszuschalten.
class VibesboxStatusCard extends StatelessWidget {
  /// Aktueller Status der VibesBox (true = aktiviert, false = deaktiviert)
  final bool value;
  
  /// Callback, der aufgerufen wird, wenn der Status geändert wird
  final ValueChanged<bool> onChanged;
  
  /// Funktion zum Erstellen der Card-Wrapper (für konsistentes Design)
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const VibesboxStatusCard({
    super.key,
    required this.value,
    required this.onChanged,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return cardBuilder(
      context,
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.vibesbox_status_title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ? l.status_enabled : l.status_disabled,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
