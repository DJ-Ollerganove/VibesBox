import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'active_party_service.dart';
import 'app_diagnostic_log_service.dart';
import 'open_wishes_visibility_service.dart';
import 'party_secure_service.dart';
import '../utils/debug_log.dart';
import '../utils/stable_device_id.dart';

/// Ergebnis beim Tippen auf den Anker (Verankern / Loslösen).
enum WishPinToggleResult {
  pinned,
  unpinned,
  limitReached,
  failed,
}

/// DJ-Reihenfolge offener Wünsche: kleine Order-Liste + Sortier-Sperre am Party-Dokument.
class OpenWishOrderService extends ChangeNotifier {
  OpenWishOrderService._();
  static final OpenWishOrderService instance = OpenWishOrderService._();

  static const Duration sortLockTimeout = Duration(minutes: 3);
  static const Duration writeDebounce = Duration(milliseconds: 450);
  static const int maxOrderKeys = 500;
  static const int maxPinnedKeys = 3;
  static const int _sortLockDeviceIdMaxLen = 128;
  static const int _orderWriteMaxAttempts = 4;
  static const Duration _orderWriteRetryDelay = Duration(milliseconds: 500);

  String? _partyId;
  String? _attachedPartyId;
  String? _reorderPartyId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _partySub;

  List<String> _serverOrderKeys = [];
  List<String> _pinnedKeys = [];
  List<String> _rawPinnedKeys = [];
  int _serverRev = 0;
  String? _lockDeviceId;
  DateTime? _lockAt;

  String? _deviceId;
  Future<String>? _deviceIdFuture;

  bool reorderExpanded = false;
  List<String>? _preDragOrderSnapshot;
  List<String>? _localOrderOverride;
  bool _reorderCommittedThisSession = false;

  final Map<String, int> _lastSeenWishCounts = {};
  Timer? _writeDebounceTimer;
  List<String>? _pendingWriteOrder;
  int _pendingWriteBaseRev = 0;
  List<String>? _pendingVoteBumpOrder;
  bool _voteBumpFlushScheduled = false;
  Map<String, List<String>> _docIdsByGroupKey = {};

  List<String> get serverOrderKeys => List.unmodifiable(_serverOrderKeys);
  List<String> get pinnedKeys => List.unmodifiable(_pinnedKeys);
  int get serverRev => _serverRev;

  bool isPinned(String groupKey) =>
      groupKey.isNotEmpty && _pinnedKeys.contains(groupKey);
  bool get isReorderExpanded => reorderExpanded;
  List<String>? get localOrderKeys => _localOrderOverride == null
      ? null
      : List<String>.from(_localOrderOverride!);

  void updateDocIdsByGroupKey(Map<String, List<String>> docIdsByGroupKey) {
    _docIdsByGroupKey = Map<String, List<String>>.from(docIdsByGroupKey);
    final resolved = _resolveStoredKeysToGroupKeys(_rawPinnedKeys);
    if (!listEquals(resolved, _pinnedKeys)) {
      _pinnedKeys = resolved;
      notifyListeners();
    }
  }

