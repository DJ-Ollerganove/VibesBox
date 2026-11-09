import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Dieselben Felder wie `MusicSearchRules` in der App.
/// Quelle: `admin_config/music_search`.
class MusicSearchRules {
  const MusicSearchRules({
    required this.enabled,
    required this.applyFilters,
    required this.maxCount,
    required this.kiMax,
    required this.steps,
  });

  static const fallback = MusicSearchRules(
    enabled: true,
    applyFilters: true,
    maxCount: 10,
    kiMax: 10,
    steps: <String>['played_after', 'recommended', 'ki'],
  );

  static const knownSteps = <String>{'played_after', 'recommended', 'ki'};

  final bool enabled;
  final bool applyFilters;
  final int maxCount;
  final int kiMax;
  final List<String> steps;

  String get fingerprint =>
      '$enabled|$applyFilters|$maxCount|$kiMax|${steps.join(',')}';

  static MusicSearchRules parse(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return fallback;
    final enabled = data['enabled'] != false;
    final applyFilters = data['apply_filters'] != false;
    final maxCount = _clampCount(data['max_count'], fallback: 10);
    final kiMax = _clampCount(data['ki_max'], fallback: 10);
    final raw = data['steps'];
    if (raw is! List) {
      return MusicSearchRules(
        enabled: enabled,
        applyFilters: applyFilters,
        maxCount: maxCount,
        kiMax: kiMax,
        steps: fallback.steps,
      );
    }
    final steps = <String>[];
    for (final item in raw) {
      String id = '';
      var on = true;
      if (item is String) {
        id = item.trim();
      } else if (item is Map) {
        id = (item['id'] ?? '').toString().trim();
        on = item['enabled'] != false;
      }
      if (!knownSteps.contains(id) || !on || steps.contains(id)) continue;
      steps.add(id);
    }
    return MusicSearchRules(
      enabled: enabled,
      applyFilters: applyFilters,
      maxCount: maxCount,
      kiMax: kiMax,
      steps: steps.isEmpty ? fallback.steps : steps,
    );
  }

  static int _clampCount(Object? raw, {required int fallback}) {
    final n = raw is int
        ? raw
        : raw is num
            ? raw.round()
            : int.tryParse('$raw');
    if (n == null) return fallback;
    if (n < 1) return 1;
    if (n > 10) return 10;
    return n;
  }
}

class MusicSearchRulesStore {
  MusicSearchRulesStore._();

  static final MusicSearchRulesStore instance = MusicSearchRulesStore._();

  MusicSearchRules _current = MusicSearchRules.fallback;
  Future<void>? _start;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _fromServer = false;

  MusicSearchRules get current => _current;

  Future<void> ensureReady() {
    return start().timeout(const Duration(seconds: 2), onTimeout: () {});
  }

  Future<void> start() {
    return _start ??= _listen();
  }

  Future<void> _listen() async {
    final doc = FirebaseFirestore.instance
        .collection('admin_config')
        .doc('music_search');
    _sub ??= doc.snapshots().listen((snap) {
      if (snap.metadata.isFromCache && _fromServer) return;
      _current = MusicSearchRules.parse(snap.data());
    }, onError: (_) {});
    try {
      final snap = await doc.get(const GetOptions(source: Source.server));
      _fromServer = true;
      _current = MusicSearchRules.parse(snap.data());
    } catch (_) {}
  }
}
