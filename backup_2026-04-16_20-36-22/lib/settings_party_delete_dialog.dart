import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'services/active_party_service.dart';
import 'services/limit_service.dart';
import 'utils/ui_constants.dart';
import 'config/app_config.dart';
import 'services/user_service.dart';
import 'utils/debug_log.dart';

/// Dialog für die Bestätigung und Löschung einer Party
/// Erlaubt: Admin oder DJ (created_by der Party)
class SettingsPartyDeleteDialog {
  static bool _isAdmin() {
    return AppConfig.isAdminRole(UserService().currentUser.value);
  }

  /// Prüft ob der aktuelle User die Party löschen darf (Admin oder Ersteller)
  static Future<bool> _mayDeleteParty(String partyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (_isAdmin()) return true;
    try {
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();
      if (!partyDoc.exists) return false;
      final createdBy = partyDoc.data()?['created_by'] as String?;
      return createdBy == user.uid;
    } catch (_) {
      return false;
    }
  }

  /// Bestätigt und löscht eine Party (nach expliziter User-Bestätigung).
  /// Returns true wenn die Party erfolgreich gelöscht wurde, sonst false.
  static Future<bool> confirm(
    BuildContext context,
    String partyId,
    String partyName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _mayDeleteParty(partyId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.delete_party_only_own),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    // SICHERHEITS-DIALOG mit Warnung (explizite Bestätigung)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Container(
          decoration: BoxDecoration(
            color: UIConstants.djShellPageBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red, width: 3),
          ),
          child: AlertDialog(
            backgroundColor: UIConstants.djShellPageBackground,
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.party_delete_radical_title,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.party_delete_named_line(partyName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.party_delete_radical_intro,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('• ${l10n.party_delete_bullet_wishes}', style: const TextStyle(color: Colors.white70)),
                Text('• ${l10n.party_delete_bullet_music_history}', style: const TextStyle(color: Colors.white70)),
                Text('• ${l10n.party_delete_bullet_shazam}', style: const TextStyle(color: Colors.white70)),
                Text('• ${l10n.party_delete_bullet_blocked_guests}', style: const TextStyle(color: Colors.white70)),
                Text('• ${l10n.party_delete_bullet_block_history}', style: const TextStyle(color: Colors.white70)),
                Text('• ${l10n.party_delete_bullet_party_status}', style: const TextStyle(color: Colors.white70)),
                Text('• ${l10n.party_delete_bullet_party_sessions}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Text(
                  l10n.party_delete_stats_will_decrease,
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.party_delete_confirm_anyway, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      // Lade-Overlay während der gesamten Cascade-Löschung (blockiert weitere Aktionen)
      if (context.mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (ctx) => const PopScope(
            canPop: false,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }
      bool ok = false;
      try {
        ok = await _deletePartyCompletely(context, partyId, partyName, l10n);
      } catch (_) {
        // Fehler-SnackBar wird bereits in _deletePartyCompletely angezeigt
      } finally {
        if (context.mounted) {
          Navigator.of(context).pop(); // Lade-Overlay schließen
        }
      }
      return ok;
    }
    return false;
  }

  /// Radikale Cascade-Löschung aller Party-Daten. Returns true bei Erfolg, false bei Fehler.
  static Future<bool> _deletePartyCompletely(
    BuildContext context,
    String partyId,
    String partyName,
    AppLocalizations l10n,
  ) async {
    if (!await _mayDeleteParty(partyId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.delete_party_only_own),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    try {
      debugLog('🗑️ STARTE RADIKALE LÖSCHUNG FÜR PARTY: $partyName (ID: $partyId)');
      debugLog('═══════════════════════════════════════════════════════════');

      final firestore = FirebaseFirestore.instance;
      int totalDeleted = 0;

      // 0. FÄLSCHUNGSSICHERES PARTY-LIMIT (Fall A/B):
      // Party-Dokument laden für start_date und created_by
      try {
        final partyDoc = await firestore.collection('parties').doc(partyId).get();
        if (partyDoc.exists) {
          final data = partyDoc.data()!;
          final createdBy = data['created_by'] as String?;
          if (createdBy != null && createdBy.isNotEmpty) {
            // Startdatum ermitteln: start_time_posix (Unix-Sekunden) oder start_date (Timestamp)
            DateTime? partyStartDate;
            final startPosix = data['start_time_posix'] as int? ??
                data['start_time_posix_seconds'] as int?;
            if (startPosix != null) {
              partyStartDate = DateTime.fromMillisecondsSinceEpoch(
                  startPosix * 1000,
                  isUtc: true);
            } else {
              final startTs = data['start_date'] as Timestamp?;
              if (startTs != null) {
                partyStartDate = startTs.toDate();
              }
            }
            final now = DateTime.now();
            final hasPartyStarted =
                partyStartDate != null && !now.isBefore(partyStartDate);
            if (hasPartyStarted) {
              // Fall B: Party hat bereits begonnen oder ist beendet → Stichtag-Slot setzen
              final userDoc = await firestore.collection('users').doc(createdBy).get();
              final anchorDay = LimitService.getAnchorDayFromUserData(userDoc.data());
              final periodSlotKey = LimitService.computePeriodSlotKey(partyStartDate!, anchorDay);
              await LimitService.addUsedPartySlotForFreeDj(createdBy, periodSlotKey);
              debugLog('   📌 Fall B: Party war gestartet → usedPartySlots ergänzt ($periodSlotKey)');
            } else {
              debugLog('   📌 Fall A: Party noch nicht gestartet → usedPartySlots unverändert');
            }
          }
        }
      } catch (e) {
        debugLog('   ⚠️ Hinweis bei usedPartySlots-Prüfung: $e');
      }

      // 1. Lösche music_history Sessions (party_id UND partyId – beide Formate abdecken)
      debugLog('📊 Schritt 1: Lösche music_history Sessions...');
      try {
        final byPartyId = await firestore
            .collection('music_history')
            .where('partyId', isEqualTo: partyId)
            .get();
        final byPartyIdUnderscore = await firestore
            .collection('music_history')
            .where('party_id', isEqualTo: partyId)
            .get();
        final allSessionRefs = <String>{};
        for (final doc in byPartyId.docs) {
          allSessionRefs.add(doc.reference.id);
        }
        for (final doc in byPartyIdUnderscore.docs) {
          allSessionRefs.add(doc.reference.id);
        }
        int sessionsDeleted = 0;
        for (final sessionId in allSessionRefs) {
          final sessionRef = firestore.collection('music_history').doc(sessionId);
          final tracksSnapshot = await sessionRef.collection('tracks').get();
          final batch = firestore.batch();
          for (final trackDoc in tracksSnapshot.docs) {
            batch.delete(trackDoc.reference);
          }
          if (tracksSnapshot.docs.isNotEmpty) {
            await batch.commit();
          }
          await sessionRef.delete();
          sessionsDeleted++;
        }
        totalDeleted += sessionsDeleted;
        debugLog('   ✅ $sessionsDeleted music_history Sessions gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen von music_history: $e');
      }

      // 2. Lösche wishes (mit party_id) - IN BATCHES
      debugLog('📝 Schritt 2: Lösche wishes...');
      try {
        const BATCH_SIZE = 450; // Firestore Batch-Limit: 500
        int wishesDeleted = 0;
        
        Query wishesQuery = firestore
            .collection('wishes')
            .where('party_id', isEqualTo: partyId)
            .limit(BATCH_SIZE);
        
        while (true) {
          final wishesSnapshot = await wishesQuery.get();
          
          if (wishesSnapshot.docs.isEmpty) break;
          
          final batch = firestore.batch();
          for (final wishDoc in wishesSnapshot.docs) {
            batch.delete(wishDoc.reference);
          }
          await batch.commit();
          wishesDeleted += wishesSnapshot.docs.length;
          
          if (wishesSnapshot.docs.length < BATCH_SIZE) break;
          
          // Nächste Seite
          final lastDoc = wishesSnapshot.docs.last;
          wishesQuery = firestore
              .collection('wishes')
              .where('party_id', isEqualTo: partyId)
              .startAfterDocument(lastDoc)
              .limit(BATCH_SIZE);
        }
        totalDeleted += wishesDeleted;
        debugLog('   ✅ $wishesDeleted wishes gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen von wishes: $e');
      }

      // 3. Lösche shazam_history (mit party_id)
      debugLog('🎵 Schritt 3: Lösche shazam_history...');
      try {
        final shazamSnapshot = await firestore
            .collection('shazam_history')
            .where('party_id', isEqualTo: partyId)
            .get();
        
        final batch = firestore.batch();
        for (final doc in shazamSnapshot.docs) {
          batch.delete(doc.reference);
        }
        if (shazamSnapshot.docs.isNotEmpty) {
          await batch.commit();
        }
        totalDeleted += shazamSnapshot.docs.length;
        debugLog('   ✅ ${shazamSnapshot.docs.length} shazam_history Einträge gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen von shazam_history: $e');
      }

      // 4. Lösche blocked_guests (Dokument-ID enthält partyId ODER party_id Feld)
      debugLog('🚫 Schritt 4: Lösche blocked_guests...');
      try {
        // Methode 1: Nach party_id Feld filtern
        final blockedByPartyId = await firestore
            .collection('blocked_guests')
            .where('party_id', isEqualTo: partyId)
            .get();
        
        // Methode 2: Dokument-IDs die mit _${partyId} enden
        // (Format: ${clientId}_${partyId})
        final allBlocked = await firestore
            .collection('blocked_guests')
            .get();
        
        final batch = firestore.batch();
        int blockedDeleted = 0;
        
        // Lösche alle mit party_id Feld
        for (final doc in blockedByPartyId.docs) {
          batch.delete(doc.reference);
          blockedDeleted++;
        }
        
        // Lösche alle mit Dokument-ID die auf _${partyId} endet
        for (final doc in allBlocked.docs) {
          if (doc.id.endsWith('_$partyId')) {
            // Prüfe ob bereits in batch (doppelte Vermeidung)
            if (!blockedByPartyId.docs.any((d) => d.id == doc.id)) {
              batch.delete(doc.reference);
              blockedDeleted++;
            }
          }
        }
        
        if (blockedDeleted > 0) {
          await batch.commit();
        }
        totalDeleted += blockedDeleted;
        debugLog('   ✅ $blockedDeleted blocked_guests Einträge gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen von blocked_guests: $e');
      }

      // 5. Lösche block_history (mit party_id)
      debugLog('📜 Schritt 5: Lösche block_history...');
      try {
        final blockHistorySnapshot = await firestore
            .collection('block_history')
            .where('party_id', isEqualTo: partyId)
            .get();
        
        final batch = firestore.batch();
        for (final doc in blockHistorySnapshot.docs) {
          batch.delete(doc.reference);
        }
        if (blockHistorySnapshot.docs.isNotEmpty) {
          await batch.commit();
        }
        totalDeleted += blockHistorySnapshot.docs.length;
        debugLog('   ✅ ${blockHistorySnapshot.docs.length} block_history Einträge gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen von block_history: $e');
      }

      // 6. Lösche party_status (mit party_id)
      debugLog('📊 Schritt 6: Lösche party_status...');
      try {
        final partyStatusSnapshot = await firestore
            .collection('party_status')
            .where('party_id', isEqualTo: partyId)
            .get();
        
        final batch = firestore.batch();
        for (final doc in partyStatusSnapshot.docs) {
          batch.delete(doc.reference);
        }
        if (partyStatusSnapshot.docs.isNotEmpty) {
          await batch.commit();
        }
        totalDeleted += partyStatusSnapshot.docs.length;
        debugLog('   ✅ ${partyStatusSnapshot.docs.length} party_status Einträge gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen von party_status: $e');
      }

      // 7. Lösche party_sessions (mit party_id)
      debugLog('🎪 Schritt 7: Lösche party_sessions...');
      try {
        final partySessionsSnapshot = await firestore
            .collection('party_sessions')
            .where('party_id', isEqualTo: partyId)
            .get();
        
        final batch = firestore.batch();
        for (final doc in partySessionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        if (partySessionsSnapshot.docs.isNotEmpty) {
          await batch.commit();
        }
        totalDeleted += partySessionsSnapshot.docs.length;
        debugLog('   ✅ ${partySessionsSnapshot.docs.length} party_sessions Einträge gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen von party_sessions: $e');
      }

      // 8. Lösche seenWishIds (lokal in SharedPreferences)
      debugLog('👁️ Schritt 8: Lösche seenWishIds...');
      try {
        await ActivePartyService.clearSeenWishIds(partyId);
        debugLog('   ✅ seenWishIds gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen von seenWishIds: $e');
      }

      // 9. Lösche das Party-Dokument selbst (ZU LETZT, nach allen abhängigen Daten)
      debugLog('🎉 Schritt 9: Lösche Party-Dokument...');
      try {
        await firestore.collection('parties').doc(partyId).delete();
        debugLog('   ✅ Party-Dokument gelöscht');
      } catch (e) {
        debugLog('   ⚠️ Fehler beim Löschen des Party-Dokuments: $e');
        rethrow; // Wichtig: Wenn Party nicht gelöscht werden kann, Fehler weiterwerfen
      }

      debugLog('═══════════════════════════════════════════════════════════');
      debugLog('✅ RADIKALE LÖSCHUNG ABGESCHLOSSEN');
      debugLog('📊 Gesamt gelöscht: $totalDeleted Dokumente');
      debugLog('═══════════════════════════════════════════════════════════');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.party_deleted_with_related(partyName, totalDeleted)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return true;
    } catch (e, stackTrace) {
      debugLog('❌ FEHLER BEI DER RADIKALEN LÖSCHUNG: $e');
      debugLog('Stack Trace: $stackTrace');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbar_error_details(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }
}
