import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_helper.dart';

/// Utility-Klasse für Formatierungs-Funktionen
class FormattingUtils {
  /// Gibt eine Begrüßung basierend auf der Tageszeit zurück (für DJs ohne "bei")
  static String getGreeting(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return localizations.greeting_morning_dj;
    } else if (hour >= 12 && hour < 17) {
      return localizations.greeting_day_dj;
    } else if (hour >= 17 && hour < 22) {
      return localizations.greeting_evening_dj;
    } else {
      return localizations.greeting_night_dj;
    }
  }

  /// Begrüßung für die Gast-Startseite: "Schöne Nacht bei VibesBox" (bzw. l10n für alle 8 Sprachen)
  static String getGreetingForGuest(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return localizations.greeting_morning_vibesbox;
    } else if (hour >= 12 && hour < 17) {
      return localizations.greeting_day_vibesbox;
    } else if (hour >= 17 && hour < 22) {
      return localizations.greeting_evening_vibesbox;
    } else {
      return localizations.greeting_night_vibesbox;
    }
  }

  /// Titelzeile Gast-Start (privat): mit Namen (`greeting_personal_*` + `{name}`) oder [getGreetingForGuest].
  /// [profileDisplayName]: z. B. realName / displayName aus Profil oder Auth (ohne leere Strings).
  static String getGuestHomeGreetingTitle(
    BuildContext context, {
    required String? profileDisplayName,
  }) {
    final raw = profileDisplayName?.trim();
    if (raw == null || raw.isEmpty) {
      return getGreetingForGuest(context);
    }
    var name = raw;
    if (name.length > 40) {
      name = name.substring(0, 37) + '\u2026';
    }
    final l = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return l.greetingPersonalMorning(name);
    }
    if (hour >= 12 && hour < 17) {
      return l.greetingPersonalDay(name);
    }
    if (hour >= 17 && hour < 22) {
      return l.greetingPersonalEvening(name);
    }
    return l.greetingPersonalNight(name);
  }

  /// Formatiert Startzeit für QR-Export: TT.MM.JJ - HH:MM, für DE zusätzlich " Uhr".
  static String formatStartTimeForExport(DateTime date, Locale locale) {
    final t = LocaleHelper.getTranslations(locale);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final use12Hour = locale.languageCode == 'en';
    final useH = locale.languageCode == 'fr';
    String timePart;
    if (use12Hour) {
      final hour12 = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
      final amPm = date.hour < 12 ? (t['time_am'] ?? 'AM') : (t['time_pm'] ?? 'PM');
      timePart = '$hour12:${minute} $amPm';
    } else if (useH) {
      timePart = '${hour}h$minute';
    } else {
      timePart = '$hour:$minute';
    }
    final uhrSuffix = locale.languageCode == 'de' ? ' Uhr' : '';
    return '$day.$month.$year - $timePart$uhrSuffix';
  }

  /// Formatiert nur die Uhrzeit (ohne Datum) - zentral für alle Zeitformatierungen
  static String formatTime(DateTime dateTime, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    // Prüfe ob 12-Stunden-Format verwendet werden soll (nur für Englisch)
    final use12HourFormat = locale.languageCode == 'en';
    
    // Prüfe ob "h" statt ":" verwendet werden soll (für Französisch)
    final useHInsteadOfColon = locale.languageCode == 'fr';
    final timeSeparator = useHInsteadOfColon ? 'h' : ':';
    
    String timeString;
    if (use12HourFormat) {
      // 12-Stunden-Format mit AM/PM
      final hour12 = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
      final amPm = dateTime.hour < 12
          ? localizations.time_am
          : localizations.time_pm;
      timeString = '$hour12$timeSeparator$minute $amPm';
    } else {
      // 24-Stunden-Format
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final clock = localizations.party_time_clock;
      // Für Französisch: "20h00" statt "20:00 Uhr"
      if (useHInsteadOfColon) {
        timeString = '$hour$timeSeparator$minute';
      } else {
        timeString = '$hour$timeSeparator$minute $clock';
      }
    }
    
    return timeString;
  }

  /// Formatiert DateTime für die Anzeige (mit "um" und "Uhr")
  static String formatDateTime(DateTime? dateTime, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (dateTime == null) return localizations.never;
    
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final timeString = formatTime(dateTime, context);
    
    final at = localizations.party_time_at;
    return '$day.$month.$year $at $timeString';
  }

  /// Formatiert DateTime für die Anzeige (mit "um" und lokalisiert)
  static String formatDateTimeForDisplay(DateTime date, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final timeString = formatTime(date, context);

    final at = localizations.party_time_at;
    return '$day.$month.$year $at $timeString';
  }

  /// Formatiert Countdown für bevorstehende Partys (Minuten aufgerundet; ≤60s → Sekunden)
  static String formatCountdown(DateTime startDate, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = startDate.difference(now);
    
    if (difference.isNegative) {
      return localizations.party_status_started;
    }
    if (difference.inSeconds <= 60) {
      final startsIn = localizations.party_starts_in;
      return '$startsIn ${difference.inSeconds}s';
    }
    final totalMinutes = (difference.inSeconds + 59) ~/ 60;
    final totalHours = totalMinutes ~/ 60;
    final days = totalHours ~/ 24;

    final dayText = days == 1
        ? localizations.party_day
        : localizations.party_days;
    final hourText = (totalHours % 24) == 1
        ? localizations.party_hour
        : localizations.party_hours;
    final minuteText = (totalMinutes % 60) == 1
        ? localizations.party_minute
        : localizations.party_minutes;
    
    // Wenn mehr als 24 Stunden: Tage, Stunden, Minuten
    if (totalHours >= 24) {
      final hours = totalHours % 24;
      final minutes = totalMinutes % 60;
      
      if (hours == 0 && minutes == 0) {
        return '$days $dayText';
      } else if (hours == 0) {
        return '$days $dayText, $minutes $minuteText';
      } else if (minutes == 0) {
        return '$days $dayText, $hours $hourText';
      } else {
        return '$days $dayText, $hours $hourText, $minutes $minuteText';
      }
    } else {
      // Weniger als 24 Stunden: Stunden und Minuten
      final hours = totalHours;
      final minutes = totalMinutes % 60;
      
      final hourTextShort = hours == 1
          ? localizations.party_hour
          : localizations.party_hours;
      final minuteTextShort = minutes == 1
          ? localizations.party_minute
          : localizations.party_minutes;

      if (hours == 0 && minutes == 0) {
        return localizations.party_status_starts_now;
      } else if (hours == 0) {
        return '$minutes $minuteTextShort';
      } else if (minutes == 0) {
        return '$hours $hourTextShort';
      } else {
        return '$hours $hourTextShort, $minutes $minuteTextShort';
      }
    }
  }

  /// Formatiert Dauer in Millisekunden zu MM:SS Format
  static String formatDurationFromMs(int? durationMs) {
    if (durationMs == null) return '';
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatiert Countdown für laufende Partys (bis zum Ende).
  /// Ceil-Rundung; bei ≤60 s Sekunden-Countdown (z. B. „59s“).
  static String formatCountdownToEnd(DateTime endDate, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = endDate.difference(now);

    if (difference.isNegative) {
      return localizations.party_status_ended;
    }

    final totalSeconds = difference.inSeconds;
    if (totalSeconds <= 60) {
      return '${totalSeconds}s';
    }
    final totalMinutes = (totalSeconds + 59) ~/ 60;
    final totalHours = totalMinutes ~/ 60;
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;
    final minutes = totalMinutes % 60;

    final dayText =
        days == 1 ? localizations.party_day : localizations.party_days;
    final hourText =
        hours == 1 ? localizations.party_hour : localizations.party_hours;
    final minuteText = minutes == 1
        ? localizations.party_minute
        : localizations.party_minutes;

    if (days >= 1) {
      if (hours == 0 && minutes == 0) {
        return '$days $dayText';
      } else if (hours == 0) {
        return '$days $dayText, $minutes $minuteText';
      } else if (minutes == 0) {
        return '$days $dayText, $hours $hourText';
      } else {
        return '$days $dayText, $hours $hourText, $minutes $minuteText';
      }
    } else {
      if (hours == 0 && minutes == 0) {
        return localizations.party_status_less_than_minute;
      } else if (hours == 0) {
        return '$minutes $minuteText';
      } else if (minutes == 0) {
        return '$hours $hourText';
      } else {
        return '$hours $hourText, $minutes $minuteText';
      }
    }
  }
}

