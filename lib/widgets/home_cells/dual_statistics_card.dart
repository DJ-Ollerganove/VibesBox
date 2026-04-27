import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/formatting_utils.dart';
import '../../widgets/common/pwa_widget_cell.dart';
import 'total_statistics_card.dart';
import 'live_guest_stats_view.dart';
import '../../utils/debug_log.dart';

/// Widget für duale Statistik: Aktuelle/Letzte Party + Gesamtbilanz
class DualStatisticsCard extends StatelessWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final String effectiveDjId;
  final bool onlyFirstCard;
  final bool skipFirstCard;
  /// Von außen vorgegebene Party-ID (z. B. von home_dj berechnet). Spart _identifyParty()-Abfrage.
  final String? preferredPartyId;

  const DualStatisticsCard({
    super.key,
    required this.cardBuilder,
    required this.effectiveDjId,
    this.onlyFirstCard = false,
    this.skipFirstCard = false,
    this.preferredPartyId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // POSITION 1: Letzte Party (Zelle mit dem ersten Kreisdiagramm)
        if (!skipFirstCard)
          _CurrentPartyStatisticsCard(
            cardBuilder: cardBuilder,
            effectiveDjId: effectiveDjId,
            hideBorder: onlyFirstCard, // Rahmen verstecken wenn nur erste Karte
            preferredPartyId: preferredPartyId,
          ),
        if (!onlyFirstCard && !skipFirstCard) const SizedBox(height: 16),
        if (!onlyFirstCard) ...[
          // POSITION 2: Logins (Zelle mit Gesamtzahl & letztem Login)
          _LoginStatisticsCard(
            cardBuilder: cardBuilder,
          ),
          const SizedBox(height: 16),
          // POSITION 3: Gesamtbilanz (Zelle mit dem zweiten Kreisdiagramm)
          TotalStatisticsCard(
            cardBuilder: cardBuilder,
            effectiveDjId: effectiveDjId,
          ),
        ],
      ],
    );
  }
}

/// Cache-Eintrag für eine bereits geladene (nicht aktive) Party – vermeidet erneute Reads.
class _CachedPartyData {
  final _PartyInfo info;
  final _StatsPayload stats;
  _CachedPartyData(this.info, this.stats);
}

/// Widget für die Statistik der aktuellen/letzten Party
/// Implementiert drei Zustände: Live-Party, Letzte Party, Absolut Leer
/// Nutzt Echtzeit-Streams für Live-Partys und statische Abfragen für Archiv-Partys
class _CurrentPartyStatisticsCard extends StatelessWidget {
  static final Map<String, _CachedPartyData> _cache = {};

  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final String effectiveDjId;
  final bool hideBorder;
  /// Wenn gesetzt: _identifyParty() wird übersprungen; nur diese Party wird geladen (traffic-sparend).
  final String? preferredPartyId;

  const _CurrentPartyStatisticsCard({
    required this.cardBuilder,
    required this.effectiveDjId,
    this.hideBorder = false,
    this.preferredPartyId,
  });

