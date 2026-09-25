import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart' show incrementDeletedCount;
import '../config/app_config.dart';
import '../helpers/security_helper.dart';
import '../l10n/app_localizations.dart';
import '../services/user_service.dart';
import '../utils/string_utils.dart';
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';
import '../utils/pre_wish_helper.dart';
import '../utils/wish_paths.dart';
import 'active_party_service.dart';
import 'open_wishes_visibility_service.dart';
import '../app_scaffold_messenger.dart';

/// Service für die Verwaltung von Musikwünschen in Firestore
/// Enthält Datenoperationen und UI-Dialoge für Wunsch-Verwaltung
class WishManagementService {
  static String _decoded(String value) => unescapeHtml(value);
  static Map<String, dynamic> _sanitizeWriteMap(Map<String, dynamic> map) =>
      SecurityHelper.sanitizeMap(map);

  static bool _isAdminUser() =>
      AppConfig.isAdminRole(UserService().currentUser.value);

  static Future<String> _requirePartyId([String? partyId]) async {
    if (partyId != null && partyId.isNotEmpty) return partyId;
    final fromVisibility = OpenWishesVisibilityService.resolveDjWishPartyId();
    if (fromVisibility != null && fromVisibility.isNotEmpty) {
      return fromVisibility;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('WishManagementService: nicht eingeloggt');
    }
    final info = await ActivePartyService.getActivePartyInfo(user.uid);
    final id = info?.partyId;
    if (id == null || id.isEmpty) {
      throw StateError('WishManagementService: keine aktive Party');
    }
    return id;
  }

  /// Stream-Funktion für Wünsche einer bestimmten Party mit Status-Filter
  ///
  /// [partyId] - Die lange Dokument-ID der Party (z.B. '8cOmLfOf170XAfd5C7BV')
  /// [status] - Der Status-Filter ('pending', 'played', 'rejected')
  ///
  /// Gibt einen Stream zurück, der automatisch aktualisiert wird, wenn sich die Daten ändern.
  /// Filtert nach party_id und status für maximale Sicherheit.
  ///
  /// Sicherheits-Check: Prüft auf FirebaseAuth.instance.currentUser?.uid für zukünftige
  /// Erweiterungen, verwendet aktuell aber nur party_id als Filter (da diese bereits eindeutig ist).
  static Stream<QuerySnapshot> getWishesStream(
    String partyId,
    String status, {
    bool forceGlobalForAdmin = false,
  }) {
    // Sicherheits-Check: Prüfe ob User eingeloggt ist (für zukünftige Erweiterungen)
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid;

    // Aktuell filtern wir nur nach party_id, da diese bereits eindeutig ist
    // Die userId-Prüfung ist für zukünftige Sicherheits-Erweiterungen vorbereitet
    if (userId == null) {
      debugLog(
        '⚠️ WishManagementService: Kein User eingeloggt - Stream läuft trotzdem (nur party_id Filter)',
      );
    }

    debugLog(
      '🔍 WishManagementService: Erstelle Query mit party_id: $partyId, status: $status',
    );

    // Admin-Globalmodus: keine party_id-Filter (nur wenn explizit angefordert)
    if (forceGlobalForAdmin && _isAdminUser()) {
      return WishPaths.allWishesCollectionGroup()
          .where('status', isEqualTo: status)
          .snapshots();
    }

    return WishPaths.partyWishes(partyId)
        .where('status', isEqualTo: status)
        .snapshots();
  }

  static final Map<String, Stream<QuerySnapshot>> _preWishOverviewStreamCache =
      {};

  static Query<Map<String, dynamic>> _preWishOverviewQuery(String partyId) {
    return WishPaths.partyWishes(partyId)
        .where('status', isEqualTo: 'pending')
        .where('is_pre_wish', isEqualTo: true)
        .limit(200);
  }

  /// Einmaliger Read für Party-Karten (sofort „0 Wünsche“, nicht „…“).
  static Future<QuerySnapshot<Map<String, dynamic>>> fetchPreWishOverviewOnce(
    String partyId,
  ) {
    if (partyId.isEmpty) {
      return Future.error(ArgumentError('partyId empty'));
    }
    return _preWishOverviewQuery(partyId).get();
  }

