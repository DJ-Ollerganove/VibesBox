import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Readonly SQLite with live open first and copy-on-lock fallback.
class ReadonlySqlite {
  Database? _db;
  String? _sourcePath;
  String? _copyName;
  bool openedViaCopy = false;

  Database ensure(String path, String copyName) {
    // Immer neu öffnen (wie what's-now-playing): unter Windows bleiben
    // WAL-Updates auf einer alten Readonly-Connection sonst oft unsichtbar.
    close();
    _sourcePath = path;
    _copyName = copyName;
    try {
      _db = openSqliteDirect(path);
      openedViaCopy = false;
      return _db!;
    } catch (_) {
      final copy = copySqliteForRead(path, copyName);
      _db = openSqliteDirect(copy);
      openedViaCopy = true;
      return _db!;
    }
  }

  void close() {
    _db?.close();
    _db = null;
    openedViaCopy = false;
  }
}

Database openSqliteDirect(String path) {
  return withSqliteRetry(() {
    final db = _openReadonlyUri(path);
    try {
      db.execute('PRAGMA query_only = ON');
      db.execute('PRAGMA read_uncommitted = 1');
      db.select('SELECT count(*) FROM sqlite_master');
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  });
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
  withSqliteRetry(() {
    File(path).copySync(copy.path);
    return null;
  });
  for (final extra in const ['-wal', '-shm']) {
    final src = File('$path$extra');
    final dst = File('${copy.path}$extra');
    try {
      if (src.existsSync() && src.lengthSync() > 0) {
        withSqliteRetry(() {
          src.copySync(dst.path);
          return null;
        });
      } else if (dst.existsSync()) {
        dst.deleteSync();
      }
    } catch (_) {
      // Nie WAL/SHM einer alten Kopie mit neuer Hauptdatei mischen.
      try {
        if (dst.existsSync()) dst.deleteSync();
      } catch (_) {}
    }
  }
  return copy.path;
}

/// Retry for Windows sharing violations / SQLite "database is locked".
T withSqliteRetry<T>(
  T Function() action, {
  int maxAttempts = 5,
  Duration baseDelay = const Duration(milliseconds: 25),
}) {
  Object? lastError;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return action();
    } catch (error) {
      lastError = error;
      if (!_isTransientIoOrLock(error) || attempt == maxAttempts - 1) {
        rethrow;
      }
      final delay = baseDelay * (1 << attempt);
      sleep(delay > const Duration(milliseconds: 200)
          ? const Duration(milliseconds: 200)
          : delay);
    }
  }
  throw StateError('sqlite retry exhausted: $lastError');
}

/// Exposed for unit tests.
bool isTransientSqliteLockError(Object error) => _isTransientIoOrLock(error);

bool _isTransientIoOrLock(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('database is locked') ||
      text.contains('locked') ||
      text.contains('sharing violation') ||
      text.contains('being used by another process') ||
      text.contains('errno = 32') ||
      text.contains('error 32')) {
    return true;
  }
  if (error is PathAccessException || error is FileSystemException) {
    final os = error is PathAccessException
        ? error.osError
        : (error as FileSystemException).osError;
    // Windows ERROR_SHARING_VIOLATION = 32, ERROR_LOCK_VIOLATION = 33
    if (os?.errorCode == 32 || os?.errorCode == 33) return true;
  }
  return false;
}

Database _openReadonlyUri(String path) {
  // URI mode: Windows-Pfade ohne Leading-Slash korrekt als file:///C:/...
  final uri = Uri.file(File(path).absolute.path).replace(
    queryParameters: const {'mode': 'ro'},
  );
  try {
    return sqlite3.open(uri.toString(), mode: OpenMode.readOnly, uri: true);
  } catch (_) {
    return sqlite3.open(path, mode: OpenMode.readOnly);
  }
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
