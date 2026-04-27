import 'package:firebase_auth/firebase_auth.dart';

/// Gemeinsame Logik für E-Mail-Verifizierung per Deep Link (`/verify?oobCode=`) oder manuellem Code.
class AuthService {
  AuthService._();

  static bool uriLooksLikeAppEmailVerification(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host != 'vibesbox.app' && host != 'www.vibesbox.app') return false;
    var p = uri.path;
    if (p.endsWith('/') && p.length > 1) p = p.substring(0, p.length - 1);
    if (p.toLowerCase() != '/verify') return false;
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

  /// Wendet den Firebase-Aktionscode an und lädt den aktuellen User neu (falls vorhanden).
  static Future<void> applyEmailVerificationCode(String oobCode) async {
    final trimmed = oobCode.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-oob-code', message: 'empty');
    }
    await FirebaseAuth.instance.applyActionCode(trimmed);
    await FirebaseAuth.instance.currentUser?.reload();
  }
}
