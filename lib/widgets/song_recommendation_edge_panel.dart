/// Schmales Randfenster links über der Musikerkennung: 5 Folgevorschläge.
///
/// Verhalten:
/// - Neuer erkannter Song → Panel aufklappen, 5 Vorschläge laden, nach 15s zuklappen.
/// - Gleicher Song erneut → kein erneutes Aufklappen, kein neuer KI-Call (Cache).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/song_recommendation.dart';
import '../services/active_party_service.dart';
import '../services/song_recommendation_service.dart';
import '../services/song_recommendation_settings_service.dart';
import '../utils/pre_wish_helper.dart';
import '../utils/ui_constants.dart';
import '../utils/wish_paths.dart';

class SongRecommendationEdgePanel extends StatefulWidget {
  const SongRecommendationEdgePanel({
    super.key,
    required this.seedTitle,
    required this.seedArtist,
    this.seedBpm,
    this.seedCamelot,
    required this.onDismissPermanently,
    this.useExternalSource = false,
    this.externalItems = const <SongRecommendation>[],
    this.externalLoading = false,
  });

  final String seedTitle;
  final String seedArtist;
  final double? seedBpm;
  final String? seedCamelot;
  final VoidCallback onDismissPermanently;
  /// VibesBox Sync: Vorschläge kommen vom Tool, die App sucht nicht.
  final bool useExternalSource;
  final List<SongRecommendation> externalItems;
  final bool externalLoading;

  static const double stripWidth = 15;
  static const double collapsedHeight = 72;
  static const double collapsedHitWidth = 36;
  static const double maxWidthFraction = 0.5;
  static const Duration autoCollapseAfter = Duration(seconds: 15);

  @override
  State<SongRecommendationEdgePanel> createState() =>
      _SongRecommendationEdgePanelState();
}

