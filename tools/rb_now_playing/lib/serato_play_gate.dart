import 'rekordbox_history.dart';
import 'rekordbox_live.dart';

/// So lange wartet Sync auf den Live-Status, bevor die History gilt.
const seratoRemoteGrace = Duration(seconds: 12);

class SeratoDeckLive {
  SeratoDeckLive(this.deckId);

  final int deckId;
  String title = '';
  String artist = '';
  double playRate = 0;
  double positionSeconds = 0;
  double bpm = 0;

  bool get playing => playRate.abs() > 0.001 && title.trim().isNotEmpty;

  SeratoDeckLive copy() {
    return SeratoDeckLive(deckId)
      ..title = title
      ..artist = artist
      ..playRate = playRate
      ..positionSeconds = positionSeconds
      ..bpm = bpm;
  }
}

/// Merkt sich, seit wann ein Deck wirklich läuft, und gibt den Song erst
/// nach der eingestellten Wartezeit frei.
class SeratoPlayClock {
  final Map<String, DateTime> _started = {};

  void clear() => _started.clear();

  LiveSnapshot apply({
    required LiveSnapshot snapshot,
    required bool holdsHistory,
    required List<SeratoDeckLive> decks,
    required int delaySeconds,
    required DateTime now,
  }) {
    if (!holdsHistory) {
      _started.clear();
      return snapshot;
    }
    final delay = Duration(seconds: delaySeconds.clamp(0, 60));
    final playingKeys = <String>{};
    SeratoDeckLive? chosen;
    DateTime? chosenStart;
    for (final deck in decks) {
      if (!deck.playing) continue;
      final key =
          '${deck.deckId}|${deck.title.trim().toLowerCase()}|${deck.artist.trim().toLowerCase()}';
      playingKeys.add(key);
      _started.putIfAbsent(key, () => now);
      final start = _started[key]!;
      if (now.difference(start) >= delay) {
        if (chosenStart == null || start.isAfter(chosenStart)) {
          chosen = deck;
          chosenStart = start;
        }
      }
    }
    _started.removeWhere((key, _) => !playingKeys.contains(key));
    if (chosen == null || chosenStart == null) {
      return snapshot.asIdle();
    }
    return LiveSnapshot(
      history: HistorySnapshot(
        dbPath: snapshot.history.dbPath,
        historyName: snapshot.history.historyName,
        tracks: [_matchHistory(snapshot.history, chosen, chosenStart)],
        recent: snapshot.history.recent,
        readAt: snapshot.history.readAt,
      ),
      readAt: snapshot.readAt,
    );
  }
}

HistoryTrack _matchHistory(
  HistorySnapshot history,
  SeratoDeckLive deck,
  DateTime started,
) {
  final title = deck.title.trim();
  final artist = deck.artist.trim();
  HistoryTrack? titleHit;
  for (final track in history.tracks) {
    if (track.title.trim().toLowerCase() != title.toLowerCase()) continue;
    titleHit ??= track;
    if (artist.isEmpty ||
        track.artist.trim().isEmpty ||
        track.artist.trim().toLowerCase() == artist.toLowerCase()) {
      return track;
    }
  }
  if (titleHit != null) return titleHit;
  return HistoryTrack(
    trackNo: deck.deckId,
    title: title,
    artist: artist,
    playedAt: started,
    historyName: history.historyName ?? '',
    bpm: deck.bpm > 0 ? deck.bpm : null,
    musicalKey: null,
    length: null,
  );
}

/// true, solange der Live-Status entscheidet und die History noch nicht gilt.
bool seratoHoldsHistory({
  required bool armed,
  required bool paired,
  required bool advertiseFailed,
  required DateTime? advertisingSince,
  required DateTime? lastStatusAt,
  required DateTime now,
}) {
  if (!armed || advertiseFailed) return false;
  if (paired) return true;
  final last = lastStatusAt;
  if (last != null && now.difference(last) < seratoRemoteGrace) return true;
  final since = advertisingSince;
  if (since == null) return true;
  return now.difference(since) < seratoRemoteGrace;
}
