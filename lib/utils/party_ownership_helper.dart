import '../config/app_config.dart';
import '../models/user_model.dart';

/// Prüft, ob ein Party-Dokument dem eingeloggten DJ gehört (Firestore-Regeln analog).
class PartyOwnershipHelper {
  PartyOwnershipHelper._();

  static bool isPartyOwnedByUid(
    Map<String, dynamic>? partyData,
    String uid,
  ) {
    if (partyData == null || uid.isEmpty) return false;
    final createdBy = partyData['created_by'] as String?;
    final djId = partyData['djId'] as String?;
    final ownerUid = partyData['uid'] as String?;
    final djCode = partyData['dj_code'] as String?;
    return createdBy == uid ||
        djId == uid ||
        ownerUid == uid ||
        djCode == uid;
  }

  /// Darf der aktuelle Nutzer diese Party bearbeiten/löschen?
  static bool canManageParty(
    Map<String, dynamic>? partyData,
    String? authUid, {
    UserModel? currentUser,
  }) {
    if (authUid == null || authUid.isEmpty) return false;
    if (currentUser != null && AppConfig.isAdminRole(currentUser)) {
      return true;
    }
    return isPartyOwnedByUid(partyData, authUid);
  }
}