class _SongRecommendationEdgePanelState
    extends State<SongRecommendationEdgePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;
  Timer? _autoCollapse;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  List<SongRecommendation> _items = const <SongRecommendation>[];
  int _requestId = 0;
  List<({String title, String artist})> _openWishes =
      const <({String title, String artist})>[];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _openSub;
  String? _openPartyId;

  bool get _isExpanded => _slide.value > 0.12;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
    _slide.addStatusListener(_onSlideStatus);
    SongRecommendationSettingsService.instance.notifier.addListener(
      _onSettingsChanged,
    );
    ActivePartyService.storedSessionNotifier.addListener(_bindOpenWishes);
    _bindOpenWishes();
    // Neuer Seed (Widget neu gebaut) → sofort öffnen + laden.
    unawaited(_openFullyAndLoad());
  }

  @override
  void didUpdateWidget(SongRecommendationEdgePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seedTitle != widget.seedTitle ||
        oldWidget.seedArtist != widget.seedArtist) {
      _hasLoadedOnce = false;
      _items = const <SongRecommendation>[];
      unawaited(_openFullyAndLoad());
      return;
    }
    if (widget.useExternalSource &&
        (oldWidget.externalLoading != widget.externalLoading ||
            oldWidget.externalItems != widget.externalItems)) {
      _applyExternal();
    }
  }

  @override
  void dispose() {
    _autoCollapse?.cancel();
    _slide.removeStatusListener(_onSlideStatus);
    SongRecommendationSettingsService.instance.notifier.removeListener(
      _onSettingsChanged,
    );
    ActivePartyService.storedSessionNotifier.removeListener(_bindOpenWishes);
    unawaited(_openSub?.cancel());
    _slide.dispose();
    super.dispose();
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _slide.value > 0.9) {
      _armAutoCollapse();
    }
    if (status == AnimationStatus.dismissed) {
      _autoCollapse?.cancel();
    }
  }

  void _armAutoCollapse() {
    _autoCollapse?.cancel();
    _autoCollapse = Timer(SongRecommendationEdgePanel.autoCollapseAfter, () {
      if (!mounted) return;
      if (_slide.value > 0.08) {
        unawaited(_slide.animateTo(0, curve: Curves.easeOutCubic));
      }
    });
  }

  Future<void> _openFullyAndLoad() async {
    _armAutoCollapse();
    unawaited(_load());
    if (_slide.value < 0.95) {
      await _slide.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      _armAutoCollapse();
    }
  }

  Future<void> _openFully() async {
    _armAutoCollapse();
    if (!_hasLoadedOnce || _items.isEmpty) {
      unawaited(_load());
    }
    await _slide.animateTo(1, curve: Curves.easeOutCubic);
  }

  Future<void> _collapseToStrip() async {
    _autoCollapse?.cancel();
    await _slide.animateTo(0, curve: Curves.easeOutCubic);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final settings =
        SongRecommendationSettingsService.instance.notifier.value;
    if (!settings.enabled) {
      _autoCollapse?.cancel();
      setState(() {
        _loading = false;
        _hasLoadedOnce = false;
        _items = const <SongRecommendation>[];
      });
      return;
    }
    // Settings geändert → sofort neu suchen (nicht bei Sync-Fremdquelle).
    if (widget.useExternalSource) return;
    SongRecommendationService.instance.clearRuntimeCaches();
    _hasLoadedOnce = false;
    setState(() {
      _loading = true;
      _items = const <SongRecommendation>[];
    });
    if (_isExpanded) {
      unawaited(_openFullyAndLoad());
    } else {
      unawaited(_load());
    }
  }

  void _bindOpenWishes() {
    final partyId = ActivePartyService.getStoredSession()?.partyId;
    if (partyId == null || partyId.isEmpty || partyId == 'manual') {
      unawaited(_openSub?.cancel());
      _openSub = null;
      _openPartyId = null;
      if (_openWishes.isNotEmpty && mounted) {
        setState(() => _openWishes = const []);
      }
      return;
    }
    if (_openPartyId == partyId && _openSub != null) return;
    unawaited(_openSub?.cancel());
    _openPartyId = partyId;
    _openSub = WishPaths.partyWishes(partyId)
        .where('status', isEqualTo: 'pending')
        .limit(200)
        .snapshots()
        .listen((snap) {
      final rows = <({String title, String artist})>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (PreWishHelper.isQueuedPreWish(data)) continue;
        final title = (data['title'] ?? data['song'] ?? '').toString().trim();
        final artist = (data['artist'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        rows.add((title: title, artist: artist));
      }
      if (!mounted) return;
      setState(() => _openWishes = rows);
    });
  }

  bool _isOpenWish(SongRecommendation item) {
    for (final wish in _openWishes) {
      if (SongRecommendationService.sameWork(
        titleA: wish.title,
        artistA: wish.artist,
        titleB: item.title,
        artistB: item.artist,
      )) {
        return true;
      }
    }
    return false;
  }

  void _applyExternal() {
    if (!mounted) return;
    setState(() {
      _loading = widget.externalLoading;
      _items = widget.externalItems;
      _hasLoadedOnce = widget.externalItems.isNotEmpty || !widget.externalLoading;
    });
  }

  Future<void> _load() async {
    if (widget.useExternalSource) {
      _applyExternal();
      return;
    }
    final id = ++_requestId;
    setState(() => _loading = true);
    final items = await SongRecommendationService.instance
        .suggestForRecognizedSong(
          title: widget.seedTitle,
          artist: widget.seedArtist,
          bpm: widget.seedBpm,
          camelot: widget.seedCamelot,
        );
    if (!mounted || id != _requestId) return;
    setState(() {
      _loading = false;
      _hasLoadedOnce = true;
      _items = items;
    });
  }

  Future<void> _refresh() async {
    if (widget.useExternalSource) return;
    if (_loading) return;
    _armAutoCollapse();
    final id = ++_requestId;
    setState(() => _loading = true);
    final items = await SongRecommendationService.instance
        .suggestForRecognizedSong(
          title: widget.seedTitle,
          artist: widget.seedArtist,
          bpm: widget.seedBpm,
          camelot: widget.seedCamelot,
          refresh: true,
          alreadyShown: _items,
        );
    if (!mounted || id != _requestId) return;
    setState(() {
      _loading = false;
      _hasLoadedOnce = true;
      if (items.isNotEmpty) _items = items;
    });
  }

  double _maxWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width *
        SongRecommendationEdgePanel.maxWidthFraction;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _autoCollapse?.cancel();
    final range =
        _maxWidth(context) - SongRecommendationEdgePanel.stripWidth;
    if (range <= 0) return;
    final boost = _slide.value < 0.12 ? 2.2 : 1.0;
    _slide.value =
        (_slide.value + details.delta.dx / range * boost).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final vx = details.primaryVelocity ?? 0;
    if (vx < -450) {
      unawaited(_collapseToStrip());
      return;
    }
    if (vx > 450) {
      unawaited(_openFully());
      return;
    }
    if (_slide.value >= 0.42) {
      unawaited(_openFully());
    } else {
      unawaited(_collapseToStrip());
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = _maxWidth(context);
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final t = _slide.value;
        final width = SongRecommendationEdgePanel.stripWidth +
            (maxWidth - SongRecommendationEdgePanel.stripWidth) * t;
        final collapsed = t < 0.12;
        final hitWidth = collapsed
            ? SongRecommendationEdgePanel.collapsedHitWidth
            : width;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: collapsed ? () => unawaited(_openFully()) : null,
          onHorizontalDragStart: (_) => _autoCollapse?.cancel(),
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: SizedBox(
            width: hitWidth,
            height: collapsed
                ? SongRecommendationEdgePanel.collapsedHeight
                : null,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ClipRect(
                child: SizedBox(
                  width: width,
                  height: collapsed
                      ? SongRecommendationEdgePanel.collapsedHeight
                      : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: collapsed
                          ? UIConstants.appOrange
                          : Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(collapsed ? 5 : 10),
                        bottomRight: Radius.circular(collapsed ? 5 : 0),
                      ),
                      border: Border.all(
                        color: UIConstants.appOrange,
                        width: collapsed ? 0 : 2,
                      ),
                    ),
                    child: collapsed
                        ? const SizedBox.expand()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
                            child: _panelBody(),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _panelBody() {
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: UIConstants.appOrange.withValues(alpha: 0.55),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.song_rec_panel_title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.song_rec_refresh,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  iconSize: 16,
                  color: Colors.white70,
                  onPressed: (_loading || widget.useExternalSource)
                      ? null
                      : () => unawaited(_refresh()),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: l.song_rec_collapse,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  iconSize: 16,
                  color: Colors.white70,
                  onPressed: () => unawaited(_collapseToStrip()),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: UIConstants.appOrange,
              backgroundColor: Color(0x33FFFFFF),
            ),
          ),
        const SizedBox(height: 6),
        if (_items.isEmpty && !_loading)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                l.song_rec_empty,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          )
        else
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            _MiniTrackTile(
              item: _items[i],
              inOpenWishes: _isOpenWish(_items[i]),
            ),
          ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: widget.onDismissPermanently,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white54,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              l.song_rec_dismiss_permanently,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white38,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniTrackTile extends StatelessWidget {
  const _MiniTrackTile({
    required this.item,
    required this.inOpenWishes,
  });

  final SongRecommendation item;
  final bool inOpenWishes;

  static String _metaLine(SongRecommendation item) => item.mixMetaLine;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: UIConstants.appOrange.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inOpenWishes)
                  Tooltip(
                    message: AppLocalizations.of(context)!.song_rec_open_wish,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 1, right: 4),
                      child: Icon(
                        Icons.inbox,
                        size: 14,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const TextSpan(
                    text: ' – ',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: item.artist,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
                ),
              ],
            ),
            if (_metaLine(item).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _metaLine(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFCC80),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
