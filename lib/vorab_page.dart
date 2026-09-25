import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'main.dart' show buildFirebaseErrorWidget;
import 'models/song_request.dart';
import 'services/active_party_service.dart';
import 'services/duplicate_check_service.dart';
import 'services/history_pagination_service.dart';
import 'services/results_per_page_service.dart';
import 'services/user_blocking_service.dart';
import 'services/wish_management_service.dart';
import 'utils/pre_wish_helper.dart';
import 'utils/string_utils.dart';
import 'utils/ui_constants.dart';
import 'utils/wish_grouping_helper.dart';
import 'utils/wish_party_filter.dart';
import 'widgets/empty_list_message.dart';
import 'widgets/dj_wish_party_scope.dart';
import 'widgets/pre_wish_action_dialogs.dart';
import 'widgets/pro_promotion_banner.dart';
import 'widgets/sticky_pagination_layout.dart';
import 'widgets/wish_card.dart';
import 'services/user_service.dart';
import 'utils/free_list_pro_promo.dart';
import 'app_scaffold_messenger.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

/// DJ-Tab: Vorab-Wünsche, die noch nicht in „Offen“ freigegeben wurden.
class VorabPage extends StatefulWidget {
  final List<SongRequest> requests;
  final VoidCallback? onPageOpened;

  const VorabPage({
    super.key,
    required this.requests,
    this.onPageOpened,
  });

  @override
  State<VorabPage> createState() => _VorabPageState();
}

