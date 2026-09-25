import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../utils/party_grace_period_helper.dart';
import 'active_party_service.dart';
import 'grace_period_settings_service.dart';
import 'party_secure_service.dart';
import 'user_service.dart';

/// Ergebnis der Sichtbarkeitsprüfung für die DJ-Offen-Liste.
class OpenWishesVisibility {
  const OpenWishesVisibility({
    required this.partyId,
    required this.endDate,
    required this.graceEndsAt,
    required this.isGracePeriodOnly,
    required this.showHideWishesButton,
    this.partyName,
    this.startDate,
  });

  final String partyId;
  final DateTime endDate;
  final DateTime graceEndsAt;
  final String? partyName;
  final DateTime? startDate;

  /// Reguläres Party-Ende überschritten, Nachlaufzeit läuft noch.
  final bool isGracePeriodOnly;

  /// Button „Wünsche jetzt ausblenden“ anzeigen.
  final bool showHideWishesButton;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenWishesVisibility &&
        other.partyId == partyId &&
        other.isGracePeriodOnly == isGracePeriodOnly &&
        other.showHideWishesButton == showHideWishesButton &&
        other.endDate == endDate &&
        other.graceEndsAt == graceEndsAt &&
        other.partyName == partyName &&
        other.startDate == startDate;
  }

  @override
  int get hashCode => Object.hash(
        partyId,
        isGracePeriodOnly,
        showHideWishesButton,
        endDate,
        graceEndsAt,
        partyName,
        startDate,
      );
}

/// Echtzeit-Stream: welche Party offene Wünsche für den DJ zeigt (inkl. Nachlaufzeit).
class OpenWishesVisibilityService {
  static final Map<String, Stream<OpenWishesVisibility?>> _streamCache = {};

  /// Zentraler UI-Notifier — alle DJ-Wunsch-Tabs (Offen/Gespielt/Abgelehnt) lauschen darauf,
  /// damit Keep-Alive-Tabs nicht am Stream-Subscribe hängen bleiben.
  static final ValueNotifier<OpenWishesVisibility?> visibilityNotifier =
      ValueNotifier<OpenWishesVisibility?>(null);

  static StreamSubscription<OpenWishesVisibility?>? _appLifetimeSub;
  static String? _appLifetimeDjId;

  /// Ein Firestore-Abo pro App-Session — alle Tabs lesen nur [visibilityNotifier].
  static void ensureWatching([String? djId]) {
    final effectiveDjId = _effectiveDjId(djId);
    if (effectiveDjId.isEmpty) return;
    if (_appLifetimeSub != null && _appLifetimeDjId == effectiveDjId) return;
    unawaited(resetForLogout());
    _appLifetimeDjId = effectiveDjId;
    _appLifetimeSub = watch(effectiveDjId).listen((_) {});
  }

  /// Logout / Account-Wechsel — Stream und Cache zurücksetzen.
  static Future<void> resetForLogout() async {
    await _appLifetimeSub?.cancel();
    _appLifetimeSub = null;
    _appLifetimeDjId = null;
    visibilityNotifier.value = null;
    _streamCache.clear();
  }

  static String _effectiveDjId(String? djId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return djId ?? '';

    final current = UserService().currentUser.value;
    final isAdmin =
        current != null &&
        current.id == user.uid &&
        AppConfig.isAdminRole(current);

    if (isAdmin && AppConfig.adminDjId != null) {
      return AppConfig.adminDjId!;
    }
    return djId ?? user.uid;
  }

  static Stream<OpenWishesVisibility?> watch([String? djId]) {
    final effectiveDjId = _effectiveDjId(djId);
    if (effectiveDjId.isEmpty) return Stream.value(null);

    return _streamCache.putIfAbsent(
      effectiveDjId,
      () => _createStream(effectiveDjId),
    );
  }

