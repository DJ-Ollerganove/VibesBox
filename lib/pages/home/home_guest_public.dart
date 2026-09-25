import 'package:flutter/material.dart';

import '../../widgets/dj_features_card.dart';
import '../../widgets/home_guest_info.dart';
import '../../widgets/home_guest_public_landing.dart';

class HomeGuestPublic extends StatelessWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final VoidCallback? onLoginRequested;
  final VoidCallback? onRegisterRequested;
  final VoidCallback? onOpenParty;
  final bool hasJoinedParty;

  const HomeGuestPublic({
    super.key,
    required this.cardBuilder,
    this.onLoginRequested,
    this.onRegisterRequested,
    this.onOpenParty,
    this.hasJoinedParty = false,
  });

  @override
  Widget build(BuildContext context) {
    // PWA-Startseite (ohne Kontakt) + bisherige App-Texte (HomeGuestInfo, DjFeaturesCard).
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeGuestPublicLanding(
            cardBuilder: cardBuilder,
            onOpenParty: onOpenParty,
            hasJoinedParty: hasJoinedParty,
          ),
          const SizedBox(height: 24),
          // Legacy-Texte (l10n: logged_in_user_more_features, available_as_guest, feature_dj_* …)
          HomeGuestInfo(
            cardBuilder: cardBuilder,
            onLoginRequested: onLoginRequested,
            onRegisterRequested: onRegisterRequested,
            showAuthButtons: false,
          ),
          const SizedBox(height: 24),
          const DjFeaturesCard(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}


