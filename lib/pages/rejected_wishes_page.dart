import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'dart:async';

import '../main.dart' show buildFirebaseErrorWidget;
import '../services/history_pagination_service.dart';
import '../utils/ui_constants.dart';
import '../l10n/app_localizations.dart';
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
import '../utils/wish_grouping_helper.dart';
import '../services/wish_management_service.dart';
import '../utils/debug_log.dart';
import '../utils/string_utils.dart';

/// DJ-Übersicht: abgelehnte Wünsche (ehemals [AbgelehntPage]).
class RejectedWishesPage extends StatefulWidget {
  final List<SongRequest> requests;
  /// Wird aufgerufen, wenn ein Wunsch auf „Offen“ zurückgesetzt wurde – für Tab-Wechsel
  final VoidCallback? onWishRestoredToOpen;

  const RejectedWishesPage({
    super.key,
    required this.requests,
    this.onWishRestoredToOpen,
  });

  @override
  State<RejectedWishesPage> createState() => _RejectedWishesPageState();
}

class _RejectedWishesPageState extends State<RejectedWishesPage> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  final ScrollController _scrollController =
      ScrollController(); // ✅ Für Scrollen nach oben beim Seitenwechsel

  String? _cachedRejectedStreamPartyId;
  Stream<QuerySnapshot>? _cachedRejectedWishesStream;

  Stream<QuerySnapshot> _rejectedWishesStreamForParty(String partyId) {
    if (_cachedRejectedStreamPartyId != partyId) {
      _cachedRejectedStreamPartyId = partyId;
      _cachedRejectedWishesStream =
          WishManagementService.getWishesStream(partyId, 'rejected');
    }
    return _cachedRejectedWishesStream!;
  }

  void _tearDownRejectedStream() {
    _cachedRejectedStreamPartyId = null;
    _cachedRejectedWishesStream = null;
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
  void dispose() {
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

  Widget _buildPaginationButtons(
    int currentPage,
    int totalPages,
    BuildContext context,
  ) {
    final l = AppLocalizations.of(context)!;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(
        top: 8,
        bottom: 16,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: UIConstants.djChromePanelDecoration,
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: HistoryPaginationService.hasPreviousPage(currentPage)
                ? _goToPreviousPage
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_forward : Icons.arrow_back,
              size: 18,
            ),
            label: Text(l.history_page_previous),
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.djShellPageBackground,
              foregroundColor: Colors.white,
              disabledBackgroundColor: UIConstants.colorGrey.withValues(alpha: 0.4),
              disabledForegroundColor: UIConstants.colorGrey,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: UIConstants.appOrange, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Text(
            '${l.history_page} $currentPage / $totalPages',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          ElevatedButton.icon(
            onPressed:
                HistoryPaginationService.hasNextPage(currentPage, totalPages)
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
              disabledBackgroundColor: UIConstants.colorGrey.withValues(alpha: 0.4),
              disabledForegroundColor: UIConstants.colorGrey,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: UIConstants.appOrange, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
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
          final effectivePartyId = info?.partyId;
          if (effectivePartyId == null || effectivePartyId.isEmpty) {
            _tearDownRejectedStream();
            return const KeyedSubtree(
              key: ValueKey<String>('none'),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(child: NoActivePartyDisplay()),
                  ),
                ],
              ),
            );
          }
          return KeyedSubtree(
            key: ValueKey<String>(effectivePartyId),
            child: StreamBuilder<QuerySnapshot>(
              stream: _rejectedWishesStreamForParty(effectivePartyId),
              builder: (context, snapshot) => _buildWishesListWithPartyId(
                context,
                snapshot,
                effectivePartyId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWishesListWithPartyId(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot> snapshot,
    String partyId,
  ) {
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
            EmptyListMessage(),
            const SizedBox(height: UIConstants.kFooterPadding * 2),
          ],
        ),
      );
    }

    if (snapshot.hasError) {
      debugLog('❌❌❌ STREAM FEHLER in rejected_wishes_page.dart ❌❌❌');
      debugLog('   Error: ${snapshot.error}');
      debugLog('   Error Type: ${snapshot.error.runtimeType}');
      debugLog(
        '   Party ID: ${ActivePartyService.currentPartyId}',
      );
      if (snapshot.error is Error) {
        debugLog('   Stack Trace: ${(snapshot.error as Error).stackTrace}');
      }
      return buildFirebaseErrorWidget(snapshot.error!);
    }

    final wishesDocs = snapshot.data?.docs ?? [];

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] RejectedWishesPage: Party-ID: $partyId, Gefundene Wünsche: ${wishesDocs.length}',
      );
      if (wishesDocs.isEmpty) {
        debugLog('⚠️ [DEBUG] Keine Wünsche gefunden für Party-ID: $partyId');
      }
    }

    final partyFilteredDocs = wishesDocs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docPartyId = data['party_id'] as String?;
          final matches = docPartyId == partyId;
          if (kDebugMode && !matches) {
            debugLog(
              '🚫 PARTY-FILTER: Dokument ${doc.id} gehört zu Party "$docPartyId", erwartet "$partyId" - wird ausgeschlossen',
            );
          }
          return matches;
        })
        .toList()
        .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] RejectedWishesPage: Nach Party-ID-Filter: ${partyFilteredDocs.length} von ${wishesDocs.length} Dokumenten verbleiben',
      );
    }

    final rejectedWishes = <SongRequest>[];
    final seenRejectedDocIds = <String>{};
    for (final doc in partyFilteredDocs) {
      if (!seenRejectedDocIds.add(doc.id)) {
        if (kDebugMode) {
          debugLog(
            '⚠️ RejectedWishesPage: doppelte Dokument-ID übersprungen: ${doc.id}',
          );
        }
        continue;
      }
      try {
        final songRequest = SongRequest.fromDocument(doc);
        rejectedWishes.add(songRequest);
      } catch (e, stackTrace) {
        debugLog('❌ Fehler beim Konvertieren von Dokument ${doc.id}: $e');
        debugLog('   Stack: $stackTrace');
        debugLog('   Document Data: ${doc.data()}');
        continue;
      }
    }

    if (rejectedWishes.isEmpty) {
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

    rejectedWishes.sort((a, b) =>
        b.sortTimestampRejected.compareTo(a.sortTimestampRejected));

    final groupedResult = WishGroupingHelper.groupWishes(
      rejectedWishes,
      listSort: WishGroupListSort.byRejectedTimestamp,
      sessionPartyId: partyId,
    );
    final allGroupedList =
        groupedResult['groups'] as List<Map<String, dynamic>>;
    final groupedFirstRequests =
        groupedResult['firstRequests'] as Map<String, SongRequest>;
    final groupedDocIds = groupedResult['docIds'] as Map<String, List<String>>;

    for (final groupedItem in allGroupedList) {
      final groupKey = groupedItem['key'] as String;
      final data = groupedItem['data'] as Map<String, dynamic>;
      final docIds = groupedDocIds[groupKey] ?? [];

      String? rejectionReason;
      for (final docId in docIds) {
        try {
          final foundDoc = partyFilteredDocs.firstWhere((d) => d.id == docId);
          final docData = foundDoc.data();
          final rr = docData['rejection_reason'] as String?;
          if (rr == 'user_blocked') {
            rejectionReason = rr;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      if (rejectionReason != null) {
        data['rejection_reason'] = rejectionReason;
      }
    }

    final totalPages = HistoryPaginationService.calculateTotalPages(
      allGroupedList.length,
      itemsPerPage: _resultsPerPage,
    );

    if (_currentPage > totalPages && totalPages > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentPage = totalPages;
          });
        }
      });
    }

    final paginatedGroupedList = HistoryPaginationService.getItemsForPage(
      allGroupedList,
      _currentPage > 0 ? _currentPage : 1,
      itemsPerPage: _resultsPerPage,
    );

    final bottomPadding = totalPages > 1 ? 8.0 : 150.0;

    return SingleChildScrollView(
      key: PageStorageKey<String>('rejected_scroll_$partyId'),
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
          RepaintBoundary(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 8.0, bottom: bottomPadding),
              itemCount: () {
                final len = paginatedGroupedList.length;
                final isFree =
                    UserService().sessionProStatus.value?.isActive != true;
                return isFree ? len + (len / 5).floor() : len;
              }(),
              separatorBuilder: (_, i) {
                final isFree =
                    UserService().sessionProStatus.value?.isActive != true;
                if (!isFree) return const SizedBox(height: 8);
                if (i % 6 != 5 && (i + 1) % 6 != 5) {
                  return const SizedBox(height: 8);
                }
                return const SizedBox.shrink();
              },
              itemBuilder: (context, index) {
                final isFree =
                    UserService().sessionProStatus.value?.isActive != true;
                if (isFree && index % 6 == 5) {
                  return const ProPromotionBanner();
                }
                final dataIndex = index - (index ~/ 6);
                final groupedItem = paginatedGroupedList[dataIndex];
                final groupKey = groupedItem['key'] as String;
                final data = groupedItem['data'] as Map<String, dynamic>;
                final firstRequest = groupedFirstRequests[groupKey];
                final docIds = groupedDocIds[groupKey] ?? [];

                final number =
                    allGroupedList.length -
                    (HistoryPaginationService.calculateStartIndex(
                          _currentPage > 0 ? _currentPage : 1,
                          itemsPerPage: _resultsPerPage,
                        ) +
                        dataIndex);

                final titleDisp = unescapeHtml((data['title'] ?? '') as String);
                final artistDisp = unescapeHtml((data['artist'] ?? '') as String);
                final displayText = titleDisp.isNotEmpty && artistDisp.isNotEmpty
                    ? '$titleDisp - $artistDisp'
                    : (titleDisp.isNotEmpty ? titleDisp : artistDisp);

                final rejectionReason = data['rejection_reason'] as String?;
                final isUserBlocked = rejectionReason == 'user_blocked';
                final clientId =
                    firstRequest?.clientId ?? data['client_id'] as String?;

                final enhancedData = Map<String, dynamic>.from(data);
                if (isUserBlocked) {
                  enhancedData['rejection_reason'] = 'user_blocked';
                  enhancedData['client_id'] = clientId;
                }

                return FutureBuilder<int>(
                  future:
                      isUserBlocked && clientId != null && clientId.isNotEmpty
                      ? _getBlockHistoryCount(clientId)
                      : Future.value(0),
                  builder: (context, historySnapshot) {
                    final blockCount = historySnapshot.data ?? 0;
                    final l = AppLocalizations.of(context)!;
                    final guestBadgeText = blockCount > 0
                        ? l.guest_blocked_badge_with_occurrence(blockCount)
                        : l.guest_blocked_badge;

                    return Stack(
                      children: [
                        WishCard(
                          key: ValueKey(groupKey),
                          groupedData: enhancedData,
                          docIds: docIds,
                          type: WishCardType.abgelehnt,
                          number: number,
                          isNew: false,
                          detailDialogBorderColor: UIConstants.frameAbgelehnt,
                          onRestore: (detailContext) async {
                            if (ActivePartyService.currentPartyId != null &&
                                ActivePartyService.currentPartyId!.isNotEmpty) {
                              await _restoreGroupedWishes(
                                detailContext,
                                context,
                                docIds,
                                displayText,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.error_no_party_id_found),
                                  backgroundColor: UIConstants.frameNoParty,
                                ),
                              );
                            }
                          },
                          onDelete: (ctx, ids) {
                            final title = unescapeHtml((data['title'] ?? '') as String);
                            final artist = unescapeHtml((data['artist'] ?? '') as String);
                            final delDisplayText =
                                title.isNotEmpty && artist.isNotEmpty
                                ? '$title - $artist'
                                : (title.isNotEmpty ? title : artist);
                            if (ActivePartyService.currentPartyId != null &&
                                ActivePartyService.currentPartyId!.isNotEmpty) {
                              WishManagementService.showConfirmDeleteGroupedDialog(
                                ctx,
                                ids,
                                delDisplayText,
                                ActivePartyService.currentPartyId!,
                              );
                            } else {
                              final loc = AppLocalizations.of(ctx)!;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(loc.error_no_party_id_found),
                                  backgroundColor: UIConstants.frameNoParty,
                                ),
                              );
                            }
                          },
                        ),
                        if (isUserBlocked)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: UIConstants.frameNoParty,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.block,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    guestBadgeText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (totalPages > 1)
            _buildPaginationButtons(_currentPage, totalPages, context),
          const SizedBox(height: UIConstants.kFooterPadding * 2),
        ],
      ),
    );
  }

  /// [dialogContext]: Detail-Modal (wird nach erfolgreichem Update geschlossen).
  /// [listContext]: Listen-/Seiten-Kontext für SnackBar (bleibt nach Pop gültig).
  Future<void> _restoreGroupedWishes(
    BuildContext dialogContext,
    BuildContext listContext,
    List<String> docIds,
    String displayText,
  ) async {
    final l = AppLocalizations.of(listContext)!;
    try {
      if (ActivePartyService.currentPartyId != null &&
          ActivePartyService.currentPartyId!.isNotEmpty) {
        await WishManagementService.updateGroupedStatus(
          docIds,
          'pending',
          ActivePartyService.currentPartyId!,
        );
        // 1) Bestätigungsdialog ist bereits zu; 2) Detail-Dialog schließen
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        if (!listContext.mounted) return;
        ScaffoldMessenger.of(listContext).showSnackBar(
          SnackBar(
            content: Text(
              l.wish_restored_count(docIds.length),
            ),
            backgroundColor: UIConstants.frameGespielt,
          ),
        );
        // Tab „Offen“ (Index 0 in DJ-VibesBox)
        widget.onWishRestoredToOpen?.call();
      } else {
        throw Exception(l.error_no_party_id_found);
      }
    } catch (e) {
      if (listContext.mounted) {
        ScaffoldMessenger.of(listContext).showSnackBar(
          SnackBar(
            content: Text(l.error_with_message(e.toString())),
            backgroundColor: UIConstants.frameNoParty,
          ),
        );
      }
    }
  }

  Future<int> _getBlockHistoryCount(String clientId) async {
    if (clientId.isEmpty) {
      return 0;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return 0;
      }

      final historyQuery = await FirebaseFirestore.instance
          .collection('block_history')
          .where('client_id', isEqualTo: clientId)
          .where('dj_id', isEqualTo: user.uid)
          .get();

      return historyQuery.docs.length;
    } catch (e) {
      debugLog('⚠️ Fehler beim Abrufen der Block-Historie: $e');
      return 0;
    }
  }
}
