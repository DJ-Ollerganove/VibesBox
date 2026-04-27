import 'package:string_similarity/string_similarity.dart';

import 'text_utils.dart';

/// Ergebnis des Abgleichs „neuer Scan vs. letzter History-Track“.
class HistoryLastTrackDedupAnalysis {
  HistoryLastTrackDedupAnalysis({
    required this.avgSimilarity,
    required this.elapsedSinceLast,
    required this.isHighSimilarityMatch,
    required this.isWithinCooldownWindow,
  });

  /// Durchschnitt aus Titel- und Artist-Ähnlichkeit (0–1) nach Normalisierung.
  final double avgSimilarity;

  /// Zeit seit dem Timestamp des letzten gespeicherten Tracks.
  final Duration elapsedSinceLast;

  /// [avgSimilarity] ≥ [HistoryLastTrackDedup.sameSongSimilarityMin].
  final bool isHighSimilarityMatch;

  /// Liegt unter [HistoryLastTrackDedup.minGapBeforeRepeatSameSong].
  final bool isWithinCooldownWindow;

  /// Überspringen nur wenn „gleicher Song“ **und** noch im Zeitfenster.
  bool get shouldSkip => isHighSimilarityMatch && isWithinCooldownWindow;
}

/// Logik für „gleicher Song wie der letzte History-Eintrag“ (Musikerkennung,
/// minimale Metadaten-Abweichungen). Unabhängig vom Admin-[duplicate_threshold]:
/// hier fester Vergleich nach [normalizeTextForDuplicateCheck].
class HistoryLastTrackDedup {
  HistoryLastTrackDedup._();

  /// Nach Normalisierung: Durchschnitt aus Titel- und Artist-Ähnlichkeit ab diesem
  /// Wert gilt der Treffer als „derselbe Song“ wie der letzte Eintrag.
  static const double sameSongSimilarityMin = 0.90;

  /// Derselbe Song darf erst wieder geschrieben werden, wenn mindestens so viel
  /// Zeit seit dem letzten Eintrag vergangen ist (z. B. Song zu Party-Anfang und -Ende).
  static const Duration minGapBeforeRepeatSameSong = Duration(minutes: 2, seconds: 30);

  /// Vollständige Auswertung für Logging (Match-Quote, Zeitfenster).
  static HistoryLastTrackDedupAnalysis analyzeRapidRepeatOfLast({
    required String newTitle,
    required String newArtist,
    required String lastTitle,
    required String lastArtist,
    required DateTime lastTimestamp,
    required List<String>? ignoredKeywords,
    DateTime? now,
  }) {
    final nt = normalizeTextForDuplicateCheck(newTitle, ignoredKeywords);
    final na = normalizeTextForDuplicateCheck(newArtist, ignoredKeywords);
    final lt = normalizeTextForDuplicateCheck(lastTitle, ignoredKeywords);
    final la = normalizeTextForDuplicateCheck(lastArtist, ignoredKeywords);

    final titleSim = StringSimilarity.compareTwoStrings(nt, lt);
    final artistSim = StringSimilarity.compareTwoStrings(na, la);
    final avg = (titleSim + artistSim) / 2.0;

    final clock = now ?? DateTime.now();
    final elapsed = clock.difference(lastTimestamp);

    return HistoryLastTrackDedupAnalysis(
      avgSimilarity: avg,
      elapsedSinceLast: elapsed,
      isHighSimilarityMatch: avg >= sameSongSimilarityMin,
      isWithinCooldownWindow: elapsed < minGapBeforeRepeatSameSong,
    );
  }

  /// Ob ein neuer Track verworfen werden soll, weil er dem letzten Eintrag zu ähnlich ist
  /// und die Zeit seit [lastTimestamp] noch unter [minGapBeforeRepeatSameSong] liegt.
  static bool shouldSkipAsRapidRepeatOfLast({
    required String newTitle,
    required String newArtist,
    required String lastTitle,
    required String lastArtist,
    required DateTime lastTimestamp,
    required List<String>? ignoredKeywords,
    DateTime? now,
  }) {
    return analyzeRapidRepeatOfLast(
      newTitle: newTitle,
      newArtist: newArtist,
      lastTitle: lastTitle,
      lastArtist: lastArtist,
      lastTimestamp: lastTimestamp,
      ignoredKeywords: ignoredKeywords,
      now: now,
    ).shouldSkip;
  }
}
