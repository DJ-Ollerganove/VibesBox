import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'main.dart' show buildFirebaseErrorWidget;
import '../utils/ui_constants.dart';
import '../models/song_request.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/sticky_pagination_layout.dart';
import '../widgets/wish_card.dart';
import '../widgets/dj_wish_party_scope.dart';
import '../widgets/pro_promotion_banner.dart';
import '../services/user_service.dart';
import '../services/duplicate_check_service.dart';
import '../services/results_per_page_service.dart';
import '../services/history_pagination_service.dart';
import '../utils/wish_grouping_helper.dart';
import '../utils/wish_paths.dart';
import '../utils/wish_party_filter.dart';
import '../utils/free_list_pro_promo.dart';
import 'utils/debug_log.dart';

class GespieltPage extends StatefulWidget {
  final List<SongRequest> requests;
  
  const GespieltPage({super.key, required this.requests});

  @override
  State<GespieltPage> createState() => _GespieltPageState();
}

class _GespieltPageState extends State<GespieltPage>
    with AutomaticKeepAliveClientMixin {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;

  @override
  bool get wantKeepAlive => true;

  String? _cachedPlayedStreamPartyId;
  Stream<QuerySnapshot>? _cachedPlayedWishesStream;

  Stream<QuerySnapshot> _playedWishesStreamForParty(String partyId) {
    if (_cachedPlayedStreamPartyId != partyId) {
      _cachedPlayedStreamPartyId = partyId;
      _cachedPlayedWishesStream = _watchPlayedWishes(partyId);
    }
    return _cachedPlayedWishesStream!;
  }

  Stream<QuerySnapshot> _watchPlayedWishes(String partyId) async* {
    final query =
        WishPaths.partyWishes(partyId).where('status', isEqualTo: 'played');
    yield await query.get();
    yield* query.snapshots();
  }


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
    super.build(context);
    return StickyPaginationLayout(
                currentPage: _currentPage > 0 ? _currentPage : 1,
                totalPages: 1,
                onPrevious: null,
                onNext: null,
                child: DjWishPartyScope(
                  builder: (context, activePartyId, visibility) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _playedWishesStreamForParty(activePartyId),
                      builder: (context, snapshot) =>
                          _buildWishesListWithPartyId(
                        context,
                        snapshot,
                        activePartyId,
                      ),
                    );
                  },
                ),
              );
  }

  /// Wunschliste für eine gegebene Party-ID (für Stream- und Prefs-Fallback)
  Widget _buildWishesListWithPartyId(BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot, String partyId) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
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
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: UIConstants.appOrange,
                                  ),
                                ),
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
                          debugLog('   Party ID: $partyId');
                          if (snapshot.error is Error) {
                            debugLog('   Stack Trace: ${(snapshot.error as Error).stackTrace}');
                          }
                          return buildFirebaseErrorWidget(snapshot.error!);
                        }

                        final wishesDocs = snapshot.data?.docs ?? [];
                        
                        if (kDebugMode) {
                          debugLog('🔍 [DEBUG] GespieltPage: Party-ID: $partyId, Gefundene Wünsche: ${wishesDocs.length}');
                          if (wishesDocs.isEmpty) {
                            debugLog('⚠️ [DEBUG] Keine Wünsche gefunden für Party-ID: $partyId');
                          }
                        }

                        // SICHERHEITS-PRÜFUNG: Filter nach party_id
                        final partyFilteredDocs = wishesDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final matches = wishDocDataMatchesPartyId(data, partyId);
                          if (kDebugMode && !matches) {
                            final docPartyId = data['party_id'] ?? data['partyId'];
                            debugLog('🚫 PARTY-FILTER: Dokument ${doc.id} gehört zu Party "$docPartyId", erwartet "$partyId" - wird ausgeschlossen');
                          }
                          return matches;
                        }).toList();
                        
                        if (kDebugMode) {
                          debugLog('🔍 [DEBUG] GespieltPage: Nach Party-ID-Filter: ${partyFilteredDocs.length} von ${wishesDocs.length} Dokumenten verbleiben');
                        }

                        // Konvertiere zu SongRequest Objekten (mit Error-Handling)
                        // WICHTIG: is_duplicate Filter entfernt, da Gruppierung jetzt party-spezifisch ist
                        final playedWishes = <SongRequest>[];
                        final seenPlayedDocIds = <String>{};
                        for (final doc in partyFilteredDocs) {
                          if (!seenPlayedDocIds.add(doc.id)) {
                            if (kDebugMode) {
                              debugLog('⚠️ GespieltPage: doppelte Dokument-ID übersprungen: ${doc.id}');
                            }
                            continue;
                          }
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

                        // Shadow-Docs nur für Uhrzeiten, nicht als eigene Zeile (wie Offen).
                        final primaryPlayedWishes =
                            WishGroupingHelper.withoutDuplicateShadowDocuments(
                          playedWishes,
                        );

                        // Sortiere nach Spiel-/Status-Datum (neueste zuerst), s. [SongRequest.sortTimestampPlayed]
                        final sortedWishes = primaryPlayedWishes.toList()
                          ..sort((a, b) =>
                              b.sortTimestampPlayed.compareTo(a.sortTimestampPlayed));

                        // Gruppiere Wünsche
                        final groupedResult = WishGroupingHelper.groupWishes(
                          sortedWishes,
                          listSort: WishGroupListSort.byPlayedTimestamp,
                          sessionPartyId: partyId,
                          allRequestsForTimestamps: playedWishes,
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
                          key: PageStorageKey<String>('gespielt_played_scroll_$partyId'),
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
                                    return FreeListProPromo.itemCount(len, isFree: isFree);
                                  }(),
                                  separatorBuilder: (_, i) {
                                    final len = paginatedGroupedList.length;
                                    final isFree = UserService().sessionProStatus.value?.isActive != true;
                                    if (!isFree) return const Divider(height: 1);
                                    if (FreeListProPromo.isPromoIndex(i, len, isFree: true) ||
                                        FreeListProPromo.isPromoIndex(i + 1, len, isFree: true)) {
                                      return const SizedBox.shrink();
                                    }
                                    return const Divider(height: 1);
                                  },
                                  itemBuilder: (context, index) {
                                    final len = paginatedGroupedList.length;
                                    final isFree = UserService().sessionProStatus.value?.isActive != true;
                                    if (FreeListProPromo.isPromoIndex(index, len, isFree: isFree)) {
                                      return const ProPromotionBanner();
                                    }
                                    final dataIndex =
                                        FreeListProPromo.dataIndex(index, len, isFree: isFree);
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
