import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/formatting_utils.dart';
import '../../utils/ui_constants.dart';

/// Begrüßungs-Header für DJ-Ansicht:
/// Zeile 1: "Guten Morgen [Name]" (tageszeitabhängig) + optional Bearbeiten-Icon rechts
/// Zeile 2: "Dein DJ-Dashboard – Volle Kontrolle über die Party" (l10n)
class WelcomeHeader extends StatelessWidget {
  final String displayNameOrFallback;
  final VoidCallback? onCustomize;

  const WelcomeHeader({
    super.key,
    required this.displayNameOrFallback,
    this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final greeting = FormattingUtils.getGreeting(context);
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '$greeting $displayNameOrFallback',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.start,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
            if (onCustomize != null)
              IconButton(
                tooltip: l.dj_home_customize_tooltip,
                onPressed: onCustomize,
                icon: const Icon(Icons.edit, color: UIConstants.appOrange),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                visualDensity: VisualDensity.compact,
              ),
          ],
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


