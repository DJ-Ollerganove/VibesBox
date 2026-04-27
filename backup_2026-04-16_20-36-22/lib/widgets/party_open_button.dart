import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Button "Party öffnen" – schwarzer Hintergrund, oranger Rahmen, weißer Text.
/// Abgerundete Ecken passend zum VibesBox-Design.
class PartyOpenButton extends StatelessWidget {
  final VoidCallback onPressed;

  const PartyOpenButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UIConstants.appOrange, width: 2),
          ),
          child: Text(
            l.party_open,
            style: const TextStyle(
              color: UIConstants.colorWhite,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
