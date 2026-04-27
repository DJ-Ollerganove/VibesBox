import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// AGB-Seite (Allgemeine Geschäftsbedingungen für DJs) – Design: schwarzer Hintergrund, orange Rahmen.
/// Nur Zeilen mit Nummerierung (z. B. „1. Geltungsbereich“) sind fett; Fließtext normal. Leerzeilen zwischen Überschriften und Abschnitten.
class TermsOfServicePage extends StatelessWidget {
  /// Pflicht: Zurück-Navigation setzt _currentIndex in MainPage.
  final VoidCallback onBack;

  const TermsOfServicePage({super.key, required this.onBack});

  static final _numberedHeading = RegExp(r'^\d+\.\s+');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const textColor = Colors.white;

    final content = l.termsOfServiceContent;

    const normalStyle = TextStyle(
      color: textColor,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.normal,
    );
    const boldStyle = TextStyle(
      color: textColor,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.bold,
    );

    if (content.isEmpty) {
      final backLabel = l.back;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: UIConstants.guestBoxDecoration,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: onBack,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, color: UIConstants.appOrange, size: 20),
                        const SizedBox(width: 8),
                        Text(backLabel, style: const TextStyle(color: UIConstants.appOrange, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const Text('AGB werden geladen...', style: normalStyle),
              ],
            ),
          ),
        ),
      );
    }

    final paragraphs = content
        .split('\n\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final children = <Widget>[];
    const gap = SizedBox(height: 12);

    for (int i = 0; i < paragraphs.length; i++) {
      if (i > 0) children.add(gap);
      final p = paragraphs[i];
      final lines = p.split('\n');
      final firstLine = lines.first.trim();

      if (lines.length == 1) {
        // Einzeiliger Absatz: nur Überschrift fett, sonst normal
        children.add(SelectableText(
          p,
          style: _numberedHeading.hasMatch(firstLine) ? boldStyle : normalStyle,
        ));
        continue;
      }

      if (_numberedHeading.hasMatch(firstLine)) {
        // Erste Zeile = nummerierte Überschrift → fett, dann Leerzeile, dann Rest normal
        children.add(SelectableText(firstLine, style: boldStyle));
        children.add(gap);
        final body = lines.skip(1).join('\n').trim();
        if (body.isNotEmpty) {
          children.add(SelectableText(body, style: normalStyle));
        }
      } else {
        // Keine Überschrift am Anfang (z. B. Anbieter-Block) → alles normal
        children.add(SelectableText(p, style: normalStyle));
      }
    }

    final backLabel = l.back;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: UIConstants.guestBoxDecoration,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: onBack,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, color: UIConstants.appOrange, size: 20),
                      const SizedBox(width: 8),
                      Text(backLabel, style: const TextStyle(color: UIConstants.appOrange, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
