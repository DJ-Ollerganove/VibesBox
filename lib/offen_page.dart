import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'main.dart' show buildFirebaseErrorWidget;
import 'l10n/app_localizations.dart';
import '../services/active_party_service.dart';
import '../services/open_wishes_visibility_service.dart';
import '../services/history_pagination_service.dart';
import '../services/wish_management_service.dart';
import '../services/user_blocking_service.dart';
import '../services/duplicate_check_service.dart';
import '../services/results_per_page_service.dart';
import '../services/open_wish_order_service.dart';
import '../services/dj_song_blacklist_service.dart';
import '../widgets/party/dj_song_blacklist_add_dialog.dart';
import '../utils/ui_constants.dart';
import '../utils/string_utils.dart';
import '../utils/pre_wish_helper.dart';
import '../utils/wish_grouping_helper.dart';
import '../models/song_request.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/sticky_pagination_layout.dart';
import '../widgets/wish_card.dart';
import '../widgets/dj_wish_party_scope.dart';
import '../utils/wish_paths.dart';
import '../utils/wish_party_filter.dart';
import '../widgets/pro_promotion_banner.dart';
import '../services/user_service.dart';
import '../utils/free_list_pro_promo.dart';
import 'utils/debug_log.dart';
import 'app_scaffold_messenger.dart';

class OffenPage extends StatefulWidget {
  final List<SongRequest> requests;
  final VoidCallback? onPageOpened;
  final ValueNotifier<bool>? showOnlyFavoritesNotifier;

  const OffenPage({
    super.key,
    required this.requests,
    this.onPageOpened,
    this.showOnlyFavoritesNotifier,
  });

  @override
  State<OffenPage> createState() => _OffenPageState();
}

// Öffentliche abstrakte Klasse für den State, damit MainPage/DjVibesBoxPage darauf zugreifen kann
abstract class OffenPageState extends State<OffenPage> {
  List<String> getCurrentVisibleIds();
}

