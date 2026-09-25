import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/app_localizations.dart';
import '../utils/formatting_utils.dart';
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';
import '../app_scaffold_messenger.dart';
import '../services/app_diagnostic_log_service.dart';

// Seite für Party-Statistik
class PartyStatistikPage extends StatefulWidget {
  final String partyId;
  final String partyName;
  final DateTime startDate;
  final DateTime endDate;
  final String partyCode;
  /// Optional: bereits geladenes Party-Dokument (z. B. aus Cache), spart erneuten Firestore-Read.
  final Map<String, dynamic>? preloadedPartyData;
  /// Modal über der aktuellen Seite (kein Vollbild-Scaffold).
  final bool embeddedInModal;
  /// Messenger des Statistik-Dialogs — SnackBars über Modal statt hinter der App.
  final GlobalKey<ScaffoldMessengerState>? modalScaffoldMessengerKey;

  const PartyStatistikPage({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.startDate,
    required this.endDate,
    required this.partyCode,
    this.preloadedPartyData,
    this.embeddedInModal = false,
    this.modalScaffoldMessengerKey,
  });

  /// Party-Statistik als Overlay: App im Hintergrund unscharf, oranger Rahmen.
  static Future<void> show(
    BuildContext context, {
    required String partyId,
    required String partyName,
    required DateTime startDate,
    required DateTime endDate,
    required String partyCode,
    Map<String, dynamic>? preloadedPartyData,
  }) {
    final size = MediaQuery.sizeOf(context);
    final maxH = size.height * 0.88;
    final maxW = (size.width - 32).clamp(0.0, 560.0);
    final modalMessengerKey = GlobalKey<ScaffoldMessengerState>();

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: AppLocalizations.of(context)!.party_statistics_title,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, _, __) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: Material(
            type: MaterialType.transparency,
            child: ScaffoldMessenger(
              key: modalMessengerKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Container(
                        width: maxW,
                        height: maxH,
                        decoration: UIConstants.guestBoxDecoration.copyWith(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PartyStatistikPage(
                          partyId: partyId,
                          partyName: partyName,
                          startDate: startDate,
                          endDate: endDate,
                          partyCode: partyCode,
                          preloadedPartyData: preloadedPartyData,
                          embeddedInModal: true,
                          modalScaffoldMessengerKey: modalMessengerKey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<PartyStatistikPage> createState() => _PartyStatistikPageState();
}

class _PartyStatistikPageState extends State<PartyStatistikPage> {
  int _totalWishes = 0;
  int _playedWishes = 0;
  int _rejectedWishes = 0;
  int _notPlayedWishes = 0;
  Map<int, int> _wishesPerHour = {}; // Stunde -> Anzahl Wünsche
  double _averagePlayTimeMinutes = 0.0; // Durchschnittliche Zeit bis zum Spielen in Minuten
  List<Map<String, dynamic>> _playedWishesList = []; // Liste der gespielten Wünsche (sortiert nach playedAt)
  bool _isLoading = true;
  int _firstFullHour = 0; // Erste volle Stunde der Party
  int _lastFullHour = 23; // Letzte volle Stunde der Party
  List<int> _hoursInRange = []; // Liste aller Stunden im Party-Zeitraum
  String? _djName; // DJ-Name der Party

  void _showPageSnackBar(SnackBar snackBar) {
    final modalMessenger = widget.modalScaffoldMessengerKey?.currentState;
    if (widget.embeddedInModal && modalMessenger != null) {
      AppDiagnosticLogService.instance.recordSnackBar(snackBar);
      modalMessenger.showSnackBar(snackBar);
      return;
    }
    showVibesSnackBar(context, snackBar);
  }

  @override
  void initState() {
    super.initState();
    _loadDjName();
    _closePendingWishesAndLoadStatistics();
  }
  
  // Lädt den DJ-Namen für diese Party (nutzt preloadedPartyData wenn vorhanden, sonst Firestore)
  Future<void> _loadDjName() async {
    try {
      String? djCode;

      if (widget.preloadedPartyData != null) {
        djCode = widget.preloadedPartyData!['created_by'] as String?;
      }
      if (djCode == null || djCode.isEmpty) {
        final partyDoc = await FirebaseFirestore.instance
            .collection('parties')
            .doc(widget.partyId)
            .get();
        if (partyDoc.exists) {
          final partyData = partyDoc.data() as Map<String, dynamic>?;
          if (partyData != null) {
            djCode = partyData['created_by'] as String?;
          }
        }
      }
      if ((djCode == null || djCode.isEmpty) && widget.partyCode.isNotEmpty) {
        final partyStatusQuery = await FirebaseFirestore.instance
            .collection('party_status')
            .where('party_code', isEqualTo: widget.partyCode)
            .limit(1)
            .get();
        if (partyStatusQuery.docs.isNotEmpty) {
          final partyStatusData = partyStatusQuery.docs.first.data();
          final createdBy = partyStatusData['created_by'] as String?;
          if (createdBy != null && createdBy.isNotEmpty) {
            djCode = createdBy;
          }
        }
      }

      // Wenn DJ-Code gefunden wurde, lade den DJ-Namen
      if (djCode != null && djCode.isNotEmpty) {
        // Lade DJ-Namen aus users Collection
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(djCode)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>?;
            if (userData != null) {
              // Versuche displayName, dann email, dann name
              final displayName = userData['displayName'] as String?;
              final email = userData['email'] as String?;
              final name = userData['name'] as String?;
              
              final djName = displayName ?? name ?? email ?? djCode;
              
              setState(() {
                _djName = djName;
              });
              return;
            }
          }
        } catch (e) {
          debugLog('Fehler beim Laden des DJ-Namens: $e');
        }
      }
      
      // Wenn kein DJ-Code oder Name gefunden wurde, setze auf null
      setState(() {
        _djName = null;
      });
    } catch (e) {
      debugLog('Fehler beim Laden des DJ-Codes: $e');
      setState(() {
        _djName = null;
      });
    }
  }

  // Schließt pending-Wünsche für diese Party und lädt dann die Statistik
  Future<void> _closePendingWishesAndLoadStatistics() async {
    debugLog('🔍 Starte _closePendingWishesAndLoadStatistics für Party-ID: ${widget.partyId}');
    debugLog('📅 Party: ${widget.partyName}, Start: ${widget.startDate}, Ende: ${widget.endDate}, Party-Code: ${widget.partyCode}');
    
    try {
      // OPTIMIERT: Prüfe nur Wünsche im Zeitraum der Party (createdAt zwischen startDate und endDate)
      // Query nach party_id und status, dann clientseitig nach Zeitraum filtern
      var pendingWishesQuery = WishPaths.partyWishes(widget.partyId)
          .where('status', isEqualTo: 'pending');
      
      // Optional: Filter nach createdAt >= startDate (wenn Composite Index vorhanden)
      // Sonst clientseitig filtern
      var pendingWishesSnapshot = await pendingWishesQuery.get();
      
      // Clientseitig filtern: Nur Wünsche im Zeitraum der Party
      final partyStartDate = widget.startDate;
      final partyEndDate = widget.endDate;
      
      final relevantWishes = pendingWishesSnapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        
        final createdDate = createdAt.toDate();
        // Wunsch muss im Zeitraum der Party liegen
        return createdDate.isAfter(partyStartDate.subtract(const Duration(seconds: 1))) &&
               createdDate.isBefore(partyEndDate.add(const Duration(seconds: 1)));
      }).toList();
      
      debugLog('📊 Gefundene pending-Wünsche für Party-ID ${widget.partyId} im Zeitraum: ${relevantWishes.length} (von ${pendingWishesSnapshot.docs.length} insgesamt)');
      
      // Schließe die gefundenen Wünsche
      if (relevantWishes.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in relevantWishes) {
          batch.update(doc.reference, {'status': 'not_played'});
        }
        await batch.commit();
        debugLog('✅ ${relevantWishes.length} pending-Wünsche wurden auf "not_played" gesetzt');
      }
      
      // Lade dann die Statistik
      await _loadStatistics();
    } catch (e) {
      debugLog('❌ Fehler beim Schließen der pending-Wünsche: $e');
      // Lade trotzdem die Statistik
      await _loadStatistics();
    }
  }

