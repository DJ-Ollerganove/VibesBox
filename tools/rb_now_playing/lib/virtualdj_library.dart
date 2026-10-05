import 'dart:convert';
import 'dart:io';

import 'dj_library_source.dart';
import 'tool_i18n.dart';
import 'library_match.dart';
import 'rekordbox_history.dart';

class VirtualDjLibrarySource implements DjLibrarySource {
  VirtualDjLibrarySource(this.overridePath);

  final String? overridePath;
  List<LibraryTrack>? _tracks;
  String? _xmlPath;
  DateTime? _mtime;
  int? _size;

  @override
  String get label => 'Virtual DJ';

  @override
  HistorySnapshot readHistory() {
    final xmlPath = _requireXml();
    final m3u = _latestHistoryPlaylist(xmlPath);
    if (m3u != null) {
      final tracks = parseVirtualDjM3u(m3u.readAsStringSync());
      return HistorySnapshot(
        dbPath: m3u.path,
        historyName: m3u.uri.pathSegments.isEmpty
            ? m3u.path
            : m3u.uri.pathSegments.last,
        tracks: tracks,
        readAt: DateTime.now(),
      );
    }
    final byLast = parseVirtualDjLastPlayed(File(xmlPath).readAsStringSync());
    return HistorySnapshot(
      dbPath: xmlPath,
      historyName: 'LastPlay',
      tracks: byLast,
      readAt: DateTime.now(),
    );
  }

  @override
  List<LibraryTrack> readLibrary() {
    final tracks = _libraryCached();
    if (tracks.isEmpty) {
      throw StateError(toolI18n.text('noTracks', {'name': 'Virtual DJ'}));
    }
    return tracks;
  }

  @override
  LibraryPulse libraryPulse() {
    final file = File(_requireXml());
    final tracks = _libraryCached();
    return LibraryPulse(
      trackCount: tracks.length,
      playSum: tracks.fold<int>(0, (s, t) => s + t.playCount),
      updatedAt: file.lastModifiedSync().toUtc().toIso8601String(),
    );
  }

  @override
  Map<String, int> readPlayCounts() {
    final tracks = _libraryCached();
    return {for (final t in tracks) t.id: t.playCount};
  }

  @override
  void close() {
    _tracks = null;
    _xmlPath = null;
    _mtime = null;
    _size = null;
  }

  List<LibraryTrack> _libraryCached() {
    final path = _requireXml();
    final file = File(path);
    final mtime = file.lastModifiedSync();
    final size = file.lengthSync();
    if (_tracks != null &&
        _xmlPath == path &&
        _mtime == mtime &&
        _size == size) {
      return _tracks!;
    }
    final tracks = parseVirtualDjDatabase(file.readAsStringSync());
    _tracks = tracks;
    _xmlPath = path;
    _mtime = mtime;
    _size = size;
    return tracks;
  }

  String _requireXml() {
    final path = locateVirtualDjDatabase(overridePath);
    if (path == null) {
      throw StateError(toolI18n.text('errVdj'));
    }
    return path;
  }
}

String? locateVirtualDjDatabase(String? override) {
  final custom = override?.trim();
  if (custom != null && custom.isNotEmpty) {
    if (File(custom).existsSync()) return custom;
    final nested = File('$custom/database.xml');
    if (nested.existsSync()) return nested.path;
  }
  for (final path in virtualDjDatabaseCandidates()) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

List<String> virtualDjDatabaseCandidates() {
  final out = <String>[];
  final home = Platform.environment['HOME'];
  if (home != null) {
    out.add('$home/Library/Application Support/VirtualDJ/database.xml');
    out.add('$home/Documents/VirtualDJ/database.xml');
  }
  final appData = Platform.environment['APPDATA'];
  if (appData != null) {
    out.add('$appData\\VirtualDJ\\database.xml');
  }
  final user = Platform.environment['USERPROFILE'];
  if (user != null) {
    out.add('$user\\Documents\\VirtualDJ\\database.xml');
  }
  return out;
}

File? _latestHistoryPlaylist(String xmlPath) {
  final root = File(xmlPath).parent;
  File? best;
  DateTime? bestTime;
  void consider(Directory dir) {
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.m3u') && !lower.endsWith('.m3u8')) continue;
      // Leere Playlists überspringen.
      if (entity.lengthSync() < 32) continue;
      final m = entity.lastModifiedSync();
      if (bestTime == null || m.isAfter(bestTime!)) {
        best = entity;
        bestTime = m;
      }
    }
  }

  consider(Directory('${root.path}${Platform.pathSeparator}History'));
  consider(Directory('${root.path}${Platform.pathSeparator}Tracklisting'));
  final home = Platform.environment['HOME'];
  if (home != null) {
    consider(Directory('$home/Documents/VirtualDJ/History'));
    consider(Directory('$home/Documents/VirtualDJ/Tracklisting'));
  }
  final user = Platform.environment['USERPROFILE'];
  if (user != null) {
    consider(Directory('$user\\Documents\\VirtualDJ\\History'));
    consider(Directory('$user\\Documents\\VirtualDJ\\Tracklisting'));
  }
  final appData = Platform.environment['APPDATA'];
  if (appData != null) {
    consider(Directory('$appData\\VirtualDJ\\History'));
    consider(Directory('$appData\\VirtualDJ\\Tracklisting'));
  }
  return best;
}

