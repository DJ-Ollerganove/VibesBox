import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'dj_library_source.dart';
import 'dj_sqlite.dart';
import 'library_match.dart';
import 'rekordbox_history.dart';
import 'tool_i18n.dart';

/// Algoriddim DJAY Pro – liest MediaLibrary.db (YapDatabase + TSAF-Blobs).
class DjayLibrarySource implements DjLibrarySource {
  DjayLibrarySource(this.overridePath);

  final String? overridePath;
  final _sqlite = ReadonlySqlite();
  String? _dbPath;

  @override
  String get label => 'DJAY Pro';

  @override
  HistorySnapshot readHistory() {
    final db = _ensure();
    if (!sqliteHasTable(db, 'database2')) {
      return HistorySnapshot(
        dbPath: _dbPath ?? '',
        historyName: null,
        tracks: const [],
        readAt: DateTime.now(),
      );
    }
    final rows = db.select('''
SELECT key, data FROM database2
WHERE collection = 'historySessionItems'
ORDER BY rowid DESC
LIMIT 80
''');
    final tracks = <HistoryTrack>[];
    var n = 0;
    for (final row in rows) {
      final blob = _blobOf(row['data']);
      if (blob == null) continue;
      final parsed = parseDjayHistoryItem(blob);
      if (parsed == null) continue;
      var title = parsed.title;
      var artist = parsed.artist;
      if (parsed.titleId != null &&
          ((title == null || title.isEmpty) ||
              (artist == null || artist.isEmpty))) {
        final meta = _titleById(db, parsed.titleId!);
        if (title == null || title.isEmpty) title = meta?.title;
        if (artist == null || artist.isEmpty) artist = meta?.artist;
      }
      if (title == null || title.isEmpty) continue;
      n += 1;
      final analyzed =
          parsed.titleId == null ? null : _analyzedById(db, parsed.titleId!);
      tracks.add(
        HistoryTrack(
          trackNo: n,
          title: title,
          artist: artist ?? '',
          playedAt: parsed.startTime,
          historyName: 'historySessionItems',
          bpm: analyzed?.bpm,
          musicalKey: analyzed?.musicalKey,
          length: parsed.duration == null
              ? null
              : Duration(seconds: parsed.duration!.round()),
        ),
      );
    }
    return HistorySnapshot(
      dbPath: _dbPath ?? '',
      historyName: tracks.isEmpty ? null : 'historySessionItems',
      tracks: tracks,
      readAt: DateTime.now(),
    );
  }

  @override
  List<LibraryTrack> readLibrary() {
    final db = _ensure();
    if (!sqliteHasTable(db, 'database2')) {
      throw StateError(toolI18n.text('errDjay'));
    }
    final titleRows = db.select('''
SELECT key, data FROM database2
WHERE collection = 'mediaItemTitleIDs'
''');
    final analyzed = _mapByKey(db, 'mediaItemAnalyzedData');
    final userData = _mapByKey(db, 'mediaItemUserData');
    final localLoc = _mapByKey(db, 'localMediaItemLocations');
    final globalLoc = _mapByKey(db, 'globalMediaItemLocations');

    final tracks = <LibraryTrack>[];
    for (final row in titleRows) {
      final key = textOrNull(row['key']);
      final blob = _blobOf(row['data']);
      if (key == null || blob == null) continue;
      final title = extractDjayString(blob, 'title');
      if (title == null || title.isEmpty) continue;
      final artist = extractDjayString(blob, 'artist') ?? '';
      final duration = extractDjayDouble(blob, 'duration');
      final analysis = analyzed[key] == null
          ? null
          : parseDjayAnalyzed(analyzed[key]!);
      final plays = userData[key] == null
          ? 0
          : (extractDjayDouble(userData[key]!, 'playCount')?.round() ?? 0);
      final location = _locationFor(
        localLoc[key],
        globalLoc[key],
      );
      tracks.add(
        LibraryTrack(
          id: key,
          title: title,
          artist: artist,
          bpm: analysis?.bpm,
          musicalKey: analysis?.musicalKey,
          lengthSec: duration?.round(),
          playCount: plays,
          location: location,
        ),
      );
    }
    if (tracks.isEmpty) {
      throw StateError(toolI18n.text('noTracks', {'name': 'DJAY Pro'}));
    }
    return tracks;
  }

