/// Datenmodell für Google Places API Ergebnisse
class LocationResult {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? timezoneId; // Wird später mit Time Zone API gefüllt
  /// PLZ aus address_components (postal_code)
  final String? postalCode;
  /// Ort aus address_components (locality)
  final String? city;
  /// Straße + Hausnummer aus address_components (route + street_number)
  final String? street;

  LocationResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.timezoneId,
    this.postalCode,
    this.city,
    this.street,
  });

  @override
  String toString() {
    return 'LocationResult(placeId: $placeId, name: $name, address: $address, lat: $latitude, lng: $longitude, timezone: $timezoneId, postalCode: $postalCode, city: $city, street: $street)';
  }
}

/// Datenmodell für Autocomplete-Vorschläge
class PlacePrediction {
  final String placeId;
  final String description; // Name + Adresse kombiniert
  final String mainText; // Haupttext (Name)
  final String? secondaryText; // Sekundärtext (Adresse)

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
  });
}
