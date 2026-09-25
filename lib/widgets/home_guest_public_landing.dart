import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Startseite wie PWA-Root (ohne Kontakt, Philosophie, Social, Legal) — `main_*` l10n.
class HomeGuestPublicLanding extends StatelessWidget {
  const HomeGuestPublicLanding({
    super.key,
    required this.cardBuilder,
    this.onOpenParty,
    this.hasJoinedParty = false,
  });

  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final VoidCallback? onOpenParty;
  final bool hasJoinedParty;

  String _t(AppLocalizations l, String key) => l.translate(key);

  static const _accentTitleStyle = TextStyle(
    color: UIConstants.appOrange,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(context, l),
        const SizedBox(height: 20),
        _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(l, 'main_intro_title'),
                style: _accentTitleStyle,
              ),
              const SizedBox(height: 12),
              Text(
                _t(l, 'main_intro_paragraph1'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.55,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(l, 'main_features_accent'),
                style: _accentTitleStyle,
              ),
              const SizedBox(height: 16),
              _featureTile(context, l, 'main_feature_guest_title', 'main_feature_guest_body'),
              const SizedBox(height: 12),
              _featureTile(context, l, 'main_feature_dj_title', 'main_feature_dj_body'),
              const SizedBox(height: 12),
              _featureTile(context, l, 'main_feature_auto_title', 'main_feature_auto_body'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context, AppLocalizations l) {
    final btnKey =
        hasJoinedParty ? 'main_hero_btn_party' : 'main_hero_btn_code';

    return cardBuilder(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icon/vibesbox-logo.png',
                height: 72,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) =>
                    AppAssets.placeholder(width: 72, height: 72),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _t(l, 'main_hero_title'),
                  style: _accentTitleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t(l, 'main_hero_tagline'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.45,
                ),
          ),
          if (onOpenParty != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: UIConstants.appOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onOpenParty,
                child: Text(
                  _t(l, btnKey),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) {
    return cardBuilder(context, child);
  }

  Widget _featureTile(
    BuildContext context,
    AppLocalizations l,
    String titleKey,
    String bodyKey,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF252528),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UIConstants.appOrange.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(l, titleKey),
            style: const TextStyle(
              color: UIConstants.appOrange,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(l, bodyKey),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
