import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'dj_sqlite.dart';
import 'tool_gate_strings.dart';
import 'tool_packs.dart';

class ToolLanguage {
  const ToolLanguage(this.code, this.name, this.flag);

  final String code;
  final String name;
  final String flag;
}

const toolLanguages = <ToolLanguage>[
  ToolLanguage('sq', 'Albanian', '🇦🇱'),
  ToolLanguage('ar', 'Arabic', '🇸🇦'),
  ToolLanguage('zh', 'Chinese', '🇨🇳'),
  ToolLanguage('cs', 'Czech', '🇨🇿'),
  ToolLanguage('nl', 'Dutch', '🇳🇱'),
  ToolLanguage('en', 'English', '🇬🇧'),
  ToolLanguage('fr', 'French', '🇫🇷'),
  ToolLanguage('de', 'German', '🇩🇪'),
  ToolLanguage('el', 'Greek', '🇬🇷'),
  ToolLanguage('hi', 'Hindi', '🇮🇳'),
  ToolLanguage('it', 'Italian', '🇮🇹'),
  ToolLanguage('ja', 'Japanese', '🇯🇵'),
  ToolLanguage('pl', 'Polish', '🇵🇱'),
  ToolLanguage('pt', 'Portuguese', '🇵🇹'),
  ToolLanguage('ru', 'Russian', '🇷🇺'),
  ToolLanguage('es', 'Spanish', '🇪🇸'),
  ToolLanguage('th', 'Thai', '🇹🇭'),
  ToolLanguage('tr', 'Turkish', '🇹🇷'),
  ToolLanguage('uk', 'Ukrainian', '🇺🇦'),
  ToolLanguage('vi', 'Vietnamese', '🇻🇳'),
];

bool toolIsRtl(String code) => code == 'ar';

final toolI18n = ToolI18n();

/// Gerätesprache, wenn wir sie haben — sonst Englisch.
String toolLanguageForDevice(String localeName) {
  final raw = localeName.trim().toLowerCase();
  if (raw.startsWith('zh')) return 'zh';
  final code = raw.split(RegExp(r'[_-]')).first;
  if (code.isNotEmpty && toolPacks.containsKey(code)) return code;
  return 'en';
}

class ToolI18n extends ChangeNotifier {
  String code = 'en';

  Future<void> load() async {
    final saved = _readSaved();
    code = saved ?? _systemCode();
  }

  Future<void> setCode(String next) async {
    if (next == code) return;
    if (!toolPacks.containsKey(next)) return;
    code = next;
    await _writeSaved(next);
    notifyListeners();
  }

  String text(String key, [Map<String, String> vars = const {}]) {
    final pack = toolPacks[code] ?? toolPacks['en']!;
    var value = toolGateText(code, key) ?? pack[key] ?? toolPacks['en']![key] ?? key;
    for (final entry in vars.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  String? _readSaved() {
    try {
      final file = _file();
      if (!file.existsSync()) return null;
      final data = jsonDecode(file.readAsStringSync());
      if (data is! Map) return null;
      final code = data['code']?.toString();
      if (code == null || !toolPacks.containsKey(code)) return null;
      return code;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSaved(String code) async {
    final file = _file();
    await file.writeAsString(jsonEncode({'code': code}));
  }

  File _file() {
    final dir = toolSupportDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/locale.json');
  }

  String _systemCode() => toolLanguageForDevice(Platform.localeName);
}
