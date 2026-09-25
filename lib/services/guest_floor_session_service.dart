import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/venue_constants.dart';
import '../models/guest_floor_option.dart';
import '../utils/floor_key_utils.dart';
import '../utils/party_code_utils.dart';
import '../utils/venue_party_fields.dart';
import 'public_dj_profile_service.dart';

/// Gast-Floor-Auswahl und Weiterleitung bei beendeter Party (PWA + App Phase 4).
class GuestFloorSessionService {
  GuestFloorSessionService._({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final GuestFloorSessionService instance =
      GuestFloorSessionService._();

  final FirebaseFirestore _firestore;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      queryPartiesByJoinCode(
    String joinCode, {
    int limit = 25,
  }) async {
    return _queryPartiesByJoinCode(joinCode, limit: limit);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _queryPartiesByJoinCode(
    String joinCode, {
    int limit = 25,
  }) async {
    final normalized = PartyCodeUtils.normalizeDigits(joinCode);
    if (normalized.length != PartyCodeUtils.codeLength) return [];

    final col = _firestore.collection('parties');
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final seen = <String>{};

    void addDocs(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) results.add(doc);
      }
    }

    for (final value in [normalized, int.tryParse(normalized)]) {
      if (value == null) continue;
      addDocs(
        await col.where('party_code', isEqualTo: value).limit(limit).get(),
      );
      addDocs(
        await col
            .where('fixed_party_code', isEqualTo: value)
            .limit(limit)
            .get(),
      );
    }

    return results;
  }

  bool _isPartyEnded(Map<String, dynamic> data, DateTime now) {
    final lifecycle = data['lifecycle_status'] as String?;
    if (lifecycle == 'finished' || data['finished_at'] != null) return true;
    final status = data['status'] as String?;
    if (status == 'beendet' || status == 'ended') return true;

    final endTs = data['end_date'] as Timestamp?;
    final endPosix = data['end_time_posix'];
    DateTime? endDate;
    if (endTs != null) {
      endDate = endTs.toDate();
    } else if (endPosix is int) {
      endDate = DateTime.fromMillisecondsSinceEpoch(endPosix * 1000);
    }
    return endDate != null && now.isAfter(endDate);
  }

  bool isPartyGuestJoinable(Map<String, dynamic> data, DateTime now) {
    if (_isPartyEnded(data, now)) return false;

    final lifecycle = data['lifecycle_status'] as String?;
    if (lifecycle == 'standby') return false;

    DateTime? startDate;
    final startTs = data['start_date'] as Timestamp?;
    final startPosix = data['start_time_posix'];
    if (startTs != null) {
      startDate = startTs.toDate();
    } else if (startPosix is int) {
      startDate = DateTime.fromMillisecondsSinceEpoch(startPosix * 1000);
    }

    DateTime? endDate;
    final endTs = data['end_date'] as Timestamp?;
    final endPosix = data['end_time_posix'];
    if (endTs != null) {
      endDate = endTs.toDate();
    } else if (endPosix is int) {
      endDate = DateTime.fromMillisecondsSinceEpoch(endPosix * 1000);
    }

    if (startDate != null && endDate != null) {
      return !now.isBefore(startDate) && now.isBefore(endDate);
    }
    if (startDate != null && endDate == null) {
      return !now.isBefore(startDate);
    }
    if (endDate != null) {
      return now.isBefore(endDate);
    }
    return lifecycle == 'active' || lifecycle == null;
  }

  String _floorLabelFromParty(Map<String, dynamic> data) {
    final explicit = (data['floor_label'] as String?)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final key = VenuePartyFields.effectiveFloorKeyFromParty(data);
    if (FloorKeyUtils.isDefaultFloorKey(key)) {
      return VenueConstants.defaultFloorKey;
    }
    return key;
  }

  Future<String> _djDisplayName(Map<String, dynamic> data) async {
    final djIdRaw = data['created_by'] ?? data['dj_code'];
    final djId = djIdRaw?.toString().trim();
    if (djId == null || djId.isEmpty) return 'DJ';
    try {
      final profile = await PublicDjProfileService().fetchByUid(djId);
      final name = profile?.displayName?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return 'DJ';
  }

  /// Aktive Floor-Optionen für einen Join-Code (mehrere Partys am Ort).
  Future<List<GuestFloorOption>> listJoinableFloorOptions(
    String joinCode, {
    String? excludePartyId,
  }) async {
    final docs = await _queryPartiesByJoinCode(joinCode);
    final now = DateTime.now();
    final options = <GuestFloorOption>[];

    for (final doc in docs) {
      if (excludePartyId != null && doc.id == excludePartyId) continue;
      final data = doc.data();
      if (!isPartyGuestJoinable(data, now)) continue;
      if (!VenuePartyFields.isPublicVenueParty(data)) continue;

      final djName = await _djDisplayName(data);
      final floorKey = VenuePartyFields.effectiveFloorKeyFromParty(data);
      options.add(
        GuestFloorOption(
          partyId: doc.id,
          floorKey: floorKey,
          floorLabel: _floorLabelFromParty(data),
          djName: djName,
          partyName: (data['party_name'] as String?)?.trim(),
        ),
      );
    }

    options.sort((a, b) => a.floorLabel.compareTo(b.floorLabel));
    return options;
  }

  Future<bool> hasMultipleJoinableFloors(
    String joinCode, {
    String? currentPartyId,
  }) async {
    if (currentPartyId != null) {
      final docs = await _queryPartiesByJoinCode(joinCode);
      QueryDocumentSnapshot<Map<String, dynamic>>? current;
      for (final doc in docs) {
        if (doc.id == currentPartyId) {
          current = doc;
          break;
        }
      }
      if (current == null ||
          !VenuePartyFields.isPublicVenueParty(current.data())) {
        return false;
      }
    }

    final options = await listJoinableFloorOptions(
      joinCode,
      excludePartyId: null,
    );
    final distinctKeys = options.map((o) => o.floorKey).toSet();
    if (distinctKeys.length <= 1) return false;

    if (currentPartyId == null) return distinctKeys.length > 1;

    final currentKey = options
        .where((o) => o.partyId == currentPartyId)
        .map((o) => o.floorKey)
        .firstOrNull;
    if (currentKey == null) return distinctKeys.length > 1;

    return options.any(
      (o) => o.partyId != currentPartyId && o.floorKey != currentKey,
    );
  }

  /// Wenn die aktuelle Party endet, aber andere Floors noch aktiv sind.
  Future<GuestFloorRedirectState?> redirectAfterPartyEnded({
    required String endedPartyId,
    required String joinCode,
    required Map<String, dynamic> endedPartyData,
  }) async {
    if (!VenuePartyFields.isPublicVenueParty(endedPartyData)) return null;

    final endedFloorLabel = _floorLabelFromParty(endedPartyData);
    final options = await listJoinableFloorOptions(
      joinCode,
      excludePartyId: endedPartyId,
    );
    if (options.isEmpty) return null;

    final endedKey = VenuePartyFields.effectiveFloorKeyFromParty(endedPartyData);
    final otherFloors =
        options.where((o) => o.floorKey != endedKey).toList();
    if (otherFloors.isEmpty) return null;

    return GuestFloorRedirectState(
      joinCode: PartyCodeUtils.normalizeDigits(joinCode),
      endedFloorLabel: endedFloorLabel,
      options: otherFloors,
    );
  }

  /// Floor-Picker nur bei mehreren verschiedenen Floors (öffentliche Venue).
  Future<bool> shouldOfferFloorSelection(String joinCode) async {
    final docs = await _queryPartiesByJoinCode(joinCode);
    final now = DateTime.now();
    final joinableData = docs
        .where((d) => isPartyGuestJoinable(d.data(), now))
        .map((d) => d.data())
        .toList();
    return VenuePartyFields.hasMultipleDistinctPublicFloors(joinableData);
  }

  /// Anzeige-Label für Floor (l10n-Schlüssel-Auflösung in UI).
  static bool isDefaultFloorLabelToken(String label) =>
      label == VenueConstants.defaultFloorKey;

  /// Bei mehreren Treffern ohne Multi-Floor (privat/Legacy): bestes Dokument wählen.
  static QueryDocumentSnapshot<Map<String, dynamic>>? pickBestPartyDoc(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    DateTime? now,
  }) {
    if (docs.isEmpty) return null;
    if (docs.length == 1) return docs.first;

    final nowDate = now ?? DateTime.now();

    String tierFor(Map<String, dynamic> data) {
      final service = GuestFloorSessionService._();
      if (service._isPartyEnded(data, nowDate)) return 'past';

      DateTime? startDate;
      final startTs = data['start_date'] as Timestamp?;
      final startPosix = data['start_time_posix'];
      if (startTs != null) {
        startDate = startTs.toDate();
      } else if (startPosix is int) {
        startDate = DateTime.fromMillisecondsSinceEpoch(startPosix * 1000);
      }

      DateTime? endDate;
      final endTs = data['end_date'] as Timestamp?;
      final endPosix = data['end_time_posix'];
      if (endTs != null) {
        endDate = endTs.toDate();
      } else if (endPosix is int) {
        endDate = DateTime.fromMillisecondsSinceEpoch(endPosix * 1000);
      }

      if (startDate != null && endDate != null) {
        if (!nowDate.isBefore(startDate) && nowDate.isBefore(endDate)) {
          return 'running';
        }
        if (nowDate.isBefore(startDate)) return 'future';
        return 'past';
      }
      if (startDate != null && endDate == null) {
        if (nowDate.isBefore(startDate)) return 'future';
        if (!service._isPartyEnded(data, nowDate)) return 'running';
        return 'past';
      }
      if (endDate != null) {
        if (!service._isPartyEnded(data, nowDate) && nowDate.isBefore(endDate)) {
          return 'running';
        }
        return 'past';
      }
      return 'unknown';
    }

    int startMs(Map<String, dynamic> data) {
      final startTs = data['start_date'] as Timestamp?;
      final startPosix = data['start_time_posix'];
      if (startTs != null) return startTs.millisecondsSinceEpoch;
      if (startPosix is int) return startPosix * 1000;
      return 0;
    }

    int endMs(Map<String, dynamic> data) {
      final endTs = data['end_date'] as Timestamp?;
      final endPosix = data['end_time_posix'];
      if (endTs != null) return endTs.millisecondsSinceEpoch;
      if (endPosix is int) return endPosix * 1000;
      return 0;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? pickTier(String tier) {
      final matches = docs.where((d) => tierFor(d.data()) == tier).toList();
      if (matches.isEmpty) return null;
      matches.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        if (tier == 'past') {
          return endMs(bData).compareTo(endMs(aData));
        }
        return startMs(aData).compareTo(startMs(bData));
      });
      return matches.first;
    }

    return pickTier('running') ??
        pickTier('future') ??
        pickTier('unknown') ??
        pickTier('past');
  }
}
