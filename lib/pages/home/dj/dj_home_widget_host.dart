import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/dj_home_layout_service.dart';
import '../../../services/user_service.dart';
import '../../../widgets/common/pwa_widget_cell.dart';
import '../../../widgets/home_cells/dual_statistics_card.dart';
import '../../../widgets/pro_comparison_table.dart';
import '../../../widgets/pro_promotion_banner.dart';
import 'dj_home_party_resolver.dart';
import 'widgets/dj_home_feed_widgets.dart';
import 'widgets/dj_home_party_tile_carousel.dart';

/// Abhängigkeiten für modulare Startseiten-Widgets (von [HomeDj] bereitgestellt).
class DjHomeWidgetDeps {
  const DjHomeWidgetDeps({
    required this.effectiveDjId,
    required this.gracePeriodMinutes,
    required this.cardBuilder,
    required this.partySnapshot,
    required this.parties,
    required this.timeStream,
    required this.formatDateTime,
    required this.buildPartyStatusSection,
    required this.buildTrialBanner,
    required this.buildUpcomingPartyCard,
    required this.displayName,
    required this.onCustomizeHome,
  });

  final String? effectiveDjId;
  final int gracePeriodMinutes;
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final DjHomePartySnapshot partySnapshot;
  final List<QueryDocumentSnapshot> parties;
  final Stream<DateTime> timeStream;
  final String Function(DateTime date, BuildContext? context) formatDateTime;
  final Widget Function(BuildContext context) buildPartyStatusSection;
  final Widget Function(BuildContext context) buildTrialBanner;
  final Widget Function(BuildContext context, QueryDocumentSnapshot party)
      buildUpcomingPartyCard;
  final String displayName;
  final VoidCallback onCustomizeHome;
}

/// Rendert ein einzelnes konfigurierbares Startseiten-Widget.
class DjHomeWidgetHost {
  const DjHomeWidgetHost._();

  static Widget? build(
    BuildContext context,
    String widgetId,
    DjHomeWidgetDeps deps,
  ) {
    final l = AppLocalizations.of(context)!;
    switch (widgetId) {
      case DjHomeWidgetId.welcome:
        return const SizedBox.shrink();
      case DjHomeWidgetId.partyStatus:
        return deps.buildPartyStatusSection(context);
      case DjHomeWidgetId.statsLive:
        return _wrapStats(
          context,
          deps,
          partyId: deps.partySnapshot.activePartyId,
          sectionTitle: l.dj_home_widget_stats_live,
          showLiveIndicator: true,
          emptyHint: l.dj_home_no_party_running,
        );
      case DjHomeWidgetId.statsLast:
        return _wrapStats(
          context,
          deps,
          partyId: deps.partySnapshot.lastFinishedParty?.id,
          sectionTitle: l.dj_home_widget_stats_last,
          emptyHint: l.dj_home_no_saved_last_party,
        );
      case DjHomeWidgetId.statsUpcoming:
        return _buildUpcomingPreview(context, deps);
      case DjHomeWidgetId.statsLogins:
        return _buildLogins(context, deps);
      case DjHomeWidgetId.statsTotal:
        return _buildTotal(context, deps);
      case DjHomeWidgetId.partyCarousel:
        return DjHomePartyTileCarousel(
          allParties: deps.parties,
          timeStream: deps.timeStream,
          mode: 'management',
        );
      case DjHomeWidgetId.partyHistoryCarousel:
        return DjHomePartyTileCarousel(
          allParties: deps.parties,
          timeStream: deps.timeStream,
          mode: 'history',
        );
      case DjHomeWidgetId.historyRecent:
        return const DjHomeRecentHistoryWidget();
      case DjHomeWidgetId.openWishesCount:
        return const DjHomeOpenWishesCountWidget();
      case DjHomeWidgetId.preWishesCount:
        return const DjHomePreWishesCountWidget();
      case DjHomeWidgetId.proTrialBanner:
        final trialUsed = UserScope.userOf(context)?.trialUsed ?? true;
        final isFree = UserService().sessionProStatus.value?.isActive != true;
        if (!DjHomeWidgetId.showProTrialBannerOnHome(
          isFreeDj: isFree,
          trialUsed: trialUsed,
        )) {
          return const SizedBox.shrink();
        }
        return deps.buildTrialBanner(context);
      case DjHomeWidgetId.proPromotion:
        if (UserService().sessionProStatus.value?.isActive == true) {
          return const SizedBox.shrink();
        }
        return _buildProPromotion(context);
      case DjHomeWidgetId.proComparison:
        if (!DjHomeWidgetId.showProComparisonOnHome(
          UserService().sessionProStatus.value?.isActive != true,
        )) {
          return const SizedBox.shrink();
        }
        return _buildProComparison(context);
      default:
        return null;
    }
  }

