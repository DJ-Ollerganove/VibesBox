import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

/// Bestätigungsdialoge für Vorab-Wünsche (DJ-Übersicht / Detail).
class PreWishActionDialogs {
  PreWishActionDialogs._();

  static Future<bool?> showPublishAllConfirm(BuildContext context) {
    final isRtl = VbTextDirection.isRtl(context);
    final l = AppLocalizations.of(context)!;
    const borderColor = UIConstants.appGreen;
    const confirmColor = UIConstants.appGreen;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: UIConstants.colorGreyGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isRtl
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    l.pre_wish_publish_all_confirm_title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.pre_wish_publish_all_confirm_body,
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
                          onPressed: () => Navigator.pop(ctx, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(l.no),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(l.yes),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<bool?> showPublishConfirm(
    BuildContext context, {
    required String displayText,
  }) {
    final isRtl = VbTextDirection.isRtl(context);
    final l = AppLocalizations.of(context)!;
    const accent = UIConstants.colorPreWish;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: accent, width: 2),
            ),
            title: Text(
              l.pre_wish_publish_confirm_title,
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: accent,
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                Text(
                  l.pre_wish_publish_confirm_body,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                child: Text(l.yes),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                ),
                child: Text(l.no),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<bool?> showDeleteConfirm(
    BuildContext context, {
    required String displayText,
  }) {
    final isRtl = VbTextDirection.isRtl(context);
    final l = AppLocalizations.of(context)!;
    const accent = UIConstants.frameGesperrt;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: accent, width: 2),
            ),
            title: Text(
              l.delete,
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: accent,
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                Text(
                  l.confirm_delete_permanently,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                child: Text(l.yes),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                ),
                child: Text(l.no),
              ),
            ],
          ),
        );
      },
    );
  }
}
