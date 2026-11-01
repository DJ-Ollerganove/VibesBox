import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rb_now_playing/dj_library_prefs.dart';
import 'package:rb_now_playing/rekordbox_history.dart';
import 'package:rb_now_playing/rekordbox_live.dart';
import 'package:rb_now_playing/serato_osc.dart';
import 'package:rb_now_playing/serato_play_gate.dart';
import 'package:rb_now_playing/serato_remote.dart';

void main() {
  test('Ping-Rahmen entspricht dem Serato-Mitschnitt', () {
    final frame = frameOsc(const OscMessage('/Ping'));
    expect(frame, [
      0x2f,
      0x50,
      0x69,
      0x6e,
      0x67,
      0x00,
      0x00,
      0x00,
      0x2c,
      0x00,
      0x00,
      0x00,
      0x4c,
      0xaa,
      0xc2,
      0xae,
      0x35,
      0xb1,
      0xc4,
      0x76,
      0xdb,
      0x5a,
      0x64,
      0x44,
      0x03,
      0xbd,
      0x41,
      0x70,
    ]);
  });

  test('Antwort auf die Anmeldung trägt den Digest', () async {
    final monitor = SeratoRemoteMonitor(advertise: false);
    await monitor.ensureStarted();
    final socket = await Socket.connect('127.0.0.1', monitor.port!);
    addTearDown(() {
      socket.destroy();
      monitor.stop();
    });
    const nonce = <int>[
      0xe8,
      0x05,
      0x4e,
      0x4b,
      0x49,
      0xeb,
      0x45,
      0x6f,
      0x29,
      0xe5,
      0xec,
      0xde,
      0xa5,
      0xc7,
      0xc0,
      0xad,
    ];
    final reader = SeratoFrameReader();
    final messages = <OscMessage>[];
    socket.listen((chunk) => messages.addAll(reader.push(chunk)));
    socket.add(
      frameOsc(
        OscMessage('/StreamMgmt/Authorize/Request', [
          OscArg.b(nonce),
          OscArg.i(1),
          OscArg.i(1),
        ]),
      ),
    );
    await _until(() => messages.any((m) => m.address.endsWith('/Response')));
    expect(messages.single.address, '/StreamMgmt/Authorize/Response');
    expect(messages.single.args[2].blob, seratoAuthDigest(nonce));

    socket.add(
      frameOsc(
        OscMessage('/StreamMgmt/Pairing/Pair', [
          OscArg.s('SDJ'),
          OscArg.s('uuid'),
          OscArg.i(0),
        ]),
      ),
    );
    await _until(
      () => messages.any((m) => m.address == '/Register/Status/Deck/Playhead'),
    );
    expect(
      messages.map((m) => m.address),
      containsAll([
        '/StreamMgmt/Pairing/Pair',
        '/Register/Status/Deck/Playhead',
      ]),
    );
    expect(monitor.paired, isTrue);
  });

  test('Auflegen bleibt stumm, Play zählt erst nach der Wartezeit', () {
    final clock = SeratoPlayClock();
    final now = DateTime.utc(2026, 10, 24, 20, 13);
    final history = HistorySnapshot(
      dbPath: 'db',
      historyName: 'session',
      tracks: [
        HistoryTrack(
          trackNo: 1,
          title: 'My Heart Will Go On',
          artist: 'Celine Dion',
          playedAt: now.subtract(const Duration(minutes: 5)),
          historyName: 'session',
          bpm: 99,
          musicalKey: '8A',
          length: const Duration(minutes: 4),
        ),
      ],
      readAt: now,
    );
    final snap = LiveSnapshot(history: history, readAt: now);
    final deck = SeratoDeckLive(0)
      ..title = 'My Heart Will Go On'
      ..artist = 'Celine Dion'
      ..playRate = 0;

    final loaded = clock.apply(
      snapshot: snap,
      holdsHistory: true,
      decks: [deck],
      delaySeconds: 10,
      now: now,
    );
    expect(loaded.idle, isTrue);

    deck.playRate = 1;
    final started = clock.apply(
      snapshot: snap,
      holdsHistory: true,
      decks: [deck],
      delaySeconds: 10,
      now: now,
    );
    expect(started.idle, isTrue);
    final early = clock.apply(
      snapshot: snap,
      holdsHistory: true,
      decks: [deck],
      delaySeconds: 10,
      now: now.add(const Duration(seconds: 9)),
    );
    expect(early.idle, isTrue);

    final ready = clock.apply(
      snapshot: snap,
      holdsHistory: true,
      decks: [deck],
      delaySeconds: 10,
      now: now.add(const Duration(seconds: 10)),
    );
    expect(ready.idle, isFalse);
    expect(ready.nowPlaying?.title, 'My Heart Will Go On');
    expect(ready.nowPlaying?.bpm, 99);
    expect(ready.nowPlaying?.musicalKey, '8A');

    deck.playRate = 0;
    final paused = clock.apply(
      snapshot: snap,
      holdsHistory: true,
      decks: [deck],
      delaySeconds: 10,
      now: now.add(const Duration(seconds: 15)),
    );
    expect(paused.idle, isTrue);

    deck.playRate = 1;
    final again = clock.apply(
      snapshot: snap,
      holdsHistory: true,
      decks: [deck],
      delaySeconds: 10,
      now: now.add(const Duration(seconds: 16)),
    );
    expect(again.idle, isTrue);
  });

  test('ohne Live-Status gilt die History', () {
    final now = DateTime.utc(2026, 10, 24, 20);
    expect(
      seratoHoldsHistory(
        armed: true,
        paired: false,
        advertiseFailed: false,
        advertisingSince: now,
        lastStatusAt: null,
        now: now.add(const Duration(seconds: 11)),
      ),
      isTrue,
    );
    expect(
      seratoHoldsHistory(
        armed: true,
        paired: false,
        advertiseFailed: false,
        advertisingSince: now,
        lastStatusAt: null,
        now: now.add(const Duration(seconds: 12)),
      ),
      isFalse,
    );
    expect(
      seratoHoldsHistory(
        armed: true,
        paired: true,
        advertiseFailed: false,
        advertisingSince: now,
        lastStatusAt: null,
        now: now.add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
    expect(clampSeratoPlayDelay(90), 60);
    expect(clampSeratoPlayDelay(-3), 0);
    expect(clampSeratoPlayDelay('15'), 15);
  });
}

Future<void> _until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Serato-Antwort blieb aus');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
