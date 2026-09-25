import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';

/// Persistenter Zähler `users/{uid}.guestWishesSubmittedCount` für eingeloggte Gäste.
/// +1 beim Absenden (App), −1 beim Löschen (Cloud Function, auch DJ-Löschung).
class GuestWishStatsService {
  GuestWishStatsService._();
  static final GuestWishStatsService instance = GuestWishStatsService._();

  static const String fieldName = 'guestWishesSubmittedCount';

  static final Set<String> _backfillAttemptedUids = <String>{};

  /// Nach erfolgreichem Wunsch-Absenden (nur eingeloggter Gast).
  Future<void> onWishSubmitted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {fieldName: FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugLog('GuestWishStatsService.onWishSubmitted: $e');
    }
  }

  /// Liest den Zähler aus dem User-Dokument (ohne Backfill).
  static int countFromUserData(Map<String, dynamic>? data) {
    if (data == null || !data.containsKey(fieldName)) return 0;
    final v = data[fieldName];
    if (v is int) return v < 0 ? 0 : v;
    if (v is num) {
      final n = v.toInt();
      return n < 0 ? 0 : n;
    }
    return 0;
  }

  /// Einmalige Migration: Feld fehlt → aus `user_id`-Wünschen zählen und speichern.
  Future<int> ensureBackfilled(String uid) async {
    if (uid.trim().isEmpty) return 0;
    if (_backfillAttemptedUids.contains(uid)) {
      return readCount(uid);
    }
    _backfillAttemptedUids.add(uid);

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      final userSnap = await userRef.get();
      if (!userSnap.exists) return 0;
      final data = userSnap.data();
      if (data != null && data.containsKey(fieldName)) {
        return countFromUserData(data);
      }

      final wishesSnap = await WishPaths.allWishesCollectionGroup()
          .where('user_id', isEqualTo: uid)
          .get();
      final count = wishesSnap.docs.length;
      if (count > 0) {
        await userRef.set({fieldName: count}, SetOptions(merge: true));
      }
      return count;
    } catch (e) {
      debugLog('GuestWishStatsService.ensureBackfilled: $e');
      return 0;
    }
  }

  Future<int> readCount(String uid) async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return countFromUserData(snap.data());
    } catch (_) {
      return 0;
    }
  }
}
