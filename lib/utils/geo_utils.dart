import 'dart:math' as math;

/// Geografische Hilfsfunktionen (Haversine, Bounding-Box).
class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusMeters = 6371000;

  /// Entfernung zwischen zwei Koordinaten in Metern (Haversine).
  static double distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static bool withinRadiusMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
    required double radiusMeters,
  }) {
    return distanceMeters(
          lat1: lat1,
          lng1: lng1,
          lat2: lat2,
          lng2: lng2,
        ) <=
        radiusMeters;
  }

  /// Grobe Grad-Delta für Firestore-Latitude-Range-Query (~Meter).
  static double approxLatitudeDeltaDegrees(double radiusMeters) {
    return radiusMeters / 111320.0;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
