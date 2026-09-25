import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';

/// Zentraler Einstieg für [AppLinks]: Stream, Initial-Link und **`/verify?oobCode=`** → `applyActionCode`.
///
/// **Native (bereits konfiguriert):**
/// - Android: `AndroidManifest.xml` — Party/Invite/`/verify` (kein Domain-weiten `/`),
///   `autoVerify` + Hosting `/.well-known/assetlinks.json`.
/// - iOS: `Runner.entitlements` — `applinks:www.vibesbox.app`, `applinks:vibesbox.app`
///   + Hosting `/.well-known/apple-app-site-association` (ohne `/vb/verify.html`).
///
/// Passwort-Reset gehört **nicht** in die App.
///
/// **E-Mails (sofort, ohne App-Update):** `dj-ollerganove.web.app/vb/verify.html`
/// (Host ohne App Links).
///
/// **Nach App-Update:** gleiche Seite unter `www.vibesbox.app/vb/verify.html`
/// (Pfad ist aus App Links / Android Intent-Filtern ausgenommen). Alte
/// `/verify?mode=resetPassword`-Links öffnen wir hier im Browser.
class AppLinksService {
  AppLinksService._();
  static final AppLinksService instance = AppLinksService._();

  /// Ziel-URL nach App-Update / wenn Reset versehentlich die App öffnet.
  static const String passwordResetWebPath =
      'https://www.vibesbox.app/vb/verify.html';

  /// Sofort-Link ohne App-Claim (aktuell in den Reset-Mails).
  static const String passwordResetWebPathNoAppLink =
      'https://dj-ollerganove.web.app/vb/verify.html';

  final AppLinks _appLinks = AppLinks();

  /// Gleicher Stream wie [AppLinks.uriLinkStream].
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;

  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  /// Zuletzt an die App übergebener Link (u. a. nach Resume, wenn das System den Link puffert).
  Future<Uri?> getLatestLink() => _appLinks.getLatestLink();

  /// DJ B2B Invite: `/invite/DJ######` auf vibesbox.app
  bool isDjB2bInviteDeepLink(Uri uri) {
    if (!_isVibesboxWebHost(uri)) return false;
    if (uri.pathSegments.contains('invite')) return true;
    final code = uri.queryParameters['code'];
    return code != null &&
        RegExp(r'^DJ\d{6}$', caseSensitive: false).hasMatch(code.trim());
  }

  bool _isVibesboxWebHost(Uri uri) {
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final h = uri.host.toLowerCase();
      return h == 'vibesbox.app' ||
          h == 'www.vibesbox.app' ||
          h == 'dj-ollerganove.web.app' ||
          h == 'dj-ollerganove.firebaseapp.com';
    }
    return uri.scheme == 'vibesbox';
  }

  /// Passwort-Reset-Link (darf nicht in der App „verifiziert“ werden).
  bool isPasswordResetDeepLink(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final mode = (uri.queryParameters['mode'] ?? '').trim();
    if (mode != 'resetPassword') return false;
    final oob = (uri.queryParameters['oobCode'] ?? '').trim();
    if (oob.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (host != 'vibesbox.app' &&
        host != 'www.vibesbox.app' &&
        host != 'dj-ollerganove.web.app' &&
        host != 'dj-ollerganove.firebaseapp.com') {
      return false;
    }
    var p = uri.path;
    if (p.endsWith('/') && p.length > 1) p = p.substring(0, p.length - 1);
    final lower = p.toLowerCase();
    return lower == '/verify' ||
        lower.endsWith('/verify.html') ||
        lower.endsWith('/vb/verify.html');
  }

  /// Browser-URL für Passwort setzen.
  /// Bevorzugt vibesbox.app (nach Manifest-Update kein App-Claim auf diesem Pfad).
  /// Fallback web.app: alte Android-Builds klaimen noch die ganze Domain — sonst Loop.
  Uri passwordResetBrowserUri(Uri from) {
    final oob = (from.queryParameters['oobCode'] ?? '').trim();
    final q = '?mode=resetPassword&oobCode=${Uri.encodeComponent(oob)}';
    // Immer web.app öffnen: funktioniert mit alter und neuer App ohne Deep-Link-Loop.
    // vibesbox.app/vb/verify.html ist parallel erreichbar und für künftige Mail-Links gedacht.
    return Uri.parse('$passwordResetWebPathNoAppLink$q');
  }

  /// vibesbox.app-Variante (für Logs / spätere Umstellung der Mail-Links).
  Uri passwordResetVibesboxUri(Uri from) {
    final oob = (from.queryParameters['oobCode'] ?? '').trim();
    return Uri.parse(
      '$passwordResetWebPath'
      '?mode=resetPassword&oobCode=${Uri.encodeComponent(oob)}',
    );
  }

  /// Alte App-Link-Resets: im System-Browser öffnen (Formular nur auf der Website).
  Future<bool> openPasswordResetInExternalBrowser(Uri uri) async {
    if (!isPasswordResetDeepLink(uri)) return false;
    final target = passwordResetBrowserUri(uri);
    try {
      return await launchUrl(target, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// `true`, wenn die URL eine App-Verifizierung ist (`https://www.vibesbox.app/verify?oobCode=` o. ä.).
  bool isEmailVerificationDeepLink(Uri uri) =>
      AuthService.uriLooksLikeAppEmailVerification(uri);

  /// Wenn [uri] eine Verifizierungs-URL ist: oobCode anwenden ([AuthService.applyEmailVerificationCodeSafely]).
  /// `null` = kein Verify-Link. Sonst Ergebnis; wirft nur bei echtem Fehler.
  Future<EmailVerificationApplyOutcome?> tryApplyVerificationDeepLink(
    Uri uri,
  ) async {
    if (!AuthService.uriLooksLikeAppEmailVerification(uri)) return null;
    final oob = uri.queryParameters['oobCode'];
    if (oob == null || oob.isEmpty) return null;
    return AuthService.applyEmailVerificationCodeSafely(oob);
  }
}
