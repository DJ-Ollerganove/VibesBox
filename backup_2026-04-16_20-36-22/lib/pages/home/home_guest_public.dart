import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../constants/app_assets.dart';
import '../../utils/formatting_utils.dart';
import '../../widgets/dj_features_card.dart';
import '../../widgets/home_guest_info.dart';
import '../../widgets/party_open_button.dart';

class HomeGuestPublic extends StatelessWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final VoidCallback? onLoginRequested;
  final VoidCallback? onRegisterRequested;
  final VoidCallback? onOpenParty;

  const HomeGuestPublic({
    super.key,
    required this.cardBuilder,
    this.onLoginRequested,
    this.onRegisterRequested,
    this.onOpenParty,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    final user = FirebaseAuth.instance.currentUser;
    // Nicht eingeloggt: Public Guest Home
    if (user != null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Header (tageszeitabhängig): "Guten Abend bei VibesBox" (bzw. Morgen/Tag)
          // Wichtig: Global bleibt LTR (Hamburger/Navigation). Für Arabisch wird nur der Content hier lokal RTL gerendert,
          // damit Satzzeichen (z.B. Punkt) korrekt links stehen.
          cardBuilder(
            context,
            isRtl
                ? Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 14),
                              child: Image.asset(
                                'assets/icon/vibesbox-logo.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stackTrace) {
                                  return AppAssets.placeholder(
                                    width: 120,
                                    height: 120,
                                  );
                                },
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      FormattingUtils.getGreetingForGuest(context),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.normal,
                                          ),
                                      textAlign: TextAlign.start,
                                    ),
                                  ),
                                if (onOpenParty != null) ...[
                                  const SizedBox(height: 12),
                                  PartyOpenButton(onPressed: onOpenParty!),
                                ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 14),
                            child: Image.asset(
                              'assets/icon/vibesbox-logo.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) {
                                return AppAssets.placeholder(
                                  width: 120,
                                  height: 120,
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    FormattingUtils.getGreetingForGuest(context),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.normal,
                                        ),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                if (onOpenParty != null) ...[
                                  const SizedBox(height: 12),
                                  PartyOpenButton(onPressed: onOpenParty!),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          HomeGuestInfo(
            cardBuilder: cardBuilder,
            onLoginRequested: onLoginRequested,
            onRegisterRequested: onRegisterRequested,
          ),
          const SizedBox(height: 24),
          const DjFeaturesCard(),
            const SizedBox(height: 48),
          ],
        ),
    );
  }
}


