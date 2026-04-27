import 'package:cloud_firestore/cloud_firestore.dart';

/// Datenmodell für Location-Dokumente in der Firestore locations-Collection
class LocationModel {
  final String id;
  final String locationName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String timezoneId; // Pflichtfeld für Unix-Berechnung
  final String? fixedPartyCode; // Optional: 900.000-999.999
  final String createdBy; // DJ-ID
  final Timestamp createdAt;

  LocationModel({
    required this.id,
    required this.locationName,
    this.address,
    this.latitude,
    this.longitude,
    required this.timezoneId,
    this.fixedPartyCode,
    required this.createdBy,
    required this.createdAt,
  });

  /// Erstellt LocationModel aus Firestore-Dokument
  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationModel(
      id: doc.id,
      locationName: data['location_name'] as String? ?? '',
      address: data['address'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      timezoneId: data['timezone_id'] as String? ?? 'UTC', // Fallback auf UTC
      fixedPartyCode: data['fixed_party_code'] as String?,
      createdBy: data['created_by'] as String? ?? '',
      createdAt: data['created_at'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Konvertiert LocationModel zu Firestore-Daten
  Map<String, dynamic> toFirestore() {
    return {
      'location_name': locationName,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'timezone_id': timezoneId, // Pflichtfeld
      if (fixedPartyCode != null) 'fixed_party_code': fixedPartyCode,
      'created_by': createdBy,
      'created_at': createdAt,
    };
  }
}
