import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/song_request.dart';
import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';
import '../app_scaffold_messenger.dart';
import 'active_party_service.dart';
import 'open_wishes_visibility_service.dart';

/// Service für die Verwaltung von User-Blockierungen
/// Enthält Dialog-Logik und Firestore-Operationen für das Sperren von Usern und Gästen
class UserBlockingService {
  static const Map<String, dynamic> _rejectByBlockUpdate = {
    'status': 'rejected',
    'auto_rejected_by_block': true,
    'rejection_reason': 'user_blocked',
  };

  /// Steigt nach erfolgreicher Sperre — [GesperrtPage] lädt die Liste neu.
  static final ValueNotifier<int> blockedGuestsRevision = ValueNotifier<int>(0);

  /// Party-ID für Sperre: **zuerst die Party, die der DJ gerade sieht**
  /// (Visibility/Session = dieselbe Quelle wie GesperrtPage / DjWishPartyScope).
  /// Wunsch-`party_id` nur Fallback — kann fehlen oder von einer anderen Party stammen.
  static String? resolveBlockPartyId({
    String? fromRequest,
    Map<String, dynamic>? fromGroupedData,
  }) {
    String? clean(dynamic raw) {
      final id = (raw ?? '').toString().trim();
      if (id.isEmpty || id == 'manual') return null;
      return id;
    }

    // 1) Laufende DJ-Ansicht (Offen/Gesperrt nutzen dieselbe Quelle)
    final active = clean(OpenWishesVisibilityService.resolveDjWishPartyId()) ??
        clean(ActivePartyService.getStoredSession()?.partyId) ??
        clean(ActivePartyService.currentPartyId);
    if (active != null) return active;

    // 2) Fallback: Wunsch / Gruppendaten
    return clean(fromGroupedData?['party_id']) ??
        clean(fromGroupedData?['partyId']) ??
        clean(fromRequest);
  }

  static bool _wishBelongsToBlockedGuest(
    Map<String, dynamic> data,
    String blockedClientId,
    String? blockedUserId,
  ) {
    final cid = (data['client_id'] ?? '').toString().trim();
    final uid = (data['user_id'] ?? '').toString().trim();
    if (cid.isNotEmpty && cid == blockedClientId) return true;
    if (blockedUserId != null &&
        blockedUserId.isNotEmpty &&
        uid.isNotEmpty &&
        uid == blockedUserId) {
      return true;
    }
    return false;
  }

  /// Original-ID für Dubletten-Kette (abgelehntes Original → Schatten anderer Gäste hochstufen).
  static void _trackOriginalForDuplicatePromotion(
    Set<String> originalsForPromotion,
    String wishDocId,
    Map<String, dynamic> data,
  ) {
    if (data['is_duplicate'] == true) {
      final originalId = (data['original_wish_id'] ?? '').toString().trim();
      if (originalId.isNotEmpty) originalsForPromotion.add(originalId);
    } else if (wishDocId.isNotEmpty) {
      originalsForPromotion.add(wishDocId);
    }
  }

  /// Felder für ein Schatten-Dokument, das nach Sperre des Erstwünschenden sichtbar wird.
  static Map<String, dynamic> _promotedPrimaryWishFields(Map<String, dynamic> shadow) {
    final guestName = (shadow['name'] ?? '').toString().trim();
    final requestedBy = guestName.isNotEmpty ? <String>[guestName] : <String>[];

    final greetings = <Map<String, dynamic>>[];
    final singleGreeting = (shadow['greeting'] ?? '').toString().trim();
    if (singleGreeting.isNotEmpty && guestName.isNotEmpty) {
      greetings.add({'name': guestName, 'greeting': singleGreeting});
    } else if (shadow['greetings'] is List) {
      for (final entry in shadow['greetings'] as List) {
        if (entry is! Map) continue;
        final n = (entry['name'] ?? '').toString().trim();
        if (guestName.isNotEmpty && n != guestName) continue;
        greetings.add(Map<String, dynamic>.from(entry));
      }
    }

    final isRegisteredUsers = <String, bool>{};
    if (guestName.isNotEmpty) {
      final reg = shadow['is_registered_users'];
      if (reg is Map && reg[guestName] == true) {
        isRegisteredUsers[guestName] = true;
      } else if (shadow['is_registered_user'] == true) {
        isRegisteredUsers[guestName] = true;
      }
    }

    return {
      'is_duplicate': false,
      'original_wish_id': FieldValue.delete(),
      'duplicate_count': 0,
      'requested_by': requestedBy,
      'greetings': greetings,
      'greeting': FieldValue.delete(),
      'is_registered_users': isRegisteredUsers,
    };
  }

