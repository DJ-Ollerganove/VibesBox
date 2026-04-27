import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug_log.dart';

/// Eintrag einer Sprache aus settings/languages.
/// [name] ist der **englische** Anzeigename (wie in Firestore `name`).
class LanguageEntry {
  final String code;
  final bool active;
  /// Relativer Pfad zur PWA-Sprachdatei (z. B. lang/de.js), aus js_url oder js_path abgeleitet.
  final String? jsUrl;
  final String? name;
  final String? dartFile;

  LanguageEntry({
    required this.code,
    required this.active,
    this.jsUrl,
    this.name,
    this.dartFile,
  });

  /// Kurzlabel für UI (englischer Name oder Code).
  String get displayLabel =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : code;

  factory LanguageEntry.fromMap(Map<String, dynamic> map) {
    return LanguageEntry(
      code: (map['code'] as String?) ?? '',
      active: _readActive(map),
      jsUrl: _readJsUrl(map),
      name: map['name'] as String?,
      dartFile: map['dart_file'] as String?,
    );
  }

  /// Für Firestore-Struktur als Map: Key = Sprachcode, Value = Felder (ohne code).
  factory LanguageEntry.fromMapWithCode(String code, Map<String, dynamic> map) {
    return LanguageEntry(
      code: code.isNotEmpty ? code : (map['code'] as String?) ?? '',
      active: _readActive(map),
      jsUrl: _readJsUrl(map),
      name: map['name'] as String?,
      dartFile: map['dart_file'] as String?,
    );
  }

  /// active/isActive aus Map; wenn beide fehlen, als aktiv behandeln (Abwärtskompatibilität).
  static bool _readActive(Map<String, dynamic> map) {
    if (map['active'] == true || map['isActive'] == true) return true;
    if (map.containsKey('active') || map.containsKey('isActive')) return false;
    return true;
  }

  static String? _readJsUrl(Map<String, dynamic> map) {
    final u = map['js_url'] as String? ?? map['jsUrl'] as String?;
    if (u != null && u.isNotEmpty) return u;
    final p = map['js_path'] as String?;
    if (p == null || p.isEmpty) return null;
    final idx = p.indexOf('lang/');
    if (idx >= 0) return p.substring(idx);
    return p.startsWith('/') ? p.substring(1) : p;
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'active': active,
        if (jsUrl != null && jsUrl!.isNotEmpty) 'js_url': jsUrl,
        if (name != null && name!.isNotEmpty) 'name': name,
        if (dartFile != null && dartFile!.isNotEmpty) 'dart_file': dartFile,
      };
}

/// Lädt die Sprachen aus settings/languages und stellt sicher, dass das Dokument existiert.
class AnnouncementLanguagesService {
  static const String _docPath = 'settings/languages';

  /// Erlaubte Sprachcodes (Kürzel): z. B. de, uk, zh.
  static final RegExp languageCodePattern = RegExp(r'^[a-z]{2,8}$');

  /// Standard-Felder wie in [init_languages_final.js]: englischer Name, js_path, dart_file, active.
  /// [noJsFile]: `true` für Sprachen ohne PWA-js (z. B. Arabisch) → `js_path` ist `null`.
  static Map<String, dynamic> languageFieldsTemplate({
    required String code,
    required String nameEnglish,
    bool active = true,
    bool noJsFile = false,
  }) {
    final c = code.trim().toLowerCase();
    final m = <String, dynamic>{
      'name': nameEnglish.trim(),
      'dart_file': 'app_localizations_$c.dart',
      'active': active,
      'js_path': noJsFile ? null : '/vb/lang/$c.js',
    };
    return m;
  }

  /// Initiales Firestore-Mapping (Schlüssel = Sprachcode). Alle [name]-Werte auf Englisch.
  static Map<String, Map<String, dynamic>> get defaultLanguagesMap => {
        'de': languageFieldsTemplate(
          code: 'de',
          nameEnglish: 'German',
        ),
        'en': languageFieldsTemplate(
          code: 'en',
          nameEnglish: 'English',
        ),
        'fr': languageFieldsTemplate(
          code: 'fr',
          nameEnglish: 'French',
        ),
        'ru': languageFieldsTemplate(
          code: 'ru',
          nameEnglish: 'Russian',
        ),
        'es': languageFieldsTemplate(
          code: 'es',
          nameEnglish: 'Spanish',
        ),
        'pt': languageFieldsTemplate(
          code: 'pt',
          nameEnglish: 'Portuguese',
        ),
        'tr': languageFieldsTemplate(
          code: 'tr',
          nameEnglish: 'Turkish',
        ),
        'zh': languageFieldsTemplate(
          code: 'zh',
          nameEnglish: 'Chinese',
        ),
        'it': languageFieldsTemplate(
          code: 'it',
          nameEnglish: 'Italian',
        ),
        'uk': languageFieldsTemplate(
          code: 'uk',
          nameEnglish: 'Ukrainian',
        ),
        'hi': languageFieldsTemplate(
          code: 'hi',
          nameEnglish: 'Hindi',
        ),
        'ar': languageFieldsTemplate(
          code: 'ar',
          nameEnglish: 'Arabic',
          noJsFile: true,
        ),
      };

