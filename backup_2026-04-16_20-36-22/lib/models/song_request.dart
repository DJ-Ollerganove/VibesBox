import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/string_utils.dart';
import '../utils/debug_log.dart';

/// Modell für einen Song-Wunsch
/// Enthält alle Felder eines Wunsch-Dokuments aus der Firebase wishes-Collection
/// Unabhängig von Firebase-Funktionalität, damit Pages passiv Daten empfangen können
class SongRequest {
  final String id;
  final String? title;
  final String? song; // Alternative zu title
  final String? artist;
  final String status; // 'pending', 'played', 'rejected', 'not_played', etc.
  final String? partyId;
  final String? djId;
  final String? djCode;
  final Timestamp? createdAt;
  final String? name;
  final List<String>? requestedBy;
  final Map<String, bool>? isRegisteredUsers;
  final List<Map<String, dynamic>>? greetings;
  final String? greeting;
  final bool? isDuplicate;
  final int? duplicateCount;
  final Timestamp? playedAt;
  final Timestamp? recognizedAt;
  final Timestamp? statusChangedAt;
  final Timestamp? rejectedAt;
  final String? statusReason;
  final bool? deleted;
  final bool? autoRejectedByBlock;
  final bool? autoRecognized;
  final String? originalWishId;
  final String? userId; // user_id aus Firebase
  final String? clientId; // client_id aus Firebase
  final bool? isSeen; // Read-Status: false = ungelesen (weißer Rahmen), true = gelesen (hellblauer Rahmen)
  final bool? isFavorite; // Favoriten-Markierung
  final bool? isDjWish; // Von DJ hinzugefügter Wunsch

  SongRequest({
    required this.id,
    this.title,
    this.song,
    this.artist,
    required this.status,
    this.partyId,
    this.djId,
    this.djCode,
    this.createdAt,
    this.name,
    this.requestedBy,
    this.isRegisteredUsers,
    this.greetings,
    this.greeting,
    this.isDuplicate,
    this.duplicateCount,
    this.playedAt,
    this.recognizedAt,
    this.statusChangedAt,
    this.rejectedAt,
    this.statusReason,
    this.deleted,
    this.autoRejectedByBlock,
    this.autoRecognized,
    this.originalWishId,
    this.userId,
    this.clientId,
    this.isSeen,
    this.isFavorite,
    this.isDjWish,
  });

  /// Hilfsmethode: Parst Timestamp aus dynamic (unterstützt played_at/playedAt, rejected_at/rejectedAt)
  static Timestamp? _parseTimestamp(dynamic value) {
    return value is Timestamp ? value : null;
  }

  /// Erstellt ein SongRequest aus einem QueryDocumentSnapshot
  /// Null-Safe: Alle Felder sind optional und werden sicher gecastet
  factory SongRequest.fromDocument(QueryDocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      
      // Sichere Typ-Konvertierung für duration_ms (int oder double)
      int? durationMs;
      final durationMsValue = data['duration_ms'];
      if (durationMsValue != null) {
        if (durationMsValue is int) {
          durationMs = durationMsValue;
        } else if (durationMsValue is double) {
          durationMs = durationMsValue.toInt();
        } else if (durationMsValue is String) {
          durationMs = int.tryParse(durationMsValue);
        }
      }
      
      // Sichere Liste-Konvertierung für requested_by
      List<String>? requestedByList;
      try {
        final requestedByValue = data['requested_by'];
        if (requestedByValue != null && requestedByValue is List) {
          requestedByList = requestedByValue
              .map((e) => e?.toString())
              .where((e) => e != null)
              .map((e) => unescapeHtml(e!))
              .cast<String>()
              .toList();
        }
      } catch (e) {
        debugLog('⚠️ Fehler beim Parsen von requested_by: $e');
      }
      
      // Sichere Map-Konvertierung für is_registered_users
      Map<String, bool>? isRegisteredUsersMap;
      try {
        final isRegisteredUsersValue = data['is_registered_users'];
        if (isRegisteredUsersValue != null && isRegisteredUsersValue is Map) {
          isRegisteredUsersMap = Map<String, bool>.from(
            (isRegisteredUsersValue as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value is bool ? value : false),
            ),
          );
        }
      } catch (e) {
        debugLog('⚠️ Fehler beim Parsen von is_registered_users: $e');
      }
      