List<LibraryTrack> parseVirtualDjDatabase(String xml) {
  final tracks = <LibraryTrack>[];
  final songRe = RegExp(r'<Song\b([^>]*)>(.*?)</Song>', dotAll: true);
  for (final match in songRe.allMatches(xml)) {
    final attrs = parseXmlAttributes(match.group(1) ?? '');
    final body = match.group(2) ?? '';
    final tags = _firstTag(body, 'Tags');
    final infos = _firstTag(body, 'Infos');
    final scan = _firstTag(body, 'Scan');
    final path = unescapeXml(attrs['FilePath'] ?? '');
    final title = unescapeXml(tags['Title'] ?? '').trim();
    if (title.isEmpty) continue;
    final artist = unescapeXml(tags['Author'] ?? tags['Artist'] ?? '').trim();
    tracks.add(
      LibraryTrack(
        id: path.isEmpty ? title : path,
        title: title,
        artist: artist,
        bpm: virtualDjBpm(scan['Bpm'] ?? tags['Bpm']),
        musicalKey: unescapeXml(scan['Key'] ?? tags['Key'] ?? '').trim().isEmpty
            ? null
            : unescapeXml(scan['Key'] ?? tags['Key'] ?? '').trim(),
        lengthSec: doubleOrNull(infos['SongLength'])?.round(),
        playCount: intOrNull(infos['PlayCount']) ?? 0,
        location: path.isEmpty ? null : toDragLocation(path),
      ),
    );
  }
  return tracks;
}

List<HistoryTrack> parseVirtualDjLastPlayed(String xml) {
  final items = <({DateTime? at, HistoryTrack track})>[];
  final songRe = RegExp(r'<Song\b([^>]*)>(.*?)</Song>', dotAll: true);
  var n = 0;
  for (final match in songRe.allMatches(xml)) {
    final body = match.group(2) ?? '';
    final tags = _firstTag(body, 'Tags');
    final infos = _firstTag(body, 'Infos');
    final scan = _firstTag(body, 'Scan');
    final last = intOrNull(infos['LastPlay']);
    if (last == null || last <= 0) continue;
    final title = unescapeXml(tags['Title'] ?? '').trim();
    if (title.isEmpty) continue;
    n += 1;
    items.add(
      (
        at: DateTime.fromMillisecondsSinceEpoch(last * 1000, isUtc: true)
            .toLocal(),
        track: HistoryTrack(
          trackNo: n,
          title: title,
          artist: unescapeXml(tags['Author'] ?? '').trim(),
          playedAt: DateTime.fromMillisecondsSinceEpoch(last * 1000, isUtc: true)
              .toLocal(),
          historyName: 'LastPlay',
          bpm: virtualDjBpm(scan['Bpm'] ?? tags['Bpm']),
          musicalKey: unescapeXml(scan['Key'] ?? tags['Key'] ?? '').trim().isEmpty
              ? null
              : unescapeXml(scan['Key'] ?? tags['Key'] ?? '').trim(),
          length: () {
            final sec = doubleOrNull(infos['SongLength'])?.round();
            if (sec == null || sec <= 0) return null;
            return Duration(seconds: sec);
          }(),
        ),
      ),
    );
  }
  items.sort((a, b) {
    final at = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return [for (final item in items.take(50)) item.track];
}

List<HistoryTrack> parseVirtualDjM3u(String raw) {
  final lines = const LineSplitter().convert(raw);
  final tracks = <HistoryTrack>[];
  String? pendingTitle;
  String? pendingArtist;
  var n = 0;
  for (final line in lines) {
    final text = line.trim();
    if (text.isEmpty || text.startsWith('#EXTM3U')) continue;
    if (text.startsWith('#EXTINF:')) {
      final comma = text.indexOf(',');
      final meta = comma >= 0 ? text.substring(comma + 1).trim() : '';
      final dash = meta.indexOf(' - ');
      if (dash > 0) {
        pendingArtist = meta.substring(0, dash).trim();
        pendingTitle = meta.substring(dash + 3).trim();
      } else {
        pendingTitle = meta;
        pendingArtist = '';
      }
      continue;
    }
    if (text.startsWith('#')) continue;
    n += 1;
    var title = pendingTitle;
    var artist = pendingArtist ?? '';
    if (title == null || title.isEmpty) {
      title = text.split(RegExp(r'[/\\]')).last;
    }
    tracks.add(
      HistoryTrack(
        trackNo: n,
        title: title,
        artist: artist,
        playedAt: null,
        historyName: '',
        bpm: null,
        musicalKey: null,
        length: null,
        location: toDragLocation(text),
      ),
    );
    pendingTitle = null;
    pendingArtist = null;
  }
  return tracks.reversed.toList();
}

double? virtualDjBpm(String? raw) {
  final value = doubleOrNull(raw);
  if (value == null || value <= 0) return null;
  if (value < 10) {
    return 60.0 / value;
  }
  return value;
}

Map<String, String> parseXmlAttributes(String raw) {
  final out = <String, String>{};
  final re = RegExp(r'''([A-Za-z_][\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')''');
  for (final match in re.allMatches(raw)) {
    out[match.group(1)!] = match.group(2) ?? match.group(3) ?? '';
  }
  return out;
}

Map<String, String> _firstTag(String body, String name) {
  final re = RegExp('<$name\\b([^>]*)/?>', caseSensitive: false);
  final match = re.firstMatch(body);
  if (match == null) return const {};
  return parseXmlAttributes(match.group(1) ?? '');
}

String unescapeXml(String raw) {
  return raw
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}