  static Widget _wrapStats(
    BuildContext context,
    DjHomeWidgetDeps deps, {
    required String? partyId,
    required String sectionTitle,
    required String emptyHint,
    bool showLiveIndicator = false,
  }) {
    if (deps.effectiveDjId == null) {
      return _modularStatsShell(
        sectionTitle: sectionTitle,
        showLiveIndicator: showLiveIndicator,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (partyId == null || partyId.isEmpty) {
      return _modularStatsShell(
        sectionTitle: sectionTitle,
        showLiveIndicator: showLiveIndicator,
        child: Text(
          emptyHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }
    return DualStatisticsCard(
      cardBuilder: deps.cardBuilder,
      effectiveDjId: deps.effectiveDjId!,
      onlyFirstCard: true,
      showPartyStatsFrame: true,
      sectionTitle: sectionTitle,
      preferredPartyId: partyId,
    );
  }

  static Widget _modularStatsShell({
    required String sectionTitle,
    required Widget child,
    bool showLiveIndicator = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (showLiveIndicator) ...[
              _LiveDot(),
              const SizedBox(width: 6),
            ],
            Text(
              sectionTitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PwaWidgetCell(child: child),
      ],
    );
  }

  static Widget _buildLogins(BuildContext context, DjHomeWidgetDeps deps) {
    if (deps.effectiveDjId == null) return const SizedBox.shrink();
    return DualStatisticsCard(
      cardBuilder: deps.cardBuilder,
      effectiveDjId: deps.effectiveDjId!,
      skipFirstCard: true,
      onlyLoginCard: true,
    );
  }

  static Widget _buildTotal(BuildContext context, DjHomeWidgetDeps deps) {
    if (deps.effectiveDjId == null) return const SizedBox.shrink();
    return DualStatisticsCard(
      cardBuilder: deps.cardBuilder,
      effectiveDjId: deps.effectiveDjId!,
      skipFirstCard: true,
      onlyTotalCard: true,
    );
  }

  static Widget _buildUpcomingPreview(
    BuildContext context,
    DjHomeWidgetDeps deps,
  ) {
    final l = AppLocalizations.of(context)!;
    final upcoming = deps.partySnapshot.upcomingParty;
    if (upcoming == null) {
      return _hintBox(l.no_further_parties_planned);
    }
    return deps.buildUpcomingPartyCard(context, upcoming);
  }

  static Widget _buildProPromotion(BuildContext context) {
    final userModel = UserScope.userOf(context);
    final sessionActive = UserService().sessionProStatus.value?.isActive == true;
    if (userModel == null || sessionActive || !userModel.trialUsed) {
      return const SizedBox.shrink();
    }
    return const ProPromotionBanner(compactPadding: false);
  }

  static Widget _buildProComparison(BuildContext context) {
    final sessionActive = UserService().sessionProStatus.value?.isActive == true;
    if (sessionActive) return const SizedBox.shrink();
    return const ProComparisonTable();
  }

  static Widget _hintBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      ),
    );
  }
}

/// Grüner Puls-Punkt für Live-Statistik (Leerzustand).
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
