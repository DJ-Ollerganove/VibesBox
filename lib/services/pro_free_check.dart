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
  FREE,
}

/// Zentrale Logik für Pro/Free-Status: Life-Check, History-Check, Kulanz-Regel.
/// Kein UI-Code, nur Zugriffskontrolle und Status-Ermittlung.
class ProFreeCheck {
  ProFreeCheck._();

  /// Ermittelt den Pro/Free-Status strikt nach: Life -> History -> Kulanz.
  ///
  /// [user] – aktuelles UserModel aus Firestore.
  /// [historyEntries] – Liste der History-Einträge (users/{uid}/history).
  ///   Format: Map mit 'timestamp' (Timestamp?) und optional weiteren Feldern.
  ///
  /// Check 1 (Life): proUntil Jahr >= 2099 -> PRO_LIFE.
  /// Check 2 (History): Kein Life -> neuester History-Eintrag bzw. User-Dokument liefert expiryDate.
  /// Check 3 (Kulanz): expiryDate überschritten -> wenn noch vor 23:59 Folgetag (lokal) -> PRO.
  static ProFreeStatusResult determineStatus({
    UserModel? user,
    List<Map<String, dynamic>> historyEntries = const [],
  }) {
    if (user == null) {
      return const ProFreeStatusResult(status: ProFreeStatus.FREE, isActive: false);
    }

    // Check 1 (Life): proUntil im Jahr 2099 oder später -> PRO_LIFE
    final proUntilDate = user.proUntil?.toDate();
    if (proUntilDate != null && proUntilDate.year >= 2099) {
      return ProFreeStatusResult(
        status: ProFreeStatus.PRO_LIFE,
        displayDate: proUntilDate,
        isActive: true,
      );
    }

    // Check 2 (History): Kein Life -> neuester Eintrag / User-Dokument liefert expiryDate
    // expiryDate aus User-Dokument (proUntil oder trialUntil)
    DateTime? expiryDate = user.proUntil?.toDate() ?? user.trialUntil?.toDate();

    // Falls User-Dokument kein Datum hat, könnte aus History abgeleitet werden
    // (z.B. neuester Kauf + Standardlaufzeit). Aktuell: primär aus User-Dokument.
    if (expiryDate == null && historyEntries.isNotEmpty) {
      final newest = historyEntries.first;
      final ts = newest['timestamp'];
      if (ts != null && ts is Timestamp) {
        expiryDate = ts.toDate();
        // Kein Ablaufdatum in History – Fallback: Datum des letzten Kaufs
        // (optional: +1 Monat wenn Kauf-Typ bekannt; hier nur Timestamp)
      }
    }

    // Kein Ablaufdatum verfügbar -> FREE
    if (expiryDate == null) {
      return const ProFreeStatusResult(status: ProFreeStatus.FREE, isActive: false);
    }

    final now = DateTime.now();

    // Check 3 (Kulanz): expiryDate überschritten?
    if (expiryDate.isAfter(now)) {
      // Noch gültig -> PRO
      return ProFreeStatusResult(
        status: ProFreeStatus.PRO,
        displayDate: expiryDate,
        isActive: true,
      );
    }

    // Abgelaufen: Bei planType 'trial' keine Kulanz (exakt trialUntil/proUntil).
    if (user.planType == 'trial') {
      return ProFreeStatusResult(
        status: ProFreeStatus.FREE,
        displayDate: expiryDate,
        isActive: false,
      );
    }

    // Kulanz: expiryDate überschritten – prüfen, ob vor 23:59 Uhr des Folgetages (lokale Zeit)
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
}
