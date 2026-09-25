import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

import '../models/user_model.dart';
import '../services/user_self_settings_service.dart';
import '../utils/debug_log.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'generated/language_registry.g.dart';
import 'generated/locale_translations.g.dart';

/// Zentrale Locale-Logik: Gerät → unterstützte Sprache oder Englisch; eingeloggte Nutzer:
/// Firestore `users/{uid}` Felder `language`, `selected_language` oder `locale` haben Vorrang.
class LocaleHelper {
  static const String _permanentLocaleKey = 'permanent_user_locale';
  static const String _legacyLocaleKey = 'language_code';

  /// Alle in der App verfügbaren Sprachen — aus [l10n/languages.json] generiert.
  static const List<String> supportedLanguageCodes =
      LanguageRegistry.supportedLanguageCodes;

  /// Öffentliche + ggf. Admin-only Sprachen — für Delegates/DateFormat.
  static bool isLoadableLanguageCode(String code) {
    return supportedLanguageCodes.contains(code) ||
        LanguageRegistry.adminOnlyLanguageCodes.contains(code);
  }

  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));

  /// Ob Admin-only-Sprachen aufgelöst werden dürfen (Legacy-Hook, derzeit ungenutzt).
  static bool Function()? adminOnlyLanguagesResolver;

  static bool get canUseAdminOnlyLanguages =>
      adminOnlyLanguagesResolver?.call() ?? false;

  static bool get _allowAdminOnlyLanguages => canUseAdminOnlyLanguages;

  /// Mappt einen beliebigen Sprach-String (z. B. `de_AT`, `en-US`, `it`) auf einen
  /// unterstützten Code; **nicht unterstützt → `en`** (nicht Deutsch).
  static String mapToSupportedOrEnglish(
    String raw, {
    bool? allowAdminOnly,
  }) {
    final allowAdmin = allowAdminOnly ?? _allowAdminOnlyLanguages;
    final first = raw
        .toLowerCase()
        .trim()
        .split(RegExp(r'[-_]'))
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (first.isEmpty) return 'en';
    if (supportedLanguageCodes.contains(first)) return first;
    if (allowAdmin && LanguageRegistry.adminOnlyLanguageCodes.contains(first)) {
      return first;
    }
    if (first.startsWith('zh')) return 'zh';
    if (first.startsWith('es')) return 'es';
    if (first.startsWith('tr')) return 'tr';
    if (first.startsWith('pt')) return 'pt';
    if (first.startsWith('it')) return 'it';
    if (first == 'ua' || first.startsWith('uk')) return 'uk';
    if (first == 'hi' || first.startsWith('hi')) return 'hi';
    if (first == 'sq' || first.startsWith('sq') || first == 'al') return 'sq';
    if (first == 'vi' || first.startsWith('vi')) return 'vi';
    if (first == 'ja' || first.startsWith('ja') || first == 'jp') return 'ja';
    if (first == 'el' || first.startsWith('el') || first == 'gr') return 'el';
    if (first == 'nl' || first.startsWith('nl')) return 'nl';
    if (first == 'pl' || first.startsWith('pl')) return 'pl';
    if (first == 'cs' || first.startsWith('cs') || first == 'cz') return 'cs';
    if (first == 'th' || first.startsWith('th')) return 'th';
    if (first == 'ar' || first.startsWith('ar')) return 'ar';
    return 'en';
  }

  static String _deviceLocaleToSupportedOrEnglish() {
    try {
      final systemLocale = ui.PlatformDispatcher.instance.locale;
      final tag = kIsWeb
          ? systemLocale.toLanguageTag()
          : systemLocale.languageCode;
      return mapToSupportedOrEnglish(tag.replaceAll('-', '_'));
    } catch (e) {
      debugLog('🌍 Fehler Geräte-Locale: $e');
      return 'en';
    }
  }

  /// Einmal beim App-Start nach [Firebase.initializeApp]: Gerät, Prefs oder Profil.
  static Future<void> initializeAppLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    late String code;
    var backfillLanguageToFirestore = false;

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        final fromProfile = UserModel.parsePreferredLanguageFields(data);
        if (fromProfile != null && fromProfile.isNotEmpty) {
          code = mapToSupportedOrEnglish(fromProfile);
        } else {
          code = _deviceLocaleToSupportedOrEnglish();
          // Admin-UI / Support: fehlende Felder nachtragen (einmalig pro Gerät mit App-Start)
          backfillLanguageToFirestore = true;
        }
      } catch (e) {
        debugLog('🌍 initializeAppLocale Profil-Lesen: $e');
        code = _deviceLocaleToSupportedOrEnglish();
        backfillLanguageToFirestore = true;
      }
      await prefs.setString(_legacyLocaleKey, code);
      await prefs.setString(_permanentLocaleKey, code);
    } else {
      final permanent = prefs.getString(_permanentLocaleKey)?.trim();
      if (permanent != null && permanent.isNotEmpty) {
        code = mapToSupportedOrEnglish(permanent);
      } else {
        code = _deviceLocaleToSupportedOrEnglish();
        await prefs.setString(_legacyLocaleKey, code);
        await prefs.setString(_permanentLocaleKey, code);
      }
    }

    localeNotifier.value = Locale(code);
    debugLog('🌍 initializeAppLocale → $code');

    if (user != null && backfillLanguageToFirestore) {
      unawaited(_backfillLanguageToFirestore(user.uid, code));
    }
  }

  /// Schreibt `language` / `selected_language`, wenn sie im Profil fehlen (für Admin-Ansicht & Konsistenz).
  static Future<void> _backfillLanguageToFirestore(String uid, String code) async {
    try {
      await UserSelfSettingsService.instance.write(
        <String, dynamic>{
          'language': code,
          'selected_language': code,
        },
        userId: uid,
      );
      debugLog('🌍 Firestore Sprache nachgetragen ($code)');
    } catch (e) {
      debugLog('🌍 Firestore Sprache nachtragen fehlgeschlagen: $e');
    }
  }

  /// Nach Firestore-Profil-Updates: gespeicherte `language` / `locale` erzwingen.
  static Future<void> syncLocaleFromUserProfile(UserModel? model) async {
    if (model == null) return;
    final raw = model.preferredLanguage;
    if (raw == null || raw.isEmpty) return;
    final code = mapToSupportedOrEnglish(raw);
    if (localeNotifier.value.languageCode == code) return;
    await saveLocale(code, persistToFirestore: false);
    debugLog('🌍 syncLocaleFromUserProfile → $code');
  }

  @Deprecated('Nutze initializeAppLocale()')
  static Future<void> loadLocale() async {
    await initializeAppLocale();
  }

  /// Legacy-Helfer: gespeicherte Locale oder Gerät (für FirebaseAuth-E-Mails etc.).
  static Future<Locale> getSavedOrDeviceLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedPermanent = (prefs.getString(_permanentLocaleKey) ?? '').trim();
      if (savedPermanent.isNotEmpty) {
        return Locale(mapToSupportedOrEnglish(savedPermanent));
      }

      final savedLegacy = (prefs.getString(_legacyLocaleKey) ?? '').trim();
      if (savedLegacy.isNotEmpty) {
        return Locale(mapToSupportedOrEnglish(savedLegacy));
      }
    } catch (e) {
      debugLog('🌍 getSavedOrDeviceLocale Prefs: $e');
    }

    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final raw = kIsWeb
          ? locale.toLanguageTag()
          : locale.languageCode;
      return Locale(mapToSupportedOrEnglish(raw.replaceAll('-', '_')));
    } catch (e) {
      debugLog('🌍 getSavedOrDeviceLocale Fallback: $e');
      return const Locale('en');
    }
  }

  /// Speichert lokal und optional in Firestore (bei manueller Sprachwahl im UI: [persistToFirestore] = true).
  /// Beim Abgleich aus dem Profil [persistToFirestore=false], damit keine redundanten Writes entstehen.
  static Future<void> saveLocale(
    String languageCode, {
    bool persistToFirestore = true,
  }) async {
    final code = mapToSupportedOrEnglish(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyLocaleKey, code);
    await prefs.setString(_permanentLocaleKey, code);
    localeNotifier.value = Locale(code);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseAuth.instance.setLanguageCode(code);
    } catch (e) {
      debugLog('🌍 FirebaseAuth.setLanguageCode: $e');
    }

    if (!persistToFirestore) return;

    try {
      await UserSelfSettingsService.instance.write(
        <String, dynamic>{
          'language': code,
          'selected_language': code,
        },
      );
      debugLog('🌍 Firestore Sprache gespeichert ($code)');
    } catch (e) {
      debugLog('🌍 Firestore Sprache speichern fehlgeschlagen: $e');
    }
  }

  /// Liefert einen Eintrag aus einer [getTranslations]-Map ohne hartcodierte UI-Fallbacks.
  /// Fehlt der Key in der gewählten Sprache, wird Deutsch verwendet, dann der [key] protokolliert.
  static String tr(Map<String, String> map, String key) {
    final v = map[key];
    if (v != null && v.trim().isNotEmpty) return v;
    final deV = AppLocalizationsDE.translations[key];
    if (deV != null && deV.trim().isNotEmpty) {
      if (v != null && v.isEmpty) {
        debugLog('⚠️ LocaleHelper.tr: Key "$key" leer in Export-Sprache, nutze DE');
      } else {
        debugLog('⚠️ LocaleHelper.tr: Key "$key" fehlt in Export-Sprache, nutze DE');
      }
      return deV;
    }
    final enV = AppLocalizationsEN.translations[key];
    if (enV != null && enV.trim().isNotEmpty) {
      debugLog('⚠️ LocaleHelper.tr: Key "$key" fehlt/leer auch in DE, nutze EN');
      return enV;
    }
    debugLog('⚠️ LocaleHelper.tr: Key "$key" fehlt/leer auch in DE/EN');
    return key;
  }

  static Map<String, String> getTranslations(Locale locale) {
    return translationsForLanguageCode(locale.languageCode);
  }

  /// RTL/LTR aus [l10n/languages.json] (Feld text_direction).
  static bool isRtlLanguageCode(String code) => LanguageRegistry.isRtl(code);

  static bool isRtl(BuildContext context) =>
      isRtlLanguageCode(Localizations.localeOf(context).languageCode);

  static TextDirection textDirectionFor(String code) =>
      LanguageRegistry.textDirectionFor(code);
}
