import '../constants/venue_constants.dart';

/// Slug für `floor_key` aus Anzeigenamen (z. B. „1. OG“ → `1_og`).
class FloorKeyUtils {
  FloorKeyUtils._();

  static String normalizeLabel(String label) => label.trim();

  static String slugFromLabel(String label) {
    final trimmed = normalizeLabel(label);
    if (trimmed.isEmpty) {
      return VenueConstants.defaultFloorKey;
    }

    var slug = trimmed.toLowerCase();
    slug = slug.replaceAll(RegExp(r'[äÄ]'), 'ae');
    slug = slug.replaceAll(RegExp(r'[öÖ]'), 'oe');
    slug = slug.replaceAll(RegExp(r'[üÜ]'), 'ue');
    slug = slug.replaceAll('ß', 'ss');
    slug = slug.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    slug = slug.replaceAll(RegExp(r'_+'), '_');
    slug = slug.replaceAll(RegExp(r'^_|_$'), '');

    if (slug.isEmpty) {
      return VenueConstants.defaultFloorKey;
    }
    if (slug == VenueConstants.defaultFloorKey) {
      return '${slug}_floor';
    }
    return slug.length > 80 ? slug.substring(0, 80) : slug;
  }

  static String? normalizeFloorKey(String? floorKey) {
    if (floorKey == null) return null;
    final trimmed = floorKey.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  static bool isDefaultFloorKey(String? floorKey) {
    final normalized = normalizeFloorKey(floorKey);
    return normalized == null || normalized == VenueConstants.defaultFloorKey;
  }

  static String effectiveFloorKey(String? floorKey) {
    return normalizeFloorKey(floorKey) ?? VenueConstants.defaultFloorKey;
  }
}
