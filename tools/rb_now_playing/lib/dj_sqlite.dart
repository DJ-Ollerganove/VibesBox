import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

Database openSqliteReadonly(String path, String copyName) {
  try {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    db.execute('PRAGMA query_only = ON');
    db.select('SELECT count(*) FROM sqlite_master');
    return db;
  } catch (_) {
    final copy = copySqliteForRead(path, copyName);
    final db = sqlite3.open(copy, mode: OpenMode.readOnly);
    db.execute('PRAGMA query_only = ON');
    db.select('SELECT count(*) FROM sqlite_master');
    return db;
  }
}

String copySqliteForRead(String path, String copyName) {
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  final dir = Directory('$home/Library/Application Support/VibesBoxRbTool');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final copy = File('${dir.path}/$copyName');
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
    (row) => (row['name']?.toString() ?? '').toLowerCase() == column.toLowerCase(),
  );
}
