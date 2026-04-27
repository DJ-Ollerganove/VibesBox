import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

/// Helper-Klasse für die Formatierung von Party-Countdowns
/// Zeitbasis: Vergleiche nutzen Geräte-UTC (DateTime.now().toUtc()) bzw. Firestore start_time_posix/end_time_posix (ebenfalls UTC), damit DJ-Gerät und Firestore konsistent sind.
class SettingsPartyCountdownHelper {
  /// Formatiere Countdown für bevorstehende Partys basierend auf UTC Unix-Timestamp (Sekunden)
  static String formatCountdownFromUnix(
    int startUnixSeconds,
    BuildContext context,
  ) {
    final l = AppLocalizations.of(context)!;
    final nowUnixSeconds =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final differenceSeconds = startUnixSeconds - nowUnixSeconds;

    if (differenceSeconds <= 0) {
      return l.party_status_started;
    }
    if (differenceSeconds <= 60) {
      final startsIn = l.party_starts_in;
      return '$startsIn ${differenceSeconds}s';
    }
    // Aufrunden: 61–119 Sek. → "2 Minuten", 120–179 Sek. → "3 Minuten"
    final totalMinutes = (differenceSeconds + 59) ~/ 60;
    final totalHours = totalMinutes ~/ 60;
    final days = totalHours ~/ 24;

    final dayStr =
        days == 1 ? l.party_day : l.party_days;
    final hourStr = (totalHours % 24) == 1
        ? l.party_hour
        : l.party_hours;
    final minuteStr = (totalMinutes % 60) == 1
        ? l.party_minute
        : l.party_minutes;

    // Wenn mehr als 24 Stunden: Tage, Stunden, Minuten
    if (totalHours >= 24) {
      final hours = totalHours % 24;
      final minutes = totalMinutes % 60;

      if (hours == 0 && minutes == 0) {
        return '$days $dayStr';
      } else if (hours == 0) {
        return '$days $dayStr, $minutes $minuteStr';
      } else if (minutes == 0) {
        return '$days $dayStr, $hours $hourStr';
      } else {
        return '$days $dayStr, $hours $hourStr, $minutes $minuteStr';
      }
    } else {
      // Weniger als 24 Stunden: Stunden und Minuten
      final hours = totalHours;
      final minutes = totalMinutes % 60;
      final hourStrShort = hours == 1 ? l.party_hour : l.party_hours;
      final minuteStrShort =
          minutes == 1 ? l.party_minute : l.party_minutes;

      if (hours == 0 && minutes == 0) {
        return l.party_status_starts_now;
      } else if (hours == 0) {
        return '$minutes $minuteStrShort';
      } else if (minutes == 0) {
        return '$hours $hourStrShort';
      } else {
        return '$hours $hourStrShort, $minutes $minuteStrShort';
      }
    }
  }

  /// Formatiere Countdown für bevorstehende Partys (≤60s: Sekunden z. B. "Startet in 45s")
  static String formatCountdown(DateTime startDate, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = startDate.difference(now);

    if (difference.isNegative) {
      return l.party_status_started;
    }
    if (difference.inSeconds <= 60) {
      final startsIn = l.party_starts_in;
      return '$startsIn ${difference.inSeconds}s';
    }
    // Aufrunden: 61–119 Sek. → "2 Minuten"
    final totalMinutes = (difference.inSeconds + 59) ~/ 60;
    final totalHours = totalMinutes ~/ 60;
    final days = difference.inDays;

    final dayStr = days == 1 ? l.party_day : l.party_days;
    final hourStr = (totalHours % 24) == 1
        ? l.party_hour
        : l.party_hours;
    final minuteStr = (totalMinutes % 60) == 1
        ? l.party_minute
        : l.party_minutes;

    // Wenn mehr als 24 Stunden: Tage, Stunden, Minuten
    if (totalHours >= 24) {
      final hours = totalHours % 24;
      final minutes = totalMinutes % 60;

      if (hours == 0 && minutes == 0) {
        return '$days $dayStr';
      } else if (hours == 0) {
        return '$days $dayStr, $minutes $minuteStr';
      } else if (minutes == 0) {
        return '$days $dayStr, $hours $hourStr';
      } else {
        return '$days $dayStr, $hours $hourStr, $minutes $minuteStr';
      }
    } else {
      // Weniger als 24 Stunden: Stunden und Minuten
      final hours = totalHours;
      final minutes = totalMinutes % 60;
      final hourStrShort = hours == 1 ? l.party_hour : l.party_hours;
      final minuteStrShort =
          minutes == 1 ? l.party_minute : l.party_minutes;

      if (hours == 0 && minutes == 0) {
        return l.party_status_starts_now;
      } else if (hours == 0) {
        return '$minutes $minuteStrShort';
      } else if (minutes == 0) {
        return '$hours $hourStrShort';
      } else {
        return '$hours $hourStrShort, $minutes $minuteStrShort';
      }
    }
  }

  /// Formatiere Countdown für laufende Partys (bis zum Ende).
  /// Ceil-Rundung: z. B. 2 Min 10 s → „3 Minuten“. Bei ≤60 s Sekunden-Countdown (z. B. „59s“).
  static String formatCountdownToEnd(DateTime endDate, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = endDate.difference(now);

    if (difference.isNegative) {
      return l.party_status_ended_label;
    }

    final totalSeconds = difference.inSeconds;
    // Sekunden-Countdown bei ≤60 Sekunden
    if (totalSeconds <= 60) {
      return '${totalSeconds}s';
    }
    // Aufrunden: totalMinutes = ceil(seconds/60)
    final totalMinutes = (totalSeconds + 59) ~/ 60;
    final totalHours = totalMinutes ~/ 60;
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;
    final minutes = totalMinutes % 60;

    final dayStr = days == 1 ? l.party_day : l.party_days;
    final hourStr =
        hours == 1 ? l.party_hour : l.party_hours;
    final minuteStr = minutes == 1
        ? l.party_minute
        : l.party_minutes;

    if (days >= 1) {
      if (hours == 0 && minutes == 0) {
        return '$days $dayStr';
      } else if (hours == 0) {
        return '$days $dayStr, $minutes $minuteStr';
      } else if (minutes == 0) {
        return '$days $dayStr, $hours $hourStr';
      } else {
        return '$days $dayStr, $hours $hourStr, $minutes $minuteStr';
      }
    } else {
      if (hours == 0 && minutes == 0) {
        return l.party_status_less_than_minute;
      } else if (hours == 0) {
        return '$minutes $minuteStr';
      } else if (minutes == 0) {
        return '$hours $hourStr';
      } else {
        return '$hours $hourStr, $minutes $minuteStr';
      }
    }
  }
}
