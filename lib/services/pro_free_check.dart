import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

/// Ergebnis von [ProFreeCheck.determineStatus]: Status, Datum für Widget, ob aktiv.
class ProFreeStatusResult {
  final ProFreeStatus status;
  final DateTime? displayDate;
  final bool isActive;

  const ProFreeStatusResult({
    required this.status,
    this.displayDate,
    required this.isActive,
  });
}

/// Mögliche Status-Werte nach Life/History/Kulanz-Prüfung.
enum ProFreeStatus {
  PRO_LIFE,
  PRO,
  DJ_B2B,
  FREE,
}

/// Zentrale Logik für Pro/Free-Status: Life-Check, Trial, bezahltes Pro, Kulanz.
/// Kein UI-Code, nur Zugriffskontrolle und Status-Ermittlung.
class ProFreeCheck {
  ProFreeCheck._();

  static const _freeInactive =
      ProFreeStatusResult(status: ProFreeStatus.FREE, isActive: false);

  /// Ermittelt den Pro/Free-Status:
  /// Life → aktives Trial → bezahltes Pro → Kulanz (nur bezahltes Pro, **nie** Trial).
  static ProFreeStatusResult determineStatus({
    UserModel? user,
    List<Map<String, dynamic>> historyEntries = const [],
  }) {
    if (user == null) {
      return _freeInactive;
    }

    final now = DateTime.now();
    final proUntilDate = user.proUntil?.toDate();
    final trialUntilDate = user.trialUntil?.toDate();

    // Check 1 (Life): proUntil im Jahr 2099 oder später, oder planType pro_life
    if (proUntilDate != null && proUntilDate.year >= 2099) {
      return ProFreeStatusResult(
        status: ProFreeStatus.PRO_LIFE,
        displayDate: proUntilDate,
        isActive: true,
      );
    }
    if (user.planType == 'pro_life' &&
        proUntilDate != null &&
        proUntilDate.isAfter(now)) {
      return ProFreeStatusResult(
        status: ProFreeStatus.PRO_LIFE,
        displayDate: proUntilDate,
        isActive: true,
      );
    }

    // Check 2: Aktives Trial (planType trial, trialUntil in der Zukunft)
    if (user.planType == 'trial' &&
        trialUntilDate != null &&
        trialUntilDate.isAfter(now)) {
      return ProFreeStatusResult(
        status: ProFreeStatus.PRO,
        displayDate: trialUntilDate,
        isActive: true,
      );
    }

    // Check 2b: Bezahltes Store-Abo (RevenueCat) vor DJ B2B
    if (_hasActivePaidStoreSubscription(user, now)) {
      final expiry = proUntilDate ?? trialUntilDate;
      if (expiry != null && expiry.isAfter(now)) {
        return ProFreeStatusResult(
          status: ProFreeStatus.PRO,
          displayDate: expiry,
          isActive: true,
        );
      }
    }

    // Check 2c: DJ B2B-Verbrauch aktiv
    if (user.isDjB2bActive) {
      return ProFreeStatusResult(
        status: ProFreeStatus.DJ_B2B,
        displayDate: proUntilDate,
        isActive: true,
      );
    }

    // Abgelaufenes Trial oder Free ohne bezahltes Pro — kein Pro, keine Kulanz auf trialUntil
    final hasPaidProEntitlement =
        user.isPro ||
        user.planType == 'pro' ||
        user.planType == 'pro_life' ||
        _hasPaidProInHistory(historyEntries) ||
        _hasActivePaidStoreSubscription(user, now);

    if (!hasPaidProEntitlement) {
      if (trialUntilDate != null &&
          (user.planType == 'trial' || user.planType == 'free')) {
        return ProFreeStatusResult(
          status: ProFreeStatus.FREE,
          displayDate: trialUntilDate,
          isActive: false,
        );
      }
      return _freeInactive;
    }

    // Check 3: Bezahltes Pro — Ablauf aus proUntil (nicht trialUntil)
    DateTime? expiryDate = proUntilDate;

    if (expiryDate == null && historyEntries.isNotEmpty) {
      final newest = historyEntries.first;
      final ts = newest['timestamp'];
      if (ts is Timestamp) {
        expiryDate = ts.toDate();
      }
    }

    if (expiryDate == null) {
      return _freeInactive;
    }

    if (expiryDate.isAfter(now)) {
      return ProFreeStatusResult(
        status: ProFreeStatus.PRO,
        displayDate: expiryDate,
        isActive: true,
      );
    }

    // Check 4 (Kulanz): nur bezahltes Pro — bis 23:59 Folgetag nach Ablauf
    final dateOnly =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final nextDay = dateOnly.add(const Duration(days: 1));
    final endOfNextDay = DateTime(
      nextDay.year,
      nextDay.month,
      nextDay.day,
      23,
      59,
      59,
      999,
    );
    if (now.isBefore(endOfNextDay)) {
      return ProFreeStatusResult(
        status: ProFreeStatus.PRO,
        displayDate: expiryDate,
        isActive: true,
      );
    }

    return ProFreeStatusResult(
      status: ProFreeStatus.FREE,
      displayDate: expiryDate,
      isActive: false,
    );
  }

  static bool _hasPaidProInHistory(List<Map<String, dynamic>> historyEntries) {
    for (final entry in historyEntries) {
      final type = (entry['type'] ?? entry['planType'] ?? '')
          .toString()
          .toLowerCase();
      if (type.contains('pro') || type.contains('purchase') || type.contains('subscription')) {
        return true;
      }
    }
    return false;
  }

  static bool _hasActivePaidStoreSubscription(UserModel user, DateTime now) {
    if (!user.isPro) return false;
    final proUntil = user.proUntil?.toDate();
    if (proUntil == null || !proUntil.isAfter(now)) return false;
    if (proUntil.year >= 2099) return true;
    if (user.planType == 'trial') return false;
    if (user.isDjB2bActive) return false;
    final provider = user.lastPaymentProvider.trim();
    return provider == 'RevenueCat' ||
        user.planType == 'pro' ||
        user.planType == 'pro_life';
  }

  /// Erster Kalendertag (lokal, 00:00), an dem der User nach der Kulanz-Regel ([determineStatus] Check 4)
  /// für Abrechnungszwecke als **Free** gilt — nicht der Moment des Entzugs/Kündigungs-Klicks.
  static DateTime computeFreePeriodStartAfterProGrace(DateTime lastProInstant) {
    final local = lastProInstant.toLocal();
    final dateOnly = DateTime(local.year, local.month, local.day);
    return dateOnly.add(const Duration(days: 2));
  }
}
