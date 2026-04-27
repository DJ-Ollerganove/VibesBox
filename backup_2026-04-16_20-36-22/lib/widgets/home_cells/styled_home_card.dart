import 'package:flutter/material.dart';
import '../../utils/ui_constants.dart';

/// Zentrales Widget für Home-Cards mit einheitlichem Design
/// Basiert auf den PWA-Design-Definitionen aus public/index.html
/// 
/// Design-Spezifikationen (aus PWA):
/// - Hintergrund: Grauer Gradient (#1F2937 → #121417) - entspricht --info-cell-bg
/// - Border: von außen steuerbar via borderColor
/// - BorderRadius: 12 - entspricht --info-cell-radius
/// - Padding: 16 (angepasst für Flutter, PWA verwendet 24px für Info-Cards)
class StyledHomeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  /// Rahmenfarbe aus Rollen: frameOffen, frameGespielt, frameAbgelehnt, frameGesperrt, frameHistory, frameNoParty
  final Color borderColor;

  const StyledHomeCard({
    super.key,
    required this.child,
    this.padding,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            UIConstants.bgGradientStart,
            UIConstants.bgGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0), // Standard: 16, PWA: 24px für Info-Cards
        child: child,
      ),
    );
  }
}
