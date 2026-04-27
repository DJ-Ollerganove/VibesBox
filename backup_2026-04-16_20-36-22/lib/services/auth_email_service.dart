import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';
import '../utils/sanitize.dart';
import 'recaptcha_enterprise_action_service.dart';
import '../utils/debug_log.dart';

/// Verifizierungs- und Passwort-Reset-Mails ausschließlich über Callable [sendAuthEmail].
/// Inhalte kommen aus [AppLocalizations] (Sprache = UI zum Aufruf).
///
/// Server: [sendAuthEmail] mit **enforceAppCheck: true** — nur Clients mit gültigem App-Check-Token
/// (Release: Play Integrity / App Attest; Debug: Debug-Token in der Firebase Console).
///
/// Hinweis: HTTPS Callable nutzt kein browser-CORS.
class AuthEmailService {
  AuthEmailService._();

  static const String _region = 'us-central1';

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

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
      final recaptchaToken =
          await RecaptchaEnterpriseActionService.getSubmitActionToken();
      final result = await callable.call<Map<String, dynamic>>({
        'type': 'verification',
        'idToken': idToken,
        'recaptchaToken': recaptchaToken,
        'subject': subject,
        'bodyTemplate': bodyTemplate,
        'userName': userName.trim(),
        'locale': l.locale.languageCode,
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
      rethrow;
    }
  }

  static Future<void> sendPasswordResetEmail({
    required AppLocalizations l,
    required String email,
  }) async {
    debugLog('🚀 [PasswordReset] Starte Request zu Cloud Function...');
    try {
      final trimmed = sanitizeEmail(email);
      final callable = _functions.httpsCallable('sendAuthEmail');
      final recaptchaToken =
          await RecaptchaEnterpriseActionService.getSubmitActionToken();
      final result = await callable.call<Map<String, dynamic>>({
        'type': 'passwordReset',
        'email': trimmed,
        'recaptchaToken': recaptchaToken,
        'subject': l.auth_password_reset_subject,
        'bodyTemplate': l.translate('auth_password_reset_body'),
        'userName': trimmed.split('@').first,
        'locale': l.locale.languageCode,
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
      rethrow;
    }
  }
}
