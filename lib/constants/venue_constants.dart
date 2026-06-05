/// Firestore-Collections und Konstanten für globale Venues / Floors.
class VenueConstants {
  VenueConstants._();

  static const String venuesCollection = 'venues';
  static const String bookmarksSubcollection = 'venue_bookmarks';
  static const String floorSwapRequestsCollection = 'floor_swap_requests';

  /// `floor_key` für „Keine getrennten Floors“ / Hauptbereich.
  static const String defaultFloorKey = 'default';

  /// Haversine-Toleranz für Venue-Deduplizierung (Meter).
  static const double coordinateMatchRadiusMeters = 50.0;

  static const int maxFloorsPerVenue = 50;

  static const List<String> activePartyLifecycleStatuses = [
    'active',
    'standby',
    'upcoming',
  ];
}
