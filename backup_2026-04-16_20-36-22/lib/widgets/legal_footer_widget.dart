import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';
import 'legal_page_scope.dart';

/// Dezenter Footer mit Links zu Impressum, Datenschutz und AGB.
/// Für Gast-Seiten (Login, Home Guest). Links öffnen in-app (kein externer Browser).
class LegalFooterWidget extends StatelessWidget {
  /// Kompakt-Modus: Kleinere Schrift, weniger Abstand (z. B. für Login)
  final bool compact;

  const LegalFooterWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur']
        .contains(Localizations.localeOf(context).languageCode);

    final imprintLabel = l.imprint;
    final privacyLabel = l.privacyPolicy;
    final agbLabel = l.agb;

    final scope = LegalPageScope.of(context);

    return Padding(
      padding: compact
          ? const EdgeInsets.symmetric(vertical: 16)
          : const EdgeInsets.symmetric(vertical: 24),
      child: Container(
        decoration: UIConstants.guestBoxDecoration,
        padding: compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 8,
          spacing: 8,
          children: [
            _FooterLink(
              label: imprintLabel,
              onTap: () => scope?.showImpressum(),
              compact: compact,
              isRtl: isRtl,
            ),
            if (!compact) _Separator(isRtl: isRtl),
            _FooterLink(
              label: privacyLabel,
              onTap: () => scope?.showDsgvo(),
              compact: compact,
              isRtl: isRtl,
            ),
            if (!compact) _Separator(isRtl: isRtl),
            _FooterLink(
              label: agbLabel,
              onTap: () => scope?.showAgb(),
              compact: compact,
              isRtl: isRtl,
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool isRtl;

  const _FooterLink({
    required this.label,
    required this.onTap,
    required this.compact,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: TextStyle(
          color: UIConstants.appOrange,
          fontSize: compact ? 12 : 14,
          decoration: TextDecoration.underline,
        ),
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  final bool isRtl;

  const _Separator({required this.isRtl});

  @override
  Widget build(BuildContext context) {
    return const Text(
      ' | ',
      style: TextStyle(
        color: UIConstants.colorGrey,
        fontSize: 14,
      ),
    );
  }
}
