import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Zentrale Design-Definition für Free-Feature-Sperren (grauer Verlauf, roter Rahmen).
/// Wiederverwendbar für Karten, Dialoge und Hinweis-Boxen (Social Media, Logo-Upload, Favoriten).
class FreeLimitDecoration {
  FreeLimitDecoration._();

  /// BoxDecoration für Container/Cards: dezenter Grau-Verlauf, markanter roter Rahmen, abgerundete Ecken.
  static BoxDecoration get boxDecoration => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            UIConstants.freeLimitGradientStart,
            UIConstants.freeLimitGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(UIConstants.freeLimitBorderRadius),
        border: Border.all(
          color: UIConstants.freeLimitBorderRed,
          width: UIConstants.freeLimitBorderWidth,
        ),
      );
}

/// Zentrales Dialog-Widget für gesperrte Pro-Features.
/// Nutzt [FreeLimitDecoration], rotes Schloss-Icon, Titel, Beschreibung und Button "VibesBox Pro holen" → /paywall.
/// In den nächsten Steps (Social Media, Logo-Upload, Favoriten) überall einbaubar.
class FreeFeatureLockedDialog extends StatelessWidget {
  final String? title;
  final String? description;

  const FreeFeatureLockedDialog({
    super.key,
    this.title,
    this.description,
  });

  /// Zeigt den Dialog modal. [title] und [description] optional (Fallback aus L10n).
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? description,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => FreeFeatureLockedDialog(
        title: title,
        description: description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveTitle = title ?? l10n.free_feature_locked_title;
    final effectiveDescription =
        description ?? l10n.free_feature_locked_description;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: FreeLimitDecoration.boxDecoration,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock,
              size: 48,
              color: UIConstants.freeLimitBorderRed,
            ),
            const SizedBox(height: 16),
            Text(
              effectiveTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: UIConstants.appWhite,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              effectiveDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/paywall');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: UIConstants.freeLimitBorderRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  l10n.getVibesboxPro,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.close,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
