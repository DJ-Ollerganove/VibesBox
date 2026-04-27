import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_log.dart';

/// Account-übergreifende Sperr-Fusion: [blocked_devices] → nach Login [users] via Cloud Function.
class DeviceBlockFusionService {
  DeviceBlockFusionService._();

  static const String _region = 'us-central1';

  /// Gleiche clientId-Logik wie Wunschbox ([app_<sanitized>] aus Geräte-ID / Prefs).
  static Future<String> resolveGuestDeviceClientId() async {
    String resolved = '';
    try {
      if (kIsWeb) {
        resolved = 'web_guest_device';
      } else if (Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        resolved = a.id.trim();
      } else if (Platform.isIOS) {
        final i = await DeviceInfoPlugin().iosInfo;
        resolved = (i.identifierForVendor ?? '').trim();
      }
      if (resolved.isEmpty) {
        final p = await SharedPreferences.getInstance();
        resolved = (p.getString('guest_device_id') ?? '').trim();
      }
      if (resolved.isEmpty) {
        resolved = 'device_unknown';
      }
      final sanitized =
          resolved.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      return 'app_$sanitized';
    } catch (e, st) {
      debugLog('DeviceBlockFusionService: resolveGuestDeviceClientId $e\n$st');
      return 'app_device_unknown';
    }
  }

  /// Ruft [applyDeviceBlockFusion] (Admin: setzt ggf. users/* Sperre + Audit-Log).
  static Future<void> applyIfNeeded(User user) async {
    final clientId = await resolveGuestDeviceClientId();
    final functions = FirebaseFunctions.instanceFor(region: _region);
    final callable = functions.httpsCallable('applyDeviceBlockFusion');
    final result = await callable.call({'deviceClientId': clientId});
    final data = result.data;
    if (data is Map && data['fused'] == true) {
      debugLog('DeviceBlockFusion: Konto mit gesperrtem Gerät verknüpft → User gesperrt.');
    }
  }
}
