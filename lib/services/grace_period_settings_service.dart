import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'user_service.dart';
import 'user_self_settings_service.dart';

/// DJ-Einstellung: Nachlaufzeit für offene Wünsche nach Party-Ende — **global pro DJ-Konto**
/// (alle Geräte), Feld `grace_period_minutes` in `users/{djUid}`.
class GracePeriodSettingsService {
  static const int minGracePeriodMinutes = 0;
  static const int maxGracePeriodMinutes = 120;
  static const int stepGracePeriodMinutes = 10;
  static const int defaultGracePeriodMinutes = 30;

  static const String fieldGracePeriodMinutes = 'grace_period_minutes';

  static final List<int> allowedValues = List.generate(
    (maxGracePeriodMinutes ~/ stepGracePeriodMinutes) + 1,
    (i) => i * stepGracePeriodMinutes,
  );

  static int? _cached;
  static String? _cachedForUid;
  static final ValueNotifier<int> gracePeriodNotifier =
      ValueNotifier<int>(defaultGracePeriodMinutes);

  static int get current => _cached ?? defaultGracePeriodMinutes;

  static int? parseValue(dynamic v) {
    if (v is! int) return null;
    if (v < minGracePeriodMinutes || v > maxGracePeriodMinutes) return null;
    if (allowedValues.contains(v)) return v;
    final snapped =
        ((v / stepGracePeriodMinutes).round() * stepGracePeriodMinutes)
            .clamp(minGracePeriodMinutes, maxGracePeriodMinutes);
    return allowedValues.contains(snapped) ? snapped : null;
  }

  /// DJ-UID für globale Einstellungen (Admin im DJ-Modus → [AppConfig.adminDjId]).
  static String? effectiveDjUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final current = UserService().currentUser.value;
    final isAdmin =
        current != null &&
        current.id == user.uid &&
        AppConfig.isAdminRole(current);

    if (isAdmin && AppConfig.adminDjId != null) {
      return AppConfig.adminDjId;
    }
    return user.uid;
  }

  static DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// Legacy-Pfad (Migration): users/{uid}/settings/grace_period
  static DocumentReference<Map<String, dynamic>> _legacySettingsRef(String uid) =>
      _userRef(uid).collection('settings').doc('grace_period');

  static Stream<int> streamForDj(String uid) {
    if (uid.isEmpty) {
      return Stream.value(defaultGracePeriodMinutes);
    }
    return _userRef(uid).snapshots().map((snap) {
      final fromRoot = parseValue(snap.data()?[fieldGracePeriodMinutes]);
      if (fromRoot != null) return fromRoot;
      return defaultGracePeriodMinutes;
    });
  }

  static Future<int> load() async {
    final uid = effectiveDjUid();
    if (uid == null || uid.isEmpty) {
      return defaultGracePeriodMinutes;
    }
    if (_cached != null && _cachedForUid == uid) {
      return _cached!;
    }

    try {
      final userDoc = await _userRef(uid).get();
      if (userDoc.exists) {
        final fromRoot = parseValue(userDoc.data()?[fieldGracePeriodMinutes]);
        if (fromRoot != null) {
          _remember(uid, fromRoot);
          return fromRoot;
        }
      }

      // Migration: altes Subcollection-Dokument übernehmen.
      final legacyDoc = await _legacySettingsRef(uid).get();
      if (legacyDoc.exists) {
        final legacy = parseValue(legacyDoc.data()?[fieldGracePeriodMinutes]);
        if (legacy != null) {
          await UserSelfSettingsService.instance.write(
            {fieldGracePeriodMinutes: legacy},
            userId: uid,
          );
          _remember(uid, legacy);
          return legacy;
        }
      }
    } catch (_) {
      // Fallback unten
    }

    _remember(uid, defaultGracePeriodMinutes);
    return defaultGracePeriodMinutes;
  }

  static void _remember(String uid, int value) {
    _cached = value;
    _cachedForUid = uid;
    gracePeriodNotifier.value = value;
  }

  static Future<void> save(int value) async {
    if (parseValue(value) == null) return;

    final uid = effectiveDjUid();
    if (uid == null || uid.isEmpty) return;

    await UserSelfSettingsService.instance.write(
      {fieldGracePeriodMinutes: value},
      userId: uid,
    );
    _remember(uid, value);
  }
}
