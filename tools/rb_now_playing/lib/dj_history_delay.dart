import 'dart:async';
import 'dart:io';

import 'dj_library_prefs.dart';
import 'virtualdj_library.dart';

/// Rekordbox erlaubt 1 bis 60 Sekunden, Virtual DJ 0 bis 60.
int clampHistoryDelay(DjSoftware software, int seconds) {
  final max = 60;
  final min = software == DjSoftware.rekordbox ? 1 : 0;
  if (seconds < min) return min;
  if (seconds > max) return max;
  return seconds;
}

int? readRekordboxPlayedTime(String xml) {
  final match = RegExp(
    r'<VALUE\s+name="playedTime"\s+val="(\d+)"',
  ).firstMatch(xml);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

String? writeRekordboxPlayedTime(String xml, int seconds) {
  final sec = clampHistoryDelay(DjSoftware.rekordbox, seconds);
  final current = readRekordboxPlayedTime(xml);
  final pattern = RegExp(r'(<VALUE\s+name="playedTime"\s+val=")(\d+)(")');
  if (pattern.hasMatch(xml)) {
    if (current == sec) return xml;
    return xml.replaceFirstMapped(pattern, (m) => '${m[1]}$sec${m[3]}');
  }
  const close = '</PROPERTIES>';
  final at = xml.lastIndexOf(close);
  if (at < 0) return null;
  final nl = xml.contains('\r\n') ? '\r\n' : '\n';
  return xml.replaceRange(at, at, '  <VALUE name="playedTime" val="$sec"/>$nl');
}

int? readVirtualDjHistoryDelay(String xml) {
  final match = RegExp(
    r'<historyDelay\b[^>]*>\s*(\d+)\s*</historyDelay>',
  ).firstMatch(xml);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

String? writeVirtualDjHistoryDelay(String xml, int seconds) {
  final sec = clampHistoryDelay(DjSoftware.virtualDj, seconds);
  final current = readVirtualDjHistoryDelay(xml);
  final pattern = RegExp(
    r'(<historyDelay\b[^>]*>)\s*(\d+)\s*(</historyDelay>)',
  );
  if (pattern.hasMatch(xml)) {
    if (current == sec) return xml;
    return xml.replaceFirstMapped(pattern, (m) => '${m[1]}$sec${m[3]}');
  }
  const close = '</settings>';
  final at = xml.lastIndexOf(close);
  if (at < 0) return null;
  final nl = xml.contains('\r\n') ? '\r\n' : '\n';
  return xml.replaceRange(
    at,
    at,
    '\t<historyDelay modified="yes">$sec</historyDelay>$nl',
  );
}

int? readVirtualDjOscPort(String xml) {
  final match = RegExp(r'<oscPort>\s*(\d+)\s*</oscPort>').firstMatch(xml);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// OSC-Adresse, mit der Virtual DJ `setting historyDelay` sofort ausführt.
List<int> oscVirtualDjHistoryDelay(int seconds) {
  final address = '/vdj/setting/historyDelay/$seconds';
  return _oscAddress(address);
}

List<int> _oscAddress(String address) {
  final raw = address.codeUnits;
  final padded = (raw.length + 4) & ~3;
  final out = List<int>.filled(padded + 4, 0);
  for (var i = 0; i < raw.length; i++) {
    out[i] = raw[i];
  }
  out[padded] = 0x2c; // ','
  return out;
}

class DjHistoryDelay {
  static Future<bool> Function(DjSoftware software)? isRunning;
  static Future<List<int>> Function(DjSoftware software)? pidsForTest;
  static List<File> Function()? rekordboxFilesForTest;
  static List<File> Function()? virtualDjFilesForTest;
  static void Function(
    DjSoftware software,
    int seconds,
    int djPid,
    List<String> paths,
  )?
  armForTest;

  static final Set<DjSoftware> _guarded = {};
  static final Map<DjSoftware, int> _guardTarget = {};
  static final Map<DjSoftware, int> _helperPid = {};

  static void resetRuntime() {
    isRunning = null;
    pidsForTest = null;
    rekordboxFilesForTest = null;
    virtualDjFilesForTest = null;
    armForTest = null;
    _guarded.clear();
    _guardTarget.clear();
    _helperPid.clear();
  }

  static Future<void> refreshDisplayed(DjLibraryPrefs prefs) async {
    final rb = _newestValue(_rekordboxFiles(), readRekordboxPlayedTime);
    final vdj = _newestValue(_virtualDjFiles(), readVirtualDjHistoryDelay);
    var changed = false;
    if (rb.found != prefs.rekordboxSettingsFound) {
      prefs.rekordboxSettingsFound = rb.found;
      changed = true;
    }
    if (vdj.found != prefs.virtualDjSettingsFound) {
      prefs.virtualDjSettingsFound = vdj.found;
      changed = true;
    }
    if (!prefs.rekordboxHistoryDelayPending &&
        rb.value != null &&
        rb.value != prefs.rekordboxHistoryDelaySec) {
      prefs.rekordboxHistoryDelaySec = rb.value!;
      changed = true;
    }
    if (!prefs.virtualDjHistoryDelayPending &&
        vdj.value != null &&
        vdj.value != prefs.virtualDjHistoryDelaySec) {
      prefs.virtualDjHistoryDelaySec = vdj.value!;
      changed = true;
    }
    if (!changed) return;
    await prefs.save();
    prefs.changed();
  }

  static Future<void> request(
    DjLibraryPrefs prefs,
    DjSoftware software,
    int seconds,
  ) async {
    final next = clampHistoryDelay(software, seconds);
    if (software == DjSoftware.rekordbox) {
      if (prefs.rekordboxHistoryDelaySec == next &&
          prefs.rekordboxHistoryDelayPending) {
        return;
      }
      prefs.rekordboxHistoryDelaySec = next;
      prefs.rekordboxHistoryDelayPending = true;
    } else if (software == DjSoftware.virtualDj) {
      if (prefs.virtualDjHistoryDelaySec == next &&
          prefs.virtualDjHistoryDelayPending) {
        return;
      }
      prefs.virtualDjHistoryDelaySec = next;
      prefs.virtualDjHistoryDelayPending = true;
    } else {
      return;
    }
    await prefs.save();
    prefs.changed();
    await applyPending(prefs);
  }

  static Future<void> applyPending(DjLibraryPrefs prefs) async {
    if (!prefs.rekordboxHistoryDelayPending &&
        !prefs.virtualDjHistoryDelayPending) {
      return;
    }
    var changed = false;
    if (prefs.rekordboxHistoryDelayPending) {
      changed =
          await _applyNow(
            software: DjSoftware.rekordbox,
            seconds: prefs.rekordboxHistoryDelaySec,
            files: _rekordboxFiles(),
            setFound: (value) => prefs.rekordboxSettingsFound = value,
            clearPending: () => prefs.rekordboxHistoryDelayPending = false,
            update: writeRekordboxPlayedTime,
          ) ||
          changed;
    }
    if (prefs.virtualDjHistoryDelayPending) {
      changed =
          await _applyNow(
            software: DjSoftware.virtualDj,
            seconds: prefs.virtualDjHistoryDelaySec,
            files: _virtualDjFiles(),
            setFound: (value) => prefs.virtualDjSettingsFound = value,
            clearPending: () => prefs.virtualDjHistoryDelayPending = false,
            update: writeVirtualDjHistoryDelay,
          ) ||
          changed;
    }
    if (!changed) return;
    await prefs.save();
    prefs.changed();
  }

  static Future<bool> _applyNow({
    required DjSoftware software,
    required int seconds,
    required List<File> files,
    required void Function(bool found) setFound,
    required void Function() clearPending,
    required String? Function(String xml, int seconds) update,
  }) async {
    if (files.isEmpty) {
      setFound(false);
      clearPending();
      _guarded.remove(software);
      return true;
    }
    setFound(true);
    final running = await _running(software);
    if (!running) {
      final wrote = await _writeAll(files, seconds, update);
      if (wrote == 0) return false;
      clearPending();
      _guarded.remove(software);
      _guardTarget.remove(software);
      return true;
    }
    final already =
        _guarded.contains(software) && _guardTarget[software] == seconds;
    if (already) return false;
    final wrote = await _writeAll(files, seconds, update);
    if (wrote == 0) return false;
    if (software == DjSoftware.virtualDj) {
      await _pushVirtualDjLive(files, seconds);
    }
    final pids = await _pids(software);
    final pid = pids.isEmpty ? 0 : pids.first;
    if (pid > 0) {
      _arm(software, seconds, pid, [for (final file in files) file.path]);
      _guarded.add(software);
      _guardTarget[software] = seconds;
    }
    // Programm läuft: die Datei hat die neue Zeit schon.
    // Pending bleibt, damit ein späteres Lesen der alten Speicher-Kopie
    // den Regler nicht zurücksetzt. Ein Helfer außerhalb von Sync schreibt
    // die Zeit noch einmal, sobald genau dieser Prozess zu ist.
    return true;
  }

  static Future<void> _pushVirtualDjLive(List<File> files, int seconds) async {
    var port = 0;
    for (final file in files) {
      try {
        final found = readVirtualDjOscPort(await file.readAsString());
        if (found != null && found > 0) {
          port = found;
          break;
        }
      } catch (_) {}
    }
    if (port <= 0 || port > 65535) return;
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      socket.send(
        oscVirtualDjHistoryDelay(seconds),
        InternetAddress.loopbackIPv4,
        port,
      );
    } catch (_) {
    } finally {
      socket?.close();
    }
  }

  static void _arm(
    DjSoftware software,
    int seconds,
    int djPid,
    List<String> paths,
  ) {
    final hook = armForTest;
    if (hook != null) {
      hook(software, seconds, djPid, paths);
      return;
    }
    unawaited(_armDetached(software, seconds, djPid, paths));
  }

  static Future<void> _armDetached(
    DjSoftware software,
    int seconds,
    int djPid,
    List<String> paths,
  ) async {
    if (djPid <= 0 || paths.isEmpty) return;
    final cmd = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}vibesbox-dj-delay-${software.id}.cmd',
    );
    final lines = <String>[
      'pid=$djPid',
      'seconds=$seconds',
      'kind=${software.id}',
      for (final path in paths)
        if (!path.contains('\n') && !path.contains('\r')) 'file=$path',
    ];
    await cmd.writeAsString('${lines.join('\n')}\n', flush: true);
    final helper = _helperPid[software];
    if (helper != null && await _pidAlive(helper)) return;
    final process = await _startHelper(cmd.path);
    if (process != null) _helperPid[software] = process.pid;
  }

  static Future<Process?> _startHelper(String cmdPath) async {
    try {
      final dir = Directory.systemTemp.path;
      final sep = Platform.pathSeparator;
      final py = File('$dir${sep}vibesbox-dj-delay.py');
      if (!py.existsSync() || py.readAsStringSync() != historyDelayHelperPy) {
        await py.writeAsString(historyDelayHelperPy, flush: true);
      }
      if (Platform.isWindows) {
        final ps1 = File('$dir${sep}vibesbox-dj-delay.ps1');
        if (!ps1.existsSync()) {
          await ps1.writeAsString(_helperPs, flush: true);
        }
        return Process.start(
          'powershell',
          ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1.path],
          mode: ProcessStartMode.detached,
          environment: {
            ...Platform.environment,
            'VB_DJ_DELAY_CMD': cmdPath,
            'VB_DJ_DELAY_PY': py.path,
          },
        );
      }
      return Process.start(
        '/bin/sh',
        ['-c', _helperSh],
        mode: ProcessStartMode.detached,
        environment: {
          ...Platform.environment,
          'VB_DJ_DELAY_CMD': cmdPath,
          'VB_DJ_DELAY_PY': py.path,
        },
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _running(DjSoftware software) {
    final override = isRunning;
    if (override != null) return override(software);
    return djAppIsRunning(software);
  }

  static Future<List<int>> _pids(DjSoftware software) {
    final override = pidsForTest;
    if (override != null) return override(software);
    return djAppPids(software);
  }
}

class _Read {
  const _Read(this.found, this.value);
  final bool found;
  final int? value;
}

_Read _newestValue(List<File> files, int? Function(String xml) read) {
  if (files.isEmpty) return const _Read(false, null);
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  for (final file in files) {
    try {
      final value = read(file.readAsStringSync());
      if (value != null) return _Read(true, value);
    } catch (_) {}
  }
  return const _Read(true, null);
}

Future<int> _writeAll(
  List<File> files,
  int seconds,
  String? Function(String xml, int seconds) update,
) async {
  var wrote = 0;
  for (final file in files) {
    try {
      final xml = await file.readAsString();
      final next = update(xml, seconds);
      if (next == null) continue;
      if (next == xml) {
        wrote++;
        continue;
      }
      final tmp = File('${file.path}.vibesboxtmp');
      await tmp.writeAsString(next, flush: true);
      try {
        await tmp.rename(file.path);
      } catch (_) {
        await file.writeAsString(next, flush: true);
        if (tmp.existsSync()) tmp.deleteSync();
      }
      wrote++;
    } catch (_) {}
  }
  return wrote;
}

List<File> _rekordboxFiles() {
  final override = DjHistoryDelay.rekordboxFilesForTest;
  if (override != null) return override();
  return [
    for (final path in rekordboxSettingsCandidates())
      if (File(path).existsSync()) File(path),
  ];
}

List<File> _virtualDjFiles() {
  final override = DjHistoryDelay.virtualDjFilesForTest;
  if (override != null) return override();
  return [
    for (final dir in virtualDjHomeDirs())
      if (File('$dir${Platform.pathSeparator}settings.xml').existsSync())
        File('$dir${Platform.pathSeparator}settings.xml'),
  ];
}

List<String> rekordboxSettingsCandidates() {
  final out = <String>[];
  final home = Platform.environment['HOME'];
  final appData = Platform.environment['APPDATA'];
  if (home != null && home.isNotEmpty) {
    for (final version in ['rekordbox7', 'rekordbox6', 'rekordbox5']) {
      out.add(
        '$home/Library/Application Support/Pioneer/$version/rekordbox3.settings',
      );
    }
  }
  if (appData != null && appData.isNotEmpty) {
    for (final version in ['rekordbox7', 'rekordbox6', 'rekordbox5']) {
      out.add('$appData\\Pioneer\\$version\\rekordbox3.settings');
    }
  }
  return out;
}

const _helperSh = r'''
cmd="$VB_DJ_DELAY_CMD"
py="$VB_DJ_DELAY_PY"
while true; do
  pid=$(awk -F= '/^pid=/{print $2; exit}' "$cmd")
  case "$pid" in
    ''|*[!0-9]*) exit 1 ;;
  esac
  if kill -0 "$pid" 2>/dev/null; then
    sleep 1
    continue
  fi
  sleep 0.5
  pid2=$(awk -F= '/^pid=/{print $2; exit}' "$cmd")
  if [ "$pid2" != "$pid" ]; then
    continue
  fi
  if kill -0 "$pid" 2>/dev/null; then
    continue
  fi
  python3 "$py" "$cmd"
  rm -f "$cmd"
  exit 0
done
''';

const _helperPs = r'''
$cmd = $env:VB_DJ_DELAY_CMD
$py = $env:VB_DJ_DELAY_PY
while ($true) {
  $line = Get-Content -LiteralPath $cmd | Where-Object { $_ -like 'pid=*' } | Select-Object -First 1
  if (-not $line) { exit 1 }
  $djPid = [int]($line.Substring(4))
  if (Get-Process -Id $djPid -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 1
    continue
  }
  Start-Sleep -Milliseconds 500
  $line2 = Get-Content -LiteralPath $cmd | Where-Object { $_ -like 'pid=*' } | Select-Object -First 1
  $djPid2 = [int]($line2.Substring(4))
  if ($djPid2 -ne $djPid) { continue }
  if (Get-Process -Id $djPid -ErrorAction SilentlyContinue) { continue }
  python $py $cmd
  Remove-Item -LiteralPath $cmd -Force -ErrorAction SilentlyContinue
  exit 0
}
''';

const historyDelayHelperPy = r'''
import pathlib, re, sys
cmd = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
vals = {}
files = []
for line in cmd.splitlines():
    if line.startswith("file="):
        files.append(line[5:])
    elif "=" in line:
        key, value = line.split("=", 1)
        vals[key] = value
seconds = int(vals["seconds"])
kind = vals.get("kind", "")
if kind == "rekordbox":
    seconds = min(60, max(1, seconds))
else:
    seconds = min(60, max(0, seconds))
for path in files:
    file = pathlib.Path(path)
    try:
        text = file.read_text(encoding="utf-8")
    except OSError:
        continue
    if kind == "rekordbox":
        pattern = re.compile(r'(<VALUE\s+name="playedTime"\s+val=")(\d+)(")')
    else:
        pattern = re.compile(r"(<historyDelay\b[^>]*>)\s*(\d+)\s*(</historyDelay>)")
    updated, count = pattern.subn(lambda m: m.group(1) + str(seconds) + m.group(3), text, count=1)
    if count == 0 or updated == text:
        continue
    tmp = pathlib.Path(path + ".vibesboxtmp")
    tmp.write_text(updated, encoding="utf-8")
    tmp.replace(file)
''';

Future<bool> _pidAlive(int pid) async {
  if (pid <= 0) return false;
  try {
    if (Platform.isWindows) {
      final result = await Process.run('tasklist', [
        '/FI',
        'PID eq $pid',
        '/NH',
      ]);
      return result.stdout.toString().contains('$pid');
    }
    final result = await Process.run('kill', ['-0', '$pid']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

bool _commandIsDjApp(String command, DjSoftware software) {
  final line = command.toLowerCase();
  if (software == DjSoftware.rekordbox) {
    if (line.contains('rekordboxagent')) return false;
    return line.contains('/macos/rekordbox') ||
        line.contains(r'\rekordbox.exe') ||
        line.endsWith('/rekordbox') ||
        line.contains('rekordbox.exe');
  }
  if (software == DjSoftware.virtualDj) {
    return line.contains('/macos/virtualdj') ||
        line.contains(r'\virtualdj.exe') ||
        line.endsWith('/virtualdj') ||
        line.contains('virtualdj.exe');
  }
  return false;
}

Future<List<int>> djAppPids(DjSoftware software) async {
  final pids = <int>[];
  try {
    if (Platform.isWindows) {
      final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
      for (final raw in result.stdout.toString().split('\n')) {
        final cells = raw.split(',');
        if (cells.length < 2) continue;
        final name = cells[0].replaceAll('"', '');
        if (!_commandIsDjApp(name, software)) continue;
        final pid = int.tryParse(cells[1].replaceAll('"', '').trim());
        if (pid != null) pids.add(pid);
      }
      return pids;
    }
    final result = await Process.run('ps', ['-ax', '-o', 'pid=,command=']);
    for (final raw in result.stdout.toString().split('\n')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final gap = trimmed.indexOf(' ');
      if (gap <= 0) continue;
      final pid = int.tryParse(trimmed.substring(0, gap));
      final command = trimmed.substring(gap + 1);
      if (pid == null || !_commandIsDjApp(command, software)) continue;
      pids.add(pid);
    }
  } catch (_) {}
  return pids;
}

Future<bool> djAppIsRunning(DjSoftware software) async {
  return (await djAppPids(software)).isNotEmpty;
}
