import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import '../utils/debug_log.dart';

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
  /// Lädt die Wünsche-Statistiken für einen normalen User
  static Future<UserStatistics> loadUserStatistics(User user) async {
    try {
      // Lade alle Wünsche des Users (nach aktuellem Namen)
      final currentName = user.displayName ?? user.email?.split('@').first ?? '';
      final wishesQuery = await FirebaseFirestore.instance
          .collection('wishes')
          .where('name', isEqualTo: currentName)
          .get();

      int total = 0;
      int played = 0;

      for (final doc in wishesQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total++;
        if (data['status'] == 'played') {
          played++;
        }
      }

      return UserStatistics(
        totalWishes: total,
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

  /// Berechnet Admin-Statistiken aus einer Liste von Dokumenten
  static AdminStatistics _calculateAdminStatistics(List<QueryDocumentSnapshot> docs) {
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
      } else if (status == 'pending' || status == 'open') {
        pending++;
      } else if (status == 'not_played' || status == 'notplayed' || status == 'skipped') {
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

  /// Stream für globale Admin-Statistiken (alle Wünsche über alle Partys).
  /// Hinweis: Für Admin-Home wird bevorzugt [loadAdminStatistics] (einmaliger get-Call) genutzt.
  static Stream<AdminStatistics> loadAdminStatisticsStream() {
    return FirebaseFirestore.instance
        .collection('wishes')
        .snapshots()
        .map((snapshot) {
      debugLog('📊 StatisticsService Stream: ${snapshot.docs.length} Dokumente aktualisiert (global)');
      return _calculateAdminStatistics(snapshot.docs);
    }).distinct((prev, next) {
      return prev.totalWishes == next.totalWishes &&
          prev.pendingWishes == next.pendingWishes &&
          prev.playedWishes == next.playedWishes &&
          prev.rejectedWishes == next.rejectedWishes &&
          prev.notPlayedWishes == next.notPlayedWishes &&
          prev.unknownWishes == next.unknownWishes;
    }).handleError((e, st) {
      debugLog('❌ StatisticsService Admin-Stream Fehler (global): $e');
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

  /// Lädt die globale Admin-Statistik EINMALIG (alle Wünsche über alle Partys).
  static Future<AdminStatistics> loadAdminStatistics() async {
    try {
      debugLog('🔍 StatisticsService: Starte loadAdminStatistics()');
      
      // Prüfe, ob Firebase initialisiert ist
      try {
        final app = FirebaseFirestore.instance.app;
        debugLog('🔍 StatisticsService: Firebase App: ${app.name}');
        debugLog('🔍 StatisticsService: Firebase Project ID: ${app.options.projectId}');
        debugLog('🔍 StatisticsService: Firebase App ID: ${app.options.appId}');
      } catch (e) {
        debugLog('❌ StatisticsService: Firebase nicht initialisiert: $e');
        throw Exception('Firebase nicht initialisiert');
      }
      
      debugLog('🔍 StatisticsService: Führe globale Query auf collection("wishes").get() aus...');
      final wishesQuery = await FirebaseFirestore.instance
          .collection('wishes')
          .get();

      debugLog('✅ StatisticsService: Query erfolgreich abgeschlossen!');
      debugLog('📊 StatisticsService: Gefundene Dokumente: ${wishesQuery.docs.length} (global)');
      
      if (wishesQuery.docs.isEmpty) {
        debugLog('⚠️ StatisticsService: KEINE DOKUMENTE GEFUNDEN!');
        debugLog('⚠️ StatisticsService: Mögliche Ursachen:');
        debugLog('   1. Firestore-Regeln blockieren den Zugriff');
        debugLog('   2. Collection "wishes" ist leer');
        debugLog('   3. Paketname/SHA-1 stimmt nicht mit Firebase überein');
        debugLog('   4. App muss nach SHA-1-Hinterlegung neu gebaut werden');
      } else {
        debugLog('✅ StatisticsService: ${wishesQuery.docs.length} Dokumente gefunden');
        // Zeige erste 3 Dokumente zur Debugging
        for (int i = 0; i < wishesQuery.docs.length && i < 3; i++) {
          final doc = wishesQuery.docs[i];
          final data = doc.data() as Map<String, dynamic>;
          debugLog('   Dokument $i: ID=${doc.id}, status=${data['status']}, name=${data['name']}');
        }
      }

      // Verwende die gemeinsame Berechnungsmethode
      final stats = _calculateAdminStatistics(wishesQuery.docs);
      
      // Debug-Ausgabe um zu sehen, welche Status-Werte existieren
      debugLog('=== Admin-Statistik: Alle Wünsche ALLER DJs ===');
      debugLog('Total: ${stats.totalWishes}');
      debugLog('Pending: ${stats.pendingWishes}');
      debugLog('Played: ${stats.playedWishes}');
      debugLog('Rejected: ${stats.rejectedWishes}');
      debugLog('Not Played: ${stats.notPlayedWishes}');
      debugLog('Unknown: ${stats.unknownWishes}');

      debugLog('=== Diagramm-Daten ===');
      debugLog('Total Wünsche: ${stats.totalWishes}');
      debugLog('Pending (ORANGE): ${stats.chartPending}');
      debugLog('Gespielt (GRÜN): ${stats.chartPlayed}');
      debugLog('Abgelehnt (ROT): ${stats.chartRejected}');
      debugLog('Nicht gespielt (BLAU): ${stats.chartNotPlayed}');
      debugLog('Unbekannt (GRAU): ${stats.chartUnknown}');
      debugLog('Summe im Diagramm: ${stats.chartPending + stats.chartPlayed + stats.chartRejected + stats.chartNotPlayed + stats.chartUnknown}');

      return stats;
    } catch (e, stackTrace) {
      debugLog('❌ StatisticsService: FEHLER beim Laden der Admin-Statistiken: $e');
      debugLog('❌ StatisticsService: Stack Trace: $stackTrace');
      debugLog('❌ StatisticsService: Fehler-Typ: ${e.runtimeType}');
      
      // Prüfe spezifische Fehlertypen
      if (e.toString().contains('DEVELOPER_ERROR') || e.toString().contains('SecurityException')) {
        debugLog('⚠️ StatisticsService: DEVELOPER_ERROR erkannt!');
        debugLog('⚠️ StatisticsService: Mögliche Ursachen:');
        debugLog('   1. SHA-1 nicht in Firebase Console hinterlegt');
        debugLog('   2. App muss nach SHA-1-Hinterlegung neu gebaut werden');
        debugLog('   3. Paketname stimmt nicht mit google-services.json überein');
        debugLog('   4. google-services.json ist veraltet oder fehlt');
      }
      
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
          final wishesQuery = await FirebaseFirestore.instance
              .collection('wishes')
              .where('party_id', isEqualTo: partyId)
              .get();
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

