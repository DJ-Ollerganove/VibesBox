import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'ios_stable_device_id.dart';

const String _prefsDeviceIdKey = 'vibesbox_stable_device_id_v1';

/// Stabile Geräte-ID für DJ-Sperren (Sortieren, Erkennung, …).
Future<String> getStableDeviceId() async {
  if (kIsWeb) return 'web_${const Uuid().v4()}';

  final prefs = await SharedPreferences.getInstance();
  final cached = (prefs.getString(_prefsDeviceIdKey) ?? '').trim();
  if (cached.isNotEmpty) return cached;

  String resolved = '';
  try {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      resolved = androidInfo.id.trim();
      if (resolved.isEmpty) {
        resolved = androidInfo.fingerprint.trim();
      }
    } else if (Platform.isIOS) {
      resolved = await getStableIosDeviceId(mirrorPrefsKey: _prefsDeviceIdKey);
    }
  } catch (_) {
    resolved = '';
  }

  if (resolved.isEmpty) {
    resolved = 'vb_${const Uuid().v4()}';
  }

  await prefs.setString(_prefsDeviceIdKey, resolved);
  return resolved;
}
