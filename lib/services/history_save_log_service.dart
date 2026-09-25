import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'app_diagnostic_log_service.dart';
import '../l10n/locale_helper.dart';
import '../l10n/generated/locale_translations.g.dart';

/// Ring-Puffer für History-Speicher-Logs — nur Admin-DJ ([AppDiagnosticLogService.canAccessDiagnosticUi]).
class HistorySaveLogService {
  HistorySaveLogService._();

  static const int _maxLines = 250;
  static final List<String> _lines = <String>[];
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get canAccess => AppDiagnosticLogService.canAccessDiagnosticUi();

  static void log(String step, String detail) {
    if (!canAccess) return;
    final ts = DateTime.now().toIso8601String();
    final line = '$ts | $step | $detail';
    _lines.add(line);
    while (_lines.length > _maxLines) {
      _lines.removeAt(0);
    }
    diagLog('HISTORY', '$step: $detail');
    revision.value++;
  }

  static List<String> get lines => List<String>.unmodifiable(_lines);

  static String _t(String key) {
    final code = LocaleHelper.localeNotifier.value.languageCode;
    final map = translationsForLanguageCode(code);
    return map[key] ??
        translationsForLanguageCode('en')[key] ??
        translationsForLanguageCode('de')[key] ??
        key;
  }

  static String exportText() {
    if (_lines.isEmpty) {
      return _t('history_save_log_empty_session');
    }
    return _lines.join('\n');
  }

  static Future<void> copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: exportText()));
  }

  static Future<void> share() async {
    await Share.share(
      exportText(),
      subject: _t('history_save_log_share_subject'),
    );
  }

  static void clear() {
    _lines.clear();
    revision.value++;
  }
}
