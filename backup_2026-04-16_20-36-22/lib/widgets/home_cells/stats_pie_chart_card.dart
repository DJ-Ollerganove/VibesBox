import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/dj_dashboard_statistics_service.dart';
import '../../services/statistics_service.dart';
import '../../services/party_statistics_service.dart';
import '../../utils/ui_constants.dart';

class StatsPieChartCard extends StatelessWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  /// Wenn gesetzt: DJ-Filter (wishes.djId == djId)
  final String? djId;

  /// Wenn gesetzt: Party-Filter (wishes.party_id == partyId)
  final String? partyId;

  /// Admin-View: keine Filterung (alle Wünsche)
  final bool isAdmin;

  /// Wenn true: Verwende Stream (für aktive Party), sonst Future (für beendete Party oder Gesamt-Statistik)
  final bool? useStreamForParty;

  /// Bei Fehler (z. B. PERMISSION_DENIED): wird aufgerufen, um den Stream neu zu starten (Parent setzt Key hoch).
  final VoidCallback? onRetry;

  /// Für Fehler-UI: angezeigte Rolle (z. B. "admin"), damit bei permission-denied sichtbar ist, was der Client sendet.
  final String? currentUserRoleForError;

  const StatsPieChartCard({
    super.key,
    required this.cardBuilder,
    required this.isAdmin,
    this.djId,
    this.partyId,
    this.useStreamForParty,
    this.onRetry,
    this.currentUserRoleForError,
  });

  Future<_StatsPayload> _load() async {
    // Party-Filter hat Priorität
    if (partyId != null && partyId!.isNotEmpty) {
      final partyStats = await PartyStatisticsService.loadForParty(
        partyId: partyId!,
        djId: djId,
      );
      return _StatsPayload(
        total: partyStats.totalWishes,
        played: partyStats.chartPlayed,
        rejected: partyStats.chartRejected,
        pending: partyStats.chartOpen,
        notPlayed: 0,
        unknown: partyStats.chartDeleted,
        showEmptyText: true,
      );
    }

    // Gesamt-Statistik: NUR nach djId filtern (keine partyId)
    if (djId != null && djId!.isNotEmpty) {
      final dj = await DjDashboardStatisticsService.loadForDj(djId: djId!);
      return _StatsPayload(
        total: dj.totalWishes,
        played: dj.chartPlayed,
        rejected: dj.chartRejected,
        pending: dj.chartOpen,
        notPlayed: 0,
        unknown: dj.chartDeleted,
        showEmptyText: true,
      );
    }

    final admin = await StatisticsService.loadAdminStatistics();
    return _StatsPayload(
      total: admin.totalWishes,
      played: admin.chartPlayed,
      rejected: admin.chartRejected,
      pending: admin.chartPending,
      notPlayed: admin.chartNotPlayed,
      unknown: admin.chartUnknown,
      showEmptyText: false,
    );
  }

  /// Stream für Admin-Statistiken (Echtzeit-Updates)
  Stream<_StatsPayload> _loadStream() {
    // Party-Filter hat Priorität (für aktive Party)
    if (partyId != null && partyId!.isNotEmpty) {
      return PartyStatisticsService.loadForPartyStream(
        partyId: partyId!,
        djId: djId,
      ).map((partyStats) {
        return _StatsPayload(
          total: partyStats.totalWishes,
          played: partyStats.chartPlayed,
          rejected: partyStats.chartRejected,
          pending: partyStats.chartOpen,
          notPlayed: 0,
          unknown: partyStats.chartDeleted,
          showEmptyText: true,
        );
      });
    }

    if (djId != null && djId!.isNotEmpty) {
      // DJ-Statistiken: Sollten nicht per Stream geladen werden (nur Future)
      // Dieser Fall sollte nicht erreicht werden, da useStream nur für aktive Party true ist
      return Stream.value(const _StatsPayload(
        total: 0,
        played: 0,
        rejected: 0,
        pending: 0,
        notPlayed: 0,
        unknown: 0,
        showEmptyText: true,
      ));
    }

    // Admin-Statistiken: Stream für Echtzeit-Updates (ohne djId/userId-Filter)
    return StatisticsService.loadAdminStatisticsStream().map((admin) {
      return _StatsPayload(
        total: admin.totalWishes,
        played: admin.chartPlayed,
        rejected: admin.chartRejected,
        pending: admin.chartPending,
        notPlayed: admin.chartNotPlayed,
        unknown: admin.chartUnknown,
        showEmptyText: false,
      );
    });
  }

  Widget _buildPie({
    required int played,
    required int rejected,
    required int pending,
    required int notPlayed,
    required int unknown,
    required bool isAdmin,
  }) {
    final total = played + rejected + pending + notPlayed + unknown;
    if (total == 0) {
      // Leerzustand: Hinweistext statt weißem Kreis (Admin: globale Daten, sonst: warte auf Daten)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isAdmin ? 'Keine globalen Daten vorhanden.' : 'Warte auf Daten...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final playedPercent = (played / total * 100);
    final rejectedPercent = (rejected / total * 100);
    final pendingPercent = (pending / total * 100);
    final notPlayedPercent = (notPlayed / total * 100);
    final unknownPercent = (unknown / total * 100);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        startDegreeOffset: 270,
        sections: [
          if (played > 0)
            PieChartSectionData(
              value: played.toDouble(),
              title: '${playedPercent.toStringAsFixed(1)}%',
              color: Colors.green,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          if (rejected > 0)
            PieChartSectionData(
              value: rejected.toDouble(),
              title: '${rejectedPercent.toStringAsFixed(1)}%',
              color: UIConstants.frameAbgelehnt,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          if (notPlayed > 0)
            PieChartSectionData(
              value: notPlayed.toDouble(),
              title: '${notPlayedPercent.toStringAsFixed(1)}%',
              color: Colors.blue,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          if (pending > 0)
            PieChartSectionData(
              value: pending.toDouble(),
              title: '${pendingPercent.toStringAsFixed(1)}%',
              color: Colors.orange,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          if (unknown > 0)
            PieChartSectionData(
              value: unknown.toDouble(),
              title: '${unknownPercent.toStringAsFixed(1)}%',
              color: Colors.grey,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    // Admin-View (global): Einmaliger get()-Call, um unnötige Dauerstreams zu vermeiden.
    // Party-View: Verwende Stream nur wenn useStreamForParty == true (aktive Party), sonst Future (beendete Party)
    // Gesamt-Statistik: Verwende Future (einmaliges Laden nach djId)
    final useStream = (partyId != null && partyId!.isNotEmpty && useStreamForParty == true);

    return cardBuilder(
      context,
      useStream
          ? StreamBuilder<_StatsPayload>(
              stream: _loadStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorRetry(context, snapshot.error, onRetry, currentUserRoleForError);
                }
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data ??
                    const _StatsPayload(
                      total: 0,
                      played: 0,
                      rejected: 0,
                      pending: 0,
                      notPlayed: 0,
                      unknown: 0,
                      showEmptyText: false,
                    );
                return _buildContent(context, l, data, isAdmin);
              },
            )
          : FutureBuilder<_StatsPayload>(
              future: _load(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorRetry(context, snapshot.error, onRetry, currentUserRoleForError);
                }
                final data = snapshot.data ??
                    const _StatsPayload(
                      total: 0,
                      played: 0,
                      rejected: 0,
                      pending: 0,
                      notPlayed: 0,
                      unknown: 0,
                      showEmptyText: true,
                    );
                return _buildContent(context, l, data, isAdmin);
              },
            ),
    );
  }

  static Widget _buildErrorRetry(BuildContext context, Object? error, VoidCallback? onRetry, String? currentUserRoleForError) {
    final raw = error?.toString() ?? 'Unbekannter Fehler';
    final isPermissionDenied = raw.contains('PERMISSION_DENIED') || raw.toLowerCase().contains('permission');
    final msg = isPermissionDenied
        ? 'Datenbank-Zugriff verweigert (Rolle: ${currentUserRoleForError ?? 'unbekannt'})'
        : (raw.length > 80 ? '${raw.substring(0, 80)}…' : raw);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange.shade300),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l, _StatsPayload data, bool isAdminValue) {
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
                child: _buildPie(
                  played: data.played,
                  rejected: data.rejected,
                  pending: data.pending,
                  notPlayed: data.notPlayed,
                  unknown: data.unknown,
                  isAdmin: isAdminValue,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.played > 0) ...[
                    _LegendRow(color: Colors.green, text: '${l.played}\n(${data.played})'),
                    const SizedBox(height: 12),
                  ],
                  if (data.rejected > 0) ...[
                    _LegendRow(color: UIConstants.frameAbgelehnt, text: '${l.rejected}\n(${data.rejected})'),
                    const SizedBox(height: 12),
                  ],
                  if (data.notPlayed > 0) ...[
                    _LegendRow(color: Colors.blue, text: '${l.not_played_songs}\n(${data.notPlayed})'),
                    const SizedBox(height: 12),
                  ],
                  if (data.pending > 0) ...[
                    _LegendRow(color: Colors.orange, text: '${l.open}\n(${data.pending})'),
                    const SizedBox(height: 12),
                  ],
                  if (data.unknown > 0) ...[
                    _LegendRow(color: Colors.grey, text: 'Unbekannt\n(${data.unknown})'),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (data.total == 0 && data.showEmptyText) ...[
          const SizedBox(height: 12),
          Text(
            l.djDashboardEmptyState,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendRow({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}

class _StatsPayload {
  final int total;
  final int played;
  final int rejected;
  final int pending;
  final int notPlayed;
  final int unknown;
  final bool showEmptyText;

  const _StatsPayload({
    required this.total,
    required this.played,
    required this.rejected,
    required this.pending,
    required this.notPlayed,
    required this.unknown,
    required this.showEmptyText,
  });
}


