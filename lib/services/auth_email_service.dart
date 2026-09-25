import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../l10n/app_localizations.dart';
import '../utils/sanitize.dart';
import 'recaptcha_enterprise_action_service.dart';
import '../utils/debug_log.dart';

/// Verifizierungs- und Passwort-Reset-Mails bevorzugt über Callable [sendAuthEmail].
/// Der Server versendet per **EmailJS** (Service-/Template-ID, Public Key, Private Key in Functions).
///
/// Inhalte kommen aus [AppLocalizations] (Sprache = UI zum Aufruf).
///
/// Fallback (wie Verifizierung): Wenn der Callable scheitert (z. B. App Check), nutzt die App
/// [User.sendEmailVerification] bzw. [FirebaseAuth.sendPasswordResetEmail], damit Login/Reset
/// nicht komplett blockiert sind.
///
/// Hinweis: HTTPS Callable nutzt kein browser-CORS.
class AuthEmailService {
  AuthEmailService._();

  static const String _region = 'us-central1';

  /// Continue-URL wie Cloud Function [AUTH_EMAIL_CONTINUE_URL].
  static const String _authEmailContinueUrl =
      'https://vibesbox.app/vb/verify.html?firebaseAuth=1';

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  /// EmailJS-Template-Chrome (Intro, Header, Footer, Antworten-Button) aus App-l10n.
  static Map<String, String> _authEmailUiLabels(AppLocalizations l) => {
        'authMailIntro': l.auth_mail_intro,
        'authMailHeader': l.auth_mail_header,
        'registrationHeader': l.auth_registration_header,
        'authMailFooter': l.auth_mail_footer_automated,
        'labelReplyButton': l.label_reply_button,
      };

  static Future<void> sendVerificationEmail({
    required AppLocalizations l,
    required User user,
    required String userName,
    String? registrationRole,
  }) async {
    debugLog('🚀 [Registration] Starte Request zu Cloud Function...');
    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'idToken fehlt nach Registrierung',
        );
      }
      final subject = l.auth_email_verification_subject.trim();
      final bodyTemplate = l
          .translate('auth_email_verification_body')
          .replaceAll('{confirm_email_button}', l.confirm_email_button);
      if (subject.isEmpty) {
        throw StateError('auth_email_verification_subject leer');
      }
      if (!bodyTemplate.contains('{link}')) {
        throw StateError('auth_email_verification_body ohne {link}');
      }

      final callable = _functions.httpsCallable('sendAuthEmail');
      // reCAPTCHA optional: leerer Token → serverseitiger Bypass (keine harte Blockade mehr).
      var recaptchaToken =
          await RecaptchaEnterpriseActionService.getSubmitActionToken();
      var recaptchaTechnicalBypass = false;
      if (recaptchaToken.isEmpty) {
        recaptchaTechnicalBypass = true;
        debugLog(
          '[AuthEmail] Kein reCAPTCHA-Token — sendAuthEmail mit recaptchaTechnicalBypass (EmailJS bleibt aktiv).',
        );
      }
      debugPrint('🚀 EmailJS wird jetzt getriggert');
      final result = await callable.call<Map<String, dynamic>>({
        'type': 'verification',
        'idToken': idToken,
        'recaptchaToken': recaptchaToken,
        if (recaptchaTechnicalBypass) 'recaptchaTechnicalBypass': true,
        if (recaptchaToken.isNotEmpty)
          'recaptchaSiteKey':
              RecaptchaEnterpriseActionService.siteKeyForBackendAttestation(),
        'subject': subject,
        'bodyTemplate': bodyTemplate,
        'userName': userName.trim(),
        'locale': l.locale.languageCode,
        ..._authEmailUiLabels(l),
        if (registrationRole != null && registrationRole.trim().isNotEmpty)
          'role': registrationRole.trim(),
      });
      debugLog('✅ [Registration] Server-Antwort (Callable data): ${result.data}');
    } on FirebaseAuthException {
      rethrow;
    } catch (e, st) {
      debugLog('❌ [Registration] FEHLER: $e');
      debugLog('❌ [Registration] Stack: $st');
      if (e is FirebaseFunctionsException) {
        debugLog(
          '❌ [Registration] code=${e.code} message=${e.message} details=${e.details}',
        );
      }
      // Wenn Callable/App Check/reCAPTCHA/EmailJS scheitert: Nutzer trotzdem einen Link schicken
      // (Firebase-Hosting der Mail; Server-EmailJS bleibt bevorzugter Weg).
      try {
        await user.sendEmailVerification();
        debugLog('✅ [Registration] sendEmailVerification fallback OK');
      } catch (e2, st2) {
        debugLog('❌ [Registration] sendEmailVerification fallback: $e2\n$st2');
        rethrow;
      }
    }
  }

  static Future<void> sendPasswordResetEmail({
    required AppLocalizations l,
    required String email,
  }) async {
    debugLog('🚀 [PasswordReset] Starte Request zu Cloud Function...');
    final trimmed = sanitizeEmail(email);
    try {
      final callable = _functions.httpsCallable('sendAuthEmail');
      var recaptchaToken =
          await RecaptchaEnterpriseActionService.getSubmitActionToken();
      var recaptchaTechnicalBypass = false;
      if (recaptchaToken.isEmpty) {
        recaptchaTechnicalBypass = true;
        debugLog(
          '[AuthEmail] Kein reCAPTCHA-Token (passwordReset) — Callable mit recaptchaTechnicalBypass.',
        );
      }
      debugPrint('🚀 EmailJS wird jetzt getriggert');
      final result = await callable.call<Map<String, dynamic>>({
        'type': 'passwordReset',
        'email': trimmed,
        'recaptchaToken': recaptchaToken,
        if (recaptchaTechnicalBypass) 'recaptchaTechnicalBypass': true,
        if (recaptchaToken.isNotEmpty)
          'recaptchaSiteKey':
              RecaptchaEnterpriseActionService.siteKeyForBackendAttestation(),
        'subject': l.auth_password_reset_subject,
        'bodyTemplate': l.translate('auth_password_reset_body'),
        'userName': trimmed.split('@').first,
        'locale': l.locale.languageCode,
        ..._authEmailUiLabels(l),
      });
      debugLog('✅ [PasswordReset] Server-Antwort (Callable data): ${result.data}');
    } catch (e, st) {
      debugLog('❌ [PasswordReset] FEHLER: $e');
      debugLog('❌ [PasswordReset] Stack: $st');
      if (e is FirebaseFunctionsException) {
        debugLog(
          '❌ [PasswordReset] code=${e.code} message=${e.message} details=${e.details}',
        );
      }
      // Callable/App Check: Nutzer trotzdem Reset-Mail (Firebase Auth Template).
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: trimmed,
          actionCodeSettings: ActionCodeSettings(
            url: _authEmailContinueUrl,
            handleCodeInApp: false,
          ),
        );
        debugLog('✅ [PasswordReset] sendPasswordResetEmail fallback OK');
      } on FirebaseAuthException catch (e2, st2) {
        // Server-Parität: unbekannte E-Mail nicht als Fehler zeigen (Enumeration).
        if (e2.code == 'user-not-found') {
          debugLog(
            'ℹ️ [PasswordReset] Fallback user-not-found — still success UX',
          );
          return;
        }
        debugLog('❌ [PasswordReset] sendPasswordResetEmail fallback: $e2\n$st2');
        rethrow;
      } catch (e2, st2) {
        debugLog('❌ [PasswordReset] sendPasswordResetEmail fallback: $e2\n$st2');
        rethrow;
      }
    }
  }
}
