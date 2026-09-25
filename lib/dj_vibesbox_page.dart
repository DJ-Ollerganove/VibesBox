import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'l10n/app_localizations.dart';
import 'utils/firebase_error_message.dart';
import 'utils/formatting_utils.dart';
import 'utils/ui_constants.dart';
import 'services/active_party_service.dart';
import 'services/open_wishes_visibility_service.dart';
import 'services/wish_management_service.dart';
import 'offen_page.dart';
import 'vorab_page.dart';
import 'gespielt_page.dart';
import 'abgelehnt_page.dart';
import 'models/song_request.dart';
import 'models/event_setlist_track.dart';
import 'pages/favoriten_page.dart';
import 'pages/manual_wish_page.dart';
import 'services/user_service.dart';
import 'services/dj_setlist_store_service.dart';
import 'widgets/party/dj_setlist_tab_page.dart';
import 'widgets/party/offen_blacklist_count_banner.dart';
import 'widgets/free_feature_locked.dart';
import 'services/dj_wish_notification_navigator.dart';
import 'widgets/custom_page_header.dart';
import 'widgets/grace_period_end_dialog.dart';
import 'widgets/party_grace_countdown.dart';
import 'widgets/pre_wish_action_dialogs.dart';
import 'widgets/pre_wishes_paused_dj_banner.dart';
import 'utils/pre_wish_helper.dart';
import 'services/vibesbox_fullscreen_service.dart';
import 'services/dj_pro_session_service.dart';
import 'services/pro_feature_guard.dart';
import 'services/pro_free_check.dart';
import 'config/app_config.dart';
import 'widgets/dj_browser_code_dialog.dart';
import 'app_scaffold_messenger.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

/// Zentrale DJ-Wunschverwaltung: optional Vorab | Offen | Gespielt | Abgelehnt
class DjVibesBoxPage extends StatefulWidget {
  final GlobalKey<OffenPageState> offenPageKey;
  final List<SongRequest> requests;
  final VoidCallback? onPageOpened;
  /// Wenn true, wird beim Anzeigen der Seite der Offen-Tab aktiviert
  final bool isActive;

  const DjVibesBoxPage({
    super.key,
    required this.offenPageKey,
    required this.requests,
    this.onPageOpened,
    this.isActive = true,
  });

  @override
  State<DjVibesBoxPage> createState() => _DjVibesBoxPageState();
}

