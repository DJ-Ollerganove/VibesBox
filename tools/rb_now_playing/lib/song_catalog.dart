import 'camelot.dart';
import 'library_match.dart';
import 'mix_compat.dart';
import 'rekordbox_history.dart';
import 'song_track_id.dart';
import 'tool_session.dart';

class SongCatalogStore {
  SongCatalogStore(this._session);

  final ToolSession _session;

  Future<List<Map<String, dynamic>>?> readSuggestions(
    HistoryTrack seed, {
    required String scope,
    required String familiarity,
    required bool allowSameArtist,
  }) async {
    final token = await _session.freshIdTokenOrNull();
    if (token == null) return null;
    final docId = suggestionCacheDocId(
      artist: seed.artist,
      title: seed.title,
      scope: scope,
      familiarity: familiarity,
      allowSameArtist: allowSameArtist,
    );
    if (docId.isEmpty) return null;
    try {
      final doc = await _session.rest.getDocument(
        idToken: token,
        collection: 'song_suggestions',
        docId: docId,
      );
      if (doc == null) return null;
      final raw = doc['suggestions'];
      if (raw is! List || raw.isEmpty) return null;
      final out = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final title = (map['title'] ?? '').toString().trim();
        final artist = (map['artist'] ?? '').toString().trim();
        final uri = (map['spotify_uri'] ?? '').toString().trim();
        if (title.isEmpty || artist.isEmpty) continue;
        if (!uri.startsWith('spotify:')) continue;
        out.add({
          'title': title,
          'artist': artist,
          'version': (map['version'] ?? '').toString(),
          'track_id': (map['track_id'] ?? '').toString(),
          'spotify_uri': (map['spotify_uri'] ?? '').toString(),
          if (map['bpm'] is num) 'bpm': map['bpm'],
          if ((map['camelot'] ?? '').toString().trim().isNotEmpty)
            'camelot': map['camelot'].toString().trim(),
          if ((map['genre'] ?? '').toString().trim().isNotEmpty)
            'genre': map['genre'].toString().trim(),
        });
        if (out.length >= 20) break;
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSuggestions(
    HistoryTrack seed,
    List<Map<String, dynamic>> tracks, {
    required String scope,
    required String familiarity,
    required bool allowSameArtist,
  }) async {
    if (tracks.isEmpty) return;
    final token = await _session.freshIdTokenOrNull();
    if (token == null) return;
    final id = trackIdentityOf(artist: seed.artist, title: seed.title);
    final docId = suggestionCacheDocId(
      artist: seed.artist,
      title: seed.title,
      scope: scope,
      familiarity: familiarity,
      allowSameArtist: allowSameArtist,
    );
    if (id.id.isEmpty || docId.isEmpty) return;
    final suggestions = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in tracks) {
      if (item['fromTransition'] == true) continue;
      final title = (item['title'] ?? '').toString().trim();
      final artist = (item['artist'] ?? '').toString().trim();
      if (title.isEmpty || artist.isEmpty) continue;
      final split = splitTitleVersion(title);
      final key = workKeyOf(split.title, artist);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      final rowId = trackIdentityOf(artist: artist, title: title);
      suggestions.add({
        'track_id': (item['track_id'] ?? item['id'] ?? rowId.id).toString(),
        'artist': artist,
        'title': split.title,
        'version': (item['version'] ?? split.version).toString(),
        'spotify_uri': (item['spotify_uri'] ?? item['uri'] ?? '').toString(),
        if (item['bpm'] is num) 'bpm': item['bpm'],
        if ((item['camelot'] ?? '').toString().trim().isNotEmpty)
          'camelot': item['camelot'].toString().trim(),
        if ((item['genre'] ?? '').toString().trim().isNotEmpty)
          'genre': item['genre'].toString().trim(),
      });
      if (suggestions.length >= 20) break;
    }
    if (suggestions.isEmpty) return;
    try {
      await _session.rest.setDocument(
        idToken: token,
        collection: 'song_suggestions',
        docId: docId,
        data: {
          'artist': id.artist,
          'title': id.title,
          'version': id.version,
          'scope': scope,
          'familiarity': familiarity,
          'allowSameArtist': allowSameArtist,
          'created_at': DateTime.now().toUtc(),
          'suggestions': suggestions,
        },
      );
    } catch (_) {}
  }

  /// Genre/BPM-Pool (Cache/KI) nach echten Folgesongs sortieren.
  /// Ein Übergang ohne Mix-Metadaten kommt nur, wenn er schon im Pool liegt.
  Future<List<Map<String, dynamic>>> withTransitions(
    List<Map<String, dynamic>> pool,
    HistoryTrack seed, {
    required String scope,
    required bool allowSameArtist,
  }) async {
    final ranked = await _transitionTracks(seed);
    if (ranked.isEmpty) return pool;
    return rankByPlayedAfter(
      pool: pool,
      playedAfter: ranked,
      seedBpm: seed.bpm,
      seedCamelot: camelotFromScaleName(seed.musicalKey),
      seedArtist: seed.artist,
      scope: scope,
      allowSameArtist: allowSameArtist,
    );
  }

  Future<void> recordTransition({
    required HistoryTrack from,
    required HistoryTrack to,
    required String? softwareId,
  }) async {
    if (isSameWork(
      titleA: from.title,
      artistA: from.artist,
      titleB: to.title,
      artistB: to.artist,
    )) {
      return;
    }
    final token = await _session.freshIdTokenOrNull();
    if (token == null) return;
    final fromId = trackIdentityOf(artist: from.artist, title: from.title);
    final toId = trackIdentityOf(artist: to.artist, title: to.title);
    if (fromId.id.isEmpty || toId.id.isEmpty) return;
    try {
      await _session.rest.incrementTransition(
        idToken: token,
        fromId: fromId.id,
        toId: toId.id,
        fromArtist: fromId.artist,
        fromTitle: fromId.title,
        fromVersion: fromId.version,
        toArtist: toId.artist,
        toTitle: toId.title,
        toVersion: toId.version,
        toBpm: _mixBpm(to.bpm),
        toCamelot: camelotFromScaleName(to.musicalKey),
        software: metricsSoftwareId(softwareId),
        osKey: metricsOsKey(),
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _transitionTracks(HistoryTrack seed) async {
    final token = await _session.freshIdTokenOrNull();
    if (token == null) return const [];
    final id = trackIdentityOf(artist: seed.artist, title: seed.title);
    if (id.id.isEmpty) return const [];
    try {
      final doc = await _session.rest.getDocument(
        idToken: token,
        collection: 'song_transitions',
        docId: id.id,
      );
      final next = doc?['next_tracks'];
      if (next is! Map) return const [];
      final rows = <({int count, Map<String, dynamic> track})>[];
      for (final entry in next.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final map = Map<String, dynamic>.from(value);
        final title = (map['to_title'] ?? map['title'] ?? '').toString().trim();
        final artist =
            (map['to_artist'] ?? map['artist'] ?? '').toString().trim();
        if (title.isEmpty || artist.isEmpty) continue;
        final count = map['count'] is int
            ? map['count'] as int
            : int.tryParse('${map['count']}') ?? 0;
        final bpm = _asBpm(map['to_bpm'] ?? map['bpm']);
        final camelot = camelotFromScaleName(
          (map['to_camelot'] ?? map['camelot'] ?? '').toString(),
        );
        rows.add((
          count: count,
          track: {
            'title': title,
            'artist': artist,
            'version': (map['to_version'] ?? map['version'] ?? '').toString(),
            'track_id': entry.key.toString(),
            'fromTransition': true,
            'playedAfter': count,
            if (bpm != null) 'bpm': bpm,
            if (camelot != null && camelot.isNotEmpty) 'camelot': camelot,
          },
        ));
      }
      rows.sort((a, b) => b.count.compareTo(a.count));
      return [for (final row in rows) row.track];
    } catch (_) {
      return const [];
    }
  }
}

int? _mixBpm(double? raw) {
  if (raw == null || raw < 60 || raw > 220) return null;
  return raw.round();
}

double? _asBpm(Object? raw) {
  final n = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (n == null || n < 60 || n > 220) return null;
  return n;
}

class _RankedNext {
  const _RankedNext({
    required this.count,
    required this.order,
    required this.track,
  });

  final int count;
  final int order;
  final Map<String, dynamic> track;
}

/// Pool = Songs, die laut Einstellungen (Genre/BPM) passen.
/// Sortierung = wie oft sie nach dem laufenden Song wirklich kamen.
List<Map<String, dynamic>> rankByPlayedAfter({
  required List<Map<String, dynamic>> pool,
  required List<Map<String, dynamic>> playedAfter,
  double? seedBpm,
  String? seedCamelot,
  String seedArtist = '',
  String scope = 'similar',
  bool allowSameArtist = true,
}) {
  final seedArtistId = identityArtistOf(seedArtist);
  final counts = <String, int>{};
  final extras = <String, Map<String, dynamic>>{};
  for (final row in playedAfter) {
    final title = (row['title'] ?? '').toString().trim();
    final artist = (row['artist'] ?? '').toString().trim();
    final key = workKeyOf(title, artist);
    if (key.isEmpty) continue;
    if (!allowSameArtist &&
        seedArtistId.isNotEmpty &&
        identityArtistOf(artist) == seedArtistId) {
      continue;
    }
    final count = row['playedAfter'] is int
        ? row['playedAfter'] as int
        : int.tryParse('${row['playedAfter'] ?? row['count']}') ?? 0;
    counts[key] = count;
    extras[key] = row;
  }

  final seen = <String>{};
  final ranked = <_RankedNext>[];
  var order = 0;
  for (final item in pool) {
    final key = workKeyOf(
      (item['title'] ?? '').toString(),
      (item['artist'] ?? '').toString(),
    );
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    ranked.add(_RankedNext(
      count: counts[key] ?? 0,
      order: order++,
      track: item,
    ));
  }
  for (final entry in extras.entries) {
    if (seen.contains(entry.key)) continue;
    final row = entry.value;
    if (!fitsMixWindow(
      seedBpm: seedBpm,
      seedCamelot: seedCamelot,
      candidateBpm: _asBpm(row['bpm']),
      candidateCamelot: (row['camelot'] ?? '').toString(),
      scope: scope,
    )) {
      continue;
    }
    seen.add(entry.key);
    ranked.add(_RankedNext(
      count: counts[entry.key] ?? 0,
      order: order++,
      track: row,
    ));
  }
  ranked.sort((a, b) {
    if (a.count != b.count) return b.count.compareTo(a.count);
    return a.order.compareTo(b.order);
  });
  return [for (final row in ranked) row.track];
}
