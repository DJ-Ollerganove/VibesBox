import 'package:cloud_firestore/cloud_firestore.dart';

/// Ein Floor-Eintrag in `venues.floors[]` (venue-global für alle DJs).
class VenueFloor {
  final String key;
  final String label;
  final String? createdBy;
  final Timestamp? createdAt;

  const VenueFloor({
    required this.key,
    required this.label,
    this.createdBy,
    this.createdAt,
  });

  factory VenueFloor.fromMap(Map<String, dynamic> map) {
    return VenueFloor(
      key: map['key'] as String? ?? '',
      label: map['label'] as String? ?? '',
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  VenueFloor copyWith({
    String? key,
    String? label,
    String? createdBy,
    Timestamp? createdAt,
  }) {
    return VenueFloor(
      key: key ?? this.key,
      label: label ?? this.label,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
