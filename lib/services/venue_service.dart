import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/venue_constants.dart';
import '../models/venue_floor.dart';
import '../models/venue_model.dart';
import '../utils/debug_log.dart';
import '../utils/floor_key_utils.dart';
import '../utils/geo_utils.dart';
import 'party_service.dart';

/// CRUD und Koordinaten-Match für globale `venues`.
class VenueService {
  VenueService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _venues =>
      _firestore.collection(VenueConstants.venuesCollection);

  Future<VenueModel?> getVenueById(String venueId) async {
    if (venueId.trim().isEmpty) return null;
    final doc = await _venues.doc(venueId).get();
    if (!doc.exists) return null;
    return VenueModel.fromFirestore(doc);
  }

  Future<VenueModel?> getVenueByFixedPartyCode(String fixedPartyCode) async {
    final code = fixedPartyCode.trim();
    if (code.isEmpty) return null;

    final snap = await _venues
        .where('fixed_party_code', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return VenueModel.fromFirestore(snap.docs.first);
  }

  /// Findet eine Venue innerhalb von [radiusMeters] (Standard 50 m).
  Future<VenueModel?> findVenueNearCoordinates({
    required double latitude,
    required double longitude,
    double radiusMeters = VenueConstants.coordinateMatchRadiusMeters,
  }) async {
    final latDelta = GeoUtils.approxLatitudeDeltaDegrees(radiusMeters);
    final minLat = latitude - latDelta;
    final maxLat = latitude + latDelta;

    final snap = await _venues
        .where('latitude', isGreaterThanOrEqualTo: minLat)
        .where('latitude', isLessThanOrEqualTo: maxLat)
        .get();

    VenueModel? closest;
    var closestDistance = double.infinity;

    for (final doc in snap.docs) {
      final venue = VenueModel.fromFirestore(doc);
      final distance = GeoUtils.distanceMeters(
        lat1: latitude,
        lng1: longitude,
        lat2: venue.latitude,
        lng2: venue.longitude,
      );
      if (distance <= radiusMeters && distance < closestDistance) {
        closest = venue;
        closestDistance = distance;
      }
    }

    return closest;
  }

  /// Match per `place_id` (falls vorhanden), sonst Koordinaten-Radius.
  Future<VenueModel?> findMatchingVenue({
    required double latitude,
    required double longitude,
    String? placeId,
    double radiusMeters = VenueConstants.coordinateMatchRadiusMeters,
  }) async {
    final normalizedPlaceId = placeId?.trim();
    if (normalizedPlaceId != null && normalizedPlaceId.isNotEmpty) {
      final byPlace = await _venues
          .where('place_id', isEqualTo: normalizedPlaceId)
          .limit(1)
          .get();
      if (byPlace.docs.isNotEmpty) {
        return VenueModel.fromFirestore(byPlace.docs.first);
      }
    }

    return findVenueNearCoordinates(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  /// Erstellt eine neue globale Venue inkl. Festcode (99er-Bereich).
  Future<VenueModel> createVenue({
    required String name,
    String? address,
    required double latitude,
    required double longitude,
    required String timezoneId,
    required String createdBy,
    String? placeId,
    String? fixedPartyCode,
  }) async {
    if (timezoneId.trim().isEmpty) {
      throw ArgumentError('timezone_id ist Pflicht');
    }

    final code = fixedPartyCode?.trim().isNotEmpty == true
        ? fixedPartyCode!.trim()
        : await PartyService.generatePartyCode(
            isFixedCode: true,
            createdBy: createdBy,
          );

    final now = Timestamp.now();
    final data = {
      'name': name.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'timezone_id': timezoneId.trim(),
      'fixed_party_code': code,
      if (placeId != null && placeId.trim().isNotEmpty) 'place_id': placeId.trim(),
      'floors': <Map<String, dynamic>>[],
      'created_by': createdBy,
      'created_at': now,
      'updated_at': now,
    };

    final ref = await _venues.add(data);
    debugLog('✅ Venue erstellt: ${ref.id} (Code $code)');
    final doc = await ref.get();
    return VenueModel.fromFirestore(doc);
  }

  /// Match oder neue Venue — für öffentliche Partys (Phase 2 Wizard).
  Future<VenueModel> resolveOrCreateVenue({
    required String name,
    String? address,
    required double latitude,
    required double longitude,
    required String timezoneId,
    required String createdBy,
    String? placeId,
  }) async {
    final existing = await findMatchingVenue(
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
    );
    if (existing != null) {
      debugLog('✅ Bestehende Venue gefunden: ${existing.id}');
      return existing;
    }

    return createVenue(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      timezoneId: timezoneId,
      createdBy: createdBy,
      placeId: placeId,
    );
  }

  /// Legt einen Floor global an der Venue an (falls key noch nicht existiert).
  Future<VenueModel> addFloor({
    required String venueId,
    required String floorLabel,
    required String createdBy,
  }) async {
    final label = FloorKeyUtils.normalizeLabel(floorLabel);
    if (label.isEmpty) {
      throw ArgumentError('Floor-Name darf nicht leer sein');
    }

    final key = FloorKeyUtils.slugFromLabel(label);
    final docRef = _venues.doc(venueId);

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('Venue nicht gefunden: $venueId');
      }

      final venue = VenueModel.fromFirestore(snap);
      if (venue.floors.length >= VenueConstants.maxFloorsPerVenue) {
        throw StateError('Maximale Anzahl Floors erreicht');
      }

      if (venue.floorByKey(key) != null) {
        return venue;
      }

      final newFloor = VenueFloor(
        key: key,
        label: label,
        createdBy: createdBy,
        createdAt: Timestamp.now(),
      );

      final updatedFloors = [...venue.floors, newFloor];
      tx.update(docRef, {
        'floors': updatedFloors.map((f) => f.toMap()).toList(),
        'updated_at': Timestamp.now(),
      });

      return venue.copyWithFloors(updatedFloors);
    });
  }
}

extension _VenueModelCopy on VenueModel {
  VenueModel copyWithFloors(List<VenueFloor> newFloors) {
    return VenueModel(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      timezoneId: timezoneId,
      fixedPartyCode: fixedPartyCode,
      placeId: placeId,
      floors: newFloors,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: Timestamp.now(),
    );
  }
}
