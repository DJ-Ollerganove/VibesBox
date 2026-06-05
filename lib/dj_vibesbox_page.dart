import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'l10n/app_localizations.dart';
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
import 'pages/favoriten_page.dart';
import 'pages/manual_wish_page.dart';
import 'services/user_service.dart';
import 'widgets/free_feature_locked.dart';
import 'widgets/heartbeat_pulse_dot.dart';
import 'services/dj_wish_notification_navigator.dart';

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
  final ValueNotifier<bool> _showOnlyFavoritesNotifier = ValueNotifier<bool>(false);

  int get _offenTabIndex => _showVorabTab ? 1 : 0;

  void _ensureTabController({required bool showVorab, int? preferIndex}) {
    final length = showVorab ? 4 : 3;
    if (_tabController != null && _tabController!.length == length) {
      _showVorabTab = showVorab;
      return;
    }

    final oldIndex = _tabController?.index ?? _offenTabIndex;
    _tabController?.dispose();

    int newIndex;
    if (preferIndex != null) {
      newIndex = preferIndex.clamp(0, length - 1);
    } else if (_tabController == null) {
      newIndex = showVorab ? 1 : 0;
    } else if (showVorab && !_showVorabTab) {
      newIndex = (oldIndex + 1).clamp(0, length - 1);
    } else if (!showVorab && _showVorabTab) {
      newIndex = oldIndex == 0 ? 0 : (oldIndex - 1).clamp(0, length - 1);
    } else {
      newIndex = oldIndex.clamp(0, length - 1);
    }

    _showVorabTab = showVorab;
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
    if (_tabController!.index != 0) {
      _tabController!.animateTo(0);
    }
    widget.onPageOpened?.call();
  }

  @override
  void initState() {
    super.initState();
    _ensureTabController(showVorab: false, preferIndex: 0);
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
    if (_showVorabTab) {
      switch (index) {
        case 0:
          return UIConstants.tabVorabColor;
        case 1:
          return UIConstants.tabOffenColor;
        case 2:
          return UIConstants.tabGespieltColor;
        default:
          return UIConstants.tabAbgelehntColor;
      }
    }
    switch (index) {
      case 0:
        return UIConstants.tabOffenColor;
      case 1:
        return UIConstants.tabGespieltColor;
      default:
        return UIConstants.tabAbgelehntColor;
    }
  }

  List<Widget> _buildTabs(AppLocalizations l, TabController controller) {
    final compact = _showVorabTab;
    if (_showVorabTab) {
      return [
        _tabLabel(
          l.dj_wish_tab_vorab,
          UIConstants.tabVorabColor,
          controller.index == 0,
          compact: compact,
          tooltip: l.vorab_tab,
        ),
        _tabLabel(
          l.dj_wish_tab_open,
          UIConstants.tabOffenColor,
          controller.index == 1,
          compact: compact,
          tooltip: l.open,
        ),
        _tabLabel(
          l.dj_wish_tab_played,
          UIConstants.tabGespieltColor,
          controller.index == 2,
          compact: compact,
          tooltip: l.played,
        ),
        _tabLabel(
          l.dj_wish_tab_rejected,
          UIConstants.tabAbgelehntColor,
          controller.index == 3,
          compact: compact,
          tooltip: l.rejected,
        ),
      ];
    }
    return [
      _tabLabel(
        l.dj_wish_tab_open,
        UIConstants.tabOffenColor,
        controller.index == 0,
        tooltip: l.open,
      ),
      _tabLabel(
        l.dj_wish_tab_played,
        UIConstants.tabGespieltColor,
        controller.index == 1,
        tooltip: l.played,
      ),
      _tabLabel(
        l.dj_wish_tab_rejected,
        UIConstants.tabAbgelehntColor,
        controller.index == 2,
        tooltip: l.rejected,
      ),
    ];
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
          fontSize: compact ? 11.5 : 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: color,
          height: 1.1,
        ),
      ),
    );
    return Tab(
      child: tooltip != null
          ? Tooltip(message: tooltip, child: label)
          : label,
    );
  }

  List<Widget> _buildTabViews() {
    if (_showVorabTab) {
      return [
        VorabPage(
          requests: widget.requests,
          onPageOpened: widget.onPageOpened,
        ),
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
      ];
    }
    return [
      OffenPage(
        key: widget.offenPageKey,
        requests: widget.requests,
        onPageOpened: widget.onPageOpened,
        showOnlyFavoritesNotifier: _showOnlyFavoritesNotifier,
      ),
      GespieltPage(requests: widget.requests),
      AbgelehntPage(
        requests: widget.requests,
        onWishRestoredToOpen: () => _tabController?.animateTo(_offenTabIndex),
      ),
    ];
  }

  ActivePartyInfo? _partyInfoForHeader(
    OpenWishesVisibility? visibility,
    ActivePartyInfo? session,
  ) {
    final partyId = visibility?.partyId;
    if (partyId == null || partyId.isEmpty) return null;
    if (session != null && session.partyId == partyId) return session;
    return ActivePartyInfo(
      partyId: partyId,
      endDate: visibility?.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur']
        .contains(Localizations.localeOf(context).languageCode);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<OpenWishesVisibility?>(
      stream: OpenWishesVisibilityService.watch(uid),
      builder: (context, visibilitySnapshot) {
        final visibility = visibilitySnapshot.data;
        final partyId = visibility?.partyId;

        return ValueListenableBuilder<ActivePartyInfo?>(
          valueListenable: ActivePartyService.storedSessionNotifier,
          builder: (context, session, _) {
            final effective = _partyInfoForHeader(visibility, session);

            return StreamBuilder<bool>(
          stream: partyId != null
              ? WishManagementService.watchHasQueuedPreWishes(partyId)
              : Stream.value(false),
          builder: (context, vorabSnapshot) {
            final showVorab = partyId != null && vorabSnapshot.data == true;
            if (_showVorabTab != showVorab ||
                _tabController == null ||
                _tabController!.length != (showVorab ? 4 : 3)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final wasOnVorab = _showVorabTab && _tabController?.index == 0;
                setState(() {
                  _ensureTabController(
                    showVorab: showVorab,
                    preferIndex: !showVorab && wasOnVorab
                        ? 0
                        : _tabController?.index,
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
                _buildPartyContextHeader(context, l, isRtl, effective),
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
                          return Row(
                            textDirection:
                                isRtl ? TextDirection.rtl : TextDirection.ltr,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TabBar(
                                  controller: controller,
                                  labelPadding: EdgeInsets.symmetric(
                                    horizontal: _showVorabTab ? 4 : 8,
                                  ),
                                  indicator: UnderlineTabIndicator(
                                    borderSide: BorderSide(
                                      color: indicatorColor,
                                      width: 3,
                                    ),
                                  ),
                                  dividerColor: UIConstants.colorWhite
                                      .withValues(alpha: 0.3),
                                  labelColor: Colors.transparent,
                                  unselectedLabelColor: Colors.transparent,
                                  tabs: _buildTabs(l, controller),
                                ),
                              ),
                              HeartbeatPulseDot(
                                padding: EdgeInsetsDirectional.only(
                                  start: isRtl ? 8 : 0,
                                  end: isRtl ? 0 : 8,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(
                        height: 52,
                        child: AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) {
                            if (controller.index != _offenTabIndex) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              child: Row(
                                mainAxisAlignment: isRtl
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle_outline,
                                      color: partyId != null
                                          ? UIConstants.appOrange
                                          : Colors.grey,
                                    ),
                                    tooltip: l.addManualWish,
                                    onPressed: partyId != null
                                        ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ManualWishPage(
                                                  partyId: partyId,
                                                ),
                                              ),
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
                                                        ? 'Nur Favoriten (aktiv). Lang: Favoriten-Seite'
                                                        : 'Nur Favoriten anzeigen. Lang: Favoriten-Seite')
                                                    : 'Favoriten (keine Party aktiv)',
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
                  child: TabBarView(
                    controller: controller,
                    children: _buildTabViews(),
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
  }

  Widget _buildPartyContextHeader(
    BuildContext context,
    AppLocalizations l,
    bool isRtl,
    ActivePartyInfo? effective,
  ) {
    final align = isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = isRtl ? TextAlign.end : TextAlign.start;
    final nameStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.94),
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final lineStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.72),
      fontSize: 12.5,
      height: 1.35,
    );

    if (effective == null || effective.partyId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
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

    final name = (effective.partyName?.trim().isNotEmpty ?? false)
        ? effective.partyName!.trim()
        : l.wishbox_dj_party_unnamed;

    final startLine = effective.startDate != null
        ? '${l.wishbox_dj_party_start}: ${FormattingUtils.formatDateTimeForDisplay(effective.startDate!, context)}'
        : '${l.wishbox_dj_party_start}: ${l.wishbox_dj_party_time_not_set}';

    final endLine = effective.endDate != null
        ? '${l.wishbox_dj_party_end}: ${FormattingUtils.formatDateTimeForDisplay(effective.endDate!, context)}'
        : (effective.startDate != null
            ? '${l.wishbox_dj_party_end}: ${l.party_running_still}'
            : '${l.wishbox_dj_party_end}: ${l.wishbox_dj_party_time_not_set}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(name, style: nameStyle, textAlign: textAlign),
          const SizedBox(height: 6),
          Text(startLine, style: lineStyle, textAlign: textAlign),
          Text(endLine, style: lineStyle, textAlign: textAlign),
        ],
      ),
    );
  }
}
