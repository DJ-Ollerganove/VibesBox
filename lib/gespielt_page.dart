import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'main.dart' show buildFirebaseErrorWidget;
import '../utils/ui_constants.dart';
import '../services/active_party_service.dart';
import '../models/song_request.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/sticky_pagination_layout.dart';
import '../widgets/wish_card.dart';
import '../widgets/no_active_party_display.dart';
import '../widgets/pro_promotion_banner.dart';
import '../services/user_service.dart';
import '../services/duplicate_check_service.dart';
import '../services/results_per_page_service.dart';
import '../services/history_pagination_service.dart';
import '../utils/wish_grouping_helper.dart';
import '../services/wish_management_service.dart';
import 'utils/debug_log.dart';

class GespieltPage extends StatefulWidget {
  final List<SongRequest> requests;
  
  const GespieltPage({super.key, required this.requests});

  @override
  State<GespieltPage> createState() => _GespieltPageState();
}

class _GespieltPageState extends State<GespieltPage> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  String? _currentPartyId;

  @override
  void initState() {
    super.initState();
    DuplicateCheckService.ensurePartySettingsLoaded();
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StickyPaginationLayout(
                currentPage: _currentPage > 0 ? _currentPage : 1,
                totalPages: 1,
                onPrevious: null,
                onNext: null,
                child: ValueListenableBuilder<ActivePartyInfo?>(
                  valueListenable: ActivePartyService.storedSessionNotifier,
                  builder: (context, info, _) {
                    final activePartyId = info?.partyId;
                    if (activePartyId != null && activePartyId.isNotEmpty && activePartyId != _currentPartyId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _currentPartyId = activePartyId);
                      });
                    } else if (activePartyId == null || activePartyId.isEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _currentPartyId = null);
                      });
                    }
                    return KeyedSubtree(
                      key: ValueKey<String>(activePartyId ?? 'none'),
                      child: activePartyId == null || activePartyId.isEmpty
                          ? const Stack(
                              children: [
                                Positioned.fill(
                                  child: Center(child: NoActivePartyDisplay()),
                                ),
                              ],
                            )
                          : StreamBuilder<QuerySnapshot>(
                              stream: WishManagementService.getWishesStream(activePartyId, 'played'),
                              builder: (context, snapshot) => _buildWishesListWithPartyId(context, snapshot, activePartyId),
                            ),
                    );
                  },
                ),
              );
  }

  /// Wunschliste für eine gegebene Party-ID (für Stream- und Prefs-Fallback)
  Widget _buildWishesListWithPartyId(BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot, String partyId) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                          return SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 24),
                                EmptyListMessage(),
                                const SizedBox(height: UIConstants.kFooterPadding * 2),
                              ],
                            ),
                          );
                        }

                        // STREAM-ERROR-LOGGING: Detaillierte Fehlerausgabe
                        if (snapshot.hasError) {
                          debugLog('❌❌❌ STREAM FEHLER in gespielt_page.dart ❌❌❌');
                          debugLog('   Error: ${snapshot.error}');
                          debugLog('   Error Type: ${snapshot.error.runtimeType}');
                          debugLog('   Party ID: $_currentPartyId');
                          if (snapshot.error is Error) {
                            debugLog('   Stack Trace: ${(snapshot.error as Error).stackTrace}');
                          }
                          return buildFirebaseErrorWidget(snapshot.error!);
                        }

                        final wishesDocs = snapshot.data?.docs ?? [];
                        
                        // DEBUG: Zeige Party-ID und Anzahl der gefundenen Dokumente
                        debugLog('🔍 [DEBUG] GespieltPage: Party-ID: $partyId, Gefundene Wünsche: ${wishesDocs.length}');
                        if (wishesDocs.isEmpty) {
                          debugLog('⚠️ [DEBUG] Keine Wünsche gefunden für Party-ID: $partyId');
                        }

                        // SICHERHEITS-PRÜFUNG: Filter nach party_id
                        final partyFilteredDocs = wishesDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final docPartyId = data['party_id'] as String?;
                          final matches = docPartyId == partyId;
                          if (!matches) {
                            debugLog('🚫 PARTY-FILTER: Dokument ${doc.id} gehört zu Party "$docPartyId", erwartet "$partyId" - wird ausgeschlossen');
                          }
                          return matches;
                        }).toList();
                        
                        debugLog('🔍 [DEBUG] GespieltPage: Nach Party-ID-Filter: ${partyFilteredDocs.length} von ${wishesDocs.length} Dokumenten verbleiben');

                        // Konvertiere zu SongRequest Objekten (mit Error-Handling)
                        // WICHTIG: is_duplicate Filter entfernt, da Gruppierung jetzt party-spezifisch ist
                        final playedWishes = <SongRequest>[];
                        for (final doc in partyFilteredDocs) {
                          try {
                            final songRequest = SongRequest.fromDocument(doc);
                            playedWishes.add(songRequest);
                          } catch (e, stackTrace) {
                            debugLog('❌ Fehler beim Konvertieren von Dokument ${doc.id}: $e');
                            debugLog('   Stack: $stackTrace');
                            debugLog('   Document Data: ${doc.data()}');
                            // Überspringe dieses Dokument, damit die App weiterläuft
                            continue;
                          }
                        }

                        // Wenn Liste leer -> EmptyListMessage
                        if (playedWishes.isEmpty) {
                          return SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 24),
                                EmptyListMessage(),
                                const SizedBox(height: UIConstants.kFooterPadding * 2),
                              ],
                            ),
                          );
                        }

                        // Sortiere nach Spiel-/Status-Datum (neueste zuerst), s. [SongRequest.sortTimestampPlayed]
                        final sortedWishes = playedWishes.toList()
                          ..sort((a, b) =>
                              b.sortTimestampPlayed.compareTo(a.sortTimestampPlayed));

                        // Gruppiere Wünsche
                        final groupedResult = WishGroupingHelper.groupWishes(
                          sortedWishes,
                          listSort: WishGroupListSort.byPlayedTimestamp,
                        );
                        final allGroupedList = groupedResult['groups'] as List<Map<String, dynamic>>;
                        final groupedDocIds = groupedResult['docIds'] as Map<String, List<String>>;

                        // Paginierung: Berechne Seiten (Ergebnisse pro Seite aus Einstellungen)
                        final totalPages = HistoryPaginationService.calculateTotalPages(allGroupedList.length, itemsPerPage: _resultsPerPage);
                        if (_currentPage > totalPages && totalPages > 0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              _currentPage = totalPages;
                            });
                          });
                        }
                        
                        // Hole paginierte Liste
                        final paginatedGroupedList = HistoryPaginationService.getItemsForPage(
                          allGroupedList,
                          _currentPage > 0 ? _currentPage : 1,
                          itemsPerPage: _resultsPerPage,
                        );

                        // Variable Logik für bottomPadding
                        final bottomPadding = totalPages > 1 ? 220.0 : 150.0;

                        return SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 24),
                              RepaintBoundary(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.only(
                                    top: 8.0,
                                    bottom: bottomPadding,
                                  ),
                                  itemCount: () {
                                    final len = paginatedGroupedList.length;
                                    final isFree = UserService().sessionProStatus.value?.isActive != true;
                                    return isFree ? len + (len / 5).floor() : len;
                                  }(),
                                  separatorBuilder: (_, i) {
                                    final isFree = UserService().sessionProStatus.value?.isActive != true;
                                    if (!isFree) return const Divider(height: 1);
                                    if (i % 6 != 5 && (i + 1) % 6 != 5) return const Divider(height: 1);
                                    return const SizedBox.shrink();
                                  },
                                  itemBuilder: (context, index) {
                                    final isFree = UserService().sessionProStatus.value?.isActive != true;
                                    if (isFree && index % 6 == 5) {
                                      return const ProPromotionBanner();
                                    }
                                    final dataIndex = index - (index ~/ 6);
                                    final groupEntry = paginatedGroupedList[dataIndex];
                                    final groupKey = groupEntry['key'] as String;
                                    final data = groupEntry['data'] as Map<String, dynamic>;
                                    final docIds = groupedDocIds[groupKey]!;
                                    
                                    final number = allGroupedList.length - (HistoryPaginationService.calculateStartIndex(_currentPage > 0 ? _currentPage : 1, itemsPerPage: _resultsPerPage) + dataIndex);
                                    const isNew = false; // Gespielte Wünsche sind nicht "neu"

                                    return WishCard(
                                      key: ValueKey(groupKey),
                                      groupedData: data,
                                      docIds: docIds,
                                      type: WishCardType.gespielt,
                                      number: number,
                                      isNew: isNew,
                                      detailDialogBorderColor: UIConstants.frameGespielt,
                                      onPlay: null,
                                      onReject: null,
                                      onDelete: null,
                                      onBlockGrouped: null,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: UIConstants.kFooterPadding * 2),
                            ],
                          ),
                        );
  }

}
