import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'dj_library_source.dart';
import 'dj_sqlite.dart';
import 'library_match.dart';
import 'tool_i18n.dart';
import 'rekordbox_history.dart';

class SeratoLibrarySource implements DjLibrarySource {
  SeratoLibrarySource(this.overridePath);

  final String? overridePath;
  final _sqlite = ReadonlySqlite();
  String? _dbPath;

  @override
  String get label => 'Serato DJ Pro';

  @override
  HistorySnapshot readHistory() {
    if (_ensureSqlite()) {
      return _readSqliteHistory();
    }
    return _readSessionHistory();
  }

  @override
  List<LibraryTrack> readLibrary() {
    if (_ensureSqlite()) {
      return _readSqliteLibrary();
    }
    final tracks = parseSeratoDatabaseV2(File(_requireDatabaseV2()).readAsBytesSync());
    if (tracks.isEmpty) {
      throw StateError(toolI18n.text('noTracks', {'name': 'Serato DJ Pro'}));
    }
    return tracks;
  }

  @override
  LibraryPulse libraryPulse() {
    if (_ensureSqlite()) {
      final row = _sqlite.ensure(_dbPath!, 'serato_read_copy.sqlite').select('''
SELECT count(*) AS n,
       sum(IFNULL(dj_play_count, 0)) AS plays,
       max(time_modified) AS updatedAt
FROM asset
WHERE IFNULL(name, '') != ''
''').first;
      return LibraryPulse(
        trackCount: intOrNull(row['n']) ?? 0,
        playSum: intOrNull(row['plays']) ?? 0,
        updatedAt: textOrNull(row['updatedAt']),
      );
    }
    final file = File(_requireDatabaseV2());
    final tracks = parseSeratoDatabaseV2(file.readAsBytesSync());
    return LibraryPulse(
      trackCount: tracks.length,
      playSum: tracks.fold<int>(0, (s, t) => s + t.playCount),
      updatedAt: file.lastModifiedSync().toUtc().toIso8601String(),
    );
  }

  @override
  Map<String, int> readPlayCounts() {
    if (_ensureSqlite()) {
      final rows = _sqlite.ensure(_dbPath!, 'serato_read_copy.sqlite').select('''
SELECT id, IFNULL(dj_play_count, 0) AS playCount
FROM asset
WHERE IFNULL(name, '') != ''
''');
      final counts = <String, int>{};
      for (final row in rows) {
        final id = textOrNull(row['id']);
        if (id == null) continue;
        counts[id] = intOrNull(row['playCount']) ?? 0;
      }
      return counts;
    }
    final tracks = parseSeratoDatabaseV2(File(_requireDatabaseV2()).readAsBytesSync());
    return {for (final t in tracks) t.id: t.playCount};
  }

  @override
  void close() {
    _sqlite.close();
    _dbPath = null;
  }

  bool _ensureSqlite() {
    final path = locateSeratoSqlite(overridePath);
    if (path == null) return false;
    _dbPath = path;
    _sqlite.ensure(path, 'serato_read_copy.sqlite');
    return true;
  }

  HistorySnapshot _readSqliteHistory() {
    final db = _sqlite.ensure(_dbPath!, 'serato_read_copy.sqlite');
    final hasEntry = db.select(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='history_entry'",
    );
    if (hasEntry.isEmpty) {
      return _readSessionHistory();
    }
    // Session mit dem zuletzt gespielten Entry (nicht leere Neusession).
    final rows = db.select('''
SELECT
  he.name AS title,
  he.artist AS artist,
  he.bpm AS bpm,
  he."key" AS musicalKey,
  he.length_sec AS lengthSec,
  he.start_time AS startTime,
  he.portable_id AS location,
  hs.name AS historyName
FROM history_entry he
LEFT JOIN history_session hs ON hs.id = he.session_id
WHERE he.session_id = (
  SELECT he2.session_id
  FROM history_entry he2
  ORDER BY he2.start_time DESC
  LIMIT 1
)
ORDER BY he.start_time DESC
LIMIT 50
''');
    final tracks = <HistoryTrack>[];
    String? historyName;
    var n = rows.length;
    for (final row in rows) {
      historyName ??= textOrNull(row['historyName']);
      final title = textOrNull(row['title']) ?? toolI18n.text('unknownTitle');
      tracks.add(
        HistoryTrack(
          trackNo: n,
          title: title,
          artist: textOrNull(row['artist']) ?? '',
          playedAt: _unix(intOrNull(row['startTime'])),
          historyName: historyName ?? '',
          bpm: doubleOrNull(row['bpm']),
          musicalKey: textOrNull(row['musicalKey']),
          length: _length(intOrNull(row['lengthSec'])),
          location: seratoPortableToPath(textOrNull(row['location'])),
        ),
      );
      n -= 1;
    }
    return HistorySnapshot(
      dbPath: _dbPath ?? '',
      historyName: historyName,
      tracks: tracks,
      readAt: DateTime.now(),
    );
  }

