import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../constants/app_assets.dart';

/// Große Welcome-Karte für die Startseite (Logo groß links, Text umfließt es).
class HomeWelcomeCard extends StatelessWidget {
  final String greetingTitleUpper;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const HomeWelcomeCard({
    super.key,
    required this.greetingTitleUpper,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    final line1 = l.welcomeLine1;
    final line2 = l.welcomeLine2;
    final bodyText = l.welcomeBodyText.isNotEmpty
        ? l.welcomeBodyText
        : l.welcomeFullText;

    return cardBuilder(
      context,
      isRtl
          ? Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    greetingTitleUpper,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 14),
                        child: Image.asset(
                          'assets/icon/vibesbox-logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) {
                            return AppAssets.placeholder(
                              width: 120,
                              height: 120,
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              line1,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.normal,
                                  ),
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              line2,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bodyText,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingTitleUpper,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 14),
                      child: Image.asset(
                        'assets/icon/vibesbox-logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return AppAssets.placeholder(
                            width: 120,
                            height: 120,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line1,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            line2,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  bodyText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
    );
  }
}


