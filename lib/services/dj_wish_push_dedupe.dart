import 'package:shared_preferences/shared_preferences.dart';

const String _kDjWishPushDeliveredPrefix = 'dj_push_notified_';

/// Push bereits auf dem Gerät angezeigt (über FCM-Hintergrund-Isolate).
Future<bool> wasDjWishPushDelivered(String wishDocId) async {
  final id = wishDocId.trim();
  if (id.isEmpty) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('$_kDjWishPushDeliveredPrefix$id') ?? false;
}

Future<void> markDjWishPushDelivered(String wishDocId) async {
  final id = wishDocId.trim();
  if (id.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('$_kDjWishPushDeliveredPrefix$id', true);
}
