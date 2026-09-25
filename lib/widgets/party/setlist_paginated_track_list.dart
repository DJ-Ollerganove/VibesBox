import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/locale_helper.dart';
import '../../l10n/text_direction_helper.dart';
import '../../models/event_setlist_track.dart';
import '../../services/history_pagination_service.dart';
import '../../services/results_per_page_service.dart';
import '../../services/setlist_reason_localize_service.dart';
import '../../utils/ui_constants.dart';
import 'setlist_track_action_icons.dart';

/// Setlisten-Anzeige mit derselben Seitengröße wie Offen/Vorab/History.
class SetlistPaginatedTrackList extends StatefulWidget {
  const SetlistPaginatedTrackList({
    super.key,
    required this.tracks,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
    this.padForAppFooter = false,
    this.onEdit,
    this.onDelete,
    this.onReorder,
    this.onMoveToOpen,
    this.onMarkPlayed,
    this.onReasonsLocalized,
    this.omitMovedTracks = false,
  });

  final List<EventSetlistTrack> tracks;
  final EdgeInsets padding;
  /// Platz über der Musikerkennungs-Leiste (Wunschbox-Tab).
  final bool padForAppFooter;
  final void Function(int index, EventSetlistTrack track)? onEdit;
  final void Function(int index, EventSetlistTrack track)? onDelete;
  /// Neue Reihenfolge der kompletten Track-Liste (inkl. moved).
  final void Function(List<EventSetlistTrack> tracks)? onReorder;
  final void Function(int index, EventSetlistTrack track)? onMoveToOpen;
  final void Function(int index, EventSetlistTrack track)? onMarkPlayed;
  /// Nach Batch-Übersetzung der Begründungen — zum Speichern auf der Liste.
  final Future<void> Function(List<EventSetlistTrack> tracks)?
      onReasonsLocalized;
  /// Party-Reiter: nach Offen/Gespielt verschobene Titel nicht anzeigen.
  final bool omitMovedTracks;

  @override
  State<SetlistPaginatedTrackList> createState() =>
      _SetlistPaginatedTrackListState();
}

class _SetlistPaginatedTrackListState extends State<SetlistPaginatedTrackList> {
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  int _currentPage = 1;
  int? _selectedIndex;
  bool _actionsLocked = false;
  Timer? _actionsUnlockTimer;
  List<EventSetlistTrack>? _overlay;
  bool _localizing = false;

  List<EventSetlistTrack> get _tracks => _overlay ?? widget.tracks;

  List<(int, EventSetlistTrack)> get _visibleIndexed {
    final all = _tracks;
    final out = <(int, EventSetlistTrack)>[];
    for (var i = 0; i < all.length; i++) {
      if (widget.omitMovedTracks && all[i].moved) continue;
      out.add((i, all[i]));
    }
    return out;
  }

  bool get _hasActions =>
      widget.onEdit != null ||
      widget.onDelete != null ||
      widget.onReorder != null ||
      widget.onMoveToOpen != null ||
      widget.onMarkPlayed != null;

