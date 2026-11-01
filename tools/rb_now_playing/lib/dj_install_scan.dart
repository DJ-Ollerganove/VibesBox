import 'dart:io';

import 'dj_app_match.dart';
import 'dj_library_prefs.dart';
import 'rekordbox_history.dart';
import 'serato_library.dart';
import 'traktor_library.dart';
import 'virtualdj_library.dart';

/// Sucht die Installation der gewählten DJ-Software und die Bibliothek
/// daneben oder an den bekannten Datenorten. Kein Ganzplatten-Lauf.
Future<String?> scanInstalledLibrary(
  DjSoftware software, {
  List<String>? installRoots,
  bool queryRegistry = true,
}) async {
  final candidates = <String>[
    if (installRoots == null) ...knownLibraryFiles(software),
    ...await _librariesBesideInstall(
      software,
      installRoots: installRoots,
      queryRegistry: queryRegistry && installRoots == null,
    ),
  ];
  return newestExistingLibrary(candidates);
}

bool libraryPathExists(String path) {
  if (path.trim().isEmpty) return false;
  return File(path).existsSync() || Directory(path).existsSync();
}

bool libraryFileIsNewer(String candidate, String current) {
  final next = File(candidate);
  final prev = File(current);
  if (!next.existsSync()) return false;
  if (!prev.existsSync()) return true;
  return next.lastModifiedSync().isAfter(prev.lastModifiedSync());
}

bool sameLibraryPath(String a, String b) {
  return a.replaceAll('\\', '/').toLowerCase() ==
      b.replaceAll('\\', '/').toLowerCase();
}

List<String> knownLibraryFiles(DjSoftware software) {
  switch (software) {
    case DjSoftware.virtualDj:
      return virtualDjDatabaseCandidates();
    case DjSoftware.rekordbox:
      try {
        return [locateMasterDb()];
      } catch (_) {
        return const [];
      }
    case DjSoftware.serato:
      return [
        locateSeratoSqlite(null),
        locateSeratoDatabaseV2(null),
      ].whereType<String>().toList();
    case DjSoftware.traktor:
      final nml = locateTraktorCollection(null);
      return nml == null ? const [] : [nml];
    case DjSoftware.mixxx:
    case DjSoftware.engineDj:
    case DjSoftware.djayPro:
      final path = defaultLibraryPath(software);
      return libraryPathExists(path) ? [path] : const [];
  }
}

String? newestExistingLibrary(List<String> paths) {
  String? best;
  DateTime? bestTime;
  final seen = <String>{};
  for (final raw in paths) {
    final path = raw.trim();
    if (path.isEmpty) continue;
    final key = path.replaceAll('\\', '/').toLowerCase();
    if (!seen.add(key)) continue;
    final file = File(path);
    if (!file.existsSync()) {
      if (Directory(path).existsSync() && best == null) best = path;
      continue;
    }
    final modified = file.lastModifiedSync();
    if (bestTime == null || modified.isAfter(bestTime)) {
      best = path;
      bestTime = modified;
    }
  }
  return best;
}

Future<List<String>> _librariesBesideInstall(
  DjSoftware software, {
  List<String>? installRoots,
  required bool queryRegistry,
}) async {
  final dirs = <String>[
    ...?installRoots,
    if (installRoots == null) ..._defaultInstallRoots(),
    if (queryRegistry) ...await _registryInstallDirs(software),
  ];
  final out = <String>[];
  final rule = _ruleFor(software);
  for (final root in dirs) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    _walkInstall(directory, 0, (entity) {
      if (!_installNameMatches(rule, entity)) return;
      final installDir = entity is Directory
          ? entity.path
          : File(entity.path).parent.path;
      out.addAll(_librariesBeside(software, installDir));
      out.addAll(_librariesBeside(software, Directory(installDir).parent.path));
    });
  }
  return out;
}

DjAppRule _ruleFor(DjSoftware software) {
  return djAppRules.firstWhere((rule) => rule.software == software);
}

bool _installNameMatches(DjAppRule rule, FileSystemEntity entity) {
  var name = entity.uri.pathSegments.isEmpty
      ? entity.path
      : entity.uri.pathSegments.last;
  final lower = name.toLowerCase();
  if (entity is Directory && lower.endsWith('.app')) {
    name = name.substring(0, name.length - 4);
  } else if (entity is File && lower.endsWith('.exe')) {
    name = name.substring(0, name.length - 4);
  } else {
    return false;
  }
  final bare = name.toLowerCase();
  if (deniedExactNames.contains(bare)) return false;
  return rule.names.contains(bare);
}

