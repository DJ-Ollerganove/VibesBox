import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;

import 'package:recaptcha_enterprise_flutter/recaptcha.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_action.dart';

import 'app_check_service.dart';
import '../utils/debug_log.dart';

/// Token für Firebase Callable [sendAuthEmail] — Action muss mit RECAPTCHA_CONTACT_ACTION ('submit') im Backend übereinstimmen.
///
/// **Plattform-Keys:** Web → [AppCheckService.recaptchaWebSiteKey], Android → [AppCheckService.recaptchaAndroidSiteKey],
/// iOS → [AppCheckService.recaptchaIosSiteKey].
///
/// **Resilienz:** Bei jedem Fehler oder leerem Token wird `''` zurückgegeben — Aufrufer setzen
/// `recaptchaTechnicalBypass` für [sendAuthEmail], damit der Mail-Versand nicht blockiert wird.
///
/// **Timeout:** Native-Plugin übergibt Millisekunden an Android/iOS (z. B. `10000` = 10 s).
class RecaptchaEnterpriseActionService {
  RecaptchaEnterpriseActionService._();

  static void _debugLogLoadedSiteKey(String siteKey, String label) {
    if (!kDebugMode) return;
    final len = siteKey.length;
    final preview = len <= 14
        ? '(zu kurz)'
        : '${siteKey.substring(0, 10)}…${siteKey.substring(len - 4)} (Länge $len)';
    debugLog(
      '[reCAPTCHA Enterprise] $label → siteKey $preview',
    );
  }

  /// Web / Android / iOS — ohne `dart:io` (Web-Build-kompatibel).
  static String _recaptchaKeyLabel() {
    if (kIsWeb) {
      return 'Web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      default:
        return 'Web(Fallback)';
    }
  }

  static String _siteKeyForFetchClient() {
    if (kIsWeb) {
      return AppCheckService.recaptchaWebSiteKey;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AppCheckService.recaptchaAndroidSiteKey;
      case TargetPlatform.iOS:
        return AppCheckService.recaptchaIosSiteKey;
      default:
        return AppCheckService.recaptchaWebSiteKey;
    }
  }

  /// Gleicher Key wie beim Token — wird an [sendAuthEmail] übergeben, damit die Cloud Function
  /// das Assessment mit dem passenden `siteKey` ausführt.
  static String siteKeyForBackendAttestation() => _siteKeyForFetchClient();

  /// Liefert ein Enterprise-Token oder `''` bei Fehler/leer — **wirft nicht** (E-Mail-Flow soll weiterlaufen).
  static Future<String> getSubmitActionToken() async {
    final label = _recaptchaKeyLabel();
    debugLog('reCAPTCHA: Nutze $label Key');
    final siteKey = _siteKeyForFetchClient();
    _debugLogLoadedSiteKey(siteKey, label);

    try {
      final client = await Recaptcha.fetchClient(siteKey);
      final token = await client.execute(
        RecaptchaAction.custom('submit'),
        timeout: 10000,
      );
      final t = token.trim();
      if (t.isEmpty) {
        debugLog(
          'reCAPTCHA Enterprise: leeres Token — E-Mail-Flow mit serverseitigem Bypass.',
        );
        return '';
      }
      return t;
    } catch (e, st) {
      debugLog('reCAPTCHA Enterprise (execute): $e\n$st');
      return '';
    }
  }
}