  /// Lädt Party-Info nur per Doc-Get (eine Abfrage), wenn preferredPartyId von außen kommt.
  Future<_PartyInfo> _loadPartyInfoById(String partyId, BuildContext context) async {
    final unnamedParty = AppLocalizations.of(context)!.unnamed_party;
    try {
      final partyDoc = await FirebaseFirestore.instance.collection('parties').doc(partyId).get();
      if (!partyDoc.exists) {
        return const _PartyInfo(partyId: null, partyName: null, isLive: false, startDate: null, endDate: null, isEmpty: true, hasFinishedParty: false);
      }
      final data = partyDoc.data();
      final partyName = data?['party_name'] as String? ?? unnamedParty;
      final startTimestamp = data?['start_date'] as Timestamp?;
      final endTimestamp = data?['end_date'] as Timestamp?;
      final isActive = data?['isActive'] as bool? ?? false;
      final status = data?['status'] as String?;
      DateTime? startDate = startTimestamp?.toDate();
      DateTime? endDate = endTimestamp?.toDate();
      final now = DateTime.now();
      final isLive = isActive || status == 'active' || (startDate != null && endDate != null && (now.isAfter(startDate) || now.isAtSameMomentAs(startDate)) && now.isBefore(endDate));
      final hasFinished = status == 'finished' || (endDate != null && now.isAfter(endDate));
      return _PartyInfo(
        partyId: partyId,
        partyName: partyName,
        isLive: isLive,
        startDate: startDate,
        endDate: endDate,
        isEmpty: false,
        hasFinishedParty: hasFinished,
      );
    } catch (e) {
      debugLog('❌ _loadPartyInfoById Fehler: $e');
      return const _PartyInfo(partyId: null, partyName: null, isLive: false, startDate: null, endDate: null, isEmpty: true, hasFinishedParty: false);
    }
  }

  /// Identifiziert die aktuelle/letzte Party (ohne Wünsche zu laden). Wird übersprungen, wenn preferredPartyId gesetzt ist.
  Future<_PartyInfo> _identifyParty(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    
    debugLog('🔍 _identifyParty START: Suche Party für DJ $effectiveDjId');
    
    // SCHRITT 1: Hole alle Partys des DJs (Firestore-Schema: created_by)
    List<Map<String, dynamic>> myParties = [];
    try {
      final partiesSnapshot = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: effectiveDjId)
          .get();
      
      for (final partyDoc in partiesSnapshot.docs) {
        final partyData = partyDoc.data();
        myParties.add({
          'id': partyDoc.id,
          'party_name': partyData['party_name'] as String?,
          'start_date': partyData['start_date'] as Timestamp?,
          'end_date': partyData['end_date'] as Timestamp?,
          'finished_at': partyData['finished_at'] as Timestamp?,
          'isActive': partyData['isActive'] as bool?,
          'status': partyData['status'] as String?,
        });
      }
      
      debugLog('✅ Gefundene Partys für DJ $effectiveDjId: ${myParties.length} Partys');
    } catch (e) {
      debugLog('❌ Fehler beim Laden der Partys: $e');
    }

    // ZUSTAND 3: Absolut Leer (Neu-DJ)
    if (myParties.isEmpty) {
      return const _PartyInfo(
        partyId: null,
        partyName: null,
        isLive: false,
        startDate: null,
        endDate: null,
        isEmpty: true,
        hasFinishedParty: false,
      );
    }

    final now = DateTime.now();
    String? selectedPartyId;
    String? selectedPartyName;
    bool isLive = false;

    // SCHRITT 2: Sortierung nach Abschluss - Finde aktive Party oder letzte beendete
    // ZUERST: Prüfe ob eine Party aktiv ist (Status active oder start_date <= now < end_date)
    for (final party in myParties) {
      final isActiveStatus = party['isActive'] == true || party['status'] == 'active';
      final startDate = party['start_date'] as Timestamp?;
      final endDate = party['end_date'] as Timestamp?;
      
      bool isCurrentlyActive = false;
      if (isActiveStatus) {
        isCurrentlyActive = true;
      } else if (startDate != null && endDate != null) {
        final start = startDate.toDate();
        final end = endDate.toDate();
        isCurrentlyActive = now.compareTo(start) >= 0 && now.compareTo(end) < 0;
      }
      
      if (isCurrentlyActive) {
        selectedPartyId = party['id'] as String;
        selectedPartyName = party['party_name'] as String? ?? (l.unnamed_party);
        isLive = true;
        debugLog('✅ Aktive Party gefunden: $selectedPartyId ($selectedPartyName)');
        break;
      }
    }

