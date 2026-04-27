import 'package:flutter/material.dart';

import '../../services/statistics_service.dart';

/// Admin-Dashboard: DJ- und Gast-Zahlen (E-Mail bestätigt vs. offen), gleicher Karten-Stil wie [LoginCounterCard].
class AdminUserRoleStatsCard extends StatelessWidget {
  final AdminUserRoleStatistics stats;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const AdminUserRoleStatsCard({
    super.key,
    required this.stats,
    required this.cardBuilder,
  });

  static const Color _mutedOrange = Color(0xFFB8732F);

  TextStyle _body(BuildContext context) {
    final t = Theme.of(context).textTheme.bodyMedium;
    return (t ?? const TextStyle()).copyWith(color: Colors.white70);
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int confirmed,
    required int open,
  }) {
    final body = _body(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: body,
              children: [
                TextSpan(text: '$label: '),
                TextSpan(
                  text: '$confirmed',
                  style: body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: ' ($open)',
                  style: body.copyWith(color: _mutedOrange),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return cardBuilder(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            context,
            icon: Icons.graphic_eq,
            label: 'DJs',
            confirmed: stats.djEmailVerified,
            open: stats.djEmailUnverified,
          ),
          const SizedBox(height: 10),
          _row(
            context,
            icon: Icons.people_outline,
            label: 'Gäste',
            confirmed: stats.guestEmailVerified,
            open: stats.guestEmailUnverified,
          ),
        ],
      ),
    );
  }
}
