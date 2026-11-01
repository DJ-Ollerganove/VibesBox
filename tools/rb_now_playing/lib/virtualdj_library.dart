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
    final m3u = newestVirtualDjHistory([
      File(xmlPath).parent.path,
      ...virtualDjHomeDirs(),
    ]);
    if (m3u != null) {
      final tracks = parseVirtualDjM3u(
        decodeVirtualDjBytes(m3u.readAsBytesSync()),
        libraryByPath: _libraryByPath(),
      );
      if (tracks.isNotEmpty) {
        return HistorySnapshot(
          dbPath: m3u.path,
          historyName: m3u.uri.pathSegments.isEmpty
              ? m3u.path
              : m3u.uri.pathSegments.last,
          tracks: tracks,
          readAt: DateTime.now(),
        );
      }
    }
    final byLast = parseVirtualDjLastPlayed(
      decodeVirtualDjBytes(File(xmlPath).readAsBytesSync()),
    );
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

  Map<String, LibraryTrack> _libraryByPath() {
    try {
      return virtualDjLibraryByPath(_libraryCached());
    } catch (_) {
      return const {};
    }
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
  final existing = [
    for (final path in virtualDjDatabaseCandidates())
      if (File(path).existsSync()) path,
  ];
  return preferVirtualDjDatabase(existing);
}

/// Datenordner, in denen Virtual DJ History und database.xml ablegt.
/// Aktuelle Windows-Installation: AppData\Local\VirtualDJ.
List<String> virtualDjHomeDirs() {
  final out = <String>[];
  void add(String? dir) {
    if (dir == null || dir.isEmpty) return;
    if (!out.contains(dir)) out.add(dir);
  }

  final home = Platform.environment['HOME'];
  add(home == null ? null : '$home/Library/Application Support/VirtualDJ');
  add(home == null ? null : '$home/Documents/VirtualDJ');
  final local = Platform.environment['LOCALAPPDATA'];
  add(local == null ? null : '$local\\VirtualDJ');
  final roaming = Platform.environment['APPDATA'];
  add(roaming == null ? null : '$roaming\\VirtualDJ');
  final user = Platform.environment['USERPROFILE'];
  add(user == null ? null : '$user\\Documents\\VirtualDJ');
  add(user == null ? null : '$user\\OneDrive\\Documents\\VirtualDJ');
  return out;
}

/// Unter mehreren database.xml die, deren History zuletzt geschrieben wurde.
String? preferVirtualDjDatabase(List<String> existing) {
  String? best;
  DateTime? bestHist;
  String? newestDb;
  DateTime? newestDbTime;
  for (final path in existing) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final dbTime = file.lastModifiedSync();
    if (newestDbTime == null || dbTime.isAfter(newestDbTime)) {
      newestDb = path;
      newestDbTime = dbTime;
    }
    final history = newestVirtualDjHistory([file.parent.path]);
    if (history == null) continue;
    final histTime = history.lastModifiedSync();
    if (bestHist == null || histTime.isAfter(bestHist)) {
      best = path;
      bestHist = histTime;
    }
  }
  return best ?? newestDb;
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
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null) {
    out.add('$localAppData\\VirtualDJ\\database.xml');
  }
  final user = Platform.environment['USERPROFILE'];
  if (user != null) {
    out.add('$user\\Documents\\VirtualDJ\\database.xml');
  }
  return out;
}

File? newestVirtualDjHistory(Iterable<String> homeDirs) {
  File? best;
  DateTime? bestTime;
  final seen = <String>{};
  for (final home in homeDirs) {
    if (home.isEmpty || !seen.add(home)) continue;
    for (final folder in ['History', 'Tracklisting']) {
      final dir = Directory('$home${Platform.pathSeparator}$folder');
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (!lower.endsWith('.m3u') && !lower.endsWith('.m3u8')) continue;
        final modified = entity.lastModifiedSync();
        if (bestTime == null || modified.isAfter(bestTime!)) {
          best = entity;
          bestTime = modified;
        }
      }
    }
  }
  return best;
}

