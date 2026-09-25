import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'tool_i18n.dart';

/// Entpackt denselben SQLCipher-Schlüssel, den pyrekordbox für Rekordbox 6/7 nutzt.
/// Das ist der app-weite Library-Key, nicht ein Nutzerpasswort.
String rekordboxSqlCipherKey() {
  const blob =
      r"PN_Pq^*N>(JYe*u^8;Yg76HuZ<mR13S?=>)b9;DpoTXV(6ItkU`}8*m6tx_I{Solh_N#dfe{v=";
  const xorAscii = '657f48f84c437cc1';
  final decoded = _b85decode(utf8.encode(blob));
  final xorKey = utf8.encode(xorAscii);
  final xored = Uint8List(decoded.length);
  for (var i = 0; i < decoded.length; i++) {
    xored[i] = decoded[i] ^ xorKey[i % xorKey.length];
  }
  final key = utf8.decode(ZLibDecoder().convert(xored));
  if (!key.startsWith('402fd') || key.length != 64) {
    throw StateError(toolI18n.text('errRbOpen'));
  }
  return key;
}

/// RFC-1924 / Python `base64.b85decode`.
Uint8List _b85decode(List<int> source) {
  const alphabet =
      r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~';
  final map = List<int>.filled(256, -1);
  for (var i = 0; i < alphabet.length; i++) {
    map[alphabet.codeUnitAt(i)] = i;
  }

  final input = source.where((c) => c != 32 && c != 10 && c != 13 && c != 9).toList();
  final padding = (-input.length) % 5;
  if (padding != 0) {
    input.addAll(List<int>.filled(padding, 0x7e)); // '~'
  }

  final out = BytesBuilder(copy: false);
  for (var i = 0; i < input.length; i += 5) {
    var acc = 0;
    for (var j = 0; j < 5; j++) {
      final v = map[input[i + j]];
      if (v < 0) {
        throw FormatException('Ungültiges Base85-Zeichen', input, i + j);
      }
      acc = acc * 85 + v;
    }
    out.add([
      (acc >> 24) & 0xff,
      (acc >> 16) & 0xff,
      (acc >> 8) & 0xff,
      acc & 0xff,
    ]);
  }
  final bytes = out.takeBytes();
  if (padding == 0) return bytes;
  return Uint8List.fromList(bytes.sublist(0, bytes.length - padding));
}
