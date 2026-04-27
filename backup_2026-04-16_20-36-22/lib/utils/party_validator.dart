import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Zentrale Validierungsklasse für Party-Zeiten
/// 
/// Diese Klasse stellt Methoden zur Validierung von Party-Zeiten bereit:
/// - Dauer-Check (5 Min bis 23:55 Std)
/// - Überschneidungs-Check mit anderen Partys
/// 
/// Vorbereitet für zukünftige DJ-spezifische Limits (z.B. für Free-Accounts)
class PartyValidator {
  /// Minimale Partydauer: 5 Minuten
  static const Duration minDuration = Duration(minutes: 5);
  
  /// Maximale Partydauer: 23 Stunden und 55 Minuten
  static const Duration maxDuration = Duration(hours: 23, minutes: 55);
  
  /// Maximale Vorlaufzeit für Party-Planung: 6 Monate
  static const int maxMonthsInAdvance = 6;

  /// Validiert die Partydauer
  /// 
  /// Gibt null zurück, wenn die Dauer valide ist.
  /// Gibt eine Fehlermeldung zurück, wenn die Dauer nicht valide ist.
  /// 
  /// [startDateTime] - Startzeit der Party
  /// [endDateTime] - Endzeit der Party
  /// [context] - BuildContext für Lokalisierung (optional)
  /// 
  /// Returns: Fehlermeldung oder null
  static String? validateDuration(
    DateTime startDateTime,
    DateTime endDateTime, {
    BuildContext? context,
  }) {
    // Prüfe: Endzeit muss nach Startzeit sein
    if (endDateTime.isBefore(startDateTime) || 
        endDateTime.isAtSameMomentAs(startDateTime)) {
      return null; // Wird durch andere Validierung abgefangen
    }

    final duration = endDateTime.difference(startDateTime);

    // Prüfe: Mindestdauer 5 Minuten
    if (duration < minDuration) {
      return context != null
          ? AppLocalizations.of(context)!.party_validation_duration_too_short
          : 'Die Partydauer muss mindestens 5 Minuten betragen.';
    }

    // Prüfe: Maximaldauer 23:55 Stunden
    if (duration > maxDuration) {
      return context != null
          ? AppLocalizations.of(context)!.party_validation_duration_too_long
          : 'Die Partydauer darf maximal 23 Stunden und 55 Minuten betragen.';
    }

    return null; // Alles valide
  }

  /// Prüft auf Überschneidungen mit anderen Partys (mit 5-Minuten-Puffer)
  /// 
  /// Gibt null zurück, wenn keine Überschneidung gefunden wurde.
  /// Gibt eine Fehlermeldung zurück, wenn eine Überschneidung oder zu wenig Puffer gefunden wurde.
  /// 
  /// Mathematische Puffer-Logik:
  /// Eine neue Party (Start S1, Ende E1) kollidiert mit einer bestehenden Party (Start S2, Ende E2), wenn:
  /// S1 < (E2 + 300 Sekunden) UND E1 > (S2 - 300 Sekunden)
  /// 
  /// Das stellt sicher, dass zwischen dem Ende der einen und dem Start der nächsten Party
  /// immer mindestens 300 Sekunden (5 Minuten) Luft sind.
  /// 
  /// [startDateTime] - Startzeit der neuen Party
  /// [endDateTime] - Endzeit der neuen Party
  /// [allParties] - Liste aller Partys des DJs (QueryDocumentSnapshot)
  /// [currentPartyId] - ID der aktuellen Party (wird bei der Prüfung übersprungen)
  /// [context] - BuildContext für Lokalisierung (optional)
  /// 
  /// Returns: Fehlermeldung oder null
  static String? validateOverlap(
    DateTime startDateTime,
    DateTime endDateTime,
    List<QueryDocumentSnapshot> allParties,
    String? currentPartyId, {
    BuildContext? context,
  }) {
    if (allParties.isEmpty) {
      return null; // Keine Partys vorhanden, keine Überschneidung möglich
    }

    // Konvertiere neue Zeiten zu UTC Unix-Timestamps (Sekunden)
    final newStartUtc = startDateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final newEndUtc = endDateTime.toUtc().millisecondsSinceEpoch ~/ 1000;

    // 5-Minuten-Puffer in Sekunden
    const int bufferSeconds = 300; // 5 Minuten = 300 Sekunden

    // Prüfe Überschneidungen mit allen anderen Partys
    for (final partyDoc in allParties) {
      // Überspringe die aktuelle Party (bei Bearbeitung)
      if (currentPartyId != null && partyDoc.id == currentPartyId) {
        continue;
      }

      final data = partyDoc.data() as Map<String, dynamic>;
      final existingStartPosix = data['start_time_posix'] as int?;
      final existingEndPosix = data['end_time_posix'] as int?;

      if (existingStartPosix != null && existingEndPosix != null) {
        // Mathematische Puffer-Logik:
        // Eine neue Party (Start S1, Ende E1) kollidiert mit einer bestehenden Party (Start S2, Ende E2), wenn:
        // S1 < (E2 + 300 Sekunden) UND E1 > (S2 - 300 Sekunden)
        // 
        // Das ist äquivalent zu: Fehler wenn BEIDE Bedingungen NICHT zutreffen:
        // - neuerStart >= (existierendesEnde + 300) ODER
        // - neuesEnde <= (existierenderStart - 300)
        // 
        // Beispiel: Bestehende Party 10:00-12:00 Uhr
        // - Start um 12:04:59 Uhr → Fehler (12:04:59 < 12:05:00)
        // - Start um 12:05:00 Uhr → OK (12:05:00 >= 12:05:00)
        final existingEndWithBuffer = existingEndPosix + bufferSeconds;
        final existingStartWithBuffer = existingStartPosix - bufferSeconds;
        
        // Fehler wenn: neuerStart < (existierendesEnde + 300) UND neuesEnde > (existierenderStart - 300)
        // Das bedeutet: Zu wenig Puffer zwischen den Partys
        if (newStartUtc < existingEndWithBuffer && newEndUtc > existingStartWithBuffer) {
          return context != null
              ? AppLocalizations.of(context)!.party_validation_gap_too_short
              : 'Zwischen zwei Partys müssen mindestens 5 Minuten Pause liegen.';
        }
      }
    }

    return null; // Keine Überschneidung gefunden
  }