  static Stream<OpenWishesVisibility?> _createStream(String djId) {
    late final StreamController<OpenWishesVisibility?> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? partiesSub;
    StreamSubscription<int>? graceSub;
    Timer? clockTimer;
    QuerySnapshot<Map<String, dynamic>>? latestParties;
    var graceMinutes = GracePeriodSettingsService.defaultGracePeriodMinutes;
    var listenerCount = 0;

    void emit() {
      if (controller.isClosed) return;
      final OpenWishesVisibility? resolved;
      if (latestParties == null) {
        resolved = null;
      } else {
        resolved = _resolveFromSnapshot(
          latestParties!,
          graceMinutes,
          DateTime.now(),
        );
      }
      if (visibilityNotifier.value == resolved) return;
      visibilityNotifier.value = resolved;
      controller.add(resolved);
    }

    /// Nur kurz vor Start / Ende / Grace-Ende — sonst reicht der Firestore-Stream.
    Duration? clockIntervalForNow(DateTime now) {
      final visibility = latestParties != null
          ? _resolveFromSnapshot(latestParties!, graceMinutes, now)
          : null;

      if (visibility != null) {
        if (!visibility.isGracePeriodOnly) {
          final untilEnd = visibility.endDate.difference(now);
          if (untilEnd.inSeconds > 0 && untilEnd.inSeconds <= 60) {
            return const Duration(seconds: 1);
          }
          return null;
        }
        final remainingGrace = visibility.graceEndsAt.difference(now);
        if (remainingGrace.inSeconds > 0 && remainingGrace.inSeconds <= 60) {
          return const Duration(seconds: 1);
        }
        return null;
      }

      final nextStart = latestParties != null
          ? _nearestUpcomingStart(latestParties!, now)
          : null;
      if (nextStart != null) {
        final untilStart = nextStart.difference(now);
        if (untilStart.inSeconds > 0 && untilStart.inSeconds <= 60) {
          return const Duration(seconds: 1);
        }
      }
      return null;
    }

    void rescheduleClock() {
      clockTimer?.cancel();
      clockTimer = null;

      final interval = clockIntervalForNow(DateTime.now());
      if (interval == null) return;

      clockTimer = Timer.periodic(interval, (_) {
        emit();
        rescheduleClock();
      });
    }

    controller = StreamController<OpenWishesVisibility?>.broadcast(
      onListen: () {
        listenerCount++;
        if (listenerCount > 1) {
          emit();
          return;
        }

        partiesSub = FirebaseFirestore.instance
            .collection('parties')
            .where('created_by', isEqualTo: djId)
            .snapshots()
            .listen((snap) {
              latestParties = snap;
              emit();
              rescheduleClock();
            });

        graceSub = GracePeriodSettingsService.streamForDj(djId).listen((m) {
          graceMinutes = m;
          emit();
          rescheduleClock();
        });

        emit();
        rescheduleClock();
      },
      onCancel: () {
        listenerCount--;
        if (listenerCount > 0) return;
        partiesSub?.cancel();
        graceSub?.cancel();
        clockTimer?.cancel();
        partiesSub = null;
        graceSub = null;
        clockTimer = null;
        _streamCache.remove(djId);
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    return controller.stream;
  }

  static String? _partyNameFromData(Map<String, dynamic> data) {
    final raw =
        (data['party_name'] ?? data['name'] ?? data['title']) as String?;
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static DateTime? _startDateFromData(Map<String, dynamic> data) {
    final ts = data['start_date'] as Timestamp?;
    return ts?.toDate();
  }

  static DateTime? _nearestUpcomingStart(
    QuerySnapshot<Map<String, dynamic>> snap,
    DateTime now,
  ) {
    DateTime? next;
    for (final doc in snap.docs) {
      final data = doc.data();
      final lifecycle = data['lifecycle_status'] as String?;
      if (lifecycle == 'finished' ||
          lifecycle == 'standby' ||
          data['finished_at'] != null) {
        continue;
      }
      final start = _startDateFromData(data);
      if (start == null || !start.isAfter(now)) continue;
      if (next == null || start.isBefore(next)) {
        next = start;
      }
    }
    return next;
  }

  static OpenWishesVisibility? _resolveFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    int graceMinutes,
    DateTime now,
  ) {
    OpenWishesVisibility? bestGrace;
    DateTime? bestGraceEnd;

    for (final doc in snap.docs) {
      final data = doc.data();
      final endDate = PartyGracePeriodHelper.partyEndDate(data);
      if (endDate == null) continue;
      final partyName = _partyNameFromData(data);
      final startDate = _startDateFromData(data);

      final manuallyHidden = PartyGracePeriodHelper.wishesManuallyHidden(data);
      final isFinished = data['lifecycle_status'] == 'finished' ||
          data['finished_at'] != null;

      // Laufende Party: geplante Startzeit erreicht, Ende noch nicht (wie Startseite).
      if (ActivePartyService.isPartyDocumentRunningNow(data, now: now)) {
        return OpenWishesVisibility(
          partyId: doc.id,
          endDate: endDate,
          graceEndsAt: PartyGracePeriodHelper.graceEndsAt(endDate, graceMinutes),
          isGracePeriodOnly: false,
          showHideWishesButton: false,
          partyName: partyName,
          startDate: startDate,
        );
      }

      if (!PartyGracePeriodHelper.shouldShowOpenWishes(
        now: now,
        endDate: endDate,
        graceMinutes: graceMinutes,
        wishesManuallyHidden: manuallyHidden,
      )) {
        continue;
      }

      // Nachlaufzeit / beendete Party — keine zukünftig geplanten Partys (Start noch nicht).
      if (now.isBefore(endDate) && !isFinished) {
        continue;
      }

      if (bestGraceEnd == null || endDate.isAfter(bestGraceEnd)) {
        bestGraceEnd = endDate;
        bestGrace = OpenWishesVisibility(
          partyId: doc.id,
          endDate: endDate,
          graceEndsAt: PartyGracePeriodHelper.graceEndsAt(endDate, graceMinutes),
          isGracePeriodOnly: true,
          showHideWishesButton: true,
          partyName: partyName,
          startDate: startDate,
        );
      }
    }

    return bestGrace;
  }

  static Future<void> hideWishesNow(String partyId) async {
    if (partyId.isEmpty) return;
    await PartySecureService.instance.updateParty(
      partyId: partyId,
      patch: const {'wishes_manually_hidden': true},
    );
    ActivePartyService.stopHeartbeat();
  }

  /// Party-ID für DJ-Wunsch-Aktionen (Offen/Gespielt/Abgelehnt): laufende Party + Nachlaufzeit.
  static String? resolveDjWishPartyId() {
    final fromVisibility = visibilityNotifier.value?.partyId;
    if (fromVisibility != null && fromVisibility.isNotEmpty) {
      return fromVisibility;
    }
    final stored = ActivePartyService.getStoredSession()?.partyId;
    if (stored != null && stored.isNotEmpty) return stored;
    return ActivePartyService.currentPartyId;
  }
}
