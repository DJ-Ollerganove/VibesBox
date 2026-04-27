import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../utils/debug_log.dart';

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
      if (kDebugMode) {
        debugLog(
          'ℹ️ App Check: Debug-Provider — nach erstem Start das ausgegebene Debug-Token in der '
          'Firebase Console (App Check) eintragen.',
        );
        await FirebaseAppCheck.instance.activate(
          providerWeb: kIsWeb ? ReCaptchaV3Provider(recaptchaWebSiteKey) : null,
          providerAndroid: const AndroidDebugProvider(),
          providerApple: const AppleDebugProvider(),
        );
        try {
          final token = await FirebaseAppCheck.instance.getToken();
          if (token != null && token.isNotEmpty) {
            debugLog(
              'ℹ️ App Check Debug-Token (für Firebase Console → App Check → Apps → Debug): $token',
            );
          } else {
            debugLog(
              'ℹ️ App Check: getToken() leer — ggf. Logcat nach nativer „Enter this debug secret“-Zeile prüfen.',
            );
          }
        } catch (e) {
          debugLog(
            'ℹ️ App Check: Debug-Token konnte nicht gelesen werden (nativer Log kann trotzdem Token zeigen): $e',
          );
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          providerWeb: kIsWeb ? ReCaptchaV3Provider(recaptchaWebSiteKey) : null,
          providerAndroid: const AndroidPlayIntegrityProvider(),
          providerApple: const AppleAppAttestProvider(),
        );
        debugLog(
          '✅ Firebase App Check aktiv (Android: Play Integrity, Apple: App Attest, Web: reCAPTCHA v3). '
          'Durchsetzung zusätzlich in der Firebase Console bei Auth / Functions aktivieren.',
        );
      }

      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (e) {
      debugLog('⚠️ Firebase App Check Aktivierung fehlgeschlagen: $e');
    }
  }
}
