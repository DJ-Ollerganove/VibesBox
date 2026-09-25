import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../../models/user_model.dart';
import '../../services/guest_wish_stats_service.dart';
import '../../services/user_service.dart';
import '../../services/app_update_service.dart';
import '../../utils/formatting_utils.dart';
import '../../widgets/home_guest_info.dart';
import '../../widgets/home_statistics_cards.dart';
import '../../widgets/home_welcome_card.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

class HomeGuestPrivate extends StatefulWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final Listenable reloadListenable;
  final Widget? adminRoleSwitcherBottom;

  const HomeGuestPrivate({
    super.key,
    required this.cardBuilder,
    required this.reloadListenable,
    this.adminRoleSwitcherBottom,
  });

  @override
  State<HomeGuestPrivate> createState() => _HomeGuestPrivateState();
}

class _HomeGuestPrivateState extends State<HomeGuestPrivate> {
  bool _backfillDone = false;
  bool _homeTelemetryScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.reloadListenable.addListener(_runBackfillIfNeeded);
    _runBackfillIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_homeTelemetryScheduled) return;
      _homeTelemetryScheduled = true;
      unawaited(AppUpdateService.logUserAppVersionFromHomeShell(area: 'guest'));
    });
  }

  @override
  void didUpdateWidget(covariant HomeGuestPrivate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadListenable != widget.reloadListenable) {
      oldWidget.reloadListenable.removeListener(_runBackfillIfNeeded);
      widget.reloadListenable.addListener(_runBackfillIfNeeded);
    }
  }

  @override
  void dispose() {
    widget.reloadListenable.removeListener(_runBackfillIfNeeded);
    super.dispose();
  }

  Future<void> _runBackfillIfNeeded() async {
    if (_backfillDone) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _backfillDone = true;
    await GuestWishStatsService.instance.ensureBackfilled(user.uid);
  }

  /// Anzeigename für Begrüßung: Profil (realName, displayName), sonst Auth, sonst E-Mail-Localteil.
  String? _resolveGuestGreetingName(User u, UserModel? m) {
    final r = m?.realName?.trim();
    if (r != null && r.isNotEmpty) return r;
    final d = m?.displayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    final ad = u.displayName?.trim();
    if (ad != null && ad.isNotEmpty) return ad;
    final e = u.email?.trim();
    if (e != null && e.contains('@')) {
      final local = e.split('@').first.trim();
      if (local.isNotEmpty) return local;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return ValueListenableBuilder<UserModel?>(
      valueListenable: UserService().currentUser,
      builder: (context, userModel, _) {
        final loginCount = userModel?.loginCount ?? 0;
        final totalWishes = userModel?.guestWishesSubmittedCount ?? 0;
        final isRtl = VbTextDirection.isRtl(context);
        final greetingName = _resolveGuestGreetingName(user, userModel);
        final greetingTitleUpper = FormattingUtils.getGuestHomeGreetingTitle(
          context,
          profileDisplayName: greetingName,
        ).toUpperCase();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isRtl
              ? Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HomeWelcomeCard(
                        greetingTitleUpper: greetingTitleUpper,
                        cardBuilder: widget.cardBuilder,
                      ),
                      const SizedBox(height: 24),
                      HomeUserStatisticsCard(
                        loginCount: loginCount,
                        totalWishes: totalWishes,
                        cardBuilder: widget.cardBuilder,
                      ),
                      const SizedBox(height: 24),
                      HomeNavigationHint(cardBuilder: widget.cardBuilder),
                      const SizedBox(height: 24),
                      if (widget.adminRoleSwitcherBottom != null) ...[
                        widget.adminRoleSwitcherBottom!,
                        const SizedBox(height: 24),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeWelcomeCard(
                      greetingTitleUpper: greetingTitleUpper,
                      cardBuilder: widget.cardBuilder,
                    ),
                    const SizedBox(height: 24),
                    HomeUserStatisticsCard(
                      loginCount: loginCount,
                      totalWishes: totalWishes,
                      cardBuilder: widget.cardBuilder,
                    ),
                    const SizedBox(height: 24),
                    HomeNavigationHint(cardBuilder: widget.cardBuilder),
                    const SizedBox(height: 24),
                    if (widget.adminRoleSwitcherBottom != null) ...[
                      widget.adminRoleSwitcherBottom!,
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
        );
      },
    );
  }
}
