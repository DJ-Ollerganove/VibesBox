import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 16 Byte, die Serato hinter jedes OSC-Paket setzt.
const seratoFrameSentinel = <int>[
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
];

/// Eines der beiden Geheimnisse aus Serato DJ Pro. Beide öffnen den Status.
const seratoRemoteSecret = <int>[
  0xd2,
  0x5d,
  0xb2,
  0x61,
  0xa4,
  0x41,
  0x1b,
  0xc1,
  0xf3,
  0x78,
  0x8f,
  0x57,
  0x72,
  0x3b,
  0x89,
  0x77,
  0xc5,
  0x41,
  0xa4,
  0xb6,
  0x19,
  0xb9,
  0x4a,
  0x9a,
  0x8b,
  0x45,
  0xc4,
  0x6f,
  0x85,
  0x11,
  0xc2,
  0xf8,
];

class OscArg {
  OscArg.i(this.intValue)
    : type = 'i',
      floatValue = 0,
      stringValue = '',
      blob = const [];

  OscArg.f(this.floatValue)
    : type = 'f',
      intValue = 0,
      stringValue = '',
      blob = const [];

  OscArg.s(this.stringValue)
    : type = 's',
      intValue = 0,
      floatValue = 0,
      blob = const [];

  OscArg.b(List<int> bytes)
    : type = 'b',
      intValue = 0,
      floatValue = 0,
      stringValue = '',
      blob = List<int>.unmodifiable(bytes);

  final String type;
  final int intValue;
  final double floatValue;
  final String stringValue;
  final List<int> blob;
}

class OscMessage {
  const OscMessage(this.address, [this.args = const []]);

  final String address;
  final List<OscArg> args;
}

int _pad4(int n) => (n + 3) & ~3;

Uint8List _oscString(String value) {
  final raw = utf8.encode(value);
  final out = Uint8List(_pad4(raw.length + 1));
  out.setRange(0, raw.length, raw);
  return out;
}

Uint8List encodeOsc(OscMessage message) {
  final parts = <Uint8List>[
    _oscString(message.address),
    _oscString(',${message.args.map((a) => a.type).join()}'),
  ];
  for (final arg in message.args) {
    switch (arg.type) {
      case 'i':
        parts.add(_be32(arg.intValue));
      case 'f':
        final b = ByteData(4);
        b.setFloat32(0, arg.floatValue, Endian.big);
        parts.add(b.buffer.asUint8List());
      case 's':
        parts.add(_oscString(arg.stringValue));
      case 'b':
        final data = Uint8List(_pad4(arg.blob.length));
        data.setRange(0, arg.blob.length, arg.blob);
        parts.add(_beU32(arg.blob.length));
        parts.add(data);
    }
  }
  var n = 0;
  for (final part in parts) {
    n += part.length;
  }
  final out = Uint8List(n);
  var at = 0;
  for (final part in parts) {
    out.setRange(at, at + part.length, part);
    at += part.length;
  }
  return out;
}

Uint8List frameOsc(OscMessage message) {
  final body = encodeOsc(message);
  final out = Uint8List(body.length + seratoFrameSentinel.length);
  out.setRange(0, body.length, body);
  out.setRange(body.length, out.length, seratoFrameSentinel);
  return out;
}

Uint8List _be32(int value) {
  final b = ByteData(4);
  b.setInt32(0, value, Endian.big);
  return b.buffer.asUint8List();
}

Uint8List _beU32(int value) {
  final b = ByteData(4);
  b.setUint32(0, value, Endian.big);
  return b.buffer.asUint8List();
}

List<int> seratoAuthDigest(List<int> nonce) {
  return md5.convert(<int>[...nonce, ...seratoRemoteSecret]).bytes;
}

class SeratoFrameReader {
  var _buf = Uint8List(0);

  List<OscMessage> push(List<int> chunk) {
    final next = Uint8List(_buf.length + chunk.length);
    next.setRange(0, _buf.length, _buf);
    next.setRange(_buf.length, next.length, chunk);
    _buf = next;
    final messages = <OscMessage>[];
    var start = 0;
    while (true) {
      final at = _indexOf(_buf, seratoFrameSentinel, start);
      if (at < 0) {
        if (start > 0) _buf = Uint8List.sublistView(_buf, start);
        return messages;
      }
      if (at > start) {
        messages.addAll(
          decodeOscPacket(Uint8List.sublistView(_buf, start, at)),
        );
      }
      start = at + seratoFrameSentinel.length;
      if (start >= _buf.length) {
        _buf = Uint8List(0);
        return messages;
      }
    }
  }
}

int _indexOf(Uint8List data, List<int> needle, int start) {
  final last = data.length - needle.length;
  for (var i = start; i <= last; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (data[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

List<OscMessage> decodeOscPacket(List<int> raw) {
  final buf = raw is Uint8List ? raw : Uint8List.fromList(raw);
  if (buf.length >= 8 &&
      utf8.decode(buf.sublist(0, 7), allowMalformed: true) == '#bundle') {
    final messages = <OscMessage>[];
    var cursor = 16;
    final view = ByteData.sublistView(buf);
    while (cursor + 4 <= buf.length) {
      final size = view.getUint32(cursor, Endian.big);
      cursor += 4;
      if (size == 0) continue;
      if (cursor + size > buf.length) break;
      messages.addAll(decodeOscPacket(buf.sublist(cursor, cursor + size)));
      cursor += size;
    }
    return messages;
  }
  final one = _decodeOne(buf);
  return one == null ? const [] : [one];
}

OscMessage? _decodeOne(Uint8List buf) {
  final address = _readString(buf, 0);
  if (address == null) return null;
  if (address.next >= buf.length) return OscMessage(address.value);
  final tags = _readString(buf, address.next);
  if (tags == null || tags.value.isEmpty) return OscMessage(address.value);
  if (!tags.value.startsWith(',')) return null;
  final args = <OscArg>[];
  var cursor = tags.next;
  final view = ByteData.sublistView(buf);
  for (final tag in tags.value.substring(1).split('')) {
    switch (tag) {
      case 'i':
        if (cursor + 4 > buf.length) return null;
        args.add(OscArg.i(view.getInt32(cursor, Endian.big)));
        cursor += 4;
      case 'f':
        if (cursor + 4 > buf.length) return null;
        args.add(OscArg.f(view.getFloat32(cursor, Endian.big)));
        cursor += 4;
      case 's':
        final text = _readString(buf, cursor);
        if (text == null) return null;
        args.add(OscArg.s(text.value));
        cursor = text.next;
      case 'b':
        if (cursor + 4 > buf.length) return null;
        final n = view.getUint32(cursor, Endian.big);
        cursor += 4;
        if (cursor + n > buf.length) return null;
        args.add(OscArg.b(buf.sublist(cursor, cursor + n)));
        cursor += _pad4(n);
      default:
        return null;
    }
  }
  return OscMessage(address.value, args);
}

class _ReadString {
  const _ReadString(this.value, this.next);
  final String value;
  final int next;
}

_ReadString? _readString(Uint8List buf, int offset) {
  var end = offset;
  while (end < buf.length && buf[end] != 0) {
    end++;
  }
  if (end >= buf.length) return null;
  final value = utf8.decode(buf.sublist(offset, end), allowMalformed: true);
  return _ReadString(value, offset + _pad4(end - offset + 1));
}
