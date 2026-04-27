import 'package:flutter/material.dart';

/// Helper-Klasse für Footer-Berechnungen
/// Berechnet die Footer-Höhe dynamisch basierend auf dem Design
class FooterHelper {
  /// Berechnet die Höhe des Footers
  /// Pegellinie (4px) + Padding oben (8px) + Inhalt (Zeile 1: ~24px, optional Zeile 2: ~20px) + Padding unten (6px + bottomPadding)
  static double getFooterHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Pegellinie: 4px
    const pegellinieHeight = 4.0;
    
    // Footer-Container: top 4px + Inhalt (min. 1 Zeile ~28px) + bottom 4px + bottomPadding
    // Zeile 1: ~28px (Icon 20px + Text ~14px + Padding)
    // Optional Zeile 2: ~18px (wenn Song angezeigt wird)
    // Wir nehmen den maximalen Fall mit 2 Zeilen
    const footerContentHeight = 4.0 + 28.0 + 2.0 + 18.0 + 4.0; // top + Zeile 1 + Padding zwischen Zeilen + Zeile 2 + bottom = 60.0px
    
    return pegellinieHeight + footerContentHeight + bottomPadding;
  }
  
  /// Gibt das Padding zurück, das am Ende von Listen verwendet werden sollte
  /// Entspricht exakt der Footer-Höhe, damit der letzte Eintrag vollständig über den Footer scrollbar ist
  static EdgeInsets getFooterPadding(BuildContext context) {
    return const EdgeInsets.only(
      top: 8.0, // Padding oben für bessere Sichtbarkeit des ersten Eintrags
      bottom: 84.0, // Reduziertes Bottom-Padding für kompakteres Seitenende
    );
  }
  
  /// Gibt nur das Bottom-Padding zurück (ohne Top-Padding)
  static EdgeInsets getFooterBottomPadding(BuildContext context) {
    return EdgeInsets.only(
      bottom: getFooterHeight(context),
    );
  }

  /// Gibt die Höhe des benötigten bottomPadding zurück
  /// Wird verwendet, damit der letzte Eintrag vollständig über der Pegellinie scrollbar ist
  /// Diese Funktion sollte für SizedBox am Ende von Listen verwendet werden
  static double getBottomPaddingHeight() {
    return 96.0;
  }

  /// Gibt das Bottom-Padding zurück, das am Ende aller Seiten verwendet werden sollte.
  static EdgeInsets getPageBottomPadding() {
    return const EdgeInsets.only(
      bottom: 96.0,
    );
  }
}

