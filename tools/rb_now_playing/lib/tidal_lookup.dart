import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dj_sqlite.dart';
import 'library_match.dart';

class TidalHit {
  const TidalHit({
    required this.trackId,
    required this.title,
    required this.artist,
  });

  final String trackId;
  final String title;
  final String artist;

  String get url => 'https://tidal.com/browse/track/$trackId';
  String get location => 'tidal:tracks:$trackId';

  Map<String, dynamic> toJson() => {
        'id': trackId,
        't': title,
        'a': artist,
      };

  factory TidalHit.fromJson(Map<String, dynamic> json) {
    return TidalHit(
      trackId: (json['id'] ?? '').toString(),
      title: (json['t'] ?? json['title'] ?? '').toString(),
      artist: (json['a'] ?? json['artist'] ?? '').toString(),
    );
  }
}

enum TidalLookupStatus { queued, searching, found, missed }

/// Sucht fehlende Wünsche: mit Tidal-Login direkt im Katalog,
/// sonst MusicBrainz nach einem Tidal-Link.
class TidalLookupStore extends ChangeNotifier {
  static const _userAgent = 'VibesBoxSync/1.0 (https://vibesbox.app)';
  static const _gap = Duration(milliseconds: 1100);
  static const _channel = MethodChannel('vibesbox_sync/tidal');

  final Map<String, TidalLookupStatus> _status = {};
  final Map<String, TidalHit> _hits = {};
  final List<String> _queue = [];
  var _pumping = false;
  Timer? _persistTimer;
  var loggedIn = false;
  var loggingIn = false;
  int revision = 0;

  @override
  void notifyListeners() {
    revision++;
    super.notifyListeners();
  }

  TidalLookupStatus? statusOf(String title, String artist) =>
      _status[_key(title, artist)];

  TidalHit? hitOf(String title, String artist) => _hits[_key(title, artist)];

  /// Tidal-Katalog unabhängig von der DJ-Collection: Location zum Ziehen.
  Map<String, dynamic> applyCatalog(
    Map<String, dynamic> item, {
    required bool allowDeckDrag,
  }) {
    final title = (item['title'] ?? '').toString();
    final artist = (item['artist'] ?? '').toString();
    if (item['canDrag'] == true) return item;
    final loc = (item['location'] ?? '').toString();
    if (isRekordboxDragPath(loc.isEmpty ? null : loc)) {
      return {...item, 'canDrag': allowDeckDrag, 'isTidal': loc.toLowerCase().startsWith('tidal:')};
    }
    final hit = hitOf(title, artist);
    if (hit == null) return item;
    return {
      ...item,
      'location': hit.location,
      'isTidal': true,
      'canDrag': false,
    };
  }

  bool isSearching(String title, String artist) {
    final s = statusOf(title, artist);
    return s == TidalLookupStatus.queued || s == TidalLookupStatus.searching;
  }

  Future<void> load() async {
    await refreshAuth();
    try {
      final file = _file();
      if (!file.existsSync()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return;
      final hits = data['hits'];
      if (hits is Map) {
        for (final entry in hits.entries) {
          if (entry.value is Map) {
            final hit = TidalHit.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
            if (hit.trackId.isEmpty) continue;
            _hits[entry.key.toString()] = hit;
            _status[entry.key.toString()] = TidalLookupStatus.found;
          }
        }
      }
      final miss = data['miss'];
      if (miss is List) {
        for (final key in miss) {
          final k = key.toString();
          if (k.isEmpty || _hits.containsKey(k)) continue;
          _status[k] = TidalLookupStatus.missed;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshAuth() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('status');
      final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      loggedIn = map['loggedIn'] == true;
    } catch (_) {
      loggedIn = false;
    }
    notifyListeners();
  }

  Future<void> login() async {
    if (loggingIn) return;
    loggingIn = true;
    notifyListeners();
    try {
      final raw = await _channel.invokeMethod<dynamic>('login');
      final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      loggedIn = map['loggedIn'] == true;
      if (loggedIn) retryMissed();
    } catch (_) {
      loggedIn = false;
    } finally {
      loggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _channel.invokeMethod<dynamic>('logout');
    } catch (_) {}
    loggedIn = false;
    notifyListeners();
  }

  void retryMissed() {
    final missed = [
      for (final e in _status.entries)
        if (e.value == TidalLookupStatus.missed) e.key,
    ];
    for (final key in missed) {
      _status.remove(key);
      final parts = key.split('|');
      ensure(parts.isNotEmpty ? parts[0] : '', parts.length > 1 ? parts[1] : '');
    }
  }

  void ensure(String title, String artist) {
    final key = _key(title, artist);
    if (key.split('|').first.length < 2) return;
    if (_status.containsKey(key)) return;
    _status[key] = TidalLookupStatus.queued;
    _queue.add(key);
    notifyListeners();
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_queue.isNotEmpty) {
        final key = _queue.removeAt(0);
        _status[key] = TidalLookupStatus.searching;
        notifyListeners();
        final parts = key.split('|');
        final title = parts.isNotEmpty ? parts[0] : '';
        final artist = parts.length > 1 ? parts[1] : '';
        try {
          final hit = await _search(title, artist);
          if (hit == null) {
            _status[key] = TidalLookupStatus.missed;
          } else {
            _hits[key] = hit;
            _status[key] = TidalLookupStatus.found;
          }
        } catch (_) {
          _status[key] = TidalLookupStatus.missed;
        }
        notifyListeners();
        _schedulePersist();
        if (_queue.isNotEmpty) {
          await Future<void>.delayed(
            loggedIn
                ? const Duration(milliseconds: 280)
                : _gap,
          );
        }
      }
    } finally {
      _pumping = false;
    }
  }

  Future<TidalHit?> _search(String title, String artist) async {
    if (loggedIn) {
      try {
        final hit = await _searchTidal(title, artist);
        if (hit != null) return hit;
      } catch (_) {}
    }
    return _searchMusicBrainz(title, artist);
  }

  Future<TidalHit?> _searchTidal(String title, String artist) async {
    final raw = await _channel.invokeMethod<dynamic>('search', {
      'title': title,
      'artist': artist,
    });
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['loggedIn'] == false) {
      loggedIn = false;
      notifyListeners();
    }
    final tracks = map['tracks'];
    if (tracks is! List) return null;
    TidalHit? fallback;
    for (final item in tracks) {
      if (item is! Map) continue;
      final hit = TidalHit(
        trackId: '${item['id'] ?? ''}',
        title: '${item['t'] ?? item['title'] ?? ''}',
        artist: '${item['a'] ?? item['artist'] ?? ''}',
      );
      if (hit.trackId.isEmpty) continue;
      fallback ??= hit;
      if (_closeEnough(title, artist, hit.title, hit.artist)) return hit;
    }
    return fallback;
  }

