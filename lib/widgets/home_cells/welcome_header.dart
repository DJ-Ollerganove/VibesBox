import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/formatting_utils.dart';

/// Begrüßungs-Header für DJ-Ansicht:
/// Zeile 1: "Guten Morgen [Name]" (tageszeitabhängig)
/// Zeile 2: "Dein DJ-Dashboard – Volle Kontrolle über die Party" (l10n)
class WelcomeHeader extends StatelessWidget {
  final String displayNameOrFallback;

  const WelcomeHeader({
    super.key,
    required this.displayNameOrFallback,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final greeting = FormattingUtils.getGreeting(context);
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting $displayNameOrFallback',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.start,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        ),
        const SizedBox(height: 4),
        RichText(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: TextAlign.start,
          text: TextSpan(
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: l.dj_dashboard_title,
              ),
              const TextSpan(text: '\n'),
              TextSpan(
                text: l.dj_dashboard_subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.normal,
                      color: Colors.grey[700],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


