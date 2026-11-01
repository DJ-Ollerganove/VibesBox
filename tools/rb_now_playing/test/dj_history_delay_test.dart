import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rb_now_playing/dj_history_delay.dart';
import 'package:rb_now_playing/dj_library_prefs.dart';

void main() {
  test('Rekordbox playedTime bleibt der Rest der Datei', () {
    const xml =
        '<PROPERTIES>\r\n'
        '  <VALUE name="playedTime" val="1"/>\r\n'
        '  <VALUE name="other" val="9"/>\r\n'
        '</PROPERTIES>\r\n';
    expect(readRekordboxPlayedTime(xml), 1);
    final next = writeRekordboxPlayedTime(xml, 25)!;
    expect(next.contains('\r\n'), isTrue);
    expect(next, contains('val="25"'));
    expect(next, contains('<VALUE name="other" val="9"/>'));
    expect(writeRekordboxPlayedTime(xml, 0), contains('val="1"'));
    expect(writeRekordboxPlayedTime(xml, 1), xml);
  });

  test('Virtual DJ historyDelay ändert nur die Sekunden', () {
    const xml =
        '<settings>\n'
        '\t<historyDelay modified="yes">5</historyDelay>\n'
        '\t<writeHistory>yes</writeHistory>\n'
        '</settings>\n';
    expect(readVirtualDjHistoryDelay(xml), 5);
    final next = writeVirtualDjHistoryDelay(xml, 12)!;
    expect(next, contains('<historyDelay modified="yes">12</historyDelay>'));
    expect(next, contains('<writeHistory>yes</writeHistory>'));
    expect(writeVirtualDjHistoryDelay(xml, 99), contains('>60</historyDelay>'));
  });

  test('fehlendes Feld wird ergänzt', () {
    const rb = '<PROPERTIES>\n</PROPERTIES>\n';
    expect(
      writeRekordboxPlayedTime(rb, 8),
      contains('<VALUE name="playedTime" val="8"/>'),
    );
    const vdj = '<settings>\n</settings>\n';
    expect(
      writeVirtualDjHistoryDelay(vdj, 0),
      contains('<historyDelay modified="yes">0</historyDelay>'),
    );
  });

  test('OSC-Adresse setzt historyDelay direkt', () {
    final packet = oscVirtualDjHistoryDelay(12);
    expect(
      String.fromCharCodes(packet.take(28)),
      '/vdj/setting/historyDelay/12',
    );
    expect(packet[28], 0);
  });

  test('schreibt die History-Zeit sofort und sichert sie ohne Sync', () async {
    final dir = await Directory.systemTemp.createTemp('vb-history-delay');
    final armed = <List<Object?>>[];
    addTearDown(() async {
      DjHistoryDelay.resetRuntime();
      await dir.delete(recursive: true);
    });
    final file = File('${dir.path}/rekordbox3.settings');
    await file.writeAsString(
      '<PROPERTIES>\n  <VALUE name="playedTime" val="1"/>\n</PROPERTIES>\n',
    );
    DjHistoryDelay.rekordboxFilesForTest = () => [file];
    DjHistoryDelay.virtualDjFilesForTest = () => [];
    DjHistoryDelay.armForTest = (software, seconds, pid, paths) {
      armed.add([software, seconds, pid, paths]);
    };
    DjHistoryDelay.pidsForTest = (_) async => [42];
    final prefs = _MemPrefs()
      ..rekordboxHistoryDelaySec = 20
      ..rekordboxHistoryDelayPending = true;
    DjHistoryDelay.isRunning = (_) async => true;
    await DjHistoryDelay.applyPending(prefs);
    expect(prefs.rekordboxHistoryDelayPending, isTrue);
    expect(file.readAsStringSync(), contains('val="20"'));
    expect(armed, [
      [
        DjSoftware.rekordbox,
        20,
        42,
        [file.path],
      ],
    ]);

    await DjHistoryDelay.applyPending(prefs);
    expect(armed, hasLength(1));

    DjHistoryDelay.isRunning = (_) async => false;
    await DjHistoryDelay.applyPending(prefs);
    expect(prefs.rekordboxHistoryDelayPending, isFalse);
    expect(file.readAsStringSync(), contains('val="20"'));
  });

  test('Helfer schreibt die Zeit nach dem Beenden noch einmal', () async {
    final dir = await Directory.systemTemp.createTemp('vb-history-delay-py');
    addTearDown(() async {
      await dir.delete(recursive: true);
    });
    final file = File('${dir.path}/settings.xml');
    await file.writeAsString(
      '<settings>\n\t<historyDelay modified="yes">5</historyDelay>\n</settings>\n',
    );
    final cmd = File('${dir.path}/delay.cmd');
    await cmd.writeAsString(
      'pid=1\nseconds=12\nkind=virtualdj\nfile=${file.path}\n',
    );
    final py = File('${dir.path}/helper.py');
    await py.writeAsString(historyDelayHelperPy);
    final result = await Process.run('python3', [py.path, cmd.path]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      file.readAsStringSync(),
      contains('<historyDelay modified="yes">12</historyDelay>'),
    );
  });
}

class _MemPrefs extends DjLibraryPrefs {
  @override
  Future<void> save() async {}
}
