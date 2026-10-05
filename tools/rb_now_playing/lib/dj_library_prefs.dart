import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rekordbox_history.dart';

/// Reihenfolge = Anzeige alphabetisch nach [label].
enum DjSoftware {
  djayPro,
  engineDj,
  mixxx,
  rekordbox,
  serato,
  traktor,
  virtualDj;

  String get id => switch (this) {
        DjSoftware.djayPro => 'djaypro',
        DjSoftware.engineDj => 'enginedj',
        DjSoftware.mixxx => 'mixxx',
        DjSoftware.rekordbox => 'rekordbox',
        DjSoftware.serato => 'serato',
        DjSoftware.traktor => 'traktor',
        DjSoftware.virtualDj => 'virtualdj',
      };

  String get label => switch (this) {
        DjSoftware.djayPro => 'DJAY Pro',
        DjSoftware.engineDj => 'Engine DJ',
        DjSoftware.mixxx => 'Mixxx',
        DjSoftware.rekordbox => 'Rekordbox',
        DjSoftware.serato => 'Serato DJ Pro',
        DjSoftware.traktor => 'Traktor Pro',
        DjSoftware.virtualDj => 'Virtual DJ',
      };

  static DjSoftware? tryParse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'djay':
      case 'djay pro':
      case 'djaypro':
      case 'djay pro ai':
      case 'algoriddim':
      case 'algoriddim djay':
      case 'algoriddim djay pro':
        return DjSoftware.djayPro;
      case 'enginedj':
      case 'engine':
      case 'engine dj':
      case 'engine prime':
        return DjSoftware.engineDj;
      case 'mixxx':
        return DjSoftware.mixxx;
      case 'rekordbox':
        return DjSoftware.rekordbox;
      case 'serato':
      case 'serato dj':
      case 'serato dj pro':
      case 'seratodj':
        return DjSoftware.serato;
      case 'traktor':
      case 'traktor pro':
      case 'traktorpro':
      case 'traktordj':
        return DjSoftware.traktor;
      case 'virtualdj':
      case 'virtual_dj':
      case 'virtual dj':
        return DjSoftware.virtualDj;
      default:
        return null;
    }
  }
}

/// Standardpfade der unterstützten Bibliotheken.
String defaultLibraryPath(DjSoftware software) {
  switch (software) {
    case DjSoftware.rekordbox:
      try {
        return locateMasterDb();
      } catch (_) {
        return _joinHome(
          const ['Library', 'Pioneer', 'rekordbox', 'master.db'],
          winParts: const ['Pioneer', 'rekordbox', 'master.db'],
          winEnv: 'APPDATA',
        );
      }
    case DjSoftware.serato:
      return _joinHome(
        const ['Music', '_Serato_'],
        winParts: const ['Music', '_Serato_'],
      );
    case DjSoftware.virtualDj:
      for (final path in const [
        ['Library', 'Application Support', 'VirtualDJ', 'database.xml'],
      ]) {
        final candidate = _joinHome(
          path,
          winParts: const ['VirtualDJ', 'database.xml'],
          winEnv: 'APPDATA',
        );
        if (File(candidate).existsSync()) return candidate;
      }
      return _joinHome(
        const ['Documents', 'VirtualDJ', 'database.xml'],
        winParts: const ['Documents', 'VirtualDJ', 'database.xml'],
      );
    case DjSoftware.traktor:
      return _joinHome(
        const ['Documents', 'Native Instruments'],
        winParts: const ['Documents', 'Native Instruments'],
      );
    case DjSoftware.mixxx:
      for (final path in [
        _joinHome(
          const ['Library', 'Application Support', 'Mixxx', 'mixxxdb.sqlite'],
          winParts: const ['Mixxx', 'mixxxdb.sqlite'],
          winEnv: 'LOCALAPPDATA',
        ),
      ]) {
        if (File(path).existsSync()) return path;
      }
      return _joinHome(
        const ['Library', 'Application Support', 'Mixxx', 'mixxxdb.sqlite'],
        winParts: const ['Mixxx', 'mixxxdb.sqlite'],
        winEnv: 'LOCALAPPDATA',
      );
    case DjSoftware.engineDj:
      return _joinHome(
        const ['Music', 'Engine Library', 'Database2', 'm.db'],
        winParts: const ['Music', 'Engine Library', 'Database2', 'm.db'],
      );
    case DjSoftware.djayPro:
      return _joinHome(
        const [
          'Music',
          'djay',
          'djay Media Library.djayMediaLibrary',
          'MediaLibrary.db',
        ],
        winParts: const [
          'Music',
          'djay',
          'djay Media Library',
          'MediaLibrary.db',
        ],
      );
  }
}

