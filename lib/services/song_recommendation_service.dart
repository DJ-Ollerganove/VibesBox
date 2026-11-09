import 'dart:async';

import '../models/song_recommendation.dart';
import '../utils/debug_log.dart';
import '../utils/text_utils.dart';
import 'music_search_rules_service.dart';
import 'music_search_sources.dart';
import 'openai_music_proxy_service.dart';
import 'pro_feature_guard.dart';
import 'recommendation_cache_service.dart';
import 'song_recommendation_settings_service.dart';

/// Prototyp: Folgevorschläge nach Musikerkennung via OpenAI (gpt-4o-mini).
class SongRecommendationService {
  SongRecommendationService._();

  static final SongRecommendationService instance =
      SongRecommendationService._();

  /// Cache-Bump: Anzahl der Vorschläge kommt aus den DJ-Einstellungen.
  static const _promptRev = 'a16';
  static const _versionKeywords = <String>[
    ...kIgnoredKeywordsDefault,
    'Live',
    'Acoustic',
    'Unplugged',
    'Instrumental',
    'Karaoke',
    'Remaster',
    'Remastered',
    'Deluxe',
    'Bonus',
    'Original',
    'Reprise',
    'Cover',
    'Mashup',
    'Bootleg',
    'Dub',
    'Demo',
    'Session',
    'Concert',
    'Tour',
    'Mono',
    'Stereo',
  ];
  static final _featSplit = RegExp(
    r'\s+(feat\.?|ft\.?|featuring|&|/|,)\s+',
    caseSensitive: false,
  );

  static const _maxShownSeedKeys = 10;
  static const _maxShownItemsPerSeed = 20;

  final Map<String, Future<List<SongRecommendation>>> _inflight =
      <String, Future<List<SongRecommendation>>>{};
  final Map<String, Set<String>> _shownWorkKeys = <String, Set<String>>{};
  final Map<String, List<SongRecommendation>> _shownItems =
      <String, List<SongRecommendation>>{};

  /// RAM freigeben, wenn Musikerkennung aus ist (Prefs-Cache bleibt begrenzt).
  void clearRuntimeCaches() {
    _inflight.clear();
    _shownWorkKeys.clear();
    _shownItems.clear();
    RecommendationCacheService.instance.clearMemory();
  }

  Future<List<SongRecommendation>> suggestForRecognizedSong({
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    bool refresh = false,
    List<SongRecommendation> alreadyShown = const <SongRecommendation>[],
  }) async {
    final t = title.trim();
    final a = artist.trim();
    if (t.isEmpty || a.isEmpty || t == '-' || a == '-') {
      return const <SongRecommendation>[];
    }

    if (!ProFeatureGuard.canUseProExclusiveNow()) {
      return const <SongRecommendation>[];
    }

    final settings =
        await SongRecommendationSettingsService.instance.ensureLoaded();
    if (!settings.enabled) return const <SongRecommendation>[];
    await MusicSearchRulesService.instance.ensureReady();
    final rules = MusicSearchRulesService.instance.current;
    if (!rules.enabled) return const <SongRecommendation>[];

    final extra = _cacheExtra(settings);
    final shownKey = _shownKey(t, a, extra);
    if (alreadyShown.isNotEmpty) {
      _rememberShown(shownKey, alreadyShown);
    }

    if (!refresh && !rules.queriesCatalog) {
      final ram = RecommendationCacheService.instance.peekMemory(
        artist: a,
        title: t,
        extra: extra,
      );
      if (ram != null && ram.isNotEmpty) {
        _rememberShown(shownKey, ram);
        return ram;
      }
    }

    final cacheKey = RecommendationCacheService.keyFor(
      artist: a,
      title: t,
      extra: extra,
    );
    final inflightKey = refresh ? '$cacheKey|r${_shownCount(shownKey)}' : cacheKey;
    final existing = _inflight[inflightKey];
    if (existing != null) return existing;

    final future = _suggestUncached(
          title: t,
          artist: a,
          bpm: bpm,
          camelot: camelot,
          settings: settings,
          extra: extra,
          shownKey: shownKey,
          refresh: refresh,
        )
        .timeout(Duration(seconds: (16 + settings.count).clamp(24, 40)))
        .catchError((Object e) {
          debugLog('SongRecommendationService: $e');
          return const <SongRecommendation>[];
        });
    _inflight[inflightKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(inflightKey);
    }
  }

