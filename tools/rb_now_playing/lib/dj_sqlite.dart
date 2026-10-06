import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Readonly SQLite with copy-on-lock and automatic copy refresh per poll.
class ReadonlySqlite {
  Database? _db;
  String? _sourcePath;
  String? _copyName;
  bool openedViaCopy = false;

  Database ensure(String path, String copyName) {
    if (_db != null && _sourcePath == path && !openedViaCopy) {
      return _db!;
    }
    // Kopie oder anderer Pfad: neu öffnen (Kopie sonst veraltet).
    close();
    _sourcePath = path;
    _copyName = copyName;
    try {
      _db = openSqliteDirect(path);
      openedViaCopy = false;
    } catch (_) {
      final copy = copySqliteForRead(path, copyName);
      _db = openSqliteDirect(copy);
      openedViaCopy = true;
    }
    return _db!;
  }

  void close() {
    _db?.close();
    _db = null;
    openedViaCopy = false;
  }
}

Database openSqliteDirect(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  db.execute('PRAGMA query_only = ON');
  db.select('SELECT count(*) FROM sqlite_master');
  return db;
}

Database openSqliteReadonly(String path, String copyName) {
  try {
    return openSqliteDirect(path);
  } catch (_) {
    final copy = copySqliteForRead(path, copyName);
    return openSqliteDirect(copy);
  }
}

String copySqliteForRead(String path, String copyName) {
  final dir = toolSupportDir();
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final copy = File('${dir.path}${Platform.pathSeparator}$copyName');
  File(path).copySync(copy.path);
  for (final extra in const ['-wal', '-shm']) {
    final src = File('$path$extra');
    final dst = File('${copy.path}$extra');
    if (src.existsSync() && src.lengthSync() > 0) {
      src.copySync(dst.path);
    } else if (dst.existsSync()) {
      dst.deleteSync();
    }
  }
  return copy.path;
}

/// Gemeinsamer App-Support-Ordner (Windows: %APPDATA%\\VibesBoxRbTool).
Directory toolSupportDir() {
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

bool sqliteHasTable(Database db, String name) {
  final parts = name.split('.');
  final table = parts.last;
  final schema = parts.length > 1 ? parts.first : null;
  final master = schema == null ? 'sqlite_master' : '"$schema".sqlite_master';
  try {
    final rows = db.select(
      "SELECT 1 FROM $master WHERE type IN ('table','view') AND lower(name) = lower(?)",
      [table],
    );
    return rows.isNotEmpty;
  } catch (_) {
    return false;
  }
}

String sqliteTable(Database db, List<String> names) {
  final rows = db.select(
    "SELECT name FROM sqlite_master WHERE type IN ('table','view')",
  );
  final found = <String, String>{};
  for (final row in rows) {
    final name = row['name']?.toString() ?? '';
    if (name.isEmpty) continue;
    found[name.toLowerCase()] = name;
  }
  for (final name in names) {
    final hit = found[name.toLowerCase()];
    if (hit != null) return hit;
  }
  return names.first;
}

bool sqliteHasColumn(Database db, String table, String column) {
  final rows = db.select('PRAGMA table_info("$table")');
  return rows.any(
    (row) =>
        (row['name']?.toString() ?? '').toLowerCase() == column.toLowerCase(),
  );
}
