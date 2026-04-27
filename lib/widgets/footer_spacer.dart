import 'package:flutter/material.dart';

/// Widget, das einen Leerraum am Ende von scrollbaren Seiten hinzufügt,
/// damit der letzte Eintrag vollständig über der Pegellinie des schwebenden Footers scrollbar ist.
/// 
/// Verwendung:
/// ```dart
/// Column(
///   children: [
///     // ... Content ...
///     FooterSpacer(), // Am Ende der Liste
///   ],
/// )
/// ```
class FooterSpacer extends StatelessWidget {
  /// Höhe des Leerraums (Standard: 200px für sichtbaren Abstand)
  final double height;

  const FooterSpacer({
    super.key,
    this.height = 200.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}


