import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../utils/debug_log.dart';

void _appCheckPrint(String message) {
  // Immer ausgeben (auch Profile) — nicht nur [kDebugMode], sonst fehlt das Debug-Token in Xcode/Geräte-Logs.
  debugPrint('[AppCheck] $message');
}

/// App Check: **Release** = Play Integrity / App Attest / Web reCAPTCHA v3.
/// **Debug** = [AndroidDebugProvider] / [AppleDebugProvider] — Token aus Log in der Firebase Console
/// unter App Check → Debug-Token registrieren (sonst schlagen geschützte Callables fehl).
class AppCheckService {
  AppCheckService._();

  /// **Nur Web / PWA:** App Check `ReCaptchaV3Provider` und reCAPTCHA Enterprise (Web) — nicht der Android-Key.
  static const String recaptchaWebSiteKey =
      '6LdoeDcsAAAAAI0Rb90GjRovm2tW5qE4v9q5J-u5';

  /// **Android:** `Recaptcha.fetchClient` — eigener Enterprise-Key (Package + SHA-256 in GCP).
  static const String recaptchaAndroidSiteKey =
      '6Le9Wr4sAAAAAJwlB6cpaPZXHlam_QeRCvZkrrIW';

  /// **iOS:** eigener Key in der Console; bislang Fallback wie früher (Web-Key-Generation).
  static const String recaptchaIosSiteKey =
      '6LdoeDcsAAAAAIORb90GjRovm2tW5qE4v9q5J-u5';

  /// @deprecated Verwende [recaptchaWebSiteKey] (Web) bzw. [recaptchaAndroidSiteKey]/[recaptchaIosSiteKey] (Mobile).
  static const String recaptchaEnterpriseSiteKey = recaptchaWebSiteKey;

  static Future<void> initialize() async {
    try {
      // Profile (`flutter run --profile`, install-stable) hat kDebugMode == false — würde sonst
      // App Attest nutzen und mit „App not registered“ spammen, wenn die iOS-App in Firebase
      // App Check noch nicht passt. Nicht-Release = Debug-Provider wie im reinen Debug-Build.
      final useDebugProviders = !kReleaseMode;
      if (useDebugProviders) {
        _appCheckPrint(
          'Debug-Provider aktiv (${kDebugMode ? "Debug" : "Profile"}) — Token unten in Firebase Console '
          '→ App Check → iOS-App → „Debug-Tokens verwalten“ eintragen.',
        );
        await FirebaseAppCheck.instance.activate(
          providerWeb: kIsWeb ? ReCaptchaV3Provider(recaptchaWebSiteKey) : null,
          providerAndroid: const AndroidDebugProvider(),
          providerApple: const AppleDebugProvider(),
        );
        try {
          // Einmal Token ziehen, damit das Secret sicher im Log landet (JWT; zur Registrierung meist ausreichend).
          final token = await FirebaseAppCheck.instance.getToken(true);
          if (token != null && token.isNotEmpty) {
            _appCheckPrint(
              'DEBUG TOKEN / App Check JWT (Firebase Console → App Check → Apps → iOS → Debug-Tokens): $token',
            );
          } else {
            _appCheckPrint(
              'getToken() leer — in Xcode/Konsole nach nativer Zeile „Firebase App Check“ / '
              '„Enter this debug secret“ suchen.',
            );
          }
        } catch (e) {
          _appCheckPrint(
            'getToken fehlgeschlagen (nativer Log kann trotzdem Debug-Secret zeigen): $e',
          );
        }
        debugLog(
          'ℹ️ App Check: Debug-Provider — siehe [AppCheck]-Zeilen oben (auch in Profile sichtbar).',
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          providerWeb: kIsWeb ? ReCaptchaV3Provider(recaptchaWebSiteKey) : null,
          providerAndroid: const AndroidPlayIntegrityProvider(),
          providerApple: const AppleAppAttestProvider(),
        );
        _appCheckPrint(
          'Release: Play Integrity / App Attest aktiv — Durchsetzung in Firebase Console prüfen.',
        );
        debugLog(
          '✅ Firebase App Check aktiv (Android: Play Integrity, Apple: App Attest, Web: reCAPTCHA v3). '
          'Durchsetzung zusätzlich in der Firebase Console bei Auth / Functions aktivieren.',
        );
      }

      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (e) {
      _appCheckPrint('Aktivierung fehlgeschlagen: $e');
      debugLog('⚠️ Firebase App Check Aktivierung fehlgeschlagen: $e');
    }
  }
}
