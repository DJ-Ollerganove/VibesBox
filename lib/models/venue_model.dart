import 'package:cloud_firestore/cloud_firestore.dart';

import 'venue_floor.dart';

/// Globale Venue (DJ-übergreifend): Koordinaten, Festcode, Floors.
class VenueModel {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String timezoneId;
  final String? fixedPartyCode;
  final String? placeId;
  final List<VenueFloor> floors;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const VenueModel({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.timezoneId,
    this.fixedPartyCode,
    this.placeId,
    this.floors = const [],
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory VenueModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawFloors = data['floors'];
    final floors = <VenueFloor>[];
    if (rawFloors is List) {
      for (final entry in rawFloors) {
        if (entry is Map<String, dynamic>) {
          floors.add(VenueFloor.fromMap(entry));
        }
      }
    }

    return VenueModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      timezoneId: data['timezone_id'] as String? ?? 'UTC',
      fixedPartyCode: data['fixed_party_code'] as String?,
      placeId: data['place_id'] as String?,
      floors: floors,
      createdBy: data['created_by'] as String? ?? '',
      createdAt: data['created_at'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updated_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore({bool includeTimestamps = true}) {
    return {
      'name': name,
      if (address != null && address!.isNotEmpty) 'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'timezone_id': timezoneId,
      if (fixedPartyCode != null && fixedPartyCode!.isNotEmpty)
        'fixed_party_code': fixedPartyCode,
      if (placeId != null && placeId!.isNotEmpty) 'place_id': placeId,
      'floors': floors.map((f) => f.toMap()).toList(),
      'created_by': createdBy,
      if (includeTimestamps) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  VenueFloor? floorByKey(String floorKey) {
    for (final floor in floors) {
      if (floor.key == floorKey) return floor;
    }
    return null;
  }

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
      updatedAt: updatedAt,
    );
  }
}
