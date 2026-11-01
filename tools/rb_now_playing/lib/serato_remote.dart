import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'serato_osc.dart';
import 'serato_play_gate.dart';

const _peerName = 'VibesBoxSync';

const _topics = <String>[
  '/Register/Status/Deck/Playhead',
  '/Register/Status/Deck/Song/Title',
  '/Register/Status/Deck/Song/Artist',
  '/Register/Status/Deck/Song/Filepath',
];

/// Nimmt Seratos Verbindung an und hält Geschwindigkeit und Titel der Decks.
class SeratoRemoteMonitor {
  SeratoRemoteMonitor({this.advertise = true});

  final bool advertise;

  ServerSocket? _server;
  Process? _dns;
  _SeratoMdns? _mdns;
  final _sockets = <Socket>{};
  final _subscribed = <Socket>{};
  final _decks = <int, SeratoDeckLive>{};
  var _gen = 0;
  var _armed = false;
  var _paired = false;
  var _advertiseFailed = false;
  DateTime? _advertisingSince;
  DateTime? _lastStatusAt;
  late final String _peerUuid = _uuid();

  bool get paired => _paired;
  bool get advertiseFailed => _advertiseFailed;
  DateTime? get advertisingSince => _advertisingSince;
  DateTime? get lastStatusAt => _lastStatusAt;
  int? get port => _server?.port;

  bool holdsHistoryAt(DateTime now) {
    return seratoHoldsHistory(
      armed: _armed,
      paired: _paired,
      advertiseFailed: _advertiseFailed,
      advertisingSince: _advertisingSince,
      lastStatusAt: _lastStatusAt,
      now: now,
    );
  }

  List<SeratoDeckLive> get decks =>
      _decks.values.map((deck) => deck.copy()).toList();

  void arm() {
    _armed = true;
    _advertiseFailed = false;
  }

  Future<void> ensureStarted() async {
    if (_server != null) return;
    final gen = ++_gen;
    arm();
    ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (error) {
      debugPrint('Serato Remote: $error');
      if (gen == _gen) _advertiseFailed = true;
      return;
    }
    if (gen != _gen) {
      await server.close();
      return;
    }
    _server = server;
    _advertisingSince = DateTime.now();
    server.listen(_onSocket, onError: (Object _) {});
    if (!advertise) return;
    final ok = await _advertise(server.port, gen);
    if (gen != _gen) return;
    if (!ok) _advertiseFailed = true;
  }

  void stop() {
    _gen++;
    _armed = false;
    _paired = false;
    _advertiseFailed = false;
    _advertisingSince = null;
    _lastStatusAt = null;
    _decks.clear();
    _subscribed.clear();
    final dns = _dns;
    _dns = null;
    dns?.kill();
    final mdns = _mdns;
    _mdns = null;
    mdns?.close();
    for (final socket in _sockets.toList()) {
      _sockets.remove(socket);
      socket.destroy();
    }
    final server = _server;
    _server = null;
    server?.close();
  }

  Future<bool> _advertise(int port, int gen) async {
    final host = _hostLabel();
    final instance = '$_peerName @ $host';
    final bin = _dnsSdPath();
    if (bin != null) {
      try {
        final proc = await Process.start(bin, [
          '-R',
          instance,
          '_SeratoIOSRemote._tcp',
          'local',
          '$port',
        ]);
        if (gen != _gen) {
          proc.kill();
          return false;
        }
        _dns = proc;
        unawaited(proc.stdout.drain<void>());
        unawaited(proc.stderr.drain<void>());
        unawaited(
          proc.exitCode.then((_) {
            if (_dns == proc) _dns = null;
          }),
        );
        return true;
      } catch (error) {
        debugPrint('Serato Remote dns-sd: $error');
      }
    }
    try {
      final mdns = _SeratoMdns(port: port, instance: instance, host: host);
      await mdns.start();
      if (gen != _gen) {
        mdns.close();
        return false;
      }
      _mdns = mdns;
      return true;
    } catch (error) {
      debugPrint('Serato Remote mDNS: $error');
      return false;
    }
  }

