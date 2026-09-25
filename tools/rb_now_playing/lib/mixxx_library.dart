import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'dj_library_source.dart';
import 'tool_i18n.dart';
import 'dj_sqlite.dart';
import 'library_match.dart';
import 'rekordbox_history.dart';

class MixxxLibrarySource implements DjLibrarySource {
  MixxxLibrarySource(this.overridePath);

  final String? overridePath;
  Database? _db;
  String? _dbPath;

  @override
  String get label => 'Mixxx';

  @override
  HistorySnapshot readHistory() {
    final db = _ensure();
    final playlists = sqliteTable(db, const ['Playlists', 'playlists']);
    final playlistTracks = sqliteTable(db, const [
      'PlaylistTracks',
      'playlistTracks',
      'playlisttracks',
    ]);
    final library = sqliteTable(db, const ['library', 'Library']);
    if (sqliteHasTable(db, playlists) && sqliteHasColumn(db, playlists, 'hidden')) {
      final order = sqliteHasColumn(db, playlists, 'date_modified')
          ? 'date_modified DESC, id DESC'
          : 'id DESC';
      final latest = db.select('''
SELECT id, name FROM "$playlists"
WHERE hidden = 2
ORDER BY $order
LIMIT 1
''');
      if (latest.isNotEmpty) {
        final id = latest.first['id'];
        final name = textOrNull(latest.first['name']) ?? 'History';
        final hasWhen = sqliteHasColumn(db, playlistTracks, 'pl_datetime_added');
        final rows = db.select('''
SELECT l.title, l.artist, l.bpm, l.key AS musicalKey, l.duration
${hasWhen ? ', pt.pl_datetime_added AS playedAt' : ''}
FROM "$playlistTracks" pt
JOIN "$library" l ON l.id = pt.track_id
WHERE pt.playlist_id = ?
ORDER BY ${hasWhen ? 'pt.pl_datetime_added DESC, ' : ''}pt.position DESC
LIMIT 80
''', [id]);
        return HistorySnapshot(
          dbPath: _dbPath ?? '',
          historyName: name,
          tracks: _historyRows(rows),
          readAt: DateTime.now(),
        );
      }
    }
    if (sqliteHasColumn(db, library, 'last_played_at')) {
      final rows = db.select('''
SELECT title, artist, bpm, key AS musicalKey, duration, last_played_at AS playedAt
FROM "$library"
WHERE IFNULL(title, '') != ''
  AND last_played_at IS NOT NULL
ORDER BY last_played_at DESC
LIMIT 80
''');
      return HistorySnapshot(
        dbPath: _dbPath ?? '',
        historyName: 'last_played_at',
        tracks: _historyRows(rows),
        readAt: DateTime.now(),
      );
    }
    return HistorySnapshot(
      dbPath: _dbPath ?? '',
      historyName: null,
      tracks: const [],
      readAt: DateTime.now(),
    );
  }

  @override
  List<LibraryTrack> readLibrary() {
    final db = _ensure();
    final library = sqliteTable(db, const ['library', 'Library']);
    final locations = sqliteHasTable(db, 'track_locations')
        ? 'track_locations'
        : sqliteHasTable(db, 'Track_Locations')
            ? 'Track_Locations'
            : null;
    final deleted = sqliteHasColumn(db, library, 'mixxx_deleted')
        ? 'AND IFNULL(l.mixxx_deleted, 0) = 0'
        : '';
    final plays = sqliteHasColumn(db, library, 'timesplayed')
        ? 'IFNULL(l.timesplayed, 0)'
        : '0';
    final urlCol = sqliteHasColumn(db, library, 'url') ? 'l.url' : 'NULL';
    final locJoin = locations == null
        ? 'NULL'
        : 'loc.location';
    final sql = '''
SELECT l.id, l.title, l.artist, l.bpm, l.key AS musicalKey, l.duration,
       $plays AS playCount, $locJoin AS filePath, $urlCol AS url
FROM "$library" l
${locations == null ? '' : 'LEFT JOIN "$locations" loc ON loc.id = l.location'}
WHERE IFNULL(l.title, '') != ''
$deleted
''';
    final rows = db.select(sql);
    final tracks = <LibraryTrack>[];
    for (final row in rows) {
      final title = textOrNull(row['title']);
      if (title == null) continue;
      final file = textOrNull(row['filePath']);
      final url = textOrNull(row['url']);
      final location = toDragLocation(file) ?? toDragLocation(url);
      tracks.add(
        LibraryTrack(
          id: textOrNull(row['id']) ?? title,
          title: title,
          artist: textOrNull(row['artist']) ?? '',
          bpm: doubleOrNull(row['bpm']),
          musicalKey: textOrNull(row['musicalKey']),
          lengthSec: doubleOrNull(row['duration'])?.round(),
          playCount: intOrNull(row['playCount']) ?? 0,
          location: location,
        ),
      );
    }
    if (tracks.isEmpty) {
      throw StateError(toolI18n.text('noTracks', {'name': 'Mixxx'}));
    }
    return tracks;
  }

