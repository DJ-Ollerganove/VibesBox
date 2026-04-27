import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_navigator_keys.dart';
import '../l10n/app_localizations.dart';
import '../utils/debug_log.dart';
import '../utils/notification_display_text.dart';
import 'active_party_service.dart';
import 'app_local_notifications.dart';
import 'user_service.dart';

/// Lokale DJ-Benachrichtigungen für neue Wünsche (kein Admin-Dashboard).
///
/// Filter: `party_id` = aktive Session, `dj_id` = Firebase-UID, `status` = pending.
/// Deduplizierung: [\_notifiedWishIds] im Speicher.
class DjWishNotificationService {
  DjWishNotificationService._();
  static final DjWishNotificationService instance =
      DjWishNotificationService._();

  bool _attached = false;
  bool _shellGate = false;
  VoidCallback? _recomputeListener;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _wishSub;

  final Set<String> _notifiedWishIds = <String>{};
  bool _pendingPrime = true;
  String? _subKey;

  /// Nur DJ-Shell / Admin-als-DJ — nicht im Admin-Dashboard.
  void setShellGate({required bool allow}) {
    if (_shellGate == allow) return;
    _shellGate = allow;
    _recomputeSubscription();
  }

  void attach() {
    if (_attached) return;
    _attached = true;
    _recomputeListener = _recomputeSubscription;
    UserService().currentUser.addListener(_recomputeListener!);
    ActivePartyService.storedSessionNotifier.addListener(_recomputeListener!);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _recomputeSubscription();
    });
    _recomputeSubscription();
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
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
    final djId = user.uid;
    final key = '$partyId|$djId';
    if (_subKey == key && _wishSub != null) {
      return;
    }
    _cancelWishSub();
    _subKey = key;
    _pendingPrime = true;

    debugLog(
      '🔔 DjWishNotificationService: Stream party_id=$partyId dj_id=$djId',
    );

    _wishSub = FirebaseFirestore.instance
        .collection('wishes')
        .where('party_id', isEqualTo: partyId)
        .where('dj_id', isEqualTo: djId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          _onWishSnapshot,
          onError: (Object e, StackTrace st) {
            debugLog('❌ DjWishNotificationService Stream: $e');
          },
        );
  }

  Future<void> _onWishSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (_pendingPrime) {
      for (final d in snapshot.docs) {
        _notifiedWishIds.add(d.id);
      }
      _pendingPrime = false;
      return;
    }
    final um = UserService().currentUser.value;
    final soundOn = um?.enableNotificationSound ?? true;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final id = change.doc.id;
      if (_notifiedWishIds.contains(id)) continue;
      _notifiedWishIds.add(id);
      await _showLocalNotification(
        id,
        change.doc.data() ?? <String, dynamic>{},
        soundOn: soundOn,
      );
    }
  }

  Future<void> _showLocalNotification(
    String wishDocId,
    Map<String, dynamic> data, {
    required bool soundOn,
  }) async {
    final ctx = appRootNavigatorKey.currentContext;
    if (ctx == null) {
      debugLog('⚠️ DjWishNotification: kein Navigator-Kontext für l10n');
      return;
    }
    final l = AppLocalizations.of(ctx);
    if (l == null) return;

    final rawTitle = (data['title'] as String?)?.trim();
    final rawArtist = (data['artist'] as String?)?.trim();
    final title = rawTitle != null && rawTitle.isNotEmpty
        ? decodeNotificationDisplayText(rawTitle)
        : null;
    final artist = rawArtist != null && rawArtist.isNotEmpty
        ? decodeNotificationDisplayText(rawArtist)
        : null;
    // Kurzer Notification-Titel + Songzeile: verhindert Android-Umbruch mitten in HTML-Entities
    // (z. B. `I&#x27;m` in der sichtbaren Titelzeile) und hält Titel/Interpret in einer Body-Zeile.
    final titleLine = l.dj_notification_short_title;
    final body = l.dj_notification_song_line(
      (title != null && title.isNotEmpty) ? title : '—',
      (artist != null && artist.isNotEmpty) ? artist : '—',
    );

    final android = AndroidNotificationDetails(
      'new_wishes_channel',
      'Neue Wünsche',
      channelDescription: 'Benachrichtigungen für neue Wünsche',
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
      presentBadge: true,
      presentSound: soundOn,
    );
    final details = NotificationDetails(android: android, iOS: ios);

    try {
      await appLocalNotificationsPlugin.show(
        wishDocId.hashCode & 0x7fffffff,
        titleLine,
        body,
        details,
      );
    } catch (e) {
      debugLog('❌ DjWishNotification show: $e');
    }
  }

  /// Beim ersten Einschalten des Switches (Settings).
  static Future<bool> requestNotificationPermissionIfNeeded() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }
}
