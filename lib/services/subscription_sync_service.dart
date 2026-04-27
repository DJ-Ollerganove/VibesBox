import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../models/user_model.dart';
import 'user_service.dart';
import 'party_limit_service.dart';
import 'trial_expiry_service.dart';
import 'revenue_cat_bootstrap.dart';
import '../utils/debug_log.dart';

/// Zentraler Service für RevenueCat ↔ Firestore Subscription-Sync.
/// Verknüpft RevenueCat-Identität mit Firebase-UID und synchronisiert proUntil.
class SubscriptionSyncService {
  static const String _proEntitlementId = 'vibesbox pro';
  static const String _proEntitlementIdAlt = 'vibesbox_pro';

  /// Letzte erfolgreich an RevenueCat gebundene UID (verhindert doppeltes [Purchases.logIn] pro Session).
  static String? _lastLinkedRcUid;

  /// Verknüpft RevenueCat mit der Firebase-UID (nach Login).
  /// Nur auf Mobile (Android/iOS) – auf Web wird nichts ausgeführt.
  static Future<void> logIn(String uid) async {
    if (kIsWeb) return;
    await RevenueCatBootstrap.ensureConfigured();
    if (_lastLinkedRcUid == uid) {
      debugLog('💳 RevenueCat: Identität bereits verknüpft (überspringe doppeltes logIn)');
      return;
    }
    try {
      await Purchases.logIn(uid);
      _lastLinkedRcUid = uid;
      debugLog('💳 RevenueCat: Identität verknüpft');
    } catch (e) {
      debugLog('⚠️ RevenueCat logIn fehlgeschlagen: $e');
    }
  }

  /// Meldet RevenueCat ab (beim Logout).
  static Future<void> logOut() async {
    if (kIsWeb) return;
    await RevenueCatBootstrap.ensureConfigured();
    _lastLinkedRcUid = null;
    try {
      await Purchases.logOut();
      debugLog('💳 RevenueCat: Abmeldung durchgeführt');
    } catch (e) {
      debugLog('⚠️ RevenueCat logOut fehlgeschlagen: $e');
    }
  }

  /// Liest CustomerInfo von RevenueCat und schreibt proUntil/planType nach Firestore.
  /// Bei aktivem Entitlement: planType 'pro'; sonst Fallback auf 'free' inkl. free_period_start bei Bedarf.
  static Future<void> syncSubscriptionStatus(String uid) async {
    if (kIsWeb) return;
    try {
      await RevenueCatBootstrap.ensureConfigured();
      final customerInfo = await Purchases.getCustomerInfo();

      final entitlement = customerInfo.entitlements.all[_proEntitlementId] ??
          customerInfo.entitlements.all[_proEntitlementIdAlt];

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();
      final data = userDoc.data();

      if (entitlement != null && entitlement.isActive) {
        final expDateString = entitlement.expirationDate;
        if (expDateString == null) return;

        final expDateTime = DateTime.parse(expDateString);
        final rcTimestamp = Timestamp.fromDate(expDateTime);
        final currentProUntil = data?['proUntil'] as Timestamp?;

        if (currentProUntil != null &&
            rcTimestamp.millisecondsSinceEpoch <= currentProUntil.millisecondsSinceEpoch) {
          return; // Firestore hat bereits neueres oder gleiches Datum
        }

        await userRef.set({
          'proUntil': rcTimestamp,
          'isPro': true,
          'planType': 'pro',
        }, SetOptions(merge: true));

        debugLog(
          '💳 SubscriptionSync: proUntil + planType=pro aktualisiert auf ${expDateTime.toIso8601String()}',
        );
        return;
      }

      // Fallback: Prüfen ob Trial noch aktiv (trialUntil in Firestore)
      final trialUntilTs = data?['trialUntil'] as Timestamp?;
      final trialActive = trialUntilTs != null &&
          trialUntilTs.toDate().isAfter(DateTime.now());

      if (trialActive) {
        await userRef.set({
          'planType': 'trial',
          'isPro': true,
          'trialUntil': trialUntilTs,
          'proUntil': trialUntilTs,
        }, SetOptions(merge: true));
        debugLog('💳 SubscriptionSync: planType=trial, isPro=true (Trial noch aktiv)');
        return;
      }

      // Pro Life (Lifetime): proUntil Jahr >= 2099 – kein Zurücksetzen auf Free.
      final currentProUntil = data?['proUntil'] as Timestamp?;
      if (currentProUntil != null && currentProUntil.toDate().year >= 2099) {
        debugLog('💳 SubscriptionSync: Pro Life (proUntil >= 2099) – Überschreiben übersprungen.');
        return;
      }

      // Downgrade/Bestätigung Free: planType='free', isPro=false.
      // Schreibschutz für free_period_start: Nur setzen bei echtem Wechsel (planType war nicht 'free')
      // oder wenn das Feld fehlt – sonst Stichtag nicht überschreiben (verhindert Reset bei jedem App-Start).
      final currentPlanType = (data?['planType'] as String?)?.trim().toLowerCase();
      final hasFreePeriodStart = data?['free_period_start'] != null;
      final mayWriteFreePeriodStart = currentPlanType != 'free' || !hasFreePeriodStart;

      final updatePayload = <String, dynamic>{
        'planType': 'free',
        'isPro': false,
      };
      if (mayWriteFreePeriodStart) {
        updatePayload['free_period_start'] = Timestamp.now();
        debugLog('💳 SubscriptionSync: auf Free gesetzt (free_period_start = jetzt).');
      } else {
        debugLog('💳 SubscriptionSync: bereits Free mit Stichtag – free_period_start unverändert.');
      }
      await userRef.set(updatePayload, SetOptions(merge: true));
      // Party-Status synchronisieren: nur erste Party im Zyklus bleibt active, Rest → standby
      final updatedUserDoc = await userRef.get();
      if (updatedUserDoc.exists) {
        await PartyLimitService.syncPartyStates(UserModel.fromFirestore(updatedUserDoc));
      }
    } catch (e) {
      debugLog('⚠️ SubscriptionSync fehlgeschlagen: $e');
    } finally {
      // Force-Reload des User-Dokuments, damit alle Listener (z. B. Profil-Widget) sofort aktualisierte Daten erhalten.
      UserService().forceRefresh();
    }
  }

