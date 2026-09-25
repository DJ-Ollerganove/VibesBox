import '../constants/venue_constants.dart';
import '../utils/floor_key_utils.dart';

/// Optionale Party-Felder für Venue/Floor (nur neue Partys — Legacy unverändert).
class VenuePartyFields {
  VenuePartyFields._();

  /// Baut die Map für Firestore — nur gesetzte Felder, kein Backfill für Legacy.
  static Map<String, dynamic> build({
    String? venueId,
    String? floorKey,
    String? floorLabel,
    bool? isCoVenueDj,
  }) {
    final map = <String, dynamic>{};

    if (venueId != null && venueId.trim().isNotEmpty) {
      map['venue_id'] = venueId.trim();
    }

    final normalizedKey = FloorKeyUtils.normalizeFloorKey(floorKey);
    if (normalizedKey != null) {
      map['floor_key'] = normalizedKey;
    }

    if (floorLabel != null && floorLabel.trim().isNotEmpty) {
      map['floor_label'] = floorLabel.trim();
    }

    if (isCoVenueDj == true) {
      map['is_co_venue_dj'] = true;
    }

    return map;
  }

  /// Liest `floor_key` aus Party-Daten (Legacy → null/default).
  static String? readFloorKey(Map<String, dynamic> partyData) {
    return FloorKeyUtils.normalizeFloorKey(partyData['floor_key'] as String?);
  }

  static String? readVenueId(Map<String, dynamic> partyData) {
    final id = partyData['venue_id'] as String?;
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  static bool readIsCoVenueDj(Map<String, dynamic> partyData) {
    return partyData['is_co_venue_dj'] == true;
  }

  static bool hasVenueFields(Map<String, dynamic> partyData) {
    return readVenueId(partyData) != null;
  }

  /// Multi-Floor-Gast-UI nur bei öffentlichen Veranstaltungen mit globaler Venue.
  static bool isPublicVenueParty(Map<String, dynamic> partyData) {
    final type = partyData['party_type'] as String?;
    if (type != 'public') return false;
    return hasVenueFields(partyData);
  }

  /// Unterschiedliche `floor_key` unter öffentlichen Venue-Partys.
  static Set<String> distinctPublicVenueFloorKeys(
    Iterable<Map<String, dynamic>> parties,
  ) {
    final keys = <String>{};
    for (final data in parties) {
      if (!isPublicVenueParty(data)) continue;
      keys.add(effectiveFloorKeyFromParty(data));
    }
    return keys;
  }

  /// Raum-Auswahl nur wenn wirklich mehr als ein Floor aktiv ist (nicht jede öffentliche Party).
  static bool hasMultipleDistinctPublicFloors(
    Iterable<Map<String, dynamic>> parties,
  ) {
    return distinctPublicVenueFloorKeys(parties).length > 1;
  }

  static String effectiveFloorKeyFromParty(Map<String, dynamic> partyData) {
    return FloorKeyUtils.effectiveFloorKey(readFloorKey(partyData));
  }

  static bool isDefaultFloorParty(Map<String, dynamic> partyData) {
    return FloorKeyUtils.isDefaultFloorKey(readFloorKey(partyData));
  }

  /// Für Konflikt-Queries: nur Partys mit venue_id und aktivem Lifecycle.
  static bool isRelevantForVenueConflict(Map<String, dynamic> partyData) {
    if (!hasVenueFields(partyData)) return false;
    final lifecycle = partyData['lifecycle_status'] as String?;
    if (lifecycle == null) return true;
    return VenueConstants.activePartyLifecycleStatuses.contains(lifecycle);
  }
}
