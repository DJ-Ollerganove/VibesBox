import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/dj_dashboard_statistics_service.dart';

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
    required int played,
    required int rejected,
    required int open,
    required int deleted,
  }) {
    final total = played + rejected + open + deleted;
    if (total == 0) {
      // Leerzustand: identische Größe, aber komplett weiß gefüllt
      return Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    final playedPercent = (played / total * 100);
    final rejectedPercent = (rejected / total * 100);
    final openPercent = (open / total * 100);
    final deletedPercent = (deleted / total * 100);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        startDegreeOffset: 270,
        sections: [
          if (deleted > 0)
            PieChartSectionData(
              value: deleted.toDouble(),
              title: '${deletedPercent.toStringAsFixed(1)}%',
              color: Colors.black,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (played > 0)
            PieChartSectionData(
              value: played.toDouble(),
              title: '${playedPercent.toStringAsFixed(1)}%',
              color: Colors.green,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (rejected > 0)
            PieChartSectionData(
              value: rejected.toDouble(),
              title: '${rejectedPercent.toStringAsFixed(1)}%',
              color: Colors.red,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (open > 0)
            PieChartSectionData(
              value: open.toDouble(),
              title: '${openPercent.toStringAsFixed(1)}%',
              color: Colors.blue,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _buildPieChart(
                            played: played,
                            rejected: rejected,
                            open: open,
                            deleted: deleted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
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
                    ],
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


