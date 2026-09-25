import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';
import 'guest_wish_stats_service.dart';

/// Datenklasse für User-Statistiken
class UserStatistics {
  final int totalWishes;
  final int playedWishes;

  UserStatistics({
    required this.totalWishes,
    required this.playedWishes,
  });
}

/// Datenklasse für Admin-Statistiken
class AdminStatistics {
  final int totalWishes;
  final int pendingWishes;
  final int playedWishes;
  final int rejectedWishes;
  final int notPlayedWishes;
  final int unknownWishes;
  // Diagramm-Daten (Summe muss immer totalWishes ergeben)
  final int chartPending;
  final int chartPlayed;
  final int chartRejected;
  final int chartNotPlayed;
  final int chartUnknown;

  AdminStatistics({
    required this.totalWishes,
    required this.pendingWishes,
    required this.playedWishes,
    required this.rejectedWishes,
    required this.notPlayedWishes,
    required this.unknownWishes,
    required this.chartPending,
    required this.chartPlayed,
    required this.chartRejected,
    required this.chartNotPlayed,
    required this.chartUnknown,
  });
}

/// Admin-Dashboard: Nutzerzahlen aus [users] nach Rolle und E-Mail-Verifizierung (Firestore-Feld).
class AdminUserRoleStatistics {
  final int totalUsers;
  final int djEmailVerified;
  final int djEmailUnverified;
  final int guestEmailVerified;
  final int guestEmailUnverified;

  const AdminUserRoleStatistics({
    required this.totalUsers,
    required this.djEmailVerified,
    required this.djEmailUnverified,
    required this.guestEmailVerified,
    required this.guestEmailUnverified,
  });

  static const AdminUserRoleStatistics empty = AdminUserRoleStatistics(
    totalUsers: 0,
    djEmailVerified: 0,
    djEmailUnverified: 0,
    guestEmailVerified: 0,
    guestEmailUnverified: 0,
  );
}

/// Datenklasse für DJ-Statistiken
class DJStatistics {
  final int totalWishes;
  final int chartPlayed;
  final int chartRejected;
  final int chartNotPlayed;
  final int chartDeleted;

  DJStatistics({
    required this.totalWishes,
    required this.chartPlayed,
    required this.chartRejected,
    required this.chartNotPlayed,
    required this.chartDeleted,
  });
}

/// True, wenn der User für die Admin-Statistik als „E-Mail bestätigt“ zählen soll.
///
/// - [email_verified_override] wie in der App (MainPage-Gate).
/// - [emailVerified] / [email_verified] als bool, Zahl oder String.
/// - Fehlen beide Felder: **true** (ältere Docs ohne Sync aus Auth; sonst wäre alles „offen“).
/// - Nur explizit false / 0 / „false“ zählt als unbestätigt.
bool _userDocEmailVerifiedForAdminStats(Map<String, dynamic> data) {
  if (data['email_verified_override'] == true) return true;

  bool? parseKey(String key) {
    if (!data.containsKey(key)) return null;
    final v = data[key];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s.isEmpty) return false;
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return null;
  }

  final fromCamel = parseKey('emailVerified');
  if (fromCamel != null) return fromCamel;
  final fromSnake = parseKey('email_verified');
  if (fromSnake != null) return fromSnake;

  return true;
}

String? _roleIdFromUserData(Map<String, dynamic> data) {
  final r = data['role_id'];
  if (r == null) return null;
  if (r is String) {
    final t = r.trim();
    return t.isEmpty ? null : t;
  }
  final s = r.toString().trim();
  return s.isEmpty ? null : s;
}

/// Service für das Laden von Wunsch-Statistiken
class StatisticsService {
  static const String _adminWishTotalsPath = 'admin_stats/wish_totals';

  static AdminStatistics _adminStatisticsFromWishTotals(
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return AdminStatistics(
        totalWishes: 0,
        pendingWishes: 0,
        playedWishes: 0,
        rejectedWishes: 0,
        notPlayedWishes: 0,
        unknownWishes: 0,
        chartPending: 0,
        chartPlayed: 0,
        chartRejected: 0,
        chartNotPlayed: 0,
        chartUnknown: 0,
      );
    }