void _walkInstall(
  Directory dir,
  int depth,
  void Function(FileSystemEntity entity) onHit,
) {
  if (depth > 2) return;
  List<FileSystemEntity> children;
  try {
    children = dir.listSync(followLinks: false);
  } catch (_) {
    return;
  }
  if (children.length > 250) return;
  for (final child in children) {
    final name = child.uri.pathSegments.isEmpty
        ? ''
        : child.uri.pathSegments.last.toLowerCase();
    if (child is Directory && name.endsWith('.app')) {
      onHit(child);
      continue;
    }
    if (child is File && name.endsWith('.exe')) {
      onHit(child);
      continue;
    }
    if (child is Directory && depth < 2) {
      _walkInstall(child, depth + 1, onHit);
    }
  }
}

List<String> _librariesBeside(DjSoftware software, String installDir) {
  final sep = Platform.pathSeparator;
  switch (software) {
    case DjSoftware.virtualDj:
      return ['$installDir${sep}database.xml'];
    case DjSoftware.rekordbox:
      return ['$installDir${sep}master.db'];
    case DjSoftware.serato:
      return [
        '$installDir${sep}_Serato_${sep}database V2',
        '$installDir${sep}Library${sep}master.sqlite',
      ];
    case DjSoftware.traktor:
      return ['$installDir${sep}collection.nml'];
    case DjSoftware.mixxx:
      return ['$installDir${sep}mixxxdb.sqlite'];
    case DjSoftware.engineDj:
      return [
        '$installDir${sep}m.db',
        '$installDir${sep}Database2${sep}m.db',
        '$installDir${sep}Engine Library${sep}Database2${sep}m.db',
      ];
    case DjSoftware.djayPro:
      return [
        '$installDir${sep}MediaLibrary.db',
        '$installDir${sep}djay Media Library.djayMediaLibrary${sep}MediaLibrary.db',
      ];
  }
}

List<String> _defaultInstallRoots() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    return [
      '/Applications',
      if (home != null && home.isNotEmpty) '$home/Applications',
    ];
  }
  if (Platform.isWindows) {
    final roots = <String>[];
    for (final key in ['ProgramFiles', 'ProgramFiles(x86)', 'LOCALAPPDATA']) {
      final value = Platform.environment[key];
      if (value == null || value.isEmpty) continue;
      roots.add(value);
      if (key == 'LOCALAPPDATA') roots.add('$value\\Programs');
    }
    return roots;
  }
  return const [];
}

Future<List<String>> _registryInstallDirs(DjSoftware software) async {
  if (!Platform.isWindows) return const [];
  final keys = switch (software) {
    DjSoftware.virtualDj => const [
        r'HKCU\Software\VirtualDJ',
        r'HKLM\Software\VirtualDJ',
        r'HKLM\Software\AtomixProductions\VirtualDJ',
      ],
    DjSoftware.rekordbox => const [
        r'HKCU\Software\Pioneer\rekordbox',
        r'HKLM\Software\Pioneer\rekordbox',
      ],
    DjSoftware.serato => const [
        r'HKCU\Software\Serato',
        r'HKLM\Software\Serato',
      ],
    DjSoftware.traktor => const [
        r'HKCU\Software\Native Instruments\Traktor',
        r'HKLM\Software\Native Instruments\Traktor',
      ],
    DjSoftware.mixxx => const [
        r'HKCU\Software\Mixxx',
        r'HKLM\Software\Mixxx',
      ],
    DjSoftware.engineDj => const [
        r'HKCU\Software\Engine DJ',
        r'HKLM\Software\Engine DJ',
      ],
    DjSoftware.djayPro => const [
        r'HKCU\Software\Algoriddim',
        r'HKLM\Software\Algoriddim',
      ],
  };
  final dirs = <String>[];
  for (final key in keys) {
    try {
      final result = await Process.run('reg', ['query', key]);
      if (result.exitCode != 0) continue;
      for (final line in '${result.stdout}'.split(RegExp(r'\r?\n'))) {
        final match = RegExp(r'REG_SZ\s+(.+)$').firstMatch(line.trim());
        if (match == null) continue;
        final value = match.group(1)!.trim().replaceAll('"', '');
        if (value.contains(r'\') || value.contains('/')) dirs.add(value);
      }
    } catch (_) {}
  }
  return dirs;
}
