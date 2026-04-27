import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import 'user_service.dart';
import '../utils/debug_log.dart';

class DjDashboardStatistics {
  final int totalWishes;
  final int chartPlayed;
  final int chartRejected;
  final int chartOpen;
  final int chartDeleted;

  const DjDashboardStatistics({
    required this.totalWishes,
    required this.chartPlayed,
    required this.chartRejected,
    required this.chartOpen,
    required this.chartDeleted,
  });
}

/// Lädt DJ-Statistiken strikt gefiltert nach `wishes.djId == currentUserId`
/// (Sicherheitsanforderung: DJs dürfen nie System-/Fremddaten sehen).
class DjDashboardStatisticsService {
  /// Berechnet die effektive DJ-ID
  /// Wenn Admin eingeloggt ist, verwendet adminDjId (rtJXMTULzTPUz0xtdQOw9Jm8SGD3)
  /// Sonst die übergebene djId oder die aktuelle User-ID
  static String _getEffectiveDjId(String? djId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return djId ?? '';
    }
    
    final current = UserService().currentUser.value;
    final isAdmin = current != null && current.id == user.uid && AppConfig.isAdminRole(current);
    
    // Wenn Admin: Verwende adminDjId, unabhängig von der übergebenen djId
    if (isAdmin && AppConfig.adminDjId != null) {
      debugLog('🔧 DjDashboardStatisticsService: Admin erkannt, erzwinge adminDjId: ${AppConfig.adminDjId}');
      return AppConfig.adminDjId!;
    }
    
    // Normaler User: Verwende übergebene djId oder User-ID
    return djId ?? user.uid;
  }
  
  static Future<DjDashboardStatistics> loadForDj({
    required String djId,
  }) async {
    if (djId.isEmpty) {
      return const DjDashboardStatistics(
        totalWishes: 0,
        chartPlayed: 0,
        chartRejected: 0,
        chartOpen: 0,
        chartDeleted: 0,
      );
    }

    try {
      // Security: Wünsche haben party_id, nicht djId. Nur Partys des DJs (created_by) laden, dann wishes pro party_id.
      final effectiveDjId = _getEffectiveDjId(djId);
      debugLog('DEBUG STATS: Abfrage läuft für DJ-ID: $effectiveDjId (adminDjId: ${AppConfig.adminDjId})');

      final partiesSnapshot = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: effectiveDjId)
          .get();
      final partyIds = partiesSnapshot.docs.map((d) => d.id).toList();
      if (partyIds.isEmpty) {
        return const DjDashboardStatistics(
          totalWishes: 0,
          chartPlayed: 0,
          chartRejected: 0,
          chartOpen: 0,
          chartDeleted: 0,
        );
      }

      // Firestore 'in' ist auf 30 Werte begrenzt – bei vielen Partys in Batches
      const chunkSize = 30;
      int total = 0, played = 0, rejected = 0, open = 0, deleted = 0;
      for (var i = 0; i < partyIds.length; i += chunkSize) {
        final chunk = partyIds.skip(i).take(chunkSize).toList();
        final wishesQuery = await FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', whereIn: chunk)
            .get();
        for (final doc in wishesQuery.docs) {
          final data = doc.data();
          total++;
          final isDeleted = data['deleted'] as bool? ?? false;
          if (isDeleted) {
            deleted++;
            continue;
          }
          final status = data['status'] as String?;
          if (status == 'played') {
            played++;
          } else if (status == 'rejected') {
            rejected++;
          } else {
            open++;
          }
        }
      }

      return DjDashboardStatistics(
        totalWishes: total,
        chartPlayed: played,
        chartRejected: rejected,
        chartOpen: open,
        chartDeleted: deleted,
      );
    } catch (_) {
      return const DjDashboardStatistics(
        totalWishes: 0,
        chartPlayed: 0,
        chartRejected: 0,
        chartOpen: 0,
        chartDeleted: 0,
      );
    }
  }
}


