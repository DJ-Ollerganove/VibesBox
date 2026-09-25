import 'package:flutter/material.dart';

import 'generated/language_registry.g.dart';

/// Schreibrichtung — Quelle: [l10n/languages.json] → [LanguageRegistry.textDirectionByCode].
abstract final class VbTextDirection {
  static bool isRtlLanguageCode(String code) => LanguageRegistry.isRtl(code);

  static bool isRtl(BuildContext context) =>
      isRtlLanguageCode(Localizations.localeOf(context).languageCode);

  static bool isRtlLocale(Locale locale) => isRtlLanguageCode(locale.languageCode);

  static TextDirection directionFor(String code) =>
      LanguageRegistry.textDirectionFor(code);

  static TextDirection directionForContext(BuildContext context) =>
      directionFor(Localizations.localeOf(context).languageCode);
}
