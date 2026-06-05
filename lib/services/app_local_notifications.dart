import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/debug_log.dart';
import 'dj_wish_notification_navigator.dart';

/// Globale Instanz — früher in `main.dart`; hier zentral für DJ-Wunsch-Benachrichtigungen.
final FlutterLocalNotificationsPlugin appLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
      if (p != null && p.startsWith('dj_wish')) {
        DjWishNotificationNavigator.instance.navigateToOpenWishesTab();
      }
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
      const androidChannel = AndroidNotificationChannel(
        'new_wishes_channel',
        'Neue Wünsche',
        description: 'Benachrichtigungen für neue Wünsche',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
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