class DjLibraryPrefs extends ChangeNotifier {
  static const _channel = MethodChannel('vibesbox_sync/library_path');

  DjSoftware? software;
  bool? readLibrary;
  bool autoUpdate = false;
  bool alwaysOnTop = false;
  final Map<DjSoftware, String> _customPaths = {};

  bool get wantsRead => software != null && readLibrary == true;
  bool get wantsAuto => wantsRead && autoUpdate;

  String resolvedPath(DjSoftware forSoftware) {
    final custom = _customPaths[forSoftware]?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return defaultLibraryPath(forSoftware);
  }

  bool isCustomPath(DjSoftware forSoftware) {
    final custom = _customPaths[forSoftware]?.trim();
    if (custom == null || custom.isEmpty) return false;
    return custom != defaultLibraryPath(forSoftware);
  }

  Future<void> load() async {
    try {
      final file = _file();
      if (!file.existsSync()) {
        if (_legacyLibraryFile().existsSync()) {
          software = DjSoftware.rekordbox;
          readLibrary = true;
          autoUpdate = true;
          await save();
        }
        notifyListeners();
        await _ensureWindowsDjWatch();
        return;
      }
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) {
        notifyListeners();
        await _ensureWindowsDjWatch();
        return;
      }
      software = DjSoftware.tryParse(data['software']?.toString());
      final read = data['readLibrary'];
      readLibrary = read is bool ? read : null;
      autoUpdate = data['autoUpdate'] == true;
      alwaysOnTop = data['alwaysOnTop'] == true;
      _customPaths.clear();
      void take(DjSoftware key, String jsonKey) {
        final v = data[jsonKey]?.toString().trim();
        if (v != null && v.isNotEmpty) _customPaths[key] = v;
      }

      take(DjSoftware.rekordbox, 'pathRekordbox');
      take(DjSoftware.serato, 'pathSerato');
      take(DjSoftware.virtualDj, 'pathVirtualDj');
      take(DjSoftware.traktor, 'pathTraktor');
      take(DjSoftware.mixxx, 'pathMixxx');
      take(DjSoftware.engineDj, 'pathEngineDj');
      take(DjSoftware.djayPro, 'pathDjayPro');
      notifyListeners();
      if (alwaysOnTop) {
        await WindowChrome.setAlwaysOnTop(true);
      }
      await _ensureWindowsDjWatch();
    } catch (_) {
      notifyListeners();
      await _ensureWindowsDjWatch();
    }
  }

  Future<void> _ensureWindowsDjWatch() async {
    // Windows: DJ-Watchdog immer an (nativ auch in main.cpp). Mac unverändert.
    if (Platform.isWindows) {
      await WindowChrome.ensureDjWatchAutostart();
    }
  }

  Future<void> setAlwaysOnTop(bool value) async {
    if (alwaysOnTop == value) return;
    alwaysOnTop = value;
    await save();
    notifyListeners();
    await WindowChrome.setAlwaysOnTop(value);
  }

  Future<void> setSoftware(DjSoftware? value) async {
    if (software == value) return;
    software = value;
    await save();
    notifyListeners();
  }

  Future<void> setReadLibrary(bool value) async {
    if (readLibrary == value) return;
    readLibrary = value;
    if (!value) {
      autoUpdate = false;
    }
    await save();
    notifyListeners();
  }

  Future<void> setAutoUpdate(bool value) async {
    if (autoUpdate == value) return;
    autoUpdate = value;
    await save();
    notifyListeners();
  }

  Future<void> setCustomPath(DjSoftware forSoftware, String? path) async {
    final next = path?.trim();
    if (next == null || next.isEmpty) {
      _customPaths.remove(forSoftware);
    } else {
      _customPaths[forSoftware] = next;
    }
    await save();
    notifyListeners();
  }

  Future<void> clearCustomPath(DjSoftware forSoftware) {
    return setCustomPath(forSoftware, null);
  }

  Future<String?> browse(DjSoftware forSoftware) async {
    final start = resolvedPath(forSoftware);
    try {
      final picked = await _channel.invokeMethod<String>('pick', {
        'start': start,
        'folders': forSoftware == DjSoftware.serato ||
            forSoftware == DjSoftware.djayPro,
      });
      final path = picked?.trim();
      if (path == null || path.isEmpty) return null;
      final resolved = resolvePickedPath(forSoftware, path);
      await setCustomPath(forSoftware, resolved);
      return resolved;
    } on PlatformException {
      return null;
    }
  }

  Future<void> save() async {
    final file = _file();
    await file.writeAsString(
      jsonEncode({
        'software': software?.id,
        'readLibrary': readLibrary,
        'autoUpdate': autoUpdate,
        'alwaysOnTop': alwaysOnTop,
        'pathRekordbox': _customPaths[DjSoftware.rekordbox],
        'pathSerato': _customPaths[DjSoftware.serato],
        'pathVirtualDj': _customPaths[DjSoftware.virtualDj],
        'pathTraktor': _customPaths[DjSoftware.traktor],
        'pathMixxx': _customPaths[DjSoftware.mixxx],
        'pathEngineDj': _customPaths[DjSoftware.engineDj],
        'pathDjayPro': _customPaths[DjSoftware.djayPro],
      }),
    );
  }

  File _file() {
    final dir = _supportDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/dj_library_prefs.json');
  }

  File _legacyLibraryFile() {
    return File('${_supportDir().path}/library.json');
  }

  Directory _supportDir() {
    // Gleicher Ort wie tool_gate / tool_session (nicht Mac-Pfad unter Windows).
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    if (Platform.isWindows) {
      final appData =
          Platform.environment['APPDATA'] ?? '$home\\AppData\\Roaming';
      return Directory('$appData\\VibesBoxRbTool');
    }
    if (Platform.isMacOS) {
      return Directory('$home/Library/Application Support/VibesBoxRbTool');
    }
    return Directory('$home/.vibesbox_rb_tool');
  }
}