    final played = (data['played'] as num?)?.toInt() ?? 0;
    final rejected = (data['rejected'] as num?)?.toInt() ?? 0;
    final notPlayed = (data['not_played'] as num?)?.toInt() ?? 0;
    final deleted = (data['deleted'] as num?)?.toInt() ?? 0;
    final pendingActive = (data['pending_active'] as num?)?.toInt() ?? 0;
    final pendingInactive = (data['pending_inactive'] as num?)?.toInt() ?? 0;
    final chartNotPlayed = notPlayed + pendingInactive;
    final total =
        played + rejected + chartNotPlayed + pendingActive + deleted;

    return AdminStatistics(
      totalWishes: total,
      pendingWishes: pendingActive,
      playedWishes: played,
      rejectedWishes: rejected,
      notPlayedWishes: chartNotPlayed,
      unknownWishes: deleted,
      chartPending: pendingActive,
      chartPlayed: played,
      chartRejected: rejected,
      chartNotPlayed: chartNotPlayed,
      chartUnknown: deleted,
    );
  }

  static DocumentReference<Map<String, dynamic>> _adminWishTotalsRef() {
    return FirebaseFirestore.instance.doc(_adminWishTotalsPath);
  }
  /// Lädt die Wünsche-Statistiken für einen normalen User (eingeloggter Gast).
  /// Primär: persistenter Zähler `guestWishesSubmittedCount` im User-Dokument.
  static Future<UserStatistics> loadUserStatistics(User user) async {
    try {
      final uid = user.uid;
      final backfilled =
          await GuestWishStatsService.instance.ensureBackfilled(uid);
      int total = backfilled;
      int played = 0;

      if (total <= 0) {
        total = await GuestWishStatsService.instance.readCount(uid);
      }

      // Gespielte Wünsche weiterhin live zählen (nur Anzeige-Hilfe, falls später genutzt).
      try {
        final wishesQuery = await WishPaths.allWishesCollectionGroup()
            .where('user_id', isEqualTo: uid)
            .get();
        if (total <= 0) {
          total = wishesQuery.docs.length;
        }
        for (final doc in wishesQuery.docs) {
          final data = doc.data();
          if (data['status'] == 'played') {
            played++;
          }
        }
      } catch (e) {
        debugLog('Fehler beim Zählen gespielter Wünsche: $e');
      }

      return UserStatistics(
        totalWishes: total < 0 ? 0 : total,
        playedWishes: played,
      );
    } catch (e) {
      debugLog('Fehler beim Laden der Wünsche-Statistiken: $e');
      return UserStatistics(
        totalWishes: 0,
        playedWishes: 0,
      );
    }
  }

  /// Vereinigt Wunsch-Docs aus Partys-Pfad und collectionGroup (dedupliziert nach Pfad).
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergeWishDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> viaParties,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> viaGroup,
  ) {
    final byPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in viaParties) {
      byPath[doc.reference.path] = doc;
    }
    for (final doc in viaGroup) {
      byPath.putIfAbsent(doc.reference.path, () => doc);
    }
    return byPath.values.toList();
  }

  /// Alle Wünsche aller DJs (nur sinnvoll mit Firestore-Admin-Rechten).
  /// Primär: alle Partys + Subcollections; zusätzlich collectionGroup (Union).
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadAllWishDocumentsForAdmin() async {
    final viaParties = await _loadAllWishDocumentsViaParties();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> viaGroup = [];
    try {
      final groupSnap = await WishPaths.allWishesCollectionGroup().get();
      viaGroup = groupSnap.docs;
    } catch (e, st) {
      debugLog('❌ Admin-Statistik collectionGroup: $e');
      debugLog('$st');
    }

    final merged = _mergeWishDocuments(viaParties, viaGroup);
    debugLog(
      '📊 Admin-Statistik: Partys=${viaParties.length}, '
      'collectionGroup=${viaGroup.length}, merged=${merged.length}',
    );
    return merged;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadAllWishDocumentsViaParties() async {
    final partiesSnap =
        await FirebaseFirestore.instance.collection('parties').get();
    final all = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final partyDoc in partiesSnap.docs) {
      try {
        final wishesSnap = await WishPaths.partyWishes(partyDoc.id).get();
        all.addAll(wishesSnap.docs);
      } catch (e) {
        debugLog(
          '⚠️ Admin-Statistik: wishes für Party ${partyDoc.id} übersprungen: $e',
        );
      }
    }

    debugLog(
      '📊 Admin-Statistik: ${all.length} Wünsche aus ${partiesSnap.docs.length} Partys',
    );
    return all;
  }

  static int _nowUnixUtc() =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  /// Party-IDs, die gerade laufen (gleiche Logik wie DJ-Startseite / Plattform-Statistik).
  static Future<Set<String>> loadCurrentlyActivePartyIds() async {
    final nowUnix = _nowUnixUtc();
    final ids = <String>{};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('parties')
          .where('lifecycle_status', isEqualTo: 'active')
          .get();
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
          if (nowUnix >= start && nowUnix < end) {
            ids.add(doc.id);
          }
          continue;
        }
        if (d['isActive'] == true) {
          ids.add(doc.id);
        }
      }
    } catch (e) {
      debugLog('StatisticsService: aktive Partys: $e');
    }
    return ids;
  }

  static bool _pendingCountsAsOpen(
    Map<String, dynamic> data,
    Set<String> activePartyIds,
  ) {
    final partyId = data['party_id'] as String?;
    if (partyId == null || partyId.isEmpty) return false;
    return activePartyIds.contains(partyId);
  }

  /// Berechnet Admin-Statistiken aus einer Liste von Dokumenten.
  /// `pending`/`open` zählen nur bei **laufenden** Partys; sonst → `not_played`
  /// (wie bei beendeter Party im DJ-Dashboard).
  static AdminStatistics _calculateAdminStatistics(
    List<QueryDocumentSnapshot> docs, {
    required Set<String> activePartyIds,
  }) {
    int total = 0;
    int pending = 0;
    int played = 0;
    int rejected = 0;
    int notPlayed = 0;
    int unknown = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      total++;

      final isDeleted = data['deleted'] as bool? ?? false;
      final status = isDeleted
          ? 'unknown'
          : (data['status'] as String?)?.trim().toLowerCase();

      if (status == 'played') {
        played++;
      } else if (status == 'rejected') {
        rejected++;
      } else if (status == 'pending' ||
          status == 'open' ||
          status == null ||
          status.isEmpty) {
        if (_pendingCountsAsOpen(data, activePartyIds)) {
          pending++;
        } else {
          notPlayed++;
        }
      } else if (status == 'not_played' ||
          status == 'notplayed' ||
          status == 'skipped') {
        notPlayed++;
      } else {
        unknown++;
      }
    }

    return AdminStatistics(
      totalWishes: total,
      pendingWishes: pending,
      playedWishes: played,
      rejectedWishes: rejected,
      notPlayedWishes: notPlayed,
      unknownWishes: unknown,
      chartPending: pending,
      chartPlayed: played,
      chartRejected: rejected,
      chartNotPlayed: notPlayed,
      chartUnknown: unknown,
    );
  }

  static Future<AdminStatistics> _calculateAdminStatisticsAsync(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final activePartyIds = await loadCurrentlyActivePartyIds();
    return _calculateAdminStatistics(docs, activePartyIds: activePartyIds);
  }

  /// Stream für globale Admin-Statistiken (gecachte Zähler, kein Vollscan).
  static Stream<AdminStatistics> loadAdminStatisticsStream() {
    return _adminWishTotalsRef().snapshots().map((snap) {
      final stats = _adminStatisticsFromWishTotals(snap.data());
      debugLog(
        '📊 StatisticsService Stream (wish_totals): total=${stats.totalWishes}',
      );
      return stats;
    }).distinct((prev, next) {
      return prev.totalWishes == next.totalWishes &&
          prev.pendingWishes == next.pendingWishes &&
          prev.playedWishes == next.playedWishes &&
          prev.rejectedWishes == next.rejectedWishes &&
          prev.notPlayedWishes == next.notPlayedWishes &&
          prev.unknownWishes == next.unknownWishes;
    }).handleError((e, st) {
      debugLog('❌ StatisticsService Admin-Stream Fehler (wish_totals): $e');
    });
  }

  /// Lädt einmalig alle [users]-Dokumente und zählt nach DJ-/Gast-role_id und E-Mail-Verifizierung.
  static Future<AdminUserRoleStatistics> loadAdminUserRoleStatistics() async {
    final djId = AppConfig.djRoleId?.trim();
    final guestId = AppConfig.guestRoleId?.trim();
    if (djId == null ||
        djId.isEmpty ||
        guestId == null ||
        guestId.isEmpty) {
      debugLog(
        '⚠️ StatisticsService: loadAdminUserRoleStatistics — djRoleId/guestRoleId fehlen, liefere leer.',
      );
      return AdminUserRoleStatistics.empty;
    }

    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').get();
      int djOk = 0, djOpen = 0, gOk = 0, gOpen = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final rid = _roleIdFromUserData(data);
        if (rid == null) continue;

        final verified = _userDocEmailVerifiedForAdminStats(data);
        if (rid == djId) {
          if (verified) {
            djOk++;
          } else {
            djOpen++;
          }
        } else if (rid == guestId) {
          if (verified) {
            gOk++;
          } else {
            gOpen++;
          }
        }
      }

      return AdminUserRoleStatistics(
        totalUsers: snap.docs.length,
        djEmailVerified: djOk,
        djEmailUnverified: djOpen,
        guestEmailVerified: gOk,
        guestEmailUnverified: gOpen,
      );
    } catch (e, st) {
      debugLog('❌ StatisticsService: loadAdminUserRoleStatistics: $e');
      debugLog('$st');
      return AdminUserRoleStatistics.empty;
    }
  }

  /// Lädt die globale Admin-Statistik EINMALIG (gecachte Zähler).
  static Future<AdminStatistics> loadAdminStatistics() async {
    try {
      debugLog('🔍 StatisticsService: loadAdminStatistics() (wish_totals)');
      final snap = await _adminWishTotalsRef().get();
      final stats = _adminStatisticsFromWishTotals(snap.data());
      debugLog(
        '=== Admin-Statistik (wish_totals) total=${stats.totalWishes} ===',
      );
      return stats;
    } catch (e, stackTrace) {
      debugLog('❌ StatisticsService: loadAdminStatistics: $e');
      debugLog('$stackTrace');
      return AdminStatistics(
        totalWishes: 0,
        pendingWishes: 0,
        playedWishes: 0,
        rejectedWishes: 0,
        notPlayedWishes: 0,
        unknownWishes: 0,
        chartPending: 0,
        chartPlayed: 0,
        chartRejected: 0,
        chartNotPlayed: 0,
        chartUnknown: 0,
      );
    }
  }

  /// Lädt DJ-Statistiken (alle Wünsche des DJs)
  static Future<DJStatistics> loadDJStatistics(User user) async {
    try {
      // Lade alle Partys des DJs
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: user.uid)
          .get();
      
      final partyIds = partiesQuery.docs.map((doc) => doc.id).toList();
      final partyCodes = partiesQuery.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['party_code'] as String?;
          })
          .where((code) => code != null && code.isNotEmpty)
          .toList();
      
      if (partyIds.isEmpty && partyCodes.isEmpty) {
        return DJStatistics(
          totalWishes: 0,
          chartPlayed: 0,
          chartRejected: 0,
          chartNotPlayed: 0,
          chartDeleted: 0,
        );
      }
      
      // Lade alle Wünsche, die zu Partys des DJs gehören
      List<QueryDocumentSnapshot> allWishes = [];
      
      // Lade Wünsche nach party_id
      if (partyIds.isNotEmpty) {
        for (final partyId in partyIds) {
          final wishesQuery = await WishPaths.partyWishes(partyId).get();
          allWishes.addAll(wishesQuery.docs);
        }
      }
      
      // Entferne Duplikate
      final uniqueWishes = <String, QueryDocumentSnapshot>{};
      for (final doc in allWishes) {
        uniqueWishes[doc.id] = doc;
      }
      
      int total = uniqueWishes.length;
      int played = 0;
      int rejected = 0;
      int notPlayed = 0;
      int deleted = 0;
      
      for (final doc in uniqueWishes.values) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        final status = data['status'] as String?;
        final isDeleted = data['deleted'] as bool? ?? false;
        
        if (isDeleted) {
          deleted++;
        } else if (status == 'played') {
          played++;
        } else if (status == 'rejected') {
          rejected++;
        } else if (status != 'pending') {
          // Alle anderen Status (außer pending) zählen als "nicht gespielt"
          notPlayed++;
        }
      }
      
      return DJStatistics(
        totalWishes: total,
        chartPlayed: played,
        chartRejected: rejected,
        chartNotPlayed: notPlayed,
        chartDeleted: deleted,
      );
    } catch (e) {
      debugLog('Fehler beim Laden der DJ-Statistiken: $e');
      return DJStatistics(
        totalWishes: 0,
        chartPlayed: 0,
        chartRejected: 0,
        chartNotPlayed: 0,
        chartDeleted: 0,
      );
    }
  }
}

