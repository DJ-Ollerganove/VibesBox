import 'package:cloud_firestore/cloud_firestore.dart';

/// Persönlicher Ort in `users/{djId}/venue_bookmarks` (öffentlich + privat).
class VenueBookmarkModel {
  final String id;
  final String? venueId;
  final String locationName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String timezoneId;
  final String source;
  final String? label;
  final Timestamp lastUsedAt;
  final Timestamp createdAt;

  const VenueBookmarkModel({
    required this.id,
    this.venueId,
    required this.locationName,
    this.address,
    this.latitude,
    this.longitude,
    required this.timezoneId,
    required this.source,
    this.label,
    required this.lastUsedAt,
    required this.createdAt,
  });

  static const String sourcePublic = 'public';
  static const String sourcePrivate = 'private';

  String get displayName =>
      (label != null && label!.trim().isNotEmpty) ? label!.trim() : locationName;

  factory VenueBookmarkModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VenueBookmarkModel(
      id: doc.id,
      venueId: data['venue_id'] as String?,
      locationName: data['location_name'] as String? ?? '',
      address: data['address'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      timezoneId: data['timezone_id'] as String? ?? 'UTC',
      source: data['source'] as String? ?? sourcePrivate,
      label: data['label'] as String?,
      lastUsedAt: data['last_used_at'] as Timestamp? ?? Timestamp.now(),
      createdAt: data['created_at'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (venueId != null && venueId!.isNotEmpty) 'venue_id': venueId,
      'location_name': locationName,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'timezone_id': timezoneId,
      'source': source,
      if (label != null && label!.isNotEmpty) 'label': label,
      'last_used_at': lastUsedAt,
      'created_at': createdAt,
    };
  }
}