  /// Dubletten-Schatten des gesperrten Gastes → rejected (nur Status-Patch, Batch-sicher).
  static Future<int> _enqueueBlockedGuestShadowRejects({
    required WriteBatch batch,
    required Set<String> originalWishIds,
    required String blockedClientId,
    required String? blockedUserId,
    required String partyId,
  }) async {
    var rejected = 0;
    for (final originalId in originalWishIds) {
      if (originalId.isEmpty) continue;

      final shadows = await WishPaths.partyWishes(partyId)
          .where('original_wish_id', isEqualTo: originalId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in shadows.docs) {
        final data = doc.data();
        if (data['is_duplicate'] != true) continue;
        if (!_wishBelongsToBlockedGuest(data, blockedClientId, blockedUserId)) {
          continue;
        }
        batch.update(doc.reference, {
          ..._rejectByBlockUpdate,
          'rejectedAt': FieldValue.serverTimestamp(),
        });
        rejected++;
        debugLog('✅ Dublette des gesperrten Gastes abgelehnt: ${doc.id}');
      }
    }
    return rejected;
  }

  /// Nach erfolgreicher Sperre: Schatten anderer Gäste hochstufen (eigener Batch,
  /// darf die Sperre nicht mehr rollbacken — Full-Doc-Update vs. Status-Patch-Rules).
  static Future<void> _promoteOtherGuestsDuplicateWishesBestEffort({
    required Set<String> originalWishIds,
    required String blockedClientId,
    required String? blockedUserId,
    required String partyId,
  }) async {
    if (originalWishIds.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    var updates = 0;
    for (final originalId in originalWishIds) {
      if (originalId.isEmpty) continue;

      final shadows = await WishPaths.partyWishes(partyId)
          .where('original_wish_id', isEqualTo: originalId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in shadows.docs) {
        final data = doc.data();
        if (data['is_duplicate'] != true) continue;
        if (_wishBelongsToBlockedGuest(data, blockedClientId, blockedUserId)) {
          continue;
        }
        batch.update(doc.reference, _promotedPrimaryWishFields(data));
        updates++;
        debugLog(
          '✅ Dubletten-Schatten hochgestuft (bleibt in Offen): ${doc.id}',
        );
      }
    }
    if (updates == 0) return;
    await batch.commit();
    debugLog('✅ Dubletten-Promotion: $updates Schatten hochgestuft');
  }
  /// Sperrt einen User oder Gast in Firestore (immer party-spezifisch)
  static Future<void> blockUser(
    BuildContext context,
    String? userId,
    String? clientId,
    String? name,
    String? partyId, [
    String? currentWishId,
  ]) async {
    debugLog('🔒 blockUser (party-spezifische Sperre)');
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid == null) {
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(AppLocalizations.of(context)!.not_authorized),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      partyId = resolveBlockPartyId(fromRequest: partyId);
      
      // WICHTIG: Nutze UID statt E-Mail (UID bleibt konstant, E-Mail kann sich ändern)
      final djId = currentUser!.uid;
      final djEmail = currentUser.email ?? ''; // E-Mail nur für Kompatibilität
      
      // Hole Party-Daten für party_code (falls partyId vorhanden)
      String? partyCode;
      if (partyId != null && partyId.isNotEmpty && partyId != 'manual') {
        try {
          final partyDoc = await FirebaseFirestore.instance
              .collection('parties')
              .doc(partyId)
              .get();
          
          if (partyDoc.exists) {
            final partyData = partyDoc.data()!;
            partyCode = partyData['party_code'] as String?;
            debugLog('✅ Party-Code geladen');
          }
        } catch (e) {
          debugLog('⚠️ Fehler beim Abrufen des Party-Codes: $e');
        }
      }
      
      // finalClientId für beide Fälle (User und Gast) verfügbar machen
      String? finalClientId = clientId;
      
      // VEREINFACHT: Immer party-spezifische Sperre für alle (User und Gast)
      // Document-ID = ${clientId}_${partyId}
      
      if (finalClientId == null || finalClientId.isEmpty) {
        debugLog('❌ FEHLER: clientId ist null oder leer! Kann keine Sperre erstellen.');
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(AppLocalizations.of(context)!.no_user_info_found),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (partyId == null || partyId.isEmpty || partyId == 'manual') {
        debugLog('❌ FEHLER: partyId ist ungültig! Kann keine party-spezifische Sperre erstellen.');
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(AppLocalizations.of(context)!.user_block_invalid_party_id),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // ID-ERZWINGUNG: Document-ID = ${clientId}_${partyId}
      final documentId = '${finalClientId}_$partyId';
      
      debugLog('📡 Erstelle party-spezifische Sperre');
      
      final blockData = <String, dynamic>{
        'block_status': 'party_specific', // Immer party-spezifisch
        'blocked_at': FieldValue.serverTimestamp(),
        'dj_id': djId, // ✅ WICHTIG: UID statt E-Mail (bleibt konstant)
        'blocked_by': djEmail, // E-Mail nur für Kompatibilität/Anzeige
        'blocked_by_dj': djEmail, // E-Mail nur für Kompatibilität/Anzeige
        'name': name,
        'client_id': finalClientId,
        'party_id': partyId, // Immer vorhanden (wurde oben geprüft)
      };
      
      // Füge party_code hinzu, falls vorhanden
      if (partyCode != null && partyCode.isNotEmpty) {
        blockData['party_code'] = partyCode;
      }
      
      // Füge user_id hinzu, falls vorhanden
      if (userId != null) {
        blockData['user_id'] = userId;
      }
      
      
      // ✅ Hole trigger_wish_id und trigger_wish_title aus dem aktuellen Wunsch
      String? triggerWishId;
      String? triggerWishTitle;
      if (currentWishId != null && currentWishId.isNotEmpty) {
        try {
          final wishDoc = await WishPaths.partyWish(partyId, currentWishId).get();
          
          if (wishDoc.exists) {
            final wishData = wishDoc.data() as Map<String, dynamic>;
            triggerWishId = currentWishId;
            triggerWishTitle = (wishData['title'] as String? ?? '') + 
                (wishData['artist'] != null ? ' - ${wishData['artist']}' : '');
            debugLog('✅ Trigger-Wunsch-Metadaten geladen');
          }
        } catch (e) {
          debugLog('⚠️ Fehler beim Abrufen des Trigger-Wunsches: $e');
        }
      }
      
      // ✅ BATCH 1 (kritisch): Sperre muss in blocked_guests landen — eigener Commit.
      // Früher: ein Batch mit block_history + Wish-Updates. Wenn Historie/Rules scheiterten,
      // konnte die Anzeige-Liste leer bleiben, obwohl der Gast über Devices/Wünsche gesperrt wirkte.
      final anchorBatch = FirebaseFirestore.instance.batch();
      final blockedGuestRef = FirebaseFirestore.instance
          .collection('blocked_guests')
          .doc(documentId);
      anchorBatch.set(blockedGuestRef, blockData, SetOptions(merge: true));

      final blockedDeviceRef = FirebaseFirestore.instance
          .collection('blocked_devices')
          .doc(finalClientId);
      final deviceBlockData = <String, dynamic>{
        'block_status': 'permanent',
        'blocked_at': FieldValue.serverTimestamp(),
        'dj_id': djId,
        'client_id': finalClientId,
        'device_id': finalClientId,
        'party_id': partyId,
        'source': 'dj_block_guest',
      };
      if (userId != null && userId.isNotEmpty) {
        deviceBlockData['blocked_user_id'] = userId;
      }
      anchorBatch.set(blockedDeviceRef, deviceBlockData, SetOptions(merge: true));
      await anchorBatch.commit();
      debugLog(
        '✅ blocked_guests + blocked_devices committed party=$partyId doc=$documentId',
      );
      blockedGuestsRevision.value = blockedGuestsRevision.value + 1;

      // Historie best-effort (darf die Sperre nicht zurückrollen)
      try {
        await FirebaseFirestore.instance.collection('block_history').add({
          'client_id': finalClientId,
          'dj_id': djId,
          'party_id': partyId,
          'timestamp': FieldValue.serverTimestamp(),
          'blocked_as_name': name ?? 'Unbekannt',
          if (triggerWishId != null && triggerWishId.isNotEmpty)
            'trigger_wish_id': triggerWishId,
          if (triggerWishTitle != null && triggerWishTitle.isNotEmpty)
            'trigger_wish_title': triggerWishTitle,
        });
      } catch (e) {
        debugLog('⚠️ block_history fehlgeschlagen (Sperre bleibt aktiv): $e');
      }

      // ✅ BATCH 2: Wünsche auf rejected setzen
      final batch = FirebaseFirestore.instance.batch();
      int rejectedCount = 0;
      
      // B. & C. Song-Markierung: Setze alle pending Wünsche auf rejected mit rejection_reason
      final originalsForPromotion = <String>{};

      // Wenn eine aktuelle Wunsch-ID übergeben wurde, markiere diesen Wunsch direkt
      if (currentWishId != null && currentWishId.isNotEmpty) {
        try {
          final wishRef = WishPaths.partyWish(partyId, currentWishId);
          final wishDoc = await wishRef.get();
          if (wishDoc.exists) {
            final wishData = wishDoc.data() as Map<String, dynamic>;
            final currentStatus = wishData['status'] as String?;
            if (currentStatus != 'rejected') {
              batch.update(wishRef, {
                ..._rejectByBlockUpdate,
                'rejectedAt': FieldValue.serverTimestamp(),
              });
              _trackOriginalForDuplicatePromotion(
                originalsForPromotion,
                currentWishId,
                wishData,
              );
              rejectedCount++;
              debugLog('✅ Aktueller Wunsch wird abgelehnt markiert');
            } else {
              debugLog('⚠️ Aktueller Wunsch ist bereits abgelehnt');
              _trackOriginalForDuplicatePromotion(
                originalsForPromotion,
                currentWishId,
                wishData,
              );
            }
          } else {
            debugLog('⚠️ Aktueller Wunsch existiert nicht');
          }
        } catch (e) {
          debugLog('⚠️ Fehler beim Markieren des aktuellen Wunsches: $e');
          rethrow;
        }
      }

      // KASKADIERENDES ABLEHNEN: Alle pending Wünsche des Gastes automatisch ablehnen
      // WICHTIG: Nur nach client_id oder user_id suchen, NIEMALS nur nach Name!
      Query? wishesQuery;
      if (finalClientId.isNotEmpty &&
          partyId != 'manual' &&
          partyId.isNotEmpty) {
        debugLog('🔍 KASKADIEREND: pending (client_id + party_id)');
        wishesQuery = WishPaths.partyWishes(partyId)
            .where('client_id', isEqualTo: finalClientId)
            .where('status', isEqualTo: 'pending');
      } else if (userId != null &&
          partyId != 'manual' &&
          partyId.isNotEmpty) {
        debugLog('🔍 KASKADIEREND: pending (user_id + party_id)');
        wishesQuery = WishPaths.partyWishes(partyId)
            .where('user_id', isEqualTo: userId)
            .where('status', isEqualTo: 'pending');
      }

      if (wishesQuery != null) {
        final wishesSnapshot = await wishesQuery.get();
        debugLog(
          '🔍 KASKADIEREND: Gefundene pending Wünsche: ${wishesSnapshot.docs.length}',
        );

        for (final wishDoc in wishesSnapshot.docs) {
          if (currentWishId != null && wishDoc.id == currentWishId) {
            continue;
          }

          final wishData = wishDoc.data() as Map<String, dynamic>;
          final currentStatus = wishData['status'] as String?;
          if (currentStatus == 'pending') {
            batch.update(wishDoc.reference, {
              ..._rejectByBlockUpdate,
              'rejectedAt': FieldValue.serverTimestamp(),
            });
            _trackOriginalForDuplicatePromotion(
              originalsForPromotion,
              wishDoc.id,
              wishData,
            );
            rejectedCount++;
            debugLog('✅ KASKADIEREND: Wunsch abgelehnt');
          }
        }
      } else {
        debugLog(
          '⚠️ Keine client_id/user_id oder party_id für kaskadierendes Ablehnen',
        );
      }

      if (originalsForPromotion.isNotEmpty) {
        rejectedCount += await _enqueueBlockedGuestShadowRejects(
          batch: batch,
          originalWishIds: originalsForPromotion,
          blockedClientId: finalClientId,
          blockedUserId: userId,
          partyId: partyId,
        );
      }

      await batch.commit();
      debugLog('✅✅✅ WISH-BATCH COMMIT ERFOLGREICH:');
      debugLog('   - blocked_guests bereits committed');
      debugLog(
        '   - $rejectedCount pending Wünsche automatisch als abgelehnt markiert',
      );

      try {
        await _promoteOtherGuestsDuplicateWishesBestEffort(
          originalWishIds: originalsForPromotion,
          blockedClientId: finalClientId,
          blockedUserId: userId,
          partyId: partyId,
        );
      } catch (e) {
        debugLog(
          '⚠️ Dubletten-Promotion nach Sperre fehlgeschlagen (Sperre bleibt aktiv): $e',
        );
      }

      // Dialog wird bereits in wish_card.dart geschlossen
    } catch (e) {
      debugLog('❌ blockUser fehlgeschlagen: $e');
      if (context.mounted) {
        showVibesSnackBar(
          context,
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.error_blocking} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Zeigt Block-Dialog für gruppierte Wünsche
  /// WICHTIG: Ruft direkt blockUser auf, kein zweiter Dialog mehr!
  static Future<void> showGroupedBlockDialog(BuildContext context, SongRequest firstRequest, Map<String, dynamic> data, List<String> docIds) async {
    final clientId = firstRequest.clientId;
    final partyId = resolveBlockPartyId(
      fromRequest: firstRequest.partyId,
      fromGroupedData: data,
    );
    final userId = firstRequest.userId;
    final name = firstRequest.name ?? '';
    
    debugLog('📡 showGroupedBlockDialog: Direkte Sperre party=$partyId');
    
    await blockUser(
      context,
      userId,
      clientId,
      name,
      partyId,
      firstRequest.id,
    );
  }
}
