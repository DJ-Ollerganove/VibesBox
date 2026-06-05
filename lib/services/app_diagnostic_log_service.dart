import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'active_party_service.dart';
import 'user_service.dart';

/// Geräte-Diagnoseprotokoll für den Admin-DJ (Release-tauglich).
///
/// Erfasst u. a. Framework-Fehler, App-Lifecycle und explizite [diagLog]-Einträge.
/// Nur der Admin-DJ-Account ([AppConfig.adminDjId]) kann die Logs in der App lesen.
class AppDiagnosticLogService with WidgetsBindingObserver {
  AppDiagnosticLogService._();
  static final AppDiagnosticLogService instance = AppDiagnosticLogService._();

  static const String _prefsCaptureKey = 'admin_diagnostic_log_capture_v1';
  static const int _maxInMemoryEntries = 600;
  static const int _maxFileBytes = 512 * 1024;

  final List<DiagnosticLogEntry> _entries = <DiagnosticLogEntry>[];
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _installed = false;
  bool _captureEnabled = true;
  bool _persistScheduled = false;
  Timer? _heartbeatTimer;
  File? _logFile;
  PackageInfo? _packageInfo;

  /// Nur Admin-Rolle + eingeloggte UID = [AppConfig.adminDjId].
  static bool canAccessDiagnosticUi() {
    final user = FirebaseAuth.instance.currentUser;
    final model = UserService().currentUser.value;
    final adminUid = AppConfig.adminDjId;
    if (user == null || model == null || adminUid == null || adminUid.isEmpty) {
      return false;
    }
    return model.id == user.uid &&
        user.uid == adminUid &&
        AppConfig.isAdminRole(model);
  }

  bool _shouldCaptureForCurrentUser() {
    if (!_captureEnabled) return false;
    if (Firebase.apps.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    final adminUid = AppConfig.adminDjId;
    if (user == null || adminUid == null || adminUid.isEmpty) return false;
    return user.uid == adminUid;
  }

  bool get captureEnabledPreference => _captureEnabled;

  List<DiagnosticLogEntry> get entries =>
      List<DiagnosticLogEntry>.unmodifiable(_entries);

  Future<void> install() async {
    if (_installed) return;
    _installed = true;

    final prefs = await SharedPreferences.getInstance();
    _captureEnabled = prefs.getBool(_prefsCaptureKey) ?? true;

    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}

    await _ensureLogFile();
    await _loadTailFromFile();

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _recordInternal(
        'ERROR',
        '${details.exceptionAsString()}\n${details.stack ?? ''}',
      );
      previousFlutterOnError?.call(details);
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _recordInternal('ERROR', '$error\n$stack');
      if (previousPlatformOnError != null) {
        return previousPlatformOnError(error, stack);
      }
      return false;
    };