  static bool sameWork({
    required String titleA,
    required String artistA,
    required String titleB,
    required String artistB,
  }) {
    return _isSameWork(
      titleA: titleA,
      artistA: artistA,
      titleB: titleB,
      artistB: artistB,
    );
  }

  Future<List<SongRecommendation>> _suggestUncached({
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    required SongRecommendationSettings settings,
    required String extra,
    required String shownKey,
    required bool refresh,
  }) async {
    final rules = MusicSearchRulesService.instance.current;
    if (!refresh && !rules.queriesCatalog) {
      final cached = await RecommendationCacheService.instance.read(
        artist: artist,
        title: title,
        extra: extra,
      );
      if (cached != null && cached.isNotEmpty) {
        _rememberShown(shownKey, cached);
        return cached;
      }
    }

    final exclude = List<SongRecommendation>.from(
      _shownItems[shownKey] ?? const <SongRecommendation>[],
    );
    final need = settings.count.clamp(1, rules.maxCount);
    final items = await _byRules(
      title: title,
      artist: artist,
      bpm: bpm,
      camelot: camelot,
      settings: settings,
      rules: rules,
      exclude: exclude,
      need: need,
      skipRecommended: refresh,
    );

    if (items.length < need) {
      debugLog(
        'SongRecommendationService: only ${items.length}/$need',
      );
    }
    if (items.isEmpty) return const <SongRecommendation>[];

    if (items.length >= need) {
      _rememberShown(shownKey, items);
      await RecommendationCacheService.instance.write(
        artist: artist,
        title: title,
        items: items,
        extra: extra,
      );
    }
    return items;
  }

  Future<List<SongRecommendation>> _fromOpenAi({
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    required SongRecommendationSettings settings,
    List<SongRecommendation> exclude = const <SongRecommendation>[],
  }) async {
    try {
      final raw = await OpenaiMusicProxyService.instance.recommend(
        title: title,
        artist: artist,
        bpm: bpm,
        camelot: camelot,
        scope: settings.scope.name,
        familiarity: settings.familiarity.name,
        allowSameArtist: settings.allowSameArtist,
        count: settings.count,
        exclude: exclude
            .take(20)
            .map(
              (e) => <String, String>{
                'title': e.title,
                'artist': e.artist,
              },
            )
            .toList(),
      );
      final out = <SongRecommendation>[];
      final cap = settings.count + 3;
      for (final map in raw) {
        final rec = SongRecommendation.fromJson(map);
        if (rec.title.isEmpty || rec.artist.isEmpty) continue;
        out.add(rec);
        if (out.length >= cap) break;
      }
      return out;
    } catch (e) {
      debugLog('SongRecommendationService proxy: $e');
      return const <SongRecommendation>[];
    }
  }

  static String _cacheExtra(SongRecommendationSettings settings) =>
      '${settings.cacheSuffix}_${MusicSearchRulesService.instance.fingerprint}_$_promptRev';

