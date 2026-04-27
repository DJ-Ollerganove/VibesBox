import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_constants.dart';
import 'styled_home_card.dart';

/// Widget für die Gesamtbilanz-Statistik (nur beendete Partys)
/// PERFORMANCE: Cached historische Daten
class TotalStatisticsCard extends StatefulWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final String effectiveDjId;

  const TotalStatisticsCard({
    super.key,
    required this.cardBuilder,
    required this.effectiveDjId,
  });

  @override
  State<TotalStatisticsCard> createState() => _TotalStatisticsCardState();
}

class _TotalStatisticsCardState extends State<TotalStatisticsCard> {
  // PERFORMANCE: Statisches Caching der historischen Daten
  _HistoricalStats? _cachedHistoricalStats;
  bool _isLoadingHistorical = true;
  String? _cachedActivePartyId;
  int? _cachedPartyCount; // ✅ Party-Count wird einmalig geladen

  @override
  void initState() {
    super.initState();
    _loadHistoricalStatsOnce();
    _loadPartyCountOnce(); // ✅ Party-Count einmalig laden
  }
  
  /// ✅ Lädt Party-Count einmalig in initState
  Future<void> _loadPartyCountOnce() async {
    if (_cachedPartyCount != null) {
      return;
    }
    
    try {
      final partyCount = await _countDjParties();
      if (mounted) {
        setState(() {
          _cachedPartyCount = partyCount;
        });
      }
    } catch (e) {
      // Fehler ignorieren
      if (mounted) {
        setState(() {
          _cachedPartyCount = 0;
        });
      }
    }
  }

  /// PERFORMANCE: Lädt historische Daten einmalig und cached sie
  Future<void> _loadHistoricalStatsOnce() async {
    if (_cachedHistoricalStats != null) {
      return;
    }

    setState(() {
      _isLoadingHistorical = true;
    });

    try {
      final activeParty = await _identifyActiveParty();
      final activePartyId = activeParty?.partyId;
      final historicalStats = await _loadHistoricalStats(activePartyId);

      if (mounted) {
        setState(() {
          _cachedHistoricalStats = historicalStats;
          _cachedActivePartyId = activePartyId;
          _isLoadingHistorical = false;
        });
      }
    } catch (e) {
      // ✅ Logging entfernt zur Kontrolle
      if (mounted) {
        setState(() {
          _isLoadingHistorical = false;
        });
      }
    }
  }

  /// PERFORMANCE: Prüft, ob historische Daten neu geladen werden müssen
  /// ❌ DEAKTIVIERT: Diese Funktion wird NICHT mehr automatisch aufgerufen!
  /// History wird NUR einmalig in initState() geladen
  // Future<void> _refreshHistoricalIfNeeded() async {
  //   // DEAKTIVIERT um Endlosschleife zu verhindern
  // }

  /// Identifiziert die aktive Party (falls vorhanden) - SICHERHEIT: Nur für diesen DJ
  Future<_ActivePartyInfo?> _identifyActiveParty() async {
    final now = DateTime.now();
    
    try {
      final partiesSnapshot = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: widget.effectiveDjId)
          .get();

      for (final partyDoc in partiesSnapshot.docs) {
        final partyData = partyDoc.data();
        final partyCreatedBy = partyData['created_by'] as String?;
        if (partyCreatedBy != widget.effectiveDjId) {
          continue;
        }
        
        final isActiveStatus = partyData['isActive'] == true || partyData['status'] == 'active';
        final startTimestamp = partyData['start_date'] as Timestamp?;
        final endTimestamp = partyData['end_date'] as Timestamp?;
        
        bool isCurrentlyActive = false;
        if (isActiveStatus) {
          isCurrentlyActive = true;
        } else if (startTimestamp != null && endTimestamp != null) {
          final start = startTimestamp.toDate();
          final end = endTimestamp.toDate();
          isCurrentlyActive = now.compareTo(start) >= 0 && now.compareTo(end) < 0;
        }
        
        if (isCurrentlyActive) {
          return _ActivePartyInfo(
            partyId: partyDoc.id,
            startDate: startTimestamp?.toDate(),
            endDate: endTimestamp?.toDate(),
          );
        }
      }
    } catch (e) {
      // ✅ Logging entfernt zur Kontrolle
    }
    
