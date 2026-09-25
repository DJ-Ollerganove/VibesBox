import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/saved_track_model.dart';
import '../services/history_pagination_service.dart';
import '../services/results_per_page_service.dart';
import '../services/dj_pro_session_service.dart';
import '../services/saved_tracks_service.dart';
import '../services/user_service.dart';
import '../utils/ui_constants.dart';
import '../app_scaffold_messenger.dart';
import '../widgets/custom_page_header.dart';
import '../widgets/settings_help_dialog.dart';
import '../widgets/free_feature_locked.dart';
import '../widgets/pro_promotion_banner.dart';
import '../widgets/pagination_control.dart';

const double _kNrColumnWidth = 52;
const double _kDeleteColumnWidth = 36;
const double _kSortArrowSlot = 16;

class SavedTracksPage extends StatefulWidget {
  const SavedTracksPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<SavedTracksPage> createState() => _SavedTracksPageState();
}

class _SavedTracksPageState extends State<SavedTracksPage> {
  MerklisteSortColumn _sortColumn = MerklisteSortColumn.nr;
  bool _sortAscending = false;
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SavedTracksService.startWatchingForCurrentUser();
    _reloadResultsPerPage();
  }

  @override
  void didUpdateWidget(covariant SavedTracksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _reloadResultsPerPage();
    }
  }

  Future<void> _reloadResultsPerPage() async {
    final v = await ResultsPerPageService.load();
    if (!mounted) return;
    setState(() => _resultsPerPage = v);
  }

  int _clampPage(int page, int totalPages) {
    if (totalPages <= 0) return 1;
    if (page < 1) return 1;
    if (page > totalPages) return totalPages;
    return page;
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

  void _onHeaderTap(MerklisteSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = column != MerklisteSortColumn.nr;
      }
      _currentPage = 1;
    });
  }

  int _displayRowNumber({
    required int indexInPage,
    required int totalTracks,
    required int rowOffset,
  }) {
    final position = rowOffset + indexInPage;
    if (_sortColumn == MerklisteSortColumn.nr && _sortAscending) {
      return totalTracks - position + 1;
    }
    return position;
  }

  List<SavedTrack> _sortedTracks(List<SavedTrack> tracks) {
    final list = List<SavedTrack>.from(tracks);
    int compare<T extends Comparable<T>>(T a, T b) =>
        _sortAscending ? a.compareTo(b) : b.compareTo(a);

    list.sort((a, b) {
      switch (_sortColumn) {
        case MerklisteSortColumn.nr:
          return compare(a.bookmarkedAt, b.bookmarkedAt);
        case MerklisteSortColumn.song:
          final byTitle =
              compare(a.title.toLowerCase(), b.title.toLowerCase());
          if (byTitle != 0) return byTitle;
          return compare(a.artist.toLowerCase(), b.artist.toLowerCase());
      }
    });
    return list;
  }

  Future<void> _confirmAndRemoveTrack(SavedTrack track) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          title: Text(
            l.saved_tracks_remove_confirm_title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            l.saved_tracks_remove_confirm_body(track.title, track.artist),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(
              color: UIConstants.freeLimitBorderRed,
              width: 2,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                l.no,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l.yes,
                style: const TextStyle(
                  color: UIConstants.freeLimitBorderRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _removeTrack(track);
    }
  }

  Future<void> _removeTrack(SavedTrack track) async {
    await SavedTracksService.removeTrack(
      title: track.title,
      artist: track.artist,
    );
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    showVibesSnackBar(
      context,
      SnackBar(
        content: Text(l.saved_tracks_removed_snackbar),
        backgroundColor: UIConstants.appGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildTrackList(
    BuildContext context,
    AppLocalizations l,
    List<SavedTrack> rawTracks,
  ) {
    final tracks = _sortedTracks(rawTracks);
    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.saved_tracks_empty,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final totalPages = HistoryPaginationService.calculateTotalPages(
      tracks.length,
      itemsPerPage: _resultsPerPage,
    );
    final effectivePage = _clampPage(_currentPage, totalPages);
    if (effectivePage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = effectivePage);
      });
    }
    final pageItems = HistoryPaginationService.getItemsForPage(
      tracks,
      effectivePage,
      itemsPerPage: _resultsPerPage,
    );
    final rowOffset = (effectivePage - 1) * _resultsPerPage;

    return ColoredBox(
      color: UIConstants.djShellPageBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              itemCount: pageItems.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _MerklisteTableHeader(
                    sortColumn: _sortColumn,
                    sortAscending: _sortAscending,
                    onTap: _onHeaderTap,
                  );
                }
                final track = pageItems[index - 1];
                final rowNumber = _displayRowNumber(
                  indexInPage: index,
                  totalTracks: tracks.length,
                  rowOffset: rowOffset,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 1)
                      const Divider(height: 1, color: Colors.white24),
                    _MerklisteTableRow(
                      rowNumber: rowNumber,
                      track: track,
                      onRemove: () => _confirmAndRemoveTrack(track),
                    ),
                  ],
                );
              },
            ),
          ),
          if (totalPages > 1)
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 8,
              ),
              child: PaginationControl(
                currentPage: effectivePage,
                totalPages: totalPages,
                onPreviousPage: _goToPreviousPage,
                onNextPage: () => _goToNextPage(totalPages),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return ValueListenableBuilder(
      valueListenable: UserService().currentUser,
      builder: (context, userModel, _) {
        return ValueListenableBuilder<SessionProStatus?>(
          valueListenable: DjProSessionService.instance.sessionProStatus,
          builder: (context, session, __) {
            final isFree = DjProSessionService.instance.isFreeDj;
            return ValueListenableBuilder<List<SavedTrack>>(
              valueListenable: SavedTracksService.savedTracks,
              builder: (context, debugTracks, _) {
                if (isFree) {
                  return ColoredBox(
                    color: UIConstants.djShellPageBackground,
                    child: SafeArea(
                      child: Column(
                        children: [
                          CustomPageHeader(
                            icon: Icons.bookmark_outline,
                            title: l.saved_tracks_page_title,
                            onInfoPressed: () => showPageInfoHelp(
                              context,
                              titleKey: 'saved_tracks_page_title',
                              prefix: 'info_page_saved_tracks',
                            ),
                          ),
                          const ProPromotionBanner(),
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bookmark_outline,
                                      size: 56,
                                      color: UIConstants.appGreen
                                          .withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l.free_feature_saved_tracks_title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l.free_feature_saved_tracks_description,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: () =>
                                          FreeFeatureLockedDialog.show(
                                        context,
                                        title:
                                            l.free_feature_saved_tracks_title,
                                        description: l
                                            .free_feature_saved_tracks_description,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: UIConstants.appGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text(l.getVibesboxPro),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (uid == null || uid.isEmpty) {
                  return ColoredBox(
                    color: UIConstants.djShellPageBackground,
                    child: SafeArea(
                      child: CustomPageHeader(
                        icon: Icons.bookmark_outline,
                        title: l.saved_tracks_page_title,
                        onInfoPressed: () => showPageInfoHelp(
                          context,
                          titleKey: 'saved_tracks_page_title',
                          prefix: 'info_page_saved_tracks',
                        ),
                      ),
                    ),
                  );
                }

                return ColoredBox(
                  color: UIConstants.djShellPageBackground,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomPageHeader(
                          icon: Icons.bookmark_outline,
                          title: l.saved_tracks_page_title,
                          onInfoPressed: () => showPageInfoHelp(
                            context,
                            titleKey: 'saved_tracks_page_title',
                            prefix: 'info_page_saved_tracks',
                          ),
                        ),
                        Expanded(
                          child: _buildTrackList(context, l, debugTracks),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MerklisteTableHeader extends StatelessWidget {
  const _MerklisteTableHeader({
    required this.sortColumn,
    required this.sortAscending,
    required this.onTap,
  });

  final MerklisteSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<MerklisteSortColumn> onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: UIConstants.appGreen.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SortableHeaderCell(
            width: _kNrColumnWidth,
            label: l.saved_tracks_col_nr,
            column: MerklisteSortColumn.nr,
            active: sortColumn,
            ascending: sortAscending,
            onTap: onTap,
          ),
          Expanded(
            child: _SortableHeaderCell(
              label: l.saved_tracks_col_song,
              column: MerklisteSortColumn.song,
              active: sortColumn,
              ascending: sortAscending,
              onTap: onTap,
            ),
          ),
          const SizedBox(width: _kDeleteColumnWidth),
        ],
      ),
    );
  }
}

class _SortableHeaderCell extends StatelessWidget {
  const _SortableHeaderCell({
    required this.label,
    required this.column,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.width,
  });

  final String label;
  final MerklisteSortColumn column;
  final MerklisteSortColumn active;
  final bool ascending;
  final ValueChanged<MerklisteSortColumn> onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isActive = active == column;
    final color = isActive ? Colors.lightBlueAccent : Colors.white;
    final content = InkWell(
      onTap: () => onTap(column),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: _kSortArrowSlot,
              height: 14,
              child: Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isActive ? color : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: content);
    }
    return content;
  }
}

class _MerklisteTableRow extends StatelessWidget {
  const _MerklisteTableRow({
    required this.rowNumber,
    required this.track,
    required this.onRemove,
  });

  final int rowNumber;
  final SavedTrack track;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final artist = track.artist.trim();
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _kNrColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 1, right: _kSortArrowSlot),
              child: Text(
                '$rowNumber',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: _kDeleteColumnWidth,
            child: Align(
              alignment: Alignment.topCenter,
              child: IconButton(
                tooltip: l.saved_tracks_remove_tooltip,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                alignment: Alignment.topCenter,
                onPressed: onRemove,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
