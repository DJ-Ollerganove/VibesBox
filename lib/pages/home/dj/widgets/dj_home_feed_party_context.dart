import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../config/app_config.dart';
import '../../../../services/active_party_service.dart';
import '../../../../services/open_wishes_visibility_service.dart';
import '../../../../services/user_service.dart';

/// Startseiten-Feed: Visibility-Stream aktiv halten und Party/Session stabil auflösen.
class DjHomeFeedPartyContext {
  DjHomeFeedPartyContext._();

  static final DjHomeFeedPartyContext instance = DjHomeFeedPartyContext._();

  StreamSubscription<OpenWishesVisibility?>? _visibilitySub;
  int _retainCount = 0;

  void retain() {
    _retainCount++;
    _visibilitySub ??=
        OpenWishesVisibilityService.watch().listen((_) {});
  }

  void release() {
    if (_retainCount <= 0) return;
    _retainCount--;
    if (_retainCount > 0) return;
    unawaited(_visibilitySub?.cancel());
    _visibilitySub = null;
  }

  /// Laufende Party oder Nachlaufzeit — ohne kurzzeitiges Null durch Session-Ticks.
  String? resolveOpenWishesPartyId() {
    return OpenWishesVisibilityService.resolveDjWishPartyId();
  }

  static String? _effectiveDjId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final current = UserService().currentUser.value;
    final isAdmin = current != null &&
        current.id == user.uid &&
        AppConfig.isAdminRole(current);
    if (isAdmin && AppConfig.adminDjId != null) {
      return AppConfig.adminDjId;
    }
    return user.uid;
  }

  /// Session für Musik-History der laufenden Party bzw. Nachlaufzeit.
  /// Immer über Firestore auflösen (Session mit Tracks), nicht nur stored —
  /// sonst kann History leer sein, obwohl Saves in eine andere Session gingen.
  Future<String?> resolveMusicHistorySessionId() async {
    final partyId = resolveOpenWishesPartyId();
    if (partyId == null || partyId.isEmpty) return null;

    final fromParty = await ActivePartyService.resolveMusicHistorySessionIdForParty(
      partyId,
      djId: _effectiveDjId(),
    );
    if (fromParty != null && fromParty.isNotEmpty) {
      return fromParty;
    }

    final stored = ActivePartyService.getStoredSession();
    if (stored != null &&
        stored.partyId == partyId &&
        stored.sessionId != null &&
        stored.sessionId!.isNotEmpty) {
      return stored.sessionId;
    }
    return null;
  }
}
