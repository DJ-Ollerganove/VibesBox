import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/wish_paths.dart';

/// Vorab-Wunsch-Limit pro Gast: [pre_wish_limit_per_guest] auf dem Party-Dokument.
/// **0 = unbegrenzt**, **1–50** = maximale Anzahl Vorab-Wünsche bis Partystart.
/// Unabhängig von [guest_limit_per_hour] / [user_limit_per_hour].
class PreWishLimitService {
  PreWishLimitService._();

  static const int minLimited = 1;
  static const int maxLimited = 50;
  static const int defaultLimited = 5;

  /// 0 = unbegrenzt; sonst 1–50.
  static int parseLimitFromParty(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final raw = data['pre_wish_limit_per_guest'];
    if (raw == null) return 0;
    if (raw is int) return raw.clamp(0, maxLimited);
    if (raw is num) return raw.toInt().clamp(0, maxLimited);
    return 0;
  }

  static bool isUnlimited(int limitPerGuest) => limitPerGuest <= 0;

  static int clampForSave(int value, {required bool allowPreWishes}) {
    if (!allowPreWishes) return 0;
    if (value <= 0) return 0;
    return value.clamp(minLimited, maxLimited);
  }

  /// Zählt Vorab-Wünsche des Gastes (keine Dubletten-Zeilen).
  static Future<({int limit, int count, int remaining, bool allowed})> loadGuestStats({
    required String partyId,
    required String clientId,
    String? userId,
  }) async {
    if (partyId.isEmpty || partyId == 'manual') {
      return (limit: 0, count: 0, remaining: 0, allowed: true);
    }
    try {
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();
      if (!partyDoc.exists) {
        return (limit: 0, count: 0, remaining: 0, allowed: true);
      }
      final limit = parseLimitFromParty(partyDoc.data());
      if (isUnlimited(limit)) {
        return (limit: 0, count: 0, remaining: 0, allowed: true);
      }

      QuerySnapshot<Map<String, dynamic>> snap;
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        snap = await WishPaths.partyWishes(partyId)
            .where('user_id', isEqualTo: uid)
            .get();
      } else {
        if (clientId.isEmpty) {
          return (limit: limit, count: 0, remaining: limit, allowed: true);
        }
        snap = await WishPaths.partyWishes(partyId)
            .where('client_id', isEqualTo: clientId)
            .get();
      }

      var count = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['is_pre_wish'] != true) continue;
        if (d['is_duplicate'] == true) continue;
        count++;
      }
      final remaining = (limit - count).clamp(0, limit);
      return (
        limit: limit,
        count: count,
        remaining: remaining,
        allowed: remaining > 0,
      );
    } catch (_) {
      return (limit: 0, count: 0, remaining: 0, allowed: true);
    }
  }
}
