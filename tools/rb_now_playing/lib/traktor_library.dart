import 'dart:io';

import 'dj_library_source.dart';
import 'tool_i18n.dart';
import 'library_match.dart';
import 'rekordbox_history.dart';

class TraktorLibrarySource implements DjLibrarySource {
  TraktorLibrarySource(this.overridePath);

  final String? overridePath;
  List<LibraryTrack>? _tracks;
  String? _nmlPath;
  DateTime? _mtime;
  int? _size;

  @override
  String get label => 'Traktor Pro';

  @override
  HistorySnapshot readHistory() {
    final nmlPath = _requireCollection();
    final historyFile = locateTraktorHistory(nmlPath);
    if (historyFile != null) {
      final tracks = parseTraktorHistoryNml(historyFile.readAsStringSync());
      return HistorySnapshot(
        dbPath: historyFile.path,
        historyName: historyFile.uri.pathSegments.isEmpty
            ? historyFile.path
            : historyFile.uri.pathSegments.last,
        tracks: tracks,
        readAt: DateTime.now(),
      );
    }
    return HistorySnapshot(
      dbPath: nmlPath,
      historyName: 'LAST_PLAYED',
      tracks: parseTraktorLastPlayed(File(nmlPath).readAsStringSync()),
      readAt: DateTime.now(),
    );
  }

  @override
  List<LibraryTrack> readLibrary() {
    final tracks = _libraryCached();
    if (tracks.isEmpty) {
      throw StateError(toolI18n.text('noTracks', {'name': 'Traktor Pro'}));
    }
    return tracks;
  }

  @override
  LibraryPulse libraryPulse() {
    final file = File(_requireCollection());
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
    _nmlPath = null;
    _mtime = null;
    _size = null;
  }

  List<LibraryTrack> _libraryCached() {
    final path = _requireCollection();
    final file = File(path);
    final mtime = file.lastModifiedSync();
    final size = file.lengthSync();
    if (_tracks != null &&
        _nmlPath == path &&
        _mtime == mtime &&
        _size == size) {
      return _tracks!;
    }
    _nmlPath = path;
    _mtime = mtime;
    _size = size;
    _tracks = parseTraktorCollection(file.readAsStringSync());
    return _tracks!;
  }

  String _requireCollection() {
    final path = locateTraktorCollection(overridePath);
    if (path == null || !File(path).existsSync()) {
      throw StateError(toolI18n.text('errTraktor'));
    }
    return path;
  }
}

String? locateTraktorCollection(String? override) {
  final custom = override?.trim();
  if (custom != null && custom.isNotEmpty) {
    if (custom.toLowerCase().endsWith('.nml') && File(custom).existsSync()) {
      return custom;
    }
    final nested = File('$custom/collection.nml');
    if (nested.existsSync()) return nested.path;
  }
  File? best;
  DateTime? bestTime;
  for (final dir in _traktorRootCandidates()) {
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
      if (!name.startsWith('traktor')) continue;
      final nml = File('${entity.path}${Platform.pathSeparator}collection.nml');
      if (!nml.existsSync()) continue;
      final m = nml.lastModifiedSync();
      if (bestTime == null || m.isAfter(bestTime)) {
        best = nml;
        bestTime = m;
      }
    }
  }
  return best?.path;
}

File? locateTraktorHistory(String collectionPath) {
  final historyDir = Directory('${File(collectionPath).parent.path}${Platform.pathSeparator}History');
  File? best;
  DateTime? bestTime;
  void consider(File file) {
    if (!file.existsSync()) return;
    final m = file.lastModifiedSync();
    if (bestTime == null || m.isAfter(bestTime!)) {
      best = file;
      bestTime = m;
    }
  }

  consider(File('${File(collectionPath).parent.path}${Platform.pathSeparator}sessionhistory.nml'));
  if (historyDir.existsSync()) {
    for (final entity in historyDir.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.nml')) continue;
      consider(entity);
    }
  }
  return best;
}

