import 'rekordbox_history.dart';

const Duration nowPlayingIdleFloor = Duration(minutes: 10);
const Duration nowPlayingIdleCap = Duration(hours: 3);

/// Wie lange der History-Kopf noch als „läuft“ gilt.
/// Kurze Titel mindestens 10 Minuten, lange mindestens ihre Länge plus
/// zwei Minuten, nie länger als drei Stunden.
Duration nowPlayingHold(HistoryTrack track) {
  var limit = nowPlayingIdleFloor;
  final length = track.length;
  if (length != null && length > Duration.zero) {
    final untilEnd = length + const Duration(minutes: 2);
    if (untilEnd > limit) limit = untilEnd;
  }
  if (limit > nowPlayingIdleCap) return nowPlayingIdleCap;
  return limit;
}

bool historyHeadIsIdle(
  HistoryTrack? track,
  DateTime now, {
  bool ignorePlayedAt = false,
  DateTime? seenAt,
}) {
  if (track == null) return true;
  final seenAge = seenAt == null ? Duration.zero : now.difference(seenAt);
  if (ignorePlayedAt || track.playedAt == null) {
    return seenAge >= nowPlayingIdleFloor;
  }
  return now.difference(track.playedAt!) >= nowPlayingHold(track);
}

/// Party-History, neuester Eintrag zuerst. Ergebnis: ältester zuerst.
/// Leere Titel fallen weg. Derselbe Titel bleibt einmal, und zwar als letzter.
List<HistoryTrack> partyHeardTracks(List<Map<String, String>> newestFirst) {
  final picked = <({String title, String artist})>[];
  final seen = <String>{};
  for (final row in newestFirst) {
    final title = (row['title'] ?? '').trim();
    final artist = (row['artist'] ?? '').trim();
    if (title.isEmpty) continue;
    final key = '${title.toLowerCase()}|${artist.toLowerCase()}';
    if (!seen.add(key)) continue;
    picked.add((title: title, artist: artist));
  }
  final ordered = picked.reversed.toList();
  return [
    for (var i = 0; i < ordered.length; i++)
      HistoryTrack(
        trackNo: i + 1,
        title: ordered[i].title,
        artist: ordered[i].artist,
        playedAt: null,
        historyName: 'party',
        bpm: null,
        musicalKey: null,
        length: null,
      ),
  ];
}

/// Titel der laufenden History, die noch nicht in [heardIdentities] sind.
/// [historyNewestFirst] ist die History (neuester zuerst). Ergebnis: ältester zuerst.
List<HistoryTrack> missingSessionTracks({
  required Iterable<String> heardIdentities,
  required List<HistoryTrack> historyNewestFirst,
}) {
  final have = heardIdentities.toSet();
  final missing = <HistoryTrack>[];
  for (final track in historyNewestFirst.reversed) {
    if (track.title.trim().isEmpty) continue;
    if (!have.add(track.identity)) continue;
    missing.add(track);
  }
  return missing;
}