  @override
  LibraryPulse libraryPulse() {
    final db = _ensure();
    if (!sqliteHasTable(db, 'database2')) {
      return const LibraryPulse(trackCount: 0, playSum: 0);
    }
    final n = db.select('''
SELECT count(*) AS n FROM database2
WHERE collection = 'mediaItemTitleIDs'
''').first;
    var playSum = 0;
    final userRows = db.select('''
SELECT data FROM database2
WHERE collection = 'mediaItemUserData'
''');
    for (final row in userRows) {
      final blob = _blobOf(row['data']);
      if (blob == null) continue;
      playSum += extractDjayDouble(blob, 'playCount')?.round() ?? 0;
    }
    final file = File(_dbPath ?? '');
    return LibraryPulse(
      trackCount: intOrNull(n['n']) ?? 0,
      playSum: playSum,
      updatedAt: file.existsSync()
          ? file.lastModifiedSync().toUtc().toIso8601String()
          : null,
    );
  }

  @override
  Map<String, int> readPlayCounts() {
    final db = _ensure();
    if (!sqliteHasTable(db, 'database2')) return {};
    final rows = db.select('''
SELECT key, data FROM database2
WHERE collection = 'mediaItemUserData'
''');
    final counts = <String, int>{};
    for (final row in rows) {
      final key = textOrNull(row['key']);
      final blob = _blobOf(row['data']);
      if (key == null || blob == null) continue;
      counts[key] = extractDjayDouble(blob, 'playCount')?.round() ?? 0;
    }
    return counts;
  }

  @override
  void close() {
    _sqlite.close();
    _dbPath = null;
  }

  Database _ensure() {
    final path = locateDjayDb(overridePath);
    if (path == null || !File(path).existsSync()) {
      throw StateError(toolI18n.text('errDjay'));
    }
    _dbPath = path;
    return _sqlite.ensure(path, 'djay_read_copy.sqlite');
  }

  Map<String, Uint8List> _mapByKey(Database db, String collection) {
    final rows = db.select(
      'SELECT key, data FROM database2 WHERE collection = ?',
      [collection],
    );
    final out = <String, Uint8List>{};
    for (final row in rows) {
      final key = textOrNull(row['key']);
      final blob = _blobOf(row['data']);
      if (key == null || blob == null) continue;
      out[key] = blob;
    }
    return out;
  }

  ({String? title, String? artist})? _titleById(Database db, String titleId) {
    final rows = db.select(
      "SELECT data FROM database2 WHERE collection = 'mediaItemTitleIDs' AND key = ?",
      [titleId],
    );
    if (rows.isEmpty) return null;
    final blob = _blobOf(rows.first['data']);
    if (blob == null) return null;
    return (
      title: extractDjayString(blob, 'title'),
      artist: extractDjayString(blob, 'artist'),
    );
  }

  ({double? bpm, String? musicalKey})? _analyzedById(
    Database db,
    String titleId,
  ) {
    final rows = db.select(
      "SELECT data FROM database2 WHERE collection = 'mediaItemAnalyzedData' AND key = ?",
      [titleId],
    );
    if (rows.isEmpty) return null;
    final blob = _blobOf(rows.first['data']);
    if (blob == null) return null;
    return parseDjayAnalyzed(blob);
  }
}

