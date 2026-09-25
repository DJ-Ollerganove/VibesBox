import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';
import 'active_party_service.dart';
import 'app_local_notifications.dart';
import 'dj_wish_notification_navigator.dart';
import 'dj_wish_notification_service.dart';
import 'dj_wish_push_dedupe.dart';
import 'user_self_settings_service.dart';
import 'user_service.dart';

/// Top-Level für [FirebaseMessaging.onBackgroundMessage] (separate Isolate).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await showDjWishPushFromRemoteMessage(message);
}

/// iOS: FCM braucht APNs-Token — ohne Wartezeit oft kein gültiger Token.
Future<void> _ensureIosApnsTokenReady() async {
  if (!Platform.isIOS) return;
  for (var attempt = 0; attempt < 12; attempt++) {
    final apns = await FirebaseMessaging.instance.getAPNSToken();
    if (apns != null && apns.isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  debugLog('⚠️ DjWishFcm: APNs-Token nach Wartezeit noch null');
}

/// FCM: Token unter `users/{uid}.fcm_token`, Push bei neuem Wunsch via Cloud Function.
class DjWishFcmService {
  DjWishFcmService._();
  static final DjWishFcmService instance = DjWishFcmService._();

  bool _listenersAttached = false;
  bool _tokenRefreshLinked = false;
  String? _lastWrittenToken;
  DateTime? _lastSyncAttemptAt;
  DateTime? _permissionDeniedUntil;

  Future<void> ensureDartListenersAttached() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;
    if (_listenersAttached) return;
    _listenersAttached = true;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedFromTray);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleOpenedFromTray(initial);
      });
    }
  }

  void _handleOpenedFromTray(RemoteMessage message) {
    if ((message.data['type'] ?? '') != 'dj_new_wish') return;
    DjWishNotificationNavigator.instance.navigateToOpenWishesTab();
  }

  Future<void> _onForegroundMessage(RemoteMessage msg) async {
    if ((msg.data['type'] ?? '') != 'dj_new_wish') return;
    final wishId = msg.data['wishId'] ?? '';
    if (wishId.isEmpty) return;
    final partyId = (msg.data['party_id'] ?? '').trim();
    if (partyId.isEmpty) return;

    if (!await ActivePartyService.isPartyIdRunningNowForCurrentDj(partyId)) {
      return;
    }

    try {
      final wishSnap = await WishPaths.partyWish(partyId, wishId).get();
      if (wishSnap.data()?['is_pre_wish'] == true) return;
    } catch (_) {
      return;
    }

    // Native FCM-Banner im Vordergrund aus — wir zeigen einheitlich über flutter_local_notifications.
    if (!DjWishNotificationService.instance.consumeWishNotificationSlot(wishId)) {
      return;
    }

    final n = msg.notification;
    final dataTitle = (msg.data['title'] ?? '').toString().trim();
    final dataBody = (msg.data['body'] ?? '').toString().trim();
    final title = (n?.title ?? '').trim().isNotEmpty
        ? n!.title!.trim()
        : (dataTitle.isNotEmpty
            ? dataTitle
            : DjWishNotificationService.fallbackWishTitleStatic);
    final bodyRaw = (n?.body ?? '').trim();
    final body = bodyRaw.isNotEmpty
        ? bodyRaw
        : (dataBody.isNotEmpty ? dataBody : '—');

    final um = UserService().currentUser.value;
    final soundOn =
        msg.data['sound'] != '0' && (um?.enableNotificationSound ?? true);

    await DjWishNotificationService.instance.showWishNotificationFromRemotePayload(
      wishDocId: wishId,
      titleLine: title,
      body: body,
      soundOn: soundOn,
    );
    await markDjWishPushDelivered(wishId);
  }

  /// Nach Login / bei Bedarf: Berechtigung, Token speichern. Kein Prompt ohne eingeschaltete DJ-Wünsche.
  Future<void> syncTokenForCurrentUserIfEligible() async {
    // Darf nie ungecatcht werfen: Aufrufer nutzen oft unawaited() → sonst
    // PlatformDispatcher.onError → Diagnose-Log-Sturm (~5s) und iOS-Jetsam-Risiko.
    try {
      await _syncTokenForCurrentUserIfEligibleBody();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _permissionDeniedUntil =
            DateTime.now().add(const Duration(hours: 1));
        debugLog(
          '⚠️ DjWishFcm: permission-denied — Sync 1h pausiert',
        );
      } else {
        debugLog('⚠️ DjWishFcm: Token-Sync FirebaseException ${e.code}: $e');
      }
    } catch (e) {
      debugLog('⚠️ DjWishFcm: Token-Sync Fehler: $e');
    }
  }

  Future<void> _syncTokenForCurrentUserIfEligibleBody() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;

    final deniedUntil = _permissionDeniedUntil;
    if (deniedUntil != null && DateTime.now().isBefore(deniedUntil)) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final um = UserService().currentUser.value;
    if (um?.notifyNewWishes != true) return;

    final now = DateTime.now();
    final last = _lastSyncAttemptAt;
    if (last != null && now.difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _lastSyncAttemptAt = now;

    await ensureDartListenersAttached();

    final messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) {
      await ensureIosNotificationPermission();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!ok) return;

    if (Platform.isIOS) {
      await _ensureIosApnsTokenReady();
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      debugLog('⚠️ DjWishFcm: getToken() leer');
      return;
    }
    if (_lastWrittenToken == token) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    await UserSelfSettingsService.instance.write({
      'fcm_token': token,
      'fcm_token_platform': platform,
      'fcm_token_updated_at': FieldValue.serverTimestamp(),
    });
    _lastWrittenToken = token;
    _permissionDeniedUntil = null;
    debugLog('✅ DjWishFcm: Token gespeichert platform=$platform');

    if (!_tokenRefreshLinked) {
      _tokenRefreshLinked = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          final cur = FirebaseAuth.instance.currentUser;
          if (cur == null) return;
          final m = UserService().currentUser.value;
          if (m?.notifyNewWishes != true) return;
          if (Platform.isIOS) {
            await _ensureIosApnsTokenReady();
          }
          final p = Platform.isIOS ? 'ios' : 'android';
          await UserSelfSettingsService.instance.write({
            'fcm_token': newToken,
            'fcm_token_platform': p,
            'fcm_token_updated_at': FieldValue.serverTimestamp(),
          });
          _lastWrittenToken = newToken;
        } catch (e) {
          debugLog('⚠️ DjWishFcm: onTokenRefresh Fehler: $e');
        }
      });
    }
  }

  /// Vor Logout: FCM-Token dieses Geräts vom User-Doc entfernen.
  /// Sonst bekommt das Gerät weiter Pushes für den alten DJ (Account-Wechsel).
  Future<void> clearDeviceTokenFromCurrentUserIfOwned() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final deviceToken = await FirebaseMessaging.instance.getToken();
      if (deviceToken == null || deviceToken.isEmpty) return;

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final stored = (snap.data()?['fcm_token'] as String?)?.trim() ?? '';
      if (stored.isEmpty) return;
      if (stored != deviceToken) {
        debugLog(
          'DjWishFcm: Logout — fcm_token gehört anderem Gerät, belasse ihn',
        );
        return;
      }

      await UserSelfSettingsService.instance.write({
        'fcm_token': null,
        'fcm_token_platform': null,
        'fcm_token_updated_at': null,
      });
      debugLog('✅ DjWishFcm: Gerät-Token vom User-Doc entfernt (Logout)');
    } catch (e) {
      debugLog('⚠️ DjWishFcm: Token-Clear beim Logout fehlgeschlagen: $e');
    }
  }
}
