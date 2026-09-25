import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

/// Abschnitt im Einstellungs-Hilfe-Dialog (wie Musikerkennung).
class SettingsHelpBullet {
  const SettingsHelpBullet({
    required this.title,
    required this.body,
    this.icon,
  });

  final String title;
  final String body;
  final IconData? icon;
}

Future<void> showSettingsHelpFromL10n(
  BuildContext context, {
  required String titleKey,
  required String introKey,
  required List<(String titleKey, String bodyKey)> bullets,
}) async {
  final l = AppLocalizations.of(context)!;
  await showSettingsHelpDialog(
    context,
    title: l.translate(titleKey),
    intro: l.translate(introKey),
    bullets: [
      for (final b in bullets)
        SettingsHelpBullet(
          title: l.translate(b.$1),
          body: l.translate(b.$2),
        ),
    ],
  );
}

Future<void> showPageInfoHelp(
  BuildContext context, {
  required String titleKey,
  required String prefix,
  List<(String titleKey, String bodyKey)> extraBullets = const [],
}) {
  return showSettingsHelpFromL10n(
    context,
    titleKey: titleKey,
    introKey: '${prefix}_intro',
    bullets: [
      ('${prefix}_what', '${prefix}_what_body'),
      ...extraBullets,
      ('${prefix}_when', '${prefix}_when_body'),
    ],
  );
}

/// Gleicher Dialog wie die Musikerkennung: Verlauf, i-Icon, Abschnitte.
Future<void> showSettingsHelpDialog(
  BuildContext context, {
  required String title,
  String? intro,
  required List<SettingsHelpBullet> bullets,
}) async {
  final locale = Localizations.localeOf(context).languageCode;
  final isRtl = VbTextDirection.isRtlLanguageCode(locale);

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx)!;
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _SettingsHelpBody(
            l: l,
            title: title,
            intro: intro,
            bullets: bullets,
            maxContentHeight: MediaQuery.sizeOf(ctx).height * 0.62,
          ),
        ),
      );
    },
  );
}

class _SettingsHelpBody extends StatelessWidget {
  const _SettingsHelpBody({
    required this.l,
    required this.title,
    required this.intro,
    required this.bullets,
    required this.maxContentHeight,
  });

  final AppLocalizations l;
  final String title;
  final String? intro;
  final List<SettingsHelpBullet> bullets;
  final double maxContentHeight;

  static const LinearGradient _accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFF8C00),
      Color(0xFF6E6E6E),
      Color(0xFFFFA726),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _accentGradient,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => _accentGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => _accentGradient.createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxContentHeight),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (intro != null && intro!.trim().isNotEmpty) ...[
                        Text(
                          intro!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            height: 1.25,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 14),
                      ],
                      for (var i = 0; i < bullets.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        if (bullets[i].icon != null)
                          _bulletWithIcon(
                            bullets[i].icon!,
                            bullets[i].title,
                            bullets[i].body,
                          )
                        else
                          _bullet(bullets[i].title, bullets[i].body),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Text(
                          l.understood,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => _accentGradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: const Text(
                '• ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => _accentGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, top: 4),
          child: Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.35,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }

  Widget _bulletWithIcon(IconData icon, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => _accentGradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => _accentGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 26, top: 4),
          child: Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.35,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }
}
