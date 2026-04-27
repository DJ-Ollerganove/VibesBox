import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/paywall_page.dart';
import '../../../services/subscription_sync_service.dart';
import '../../../services/user_service.dart';
import '../../../utils/ui_constants.dart';
import '../../../utils/debug_log.dart';

/// Baut die Pro-Status Karte (Top-Level im Profil).
/// Session-First: Widget zeigt ausschließlich den [SessionProStatus] aus dem UserService.
class ProStatusCard extends StatefulWidget {
  const ProStatusCard({super.key, required this.uid, this.onPurchased});

  final String uid;
  /// Wird aufgerufen, wenn der User über die Karte einen Kauf abgeschlossen hat (Paywall mit result true geschlossen).
  final VoidCallback? onPurchased;

  @override
  State<ProStatusCard> createState() => _ProStatusCardState();
}

class _ProStatusCardState extends State<ProStatusCard> {
  bool _paywallOpen = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionProStatus?>(
      valueListenable: UserService().sessionProStatus,
      builder: (context, session, _) {
        final userModel = UserService().currentUser.value;
        if (userModel == null) return const SizedBox.shrink();

        final isActive = session?.isActive ?? (userModel.isPremiumActive || userModel.isLifetime);
        final isLifetime = session?.isLifetime ?? userModel.isLifetime;
        final expiryDate = session?.proUntil;

        if (isActive && _paywallOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_paywallOpen) return;
            if (Navigator.of(context).canPop()) {
              setState(() => _paywallOpen = false);
              debugLog('CLEANUP-LOG: Session Pro-Status erkannt. Schließe Paywall-Modal.');
              Navigator.of(context).pop(true);
            }
          });
        }

        final locale = Localizations.localeOf(context);
        final loc = AppLocalizations.of(context)!;
        final dateFormat = DateFormat.yMd(locale.toString());

        return Column(
          children: [
            InkWell(
              onTap: isActive
                  ? null
                  : () async {
                      setState(() => _paywallOpen = true);
                      final bool? result = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Container(
                          height: MediaQuery.of(context).size.height * 0.9,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            border: Border.all(color: UIConstants.appOrange, width: 2),
                          ),
                          child: const PaywallPage(),
                        ),
                      );
                      setState(() => _paywallOpen = false);
                      if (mounted && result == true) {
                        SubscriptionSyncService.syncSubscriptionStatus(widget.uid).then(
                          (_) => UserService().refreshSessionProStatus(widget.uid),
                        );
                        widget.onPurchased?.call();
                      }
                    },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: isActive
                    ? UIConstants.statusFrameGreen
                    : UIConstants.statusFrameRed,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLifetime ? Icons.verified_user : (isActive ? Icons.star : Icons.star_border),
                          color: isLifetime ? const Color(0xFFFFD700) : (isActive ? UIConstants.appGreen : Colors.red),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isLifetime
                              ? (loc.vibesbox_pro_life)
                              : (isActive ? (loc.vibesbox_pro) : (loc.vibesbox_free)),
                          style: TextStyle(
                            color: isLifetime ? const Color(0xFFFFD700) : (isActive ? UIConstants.appGreen : Colors.red),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (!isLifetime) ...[
                      const SizedBox(height: 8),
                      if (isActive && expiryDate != null)
                        Text(
                          '${loc.pro_runs_until} ${dateFormat.format(expiryDate)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        )
                      else if (!isActive)
                        Text(
                          loc.click_for_pro_hint,
                          style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
