import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Impressum-Seite im DJ-Bereich – gleiches Layout wie DSGVO/AGB (schwarzer Hintergrund, orange Rahmen).
/// Oben: L10n-Hinweistext in der jeweiligen Sprache (nur bei nicht-DE). Darunter: deutsches Impressum (wie in der PWA).
class ImpressumPage extends StatelessWidget {
  /// Pflicht: Zurück-Navigation setzt _currentIndex in MainPage.
  final VoidCallback onBack;

  const ImpressumPage({super.key, required this.onBack});

  /// Erkennt "1. " oder "§ 1 " / "§ 2 " usw. als Überschrift.
  static final _headingPattern = RegExp(r'^(\d+\.|§\s*\d+)\s+');

  /// Deutsches Impressum (steht immer darunter, wie in der PWA).
  static const String _germanImprint = '''
Impressum
Angaben gemäß § 5 TMG

VibesBox by Swen Steller
Neefestraße 9
09119 Chemnitz / Deutschland

Vertreten durch:
Swen Steller

Kontakt
E-Mail: info@vibesbox.app

§ 1 Inhaltliche Hinweise
(1) Die Inhalte dieser App und Website werden mit größter Sorgfalt erstellt. Der Anbieter übernimmt jedoch keine Gewähr für die Richtigkeit, Vollständigkeit und Aktualität der bereitgestellten Inhalte. (2) Die Nutzung kostenloser Inhalte erfolgt auf eigene Gefahr. Der bloße Abruf dieser Inhalte begründet kein Vertragsverhältnis zwischen Nutzer und Anbieter. (3) Für kostenpflichtige Leistungen (Abonnements für DJs und Locations) gelten vorrangig die Allgemeinen Geschäftsbedingungen (AGB).

§ 2 Externe Links
Dieses Angebot enthält Verlinkungen zu Websites Dritter („externe Links"), z. B. Profile von Dienstleistern oder Veranstaltungsorten. Diese Websites unterliegen der Haftung der jeweiligen Betreiber. Bei Kenntnis von Rechtsverstößen werden derartige Links unverzüglich entfernt.

§ 3 Urheberrecht und verwandte Schutzrechte
(1) Die veröffentlichten Inhalte unterliegen dem deutschen Urheberrecht und Leistungsschutzrecht. Jede Verwertung bedarf der vorherigen schriftlichen Zustimmung des Anbieters. (2) Nutzer, die eigene Inhalte (Texte, Bilder, Logos) hochladen, räumen dem Anbieter die für den Betrieb der App erforderlichen Nutzungsrechte ein. Der Nutzer garantiert, dass er Inhaber aller Rechte an diesen Inhalten ist.

§ 4 Sprachenklausel
Bei Abweichungen zwischen der deutschen Version dieses Dokuments und bereitgestellten Übersetzungen ist die deutsche Version maßgeblich.
''';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const textColor = Colors.white;

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

    final children = <Widget>[];
    const gap = SizedBox(height: 12);

    // Wie in der PWA: Hinweistext in der jeweiligen Sprache (nur bei nicht-DE), darunter deutsches Impressum
    final legalNote = l.imprintLegalNoteNonDe;
    if (legalNote.trim().isNotEmpty) {
      children.add(SelectableText(legalNote.trim(), style: normalStyle));
      children.add(gap);
    }

    final paragraphs = _germanImprint
        .split('\n\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (int i = 0; i < paragraphs.length; i++) {
      if (i > 0) children.add(gap);
      final p = paragraphs[i];
      final lines = p.split('\n');
      final firstLine = lines.first.trim();

      if (lines.length == 1) {
        children.add(SelectableText(
          p,
          style: _headingPattern.hasMatch(firstLine) ? boldStyle : normalStyle,
        ));
        continue;
      }

      if (_headingPattern.hasMatch(firstLine)) {
        children.add(SelectableText(firstLine, style: boldStyle));
        children.add(gap);
        final body = lines.skip(1).join('\n').trim();
        if (body.isNotEmpty) {
          children.add(SelectableText(body, style: normalStyle));
        }
      } else {
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