    WidgetsBinding.instance.addObserver(this);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!_shouldCaptureForCurrentUser()) return;
      _recordInternal(
        'LIFE',
        'Heartbeat (30 min) | seenWishIds=${ActivePartyService.seenWishIds.length}',
      );
    });
    _recordInternal(
      'LIFE',
      'Diagnose-Log installiert (${_platformLabel()}, '
      'v${_packageInfo?.version ?? '?'}+${_packageInfo?.buildNumber ?? '?'})',
    );
  }

  Future<void> setCaptureEnabled(bool enabled) async {
    _captureEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsCaptureKey, enabled);
    _recordInternal('INFO', 'Aufzeichnung ${enabled ? 'an' : 'aus'}');
  }

  void log(String level, Object? message) {
    _recordInternal(level, message?.toString() ?? '');
  }

  void _recordInternal(String level, String message) {
    if (!_captureEnabled) return;
    if (!_shouldCaptureForCurrentUser()) return;

    final line = message.trim();
    if (line.isEmpty) return;

    final entry = DiagnosticLogEntry(
      at: DateTime.now(),
      level: level.toUpperCase(),
      message: line.length > 4000 ? '${line.substring(0, 4000)}…' : line,
    );

    _entries.add(entry);
    if (_entries.length > _maxInMemoryEntries) {
      _entries.removeRange(0, _entries.length - _maxInMemoryEntries);
    }
    revision.value++;
    _schedulePersist(entry);
  }

  void _schedulePersist(DiagnosticLogEntry entry) {
    if (_persistScheduled) return;
    _persistScheduled = true;
    scheduleMicrotask(() async {
      _persistScheduled = false;
      await _appendToFile(entry);
    });
  }

  Future<File?> getLogFile() async {
    await _ensureLogFile();
    return _logFile;
  }

  Future<String> exportAsText() async {
    final buf = StringBuffer();
    buf.writeln('VibesBox Diagnose-Log');
    buf.writeln(
      'Export: ${DateTime.now().toIso8601String()} | '
      'Plattform: ${_platformLabel()} | '
      'App: ${_packageInfo?.version ?? '?'} (${_packageInfo?.buildNumber ?? '?'})',
    );
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '—';
    buf.writeln('UID: $uid');
    buf.writeln('—' * 48);
    for (final e in _entries) {
      buf.writeln(e.formatLine());
    }
    return buf.toString();
  }

  Future<void> clear() async {
    _entries.clear();
    revision.value++;
    await _ensureLogFile();
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('', flush: true);
    }
    _recordInternal('INFO', 'Log geleert');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _recordInternal('LIFE', 'AppLifecycle: $state');
    if (state == AppLifecycleState.detached) {
      unawaited(_flushFile());
    }
  }

  Future<void> _ensureLogFile() async {
    if (_logFile != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/vibesbox_admin_diagnostic.log');
    } catch (e) {
      _logFile = null;
    }
  }

  Future<void> _loadTailFromFile() async {
    await _ensureLogFile();
    final file = _logFile;
    if (file == null || !await file.exists()) return;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
      final tail = lines.length > 120 ? lines.skip(lines.length - 120) : lines;
      for (final line in tail) {
        final parsed = DiagnosticLogEntry.tryParseStoredLine(line);
        if (parsed != null) {
          _entries.add(parsed);
        }
      }
      if (_entries.length > _maxInMemoryEntries) {
        _entries.removeRange(0, _entries.length - _maxInMemoryEntries);
      }
      revision.value++;
    } catch (_) {}
  }

  Future<void> _appendToFile(DiagnosticLogEntry entry) async {
    await _ensureLogFile();
    final file = _logFile;
    if (file == null) return;
    try {
      await file.writeAsString(
        '${entry.formatLine()}\n',
        mode: FileMode.append,
        flush: false,
      );
      final len = await file.length();
      if (len > _maxFileBytes) {
        final content = await file.readAsString();
        final trimmed = content.length > _maxFileBytes ~/ 2
            ? content.substring(content.length - (_maxFileBytes ~/ 2))
            : content;
        await file.writeAsString(trimmed, flush: true);
      }
    } catch (_) {}
  }

  Future<void> _flushFile() async {}

  String _platformLabel() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }
}

class DiagnosticLogEntry {
  final DateTime at;
  final String level;
  final String message;

  const DiagnosticLogEntry({
    required this.at,
    required this.level,
    required this.message,
  });

  String formatLine() {
    final ts = at.toIso8601String();
    final oneLine = message.replaceAll('\n', ' ↵ ');
    return '[$ts] [$level] $oneLine';
  }

  static DiagnosticLogEntry? tryParseStoredLine(String line) {
    final m = RegExp(r'^\[([^\]]+)\] \[([^\]]+)\] (.+)$').firstMatch(line.trim());
    if (m == null) return null;
    final at = DateTime.tryParse(m.group(1)!);
    if (at == null) return null;
    return DiagnosticLogEntry(
      at: at,
      level: m.group(2)!,
      message: (m.group(3) ?? '').replaceAll(' ↵ ', '\n'),
    );
  }
}

/// Kurzform für wichtige Diagnose-Einträge (Shazam, Party, …).
void diagLog(String level, Object? message) {
  AppDiagnosticLogService.instance.log(level, message);
}
