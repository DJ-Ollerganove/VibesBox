import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_log.dart';
import 'user_self_settings_service.dart';

/// Wunschbox-Wortvorschläge (intern Spotify-API) — DJ-Einstellung + Gast-Spiegel.
///
/// DJ: [userField] auf `users/{uid}`.
/// Gäste (App/PWA): `users/{djId}/guest_live/wishbox` (öffentlich lesbar).
class WishboxSuggestionsSettingsService {
  WishboxSuggestionsSettingsService._();

  static const String userField = 'wishbox_suggestions_enabled';
  static const String guestLiveCollection = 'guest_live';
  static const String guestLiveDocId = 'wishbox';
  static const String _prefsKeyPrefix = 'wishbox_suggestions_enabled_';

  static bool parseEnabled(Map<String, dynamic>? data) {
    if (data == null) return true;
    return data[userField] != false;
  }

  static DocumentReference<Map<String, dynamic>> guestLiveRef(String djUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(djUid)
        .collection(guestLiveCollection)
        .doc(guestLiveDocId);
  }

  static String _prefsKey(String uid) => '$_prefsKeyPrefix$uid';

  static Future<bool> isEnabledForDj({String? userId}) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_prefsKey(uid));
    if (cached != null) return cached;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final enabled = parseEnabled(doc.data());
      await prefs.setBool(_prefsKey(uid), enabled);
      return enabled;
    } catch (e) {
      debugLog('⚠️ wishbox_suggestions laden: $e');
      return true;
    }
  }

  static Future<void> setEnabledForDj(bool enabled, {String? userId}) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey('local'), enabled);
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    // users/{uid}: Callable (Legacy-sicher); guest_live weiter Client-Write
    await UserSelfSettingsService.instance.write(
      {userField: enabled},
      userId: uid,
    );
    batch.set(
      guestLiveRef(uid),
      {
        userField: enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey(uid), enabled);
  }
}

/// Echtzeit-Spiegel für Gäste (`guest_live/wishbox`).
class WishboxSuggestionsGuestBridge {
  WishboxSuggestionsGuestBridge._();

  static final WishboxSuggestionsGuestBridge instance =
      WishboxSuggestionsGuestBridge._();

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _boundDjId;

  Future<void> bind(String djId) async {
    final id = djId.trim();
    if (id.isEmpty) return;
    if (_boundDjId == id && _sub != null) return;
    await unbind();
    _boundDjId = id;
    try {
      final snap = await WishboxSuggestionsSettingsService.guestLiveRef(id).get();
      enabled.value =
          WishboxSuggestionsSettingsService.parseEnabled(snap.data());
      await _cache(id, enabled.value);
    } catch (e) {
      debugLog('⚠️ guest_live/wishbox initial: $e');
    }
    _sub = WishboxSuggestionsSettingsService.guestLiveRef(id).snapshots().listen(
      (snap) {
        enabled.value =
            WishboxSuggestionsSettingsService.parseEnabled(snap.data());
        unawaited(_cache(id, enabled.value));
      },
      onError: (e) => debugLog('⚠️ guest_live/wishbox stream: $e'),
    );
  }

  Future<void> unbind() async {
    await _sub?.cancel();
    _sub = null;
    _boundDjId = null;
    enabled.value = true;
  }

  Future<void> _cache(String djId, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        '${WishboxSuggestionsSettingsService.userField}_guest_$djId',
        value,
      );
    } catch (_) {}
  }
}
