/// Location-Name und -Adresse getrennt für QR/PDF-Export aus Party-Daten.
class PartyLocationExportParts {
  const PartyLocationExportParts({
    this.displayName,
    this.displayAddress,
    this.mapsUrl,
  });

  final String? displayName;
  final String? displayAddress;
  final String? mapsUrl;

  bool get hasName => displayName != null && displayName!.trim().isNotEmpty;
  bool get hasAddress =>
      displayAddress != null && displayAddress!.trim().isNotEmpty;
  bool get hasAny => hasName || hasAddress;
}

abstract final class PartyLocationExportHelper {
  /// POI-Name (z. B. Club), nicht identisch mit Adresse/Straße/Ort.
  static bool isExplicitLocationName(
    String? name, {
    String? street,
    String? city,
    String? address,
  }) {
    if (name == null || name.trim().isEmpty) return false;
    final n = name.trim().toLowerCase();
    final a = (address ?? '').trim().toLowerCase();
    final s = (street ?? '').trim().toLowerCase();
    final c = (city ?? '').trim().toLowerCase();
    if (a.isNotEmpty && n == a) return false;
    if (s.isNotEmpty && n == s) return false;
    if (c.isNotEmpty && n == c) return false;
    return true;
  }

  static bool _isExplicitLocationName(
    String? name,
    String? street,
    String? city,
  ) =>
      isExplicitLocationName(name, street: street, city: city);

  /// [mapOnlyLabel]: z. B. l10n „Auf der Karte“ wenn nur Koordinaten, keine Textadresse.
  static PartyLocationExportParts fromPartyData(
    Map<String, dynamic> data, {
    String? mapOnlyLabel,
  }) {
    final locName = (data['location_name'] as String?)?.trim();
    final street = (data['location_street'] as String?)?.trim();
    final zip = (data['location_zip'] as String?)?.trim();
    final city = (data['location_city'] as String?)?.trim();
    final rawAddress = (data['location_address'] as String?)?.trim();
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();

    final zipCityPart = [
      if (zip != null && zip.isNotEmpty) zip,
      if (city != null && city.isNotEmpty) city,
    ].join(' ').trim();

    var addressPart = [
      if (street != null && street.isNotEmpty) street,
      if (zipCityPart.isNotEmpty) zipCityPart,
    ].join(', ').trim();

    if (addressPart.isEmpty &&
        rawAddress != null &&
        rawAddress.isNotEmpty) {
      addressPart = rawAddress;
    }

    final explicitName = _isExplicitLocationName(locName, street, city);
    String? displayName;
    if (explicitName) {
      displayName = locName;
    } else if (addressPart.isEmpty &&
        locName != null &&
        locName.isNotEmpty) {
      displayName = locName;
    }

    String? displayAddress = addressPart.isNotEmpty ? addressPart : null;
    if (displayAddress == null &&
        mapOnlyLabel != null &&
        mapOnlyLabel.trim().isNotEmpty &&
        latitude != null &&
        longitude != null) {
      displayAddress = mapOnlyLabel.trim();
    }

    final mapsUrl = (latitude != null && longitude != null)
        ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
        : null;

    return PartyLocationExportParts(
      displayName: displayName,
      displayAddress: displayAddress,
      mapsUrl: mapsUrl,
    );
  }
}
