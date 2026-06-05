import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../utils/debug_log.dart';

/// Gecachte Plattform-Kennzahlen für das Admin-Dashboard (ein Firestore-Dokument).
class AdminPlatformTotals {
  final int guestsTotal;
  final int djsTotal;
  final int djsFree;
  final int djsPro;
  final int djsProLife;
  final int partiesTotal;
  final int partiesRunning;
  final DateTime? lastFullRecountAt;
  final DateTime? lastSyncAt;

  const AdminPlatformTotals({
    this.guestsTotal = 0,
    this.djsTotal = 0,
    this.djsFree = 0,
    this.djsPro = 0,
    this.djsProLife = 0,
    this.partiesTotal = 0,
    this.partiesRunning = 0,
    this.lastFullRecountAt,
    this.lastSyncAt,
  });

  static const empty = AdminPlatformTotals();

  AdminPlatformTotals copyWith({
    int? guestsTotal,
    int? djsTotal,
    int? djsFree,
    int? djsPro,
    int? djsProLife,
    int? partiesTotal,
    int? partiesRunning,
    DateTime? lastFullRecountAt,
    DateTime? lastSyncAt,
  }) {
    return AdminPlatformTotals(
      guestsTotal: guestsTotal ?? this.guestsTotal,
      djsTotal: djsTotal ?? this.djsTotal,
      djsFree: djsFree ?? this.djsFree,
      djsPro: djsPro ?? this.djsPro,
      djsProLife: djsProLife ?? this.djsProLife,
      partiesTotal: partiesTotal ?? this.partiesTotal,
      partiesRunning: partiesRunning ?? this.partiesRunning,
      lastFullRecountAt: lastFullRecountAt ?? this.lastFullRecountAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

/// Aktualisiert Admin-Kennzahlen beim Öffnen der Admin-Startseite.
///
/// - **7-Tage-Vollzählung:** ab [last_full_recount_at] im Cache-Dokument; fehlt das
///   Feld oder sind ≥ 7 Tage vergangen → alle Zähler neu (Count + DJ-Aufteilung).
/// - **Dazwischen:** nur neue User/Partys seit [last_sync_at] dazurechnen.
/// - **Laufende Partys:** bei jedem Besuch kurz neu zählen (aktueller Stand).
class AdminPlatformTotalsService {
  AdminPlatformTotalsService._();

  static const _docPath = 'admin_stats/platform_totals';
  static const _fullRecountInterval = Duration(days: 7);

  static DocumentReference<Map<String, dynamic>> get _docRef =>
      FirebaseFirestore.instance.doc(_docPath);

  static int _nowUnixUtc() =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  static bool _isGuestRole(String? roleId) =>
      AppConfig.classifyRoleId(roleId) == AppRoleKind.guest;

  static bool _isDjRole(String? roleId) =>
      AppConfig.classifyRoleId(roleId) == AppRoleKind.dj;

  /// free | pro | pro_life
  static String _djPlanBucket(Map<String, dynamic> data) {
    final proUntil = data['proUntil'] as Timestamp?;
    if (proUntil != null && proUntil.toDate().year >= 2099) {
      return 'pro_life';
    }
    if (data['isPro'] == true) return 'pro';
    final trialUntil = data['trialUntil'] as Timestamp?;
    if (trialUntil != null && trialUntil.toDate().isAfter(DateTime.now())) {
      return 'pro';
    }
    final plan = (data['planType'] as String?)?.trim().toLowerCase() ?? 'free';
    if (plan == 'pro' || plan == 'trial') return 'pro';
    return 'free';
  }

  static AdminPlatformTotals _fromDoc(Map<String, dynamic>? data) {
    if (data == null) return AdminPlatformTotals.empty;
    return AdminPlatformTotals(
      guestsTotal: (data['guests_total'] as num?)?.toInt() ?? 0,
      djsTotal: (data['djs_total'] as num?)?.toInt() ?? 0,
      djsFree: (data['djs_free'] as num?)?.toInt() ?? 0,
      djsPro: (data['djs_pro'] as num?)?.toInt() ?? 0,
      djsProLife: (data['djs_pro_life'] as num?)?.toInt() ?? 0,
      partiesTotal: (data['parties_total'] as num?)?.toInt() ?? 0,
      partiesRunning: (data['parties_running'] as num?)?.toInt() ?? 0,
      lastFullRecountAt:
          (data['last_full_recount_at'] as Timestamp?)?.toDate().toUtc(),
      lastSyncAt: (data['last_sync_at'] as Timestamp?)?.toDate().toUtc(),
    );
  }

  static Map<String, dynamic> _toFirestore(AdminPlatformTotals t) {
    return {
      'guests_total': t.guestsTotal,
      'djs_total': t.djsTotal,
      'djs_free': t.djsFree,
      'djs_pro': t.djsPro,
      'djs_pro_life': t.djsProLife,
      'parties_total': t.partiesTotal,
      'parties_running': t.partiesRunning,
      if (t.lastFullRecountAt != null)
        'last_full_recount_at': Timestamp.fromDate(t.lastFullRecountAt!),
      if (t.lastSyncAt != null)
        'last_sync_at': Timestamp.fromDate(t.lastSyncAt!),
    };
  }

  static bool _needsFullRecount(AdminPlatformTotals cached, DateTime now) {
    final last = cached.lastFullRecountAt;
    if (last == null) return true;
    return now.difference(last) >= _fullRecountInterval;
  }

  static Future<int> _countUsersWithRole(String roleId) async {
    if (roleId.isEmpty) return 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role_id', isEqualTo: roleId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugLog('AdminPlatformTotals: count role $roleId: $e');
      return 0;
    }
  }

  static Future<int> _countGuestsAllRoleIds() async {
    final ids = <String>{
      if (AppConfig.guestRoleId != null && AppConfig.guestRoleId!.isNotEmpty)
        AppConfig.guestRoleId!,
      ...AppConfig.allGuestRoleDocIds,
    };
    if (ids.isEmpty) return 0;
    var sum = 0;
    for (final id in ids) {
      sum += await _countUsersWithRole(id);
    }
    return sum;
  }

  static Future<({int total, int free, int pro, int proLife})> _countDjsBuckets() async {
    final ids = <String>{
      if (AppConfig.djRoleId != null && AppConfig.djRoleId!.isNotEmpty)
        AppConfig.djRoleId!,
      ...AppConfig.allDjRoleDocIds,
    };
    if (ids.isEmpty) {
      return (total: 0, free: 0, pro: 0, proLife: 0);
    }

    int free = 0, pro = 0, proLife = 0;
    final seen = <String>{};

    for (final roleId in ids) {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('role_id', isEqualTo: roleId)
            .get();
      } catch (e) {
        debugLog('AdminPlatformTotals: DJ query $roleId: $e');
        continue;
      }
      for (final doc in snap.docs) {
        if (!seen.add(doc.id)) continue;
        final bucket = _djPlanBucket(doc.data());
        switch (bucket) {
          case 'pro_life':
            proLife++;
            break;
          case 'pro':
            pro++;
            break;
          default:
            free++;
        }
      }
    }

    return (total: seen.length, free: free, pro: pro, proLife: proLife);
  }

  static Future<int> _countPartiesTotal() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('parties')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugLog('AdminPlatformTotals: parties count: $e');
      return 0;
    }
  }

  static Future<int> _countPartiesRunning() async {
    final nowUnix = _nowUnixUtc();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('parties')
          .where('lifecycle_status', isEqualTo: 'active')
          .get();
      var n = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['lifecycle_status'] == 'finished' ||
            d['lifecycle_status'] == 'standby' ||
            d['finished_at'] != null) {
          continue;
        }
        final start = d['start_time_posix'] as int?;
        final end = d['end_time_posix'] as int?;
        if (start != null && end != null) {
          if (nowUnix >= start && nowUnix < end) n++;
          continue;
        }
        if (d['isActive'] == true) n++;
      }
      return n;
    } catch (e) {
      debugLog('AdminPlatformTotals: parties running: $e');
      return 0;
    }
  }

  static Future<AdminPlatformTotals> _fullRecount(DateTime now) async {
    debugLog('AdminPlatformTotals: Vollzählung (7-Tage-Intervall)');
    final guests = await _countGuestsAllRoleIds();
    final dj = await _countDjsBuckets();
    final partiesTotal = await _countPartiesTotal();
    final running = await _countPartiesRunning();
    return AdminPlatformTotals(
      guestsTotal: guests,
      djsTotal: dj.total,
      djsFree: dj.free,
      djsPro: dj.pro,
      djsProLife: dj.proLife,
      partiesTotal: partiesTotal,
      partiesRunning: running,
      lastFullRecountAt: now,
      lastSyncAt: now,
    );
  }

  static Future<AdminPlatformTotals> _applyDelta(
    AdminPlatformTotals base,
    DateTime now,
  ) async {
    final since = base.lastSyncAt ?? base.lastFullRecountAt;
    if (since == null) return base;

    var guests = base.guestsTotal;
    var djsTotal = base.djsTotal;
    var djsFree = base.djsFree;
    var djsPro = base.djsPro;
    var djsProLife = base.djsProLife;
    var partiesTotal = base.partiesTotal;

    try {
      final newUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('created_at', isGreaterThan: Timestamp.fromDate(since))
          .get();
      for (final doc in newUsers.docs) {
        final data = doc.data();
        final roleId = data['role_id'] as String?;
        if (_isGuestRole(roleId)) {
          guests++;
        } else if (_isDjRole(roleId)) {
          djsTotal++;
          switch (_djPlanBucket(data)) {
            case 'pro_life':
              djsProLife++;
              break;
            case 'pro':
              djsPro++;
              break;
            default:
              djsFree++;
          }
        }
      }
    } catch (e) {
      debugLog('AdminPlatformTotals: Delta users: $e');
    }

    try {
      final newParties = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_at', isGreaterThan: Timestamp.fromDate(since))
          .get();
      partiesTotal += newParties.docs.length;
    } catch (e) {
      debugLog('AdminPlatformTotals: Delta parties: $e');
    }

    final running = await _countPartiesRunning();

    return base.copyWith(
      guestsTotal: guests,
      djsTotal: djsTotal,
      djsFree: djsFree,
      djsPro: djsPro,
      djsProLife: djsProLife,
      partiesTotal: partiesTotal,
      partiesRunning: running,
      lastSyncAt: now,
    );
  }

  /// Beim Öffnen der Admin-Startseite aufrufen (kein Dauer-Stream).
  static Future<AdminPlatformTotals> refreshOnAdminOpen() async {
    final now = DateTime.now().toUtc();
    AdminPlatformTotals cached = AdminPlatformTotals.empty;

    try {
      final doc = await _docRef.get();
      if (doc.exists) {
        cached = _fromDoc(doc.data());
      }
    } catch (e) {
      debugLog('AdminPlatformTotals: Cache lesen: $e');
    }

    AdminPlatformTotals result;
    if (_needsFullRecount(cached, now)) {
      result = await _fullRecount(now);
    } else {
      result = await _applyDelta(cached, now);
      if (result.partiesRunning != cached.partiesRunning &&
          result.lastSyncAt == cached.lastSyncAt) {
        result = result.copyWith(lastSyncAt: now);
      }
    }

    try {
      await _docRef.set(_toFirestore(result), SetOptions(merge: true));
    } catch (e) {
      debugLog('AdminPlatformTotals: Cache speichern: $e');
    }

    return result;
  }
}