    // Prüfe ob es beendete Partys gibt
    bool hasFinishedParty = false;
    for (final party in myParties) {
      final endDate = party['end_date'] as Timestamp?;
      final finishedAt = party['finished_at'] as Timestamp?;
      final lifecycleStatus = party['status'] as String?;
      
      if (lifecycleStatus == 'finished') {
        hasFinishedParty = true;
        break;
      } else if (endDate != null || finishedAt != null) {
        final endDateTime = endDate?.toDate() ?? finishedAt?.toDate();
        if (endDateTime != null && now.isAfter(endDateTime)) {
          hasFinishedParty = true;
          break;
        }
      }
    }

    // FALLBACK: Wenn keine aktive Party, nimm die letzte beendete = größtes Enddatum, das VOR jetzt liegt
    if (selectedPartyId == null) {
      DateTime? newestEndDateInPast;
      for (final party in myParties) {
        final endDate = party['end_date'] as Timestamp?;
        final finishedAt = party['finished_at'] as Timestamp?;
        final endDateTime = endDate?.toDate() ?? finishedAt?.toDate();
        // Nur Partys, die bereits beendet sind (end_date vor jetzt)
        if (endDateTime != null && endDateTime.isBefore(now)) {
          if (newestEndDateInPast == null || endDateTime.isAfter(newestEndDateInPast)) {
            newestEndDateInPast = endDateTime;
            selectedPartyId = party['id'] as String;
            selectedPartyName = party['party_name'] as String? ?? (l.unnamed_party);
          }
        }
      }
      if (selectedPartyId != null) {
        debugLog('✅ Letzte beendete Party gefunden: $selectedPartyId ($selectedPartyName) - Enddatum: $newestEndDateInPast');
      }
    }

    if (selectedPartyId == null) {
      // Keine aktive und keine beendete Party – zeige Leerzustand (kein Fallback auf zukünftige Party)
      return _PartyInfo(
        partyId: null,
        partyName: null,
        isLive: false,
        startDate: null,
        endDate: null,
        isEmpty: true,
        hasFinishedParty: hasFinishedParty,
      );
    }

    // Lade Party-Daten für Start- und Enddatum
    DateTime? startDate;
    DateTime? endDate;
    try {
      final partyDoc = await FirebaseFirestore.instance.collection('parties').doc(selectedPartyId).get();
      if (partyDoc.exists) {
        final partyData = partyDoc.data();
        final startTimestamp = partyData?['start_date'] as Timestamp?;
        final endTimestamp = partyData?['end_date'] as Timestamp?;
        if (startTimestamp != null) {
          startDate = startTimestamp.toDate();
        }
        if (endTimestamp != null) {
          endDate = endTimestamp.toDate();
        }
      }
    } catch (e) {
      debugLog('❌ Fehler beim Laden der Party-Daten: $e');
    }

    debugLog('✅ Party identifiziert: $selectedPartyId ($selectedPartyName) - Live: $isLive');

