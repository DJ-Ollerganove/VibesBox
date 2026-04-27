import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart' show buildFirebaseErrorWidget;
import '../l10n/app_localizations.dart';
import '../services/active_party_service.dart';
import '../services/history_pagination_service.dart';
import '../services/results_per_page_service.dart';
import '../services/wish_management_service.dart';
import '../services/duplicate_check_service.dart';
import '../services/user_blocking_service.dart';
import '../utils/ui_constants.dart';
import '../utils/wish_grouping_helper.dart';
import '../models/song_request.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/sticky_pagination_layout.dart';
import '../widgets/custom_page_header.dart';
import '../widgets/no_active_party_display.dart';
import '../widgets/wish_card.dart';
import '../utils/debug_log.dart';

class FavoritenPage extends StatefulWidget {
  final List<SongRequest> requests;
  final VoidCallback? onPageOpened;
  
  const FavoritenPage({super.key, required this.requests, this.onPageOpened});

  @override
  State<FavoritenPage> createState() => _FavoritenPageState();
}

class _FavoritenPageState extends State<FavoritenPage> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  Stream<QuerySnapshot>? _wishesStream;
  StreamSubscription<ActivePartyInfo?>? _partySubscription;
  String? _currentPartyId;
  List<String> _currentVisibleIds = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentVisibleIds = [];
    _initializeStream();
    DuplicateCheckService.ensurePartySettingsLoaded();
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
    widget.onPageOpened?.call();
  }

  void _initializeStream() {
    final user = FirebaseAuth.instance.currentUser;
    _partySubscription = ActivePartyService.getActivePartyInfoStream(user?.uid).listen(
      (activeParty) {
        final partyId = activeParty?.partyId;
        debugLog('🚀 FavoritenPage: Initialisiere Stream für lange ID: $partyId');
        if (partyId != null && partyId.isNotEmpty && partyId != _currentPartyId) {
          _currentPartyId = partyId;
          debugLog('✅ FavoritenPage: Erstelle Favoriten-Wishes-Stream mit party_id: $partyId');
          _wishesStream = WishManagementService.getFavoriteWishesStream(partyId, 'pending');
          if (mounted) {
            setState(() {});
          }
        } else if (partyId == null || partyId.isEmpty) {
          debugLog('⚠️ FavoritenPage: Keine partyId erhalten, setze Stream auf null');
          _currentPartyId = null;
          _wishesStream = null;
          if (mounted) {
            setState(() {});
          }
        }
      },
      onError: (error) {
        debugLog('❌ FavoritenPage: Fehler im ActivePartyInfo-Stream: $error');
      },
    );
  }

  @override
  void dispose() {
    _partySubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _goToNextPage(int totalPages) {
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Widget _buildPaginationButtons(int currentPage, int totalPages, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: UIConstants.djChromePanelDecoration,
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: HistoryPaginationService.hasPreviousPage(currentPage)
                ? () => _goToPreviousPage()
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_forward : Icons.arrow_back,
              size: 18,
            ),
            label: Text(l.history_page_previous),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              side: BorderSide(
                color: HistoryPaginationService.hasPreviousPage(currentPage)
                    ? UIConstants.frameOffen
                    : UIConstants.colorGrey,
                width: 1,
              ),
              disabledForegroundColor: UIConstants.colorGrey,
            ),
          ),
          Text(
            '${l.history_page} $currentPage / $totalPages',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          ElevatedButton.icon(
            onPressed: HistoryPaginationService.hasNextPage(currentPage, totalPages)
                ? () => _goToNextPage(totalPages)
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_back : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(l.history_page_next),
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.djShellPageBackground,
              foregroundColor: Colors.white,
              side: BorderSide(
                color: HistoryPaginationService.hasNextPage(currentPage, totalPages)
                    ? UIConstants.appOrange
                    : UIConstants.colorGrey,
                width: 1,
              ),
              disabledForegroundColor: UIConstants.colorGrey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Titelleiste mit CustomPageHeader
            CustomPageHeader(
              icon: Icons.favorite,
              title: l.favorites_page_title,
              trailing: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Content-Bereich
            Expanded(
              child: StickyPaginationLayout(
                currentPage: _currentPage > 0 ? _currentPage : 1,
                totalPages: 1,
                onPrevious: null,
                onNext: null,
                child: ValueListenableBuilder<ActivePartyInfo?>(
                  valueListenable: ActivePartyService.storedSessionNotifier,
                  builder: (context, info, _) {
                    final partyId = info?.partyId;
                    if (partyId != null && partyId.isNotEmpty && partyId != _currentPartyId) {
                      _currentPartyId = partyId;
                    } else if (partyId == null || partyId.isEmpty) {
                      _currentPartyId = null;
                    }
                    if (info == null || partyId == null || partyId.isEmpty) {
                      return const NoActivePartyDisplay();
                    }
                    // Fall B: Party aktiv – Favoriten-Stream
                    if (_wishesStream == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return StreamBuilder<QuerySnapshot>(
                      stream: _wishesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          debugLog('❌ FavoritenPage: Stream-Fehler: ${snapshot.error}');
                          return buildFirebaseErrorWidget(snapshot.error!);
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return SingleChildScrollView(
                            controller: _scrollController,
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
                        // Gruppiere Wünsche
                        final openWishes = snapshot.data!.docs.map((doc) {
                          return SongRequest.fromDocument(doc);
                        }).toList() as List<SongRequest>;
                        // Sortiere nach createdAt (neueste zuerst)
                        openWishes.sort((a, b) {
                      final tsA = a.createdAt;
                      final tsB = b.createdAt;
                      if (tsA == null && tsB == null) return 0;
                      if (tsA == null) return 1;
                      if (tsB == null) return -1;
                      return tsB.compareTo(tsA);
                    });
                    
                    final groupedResult = WishGroupingHelper.groupWishes(openWishes);
                    final allGroupedList = groupedResult['groups'] as List<Map<String, dynamic>>;
                    final groupedFirstRequests = groupedResult['firstRequests'] as Map<String, SongRequest>;
                    final groupedDocIds = groupedResult['docIds'] as Map<String, List<String>>;
                    
                    final totalPages = HistoryPaginationService.calculateTotalPages(allGroupedList.length, itemsPerPage: _resultsPerPage);
                    
                    // Korrigiere _currentPage falls nötig
                    if (_currentPage > totalPages && totalPages > 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _currentPage = totalPages;
                        });
                      });
                    }
                    
                    final paginatedGroupedList = HistoryPaginationService.getItemsForPage(
                      allGroupedList,
                      _currentPage > 0 ? _currentPage : 1,
                      itemsPerPage: _resultsPerPage,
                    );
                    
                    _currentVisibleIds = paginatedGroupedList
                        .map((groupEntry) {
                          final groupKey = groupEntry['key'] as String;
                          return groupedDocIds[groupKey] ?? [];
                        })
                        .expand((ids) => ids)
                        .toList();

                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...paginatedGroupedList.asMap().entries.map((entry) {
                            final index = entry.key;
                            final groupEntry = entry.value;
                            final groupKey = groupEntry['key'] as String;
                            final data = groupEntry['data'] as Map<String, dynamic>;
                            final docIds = groupedDocIds[groupKey]!;
                            final firstRequest = groupedFirstRequests[groupKey]!;
                            
                            final number = allGroupedList.length - (HistoryPaginationService.calculateStartIndex(_currentPage > 0 ? _currentPage : 1, itemsPerPage: _resultsPerPage) + index);
                            
                            // Prüfe ob Wunsch als "NEU" markiert werden soll
                            final isNew = docIds.any((docId) => !ActivePartyService.seenWishIds.contains(docId));
                            
                            // Füge alle docIds dieser Gruppe zu _currentVisibleIds hinzu (falls noch nicht vorhanden)
                            for (final docId in docIds) {
                              if (!_currentVisibleIds.contains(docId)) {
                                _currentVisibleIds.add(docId);
                              }
                            }

                            return WishCard(
                              key: ValueKey('favorite-${docIds.join("-")}'),
                              groupedData: data,
                              docIds: docIds,
                              type: WishCardType.offen,
                              number: number,
                              isNew: isNew,
                              lastViewedTime: null,
                              onPlay: (context, ids) async {
                                await WishManagementService.updateGroupedStatus(
                                  ids,
                                  'played',
                                  _currentPartyId!,
                                );
                              },
                              onReject: (context, ids) async {
                                await WishManagementService.updateGroupedStatus(
                                  ids,
                                  'rejected',
                                  _currentPartyId!,
                                );
                              },
                              onDelete: (context, ids) async {
                                await WishManagementService.deleteGroupedWishes(
                                  ids,
                                  _currentPartyId!,
                                );
                              },
                              onBlockGrouped: (context, request, dataMap, ids) async {
                                await UserBlockingService.showGroupedBlockDialog(
                                  context,
                                  request,
                                  dataMap,
                                  ids,
                                );
                              },
                            );
                          }),
                          _buildPaginationButtons(
                            _currentPage > 0 ? _currentPage : 1,
                            totalPages,
                            context,
                          ),
                          const SizedBox(height: UIConstants.kFooterPadding * 2),
                        ],
                      ),
                    );
                  },
                  );
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