String? locateDjayDb(String? override) {
  final custom = override?.trim();
  if (custom != null && custom.isNotEmpty) {
    if (custom.toLowerCase().endsWith('medialibrary.db') &&
        File(custom).existsSync()) {
      return custom;
    }
    for (final nested in [
      '$custom/MediaLibrary.db',
      '$custom/djay Media Library/MediaLibrary.db',
      '$custom/djay Media Library.djayMediaLibrary/MediaLibrary.db',
      '$custom/djay/djay Media Library/MediaLibrary.db',
      '$custom/djay/djay Media Library.djayMediaLibrary/MediaLibrary.db',
    ]) {
      if (File(nested).existsSync()) return nested;
    }
  }
  for (final path in _djayDbCandidates()) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

List<String> _djayDbCandidates() {
  final out = <String>[];
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  if (home.isNotEmpty) {
    out.add(
      '$home/Music/djay/djay Media Library.djayMediaLibrary/MediaLibrary.db',
    );
    out.add('$home/Music/djay/djay Media Library/MediaLibrary.db');
    out.add(
      '$home\\Music\\djay\\djay Media Library\\MediaLibrary.db',
    );
    out.add(
      '$home\\Music\\djay\\djay Media Library.djayMediaLibrary\\MediaLibrary.db',
    );
  }
  return out;
}

Uint8List? _blobOf(Object? raw) {
  if (raw is Uint8List) return raw;
  if (raw is List<int>) return Uint8List.fromList(raw);
  return null;
}

String? _locationFor(Uint8List? local, Uint8List? global) {
  for (final blob in [local, global]) {
    if (blob == null) continue;
    final uris = extractDjaySourceUris(blob);
    for (final uri in uris) {
      final resolved = resolveDjayUri(uri);
      if (resolved != null) return resolved;
    }
    // Fallback: title/artist blobs sometimes carry a lone file:// string.
    final fileHint = extractDjayString(blob, 'sourceURI');
    final resolved = resolveDjayUri(fileHint);
    if (resolved != null) return resolved;
  }
  return null;
}

({double? bpm, String? musicalKey}) parseDjayAnalyzed(Uint8List blob) {
  final bpm = extractDjayDouble(blob, 'bpm');
  final keyIdx = extractDjayDouble(blob, 'keySignatureIndex');
  return (
    bpm: bpm != null && bpm > 0 && bpm.isFinite ? bpm : null,
    musicalKey: keyIdx == null ? null : djayKeyName(keyIdx.round()),
  );
}

class DjayHistoryItem {
  const DjayHistoryItem({
    this.title,
    this.artist,
    this.titleId,
    this.duration,
    this.startTime,
  });

  final String? title;
  final String? artist;
  final String? titleId;
  final double? duration;
  final DateTime? startTime;
}

DjayHistoryItem? parseDjayHistoryItem(Uint8List blob) {
  final title = extractDjayString(blob, 'title');
  final artist = extractDjayString(blob, 'artist');
  final titleId = extractDjayTitleId(blob);
  if ((title == null || title.isEmpty) &&
      (artist == null || artist.isEmpty) &&
      titleId == null) {
    return null;
  }
  return DjayHistoryItem(
    title: title,
    artist: artist,
    titleId: titleId,
    duration: extractDjayDouble(blob, 'duration'),
    startTime: extractDjayDate(blob, 'startTime'),
  );
}

/// CFAbsoluteTime-Epoche: 2001-01-01 UTC.
final int _cfEpochMs = DateTime.utc(2001, 1, 1).millisecondsSinceEpoch;

String? extractDjayString(Uint8List blob, String key) {
  final keyPos = _findDjayKey(blob, key);
  if (keyPos < 0) return null;
  return _readStringBeforeKey(blob, keyPos);
}

double? extractDjayDouble(Uint8List blob, String key) {
  final keyPos = _findDjayKey(blob, key);
  if (keyPos < 8) return null;
  final bd = ByteData.sublistView(blob, keyPos - 8, keyPos);
  final value = bd.getFloat64(0, Endian.little);
  if (!value.isFinite) return null;
  return value;
}

DateTime? extractDjayDate(Uint8List blob, String key) {
  final cf = extractDjayDouble(blob, key);
  if (cf == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    _cfEpochMs + (cf * 1000).round(),
    isUtc: true,
  ).toLocal();
}

String? extractDjayTitleId(Uint8List blob) {
  const marker = 'ADCMediaItemTitleID';
  final needle = Uint8List(2 + marker.length + 1);
  needle[0] = 0x2b;
  needle[1] = 0x08;
  for (var i = 0; i < marker.length; i++) {
    needle[2 + i] = marker.codeUnitAt(i);
  }
  needle[needle.length - 1] = 0x00;
  final markerPos = _indexOfBytes(blob, needle);
  if (markerPos < 0) return null;
  final stringTagPos = markerPos + needle.length;
  if (stringTagPos >= blob.length || blob[stringTagPos] != 0x08) return null;
  final start = stringTagPos + 1;
  final end = blob.indexOf(0x00, start);
  if (end < 0) return null;
  final candidate = ascii.decode(blob.sublist(start, end), allowInvalid: true);
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(candidate)) return null;
  return candidate;
}

