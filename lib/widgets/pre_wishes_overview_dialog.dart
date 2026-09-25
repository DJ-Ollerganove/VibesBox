import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/song_request.dart';
import '../services/active_party_service.dart';
import '../services/history_pagination_service.dart';
import '../services/party_secure_service.dart';
import '../services/pre_wish_export_service.dart';
import '../services/results_per_page_service.dart';
import '../services/wish_management_service.dart';
import '../utils/pre_wish_export_helper.dart';
import '../utils/pre_wish_helper.dart';
import '../utils/string_utils.dart';
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';
import '../widgets/pre_wishes_paused_dj_banner.dart';
import '../widgets/pre_wish_action_dialogs.dart';
import '../widgets/pre_wish_export_format_dialog.dart';
import '../utils/wish_grouping_helper.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/wish_card.dart';
import '../main.dart' show buildFirebaseErrorWidget;
import '../app_scaffold_messenger.dart';

/// Übersicht aller Vorab-Wünsche einer Party (Queue + freigegebene; Rahmen je nach Status).
class PreWishesOverviewDialog extends StatefulWidget {
  const PreWishesOverviewDialog({
    super.key,
    required this.partyId,
    required this.partyName,
    this.partyStartDate,
  });

  final String partyId;
  final String partyName;
  final DateTime? partyStartDate;

  static Future<void> show(
    BuildContext context, {
    required String partyId,
    required String partyName,
    DateTime? partyStartDate,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => PreWishesOverviewDialog(
        partyId: partyId,
        partyName: partyName,
        partyStartDate: partyStartDate,
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
  StreamSubscription<QuerySnapshot>? _overviewSub;
  List<Map<String, dynamic>> _exportGroups = const [];
  bool _canExport = false;
  bool _exportInFlight = false;
  bool _pauseToggleInFlight = false;

  @override
  void initState() {
    super.initState();
    _loadResultsPerPage();
    _overviewSub =
        WishManagementService.watchPreWishOverview(widget.partyId).listen(
      (snapshot) {
        final primary = _primaryPreWishes(snapshot.docs);
        final grouped = _groupPreWishes(primary);
        if (!mounted) return;
        setState(() {
          _exportGroups = grouped?.allGroups ?? const [];
          _canExport = _exportGroups.isNotEmpty;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _exportGroups = const [];
          _canExport = false;
        });
      },
    );
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
    unawaited(_overviewSub?.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  DateTime get _partyStartForExport =>
      widget.partyStartDate ?? DateTime.now();

  Future<void> _exportPreWishes() async {
    if (!_canExport || _exportInFlight || _exportGroups.isEmpty) return;

    final format = await PreWishExportFormatDialog.show(context);
    if (format == null || !mounted) return;

    setState(() => _exportInFlight = true);
    try {
      final l = AppLocalizations.of(context)!;
      final songs = PreWishExportHelper.songsFromGrouped(
        allGroups: _exportGroups,
        l: l,
      );
      if (songs.isEmpty) return;

      await PreWishExportService.shareExport(
        context: context,
        format: format,
        partyName: widget.partyName,
        partyStartDate: _partyStartForExport,
        songs: songs,
      );
    } catch (e, st) {
      debugLog('PreWishesOverviewDialog export: $e\n$st');
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.pre_wish_export_failed),
          backgroundColor: UIConstants.frameNoParty,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportInFlight = false);
    }
  }

  Widget _buildOverviewPausedBanner() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('parties')
          .doc(widget.partyId)
          .snapshots(),
      builder: (context, partySnap) {
        if (!PreWishHelper.arePreWishesPaused(partySnap.data?.data())) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: const PreWishesPausedDjBanner(),
        );
      },
    );
  }

  bool _partyNotStartedYet(Map<String, dynamic>? data) {
    final start = widget.partyStartDate ??
        (data != null ? PreWishHelper.partyStartFromData(data) : null);
    if (start == null) return false;
    return DateTime.now().isBefore(start);
  }

  void _showPreWishesPauseConfirm(
    BuildContext context,
    bool currentlyPaused,
  ) {
    final l = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: UIConstants.colorPreWish.withValues(alpha: 0.85),
              width: 2,
            ),
          ),
          title: Text(
            currentlyPaused
                ? l.pre_wishes_resume_confirm_title
                : l.pre_wishes_pause_confirm_title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            currentlyPaused
                ? l.pre_wishes_resume_confirm_body
                : l.pre_wishes_pause_confirm_body,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l.cancel,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_togglePreWishesPaused(currentlyPaused));
              },
              child: Text(
                currentlyPaused ? l.pre_wishes_resume : l.pre_wishes_pause,
                style: TextStyle(
                  color: UIConstants.colorPreWish.withValues(alpha: 0.95),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _togglePreWishesPaused(bool currentlyPaused) async {
    if (_pauseToggleInFlight) return;
    setState(() => _pauseToggleInFlight = true);
    try {
      await PartySecureService.instance.updateParty(
        partyId: widget.partyId,
        patch: {'pre_wishes_paused': !currentlyPaused},
      );
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(
            currentlyPaused
                ? l.pre_wishes_resumed_success
                : l.pre_wishes_paused_success,
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.snackbar_error_details('$e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _pauseToggleInFlight = false);
    }
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
                    if (_canExport)
                      TextButton.icon(
                        onPressed: _exportInFlight ? null : _exportPreWishes,
                        icon: _exportInFlight
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: UIConstants.appGreen
                                      .withValues(alpha: 0.9),
                                ),
                              )
                            : Icon(
                                Icons.upload_file,
                                size: 18,
                                color: UIConstants.appGreen
                                    .withValues(alpha: 0.95),
                              ),
                        label: Text(
                          l.pre_wish_export,
                          style: TextStyle(
                            color: UIConstants.appGreen
                                .withValues(alpha: 0.95),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('parties')
                          .doc(widget.partyId)
                          .snapshots(),
                      builder: (context, partySnap) {
                        final partyData = partySnap.data?.data();
                        if (!_partyNotStartedYet(partyData)) {
                          return const SizedBox.shrink();
                        }
                        final paused =
                            partyData?['pre_wishes_paused'] == true;
                        return IconButton(
                          tooltip: paused
                              ? l.pre_wishes_resume
                              : l.pre_wishes_pause,
                          onPressed: _pauseToggleInFlight
                              ? null
                              : () => _showPreWishesPauseConfirm(context, paused),
                          icon: Icon(
                            paused ? Icons.play_arrow : Icons.pause,
                            color: UIConstants.colorPreWish.withValues(alpha: 0.95),
                          ),
                        );
                      },
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
              _buildOverviewPausedBanner(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: WishManagementService.watchPreWishOverview(
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
                                          showVibesSnackBar(ctx, 
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
                                    showVibesSnackBar(ctx, 
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
