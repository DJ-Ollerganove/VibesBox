import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../l10n/app_localizations.dart';
import '../l10n/generated/language_registry.g.dart';
import '../l10n/locale_helper.dart';
import 'locale_clock_format.dart';

/// Zentrale Datum-/Uhrzeit-Formatierung (BCP-47 aus [LanguageRegistry] / languages.json).
class FormattingUtils {
  /// BCP-47-Tag der aktuellen App-Sprache (z. B. `pl-PL`, `el-GR`).
  static String intlTag(BuildContext context) {
    return LanguageRegistry.intlTagFor(
      Localizations.localeOf(context).languageCode,
    );
  }

  /// BCP-47-Tag für einen Sprachcode (mit Fallback auf unterstützte Sprache).
  static String intlTagForLanguageCode(String languageCode) {
    final code = LocaleHelper.mapToSupportedOrEnglish(languageCode);
    return LanguageRegistry.intlTagFor(code);
  }

  static bool usesHour12(BuildContext context) {
    return LanguageRegistry.usesHour12(
      Localizations.localeOf(context).languageCode,
    );
  }

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

  /// Langes Datum (z. B. Profil „Mitglied seit“).
  static String formatDateLong(DateTime date, BuildContext context) {
    return intl.DateFormat.yMMMMd(intlTag(context)).format(date);
  }

  /// Mittleres Datum (z. B. abgelehnte Wünsche).
  static String formatDateMedium(DateTime date, BuildContext context) {
    return intl.DateFormat.yMMMd(intlTag(context)).format(date);
  }

  /// Nur Uhrzeit — [LocaleClockFormat] / languages.json (time_style, time_suffix).
  static String _formatTimeForTag(
    DateTime dateTime,
    String tag,
    String languageCode, {
    bool withSuffix = true,
  }) {
    final code = LocaleHelper.mapToSupportedOrEnglish(languageCode);
    return LocaleClockFormat.format(
      dateTime,
      code,
      intlTag: tag,
      withSuffix: withSuffix,
    );
  }

  static String _formatTimeForContext(DateTime dateTime, BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return _formatTimeForTag(dateTime, intlTag(context), code);
  }

  /// Kurzes Datum + Uhrzeit (12h nur für EN laut languages.json).
  static String formatDateTimeYmdHm(DateTime date, BuildContext context) {
    final tag = intlTag(context);
    return '${intl.DateFormat.yMd(tag).format(date)} ${_formatTimeForContext(date, context)}';
  }

  /// Alias — [formatDateTimeYmdHm] enthält bereits [time_suffix] wenn gesetzt.
  static String formatDateTimeYmdHmWithSuffix(
    DateTime date,
    BuildContext context,
  ) {
    return formatDateTimeYmdHm(date, context);
  }

  /// Explizit 24-Stunden-Uhr ([Hm]).
  static String formatTime24h(DateTime dateTime, BuildContext context) {
    return intl.DateFormat.Hm(intlTag(context)).format(dateTime);
  }

  /// Formatiert Startzeit für QR-Export (Datum + Uhrzeit nach [intl_locale] in languages.json).
  static String formatStartTimeForExport(DateTime date, Locale locale) {
    final tag = LanguageRegistry.intlTagFor(locale.languageCode);
    final datePart = intl.DateFormat.yMd(tag).format(date);
    final timePart = _formatTimeForTag(date, tag, locale.languageCode);
    return '$datePart - $timePart';
  }

  /// Datum und Uhrzeit für PDF/QR-Bild gemäß Export-Sprache ([languageCode], z. B. `de`, `en`).
  static String formatDateTimeForLanguageExport(DateTime date, String languageCode) {
    final tag = intlTagForLanguageCode(languageCode);
    final code = LocaleHelper.mapToSupportedOrEnglish(languageCode);
    return '${intl.DateFormat.yMd(tag).format(date)} ${_formatTimeForTag(date, tag, code)}';
  }

  /// Kurzes Datum (ohne Uhrzeit) passend zur App-Sprache.
  static String formatDateForLocale(DateTime date, BuildContext context) {
    return intl.DateFormat.yMd(intlTag(context)).format(date);
  }

