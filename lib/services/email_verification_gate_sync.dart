/// Synchronisiert [User.reload] nach Login auf der [LoginPage] mit der
/// [MainPage]-Prüfung, damit kein zweites „Profil lädt“-Overlay ohne Login-Hintergrund
/// aufblitzt.
class EmailVerificationGateSync {
  EmailVerificationGateSync._();

  static String? _loginReloadCompletedUid;

  /// Nach erfolgreichem [User.reload] auf der Login-Route aufrufen, **bevor** die Route
  /// geschlossen wird.
  static void markLoginReloadCompleted(String uid) {
    _loginReloadCompletedUid = uid;
  }

  /// Wenn die Login-Seite den Reload bereits erledigt hat, entfällt ein zweiter
  /// Netzwerk-[reload] auf der MainPage (verhindert Flackern).
  static bool consumeLoginReloadCompleted(String uid) {
    if (_loginReloadCompletedUid == uid) {
      _loginReloadCompletedUid = null;
      return true;
    }
    return false;
  }

  static void clear() {
    _loginReloadCompletedUid = null;
  }
}
