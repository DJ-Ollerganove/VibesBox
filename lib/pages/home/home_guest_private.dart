import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/statistics_service.dart';
import '../../services/user_service.dart';
import '../../utils/formatting_utils.dart';
import '../../widgets/home_guest_info.dart';
import '../../widgets/home_statistics_cards.dart';
import '../../widgets/home_welcome_card.dart';
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
  int _totalWishes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.reloadListenable.addListener(_reload);
    _reload();
  }

  @override
  void didUpdateWidget(covariant HomeGuestPrivate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadListenable != widget.reloadListenable) {
      oldWidget.reloadListenable.removeListener(_reload);
      widget.reloadListenable.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.reloadListenable.removeListener(_reload);
    super.dispose();
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

  Future<void> _reload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final stats = await StatisticsService.loadUserStatistics(user);
      if (!mounted) return;
      setState(() {
        _totalWishes = stats.totalWishes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final userModel = UserScope.userOf(context);
    final loginCount = userModel?.loginCount ?? 0;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    final greetingName = _resolveGuestGreetingName(user, userModel);
    final greetingTitleUpper = FormattingUtils.getGuestHomeGreetingTitle(
      context,
      profileDisplayName: greetingName,
    ).toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: isRtl
          ? Directionality(
              // Global bleibt LTR (Hamburger/Navigation). Für Arabisch wird nur der Content hier lokal RTL gerendert.
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeWelcomeCard(
                    greetingTitleUpper: greetingTitleUpper,
                    cardBuilder: widget.cardBuilder,
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    HomeUserStatisticsCard(
                      loginCount: loginCount,
                      totalWishes: _totalWishes,
                      cardBuilder: widget.cardBuilder,
                    ),
                    const SizedBox(height: 24),
                    HomeNavigationHint(cardBuilder: widget.cardBuilder),
                    const SizedBox(height: 24),
                  ],
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
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  HomeUserStatisticsCard(
                    loginCount: loginCount,
                    totalWishes: _totalWishes,
                    cardBuilder: widget.cardBuilder,
                  ),
                  const SizedBox(height: 24),
                  HomeNavigationHint(cardBuilder: widget.cardBuilder),
                  const SizedBox(height: 24),
                ],
                if (widget.adminRoleSwitcherBottom != null) ...[
                  widget.adminRoleSwitcherBottom!,
                  const SizedBox(height: 24),
                ],
                const SizedBox(height: 48),
              ],
            ),
    );
  }
}


