import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import 'user_service.dart';

/// Zentraler Guard für Pro/Premium-gesperrte Features (z.B. Musikerkennung).
///
/// Nutzt [UserService.sessionProStatus] (lokal/trial-timer-synchron), kein periodisches Firestore-Polling.
/// Admin-Status wird über Firestore role_id (AppConfig.isAdminRole) ermittelt, nicht über E-Mail.
class ProFeatureGuard {
  ProFeatureGuard._();

  /// True, wenn der übergebene User Admin ist (über Firestore role_id, nicht E-Mail).
  static bool isAdmin(User? user) {
    if (user == null) return false;
    final current = UserService().currentUser.value;
    return current != null &&
        current.id == user.uid &&
        AppConfig.isAdminRole(current);
  }

  /// Synchrone Prüfung (für UI, die auf Trial/Pro-Wechsel sofort reagieren soll).
  static bool canUseMusicRecognitionNow({User? user}) {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) return false;
    if (isAdmin(u)) return true;
    final model = UserService().currentUser.value;
    if (model != null &&
        model.id == u.uid &&
        model.planType == 'free') {
      return true;
    }
    return UserService().sessionProStatus.value?.isActive == true;
  }

  /// True, wenn der aktuelle User Musikerkennung nutzen darf
  /// (Admin, Free mit 5-Min-Limit im [ShazamService], oder aktives Pro/Trial laut Session).
  static Future<bool> canUseMusicRecognition({User? user}) async {
    return canUseMusicRecognitionNow(user: user);
  }

  /// Kompatibilität: früher Firestore-Cache; Session wird live gelesen.
  static void invalidateCache() {}
}


