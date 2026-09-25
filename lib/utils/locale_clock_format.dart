import 'package:intl/intl.dart' as intl;

import '../l10n/generated/language_registry.g.dart';

/// Uhrzeit nach [LanguageRegistry.timeStyleFor] / [time_suffix] (Quelle: languages.json).
abstract final class LocaleClockFormat {
  static String format(
    DateTime dateTime,
    String languageCode, {
    required String intlTag,
    bool withSuffix = true,
  }) {
    final code = languageCode;
    final style = LanguageRegistry.timeStyleFor(code);
    switch (style) {
      case 'intl_12':
        return _fmt(() => intl.DateFormat.jm(intlTag).format(dateTime), dateTime);
      case 'fr_h':
        return _frH(dateTime);
      case 'h_compact':
      case 'pt_h': // legacy alias
        return _hCompact(dateTime);
      case 'ja_kanji':
        return _jaKanji(dateTime);
      case 'colon_suffix':
      default:
        final clock = _fmt(
          () => intl.DateFormat.Hm(intlTag).format(dateTime),
          dateTime,
        );
        if (!withSuffix) return clock;
        return _appendSuffix(clock, LanguageRegistry.timeSuffixFor(code));
    }
  }

  static String _fmt(String Function() build, DateTime dateTime) {
    try {
      return build();
    } catch (_) {
      return intl.DateFormat.Hm('en_US').format(dateTime);
    }
  }

  static String _frH(DateTime dt) {
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.hour} h $m';
  }

  /// PT/IT: 20h30
  static String _hCompact(DateTime dt) {
    return '${dt.hour}h${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _jaKanji(DateTime dt) {
    return '${dt.hour}時${dt.minute.toString().padLeft(2, '0')}分';
  }

  static String _appendSuffix(String clock, String suffix) {
    final s = suffix.trim();
    if (s.isEmpty || clock.contains(s)) return clock;
    return '$clock\u00A0$s';
  }
}
