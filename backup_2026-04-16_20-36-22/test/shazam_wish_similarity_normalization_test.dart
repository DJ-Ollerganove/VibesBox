import 'package:flutter_test/flutter_test.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:vibesbox/utils/text_utils.dart';

/// Dokumentiert den Effekt der Normalisierung für den Wunsch-Abgleich
/// (_checkAndUpdateWishes): gleicher Admin-Threshold aus Firestore, aber
/// höhere StringSimilarity nach normalizeTextForDuplicateCheck.
void main() {
  const ignored = kIgnoredKeywordsDefault;

  group('Y.M.C.A. vs YMCA (Titel)', () {
    const recognized = 'Y.M.C.A.';
    const wish = 'YMCA';

    test('ohne Duplikat-Normalisierung: keine 100%-Übereinstimmung', () {
      final raw = StringSimilarity.compareTwoStrings(
        recognized.toLowerCase(),
        wish.toLowerCase(),
      );
      // Nur toLowerCase: Punkte bleiben → gleicher Admin-Threshold würde oft nicht reichen
      expect(raw, lessThan(1.0));
    });

    test('mit normalizeTextForDuplicateCheck: Titel-Ähnlichkeit = 100%', () {
      final a = normalizeTextForDuplicateCheck(recognized, ignored);
      final b = normalizeTextForDuplicateCheck(wish, ignored);
      expect(a, 'ymca');
      expect(b, 'ymca');
      final sim = StringSimilarity.compareTwoStrings(a, b);
      expect(sim, 1.0);
    });
  });

  group('Whitespace', () {
    test('mehrfache Leerzeichen kollabieren vor dem Vergleich', () {
      final a = normalizeTextForDuplicateCheck('Foo    Bar', ignored);
      final b = normalizeTextForDuplicateCheck('Foo Bar', ignored);
      expect(a, b);
      expect(
        StringSimilarity.compareTwoStrings(a, b),
        1.0,
      );
    });
  });

  /// Wie [_checkAndUpdateWishes]: Durchschnitt aus Titel- und Artist-StringSimilarity,
  /// nach [normalizeTextForDuplicateCheck] auf beiden Seiten (Admin-Threshold Default 0.85).
  group('Reales App-Szenario (Wunsch vs. Erkennung)', () {
    const standardThreshold = 0.85;

    test(
      'YMCA / Village People vs. Y.M.C.A. / The Village People: avg > 0.85',
      () {
        // Wunsch
        const wishTitle = 'YMCA';
        const wishArtist = 'Village People';
        // Shazam-Erkennung
        const recognizedTitle = 'Y.M.C.A.';
        const recognizedArtist = 'The Village People';

        final nt = normalizeTextForDuplicateCheck(wishTitle, ignored);
        final na = normalizeTextForDuplicateCheck(wishArtist, ignored);
        final rt = normalizeTextForDuplicateCheck(recognizedTitle, ignored);
        final ra = normalizeTextForDuplicateCheck(recognizedArtist, ignored);

        final titleSimilarity = StringSimilarity.compareTwoStrings(rt, nt);
        final artistSimilarity = StringSimilarity.compareTwoStrings(ra, na);
        final avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

        expect(titleSimilarity, 1.0, reason: 'normalisiert: $rt vs $nt');
        expect(
          avgSimilarity,
          greaterThan(standardThreshold),
          reason:
              'title=$titleSimilarity artist=$artistSimilarity avg=$avgSimilarity',
        );
      },
    );
  });
}