    return null;
  }

  /// Lädt historische Daten (beendete Partys) - SICHERHEIT: Nur für diesen DJ
  /// NEU: Nutzt statistics-Map aus Party-Dokumenten (nach Migration Stufe 2)
  Future<_HistoricalStats> _loadHistoricalStats(String? excludePartyId) async {
    try {
      // SICHERHEIT: Lade nur Partys dieses DJs (created_by) mit lifecycle_status == 'finished'
      final partiesSnapshot = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: widget.effectiveDjId)
          .where('lifecycle_status', isEqualTo: 'finished')
          .get();

      // SICHERHEIT: Zusätzliche Filterung auf Client-Seite
      final validParties = <QueryDocumentSnapshot>[];
      for (final partyDoc in partiesSnapshot.docs) {
        final partyId = partyDoc.id;
        
        // DUBLETTEN-CHECK: Aktive Party ausschließen
        if (excludePartyId != null && partyId == excludePartyId) {
          continue;
        }
        
        final partyData = partyDoc.data() as Map<String, dynamic>;
        final partyCreatedBy = partyData['created_by'] as String?;
        
        // SICHERHEIT: Verifiziere, dass die Party wirklich diesem DJ gehört
        if (partyCreatedBy != widget.effectiveDjId) {
          continue; // Überspringe Partys, die nicht diesem DJ gehören
        }
        
        validParties.add(partyDoc);
      }
      
      // ✅ Logging entfernt zur Kontrolle

      // Summiere Statistiken aus statistics-Map
      int totalRequests = 0;
      int played = 0;
      int rejected = 0;
      int notPlayed = 0;
      int deleted = 0;
      double totalWaitMinutes = 0.0;
      int totalPlayedCount = 0;
      List<int> globalHourlyDistribution = List.filled(24, 0); // 0-23 Uhr

      for (final partyDoc in validParties) {
        final partyData = partyDoc.data() as Map<String, dynamic>;
        final statistics = partyData['statistics'] as Map<String, dynamic>?;
        
        if (statistics != null) {
          // Summiere Werte aus statistics-Map
          totalRequests += (statistics['total_requests'] as int? ?? 0);
          played += (statistics['played'] as int? ?? 0);
          rejected += (statistics['rejected'] as int? ?? 0);
          notPlayed += (statistics['not_played'] as int? ?? 0);
          
          // Wartezeit: Berechne gewichteten Durchschnitt
          final avgWaitMinutes = statistics['avg_wait_minutes'] as double?;
          final partyPlayed = statistics['played'] as int? ?? 0;
          if (avgWaitMinutes != null && partyPlayed > 0) {
            // Für gewichteten Durchschnitt: Summe der Minuten
            totalWaitMinutes += avgWaitMinutes * partyPlayed;
            totalPlayedCount += partyPlayed;
          }
          
          // Stunden-Verteilung: Addiere Arrays
          final hourlyDist = statistics['hourly_distribution'] as List<dynamic>?;
          if (hourlyDist != null && hourlyDist.length == 24) {
            for (int hour = 0; hour < 24; hour++) {
              globalHourlyDistribution[hour] += (hourlyDist[hour] as int? ?? 0);
            }
          }
        }
      }

      // Berechne Durchschnittswartezeit
      double? averageWaitTime;
      if (totalPlayedCount > 0) {
        averageWaitTime = totalWaitMinutes / totalPlayedCount;
      }

      // ✅ Logging entfernt zur Kontrolle

      return _HistoricalStats(
        total: totalRequests,
        played: played,
        rejected: rejected,
        open: 0, // Finished Partys haben keine offenen Wünsche
        notPlayed: notPlayed,
        deleted: deleted,
        averageWaitTime: averageWaitTime,
      );
    } catch (e) {
      // ✅ Logging entfernt zur Kontrolle
      return _HistoricalStats(
        total: 0,
        played: 0,
        rejected: 0,
        open: 0,
        notPlayed: 0,
        deleted: 0,
        averageWaitTime: null,
      );
    }
  }

  /// Berechnet Statistik aus Firestore-Dokumenten
  _HistoricalStats _calculateStatsFromDocs(List<QueryDocumentSnapshot> docs, {required bool isLive}) {
    int played = 0;
    int rejected = 0;
    int open = 0;
    int notPlayed = 0;
    int deleted = 0;
    List<int> waitTimes = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      if (data['deleted'] == true) {
        deleted++;
        continue;
      }

      final status = (data['status']?.toString()) ?? 'pending';
      
      if (status == 'played') {
        played++;
        
        final createdAt = data['createdAt'] as Timestamp?;
        final playedAt = data['played_at'] as Timestamp?;
        if (createdAt != null && playedAt != null) {
          final createdDate = createdAt.toDate();
          final playedDate = playedAt.toDate();
          final difference = playedDate.difference(createdDate);
          final minutes = difference.inMinutes;
          if (minutes >= 0) {
            waitTimes.add(minutes);
          }
        }
      } else if (status == 'rejected') {
        rejected++;
      } else if (status == 'not_played') {
        notPlayed++;
      } else if (status == 'pending' || status == 'open' || status.isEmpty) {
        if (isLive) {
          open++;
        } else {
          notPlayed++;
        }
      } else {
        notPlayed++;
      }
    }
    
    double? averageWaitTime;
    if (waitTimes.isNotEmpty) {
      final sum = waitTimes.fold<int>(0, (a, b) => a + b);
      averageWaitTime = sum / waitTimes.length;
    }

    return _HistoricalStats(
      total: docs.length,
      played: played,
      rejected: rejected,
      open: open,
      notPlayed: notPlayed,
      deleted: deleted,
      averageWaitTime: averageWaitTime,
    );
  }

  /// Zählt die Anzahl der beendeten Partys dieses DJs
  /// NEU: Nutzt lifecycle_status == 'finished'
  Future<int> _countDjParties() async {
    try {
      // SICHERHEIT: Lade nur Partys dieses DJs (created_by) mit lifecycle_status == 'finished'
      final partiesSnapshot = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: widget.effectiveDjId)
          .where('lifecycle_status', isEqualTo: 'finished')
          .get();

      // SICHERHEIT: Zusätzliche Filterung auf Client-Seite
      int validCount = 0;
      for (final partyDoc in partiesSnapshot.docs) {
        final partyData = partyDoc.data() as Map<String, dynamic>;
        final partyCreatedBy = partyData['created_by'] as String?;
        
        // SICHERHEIT: Verifiziere, dass die Party wirklich diesem DJ gehört
        if (partyCreatedBy == widget.effectiveDjId) {
          validCount++;
        }
      }
      
      return validCount;
    } catch (e) {
      // ✅ Logging entfernt zur Kontrolle
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ History wird NUR in initState() geladen - KEINE automatischen Reloads!
    
    if (_isLoadingHistorical || _cachedHistoricalStats == null || _cachedPartyCount == null) {
      return _buildLoadingState(context);
    }

    final historicalStats = _cachedHistoricalStats!;
    final partyCount = _cachedPartyCount!;

    // ✅ StreamBuilder für aktive Party - NUR für UI-Anzeige, KEINE History-Abfragen!
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: widget.effectiveDjId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // ✅ NUR lokale Variablen - KEINE setState() oder History-Aufrufe hier!
        final hasActiveParty = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final activePartyId = hasActiveParty ? snapshot.data!.docs.first.id : null;

        return _buildStatsDisplay(
          context,
          stats: _convertHistoricalToPayload(historicalStats, partyCount),
          hasActiveParty: hasActiveParty,
          activePartyId: activePartyId,
        );
      },
    );
  }

  /// Konvertiert historische Statistiken in das Payload-Format
  _TotalStatsPayload _convertHistoricalToPayload(
    _HistoricalStats historical,
    int totalPartyCount,
  ) {
    return _TotalStatsPayload(
      total: historical.total,
      played: historical.played,
      rejected: historical.rejected,
      open: historical.open,
      notPlayed: historical.notPlayed,
      deleted: historical.deleted,
      partyCount: totalPartyCount,
      averageWaitTime: historical.averageWaitTime,
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: widget.effectiveDjId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final hasActiveParty = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'GESAMTBILANZ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasActiveParty)
                    const TextSpan(
                      text: ' (ohne die aktuell laufende Party)',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white70,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const StyledHomeCard(
              borderColor: UIConstants.appOrange,
              child: Center(
                child: CircularProgressIndicator(
                  color: UIConstants.appOrange,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsDisplay(BuildContext context, {required _TotalStatsPayload stats, required bool hasActiveParty, String? activePartyId}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'GESAMTBILANZ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasActiveParty)
                const TextSpan(
                  text: ' (ohne die aktuell laufende Party)',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white70,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        StyledHomeCard(
          borderColor: UIConstants.appOrange,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gesamtzahl:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${stats.total}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: UIConstants.appOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gespielt:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${stats.played}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: UIConstants.appOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Anzahl Partys:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${stats.partyCount}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: UIConstants.appOrange,
                        ),
                      ),
                    ],
                  ),
                  if (stats.averageWaitTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ø Wartezeit:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${stats.averageWaitTime!.toStringAsFixed(0)} Min.',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: UIConstants.appOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _TotalStatsPieChartContent(
                    stats: stats,
                    hasActiveParty: hasActiveParty,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Info über aktive Party
class _ActivePartyInfo {
  final String partyId;
  final DateTime? startDate;
  final DateTime? endDate;

  _ActivePartyInfo({
    required this.partyId,
    this.startDate,
    this.endDate,
  });
}

/// Historische Statistik (beendete Partys)
class _HistoricalStats {
  final int total;
  final int played;
  final int rejected;
  final int open;
  final int notPlayed;
  final int deleted;
  final double? averageWaitTime;

  _HistoricalStats({
    required this.total,
    required this.played,
    required this.rejected,
    required this.open,
    required this.notPlayed,
    required this.deleted,
    this.averageWaitTime,
  });
}

/// Kombinierte Gesamtstatistik
class _TotalStatsPayload {
  final int total;
  final int played;
  final int rejected;
  final int open;
  final int notPlayed;
  final int deleted;
  final int partyCount;
  final double? averageWaitTime;

  _TotalStatsPayload({
    required this.total,
    required this.played,
    required this.rejected,
    required this.open,
    required this.notPlayed,
    required this.deleted,
    required this.partyCount,
    this.averageWaitTime,
  });
}

/// Widget für die Pie-Chart-Darstellung
class _TotalStatsPieChartContent extends StatelessWidget {
  final _TotalStatsPayload stats;
  final bool hasActiveParty;

  const _TotalStatsPieChartContent({
    required this.stats,
    required this.hasActiveParty,
  });

  Widget _buildPie({
    required int played,
    required int rejected,
    required int open,
    required int notPlayed,
    required int deleted,
    required bool showBlue,
  }) {
    final total = played + rejected + open + notPlayed + deleted;
    if (total == 0) {
      return Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      );
    }

    final playedPercent = (played / total * 100);
    final rejectedPercent = (rejected / total * 100);
    final openPercent = showBlue && open > 0 ? (open / total * 100) : 0.0;
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
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
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
              color: Colors.red,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          if (showBlue && open > 0)
            PieChartSectionData(
              value: open.toDouble(),
              title: '${openPercent.toStringAsFixed(1)}%',
              color: Colors.blue,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          if (notPlayed > 0)
            PieChartSectionData(
              value: notPlayed.toDouble(),
              title: '${notPlayedPercent.toStringAsFixed(1)}%',
              color: Colors.orange,
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
                  played: stats.played,
                  rejected: stats.rejected,
                  open: stats.open,
                  notPlayed: stats.notPlayed,
                  deleted: stats.deleted,
                  showBlue: hasActiveParty,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats.played > 0) ...[
                    _LegendRow(color: Colors.green, text: '${l.played_songs_label}\n(${stats.played})'),
                    const SizedBox(height: 12),
                  ],
                  if (stats.rejected > 0) ...[
                    _LegendRow(color: Colors.red, text: '${l.rejected_songs_label}\n(${stats.rejected})'),
                    const SizedBox(height: 12),
                  ],
                  if (hasActiveParty && stats.open > 0) ...[
                    _LegendRow(color: Colors.blue, text: '${l.open_songs_label}\n(${stats.open})'),
                    const SizedBox(height: 12),
                  ],
                  if (stats.notPlayed > 0) ...[
                    _LegendRow(color: Colors.orange, text: '${l.not_played_songs_label}\n(${stats.notPlayed})'),
                    const SizedBox(height: 12),
                  ],
                  if (stats.deleted > 0) ...[
                    _LegendRow(color: Colors.black, text: '${l.deleted_songs_label}\n(${stats.deleted})'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Widget für eine Legende-Zeile
class _LegendRow extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendRow({
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
