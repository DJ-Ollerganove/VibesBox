import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/song_request.dart';
import '../services/active_party_service.dart';
import '../services/history_pagination_service.dart';
import '../services/results_per_page_service.dart';
import '../services/wish_management_service.dart';
import '../utils/pre_wish_helper.dart';
import '../utils/string_utils.dart';
import '../utils/ui_constants.dart';
import '../widgets/pre_wish_action_dialogs.dart';
import '../utils/wish_grouping_helper.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/wish_card.dart';
import '../main.dart' show buildFirebaseErrorWidget;

/// Übersicht aller Vorab-Wünsche einer Party (Queue + freigegebene; Rahmen je nach Status).
class PreWishesOverviewDialog extends StatefulWidget {
  const PreWishesOverviewDialog({
    super.key,
    required this.partyId,
    required this.partyName,
  });

  final String partyId;
  final String partyName;

  static Future<void> show(
    BuildContext context, {
    required String partyId,
    required String partyName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => PreWishesOverviewDialog(
        partyId: partyId,
        partyName: partyName,
      ),
    );
  }

  @override
  State<PreWishesOverviewDialog> createState() =>
      _PreWishesOverviewDialogState();
}

class _PreWishesOverviewDialogState extends State<PreWishesOverviewDialog> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadResultsPerPage();
  }

  Future<void> _loadResultsPerPage() async {
    final v = await ResultsPerPageService.load();
    if (mounted) {
      setState(() {
        _resultsPerPage = v;
        _currentPage = 1;
      });
    }
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

  List<SongRequest> _primaryPreWishes(List<QueryDocumentSnapshot> docs) {
    final wishes = <SongRequest>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (!PreWishHelper.isPreWishInOverview(data)) continue;
      try {
        wishes.add(SongRequest.fromDocument(doc));
      } catch (_) {
        continue;
      }
    }
    return WishGroupingHelper.withoutDuplicateShadowDocuments(wishes);
  }

  ({
    List<Map<String, dynamic>> allGroups,
    Map<String, SongRequest> firstRequests,
    Map<String, List<String>> docIds,
  })?
  _groupPreWishes(List<SongRequest> primary) {
    if (primary.isEmpty) return null;

    final sorted = primary.toList()
      ..sort((a, b) {
        final ta = a.createdAt?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });

    final groupedResult = WishGroupingHelper.groupWishes(
      sorted,
      sessionPartyId: widget.partyId,
      allRequestsForTimestamps: sorted,
    );
    final groupedFirstRequests =
        groupedResult['firstRequests'] as Map<String, SongRequest>;
    final groupedDocIds = Map<String, List<String>>.from(
      groupedResult['docIds'] as Map<String, List<String>>,
    );
    final allGroups = WishGroupingHelper.groupsWithUniqueDocumentIds(
      groupedResult['groups'] as List<Map<String, dynamic>>,
      groupedDocIds,
    );

    return (
      allGroups: allGroups,
      firstRequests: groupedFirstRequests,
      docIds: groupedDocIds,
    );
  }

  Widget _buildPaginationFooter({
    required int currentPage,
    required int totalPages,
    required int totalItems,
  }) {
    final l = AppLocalizations.of(context)!;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    final page = currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final hasMultiplePages = totalPages > 1;
    final countLabel = totalItems == 1
        ? l.pre_wish_count_singular
        : l.pre_wish_count_plural.replaceAll('{count}', '$totalItems');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: UIConstants.djShellPageBackground.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: UIConstants.colorPreWish.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${l.history_page} $page / ${totalPages > 0 ? totalPages : 1}'
            ' · $countLabel'
            ' · $_resultsPerPage ${l.results_per_page}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              height: 1.3,
            ),
          ),
          if (hasMultiplePages) ...[
            const SizedBox(height: 8),
            Row(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      HistoryPaginationService.hasPreviousPage(page)
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    side: BorderSide(
                      color: UIConstants.colorPreWish.withValues(alpha: 0.8),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      HistoryPaginationService.hasNextPage(page, totalPages)
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    side: BorderSide(
                      color: UIConstants.colorPreWish.withValues(alpha: 0.8),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
        decoration: BoxDecoration(
          gradient: UIConstants.colorGreyGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UIConstants.colorPreWish, width: 2),
        ),
        child: SizedBox(
          height: maxH,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.pre_wishes_overview_title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (widget.partyName.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.partyName,
                      style: TextStyle(
                        color: UIConstants.colorPreWish.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: WishManagementService.getPreWishOverviewStream(
                    widget.partyId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: buildFirebaseErrorWidget(snapshot.error!),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final primary = _primaryPreWishes(snapshot.data!.docs);
                    if (primary.isEmpty) {
                      return Center(child: EmptyListMessage());
                    }

                    final grouped = _groupPreWishes(primary);
                    if (grouped == null) {
                      return Center(child: EmptyListMessage());
                    }

                    final allGroups = grouped.allGroups;
                    final groupedFirstRequests = grouped.firstRequests;
                    final groupedDocIds = grouped.docIds;

                    final totalPages =
                        HistoryPaginationService.calculateTotalPages(
                      allGroups.length,
                      itemsPerPage: _resultsPerPage,
                    );
                    final effectivePage = _currentPage.clamp(
                      1,
                      totalPages > 0 ? totalPages : 1,
                    );

                    if (_currentPage > totalPages && totalPages > 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _currentPage = totalPages);
                        }
                      });
                    }

                    final pageGroups = HistoryPaginationService.getItemsForPage(
                      allGroups,
                      effectivePage,
                      itemsPerPage: _resultsPerPage,
                    );

                    final startIndex =
                        HistoryPaginationService.calculateStartIndex(
                      effectivePage,
                      itemsPerPage: _resultsPerPage,
                    );

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            itemCount: pageGroups.length,
                            itemBuilder: (context, index) {
                              final entry = pageGroups[index];
                              final groupKey = entry['key'] as String;
                              final data =
                                  entry['data'] as Map<String, dynamic>;
                              final docIds =
                                  groupedDocIds[groupKey] ?? const <String>[];
                              if (docIds.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              final isNew = docIds.any(
                                (id) => !ActivePartyService.seenWishIds
                                    .contains(id),
                              );
                              final number =
                                  allGroups.length - (startIndex + index);
                              final titleDisp = unescapeHtml(
                                (data['title'] ?? '') as String,
                              );
                              final artistDisp = unescapeHtml(
                                (data['artist'] ?? '') as String,
                              );
                              final displayText = titleDisp.isNotEmpty &&
                                      artistDisp.isNotEmpty
                                  ? '$titleDisp - $artistDisp'
                                  : (titleDisp.isNotEmpty
                                      ? titleDisp
                                      : artistDisp);

                              final publishedToOpen =
                                  PreWishHelper.isPublishedPreWish(data);

                              return WishCard(
                                key: ValueKey(
                                  'pre-${widget.partyId}-${docIds.first}',
                                ),
                                request: groupedFirstRequests[groupKey],
                                groupedData: data,
                                docIds: docIds,
                                type: WishCardType.offen,
                                number: number,
                                isNew: isNew,
                                isPreWishOverviewMode: true,
                                listBorderColorOverride: publishedToOpen
                                    ? UIConstants.frameOffen
                                    : UIConstants.framePreWish,
                                detailDialogBorderColor: publishedToOpen
                                    ? UIConstants.frameOffen
                                    : UIConstants.framePreWish,
                                onPublishPreWish: publishedToOpen
                                    ? null
                                    : (ctx, ids) async {
                                        final confirmed =
                                            await PreWishActionDialogs
                                                .showPublishConfirm(
                                          ctx,
                                          displayText: displayText,
                                        );
                                        if (confirmed != true ||
                                            !ctx.mounted) {
                                          return;
                                        }
                                        try {
                                          await WishManagementService
                                              .publishPreWishToOpen(
                                            ids,
                                            widget.partyId,
                                          );
                                        } catch (e) {
                                          if (!ctx.mounted) return;
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${AppLocalizations.of(ctx)!.error}: $e',
                                              ),
                                              backgroundColor:
                                                  UIConstants.frameNoParty,
                                            ),
                                          );
                                        }
                                      },
                                onDelete: (ctx, ids) async {
                                  final confirmed =
                                      await PreWishActionDialogs
                                          .showDeleteConfirm(
                                    ctx,
                                    displayText: displayText,
                                  );
                                  if (confirmed != true || !ctx.mounted) {
                                    return;
                                  }
                                  try {
                                    await WishManagementService
                                        .deleteGroupedWishes(
                                      ids,
                                      widget.partyId,
                                    );
                                  } catch (e) {
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${AppLocalizations.of(ctx)!.error}: $e',
                                        ),
                                        backgroundColor:
                                            UIConstants.frameNoParty,
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        _buildPaginationFooter(
                          currentPage: effectivePage,
                          totalPages: totalPages,
                          totalItems: allGroups.length,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
