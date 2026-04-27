import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/locale_helper.dart';
import '../services/translation_settings_service.dart';
import '../utils/debug_log.dart';

class GreetingTranslator {
  static final GoogleTranslator _translator = GoogleTranslator();
  
  // Cache für Übersetzungen (um API-Aufrufe zu reduzieren)
  static final Map<String, String> _translationCache = {};
  
  /// Mappt App-Language-Codes zu Google Translate API-Codes
  /// Unterstützt alle 8 Sprachen: de, en, fr, ru, zh, es, tr, ar
  /// WICHTIG: Google Translate benötigt 'zh-cn' (kleingeschrieben) statt 'zh'
  static String _mapToGoogleTranslateCode(String languageCode) {
    final code = languageCode.toLowerCase();
    
    // Spezielle Behandlung für Chinesisch: 'zh' -> 'zh-cn'
    if (code == 'zh') {
      return 'zh-cn'; // Vereinfachtes Chinesisch (kleingeschrieben für API-Kompatibilität)
    }
    
    // Alle anderen Sprachen bleiben unverändert
    switch (code) {
      case 'ar':
        return 'ar'; // Arabisch
      case 'ru':
        return 'ru'; // Russisch
      case 'tr':
        return 'tr'; // Türkisch
      case 'fr':
        return 'fr'; // Französisch
      case 'es':
        return 'es'; // Spanisch
      case 'en':
        return 'en'; // Englisch
      case 'de':
        return 'de'; // Deutsch
      default:
        debugLog('⚠️ Unbekannter Language-Code: $languageCode, verwende Fallback: de');
        return 'de';
    }
  }
  
  /// Erkennt die Sprache eines Textes (einfache Heuristik)
  /// Gibt den Language-Code zurück (de, en, fr, ru, zh, es, tr, ar)
  static String _detectLanguage(String text) {
    if (text.isEmpty) return 'de';
    
    // Einfache Heuristik basierend auf charakteristischen Zeichen und Wörtern
    final lowerText = text.toLowerCase().trim();
    
    // Chinesisch
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      return 'zh';
    }
    
    // Russisch (kyrillisch)
    if (RegExp(r'[а-яё]', caseSensitive: false).hasMatch(text)) {
      return 'ru';
    }
    
    // Türkisch (charakteristische Zeichen)
    if (RegExp(r'[ğĞıİşŞüÜöÖçÇ]').hasMatch(text)) {
      return 'tr';
    }
    
    // Französisch
    final frenchWords = ['bonjour', 'salut', 'merci', 'au revoir', 'bonsoir', 'ça va', 'comment', 'vous', 'êtes', 'français'];
    if (frenchWords.any((word) => lowerText.contains(word))) {
      return 'fr';
    }
    
    // Spanisch
    final spanishWords = ['hola', 'gracias', 'adiós', 'por favor', 'buenos días', 'buenas noches', 'español', 'cómo', 'estás'];
    if (spanishWords.any((word) => lowerText.contains(word))) {
      return 'es';
    }
    
    // Englisch - erweitere Liste für bessere Erkennung
    final englishWords = [
      'hello', 'hi', 'hey', 'thank you', 'thanks', 'thank', 'goodbye', 'bye', 
      'good morning', 'good evening', 'good night', 'how are you', 'english',
      'please', 'wish', 'wishes', 'song', 'songs', 'play', 'playing', 'love',
      'happy', 'birthday', 'congratulations', 'congrats', 'cheers', 'best',
      'great', 'awesome', 'amazing', 'fantastic', 'wonderful', 'enjoy'
    ];
    if (englishWords.any((word) => lowerText.contains(word))) {
      return 'en';
    }
    
