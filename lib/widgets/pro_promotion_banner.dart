import 'package:flutter/material.dart';

import '../utils/ui_constants.dart';
import 'free_feature_locked.dart';

/// Kompakter Werbe-Banner für VibesBox Pro (nur für Free-DJs).
/// Nutzt [FreeLimitDecoration], Icon, Kurztext und Button zur Paywall.
/// Optional: [message] und [buttonLabel] für kontextspezifische Texte.
class ProPromotionBanner extends StatelessWidget {
  final String? message;
  final String? buttonLabel;
  final bool compactPadding;

  const ProPromotionBanner({
    super.key,
    this.message,
    this.buttonLabel,
    this.compactPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMessage = message ?? 'VibesBox Pro für volle Kontrolle';
    final effectiveButtonLabel = buttonLabel ?? 'Pro holen';
    return Padding(
      padding: compactPadding
          ? const EdgeInsets.only(top: 8, bottom: 8)
          : const EdgeInsets.only(top: 12, bottom: 12),
      child: Container(
        decoration: FreeLimitDecoration.boxDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium,
              size: 28,
              color: UIConstants.freeLimitBorderRed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                effectiveMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamed('/paywall'),
              style: FilledButton.styleFrom(
                backgroundColor: UIConstants.freeLimitBorderRed,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(effectiveButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
