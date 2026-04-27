import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug_log.dart';

/// Eintrag einer Sprache aus settings/languages.
class LanguageEntry {
  final String code;
  final bool active;
  /// Relativer Pfad zur PWA-Sprachdatei (z. B. lang/de.js), für dynamisches Laden.
  final String? jsUrl;

  LanguageEntry({required this.code, required this.active, this.jsUrl});

  factory LanguageEntry.fromMap(Map<String, dynamic> map) {
    return LanguageEntry(
      code: (map['code'] as String?) ?? '',
      active: _readActive(map),
      jsUrl: map['js_url'] as String? ?? map['jsUrl'] as String?,
    );
  }

  /// Für Firestore-Struktur als Map: Key = Sprachcode, Value = { active?, js_url? } (ohne code-Feld).
  factory LanguageEntry.fromMapWithCode(String code, Map<String, dynamic> map) {
    return LanguageEntry(
      code: code.isNotEmpty ? code : (map['code'] as String?) ?? '',
      active: _readActive(map),
      jsUrl: map['js_url'] as String? ?? map['jsUrl'] as String?,
    );
  }

  /// active/isActive aus Map; wenn beide fehlen, als aktiv behandeln (Abwärtskompatibilität).
  static bool _readActive(Map<String, dynamic> map) {
    if (map['active'] == true || map['isActive'] == true) return true;
    if (map.containsKey('active') || map.containsKey('isActive')) return false;
    return true;
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'active': active,
        if (jsUrl != null && jsUrl!.isNotEmpty) 'js_url': jsUrl,
      };
}

/// Lädt die Sprachen aus settings/languages und stellt sicher, dass das Dokument existiert.
class AnnouncementLanguagesService {
  static const String _docPath = 'settings/languages';

  /// Genutzte Sprachen (PWA /vb/lang + Flutter l10n).
  /// js_url: relativer Pfad zur PWA-Sprachdatei (z. B. lang/de.js) für dynamisches Laden.
  static const List<Map<String, dynamic>> defaultLanguages = [
    {'code': 'de', 'active': true, 'js_url': 'lang/de.js'},
    {'code': 'en', 'active': true, 'js_url': 'lang/en.js'},
    {'code': 'fr', 'active': true, 'js_url': 'lang/fr.js'},
    {'code': 'ru', 'active': true, 'js_url': 'lang/ru.js'},
    {'code': 'zh', 'active': true, 'js_url': 'lang/zh.js'},
    {'code': 'es', 'active': true, 'js_url': 'lang/es.js'},
    {'code': 'tr', 'active': true, 'js_url': 'lang/tr.js'},
    {'code': 'pt', 'active': true, 'js_url': 'lang/pt.js'},
    {'code': 'it', 'active': true, 'js_url': 'lang/it.js'},
    {'code': 'uk', 'active': true, 'js_url': 'lang/uk.js'},
  ];

  /// Lädt die Sprachenliste. Wenn das Dokument fehlt, wird es mit [defaultLanguages] angelegt.
  static Future<List<LanguageEntry>> getLanguages({bool ensureExists = true}) async {
    final ref = FirebaseFirestore.instance.doc(_docPath);
    final snap = await ref.get();

    if (!snap.exists && ensureExists) {
      await ref.set({
        'languages': defaultLanguages,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return defaultLanguages.map((e) => LanguageEntry.fromMap(e)).toList();
    }

    if (!snap.exists) return [];

    final data = snap.data();
    final raw = data?['languages'];
    debugLog('DEBUG [Languages]: Rohdaten aus Firestore: $raw');
    debugLog('DEBUG [Languages]: Typ von raw: ${raw.runtimeType}');

    // Firestore: languages kann List (z. B. [{code: "de", active: true}, ...]) oder Map (z. B. {de: {active: true}, en: {...}}) sein
    if (raw is Map<String, dynamic> || raw is Map) {
      final map = raw is Map<String, dynamic> ? raw! : Map<String, dynamic>.from(raw as Map);
      final entries = map.entries
          .map((e) {
            final key = e.key.toString();
            final val = e.value;
            if (val is Map<String, dynamic>) return LanguageEntry.fromMapWithCode(key, val);
            if (val is Map) return LanguageEntry.fromMapWithCode(key, Map<String, dynamic>.from(val));
            return null;
          })
          .whereType<LanguageEntry>()
          .where((e) => e.code.isNotEmpty)
          .toList();
      debugLog('DEBUG [Languages]: Aus Map gelesen: ${entries.length} Einträge, active: ${entries.where((e) => e.active).length}');
      if (entries.isNotEmpty) return entries;
      if (ensureExists) {
        await ref.set({'languages': defaultLanguages, 'updatedAt': FieldValue.serverTimestamp()});
        return defaultLanguages.map((e) => LanguageEntry.fromMap(e)).toList();
      }
      return [];
    }

    if (raw is! List<dynamic>) {
      debugLog('DEBUG [Languages]: languages ist weder Map noch List – Typ: ${raw.runtimeType}');
      if (ensureExists) {
        await ref.set({'languages': defaultLanguages, 'updatedAt': FieldValue.serverTimestamp()});
        return defaultLanguages.map((e) => LanguageEntry.fromMap(e)).toList();
      }
      return [];
    }

    final list = raw as List<dynamic>;
    final fromList = list
        .map((e) {
          if (e is Map<String, dynamic>) return LanguageEntry.fromMap(e);
          if (e is Map) return LanguageEntry.fromMap(Map<String, dynamic>.from(e));
          return null;
        })
        .whereType<LanguageEntry>()
        .where((e) => e.code.isNotEmpty)
        .toList();
    debugLog('DEBUG [Languages]: Aus List gelesen: ${fromList.length} Einträge, active: ${fromList.where((e) => e.active).length}');
    if (fromList.isEmpty && ensureExists) {
      await ref.set({'languages': defaultLanguages, 'updatedAt': FieldValue.serverTimestamp()});
      return defaultLanguages.map((e) => LanguageEntry.fromMap(e)).toList();
    }
    return fromList;
  }

  /// Nur Sprachen mit active == true.
  static Future<List<LanguageEntry>> getActiveLanguages({bool ensureExists = true}) async {
    final all = await getLanguages(ensureExists: ensureExists);
    return all.where((e) => e.active).toList();
  }
}
