import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

import '../models/user_model.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';
import 'app_localizations_es.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_it.dart';
import 'app_localizations_uk.dart';
import '../utils/debug_log.dart';

/// Zentrale Locale-Logik: Gerät → unterstützte Sprache oder Englisch; eingeloggte Nutzer:
/// Firestore `users/{uid}` Felder `language`, `selected_language` oder `locale` haben Vorrang.
class LocaleHelper {
  static const String _permanentLocaleKey = 'permanent_user_locale';
  static const String _legacyLocaleKey = 'language_code';

  /// Alle in der App verfügbaren Sprachen (Reihenfolge wie UI / delegate).
  static const List<String> supportedLanguageCodes = [
    'de',
    'en',
    'fr',
    'ru',
    'zh',
    'es',
    'tr',
    // 'ar', // deaktiviert: nicht wählbar, kein Auto-Wechsel (s. mapToSupportedOrEnglish)
    'pt',
    'it',
    'uk',
  ];

  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));

  /// Mappt einen beliebigen Sprach-String (z. B. `de_AT`, `en-US`, `it`) auf einen
  /// unterstützten Code; **nicht unterstützt → `en`** (nicht Deutsch).
  static String mapToSupportedOrEnglish(String raw) {
    final first = raw
        .toLowerCase()
        .trim()
        .split(RegExp(r'[-_]'))
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (first.isEmpty) return 'en';
    // Arabisch bewusst nicht unterstützt (Auswahl ausgeblendet) → Englisch
    if (first == 'ar' || first.startsWith('ar')) return 'en';
    if (supportedLanguageCodes.contains(first)) return first;
    if (first.startsWith('zh')) return 'zh';
    if (first.startsWith('es')) return 'es';
    if (first.startsWith('tr')) return 'tr';
    if (first.startsWith('pt')) return 'pt';
    if (first.startsWith('it')) return 'it';
    if (first == 'ua' || first.startsWith('uk')) return 'uk';
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
        }
      } catch (e) {
        debugLog('🌍 initializeAppLocale Profil-Lesen: $e');
        code = _deviceLocaleToSupportedOrEnglish();
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
            <String, dynamic>{
              'language': code,
              'selected_language': code,
            },
            SetOptions(merge: true),
          );
      debugLog('🌍 Firestore Sprache gespeichert ($code)');
    } catch (e) {
      debugLog('🌍 Firestore Sprache speichern fehlgeschlagen: $e');
    }
  }

  static Map<String, String> getTranslations(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return AppLocalizationsEN.translations;
      case 'fr':
        return AppLocalizationsFR.translations;
      case 'ru':
        return AppLocalizationsRU.translations;
      case 'zh':
        return AppLocalizationsZH.translations;
      case 'es':
        return AppLocalizationsES.translations;
      case 'tr':
        return AppLocalizationsTR.translations;
      case 'ar':
        return AppLocalizationsAR.translations;
      case 'pt':
        return AppLocalizationsPT.translations;
      case 'it':
        return AppLocalizationsIT.translations;
      case 'uk':
        return AppLocalizationsUK.translations;
      case 'de':
      default:
        return AppLocalizationsDE.translations;
    }
  }
}
