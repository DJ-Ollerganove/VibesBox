import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _iosStableDeviceIdStorageKey = 'ios_stable_device_id_v1';
const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

Future<String> getStableIosDeviceId({
  String? mirrorPrefsKey,
  String fallback = 'device_unknown',
}) async {
  if (kIsWeb) return fallback;

  final prefs = await SharedPreferences.getInstance();
  final mirrored = mirrorPrefsKey == null
      ? ''
      : (prefs.getString(mirrorPrefsKey) ?? '').trim();

  final fromKeychain =
      (await _secureStorage.read(key: _iosStableDeviceIdStorageKey) ?? '').trim();
  if (fromKeychain.isNotEmpty && fromKeychain != fallback) {
    if (mirrorPrefsKey != null && mirrored != fromKeychain) {
      await prefs.setString(mirrorPrefsKey, fromKeychain);
    }
    return fromKeychain;
  }

  String resolved = '';
  if (mirrored.isNotEmpty && mirrored != fallback) {
    resolved = mirrored;
  } else {
    final info = await DeviceInfoPlugin().iosInfo;
    resolved = (info.identifierForVendor ?? '').trim();
  }

  if (resolved.isEmpty || resolved == fallback) {
    resolved = 'ios_local_${_randomHex(16)}';
  }

  await _secureStorage.write(key: _iosStableDeviceIdStorageKey, value: resolved);
  if (mirrorPrefsKey != null) {
    await prefs.setString(mirrorPrefsKey, resolved);
  }
  return resolved;
}

String _randomHex(int bytes) {
  final random = Random.secure();
  final values = List<int>.generate(bytes, (_) => random.nextInt(256));
  final buffer = StringBuffer();
  for (final v in values) {
    buffer.write(v.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
