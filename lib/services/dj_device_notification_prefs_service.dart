import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../utils/ios_stable_device_id.dart';

/// DJ-Benachrichtigungs-Schalter (Wünsche, Ton, Statusleiste) pro **Gerät**
/// unter `users/{uid}/dj_device_prefs/{installId}`.
///
/// [installId] ist hardware-/installationstabil (Android-ID bzw. iOS Keychain),
/// damit Debug-Neuinstallationen nicht jedes Mal neue leere Geräte-Dokumente erzeugen.
class DjDeviceNotificationPrefsService {
  DjDeviceNotificationPrefsService._();

  static const prefsKeyInstallId = 'dj_notification_install_id_v1';
  static const collectionName = 'dj_device_prefs';

  /// Admin-Skript setzt `true`; erstes Gerät nach Update kopiert Root-Werte ins Geräte-Dokument und setzt `false`.
  static const userFieldAwaitingFirstDeviceSeed =
      'dj_notif_awaiting_first_device_seed';

  static String platformTag() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return defaultTargetPlatform.name;
    }
  }

  /// Stabile Geräte-ID: überlebt App-Deinstallation (Debug-Install), solange dasselbe physische Gerät.
  static Future<String> getOrCreateInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(prefsKeyInstallId);
    if (existing != null && existing.isNotEmpty) return existing;

    final stable = await _resolveStableInstallId();
    await prefs.setString(prefsKeyInstallId, stable);
    return stable;
  }

  static Future<String> _resolveStableInstallId() async {
    if (kIsWeb) {
      return const Uuid().v4();
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        final androidId = info.id.trim();
        if (androidId.isNotEmpty) {
          return 'android_$androidId';
        }
      } catch (_) {
        // Fallback unten
      }
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final iosId = await getStableIosDeviceId(
          mirrorPrefsKey: prefsKeyInstallId,
        );
        if (iosId.isNotEmpty && iosId != 'device_unknown') {
          return 'ios_$iosId';
        }
      } catch (_) {
        // Fallback unten
      }
    }
    return const Uuid().v4();
  }

  static DocumentReference<Map<String, dynamic>> deviceDocRef(
    String uid,
    String installId,
  ) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(collectionName)
          .doc(installId);

  /// Nach Debug-Reinstall: letztes Geräte-Dokument derselben Plattform übernehmen.
  static Future<Map<String, dynamic>?> findReusableSamePlatformPrefs(
    String uid,
    String currentInstallId,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(collectionName)
          .get();
      if (snap.docs.isEmpty) return null;

      final tag = platformTag();
      QueryDocumentSnapshot<Map<String, dynamic>>? best;
      Timestamp? bestTs;

      for (final doc in snap.docs) {
        if (doc.id == currentInstallId) continue;
        final data = doc.data();
        if (data['platform'] != tag) continue;
        final ts = data['updatedAt'] as Timestamp?;
        if (best == null ||
            (ts != null && (bestTs == null || ts.compareTo(bestTs) > 0))) {
          best = doc;
          bestTs = ts;
        }
      }
      if (best == null) return null;

      final d = best.data();
      return fullDevicePayload(
        notifyNewWishes: d['notifyNewWishes'] == true,
        enableNotificationSound: d['enableNotificationSound'] != false,
        showStatusNotification: d['show_status_notification'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Geräte-Dokument überschreibt nur gesetzte Keys; sonst Werte aus [base] (User-Root).
  static UserModel merge(UserModel base, Map<String, dynamic>? device) {
    if (device == null || device.isEmpty) return base;
    final n = device.containsKey('notifyNewWishes')
        ? device['notifyNewWishes'] == true
        : base.notifyNewWishes;
    final snd = device.containsKey('enableNotificationSound')
        ? device['enableNotificationSound'] != false
        : base.enableNotificationSound;
    final st = device.containsKey('show_status_notification')
        ? device['show_status_notification'] == true
        : base.showStatusNotification;
    return base.copyWith(
      notifyNewWishes: n,
      enableNotificationSound: snd,
      showStatusNotification: st,
    );
  }

  static Map<String, dynamic> fullDevicePayload({
    required bool notifyNewWishes,
    required bool enableNotificationSound,
    required bool showStatusNotification,
  }) =>
      {
        'notifyNewWishes': notifyNewWishes,
        'enableNotificationSound': enableNotificationSound,
        'show_status_notification': showStatusNotification,
        'platform': platformTag(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
