import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'party_limit_service.dart';
import '../utils/debug_log.dart';

/// Reine Trial-Ablauf-Logik ohne [UserService] (vermeidet Zirkel-Imports).
class TrialExpiryService {
  TrialExpiryService._();

  /// 48 Stunden ab [from] (Standard: jetzt), Ende auf die **nächste volle Stunde** gerundet.
  static DateTime computeTwoDayTrialEndRoundedToNextHour([DateTime? from]) {
    final base = (from ?? DateTime.now()).toLocal();
    final plus48 = base.add(const Duration(hours: 48));
    if (plus48.minute == 0 &&
        plus48.second == 0 &&
        plus48.millisecond == 0 &&
        plus48.microsecond == 0) {
      return plus48;
    }
    return DateTime(
      plus48.year,
      plus48.month,
      plus48.day,
      plus48.hour + 1,
      0,
      0,
      0,
      0,
    );
  }

  /// Nach abgelaufenem 2-Tage-Trial: `planType` → free, Partys auf Free-Limits.
  static Future<void> applyExpiredTrialDowngrade(String uid) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();
      if (!userDoc.exists) return;
      final data = userDoc.data();
      if (data == null) return;

      final planType = (data['planType'] as String?)?.trim().toLowerCase();
      if (planType != 'trial') return;

      final trialTs = data['trialUntil'] as Timestamp?;
      if (trialTs == null) return;
      if (trialTs.toDate().isAfter(DateTime.now())) return;

      final currentProUntil = data['proUntil'] as Timestamp?;
      if (currentProUntil != null && currentProUntil.toDate().year >= 2099) {
        return;
      }

      final hasFreePeriodStart = data['free_period_start'] != null;
      final mayWriteFreePeriodStart = planType != 'free' || !hasFreePeriodStart;

      final updatePayload = <String, dynamic>{
        'planType': 'free',
        'isPro': false,
      };
      if (mayWriteFreePeriodStart) {
        updatePayload['free_period_start'] = Timestamp.now();
      }
      await userRef.set(updatePayload, SetOptions(merge: true));
      final updatedUserDoc = await userRef.get();
      if (updatedUserDoc.exists) {
        await PartyLimitService.syncPartyStates(
          UserModel.fromFirestore(updatedUserDoc),
        );
      }
      debugLog(
        '💳 TrialExpiryService: User $uid auf Free (Trial abgelaufen).',
      );
    } catch (e) {
      debugLog('⚠️ TrialExpiryService.applyExpiredTrialDowngrade: $e');
    }
  }
}