List<Directory> _traktorRootCandidates() {
  final home = Platform.environment['HOME'] ?? '';
  final out = <Directory>[];
  if (home.isNotEmpty) {
    out.add(Directory('$home/Documents/Native Instruments'));
  }
  final user = Platform.environment['USERPROFILE'];
  if (user != null && user.isNotEmpty) {
    out.add(Directory('$user\\Documents\\Native Instruments'));
  }
  return out;
}

List<LibraryTrack> parseTraktorCollection(String nml) {
  final tracks = <LibraryTrack>[];
  final collection = _xmlSection(nml, 'COLLECTION');
  final entryRe = RegExp(r'<ENTRY\b([^>]*)>(.*?)</ENTRY>', dotAll: true);
  for (final match in entryRe.allMatches(collection)) {
    final attrs = _xmlAttrs(match.group(1) ?? '');
    final body = match.group(2) ?? '';
    final title = _unescapeXml(attrs['TITLE'] ?? '').trim();
    if (title.isEmpty) continue;
    final location = _firstTag(body, 'LOCATION');
    final info = _firstTag(body, 'INFO');
    final tempo = _firstTag(body, 'TEMPO');
    final stream = _firstTag(body, 'STREAMURL');
    final path = toDragLocation(
          stream['VALUE'] ??
              traktorLocationToPath(
                volume: location['VOLUME'],
                dir: location['DIR'],
                file: location['FILE'],
              ),
        ) ??
        toDragLocation(location['FILE']);
    tracks.add(
      LibraryTrack(
        id: path ?? title,
        title: title,
        artist: _unescapeXml(attrs['ARTIST'] ?? '').trim(),
        bpm: doubleOrNull(tempo['BPM']),
        musicalKey: _unescapeXml(info['KEY'] ?? '').trim().isEmpty
            ? null
            : _unescapeXml(info['KEY'] ?? '').trim(),
        lengthSec: intOrNull(info['PLAYTIME']),
        playCount: intOrNull(info['PLAYCOUNT']) ?? 0,
        location: path,
      ),
    );
  }
  return tracks;
}

List<HistoryTrack> parseTraktorHistoryNml(String nml) {
  final keys = <String>[];
  final pkRe = RegExp(
    r'<PRIMARYKEY\b[^>]*\bKEY="([^"]+)"',
    caseSensitive: false,
  );
  for (final match in pkRe.allMatches(nml)) {
    final key = _unescapeXml(match.group(1) ?? '').trim();
    if (key.isEmpty) continue;
    keys.add(key);
  }
  if (keys.isEmpty) {
    final entryRe = RegExp(
      r'<ENTRY\b[^>]*\bPRIMARYKEY="([^"]+)"',
      caseSensitive: false,
    );
    for (final match in entryRe.allMatches(nml)) {
      final key = _unescapeXml(match.group(1) ?? '').trim();
      if (key.isEmpty) continue;
      keys.add(key);
    }
  }
  final tracks = <HistoryTrack>[];
  var n = 0;
  for (final key in keys.reversed) {
    n += 1;
    final parsed = traktorPrimaryKeyToTitle(key);
    tracks.add(
      HistoryTrack(
        trackNo: n,
        title: parsed.title,
        artist: '',
        playedAt: null,
        historyName: '',
        bpm: null,
        musicalKey: null,
        length: null,
      ),
    );
  }
  return tracks;
}

