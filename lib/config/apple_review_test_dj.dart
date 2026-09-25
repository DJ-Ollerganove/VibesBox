import '../models/user_model.dart';

/// Fest verdrahteter Apple-Review-/Test-DJ.
/// Bleibt Free, darf aber:
/// - längere Partys (14 Tage, kein 12h-Cutoff)
/// - mehr Free-Partys pro Abrechnungszeitraum
/// - Wunsch-Limits wie Pro (kein Free-Zwang auf 1/Stunde)
/// Nur dieser Account — keine globale Free-Änderung.
class AppleReviewTestDj {
  AppleReviewTestDj._();

  static const String email = 'info@ollerganove.de';
  static const String uid = 'ac8TzERL6VMRjHq7AOrNeer5yyA2';

  /// Free-Party-Kontingent pro Abrechnungszeitraum (sonst Free = 1).
  static const int freePartiesPerPeriod = 5;

  static bool isUid(String? id) =>
      id != null && id.trim() == uid;

  static bool isEmail(String? value) =>
      value != null && value.trim().toLowerCase() == email;

  static bool matchesUser(UserModel? user) {
    if (user == null) return false;
    return isUid(user.id) || isEmail(user.email);
  }

  /// Party gehört zu diesem Test-DJ ([created_by] / E-Mail-Felder).
  static bool matchesPartyData(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (isUid(data['created_by']?.toString())) return true;
    if (isUid(data['djId']?.toString())) return true;
    if (isEmail(data['created_by_email']?.toString())) return true;
    return false;
  }

  /// Free-Account, aber Wunsch-Limits wie Pro (kein Lock auf 1/Stunde).
  static bool usesProStyleWishLimits(UserModel? user) => matchesUser(user);
}
