import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rb_now_playing/dj_app_match.dart';
import 'package:rb_now_playing/dj_library_prefs.dart';
import 'package:rb_now_playing/dj_watch_script.dart';

void main() {
  test('erkennt unterstützte DJ-Apps und nicht Pulse DJ', () {
    expect(
      matchDjApp(bundleId: 'com.pioneerdj.rekordboxdj'),
      DjSoftware.rekordbox,
    );
    expect(
      matchDjApp(bundleId: 'com.pioneer.rekordboxdj', appName: 'rekordbox'),
      DjSoftware.rekordbox,
    );
    expect(matchDjApp(appName: 'rekordbox 7'), DjSoftware.rekordbox);
    expect(matchDjApp(exeName: 'rekordbox.exe'), DjSoftware.rekordbox);
    expect(
      matchDjApp(
        executablePath:
            '/Applications/rekordbox 7/rekordbox.app/Contents/MacOS/rekordbox',
      ),
      DjSoftware.rekordbox,
    );
    expect(
      matchDjApp(
        executablePath:
            r'C:\Program Files\Pioneer\rekordbox 7\rekordbox.exe',
      ),
      DjSoftware.rekordbox,
    );

    expect(
      matchDjApp(bundleId: 'com.serato.seratodj', appName: 'Serato DJ Pro'),
      DjSoftware.serato,
    );
    expect(matchDjApp(exeName: 'SeratoDJ.exe'), DjSoftware.serato);
    expect(
      matchDjApp(
        executablePath:
            '/Applications/Serato DJ Pro.app/Contents/MacOS/Serato DJ Pro',
      ),
      DjSoftware.serato,
    );
    expect(
      matchDjApp(
        executablePath:
            r'C:\Program Files\Serato\Serato DJ Pro\Serato DJ Pro.exe',
      ),
      DjSoftware.serato,
    );

    expect(
      matchDjApp(
        bundleId: 'com.atomixproductions.virtualdj',
        appName: 'VirtualDJ',
        exeName: 'virtualdj.exe',
      ),
      DjSoftware.virtualDj,
    );
    expect(
      matchDjApp(executablePath: r'C:\Program Files\VirtualDJ\virtualdj.exe'),
      DjSoftware.virtualDj,
    );

    expect(
      matchDjApp(
        bundleId: 'com.native-instruments.Traktor',
        appName: 'Traktor Pro 4',
        exeName: 'Traktor.exe',
      ),
      DjSoftware.traktor,
    );
    expect(
      matchDjApp(
        executablePath:
            '/Applications/Native Instruments/Traktor Pro 4/Traktor Pro 4.app/Contents/MacOS/Traktor Pro 4',
      ),
      DjSoftware.traktor,
    );
    expect(
      matchDjApp(
        executablePath:
            r'C:\Program Files\Native Instruments\Traktor 4\Traktor.exe',
      ),
      DjSoftware.traktor,
    );

    expect(
      matchDjApp(bundleId: 'org.mixxx.mixxx', appName: 'Mixxx', exeName: 'mixxx'),
      DjSoftware.mixxx,
    );
    expect(
      matchDjApp(executablePath: '/Applications/Mixxx.app/Contents/MacOS/mixxx'),
      DjSoftware.mixxx,
    );
    expect(
      matchDjApp(executablePath: r'C:\Program Files\Mixxx\mixxx.exe'),
      DjSoftware.mixxx,
    );

    expect(
      matchDjApp(bundleId: 'com.inmusicbrands.enginedj', appName: 'Engine DJ'),
      DjSoftware.engineDj,
    );
    expect(matchDjApp(exeName: 'Engine Prime.exe'), DjSoftware.engineDj);
    expect(
      matchDjApp(
        executablePath: r'C:\Program Files\Engine DJ\Engine DJ.exe',
      ),
      DjSoftware.engineDj,
    );

    expect(
      matchDjApp(
        bundleId: 'com.algoriddim.djay-iphone-free',
        appName: 'djay Pro AI',
      ),
      DjSoftware.djayPro,
    );
    expect(
      matchDjApp(bundleId: 'com.algoriddim.djay-pro-mac', appName: 'djay Pro'),
      DjSoftware.djayPro,
    );
    expect(matchDjApp(exeName: 'djay.exe'), DjSoftware.djayPro);
    expect(
      matchDjApp(
        executablePath:
            '/Applications/djay Pro AI.app/Contents/MacOS/djay Pro AI',
      ),
      DjSoftware.djayPro,
    );

    expect(matchDjApp(bundleId: 'pulsedj.com.Pulse-DJ'), isNull);
    expect(matchDjApp(appName: 'Pulse DJ'), isNull);
    expect(matchDjApp(exeName: 'Pulse DJ.exe'), isNull);
    expect(
      matchDjApp(
        executablePath: '/Applications/Pulse DJ.app/Contents/MacOS/Pulse DJ',
      ),
      isNull,
    );
    expect(
      matchDjApp(
        executablePath: r'C:\Program Files\Pulse DJ\Pulse DJ.exe',
      ),
      isNull,
    );
    expect(
      matchDjApp(
        bundleId: 'pulsedj.com.Pulse-DJ',
        appName: 'rekordbox',
        exeName: 'rekordbox.exe',
      ),
      isNull,
    );

    expect(matchDjApp(bundleId: 'com.electron.rekordboxagent'), isNull);
    expect(
      matchDjApp(bundleId: 'com.pioneerdj.rekordboxdj.agent'),
      isNull,
    );
    expect(
      matchDjApp(
        bundleId: 'com.pioneerdj.rekordboxdj.agent',
        exeName: 'rekordbox.exe',
      ),
      isNull,
    );
    expect(matchDjApp(appName: 'rekordboxAgent'), isNull);
    expect(matchDjApp(exeName: 'rekordboxAgent.exe'), isNull);
    expect(
      matchDjApp(
        executablePath:
            '/Applications/rekordbox 6/rekordboxAgent.app/Contents/MacOS/rekordboxAgent',
      ),
      isNull,
    );
    expect(
      matchDjApp(
        executablePath:
            r'C:\Program Files\Pioneer\rekordbox 7\rekordboxAgent.exe',
      ),
      isNull,
    );

    expect(matchDjApp(appName: 'Serato DJ Lite'), isNull);
    expect(matchDjApp(appName: 'Serato Studio'), isNull);
    expect(matchDjApp(bundleId: 'com.serato.seratodjlite'), isNull);
    expect(matchDjApp(appName: 'Traktor Kontrol'), isNull);
    expect(matchDjApp(appName: 'Traktor DJ'), isNull);
    expect(matchDjApp(appName: 'Engine'), isNull);
    expect(matchDjApp(appName: 'Engine DJ OS'), isNull);
    expect(matchDjApp(appName: 'VirtualDJ LE'), isNull);
    expect(matchDjApp(exeName: 'virtualdjle.exe'), isNull);
    expect(matchDjApp(appName: 'Spotify'), isNull);
    expect(matchDjApp(appName: 'Ableton Live'), isNull);
    expect(matchDjApp(bundleId: 'com.apple.Safari'), isNull);
    expect(matchDjApp(), isNull);
  });

  test('Namen und Bundle-IDs überschneiden sich nicht mit der Sperrliste', () {
    final names = <String>{};
    final bundles = <String>{};
    for (final rule in djAppRules) {
      for (final name in rule.names) {
        expect(names.add(name), isTrue, reason: name);
        expect(isDeniedName(name), isFalse, reason: name);
      }
      for (final id in rule.bundleIds) {
        expect(bundles.add(id), isTrue, reason: id);
        expect(isDeniedBundle(id), isFalse, reason: id);
        expect(matchDjApp(bundleId: id), rule.software, reason: id);
      }
    }
    expect(djAppRules.map((rule) => rule.software).toSet(), DjSoftware.values.toSet());
  });

  test('öffnet Sync nur beim Start der DJ-App, nicht als zweites Fenster', () {
    final gate = DjWatchGate();
    expect(
      gate.shouldLaunchSync(djRunning: false, syncRunning: false),
      isFalse,
    );
    expect(
      gate.shouldLaunchSync(djRunning: true, syncRunning: false),
      isTrue,
    );
    expect(
      gate.shouldLaunchSync(djRunning: true, syncRunning: false),
      isFalse,
    );
    expect(
      gate.shouldLaunchSync(djRunning: true, syncRunning: true),
      isFalse,
    );
    expect(
      gate.shouldLaunchSync(djRunning: false, syncRunning: false),
      isFalse,
    );
    expect(
      gate.shouldLaunchSync(djRunning: true, syncRunning: true),
      isFalse,
    );
    expect(
      gate.shouldLaunchSync(djRunning: false, syncRunning: false),
      isFalse,
    );
    expect(
      gate.shouldLaunchSync(djRunning: true, syncRunning: false),
      isTrue,
    );
  });

  test('Wächter-Skript startet nur VibesBox Sync', () async {
    const app = '/Applications/VibesBox Sync.app';
    const exe = '/Applications/VibesBox Sync.app/Contents/MacOS/VibesBox Sync';
    final mac = buildMacWatchScript(
      syncAppPath: app,
      syncExePath: exe,
      statePath: '/Users/a/Library/Application Support/VibesBoxRbTool/dj_watch_state',
    );
    expect(macBundlePath(exe), app);
    expect('open'.allMatches(mac), hasLength(1));
    expect(mac.contains('/usr/bin/open "\$SYNC_APP"'), isTrue);
    expect(mac.contains("SYNC_APP='$app'"), isTrue);
    expect(mac.contains('osascript'), isFalse);
    expect(mac.contains('tell application'), isFalse);
    expect(mac.contains('Pulse DJ.app'), isFalse);
    expect(mac.contains('pulsedj'), isTrue);
    final syntax = await Process.start('/bin/bash', ['-n']);
    syntax.stdin.write(mac);
    await syntax.stdin.close();
    expect(await syntax.exitCode, 0, reason: await syntax.stderr.transform(utf8.decoder).join());
    for (final rule in djAppRules) {
      for (final id in rule.bundleIds) {
        expect(mac.toLowerCase(), contains(id));
      }
    }

    final plist = buildMacLaunchAgentPlist(
      scriptPath: '/Users/a/Library/Application Support/VibesBoxRbTool/dj_watch.sh',
    );
    expect(plist.contains(djWatchLabel), isTrue);
    expect(plist.contains('/bin/bash'), isTrue);
    expect(plist.contains('open'), isFalse);
    expect(plist.contains('Pulse'), isFalse);
    expect(plist.contains('rekordbox'), isFalse);

    const winExe = r'C:\Program Files\VibesBox Sync\VibesBoxSync.exe';
    final ps1 = buildWindowsWatchScript(
      syncExePath: winExe,
      statePath: r'C:\Users\a\AppData\Roaming\VibesBoxRbTool\dj_watch_state',
      pidPath: r'C:\Users\a\AppData\Roaming\VibesBoxRbTool\dj_watch.pid',
    );
    expect('Start-Process'.allMatches(ps1), hasLength(1));
    expect(ps1.contains(r'Start-Process -FilePath $SyncExe'), isTrue);
    expect(ps1.contains("\$SyncExe = '$winExe'"), isTrue);
    expect(ps1.contains('Pulse DJ.app'), isFalse);
    expect(ps1.toLowerCase(), contains('pulse dj'));
    expect(ps1.toLowerCase(), contains('rekordboxagent'));
    for (final rule in djAppRules) {
      for (final name in rule.names) {
        expect(ps1.toLowerCase(), contains("'$name'"));
      }
    }
    final vbs = buildWindowsWatchVbs(ps1Path: r'C:\VibesBox\dj_watch.ps1');
    expect(vbs.contains('dj_watch.ps1'), isTrue);
    expect(vbs.contains('Pulse'), isFalse);
    expect(vbs.contains('rekordbox'), isFalse);
  });

  test('Bash-Matcher erkennt DJ-Apps und weist Pulse DJ ab', () async {
    final helpers = buildMacMatchHelpers();
    final result = await Process.run('/bin/bash', [
      '-c',
      '''
$helpers
check() {
  local label="\$1"
  shift
  if is_dj "\$@"; then
    printf '%s MATCH\\n' "\$label"
  else
    printf '%s NO\\n' "\$label"
  fi
}
app_of() { parse_app "\$1"; }
check RB_ID com.pioneerdj.rekordboxdj "" ""
check RB_PATH "" "\$(app_of "/Applications/rekordbox 7/rekordbox.app/Contents/MacOS/rekordbox")" ""
check SERATO "" "\$(app_of "/Applications/Serato DJ Pro.app/Contents/MacOS/Serato DJ Pro")" ""
check VDJ com.atomixproductions.virtualdj VirtualDJ virtualdj
check TRAKTOR com.native-instruments.Traktor "Traktor Pro 4" Traktor
check MIXXX org.mixxx.mixxx Mixxx mixxx
check ENGINE com.inmusicbrands.enginedj "Engine DJ" "Engine DJ"
check DJAY com.algoriddim.djay-iphone-free "djay Pro AI" djay
check PULSE pulsedj.com.Pulse-DJ "Pulse DJ" "Pulse DJ"
check PULSE_PATH "" "\$(app_of "/Applications/Pulse DJ.app/Contents/MacOS/Pulse DJ")" ""
check AGENT com.pioneerdj.rekordboxdj.agent rekordbox rekordbox
check AGENT_APP "" "\$(app_of "/Applications/rekordbox 6/rekordboxAgent.app/Contents/MacOS/rekordboxAgent")" ""
check LITE "" "Serato DJ Lite" ""
check STUDIO "" "Serato Studio" ""
check SPOT "" Spotify Spotify
check ENGINE_OS "" "Engine DJ OS" ""
''',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final lines = result.stdout.toString().trim().split('\n');
    expect(lines, [
      'RB_ID MATCH',
      'RB_PATH MATCH',
      'SERATO MATCH',
      'VDJ MATCH',
      'TRAKTOR MATCH',
      'MIXXX MATCH',
      'ENGINE MATCH',
      'DJAY MATCH',
      'PULSE NO',
      'PULSE_PATH NO',
      'AGENT NO',
      'AGENT_APP NO',
      'LITE NO',
      'STUDIO NO',
      'SPOT NO',
      'ENGINE_OS NO',
    ]);
  });

  test('Mit der DJ-Software starten ist standardmäßig an', () {
    expect(readLaunchWithDjFlag(null), isTrue);
    expect(readLaunchWithDjFlag(<String, dynamic>{}), isTrue);
    expect(readLaunchWithDjFlag({'launchWithDj': true}), isTrue);
    expect(readLaunchWithDjFlag({'launchWithDj': false}), isFalse);
  });
}