class _DjVibesBoxPageState extends State<DjVibesBoxPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _showVorabTab = false;
  bool _showSetlistTab = false;
  String? _setlistPartyId;
  Stream<List<EventSetlistTrack>>? _setlistStream;
  final ValueNotifier<bool> _showOnlyFavoritesNotifier = ValueNotifier<bool>(false);

  int get _offenTabIndex {
    var i = 0;
    if (_showSetlistTab) i++;
    if (_showVorabTab) i++;
    return i;
  }

  int get _vorabTabIndex {
    if (!_showVorabTab) return -1;
    return _showSetlistTab ? 1 : 0;
  }

  void _ensureSetlistStream(String? partyId) {
    if (partyId == null || partyId.isEmpty) {
      _setlistPartyId = null;
      _setlistStream = null;
      return;
    }
    if (_setlistPartyId == partyId && _setlistStream != null) return;
    _setlistPartyId = partyId;
    _setlistStream = DjSetlistStoreService.instance.watch(partyId);
  }

  Future<void> _onPublishAllPreWishesToOpen(
    BuildContext context,
    String partyId,
  ) async {
    final confirmed = await PreWishActionDialogs.showPublishAllConfirm(context);
    if (confirmed != true || !context.mounted) return;

    try {
      final count =
          await WishManagementService.publishAllQueuedPreWishesToOpen(partyId);
      if (!context.mounted) return;
      if (count <= 0) return;

      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.pre_wish_publish_all_success(count)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.snackbar_error_details(formatFirebaseErrorDetail(e))),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _resolveBrowserPartyId(
    OpenWishesVisibility? visibility,
    ActivePartyInfo? session,
  ) {
    final fromVisibility = visibility?.partyId?.trim();
    if (fromVisibility != null && fromVisibility.isNotEmpty) {
      return fromVisibility;
    }
    final fromSession = session?.partyId.trim();
    if (fromSession != null && fromSession.isNotEmpty) {
      return fromSession;
    }
    final stored = ActivePartyService.getStoredSession()?.partyId.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return null;
  }

  /// Pro / Pro Life / Trial / DJ B2B — nie Free-Sperre für echte Pro-Nutzer.
  bool _djBrowserProAllowed() {
    if (DjProSessionService.instance.isProActive) return true;
    final user = UserService().currentUser.value;
    if (user == null) return false;
    if (AppConfig.isAdminRole(user)) return true;
    return ProFreeCheck.determineStatus(user: user).isActive;
  }

  Future<void> _onOpenDjBrowser(BuildContext context, String? partyId) async {
    if (partyId == null || partyId.isEmpty) {
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.wishbox_dj_no_party_selected),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_djBrowserProAllowed()) {
      final l = AppLocalizations.of(context)!;
      await FreeFeatureLockedDialog.show(
        context,
        title: l.dj_browser_free_locked_title,
        description: l.dj_browser_free_locked_description,
      );
      return;
    }
    try {
      await DjBrowserCodeDialog.present(context, partyId: partyId);
    } catch (e) {
      if (!context.mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.dj_browser_error_create),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildVorabPausedBanner(String? partyId) {
    if (partyId == null || partyId.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .snapshots(),
      builder: (context, snap) {
        if (!PreWishHelper.arePreWishesPaused(snap.data?.data())) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: const PreWishesPausedDjBanner(),
        );
      },
    );
  }

  Widget _buildVorabToolbar(
    BuildContext context,
    AppLocalizations l,
    bool isRtl,
    String? partyId,
  ) {
    if (partyId == null || partyId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Align(
        alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
        child: StreamBuilder<bool>(
          stream: WishManagementService.watchHasQueuedPreWishes(partyId),
          builder: (context, snapshot) {
            final hasQueued = snapshot.data == true;
            return TextButton.icon(
              onPressed: hasQueued
                  ? () => _onPublishAllPreWishesToOpen(context, partyId)
                  : null,
              icon: Icon(
                Icons.playlist_add_check,
                size: 20,
                color: hasQueued
                    ? UIConstants.appGreen
                    : UIConstants.frameNoParty.withValues(alpha: 0.4),
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  l.pre_wish_publish_all_to_open,
                  maxLines: 1,
                  style: TextStyle(
                    color: hasQueued
                        ? UIConstants.appGreen
                        : UIConstants.frameNoParty.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            );
          },
        ),
      ),
    );
  }

  void _ensureTabController({
    required bool showVorab,
    required bool showSetlist,
    int? preferIndex,
  }) {
    final length = 3 + (showVorab ? 1 : 0) + (showSetlist ? 1 : 0);
    if (_tabController != null &&
        _tabController!.length == length &&
        _showVorabTab == showVorab &&
        _showSetlistTab == showSetlist) {
      return;
    }

    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();

    int newIndex;
    if (preferIndex != null) {
      newIndex = preferIndex.clamp(0, length - 1);
    } else {
      var idx = oldIndex;
      if (showSetlist && !_showSetlistTab) idx += 1;
      if (!showSetlist && _showSetlistTab) {
        idx = (idx - 1).clamp(0, length - 1);
      }
      if (showVorab && !_showVorabTab) idx += 1;
      if (!showVorab && _showVorabTab) {
        final oldVorab = _showSetlistTab ? 1 : 0;
        final newOffen = (showSetlist ? 1 : 0) + (showVorab ? 1 : 0);
        idx = idx == oldVorab ? newOffen : (idx - 1);
      }
      newIndex = idx.clamp(0, length - 1);
    }

    _showVorabTab = showVorab;
    _showSetlistTab = showSetlist;
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: newIndex,
    );
  }

  void _onOpenOffenFromNotification() {
    if (!mounted || _tabController == null) return;
    final offenIndex = _offenTabIndex;
    if (_tabController!.index != offenIndex) {
      _tabController!.animateTo(offenIndex);
    }
    widget.onPageOpened?.call();
  }

  void _onOpenVorabFromNotification() {
    if (!mounted || _tabController == null) return;
    if (!_showVorabTab) return;
    final vorabIndex = _vorabTabIndex;
    if (vorabIndex < 0) return;
    if (_tabController!.index != vorabIndex) {
      _tabController!.animateTo(vorabIndex);
    }
    widget.onPageOpened?.call();
  }

  @override
  void initState() {
    super.initState();
    _ensureTabController(
      showVorab: false,
      showSetlist: false,
      preferIndex: 0,
    );
    DjWishNotificationNavigator.instance.openOffenSignal.addListener(
      _onOpenOffenFromNotification,
    );
    DjWishNotificationNavigator.instance.openVorabSignal.addListener(
      _onOpenVorabFromNotification,
    );
  }

  @override
  void didUpdateWidget(covariant DjVibesBoxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        !oldWidget.isActive &&
        _tabController != null &&
        _tabController!.index != _offenTabIndex) {
      _tabController!.animateTo(_offenTabIndex);
    }
  }

  @override
  void dispose() {
    DjWishNotificationNavigator.instance.openOffenSignal.removeListener(
      _onOpenOffenFromNotification,
    );
    DjWishNotificationNavigator.instance.openVorabSignal.removeListener(
      _onOpenVorabFromNotification,
    );
    _showOnlyFavoritesNotifier.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Color _indicatorColorForIndex(int index) {
    var i = 0;
    if (_showSetlistTab) {
      if (index == i) return UIConstants.tabDjSetlistColor;
      i++;
    }
    if (_showVorabTab) {
      if (index == i) return UIConstants.tabVorabColor;
      i++;
    }
    if (index == i) return UIConstants.tabOffenColor;
    i++;
    if (index == i) return UIConstants.tabGespieltColor;
    return UIConstants.tabAbgelehntColor;
  }

  List<Widget> _buildTabs(AppLocalizations l, TabController controller) {
    final compact = _showVorabTab || _showSetlistTab;
    final tabs = <Widget>[];
    var i = 0;
    if (_showSetlistTab) {
      tabs.add(
        _tabLabel(
          l.translate('dj_setlist_tab'),
          UIConstants.tabDjSetlistColor,
          controller.index == i,
          compact: compact,
          tooltip: l.translate('dj_setlist_tab'),
        ),
      );
      i++;
    }
    if (_showVorabTab) {
      tabs.add(
        _tabLabel(
          l.dj_wish_tab_vorab,
          UIConstants.tabVorabColor,
          controller.index == i,
          compact: compact,
          tooltip: l.vorab_tab,
        ),
      );
      i++;
    }
    tabs.add(
      _tabLabel(
        l.dj_wish_tab_open,
        UIConstants.tabOffenColor,
        controller.index == i,
        compact: compact,
        tooltip: l.open,
      ),
    );
    i++;
    tabs.add(
      _tabLabel(
        l.dj_wish_tab_played,
        UIConstants.tabGespieltColor,
        controller.index == i,
        compact: compact,
        tooltip: l.played,
      ),
    );
    i++;
    tabs.add(
      _tabLabel(
        l.dj_wish_tab_rejected,
        UIConstants.tabAbgelehntColor,
        controller.index == i,
        compact: compact,
        tooltip: l.rejected,
      ),
    );
    return tabs;
  }

  Widget _tabLabel(
    String text,
    Color color,
    bool selected, {
    bool compact = false,
    String? tooltip,
  }) {
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 11.5 : 12.5,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: color,
          height: 1.0,
        ),
      ),
    );
    return Tab(
      child: tooltip != null
          ? Tooltip(message: tooltip, child: label)
          : label,
    );
  }

  List<Widget> _buildTabViews(String? partyId) {
    final views = <Widget>[];
    if (_showSetlistTab && partyId != null) {
      views.add(DjSetlistTabPage(partyId: partyId));
    } else if (_showSetlistTab) {
      views.add(const SizedBox.shrink());
    }
    if (_showVorabTab) {
      views.add(
        VorabPage(
          requests: widget.requests,
          onPageOpened: widget.onPageOpened,
        ),
      );
    }
    views.addAll([
      OffenPage(
        key: widget.offenPageKey,
        requests: widget.requests,
        onPageOpened: widget.onPageOpened,
        showOnlyFavoritesNotifier: _showOnlyFavoritesNotifier,
      ),
      GespieltPage(requests: widget.requests),
      AbgelehntPage(
        requests: widget.requests,
        onWishRestoredToOpen: () =>
            _tabController?.animateTo(_offenTabIndex),
      ),
    ]);
    return views;
  }

  ActivePartyInfo? _partyInfoForHeader(
    OpenWishesVisibility? visibility,
    ActivePartyInfo? session,
  ) {
    final partyId = visibility?.partyId;
    if (partyId == null || partyId.isEmpty) return null;
    if (session != null && session.partyId == partyId) return session;

    final stored = ActivePartyService.getStoredSession();
    if (stored != null && stored.partyId == partyId) {
      return stored;
    }

    return ActivePartyInfo(
      partyId: partyId,
      partyName: visibility?.partyName,
      startDate: visibility?.startDate,
      endDate: visibility?.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = VbTextDirection.isRtl(context);

    return ValueListenableBuilder<OpenWishesVisibility?>(
      valueListenable: OpenWishesVisibilityService.visibilityNotifier,
      builder: (context, visibility, _) {
        final partyId = visibility?.partyId;

        return ValueListenableBuilder<ActivePartyInfo?>(
          valueListenable: ActivePartyService.storedSessionNotifier,
          builder: (context, session, _) {
            final effective = _partyInfoForHeader(visibility, session);
            final browserPartyId = _resolveBrowserPartyId(visibility, session);

            return StreamBuilder<bool>(
          stream: partyId != null
              ? WishManagementService.watchHasQueuedPreWishes(partyId)
              : Stream.value(false),
          builder: (context, vorabSnapshot) {
            _ensureSetlistStream(partyId);
            return ValueListenableBuilder<SessionProStatus?>(
              valueListenable: DjProSessionService.instance.sessionProStatus,
              builder: (context, _, __) {
            return StreamBuilder<List<EventSetlistTrack>>(
              stream: _setlistStream ??
                  Stream.value(const <EventSetlistTrack>[]),
              builder: (context, setlistSnapshot) {
            final showVorab = partyId != null && vorabSnapshot.data == true;
            final showSetlist = partyId != null &&
                ProFeatureGuard.canUseProExclusiveNow() &&
                (setlistSnapshot.data?.isNotEmpty ?? false);
            final wantLength =
                3 + (showVorab ? 1 : 0) + (showSetlist ? 1 : 0);
            if (_showVorabTab != showVorab ||
                _showSetlistTab != showSetlist ||
                _tabController == null ||
                _tabController!.length != wantLength) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final wasOnVorab =
                    _showVorabTab && _tabController?.index == _vorabTabIndex;
                setState(() {
                  _ensureTabController(
                    showVorab: showVorab,
                    showSetlist: showSetlist,
                    // null: Index verschieben, wenn Setlist/Vorab vorne
                    // eingefügt wird — sonst landet Offen auf der Setlist.
                    preferIndex: !showVorab && wasOnVorab
                        ? (showSetlist ? 1 : 0)
                        : null,
                  );
                });
              });
            }

            final controller = _tabController;
            if (controller == null) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomPageHeader(
                  icon: Icons.library_music,
                  title: l.appName,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.laptop,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: l.dj_browser_open_tooltip,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () => _onOpenDjBrowser(context, browserPartyId),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            VibesboxFullscreenService.instance.isFullscreen,
                        builder: (context, fullscreen, _) {
                          return IconButton(
                            icon: Icon(
                              fullscreen
                                  ? Icons.close_fullscreen
                                  : Icons.open_in_full,
                              color: Colors.white,
                              size: 22,
                            ),
                            tooltip: fullscreen
                                ? l.vibesbox_fullscreen_exit
                                : l.vibesbox_fullscreen_enter,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            onPressed:
                                VibesboxFullscreenService.instance.toggle,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _buildPartyContextHeader(
                  context,
                  l,
                  isRtl,
                  effective,
                  visibility,
                ),
                Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.45),
                        thickness: 1,
                      ),
                      AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          final indicatorColor =
                              _indicatorColorForIndex(controller.index);
                          return SizedBox(
                            height: 28,
                            child: TabBar(
                                  controller: controller,
                                  indicatorSize: TabBarIndicatorSize.label,
                                  padding: EdgeInsets.zero,
                                  labelPadding: EdgeInsets.symmetric(
                                    horizontal: (_showVorabTab ||
                                            _showSetlistTab)
                                        ? 4
                                        : 8,
                                  ),
                                  indicator: UnderlineTabIndicator(
                                    borderSide: BorderSide(
                                      color: indicatorColor,
                                      width: 2,
                                    ),
                                    insets: EdgeInsets.zero,
                                  ),
                                  dividerColor: UIConstants.colorWhite
                                      .withValues(alpha: 0.3),
                                  labelColor: Colors.transparent,
                                  unselectedLabelColor: Colors.transparent,
                                  tabs: _buildTabs(l, controller),
                                ),
                          );
                        },
                      ),
                      SizedBox(
                        height: 44,
                        child: AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) {
                            if (_showVorabTab &&
                                controller.index == _vorabTabIndex) {
                              return _buildVorabToolbar(
                                context,
                                l,
                                isRtl,
                                partyId,
                              );
                            }
                            if (controller.index != _offenTabIndex) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              child: Row(
                                children: [
                                  if (partyId != null && partyId.isNotEmpty)
                                    OffenBlacklistCountBanner(
                                      partyId: partyId,
                                      compact: true,
                                    ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle_outline,
                                      color: partyId != null
                                          ? UIConstants.appOrange
                                          : Colors.grey,
                                    ),
                                    tooltip: l.addManualWish,
                                    onPressed: partyId != null
                                        ? () => ManualWishPage.show(
                                              context,
                                              partyId: partyId,
                                            )
                                        : null,
                                  ),
                                  ValueListenableBuilder<bool>(
                                        valueListenable:
                                            _showOnlyFavoritesNotifier,
                                        builder: (context, showOnly, _) {
                                          final isFree = UserService()
                                                  .sessionProStatus
                                                  .value
                                                  ?.isActive !=
                                              true;
                                          return StreamBuilder<QuerySnapshot>(
                                            stream: partyId != null
                                                ? WishManagementService
                                                    .getFavoriteWishesStream(
                                                    partyId,
                                                    'pending',
                                                  )
                                                : null,
                                            builder: (context, favSnapshot) {
                                              final isFavoritePresent =
                                                  favSnapshot.hasData &&
                                                      (favSnapshot
                                                              .data
                                                              ?.docs
                                                              .isNotEmpty ??
                                                          false);
                                              final hasParty = partyId != null;
                                              return IconButton(
                                                icon: Icon(
                                                  isFavoritePresent
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                ),
                                                color: hasParty
                                                    ? (isFavoritePresent
                                                        ? Colors.red
                                                        : (isFree
                                                            ? UIConstants
                                                                .freeLimitBorderRed
                                                            : UIConstants
                                                                .frameNoParty
                                                                .withValues(
                                                                    alpha: 0.7)))
                                                    : UIConstants.frameNoParty
                                                        .withValues(alpha: 0.4),
                                                tooltip: hasParty
                                                    ? (showOnly
                                                        ? l.favorites_filter_tooltip_active
                                                        : l.favorites_filter_tooltip_inactive)
                                                    : l.favorites_filter_tooltip_no_party,
                                                onPressed: hasParty
                                                    ? () {
                                                        if (isFree) {
                                                          FreeFeatureLockedDialog
                                                              .show(context);
                                                          return;
                                                        }
                                                        _showOnlyFavoritesNotifier
                                                                .value =
                                                            !_showOnlyFavoritesNotifier
                                                                .value;
                                                      }
                                                    : null,
                                                onLongPress: hasParty &&
                                                        !isFree
                                                    ? () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                FavoritenPage(
                                                              requests: widget
                                                                  .requests,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    : (hasParty && isFree
                                                        ? () =>
                                                            FreeFeatureLockedDialog
                                                                .show(context)
                                                        : null),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          if (!_showVorabTab ||
                              controller.index != _vorabTabIndex) {
                            return const SizedBox.shrink();
                          }
                          return _buildVorabPausedBanner(partyId);
                        },
                      ),
                      Expanded(
                        child: TabBarView(
                          key: ValueKey<String>(
                            'dj-tabs-${controller.length}-'
                            '${_showSetlistTab ? 1 : 0}-'
                            '${_showVorabTab ? 1 : 0}',
                          ),
                          controller: controller,
                          children: _buildTabViews(partyId),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
              },
            );
              },
            );
          },
        );
          },
        );
      },
    );
  }

  Widget _buildPartyContextHeader(
    BuildContext context,
    AppLocalizations l,
    bool isRtl,
    ActivePartyInfo? effective,
    OpenWishesVisibility? visibility,
  ) {
    final align = isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = isRtl ? TextAlign.end : TextAlign.start;
    final lineStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.78),
      fontSize: 12,
      height: 1.25,
    );

    if (effective == null || effective.partyId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(
              l.wishbox_dj_no_party_selected,
              style: lineStyle,
              textAlign: textAlign,
            ),
          ],
        ),
      );
    }

    final hasName = effective.partyName?.trim().isNotEmpty ?? false;
    final hasStart = effective.startDate != null;
    if (!hasName && !hasStart) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
        child: Align(
          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }

    final name = hasName
        ? effective.partyName!.trim()
        : l.wishbox_dj_party_unnamed;

    final endPart = effective.endDate != null
        ? FormattingUtils.formatCompactPartyEndDateTime(
            effective.endDate!,
            context,
          )
        : (effective.startDate != null
            ? l.party_running_still
            : l.wishbox_dj_party_time_not_set);

    final subtitleLine = '${l.party_end_label} $endPart – $name';

    final inGracePeriod = visibility != null &&
        visibility.isGracePeriodOnly &&
        visibility.partyId == effective.partyId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(subtitleLine, style: lineStyle, textAlign: textAlign),
          if (inGracePeriod) ...[
            const SizedBox(height: 4),
            PartyGraceCountdown(
              graceEndsAt: visibility.graceEndsAt,
              onEndGracePeriod: () => GracePeriodEndDialog.confirmAndEnd(
                context,
                effective.partyId,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
