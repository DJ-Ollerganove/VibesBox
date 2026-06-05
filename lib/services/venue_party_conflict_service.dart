import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/venue_constants.dart';
import '../models/floor_occupancy_info.dart';
import '../utils/floor_key_utils.dart';
import '../utils/venue_party_fields.dart';

/// Überlappende Partys und Floor-Belegung an einer Venue (nur Partys mit `venue_id`).
class VenuePartyConflictService {
  VenuePartyConflictService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Partys an [venueId] mit Zeitüberlappung zu [start]–[end].
  Future<List<Map<String, dynamic>>> findOverlappingParties({
    required String venueId,
    required DateTime start,
    required DateTime end,
    String? excludePartyId,
  }) async {
    if (venueId.trim().isEmpty) return [];

    final snap = await _firestore
        .collection('parties')
        .where('venue_id', isEqualTo: venueId)
        .get();

    final results = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      if (excludePartyId != null && doc.id == excludePartyId) continue;

      final data = doc.data();
      if (!VenuePartyFields.isRelevantForVenueConflict(data)) continue;

      final partyStart = _readDate(data, 'start_date');
      final partyEnd = _readDate(data, 'end_date');
      if (partyStart == null || partyEnd == null) continue;

      if (_rangesOverlap(start, end, partyStart, partyEnd)) {
        results.add({
          'party_id': doc.id,
          ...data,
        });
      }
    }

    return results;
  }

  /// `floor_key`-Werte, die im Zeitfenster bereits belegt sind.
  Future<Set<String>> occupiedFloorKeys({
    required String venueId,
    required DateTime start,
    required DateTime end,
    String? excludePartyId,
  }) async {
    final overlapping = await findOverlappingParties(
      venueId: venueId,
      start: start,
      end: end,
      excludePartyId: excludePartyId,
    );

    return overlapping
        .map(
          (party) => VenuePartyFields.effectiveFloorKeyFromParty(party),
        )
        .toSet();
  }

  /// Belegte Floors inkl. Party-/DJ-Infos für Tausch-Anfragen.
  Future<Map<String, FloorOccupancyInfo>> occupancyByFloorKey({
    required String venueId,
    required DateTime start,
    required DateTime end,
    String? excludePartyId,
  }) async {
    final overlapping = await findOverlappingParties(
      venueId: venueId,
      start: start,
      end: end,
      excludePartyId: excludePartyId,
    );

    final map = <String, FloorOccupancyInfo>{};
    for (final party in overlapping) {
      final floorKey = VenuePartyFields.effectiveFloorKeyFromParty(party);
      final djIdRaw = party['created_by'] ?? party['dj_code'];
      final djId = djIdRaw?.toString().trim() ?? '';
      if (djId.isEmpty) continue;
      map[floorKey] = FloorOccupancyInfo(
        partyId: party['party_id'] as String? ?? '',
        djId: djId,
        floorKey: floorKey,
        floorLabel: party['floor_label'] as String?,
      );
    }
    return map;
  }

  Future<bool> isFloorAvailable({
    required String venueId,
    required String? floorKey,
    required DateTime start,
    required DateTime end,
    String? excludePartyId,
  }) async {
    final effectiveKey = FloorKeyUtils.effectiveFloorKey(floorKey);
    final occupied = await occupiedFloorKeys(
      venueId: venueId,
      start: start,
      end: end,
      excludePartyId: excludePartyId,
    );
    return !occupied.contains(effectiveKey);
  }

  Future<bool> isDefaultFloorOccupied({
    required String venueId,
    required DateTime start,
    required DateTime end,
    String? excludePartyId,
  }) async {
    return !(await isFloorAvailable(
      venueId: venueId,
      floorKey: VenueConstants.defaultFloorKey,
      start: start,
      end: end,
      excludePartyId: excludePartyId,
    ));
  }

  /// Freie Floors aus [allFloorKeys] im Zeitfenster.
  Future<List<String>> availableFloorKeys({
    required String venueId,
    required List<String> allFloorKeys,
    required DateTime start,
    required DateTime end,
    String? excludePartyId,
  }) async {
    final occupied = await occupiedFloorKeys(
      venueId: venueId,
      start: start,
      end: end,
      excludePartyId: excludePartyId,
    );

    return allFloorKeys
        .where((key) => !occupied.contains(key))
        .toList(growable: false);
  }

  /// Gibt es eine überlappende öffentliche Party an der Venue?
  Future<bool> hasVenueOverlap({
    required String venueId,
    required DateTime start,
    required DateTime end,
    String? excludePartyId,
  }) async {
    final overlapping = await findOverlappingParties(
      venueId: venueId,
      start: start,
      end: end,
      excludePartyId: excludePartyId,
    );
    return overlapping.isNotEmpty;
  }

  static bool _rangesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  static DateTime? _readDate(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
