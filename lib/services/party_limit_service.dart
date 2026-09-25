import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/apple_review_test_dj.dart';
import '../models/user_model.dart';
import 'limit_service.dart';

/// Service für die Synchronisation des Party-Status (active vs. standby) bei Free-DJs.
/// Free: Nur die ersten N Partys (nach start_date) im aktuellen 30-Tage-Zyklus bleiben active, Rest → standby.
/// N = 1 normal, [AppleReviewTestDj.freePartiesPerPeriod] für den Review-Test-DJ.
/// Block-Start: [UserModel.freePeriodStart] falls gesetzt, sonst wie [LimitService.effectiveFreeBillingAnchorDate] (1. des Monats von created_at).
/// Pro: Alle standby-Partys werden auf active gesetzt.
class PartyLimitService {
  PartyLimitService._();

  static const int _freePeriodDays = 30;

  /// Start des aktuellen 30-Tage-Blocks, der [now] enthält (ab [periodStart]).
  static DateTime _currentPeriodStart(DateTime periodStart, DateTime now) {
    final diff = now.difference(periodStart).inDays;
    final n = diff < 0 ? 0 : (diff ~/ _freePeriodDays);
    return periodStart.add(Duration(days: n * _freePeriodDays));
  }

  static int _activeSlotsFor(UserModel user) => AppleReviewTestDj.matchesUser(user)
      ? AppleReviewTestDj.freePartiesPerPeriod
      : 1;

  /// Synchronisiert die lifecycle_status aller Partys des DJs:
  /// - Free: Erste N Partys (nach start_date) im aktuellen 30-Tage-Zyklus = active, Rest = standby.
  /// - Pro: Alle Partys mit status standby → active.
  static Future<void> syncPartyStates(UserModel user) async {
    final ref = FirebaseFirestore.instance.collection('parties');
    final snapshot = await ref
        .where('created_by', isEqualTo: user.id)
        .get();

    if (user.isFree) {
      final periodStart =
          user.freePeriodStart ?? LimitService.effectiveFreeBillingAnchorDate(user);
      if (periodStart == null) return;

      final now = DateTime.now();
      final currentPeriodStart = _currentPeriodStart(periodStart, now);
      final periodEnd = currentPeriodStart.add(const Duration(days: _freePeriodDays));
      final activeSlots = _activeSlotsFor(user);

      // Nur Partys, die nicht beendet sind und deren created_at im aktuellen Zyklus liegt
      final inPeriod = <QueryDocumentSnapshot>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (data['lifecycle_status'] == 'finished' || data['finished_at'] != null) continue;
        final createdAt = data['created_at'] as Timestamp?;
        if (createdAt == null) continue;
        final t = createdAt.toDate();
        if (t.isBefore(currentPeriodStart) || !t.isBefore(periodEnd)) continue;
        inPeriod.add(doc);
      }

      if (inPeriod.isEmpty) return;

      // Nach start_date sortieren (früheste zuerst)
      inPeriod.sort((a, b) {
        final startA = ((a.data() as Map<String, dynamic>)['start_date'] as Timestamp?)?.toDate() ?? DateTime(0);
        final startB = ((b.data() as Map<String, dynamic>)['start_date'] as Timestamp?)?.toDate() ?? DateTime(0);
        return startA.compareTo(startB);
      });

      // Erste N = active, Rest = standby
      for (var i = 0; i < inPeriod.length; i++) {
        final doc = inPeriod[i];
        final newStatus = i < activeSlots ? 'active' : 'standby';
        final current = (doc.data() as Map<String, dynamic>)['lifecycle_status'] as String?;
        if (current == newStatus) continue;
        await ref.doc(doc.id).update({'lifecycle_status': newStatus});
      }
      return;
    }

    // Pro: Alle standby → active
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      if (data['lifecycle_status'] == 'standby') {
        await ref.doc(doc.id).update({'lifecycle_status': 'active'});
      }
    }
  }

  /// Zählt aktive Partys (nicht finished, nicht standby) des DJs im aktuellen 30-Tage-Zyklus.
  /// Für Free-DJ: wenn >= Kontingent, muss neue Party als standby gespeichert werden.
  static Future<int> countActivePartiesInCurrentPeriod(UserModel user) async {
    if (!user.isFree) return 0;
    final periodStart =
        user.freePeriodStart ?? LimitService.effectiveFreeBillingAnchorDate(user);
    if (periodStart == null) return 0;

    final now = DateTime.now();
    final currentPeriodStart = _currentPeriodStart(periodStart, now);
    final periodEnd = currentPeriodStart.add(const Duration(days: _freePeriodDays));

    final snapshot = await FirebaseFirestore.instance
        .collection('parties')
        .where('created_by', isEqualTo: user.id)
        .get();

    int count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      if (data['lifecycle_status'] == 'finished' || data['finished_at'] != null) continue;
      if (data['lifecycle_status'] == 'standby') continue;
      final createdAt = data['created_at'] as Timestamp?;
      if (createdAt == null) continue;
      final t = createdAt.toDate();
      if (!t.isBefore(currentPeriodStart) && t.isBefore(periodEnd)) count++;
    }
    return count;
  }

  /// Max. aktive Free-Partys im Zeitraum für diesen User.
  static int freeActivePartyQuota(UserModel user) => _activeSlotsFor(user);
}