  List<LibraryTrack> _readSqliteLibrary() {
    final rows = _sqlite.ensure(_dbPath!, 'serato_read_copy.sqlite').select('''
SELECT
  id,
  name AS title,
  artist,
  bpm,
  "key" AS musicalKey,
  length_sec AS lengthSec,
  IFNULL(dj_play_count, 0) AS playCount,
  portable_id AS location
FROM asset
WHERE IFNULL(name, '') != ''
  AND IFNULL(is_missing, 0) = 0
''');
    final tracks = <LibraryTrack>[];
    for (final row in rows) {
      final title = textOrNull(row['title']);
      if (title == null) continue;
      tracks.add(
        LibraryTrack(
          id: textOrNull(row['id']) ?? title,
          title: title,
          artist: textOrNull(row['artist']) ?? '',
          bpm: doubleOrNull(row['bpm']),
          musicalKey: textOrNull(row['musicalKey']),
          lengthSec: intOrNull(row['lengthSec']),
          playCount: intOrNull(row['playCount']) ?? 0,
          location: seratoPortableToPath(textOrNull(row['location'])),
        ),
      );
    }
    return tracks;
  }

  HistorySnapshot _readSessionHistory() {
    final folder = locateSeratoFolder(overridePath);
    final session = _latestSessionFile(folder);
    if (session == null) {
      return HistorySnapshot(
        dbPath: folder,
        historyName: null,
        tracks: const [],
        readAt: DateTime.now(),
      );
    }
    final tracks = parseSeratoSession(session.readAsBytesSync());
    return HistorySnapshot(
      dbPath: session.path,
      historyName: session.uri.pathSegments.isEmpty
          ? session.path
          : session.uri.pathSegments.last,
      tracks: tracks,
      readAt: DateTime.now(),
    );
  }

  String _requireDatabaseV2() {
    final path = locateSeratoDatabaseV2(overridePath);
    if (path == null || !File(path).existsSync()) {
      throw StateError(toolI18n.text('errSerato'));
    }
    return path;
  }
}

String? locateSeratoSqlite(String? override) {
  final custom = override?.trim();
  if (custom != null && custom.isNotEmpty) {
    if (custom.toLowerCase().endsWith('.sqlite') && File(custom).existsSync()) {
      return custom;
    }
    final nested = File('$custom/master.sqlite');
    if (nested.existsSync()) return nested.path;
    final library = File('$custom/Library/master.sqlite');
    if (library.existsSync()) return library.path;
  }
  for (final path in _seratoSqliteCandidates()) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

String locateSeratoFolder(String? override) {
  final custom = override?.trim();
  if (custom != null && custom.isNotEmpty) {
    if (FileSystemEntity.isDirectorySync(custom)) return custom;
    if (custom.toLowerCase().endsWith('database v2')) {
      return File(custom).parent.path;
    }
  }
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null) {
    final mac = '$home/Music/_Serato_';
    if (Directory(mac).existsSync()) return mac;
    final win = '$home\\Music\\_Serato_';
    if (Directory(win).existsSync()) return win;
  }
  return custom ?? '';
}

String? locateSeratoDatabaseV2(String? override) {
  final custom = override?.trim();
  if (custom != null && custom.isNotEmpty) {
    if (File(custom).existsSync() &&
        File(custom).uri.pathSegments.last.toLowerCase() == 'database v2') {
      return custom;
    }
    final nested = File('$custom/database V2');
    if (nested.existsSync()) return nested.path;
  }
  final folder = locateSeratoFolder(override);
  if (folder.isEmpty) return null;
  final file = File('$folder/database V2');
  return file.existsSync() ? file.path : null;
}

List<String> _seratoSqliteCandidates() {
  final out = <String>[];
  final home = Platform.environment['HOME'];
  if (home != null) {
    out.add('$home/Library/Application Support/Serato/Library/master.sqlite');
  }
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null) {
    out.add('$local\\Serato\\Library\\master.sqlite');
  }
  final appData = Platform.environment['APPDATA'];
  if (appData != null) {
    out.add('$appData\\Serato\\Library\\master.sqlite');
  }
  return out;
}

File? _latestSessionFile(String folder) {
  if (folder.isEmpty) return null;
  final sep = Platform.pathSeparator;
  final dir = Directory('$folder${sep}History${sep}Sessions');
  if (!dir.existsSync()) return null;
  File? best;
  DateTime? bestTime;
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    if (!entity.path.toLowerCase().endsWith('.session')) continue;
    final m = entity.lastModifiedSync();
    if (bestTime == null || m.isAfter(bestTime)) {
      best = entity;
      bestTime = m;
    }
  }
  return best;
}

String? seratoPortableToPath(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final dragged = toDragLocation(raw);
  if (dragged != null && dragged.startsWith('tidal:')) return dragged;
  if (raw.contains('://')) return dragged ?? raw;
  if (raw.startsWith('/')) return raw;
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(raw)) return raw;
  return '/$raw';
}

