import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import '../helpers/security_helper.dart';
import '../utils/party_grace_period_helper.dart';
import 'active_party_service.dart';
import 'grace_period_settings_service.dart';
import 'user_service.dart';

/// Ergebnis der Sichtbarkeitsprüfung für die DJ-Offen-Liste.
class OpenWishesVisibility {
  const OpenWishesVisibility({
    required this.partyId,
    required this.endDate,
    required this.graceEndsAt,
    required this.isGracePeriodOnly,
    required this.showHideWishesButton,
  });

  final String partyId;
  final DateTime endDate;
  final DateTime graceEndsAt;

  /// Reguläres Party-Ende überschritten, Nachlaufzeit läuft noch.
  final bool isGracePeriodOnly;

  /// Button „Wünsche jetzt ausblenden“ anzeigen.
  final bool showHideWishesButton;
}

/// Echtzeit-Stream: welche Party offene Wünsche für den DJ zeigt (inkl. Nachlaufzeit).
class OpenWishesVisibilityService {
  static final Map<String, Stream<OpenWishesVisibility?>> _streamCache = {};

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
      if (latestParties == null) {
        controller.add(null);
        return;
      }
      controller.add(
        _resolveFromSnapshot(latestParties!, graceMinutes, DateTime.now()),
      );
    }

    void rescheduleClock() {
      clockTimer?.cancel();
      final now = DateTime.now();
      final visibility = latestParties != null
          ? _resolveFromSnapshot(latestParties!, graceMinutes, now)
          : null;

      var intervalSeconds = 60;
      if (visibility != null) {
        final remaining = visibility.graceEndsAt.difference(now).inSeconds;
        if (remaining <= 60 && remaining > 0) {
          intervalSeconds = 1;
        }
      }

      clockTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
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

      final manuallyHidden = PartyGracePeriodHelper.wishesManuallyHidden(data);
      final isFinished = data['lifecycle_status'] == 'finished' ||
          data['finished_at'] != null;

      // Laufende Party (Zeitfenster + Lifecycle) — nicht nur end_date in der Zukunft.
      if (ActivePartyService.isPartyDocumentRunningNow(data, now: now)) {
        return OpenWishesVisibility(
          partyId: doc.id,
          endDate: endDate,
          graceEndsAt: PartyGracePeriodHelper.graceEndsAt(endDate, graceMinutes),
          isGracePeriodOnly: false,
          showHideWishesButton: false,
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
        );
      }
    }

    return bestGrace;
  }

  static Future<void> hideWishesNow(String partyId) async {
    if (partyId.isEmpty) return;
    await FirebaseFirestore.instance.collection('parties').doc(partyId).set(
      SecurityHelper.sanitizeMap({'wishes_manually_hidden': true}),
      SetOptions(merge: true),
    );
  }
}
