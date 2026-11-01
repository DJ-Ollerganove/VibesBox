import 'package:flutter_test/flutter_test.dart';
import 'package:rb_now_playing/library_match.dart';

void main() {
  test('lateinische Titel behalten denselben Schlüssel', () {
    expect(identityTitleOf('Waka Waka (This Time For Africa)'), 'waka waka');
    expect(identityTitleOf('Take on Me'), 'take on me');
    expect(identityTitleOf('Danza Kuduro'), 'danza kuduro');
    expect(workKeyOf('A', 'Artist'), isEmpty);
    expect(workKeyOf('Stay', 'A-ha'), 'stay|aha');
  });

  test('griechische KI-Vorschläge werden nicht verworfen', () {
    expect(identityTitleOf('Θα σπάσω κούπες'), contains('κούπες'));
    expect(workKeyOf('Θα σπάσω κούπες', 'Ζουζούνια'), isNotEmpty);
    final shown = withoutSameAsPlaying(
      [
        {'title': 'Θα σπάσω κούπες', 'artist': 'Ζουζούνια'},
        {'title': 'Ah Kounelaki', 'artist': 'Zouzounia'},
      ],
      seedTitle: 'Ah Kounelaki',
      seedArtist: 'Zouzounia',
      keep: 5,
    );
    expect(shown.map((row) => row['title']).toList(), ['Θα σπάσω κούπες']);
  });

  test('höchstens zwei Songs eines Interpreten vom laufenden Credit', () {
    final rows = [
      {'title': 'Wie?', 'artist': 'AYLIVA'},
      {'title': 'Renn!', 'artist': 'AYLIVA'},
      {'title': 'Beifahrer', 'artist': 'AYLIVA'},
      {'title': 'Hässlich', 'artist': 'AYLIVA'},
      {'title': 'Au Revoir', 'artist': 'Mark Forster'},
    ];
    final capped = capSeedArtist(
      rows,
      seedArtist: 'AYLIVA, Apache 207',
      allowSameArtist: true,
    );
    expect(capped.map((row) => row['title']).toList(), [
      'Wie?',
      'Renn!',
      'Au Revoir',
    ]);
    final off = capSeedArtist(
      rows,
      seedArtist: 'AYLIVA, Apache 207',
      allowSameArtist: false,
    );
    expect(off.map((row) => row['artist']).toList(), ['Mark Forster']);
  });
}