List<String> extractDjaySourceUris(Uint8List blob) {
  final keyPos = _findDjayKey(blob, 'sourceURIs');
  if (keyPos < 0) return const [];
  final uris = <String>[];
  final window = blob.sublist(0, keyPos);
  for (var i = 0; i < window.length - 2; i++) {
    if (window[i] != 0x21 || window[i + 1] != 0x08) continue;
    final start = i + 2;
    final end = window.indexOf(0x00, start);
    if (end < 0) break;
    final candidate = utf8.decode(window.sublist(start, end), allowMalformed: true);
    if (candidate.length >= 5 && candidate.contains(':')) {
      uris.add(candidate);
    }
    i = end;
  }
  // Manche Einträge speichern file:// ohne 0x21-Wrapper.
  if (uris.isEmpty) {
    final asText = utf8.decode(window, allowMalformed: true);
    for (final match in RegExp(r'file://[^\x00]+').allMatches(asText)) {
      uris.add(match.group(0)!);
    }
  }
  return uris;
}

String? resolveDjayUri(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final text = raw.trim();
  final lower = text.toLowerCase();
  if (lower.startsWith('file://')) {
    try {
      var path = Uri.parse(text).toFilePath();
      if (Platform.isWindows && path.startsWith('/') && path.length > 2 && path[2] == ':') {
        path = path.substring(1);
      }
      return toDragLocation(path) ?? path;
    } catch (_) {
      var path = Uri.decodeFull(text.substring('file://'.length));
      if (path.startsWith('/') &&
          Platform.isWindows &&
          path.length > 2 &&
          path[2] == ':') {
        path = path.substring(1);
      }
      return toDragLocation(path) ?? path;
    }
  }
  // Streaming: tidal:track:… / spotify:track:… usw.
  final dragged = toDragLocation(text);
  if (dragged != null) return dragged;
  if (text.contains(':')) return text;
  return null;
}

String? djayKeyName(int index) {
  const map = <int, String>{
    0: 'Db',
    1: 'Bbm',
    2: 'D',
    3: 'Bm',
    4: 'Eb',
    5: 'Cm',
    6: 'E',
    7: 'C#m',
    8: 'F',
    9: 'Dm',
    10: 'F#',
    11: 'Ebm',
    12: 'G',
    13: 'Em',
    14: 'Ab',
    15: 'Fm',
    16: 'A',
    17: 'F#m',
    18: 'Bb',
    19: 'Gm',
    20: 'B',
    21: 'Abm',
    22: 'C',
    23: 'Am',
  };
  return map[index];
}

int _findDjayKey(Uint8List blob, String key) {
  final needle = Uint8List(key.length + 2);
  needle[0] = 0x08;
  for (var i = 0; i < key.length; i++) {
    needle[1 + i] = key.codeUnitAt(i);
  }
  needle[needle.length - 1] = 0x00;
  return _indexOfBytes(blob, needle);
}

String? _readStringBeforeKey(Uint8List blob, int keyPos) {
  if (keyPos < 2) return null;
  final nullPos = keyPos - 1;
  if (blob[nullPos] != 0x00) return null;
  final scanLimit = nullPos - 2048 < 0 ? 0 : nullPos - 2048;
  for (var i = nullPos - 1; i >= scanLimit; i--) {
    if (blob[i] != 0x08) continue;
    final value = blob.sublist(i + 1, nullPos);
    if (!_isPrintableUtf8(value)) continue;
    final text = utf8.decode(value, allowMalformed: true).trim();
    return text.isEmpty ? null : text;
  }
  return null;
}

bool _isPrintableUtf8(Uint8List bytes) {
  for (final b in bytes) {
    if (b == 0x09) continue;
    if (b >= 0x20 && b < 0x7f) continue;
    if (b >= 0x80) continue;
    return false;
  }
  return true;
}

int _indexOfBytes(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty || haystack.length < needle.length) return -1;
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