  /// Validiert, ob die Party nicht zu weit in der Zukunft liegt
  /// 
  /// Gibt null zurück, wenn die Startzeit valide ist.
  /// Gibt eine Fehlermeldung zurück, wenn die Party mehr als 24 Monate im Voraus geplant ist.
  /// 
  /// [startDateTime] - Startzeit der Party
  /// [context] - BuildContext für Lokalisierung (optional)
  /// 
  /// Returns: Fehlermeldung oder null
  static String? validateMaxAdvanceTime(
    DateTime startDateTime, {
    BuildContext? context,
  }) {
    // Berechne maximal zulässigen Startzeitpunkt: jetzt + 6 Monate
    final now = DateTime.now();
    // Vereinfachte Berechnung: Addiere 6 Monate zum aktuellen Datum
    int newYear = now.year;
    int newMonth = now.month + maxMonthsInAdvance;
    
    // Korrigiere Jahr und Monat falls Monat > 12
    while (newMonth > 12) {
      newMonth -= 12;
      newYear += 1;
    }
    
    final maxAllowedStart = DateTime(
      newYear,
      newMonth,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    
    // Prüfe, ob Startzeit über dem Limit liegt
    if (startDateTime.isAfter(maxAllowedStart)) {
      return context != null
          ? AppLocalizations.of(context)!.party_validation_too_far_future
          : 'Eine Party kann maximal 6 Monate im Voraus geplant werden.';
    }
    
    return null; // Alles valide
  }

  /// Vollständige Validierung: Maximal-Vorlaufzeit + Dauer + Überschneidung
  /// 
  /// Führt alle Validierungen durch und gibt die erste gefundene Fehlermeldung zurück.
  /// Reihenfolge: 1. Maximal-Vorlaufzeit, 2. Dauer (nur für Nicht-Admins), 3. Überschneidungen
  /// 
  /// [startDateTime] - Startzeit der Party
  /// [endDateTime] - Endzeit der Party
  /// [allParties] - Liste aller Partys des DJs (optional)
  /// [currentPartyId] - ID der aktuellen Party (optional, für Bearbeitung)
  /// [isAdmin] - true wenn der aktuelle User ein Admin ist (optional, default: false)
  /// [context] - BuildContext für Lokalisierung (optional)
  /// 
  /// Returns: Fehlermeldung oder null
  static String? validate(
    DateTime startDateTime,
    DateTime endDateTime, {
    List<QueryDocumentSnapshot>? allParties,
    String? currentPartyId,
    bool isAdmin = false,
    BuildContext? context,
  }) {
    // 1. Prüfe Maximal-Vorlaufzeit (6 Monate) - gilt für alle (auch Admins)
    final maxAdvanceError = validateMaxAdvanceTime(startDateTime, context: context);
    if (maxAdvanceError != null) {
      return maxAdvanceError;
    }

    // 2. Prüfe Dauer (nur für Nicht-Admins)
    // Admins können Partys mit beliebiger Dauer erstellen
    if (!isAdmin) {
      final durationError = validateDuration(startDateTime, endDateTime, context: context);
      if (durationError != null) {
        return durationError;
      }
    }

    // 3. Prüfe Überschneidungen (nur wenn allParties vorhanden) - gilt für alle (auch Admins)
    if (allParties != null && allParties.isNotEmpty) {
      final overlapError = validateOverlap(
        startDateTime,
        endDateTime,
        allParties,
        currentPartyId,
        context: context,
      );
      if (overlapError != null) {
        return overlapError;
      }
    }

    return null; // Alles valide
  }

  /// Prüft, ob eine Party bereits läuft
  /// 
  /// [startDateTime] - Startzeit der Party
  /// [endDateTime] - Endzeit der Party
  /// 
  /// Returns: true wenn die Party aktuell läuft
  static bool isPartyRunning(DateTime startDateTime, DateTime endDateTime) {
    final now = DateTime.now();
    return now.compareTo(startDateTime) >= 0 && now.compareTo(endDateTime) < 0;
  }

  /// Prüft, ob eine Party noch nicht gestartet wurde
  /// 
  /// [startDateTime] - Startzeit der Party
  /// 
  /// Returns: true wenn die Party noch nicht gestartet wurde
  static bool hasNotStarted(DateTime startDateTime) {
    return DateTime.now().compareTo(startDateTime) < 0;
  }
}
