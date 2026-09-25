import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_navigator_keys.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_helper.dart';
import '../utils/debug_log.dart';
import '../utils/notification_display_text.dart';
import 'active_party_service.dart';
import 'app_local_notifications.dart';
import 'dj_wish_push_dedupe.dart';
import 'user_service.dart';
import '../utils/wish_paths.dart';

/// Lokale DJ-Benachrichtigungen für neue Wünsche (kein Admin-Dashboard).
///
/// Schnellpfad **Vordergrund**: Firestore-Snapshot (gleiche Query wie „Offen“, ohne `dj_id`).
/// Schnellpfad **Hintergrund / App zu**: FCM ([DjWishFcmService] + Cloud Function) —
/// Firestore-Listener ist dann gedrosselt / eingeschlafen.
///
/// Dedupe: [consumeWishNotificationSlot] — ein Wish-Doc höchstens eine sichtbare Notification.
///
/// iOS-Ton: [iosWishNotificationSound] = gleiche Quelle wie Android `res/raw/notification.mp3`,
/// konvertiert nach `ios/Runner/notification.caf` (Bundling in Xcode).
class DjWishNotificationService with WidgetsBindingObserver {
  DjWishNotificationService._();
  static final DjWishNotificationService instance =
      DjWishNotificationService._();

  /// Für FCM-Fallback-Titel (öffentlich für [DjWishFcmService] ohne Duplikat-String).
  static const String fallbackWishTitleStatic = 'VibesBox: Neuer Songwunsch';

  /// Bundled unter `ios/Runner/` — gleicher Inhalt wie Android `notification.mp3`.
  static const String iosWishNotificationSound = kIosWishNotificationSound;

  static const MethodChannel _iosSoundChannel =
      MethodChannel('dj_og_app/notification_sound');

  bool _attached = false;
  bool _shellGate = false;
  VoidCallback? _recomputeListener;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _wishSub;

  final Set<String> _notifiedWishIds = <String>{};
  bool _pendingPrime = true;
  String? _subKey;

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  /// Optional: FCM-Token sync (gesetzt aus `main.dart`, vermeidet Import-Zyklus).
  Future<void> Function()? _pushSubsystemSync;

  void registerPushSubsystemSync(Future<void> Function()? fn) {
    _pushSubsystemSync = fn;
  }

