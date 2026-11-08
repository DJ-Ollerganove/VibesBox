import 'package:flutter_test/flutter_test.dart';
import 'package:rb_now_playing/heard_session.dart';
import 'package:rb_now_playing/rekordbox_history.dart';

HistoryTrack _track(int no, String title, {Duration? length, DateTime? at}) {
  return HistoryTrack(
    trackNo: no,
    title: title,
    artist: 'A',
    playedAt: at ?? DateTime.utc(2026, 10, 25, 12, no),
    historyName: 'HISTORY',
    bpm: null,
    musicalKey: null,
    length: length,
  );
}

void main() {
  test('langer erster Titel bleibt so lange sichtbar wie er läuft', () {
    final mix = _track(1, '80er Partymix', length: const Duration(minutes: 27));
    final start = DateTime.utc(2026, 10, 25, 13, 31);
    final playing = mix;
    expect(
      historyHeadIsIdle(
        HistoryTrack(
          trackNo: playing.trackNo,
          title: playing.title,
          artist: playing.artist,
          playedAt: start,
          historyName: playing.historyName,
          bpm: null,
          musicalKey: null,
          length: playing.length,
        ),
        start.add(const Duration(minutes: 20)),
      ),
      isFalse,
    );
    expect(
      historyHeadIsIdle(
        HistoryTrack(
          trackNo: playing.trackNo,
          title: playing.title,
          artist: playing.artist,
          playedAt: start,
          historyName: playing.historyName,
          bpm: null,
          musicalKey: null,
          length: playing.length,
        ),
        start.add(const Duration(minutes: 30)),
      ),
      isTrue,
    );
  });

  test('kurzer Titel wird nach 10 Minuten nicht mehr als laufend geführt', () {
    final start = DateTime.utc(2026, 10, 25, 14, 5);
    final track = _track(6, 'There Is A Party', length: const Duration(minutes: 3), at: start);
    expect(historyHeadIsIdle(track, start.add(const Duration(minutes: 9))), isFalse);
    expect(historyHeadIsIdle(track, start.add(const Duration(minutes: 11))), isTrue);
  });

  test('fehlende History-Titel kommen ältester zuerst, der erste bleibt dabei', () {
    final first = _track(1, '80er Partymix');
    final mid = _track(2, 'Mi Gente');
    final last = _track(3, 'Mamacita');
    final missing = missingSessionTracks(
      heardIdentities: [last.identity],
      historyNewestFirst: [last, mid, first],
    );
    expect(missing.map((t) => t.title).toList(), ['80er Partymix', 'Mi Gente']);
  });

  test('Party-Songs kommen ältester zuerst, nur einmal', () {
    final tracks = partyHeardTracks(const [
      {'title': 'Neu', 'artist': 'B'},
      {'title': 'Alt', 'artist': 'A'},
      {'title': 'Neu', 'artist': 'B'},
      {'title': '  ', 'artist': 'C'},
    ]);
    expect(tracks.map((t) => t.title).toList(), ['Alt', 'Neu']);
    expect(tracks.last.artist, 'B');
    expect(tracks.first.historyName, 'party');
  });
}
