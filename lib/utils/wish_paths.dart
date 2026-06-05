import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-Pfade für Wünsche unter `parties/{partyId}/wishes/{wishId}`.
class WishPaths {
  WishPaths._();

  static CollectionReference<Map<String, dynamic>> partyWishes(String partyId) {
    return FirebaseFirestore.instance
        .collection('parties')
        .doc(partyId)
        .collection('wishes');
  }

  static DocumentReference<Map<String, dynamic>> partyWish(
    String partyId,
    String wishId,
  ) {
    return partyWishes(partyId).doc(wishId);
  }

  /// Admin / gesamtübergreifend (alle Party-Subcollections namens `wishes`).
  static Query<Map<String, dynamic>> allWishesCollectionGroup() {
    return FirebaseFirestore.instance.collectionGroup('wishes');
  }
}