  /// Nur DJ-Shell / Admin-als-DJ — nicht im Admin-Dashboard.
  void setShellGate({required bool allow}) {
    if (_shellGate == allow) return;
    _shellGate = allow;
    _recomputeSubscription();
  }

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    _recomputeListener = _recomputeSubscription;
    UserService().currentUser.addListener(_recomputeListener!);
    ActivePartyService.storedSessionNotifier.addListener(_recomputeListener!);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _recomputeSubscription();
    });
    _recomputeSubscription();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(_pushSubsystemSync?.call());
    }
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
    if (_recomputeListener != null) {
      UserService().currentUser.removeListener(_recomputeListener!);
      ActivePartyService.storedSessionNotifier.removeListener(
        _recomputeListener!,
      );
    }
    _recomputeListener = null;
    _authSub?.cancel();
    _authSub = null;
    _cancelWishSub();
  }

  void _cancelWishSub() {
    _wishSub?.cancel();
    _wishSub = null;
    _subKey = null;
    _pendingPrime = true;
  }

  /// Nur eine sichtbare Mitteilung pro Wunsch-Dokument (Firestore vs. FCM).
  bool consumeWishNotificationSlot(String wishDocId) {
    if (_notifiedWishIds.contains(wishDocId)) return false;
    _notifiedWishIds.add(wishDocId);
    return true;
  }

  void _recomputeSubscription() {
    if (!_attached) return;
    if (!_shellGate) {
      _cancelWishSub();
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    final um = UserService().currentUser.value;
    if (user == null || um == null || um.notifyNewWishes != true) {
      _cancelWishSub();
      return;
    }
    final partyId = ActivePartyService.getStoredSession()?.partyId;
    if (partyId == null || partyId.isEmpty) {
      _cancelWishSub();
      return;
    }
    final key = partyId;
    if (_subKey == key && _wishSub != null) {
      // Bereits abonniert — kein erneuter FCM-Sync (sonst Retry-Sturm).
      return;
    }
    _cancelWishSub();
    _subKey = key;
    _pendingPrime = true;

    debugLog(
      '🔔 DjWishNotificationService: Stream party_id=$partyId (pending, ohne dj_id-Filter)',
    );

    _wishSub = WishPaths.partyWishes(partyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          _onWishSnapshot,
          onError: (Object e, StackTrace st) {
            debugLog('❌ DjWishNotificationService Stream: $e');
          },
        );

    unawaited(_pushSubsystemSync?.call());
  }

  Future<void> _onWishSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (_pendingPrime) {
      if (snapshot.metadata.isFromCache && snapshot.docs.isEmpty) {
        return;
      }
      for (final d in snapshot.docs) {
        _notifiedWishIds.add(d.id);
      }
      _pendingPrime = false;
      return;
    }

    final um = UserService().currentUser.value;
    final soundOn = um?.enableNotificationSound ?? true;

    final inForeground = _lifecycleState == AppLifecycleState.resumed;

    final partyRunning = await ActivePartyService.isPartyActuallyActive();
    if (!partyRunning) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _notifiedWishIds.add(change.doc.id);
        }
      }
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final id = change.doc.id;
      if (_notifiedWishIds.contains(id)) continue;
      if (await wasDjWishPushDelivered(id)) {
        _notifiedWishIds.add(id);
        continue;
      }

      final wishData = change.doc.data() ?? <String, dynamic>{};
      if (wishData['is_pre_wish'] == true) {
        _notifiedWishIds.add(id);
        continue;
      }

      if (!inForeground) {
        // Hintergrund: FCM liefert zuverlässig & zeitnah — hier nur ID merken,
        // damit beim Zurückkehren keine zweite lokale Notification nachzieht.
        _notifiedWishIds.add(id);
        continue;
      }

      if (!consumeWishNotificationSlot(id)) continue;

      debugLog(
        '🔔 DjWishNotification: neuer Pending-Wunsch doc=$id → lokale Notification',
      );
      await _showLocalNotificationFromFirestoreDoc(
        id,
        change.doc.data() ?? <String, dynamic>{},
        soundOn: soundOn,
      );
      await markDjWishPushDelivered(id);
    }
  }

  Future<void> showWishNotificationFromRemotePayload({
    required String wishDocId,
    required String titleLine,
    required String body,
    required bool soundOn,
  }) async {
    await _showLocalNotificationImpl(
      wishDocId: wishDocId,
      soundOn: soundOn,
      titleLine: titleLine,
      body: body,
    );
  }

  Future<void> _showLocalNotificationFromFirestoreDoc(
    String wishDocId,
    Map<String, dynamic> data, {
    required bool soundOn,
  }) async {
    final rawTitle = (data['title'] as String?)?.trim();
    final rawArtist = (data['artist'] as String?)?.trim();
    final title = rawTitle != null && rawTitle.isNotEmpty
        ? decodeNotificationDisplayText(rawTitle)
        : null;
    final artist = rawArtist != null && rawArtist.isNotEmpty
        ? decodeNotificationDisplayText(rawArtist)
        : null;
    final titleForBody =
        (title != null && title.isNotEmpty) ? title : '—';
    final artistForBody =
        (artist != null && artist.isNotEmpty) ? artist : '—';

    final ctx = appRootNavigatorKey.currentContext;
    final l = ctx != null ? AppLocalizations.of(ctx) : null;
    final String titleLine;
    final String body;
    if (l != null) {
      titleLine = l.dj_notification_short_title;
      body = l.dj_notification_song_line(titleForBody, artistForBody);
    } else {
      if (ctx == null) {
        debugLog(
          '⚠️ DjWishNotification: kein Navigator-Kontext — Fallback-Texte',
        );
      }
      titleLine = fallbackWishTitleStatic;
      body = '$titleForBody - $artistForBody';
    }

    await _showLocalNotificationImpl(
      wishDocId: wishDocId,
      soundOn: soundOn,
      titleLine: titleLine,
      body: body,
    );
  }

  Future<void> _playIosWishSoundIfNeeded(bool soundOn) async {
    if (!soundOn || !Platform.isIOS) return;
    try {
      await _iosSoundChannel.invokeMethod<void>('playWishSound');
    } catch (e) {
      debugLog('⚠️ DjWishNotification: iOS-Ton fehlgeschlagen: $e');
    }
  }

  Future<void> _showLocalNotificationImpl({
    required String wishDocId,
    required bool soundOn,
    required String titleLine,
    required String body,
  }) async {
    if (Platform.isIOS) {
      await ensureIosNotificationPermission();
    }

    final t = LocaleHelper.getTranslations(LocaleHelper.localeNotifier.value);
    final channelName =
        LocaleHelper.tr(t, 'notification_channel_new_wishes');
    final channelDesc =
        LocaleHelper.tr(t, 'notification_channel_new_wishes_desc');

    final android = AndroidNotificationDetails(
      'new_wishes_channel',
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: soundOn,
      sound: soundOn
          ? const RawResourceAndroidNotificationSound('notification')
          : null,
      ongoing: false,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      channelShowBadge: true,
    );
    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentBadge: true,
      presentSound: soundOn,
      sound: soundOn ? iosWishNotificationSound : null,
      interruptionLevel: InterruptionLevel.active,
    );
    final details = NotificationDetails(android: android, iOS: ios);

    try {
      await appLocalNotificationsPlugin.show(
        wishDocId.hashCode & 0x7fffffff,
        titleLine,
        body,
        details,
        payload: 'dj_wish',
      );
      debugLog('✅ DjWishNotification: show() ok doc=$wishDocId sound=$soundOn');
      if (soundOn) {
        unawaited(_playIosWishSoundIfNeeded(true));
      }
    } catch (e) {
      debugLog('❌ DjWishNotification show: $e');
      if (soundOn) {
        unawaited(_playIosWishSoundIfNeeded(true));
      }
    }
  }

  /// Beim ersten Einschalten des Switches (Settings).
  static Future<bool> requestNotificationPermissionIfNeeded() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    if (Platform.isIOS) {
      return ensureIosNotificationPermission();
    }
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }
}