  /// Kompakte Datums+Zeit-Anzeige wenn kein gültiger [BuildContext] mehr vorliegt
  /// (z. B. nach `await`, Widget bereits entfernt).
  static String formatCompactDateTimeWithoutContext(DateTime dateTime) {
    final raw = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code = LocaleHelper.mapToSupportedOrEnglish(raw);
    final tag = LanguageRegistry.intlTagFor(code);
    return '${intl.DateFormat.yMd(tag).format(dateTime)} ${_formatTimeForTag(dateTime, tag, code)}';
  }

  /// Nur Uhrzeit, Geräte-Locale (Fallback ohne [BuildContext]).
  static String formatShortTimeWithoutContext(DateTime dateTime) {
    final raw = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code = LocaleHelper.mapToSupportedOrEnglish(raw);
    final tag = LanguageRegistry.intlTagFor(code);
    return _formatTimeForTag(dateTime, tag, code);
  }

  /// Nächste volle Stunde für Wunsch-Limits (Snackbars), sprachgerecht inkl. [time_suffix].
  static String formatNextWishFullHourClock(DateTime when, BuildContext context) {
    return formatClockWithSuffix(when, context);
  }

  /// Wie [formatTime] (inkl. [time_suffix], z. B. DE „ Uhr“).
  static String formatClockWithSuffix(DateTime dateTime, BuildContext context) {
    return formatTime(dateTime, context);
  }

  /// Kompakte Zeile Datum + Uhrzeit (z. B. Vorab-Header).
  static String formatCompactDateTimeLine(
    DateTime dateTime,
    BuildContext context,
  ) {
    final tag = intlTag(context);
    final datePart = intl.DateFormat.yMd(tag).format(dateTime);
    final timePart = formatTime(dateTime, context);
    return '$datePart $timePart';
  }

  /// Party-Zeitraum für Statistik-Kacheln (Start–Ende), nach App-Locale.
  static String formatCompactPartyPeriod(
    DateTime? start,
    DateTime? end,
    BuildContext context,
  ) {
    if (start == null) return '--';
    final tag = intlTag(context);
    final code = Localizations.localeOf(context).languageCode;
    final startStr =
        '${intl.DateFormat.yMd(tag).format(start)} ${_formatTimeForTag(start, tag, code)}';
    if (end == null) return startStr;
    final endStr =
        '${intl.DateFormat.yMd(tag).format(end)} ${_formatTimeForTag(end, tag, code)}';
    return '$startStr – $endStr';
  }

  /// Für „Letzter Login:“: Datum und Uhrzeit mit Komma (ohne verbindendes Wort wie „um“).
  static String formatDateTimeCommaBetweenDateAndTime(
    DateTime date,
    BuildContext context,
  ) {
    final datePart = formatDateForLocale(date, context);
    final timeString = formatTime(date, context);
    return '$datePart, $timeString';
  }

  /// Formatiert nur die Uhrzeit (ohne Datum), inkl. [time_suffix] wenn gesetzt.
  static String formatTime(DateTime dateTime, BuildContext context) {
    return _formatTimeForContext(dateTime, context);
  }

  /// [TimeOfDay] wie [formatTime] (z. B. Party-Erstellung).
  static String formatTimeOfDay(TimeOfDay time, BuildContext context) {
    final now = DateTime.now();
    return formatTime(
      DateTime(now.year, now.month, now.day, time.hour, time.minute),
      context,
    );
  }

  /// Formatiert DateTime für die Anzeige (mit "um" und "Uhr")
  static String formatDateTime(DateTime? dateTime, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (dateTime == null) return localizations.never;

    final datePart = formatDateForLocale(dateTime, context);
    final timeString = formatTime(dateTime, context);

    final at = localizations.party_time_at;
    return '$datePart $at $timeString';
  }

  /// Formatiert DateTime für die Anzeige (mit "um" und lokalisiert)
  static String formatDateTimeForDisplay(DateTime date, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final datePart = formatDateForLocale(date, context);
    final timeString = formatTime(date, context);

    final at = localizations.party_time_at;
    return '$datePart $at $timeString';
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
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
