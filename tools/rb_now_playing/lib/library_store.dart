import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'camelot.dart';
import 'dj_library_source.dart';
import 'dj_sqlite.dart';
import 'library_match.dart';
import 'rekordbox_history.dart';
import 'tool_i18n.dart';

String libraryCacheFileName(String? softwareId) {
  switch (softwareId) {
    case 'rekordbox':
    case 'serato':
    case 'virtualdj':
    case 'traktor':
    case 'mixxx':
    case 'enginedj':
    case 'djaypro':
      return 'library_$softwareId.json';
    default:
      return 'library.json';
  }
}

class LibraryStore extends ChangeNotifier {
  LibraryIndex _index = LibraryIndex(const []);
  int _indexSerial = 0;
  int _workerSerial = -1;
  SendPort? _workerPort;
  ReceivePort? _workerHost;
  Isolate? _workerIsolate;
  Future<void>? _workerBoot;
  DateTime? lastImportedAt;
  bool importing = false;
  String? error;
  LibraryPulse? _pulse;
  bool _busy = false;
  Timer? _persistTimer;
  bool allowDeckDrag = true;
  String? _softwareId;
  bool _loaded = false;

  String? get softwareId => _softwareId;
  LibraryIndex get index => _index;
  bool get hasLibrary => !_index.isEmpty;
  int get trackCount => _index.length;
  int get playSum =>
      _pulse?.playSum ??
      _index.tracks.fold<int>(0, (sum, t) => sum + t.playCount);
  bool get needsLocationRefresh =>
      hasLibrary &&
      _index.tracks.every(
        (t) => t.location == null || t.location!.isEmpty,
      );

  Future<void> load() async {
    await bindSoftware(_softwareId);
  }

  /// Wechselt den Cache: Rekordbox bleibt Rekordbox, Serato bleibt Serato.
  Future<void> bindSoftware(String? softwareId) async {
    final next = softwareId?.trim();
    final id = (next == null || next.isEmpty) ? null : next;
    if (_loaded && id == _softwareId) return;
    _persistTimer?.cancel();
    if (_loaded && _softwareId != null && hasLibrary) {
      try {
        await _persist(_index.tracks);
      } catch (_) {}
    }
    _softwareId = id;
    await _readFile();
    _loaded = true;
  }