  void _onSocket(Socket socket) {
    _sockets.add(socket);
    socket.setOption(SocketOption.tcpNoDelay, true);
    final reader = SeratoFrameReader();
    socket.listen(
      (chunk) {
        List<OscMessage> messages;
        try {
          messages = reader.push(chunk);
        } catch (_) {
          return;
        }
        for (final message in messages) {
          _dispatch(socket, message);
        }
      },
      onError: (Object _) {},
      onDone: () {
        _sockets.remove(socket);
        _subscribed.remove(socket);
        if (_sockets.isEmpty) _paired = false;
      },
    );
  }

  void _dispatch(Socket socket, OscMessage message) {
    final address = message.address;
    if (address == '/Ping') {
      socket.add(frameOsc(const OscMessage('/Ping')));
      return;
    }
    if (address == '/StreamMgmt/Authorize/Request') {
      List<int>? nonce;
      for (final arg in message.args) {
        if (arg.type == 'b') {
          nonce = arg.blob;
          break;
        }
      }
      if (nonce == null || nonce.isEmpty) return;
      socket.add(
        frameOsc(
          OscMessage('/StreamMgmt/Authorize/Response', [
            OscArg.s(_peerName),
            OscArg.s(_peerUuid),
            OscArg.b(seratoAuthDigest(nonce)),
          ]),
        ),
      );
      return;
    }
    if (address == '/StreamMgmt/Pairing/Pair' ||
        address == '/StreamMgmt/Pairing/StatusChanged') {
      if (address == '/StreamMgmt/Pairing/Pair') {
        socket.add(
          frameOsc(
            OscMessage('/StreamMgmt/Pairing/Pair', [
              OscArg.s(_peerName),
              OscArg.s(_peerUuid),
              OscArg.i(1),
            ]),
          ),
        );
        _paired = true;
      }
      if (_subscribed.add(socket)) {
        for (final topic in _topics) {
          socket.add(frameOsc(OscMessage(topic)));
        }
      }
      return;
    }
    if (address.startsWith('/Status/')) {
      _lastStatusAt = DateTime.now();
      _paired = true;
      _applyStatus(message);
    }
  }

  void _applyStatus(OscMessage message) {
    final deckIndex = _intArg(message.args, 0);
    if (deckIndex == null) return;
    final deck = _decks.putIfAbsent(deckIndex, () => SeratoDeckLive(deckIndex));
    switch (message.address) {
      case '/Status/Deck/Song/Title':
        deck.title = _stringArg(message.args, 1) ?? '';
      case '/Status/Deck/Song/Artist':
        deck.artist = _stringArg(message.args, 1) ?? '';
      case '/Status/Deck/Song/Filepath':
        _fillFromPath(deck, _stringArg(message.args, 1) ?? '');
      case '/Status/Deck/Playhead':
        final position = _floatArg(message.args, 1);
        final rate = _floatArg(message.args, 2);
        final bpm = _floatArg(message.args, 3);
        if (position == null || rate == null || bpm == null) return;
        deck.positionSeconds = position;
        deck.playRate = rate;
        deck.bpm = bpm;
      case '/Status/Deck/Song/Valid':
        final valid = _floatArg(message.args, 1);
        if (valid != null && valid < 0.5) {
          deck.title = '';
          deck.artist = '';
          deck.playRate = 0;
        }
    }
  }

  void _fillFromPath(SeratoDeckLive deck, String path) {
    if (path.isEmpty || deck.title.trim().isNotEmpty) return;
    var name = path.split(RegExp(r'[/\\]')).last.trim();
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    final parts = name.split(' - ');
    if (parts.length >= 2) {
      if (deck.artist.trim().isEmpty) deck.artist = parts.first.trim();
      deck.title = parts.sublist(1).join(' - ').trim();
    } else if (name.isNotEmpty) {
      deck.title = name;
    }
  }
}

int? _intArg(List<OscArg> args, int index) {
  if (index >= args.length) return null;
  final arg = args[index];
  if (arg.type == 'i') return arg.intValue;
  if (arg.type == 'f') return arg.floatValue.round();
  return null;
}

double? _floatArg(List<OscArg> args, int index) {
  if (index >= args.length) return null;
  final arg = args[index];
  if (arg.type == 'f') return arg.floatValue;
  if (arg.type == 'i') return arg.intValue.toDouble();
  return null;
}

String? _stringArg(List<OscArg> args, int index) {
  if (index >= args.length) return null;
  final arg = args[index];
  return arg.type == 's' ? arg.stringValue : null;
}

