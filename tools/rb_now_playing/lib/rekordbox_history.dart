import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'dj_sqlite.dart';
import 'library_match.dart';
import 'rekordbox_cipher.dart';
import 'tool_i18n.dart';

class HistoryTrack {
  const HistoryTrack({
    required this.trackNo,
    required this.title,
    required this.artist,
    required this.playedAt,
    required this.historyName,
    required this.bpm,
    required this.musicalKey,
    required this.length,
    this.location,
  });

  final int trackNo;
  final String title;
  final String artist;
  final DateTime? playedAt;
  final String historyName;
  final double? bpm;
  final String? musicalKey;
  final Duration? length;
  /// Lokaler Dateipfad oder Streaming-URI (wenn bekannt).
  final String? location;

  String get identity => '$trackNo|$title|$artist|${playedAt?.toUtc().toIso8601String()}';
}

class HistorySnapshot {
  const HistorySnapshot({
    required this.dbPath,
    required this.historyName,
    required this.tracks,
    this.recent = const [],
    required this.readAt,
    this.debugNote,
  });

  final String dbPath;
  final String? historyName;
  final List<HistoryTrack> tracks;
  /// Gespielte Titel der letzten 12 Stunden, auch aus älteren Playlists.
  final List<HistoryTrack> recent;
  final DateTime readAt;
  /// Diagnose für die UI: Zähler, Open-Modus, leere-History-Hinweis.
  final String? debugNote;

  HistoryTrack? get nowPlaying => tracks.isEmpty ? null : tracks.first;
}

class LibraryPulse {
  const LibraryPulse({
    required this.trackCount,
    required this.playSum,
    this.updatedAt,
  });

  final int trackCount;
  final int playSum;
  final String? updatedAt;

  bool sameAs(LibraryPulse? other) {
    if (other == null) return false;
    return trackCount == other.trackCount &&
        playSum == other.playSum &&
        updatedAt == other.updatedAt;
  }

  Map<String, dynamic> toJson() => {
        'n': trackCount,
        'p': playSum,
        if (updatedAt != null) 'u': updatedAt,
      };

  factory LibraryPulse.fromJson(Map<String, dynamic> json) {
    return LibraryPulse(
      trackCount: json['n'] is int ? json['n'] as int : 0,
      playSum: json['p'] is int ? json['p'] as int : 0,
      updatedAt: json['u']?.toString(),
    );
  }
}

class RekordboxHistoryReader {
  Database? _db;
  String? _dbPath;
  String? _key;
  String? overrideDbPath;
  var _openedViaCopy = false;

  String? get dbPath => _dbPath;

  HistorySnapshot read() {
    // Wie what's-now-playing: JEDEN Poll neue Connection.
    close();
    _ensureOpen();
    final db = _db!;
    final path = _dbPath ?? '';
    final wal = File('$path-wal');
    final songCount = _count(db, 'djmdSongHistory');
    final contentCount = _count(db, 'djmdContent');
    final via = _openedViaCopy ? 'copy' : 'direct';
    final walNote = wal.existsSync()
        ? 'WAL ${(wal.lengthSync() / 1024).round()}kb'
        : 'kein-WAL';

    // Nur djmdSongHistory – wie Mac. Kein Library-/PlayCount-Fallback.
    var session = _mapHistoryRows(_selectLatestHistory(db, limit: 1));
    if (session.$1.isNotEmpty) {
      final hid = _latestHistoryId(db);
      if (hid != null) {
        final full = _mapHistoryRows(_selectHistoryForId(db, hid, limit: 50));
        if (full.$1.isNotEmpty) session = full;
      }
    }
    if (session.$1.isEmpty && songCount > 0) {
      session = _mapHistoryRows(_selectHistoryAny(db, limit: 50));
    }

    List<HistoryTrack> recent = const [];
    try {
      final since = DateTime.now().subtract(const Duration(hours: 12));
      final recentRows = db.select('''
SELECT
  sh.TrackNo AS trackNo,
  sh.created_at AS playedAt,
  h.Name AS historyName,
  c.Title AS title,
  a.Name AS artist,
  c.BPM AS bpm,
  k.ScaleName AS musicalKey,
  c.Length AS lengthSec,
  c.FolderPath AS location
FROM djmdSongHistory sh
LEFT JOIN djmdHistory h ON h.ID = sh.HistoryID
LEFT JOIN djmdContent c ON c.ID = sh.ContentID
LEFT JOIN djmdArtist a ON a.ID = c.ArtistID
LEFT JOIN djmdKey k ON k.ID = c.KeyID
WHERE IFNULL(h.rb_local_deleted, 0) = 0
  AND sh.created_at >= ?
ORDER BY sh.created_at DESC
LIMIT 120
''', [_rekordboxStamp(since)]);
      recent = _mapHistoryRows(recentRows).$1;
    } catch (_) {
      recent = const [];
    }

    final emptyHint = session.$1.isEmpty
        ? (songCount == 0
            ? (contentCount > 0
                ? 'Warte auf Play (djmdSongHistory noch leer)'
                : 'DB ohne Tracks – falscher master.db Pfad?')
            : 'History-Zeilen=$songCount aber Query leer')
        : null;
    final debug = [
      'hist=$songCount',
      'lib=$contentCount',
      via,
      walNote,
      if (emptyHint != null) emptyHint,
    ].join(' · ');

    return HistorySnapshot(
      dbPath: path,
      historyName: session.$2,
      tracks: session.$1,
      recent: recent,
      readAt: DateTime.now(),
      debugNote: debug,
    );
  }

