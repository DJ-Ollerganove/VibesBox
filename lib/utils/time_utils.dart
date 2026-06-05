/// Hilfsmethoden für zeitbasierte Fenster (z. B. 2-Stunden-Blöcke; **volle Kalenderstunde** für Gast-Wünsche).
///
/// Blöcke sind feste 2-Stunden-Fenster: 0–1, 2–3, 4–5, …, 22–23 (gerade Stunde = Blockstart).
/// Beispiel: 15:30 → Block 14:00–15:59:59; 16:05 → Block 16:00–17:59:59.
library;

/// Start und Ende eines 2-Stunden-Blocks für ein gegebenes [DateTime].
///
/// [blockStart]: Erster Zeitpunkt des Blocks (z. B. 14:00:00.000).
/// [blockEndExclusive]: Erster Zeitpunkt des *nächsten* Blocks (z. B. 16:00:00.000).
/// Ein Zeitpunkt [t] liegt im Block genau wenn: blockStart <= t < blockEndExclusive.
class TwoHourBlockRange {
  const TwoHourBlockRange({required this.blockStart, required this.blockEndExclusive});

  final DateTime blockStart;
  final DateTime blockEndExclusive;

  /// Letzter Zeitpunkt im Block (inklusive), z. B. 15:59:59.999.
  DateTime get blockEndInclusive =>
      blockEndExclusive.subtract(const Duration(milliseconds: 1));
}

abstract final class TimeUtils {
  TimeUtils._();

  /// Gibt den 2-Stunden-Block zurück, in den [dateTime] fällt.
  ///
  /// Blöcke: 0–1, 2–3, …, 22–23 (Start immer gerade Stunde).
  /// Beispiel: 15:30 → Block 14:00:00 bis (exkl.) 16:00:00.
  static TwoHourBlockRange getTwoHourBlockRange(DateTime dateTime) {
    final hour = dateTime.hour;
    final blockStartHour = (hour ~/ 2) * 2;
    final blockStart = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      blockStartHour,
      0,
      0,
      0,
    );
    final blockEndExclusive = blockStart.add(const Duration(hours: 2));
    return TwoHourBlockRange(
      blockStart: blockStart,
      blockEndExclusive: blockEndExclusive,
    );
  }

  /// Gibt [true] zurück, wenn [a] und [b] im selben 2-Stunden-Fenster liegen.
  static bool isSameTwoHourBlock(DateTime a, DateTime b) {
    return getTwoHourBlockRange(a).blockStart == getTwoHourBlockRange(b).blockStart;
  }

  /// Aktuelle **volle Kalenderstunde** (lokal): [start] inkl., [endExclusive] exkl.
  /// (z. B. 14:37 → von 14:00:00 bis vor 15:00:00).
  static ({DateTime start, DateTime endExclusive}) getCurrentFullHourRange(
    DateTime dateTime,
  ) {
    final local = dateTime.toLocal();
    final start = DateTime(local.year, local.month, local.day, local.hour, 0, 0, 0);
    return (
      start: start,
      endExclusive: start.add(const Duration(hours: 1)),
    );
  }

  /// Erste volle Stunde **strikt nach** [now] (lokal), z. B. 13:05 → 14:00:00,
  /// 14:00:00.000 → 15:00:00 (für Hinweise „ab nächster voller Stunde“).
  static DateTime nextFullHourAfterNow(DateTime now) {
    final local = now.toLocal();
    final floor = DateTime(local.year, local.month, local.day, local.hour, 0, 0, 0);
    return floor.add(const Duration(hours: 1));
  }
}
