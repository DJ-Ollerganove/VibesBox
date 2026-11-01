import 'dart:io';

import 'dj_library_prefs.dart';
import 'dj_watch_script.dart';

/// Login-Wächter: startet beim Anmelden unsichtbar und öffnet VibesBox Sync,
/// wenn eine unterstützte DJ-App zu laufen beginnt. Startet keine DJ-Software.
class DjWatchInstall {
  DjWatchInstall._();

  static const windowsRunValue = 'VibesBoxSyncDjWatch';
  static Future<void> _tail = Future<void>.value();

  static Future<void> apply(bool enabled) {
    final run = _tail.then((_) => _apply(enabled));
    _tail = run.catchError((Object _) {});
    return run;
  }

  static Future<void> _apply(bool enabled) async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    if (Platform.resolvedExecutable.contains('flutter_tester')) return;
    try {
      if (Platform.isMacOS) {
        if (enabled) {
          await _installMac();
        } else {
          await _removeMac();
        }
      } else if (Platform.isWindows) {
        if (enabled) {
          await _installWindows();
        } else {
          await _removeWindows();
        }
      }
    } catch (_) {}
  }

  static Future<void> _installMac() async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return;
    final exe = Platform.resolvedExecutable;
    final app = macBundlePath(exe);
    if (app == null) return;
    final dir = vibesBoxToolSupportDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final script = File('${dir.path}/dj_watch.sh');
    final state = '${dir.path}/dj_watch_state';
    await script.writeAsString(
      buildMacWatchScript(
        syncAppPath: app,
        syncExePath: exe,
        statePath: state,
      ),
    );
    await _run('/bin/chmod', ['755', script.path]);
    final agents = Directory('$home/Library/LaunchAgents');
    if (!agents.existsSync()) agents.createSync(recursive: true);
    final plist = File('${agents.path}/$djWatchLabel.plist');
    await plist.writeAsString(buildMacLaunchAgentPlist(scriptPath: script.path));
    final uid = await _uid();
    if (uid == null) return;
    await _run('/bin/launchctl', ['enable', 'gui/$uid/$djWatchLabel']);
    await _run('/bin/launchctl', ['bootout', 'gui/$uid/$djWatchLabel']);
    final boot = await Process.run(
      '/bin/launchctl',
      ['bootstrap', 'gui/$uid', plist.path],
    );
    if (boot.exitCode != 0) {
      await _run('/bin/launchctl', ['load', '-w', plist.path]);
    }
  }

  static Future<void> _removeMac() async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return;
    final uid = await _uid();
    final plistPath = '$home/Library/LaunchAgents/$djWatchLabel.plist';
    if (uid != null) {
      await _run('/bin/launchctl', ['bootout', 'gui/$uid/$djWatchLabel']);
      await _run('/bin/launchctl', ['disable', 'gui/$uid/$djWatchLabel']);
    }
    await _run('/bin/launchctl', ['unload', '-w', plistPath]);
    await _delete(plistPath);
    final dir = vibesBoxToolSupportDir();
    await _delete('${dir.path}/dj_watch.sh');
    await _delete('${dir.path}/dj_watch_state');
  }

  static Future<void> _installWindows() async {
    final exe = Platform.resolvedExecutable;
    if (!exe.toLowerCase().endsWith('.exe')) return;
    final dir = vibesBoxToolSupportDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ps1 = File('${dir.path}\\dj_watch.ps1');
    final vbs = File('${dir.path}\\dj_watch.vbs');
    final state = '${dir.path}\\dj_watch_state';
    final pid = '${dir.path}\\dj_watch.pid';
    await ps1.writeAsString(
      buildWindowsWatchScript(
        syncExePath: exe,
        statePath: state,
        pidPath: pid,
      ),
    );
    await vbs.writeAsString(buildWindowsWatchVbs(ps1Path: ps1.path));
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final wscript = '$systemRoot\\System32\\wscript.exe';
    await _run('reg', [
      'add',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
      '/v',
      windowsRunValue,
      '/t',
      'REG_SZ',
      '/d',
      '"$wscript" "${vbs.path}"',
      '/f',
    ]);
    await _stopWindowsWatcher();
    await _run(wscript, [vbs.path]);
  }

  static Future<void> _removeWindows() async {
    await _stopWindowsWatcher();
    await _run('reg', [
      'delete',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
      '/v',
      windowsRunValue,
      '/f',
    ]);
    final dir = vibesBoxToolSupportDir();
    await _delete('${dir.path}\\dj_watch.ps1');
    await _delete('${dir.path}\\dj_watch.vbs');
    await _delete('${dir.path}\\dj_watch_state');
    await _delete('${dir.path}\\dj_watch.pid');
  }

  static Future<void> _stopWindowsWatcher() async {
    final pidFile = File('${vibesBoxToolSupportDir().path}\\dj_watch.pid');
    if (!pidFile.existsSync()) return;
    final pid = int.tryParse((await pidFile.readAsString()).trim());
    if (pid == null || pid <= 0) return;
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final powershell =
        '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
    await _run(powershell, [
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-Command',
      "\$p = Get-CimInstance Win32_Process -Filter \"ProcessId=$pid\"; "
          "if (\$p -and \$p.CommandLine -like '*dj_watch.ps1*') { "
          'Stop-Process -Id $pid -Force }',
    ]);
  }

  static Future<String?> _uid() async {
    final result = await Process.run('/usr/bin/id', ['-u']);
    final uid = result.stdout.toString().trim();
    if (uid.isEmpty) return null;
    return uid;
  }

  static Future<void> _run(String executable, List<String> args) async {
    try {
      await Process.run(executable, args);
    } catch (_) {}
  }

  static Future<void> _delete(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}
