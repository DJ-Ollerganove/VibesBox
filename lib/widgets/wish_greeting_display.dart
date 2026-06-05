import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/greeting_translator.dart';

/// Anzeigename eines Wünschenden: leer → lokalisiertes „Kein Name“.
String wisherDisplayName(String? raw, AppLocalizations l) {
  final n = raw?.trim() ?? '';
  return n.isEmpty ? l.no_name : n;
}

/// Grußtext + optionale Übersetzung (gleiche Logik wie in der Wunsch-Detailansicht).
class WishGreetingTextWithTranslation extends StatelessWidget {
  final String greeting;
  final bool isRtl;
  final TextStyle greetingStyle;
  final TextStyle translationStyle;
  final double loadingIndicatorSize;

  const WishGreetingTextWithTranslation({
    super.key,
    required this.greeting,
    required this.isRtl,
    required this.greetingStyle,
    required this.translationStyle,
    this.loadingIndicatorSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (greeting.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: GreetingTranslator.translateGreetingIfNeeded(greeting, context),
      builder: (context, snapshot) {
        final translation = snapshot.data?.trim();
        final hasTranslation = translation != null &&
            translation.isNotEmpty &&
            translation != greeting.trim();

        return Column(
          crossAxisAlignment:
              isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              greeting,
              style: greetingStyle,
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              textDirection:
                  isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  height: loadingIndicatorSize,
                  width: loadingIndicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: translationStyle.color?.withValues(alpha: 0.7) ??
                        const Color(0xFFB0B0B0),
                  ),
                ),
              )
            else if (hasTranslation)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  textDirection:
                      isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.translate,
                      size: translationStyle.fontSize != null
                          ? translationStyle.fontSize! + 1
                          : 14,
                      color: translationStyle.color?.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        translation,
                        style: translationStyle,
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        textDirection: isRtl
                            ? ui.TextDirection.rtl
                            : ui.TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Kompakte Wünschenden-Zeilen: Spalte 1 = Name, Spalte 2 = Gruß + Übersetzung.
class WishGreetingCompactRow extends StatelessWidget {
  final List<Map<String, dynamic>> wishers;
  final bool isRtl;
  final TextStyle nameStyle;
  final TextStyle greetingStyle;
  final TextStyle translationStyle;

  const WishGreetingCompactRow({
    super.key,
    required this.wishers,
    required this.isRtl,
    required this.nameStyle,
    required this.greetingStyle,
    required this.translationStyle,
  });

  static bool _isDisplayName(String name) {
    final n = name.trim();
    return n.isNotEmpty && n.toLowerCase() != 'gast';
  }

  /// Zeilen für die Kompakt-Karte: Anzeigename und/oder Gruß.
  static List<Map<String, dynamic>> wishersForCompactDisplay(
    List<Map<String, dynamic>> wishersList,
  ) {
    return wishersList.where((w) {
      final name = (w['name'] as String? ?? '').trim();
      final greeting = (w['greeting'] as String? ?? '').trim();
      if (greeting.isNotEmpty) return true;
      if (name.isEmpty) return true;
      return _isDisplayName(name);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = wishersForCompactDisplay(wishers);
    if (entries.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment:
          isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _WisherNameGreetingRow(
            name: wisherDisplayName(
              (entries[i]['name'] as String? ?? '').trim(),
              l,
            ),
            greeting: (entries[i]['greeting'] as String? ?? '').trim(),
            isRtl: isRtl,
            nameStyle: nameStyle,
            greetingStyle: greetingStyle,
            translationStyle: translationStyle,
          ),
        ],
      ],
    );
  }
}

class _WisherNameGreetingRow extends StatelessWidget {
  final String name;
  final String greeting;
  final bool isRtl;
  final TextStyle nameStyle;
  final TextStyle greetingStyle;
  final TextStyle translationStyle;

  const _WisherNameGreetingRow({
    required this.name,
    required this.greeting,
    required this.isRtl,
    required this.nameStyle,
    required this.greetingStyle,
    required this.translationStyle,
  });

  @override
  Widget build(BuildContext context) {
    final hasGreeting = greeting.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      children: [
        Text(
          name,
          style: nameStyle,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
        ),
        if (hasGreeting) const SizedBox(width: 8),
        Expanded(
          child: hasGreeting
              ? WishGreetingTextWithTranslation(
                  greeting: greeting,
                  isRtl: isRtl,
                  greetingStyle: greetingStyle,
                  translationStyle: translationStyle,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
