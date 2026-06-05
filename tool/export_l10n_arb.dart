// Exportiert lib/l10n/app_localizations_*.dart → l10n/app_<locale>.arb (JSON) für BabelEdit.
//
// Ausführen im Projektroot:
//   dart run tool/export_l10n_arb.dart

import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory.current;
  final outDir = Directory.fromUri(root.uri.resolve('l10n/'));
  final l10nLib = Directory.fromUri(root.uri.resolve('lib/l10n/'));
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final byLocale = <String, Map<String, String>>{};
  for (final f in l10nLib.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    final m = RegExp(r'^app_localizations_([a-z]{2,3})\.dart$').firstMatch(name);
    if (m == null) continue;
    final code = m.group(1)!;
    final content = f.readAsStringSync();
    final map = _parseTranslationsMap(content);
    if (map.isEmpty) {
      stderr.writeln('Warnung: keine translations in $name');
      continue;
    }
    byLocale[code] = map;
  }

  if (byLocale.isEmpty) {
    stderr.writeln('Keine lib/l10n/app_localizations_<locale>.dart gefunden.');
    exitCode = 1;
    return;
  }

  for (final e in byLocale.entries) {
    final locale = e.key;
    final map = e.value;
    final arb = <String, dynamic>{'@@locale': locale};
    for (final kv in map.entries) {
      if (kv.key.startsWith('@')) continue;
      arb[kv.key] = kv.value;
    }
    final path = outDir.uri.resolve('app_$locale.arb').toFilePath();
    File(path).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(arb)}\n',
    );
    stdout.writeln('Wrote $path (${map.length} keys)');
  }
}

/// Liest `static const Map<String, String> translations = { ... };` ohne Dart-Analyzer.
Map<String, String> _parseTranslationsMap(String source) {
  final start = source.indexOf('translations = {');
  if (start < 0) return {};
  var i = source.indexOf('{', start) + 1;
  final out = <String, String>{};
  while (i < source.length) {
    while (i < source.length && ' \n\r\t,}'.contains(source[i])) {
      if (source[i] == '}') return out;
      i++;
    }
    if (i >= source.length || source[i] != "'") break;
    i++;
    final keyBuf = StringBuffer();
    while (i < source.length) {
      final c = source[i];
      if (c == r'\') {
        i++;
        if (i < source.length) keyBuf.write(source[i]);
        i++;
        continue;
      }
      if (c == "'") {
        i++;
        break;
      }
      keyBuf.write(c);
      i++;
    }
    while (i < source.length && ' \n\r\t'.contains(source[i])) {
      i++;
    }
    if (i >= source.length || source[i] != ':') break;
    i++;
    while (i < source.length && ' \n\r\t'.contains(source[i])) {
      i++;
    }
    if (i >= source.length || source[i] != "'") break;
    i++;
    final valBuf = StringBuffer();
    while (i < source.length) {
      final c = source[i];
      if (c == r'\') {
        i++;
        if (i < source.length) {
          final esc = source[i];
          switch (esc) {
            case 'n':
              valBuf.write('\n');
            case 'r':
              valBuf.write('\r');
            case 't':
              valBuf.write('\t');
            case "'":
              valBuf.write("'");
            case r'\':
              valBuf.write(r'\');
            default:
              valBuf.write(esc);
          }
        }
        i++;
        continue;
      }
      if (c == "'") {
        i++;
        break;
      }
      valBuf.write(c);
      i++;
    }
    out[keyBuf.toString()] = valBuf.toString();
  }
  return out;
}
