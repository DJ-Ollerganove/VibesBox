import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../config/app_config.dart';
import '../services/user_service.dart';
import '../utils/ui_constants.dart';
import 'home/home_admin.dart';
import 'home/home_dj.dart';
import 'home/home_guest_private.dart';
import 'home/home_guest_public.dart';
import '../widgets/home_statistics_cards.dart';
import '../models/song_request.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onViewRoleChanged,
    this.currentViewRole,
    this.requests,
    this.onLoginRequested,
    this.onRegisterRequested,
    this.onOpenParty,
  });

  final Function(String?)? onViewRoleChanged;
  final String? currentViewRole;
  final List<SongRequest>? requests; // Zentrale Liste der Wünsche
  /// Wenn gesetzt (z. B. wenn Gast): Wechsel zur Login-Seite innerhalb der App statt pushNamed.
  final VoidCallback? onLoginRequested;
  /// Wenn gesetzt (z. B. wenn Gast): Wechsel zur Registrierung (Rollenwahl) innerhalb der App.
  final VoidCallback? onRegisterRequested;
  /// Wenn gesetzt: Wechsel zur VibesBox-Seite (Wunschliste/Check-In).
  final VoidCallback? onOpenParty;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  // Router-only: zentraler Reload-Trigger, damit `MainPage` weiterhin `loadUserData()`
  // aufrufen kann (ohne Home-Logik hier zu behalten).
  final ValueNotifier<int> _reloadTick = ValueNotifier<int>(0);
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    loadUserData();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      // Rebuild/Reload on auth changes
      loadUserData();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _reloadTick.dispose();
    super.dispose();
  }

  // External hook: called from `MainPageState._onIndexChanged(0)` to refresh home.
  Future<void> loadUserData() async {
    _reloadTick.value = _reloadTick.value + 1;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isRealAdmin = AppConfig.isAdminRole(UserService().currentUser.value);
    final viewRole = widget.currentViewRole;
    final isAdmin = isRealAdmin && (viewRole == null || viewRole == 'Admin');
    final isDJ = viewRole == 'DJ' || (isRealAdmin && viewRole == 'DJ');

    final adminSwitcher = isRealAdmin
        ? HomeAdminRoleSwitcherCard(
            currentViewRole: widget.currentViewRole,
            onChanged: widget.onViewRoleChanged,
            isAdminUser: isRealAdmin,
            cardBuilder: _wrapInElevatedDarkCard,
          )
        : null;

    Widget child;
    if (user == null) {
      child = HomeGuestPublic(
        cardBuilder: _wrapInGuestStyledCard,
        onLoginRequested: widget.onLoginRequested,
        onRegisterRequested: widget.onRegisterRequested,
        onOpenParty: widget.onOpenParty,
      );
    } else if (isAdmin) {
      child = HomeAdmin(
        cardBuilder: _wrapInElevatedDarkCard,
        reloadListenable: _reloadTick,
        currentViewRole: widget.currentViewRole,
        onViewRoleChanged: widget.onViewRoleChanged,
      );
    } else if (isDJ) {
      child = HomeDj(
        cardBuilder: _wrapInElevatedDarkCard,
        adminRoleSwitcherBottom: adminSwitcher,
        currentViewRole: widget.currentViewRole,
      );
    } else {
      child = HomeGuestPrivate(
        cardBuilder: _wrapInGuestStyledCard,
        reloadListenable: _reloadTick,
        adminRoleSwitcherBottom: adminSwitcher,
        onOpenParty: widget.onOpenParty,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: child,
      ),
    );
  }
  
  Widget _buildElevatedDarkCard(BuildContext context, {required Widget child}) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }

  /// Gast-Ansicht: Einheitliches Design (grauer Verlauf, oranger Rahmen) wie DJ-Widgets.
  Widget _wrapInGuestStyledCard(BuildContext context, Widget child) {
    return Container(
      decoration: UIConstants.guestBoxDecoration,
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
  
  Widget _wrapInElevatedDarkCard(BuildContext context, Widget child) {
    return _buildElevatedDarkCard(context, child: child);
  }
}