  Future<void> _readFile() async {
    _index = LibraryIndex(const []);
    _publishIndex();
    lastImportedAt = null;
    _pulse = null;
    error = null;
    try {
      final file = _file();
      if (!file.existsSync()) {
        notifyListeners();
        return;
      }
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) {
        notifyListeners();
        return;
      }
      final raw = data['tracks'];
      if (raw is! List) {
        notifyListeners();
        return;
      }
      final tracks = <LibraryTrack>[];
      for (final item in raw) {
        if (item is Map) {
          tracks.add(LibraryTrack.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      final at = data['at']?.toString();
      lastImportedAt = at == null ? null : DateTime.tryParse(at);
      final pulseRaw = data['pulse'];
      if (pulseRaw is Map) {
        _pulse = LibraryPulse.fromJson(Map<String, dynamic>.from(pulseRaw));
      }
      _index = LibraryIndex(tracks);
      _publishIndex();
      error = null;
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  Future<void> importFrom(DjLibrarySource source) {
    return syncFrom(source, forceFull: true);
  }

  Future<void> importFromRekordbox(DjLibrarySource source) {
    return importFrom(source);
  }

  /// Neue Titel und Play-Counts nachziehen.
  /// Ohne [forceFull] nur, wenn sich Anzahl oder Plays geändert haben.
  Future<void> syncFrom(
    DjLibrarySource source, {
    bool forceFull = false,
  }) async {
    if (_busy) return;
    _busy = true;
    final showSpinner = forceFull || !hasLibrary;
    var dirty = showSpinner;
    if (showSpinner) {
      importing = true;
      error = null;
      notifyListeners();
    }
    try {
      final pulse = source.libraryPulse();
      if (!forceFull &&
          hasLibrary &&
          pulse.sameAs(_pulse) &&
          !needsLocationRefresh) {
        return;
      }
      final needFull = forceFull ||
          !hasLibrary ||
          pulse.trackCount != trackCount ||
          needsLocationRefresh;
      if (!needFull) {
        final patched = _patchPlays(source.readPlayCounts());
        if (patched == true) {
          _pulse = pulse;
          lastImportedAt = DateTime.now();
          dirty = true;
          _schedulePersist();
          return;
        }
        if (patched == false) {
          _pulse = pulse;
          return;
        }
      }
      final tracks = source.readLibrary();
      if (tracks.isEmpty) {
        throw StateError(toolI18n.text('noTracks', {'name': source.label}));
      }
      _index = LibraryIndex(tracks);
      _publishIndex();
      _pulse = pulse;
      lastImportedAt = DateTime.now();
      error = null;
      dirty = true;
      await _persist(tracks);
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
      dirty = true;
    } finally {
      importing = false;
      _busy = false;
      if (dirty) notifyListeners();
    }
  }

  /// Nur den Cache dieser DJ-Software löschen, nicht die anderen.
  Future<void> clearCurrent() async {
    _persistTimer?.cancel();
    _busy = false;
    importing = false;
    try {
      final named = _file(forWrite: true);
      if (named.existsSync()) named.deleteSync();
      if (_softwareId == 'rekordbox') {
        final legacy = File('${named.parent.path}/library.json');
        if (legacy.existsSync()) legacy.deleteSync();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
      return;
    }
    _index = LibraryIndex(const []);
    _publishIndex();
    lastImportedAt = null;
    _pulse = null;
    error = null;
    notifyListeners();
  }

  Future<void> syncFromRekordbox(
    DjLibrarySource source, {
    bool forceFull = false,
  }) {
    return syncFrom(source, forceFull: forceFull);
  }

  /// `true` Plays geändert, `false` unverändert, `null` IDs passen nicht.
  bool? _patchPlays(Map<String, int> counts) {
    if (counts.length != _index.length) return null;
    final next = <LibraryTrack>[];
    var changed = false;
    for (final track in _index.tracks) {
      final plays = counts[track.id];
      if (plays == null) return null;
      if (plays != track.playCount) {
        changed = true;
        next.add(track.copyWith(playCount: plays));
      } else {
        next.add(track);
      }
    }
    if (!changed) return false;
    _index = LibraryIndex(next);
    _publishIndex();
    return true;
  }

  LibraryTrack? match(String title, String artist) {
    if (_index.isEmpty) return null;
    return _index.match(title, artist);
  }

  List<Map<String, dynamic>> applyToSuggestions(
    List<Map<String, dynamic>> items, {
    LibraryTrack? skip,
  }) {
    if (_index.isEmpty) return items;
    return [
      for (final item in items) _applyOne(item, skip: skip),
    ];
  }

  /// Treffer neben dem UI-Thread, damit der Rahmen nicht stehen bleibt.
  Future<List<Map<String, dynamic>>> applyToSuggestionsAsync(
    List<Map<String, dynamic>> items, {
    String? skipTitle,
    String? skipArtist,
  }) async {
    if (items.isEmpty || _index.isEmpty) {
      return [
        for (final item in items) {...item, 'inLibrary': false},
      ];
    }
    final need = _indexSerial;
    final port = await _workerSend();
    var spins = 0;
    while (_workerSerial < need && spins < 80) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      spins++;
    }
    final reply = ReceivePort();
    try {
      port.send({
        'op': 'apply',
        'items': items,
        'skipTitle': skipTitle ?? '',
        'skipArtist': skipArtist ?? '',
        'allowDrag': allowDeckDrag,
        'reply': reply.sendPort,
      });
      final raw = await reply.first;
      if (raw is! List) {
        return [
          for (final item in items) {...item, 'inLibrary': false},
        ];
      }
      return [
        for (final entry in raw)
          if (entry is Map) Map<String, dynamic>.from(entry),
      ];
    } catch (_) {
      return [
        for (final item in items) {...item, 'inLibrary': false},
      ];
    } finally {
      reply.close();
    }
  }

  void _publishIndex() {
    final serial = ++_indexSerial;
    final maps = [for (final track in _index.tracks) track.toJson()];
    unawaited(_sendIndex(serial, maps));
  }

  Future<void> _sendIndex(
    int serial,
    List<Map<String, dynamic>> maps,
  ) async {
    try {
      final port = await _workerSend();
      final reply = ReceivePort();
      try {
        port.send({
          'op': 'index',
          'serial': serial,
          'tracks': maps,
          'reply': reply.sendPort,
        });
        final acked = await reply.first;
        if (acked == serial && serial > _workerSerial) {
          _workerSerial = serial;
        }
      } finally {
        reply.close();
      }
    } catch (_) {}
  }

  Future<SendPort> _workerSend() {
    final ready = _workerPort;
    if (ready != null) return Future<SendPort>.value(ready);
    _workerBoot ??= _spawnWorker();
    return _workerBoot!.then((_) => _workerPort!);
  }

  Future<void> _spawnWorker() async {
    final host = ReceivePort();
    _workerHost = host;
    _workerIsolate = await Isolate.spawn(runLibraryMatchWorker, host.sendPort);
    _workerPort = await host.first as SendPort;
  }

  Map<String, dynamic> _applyOne(
    Map<String, dynamic> item, {
    LibraryTrack? skip,
  }) {
    final title = (item['title'] ?? '').toString();
    final artist = (item['artist'] ?? '').toString();
    final hit = _index.match(title, artist);
    if (hit == null || (skip != null && hit.id == skip.id)) {
      return {
        ...item,
        'inLibrary': false,
      };
    }
    final camelot = camelotFromScaleName(hit.musicalKey);
    return {
      ...item,
      'title': _keepLabel(hit.title, title),
      'artist': _keepLabel(hit.artist, artist),
      if (hit.bpm != null) 'bpm': hit.bpm,
      if (camelot != null && camelot.isNotEmpty) 'camelot': camelot,
      'inLibrary': true,
      'playCount': hit.playCount,
      if (hit.location != null) 'location': hit.location,
      'isTidal': hit.isTidal,
      'canDrag': allowDeckDrag && hit.canDragToRekordbox,
    };
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 8), () {
      unawaited(_persist(_index.tracks));
    });
  }

  Future<void> _persist(List<LibraryTrack> tracks) async {
    final file = _file(forWrite: true);
    await file.writeAsString(
      jsonEncode({
        'software': _softwareId,
        'at': lastImportedAt?.toIso8601String(),
        'pulse': _pulse?.toJson(),
        'tracks': [for (final t in tracks) t.toJson()],
      }),
    );
  }

  File _file({bool forWrite = false}) {
    final dir = toolSupportDir();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final named = File('${dir.path}/${libraryCacheFileName(_softwareId)}');
    if (!forWrite &&
        _softwareId == 'rekordbox' &&
        !named.existsSync()) {
      final legacy = File('${dir.path}/library.json');
      if (legacy.existsSync()) return legacy;
    }
    return named;
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerHost?.close();
    super.dispose();
  }
}

void runLibraryMatchWorker(SendPort host) {
  final inbox = ReceivePort();
  host.send(inbox.sendPort);
  var index = LibraryIndex(const []);
  inbox.listen((message) {
    if (message is! Map) return;
    final op = message['op'];
    final reply = message['reply'];
    if (reply is! SendPort) return;
    try {
      if (op == 'index') {
        final raw = message['tracks'];
        final tracks = <LibraryTrack>[];
        if (raw is List) {
          for (final item in raw) {
            if (item is Map) {
              tracks.add(LibraryTrack.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        index = LibraryIndex(tracks);
        reply.send(message['serial']);
        return;
      }
      if (op == 'apply') {
        final allowDrag = message['allowDrag'] == true;
        final skipTitle = (message['skipTitle'] ?? '').toString();
        final skipArtist = (message['skipArtist'] ?? '').toString();
        LibraryTrack? skip;
        if (skipTitle.trim().isNotEmpty && !index.isEmpty) {
          skip = index.match(skipTitle, skipArtist);
        }
        final items = message['items'];
        final out = <Map<String, dynamic>>[];
        if (items is List) {
          for (final item in items) {
            if (item is! Map) continue;
            out.add(_applyMatchOffUi(
              index,
              Map<String, dynamic>.from(item),
              skip: skip,
              allowDrag: allowDrag,
            ));
          }
        }
        reply.send(out);
      }
    } catch (_) {
      reply.send(op == 'index' ? message['serial'] : const <Map<String, dynamic>>[]);
    }
  });
}

/// Leere Datei-Tags nicht über einen vorhandenen Vorschlag schreiben.
String _keepLabel(String fromLibrary, String fromSuggestion) {
  final lib = fromLibrary.trim();
  if (lib.isEmpty) return fromSuggestion.trim();
  return lib;
}

Map<String, dynamic> _applyMatchOffUi(
  LibraryIndex index,
  Map<String, dynamic> item, {
  LibraryTrack? skip,
  required bool allowDrag,
}) {
  final title = (item['title'] ?? '').toString();
  final artist = (item['artist'] ?? '').toString();
  final hit = index.isEmpty ? null : index.match(title, artist);
  if (hit == null || (skip != null && hit.id == skip.id)) {
    return {...item, 'inLibrary': false};
  }
  final camelot = camelotFromScaleName(hit.musicalKey);
  return {
    ...item,
    'title': _keepLabel(hit.title, title),
    'artist': _keepLabel(hit.artist, artist),
    if (hit.bpm != null) 'bpm': hit.bpm,
    if (camelot != null && camelot.isNotEmpty) 'camelot': camelot,
    'inLibrary': true,
    'playCount': hit.playCount,
    if (hit.location != null) 'location': hit.location,
    'isTidal': hit.isTidal,
    'canDrag': allowDrag && hit.canDragToRekordbox,
  };
}
