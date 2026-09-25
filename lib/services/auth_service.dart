import 'package:firebase_auth/firebase_auth.dart';

/// Ergebnis von [AuthService.applyEmailVerificationCodeSafely].
enum EmailVerificationApplyOutcome {
  /// `applyActionCode` erfolgreich.
  applied,

  /// E-Mail war bereits bestätigt (z. B. Link zuvor in Mail/Safari geöffnet).
  alreadyVerified,

  /// Gleicher oobCode wurde in dieser App-Session schon verarbeitet.
  duplicateLink,
}

/// Gemeinsame Logik für E-Mail-Verifizierung per Deep Link (`/verify?oobCode=`) oder manuellem Code.
class AuthService {
  AuthService._();

  static final Set<String> _consumedOobCodes = <String>{};

  static bool uriLooksLikeAppEmailVerification(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host != 'vibesbox.app' && host != 'www.vibesbox.app') return false;
    var p = uri.path;
    if (p.endsWith('/') && p.length > 1) p = p.substring(0, p.length - 1);
    if (p.toLowerCase() != '/verify') return false;
    // Passwort-Reset teilt /verify, darf nicht als E-Mail-Verifizierung gelten.
    final mode = (uri.queryParameters['mode'] ?? '').trim();
    if (mode == 'resetPassword' || mode == 'recoverEmail') return false;
    final code = uri.queryParameters['oobCode'];
    return code != null && code.trim().isNotEmpty;
  }

  /// Vollständige URL, nur `oobCode` oder roher OOB-String aus der E-Mail.
  static String? extractOobCodeFromInput(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;

    final uri = Uri.tryParse(t);
    if (uri != null) {
      final q = uri.queryParameters['oobCode'];
      if (q != null && q.isNotEmpty) return q;
    }

    final m = RegExp(r'[?&]oobCode=([^&]+)').firstMatch(t);
    if (m != null) {
      try {
        return Uri.decodeComponent(m.group(1)!);
      } catch (_) {
        return m.group(1);
      }
    }

    if (RegExp(r'^[-A-Za-z0-9~._%]{20,}$').hasMatch(t)) return t;
    return null;
  }

  static Future<void> _reloadCurrentUserSilently() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}
  }

  static bool get _isCurrentUserEmailVerified =>
      FirebaseAuth.instance.currentUser?.emailVerified == true;

  /// Wendet den Code an, ignoriert Doppel-Klicks und bereits bestätigte Konten.
  static Future<EmailVerificationApplyOutcome> applyEmailVerificationCodeSafely(
    String oobCode,
  ) async {
    final trimmed = oobCode.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-oob-code', message: 'empty');
    }

    if (_consumedOobCodes.contains(trimmed)) {
      return EmailVerificationApplyOutcome.duplicateLink;
    }

    await _reloadCurrentUserSilently();
    if (_isCurrentUserEmailVerified) {
      _consumedOobCodes.add(trimmed);
      return EmailVerificationApplyOutcome.alreadyVerified;
    }

    try {
      await FirebaseAuth.instance.applyActionCode(trimmed);
      _consumedOobCodes.add(trimmed);
      await _reloadCurrentUserSilently();
      return EmailVerificationApplyOutcome.applied;
    } on FirebaseAuthException {
      await _reloadCurrentUserSilently();
      if (_isCurrentUserEmailVerified) {
        _consumedOobCodes.add(trimmed);
        return EmailVerificationApplyOutcome.alreadyVerified;
      }
      rethrow;
    }
  }
}
