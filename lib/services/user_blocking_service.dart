import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/song_request.dart';
import '../utils/debug_log.dart';

/// Service für die Verwaltung von User-Blockierungen
/// Enthält Dialog-Logik und Firestore-Operationen für das Sperren von Usern und Gästen
class UserBlockingService {
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
      final now = DateTime.now();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.not_authorized),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.no_user_info_found),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (partyId == null || partyId.isEmpty || partyId == 'manual') {
        debugLog('❌ FEHLER: partyId ist ungültig! Kann keine party-spezifische Sperre erstellen.');
        ScaffoldMessenger.of(context).showSnackBar(
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
          final wishDoc = await FirebaseFirestore.instance
              .collection('wishes')
              .doc(currentWishId)
              .get();
          
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
      
      // ✅ BATCH-OPERATION: Alles in einem Batch ausführen
      final batch = FirebaseFirestore.instance.batch();
      int rejectedCount = 0;
      
      // A. Aktuelle Sperre: Erstelle/Update das Dokument in blocked_guests
      final blockedGuestRef = FirebaseFirestore.instance
          .collection('blocked_guests')
          .doc(documentId);
      batch.set(blockedGuestRef, blockData, SetOptions(merge: true));
      debugLog('✅ Batch: blocked_guests Dokument hinzugefügt');

      // Geräte-Anker (client_id / Fingerprint): blocked_devices für Login-Fusion
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
      batch.set(blockedDeviceRef, deviceBlockData, SetOptions(merge: true));
      debugLog('Device block fusion: blocked_devices geschrieben');
      
      // D. Historie-Eintrag: Erstelle Dokument in block_history
      final blockHistoryRef = FirebaseFirestore.instance
          .collection('block_history')
          .doc(); // Auto-ID
      final blockHistoryData = <String, dynamic>{
        'client_id': finalClientId,
        'dj_id': djId, // ✅ WICHTIG: UID statt E-Mail
        'party_id': partyId, // ✅ Lange Party-ID
        'timestamp': FieldValue.serverTimestamp(),
        'blocked_as_name': name ?? 'Unbekannt', // ✅ WICHTIG: Aktueller Name dauerhaft im Archiv
      };
      
      // Füge trigger_wish_id und trigger_wish_title hinzu, falls vorhanden
      if (triggerWishId != null && triggerWishId.isNotEmpty) {
        blockHistoryData['trigger_wish_id'] = triggerWishId;
      }
      if (triggerWishTitle != null && triggerWishTitle.isNotEmpty) {
        blockHistoryData['trigger_wish_title'] = triggerWishTitle;
      }
      
      batch.set(blockHistoryRef, blockHistoryData);
      debugLog('✅ Batch: block_history Eintrag hinzugefügt');
      
      // B. & C. Song-Markierung: Setze alle pending Wünsche auf rejected mit rejection_reason
      try {
        // Wenn eine aktuelle Wunsch-ID übergeben wurde, markiere diesen Wunsch direkt
        if (currentWishId != null && currentWishId.isNotEmpty) {
          try {
            final wishRef = FirebaseFirestore.instance.collection('wishes').doc(currentWishId);
            final wishDoc = await wishRef.get();
            if (wishDoc.exists) {
              final wishData = wishDoc.data() as Map<String, dynamic>;
              final currentStatus = wishData['status'] as String?;
              if (currentStatus != 'rejected') {
              batch.update(wishRef, {
                'status': 'rejected',
                'auto_rejected_by_block': true, // Kompatibilität
                'rejection_reason': 'user_blocked', // ✅ WICHTIG: Für präzise Entsperr-Logik
                'rejectedAt': FieldValue.serverTimestamp(),
              });
                rejectedCount++;
                debugLog('✅ Aktueller Wunsch wird abgelehnt markiert');
              } else {
                debugLog('⚠️ Aktueller Wunsch ist bereits abgelehnt');
              }
            } else {
              debugLog('⚠️ Aktueller Wunsch existiert nicht');
            }
          } catch (e) {
            debugLog('⚠️ Fehler beim Markieren des aktuellen Wunsches: $e');
          }
        }
        
        // KASKADIERENDES ABLEHNEN: Alle pending Wünsche des Gastes automatisch ablehnen
        // WICHTIG: Nur nach client_id oder user_id suchen, NIEMALS nur nach Name!
        // Grund: Mehrere Gäste könnten den gleichen Namen haben
        Query? wishesQuery;
        if (finalClientId != null && finalClientId.isNotEmpty && partyId != null && partyId != 'manual' && partyId.isNotEmpty) {
          // Suche nach client_id, party_id UND status='pending' (am spezifischsten)
          debugLog('🔍 KASKADIEREND: KASKADIEREND: pending (client_id + party_id)');
          wishesQuery = FirebaseFirestore.instance
              .collection('wishes')
              .where('client_id', isEqualTo: finalClientId)
              .where('party_id', isEqualTo: partyId)
              .where('status', isEqualTo: 'pending'); // ✅ NUR pending Wünsche ablehnen
        } else if (userId != null && partyId != null && partyId != 'manual' && partyId.isNotEmpty) {
          // Suche nach user_id, party_id UND status='pending' (auch spezifisch)
          debugLog('🔍 KASKADIEREND: KASKADIEREND: pending (user_id + party_id)');
          wishesQuery = FirebaseFirestore.instance
              .collection('wishes')
              .where('user_id', isEqualTo: userId)
              .where('party_id', isEqualTo: partyId)
              .where('status', isEqualTo: 'pending'); // ✅ NUR pending Wünsche ablehnen
        }
        // Kein Fallback nach Name - zu gefährlich bei mehreren Gästen mit gleichem Namen!
        
        if (wishesQuery != null) {
          final wishesSnapshot = await wishesQuery.get();
          debugLog('🔍 KASKADIEREND: Gefundene pending Wünsche: ${wishesSnapshot.docs.length}');
          
          for (final wishDoc in wishesSnapshot.docs) {
            // Überspringe den aktuellen Wunsch, falls er bereits markiert wurde
            if (currentWishId != null && wishDoc.id == currentWishId) {
              continue;
            }
            
            final wishData = wishDoc.data() as Map<String, dynamic>;
            final currentStatus = wishData['status'] as String?;
            debugLog('🔍 KASKADIEREND: KASKADIEREND: Wunsch geprüft');
            
            // Alle pending Wünsche automatisch ablehnen
            if (currentStatus == 'pending') {
              batch.update(wishDoc.reference, {
                'status': 'rejected',
                'auto_rejected_by_block': true, // Kompatibilität
                'rejection_reason': 'user_blocked', // ✅ WICHTIG: Für präzise Entsperr-Logik
                'rejectedAt': FieldValue.serverTimestamp(),
              });
              rejectedCount++;
              debugLog('✅ KASKADIEREND: KASKADIEREND: Wunsch abgelehnt');
            } else {
              debugLog('⚠️ KASKADIEREND: Wunsch übersprungen (nicht pending)');
            }
          }
        } else {
          debugLog('⚠️ Keine client_id/user_id oder party_id für kaskadierendes Ablehnen');
        }
        
        // ✅ BATCH COMMIT: Alles zusammen ausführen (blocked_guests + block_history + rejected wishes)
        if (rejectedCount > 0 || true) { // Immer committen, auch wenn keine Wünsche abgelehnt wurden (blocked_guests + block_history müssen gespeichert werden)
          await batch.commit();
          debugLog('✅✅✅ BATCH COMMIT ERFOLGREICH:');
          debugLog('   - blocked_guests Dokument erstellt/aktualisiert');
          debugLog('   - block_history Eintrag erstellt');
          debugLog('   - $rejectedCount pending Wünsche automatisch als abgelehnt markiert');
        } else {
          debugLog('ℹ️ Keine Wünsche zum Ablehnen gefunden, aber blocked_guests und block_history wurden gespeichert');
        }
      } catch (e) {
        debugLog('⚠️ Fehler beim Batch-Commit: $e');
        // Fehler nicht fatal - Sperre wurde bereits gespeichert
      }
      
      // Dialog wird bereits in wish_card.dart geschlossen, SnackBar wird dort angezeigt
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.error_blocking} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Zeigt Block-Dialog für gruppierte Wünsche
  /// WICHTIG: Ruft direkt blockUser auf, kein zweiter Dialog mehr!
  static Future<void> showGroupedBlockDialog(BuildContext context, SongRequest firstRequest, Map<String, dynamic> data, List<String> docIds) async {
    // Direkt blockUser aufrufen mit clientId und partyId aus firstRequest
    final clientId = firstRequest.clientId;
    final partyId = firstRequest.partyId;
    final userId = firstRequest.userId;
    final name = firstRequest.name ?? '';
    
    debugLog('📡 showGroupedBlockDialog: Direkte Sperre (showGroupedBlockDialog)');
    
    // Rufe blockUser direkt auf (ohne Dialog)
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
