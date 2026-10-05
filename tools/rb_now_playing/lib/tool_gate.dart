import 'dart:convert';
import 'dart:io';

import 'tool_rest.dart';

/// Sichtbare Version. Die Zahl hinter + in der pubspec ist nur die interne
/// Build-Nummer für Mac und Windows und wird hier nicht angezeigt.
const kSyncToolVersion = '1.0.2';

const kPrivacyUrl = 'https://vibesbox.app/datenschutz.html';
const kImprintUrl = 'https://vibesbox.app/impressum.html';
const kTermsUrl = 'https://vibesbox.app/agb.html';

/// Vergleicht `1.0.1` mit `1.0.2`. Ein `+1` am Ende zählt nicht mit.
int compareSyncVersions(String a, String b) {
  List<int> parts(String raw) {
    final clean = raw.split('+').first.trim();
    final bits = clean.split('.');
    return [
      for (var i = 0; i < 3; i++)
        i < bits.length ? int.tryParse(bits[i]) ?? 0 : 0,
    ];
  }

  final left = parts(a);
  final right = parts(b);
  for (var i = 0; i < 3; i++) {
    if (left[i] != right[i]) return left[i].compareTo(right[i]);
  }
  return 0;
}

class SyncToolPolicy {
  const SyncToolPolicy({
    required this.latest,
    required this.minimum,
    required this.macUrl,
    required this.winUrl,
    required this.note,
  });

  const SyncToolPolicy.empty()
      : latest = '',
        minimum = '',
        macUrl = '',
        winUrl = '',
        note = '';

  final String latest;
  final String minimum;
  final String macUrl;
  final String winUrl;
  final String note;

  bool get blocks =>
      minimum.isNotEmpty && compareSyncVersions(kSyncToolVersion, minimum) < 0;

  bool get optional =>
      !blocks &&
      latest.isNotEmpty &&
      compareSyncVersions(kSyncToolVersion, latest) < 0;

  String get downloadUrl {
    final url = Platform.isWindows ? winUrl : macUrl;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) return '';
    return url.trim();
  }

  static Future<SyncToolPolicy> load() async {
    try {
      final data = await ToolRestClient().getPublicDocument(
        collection: 'admin_config',
        docId: 'sync_tool',
      );
      if (data == null) return const SyncToolPolicy.empty();
      final windows = Platform.isWindows;
      String field(String key) => (data[key] ?? '').toString().trim();
      final latest = field(windows ? 'win_latest_version' : 'mac_latest_version');
      final minimum = field(windows ? 'win_min_version' : 'mac_min_version');
      final note = field(windows ? 'win_note' : 'mac_note');
      return SyncToolPolicy(
        latest: latest.isNotEmpty ? latest : field('latest_version'),
        minimum: minimum.isNotEmpty ? minimum : field('min_version'),
        macUrl: field('mac_url'),
        winUrl: field('win_url'),
        note: note.isNotEmpty ? note : field('note'),
      );
    } catch (_) {
      return const SyncToolPolicy.empty();
    }
  }
}

class ToolConsentStore {
  static Future<bool> load() async {
    try {
      final file = _file();
      if (!file.existsSync()) return false;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return false;
      return data['accepted'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> accept() async {
    final file = _file();
    await file.writeAsString(jsonEncode({
      'accepted': true,
      'at': DateTime.now().toUtc().toIso8601String(),
      'version': kSyncToolVersion,
    }));
  }

  static File _file() {
    final dir = _supportDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/consent.json');
  }
}

class UpdateDismissStore {
  static Future<bool> isDismissed(String latest) async {
    if (latest.isEmpty) return false;
    try {
      final file = _file();
      if (!file.existsSync()) return false;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return false;
      return data['version']?.toString() == latest;
    } catch (_) {
      return false;
    }
  }

  static Future<void> dismiss(String latest) async {
    final file = _file();
    await file.writeAsString(jsonEncode({'version': latest}));
  }

  static File _file() {
    final dir = _supportDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/update_dismissed.json');
  }
}

/// Meldet Gerät, Version und OS höchstens alle 15 Minuten. Ein Write, kein Takt.
class ToolInstallReporter {
  static const _gap = Duration(minutes: 15);

  static Future<Map<String, String>?> payloadIfDue({required String os}) async {
    final file = _reportFile();
    final now = DateTime.now().toUtc();
    var deviceId = '';
    DateTime? reportedAt;
    var reportedVersion = '';
    var reportedOs = '';
    if (file.existsSync()) {
      try {
        final data = jsonDecode(await file.readAsString());
        if (data is Map) {
          deviceId = (data['deviceId'] ?? '').toString();
          reportedVersion = (data['version'] ?? '').toString();
          reportedOs = (data['os'] ?? '').toString();
          reportedAt = DateTime.tryParse((data['reportedAt'] ?? '').toString());
        }
      } catch (_) {}
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{8,64}$').hasMatch(deviceId)) {
      deviceId = _newDeviceId();
      reportedAt = null;
    }
    final changed = reportedVersion != kSyncToolVersion || reportedOs != os;
    final due = reportedAt == null || now.difference(reportedAt.toUtc()) >= _gap;
    if (!changed && !due) return null;
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
    if (!file.existsSync() || (dataDeviceChanged(file, deviceId))) {
      await file.writeAsString(jsonEncode({
        'deviceId': deviceId,
        'version': reportedVersion,
        'os': reportedOs,
        'reportedAt': reportedAt?.toIso8601String() ?? '',
      }));
    }
    return {
      'deviceId': deviceId,
      'version': kSyncToolVersion,
      'os': os,
    };
  }

  static bool dataDeviceChanged(File file, String deviceId) {
    try {
      final data = jsonDecode(file.readAsStringSync());
      return data is! Map || data['deviceId']?.toString() != deviceId;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markReported({required String os}) async {
    final file = _reportFile();
    if (!file.existsSync()) return;
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return;
      data['version'] = kSyncToolVersion;
      data['os'] = os;
      data['reportedAt'] = DateTime.now().toUtc().toIso8601String();
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  static String _newDeviceId() {
    final n = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final r = DateTime.now().hashCode.abs().toRadixString(16);
    final id = 'd$n$r';
    return id.length > 64 ? id.substring(0, 64) : id;
  }

  static File _reportFile() {
    final dir = _supportDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/install_report.json');
  }
}

Directory _supportDir() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'] ?? '$home\\AppData\\Roaming';
    return Directory('$appData\\VibesBoxRbTool');
  }
  if (Platform.isMacOS) {
    return Directory('$home/Library/Application Support/VibesBoxRbTool');
  }
  return Directory('$home/.vibesbox_rb_tool');
}

Future<void> openToolUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) return;
  if (Platform.isMacOS) {
    await Process.run('open', [url]);
  } else if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', url]);
  } else {
    await Process.run('xdg-open', [url]);
  }
}