  static List<LanguageEntry> _fromFirestoreMap(Map<String, dynamic> map) {
    final out = <LanguageEntry>[];
    map.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        out.add(LanguageEntry.fromMapWithCode(key, val));
      } else if (val is Map) {
        out.add(
          LanguageEntry.fromMapWithCode(key, Map<String, dynamic>.from(val)),
        );
      }
    });
    out.sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  static List<LanguageEntry> _fromFirestoreList(List<dynamic> list) {
    final out = list
        .map((e) {
          if (e is Map<String, dynamic>) return LanguageEntry.fromMap(e);
          if (e is Map) return LanguageEntry.fromMap(Map<String, dynamic>.from(e));
          return null;
        })
        .whereType<LanguageEntry>()
        .where((e) => e.code.isNotEmpty)
        .toList();
    out.sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  /// Lädt die Sprachenliste. Wenn das Dokument fehlt, wird es mit [defaultLanguagesMap] angelegt.
  static Future<List<LanguageEntry>> getLanguages({bool ensureExists = true}) async {
    final ref = FirebaseFirestore.instance.doc(_docPath);
    final snap = await ref.get();

    if (!snap.exists && ensureExists) {
      await ref.set({
        'languages': defaultLanguagesMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return _fromFirestoreMap(
        defaultLanguagesMap.map((k, v) => MapEntry(k, v)),
      );
    }

    if (!snap.exists) return [];

    final data = snap.data();
    final raw = data?['languages'];
    debugLog('DEBUG [Languages]: Rohdaten aus Firestore: $raw');
    debugLog('DEBUG [Languages]: Typ von raw: ${raw.runtimeType}');

    if (raw is Map<String, dynamic> || raw is Map) {
      final map = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
      final entries = _fromFirestoreMap(map);
      debugLog(
        'DEBUG [Languages]: Aus Map gelesen: ${entries.length} Einträge, active: ${entries.where((e) => e.active).length}',
      );
      if (entries.isNotEmpty) return entries;
      if (ensureExists) {
        await ref.set({
          'languages': defaultLanguagesMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return _fromFirestoreMap(
          defaultLanguagesMap.map((k, v) => MapEntry(k, v)),
        );
      }
      return [];
    }

    if (raw is! List<dynamic>) {
      debugLog('DEBUG [Languages]: languages ist weder Map noch List – Typ: ${raw.runtimeType}');
      if (ensureExists) {
        await ref.set({
          'languages': defaultLanguagesMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return _fromFirestoreMap(
          defaultLanguagesMap.map((k, v) => MapEntry(k, v)),
        );
      }
      return [];
    }

    final fromList = _fromFirestoreList(raw);
    debugLog(
      'DEBUG [Languages]: Aus List gelesen: ${fromList.length} Einträge, active: ${fromList.where((e) => e.active).length}',
    );
    if (fromList.isEmpty && ensureExists) {
      await ref.set({
        'languages': defaultLanguagesMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return _fromFirestoreMap(
        defaultLanguagesMap.map((k, v) => MapEntry(k, v)),
      );
    }
    return fromList;
  }

  /// Nur Sprachen mit active == true.
  static Future<List<LanguageEntry>> getActiveLanguages({bool ensureExists = true}) async {
    final all = await getLanguages(ensureExists: ensureExists);
    return all.where((e) => e.active).toList();
  }

  /// Neue Sprache in [settings/languages] speichern. Nur [nameEnglish] und [code] nötig;
  /// js_path und dart_file werden wie bei den bestehenden Einträgen gesetzt.
  ///
  /// Erwartet Map-Struktur `{ de: {...}, ... }` oder Liste `[{code, ...}, ...]`.
  static Future<void> addLanguage({
    required String codeRaw,
    required String nameEnglish,
  }) async {
    final code = codeRaw.trim().toLowerCase();
    if (!languageCodePattern.hasMatch(code)) {
      throw const FormatException(
        'Ungültiges Kürzel: nur Kleinbuchstaben, 2–8 Zeichen (z. B. de, uk).',
      );
    }
    final name = nameEnglish.trim();
    if (name.isEmpty) {
      throw const FormatException('Bitte den englischen Namen der Sprache angeben.');
    }

    final ref = FirebaseFirestore.instance.doc(_docPath);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final raw = data['languages'];
      final entry = languageFieldsTemplate(code: code, nameEnglish: name);

      if (raw is Map<String, dynamic> || raw is Map) {
        final map = Map<String, dynamic>.from(raw as Map);
        if (map.containsKey(code)) {
          throw StateError('Die Sprache „$code“ existiert bereits.');
        }
        map[code] = entry;
        tx.set(
          ref,
          {
            'languages': map,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      if (raw is List) {
        final list = List<dynamic>.from(raw);
        for (final e in list) {
          if (e is Map) {
            final c = (e['code'] as String?)?.toLowerCase();
            if (c == code) {
              throw StateError('Die Sprache „$code“ existiert bereits.');
            }
          }
        }
        list.add({
          'code': code,
          ...entry,
        });
        tx.set(
          ref,
          {
            'languages': list,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      tx.set(
        ref,
        {
          'languages': {code: entry},
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
