import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/song_recommendation.dart';
import '../utils/debug_log.dart';
import '../utils/song_catalog_id.dart';

/// Liest die zwei lokalen Quellen der Suchregeln. Ein Dokument pro Lied,
/// keine Sammlungsliste. Schreiben bleibt beim Sync-Tool.
class MusicSearchSources {
  /// Ein Lesezugriff: Nachfolger und ihre Zähler.
  static Future<({List<SongRecommendation> songs, Map<String, int> counts})>
      followUps({
    required String title,
    required String artist,
  }) async {
    final id = songCatalogDocId(artist: artist, title: title);
    if (id.isEmpty) {
      return (
        songs: const <SongRecommendation>[],
        counts: const <String, int>{},
      );
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('song_transitions')
          .doc(id)
          .get();
      final data = snap.data();
      return (
        songs: _playedAfterRows(data),
        counts: playedCountsOf(data),
      );
    } catch (e) {
      debugLog('MusicSearchSources played_after: $e');
      return (
        songs: const <SongRecommendation>[],
        counts: const <String, int>{},
      );
    }
  }

  static Future<List<SongRecommendation>> recommended({
    required String title,
    required String artist,
    required Map<String, int> playedCounts,
  }) async {
    final tokenReady = songCatalogDocId(artist: artist, title: title);
    if (tokenReady.isEmpty) return const [];
    const scopes = ['strict', 'similar', 'bold'];
    const fams = ['hits', 'mix'];
    final ids = <String>[];
    for (final scope in scopes) {
      for (final fam in fams) {
        for (final same in [true, false]) {
          final id = suggestionCatalogDocId(
            artist: artist,
            title: title,
            scope: scope,
            familiarity: fam,
            allowSameArtist: same,
          );
          if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
        }
      }
    }
    try {
      final snaps = await Future.wait(ids.map((id) async {
        try {
          return await FirebaseFirestore.instance
              .collection('song_suggestions')
              .doc(id)
              .get();
        } catch (_) {
          return null;
        }
      }));
      final ranked = <({int order, int plays, SongRecommendation song})>[];
      final seen = <String>{};
      var order = 0;
      for (final snap in snaps) {
        final data = snap?.data();
        final raw = data?['suggestions'];
        if (raw is! List) continue;
        for (final item in raw) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final songTitle = (map['title'] ?? '').toString().trim();
          final songArtist = (map['artist'] ?? '').toString().trim();
          final uri = (map['spotify_uri'] ?? '').toString().trim();
          if (songTitle.isEmpty || songArtist.isEmpty) continue;
          if (!uri.startsWith('spotify:')) continue;
          final key = '${songTitle.toLowerCase()}|${songArtist.toLowerCase()}';
          if (!seen.add(key)) continue;
          final songId = songCatalogDocId(artist: songArtist, title: songTitle);
          ranked.add((
            order: order++,
            plays: playedCounts[songId] ?? 0,
            song: SongRecommendation.fromJson(map),
          ));
        }
      }
      ranked.sort((a, b) {
        if (a.plays != b.plays) return b.plays.compareTo(a.plays);
        return a.order.compareTo(b.order);
      });
      return [for (final row in ranked) row.song];
    } catch (e) {
      debugLog('MusicSearchSources recommended: $e');
      return const [];
    }
  }

  static Map<String, int> playedCountsOf(Map<String, dynamic>? data) {
    final next = data?['next_tracks'];
    if (next is! Map) return const {};
    final counts = <String, int>{};
    for (final entry in next.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final count = value['count'];
      final n = count is int
          ? count
          : count is num
              ? count.round()
              : int.tryParse('$count') ?? 0;
      if (n > 0) counts[entry.key.toString()] = n;
    }
    return counts;
  }

  static List<SongRecommendation> _playedAfterRows(Map<String, dynamic>? data) {
    final next = data?['next_tracks'];
    if (next is! Map) return const [];
    final rows = <({int count, int order, SongRecommendation song})>[];
    var order = 0;
    for (final entry in next.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      final title = (map['to_title'] ?? map['title'] ?? '').toString().trim();
      final artist = (map['to_artist'] ?? map['artist'] ?? '').toString().trim();
      if (title.isEmpty || artist.isEmpty) continue;
      final countRaw = map['count'];
      final count = countRaw is int
          ? countRaw
          : countRaw is num
              ? countRaw.round()
              : int.tryParse('$countRaw') ?? 0;
      rows.add((
        count: count,
        order: order++,
        song: SongRecommendation.fromJson(<String, dynamic>{
          'title': title,
          'artist': artist,
          if (map['to_bpm'] != null) 'bpm': map['to_bpm'],
          if (map['to_camelot'] != null) 'camelot': map['to_camelot'],
        }),
      ));
    }
    rows.sort((a, b) {
      if (a.count != b.count) return b.count.compareTo(a.count);
      return a.order.compareTo(b.order);
    });
    return [for (final row in rows) row.song];
  }
}
