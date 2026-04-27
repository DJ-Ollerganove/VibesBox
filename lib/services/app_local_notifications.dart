import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/debug_log.dart';

/// Globale Instanz — früher in `main.dart`; hier zentral für DJ-Wunsch-Benachrichtigungen.
final FlutterLocalNotificationsPlugin appLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initialisiert Plugin + Android-Channel `new_wishes_channel` mit Sound `res/raw/notification`.
/// **Keine** automatische Notification-Permission (Android 13+) — erst bei Aktivierung in den DJ-Einstellungen.
Future<void> initializeAppLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await appLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
    onDidReceiveNotificationResponse: (details) {},
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
