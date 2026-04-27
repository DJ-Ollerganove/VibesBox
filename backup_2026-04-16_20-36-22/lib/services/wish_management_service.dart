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

/// Service für die Verwaltung von Musikwünschen in Firestore
/// Enthält Datenoperationen und UI-Dialoge für Wunsch-Verwaltung
class WishManagementService {
  static String _decoded(String value) => unescapeHtml(value);
  static Map<String, dynamic> _sanitizeWriteMap(Map<String, dynamic> map) =>
      SecurityHelper.sanitizeMap(map);

  static bool _isAdminUser() =>
      AppConfig.isAdminRole(UserService().currentUser.value);

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
      return FirebaseFirestore.instance
          .collection('wishes')
          .where('status', isEqualTo: status)
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('wishes')
        .where('party_id', isEqualTo: partyId)
        .where('status', isEqualTo: status)
        .snapshots();
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
      return FirebaseFirestore.instance
          .collection('wishes')
          .where('status', isEqualTo: status)
          .where('is_favorite', isEqualTo: true)
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('wishes')
        .where('party_id', isEqualTo: partyId)
        .where('status', isEqualTo: status)
        .where('is_favorite', isEqualTo: true)
        .snapshots();
  }

  /// Aktualisiert den Status eines einzelnen Wunsches
  ///
  /// [docId] - Die Document-ID des Wunsches
  /// [status] - Der neue Status ('pending', 'played', 'rejected')
  static Future<void> updateWishStatus(String docId, String status) async {
    await updateStatus(docId, status);
  }

  /// Aktualisiert den Status eines einzelnen Wunsches (interne Methode)
  ///
  /// [docId] - Die Document-ID des Wunsches
  /// [status] - Der neue Status ('pending', 'played', 'rejected')
  static Future<void> updateStatus(String docId, String status) async {
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

    await FirebaseFirestore.instance
        .collection('wishes')
        .doc(docId)
        .update(_sanitizeWriteMap(updateData));
  }

  /// Löscht einen einzelnen Wunsch
  ///
  /// [docId] - Die Document-ID des zu löschenden Wunsches
  static Future<void> deleteWish(String docId) async {
    await FirebaseFirestore.instance.collection('wishes').doc(docId).delete();
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

    debugLog(
      '🔒 updateGroupedStatus: Prüfe ${docIds.length} Dokumente für Party-ID: $partyId',
    );

    for (final docId in docIds) {
      try {
        // SICHERHEITS-PRÜFUNG: Lade Dokument und prüfe party_id
        final docRef = FirebaseFirestore.instance
            .collection('wishes')
            .doc(docId);
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          debugLog(
            '⚠️ updateGroupedStatus: Dokument $docId existiert nicht - überspringe',
          );
          skippedUpdates++;
          continue;
        }

        final docData = docSnapshot.data() as Map<String, dynamic>?;
        final docPartyId = docData?['party_id'] as String?;

        // WICHTIG: Nur aktualisieren, wenn party_id übereinstimmt
        if (docPartyId != partyId) {
          debugLog(
            '🚫 updateGroupedStatus: Dokument $docId gehört zu Party "$docPartyId", erwartet "$partyId" - überspringe Update',
          );
          skippedUpdates++;
          continue;
        }

        // Party-ID stimmt überein - Update vorbereiten
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
      throw Exception(
        'Keine Dokumente konnten aktualisiert werden - möglicherweise falsche Party-ID',
      );
    }
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
        final docRef = FirebaseFirestore.instance
            .collection('wishes')
            .doc(docId);
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          debugLog(
            '⚠️ deleteGroupedWishes: Dokument $docId existiert nicht - überspringe',
          );
          skippedDeletes++;
          continue;
        }

        final docData = docSnapshot.data() as Map<String, dynamic>?;
        final docPartyId = docData?['party_id'] as String?;

        // WICHTIG: Nur löschen, wenn party_id übereinstimmt
        if (docPartyId != partyId) {
          debugLog(
            '🚫 deleteGroupedWishes: Dokument $docId gehört zu Party "$docPartyId", erwartet "$partyId" - überspringe Löschung',
          );
          skippedDeletes++;
          continue;
        }

        // Party-ID stimmt überein - Löschung vorbereiten
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
                      // Unterschiedliche Nachrichten je nach Status
                      final statusText = status == 'rejected'
                          ? 'abgelehnt'
                          : status == 'played'
                          ? 'als gespielt markiert'
                          : 'als $status markiert';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${docIds.length} Wünsche wurden $statusText',
                          ),
                          backgroundColor: status == 'rejected'
                              ? UIConstants.frameAbgelehnt
                              : UIConstants.frameGespielt,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fehler: $e'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${docIds.length} Wünsche wurden gelöscht'),
              backgroundColor: UIConstants.frameGespielt,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${docIds.length} Wünsche wurden abgelehnt'),
              backgroundColor: UIConstants.frameGespielt,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${docIds.length} Wünsche wurden gelöscht',
                          ),
                          backgroundColor: UIConstants.frameGespielt,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fehler: $e'),
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
