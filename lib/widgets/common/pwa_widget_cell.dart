import 'package:flutter/material.dart';
import '../../utils/ui_constants.dart';

/// Zentrale Widget-Zelle basierend auf PWA-Design
/// Verwendet exakt die gleichen Werte wie die PWA (.info-card-style)
class PwaWidgetCell extends StatelessWidget {
  final Widget child;
  /// Optional: Rahmenfarbe (Standard: appOrange). Für Party-Bereich z.B. partyYellow.
  final Color? borderColor;

  const PwaWidgetCell({
    super.key,
    required this.child,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Hintergrund: LinearGradient wie in PWA --info-cell-bg
        // linear-gradient(135deg, #1F2937 0%, #121417 100%)
        gradient: const LinearGradient(
          begin: Alignment(-1.0, -1.0), // 135deg entspricht top-left zu bottom-right
          end: Alignment(1.0, 1.0),
          colors: [
            Color(0xFF1F2937), // Start-Farbe
            Color(0xFF121417), // End-Farbe
          ],
        ),
        // Rahmen: 2px, Farbe über borderColor oder Standard Orange
        border: Border.all(
          color: borderColor ?? UIConstants.appOrange,
          width: 2,
        ),
        // Radius: 12px wie in PWA --info-cell-radius
        borderRadius: BorderRadius.circular(12),
        // Schatten: 0 4px 16px rgba(0, 0, 0, 0.3) wie in PWA --info-cell-shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Padding: 24px wie in PWA --info-cell-padding
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: child,
      ),
    );
  }
}
