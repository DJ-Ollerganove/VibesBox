import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/guest_floor_option.dart';
import '../utils/venue_party_fields.dart';
import 'guest_floor_session_service.dart';

/// Ergebnis der Join-Code-Auflösung — **identische Logik** wie `vbResolveJoinCodeLookup` in `party_shared.js`.
enum GuestJoinResolveAction {
  join,
  selectFloor,
  ambiguous,
  notFound,
}

class GuestJoinResolveResult {
  const GuestJoinResolveResult({
    required this.action,
    this.partyDoc,
    this.floorOptions,
  });

  final GuestJoinResolveAction action;
  final QueryDocumentSnapshot<Map<String, dynamic>>? partyDoc;
  final List<GuestFloorOption>? floorOptions;
}

/// Zentrale Gast-Join-Auflösung (App ≡ PWA).
class GuestJoinCodeResolver {
  GuestJoinCodeResolver._();

  static GuestJoinResolveResult resolve({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
    required DateTime now,
    required bool Function(Map<String, dynamic>, DateTime) isGuestJoinable,
    List<GuestFloorOption>? floorOptionsForSelection,
  }) {
    if (allDocs.isEmpty) {
      return const GuestJoinResolveResult(action: GuestJoinResolveAction.notFound);
    }

    final joinable = allDocs
        .where((d) => isGuestJoinable(d.data(), now))
        .toList();

    if (joinable.length == 1) {
      return GuestJoinResolveResult(
        action: GuestJoinResolveAction.join,
        partyDoc: joinable.first,
      );
    }

    if (joinable.length > 1 &&
        VenuePartyFields.hasMultipleDistinctPublicFloors(
          joinable.map((d) => d.data()),
        )) {
      final options = floorOptionsForSelection ?? const [];
      final distinctKeys = options.map((o) => o.floorKey).toSet();
      if (distinctKeys.length > 1) {
        return GuestJoinResolveResult(
          action: GuestJoinResolveAction.selectFloor,
          floorOptions: options,
        );
      }
    }

    if (joinable.length > 1) {
      return const GuestJoinResolveResult(
        action: GuestJoinResolveAction.ambiguous,
      );
    }

    final pickPool = joinable.isNotEmpty ? joinable : allDocs;
    final best = GuestFloorSessionService.pickBestPartyDoc(pickPool, now: now);
    if (best == null) {
      return const GuestJoinResolveResult(action: GuestJoinResolveAction.notFound);
    }

    return GuestJoinResolveResult(
      action: GuestJoinResolveAction.join,
      partyDoc: best,
    );
  }
}
