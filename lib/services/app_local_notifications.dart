import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/debug_log.dart';
import '../l10n/locale_helper.dart';
import '../l10n/generated/locale_translations.g.dart';
import 'dj_wish_notification_navigator.dart';
import 'dj_wish_notification_service.dart';
import 'dj_wish_push_dedupe.dart';

/// Globale Instanz — früher in `main.dart`; hier zentral für DJ-Wunsch-Benachrichtigungen.
final FlutterLocalNotificationsPlugin appLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// iOS-Shazam-Status (Android nutzt Foreground Service).
const int kShazamStatusNotificationId = 991001;

/// Optional: weitere Payload-Taps (z. B. Shazam → History), ohne Import-Zyklen.
typedef NotificationPayloadHandler = void Function(String payload);
NotificationPayloadHandler? extraNotificationPayloadHandler;

/// Bundled unter `ios/Runner/` — gleicher Inhalt wie Android `notification.mp3`.
const String kIosWishNotificationSound = 'notification';

/// iOS: Berechtigung für Banner + Ton (getrennt von FCM, gleicher OS-Dialog).
Future<bool> ensureIosNotificationPermission() async {
  if (!Platform.isIOS) return true;

  final iosPlugin = appLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
  if (iosPlugin != null) {
    final current = await iosPlugin.checkPermissions();
    if (current?.isEnabled == true) return true;
    final granted = await iosPlugin.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted == true;
  }

  final status = await Permission.notification.status;
  if (status.isGranted) return true;
  return (await Permission.notification.request()).isGranted;
}

/// Initialisiert Plugin + Android-Channel `new_wishes_channel` mit Sound `res/raw/notification.mp3`;
/// iOS: gebündelte Datei `notification.caf` (Konvert aus demselben MP3, Xcode „Copy Bundle Resources“).
/// **Keine** automatische Notification-Permission (Android 13+) — erst bei Aktivierung in den DJ-Einstellungen.
Future<void> initializeAppLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    // iOS 14+: Banner/Leiste im Vordergrund nutzt Banner/List — nicht mehr „Alert“.
    defaultPresentAlert: true,
    defaultPresentSound: true,
    defaultPresentBadge: true,
    defaultPresentBanner: true,
    defaultPresentList: true,
  );
  await appLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      final p = details.payload;
      if (p == null || p.isEmpty) return;
      if (p.startsWith('dj_wish')) {
        DjWishNotificationNavigator.instance.navigateToOpenWishesTab();
        return;
      }
      extraNotificationPayloadHandler?.call(p);
    },
  );

  if (Platform.isAndroid) {
    final androidPlugin = appLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      try {
        await androidPlugin.deleteNotificationChannel('new_wishes_channel');
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } catch (_) {}
      String t(String key) {
        final code = LocaleHelper.localeNotifier.value.languageCode;
        final map = translationsForLanguageCode(code);
        return map[key] ??
            translationsForLanguageCode('en')[key] ??
            translationsForLanguageCode('de')[key] ??
            key;
      }
      final androidChannel = AndroidNotificationChannel(
        'new_wishes_channel',
        t('notification_channel_new_wishes'),
        description: t('notification_channel_new_wishes_desc'),
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(androidChannel);
      debugLog(
        '✅ Notification-Channel new_wishes_channel — Sound: res/raw/notification.mp3',
      );
    }
  }
}

/// iOS-Ersatz für Android Shazam-Foreground-Service-Notification (ohne Ton).
Future<void> showOrUpdateShazamStatusNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  if (!Platform.isIOS) return;

  final permitted = await ensureIosNotificationPermission();
  if (!permitted) {
    debugLog('⚠️ Shazam-Status-Notification: iOS-Berechtigung fehlt');
    return;
  }

  const ios = DarwinNotificationDetails(
    presentAlert: true,
    presentBanner: true,
    presentList: true,
    presentBadge: false,
    presentSound: false,
    threadIdentifier: 'shazam_status',
    interruptionLevel: InterruptionLevel.passive,
  );
  try {
    await appLocalNotificationsPlugin.show(
      kShazamStatusNotificationId,
      title,
      body,
      const NotificationDetails(iOS: ios),
      payload: payload,
    );
  } catch (e) {
    debugLog('❌ Shazam-Status-Notification show: $e');
  }
}

Future<void> cancelShazamStatusNotification() async {
  if (!Platform.isIOS) return;
  try {
    await appLocalNotificationsPlugin.cancel(kShazamStatusNotificationId);
  } catch (e) {
    debugLog('⚠️ Shazam-Status-Notification cancel: $e');
  }
}

/// FCM Hintergrund/Sperrbildschirm — lokale Notification (eigene Isolate, kein UserService).
Future<void> showDjWishPushFromRemoteMessage(RemoteMessage message) async {
  if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;
  if ((message.data['type'] ?? '') != 'dj_new_wish') return;

  final wishId = (message.data['wishId'] ?? '').toString().trim();
  if (wishId.isEmpty) return;
  if (await wasDjWishPushDelivered(wishId)) return;

  await initializeAppLocalNotifications();
  if (Platform.isIOS) {
    await ensureIosNotificationPermission();
  }

  final n = message.notification;
  final dataTitle = (message.data['title'] ?? '').toString().trim();
  final dataBody = (message.data['body'] ?? '').toString().trim();
  final titleLine = (n?.title ?? '').trim().isNotEmpty
      ? n!.title!.trim()
      : (dataTitle.isNotEmpty
          ? dataTitle
          : DjWishNotificationService.fallbackWishTitleStatic);
  final bodyRaw = (n?.body ?? '').trim();
  final body = bodyRaw.isNotEmpty
      ? bodyRaw
      : (dataBody.isNotEmpty ? dataBody : '—');
  final soundOn = message.data['sound'] != '0';

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
    playSound: soundOn,
    sound: soundOn
        ? const RawResourceAndroidNotificationSound('notification')
        : null,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.message,
  );
  final ios = DarwinNotificationDetails(
    presentAlert: true,
    presentBanner: true,
    presentList: true,
    presentBadge: true,
    presentSound: soundOn,
    sound: soundOn ? kIosWishNotificationSound : null,
    interruptionLevel: InterruptionLevel.active,
  );

  try {
    await appLocalNotificationsPlugin.show(
      wishId.hashCode & 0x7fffffff,
      titleLine,
      body,
      NotificationDetails(android: android, iOS: ios),
      payload: 'dj_wish',
    );
    await markDjWishPushDelivered(wishId);
    debugLog('✅ DjWish FCM background: Notification wish=$wishId');
  } catch (e) {
    debugLog('❌ DjWish FCM background show: $e');
  }
}
