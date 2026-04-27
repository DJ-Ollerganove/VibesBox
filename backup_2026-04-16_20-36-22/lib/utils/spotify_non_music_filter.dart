/// Filter für Spotify-Suchergebnisse: keine Hörspiele/Podcasts/Hörbücher in Wunschbox & DJ-Suche.
/// Konfiguration über [SpotifySearchSettingsService] bzw. [configure]; Logik parallel zu [functions/index.js].
class SpotifyNonMusicFilter {
  SpotifyNonMusicFilter._();

  static final List<String> _defaultKeywordSubstrings = [
    'hörspiel',
    'hörbuch',
    'podcast',
    'tkkg',
    'audiobook',
    'die drei ???',
    'bibi blocksberg',
    'storytelling',
  ];

  static List<String> _keywordSubstrings = List<String>.from(_defaultKeywordSubstrings);
  static int _maxTrackDurationMs = 15 * 60 * 1000;

  /// Synchron zu [SpotifySearchSettingsService] / Firestore [admin_config/spotify_settings].
  static void configure({
    required List<String> keywordSubstringsLower,
    required int maxTrackDurationMs,
  }) {
    _keywordSubstrings = List<String>.from(keywordSubstringsLower);
    _maxTrackDurationMs = maxTrackDurationMs;
  }

  static int get maxTrackDurationMs => _maxTrackDurationMs;

  static final RegExp _wordFolge = RegExp(r'\bfolge\b', caseSensitive: false);

  /// Genre-Strings (kleingeschrieben verglichen), die auf kein Song-Ergebnis passen sollen.
  static const List<String> _badGenreSubstrings = [
    "children's story",
    'childrens story',
    'audiobook',
    'storytelling',
  ];

  static bool _haystackHasKeywordSubstrings(String haystackLower) {
    for (final k in _keywordSubstrings) {
      if (haystackLower.contains(k)) return true;
    }
    if (_wordFolge.hasMatch(haystackLower)) return true;
    return false;
  }

  static bool _genresIndicateNonMusic(List<String> genresLower) {
    for (final g in genresLower) {
      for (final bad in _badGenreSubstrings) {
        if (g.contains(bad)) return true;
      }
    }
    return false;
  }

  /// [artists] z. B. „Artist1, Artist2“; [album] optional; [genres] aus API falls vorhanden.
  static bool shouldExcludeTrack({
    required String name,
    required String artists,
    String album = '',
    int? durationMs,
    List<String> genres = const [],
  }) {
    if (durationMs != null && durationMs > _maxTrackDurationMs) {
      return true;
    }
    final haystack =
        '${name.toLowerCase()} ${album.toLowerCase()} ${artists.toLowerCase()}';
    if (_haystackHasKeywordSubstrings(haystack)) {
      return true;
    }
    if (genres.isNotEmpty) {
      final gl = genres.map((e) => e.toLowerCase()).toList();
      if (_genresIndicateNonMusic(gl)) return true;
    }
    return false;
  }

  static bool shouldExcludeArtistName(String name) {
    final h = name.toLowerCase();
    return _haystackHasKeywordSubstrings(h);
  }
}
