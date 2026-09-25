import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/song_recommendation.dart';
import '../utils/debug_log.dart';

/// RAM- + Gerätelocal-Cache für Mix-Vorschläge (kein Firestore).
class RecommendationCacheService {
  RecommendationCacheService._();

  static final RecommendationCacheService instance =
      RecommendationCacheService._();

  static const _prefsPrefix = 'vb_song_rec_cache_v2_';
  static const _prefsIndexKey = 'vb_song_rec_cache_v2_index';
  static const _maxStoredItems = 20;
  /// Kleiner Prefs-Puffer für denselben Song später in der Party (ohne OpenAI).
  static const _maxPrefsEntries = 5;
  /// Prefs-Einträge älter als das werden entfernt.
  static const _prefsTtl = Duration(days: 2);

  final Map<String, List<SongRecommendation>> _memory =
      <String, List<SongRecommendation>>{};

  static String keyFor({
    required String artist,
    required String title,
    String extra = '',
  }) {
    final normalized =
        '${artist.trim().toLowerCase()}|${title.trim().toLowerCase()}|$extra'
            .replaceAll(RegExp(r'\s+'), ' ');
    return base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  }

  List<SongRecommendation>? peekMemory({
    required String artist,
    required String title,
    String extra = '',
  }) {
    final key = keyFor(artist: artist, title: title, extra: extra);
    final mem = _memory[key];
    if (mem == null || mem.isEmpty) return null;
    return List<SongRecommendation>.from(mem);
  }

  Future<List<SongRecommendation>?> read({
    required String artist,
    required String title,
    String extra = '',
  }) async {
    final key = keyFor(artist: artist, title: title, extra: extra);
    final mem = _memory[key];
    if (mem != null && mem.isNotEmpty) return List<SongRecommendation>.from(mem);

    try {
      final prefs = await SharedPreferences.getInstance();
      await _evictStalePrefs(prefs);
      final raw = prefs.getString('$_prefsPrefix$key');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final updatedAtMs = decoded['updatedAtMs'];
      if (updatedAtMs is int) {
        final age = DateTime.now().millisecondsSinceEpoch - updatedAtMs;
        if (age > _prefsTtl.inMilliseconds) {
          await prefs.remove('$_prefsPrefix$key');
          await _removeFromIndex(prefs, key);
          return null;
        }
      }
      final itemsRaw = decoded['items'];
      if (itemsRaw is! List) return null;
      final items = <SongRecommendation>[];
      for (final entry in itemsRaw) {
        if (entry is! Map) continue;
        final rec = SongRecommendation.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (rec.title.isEmpty || rec.artist.isEmpty) continue;
        items.add(rec);
        if (items.length >= _maxStoredItems) break;
      }
      if (items.isEmpty) return null;
      _putMemory(key, items);
      await _touchIndex(prefs, key);
      return List<SongRecommendation>.from(items);
    } catch (e) {
      debugLog('RecommendationCacheService.read: $e');
      return null;
    }
  }

  Future<void> write({
    required String artist,
    required String title,
    required List<SongRecommendation> items,
    String extra = '',
  }) async {
    if (items.isEmpty) return;
    final key = keyFor(artist: artist, title: title, extra: extra);
    final clipped = items.take(_maxStoredItems).toList(growable: false);
    _putMemory(key, clipped);
    unawaited(_persist(key, title, artist, clipped));
  }

  /// Leert nur den RAM-Cache (Prefs bleiben für den nächsten Start, aber begrenzt).
  void clearMemory() {
    _memory.clear();
  }

  void _putMemory(String key, List<SongRecommendation> items) {
    // Neue 5 ersetzen die alten komplett im RAM.
    _memory.clear();
    _memory[key] = items;
  }

  Future<void> _persist(
    String key,
    String title,
    String artist,
    List<SongRecommendation> clipped,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(<String, dynamic>{
        'title': title.trim(),
        'artist': artist.trim(),
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'items': clipped.map((e) => e.toJson()).toList(),
      });
      await prefs.setString('$_prefsPrefix$key', payload);
      await _touchIndex(prefs, key);
      await _evictStalePrefs(prefs);
    } catch (e) {
      debugLog('RecommendationCacheService.write: $e');
    }
  }

  Future<List<String>> _readIndex(SharedPreferences prefs) async {
    final raw = prefs.getStringList(_prefsIndexKey);
    if (raw == null) return <String>[];
    return List<String>.from(raw);
  }

  Future<void> _touchIndex(SharedPreferences prefs, String key) async {
    final index = await _readIndex(prefs);
    index.remove(key);
    index.add(key);
    await prefs.setStringList(_prefsIndexKey, index);
  }

  Future<void> _removeFromIndex(SharedPreferences prefs, String key) async {
    final index = await _readIndex(prefs);
    if (index.remove(key)) {
      await prefs.setStringList(_prefsIndexKey, index);
    }
  }

  Future<void> _evictStalePrefs(SharedPreferences prefs) async {
    try {
      final index = await _readIndex(prefs);
      final now = DateTime.now().millisecondsSinceEpoch;
      final kept = <String>[];
      for (final key in index) {
        final raw = prefs.getString('$_prefsPrefix$key');
        if (raw == null || raw.isEmpty) continue;
        var keep = true;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final updatedAtMs = decoded['updatedAtMs'];
            if (updatedAtMs is int &&
                now - updatedAtMs > _prefsTtl.inMilliseconds) {
              keep = false;
            }
          }
        } catch (_) {
          keep = false;
        }
        if (keep) {
          kept.add(key);
        } else {
          await prefs.remove('$_prefsPrefix$key');
        }
      }
      while (kept.length > _maxPrefsEntries) {
        final oldest = kept.removeAt(0);
        await prefs.remove('$_prefsPrefix$oldest');
      }
      await prefs.setStringList(_prefsIndexKey, kept);
    } catch (e) {
      debugLog('RecommendationCacheService.evict: $e');
    }
  }
}
