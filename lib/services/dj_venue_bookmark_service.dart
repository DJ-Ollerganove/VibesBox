import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/venue_constants.dart';
import '../models/venue_bookmark_model.dart';
import '../utils/debug_log.dart';

/// Persönliche Ort-Liste `users/{djId}/venue_bookmarks`.
class DjVenueBookmarkService {
  DjVenueBookmarkService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _bookmarks(String djId) {
    return _firestore
        .collection('users')
        .doc(djId)
        .collection(VenueConstants.bookmarksSubcollection);
  }

  Stream<List<VenueBookmarkModel>> watchBookmarks(String djId) {
    return _bookmarks(djId)
        .orderBy('last_used_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => VenueBookmarkModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<List<VenueBookmarkModel>> listBookmarks(String djId) async {
    final snap = await _bookmarks(djId)
        .orderBy('last_used_at', descending: true)
        .get();
    return snap.docs.map(VenueBookmarkModel.fromFirestore).toList();
  }

  /// Speichert oder aktualisiert einen Bookmark (Dedup über venue_id oder Koordinaten+Name).
  Future<String> upsertBookmark({
    required String djId,
    String? venueId,
    required String locationName,
    String? address,
    double? latitude,
    double? longitude,
    required String timezoneId,
    required String source,
    String? label,
  }) async {
    final now = Timestamp.now();
    final normalizedName = locationName.trim();
    final existingId = await _findExistingBookmarkId(
      djId: djId,
      venueId: venueId,
      locationName: normalizedName,
      latitude: latitude,
      longitude: longitude,
    );

    final data = {
      if (venueId?.isNotEmpty ?? false) 'venue_id': venueId,
      'location_name': normalizedName,
      if (address?.trim().isNotEmpty ?? false) 'address': address!.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'timezone_id': timezoneId.trim().isEmpty ? 'UTC' : timezoneId.trim(),
      'source': source,
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'last_used_at': now,
    };

    if (existingId != null) {
      await _bookmarks(djId).doc(existingId).update(data);
      debugLog('✅ Venue-Bookmark aktualisiert: $existingId');
      return existingId;
    }

    final ref = await _bookmarks(djId).add({
      ...data,
      'created_at': now,
    });
    debugLog('✅ Venue-Bookmark erstellt: ${ref.id}');
    return ref.id;
  }

  Future<void> touchBookmark({
    required String djId,
    required String bookmarkId,
  }) async {
    await _bookmarks(djId).doc(bookmarkId).update({
      'last_used_at': Timestamp.now(),
    });
  }

  Future<String?> _findExistingBookmarkId({
    required String djId,
    String? venueId,
    required String locationName,
    double? latitude,
    double? longitude,
  }) async {
    if (venueId != null && venueId.isNotEmpty) {
      final byVenue = await _bookmarks(djId)
          .where('venue_id', isEqualTo: venueId)
          .limit(1)
          .get();
      if (byVenue.docs.isNotEmpty) return byVenue.docs.first.id;
    }

    final snap = await _bookmarks(djId).get();
    final targetName = locationName.trim().toLowerCase();
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['location_name'] as String? ?? '').trim().toLowerCase();
      if (name != targetName) continue;

      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (latitude != null &&
          longitude != null &&
          lat != null &&
          lng != null &&
          (latitude - lat).abs() > 0.0001) {
        continue;
      }
      if (latitude != null &&
          longitude != null &&
          lat != null &&
          lng != null &&
          (longitude - lng).abs() > 0.0001) {
        continue;
      }
      return doc.id;
    }
    return null;
  }
}
