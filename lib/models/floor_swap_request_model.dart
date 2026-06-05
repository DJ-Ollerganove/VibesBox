import 'package:cloud_firestore/cloud_firestore.dart';

/// Anfrage zum Tausch belegter Floors zwischen zwei Partys (Phase 2+ UI).
class FloorSwapRequestModel {
  final String id;
  final String venueId;
  final String fromPartyId;
  final String toPartyId;
  final String fromDjId;
  final String toDjId;
  final String fromFloorKey;
  final String toFloorKey;
  final String status;
  final Timestamp createdAt;
  final Timestamp? respondedAt;
  final Timestamp? expiresAt;

  const FloorSwapRequestModel({
    required this.id,
    required this.venueId,
    required this.fromPartyId,
    required this.toPartyId,
    required this.fromDjId,
    required this.toDjId,
    required this.fromFloorKey,
    required this.toFloorKey,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.expiresAt,
  });

  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusRejected = 'rejected';
  static const String statusCancelled = 'cancelled';
  static const String statusExpired = 'expired';

  factory FloorSwapRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FloorSwapRequestModel(
      id: doc.id,
      venueId: data['venue_id'] as String? ?? '',
      fromPartyId: data['from_party_id'] as String? ?? '',
      toPartyId: data['to_party_id'] as String? ?? '',
      fromDjId: data['from_dj_id'] as String? ?? '',
      toDjId: data['to_dj_id'] as String? ?? '',
      fromFloorKey: data['from_floor_key'] as String? ?? '',
      toFloorKey: data['to_floor_key'] as String? ?? '',
      status: data['status'] as String? ?? statusPending,
      createdAt: data['created_at'] as Timestamp? ?? Timestamp.now(),
      respondedAt: data['responded_at'] as Timestamp?,
      expiresAt: data['expires_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'venue_id': venueId,
      'from_party_id': fromPartyId,
      'to_party_id': toPartyId,
      'from_dj_id': fromDjId,
      'to_dj_id': toDjId,
      'from_floor_key': fromFloorKey,
      'to_floor_key': toFloorKey,
      'status': status,
      'created_at': createdAt,
      if (respondedAt != null) 'responded_at': respondedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    };
  }
}