  Future<void> _loadStatistics() async {
    try {
      debugLog('📊 Lade Statistik für Party-ID: ${widget.partyId}');
      
      // Query nach party_id
      var wishesQuery = WishPaths.partyWishes(widget.partyId);
      
      var wishesSnapshot = await wishesQuery.get();
      
      int total = 0;
      int played = 0;
      int rejected = 0;
      int notPlayed = 0;
      Map<int, int> wishesPerHour = {}; // Stunde -> Anzahl Wünsche
      List<int> playTimeDurations = []; // Liste der Zeiten in Minuten zwischen createdAt und playedAt
      List<Map<String, dynamic>> playedWishesList = []; // Liste der gespielten Wünsche

      for (var doc in wishesSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        
        // Überspringe gelöschte Wünsche
        if (status == 'deleted') {
          continue;
        }

        total++;
        
        if (status == 'played') {
          played++;
          
          // Speichere gespielten Wunsch für PDF
          final title = (data['title'] ?? data['song'] ?? '') as String;
          final artist = (data['artist'] ?? '') as String;
          final playedAt = data['playedAt'] as Timestamp?;
          
          if (playedAt != null) {
            playedWishesList.add({
              'title': title,
              'artist': artist,
              'playedAt': playedAt,
            });
          }
          
          // Berechne Zeit zwischen Absendung und Spielen
          final createdAt = data['createdAt'] as Timestamp?;
          
          if (createdAt != null && playedAt != null) {
            final createdDate = createdAt.toDate();
            final playedDate = playedAt.toDate();
            final difference = playedDate.difference(createdDate);
            final minutes = difference.inMinutes.toDouble();
            if (minutes >= 0) { // Nur positive Werte berücksichtigen
              playTimeDurations.add(minutes.toInt());
            }
          }
        } else if (status == 'rejected') {
          rejected++;
        } else if (status == 'not_played') {
          notPlayed++;
        } else if (status == 'pending' || status == null) {
          // Pending-Wünsche zählen als "nicht gespielt" für die Statistik
          notPlayed++;
          debugLog('⚠️ Pending-Wunsch gefunden (sollte eigentlich bereits umgewandelt sein): ${doc.id}');
        }
        
        // Gruppiere nach Stunden - nur wenn Wunsch im Zeitraum der Party liegt
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final createdDate = createdAt.toDate();
          // Prüfe ob Wunsch im Zeitraum der Party liegt
          if (createdDate.isAfter(widget.startDate.subtract(const Duration(seconds: 1))) &&
              createdDate.isBefore(widget.endDate.add(const Duration(seconds: 1)))) {
            final hour = createdDate.hour;
            wishesPerHour[hour] = (wishesPerHour[hour] ?? 0) + 1;
            debugLog('📊 Wunsch in Stunde $hour: ${createdDate.toString()}');
          } else {
            debugLog('⚠️ Wunsch außerhalb Party-Zeitraum: ${createdDate.toString()} (Party: ${widget.startDate} - ${widget.endDate})');
          }
        } else {
          debugLog('⚠️ Wunsch ohne createdAt: ${doc.id}');
        }
      }
      
      debugLog('📊 wishesPerHour vor Filterung: $wishesPerHour');
      
      // Berechne Durchschnittszeit
      double averagePlayTimeMinutes = 0.0;
      if (playTimeDurations.isNotEmpty) {
        final sum = playTimeDurations.reduce((a, b) => a + b);
        averagePlayTimeMinutes = sum / playTimeDurations.length;
      }
      
      // Sortiere gespielte Wünsche nach playedAt (neueste zuerst)
      playedWishesList.sort((a, b) {
        final playedAtA = a['playedAt'] as Timestamp?;
        final playedAtB = b['playedAt'] as Timestamp?;
        if (playedAtA == null || playedAtB == null) return 0;
        return playedAtB.compareTo(playedAtA);
      });
      
      // Bestimme alle Stunden im Zeitraum der Party (berücksichtigt auch Partys über Mitternacht)
      final filteredWishesPerHour = <int, int>{};
      final partyStart = widget.startDate;
      final partyEnd = widget.endDate;
      
      debugLog('📅 Party-Zeitraum: ${partyStart.toString()} bis ${partyEnd.toString()}');
      
      // Volle Stunden-Buckets [H:00, H+1:00), die mit [partyStart, partyEnd) überlappen.
      // Endet die Party exakt um 2:00, zählt 2:00 nicht (letzter Bucket ist 1:00–1:59).
      final hoursInRange = <int>[];
      DateTime currentHour = DateTime(
        partyStart.year,
        partyStart.month,
        partyStart.day,
        partyStart.hour,
      );

      int iterationCount = 0;
      while (currentHour.isBefore(partyEnd)) {
        hoursInRange.add(currentHour.hour);
        debugLog(
          '⏰ Stunde hinzugefügt: ${currentHour.hour}:00 (${currentHour.toString()})',
        );
        currentHour = currentHour.add(const Duration(hours: 1));
        iterationCount++;
        if (iterationCount > 48) {
          debugLog('⚠️ Zu viele Stunden, breche ab');
          break;
        }
      }
      
      debugLog('📊 Stunden im Bereich: $hoursInRange');
      
      // Fülle filteredWishesPerHour mit allen Stunden im Bereich
      // WICHTIG: Wenn hoursInRange leer ist, verwende alle Stunden von 0-23
      if (hoursInRange.isEmpty) {
        debugLog('⚠️ Keine Stunden im Bereich gefunden, verwende alle Stunden 0-23');
        for (int hour = 0; hour < 24; hour++) {
          if (wishesPerHour.containsKey(hour)) {
            filteredWishesPerHour[hour] = wishesPerHour[hour]!;
          } else {
            filteredWishesPerHour[hour] = 0;
          }
        }
      } else {
        for (final hour in hoursInRange) {
          if (wishesPerHour.containsKey(hour)) {
            filteredWishesPerHour[hour] = wishesPerHour[hour]!;
          } else {
            filteredWishesPerHour[hour] = 0;
          }
        }
      }
      
      debugLog('📊 filteredWishesPerHour: $filteredWishesPerHour');
      
      // Bestimme erste und letzte Stunde für die Anzeige
      final firstFullHour = hoursInRange.isNotEmpty ? hoursInRange.first : (filteredWishesPerHour.keys.isNotEmpty ? filteredWishesPerHour.keys.reduce((a, b) => a < b ? a : b) : widget.startDate.hour);
      final lastFullHour = hoursInRange.isNotEmpty ? hoursInRange.last : (filteredWishesPerHour.keys.isNotEmpty ? filteredWishesPerHour.keys.reduce((a, b) => a > b ? a : b) : widget.endDate.hour);
      
      debugLog('📊 firstFullHour: $firstFullHour, lastFullHour: $lastFullHour');
      
      if (mounted) {
        setState(() {
          _totalWishes = total;
          _playedWishes = played;
          _rejectedWishes = rejected;
          _notPlayedWishes = notPlayed;
          _wishesPerHour = filteredWishesPerHour;
          _averagePlayTimeMinutes = averagePlayTimeMinutes;
          _playedWishesList = playedWishesList;
          _firstFullHour = firstFullHour;
          _lastFullHour = lastFullHour;
          _hoursInRange = hoursInRange; // Speichere die Stundenliste
          _isLoading = false;
        });
      }
      
      debugLog('✅ Statistik geladen: Total=$total, Gespielt=$played, Abgelehnt=$rejected, Nicht gespielt=$notPlayed');
    } catch (e) {
      debugLog('❌ Fehler beim Laden der Statistik: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime date, BuildContext context) {
    return FormattingUtils.formatDateTime(date, context);
  }

  Widget _buildModalHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.party_statistics_title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, widget.embeddedInModal ? 16 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: UIConstants.djShellPageBackground,
            elevation: 0,
            shape: UIConstants.djChromeCardShape,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partyName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.party_code_label} ${widget.partyCode}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _djName != null && _djName!.isNotEmpty
                        ? '${l10n.dj_name_label} $_djName'
                        : l10n.no_dj_name,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.party_start_label} ${_formatDateTime(widget.startDate, context)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.party_end_label} ${_formatDateTime(widget.endDate, context)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Statistiken
          Card(
                    color: UIConstants.djShellPageBackground,
                    elevation: 0,
                    shape: UIConstants.djChromeCardShape,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.statistics,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow(l10n.total_wishes, _totalWishes.toString(), Colors.blue, context),
                          const SizedBox(height: 8),
                          _buildStatRow(l10n.played_songs, _playedWishes.toString(), Colors.green, context),
                          const SizedBox(height: 8),
                          _buildStatRow(l10n.rejected_songs, _rejectedWishes.toString(), UIConstants.frameAbgelehnt, context),
                          const SizedBox(height: 8),
                          _buildStatRow(l10n.not_played_songs, _notPlayedWishes.toString(), Colors.blue, context),
                          if (_playedWishes > 0 && _averagePlayTimeMinutes > 0) ...[
                            const SizedBox(height: 8),
                            _buildStatRow(
                              l10n.avg_time_to_play,
                              '${_averagePlayTimeMinutes.toStringAsFixed(1)} ${l10n.minutes_short}',
                              Colors.purple,
                              context,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Kreisdiagramm
                  if (_totalWishes > 0)
                    Card(
                      color: UIConstants.djShellPageBackground,
                      elevation: 0,
                      shape: UIConstants.djChromeCardShape,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              l10n.distribution,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 250,
                              child: PieChart(
                                PieChartData(
                                  sections: _buildPieChartSections(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 60,
                                  startDegreeOffset: _calculateStartOffset(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLegend(context),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      color: UIConstants.djShellPageBackground,
                      elevation: 0,
                      shape: UIConstants.djChromeCardShape,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(l10n.no_wishes_available),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Balkendiagramm: Wünsche pro Stunde
                  Card(
                    color: UIConstants.djShellPageBackground,
                    elevation: 0,
                    shape: UIConstants.djChromeCardShape,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.wishes_per_hour,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildBarChartWithPercentages(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // PDF-Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _generateSmallStatisticsPDF(),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(l10n.small_statistics),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _generateDetailedStatisticsPDF(),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(l10n.detailed_statistics),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.embeddedInModal) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModalHeader(l10n),
            Expanded(child: _buildStatisticsBody(l10n)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: UIConstants.djShellPageBackground,
      appBar: AppBar(
        iconTheme: UIConstants.appBarIconTheme,
        titleTextStyle: UIConstants.appBarTitleTextStyle,
        backgroundColor: UIConstants.appBarBackgroundColor,
        title: Text(l10n.party_statistics_title),
      ),
      body: _buildStatisticsBody(l10n),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  double _calculateStartOffset() {
    if (_totalWishes == 0) {
      return -90;
    }
    
    final playedAngle = (_playedWishes / _totalWishes) * 360;
    final rejectedAngle = (_rejectedWishes / _totalWishes) * 360;
    final offset = -90 + playedAngle + rejectedAngle;
    
    return offset;
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final sections = <PieChartSectionData>[];
    
    if (_totalWishes == 0) {
      return sections;
    }

    final playedPercentage = (_playedWishes / _totalWishes) * 100;
    final rejectedPercentage = (_rejectedWishes / _totalWishes) * 100;
    final notPlayedPercentage = (_notPlayedWishes / _totalWishes) * 100;

    if (playedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _playedWishes.toDouble(),
          title: '${playedPercentage.toStringAsFixed(1)}%',
          color: Colors.green,
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (rejectedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _rejectedWishes.toDouble(),
          title: '${rejectedPercentage.toStringAsFixed(1)}%',
          color: UIConstants.frameAbgelehnt,
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (notPlayedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _notPlayedWishes.toDouble(),
          title: '${notPlayedPercentage.toStringAsFixed(1)}%',
          color: Colors.blue,
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildLegend(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildLegendItem(l.played_songs, Colors.green, _playedWishes),
        const SizedBox(height: 8),
        _buildLegendItem(l.rejected_songs, UIConstants.frameAbgelehnt, _rejectedWishes),
        const SizedBox(height: 8),
        _buildLegendItem(l.not_played_songs, Colors.blue, _notPlayedWishes),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
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
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          count.toString(),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildBarChartWithPercentages() {
    if (_wishesPerHour.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.no_data_available),
      );
    }

    final maxCount = _wishesPerHour.values.reduce((a, b) => a > b ? a : b);
    
    // Verwende _hoursInRange wenn verfügbar, sonst fallback auf normale Schleife
    final hoursToDisplay = _hoursInRange.isNotEmpty 
        ? _hoursInRange 
        : (_firstFullHour <= _lastFullHour 
            ? List.generate(_lastFullHour - _firstFullHour + 1, (i) => _firstFullHour + i)
            : []);
    
    return Column(
      children: [
        for (int hour in hoursToDisplay)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: maxCount > 0 ? (_wishesPerHour[hour] ?? 0) / maxCount : 0,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${_wishesPerHour[hour] ?? 0} (${_totalWishes > 0 ? ((_wishesPerHour[hour] ?? 0) / _totalWishes * 100).toStringAsFixed(1) : '0.0'}%)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDateTimeForPDF(DateTime date, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final clock = localizations.party_time_clock;
    return '$day.$month.$year $hour:$minute $clock';
  }

  Future<void> _generateSmallStatisticsPDF() async {
    // Placeholder - implement later if needed
    if (mounted) {
      _showPageSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pdf_generation_not_implemented),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _generateDetailedStatisticsPDF() async {
    // Placeholder - implement later if needed
    if (mounted) {
      _showPageSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pdf_generation_not_implemented),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