  Future<List<SongRecommendation>> _byRules({
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    required SongRecommendationSettings settings,
    required MusicSearchRules rules,
    required List<SongRecommendation> exclude,
    required int need,
    required bool skipRecommended,
  }) async {
    final out = <SongRecommendation>[];
    final sameCap = rules.applyFilters ? settings.maxSameArtistCount : need;
    var sameArtist = 0;
    var followSongs = const <SongRecommendation>[];
    var playedCounts = const <String, int>{};
    if (rules.steps.contains('played_after') ||
        rules.steps.contains('recommended')) {
      final follow = await MusicSearchSources.followUps(
        title: title,
        artist: artist,
      );
      followSongs = follow.songs;
      playedCounts = follow.counts;
    }

    void take(Iterable<SongRecommendation> rows) {
      for (final row in rows) {
        if (out.length >= need) return;
        if (_isSameWork(
          titleA: title,
          artistA: artist,
          titleB: row.title,
          artistB: row.artist,
        )) {
          continue;
        }
        if (exclude.any(
          (shown) => _isSameWork(
            titleA: shown.title,
            artistA: shown.artist,
            titleB: row.title,
            artistB: row.artist,
          ),
        )) {
          continue;
        }
        if (out.any(
          (shown) => _isSameWork(
            titleA: shown.title,
            artistA: shown.artist,
            titleB: row.title,
            artistB: row.artist,
          ),
        )) {
          continue;
        }
        final same = _artistsClose(_artistCore(artist), _artistCore(row.artist));
        if (same && sameArtist >= sameCap) continue;
        if (same) sameArtist += 1;
        out.add(row);
      }
    }

    for (final step in rules.steps) {
      if (out.length >= need) break;
      if (step == 'played_after') {
        take(followSongs);
      } else if (step == 'recommended') {
        if (skipRecommended) continue;
        final stored = await MusicSearchSources.recommended(
          title: title,
          artist: artist,
          playedCounts: playedCounts,
        );
        take(stored);
      } else if (step == 'ki') {
        final gap = (need - out.length).clamp(1, rules.kiMax);
        var more = await _fromOpenAi(
          title: title,
          artist: artist,
          bpm: bpm,
          camelot: camelot,
          settings: settings.copyWith(count: gap),
          exclude: <SongRecommendation>[...exclude, ...out],
        );
        more = _withoutSeed(more, title: title, artist: artist);
        take(more);
        if (out.length < need) {
          final fill = await _fromOpenAi(
            title: title,
            artist: artist,
            bpm: bpm,
            camelot: camelot,
            settings: settings.copyWith(count: (need - out.length).clamp(1, rules.kiMax)),
            exclude: <SongRecommendation>[...exclude, ...out],
          );
          take(_withoutSeed(fill, title: title, artist: artist));
        }
      }
    }
    return out;
  }

  static String _shownKey(String title, String artist, String extra) =>
      '${title.toLowerCase()}|${artist.toLowerCase()}|$extra';

  int _shownCount(String shownKey) => _shownWorkKeys[shownKey]?.length ?? 0;

  void _rememberShown(String shownKey, List<SongRecommendation> items) {
    final keys = _shownWorkKeys.putIfAbsent(shownKey, () => <String>{});
    final list = _shownItems.putIfAbsent(
      shownKey,
      () => <SongRecommendation>[],
    );
    for (final e in items) {
      final key = _workKey(e.title, e.artist);
      if (key.isEmpty || keys.contains(key)) continue;
      keys.add(key);
      list.add(e);
    }
    while (list.length > _maxShownItemsPerSeed) {
      final removed = list.removeAt(0);
      keys.remove(_workKey(removed.title, removed.artist));
    }
    _trimShownSeeds();
  }

  void _trimShownSeeds() {
    while (_shownWorkKeys.length > _maxShownSeedKeys) {
      final oldest = _shownWorkKeys.keys.first;
      _shownWorkKeys.remove(oldest);
      _shownItems.remove(oldest);
    }
  }

  static List<SongRecommendation> _withoutSeed(
    List<SongRecommendation> items, {
    required String title,
    required String artist,
  }) {
    return items
        .where(
          (e) => !_isSameWork(
            titleA: title,
            artistA: artist,
            titleB: e.title,
            artistB: e.artist,
          ),
        )
        .toList();
  }

  static String _titleNorm(String raw) {
    return normalizeTextForDuplicateCheck(raw, _versionKeywords);
  }

  static String _titleCore(String raw) {
    return _titleNorm(raw).replaceAll(' ', '');
  }

  static bool _titlesAreSameWork(String titleA, String titleB) {
    final na = _titleNorm(titleA);
    final nb = _titleNorm(titleB);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final ca = na.replaceAll(' ', '');
    final cb = nb.replaceAll(' ', '');
    if (ca == cb) return true;
    if (_wordsContainedInOrder(na, nb) || _wordsContainedInOrder(nb, na)) {
      return true;
    }
    if (ca.length >= 8 && cb.length >= 8 && (ca.contains(cb) || cb.contains(ca))) {
      return true;
    }
    return false;
  }