  /// Holt Details zum Store-Abo (Expiration & Auto-Renew Status).
  /// Wird für die Bonus-Berechnung im Profil benötigt.
  static Future<({DateTime? storeExpiration, bool willRenew})> getStoreSubscriptionDetails() async {
    if (kIsWeb) return (storeExpiration: null, willRenew: false);
    try {
      await RevenueCatBootstrap.ensureConfigured();
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.all[_proEntitlementId] ??
          info.entitlements.all[_proEntitlementIdAlt];
      
      if (entitlement == null || !entitlement.isActive) {
        return (storeExpiration: null, willRenew: false);
      }

      final dynamic rawDate = entitlement.expirationDate;
      DateTime? expDate;
      if (rawDate is String) {
        expDate = DateTime.parse(rawDate);
      } else if (rawDate is DateTime) {
        expDate = rawDate;
      }

      return (
        storeExpiration: expDate,
        willRenew: entitlement.willRenew
      );
    } catch (e) {
      debugLog('⚠️ Fehler beim Abrufen der Abo-Details: $e');
      return (storeExpiration: null, willRenew: false);
    }
  }

  /// Siehe [TrialExpiryService.computeTwoDayTrialEndRoundedToNextHour].
  static DateTime computeTwoDayTrialEndRoundedToNextHour([DateTime? from]) =>
      TrialExpiryService.computeTwoDayTrialEndRoundedToNextHour(from);

  /// Siehe [TrialExpiryService.applyExpiredTrialDowngrade].
  static Future<void> applyExpiredTrialDowngrade(String uid) =>
      TrialExpiryService.applyExpiredTrialDowngrade(uid);

  /// Aktiviert das 2-Tage-Trial für den User: setzt trialUntil, trialUsed und planType 'trial'.
  /// Sollte nur aufgerufen werden, wenn trialUsed noch false ist (z. B. aus der Paywall).
  static Future<void> activateTwoDayTrial(String uid) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await ref.get();
      final data = snap.data();
      if (data != null && data['trialUsed'] == true) {
        debugLog('💳 Trial bereits genutzt – keine erneute Aktivierung');
        return;
      }
      final trialUntil =
          TrialExpiryService.computeTwoDayTrialEndRoundedToNextHour();
      await ref.set({
        'trialUntil': Timestamp.fromDate(trialUntil),
        'trialUsed': true,
        'planType': 'trial',
        'isPro': true,
        'proUntil': Timestamp.fromDate(trialUntil),
      }, SetOptions(merge: true));
      debugLog(
        '💳 Trial aktiviert bis ${trialUntil.toIso8601String()} (48h + volle Stunde, planType=trial)',
      );
    } catch (e) {
      debugLog('⚠️ activateTwoDayTrial fehlgeschlagen: $e');
      rethrow;
    }
  }
}