  @override
  void initState() {
    super.initState();
    LocaleHelper.localeNotifier.addListener(_localize);
    ResultsPerPageService.load().then((v) {
      if (!mounted) return;
      setState(() => _resultsPerPage = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _localize());
  }

  @override
  void dispose() {
    _actionsUnlockTimer?.cancel();
    LocaleHelper.localeNotifier.removeListener(_localize);
    super.dispose();
  }

  void _onSelectTrack(int globalIndex) {
    final next = _selectedIndex == globalIndex ? null : globalIndex;
    _actionsUnlockTimer?.cancel();
    setState(() {
      _selectedIndex = next;
      _actionsLocked = next != null;
    });
    if (next == null) return;
    _actionsUnlockTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _actionsLocked = false);
    });
  }

  /// Reihenfolge der sichtbaren Songs ändern; `moved`-Slots bleiben.
  void _moveVisible(int fromVisible, int toVisible) {
    final reorder = widget.onReorder;
    if (reorder == null) return;
    final visible = _visibleIndexed;
    if (fromVisible < 0 ||
        fromVisible >= visible.length ||
        toVisible < 0 ||
        toVisible >= visible.length ||
        fromVisible == toVisible) {
      return;
    }
    final List<EventSetlistTrack> next;
    final int selectedOrig;
    if (!widget.omitMovedTracks) {
      next = [..._tracks];
      final item = next.removeAt(fromVisible);
      next.insert(toVisible, item);
      selectedOrig = toVisible;
    } else {
      final active = visible.map((e) => e.$2).toList();
      final movedItem = active.removeAt(fromVisible);
      active.insert(toVisible, movedItem);
      var ai = 0;
      next = [
        for (final t in _tracks) t.moved ? t : active[ai++],
      ];
      var p = 0;
      var found = toVisible;
      for (var i = 0; i < next.length; i++) {
        if (next[i].moved) continue;
        if (p == toVisible) {
          found = i;
          break;
        }
        p++;
      }
      selectedOrig = found;
    }
    setState(() {
      _overlay = next;
      _selectedIndex = selectedOrig;
    });
    reorder(next);
  }

  void _onReorderPage(int oldIndex, int newIndex, int startIndex) {
    var to = newIndex;
    if (to > oldIndex) to -= 1;
    _moveVisible(startIndex + oldIndex, startIndex + to);
  }

  @override
  void didUpdateWidget(covariant SetlistPaginatedTrackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks.length != widget.tracks.length) {
      _selectedIndex = null;
      _actionsLocked = false;
      _actionsUnlockTimer?.cancel();
    }
    if (!identical(oldWidget.tracks, widget.tracks)) {
      _overlay = null;
      _localize();
    }
  }

  Future<void> _localize() async {
    if (!mounted || _localizing) return;
    _localizing = true;
    try {
      final next = await SetlistReasonLocalizeService.instance.ensure(
        widget.tracks,
      );
      if (!mounted) return;
      if (identical(next, widget.tracks)) return;
      setState(() => _overlay = next);
      final persist = widget.onReasonsLocalized;
      if (persist != null) await persist(next);
    } finally {
      _localizing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndexed;
    final tracks = visible.map((e) => e.$2).toList();
    final totalPages = HistoryPaginationService.calculateTotalPages(
      tracks.length,
      itemsPerPage: _resultsPerPage,
    );
    final effectivePage = totalPages <= 0
        ? 1
        : _currentPage.clamp(1, totalPages);
    if (effectivePage != _currentPage && totalPages > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = effectivePage);
      });
    }
    final pageItems = HistoryPaginationService.getItemsForPage(
      tracks,
      effectivePage,
      itemsPerPage: _resultsPerPage,
    );
    final startIndex = HistoryPaginationService.calculateStartIndex(
      effectivePage,
      itemsPerPage: _resultsPerPage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onReorder != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.padding.left,
              0,
              widget.padding.right,
              4,
            ),
            child: Text(
              AppLocalizations.of(context)!.translate('drag_to_reorder_hint'),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        Expanded(
          child: widget.onReorder == null
              ? ListView.separated(
                  padding: widget.padding,
                  itemCount: pageItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) =>
                      _tileForPageIndex(index, pageItems, visible, startIndex),
                )
              : ReorderableListView.builder(
                  padding: widget.padding,
                  buildDefaultDragHandles: false,
                  itemCount: pageItems.length,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 6,
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) =>
                      _onReorderPage(oldIndex, newIndex, startIndex),
                  itemBuilder: (context, index) {
                    final visibleIndex = startIndex + index;
                    return Padding(
                      key: ValueKey(
                        'sl-$visibleIndex-${pageItems[index].title}-'
                        '${pageItems[index].artist}',
                      ),
                      padding: EdgeInsets.only(
                        bottom: index == pageItems.length - 1 ? 0 : 6,
                      ),
                      child: _tileForPageIndex(
                        index,
                        pageItems,
                        visible,
                        startIndex,
                        dragIndex: index,
                      ),
                    );
                  },
                ),
        ),
        if (totalPages > 1) _paginationBar(effectivePage, totalPages),
        SizedBox(
          height: widget.padForAppFooter
              ? UIConstants.kFooterPadding * 2
              : 8,
        ),
      ],
    );
  }

  Widget _tileForPageIndex(
    int index,
    List<EventSetlistTrack> pageItems,
    List<(int, EventSetlistTrack)> visible,
    int startIndex, {
    int? dragIndex,
  }) {
    final item = pageItems[index];
    final visibleIndex = startIndex + index;
    final origIndex = visible[visibleIndex].$1;
    final canUp = visibleIndex > 0;
    final canDown = visibleIndex < visible.length - 1;
    return _SetlistTrackTile(
      number: visibleIndex + 1,
      item: item,
      selected: _selectedIndex == origIndex,
      actionsLocked: _actionsLocked,
      dragIndex: dragIndex,
      onTap: _hasActions ? () => _onSelectTrack(origIndex) : null,
      onMoveUp: widget.onReorder == null || !canUp
          ? null
          : () => _moveVisible(visibleIndex, visibleIndex - 1),
      onMoveDown: widget.onReorder == null || !canDown
          ? null
          : () => _moveVisible(visibleIndex, visibleIndex + 1),
      onEdit: widget.onEdit == null
          ? null
          : () => widget.onEdit!(origIndex, item),
      onDelete: widget.onDelete == null
          ? null
          : () => widget.onDelete!(origIndex, item),
      onMoveToOpen: widget.onMoveToOpen == null
          ? null
          : () => widget.onMoveToOpen!(origIndex, item),
      onMarkPlayed: widget.onMarkPlayed == null
          ? null
          : () => widget.onMarkPlayed!(origIndex, item),
    );
  }

  Widget _paginationBar(int currentPage, int totalPages) {
    final l = AppLocalizations.of(context)!;
    final isRtl = VbTextDirection.isRtl(context);
    final canPrev = HistoryPaginationService.hasPreviousPage(currentPage);
    final canNext =
        HistoryPaginationService.hasNextPage(currentPage, totalPages);
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: UIConstants.djShellPageBackground,
      foregroundColor: Colors.white,
      disabledBackgroundColor: UIConstants.colorGrey.withValues(alpha: 0.4),
      disabledForegroundColor: UIConstants.colorGrey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      side: const BorderSide(color: UIConstants.appOrange, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: UIConstants.djChromePanelDecoration,
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: canPrev
                ? () => setState(() => _currentPage = currentPage - 1)
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_forward : Icons.arrow_back,
              size: 18,
            ),
            label: Text(l.history_page_previous),
            style: buttonStyle,
          ),
          Text(
            '${l.history_page} $currentPage / $totalPages',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          ElevatedButton.icon(
            onPressed: canNext
                ? () => setState(() => _currentPage = currentPage + 1)
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_back : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(l.history_page_next),
            style: buttonStyle,
          ),
        ],
      ),
    );
  }
}

