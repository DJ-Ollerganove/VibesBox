/// Relative Zeitangaben konsistent zur **angezeigten** Uhrzeit (HH:mm).
///
/// Es werden nur volle Kalender-Minuten verglichen (Sekunden/Millisekunden ignorieren).
/// Zwei Zeitpunkte in derselben Minute (z. B. 15:09:02 und 15:09:55) ⇒ Differenz **0** –
/// dieselbe relative Stufe (z. B. „Gerade eben“). Erst ab der nächsten Systemminute
/// (15:10) wird für Wünsche von 15:09 die Stufe „seit 1 Min.“ verwendet.
class RelativeTimeMinutes {
  RelativeTimeMinutes._();

  /// Volle Kalender-Minuten zwischen [event] und [now] (jeweils auf Minute trunciert).
  ///
  /// Negativ, falls [event] nach [now] liegt (Zukunft / Uhrkorrektur).
  static int elapsedCalendarMinutes(DateTime event, DateTime now) {
    final e = DateTime(event.year, event.month, event.day, event.hour, event.minute);
    final n = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return n.difference(e).inMinutes;
  }
}