  @override
  LibraryPulse libraryPulse() {
    final db = _ensure();
    final library = sqliteTable(db, const ['library', 'Library']);
    final plays = sqliteHasColumn(db, library, 'timesplayed')
        ? 'sum(IFNULL(timesplayed, 0))'
        : '0';
    final row = db.select('''
SELECT count(*) AS n, $plays AS plays
FROM "$library"
WHERE IFNULL(title, '') != ''
''').first;
    final file = File(_dbPath ?? '');
    return LibraryPulse(
      trackCount: intOrNull(row['n']) ?? 0,
      playSum: intOrNull(row['plays']) ?? 0,
      updatedAt: file.existsSync()
          ? file.lastModifiedSync().toUtc().toIso8601String()
          : null,
    );
  }

  @override
  Map<String, int> readPlayCounts() {
    final db = _ensure();
    final library = sqliteTable(db, const ['library', 'Library']);
    if (!sqliteHasColumn(db, library, 'timesplayed')) return {};
    final rows = db.select('''
SELECT id, IFNULL(timesplayed, 0) AS playCount
FROM "$library"
WHERE IFNULL(title, '') != ''
''');
    final counts = <String, int>{};
    for (final row in rows) {
      final id = textOrNull(row['id']);
      if (id == null) continue;
      counts[id] = intOrNull(row['playCount']) ?? 0;
    }
    return counts;
  }

  @override
  void close() {
    _db?.close();
    _db = null;
    _dbPath = null;
  }

  Database _ensure() {
    final path = locateMixxxDb(overridePath);
    if (path == null || !File(path).existsSync()) {
      throw StateError(toolI18n.text('errMixxx'));
    }
    if (path != _dbPath) {
      close();
      _dbPath = path;
    }
    return _db ??= openSqliteReadonly(path, 'mixxx_read_copy.sqlite');
  }

  List<HistoryTrack> _historyRows(ResultSet rows) {
    final tracks = <HistoryTrack>[];
    var n = 0;
    for (final row in rows) {
      final title = textOrNull(row['title']);
      if (title == null) continue;
      n += 1;
      final sec = doubleOrNull(row['duration'])?.round();
      tracks.add(
        HistoryTrack(
          trackNo: n,
          title: title,
          artist: textOrNull(row['artist']) ?? '',
          playedAt: _mixxxTime(row['playedAt']),
          historyName: '',
          bpm: doubleOrNull(row['bpm']),
          musicalKey: textOrNull(row['musicalKey']),
          length: sec == null ? null : Duration(seconds: sec),
        ),
      );
    }
    return tracks;
  }
}

String? locateMixxxDb(String? override) {
  final custom = override?.trim();
  if (custom != null && custom.isNotEmpty) {
    if (custom.toLowerCase().endsWith('.sqlite') && File(custom).existsSync()) {
      return custom;
    }
    final nested = File('$custom/mixxxdb.sqlite');
    if (nested.existsSync()) return nested.path;
  }
  for (final path in _mixxxCandidates()) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

List<String> _mixxxCandidates() {
  final home = Platform.environment['HOME'] ?? '';
  final out = <String>[];
  if (home.isNotEmpty) {
    out.add('$home/Library/Application Support/Mixxx/mixxxdb.sqlite');
    out.add('$home/.mixxx/mixxxdb.sqlite');
  }
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) {
    out.add('$local\\Mixxx\\mixxxdb.sqlite');
  }
  return out;
}

DateTime? _mixxxTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}