  /// Nur Vorab-Wünsche (Party-Karte / Übersicht) — ein Firestore-Listener pro Party.
  static Stream<QuerySnapshot> getPreWishOverviewStream(String partyId) {
    if (partyId.isEmpty) {
      return Stream<QuerySnapshot>.empty();
    }
    return _preWishOverviewStreamCache.putIfAbsent(
      partyId,
      () => _preWishOverviewQuery(partyId).snapshots(),
    );
  }

  /// Für [StreamBuilder]: immer sofort erste Snapshot (get), danach Live-Updates.
  /// Der gecachte [getPreWishOverviewStream] replayed nicht — zweite Listener blieben auf „…“.
  static Stream<QuerySnapshot> watchPreWishOverview(String partyId) async* {
    if (partyId.isEmpty) return;
    yield await fetchPreWishOverviewOnce(partyId);
    yield* _preWishOverviewQuery(partyId).snapshots();
  }

  /// Mindestens ein Vorab-Wunsch noch nicht in Offen freigegeben (DJ-Tab „Vorab“).
  static bool snapshotHasQueuedPreWishes(QuerySnapshot snapshot) {
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (PreWishHelper.isQueuedPreWish(data)) return true;
    }
    return false;
  }

  static Stream<bool> watchHasQueuedPreWishes(String partyId) {
    if (partyId.isEmpty) {
      return Stream.value(false);
    }
    return watchPreWishOverview(partyId).map(snapshotHasQueuedPreWishes);
  }

  /// Stream-Funktion für favorisierte Wünsche einer bestimmten Party
  ///
  /// [partyId] - Die lange Dokument-ID der Party
  /// [status] - Der Status-Filter ('pending', 'played', 'rejected')
  ///
  /// Gibt einen Stream zurück, der automatisch aktualisiert wird, wenn sich die Daten ändern.
  /// Filtert nach party_id, status und is_favorite == true.
  static Stream<QuerySnapshot> getFavoriteWishesStream(
    String partyId,
    String status, {
    bool forceGlobalForAdmin = false,
  }) {
    debugLog(
      '🔍 WishManagementService: Erstelle Favoriten-Query mit party_id: $partyId, status: $status',
    );

    if (forceGlobalForAdmin && _isAdminUser()) {
      return WishPaths.allWishesCollectionGroup()
          .where('status', isEqualTo: status)
          .where('is_favorite', isEqualTo: true)
          .snapshots();
    }

    return WishPaths.partyWishes(partyId)
        .where('status', isEqualTo: status)
        .where('is_favorite', isEqualTo: true)
        .snapshots();
  }

  /// Aktualisiert den Status eines einzelnen Wunsches
  ///
  /// [docId] - Die Document-ID des Wunsches
  /// [status] - Der neue Status ('pending', 'played', 'rejected')
  static Future<void> updateWishStatus(
    String docId,
    String status, {
    String? partyId,
  }) async {
    await updateStatus(docId, status, partyId: partyId);
  }

  /// Aktualisiert den Status eines einzelnen Wunsches (interne Methode)
  ///
  /// [docId] - Die Document-ID des Wunsches
  /// [status] - Der neue Status ('pending', 'played', 'rejected')
  static Future<void> updateStatus(
    String docId,
    String status, {
    String? partyId,
  }) async {
    final pid = await _requirePartyId(partyId);
    final now = Timestamp.now();
    final updateData = <String, dynamic>{'status': status};

    if (status == 'played') {
      updateData['playedAt'] = now;
      updateData['played_at'] =
          now; // Für SongRequest/WishCard (liest played_at)
      updateData['rejectedAt'] = FieldValue.delete();
      updateData['rejected_at'] = FieldValue.delete();
    } else if (status == 'rejected') {
      updateData['rejectedAt'] = now;
      updateData['rejected_at'] = now; // Für WishCard (liest rejected_at)
      updateData['playedAt'] = FieldValue.delete();
      updateData['played_at'] = FieldValue.delete();
    } else if (status == 'pending') {
      updateData['playedAt'] = FieldValue.delete();
      updateData['played_at'] = FieldValue.delete();
      updateData['rejectedAt'] = FieldValue.delete();
      updateData['rejected_at'] = FieldValue.delete();
    }

    await WishPaths.partyWish(pid, docId).update(_sanitizeWriteMap(updateData));
  }

  /// Löscht einen einzelnen Wunsch
  ///
  /// [docId] - Die Document-ID des zu löschenden Wunsches
  static Future<void> deleteWish(String docId, {String? partyId}) async {
    final pid = await _requirePartyId(partyId);
    await WishPaths.partyWish(pid, docId).delete();
    // Erhöhe deleted_count
    await incrementDeletedCount();
  }

  /// Aktualisiert den Status mehrerer Wünsche (Batch-Operation)
  ///
  /// [docIds] - Liste der Document-IDs der zu aktualisierenden Wünsche
  /// [status] - Der neue Status ('pending', 'played', 'rejected')
  /// [partyId] - Die lange Party-ID zur Sicherheits-Prüfung (verhindert partyübergreifende Updates)
  static Future<void> updateGroupedStatus(
    List<String> docIds,
    String status,
    String partyId,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    final now = FieldValue.serverTimestamp();
    int validUpdates = 0;
    int skippedUpdates = 0;
    int skippedBlockedGuestRestores = 0;

    debugLog(
      '🔒 updateGroupedStatus: Prüfe ${docIds.length} Dokumente für Party-ID: $partyId',
    );

    for (final docId in docIds) {
      try {
        // SICHERHEITS-PRÜFUNG: Lade Dokument und prüfe party_id
        final docRef = WishPaths.partyWish(partyId, docId);
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          debugLog(
            '⚠️ updateGroupedStatus: Dokument $docId existiert nicht - überspringe',
          );
          skippedUpdates++;
          continue;
        }

        final docData = docSnapshot.data();

        // Gesperrte Gäste: Abgelehnt → Offen ist verboten (Sperre bleibt, kein Auto-Unblock).
        if (status == 'pending' &&
            (docData?['status'] as String?) == 'rejected') {
          final cid = (docData?['client_id'] ?? '').toString().trim();
          final blockedByFlag =
              docData?['rejection_reason'] == 'user_blocked' ||
              docData?['auto_rejected_by_block'] == true;
          var stillBlocked = blockedByFlag;
          if (!stillBlocked && cid.isNotEmpty) {
            stillBlocked = await _isClientBlockedForParty(cid, partyId);
          }
          if (stillBlocked) {
            debugLog(
              '🚫 updateGroupedStatus: Restore verweigert (Gast gesperrt) doc=$docId',
            );
            skippedBlockedGuestRestores++;
            skippedUpdates++;
            continue;
          }
        }

        final updateData = <String, dynamic>{
          'status': status,
          'status_changed_at': now,
        };

        // WICHTIG: Setze playedAt/played_at nur wenn Status 'played' ist
        if (status == 'played') {
          updateData['playedAt'] = now;
          updateData['played_at'] = now;
          updateData['recognized_at'] =
              now; // Für Kompatibilität mit Auto-Erkennung
          updateData['rejectedAt'] = FieldValue.delete();
          updateData['rejected_at'] = FieldValue.delete();
        } else if (status == 'rejected') {
          updateData['rejectedAt'] = now;
          updateData['rejected_at'] = now; // Für WishCard (liest rejected_at)
          updateData['playedAt'] = FieldValue.delete();
          updateData['played_at'] = FieldValue.delete();
        } else if (status == 'pending') {
          updateData['playedAt'] = FieldValue.delete();
          updateData['played_at'] = FieldValue.delete();
          updateData['rejectedAt'] = FieldValue.delete();
          updateData['rejected_at'] = FieldValue.delete();
          updateData['rejection_reason'] = FieldValue.delete();
          updateData['auto_rejected_by_block'] = FieldValue.delete();
          updateData['auto_rejected_by_blacklist'] = FieldValue.delete();
        }

        batch.update(docRef, _sanitizeWriteMap(updateData));
        validUpdates++;
      } catch (e) {
        debugLog(
          '❌ updateGroupedStatus: Fehler beim Prüfen von Dokument $docId: $e',
        );
        skippedUpdates++;
        continue;
      }
    }

    if (validUpdates > 0) {
      await batch.commit();
      debugLog(
        '✅ updateGroupedStatus: $validUpdates Dokumente aktualisiert, $skippedUpdates übersprungen',
      );
    } else {
      debugLog(
        '⚠️ updateGroupedStatus: Keine gültigen Updates (alle Dokumente wurden übersprungen)',
      );
      if (skippedBlockedGuestRestores > 0 &&
          skippedBlockedGuestRestores == skippedUpdates) {
        throw Exception(
          'Abgelehnte Wünsche gesperrter Gäste können nicht zurück auf Offen gesetzt werden',
        );
      }
      throw Exception(
        'Keine Dokumente konnten aktualisiert werden - möglicherweise falsche Party-ID',
      );
    }
  }

  /// party_id-Anker in blocked_guests oder blocked_devices.
  static Future<bool> _isClientBlockedForParty(
    String clientId,
    String partyId,
  ) async {
    final fs = FirebaseFirestore.instance;
    try {
      final guest = await fs
          .collection('blocked_guests')
          .doc('${clientId}_$partyId')
          .get();
      if (guest.exists) return true;
      final device = await fs.collection('blocked_devices').doc(clientId).get();
      if (!device.exists) return false;
      final data = device.data();
      final docParty =
          (data?['party_id'] ?? data?['partyId'] ?? '').toString().trim();
      if (docParty.isNotEmpty && docParty != partyId) return false;
      final blockStatus =
          (data?['block_status'] ?? '').toString().trim().toLowerCase();
      return blockStatus == 'party_specific' ||
          blockStatus == 'permanent' ||
          blockStatus == 'temporary';
    } catch (e) {
      debugLog('⚠️ _isClientBlockedForParty: $e');
      return false;
    }
  }

  /// Vorab-Wunsch in die offene Liste übernehmen ([pre_wish_published], [is_pre_wish] bleibt).
  static Future<void> publishPreWishToOpen(
    List<String> docIds,
    String partyId,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    var valid = 0;

    for (final docId in docIds) {
      final docRef = WishPaths.partyWish(partyId, docId);
      final snap = await docRef.get();
      if (!snap.exists) continue;
      final data = snap.data();
      if (data == null || data['is_pre_wish'] != true) continue;
      batch.update(docRef, {
        'pre_wish_published': true,
        'status': 'pending',
      });
      valid++;
    }

    if (valid == 0) {
      throw Exception('Keine Vorab-Wünsche konnten freigegeben werden');
    }
    await batch.commit();
    debugLog('✅ publishPreWishToOpen: $valid Dokument(e) für Party $partyId');
  }

  /// Alle noch wartenden Vorab-Wünsche in die offene Liste übernehmen.
  static Future<int> publishAllQueuedPreWishesToOpen(String partyId) async {
    if (partyId.isEmpty) {
      throw ArgumentError('partyId empty');
    }

    final snap = await fetchPreWishOverviewOnce(partyId);
    final docIds = <String>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (PreWishHelper.isQueuedPreWish(data)) {
        docIds.add(doc.id);
      }
    }

    if (docIds.isEmpty) return 0;

    const batchLimit = 500;
    for (var offset = 0; offset < docIds.length; offset += batchLimit) {
      final chunk = docIds.skip(offset).take(batchLimit).toList();
      final batch = FirebaseFirestore.instance.batch();
      for (final docId in chunk) {
        batch.update(WishPaths.partyWish(partyId, docId), {
          'pre_wish_published': true,
          'status': 'pending',
        });
      }
      await batch.commit();
    }

    debugLog(
      '✅ publishAllQueuedPreWishesToOpen: ${docIds.length} Dokument(e) '
      'für Party $partyId',
    );
    return docIds.length;
  }

  /// Löscht mehrere Wünsche (Batch-Operation)
  ///
  /// [docIds] - Liste der Document-IDs der zu löschenden Wünsche
  /// [partyId] - Die lange Party-ID zur Sicherheits-Prüfung (verhindert partyübergreifende Löschungen)
  static Future<void> deleteGroupedWishes(
    List<String> docIds,
    String partyId,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    int validDeletes = 0;
    int skippedDeletes = 0;

    debugLog(
      '🔒 deleteGroupedWishes: Prüfe ${docIds.length} Dokumente für Party-ID: $partyId',
    );

    for (final docId in docIds) {
      try {
        // SICHERHEITS-PRÜFUNG: Lade Dokument und prüfe party_id
        final docRef = WishPaths.partyWish(partyId, docId);
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          debugLog(
            '⚠️ deleteGroupedWishes: Dokument $docId existiert nicht - überspringe',
          );
          skippedDeletes++;
          continue;
        }

        batch.delete(docRef);
        validDeletes++;
      } catch (e) {
        debugLog(
          '❌ deleteGroupedWishes: Fehler beim Prüfen von Dokument $docId: $e',
        );
        skippedDeletes++;
        continue;
      }
    }

    if (validDeletes > 0) {
      await batch.commit();
      debugLog(
        '✅ deleteGroupedWishes: $validDeletes Dokumente gelöscht, $skippedDeletes übersprungen',
      );
      // Erhöhe deleted_count
      await incrementDeletedCount();
    } else {
      debugLog(
        '⚠️ deleteGroupedWishes: Keine gültigen Löschungen (alle Dokumente wurden übersprungen)',
      );
      throw Exception(
        'Keine Dokumente konnten gelöscht werden - möglicherweise falsche Party-ID',
      );
    }
  }

  // ========== UI-Dialoge ==========

  /// Zeigt Dialog zum Löschen oder Ablehnen eines einzelnen Wunsches
  static Future<void> showConfirmDeleteOrRejectDialog(
    BuildContext context,
    String docId,
    String wishText,
  ) async {
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    final l = AppLocalizations.of(context)!;
    final safeWishText = _decoded(wishText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: UIConstants.frameAbgelehnt,
              width: 2.0,
            ),
          ),
          title: Align(
            alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              l.delete_or_reject_wish,
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
          content: Directionality(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    safeWishText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    l.what_to_do_with_wish,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: isRtl
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          actions: isRtl
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'löschen'),
                    child: Text(
                      l.delete,
                      style: const TextStyle(color: UIConstants.frameGesperrt),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'ablehnen'),
                    child: Text(
                      l.reject,
                      style: const TextStyle(color: UIConstants.frameAbgelehnt),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'nein'),
                    child: Text(l.nothing),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'nein'),
                    child: Text(l.nothing),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'ablehnen'),
                    child: Text(
                      l.reject,
                      style: const TextStyle(color: UIConstants.frameAbgelehnt),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'löschen'),
                    child: Text(
                      l.delete,
                      style: const TextStyle(color: UIConstants.frameGesperrt),
                    ),
                  ),
                ],
        ),
      ),
    );

    if (result == 'ablehnen') {
      try {
        await updateStatus(docId, 'rejected');
        if (context.mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.status_updated,
              ),
              backgroundColor: UIConstants.frameGespielt,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.error_updating} $e',
              ),
              backgroundColor: UIConstants.frameNoParty,
            ),
          );
        }
      }
    } else if (result == 'löschen') {
      try {
        await deleteWish(docId);
        if (context.mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.wish_deleted,
              ),
              backgroundColor: UIConstants.frameGespielt,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.error_deleting} $e',
              ),
              backgroundColor: UIConstants.frameNoParty,
            ),
          );
        }
      }
    }
  }

  /// Zeigt Dialog zur Bestätigung der Status-Änderung eines einzelnen Wunsches
  static Future<void> showConfirmUpdateStatusDialog(
    BuildContext context,
    String docId,
    String status,
    String action,
    String wishText,
  ) async {
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    final l = AppLocalizations.of(context)!;
    final safeWishText = _decoded(wishText);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: status == 'played'
                  ? UIConstants.frameGespielt
                  : UIConstants.frameAbgelehnt,
              width: 2.0,
            ),
          ),
          title: Align(
            alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              action,
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
          content: Directionality(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    safeWishText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    '${l.confirm_wish_action} $action?',
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: isRtl
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          actions: isRtl
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      l.yes,
                      style: TextStyle(
                        color: status == 'played'
                            ? UIConstants.frameGespielt
                            : UIConstants.frameGesperrt,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.no),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.no),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      l.yes,
                      style: TextStyle(
                        color: status == 'played'
                            ? UIConstants.frameGespielt
                            : UIConstants.frameGesperrt,
                      ),
                    ),
                  ),
                ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await updateStatus(docId, status);
        if (context.mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.status_updated,
              ),
              backgroundColor: UIConstants.frameGespielt,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.error_updating} $e',
              ),
              backgroundColor: UIConstants.frameNoParty,
            ),
          );
        }
      }
    }
  }

  /// Zeigt Dialog zur Bestätigung der Status-Änderung für gruppierte Wünsche
  ///
  /// [partyId] - Die lange Party-ID zur Sicherheits-Prüfung (verhindert partyübergreifende Updates)
  static Future<void> showConfirmUpdateGroupedStatusDialog(
    BuildContext context,
    List<String> docIds,
    String status,
    String title,
    String displayText,
    String partyId,
  ) async {
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    final l = AppLocalizations.of(context)!;
    final safeDisplayText = _decoded(displayText);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: status == 'played'
                    ? UIConstants.frameGespielt
                    : UIConstants.frameAbgelehnt,
                width: 2.0,
              ),
            ),
            title: Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(color: Colors.white),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    safeDisplayText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection:
                        TextDirection.ltr, // Songtitel/Interpret immer LTR
                  ),
                ),
                if (docIds.length > 1) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: isRtl
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Text(
                      '${l.translate('confirm_mark_all')} ${docIds.length} ${l.translate('wishes_for')} ${l.translate('as')} $status ${l.translate('mark')}?',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      textDirection: isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                  ),
                ],
              ],
            ),
            actionsAlignment: MainAxisAlignment.start,
            actions: [
              // JA-Button: Immer links, Farbe basierend auf Status
              ElevatedButton(
                onPressed: () async {
                  debugLog('>>> KLICK: JA gedrückt für IDs: $docIds');
                  if (status == 'rejected') {
                    debugLog('>>> SERVICE: Starte Ablehnen für: $docIds');
                  }
                  // Schließe den Bestätigungs-Dialog
                  Navigator.pop(context);
                  // Schließe dann den Detail-Dialog (falls vorhanden)
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  // Verwende updateGroupedStatus mit partyId-Sicherheits-Prüfung
                  try {
                    debugLog(
                      '>>> SERVICE-START: Update für ${docIds.length} Dokumente mit Party-ID: $partyId',
                    );
                    await updateGroupedStatus(docIds, status, partyId);
                    debugLog('>>> SERVICE-ENDE: Alle Updates durchgelaufen');
                    if (context.mounted) {
                      final loc = AppLocalizations.of(context)!;
                      final msg = status == 'rejected'
                          ? loc.snackbar_wishes_rejected(docIds.length)
                          : status == 'played'
                              ? loc.snackbar_wishes_marked_played(docIds.length)
                              : loc.snackbar_wishes_updated(docIds.length);
                      showVibesSnackBar(context, 
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: status == 'rejected'
                              ? UIConstants.frameAbgelehnt
                              : UIConstants.frameGespielt,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final locErr = AppLocalizations.of(context)!;
                      showVibesSnackBar(context, 
                        SnackBar(
                          content: Text(locErr.snackbar_error_details(e)),
                          backgroundColor: UIConstants.frameNoParty,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'played'
                      ? UIConstants.frameGespielt
                      : UIConstants.frameAbgelehnt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(l.yes),
              ),
              // Abbrechen-Button: Immer rechts daneben
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(l.cancel),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Zeigt Dialog zum Löschen oder Ablehnen von gruppierten Wünschen
  ///
  /// [partyId] - Die lange Party-ID zur Sicherheits-Prüfung (verhindert partyübergreifende Updates)
  static Future<void> showConfirmDeleteOrRejectGroupedDialog(
    BuildContext context,
    List<String> docIds,
    String displayText,
    String partyId,
  ) async {
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    final l = AppLocalizations.of(context)!;
    final safeDisplayText = _decoded(displayText);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: UIConstants.frameAbgelehnt,
              width: 2.0,
            ),
          ),
          title: Align(
            alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              l.delete_or_reject_wish,
              style: const TextStyle(color: Colors.white),
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
          content: Directionality(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                '${l.translate('confirm_all_wishes')} ${docIds.length} ${l.translate('wishes_for')} "$safeDisplayText" ${l.translate('delete_or_reject')}?',
                style: const TextStyle(color: Colors.white),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
          ),
          actionsAlignment: isRtl
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          actions: isRtl
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l.cancel,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    child: Text(
                      l.delete,
                      style: const TextStyle(color: UIConstants.frameGesperrt),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'reject'),
                    child: Text(
                      l.reject,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'reject'),
                    child: Text(
                      l.reject,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    child: Text(
                      l.delete,
                      style: const TextStyle(color: UIConstants.frameGesperrt),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l.cancel,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
        ),
      ),
    );

    if (action == 'delete') {
      // Schließe zuerst den Bestätigungs-Dialog
      Navigator.pop(context);
      // Schließe dann den Detail-Dialog (falls vorhanden)
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      try {
        await deleteGroupedWishes(docIds, partyId);
        if (context.mounted) {
          final locOk = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(locOk.snackbar_wishes_deleted(docIds.length)),
              backgroundColor: UIConstants.frameGespielt,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final locErr = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(locErr.snackbar_error_details(e)),
              backgroundColor: UIConstants.frameNoParty,
            ),
          );
        }
      }
    } else if (action == 'reject') {
      // Schließe zuerst den Bestätigungs-Dialog
      Navigator.pop(context);
      // Schließe dann den Detail-Dialog (falls vorhanden)
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      try {
        await updateGroupedStatus(docIds, 'rejected', partyId);
        if (context.mounted) {
          final locOk = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(locOk.snackbar_wishes_rejected(docIds.length)),
              backgroundColor: UIConstants.frameGespielt,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final locErr = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(locErr.snackbar_error_details(e)),
              backgroundColor: UIConstants.frameNoParty,
            ),
          );
        }
      }
    }
  }

  /// Zeigt Dialog zur Bestätigung des Löschens für gruppierte Wünsche
  ///
  /// [partyId] - Die lange Party-ID zur Sicherheits-Prüfung (verhindert partyübergreifende Löschungen)
  static Future<void> showConfirmDeleteGroupedDialog(
    BuildContext context,
    List<String> docIds,
    String displayText,
    String partyId,
  ) async {
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    final l = AppLocalizations.of(context)!;
    final safeDisplayText = _decoded(displayText);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                color: UIConstants.frameGesperrt,
                width: 2.0,
              ),
            ),
            title: Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                      l.delete,
                style: const TextStyle(color: Colors.white),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    safeDisplayText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection:
                        TextDirection.ltr, // Songtitel/Interpret immer LTR
                  ),
                ),
                if (docIds.length > 1) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: isRtl
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Text(
                      '${l.translate('confirm_mark_all')} ${docIds.length} ${l.translate('wishes_for')} ${l.translate('delete')}?',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      textDirection: isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                  ),
                ],
              ],
            ),
            actionsAlignment: MainAxisAlignment.start,
            actions: [
              // JA-Button: Immer links, Farbe Rot für Löschen
              ElevatedButton(
                onPressed: () async {
                  debugLog('>>> SERVICE: Starte Löschen für: $docIds');
                  // Schließe den Bestätigungs-Dialog
                  Navigator.pop(context);
                  // Schließe dann den Detail-Dialog (falls vorhanden)
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  // Verwende deleteGroupedWishes mit partyId-Sicherheits-Prüfung
                  try {
                    debugLog(
                      '>>> SERVICE-START: Lösche ${docIds.length} Dokumente mit Party-ID: $partyId',
                    );
                    await deleteGroupedWishes(docIds, partyId);
                    debugLog('>>> SERVICE-ENDE: Alle Löschungen durchgelaufen');
                    if (context.mounted) {
                      final locOk = AppLocalizations.of(context)!;
                      showVibesSnackBar(context, 
                        SnackBar(
                          content: Text(locOk.snackbar_wishes_deleted(docIds.length)),
                          backgroundColor: UIConstants.frameGespielt,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final locErr = AppLocalizations.of(context)!;
                      showVibesSnackBar(context, 
                        SnackBar(
                          content: Text(locErr.snackbar_error_details(e)),
                          backgroundColor: UIConstants.frameNoParty,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: UIConstants.frameGesperrt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(l.yes),
              ),
              // Abbrechen-Button: Immer rechts daneben
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(l.cancel),
              ),
            ],
          ),
        );
      },
    );
  }
}
