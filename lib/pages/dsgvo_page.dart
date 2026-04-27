import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Datenschutzerklärung für DJs – gleiches Layout wie terms_of_service_page (schwarzer Hintergrund, orange Rahmen).
/// Nummerierte Überschriften fett, danach Leerzeile, Fließtext normal. Scrollbar.
class DSGVOPage extends StatelessWidget {
  /// Pflicht: Zurück-Navigation setzt _currentIndex in MainPage.
  final VoidCallback onBack;

  const DSGVOPage({super.key, required this.onBack});

  static final _numberedHeading = RegExp(r'^\d+\.\s+');

  /// Vollständiger Text der Datenschutzerklärung für DJs (Stand: Februar 2026).
  static const String _content = '''
Datenschutzerklärung für DJs – VibesBox
Stand: Februar 2026
Anbieter: VibesBox by Swen Steller, Neefestraße 9, 09119 Chemnitz
E-Mail: info@vibesbox.app

1. Verantwortlicher
Der in den Impressumsangaben genannte Anbieter ist für die Datenverarbeitung verantwortlich. Wir nehmen den Schutz Ihrer personenbezogenen Daten sehr ernst.

2. Datensammlung bei Registrierung (DJs & Locations)
Wir erheben die für die Bereitstellung Ihres Profils und die Abwicklung Ihres Abonnements erforderlichen Daten:

Name, Anschrift, E-Mail-Adresse

Zahlungsdaten (über externe Zahlungsdienstleister)

Profilinhalte (Bilder, Beschreibungen, Einsatzbereiche)

3. Datenaustausch in der App
Zum Zweck der Vermittlung werden Daten von DJs und Locations für andere Nutzer (Paare/Veranstalter) sichtbar gemacht. Mit der Anlage eines Profils willigen Sie in diese Veröffentlichung ein.

4. Rechte der Nutzer
Sie haben jederzeit das Recht auf Auskunft, Berichtigung, Löschung oder Einschränkung der Verarbeitung Ihrer gespeicherten Daten sowie das Recht auf Datenübertragbarkeit. Wenden Sie sich dazu an info@vibesbox.app.

5. Datensicherheit
Wir setzen moderne Verschlüsselungsverfahren (SSL/TLS) ein, um Ihre Daten bei der Übertragung in der App zu schützen.
''';

  @override
  Widget build(BuildContext context) {
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

    final paragraphs = _content
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
        children.add(SelectableText(
          p,
          style: _numberedHeading.hasMatch(firstLine) ? boldStyle : normalStyle,
        ));
        continue;
      }

      if (_numberedHeading.hasMatch(firstLine)) {
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

    final l = AppLocalizations.of(context)!;
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
