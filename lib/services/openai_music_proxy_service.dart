import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../utils/debug_log.dart';

/// Callable-Proxy für Song-Vorschläge und KI-Setliste.
/// Der OpenAI-Key bleibt in Secret Manager; die App bekommt ihn nie.
class OpenaiMusicProxyService {
  OpenaiMusicProxyService._();

  static final OpenaiMusicProxyService instance = OpenaiMusicProxyService._();

  static const String _region = 'us-central1';
  static const String _name = 'openaiMusicProxy';

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  /// Dieselbe Suche wie VibesBox Sync (`collectFollowUps`), ohne Tidal/Festplatte.
  Future<List<Map<String, dynamic>>> recommend({
    required String title,
    required String artist,
    required String scope,
    required String familiarity,
    required bool allowSameArtist,
    required int count,
    required List<Map<String, String>> exclude,
    double? bpm,
    String? camelot,
  }) async {
    final n = count < 1 ? 1 : (count > 20 ? 20 : count);
    try {
      return await _recommendStream(
        title: title,
        artist: artist,
        scope: scope,
        familiarity: familiarity,
        allowSameArtist: allowSameArtist,
        count: n,
        exclude: exclude,
        bpm: bpm,
        camelot: camelot,
      );
    } catch (e) {
      debugLog('OpenaiMusicProxyService stream: $e');
      return _call(
        <String, dynamic>{
          'action': 'recommend',
          'title': title,
          'artist': artist,
          'scope': scope,
          'familiarity': familiarity,
          'allowSameArtist': allowSameArtist,
          'count': n,
          'exclude': exclude,
          if (bpm != null) 'bpm': bpm,
          if (camelot != null && camelot.trim().isNotEmpty) 'camelot': camelot,
        },
        timeout: Duration(seconds: (12 + n).clamp(20, 38)),
      );
    }
  }

  Future<List<Map<String, dynamic>>> setlistBatch({
    required String eventType,
    required String preferred,
    required String blacklist,
    required String ageStructure,
    required String region,
    required String appLanguage,
    required int need,
    required List<Map<String, String>> already,
    List<String> genres = const <String>[],
    String artistsMust = '',
    List<String> marketIds = const <String>[],
    Map<String, int> marketPercents = const <String, int>{},
    String bpmBand = 'any',
    String energyCurve = 'warm_peak_cool',
    String familiarity = 'hits',
    String scope = 'strict',
    String occasionId = '',
  }) {
    return _call(
      <String, dynamic>{
        'action': 'setlist',
        'eventType': eventType,
        'preferred': preferred,
        'blacklist': blacklist,
        'ageStructure': ageStructure,
        'region': region,
        'appLanguage': appLanguage,
        'need': need,
        'already': already,
        'genres': genres,
        'artistsMust': artistsMust,
        'marketIds': marketIds,
        'marketPercents': marketPercents,
        'bpmBand': bpmBand,
        'energyCurve': energyCurve,
        'familiarity': familiarity,
        'scope': scope,
        'occasionId': occasionId,
      },
      timeout: const Duration(seconds: 45),
    );
  }

  Future<List<String>> translateReasons({
    required String targetLang,
    required List<String> texts,
  }) async {
    if (texts.isEmpty) return const <String>[];
    final callable = _functions.httpsCallable(
      _name,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
    );
    final result = await callable.call(<String, dynamic>{
      'action': 'translateReasons',
      'targetLang': targetLang,
      'texts': texts,
    });
    final data = Map<String, dynamic>.from(
      (result.data as Map?) ?? const <String, dynamic>{},
    );
    final raw = data['texts'];
    if (raw is! List) return texts;
    final out = <String>[];
    for (var i = 0; i < texts.length; i++) {
      if (i < raw.length) {
        final t = raw[i]?.toString().trim() ?? '';
        out.add(t.isEmpty ? texts[i] : t);
      } else {
        out.add(texts[i]);
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _recommendStream({
    required String title,
    required String artist,
    required String scope,
    required String familiarity,
    required bool allowSameArtist,
    required int count,
    required List<Map<String, String>> exclude,
    double? bpm,
    String? camelot,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('nicht angemeldet');
    }
    final uri = Uri.parse(
      'https://$_region-dj-ollerganove.cloudfunctions.net/openaiMusicRecommendStream',
    );
    final client = http.Client();
    try {
      final req = http.Request('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Content-Type'] = 'application/json';
      req.headers['Accept'] = 'application/x-ndjson';
      req.body = jsonEncode(<String, dynamic>{
        'title': title,
        'artist': artist,
        'scope': scope,
        'familiarity': familiarity,
        'allowSameArtist': allowSameArtist,
        'count': count,
        'exclude': exclude,
        if (bpm != null) 'bpm': bpm,
        if (camelot != null && camelot.trim().isNotEmpty)
          'camelot': camelot.trim(),
      });
      final res = await client.send(req).timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('stream ${res.statusCode}');
      }
      final out = <Map<String, dynamic>>[];
      var pending = '';
      await for (final chunk in res.stream
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 36))) {
        pending += chunk;
        final lines = pending.split('\n');
        pending = lines.removeLast();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          dynamic decoded;
          try {
            decoded = jsonDecode(trimmed);
          } catch (_) {
            continue;
          }
          if (decoded is! Map) continue;
          if (decoded['done'] == true) return out;
          final rowTitle = (decoded['title'] ?? '').toString().trim();
          final rowArtist = (decoded['artist'] ?? '').toString().trim();
          if (rowTitle.isEmpty || rowArtist.isEmpty) continue;
          out.add(Map<String, dynamic>.from(decoded));
          if (out.length >= 20) return out;
        }
      }
      return out;
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, dynamic>>> _call(
    Map<String, dynamic> payload, {
    required Duration timeout,
  }) async {
    final callable = _functions.httpsCallable(
      _name,
      options: HttpsCallableOptions(timeout: timeout),
    );
    final result = await callable.call(payload);
    final data = Map<String, dynamic>.from(
      (result.data as Map?) ?? const <String, dynamic>{},
    );
    final raw = data['tracks'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      out.add(Map<String, dynamic>.from(entry));
    }
    return out;
  }
}
