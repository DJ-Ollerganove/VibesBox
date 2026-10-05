import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'dj_library_source.dart';
import 'tool_i18n.dart';
import 'dj_sqlite.dart';
import 'library_match.dart';
import 'rekordbox_history.dart';

class EngineDjLibrarySource implements DjLibrarySource {
  EngineDjLibrarySource(this.overridePath);

  final String? overridePath;
  final _sqlite = ReadonlySqlite();
  String? _dbPath;
  String? _hmAttachedFrom;

  @override
  String get label => 'Engine DJ';

  @override
  HistorySnapshot readHistory() {
    final db = _ensure();
    final track = sqliteTable(db, const ['Track', 'track']);
    // Zuerst Quellen mit Einträgen prüfen (leere Haupttabelle nicht bevorzugen).
    for (final candidate in [
      (
        table: 'hist.HistorylistEntity',
        name: 'hm.HistorylistEntity',
        sql: '''
SELECT e.startTime AS playedAt, t.title, t.artist, t.bpm, t.key AS musicalKey, t.length
FROM hist.HistorylistEntity e
JOIN "$track" t ON t.id = e.trackId
ORDER BY e.startTime DESC
LIMIT 80
''',
      ),
      (
        table: 'HistorylistEntity',
        name: 'HistorylistEntity',
        sql: '''
SELECT e.startTime AS playedAt, t.title, t.artist, t.bpm, t.key AS musicalKey, t.length
FROM HistorylistEntity e
JOIN "$track" t ON t.id = e.trackId
ORDER BY e.startTime DESC
LIMIT 80
''',
      ),
    ]) {
      if (!sqliteHasTable(db, candidate.table)) continue;
      final rows = db.select(candidate.sql);
      final tracks = _historyRows(rows);
      if (tracks.isEmpty) continue;
      return HistorySnapshot(
        dbPath: _dbPath ?? '',
        historyName: candidate.name,
        tracks: tracks,
        readAt: DateTime.now(),
      );
    }
    if (sqliteHasTable(db, 'HistorylistTrackList')) {
      final dateCol = sqliteHasColumn(db, 'HistorylistTrackList', 'date')
          ? 'h.date'
          : 'NULL';
      final rows = db.select('''
SELECT $dateCol AS playedAt, t.title, t.artist, t.bpm, t.key AS musicalKey, t.length
FROM HistorylistTrackList h
JOIN "$track" t ON t.id = h.trackId
ORDER BY $dateCol DESC
LIMIT 80
''');
      return HistorySnapshot(
        dbPath: _dbPath ?? '',
        historyName: 'HistorylistTrackList',
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
    final track = sqliteTable(db, const ['Track', 'track']);
    final modern = sqliteHasColumn(db, track, 'title');
    final tracks = modern ? _readModern(db, track) : _readLegacy(db, track);
    if (tracks.isEmpty) {
      throw StateError(toolI18n.text('noTracks', {'name': 'Engine DJ'}));
    }
    return tracks;
  }

  @override
  LibraryPulse libraryPulse() {
    final db = _ensure();
    final track = sqliteTable(db, const ['Track', 'track']);
    final plays = sqliteHasColumn(db, track, 'playCount')
        ? 'sum(IFNULL(playCount, 0))'
        : '0';
    final row = db.select('SELECT count(*) AS n, $plays AS plays FROM "$track"')
        .first;
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
    final track = sqliteTable(db, const ['Track', 'track']);
    if (!sqliteHasColumn(db, track, 'playCount')) {
      return {for (final t in readLibrary()) t.id: t.playCount};
    }
    final rows = db.select(
      'SELECT id, IFNULL(playCount, 0) AS playCount FROM "$track"',
    );
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
    _sqlite.close();
    _dbPath = null;
    _hmAttachedFrom = null;
  }

  Database _ensure() {
    final path = locateEngineMasterDb(overridePath);
    if (path == null || !File(path).existsSync()) {
      throw StateError(toolI18n.text('errEngine'));
    }
    final wasCopy = _sqlite.openedViaCopy;
    final db = _sqlite.ensure(path, 'engine_m_copy.sqlite');
    _dbPath = path;
    final hm = File('${File(path).parent.path}${Platform.pathSeparator}hm.db');
    final needAttach = hm.existsSync() &&
        (_hmAttachedFrom != hm.path || wasCopy || _sqlite.openedViaCopy);
    if (needAttach) {
      try {
        db.execute('DETACH DATABASE hist');
      } catch (_) {}
      try {
        final copy = copySqliteForRead(hm.path, 'engine_h_copy.sqlite');
        db.execute(
          "ATTACH DATABASE '${copy.replaceAll("'", "''")}' AS hist",
        );
        _hmAttachedFrom = hm.path;
      } catch (_) {
        _hmAttachedFrom = null;
      }
    }
    return db;
  }

  List<LibraryTrack> _readModern(Database db, String track) {
    final playCol = sqliteHasColumn(db, track, 'playCount')
        ? 'IFNULL(playCount, 0)'
        : '0';
    final uriCol = sqliteHasColumn(db, track, 'uri') ? 'uri' : 'NULL';
    final keyCol = sqliteHasColumn(db, track, 'key') ? 'key' : 'NULL';
    final root = engineLibraryRoot(_dbPath ?? '');
    final rows = db.select('''
SELECT id, title, artist, bpm, $keyCol AS musicalKey, length,
       $playCol AS playCount, path, filename, $uriCol AS uri
FROM "$track"
WHERE IFNULL(title, '') != ''
''');
    final out = <LibraryTrack>[];
    for (final row in rows) {
      final title = textOrNull(row['title']);
      if (title == null) continue;
      final location = toDragLocation(textOrNull(row['uri'])) ??
          engineAbsolutePath(
            root,
            textOrNull(row['path']),
            textOrNull(row['filename']),
          );
      out.add(
        LibraryTrack(
          id: textOrNull(row['id']) ?? title,
          title: title,
          artist: textOrNull(row['artist']) ?? '',
          bpm: doubleOrNull(row['bpm']),
          musicalKey: textOrNull(row['musicalKey']),
          lengthSec: intOrNull(row['length']),
          playCount: intOrNull(row['playCount']) ?? 0,
          location: location,
        ),
      );
    }
    return out;
  }

  List<LibraryTrack> _readLegacy(Database db, String track) {
    final root = engineLibraryRoot(_dbPath ?? '');
    final rows = db.select('''
SELECT t.id, t.path, t.filename, t.bpm, t.length,
       (SELECT text FROM MetaData WHERE id = t.id AND type = 1) AS title,
       (SELECT text FROM MetaData WHERE id = t.id AND type = 2) AS artist
FROM "$track" t
''');
    final out = <LibraryTrack>[];
    for (final row in rows) {
      final title = textOrNull(row['title']);
      if (title == null) continue;
      out.add(
        LibraryTrack(
          id: textOrNull(row['id']) ?? title,
          title: title,
          artist: textOrNull(row['artist']) ?? '',
          bpm: doubleOrNull(row['bpm']),
          lengthSec: intOrNull(row['length']),
          location: engineAbsolutePath(
            root,
            textOrNull(row['path']),
            textOrNull(row['filename']),
          ),
        ),
      );
    }
    return out;
  }

  List<HistoryTrack> _historyRows(ResultSet rows) {
    final tracks = <HistoryTrack>[];
    var n = 0;
    for (final row in rows) {
      final title = textOrNull(row['title']);
      if (title == null) continue;
      n += 1;
      final sec = intOrNull(row['length']);
      tracks.add(
        HistoryTrack(
          trackNo: n,
          title: title,
          artist: textOrNull(row['artist']) ?? '',
          playedAt: _unix(row['playedAt']),
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

String? locateEngineMasterDb(String? override) {
  final custom = override?.trim();
  if (custom != null && custom.isNotEmpty) {
    if (custom.toLowerCase().endsWith('.db') && File(custom).existsSync()) {
      return custom;
    }
    for (final nested in [
      '$custom/m.db',
      '$custom/Database2/m.db',
      '$custom/Engine Library/Database2/m.db',
    ]) {
      if (File(nested).existsSync()) return nested;
    }
  }
  for (final path in _engineCandidates()) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

List<String> _engineCandidates() {
  final home = Platform.environment['HOME'] ?? '';
  final out = <String>[];
  if (home.isNotEmpty) {
    out.add('$home/Music/Engine Library/Database2/m.db');
  }
  final user = Platform.environment['USERPROFILE'];
  if (user != null && user.isNotEmpty) {
    out.add('$user\\Music\\Engine Library\\Database2\\m.db');
  }
  return out;
}

String engineLibraryRoot(String masterDbPath) {
  final db = File(masterDbPath);
  final database2 = db.parent;
  if (database2.path.split(Platform.pathSeparator).last == 'Database2') {
    return database2.parent.path;
  }
  return database2.path;
}

String? engineAbsolutePath(String root, String? path, String? filename) {
  final direct = toDragLocation(path);
  if (direct != null &&
      (direct.startsWith('/') ||
          direct.startsWith('tidal:') ||
          RegExp(r'^[A-Za-z]:[\\/]').hasMatch(direct))) {
    return direct;
  }
  if (path != null && path.trim().isNotEmpty) {
    final rel = path.trim();
    if (root.isEmpty) return rel;
    return '$root${Platform.pathSeparator}$rel';
  }
  if (filename == null || filename.trim().isEmpty) return null;
  return filename;
}

DateTime? _unix(Object? raw) {
  final n = intOrNull(raw);
  if (n == null || n <= 0) return null;
  if (n > 1000000000000) {
    return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
}