  /// Alle inhaltlichen Wörter des kürzeren Titels kommen in Reihenfolge im längeren vor.
  static bool _wordsContainedInOrder(String shorter, String longer) {
    final sw = shorter.split(' ').where((w) => w.length >= 3).toList();
    final lw = longer.split(' ').where((w) => w.length >= 3).toList();
    if (sw.length < 2 || lw.length < sw.length) return false;
    var i = 0;
    for (final w in lw) {
      if (i < sw.length && w == sw[i]) i++;
    }
    return i == sw.length;
  }

  static String _workKey(String title, String artist) {
    final t = _titleCore(title);
    final a = _artistCore(artist);
    if (t.isEmpty) return '';
    return '$t|$a';
  }

  static bool _isSameWork({
    required String titleA,
    required String artistA,
    required String titleB,
    required String artistB,
  }) {
    final aa = _artistCore(artistA);
    final ab = _artistCore(artistB);
    final artistsClose = _artistsClose(aa, ab);
    if (_titlesAreSameWork(titleA, titleB)) {
      if (artistsClose) return true;
      return _titleCore(titleA).length >= 10;
    }
    return artistsClose && _isTitleScramble(titleA, titleB);
  }

  static bool _artistsClose(String aa, String ab) {
    if (aa.isEmpty || ab.isEmpty) return false;
    if (aa == ab) return true;
    return aa.length >= 4 &&
        ab.length >= 4 &&
        (aa.contains(ab) || ab.contains(aa));
  }

  /// Gleiche Wörter in anderer Reihenfolge oder Fast-Anagramm (Take On Me / Tame Me On).
  static bool _isTitleScramble(String titleA, String titleB) {
    final na = _titleNorm(titleA);
    final nb = _titleNorm(titleB);
    if (na.isEmpty || nb.isEmpty || na == nb) return false;
    final wa = na.split(' ').where((w) => w.length >= 2).toList();
    final wb = nb.split(' ').where((w) => w.length >= 2).toList();
    if (wa.length >= 2 &&
        wa.length == wb.length &&
        _fuzzyWordBagsMatch(wa, wb)) {
      return true;
    }
    final ca = na.replaceAll(' ', '');
    final cb = nb.replaceAll(' ', '');
    if (ca.length < 6 || cb.length < 6) return false;
    if ((ca.length - cb.length).abs() > 2) return false;
    final sa = (ca.split('')..sort()).join();
    final sb = (cb.split('')..sort()).join();
    return _levenshteinAtMost(sa, sb, 2) >= 0;
  }

  static bool _fuzzyWordBagsMatch(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final used = List<bool>.filled(b.length, false);
    for (final word in a) {
      var found = -1;
      var best = 99;
      for (var i = 0; i < b.length; i++) {
        if (used[i]) continue;
        final maxDist = word.length <= 3 ? 0 : 1;
        final d = _levenshteinAtMost(word, b[i], maxDist);
        if (d < 0 || d > maxDist || d >= best) continue;
        best = d;
        found = i;
        if (d == 0) break;
      }
      if (found < 0) return false;
      used[found] = true;
    }
    return true;
  }

  /// Levenshtein, oder -1 wenn größer als [maxDist].
  static int _levenshteinAtMost(String a, String b, int maxDist) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > maxDist) return -1;
    if (a.isEmpty) return b.length <= maxDist ? b.length : -1;
    if (b.isEmpty) return a.length <= maxDist ? a.length : -1;
    final rows = a.length + 1;
    final cols = b.length + 1;
    var prev = List<int>.generate(cols, (i) => i);
    var curr = List<int>.filled(cols, 0);
    for (var i = 1; i < rows; i++) {
      curr[0] = i;
      var rowMin = curr[0];
      for (var j = 1; j < cols; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (curr[j] < rowMin) rowMin = curr[j];
      }
      if (rowMin > maxDist) return -1;
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    final d = prev[b.length];
    return d <= maxDist ? d : -1;
  }

  static String _artistCore(String raw) {
    var s = raw.toLowerCase().trim();
    if (s.isEmpty) return '';
    s = s.split(_featSplit).first.trim();
    s = s.replaceFirst(RegExp(r'^the\s+'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }
}
