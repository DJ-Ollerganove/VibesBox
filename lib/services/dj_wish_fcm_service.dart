import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import '../utils/wish_paths.dart';
import 'active_party_service.dart';
import 'dj_wish_notification_navigator.dart';
import 'dj_wish_notification_service.dart';
import 'user_service.dart';

/// Top-Level für [FirebaseMessaging.onBackgroundMessage] (separate Isolate).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// FCM: Token unter `users/{uid}.fcm_token`, Push bei neuem Wunsch via Cloud Function.
class DjWishFcmService {
  DjWishFcmService._();
  static final DjWishFcmService instance = DjWishFcmService._();

  bool _listenersAttached = false;
  bool _tokenRefreshLinked = false;

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
    final title = (n?.title ?? '').trim().isNotEmpty
        ? n!.title!.trim()
        : DjWishNotificationService.fallbackWishTitleStatic;
    final bodyRaw = (n?.body ?? '').trim();
    final body = bodyRaw.isNotEmpty ? bodyRaw : '—';

    final um = UserService().currentUser.value;
    final soundOn = um?.enableNotificationSound ?? true;

    await DjWishNotificationService.instance.showWishNotificationFromRemotePayload(
      wishDocId: wishId,
      titleLine: title,
      body: body,
      soundOn: soundOn,
    );
  }

  /// Nach Login / bei Bedarf: Berechtigung, Token speichern. Kein Prompt ohne eingeschaltete DJ-Wünsche.
  Future<void> syncTokenForCurrentUserIfEligible() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final um = UserService().currentUser.value;
    if (um?.notifyNewWishes != true) return;

    await ensureDartListenersAttached();

    final messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) {
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

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {'fcm_token': token},
      SetOptions(merge: true),
    );

    if (!_tokenRefreshLinked) {
      _tokenRefreshLinked = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final cur = FirebaseAuth.instance.currentUser;
        if (cur == null) return;
        final m = UserService().currentUser.value;
        if (m?.notifyNewWishes != true) return;
        await FirebaseFirestore.instance.collection('users').doc(cur.uid).set(
          {'fcm_token': newToken},
          SetOptions(merge: true),
        );
      });
    }
  }
}
