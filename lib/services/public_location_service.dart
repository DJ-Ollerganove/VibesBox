import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/venue_constants.dart';
import '../models/location_model.dart';
import '../utils/debug_log.dart';
import '../utils/geo_utils.dart';

/// Öffentliche Locations (`is_public`) — DJ-übergreifend auffindbar.
class PublicLocationService {
  PublicLocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('locations');

  /// Sucht eine öffentliche Location in Koordinaten-Nähe (Festcode-Ort).
  Future<LocationModel?> findMatchingPublicLocation({
    required double latitude,
    required double longitude,
    double radiusMeters = VenueConstants.coordinateMatchRadiusMeters,
  }) async {
    final latDelta = GeoUtils.approxLatitudeDeltaDegrees(radiusMeters);
    final minLat = latitude - latDelta;
    final maxLat = latitude + latDelta;

    try {
      final snap = await _col
          .where('is_public', isEqualTo: true)
          .where('latitude', isGreaterThanOrEqualTo: minLat)
          .where('latitude', isLessThanOrEqualTo: maxLat)
          .limit(25)
          .get();

      LocationModel? closest;
      var closestDistance = double.infinity;

      for (final doc in snap.docs) {
        final model = LocationModel.fromFirestore(doc);
        final lat = model.latitude;
        final lng = model.longitude;
        if (lat == null || lng == null) continue;
        if (model.fixedPartyCode == null || model.fixedPartyCode!.isEmpty) {
          continue;
        }

        final distance = GeoUtils.distanceMeters(
          lat1: latitude,
          lng1: longitude,
          lat2: lat,
          lng2: lng,
        );
        if (distance <= radiusMeters && distance < closestDistance) {
          closest = model;
          closestDistance = distance;
        }
      }

      if (closest != null) {
        debugLog(
          '✅ Öffentliche Location gefunden: ${closest.locationName} '
          '(Code ${closest.fixedPartyCode})',
        );
      }
      return closest;
    } catch (e) {
      debugLog('⚠️ Öffentliche Location-Suche: $e');
      return null;
    }
  }

  /// Lädt eigene + alle öffentlichen Locations für die Auswahl-Liste.
  Future<List<LocationModel>> loadSelectableLocations(String djId) async {
    if (djId.isEmpty) return [];

    final results = <String, LocationModel>{};

    try {
      final ownSnap = await _col
          .where('created_by', isEqualTo: djId)
          .limit(100)
          .get();
      for (final doc in ownSnap.docs) {
        results[doc.id] = LocationModel.fromFirestore(doc);
      }
    } catch (e) {
      debugLog('⚠️ Eigene Locations laden: $e');
    }

    try {
      final publicSnap =
          await _col.where('is_public', isEqualTo: true).limit(100).get();
      for (final doc in publicSnap.docs) {
        final model = LocationModel.fromFirestore(doc);
        if (model.fixedPartyCode == null || model.fixedPartyCode!.isEmpty) {
          continue;
        }
        results.putIfAbsent(doc.id, () => model);
      }
    } catch (e) {
      debugLog('⚠️ Öffentliche Locations laden: $e');
    }

    final list = results.values.toList()
      ..sort(
        (a, b) => a.locationName.toLowerCase().compareTo(
              b.locationName.toLowerCase(),
            ),
      );
    return list;
  }
}
