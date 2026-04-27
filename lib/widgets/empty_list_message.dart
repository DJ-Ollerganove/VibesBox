import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Zentrales Widget für Leermeldungen (Empty States)
/// Prüft den Party-Status und zeigt die entsprechende Nachricht an
class EmptyListMessage extends StatelessWidget {
  /// Optional: Benutzerdefinierte Meldung, wenn Party aktiv, aber Liste leer
  /// Wenn nicht gesetzt, wird die Standard-Meldung verwendet
  final String? emptyMessageWhenPartyActive;
  
  EmptyListMessage({
    super.key,
    this.emptyMessageWhenPartyActive,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    
    // RTL-Support
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;

    // Zeige immer die "keine Wünsche"-Nachricht, keine Party-Prüfung mehr
    final message = emptyMessageWhenPartyActive ?? 
                   (l.no_wishes_yet);
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.start,
        textDirection: textDirection,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
      ),
    );
  }
}

