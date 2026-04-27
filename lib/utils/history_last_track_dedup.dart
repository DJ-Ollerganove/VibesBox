import 'dart:math' show min;

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

  /// Effektive Ähnlichkeit (0–1): bei Titel+Künstler Minimum beider Strings, sonst Fallback.
  final double avgSimilarity;

  /// Zeit seit dem Timestamp des letzten gespeicherten Tracks.
  final Duration elapsedSinceLast;

  /// [avgSimilarity] (kombiniert) ≥ übergebenem Schwellwert (üblicherweise Admin duplicate_threshold).
  final bool isHighSimilarityMatch;

  /// Liegt unter [HistoryLastTrackDedup.minGapBeforeRepeatSameSong].
  final bool isWithinCooldownWindow;

  /// Überspringen nur wenn „gleicher Song“ **und** noch im Zeitfenster.
  bool get shouldSkip => isHighSimilarityMatch && isWithinCooldownWindow;
}

/// Logik für „gleicher Song wie der letzte History-Eintrag“ (Musikerkennung,
/// minimale Metadaten-Abweichungen). [similarityMin] kommt i. d. R. aus Admin
/// `party_settings/current.duplicate_threshold` (0–1).
class HistoryLastTrackDedup {
  HistoryLastTrackDedup._();

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
    required double similarityMin,
    DateTime? now,
  }) {
    final nt = normalizeTextForDuplicateCheck(newTitle, ignoredKeywords);
    final na = normalizeTextForDuplicateCheck(newArtist, ignoredKeywords);
    final lt = normalizeTextForDuplicateCheck(lastTitle, ignoredKeywords);
    final la = normalizeTextForDuplicateCheck(lastArtist, ignoredKeywords);

    final titleSim = StringSimilarity.compareTwoStrings(nt, lt);
    final artistSim = StringSimilarity.compareTwoStrings(na, la);
    final hasFullPair = nt.isNotEmpty && lt.isNotEmpty && na.isNotEmpty && la.isNotEmpty;
    final combined = hasFullPair
        ? min(titleSim, artistSim)
        : (() {
            if (nt.isNotEmpty && lt.isNotEmpty) return titleSim;
            if (na.isNotEmpty && la.isNotEmpty) return artistSim;
            return (titleSim + artistSim) / 2.0;
          })();

    final clock = now ?? DateTime.now();
    final elapsed = clock.difference(lastTimestamp);
    final minSim = similarityMin.clamp(0.5, 0.98);

    return HistoryLastTrackDedupAnalysis(
      avgSimilarity: combined,
      elapsedSinceLast: elapsed,
      isHighSimilarityMatch: combined >= minSim,
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
    required double similarityMin,
    DateTime? now,
  }) {
    return analyzeRapidRepeatOfLast(
      newTitle: newTitle,
      newArtist: newArtist,
      lastTitle: lastTitle,
      lastArtist: lastArtist,
      lastTimestamp: lastTimestamp,
      ignoredKeywords: ignoredKeywords,
      similarityMin: similarityMin,
      now: now,
    ).shouldSkip;
  }
}