List<HistoryTrack> parseTraktorLastPlayed(String nml) {
  final items = <({DateTime? at, HistoryTrack track})>[];
  final collection = _xmlSection(nml, 'COLLECTION');
  final entryRe = RegExp(r'<ENTRY\b([^>]*)>(.*?)</ENTRY>', dotAll: true);
  var n = 0;
  for (final match in entryRe.allMatches(collection)) {
    final attrs = _xmlAttrs(match.group(1) ?? '');
    final info = _firstTag(match.group(2) ?? '', 'INFO');
    final last = info['LAST_PLAYED'];
    if (last == null || last.trim().isEmpty) continue;
    final title = _unescapeXml(attrs['TITLE'] ?? '').trim();
    if (title.isEmpty) continue;
    n += 1;
    items.add(
      (
        at: _traktorDay(last),
        track: HistoryTrack(
          trackNo: n,
          title: title,
          artist: _unescapeXml(attrs['ARTIST'] ?? '').trim(),
          playedAt: _traktorDay(last),
          historyName: 'LAST_PLAYED',
          bpm: doubleOrNull(_firstTag(match.group(2) ?? '', 'TEMPO')['BPM']),
          musicalKey: _unescapeXml(info['KEY'] ?? '').trim().isEmpty
              ? null
              : _unescapeXml(info['KEY'] ?? '').trim(),
          length: intOrNull(info['PLAYTIME']) == null
              ? null
              : Duration(seconds: intOrNull(info['PLAYTIME'])!),
        ),
      ),
    );
  }
  items.sort((a, b) {
    final at = a.at;
    final bt = b.at;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });
  return [for (var i = 0; i < items.length; i++) items[i].track];
}

({String title, String path}) traktorPrimaryKeyToTitle(String key) {
  final path = traktorPrimaryKeyToPath(key) ?? key;
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  final title = dot > 0 ? name.substring(0, dot) : name;
  return (title: title, path: path);
}

String? traktorPrimaryKeyToPath(String key) {
  final parts = key.split('/:');
  if (parts.length < 2) return toDragLocation(key);
  final volume = parts.first;
  final rest = parts.sublist(1);
  final file = rest.last;
  final dirs = rest.sublist(0, rest.length - 1);
  return traktorLocationToPath(
    volume: volume,
    dir: dirs.isEmpty ? '/:' : '/:${dirs.join('/:')}/:',
    file: file,
  );
}

String? traktorLocationToPath({
  String? volume,
  String? dir,
  String? file,
}) {
  if (file == null || file.trim().isEmpty) return null;
  final name = file.trim();
  final vol = (volume ?? '').trim();
  final volLower = vol.toLowerCase();
  if (volLower.contains('tidal') || name.toLowerCase().contains('tidal')) {
    final fromName = toDragLocation(name);
    if (fromName != null && fromName.startsWith('tidal:')) return fromName;
    if (RegExp(r'^\d+$').hasMatch(name)) return 'tidal:tracks:$name';
    return toDragLocation(vol);
  }
  final streamed = toDragLocation(name);
  if (streamed != null && streamed.startsWith('tidal:')) return streamed;
  final dirs = (dir ?? '')
      .split('/:')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (RegExp(r'^[A-Za-z]:$').hasMatch(vol)) {
    return ([vol, ...dirs, name]).join('\\');
  }
  if (name.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(name)) {
    return name;
  }
  return '/${[...dirs, name].join('/')}';
}

String _xmlSection(String xml, String name) {
  final start = xml.indexOf('<$name');
  if (start < 0) return xml;
  final endTag = '</$name>';
  final end = xml.indexOf(endTag, start);
  if (end < 0) return xml.substring(start);
  return xml.substring(start, end + endTag.length);
}

Map<String, String> _xmlAttrs(String raw) {
  final out = <String, String>{};
  final re = RegExp(r'([A-Za-z0-9_]+)="([^"]*)"');
  for (final match in re.allMatches(raw)) {
    out[match.group(1)!.toUpperCase()] = match.group(2) ?? '';
  }
  return out;
}

Map<String, String> _firstTag(String xml, String name) {
  final re = RegExp('<$name\\b([^>]*)/?>', caseSensitive: false);
  final match = re.firstMatch(xml);
  if (match == null) return {};
  return _xmlAttrs(match.group(1) ?? '');
}

String _unescapeXml(String raw) {
  return raw
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

DateTime? _traktorDay(String raw) {
  final parts = raw.split(RegExp(r'[/\-.]'));
  if (parts.length < 3) return DateTime.tryParse(raw);
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return DateTime.tryParse(raw);
  return DateTime.utc(y, m, d);
}
