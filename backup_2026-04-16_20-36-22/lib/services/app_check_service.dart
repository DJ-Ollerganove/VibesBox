import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../utils/debug_log.dart';

/// App Check: **Release** = Play Integrity / App Attest / Web reCAPTCHA v3.
/// **Debug** = [AndroidDebugProvider] / [AppleDebugProvider] — Token aus Log in der Firebase Console
/// unter App Check → Debug-Token registrieren (sonst schlagen geschützte Callables fehl).
class AppCheckService {
  AppCheckService._();

  /// Öffentlicher reCAPTCHA-Enterprise-Site-Key (muss zu Cloud Function / Assessment passen).
  static const String recaptchaEnterpriseSiteKey =
      '6LdoeDcsAAAAAIORb90GjRovm2tW5qE4v9q5J-u5';

  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        debugLog(
          'ℹ️ App Check: Debug-Provider — nach erstem Start das ausgegebene Debug-Token in der '
          'Firebase Console (App Check) eintragen.',
        );
        await FirebaseAppCheck.instance.activate(
          providerWeb: kIsWeb ? ReCaptchaV3Provider(recaptchaEnterpriseSiteKey) : null,
          providerAndroid: const AndroidDebugProvider(),
          providerApple: const AppleDebugProvider(),
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          providerWeb: kIsWeb ? ReCaptchaV3Provider(recaptchaEnterpriseSiteKey) : null,
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
