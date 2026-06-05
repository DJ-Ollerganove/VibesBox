import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/venue_constants.dart';
import '../models/floor_swap_request_model.dart';
import '../utils/debug_log.dart';

/// Floor-Tausch-Anfragen zwischen DJs am selben Ort.
class FloorSwapService {
  FloorSwapService._({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final FloorSwapService instance = FloorSwapService._();

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(VenueConstants.floorSwapRequestsCollection);

  Stream<List<FloorSwapRequestModel>> watchIncomingPending(String djId) {
    if (djId.isEmpty) return Stream.value(const []);
    return _requests
        .where('to_dj_id', isEqualTo: djId)
        .where('status', isEqualTo: FloorSwapRequestModel.statusPending)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(FloorSwapRequestModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<FloorSwapRequestModel>> watchOutgoingPending(String djId) {
    if (djId.isEmpty) return Stream.value(const []);
    return _requests
        .where('from_dj_id', isEqualTo: djId)
        .where('status', isEqualTo: FloorSwapRequestModel.statusPending)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(FloorSwapRequestModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<String?> createSwapRequest({
    required String venueId,
    required String fromPartyId,
    required String toPartyId,
    required String fromDjId,
    required String toDjId,
    required String fromFloorKey,
    required String toFloorKey,
  }) async {
    if (fromPartyId.isEmpty ||
        toPartyId.isEmpty ||
        fromDjId.isEmpty ||
        toDjId.isEmpty ||
        venueId.isEmpty) {
      return null;
    }
    if (fromPartyId == toPartyId || fromDjId == toDjId) return null;

    final existing = await _requests
        .where('from_party_id', isEqualTo: fromPartyId)
        .where('status', isEqualTo: FloorSwapRequestModel.statusPending)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final now = Timestamp.now();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 24)),
    );

    final ref = await _requests.add({
      'venue_id': venueId,
      'from_party_id': fromPartyId,
      'to_party_id': toPartyId,
      'from_dj_id': fromDjId,
      'to_dj_id': toDjId,
      'from_floor_key': fromFloorKey,
      'to_floor_key': toFloorKey,
      'status': FloorSwapRequestModel.statusPending,
      'created_at': now,
      'expires_at': expiresAt,
    });
    debugLog('✅ Floor-Tausch-Anfrage erstellt: ${ref.id}');
    return ref.id;
  }

  Future<void> rejectRequest(String requestId) async {
    await _updateStatus(
      requestId,
      FloorSwapRequestModel.statusRejected,
    );
  }

  Future<void> cancelRequest(String requestId) async {
    await _updateStatus(
      requestId,
      FloorSwapRequestModel.statusCancelled,
    );
  }

  Future<void> acceptRequest(String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _requests.doc(requestId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    if (data['to_dj_id'] != uid) return;
    if (data['status'] != FloorSwapRequestModel.statusPending) return;

    await _requests.doc(requestId).update({
      'status': FloorSwapRequestModel.statusAccepted,
      'responded_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateStatus(String requestId, String status) async {
    await _requests.doc(requestId).update({
      'status': status,
      'responded_at': FieldValue.serverTimestamp(),
    });
  }
}