String resolvePickedPath(DjSoftware software, String picked) {
  final entity = FileSystemEntity.typeSync(picked);
  if (entity != FileSystemEntityType.directory) return picked;
  switch (software) {
    case DjSoftware.rekordbox:
      final db = File('$picked/master.db');
      if (db.existsSync()) return db.path;
      return picked;
    case DjSoftware.serato:
      if (picked.endsWith('_Serato_') || picked.endsWith(r'\_Serato_')) {
        return picked;
      }
      final nested = Directory('$picked/_Serato_');
      if (nested.existsSync()) return nested.path;
      return picked;
    case DjSoftware.virtualDj:
      final xml = File('$picked/database.xml');
      if (xml.existsSync()) return xml.path;
      return picked;
    case DjSoftware.traktor:
      final nml = File('$picked/collection.nml');
      if (nml.existsSync()) return nml.path;
      return picked;
    case DjSoftware.mixxx:
      final db = File('$picked/mixxxdb.sqlite');
      if (db.existsSync()) return db.path;
      return picked;
    case DjSoftware.engineDj:
      for (final nested in [
        '$picked/m.db',
        '$picked/Database2/m.db',
        '$picked/Engine Library/Database2/m.db',
      ]) {
        if (File(nested).existsSync()) return nested;
      }
      return picked;
    case DjSoftware.djayPro:
      for (final nested in [
        '$picked/MediaLibrary.db',
        '$picked/djay Media Library/MediaLibrary.db',
        '$picked/djay Media Library.djayMediaLibrary/MediaLibrary.db',
        '$picked/djay/djay Media Library/MediaLibrary.db',
        '$picked/djay/djay Media Library.djayMediaLibrary/MediaLibrary.db',
      ]) {
        if (File(nested).existsSync()) return nested;
      }
      return picked;
  }
}

String _joinHome(
  List<String> macParts, {
  required List<String> winParts,
  String? winEnv,
}) {
  if (Platform.isWindows) {
    final root = (winEnv != null
            ? Platform.environment[winEnv]
            : Platform.environment['USERPROFILE']) ??
        '';
    return ([root, ...winParts]).join('\\');
  }
  final home = Platform.environment['HOME'] ?? '';
  return ([home, ...macParts]).join('/');
}

class WindowChrome {
  WindowChrome._();

  static const _channel = MethodChannel('vibesbox_sync/window');

  static Future<void> setAlwaysOnTop(bool on) async {
    try {
      await _channel.invokeMethod<bool>('setAlwaysOnTop', on);
    } on PlatformException {
      return;
    }
  }

  /// Windows: HKCU-Run + Watcher immer aktiv (idempotent).
  static Future<bool> ensureDjWatchAutostart() async {
    if (!Platform.isWindows) return false;
    try {
      return await _channel.invokeMethod<bool>('ensureDjWatchAutostart') ??
          false;
    } on PlatformException {
      try {
        return await _channel.invokeMethod<bool>('setLaunchWithDj', true) ??
            false;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    } on MissingPluginException {
      return false;
    }
  }
}
