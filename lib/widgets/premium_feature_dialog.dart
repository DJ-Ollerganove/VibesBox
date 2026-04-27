import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class PremiumFeatureDialog {
  PremiumFeatureDialog._();

  static Future<void> show(BuildContext context) async {
    final l = AppLocalizations.of(context)!;

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'VibesBox Pro',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          l.premiumFeatureInfoText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/paywall');
            },
            child: Text(l.getVibesboxPro),
          ),
        ],
      ),
    );
  }
}