      // Sichere Liste-Konvertierung für greetings
      List<Map<String, dynamic>>? greetingsList;
      try {
        final greetingsValue = data['greetings'];
        if (greetingsValue != null && greetingsValue is List) {
          greetingsList = greetingsValue
              .where((g) => g is Map<String, dynamic>)
              .cast<Map<String, dynamic>>()
              .map((g) {
                final mapped = Map<String, dynamic>.from(g);
                mapped['name'] = unescapeHtml((mapped['name'] ?? '').toString());
                mapped['greeting'] = unescapeHtml((mapped['greeting'] ?? '').toString());
                return mapped;
              })
              .toList();
        }
      } catch (e) {
        debugLog('⚠️ Fehler beim Parsen von greetings: $e');
      }
      
      return SongRequest(
        id: doc.id,
        title: data['title'] != null ? unescapeHtml(data['title'].toString()) : null,
        song: data['song'] != null ? unescapeHtml(data['song'].toString()) : null,
        artist: data['artist'] != null ? unescapeHtml(data['artist'].toString()) : null,
        status: (data['status']?.toString()) ?? 'pending',
        partyId: data['party_id']?.toString(),
        djId: data['djId']?.toString(),
        djCode: data['dj_code']?.toString(),
        createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null,
        name: data['name'] != null ? unescapeHtml(data['name'].toString()) : null,
        requestedBy: requestedByList,
        isRegisteredUsers: isRegisteredUsersMap,
        greetings: greetingsList,
        greeting: data['greeting'] != null ? unescapeHtml(data['greeting'].toString()) : null,
        // WICHTIG: is_duplicate exakt so abbilden wie in Firestore (kein Standardwert, der false in true verwandelt)
        isDuplicate: data['is_duplicate'] is bool ? (data['is_duplicate'] as bool) : null,
        duplicateCount: data['duplicate_count'] is int ? data['duplicate_count'] as int : null,
        playedAt: _parseTimestamp(data['played_at'] ?? data['playedAt']),
        recognizedAt: data['recognized_at'] is Timestamp ? data['recognized_at'] as Timestamp : null,
        statusChangedAt: data['status_changed_at'] is Timestamp ? data['status_changed_at'] as Timestamp : null,
        rejectedAt: _parseTimestamp(data['rejected_at'] ?? data['rejectedAt']),
        statusReason: data['status_reason'] != null
            ? unescapeHtml(data['status_reason'].toString())
            : null,
        deleted: data['deleted'] == true,
        autoRejectedByBlock: data['auto_rejected_by_block'] == true,
        autoRecognized: data['auto_recognized'] == true,
        originalWishId: data['original_wish_id']?.toString(),
        userId: data['user_id']?.toString(),
        clientId: data['client_id']?.toString(),
        isSeen: data['isSeen'] is bool ? (data['isSeen'] as bool) : null,
        isFavorite: data['is_favorite'] == true,
        isDjWish: data['is_dj_wish'] == true,
      );
    } catch (e, stackTrace) {
      debugLog('❌ KRITISCHER FEHLER beim Parsen von SongRequest: $e');
      debugLog('   Stack: $stackTrace');
      debugLog('   Document ID: ${doc.id}');
      debugLog('   Document Data: ${doc.data()}');
      // Gib ein minimales SongRequest zurück, damit die App nicht abstürzt
      return SongRequest(
        id: doc.id,
        title: unescapeHtml((doc.data() as Map<String, dynamic>?)?['title']?.toString() ?? 'Unbekannt'),
        artist: (doc.data() as Map<String, dynamic>?)?['artist'] != null
            ? unescapeHtml((doc.data() as Map<String, dynamic>)['artist'].toString())
            : null,
        status: 'pending',
      );
    }
  }

  /// Gibt den Titel zurück: bevorzugt [title], wenn nicht leer; sonst [song].
  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    final s = song?.trim();
    if (s != null && s.isNotEmpty) return s;
    return '';
  }

  /// Gibt den Display-Namen zurück (erster Eintrag aus requestedBy oder name)
  String? get displayName {
    if (requestedBy != null && requestedBy!.isNotEmpty) {
      return requestedBy!.first;
    }
    return name;
  }
}

