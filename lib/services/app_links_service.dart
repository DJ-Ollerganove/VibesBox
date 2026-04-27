import 'package:app_links/app_links.dart';

import 'auth_service.dart';

/// Zentraler Einstieg für [AppLinks]: Stream, Initial-Link und **`/verify?oobCode=`** → `applyActionCode`.
///
/// **Native (bereits konfiguriert):**
/// - Android: `AndroidManifest.xml` — `https` + `www.vibesbox.app` / `vibesbox.app`, `pathPrefix="/"`,
///   `autoVerify` + Hosting `/.well-known/assetlinks.json`.
/// - iOS: `Runner.entitlements` — `applinks:www.vibesbox.app`, `applinks:vibesbox.app`
///   + Hosting `/.well-known/apple-app-site-association`.
class AppLinksService {
  AppLinksService._();
  static final AppLinksService instance = AppLinksService._();

  final AppLinks _appLinks = AppLinks();

  /// Gleicher Stream wie [AppLinks.uriLinkStream].
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;

  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  /// Zuletzt an die App übergebener Link (u. a. nach Resume, wenn das System den Link puffert).
  Future<Uri?> getLatestLink() => _appLinks.getLatestLink();

  /// `true`, wenn die URL eine App-Verifizierung ist (`https://www.vibesbox.app/verify?oobCode=` o. ä.).
  bool isEmailVerificationDeepLink(Uri uri) =>
      AuthService.uriLooksLikeAppEmailVerification(uri);

  /// Wenn [uri] eine Verifizierungs-URL ist: **`FirebaseAuth.applyActionCode(oobCode)`** ausführen.
  /// Liefert `false`, wenn es kein `/verify`-Link war. Sonst `true` oder wirft (z. B. [FirebaseAuthException]).
  Future<bool> tryApplyVerificationDeepLink(Uri uri) async {
    if (!AuthService.uriLooksLikeAppEmailVerification(uri)) return false;
    final oob = uri.queryParameters['oobCode'];
    if (oob == null || oob.isEmpty) return false;
    await AuthService.applyEmailVerificationCode(oob);
    return true;
  }
}
