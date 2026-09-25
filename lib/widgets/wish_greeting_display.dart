import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_helper.dart';
import '../services/translation_settings_service.dart';
import '../utils/greeting_translator.dart';

/// Marker in `requested_by` / `name` (sprachunabhängig).
const kManualByDjMarker = '__manual_by_dj__';
const kFromSetlistMarker = '__from_setlist__';

/// Anzeigename eines Wünschenden: leer → lokalisiertes „Kein Name“.
String wisherDisplayName(String? raw, AppLocalizations l) {
  final n = raw?.trim() ?? '';
  if (n.isEmpty) return l.no_name;
  if (n == kFromSetlistMarker || n == l.translate('from_setlist')) {
    return l.translate('from_setlist');
  }
  if (n == kManualByDjMarker || n == l.manualByDj) {
    return l.manualByDj;
  }
  return n;
}

/// Grußtext + optionale Übersetzung (gleiche Logik wie in der Wunsch-Detailansicht).
class WishGreetingTextWithTranslation extends StatefulWidget {
  final String greeting;
  final bool isRtl;
  final TextStyle greetingStyle;
  final TextStyle translationStyle;
  final double loadingIndicatorSize;
  /// Nur Übersetzungszeile (Original wird woanders angezeigt, z. B. Sprechblase).
  final bool translationOnly;

  const WishGreetingTextWithTranslation({
    super.key,
    required this.greeting,
    required this.isRtl,
    required this.greetingStyle,
    required this.translationStyle,
    this.loadingIndicatorSize = 12,
    this.translationOnly = false,
  });

  @override
  State<WishGreetingTextWithTranslation> createState() =>
      _WishGreetingTextWithTranslationState();
}

class _WishGreetingTextWithTranslationState
    extends State<WishGreetingTextWithTranslation> {
  String? _translation;
  bool _loading = false;
  int _requestGen = 0;

  @override
  void initState() {
    super.initState();
    LocaleHelper.localeNotifier.addListener(_onExternalChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureTranslation());
  }

  @override
  void dispose() {
    LocaleHelper.localeNotifier.removeListener(_onExternalChange);
    super.dispose();
  }

  void _onExternalChange() {
    _requestGen++;
    _translation = null;
    _loading = false;
    _ensureTranslation();
  }

  @override
  void didUpdateWidget(covariant WishGreetingTextWithTranslation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.greeting != widget.greeting) {
      _requestGen++;
      _translation = null;
      _loading = false;
      _ensureTranslation();
    }
  }

  Future<void> _ensureTranslation() async {
    final greeting = widget.greeting.trim();
    if (greeting.isEmpty) {
      if (mounted) {
        setState(() {
          _translation = null;
          _loading = false;
        });
      }
      return;
    }

    final gen = ++_requestGen;
    final locale = LocaleHelper.localeNotifier.value.languageCode;
    final target = LocaleHelper.mapToSupportedOrEnglish(locale);

    final cached = GreetingTranslator.peekTranslation(greeting, target);
    if (cached != null) {
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _translation = cached;
        _loading = false;
      });
      return;
    }

    if (!mounted || gen != _requestGen) return;
    setState(() {
      _loading = true;
      _translation = null;
    });

    try {
      final enabled = await TranslationSettingsService.isTranslationEnabled();
      if (!mounted || gen != _requestGen) return;
      if (!enabled) {
        setState(() {
          _translation = null;
          _loading = false;
        });
        return;
      }

      final translated = await GreetingTranslator.translateGreetingIfNeeded(
        greeting,
        context,
      );
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _translation = translated;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _translation = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.greeting.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final translation = _translation?.trim();
    final hasTranslation = translation != null &&
        translation.isNotEmpty &&
        translation != widget.greeting.trim();

    if (widget.translationOnly) {
      if (_loading) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
            height: widget.loadingIndicatorSize,
            width: widget.loadingIndicatorSize,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: widget.translationStyle.color?.withValues(alpha: 0.7) ??
                  const Color(0xFFB0B0B0),
            ),
          ),
        );
      }
      if (!hasTranslation) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          textDirection:
              widget.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate,
              size: widget.translationStyle.fontSize != null
                  ? widget.translationStyle.fontSize! + 2
                  : 14,
              color: widget.translationStyle.color ??
                  const Color(0xFFB0B0B0),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                translation,
                style: widget.translationStyle,
                textAlign: widget.isRtl ? TextAlign.right : TextAlign.left,
                textDirection: widget.isRtl
                    ? ui.TextDirection.rtl
                    : ui.TextDirection.ltr,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          widget.isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.greeting,
          style: widget.greetingStyle,
          textAlign: widget.isRtl ? TextAlign.right : TextAlign.left,
          textDirection:
              widget.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              height: widget.loadingIndicatorSize,
              width: widget.loadingIndicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: widget.translationStyle.color?.withValues(alpha: 0.7) ??
                    const Color(0xFFB0B0B0),
              ),
            ),
          )
        else if (hasTranslation)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              textDirection:
                  widget.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate,
                  size: widget.translationStyle.fontSize != null
                      ? widget.translationStyle.fontSize! + 2
                      : 14,
                  color: widget.translationStyle.color ??
                      const Color(0xFFB0B0B0),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    translation,
                    style: widget.translationStyle,
                    textAlign:
                        widget.isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: widget.isRtl
                        ? ui.TextDirection.rtl
                        : ui.TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
      ],
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
