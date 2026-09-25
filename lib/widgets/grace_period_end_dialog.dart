import 'package:flutter/material.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../services/open_wishes_visibility_service.dart';
import '../utils/debug_log.dart';
import '../utils/firebase_error_message.dart';
import '../utils/ui_constants.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

/// Bestätigung + Firestore: Nachlaufzeit für eine Party sofort beenden.
class GracePeriodEndDialog {
  GracePeriodEndDialog._();

  static Future<void> confirmAndEnd(
    BuildContext context,
    String partyId,
  ) async {
    if (partyId.isEmpty) return;
    final l = AppLocalizations.of(context)!;
    final isRtl = VbTextDirection.isRtl(context);
    const accent = UIConstants.appOrange;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: UIConstants.colorGreyGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent, width: 2),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  l.grace_period_hide_wishes_now,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 12),
                Text(
                  l.grace_period_hide_wishes_confirm,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(l.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(l.grace_period_hide_now),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await OpenWishesVisibilityService.hideWishesNow(partyId);
      if (!context.mounted) return;
      showVibesSnackBar(context, 
        SnackBar(
          content: Text(l.snackbar_grace_wishes_hidden),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      debugLog('❌ Nachlaufzeit beenden fehlgeschlagen: $e\n$st');
      if (!context.mounted) return;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.snackbar_error_details(formatFirebaseErrorDetail(e))),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }
}