    return _PartyInfo(
      partyId: selectedPartyId,
      partyName: selectedPartyName ?? l.unnamed_party,
      isLive: isLive,
      startDate: startDate,
      endDate: endDate,
      isEmpty: false,
      hasFinishedParty: hasFinishedParty,
    );
  }

  /// Berechnet die Statistik aus Firestore-Dokumenten
  _StatsPayload _calculateStatsFromDocs(List<QueryDocumentSnapshot> docs, bool isLive) {
    int played = 0;
    int rejected = 0;
    int open = 0;
    int notPlayed = 0;
    int deleted = 0;
    List<int> waitTimes = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Überspringe gelöschte Wünsche
      if (data['deleted'] == true) {
        deleted++;
        continue;
      }

      final status = (data['status']?.toString()) ?? 'pending';
      
      if (status == 'played') {
        played++;
        
        // Berechne Wartezeit für gespielte Songs
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
        // Für beendete Partys: pending/open -> not_played
        // Für aktive Partys: pending/open -> open
        if (isLive) {
          open++;
        } else {
          notPlayed++;
        }
      } else {
        // Alle anderen Status zählen als "nicht gespielt" für beendete Partys
        if (isLive) {
          open++;
        } else {
          notPlayed++;
        }
      }
    }
    
    // Berechne Durchschnittswartezeit
    double? averageWaitTime;
    if (waitTimes.isNotEmpty) {
      final sum = waitTimes.fold<int>(0, (a, b) => a + b);
      averageWaitTime = sum / waitTimes.length;
    }

    return _StatsPayload(
      total: docs.length,
      played: played,
      rejected: rejected,
      open: open,
      notPlayed: notPlayed,
      deleted: deleted,
      showEmptyText: false,
      averageWaitTime: averageWaitTime,
    );
  }

  Future<_PartyInfo> _getPartyInfoFuture(BuildContext context) async {
    // Cache: Wenn preferredPartyId gesetzt und bereits geladen (nicht live), keine erneute Abfrage
    if (preferredPartyId != null && _cache[preferredPartyId!] != null && !_cache[preferredPartyId!]!.info.isLive) {
      return _cache[preferredPartyId!]!.info;
    }
    if (preferredPartyId != null) {
      return _loadPartyInfoById(preferredPartyId!, context);
    }
    return _identifyParty(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    
    // SCHRITT 1: Party-Info (bei preferredPartyId ohne Cache: ein Doc-Get; bei Cache: 0 Reads)
    return FutureBuilder<_PartyInfo>(
      future: _getPartyInfoFuture(context),
      builder: (context, partySnapshot) {
        if (!partySnapshot.hasData) {
          return cardBuilder(
            context,
            const Center(child: CircularProgressIndicator()),
          );
        }

        final partyInfo = partySnapshot.data!;

        // ZUSTAND 3: Absolut Leer (Neu-DJ)
        if (partyInfo.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '${l.no_party_data_available} ${l.start_your_first_party}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          );
        }

        // Caching: Bei nicht aktiver Party bereits geladene Daten wiederverwenden (kein erneuter Wishes-Read)
        if (!partyInfo.isLive && partyInfo.partyId != null && _cache[partyInfo.partyId!] != null) {
          return _buildStatsCard(
            context,
            partyInfo,
            _cache[partyInfo.partyId!]!.stats,
            false,
          );
        }

        // SCHRITT 2: UNTERSCHEIDUNG - Live-Stream vs. statischer Abruf
        if (partyInfo.isLive) {
          // FALL A: LIVE-STREAM (Echtzeit-Updates)
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('wishes')
                .where('party_id', isEqualTo: partyInfo.partyId!)
                .snapshots(),
            builder: (context, wishesSnapshot) {
              if (!wishesSnapshot.hasData) {
                return cardBuilder(
                  context,
                  const Center(child: CircularProgressIndicator()),
                );
              }

              final docs = wishesSnapshot.data?.docs ?? [];
              final stats = _calculateStatsFromDocs(docs, true);
              
              return _buildStatsCard(
                context,
                partyInfo,
                stats,
                true, // isLive
              );
            },
          );
        } else {
          // FALL B: ARCHIV (einmaliger Abruf; danach cachen)
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('wishes')
                .where('party_id', isEqualTo: partyInfo.partyId!)
                .get(),
            builder: (context, wishesSnapshot) {
              if (!wishesSnapshot.hasData) {
                return cardBuilder(
                  context,
                  const Center(child: CircularProgressIndicator()),
                );
              }

              final docs = wishesSnapshot.data?.docs ?? [];
              final stats = _calculateStatsFromDocs(docs, false);
              if (partyInfo.partyId != null) {
                _cache[partyInfo.partyId!] = _CachedPartyData(partyInfo, stats);
              }
              
              return _buildStatsCard(
                context,
                partyInfo,
                stats,
                false, // isLive
              );
            },
          );
        }
      },
    );
  }

  /// Baut die Statistik-Card mit Design-Vorgaben
  Widget _buildStatsCard(
    BuildContext context,
    _PartyInfo partyInfo,
    _StatsPayload stats,
    bool isLive,
  ) {
    String dateTimeRange = '--';
    if (partyInfo.startDate != null && partyInfo.endDate != null) {
      dateTimeRange = FormattingUtils.formatCompactPartyPeriod(
        partyInfo.startDate,
        partyInfo.endDate,
        context,
      );
    } else if (partyInfo.startDate != null) {
      dateTimeRange = FormattingUtils.formatCompactPartyPeriod(
        partyInfo.startDate,
        null,
        context,
      );
    }

    // Header-Text: Titel 2 - "LIVE-STATISTIK", "LETZTE PARTY" oder "NOCH KEINE PARTY DURCHGEFÜHRT"
    final l = AppLocalizations.of(context)!;
    final headerText = isLive 
        ? (l.stats_live)
        : (partyInfo.hasFinishedParty 
            ? (l.stats_last_party)
            : (l.stats_no_party_completed));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Titel 2 wird nur angezeigt, wenn hideBorder false ist (wenn die Statistik-Card ihren eigenen Rahmen hat)
        // Wenn hideBorder true ist, wird der Titel 2 bereits im Container in home_dj.dart angezeigt
        if (!hideBorder) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (isLive) ...[
                const _PulsatingLiveIndicator(),
                const SizedBox(width: 6),
              ],
              Text(
                headerText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.start,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Die Box mit grauem Hintergrund und orangenem Rahmen (wie LOGINS-Widget)
        if (!hideBorder)
          PwaWidgetCell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Partyname (GRÜN, fett, größer) - Hauptinformation
                Text(
                  partyInfo.partyName ?? l.unnamed_party,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent, // GRÜN
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 6),
                Text(
                  dateTimeRange,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  l.total_wishes_count(stats.total),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.start,
                ),
                if (stats.averageWaitTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${l.average_wait_time_label} ${stats.averageWaitTime!.toStringAsFixed(0)} ${l.interval_minutes_short}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ],
                // Kreisdiagramm direkt darunter
                const SizedBox(height: 16),
                _StatsPieChartContent(
                  stats: stats,
                ),
                // ✅ Live-Gast-Statistiken direkt unter dem PieChart (nur für Live-Partys)
                // ✅ MODULARISIERT: Komplett isoliertes Widget - verhindert Endlosschleifen!
                if (isLive && partyInfo.partyId != null) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  LiveGuestStatsView(partyId: partyInfo.partyId!),
                ],
              ],
            ),
          )
        else
          cardBuilder(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Partyname (GRÜN, fett, größer) - Hauptinformation
                Text(
                  partyInfo.partyName ?? l.unnamed_party,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent, // GRÜN
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 6),
                Text(
                  dateTimeRange,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  l.total_wishes_count(stats.total),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.start,
                ),
                if (stats.averageWaitTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${l.average_wait_time_label} ${stats.averageWaitTime!.toStringAsFixed(0)} ${l.interval_minutes_short}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ],
                // Kreisdiagramm direkt darunter
                const SizedBox(height: 16),
                _StatsPieChartContent(
                  stats: stats,
                ),
                // ✅ Live-Gast-Statistiken direkt unter dem PieChart (nur für Live-Partys)
                // ✅ MODULARISIERT: Komplett isoliertes Widget - verhindert Endlosschleifen!
                if (isLive && partyInfo.partyId != null) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  LiveGuestStatsView(partyId: partyInfo.partyId!),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Pulsierender LIVE-Indikator (GRÜN)
class _PulsatingLiveIndicator extends StatefulWidget {
  const _PulsatingLiveIndicator();

  @override
  State<_PulsatingLiveIndicator> createState() => _PulsatingLiveIndicatorState();
}

class _PulsatingLiveIndicatorState extends State<_PulsatingLiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.greenAccent, // GRÜN (konsistent zur App)
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Widget für die Pie-Chart-Darstellung
class _StatsPieChartContent extends StatelessWidget {
  final _StatsPayload stats;

  const _StatsPieChartContent({
    required this.stats,
  });

  Widget _buildPie({
    required int played,
    required int rejected,
    required int open,
    required int notPlayed,
    required int deleted,
  }) {
    final total = played + rejected + open + notPlayed + deleted;
    if (total == 0) {
      // Leerzustand: identische Größe, komplett weiß
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
    final openPercent = (open / total * 100);
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
          if (open > 0)
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
                  if (stats.open > 0) ...[
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
        if (stats.total == 0 && stats.showEmptyText) ...[
          const SizedBox(height: 12),
          Text(
            l.no_wishes_yet_hint,
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
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }
}

class _StatsPayload {
  final int total;
  final int played;
  final int rejected;
  final int open;
  final int notPlayed; // Nicht gespielt (für beendete Partys)
  final int deleted;
  final bool showEmptyText;
  final double? averageWaitTime; // Durchschnittliche Wartezeit in Minuten

  const _StatsPayload({
    required this.total,
    required this.played,
    required this.rejected,
    required this.open,
    required this.notPlayed,
    required this.deleted,
    required this.showEmptyText,
    this.averageWaitTime,
  });
}

enum _PartyState {
  live,
  last,
  empty,
}

class _PartyStatsResult {
  final _PartyState state;
  final _StatsPayload stats;
  final String? partyId;
  final String? partyName;
  final DateTime? startDate;
  final DateTime? endDate;

  const _PartyStatsResult({
    required this.state,
    required this.stats,
    required this.partyId,
    required this.partyName,
    this.startDate,
    this.endDate,
  });
}

class _PartyInfo {
  final String? partyId;
  final String? partyName;
  final bool isLive;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isEmpty;
  final bool hasFinishedParty;

  const _PartyInfo({
    required this.partyId,
    required this.partyName,
    required this.isLive,
    this.startDate,
    this.endDate,
    required this.isEmpty,
    this.hasFinishedParty = false,
  });
}

/// Widget für Login-Statistik
class _LoginStatisticsCard extends StatelessWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const _LoginStatisticsCard({
    required this.cardBuilder,
  });

  Future<Map<String, dynamic>> _loadLoginData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'loginCount': 0, 'lastLogin': null};
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return {'loginCount': 0, 'lastLogin': null};
      }

      final userData = userDoc.data();
      final loginCountValue = userData?['loginCount'];
      int loginCount = 0;
      if (loginCountValue is int) {
        loginCount = loginCountValue;
      } else if (loginCountValue is num) {
        loginCount = loginCountValue.toInt();
      }
      
      final lastLoginTimestamp = userData?['lastLogin'] as Timestamp?;
      final lastLogin = lastLoginTimestamp?.toDate();

      return {
        'loginCount': loginCount,
        'lastLogin': lastLogin,
      };
    } catch (e) {
      debugLog('❌ Fehler beim Laden der Login-Daten: $e');
      return {'loginCount': 0, 'lastLogin': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadLoginData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return cardBuilder(
            context,
            const Center(child: CircularProgressIndicator()),
          );
        }

        final loginCount = snapshot.data!['loginCount'] as int;
        final lastLogin = snapshot.data!['lastLogin'] as DateTime?;

        String lastLoginText = '--';
        if (lastLogin != null) {
          lastLoginText =
              FormattingUtils.formatDateTimeCommaBetweenDateAndTime(lastLogin, context);
        }

        // Login-Zelle mit orangem Rahmen (konsistent zu anderen Karten)
        return PwaWidgetCell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Icon + Titel (dezent, kleiner)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.login,
                    color: Theme.of(context).primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.logins_title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l.total_logins_count(loginCount),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 6),
              Text(
                '${l.last_login_on} $lastLoginText',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.start,
              ),
            ],
          ),
        );
      },
    );
  }
}