String decodeVirtualDjBytes(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes.sublist(2), le: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes.sublist(2), le: false);
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return latin1.decode(bytes);
  }
}

String _decodeUtf16(List<int> bytes, {required bool le}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final lo = le ? bytes[i] : bytes[i + 1];
    final hi = le ? bytes[i + 1] : bytes[i];
    units.add(lo | (hi << 8));
  }
  return String.fromCharCodes(units);
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
    final named = virtualDjResolveTitleArtist(
      taggedTitle: tags['Title'],
      taggedArtist: tags['Author'] ?? tags['Artist'],
      path: path,
    );
    if (named.title.isEmpty) continue;
    final meta = virtualDjBpmKey(scan, tags);
    tracks.add(
      LibraryTrack(
        id: path.isEmpty ? named.title : path,
        title: named.title,
        artist: named.artist,
        bpm: meta.bpm,
        musicalKey: meta.key,
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
    final attrs = parseXmlAttributes(match.group(1) ?? '');
    final path = unescapeXml(attrs['FilePath'] ?? '');
    final body = match.group(2) ?? '';
    final tags = _firstTag(body, 'Tags');
    final infos = _firstTag(body, 'Infos');
    final scan = _firstTag(body, 'Scan');
    final last = intOrNull(infos['LastPlay']);
    if (last == null || last <= 0) continue;
    final named = virtualDjResolveTitleArtist(
      taggedTitle: tags['Title'],
      taggedArtist: tags['Author'] ?? tags['Artist'],
      path: path,
    );
    if (named.title.isEmpty) continue;
    n += 1;
    final meta = virtualDjBpmKey(scan, tags);
    items.add(
      (
        at: DateTime.fromMillisecondsSinceEpoch(last * 1000, isUtc: true)
            .toLocal(),
        track: HistoryTrack(
          trackNo: n,
          title: named.title,
          artist: named.artist,
          playedAt: DateTime.fromMillisecondsSinceEpoch(last * 1000, isUtc: true)
              .toLocal(),
          historyName: 'LastPlay',
          bpm: meta.bpm,
          musicalKey: meta.key,
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

/// Pfad der History-Datei auf den Bibliothekseintrag. Groß/Klein und
/// Schrägstriche spielen keine Rolle.
Map<String, LibraryTrack> virtualDjLibraryByPath(List<LibraryTrack> tracks) {
  final out = <String, LibraryTrack>{};
  for (final track in tracks) {
    final loc = track.location;
    if (loc == null || loc.isEmpty) continue;
    final key = virtualDjPathKey(loc);
    final previous = out[key];
    if (previous == null ||
        (previous.bpm == null &&
            (previous.musicalKey == null || previous.musicalKey!.isEmpty) &&
            (track.bpm != null ||
                (track.musicalKey != null && track.musicalKey!.isNotEmpty)))) {
      out[key] = track;
    }
  }
  return out;
}

String virtualDjPathKey(String path) =>
    path.trim().replaceAll('\\', '/').toLowerCase();

/// Analysierte Werte aus Scan, sonst die Tags. Dieselbe Quelle für
/// Bibliothek und History.
({double? bpm, String? key}) virtualDjBpmKey(
  Map<String, String> scan,
  Map<String, String> tags,
) {
  final key = unescapeXml(scan['Key'] ?? tags['Key'] ?? '').trim();
  return (
    bpm: virtualDjBpm(scan['Bpm'] ?? tags['Bpm']),
    key: key.isEmpty ? null : key,
  );
}

List<HistoryTrack> parseVirtualDjM3u(
  String raw, {
  Map<String, LibraryTrack> libraryByPath = const {},
}) {
  final lines = const LineSplitter().convert(raw);
  final tracks = <HistoryTrack>[];
  String? pendingTitle;
  String? pendingArtist;
  DateTime? pendingPlayed;
  Duration? pendingLength;
  var n = 0;
  for (final line in lines) {
    final text = line.trim();
    if (text.isEmpty || text.startsWith('#EXTM3U')) continue;
    if (text.startsWith('#EXTVDJ:')) {
      final artist = _vdjXmlValue(text, 'artist');
      final title = _vdjXmlValue(text, 'title');
      if (artist.isNotEmpty) pendingArtist = artist;
      if (title.isNotEmpty) pendingTitle = title;
      final seconds = doubleOrNull(_vdjXmlValue(text, 'songlength'));
      if (seconds != null && seconds > 0) {
        pendingLength = Duration(seconds: seconds.round());
      }
      final last = intOrNull(_vdjXmlValue(text, 'lastplaytime'));
      if (last != null && last > 0) {
        pendingPlayed = DateTime.fromMillisecondsSinceEpoch(
          last * 1000,
          isUtc: true,
        ).toLocal();
      }
      continue;
    }
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
    final named = virtualDjResolveTitleArtist(
      taggedTitle: pendingTitle,
      taggedArtist: pendingArtist,
      path: text,
    );
    if (named.title.isEmpty) {
      pendingTitle = null;
      pendingArtist = null;
      pendingPlayed = null;
      pendingLength = null;
      continue;
    }
    final known = libraryByPath[virtualDjPathKey(text)];
    final knownLength = known?.lengthSec;
    tracks.add(
      HistoryTrack(
        trackNo: n,
        title: named.title,
        artist: named.artist,
        playedAt: pendingPlayed,
        historyName: '',
        bpm: known?.bpm,
        musicalKey: known?.musicalKey,
        length: pendingLength ??
            (knownLength == null || knownLength <= 0
                ? null
                : Duration(seconds: knownLength)),
      ),
    );
    pendingTitle = null;
    pendingArtist = null;
    pendingPlayed = null;
    pendingLength = null;
  }
  return tracks.reversed.toList();
}

String _vdjXmlValue(String line, String tag) {
  final match = RegExp(
    '<$tag>(.*?)</$tag>',
    caseSensitive: false,
  ).firstMatch(line);
  if (match == null) return '';
  return unescapeXml(match.group(1) ?? '').trim();
}

/// Titel und Interpret. Fehlen die Tags, wird `Interpret - Titel` aus dem
/// Dateinamen gelesen. Eine reine Zahl vor dem Strich ist keine Interpret.
({String title, String artist}) virtualDjResolveTitleArtist({
  String? taggedTitle,
  String? taggedArtist,
  required String path,
}) {
  var title = unescapeXml(taggedTitle ?? '').trim();
  var artist = unescapeXml(taggedArtist ?? '').trim();
  final fromFile = title.isEmpty;
  if (fromFile) title = virtualDjDisplayTitle(null, path) ?? '';
  if (artist.isEmpty) {
    final dash = title.indexOf(' - ');
    if (dash > 0) {
      final left = title.substring(0, dash).trim();
      final right = title.substring(dash + 3).trim();
      if (right.isNotEmpty && _looksLikeArtist(left)) {
        artist = left;
        title = right;
      }
    }
  }
  if (fromFile) {
    final paren = title.indexOf(' (');
    if (paren > 0) title = title.substring(0, paren).trim();
  }
  return (title: title, artist: artist);
}

bool _looksLikeArtist(String raw) {
  if (RegExp(r'^\d+$').hasMatch(raw)) return false;
  return RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(raw);
}

/// Titel aus den Tags. Fehlt er, wird der Dateiname genommen.
/// Zip-Dateien und andere Nicht-Audio-Pfade bleiben draußen.
String? virtualDjDisplayTitle(String? tagged, String path) {
  final title = unescapeXml(tagged ?? '').trim();
  if (title.isNotEmpty) return title;
  final lower = path.toLowerCase();
  const extensions = [
    '.mp3', '.m4a', '.m4p', '.aac', '.aif', '.aiff', '.wav', '.flac', '.alac', '.ogg', '.mp4',
  ];
  if (!extensions.any(lower.endsWith)) return null;
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  final bare = (dot > 0 ? name.substring(0, dot) : name).trim();
  return bare.isEmpty ? null : bare;
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
