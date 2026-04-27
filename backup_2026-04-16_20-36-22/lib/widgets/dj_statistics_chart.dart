import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/app_localizations.dart';

/// Widget für das DJ-Statistik-Diagramm
class DJStatisticsChart extends StatelessWidget {
  final int played;
  final int rejected;
  final int notPlayed;
  final int deleted;

  const DJStatisticsChart({
    super.key,
    required this.played,
    required this.rejected,
    required this.notPlayed,
    required this.deleted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = played + rejected + notPlayed + deleted;
    if (total == 0) {
      return Center(
        child: Text(l10n.no_data_available),
      );
    }

    final playedPercent = (played / total * 100);
    final rejectedPercent = (rejected / total * 100);
    final notPlayedPercent = (notPlayed / total * 100);
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
          if (notPlayed > 0)
            PieChartSectionData(
              value: notPlayed.toDouble(),
              title: '${notPlayedPercent.toStringAsFixed(1)}%',
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
}

/// Widget für die Legende des DJ-Statistik-Diagramms
class DJStatisticsChartLegend extends StatelessWidget {
  final int played;
  final int rejected;
  final int notPlayed;
  final int deleted;

  const DJStatisticsChartLegend({
    super.key,
    required this.played,
    required this.rejected,
    required this.notPlayed,
    required this.deleted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (played > 0) ...[
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.played}\n($played)',
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
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.rejected}\n($rejected)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (notPlayed > 0) ...[
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.not_played_songs}\n($notPlayed)',
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
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.deleted}\n($deleted)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

