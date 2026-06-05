import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/locale_helper.dart';
import '../services/translation_settings_service.dart';
import '../utils/debug_log.dart';

class GreetingTranslator {
  static const String _functionsRegion = 'us-central1';

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _functionsRegion);

  // Cache für Übersetzungen (um API-Aufrufe zu reduzieren)
  static final Map<String, String> _translationCache = {};

  /// Erkennt die Sprache eines Textes (einfache Heuristik)
  /// Gibt den Language-Code zurück (de, en, fr, ru, zh, es, tr, …)
  static String _detectLanguage(String text) {
    if (text.isEmpty) return 'de';

    final lowerText = text.toLowerCase().trim();

    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      return 'zh';
    }

    if (RegExp(r'[а-яё]', caseSensitive: false).hasMatch(text)) {
      return 'ru';
    }

    if (RegExp(r'[ğĞıİşŞüÜöÖçÇ]').hasMatch(text)) {
      return 'tr';
    }

    final frenchWords = [
      'bonjour',
      'salut',
      'merci',
      'au revoir',
      'bonsoir',
      'ça va',
      'comment',
      'vous',
      'êtes',
      'français',
    ];
    if (frenchWords.any((word) => lowerText.contains(word))) {
      return 'fr';
    }

    final spanishWords = [
      'hola',
      'gracias',
      'adiós',
      'por favor',
      'buenos días',
      'buenas noches',
      'español',
      'cómo',
      'estás',
    ];
    if (spanishWords.any((word) => lowerText.contains(word))) {
      return 'es';
    }

    final englishWords = [
      'hello',
      'hi',
      'hey',
      'thank you',
      'thanks',
      'thank',
      'goodbye',
      'bye',
      'good morning',
      'good evening',
      'good night',
      'how are you',
      'english',
      'please',
      'wish',
      'wishes',
      'song',
      'songs',
      'play',
      'playing',
      'love',
      'happy',
      'birthday',
      'congratulations',
      'congrats',
      'cheers',
      'best',
      'great',
      'awesome',
      'amazing',
      'fantastic',
      'wonderful',
      'enjoy',
    ];
    if (englishWords.any((word) => lowerText.contains(word))) {
      return 'en';
    }

    if (!RegExp(r'[äöüÄÖÜß]').hasMatch(text) &&
        RegExp(r'^[a-zA-Z\s\.,!?\-]+$').hasMatch(text) &&
        text.isNotEmpty) {
      if (RegExp(
        r'\b(the|and|or|but|in|on|at|to|for|of|with|from)\b',
        caseSensitive: false,
      ).hasMatch(lowerText)) {
        return 'en';
      }
    }

    if (RegExp(r'[äöüÄÖÜß]').hasMatch(text)) {
      return 'de';
    }

    final germanWords = [
      'hallo',
      'guten tag',
      'danke',
      'tschüss',
      'auf wiedersehen',
      'wie geht',
      'deutsch',
    ];
    if (germanWords.any((word) => lowerText.contains(word))) {
      return 'de';
    }

    return 'de';
  }

  static String _normalizeLang(String code) =>
      LocaleHelper.mapToSupportedOrEnglish(code);

  /// Übersetzt einen Gruß in die Zielsprache, wenn nötig (Gemini via Cloud Function).
  /// Ziel-Locale aus [LocaleHelper] / [LanguageRegistry] (Quelle: l10n/languages.json).
  /// Server-Seite: functions/generated/greeting_languages.js (sync-language-registry.js).
  /// Gibt die übersetzte Version zurück, oder null wenn keine Übersetzung nötig ist.
  static Future<String?> translateGreetingIfNeeded(
    String greeting,
    BuildContext context,
  ) async {
    if (greeting.isEmpty) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final isEnabled = await TranslationSettingsService.isTranslationEnabled(
          userId: user.uid,
        );
        if (!isEnabled) {
          debugLog(
            '🚫 Übersetzungen sind für diesen DJ deaktiviert. Überspringe Übersetzungslogik.',
          );
          return null;
        }
      } else {
        final isEnabled =
            await TranslationSettingsService.isTranslationEnabled();
        if (!isEnabled) {
          debugLog(
            '🚫 Übersetzungen sind deaktiviert. Überspringe Übersetzungslogik.',
          );
          return null;
        }
      }
    } catch (e) {
      debugLog('⚠️ Fehler beim Prüfen der Übersetzungs-Einstellung: $e');
    }

    try {
      final targetLanguage = _normalizeLang(
        LocaleHelper.localeNotifier.value.languageCode,
      );

      debugLog('🌍 Übersetzung: Original-Gruß: "$greeting"');
      debugLog('🌍 Übersetzung: Ziel-Sprache (DJ): $targetLanguage');

      final detectedLanguage = _normalizeLang(_detectLanguage(greeting));
      debugLog('🌍 Übersetzung: Erkannte Sprache: $detectedLanguage');

      if (detectedLanguage == targetLanguage) {
        debugLog('🌍 Übersetzung: Keine Übersetzung nötig (Sprachen stimmen überein)');
        return null;
      }

      final cacheKey = '$greeting|$targetLanguage';
      if (_translationCache.containsKey(cacheKey)) {
        debugLog('🌍 Übersetzung: Aus Cache geladen');
        return _translationCache[cacheKey]!;
      }

      if (FirebaseAuth.instance.currentUser == null) {
        debugLog('🚫 Kein eingeloggter Nutzer — Gemini-Übersetzung übersprungen.');
        return null;
      }

      try {
        debugLog(
          '🌍 Übersetzung: Gemini ($detectedLanguage → $targetLanguage)',
        );
        final callable = _functions.httpsCallable('translateGreeting');
        final result = await callable.call<Map<String, dynamic>>({
          'text': greeting,
          'targetLanguage': targetLanguage,
          'sourceLanguage': detectedLanguage,
        });
        final data = result.data;
        if (data['skipped'] == true) {
          debugLog('🌍 Übersetzung: Server — übersprungen');
          return null;
        }
        final translatedText = (data['translatedText'] as String?)?.trim();
        if (translatedText == null || translatedText.isEmpty) {
          debugLog('🌍 Übersetzung: Leere Antwort vom Server');
          return null;
        }
        debugLog('🌍 Übersetzung: Erfolgreich: "$translatedText"');
        _translationCache[cacheKey] = translatedText;
        return translatedText;
      } on FirebaseFunctionsException catch (e) {
        debugLog(
          '❌ translateGreeting Callable: ${e.code} — ${e.message}',
        );
        return null;
      } catch (e, stackTrace) {
        debugLog('❌ Fehler bei der Übersetzung: $e');
        debugLog('❌ Stack trace: $stackTrace');
        return null;
      }
    } catch (e) {
      debugLog('❌ Fehler in translateGreetingIfNeeded: $e');
      return null;
    }
  }

  /// Synchroner Platzhalter — echte Übersetzung läuft nur async über Gemini.
  static String translateGreetingSimple(String greeting, BuildContext context) {
    if (greeting.isEmpty) return greeting;

    final targetLanguage = _normalizeLang(
      LocaleHelper.localeNotifier.value.languageCode,
    );
    final detectedLanguage = _normalizeLang(_detectLanguage(greeting));

    if (detectedLanguage == targetLanguage) {
      return greeting;
    }
    return greeting;
  }
}
