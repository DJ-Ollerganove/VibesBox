import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/dj_dashboard_statistics_service.dart';
import '../widgets/home_cells/stats_pie_chart_shared.dart';

class DjDashboardStatisticsSection extends StatelessWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final Future<DjDashboardStatistics> future;
  final int loginCount;
  final String greetingLine; // z.B. "Guten Morgen Max"

  const DjDashboardStatisticsSection({
    super.key,
    required this.cardBuilder,
    required this.future,
    required this.loginCount,
    required this.greetingLine,
  });

  Widget _buildPieChart({
    required StatsPieChartMetrics metrics,
    required int played,
    required int rejected,
    required int open,
    required int deleted,
  }) {
    final total = played + rejected + open + deleted;
    if (total == 0) {
      return StatsPieChartEmptyCircle(metrics: metrics);
    }

    return buildStatsPieChart(
      metrics: metrics,
      sections: [
        if (deleted > 0)
          StatsPieChartSlice(
            value: deleted.toDouble(),
            title: statsPiePercentLabel(deleted, total),
            color: Colors.black,
          ),
        if (played > 0)
          StatsPieChartSlice(
            value: played.toDouble(),
            title: statsPiePercentLabel(played, total),
            color: Colors.green,
          ),
        if (rejected > 0)
          StatsPieChartSlice(
            value: rejected.toDouble(),
            title: statsPiePercentLabel(rejected, total),
            color: Colors.red,
          ),
        if (open > 0)
          StatsPieChartSlice(
            value: open.toDouble(),
            title: statsPiePercentLabel(open, total),
            color: Colors.blue,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Schlanker DJ-Header (nur für Rolle DJ)
        Text(
          greetingLine,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l.djDashboardHeader,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Wunsch-Statistik (eigene Zelle / Card)
        cardBuilder(
          context,
          FutureBuilder<DjDashboardStatistics>(
            future: future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final played = data?.chartPlayed ?? 0;
              final rejected = data?.chartRejected ?? 0;
              final open = data?.chartOpen ?? 0;
              final deleted = data?.chartDeleted ?? 0;
              final total = data?.totalWishes ?? 0;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = StatsPieChartMetrics.resolve(
                    context,
                    maxLayoutWidth: constraints.maxWidth,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatsPieChartLegendRow(
                        metrics: metrics,
                        pie: _buildPieChart(
                          metrics: metrics,
                          played: played,
                          rejected: rejected,
                          open: open,
                          deleted: deleted,
                        ),
                        legend: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (played > 0) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${l.played}\n($played)',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (rejected > 0) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${l.rejected}\n($rejected)',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (open > 0) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${l.open}\n($open)',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (deleted > 0) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${l.deleted}\n($deleted)',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (total == 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          l.djDashboardEmptyState,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Login-Statistik (eigene Zelle / Card) – unterhalb
        cardBuilder(
          context,
          Row(
            children: [
              Icon(Icons.login, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.login_count_message(loginCount),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),

        // Safety: DJ darf nie fremde Daten sehen – Filter ist im Service (djId) gesetzt.
        if (user == null) const SizedBox.shrink(),
      ],
    );
  }
}


