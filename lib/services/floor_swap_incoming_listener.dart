import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_navigator_keys.dart';
import '../models/floor_swap_request_model.dart';
import '../models/venue_floor.dart';
import '../services/floor_swap_service.dart';
import '../services/venue_service.dart';
import '../utils/debug_log.dart';
import '../widgets/floor_swap_dialogs.dart';

/// Zeigt eingehende Floor-Tausch-Anfragen als Dialog (DJ-App).
class FloorSwapIncomingListener {
  FloorSwapIncomingListener._();

  static final FloorSwapIncomingListener instance =
      FloorSwapIncomingListener._();

  StreamSubscription<List<FloorSwapRequestModel>>? _subscription;
  final Set<String> _handledRequestIds = {};
  String? _activeDjId;

  void start(String? djId) {
    if (djId == null || djId.isEmpty) {
      stop();
      return;
    }
    if (_activeDjId == djId && _subscription != null) return;
    stop();
    _activeDjId = djId;
    _subscription =
        FloorSwapService.instance.watchIncomingPending(djId).listen(
      (requests) {
        unawaited(_onRequests(requests));
      },
      onError: (e) => debugLog('⚠️ FloorSwapIncomingListener: $e'),
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _activeDjId = null;
  }

  Future<void> _onRequests(List<FloorSwapRequestModel> requests) async {
    for (final request in requests) {
      if (_handledRequestIds.contains(request.id)) continue;
      _handledRequestIds.add(request.id);

      final ctx = appRootNavigatorKey.currentContext;
      if (ctx == null) continue;

      var floors = <VenueFloor>[];
      try {
        final venue = await VenueService().getVenueById(request.venueId);
        floors = venue?.floors ?? <VenueFloor>[];
      } catch (_) {}

      if (!ctx.mounted) continue;
      await showFloorSwapIncomingDialog(
        context: ctx,
        requestId: request.id,
        fromDjId: request.fromDjId,
        yourFloorKey: request.toFloorKey,
        theirFloorKey: request.fromFloorKey,
        venueFloors: floors,
      );
    }
  }

  void resetShown() {
    _handledRequestIds.clear();
  }
}

void syncFloorSwapIncomingListener() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    FloorSwapIncomingListener.instance.stop();
    return;
  }
  FloorSwapIncomingListener.instance.start(uid);
}