class _OffenPageState extends OffenPageState
    with AutomaticKeepAliveClientMixin {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  List<String> _currentVisibleIds =
      []; // Liste der aktuell angezeigten Dokument-IDs
  final ScrollController _scrollController =
      ScrollController(); // ✅ Für Scrollen nach oben beim Seitenwechsel
  bool _hasFavorites = false; // Prüft ob Favoriten vorhanden sind

  /// Gleiche Party: Stream-Instanz beibehalten — sonst neu-Subscribe bei jedem
  /// [storedSessionNotifier]-Tick → Flackern, Scroll-Sprung, doppelte Events.
  String? _cachedPendingStreamPartyId;
  Stream<QuerySnapshot>? _cachedPendingWishesStream;

  StreamSubscription<QuerySnapshot>? _favoritePresenceSub;
  String? _favoritePresencePartyId;

  String? _lastHandledPartyId;

  final OpenWishOrderService _orderService = OpenWishOrderService.instance;

  static const Duration _kLongPressDelay = Duration(milliseconds: 500);

  bool _reorderActive = false;
  bool _reorderDropInProgress = false;
  bool _wishDragAccepted = false;
  int? _hoveredInsertGap;
  String? _draggingWishKey;
  double _lastDragGlobalY = 0;
  final Map<String, GlobalKey> _wishCardAnchorKeys = {};
  final GlobalKey _wishListStackKey = GlobalKey(debugLabel: 'offen-wish-stack');
  final GlobalKey _scrollViewKey = GlobalKey(debugLabel: 'offen-scroll-view');
  final ValueNotifier<({int index, double globalY})?> _insertIndicatorNotifier =
      ValueNotifier(null);

  /// Zusatz-Scroll am oberen/unteren Listenrand (Finger nahe Viewport-Kante).
  Timer? _dragAutoScrollTimer;
  int? _dragAutoScrollDirection;
  static const double _kDragEdgeBoostZone = 100;
  static const double _kDragEdgeBoostStep = 12;
  /// Verhindert Hin-und-Her zwischen zwei benachbarten Lücken an derselben Kante.
  static const double _kInsertGapSwitchHysteresis = 22;

  /// Aktuelle Gruppen-Keys für Long-Press-Sortierung (gesetzt beim Listen-Build).
  List<String>? _reorderOrderKeys;

  Stream<QuerySnapshot> _pendingWishesStreamForParty(String partyId) {
    if (_cachedPendingStreamPartyId != partyId) {
      _cachedPendingStreamPartyId = partyId;
      _cachedPendingWishesStream =
          WishManagementService.getWishesStream(partyId, 'pending');
    }
    return _cachedPendingWishesStream!;
  }

  void _ensureFavoritePresenceListener(String partyId) {
    if (_favoritePresencePartyId == partyId && _favoritePresenceSub != null) {
      return;
    }
    unawaited(_favoritePresenceSub?.cancel());
    _favoritePresencePartyId = partyId;
    _favoritePresenceSub = WishPaths.partyWishes(partyId)
        .where('status', isEqualTo: 'pending')
        .where('is_favorite', isEqualTo: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          final hasFavorites = snapshot.docs.isNotEmpty;
          if (_hasFavorites != hasFavorites && mounted) {
            setState(() {
              _hasFavorites = hasFavorites;
            });
          }
        });
  }

  void _tearDownPartyStreams() {
    if (_orderService.isReorderExpanded || _reorderActive) return;
    _cachedPendingStreamPartyId = null;
    _cachedPendingWishesStream = null;
    unawaited(_favoritePresenceSub?.cancel());
    _favoritePresenceSub = null;
    _favoritePresencePartyId = null;
    _lastHandledPartyId = null;
    _orderService.detachParty();
  }

  void _handleActivePartyIdChanged(String? partyId) {
    if (partyId == null || partyId.isEmpty) {
      _lastHandledPartyId = null;
      _tearDownPartyStreams();
      return;
    }
    if (partyId != _lastHandledPartyId) {
      _lastHandledPartyId = partyId;
      _ensureFavoritePresenceListener(partyId);
    }
    _orderService.attachParty(partyId);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentVisibleIds = []; // Erstelle leere Liste
    widget.showOnlyFavoritesNotifier?.addListener(_onFavoritesFilterChanged);
    // Lade party_settings/current (duplicate_threshold + ignored_keywords) für Duplikat-Gruppierung
    DuplicateCheckService.ensurePartySettingsLoaded();
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
    widget.onPageOpened?.call();
  }



  void _showSortLockedSnack(BuildContext context) {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    showVibesSnackBar(context, 
      SnackBar(
        content: Text(l.dj_browser_sort_locked),
      ),
    );
  }

  void _showReorderSaveFailedSnack(BuildContext context) {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    showVibesSnackBar(context, 
      SnackBar(
        content: Text(l.dj_browser_reorder_save_error),
      ),
    );
  }

  void _stopDragAutoScroll() {
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
    _dragAutoScrollDirection = null;
  }

  void _applyWishDragScrollDelta(double dy, double globalDy) {
    if (!_reorderActive || !_scrollController.hasClients) return;

    // Liste folgt leicht dem Finger — sonst kein Scrollen beim Sortieren außer am Rand.
    if (dy.abs() >= 0.5) {
      final pos = _scrollController.position;
      final next = (pos.pixels + dy)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if ((next - pos.pixels).abs() >= 0.5) {
        _scrollController.jumpTo(next);
      }
    }

    _updateHoveredInsertGapForDrag(globalDy);
    _updateEdgeBoostScroll(globalDy);
  }

  ({double top, double bottom})? _scrollViewportGlobalBounds() {
    final ctx = _scrollViewKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (top: topLeft.dy, bottom: topLeft.dy + box.size.height);
  }

  double? _cardBoundaryY(String groupKey, {required bool top}) {
    final key = _wishCardAnchorKeys[groupKey];
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return top ? offset.dy : offset.dy + box.size.height;
  }

  /// Nach Sortieren: verschobenen Song sichtbar machen (mittig, soweit die Liste es zulässt).
  void _scrollToWishGroupKeyAfterLayout(String groupKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _wishCardAnchorKeys[groupKey]?.currentContext;
        if (ctx == null) return;
        unawaited(
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            alignment: 0.5,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          ),
        );
      });
    });
  }

  Map<int, double> _computeInsertGapCenters(List<String> orderKeys) {
    final pinnedCount =
        orderKeys.where((k) => _orderService.isPinned(k)).length;
    final gapCenters = <int, double>{};

    for (var insertIdx = 0; insertIdx <= orderKeys.length; insertIdx++) {
      if (insertIdx < pinnedCount) continue;

      double? centerY;
      if (insertIdx == 0) {
        final top = _cardBoundaryY(orderKeys.first, top: true);
        if (top != null) centerY = top - 18;
      } else if (insertIdx >= orderKeys.length) {
        final bottom = _cardBoundaryY(orderKeys.last, top: false);
        if (bottom != null) centerY = bottom + 18;
      } else {
        final prevBottom =
            _cardBoundaryY(orderKeys[insertIdx - 1], top: false);
        final nextTop = _cardBoundaryY(orderKeys[insertIdx], top: true);
        if (prevBottom != null && nextTop != null) {
          centerY = (prevBottom + nextTop) / 2;
        }
      }
      if (centerY != null) {
        gapCenters[insertIdx] = centerY;
      }
    }
    return gapCenters;
  }

  void _setInsertIndicator(int? insertIndex, Map<int, double> gapCenters) {
    if (insertIndex == null || !gapCenters.containsKey(insertIndex)) {
      _hoveredInsertGap = null;
      if (_insertIndicatorNotifier.value != null) {
        _insertIndicatorNotifier.value = null;
      }
      return;
    }

    _hoveredInsertGap = insertIndex;
    final centerY = gapCenters[insertIndex]!;
    final current = _insertIndicatorNotifier.value;
    if (current?.index != insertIndex ||
        (current!.globalY - centerY).abs() > 0.5) {
      _insertIndicatorNotifier.value = (index: insertIndex, globalY: centerY);
    }
  }

  void _updateHoveredInsertGapForDrag(double globalDy) {
    final draggedKey = _draggingWishKey;
    if (!_reorderActive || draggedKey == null) return;

    _lastDragGlobalY = globalDy;

    final orderKeys = _orderService.localOrderKeys ?? _reorderOrderKeys ?? [];
    if (orderKeys.isEmpty) return;

    final pinnedCount =
        orderKeys.where((k) => _orderService.isPinned(k)).length;
    final gapCenters = _computeInsertGapCenters(orderKeys);

    int? nearest;
    var nearestDist = double.infinity;
    for (final entry in gapCenters.entries) {
      if (!_canAcceptDropAtGap(draggedKey, entry.key, pinnedCount)) continue;
      final dist = (globalDy - entry.value).abs();
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = entry.key;
      }
    }

    final current = _hoveredInsertGap;
    if (nearest != null &&
        current != null &&
        nearest != current &&
        gapCenters.containsKey(current)) {
      final currentDist = (globalDy - gapCenters[current]!).abs();
      final nearestCenterDist = (globalDy - gapCenters[nearest]!).abs();
      if (nearestCenterDist + _kInsertGapSwitchHysteresis >= currentDist) {
        nearest = current;
      }
    }

    if (!mounted) return;
    _setInsertIndicator(nearest, gapCenters);
  }

  void _handleWishDragUpdate(DragUpdateDetails details) {
    _applyWishDragScrollDelta(details.delta.dy, details.globalPosition.dy);
  }

  void _updateEdgeBoostScroll(double globalDy) {
    if (!_scrollController.hasClients) return;

    final viewport = _scrollViewportGlobalBounds();
    final media = MediaQuery.of(context);
    final topRim = viewport?.top ?? media.padding.top;
    final bottomRim =
        viewport?.bottom ?? (media.size.height - media.padding.bottom);

    int direction = 0;
    double intensity = 0;
    if (globalDy < topRim + _kDragEdgeBoostZone) {
      direction = -1;
      intensity = ((topRim + _kDragEdgeBoostZone - globalDy) / _kDragEdgeBoostZone)
          .clamp(0.0, 1.0);
    } else if (globalDy > bottomRim - _kDragEdgeBoostZone) {
      direction = 1;
      intensity = ((globalDy - (bottomRim - _kDragEdgeBoostZone)) / _kDragEdgeBoostZone)
          .clamp(0.0, 1.0);
    }

    if (direction == 0) {
      _stopDragAutoScroll();
      return;
    }

    if (_dragAutoScrollDirection == direction && _dragAutoScrollTimer != null) {
      return;
    }

    _dragAutoScrollDirection = direction;
    _dragAutoScrollTimer?.cancel();
    final step = _kDragEdgeBoostStep * (0.65 + intensity * 0.85);
    _dragAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_reorderActive || !_scrollController.hasClients) {
        _stopDragAutoScroll();
        return;
      }
      final pos = _scrollController.position;
      if (direction < 0 && pos.pixels <= pos.minScrollExtent) {
        _stopDragAutoScroll();
        return;
      }
      if (direction > 0 && pos.pixels >= pos.maxScrollExtent) {
        _stopDragAutoScroll();
        return;
      }
      final next = (pos.pixels + direction * step)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      _scrollController.jumpTo(next);
      _updateHoveredInsertGapForDrag(_lastDragGlobalY);
    });
  }

  void _onWishDragStarted(String groupKey) {
    final keys = _reorderOrderKeys ?? [];
    if (keys.isEmpty) return;

    _wishDragAccepted = false;
    _hoveredInsertGap = null;
    _insertIndicatorNotifier.value = null;
    _draggingWishKey = groupKey;
    if (!_orderService.reorderExpanded) {
      _orderService.beginReorderSession(keys);
    }
    if (!_reorderActive) {
      _reorderActive = true;
      if (mounted) setState(() {});
    }
    unawaited(HapticFeedback.mediumImpact());
    unawaited(_orderService.acquireLock());
  }

  Future<void> _onWishDroppedAtInsertIndex({
    required String draggedKey,
    required int insertIndex,
  }) async {
    if (_orderService.isPinned(draggedKey)) return;

    final keys = List<String>.from(_orderService.localOrderKeys ?? []);
    final oldIdx = keys.indexOf(draggedKey);
    if (oldIdx < 0) return;

    final pinnedCount =
        keys.where((k) => _orderService.isPinned(k)).length;
    if (insertIndex < pinnedCount) return;

    var target = insertIndex.clamp(0, keys.length);
    if (oldIdx < target) target -= 1;
    if (oldIdx == target) return;

    _wishDragAccepted = true;
    _reorderDropInProgress = true;
    _orderService.applyLocalInsertAt(draggedKey, insertIndex);
    final finalKeys = _orderService.orderWithPinsFirst(
      List<String>.from(_orderService.localOrderKeys ?? keys),
    );
    final finalIdx = finalKeys.indexOf(draggedKey);

    try {
      await HapticFeedback.lightImpact();
      final partyId =
          _lastHandledPartyId ??
          OpenWishesVisibilityService.resolveDjWishPartyId();
      final ok = await _orderService.commitReorder(
        finalOrderKeys: finalKeys,
        droppedGroupKey: draggedKey,
        partyIdOverride: partyId,
      );

      if (!mounted) return;
      if (!ok) {
        _showReorderSaveFailedSnack(context);
      } else if (finalIdx >= 0) {
        final targetPage = OpenWishOrderService.pageForGroupIndex(
          finalIdx,
          _resultsPerPage,
        );
        setState(() => _currentPage = targetPage);
        _scrollToWishGroupKeyAfterLayout(draggedKey);
      }
      setState(() {});
    } finally {
      _reorderDropInProgress = false;
    }
  }

  bool _canAcceptDropAtGap(String draggedKey, int insertIndex, int pinnedCount) {
    if (!_reorderActive) return false;
    if (_orderService.isPinned(draggedKey)) return false;
    if (insertIndex < pinnedCount) return false;

    final keys = _orderService.localOrderKeys ?? _reorderOrderKeys ?? [];
    final oldIdx = keys.indexOf(draggedKey);
    if (oldIdx < 0) return false;

    var target = insertIndex.clamp(0, keys.length);
    if (oldIdx < target) target -= 1;
    return oldIdx != target;
  }

  Widget _buildWishInsertGap({
    required int insertIndex,
    required int pinnedCount,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          _canAcceptDropAtGap(details.data, insertIndex, pinnedCount),
      onAcceptWithDetails: (details) {
        unawaited(
          _onWishDroppedAtInsertIndex(
            draggedKey: details.data,
            insertIndex: insertIndex,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final showReorderChrome = _reorderActive;
        return SizedBox(
          height: showReorderChrome ? 36 : 8,
          child: Center(
            child: Container(
              height: showReorderChrome ? 2.5 : 0,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: showReorderChrome
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragInsertIndicatorOverlay() {
    return ValueListenableBuilder<({int index, double globalY})?>(
      valueListenable: _insertIndicatorNotifier,
      builder: (context, indicator, _) {
        if (indicator == null || !_reorderActive) {
          return const SizedBox.shrink();
        }
        final stackContext = _wishListStackKey.currentContext;
        if (stackContext == null) return const SizedBox.shrink();
        final stackBox = stackContext.findRenderObject() as RenderBox?;
        if (stackBox == null || !stackBox.hasSize) {
          return const SizedBox.shrink();
        }
        final localY =
            stackBox.globalToLocal(Offset(0, indicator.globalY)).dy;
        return Positioned(
          left: 2,
          right: 2,
          top: localY - 3,
          height: 6,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onWishDragEnded() {
    if (!_wishDragAccepted &&
        _draggingWishKey != null &&
        _hoveredInsertGap != null) {
      final keys = _orderService.localOrderKeys ?? _reorderOrderKeys ?? [];
      final pinnedCount =
          keys.where((k) => _orderService.isPinned(k)).length;
      if (_canAcceptDropAtGap(
        _draggingWishKey!,
        _hoveredInsertGap!,
        pinnedCount,
      )) {
        unawaited(
          _onWishDroppedAtInsertIndex(
            draggedKey: _draggingWishKey!,
            insertIndex: _hoveredInsertGap!,
          ),
        );
      }
    }
    _finishWishDrag();
  }

  void _finishWishDrag() {
    _stopDragAutoScroll();
    if (!mounted) return;
    if (_reorderActive && !_wishDragAccepted && !_reorderDropInProgress) {
      _orderService.cancelReorderSession();
    }
    setState(() {
      _reorderActive = false;
      _wishDragAccepted = false;
      _hoveredInsertGap = null;
      _draggingWishKey = null;
    });
    _insertIndicatorNotifier.value = null;
  }

  Future<void> _toggleWishPin(BuildContext context, String groupKey) async {
    final result = await _orderService.togglePin(groupKey);
    if (!mounted) return;

    switch (result) {
      case WishPinToggleResult.pinned:
        await HapticFeedback.lightImpact();
        setState(() => _currentPage = 1);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      case WishPinToggleResult.unpinned:
        await HapticFeedback.selectionClick();
      case WishPinToggleResult.limitReached:
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.wish_anchor_limit_snackbar,
            ),
          ),
        );
      case WishPinToggleResult.failed:
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.wish_anchor_update_error,
            ),
            backgroundColor: UIConstants.frameNoParty,
          ),
        );
    }
    if (mounted) setState(() {});
  }

  Widget _wrapWishCardForReorder({
    required BuildContext context,
    required String groupKey,
    required Widget Function() buildCard,
  }) {
    if (_orderService.isPinned(groupKey)) {
      return buildCard();
    }

    final cardWidth = MediaQuery.sizeOf(context).width - 32;

    return LongPressDraggable<String>(
      key: ValueKey('wish-drag-$groupKey'),
      data: groupKey,
      rootOverlay: true,
      maxSimultaneousDrags: 1,
      delay: _kLongPressDelay,
      onDragStarted: () => _onWishDragStarted(groupKey),
      onDragUpdate: _handleWishDragUpdate,
      onDragCompleted: _onWishDragEnded,
      onDraggableCanceled: (velocity, offset) => _finishWishDrag(),
      onDragEnd: (_) => _onWishDragEnded(),
      feedback: Opacity(
        opacity: 0.52,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          color: Colors.transparent,
          shadowColor: Colors.white.withValues(alpha: 0.2),
          child: SizedBox(
            width: cardWidth,
            child: IgnorePointer(child: buildCard()),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.08,
        child: IgnorePointer(child: buildCard()),
      ),
      child: buildCard(),
    );
  }

  /// Prüft ob Favoriten vorhanden sind
  void _onFavoritesFilterChanged() {
    if (mounted) setState(() {});
  }

  Widget _buildFavoritesFilterHeading(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.favorites_page_title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                widget.showOnlyFavoritesNotifier!.value = false;
              },
              icon: const Icon(Icons.arrow_back, size: 22),
              label: Text(l10n.back),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Massen-Update beim Verlassen entfernt: Es führte beim Tab-Wechsel (oder Route-Wechsel) dazu,
    // dass die Liste neu geladen wurde und Songs scheinbar verschwanden. "Gelesen" wird weiterhin
    // beim Öffnen der Detailansicht (WishCard._markWishesAsSeen) gesetzt.
    widget.showOnlyFavoritesNotifier?.removeListener(_onFavoritesFilterChanged);
    unawaited(_favoritePresenceSub?.cancel());
    _stopDragAutoScroll();
    _insertIndicatorNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Navigiert zur vorherigen Seite und scrollt nach oben
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      // ✅ Scroll nach oben, damit DJ die neuen Titel sofort sieht
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Navigiert zur nächsten Seite und scrollt nach oben
  void _goToNextPage(int totalPages) {
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
      });
      // ✅ Scroll nach oben, damit DJ die neuen Titel sofort sieht
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Baut die Paginierungs-Buttons mit Blau/Schwarz Design (passend zu Offen-Songs)
  Widget _buildPaginationButtons(
    int currentPage,
    int totalPages,
    BuildContext context,
  ) {
    final l = AppLocalizations.of(context)!;
    final isRtl = VbTextDirection.isRtl(context);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(
        top: 8,
        bottom: 16,
      ), // ✅ Kompakter oberer Abstand (8px statt 16px), unterer Abstand bleibt für Footer
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: UIConstants.djChromePanelDecoration,
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Zurück-Button
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
          // Seitenanzeige
          Text(
            '${l.history_page} $currentPage / $totalPages',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          // Vor-Button
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

  /// Gibt die aktuell angezeigten Wunsch-IDs zurück (für Navigation-basierte Speicherung)
  @override
  List<String> getCurrentVisibleIds() {
    return List<String>.from(_currentVisibleIds);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // erforderlich für AutomaticKeepAliveClientMixin

    return StickyPaginationLayout(
      currentPage: _currentPage > 0 ? _currentPage : 1,
      totalPages: 1,
      onPrevious: null,
      onNext: null,
      child: DjWishPartyScope(
        emptyKey: 'none',
        onPartyIdChanged: _handleActivePartyIdChanged,
        builder: (context, activePartyId, visibility) {
          return StreamBuilder<QuerySnapshot>(
            stream: _pendingWishesStreamForParty(activePartyId),
            builder: (context, snapshot) => _buildWishesListWithPartyId(
              context,
              snapshot,
              activePartyId,
              visibility: visibility,
            ),
          );
        },
      ),
    );
  }

  Widget _buildWishesListWithPartyId(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot> snapshot,
    String partyId, {
    OpenWishesVisibility? visibility,
  }) {
    // Nur beim allerersten Laden ohne Daten: leere Platzhalter-UI (kein erneutes
    // „Leerflackern“ bei Stream-Neuaufbau, solange bereits Snapshots da waren).
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

    // STREAM-ERROR-LOGGING: Detaillierte Fehlerausgabe
    if (snapshot.hasError) {
      debugLog('❌❌❌ STREAM FEHLER in offen_page.dart ❌❌❌');
      debugLog('   Error: ${snapshot.error}');
      debugLog('   Error Type: ${snapshot.error.runtimeType}');
      debugLog('   Party ID: ${ActivePartyService.currentPartyId}');
      if (snapshot.error is Error) {
        debugLog('   Stack Trace: ${(snapshot.error as Error).stackTrace}');
      }
      return buildFirebaseErrorWidget(snapshot.error!);
    }

    // Firestore-Snapshot: dieselbe doc.id darf nur einmal vorkommen (Cache/Listener-Grenzfall).
    final wishesDocs = <QueryDocumentSnapshot>[];
    final docsById = <String, QueryDocumentSnapshot>{};
    for (final doc in snapshot.data?.docs ?? const <QueryDocumentSnapshot>[]) {
      if (docsById.containsKey(doc.id)) {
        if (kDebugMode) {
          debugLog(
            '⚠️ OffenPage: doppelte doc.id im Snapshot entfernt: ${doc.id}',
          );
        }
        continue;
      }
      docsById[doc.id] = doc;
      wishesDocs.add(doc);
    }

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] OffenPage: Party-ID: $partyId, Gefundene Wünsche: ${wishesDocs.length}',
      );
      if (wishesDocs.isEmpty) {
        debugLog('⚠️ [DEBUG] Keine Wünsche gefunden für Party-ID: $partyId');
      }
    }

    // Subcollection-Query: fehlendes party_id nicht hart ausfiltern (Migration).
    final partyFilteredDocs = wishesDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final matches = wishDocDataMatchesPartyId(data, partyId);
      if (kDebugMode && !matches) {
        final docPartyId = data['party_id'] ?? data['partyId'];
        debugLog(
          '🚫 PARTY-FILTER: Dokument ${doc.id} gehört zu Party "$docPartyId", erwartet "$partyId" - wird ausgeschlossen',
        );
      }
      return matches;
    }).toList();

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] OffenPage: Nach Party-ID-Filter: ${partyFilteredDocs.length} von ${wishesDocs.length} Dokumenten verbleiben',
      );
    }

    // Sammle alle docIds der aktuell angezeigten Wünsche
    _currentVisibleIds.clear();
    for (final doc in partyFilteredDocs) {
      _currentVisibleIds.add(doc.id);
    }

    // Prüfe createdAt-Typ (Debug-Logging)
    for (final doc in partyFilteredDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAtValue = data['createdAt'];
      if (kDebugMode &&
          createdAtValue != null &&
          createdAtValue is! Timestamp) {
        debugLog(
          '⚠️ ZEIT-FEHLER: createdAt ist kein Timestamp, sondern ${createdAtValue.runtimeType} (Dokument-ID: ${doc.id})',
        );
      }
    }

    final filteredDocs = partyFilteredDocs;

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] OffenPage: Nach Duplikat-Filter: ${filteredDocs.length} von ${wishesDocs.length} Dokumenten verbleiben',
      );
    }

    // Konvertiere zu SongRequest Objekten (mit Error-Handling)
    final openWishes = <SongRequest>[];
    final seenOpenWishDocIds = <String>{};
    for (final doc in filteredDocs) {
      if (!seenOpenWishDocIds.add(doc.id)) {
        if (kDebugMode) {
          debugLog(
            '⚠️ OffenPage: doppelte Dokument-ID im Snapshot übersprungen: ${doc.id}',
          );
        }
        continue;
      }
      try {
        final songRequest = SongRequest.fromDocument(doc);
        if (PreWishHelper.isQueuedPreWishRequest(songRequest)) continue;
        openWishes.add(songRequest);
      } catch (e, stackTrace) {
        debugLog('❌ Fehler beim Konvertieren von Dokument ${doc.id}: $e');
        debugLog('   Stack: $stackTrace');
        debugLog('   Document Data: ${doc.data()}');
        // Überspringe dieses Dokument, damit die App weiterläuft
        continue;
      }
    }

    // Wie PWA / Gast „Deine Wünsche“: Shadow-Docs (`is_duplicate: true`) nicht als eigene Zeile.
    final primaryOpenWishes =
        WishGroupingHelper.withoutDuplicateShadowDocuments(openWishes);
    if (kDebugMode && primaryOpenWishes.length != openWishes.length) {
      debugLog(
        '🔍 OffenPage: ${openWishes.length - primaryOpenWishes.length} is_duplicate-Shadow-Dokument(e) ausgeblendet',
      );
    }

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] OffenPage: Nach Mapping: ${primaryOpenWishes.length} primäre SongRequests (${openWishes.length} Docs gesamt)',
      );
    }
    if (kDebugMode && partyId == 'B5wSVwhA67bM5Igp7wj2') {
      debugLog(
        '🔍 [DEBUG] OffenPage (Party B5wSVwhA67bM5Igp7wj2): docs=${wishesDocs.length} primaryOpen=${primaryOpenWishes.length}',
      );
    }

    // Favoriten-Filter: Nur Markierte anzeigen, wenn Filter aktiv
    final showOnlyFavorites = widget.showOnlyFavoritesNotifier?.value == true;
    final wishesToShow = showOnlyFavorites
        ? primaryOpenWishes.where((r) => r.isFavorite == true).toList()
        : primaryOpenWishes;
    if (kDebugMode && partyId == 'B5wSVwhA67bM5Igp7wj2') {
      debugLog(
        '🔍 [DEBUG] OffenPage (Party B5wSVwhA67bM5Igp7wj2): showOnlyFavorites=$showOnlyFavorites wishesToShow=${wishesToShow.length}',
      );
    }

    // Wenn Liste leer: Hinweis, ob Filter "Nur Favoriten" Wünsche ausblendet (verhindert "Song ist weg"-Eindruck)
    if (wishesToShow.isEmpty) {
      final hiddenByFilter = showOnlyFavorites && primaryOpenWishes.isNotEmpty;
      final l10n = AppLocalizations.of(context)!;
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
            if (showOnlyFavorites && widget.showOnlyFavoritesNotifier != null)
              _buildFavoritesFilterHeading(context, l10n),
            if (hiddenByFilter)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.offen_favorites_hidden(primaryOpenWishes.length),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (!hiddenByFilter) EmptyListMessage(),
            const SizedBox(height: UIConstants.kFooterPadding * 2),
          ],
        ),
      );
    }

    // Sortiere nach createdAt (neueste zuerst)
    final sortedWishes = wishesToShow.toList()
      ..sort((a, b) {
        final tsA =
            a.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tsB =
            b.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tsB.compareTo(tsA);
      });

    // Gruppiere Wünsche
    final groupedResult = WishGroupingHelper.groupWishes(
      sortedWishes,
      sessionPartyId: partyId,
      allRequestsForTimestamps: openWishes,
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

    return ListenableBuilder(
      listenable: _orderService,
      builder: (context, _) {
        _orderService.updateDocIdsByGroupKey(groupedDocIds);
        final orderedGroupedList = _orderService.orderedGroups(allGroupedList);
        return _buildOpenWishListContent(
          context: context,
          partyId: partyId,
          showOnlyFavorites: showOnlyFavorites,
          groupedFirstRequests: groupedFirstRequests,
          groupedDocIds: groupedDocIds,
          orderedGroupedList: orderedGroupedList,
        );
      },
    );
  }

  Widget _buildOpenWishListContent({
    required BuildContext context,
    required String partyId,
    required bool showOnlyFavorites,
    required Map<String, SongRequest> groupedFirstRequests,
    required Map<String, List<String>> groupedDocIds,
    required List<Map<String, dynamic>> orderedGroupedList,
  }) {
    final orderKeys = orderedGroupedList
        .map((g) => g['key'] as String)
        .where((k) => k.isNotEmpty)
        .toList();

    // Volle Liste + Einfüge-Spalten nur während aktivem Sortieren — nicht nur weil
    // Sortieren grundsätzlich erlaubt ist (sonst keine Paginierung, alle Wünsche sichtbar).
    final useReorderLayout =
        _reorderActive || _orderService.isReorderExpanded;
    final byGroupKey = <String, Map<String, dynamic>>{
      for (final g in orderedGroupedList)
        if ((g['key'] as String?)?.isNotEmpty == true) g['key'] as String: g,
    };

    final List<Map<String, dynamic>> listEntries;
    if (useReorderLayout) {
      final keys = _orderService.localOrderKeys ?? orderKeys;
      listEntries = keys
          .where(byGroupKey.containsKey)
          .map((k) => byGroupKey[k]!)
          .toList();
    } else {
      listEntries = HistoryPaginationService.getItemsForPage(
        orderedGroupedList,
        _currentPage > 0 ? _currentPage : 1,
        itemsPerPage: _resultsPerPage,
      );
    }

    final displayCount = orderedGroupedList.length;

    final totalPages = HistoryPaginationService.calculateTotalPages(
      displayCount,
      itemsPerPage: _resultsPerPage,
    );

    // ✅ Stelle sicher, dass _currentPage automatisch korrigiert wird
    if (_currentPage > totalPages && totalPages > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentPage = totalPages;
          });
        }
      });
    }

    // ✅ Reset auf Seite 1 bei neuem Stream (wenn sich Daten ändern)
    // Wird automatisch durch Stream-Update getriggert

    // Hole paginierte Liste (im Sortier-Modus: volle Liste, gleiche Darstellung)
    final bottomPadding =
        totalPages > 1 && !useReorderLayout ? 8.0 : 150.0;

    _reorderOrderKeys = orderKeys;

    final l10nList = AppLocalizations.of(context)!;
    final blockScroll = _reorderActive;
    return SingleChildScrollView(
        key: _scrollViewKey,
        controller:
            _scrollController, // ✅ ScrollController für Scrollen nach oben
        physics: blockScroll
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
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
          if (showOnlyFavorites && widget.showOnlyFavoritesNotifier != null)
            _buildFavoritesFilterHeading(context, l10nList),
          if (_reorderActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10nList.open_wishes_reorder_hint,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          RepaintBoundary(
            child: Stack(
              key: _wishListStackKey,
              clipBehavior: Clip.none,
              children: [
                _buildWishList(
                  context: context,
                  partyId: partyId,
                  listEntries: listEntries,
                  fullListLength: displayCount,
                  showFullList: useReorderLayout,
                  showGapColumns: useReorderLayout,
                  groupedFirstRequests: groupedFirstRequests,
                  groupedDocIds: groupedDocIds,
                  bottomPadding: bottomPadding,
                ),
                _buildDragInsertIndicatorOverlay(),
              ],
            ),
          ),
          // Paginierungs-Buttons (ausgeblendet während Sortieren)
          if (totalPages > 1 && !useReorderLayout)
            _buildPaginationButtons(_currentPage, totalPages, context),
          const SizedBox(height: UIConstants.kFooterPadding * 2),
        ],
      ),
    );
  }

  int _freeAwareItemCount(int dataLen) {
    final isFree = UserService().sessionProStatus.value?.isActive != true;
    return FreeListProPromo.itemCount(dataLen, isFree: isFree);
  }

  int _dataIndexForListIndex(int index, int dataLen) {
    final isFree = UserService().sessionProStatus.value?.isActive != true;
    return FreeListProPromo.dataIndex(index, dataLen, isFree: isFree);
  }

  Future<void> _addWishToBlacklist(
    BuildContext context, {
    required String partyId,
    required String title,
    required String artist,
    required List<String> docIds,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || partyId.isEmpty) return;
    final result = await DjSongBlacklistAddDialog.show(
      context: context,
      title: title,
      artist: artist,
      useCheckboxes: true,
    );
    if (result == null || !context.mounted) return;
    try {
      await DjSongBlacklistService.instance.addEntry(
        djId: uid,
        title: result.$1,
        artist: result.$2,
      );
      DjSongBlacklistService.instance.skipLiveHintFor(docIds);
      await DjSongBlacklistService.instance.rejectWishIds(
        partyId: partyId,
        wishIds: docIds,
      );
      if (!context.mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.translate('song_blacklist_wish_moved')),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tp(
              'song_blacklist_failed',
              {'error': '$e'},
            ),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Widget _buildWishCardStack({
    required BuildContext context,
    required String partyId,
    required String groupKey,
    required Map<String, dynamic> data,
    required List<String> docIds,
    required Map<String, SongRequest> groupedFirstRequests,
    required int number,
    required bool isNew,
  }) {
    final primaryDocId = docIds.first;
    final titleDisp = unescapeHtml((data['title'] ?? '') as String);
    final artistDisp = unescapeHtml((data['artist'] ?? '') as String);
    final displayText = titleDisp.isNotEmpty && artistDisp.isNotEmpty
        ? '$titleDisp - $artistDisp'
        : (titleDisp.isNotEmpty ? titleDisp : artistDisp);

    for (final docId in docIds) {
      if (!_currentVisibleIds.contains(docId)) {
        _currentVisibleIds.add(docId);
      }
    }

    // party_id immer auf die sichtbare Party setzen (Sperre/Gesperrt).
    // Nicht nur wenn leer — sonst landet die Sperre unter einer veralteten Wunsch-party_id.
    final dataForCard = Map<String, dynamic>.from(data);
    if (partyId.isNotEmpty) {
      dataForCard['party_id'] = partyId;
    }

    return RepaintBoundary(
      child: WishCard(
      key: ValueKey('offen-$partyId-$primaryDocId'),
      request: groupedFirstRequests[groupKey],
      groupedData: dataForCard,
      docIds: docIds,
      type: WishCardType.offen,
      number: number,
      isNew: isNew,
      isPinned: _orderService.isPinned(groupKey),
      onTogglePin: () => unawaited(_toggleWishPin(context, groupKey)),
      onPlay: (ctx, ids) {
        if (partyId.isNotEmpty) {
          WishManagementService.showConfirmUpdateGroupedStatusDialog(
            ctx,
            ids,
            'played',
            AppLocalizations.of(ctx)!.mark_as_played,
            displayText,
            partyId,
          );
        }
      },
      onReject: (ctx, ids) {
        if (partyId.isNotEmpty) {
          WishManagementService.showConfirmUpdateGroupedStatusDialog(
            ctx,
            ids,
            'rejected',
            AppLocalizations.of(ctx)!.reject,
            displayText,
            partyId,
          );
        }
      },
      onDelete: (ctx, ids) {
        if (partyId.isNotEmpty) {
          WishManagementService.showConfirmDeleteGroupedDialog(
            ctx,
            ids,
            displayText,
            partyId,
          );
        }
      },
      onBlockGrouped: (ctx, req, dataMap, ids) =>
          UserBlockingService.showGroupedBlockDialog(ctx, req, dataMap, ids),
      onBlacklist: DjSongBlacklistService.instance.prefsNotifier.value.enabled
          ? (detailContext) => _addWishToBlacklist(
        detailContext,
        partyId: partyId,
        title: titleDisp,
        artist: artistDisp,
        docIds: docIds,
      )
          : null,
    ),
    );
  }

  Widget _buildWishList({
    required BuildContext context,
    required String partyId,
    required List<Map<String, dynamic>> listEntries,
    required int fullListLength,
    required bool showFullList,
    required bool showGapColumns,
    required Map<String, SongRequest> groupedFirstRequests,
    required Map<String, List<String>> groupedDocIds,
    required double bottomPadding,
  }) {
    final includeBanners =
        !showFullList && UserService().sessionProStatus.value?.isActive != true;
    final pinnedCount = showGapColumns
        ? (_orderService.localOrderKeys ?? _reorderOrderKeys ?? [])
            .where((k) => _orderService.isPinned(k))
            .length
        : 0;

    return ListView.builder(
      key: ValueKey(
        'offen-order-${_orderService.serverRev}-'
        '${listEntries.map((e) => e['key']).join('\u001e')}',
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: 8.0, bottom: bottomPadding),
      itemCount: includeBanners
          ? _freeAwareItemCount(listEntries.length)
          : listEntries.length,
      itemBuilder: (context, index) {
        final dataLen = listEntries.length;
        if (includeBanners &&
            FreeListProPromo.isPromoIndex(index, dataLen, isFree: true)) {
          return const ProPromotionBanner();
        }
        final dataIndex =
            includeBanners ? _dataIndexForListIndex(index, dataLen) : index;
        final groupEntry = listEntries[dataIndex];
        final groupKey = groupEntry['key'] as String;
        final data = groupEntry['data'] as Map<String, dynamic>;
        final docIds = groupedDocIds[groupKey] ?? const <String>[];
        if (docIds.isEmpty) return const SizedBox.shrink();

        final fullIndex = showFullList
            ? dataIndex
            : HistoryPaginationService.calculateStartIndex(
                  _currentPage > 0 ? _currentPage : 1,
                  itemsPerPage: _resultsPerPage,
                ) +
                dataIndex;

        final number = fullListLength - fullIndex;
        final isNew = docIds.any(
          (docId) => !ActivePartyService.seenWishIds.contains(docId),
        );

        final anchoredCard = KeyedSubtree(
          key: _wishCardAnchorKeys.putIfAbsent(
            groupKey,
            () => GlobalKey(debugLabel: 'offen-wish-$groupKey'),
          ),
          child: _wrapWishCardForReorder(
            context: context,
            groupKey: groupKey,
            buildCard: () => _buildWishCardStack(
              context: context,
              partyId: partyId,
              groupKey: groupKey,
              data: data,
              docIds: docIds,
              groupedFirstRequests: groupedFirstRequests,
              number: number,
              isNew: isNew,
            ),
          ),
        );

        if (!showGapColumns || _orderService.isPinned(groupKey)) {
          return anchoredCard;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWishInsertGap(
              insertIndex: dataIndex,
              pinnedCount: pinnedCount,
            ),
            anchoredCard,
            if (dataIndex == listEntries.length - 1)
              _buildWishInsertGap(
                insertIndex: listEntries.length,
                pinnedCount: pinnedCount,
              ),
          ],
        );
      },
    );
  }
}
