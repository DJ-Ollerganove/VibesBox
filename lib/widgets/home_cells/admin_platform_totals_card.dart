import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/admin_platform_totals_service.dart';
import '../../utils/ui_constants.dart';

/// Plattform-Zahlen unter dem Admin-Kreisdiagramm (Gäste, DJs, Partys).
class AdminPlatformTotalsCard extends StatelessWidget {
  final AdminPlatformTotals totals;
  final bool isLoading;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const AdminPlatformTotalsCard({
    super.key,
    required this.totals,
    required this.isLoading,
    required this.cardBuilder,
  });

  Widget _row(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          Text(
            isLoading ? '…' : '$value',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: UIConstants.appOrange,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.admin_platform_totals_title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (totals.lastFullRecountAt != null && !isLoading) ...[
          const SizedBox(height: 4),
          Text(
            l.admin_platform_totals_recount_hint,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
        const SizedBox(height: 8),
        cardBuilder(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(l.admin_platform_totals_guests, totals.guestsTotal),
              const Divider(height: 16, color: Colors.white24),
              _row(l.admin_platform_totals_djs_total, totals.djsTotal),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    _row(l.admin_platform_totals_djs_free, totals.djsFree),
                    _row(l.admin_platform_totals_djs_pro, totals.djsPro),
                    _row(
                      l.admin_platform_totals_djs_pro_life,
                      totals.djsProLife,
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, color: Colors.white24),
              _row(l.admin_platform_totals_parties_total, totals.partiesTotal),
              _row(
                l.admin_platform_totals_parties_running,
                totals.partiesRunning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
