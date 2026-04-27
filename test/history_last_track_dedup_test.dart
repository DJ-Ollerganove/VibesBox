import 'package:flutter_test/flutter_test.dart';
import 'package:vibesbox/utils/history_last_track_dedup.dart';
import 'package:vibesbox/utils/text_utils.dart';

void main() {
  const ignored = kIgnoredKeywordsDefault;

  test('(Remastered) vs (Live): gleicher Kern → Skip bei kurzem Abstand', () {
    final lastTs = DateTime.now().subtract(const Duration(seconds: 30));

    expect(
      HistoryLastTrackDedup.shouldSkipAsRapidRepeatOfLast(
        newTitle: 'Song (Remastered 2024)',
        newArtist: 'Abba',
        lastTitle: 'Song (Live)',
        lastArtist: 'Abba',
        lastTimestamp: lastTs,
        ignoredKeywords: ignored,
        similarityMin: 0.90,
      ),
      isTrue,
    );
  });

  test('nach 3 Minuten: gleicher Song darf wieder rein', () {
    final lastTs = DateTime.now().subtract(const Duration(minutes: 3));

    expect(
      HistoryLastTrackDedup.shouldSkipAsRapidRepeatOfLast(
        newTitle: 'Y.M.C.A.',
        newArtist: 'Village People',
        lastTitle: 'YMCA',
        lastArtist: 'The Village People',
        lastTimestamp: lastTs,
        ignoredKeywords: ignored,
        similarityMin: 0.90,
      ),
      isFalse,
    );
  });
}