class _SetlistTrackTile extends StatelessWidget {
  const _SetlistTrackTile({
    required this.number,
    required this.item,
    this.selected = false,
    this.actionsLocked = false,
    this.dragIndex,
    this.onTap,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onDelete,
    this.onMoveToOpen,
    this.onMarkPlayed,
  });

  final int number;
  final EventSetlistTrack item;
  final bool selected;
  final bool actionsLocked;
  final int? dragIndex;
  final VoidCallback? onTap;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveToOpen;
  final VoidCallback? onMarkPlayed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? UIConstants.colorDjSetlist
              : UIConstants.colorDjSetlist.withValues(alpha: 0.5),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$number. ${item.title}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' – ',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                                TextSpan(
                                  text: item.artist,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.mixMetaLine.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.mixMetaLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFFFCC80),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                          if (item.reasonFor(
                            LocaleHelper.localeNotifier.value.languageCode,
                          ).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.reasonFor(
                                LocaleHelper.localeNotifier.value.languageCode,
                              ),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (dragIndex != null)
                      ReorderableDragStartListener(
                        index: dragIndex!,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4, top: 2),
                          child: Icon(
                            Icons.drag_handle,
                            color: Colors.white54,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (selected &&
              (onMoveUp != null ||
                  onMoveDown != null ||
                  onEdit != null ||
                  onDelete != null ||
                  onMoveToOpen != null ||
                  onMarkPlayed != null))
            IgnorePointer(
              ignoring: actionsLocked,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: SetlistTrackActionIcons(
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                  onEdit: onEdit,
                  onMoveToOpen: onMoveToOpen,
                  onMarkPlayed: onMarkPlayed,
                  onDelete: onDelete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