  int _count(Database db, String table) {
    try {
      final n = db.select('SELECT count(*) AS n FROM "$table"').first['n'];
      return _asInt(n) ?? 0;
    } catch (_) {
      return -1;
    }
  }

  String? _latestHistoryId(Database db) {
    for (final sql in const [
      'SELECT sh.HistoryID AS hid FROM djmdSongHistory sh ORDER BY sh.created_at DESC, sh.TrackNo DESC LIMIT 1',
      'SELECT sh.HistoryID AS hid FROM djmdSongHistory sh ORDER BY sh.ID DESC LIMIT 1',
      'SELECT sh.HistoryID AS hid FROM djmdSongHistory sh LIMIT 1',
    ]) {
      try {
        final rows = db.select(sql);
        if (rows.isEmpty) continue;
        final hid = rows.first['hid']?.toString();
        if (hid != null && hid.isNotEmpty) return hid;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  ResultSet _selectLatestHistory(Database db, {required int limit}) {
    for (final order in const [
      'sh.created_at DESC, sh.TrackNo DESC',
      'sh.ID DESC',
      'sh.rowid DESC',
    ]) {
      try {
        return db.select('''
SELECT
  sh.TrackNo AS trackNo,
  sh.created_at AS playedAt,
  h.Name AS historyName,
  c.Title AS title,
  a.Name AS artist,
  c.BPM AS bpm,
  k.ScaleName AS musicalKey,
  c.Length AS lengthSec,
  c.FolderPath AS location
FROM djmdSongHistory sh
LEFT JOIN djmdHistory h ON h.ID = sh.HistoryID
LEFT JOIN djmdContent c ON c.ID = sh.ContentID
LEFT JOIN djmdArtist a ON a.ID = c.ArtistID
LEFT JOIN djmdKey k ON k.ID = c.KeyID
ORDER BY $order
LIMIT $limit
''');
      } catch (_) {
        continue;
      }
    }
    return _selectHistoryAny(db, limit: limit);
  }

  ResultSet _selectHistoryForId(Database db, String hid, {required int limit}) {
    try {
      return db.select('''
SELECT
  sh.TrackNo AS trackNo,
  sh.created_at AS playedAt,
  h.Name AS historyName,
  c.Title AS title,
  a.Name AS artist,
  c.BPM AS bpm,
  k.ScaleName AS musicalKey,
  c.Length AS lengthSec,
  c.FolderPath AS location
FROM djmdSongHistory sh
LEFT JOIN djmdHistory h ON h.ID = sh.HistoryID
LEFT JOIN djmdContent c ON c.ID = sh.ContentID
LEFT JOIN djmdArtist a ON a.ID = c.ArtistID
LEFT JOIN djmdKey k ON k.ID = c.KeyID
WHERE sh.HistoryID = ?
ORDER BY sh.TrackNo DESC
LIMIT $limit
''', [hid]);
    } catch (_) {
      return _selectHistoryAny(db, limit: limit);
    }
  }

  ResultSet _selectHistoryAny(Database db, {required int limit}) {
    return db.select('''
SELECT
  sh.TrackNo AS trackNo,
  sh.created_at AS playedAt,
  h.Name AS historyName,
  c.Title AS title,
  a.Name AS artist,
  c.BPM AS bpm,
  k.ScaleName AS musicalKey,
  c.Length AS lengthSec,
  c.FolderPath AS location
FROM djmdSongHistory sh
LEFT JOIN djmdHistory h ON h.ID = sh.HistoryID
LEFT JOIN djmdContent c ON c.ID = sh.ContentID
LEFT JOIN djmdArtist a ON a.ID = c.ArtistID
LEFT JOIN djmdKey k ON k.ID = c.KeyID
LIMIT $limit
''');
  }

  (List<HistoryTrack>, String?) _mapHistoryRows(ResultSet rows) {
    final tracks = <HistoryTrack>[];
    String? historyName;
    for (final row in rows) {
      historyName ??= _asString(row['historyName']);
      tracks.add(
        HistoryTrack(
          trackNo: _asInt(row['trackNo']) ?? 0,
          title: _asString(row['title']) ?? toolI18n.text('unknownTitle'),
          artist: _asString(row['artist']) ?? toolI18n.text('unknownArtist'),
          playedAt: _parseRekordboxTime(_asString(row['playedAt'])),
          historyName: historyName ?? '',
          bpm: _asBpm(row['bpm']),
          musicalKey: _asString(row['musicalKey']),
          length: _asLength(row['lengthSec']),
          location: _asString(row['location']),
        ),
      );
    }
    return (tracks, historyName);
  }

  List<LibraryTrack> readLibrary() {
    _ensureOpen();
    final db = _db!;
    final rows = db.select('''
SELECT
  c.ID AS id,
  c.Title AS title,
  a.Name AS artist,
  c.BPM AS bpm,
  k.ScaleName AS musicalKey,
  c.Length AS lengthSec,
  IFNULL(c.DJPlayCount, 0) AS playCount,
  c.FolderPath AS location
FROM djmdContent c
LEFT JOIN djmdArtist a ON a.ID = c.ArtistID
LEFT JOIN djmdKey k ON k.ID = c.KeyID
WHERE IFNULL(c.rb_local_deleted, 0) = 0
  AND IFNULL(c.Title, '') != ''
''');
    final tracks = <LibraryTrack>[];
    for (final row in rows) {
      final title = _asString(row['title']);
      if (title == null) continue;
      tracks.add(
        LibraryTrack(
          id: _asString(row['id']) ?? title,
          title: title,
          artist: _asString(row['artist']) ?? '',
          bpm: _asBpm(row['bpm']),
          musicalKey: _asString(row['musicalKey']),
          lengthSec: _asInt(row['lengthSec']),
          playCount: _asInt(row['playCount']) ?? 0,
          location: _asString(row['location']),
        ),
      );
    }
    return tracks;
  }

  LibraryPulse libraryPulse() {
    _ensureOpen();
    final row = _db!.select('''
SELECT
  count(*) AS n,
  sum(IFNULL(DJPlayCount, 0)) AS plays,
  max(updated_at) AS updatedAt
FROM djmdContent
WHERE IFNULL(rb_local_deleted, 0) = 0
  AND IFNULL(Title, '') != ''
''').first;
    return LibraryPulse(
      trackCount: _asInt(row['n']) ?? 0,
      playSum: _asInt(row['plays']) ?? 0,
      updatedAt: _asString(row['updatedAt']),
    );
  }

  Map<String, int> readPlayCounts() {
    _ensureOpen();
    final rows = _db!.select('''
SELECT c.ID AS id, IFNULL(c.DJPlayCount, 0) AS playCount
FROM djmdContent c
WHERE IFNULL(c.rb_local_deleted, 0) = 0
  AND IFNULL(c.Title, '') != ''
''');
    final counts = <String, int>{};
    for (final row in rows) {
      final id = _asString(row['id']);
      if (id == null) continue;
      counts[id] = _asInt(row['playCount']) ?? 0;
    }
    return counts;
  }

  HistoryTrack? lookupByPath(String filePath) {
    _ensureOpen();
    final db = _db!;
    final name = filePath.split(RegExp(r'[/\\]')).last;
    if (name.isEmpty) return null;
    final rows = db.select(
      '''
SELECT c.Title AS title, a.Name AS artist, c.BPM AS bpm, k.ScaleName AS musicalKey,
       c.Length AS lengthSec, c.FolderPath AS folderPath
FROM djmdContent c
LEFT JOIN djmdArtist a ON a.ID = c.ArtistID
LEFT JOIN djmdKey k ON k.ID = c.KeyID
WHERE IFNULL(c.rb_local_deleted, 0) = 0
  AND (
    c.FolderPath = ?
    OR c.FileNameL = ?
    OR c.FileNameS = ?
    OR lower(c.FolderPath) LIKE '%' || lower(?)
  )
LIMIT 1
''',
      [filePath, name, name, name],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return HistoryTrack(
      trackNo: 0,
      title: _asString(row['title']) ?? name,
      artist: _asString(row['artist']) ?? '',
      playedAt: null,
      historyName: '',
      bpm: _asBpm(row['bpm']),
      musicalKey: _asString(row['musicalKey']),
      length: _asLength(row['lengthSec']),
    );
  }

  void close() {
    _db?.close();
    _db = null;
    _openedViaCopy = false;
  }

  void _ensureOpen() {
    final path = locateMasterDb(override: overrideDbPath);
    close();
    _dbPath = path;

    _key ??= rekordboxSqlCipherKey();
    Object? directError;
    Object? copyError;

    // WIN_WAL_COPY: Unter Windows gelingt live open oft OHNE WAL zu sehen
    // (hist=0, lib voll). Deshalb immer frischer Snapshot DB+WAL (ohne Live-SHM).
    // Mac: live first (sieht WAL), Kopie nur bei Lock.
    if (Platform.isWindows) {
      try {
        final copyPath = copySqliteForRead(path, 'rekordbox_master_copy.db');
        _db = _openEncrypted(copyPath);
        _openedViaCopy = true;
        return;
      } catch (error) {
        copyError = error;
      }
    }

    try {
      _db = _openEncrypted(path);
      _openedViaCopy = false;
      // Windows-Fallback nach fehlgeschlagener Kopie: wenn live hist=0 aber
      // WAL existiert, Kopie nochmal versuchen (Lock war kurz).
      if (Platform.isWindows) {
        final wal = File('$path-wal');
        final liveHist = _count(_db!, 'djmdSongHistory');
        if (liveHist == 0 && wal.existsSync() && wal.lengthSync() > 0) {
          try {
            final copyPath =
                copySqliteForRead(path, 'rekordbox_master_copy.db');
            final copyDb = _openEncrypted(copyPath);
            final copyHist = _count(copyDb, 'djmdSongHistory');
            if (copyHist > liveHist) {
              _db!.close();
              _db = copyDb;
              _openedViaCopy = true;
              return;
            }
            copyDb.close();
          } catch (_) {}
        }
      }
      return;
    } catch (error) {
      directError = error;
    }

    try {
      final copyPath = copySqliteForRead(path, 'rekordbox_master_copy.db');
      _db = _openEncrypted(copyPath);
      _openedViaCopy = true;
    } catch (error) {
      throw StateError(
        '${toolI18n.text('errRbOpen')}\n$path\n'
        '${copyError ?? directError}\n$error',
      );
    }
  }

  Database _openEncrypted(String path) {
    return withSqliteRetry(() {
      // Normal öffnen (nicht mode=ro), damit WAL/SHM lesbar ist.
      final db = sqlite3.open(path);
      try {
        db.execute("PRAGMA cipher = 'sqlcipher'");
        db.execute('PRAGMA legacy = 4');
        try {
          db.execute('PRAGMA cipher_compatibility = 4');
        } catch (_) {}
        db.execute('PRAGMA key="$_key"');
        db.execute('PRAGMA read_uncommitted = 1');
        db.select('SELECT count(*) FROM sqlite_master');
        db.select(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='djmdSongHistory' LIMIT 1",
        );
        return db;
      } catch (error) {
        db.close();
        rethrow;
      }
    });
  }
}

String locateMasterDb({String? override}) {
  final custom = override?.trim();
  // Fehlender Override blockiert die Suche nicht (Standardpfad kann leer sein,
  // während options.json den echten db-path hat).
  if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
    return custom;
  }

  final fromAgent = _dbPathFromOptionsJson();
  if (fromAgent != null && File(fromAgent).existsSync()) {
    return fromAgent;
  }

  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'];
  if (home != null) {
    final macPath = '$home/Library/Pioneer/rekordbox/master.db';
    if (File(macPath).existsSync()) return macPath;
  }

  final appData = Platform.environment['APPDATA'];
  if (appData != null) {
    final winPath = '$appData\\Pioneer\\rekordbox\\master.db';
    if (File(winPath).existsSync()) return winPath;
  }

  if (custom != null && custom.isNotEmpty) {
    throw StateError('${toolI18n.text('errNotFound')}\n$custom');
  }
  throw StateError(toolI18n.text('errRb'));
}

String? _dbPathFromOptionsJson() {
  final candidates = <String>[];
  final home = Platform.environment['HOME'];
  if (home != null) {
    candidates.add(
      '$home/Library/Application Support/Pioneer/rekordboxAgent/storage/options.json',
    );
  }
  final appData = Platform.environment['APPDATA'];
  if (appData != null) {
    candidates.add('$appData\\Pioneer\\rekordboxAgent\\storage\\options.json');
  }

  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      final json = jsonDecode(file.readAsStringSync());
      final options = json['options'];
      if (options is! List) continue;
      for (final entry in options) {
        if (entry is List && entry.length >= 2 && entry[0] == 'db-path') {
          final value = entry[1];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    } catch (_) {
      continue;
    }
  }
  return null;
}

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asBpm(Object? value) {
  final raw = _asInt(value);
  if (raw == null || raw <= 0) return null;
  return raw / 100.0;
}

Duration? _asLength(Object? value) {
  final seconds = _asInt(value);
  if (seconds == null || seconds <= 0) return null;
  return Duration(seconds: seconds);
}

String _rekordboxStamp(DateTime local) {
  String two(int n) => n.toString().padLeft(2, '0');
  final t = local.toLocal();
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

DateTime? _parseRekordboxTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final compact = raw.replaceFirst(' ', 'T').replaceAll(' ', '');
  return DateTime.tryParse(compact)?.toLocal();
}