  Future<TidalHit?> _searchMusicBrainz(String title, String artist) async {
    final recordings = await _searchRecordings(title, artist);
    for (final rec in recordings) {
      await Future<void>.delayed(_gap);
      final id = (rec['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final recTitle = (rec['title'] ?? '').toString();
      final recArtist = _artistOf(rec);
      if (!_closeEnough(title, artist, recTitle, recArtist)) continue;
      final tidalId = await _tidalIdForRecording(id);
      if (tidalId == null) continue;
      return TidalHit(
        trackId: tidalId,
        title: recTitle.isEmpty ? title : recTitle,
        artist: recArtist.isEmpty ? artist : recArtist,
      );
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _searchRecordings(
    String title,
    String artist,
  ) async {
    final query = artist.isEmpty
        ? 'recording:"${_lucene(title)}"'
        : 'recording:"${_lucene(title)}" AND artist:"${_lucene(artist)}"';
    final uri = Uri.https('musicbrainz.org', '/ws/2/recording/', {
      'query': query,
      'fmt': 'json',
      'limit': '5',
    });
    final data = await _getJson(uri);
    final raw = data['recordings'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<String?> _tidalIdForRecording(String mbid) async {
    final uri = Uri.https('musicbrainz.org', '/ws/2/recording/$mbid', {
      'inc': 'url-rels',
      'fmt': 'json',
    });
    final data = await _getJson(uri);
    final rels = data['relations'];
    if (rels is! List) return null;
    final ids = <String>[];
    final re = RegExp(r'tidal\.com/(?:browse/)?track/(\d+)');
    for (final rel in rels) {
      if (rel is! Map) continue;
      final url = ((rel['url'] as Map?)?['resource'] ?? '').toString();
      final m = re.firstMatch(url);
      if (m != null) ids.add(m.group(1)!);
    }
    if (ids.isEmpty) return null;
    ids.sort();
    return ids.first;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 10));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(body);
      if (data is! Map) throw StateError('Ungültige Antwort');
      return Map<String, dynamic>.from(data);
    } finally {
      client.close(force: true);
    }
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    try {
      final file = _file();
      await file.writeAsString(
        jsonEncode({
          'hits': {
            for (final e in _hits.entries) e.key: e.value.toJson(),
          },
          'miss': [
            for (final e in _status.entries)
              if (e.value == TidalLookupStatus.missed) e.key,
          ],
        }),
      );
    } catch (_) {}
  }

  File _file() {
    final dir = toolSupportDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/tidal_cache.json');
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }
}

String _key(String title, String artist) =>
    '${identityTitleOf(title)}|${identityArtistOf(artist)}';

String _artistOf(Map<String, dynamic> rec) {
  final credit = rec['artist-credit'];
  if (credit is! List) return '';
  return [
    for (final item in credit)
      if (item is Map) (item['name'] ?? '').toString(),
  ].where((n) => n.isNotEmpty).join(' ');
}

bool _closeEnough(
  String qTitle,
  String qArtist,
  String tTitle,
  String tArtist,
) {
  final qt = identityTitleOf(qTitle);
  final tt = identityTitleOf(tTitle);
  if (qt.length < 2 || tt.length < 2) return false;
  final titleOk = qt == tt ||
      ((qt.contains(tt) || tt.contains(qt)) &&
          (qt.length >= 8 || tt.length >= 8 || qt.split(' ').length >= 2));
  if (!titleOk) return false;
  final qa = identityArtistOf(qArtist);
  final ta = identityArtistOf(tArtist);
  if (qa.isEmpty || ta.isEmpty) return true;
  return qa == ta || qa.contains(ta) || ta.contains(qa);
}

String _lucene(String raw) {
  return raw.replaceAll(RegExp(r'[+\-!(){}\[\]^"~*?:\\/]'), ' ').trim();
}

Future<void> openExternalUrl(String url) async {
  if (url.isEmpty) return;
  try {
    await Process.run('open', [url]);
  } catch (_) {}
}
