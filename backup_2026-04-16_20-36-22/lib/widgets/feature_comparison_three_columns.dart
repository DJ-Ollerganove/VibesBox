import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Drei-Spalten-Vergleich auf der Login-Seite: Gast | Angemeldeter User | DJ.
/// Schwarzer Hintergrund, orangefarbene Rahmen; responsive: auf schmalen Screens untereinander.
class FeatureComparisonThreeColumns extends StatelessWidget {
  const FeatureComparisonThreeColumns({super.key});

  static const double _breakpoint = 700;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final useColumn = width < _breakpoint;

    final guestCard = _buildColumnCard(
      context,
      title: l.feature_comparison_guest,
      icon: Icons.person_outline,
      items: [
        l.send_music_wishes,
        l.use_contact_form,
        l.open_social_media_links,
      ],
    );
    final userCard = _buildColumnCard(
      context,
      title: l.feature_comparison_user,
      icon: Icons.person,
      items: [
        l.view_your_wishes_anytime,
        l.manage_edit_profile,
        l.view_wish_statistics,
        l.edit_greetings,
      ],
    );
    final djCard = _buildColumnCard(
      context,
      title: l.feature_dj_title,
      icon: Icons.mic,
      items: [
        l.feature_dj_control,
        l.feature_dj_management,
        l.feature_dj_recognition,
        l.feature_dj_wishbox,
        l.feature_dj_branding,
      ],
      accentOrange: true,
    );

    if (useColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          guestCard,
          const SizedBox(height: 16),
          userCard,
          const SizedBox(height: 16),
          djCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: guestCard),
        const SizedBox(width: 12),
        Expanded(child: userCard),
        const SizedBox(width: 12),
        Expanded(child: djCard),
      ],
    );
  }

  Widget _buildColumnCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> items,
    bool accentOrange = false,
  }) {
    final color = accentOrange ? UIConstants.appOrange : Colors.white70;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: UIConstants.appOrange,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((text) => _featureRow(context, text)),
        ],
      ),
    );
  }

  Widget _featureRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: UIConstants.appOrange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
