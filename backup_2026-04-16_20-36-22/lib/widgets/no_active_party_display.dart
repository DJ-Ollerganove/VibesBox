import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';
import 'home_cells/styled_home_card.dart';

/// Zentrale Anzeige für "Keine Party aktiv" (Design-System).
/// Nutzt StyledHomeCard mit frameNoParty (Rot), Icon und Lokalisierung.
class NoActivePartyDisplay extends StatelessWidget {
  const NoActivePartyDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: StyledHomeCard(
            borderColor: UIConstants.frameNoParty,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_busy,
                  size: 64,
                  color: UIConstants.frameNoParty,
                ),
                const SizedBox(height: 16),
                Text(
                  l.no_active_party_message,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: UIConstants.colorGrey,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