String _hostLabel() {
  var host = Platform.localHostname.replaceAll('.local', '');
  if (host.contains('.')) host = host.split('.').first;
  host = host.trim();
  return host.isEmpty ? 'VibesBox' : host;
}

String? _dnsSdPath() {
  if (Platform.isMacOS) return '/usr/bin/dns-sd';
  if (Platform.isWindows) {
    final roots = [
      Platform.environment['ProgramFiles'],
      Platform.environment['ProgramFiles(x86)'],
    ];
    for (final root in roots) {
      if (root == null || root.isEmpty) continue;
      final file = File('$root\\Bonjour\\dns-sd.exe');
      if (file.existsSync()) return file.path;
    }
  }
  return null;
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
  return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
      '${hex(4)}${hex(5)}-'
      '${hex(6)}${hex(7)}-'
      '${hex(8)}${hex(9)}-'
      '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
}

class _SeratoMdns {
  _SeratoMdns({required this.port, required this.instance, required this.host});

  final int port;
  final String instance;
  final String host;
  RawDatagramSocket? _socket;
  Timer? _timer;
  InternetAddress? _ip;

  Future<void> start() async {
    _ip = await _localIp();
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      5353,
      reuseAddress: true,
      reusePort: true,
    );
    _socket = socket;
    socket.broadcastEnabled = true;
    socket.joinMulticast(InternetAddress('224.0.0.251'));
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = socket.receive();
      if (packet == null) return;
      if (!_wantsUs(packet.data)) return;
      final response = _response(id: (packet.data[0] << 8) | packet.data[1]);
      socket.send(response, packet.address, packet.port);
      socket.send(response, InternetAddress('224.0.0.251'), 5353);
    });
    _announce();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _announce());
  }

  void close() {
    _timer?.cancel();
    _timer = null;
    final socket = _socket;
    _socket = null;
    socket?.close();
  }

  void _announce() {
    final socket = _socket;
    if (socket == null) return;
    socket.send(_response(id: 0), InternetAddress('224.0.0.251'), 5353);
  }

  bool _wantsUs(Uint8List data) {
    if (data.length < 12) return false;
    final flags = (data[2] << 8) | data[3];
    if ((flags & 0x8000) != 0) return false;
    final text = utf8.decode(data, allowMalformed: true).toLowerCase();
    return text.contains('seratoiosremote');
  }

  Uint8List _response({required int id}) {
    final service = _name('_SeratoIOSRemote._tcp.local');
    final instanceName = _name('$instance._SeratoIOSRemote._tcp.local');
    final hostName = _name('$host.local');
    final ptr = _record(
      service,
      12,
      _name('$instance._SeratoIOSRemote._tcp.local'),
    );
    final srv = _record(instanceName, 33, _srv());
    final txt = _record(instanceName, 16, Uint8List.fromList(const [0]));
    final a = _record(hostName, 1, Uint8List.fromList(_ip!.rawAddress));
    final answers = <int>[...ptr, ...srv, ...txt, ...a];
    final header = ByteData(12);
    header.setUint16(0, id);
    header.setUint16(2, 0x8400);
    header.setUint16(4, 0);
    header.setUint16(6, 4);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...answers]);
  }

  Uint8List _srv() {
    final target = _name('$host.local');
    final out = Uint8List(6 + target.length);
    final view = ByteData.sublistView(out);
    view.setUint16(0, 0);
    view.setUint16(2, 0);
    view.setUint16(4, port);
    out.setRange(6, out.length, target);
    return out;
  }

  Uint8List _record(Uint8List name, int type, Uint8List rdata) {
    final out = Uint8List(name.length + 10 + rdata.length);
    out.setRange(0, name.length, name);
    final view = ByteData.sublistView(out);
    var at = name.length;
    view.setUint16(at, type);
    view.setUint16(at + 2, 0x8001);
    view.setUint32(at + 4, 120);
    view.setUint16(at + 8, rdata.length);
    out.setRange(at + 10, out.length, rdata);
    return out;
  }
}

Uint8List _name(String dotted) {
  final out = <int>[];
  for (final label in dotted.split('.')) {
    final bytes = utf8.encode(label);
    out.add(bytes.length);
    out.addAll(bytes);
  }
  out.add(0);
  return Uint8List.fromList(out);
}

Future<InternetAddress> _localIp() async {
  try {
    final ifaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr;
      }
    }
  } catch (_) {}
  return InternetAddress.loopbackIPv4;
}