List<LibraryTrack> parseSeratoDatabaseV2(Uint8List bytes) {
  final tracks = <LibraryTrack>[];
  for (final entry in parseSeratoTlv(bytes)) {
    if (entry.tag != 'otrk') continue;
    final fields = <String, Uint8List>{
      for (final child in parseSeratoTlv(entry.data)) child.tag: child.data,
    };
    final title = _tlvText(fields['tsng']);
    if (title == null) continue;
    final location = seratoPortableToPath(_tlvText(fields['pfil']));
    tracks.add(
      LibraryTrack(
        id: location ?? title,
        title: title,
        artist: _tlvText(fields['tart']) ?? '',
        bpm: doubleOrNull(_tlvText(fields['tbpm'])),
        musicalKey: _tlvText(fields['tkey']),
        lengthSec: parseSeratoLength(_tlvText(fields['tlen'])),
        playCount: _tlvUint(fields['utpc']) ?? 0,
        location: location,
      ),
    );
  }
  return tracks;
}

List<HistoryTrack> parseSeratoSession(Uint8List bytes) {
  final tracks = <HistoryTrack>[];
  var n = 0;
  for (final entry in parseSeratoTlv(bytes)) {
    if (entry.tag != 'oent') continue;
    n += 1;
    final adat = parseSeratoTlv(entry.data).where((e) => e.tag == 'adat');
    final payload = adat.isEmpty ? entry.data : adat.first.data;
    String? title;
    String? artist;
    DateTime? playedAt;
    double? bpm;
    for (final field in parseSeratoTlv(payload)) {
      final id = seratoNumericTag(field.tag);
      if (id == 6) title = _tlvText(field.data);
      if (id == 7) artist = _tlvText(field.data);
      if (id == 2 || field.tag == 'pfil') {
        continue;
      }
      if (id == 0x35) {
        playedAt = _unix(_tlvUint(field.data));
      }
      if (id == 0x0f) {
        final raw = _tlvUint(field.data);
        if (raw != null && raw > 0) bpm = raw / 100.0;
      }
    }
    if (title == null || title.isEmpty) continue;
    tracks.add(
      HistoryTrack(
        trackNo: n,
        title: title,
        artist: artist ?? '',
        playedAt: playedAt,
        historyName: '',
        bpm: bpm,
        musicalKey: null,
        length: null,
      ),
    );
  }
  return tracks.reversed.toList();
}

class SeratoTlvEntry {
  const SeratoTlvEntry(this.tag, this.data);
  final String tag;
  final Uint8List data;
}

List<SeratoTlvEntry> parseSeratoTlv(Uint8List bytes) {
  final out = <SeratoTlvEntry>[];
  var i = 0;
  while (i + 8 <= bytes.length) {
    final tagBytes = bytes.sublist(i, i + 4);
    final length = ByteData.sublistView(bytes, i + 4, i + 8).getUint32(0);
    i += 8;
    if (length < 0 || i + length > bytes.length) break;
    out.add(SeratoTlvEntry(_tagName(tagBytes), bytes.sublist(i, i + length)));
    i += length;
  }
  return out;
}

int? seratoNumericTag(String tag) {
  if (tag.startsWith('id:')) {
    return int.tryParse(tag.substring(3));
  }
  return null;
}

String _tagName(Uint8List tag) {
  if (tag.length == 4 && tag.every((b) => b >= 32 && b < 127)) {
    return String.fromCharCodes(tag);
  }
  if (tag.length == 4) {
    return 'id:${ByteData.sublistView(tag).getUint32(0)}';
  }
  return String.fromCharCodes(tag);
}

String? _tlvText(Uint8List? data) {
  if (data == null || data.isEmpty) return null;
  try {
    final text = utf16Be(data).replaceAll('\u0000', '').trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    final latin = latin1Fallback(data).trim();
    return latin.isEmpty ? null : latin;
  }
}

int? _tlvUint(Uint8List? data) {
  if (data == null || data.isEmpty) return null;
  if (data.length >= 4) {
    return ByteData.sublistView(data).getUint32(0);
  }
  return null;
}

String utf16Be(Uint8List data) {
  if (data.length.isOdd) {
    return utf8.decode(data, allowMalformed: true);
  }
  return String.fromCharCodes(
    List<int>.generate(data.length ~/ 2, (i) {
      return (data[i * 2] << 8) | data[i * 2 + 1];
    }),
  );
}

String latin1Fallback(Uint8List data) {
  return String.fromCharCodes(data.where((b) => b != 0));
}

int? parseSeratoLength(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) {
    return double.tryParse(raw)?.round();
  }
  final minutes = int.tryParse(parts[0]) ?? 0;
  final seconds = double.tryParse(parts[1]) ?? 0;
  return (minutes * 60 + seconds).round();
}

DateTime? _unix(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
      .toLocal();
}

Duration? _length(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  return Duration(seconds: seconds);
}