class _VorabPageState extends State<VorabPage>
    with AutomaticKeepAliveClientMixin {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  final ScrollController _scrollController = ScrollController();

  String? _cachedStreamPartyId;
  Stream<QuerySnapshot>? _cachedPreWishStream;

  Stream<QuerySnapshot> _preWishStreamForParty(String partyId) {
    if (_cachedStreamPartyId != partyId) {
      _cachedStreamPartyId = partyId;
      _cachedPreWishStream =
          WishManagementService.watchPreWishOverview(partyId);
    }
    return _cachedPreWishStream!;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    DuplicateCheckService.ensurePartySettingsLoaded();
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
    widget.onPageOpened?.call();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() => _currentPage--);
      _scrollToTop();
    }
  }

  void _goToNextPage(int totalPages) {
    if (_currentPage < totalPages) {
      setState(() => _currentPage++);
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildPaginationButtons(
    int currentPage,
    int totalPages,
    BuildContext context,
  ) {
    final l = AppLocalizations.of(context)!;
    final isRtl = VbTextDirection.isRtl(context);

    if (totalPages <= 1) return const SizedBox.shrink();

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
              disabledBackgroundColor:
                  UIConstants.colorGrey.withValues(alpha: 0.4),
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
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white),
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
              disabledBackgroundColor:
                  UIConstants.colorGrey.withValues(alpha: 0.4),
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

  List<SongRequest> _queuedPreWishes(List<QueryDocumentSnapshot> docs) {
    final wishes = <SongRequest>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (!PreWishHelper.isQueuedPreWish(data)) continue;
      try {
        wishes.add(SongRequest.fromDocument(doc));
      } catch (_) {
        continue;
      }
    }
    return WishGroupingHelper.withoutDuplicateShadowDocuments(wishes);
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
        emptyKey: 'vorab-none',
        builder: (context, partyId, visibility) {
          return StreamBuilder<QuerySnapshot>(
            stream: _preWishStreamForParty(partyId),
            builder: (context, snapshot) =>
                _buildList(context, snapshot, partyId),
          );
        },
      ),
    );
  }

  Widget _buildList(
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
            SizedBox(height: 24),
            EmptyListMessage(),
            SizedBox(height: UIConstants.kFooterPadding * 2),
          ],
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(child: buildFirebaseErrorWidget(snapshot.error!));
    }

    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final wishesDocs = snapshot.data!.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return wishDocDataMatchesPartyId(data, partyId);
    }).toList();

    final queuedWishes = _queuedPreWishes(wishesDocs);
    if (queuedWishes.isEmpty) {
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
            SizedBox(height: 24),
            EmptyListMessage(),
            SizedBox(height: UIConstants.kFooterPadding * 2),
          ],
        ),
      );
    }

    final sortedWishes = queuedWishes.toList()
      ..sort((a, b) {
        final tsA =
            a.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tsB =
            b.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tsB.compareTo(tsA);
      });

    final groupedResult = WishGroupingHelper.groupWishes(
      sortedWishes,
      sessionPartyId: partyId,
      allRequestsForTimestamps: queuedWishes,
    );
    final groupedFirstRequests =
        groupedResult['firstRequests'] as Map<String, SongRequest>;
    final groupedDocIds = Map<String, List<String>>.from(
      groupedResult['docIds'] as Map<String, List<String>>,
    );
    final allGroupedList = WishGroupingHelper.groupsWithUniqueDocumentIds(
      groupedResult['groups'] as List<Map<String, dynamic>>,
      groupedDocIds,
    );

    final totalPages = HistoryPaginationService.calculateTotalPages(
      allGroupedList.length,
      itemsPerPage: _resultsPerPage,
    );

    if (_currentPage > totalPages && totalPages > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = totalPages);
      });
    }

    final paginatedGroupedList = HistoryPaginationService.getItemsForPage(
      allGroupedList,
      _currentPage > 0 ? _currentPage : 1,
      itemsPerPage: _resultsPerPage,
    );

    final bottomPadding = totalPages > 1 ? 8.0 : 150.0;

    return SingleChildScrollView(
      key: PageStorageKey<String>('vorab_scroll_$partyId'),
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
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 8.0, bottom: bottomPadding),
              itemCount: () {
                final len = paginatedGroupedList.length;
                final isFree =
                    UserService().sessionProStatus.value?.isActive != true;
                return FreeListProPromo.itemCount(len, isFree: isFree);
              }(),
              itemBuilder: (context, index) {
                final len = paginatedGroupedList.length;
                final isFree =
                    UserService().sessionProStatus.value?.isActive != true;
                if (FreeListProPromo.isPromoIndex(index, len, isFree: isFree)) {
                  return const ProPromotionBanner();
                }
                final dataIndex =
                    FreeListProPromo.dataIndex(index, len, isFree: isFree);
                final groupEntry = paginatedGroupedList[dataIndex];
                final groupKey = groupEntry['key'] as String;
                final data = groupEntry['data'] as Map<String, dynamic>;
                final docIds = groupedDocIds[groupKey] ?? const <String>[];
                if (docIds.isEmpty) return const SizedBox.shrink();

                final primaryDocId = docIds.first;
                final number = allGroupedList.length -
                    (HistoryPaginationService.calculateStartIndex(
                          _currentPage > 0 ? _currentPage : 1,
                          itemsPerPage: _resultsPerPage,
                        ) +
                        dataIndex);

                final isNew = docIds.any(
                  (docId) => !ActivePartyService.seenWishIds.contains(docId),
                );

                final titleDisp =
                    unescapeHtml((data['title'] ?? '') as String);
                final artistDisp =
                    unescapeHtml((data['artist'] ?? '') as String);
                final displayText = titleDisp.isNotEmpty && artistDisp.isNotEmpty
                    ? '$titleDisp - $artistDisp'
                    : (titleDisp.isNotEmpty ? titleDisp : artistDisp);

                return WishCard(
                  key: ValueKey('vorab-$partyId-$primaryDocId'),
                  request: groupedFirstRequests[groupKey],
                  groupedData: data,
                  docIds: docIds,
                  type: WishCardType.offen,
                  number: number,
                  isNew: isNew,
                  isPreWishOverviewMode: true,
                  listBorderColorOverride: UIConstants.framePreWish,
                  detailDialogBorderColor: UIConstants.framePreWish,
                  onPublishPreWish: (ctx, ids) async {
                    final confirmed = await PreWishActionDialogs.showPublishConfirm(
                      ctx,
                      displayText: displayText,
                    );
                    if (confirmed != true || !ctx.mounted) return;
                    try {
                      await WishManagementService.publishPreWishToOpen(
                        ids,
                        partyId,
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      showVibesSnackBar(ctx, 
                        SnackBar(
                          content: Text('${AppLocalizations.of(ctx)!.error}: $e'),
                          backgroundColor: UIConstants.frameNoParty,
                        ),
                      );
                    }
                  },
                  onPlay: (ctx, ids) {
                    if (partyId.isEmpty) return;
                    WishManagementService.showConfirmUpdateGroupedStatusDialog(
                      ctx,
                      ids,
                      'played',
                      AppLocalizations.of(ctx)!.mark_as_played,
                      displayText,
                      partyId,
                    );
                  },
                  onReject: (ctx, ids) {
                    if (partyId.isEmpty) return;
                    WishManagementService.showConfirmUpdateGroupedStatusDialog(
                      ctx,
                      ids,
                      'rejected',
                      AppLocalizations.of(ctx)!.reject,
                      displayText,
                      partyId,
                    );
                  },
                  onDelete: (ctx, ids) {
                    if (partyId.isEmpty) return;
                    WishManagementService.showConfirmDeleteGroupedDialog(
                      ctx,
                      ids,
                      displayText,
                      partyId,
                    );
                  },
                  onBlockGrouped: (ctx, req, dataMap, ids) =>
                      UserBlockingService.showGroupedBlockDialog(
                    ctx,
                    req,
                    dataMap,
                    ids,
                  ),
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
}