  Map<String, String> _docIdToGroupKeyMap() {
    final out = <String, String>{};
    _docIdsByGroupKey.forEach((groupKey, ids) {
      for (final id in ids) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) out[trimmed] = groupKey;
      }
    });
    return out;
  }

  String? _resolveStoredOrderKey(
    String stored,
    Map<String, Map<String, dynamic>> byKey,
    Map<String, String> docIdToGroupKey,
  ) {
    final key = stored.trim();
    if (key.isEmpty) return null;
    if (byKey.containsKey(key)) return key;
    final fromDoc = docIdToGroupKey[key];
    if (fromDoc != null && byKey.containsKey(fromDoc)) return fromDoc;
    return null;
  }

  List<String> _storageKeysForGroupOrder(List<String> groupKeys) {
    return groupKeys
        .map((groupKey) {
          final ids = _docIdsByGroupKey[groupKey];
          if (ids != null && ids.isNotEmpty) {
            final id = ids.first.trim();
            if (id.isNotEmpty) return id;
          }
          return groupKey;
        })
        .toList(growable: false);
  }

  List<String> _resolveStoredKeysToGroupKeys(List<String> stored) {
    final docToGroup = _docIdToGroupKeyMap();
    final groupKeys = _docIdsByGroupKey.keys.toSet();
    final out = <String>[];
    for (final raw in stored) {
      final key = raw.trim();
      if (key.isEmpty) continue;
      String? groupKey;
      if (groupKeys.contains(key)) {
        groupKey = key;
      } else {
        groupKey = docToGroup[key];
      }
      if (groupKey != null &&
          groupKey.isNotEmpty &&
          !out.contains(groupKey)) {
        out.add(groupKey);
      }
    }
    return out.take(maxPinnedKeys).toList(growable: false);
  }

  bool get isLockHeldByOther {
    if (_lockDeviceId == null || _lockDeviceId!.isEmpty) return false;
    if (_lockDeviceId == _deviceId) return false;
    if (_lockAt == null) return false;
    return _isSortLockFresh(_lockAt!);
  }

  bool get isLockHeldByMe =>
      _lockDeviceId != null &&
      _lockDeviceId!.isNotEmpty &&
      _lockDeviceId == _deviceId;

  bool get canStartReorder => true;

  Future<String> deviceId() {
    _deviceIdFuture ??= getStableDeviceId().then((id) {
      _deviceId = id;
      return id;
    });
    return _deviceIdFuture!;
  }

  void attachParty(String partyId) {
    if (partyId.isEmpty) {
      detachParty();
      return;
    }

    if (_partyId == partyId && _partySub != null) {
      _attachedPartyId = partyId;
      if (reorderExpanded || _localOrderOverride != null) {
        _reorderPartyId ??= partyId;
      }
      return;
    }

    _partySub?.cancel();
    _partySub = null;
    _partyId = partyId;
    _attachedPartyId = partyId;
    if (reorderExpanded || _localOrderOverride != null) {
      _reorderPartyId ??= partyId;
    } else {
      _reorderPartyId = null;
    }

    unawaited(deviceId());

    _partySub = FirebaseFirestore.instance
        .collection('parties')
        .doc(partyId)
        .snapshots()
        .listen(
      (snap) {
        final data = snap.data();
        if (data == null) return;
        _applyPartySnapshot(data);
      },
      onError: (Object e) {
        debugLog('OpenWishOrderService: Party-Stream Fehler: $e');
      },
    );
  }

  void detachParty() {
    if (reorderExpanded || _localOrderOverride != null) {
      debugLog(
        'OpenWishOrderService: detachParty übersprungen (Sortieren aktiv)',
      );
      return;
    }
    _partySub?.cancel();
    _partySub = null;
    _partyId = null;
    _attachedPartyId = null;
    _reorderPartyId = null;
    _serverOrderKeys = [];
    _pinnedKeys = [];
    _rawPinnedKeys = [];
    _serverRev = 0;
    _lockDeviceId = null;
    _lockAt = null;
    _lastSeenWishCounts.clear();
    _cancelLocalReorderSession(releaseRemoteLock: false);
    _writeDebounceTimer?.cancel();
    _pendingWriteOrder = null;
    _pendingVoteBumpOrder = null;
    _voteBumpFlushScheduled = false;
  }

  List<String> _parseOrderKeys(Object? raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => (e == null ? '' : e.toString()).trim())
        .where((e) => e.isNotEmpty)
        .take(maxOrderKeys)
        .toList();
  }

  void _applyPartySnapshot(Map<String, dynamic> data) {
    final newOrderKeys = _parseOrderKeys(data['open_wish_order']);
    final newRev = _readOpenWishOrderRev(data);
    final newPinnedKeys = _parsePinnedKeys(data['open_wish_pinned_keys']);
    _rawPinnedKeys = newPinnedKeys;
    final resolvedPinnedKeys = _resolveStoredKeysToGroupKeys(newPinnedKeys);

    var newLockDeviceId =
        data['open_wish_sort_lock_device_id'] is String
            ? (data['open_wish_sort_lock_device_id'] as String).trim()
            : null;
    var newLockAt = data['open_wish_sort_lock_at'] is Timestamp
        ? (data['open_wish_sort_lock_at'] as Timestamp).toDate()
        : null;

    if (newLockDeviceId != null && newLockAt != null) {
      final lockAge = DateTime.now().difference(newLockAt);
      if (lockAge.isNegative || lockAge >= sortLockTimeout) {
        newLockDeviceId = null;
        newLockAt = null;
      }
    }

    final orderChanged = !listEquals(_serverOrderKeys, newOrderKeys);
    final pinnedChanged = !listEquals(_pinnedKeys, resolvedPinnedKeys);
    final revChanged = newRev != _serverRev;
    final lockChanged =
        _lockDeviceId != newLockDeviceId || _lockAt != newLockAt;

    if (_localOrderOverride == null &&
        (orderChanged || revChanged || pinnedChanged)) {
      _cancelPendingOrderWrites();
      if (orderChanged) {
        _lastSeenWishCounts.clear();
      }
    }

    _serverOrderKeys = newOrderKeys;
    _serverRev = newRev;
    _pinnedKeys = resolvedPinnedKeys;
    _lockDeviceId = newLockDeviceId;
    _lockAt = newLockAt;

    if (_localOrderOverride == null &&
        (orderChanged || pinnedChanged || revChanged || lockChanged)) {
      notifyListeners();
    }
  }

  /// Gruppenliste (`key` pro Eintrag) in Anzeige-Reihenfolge bringen.
  List<Map<String, dynamic>> orderedGroups(
    List<Map<String, dynamic>> defaultGroupedList, {
    bool applyVoteBumps = true,
  }) {
    final byKey = <String, Map<String, dynamic>>{
      for (final g in defaultGroupedList)
        if ((g['key'] as String?)?.isNotEmpty == true) g['key'] as String: g,
    };
    final docIdToGroupKey = _docIdToGroupKeyMap();

    final defaultKeys = defaultGroupedList
        .map((g) => g['key'] as String)
        .where((k) => k.isNotEmpty)
        .toList();

    var order = <String>[];

    final baseOrder = _localOrderOverride ??
        (_serverOrderKeys.isNotEmpty ? _serverOrderKeys : const <String>[]);

    for (final key in baseOrder) {
      final resolved = _resolveStoredOrderKey(key, byKey, docIdToGroupKey);
      if (resolved != null && !order.contains(resolved)) {
        order.add(resolved);
      }
    }
    final newKeys = defaultKeys.where((k) => !order.contains(k)).toList();
    if (newKeys.isNotEmpty) {
      final pinnedSet = _pinnedKeys.toSet();
      order = order.where((k) => !pinnedSet.contains(k)).toList();
      final newUnpinned =
          newKeys.where((k) => !pinnedSet.contains(k)).toList(growable: false);
      order = [...newUnpinned, ...order];
    }

    final pinned = _pinnedKeys
        .where((k) => byKey.containsKey(k))
        .toList(growable: false);
    final pinnedSet = pinned.toSet();

    var unpinnedOrder = order.where((k) => !pinnedSet.contains(k)).toList();

    if (applyVoteBumps && !reorderExpanded && _serverOrderKeys.isEmpty) {
      final beforeBump = List<String>.from(unpinnedOrder);
      unpinnedOrder = _applyVoteBumps(unpinnedOrder, byKey);
      if (_partyId != null &&
          _localOrderOverride == null &&
          !listEquals(beforeBump, unpinnedOrder)) {
        _queueVoteBumpPersist(
          pinned: pinned,
          unpinnedOrder: unpinnedOrder,
          defaultKeys: defaultKeys,
        );
      }
    }

    final merged = <String>[...pinned, ...unpinnedOrder];
    return merged.map((k) => byKey[k]!).whereType<Map<String, dynamic>>().toList();
  }

  /// Verankerte Gruppen immer vorne, Rest in [keys]-Reihenfolge.
  List<String> orderWithPinsFirst(List<String> keys) {
    final pinned = _pinnedKeys.where((k) => keys.contains(k)).toList();
    final pinnedSet = pinned.toSet();
    final rest = keys.where((k) => !pinnedSet.contains(k)).toList();
    return [...pinned, ...rest];
  }

  List<String> _applyVoteBumps(
    List<String> order,
    Map<String, Map<String, dynamic>> byKey,
  ) {
    final bumped = <String>[];
    final rest = <String>[];

    for (final key in order) {
      final data = byKey[key]?['data'];
      final count = _wishCountFromGroupData(data);
      final prev = _lastSeenWishCounts[key] ?? count;
      _lastSeenWishCounts[key] = count;

      if (count > prev && prev > 0) {
        bumped.add(key);
      } else {
        rest.add(key);
      }
    }

    return [...bumped, ...rest];
  }

  int _wishCountFromGroupData(Object? data) {
    if (data is! Map<String, dynamic>) return 1;
    final wtc = data['wish_total_count'];
    if (wtc is int && wtc >= 1) return wtc;
    final cal = data['createdAt_list'];
    if (cal is List && cal.isNotEmpty) return cal.length;
    final fsDup = data['firestore_duplicate_count'];
    if (fsDup is int && fsDup >= 0) return fsDup + 1;
    final dc = data['duplicate_count'];
    if (dc is int && dc >= 0) return dc + 1;
    return 1;
  }

  void _queueVoteBumpPersist({
    required List<String> pinned,
    required List<String> unpinnedOrder,
    required List<String> defaultKeys,
  }) {
    final merged = _mergedOrderKeys(
      pinned: pinned,
      unpinnedOrder: unpinnedOrder,
      defaultKeys: defaultKeys,
    );
    if (listEquals(_storageKeysForGroupOrder(merged), _serverOrderKeys)) return;
    _pendingVoteBumpOrder = _storageKeysForGroupOrder(merged);
    _scheduleVoteBumpFlush();
  }

  List<String> _mergedOrderKeys({
    required List<String> pinned,
    required List<String> unpinnedOrder,
    required List<String> defaultKeys,
  }) {
    final merged = <String>[...pinned, ...unpinnedOrder];
    final seen = merged.toSet();
    final missing = <String>[];
    for (final k in defaultKeys) {
      if (!seen.contains(k)) {
        missing.add(k);
        seen.add(k);
      }
    }
    if (missing.isNotEmpty) {
      merged.insertAll(pinned.length, missing);
    }
    return merged;
  }

  void _scheduleVoteBumpFlush() {
    if (_voteBumpFlushScheduled) return;
    _voteBumpFlushScheduled = true;
    scheduleMicrotask(() {
      _voteBumpFlushScheduled = false;
      flushPendingVoteBumpPersist();
    });
  }

  /// Nach UI-Build: Vote-Bump-Reihenfolge persistieren (nicht synchron im Build).
  void flushPendingVoteBumpPersist() {
    if (reorderExpanded || _reorderCommittedThisSession) return;
    final order = _pendingVoteBumpOrder;
    if (order == null || _partyId == null) return;
    _pendingVoteBumpOrder = null;
    if (listEquals(order, _serverOrderKeys)) return;
    scheduleDebouncedWrite(order);
  }

  /// Vote-Bump-Debounce abbrechen — vor manuellem Sortieren, damit kein paralleler Write.
  void _cancelPendingOrderWrites() {
    _writeDebounceTimer?.cancel();
    _writeDebounceTimer = null;
    _pendingWriteOrder = null;
    _pendingVoteBumpOrder = null;
    _voteBumpFlushScheduled = false;
  }

  Future<bool> _hasConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty) return true;
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static String _normalizeSortLockDeviceId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.length <= _sortLockDeviceIdMaxLen) return trimmed;
    return trimmed.substring(0, _sortLockDeviceIdMaxLen);
  }

  static bool _isSortLockFresh(DateTime lockAt) {
    final age = DateTime.now().difference(lockAt);
    if (age.isNegative) return false;
    return age < sortLockTimeout;
  }

  static bool _isRetryableFirestoreError(FirebaseException e) {
    return e.code == 'aborted' ||
        e.code == 'deadline-exceeded' ||
        e.code == 'unavailable' ||
        e.code == 'resource-exhausted' ||
        e.code == 'failed-precondition';
  }

  /// Legacy-Party-Felder kürzen, damit [isSafePartyData] Updates nicht blockiert
  /// (z. B. lange Android-Fingerprints in active_recognition_device).
  Map<String, dynamic> _legacyPartyFieldFixes(Map<String, dynamic> data) {
    final fixes = <String, dynamic>{};
    for (final field in [
      'active_recognition_device',
      'open_wish_sort_lock_device_id',
    ]) {
      final raw = data[field];
      if (raw is! String) continue;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        fixes[field] = null;
      } else if (trimmed.length > _sortLockDeviceIdMaxLen) {
        fixes[field] = trimmed.substring(0, _sortLockDeviceIdMaxLen);
      }
    }
    return fixes;
  }

  int _readOpenWishOrderRev(Map<String, dynamic> data) {
    final rev = data['open_wish_order_rev'];
    if (rev is int) return rev;
    if (rev is num) return rev.round().clamp(0, 1000000);
    return 0;
  }

  Map<String, dynamic> _buildOrderWritePatch({
    required Map<String, dynamic> existing,
    required List<String> orderList,
  }) {
    final rev = _readOpenWishOrderRev(existing);
    return <String, dynamic>{
      ..._legacyPartyFieldFixes(existing),
      'open_wish_order': orderList,
      'open_wish_order_rev': rev + 1,
    };
  }

  Future<void> _persistOrderPatch({
    required String partyId,
    required Map<String, dynamic> patch,
  }) async {
    await PartySecureService.instance.updateParty(
      partyId: partyId,
      patch: patch,
    );
  }

  Future<bool> _writePartyOrderFields({
    required String partyId,
    required Map<String, dynamic> existing,
    required List<String> orderList,
  }) async {
    final rev = _readOpenWishOrderRev(existing);
    final patch = _buildOrderWritePatch(
      existing: existing,
      orderList: orderList,
    );
    await _persistOrderPatch(partyId: partyId, patch: patch);
    _serverOrderKeys = List<String>.from(orderList);
    _serverRev = rev + 1;
    return true;
  }

  Future<bool> acquireLock() async => true;

  Future<void> releaseLock({bool force = false}) async {}

  String? _resolvePartyIdForWrite() {
    final direct = _partyId;
    if (direct != null && direct.isNotEmpty) return direct;
    final reorder = _reorderPartyId;
    if (reorder != null && reorder.isNotEmpty) return reorder;
    final attached = _attachedPartyId;
    if (attached != null && attached.isNotEmpty) return attached;
    final fromVisibility = OpenWishesVisibilityService.resolveDjWishPartyId();
    if (fromVisibility != null && fromVisibility.isNotEmpty) {
      return fromVisibility;
    }
    final stored = ActivePartyService.getStoredSession()?.partyId;
    if (stored != null && stored.isNotEmpty) return stored;
    final heartbeat = ActivePartyService.currentPartyId;
    if (heartbeat != null && heartbeat.isNotEmpty) return heartbeat;
    return null;
  }

  void beginReorderSession(List<String> currentOrderKeys) {
    _cancelPendingOrderWrites();
    _reorderPartyId = _resolvePartyIdForWrite();
    _preDragOrderSnapshot = List<String>.from(currentOrderKeys);
    _localOrderOverride = List<String>.from(currentOrderKeys);
    reorderExpanded = true;
    _reorderCommittedThisSession = false;
    _reorderIdleTimer?.cancel();
    _reorderIdleTimer = Timer(const Duration(seconds: 45), () {
      if (reorderExpanded && !_reorderCommittedThisSession) {
        cancelReorderSession();
      }
    });
    notifyListeners();
  }

  Timer? _reorderIdleTimer;

  void _cancelLocalReorderSession({required bool releaseRemoteLock}) {
    _reorderIdleTimer?.cancel();
    _reorderIdleTimer = null;
    reorderExpanded = false;
    _localOrderOverride = null;
    _preDragOrderSnapshot = null;
    _reorderCommittedThisSession = false;
    _reorderPartyId = null;
    if (releaseRemoteLock) {
      unawaited(releaseLock());
    }
    notifyListeners();
  }

  void cancelReorderSession() {
    _cancelLocalReorderSession(releaseRemoteLock: true);
  }

  /// Long-Press beendet ohne Bewegung → kein Expand, keine Änderung.
  void onLongPressEndedWithoutDrag() {
    if (reorderExpanded && !_reorderCommittedThisSession) {
      _localOrderOverride = _preDragOrderSnapshot != null
          ? List<String>.from(_preDragOrderSnapshot!)
          : null;
      _cancelLocalReorderSession(releaseRemoteLock: true);
    }
  }

  void applyLocalReorder(int oldIndex, int newIndex) {
    final list = _localOrderOverride;
    if (list == null) return;
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= list.length ||
        newIndex >= list.length) {
      return;
    }
    if (oldIndex < newIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _resetReorderIdleTimer();
    notifyListeners();
  }

  /// Setzt [key] direkt vor [insertIndex] (0 = Listenanfang, length = Ende).
  void applyLocalInsertAt(String key, int insertIndex) {
    final list = _localOrderOverride;
    if (list == null) return;
    final oldIndex = list.indexOf(key);
    if (oldIndex < 0) return;
    var target = insertIndex.clamp(0, list.length);
    if (oldIndex < target) target -= 1;
    if (oldIndex == target) return;
    final item = list.removeAt(oldIndex);
    target = target.clamp(0, list.length);
    list.insert(target, item);
    _resetReorderIdleTimer();
    notifyListeners();
  }

  void _resetReorderIdleTimer() {
    if (!reorderExpanded || _reorderCommittedThisSession) return;
    _reorderIdleTimer?.cancel();
    _reorderIdleTimer = Timer(const Duration(seconds: 45), () {
      if (reorderExpanded && !_reorderCommittedThisSession) {
        cancelReorderSession();
      }
    });
  }

  Future<bool> commitReorder({
    required List<String> finalOrderKeys,
    required String droppedGroupKey,
    String? partyIdOverride,
  }) async {
    _reorderCommittedThisSession = true;
    _cancelPendingOrderWrites();

    final partyId = (partyIdOverride != null && partyIdOverride.isNotEmpty)
        ? partyIdOverride
        : _resolvePartyIdForWrite();
    if (partyId == null || partyId.isEmpty) {
      debugLog('OpenWishOrderService: commitReorder ohne Party-ID');
      _localOrderOverride = _preDragOrderSnapshot != null
          ? List<String>.from(_preDragOrderSnapshot!)
          : null;
      _cancelLocalReorderSession(releaseRemoteLock: true);
      return false;
    }
    _partyId = partyId;
    _attachedPartyId = partyId;
    _reorderPartyId = partyId;

    final normalized = orderWithPinsFirst(finalOrderKeys);
    _localOrderOverride = List<String>.from(normalized);
    _pendingWriteOrder = _storageKeysForGroupOrder(normalized);
    _pendingWriteBaseRev = _serverRev;

    final ok = await _flushPendingWrite(partyIdOverride: partyId);
    if (!ok) {
      _localOrderOverride = _preDragOrderSnapshot != null
          ? List<String>.from(_preDragOrderSnapshot!)
          : null;
      _cancelLocalReorderSession(releaseRemoteLock: true);
      return false;
    }

    reorderExpanded = false;
    _localOrderOverride = null;
    _preDragOrderSnapshot = null;
    _reorderIdleTimer?.cancel();
    _reorderIdleTimer = null;
    await releaseLock();
    notifyListeners();
    return true;
  }

  Future<bool> _flushPendingWrite({String? partyIdOverride}) async {
    final partyId = partyIdOverride ?? _resolvePartyIdForWrite();
    final order = _pendingWriteOrder;
    if (partyId == null || partyId.isEmpty || order == null) {
      debugLog(
        'OpenWishOrderService: _flushPendingWrite ohne party/order '
        '(party=$partyId, order=${order?.length})',
      );
      return false;
    }

    final ref = FirebaseFirestore.instance.collection('parties').doc(partyId);
    final orderList = order.take(maxOrderKeys).toList();

    Object? lastError;
    for (var attempt = 1; attempt <= _orderWriteMaxAttempts; attempt++) {
      try {
        final snap = await ref.get();
        if (!snap.exists) {
          debugLog('OpenWishOrderService: Party-Dokument fehlt: $partyId');
          return false;
        }
        final data = snap.data() ?? {};
        final currentRev = _readOpenWishOrderRev(data);
        if (currentRev > _pendingWriteBaseRev) {
          debugLog(
            'OpenWishOrderService: _flushPendingWrite übersprungen '
            '(Server-Rev $currentRev > Basis $_pendingWriteBaseRev)',
          );
          _pendingWriteOrder = null;
          return false;
        }

        await _writePartyOrderFields(
          partyId: partyId,
          existing: data,
          orderList: orderList,
        );
        _serverOrderKeys = List<String>.from(orderList);
        _pendingWriteOrder = null;
        _partyId = partyId;
        _attachedPartyId = partyId;
        return true;
      } on FirebaseException catch (e) {
        lastError = e;
        debugLog(
          'OpenWishOrderService: Reihenfolge speichern Versuch '
          '$attempt/$_orderWriteMaxAttempts (party=$partyId): ${e.code} ${e.message}',
        );
        if (attempt < _orderWriteMaxAttempts &&
            _isRetryableFirestoreError(e)) {
          await Future.delayed(_orderWriteRetryDelay);
          continue;
        }
        break;
      } catch (e) {
        lastError = e;
        debugLog(
          'OpenWishOrderService: Reihenfolge speichern Versuch '
          '$attempt/$_orderWriteMaxAttempts (party=$partyId): $e',
        );
        if (attempt < _orderWriteMaxAttempts) {
          await Future.delayed(_orderWriteRetryDelay);
          continue;
        }
        break;
      }
    }

    diagLog(
      'ORDER',
      'Reihenfolge speichern fehlgeschlagen (party=$partyId): $lastError',
    );
    return false;
  }

  void scheduleDebouncedWrite(List<String> orderKeys) {
    _pendingWriteOrder = _storageKeysForGroupOrder(orderKeys);
    _pendingWriteBaseRev = _serverRev;
    _writeDebounceTimer?.cancel();
    _writeDebounceTimer = Timer(writeDebounce, () {
      unawaited(_flushPendingWrite());
    });
  }

  static int pageForGroupIndex(int indexInList, int itemsPerPage) {
    if (indexInList < 0 || itemsPerPage <= 0) return 1;
    return (indexInList ~/ itemsPerPage) + 1;
  }

  List<String> _parsePinnedKeys(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(maxPinnedKeys)
        .toList();
  }

  /// Verankern (Platz 1) oder Verankerung aufheben. Max. [maxPinnedKeys] Gruppen.
  Future<WishPinToggleResult> togglePin(String groupKey) async {
    final partyId = _resolvePartyIdForWrite();
    final key = groupKey.trim();
    if (partyId == null || partyId.isEmpty || key.isEmpty) {
      debugLog(
        'OpenWishOrderService: togglePin ohne Party/Key '
        '(party=$partyId, key=$key)',
      );
      return WishPinToggleResult.failed;
    }
    if (!await _hasConnectivity()) {
      return WishPinToggleResult.failed;
    }

    try {
      final ref =
          FirebaseFirestore.instance.collection('parties').doc(partyId);
      final snap = await ref.get();
      if (!snap.exists) {
        debugLog('OpenWishOrderService: togglePin Party fehlt: $partyId');
        return WishPinToggleResult.failed;
      }

      final data = snap.data() ?? {};
      var pinGroupKeys = List<String>.from(_pinnedKeys);

      late final WishPinToggleResult result;
      if (pinGroupKeys.contains(key)) {
        pinGroupKeys.remove(key);
        result = WishPinToggleResult.unpinned;
      } else {
        if (pinGroupKeys.length >= maxPinnedKeys) {
          return WishPinToggleResult.limitReached;
        }
        pinGroupKeys.remove(key);
        pinGroupKeys.insert(0, key);
        result = WishPinToggleResult.pinned;
      }

      final storagePins = _storageKeysForGroupOrder(pinGroupKeys);

      final patch = <String, dynamic>{
        'open_wish_pinned_keys': storagePins,
      };

      await PartySecureService.instance.updateParty(
        partyId: partyId,
        patch: patch,
      );

      _partyId = partyId;
      _attachedPartyId = partyId;
      _rawPinnedKeys = List<String>.from(storagePins);
      _pinnedKeys = List<String>.from(pinGroupKeys);
      notifyListeners();
      return result;
    } catch (e) {
      debugLog('OpenWishOrderService: togglePin fehlgeschlagen: $e');
      return WishPinToggleResult.failed;
    }
  }
}