    // Englisch: Prüfe auf typische englische Buchstabenkombinationen
    // Wenn der Text hauptsächlich lateinische Zeichen hat und keine deutschen Umlaute, könnte es Englisch sein
    if (!RegExp(r'[äöüÄÖÜß]').hasMatch(text) && 
        RegExp(r'^[a-zA-Z\s\.,!?\-]+$').hasMatch(text) &&
        text.length > 0) {
      // Prüfe auf typische englische Muster
      if (RegExp(r'\b(the|and|or|but|in|on|at|to|for|of|with|from)\b', caseSensitive: false).hasMatch(lowerText)) {
        return 'en';
      }
    }
    
    // Deutsch (Umlaute)
    if (RegExp(r'[äöüÄÖÜß]').hasMatch(text)) {
      return 'de';
    }
    
    // Deutsch (häufige Wörter)
    final germanWords = ['hallo', 'guten tag', 'danke', 'tschüss', 'auf wiedersehen', 'wie geht', 'deutsch'];
    if (germanWords.any((word) => lowerText.contains(word))) {
      return 'de';
    }
    
    // Standard: Deutsch als Fallback
    return 'de';
  }
  
  /// Übersetzt einen Gruß in die Zielsprache, wenn nötig
  /// Gibt die übersetzte Version zurück, oder null wenn keine Übersetzung nötig ist
  /// MASTER-GATE: Prüft zuerst, ob Übersetzungen für den DJ aktiviert sind
  static Future<String?> translateGreetingIfNeeded(String greeting, BuildContext context) async {
    if (greeting.isEmpty) return null;
    
    // MASTER-GATE: Prüfe, ob Übersetzungen für den aktuellen DJ aktiviert sind
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final isEnabled = await TranslationSettingsService.isTranslationEnabled(userId: user.uid);
        if (!isEnabled) {
          debugLog('🚫 Übersetzungen sind für diesen DJ deaktiviert. Überspringe Übersetzungslogik.');
          return null; // Sofort beenden, keine Übersetzungslogik ausführen
        }
      } else {
        // Wenn kein User eingeloggt, prüfe SharedPreferences
        final isEnabled = await TranslationSettingsService.isTranslationEnabled();
        if (!isEnabled) {
          debugLog('🚫 Übersetzungen sind deaktiviert. Überspringe Übersetzungslogik.');
          return null; // Sofort beenden, keine Übersetzungslogik ausführen
        }
      }
    } catch (e) {
      debugLog('⚠️ Fehler beim Prüfen der Übersetzungs-Einstellung: $e');
      // Bei Fehler: Übersetzungen erlauben (Default-Verhalten)
    }
    
    try {
      // Hole aktuelle DJ-Sprache
      final currentLocale = LocaleHelper.localeNotifier.value;
      final targetLanguage = currentLocale.languageCode;
      
      debugLog('🌍 Übersetzung: Original-Gruß: "$greeting"');
      debugLog('🌍 Übersetzung: Ziel-Sprache (DJ): $targetLanguage');
      
      // Erkenne Sprache des Grußes
      final detectedLanguage = _detectLanguage(greeting);
      debugLog('🌍 Übersetzung: Erkannte Sprache: $detectedLanguage');
      
      // Wenn die erkannte Sprache mit der Zielsprache übereinstimmt, keine Übersetzung nötig
      if (detectedLanguage == targetLanguage) {
        debugLog('🌍 Übersetzung: Keine Übersetzung nötig (Sprachen stimmen überein)');
        return null;
      }
      
      // Prüfe Cache
      final cacheKey = '$greeting|$targetLanguage';
      if (_translationCache.containsKey(cacheKey)) {
        debugLog('🌍 Übersetzung: Aus Cache geladen');
        return _translationCache[cacheKey]!;
      }
      
      // Übersetze
      try {
        // Mappe Language-Codes zu Google Translate API-Codes
        // WICHTIG: 'zh' muss zu 'zh-cn' gemappt werden, sonst LanguageNotSupportedException
        final fromCode = _mapToGoogleTranslateCode(detectedLanguage);
        final toCode = _mapToGoogleTranslateCode(targetLanguage);
        
        debugLog('🌍 Übersetzung: Starte Übersetzung von "$detectedLanguage" ($fromCode) nach "$targetLanguage" ($toCode)');
        debugLog('🌍 Übersetzung: Original-Text: "$greeting"');
        
        final translation = await _translator.translate(
          greeting,
          from: fromCode,
          to: toCode,
        );
        
        final translatedText = translation.text;
        debugLog('🌍 Übersetzung: Erfolgreich übersetzt zu: "$translatedText"');
        
        // Speichere im Cache
        _translationCache[cacheKey] = translatedText;
        
        return translatedText;
      } catch (e, stackTrace) {
        debugLog('❌ Fehler bei der Übersetzung:');
        debugLog('❌ Fehler-Typ: ${e.runtimeType}');
        debugLog('❌ Fehler-Message: $e');
        debugLog('❌ Von: "$detectedLanguage" nach "$targetLanguage"');
        debugLog('❌ Original-Text: "$greeting"');
        debugLog('❌ Stack trace: $stackTrace');
        
        // Versuche Fallback 1: Übersetze ohne "from"-Parameter (Auto-Detection)
        if (detectedLanguage != targetLanguage) {
          try {
            debugLog('🔄 Versuche Fallback 1: Übersetzung mit Auto-Detection (ohne from-Parameter)...');
            final toCode = _mapToGoogleTranslateCode(targetLanguage);
            debugLog('🔄 Fallback: Ziel-Sprache gemappt: $toCode');
            final fallbackTranslation = await _translator.translate(
              greeting,
              to: toCode,
            );
            final fallbackText = fallbackTranslation.text;
            debugLog('✅ Fallback-Übersetzung erfolgreich: "$fallbackText"');
            _translationCache[cacheKey] = fallbackText;
            return fallbackText;
          } catch (fallbackError, fallbackStackTrace) {
            debugLog('❌ Fallback 1 fehlgeschlagen: $fallbackError');
            debugLog('❌ Fallback Stack trace: $fallbackStackTrace');
            
            // Versuche Fallback 2: Nur mit 'to', ohne jegliche Parameter
            try {
              debugLog('🔄 Versuche Fallback 2: Übersetzung nur mit to-Parameter (ohne from)...');
              final toCode = _mapToGoogleTranslateCode(targetLanguage);
              // Versuche mit explizitem 'auto' für from
              final fallback2Translation = await _translator.translate(
                greeting,
                from: 'auto',
                to: toCode,
              );
              final fallback2Text = fallback2Translation.text;
              debugLog('✅ Fallback 2 erfolgreich: "$fallback2Text"');
              _translationCache[cacheKey] = fallback2Text;
              return fallback2Text;
            } catch (fallback2Error) {
              debugLog('❌ Fallback 2 fehlgeschlagen: $fallback2Error');
            }
          }
        }
        
        // Bei Fehler: null zurückgeben (keine Übersetzung anzeigen, Original-Text bleibt sichtbar)
        debugLog('⚠️ Alle Übersetzungsversuche fehlgeschlagen. Zeige nur Original-Text.');
        return null;
      }
    } catch (e) {
      debugLog('❌ Fehler in translateGreetingIfNeeded: $e');
      debugLog('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }
  
  /// Übersetzt einen Gruß synchron (ohne async, für einfache Fälle)
  /// Diese Methode sollte nur verwendet werden, wenn keine API-Übersetzung nötig ist
  static String translateGreetingSimple(String greeting, BuildContext context) {
    if (greeting.isEmpty) return greeting;
    
    final currentLocale = LocaleHelper.localeNotifier.value;
    final targetLanguage = currentLocale.languageCode;
    
    final detectedLanguage = _detectLanguage(greeting);
    
    // Wenn die erkannte Sprache mit der Zielsprache übereinstimmt, keine Übersetzung nötig
    if (detectedLanguage == targetLanguage) {
      return greeting;
    }
    
    // Für eine einfache synchronen Übersetzung würden wir hier eine statische Übersetzungstabelle verwenden
    // Aber da wir Google Translate verwenden, müssen wir async sein
    return greeting;
  }
}

