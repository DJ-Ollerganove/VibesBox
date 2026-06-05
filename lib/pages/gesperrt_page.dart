import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../services/active_party_service.dart';
import '../services/history_pagination_service.dart';
import '../services/results_per_page_service.dart';
import '../utils/formatting_utils.dart';
import '../utils/ui_constants.dart';
import '../widgets/sticky_pagination_layout.dart';
import '../widgets/custom_page_header.dart';
import '../widgets/no_active_party_display.dart';
import '../utils/greeting_translator.dart';
import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';

class GesperrtPage extends StatefulWidget {
  const GesperrtPage({super.key});

  @override
  State<GesperrtPage> createState() => _GesperrtPageState();
}

class _GesperrtPageState extends State<GesperrtPage> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  String? _partyIdForPage;
  VoidCallback? _partySessionListener;
  final ScrollController _scrollController = ScrollController(); // ✅ Für Scrollen nach oben beim Seitenwechsel

  @override
  void initState() {
    super.initState();
    _partyIdForPage = ActivePartyService.getStoredSession()?.partyId;
    _partySessionListener = () {
      final nextPartyId = ActivePartyService.storedSessionNotifier.value?.partyId;
      if (nextPartyId == _partyIdForPage) return;
      if (!mounted) return;
      setState(() {
        _partyIdForPage = nextPartyId;
        _currentPage = 1;
      });
    };
    ActivePartyService.storedSessionNotifier.addListener(_partySessionListener!);
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
  }

  @override
  void dispose() {
    if (_partySessionListener != null) {
      ActivePartyService.storedSessionNotifier.removeListener(_partySessionListener!);
    }
    _scrollController.dispose(); // ✅ ScrollController aufräumen
    super.dispose();
  }

  /// Navigiert zur vorherigen Seite und scrollt nach oben
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      // ✅ Scroll nach oben, damit DJ die neuen Titel sofort sieht
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Navigiert zur nächsten Seite und scrollt nach oben
  void _goToNextPage(int totalPages) {
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
      });
      // ✅ Scroll nach oben, damit DJ die neuen Titel sofort sieht
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Baut die Paginierungs-Buttons mit Rot/Schwarz Design (passend zu Gesperrt-Gästen)
  Widget _buildPaginationButtons(int currentPage, int totalPages, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16), // ✅ Kompakter oberer Abstand, unterer Abstand bleibt für Footer
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: UIConstants.djChromePanelDecoration,
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Zurück-Button
          ElevatedButton.icon(
            onPressed: HistoryPaginationService.hasPreviousPage(currentPage)
                ? _goToPreviousPage
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_forward : Icons.arrow_back,
              size: 18,
            ),
            label: Text(l10n.history_page_previous),
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.djShellPageBackground,
              foregroundColor: Colors.white,
              disabledBackgroundColor: UIConstants.colorGrey.withValues(alpha: 0.4),
              disabledForegroundColor: UIConstants.colorGrey,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: UIConstants.appOrange, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Seitenanzeige
          Text(
            '${l10n.history_page} $currentPage / $totalPages',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          // Vor-Button
          ElevatedButton.icon(
            onPressed: HistoryPaginationService.hasNextPage(currentPage, totalPages)
                ? () => _goToNextPage(totalPages)
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_back : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(l10n.history_page_next),
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.djShellPageBackground,
              foregroundColor: Colors.white,
              disabledBackgroundColor: UIConstants.colorGrey.withValues(alpha: 0.4),
              disabledForegroundColor: UIConstants.colorGrey,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: UIConstants.appOrange, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Clientseitig: Party + abgelaufene temporäre Sperren (ohne Extra-Firestore-Roundtrips).
  List<QueryDocumentSnapshot> _filterBlockedGuestsSync(
    List<QueryDocumentSnapshot> blockedGuests,
    String partyId,
  ) {
    final now = DateTime.now();
    return blockedGuests.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final docPartyId = data['party_id'] as String?;
      if (docPartyId != partyId) return false;
      if (data['block_status'] == 'temporary') {
        final blockedUntil = data['blocked_until'] as Timestamp?;
        if (blockedUntil != null && now.isAfter(blockedUntil.toDate())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _formatDateTime(DateTime date) {
    return FormattingUtils.formatDateTime(date, context);
  }

  Future<void> _showGuestInfoDialog(
    BuildContext context,
    String name,
    String? clientId,
    Map<String, dynamic> blockData,
    String partyId, {
    required String blockedDocId,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    // ✅ Sammle ALLE Songs mit optionalen Grüßen aus blockierten Wünschen
    final List<Map<String, dynamic>> songsWithGreetings = [];
    
    try {
      QuerySnapshot wishesSnapshot;
      
      // ✅ DEBUG: Logge die verwendeten IDs
      debugLog('🔍 GesperrtPage Info-Dialog: Lade blockierte Wünsche');
      debugLog('   party_id: $partyId');
      debugLog('   client_id: (redacted)');
      debugLog('   name: (redacted)');
      
      // ✅ PRÄZISE ABFRAGE: Filter 1-4 wie spezifiziert
      if (clientId != null && clientId.isNotEmpty) {
        wishesSnapshot = await WishPaths.partyWishes(partyId)
            .where('client_id', isEqualTo: clientId) // ✅ Filter 2: Client-ID
            .where('status', isEqualTo: 'rejected') // ✅ Filter 3: Status rejected
            .where('rejection_reason', isEqualTo: 'user_blocked') // ✅ Filter 4: Rejection-Reason
            .get();
        
        debugLog('   ✅ Query ausgeführt mit client_id. Gefundene Dokumente: ${wishesSnapshot.docs.length}');
      } else {
        // Fallback: Suche nach Name (weniger präzise, aber notwendig wenn clientId fehlt)
        debugLog('   ⚠️ Fallback: Query mit name statt client_id');
        wishesSnapshot = await WishPaths.partyWishes(partyId)
            .where('name', isEqualTo: name) // ✅ Filter 2 (Fallback): Name
            .where('status', isEqualTo: 'rejected') // ✅ Filter 3: Status rejected
            .where('rejection_reason', isEqualTo: 'user_blocked') // ✅ Filter 4: Rejection-Reason
            .get();
        
        debugLog('   ✅ Query ausgeführt mit name. Gefundene Dokumente: ${wishesSnapshot.docs.length}');
      }
      
      // ✅ DEBUG: Logge Details jedes gefundenen Dokuments
      for (final doc in wishesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugLog('   📄 Dokument ${doc.id}:');
        debugLog('      title: ${data['title']}');
        debugLog('      artist: ${data['artist']}');
        debugLog('      greeting: ${data['greeting']}');
        debugLog('      greetings: ${data['greetings']}');
        debugLog('      status: ${data['status']}');
        debugLog('      rejection_reason: ${data['rejection_reason']}');
        debugLog('      party_id: ${data['party_id']}');
        debugLog('      client_id: ${data['client_id']}');
      }

      final wishes = wishesSnapshot.docs.toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['created_at'] as Timestamp?)?.toDate() ?? 
                        (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime = (bData['created_at'] as Timestamp?)?.toDate() ?? 
                        (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

      // ✅ Sammle ALLE Songs (mit optionalen Grüßen) aus blockierten Wünschen
      for (final wishDoc in wishes) {
        final wishData = wishDoc.data() as Map<String, dynamic>;
        final createdAt = wishData['createdAt'] as Timestamp?;
        
        final title = wishData['title'] as String?;
        final artist = wishData['artist'] as String?;
        
        // ✅ WICHTIG: Füge ALLE Songs hinzu (auch ohne Titel/Artist, aber nur wenn mindestens eins vorhanden)
        // Wir filtern nicht nach Gruß, sondern zeigen alle gefundenen Songs
        if ((title != null && title.isNotEmpty) || (artist != null && artist.isNotEmpty)) {
          // ✅ KORREKTUR: Nutze KONSEQUENT das Feld 'greeting' (Singular)
          final greetingText = wishData['greeting'] as String?;
          
          // ✅ DEBUG: Logge jeden hinzugefügten Song
          debugLog('   ✅ Füge Song hinzu: "${title ?? 'Kein Titel'}" von "${artist ?? 'Kein Künstler'}"');
          debugLog('      greeting-Feld Wert: "$greetingText"');
          debugLog('      Gruß vorhanden: ${greetingText != null && greetingText.isNotEmpty}');
          
          // ✅ Song mit optionalem Gruß hinzufügen
          songsWithGreetings.add({
            'title': title ?? '',
            'artist': artist ?? '',
            'greeting': greetingText, // ✅ Kann null sein
            'createdAt': createdAt,
          });
        } else {
          debugLog('   ⚠️ Überspringe Dokument ${wishDoc.id}: Kein Titel und kein Artist');
        }
      }
      
      debugLog('   📊 Gesamtanzahl Songs in Liste: ${songsWithGreetings.length}');
    } catch (e) {
      debugLog('❌ GesperrtPage: Fehler beim Laden der Wünsche: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error_loading_info} $e'),
            backgroundColor: UIConstants.frameGesperrt,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: UIConstants.frameGesperrt, width: 2.0),
          ),
          title: Column(
            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Roter Status-Text dezent über dem Namen
              Text(
                l10n.block_status,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: UIConstants.frameGesperrt,
                  letterSpacing: 0.5,
                ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
              ),
              const SizedBox(height: 4),
              // ✅ Name mit Schriftgröße 14
              Text(
                name,
                style: const TextStyle(
                  color: UIConstants.frameGesperrt,
                  fontSize: 14, // ✅ Schriftgröße 14
                  fontWeight: FontWeight.w500,
                ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
              ),
              // ✅ Sperr-Datum dezent darunter
              if (blockData['blocked_at'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDateTime((blockData['blocked_at'] as Timestamp).toDate()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: UIConstants.colorGrey,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                ),
              ],
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Alle Songs anzeigen (mit optionalen Grüßen)
                  if (songsWithGreetings.isNotEmpty) ...[
                    const SizedBox(height: 12), // ✅ Reduzierter Abstand
                    Text(
                      '${l10n.requested_songs} (${songsWithGreetings.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14, // ✅ Reduzierte Schriftgröße
                        color: Colors.white, // ✅ Weißer Text
                      ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    ),
                    const SizedBox(height: 6), // ✅ Reduzierter Abstand
                    // ✅ Liste aller Songs (mit optionalen Grüßen)
                    ...songsWithGreetings.map((songData) {
                      final title = songData['title'] as String? ?? '';
                      final artist = songData['artist'] as String? ?? '';
                      final greetingText = songData['greeting'] as String?;
                      // ✅ ERZWINGE Prüfung: greeting != null und nicht leer
                      final hasGreeting = greetingText != null && greetingText.isNotEmpty && greetingText.trim().isNotEmpty;
                      final createdAt = songData['createdAt'] as Timestamp?;
                      
                      // ✅ DEBUG: Logge für UI-Anzeige
                      debugLog('   🎨 UI: Song "${title}" von "${artist}" - hasGreeting: $hasGreeting, greetingText: "$greetingText"');
                      
                      return Card(
                        color: UIConstants.djShellPageBackground,
                        margin: const EdgeInsets.only(bottom: 6), // ✅ Reduzierter Abstand
                        shape: UIConstants.djChromeCardShape,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // ✅ Kompakteres Padding
                          child: Column(
                            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ✅ ERZWUNgen: Zeige IMMER '${artist} - ${title}'
                              Text(
                                '${artist.isNotEmpty ? artist : l10n.no_artist} - ${title.isNotEmpty ? title : l10n.no_title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14, // ✅ Standard-Bodytext
                                  color: Colors.white, // ✅ Weißer Text
                                ),
                              ),
                              // ✅ Gruß anzeigen (NUR wenn greeting != null und nicht leer)
                              if (hasGreeting) ...[
                                const SizedBox(height: 8),
                                FutureBuilder<String?>(
                                  // ✅ Live-Übersetzung (wenn aktiviert und Sprache abweicht)
                                  future: GreetingTranslator.translateGreetingIfNeeded(greetingText!, context),
                                  builder: (context, translationSnapshot) {
                                    final originalGreeting = greetingText!;
                                    final translatedGreeting = translationSnapshot.data;
                                    final displayGreeting = translatedGreeting ?? originalGreeting;
                                    final showTranslation = translatedGreeting != null && translatedGreeting.isNotEmpty && translatedGreeting != originalGreeting;
                                    
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline, // ✅ Exakt dasselbe Icon wie in WishCard
                                          color: UIConstants.frameOffen,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                displayGreeting,
                                                style: const TextStyle(
                                                  color: UIConstants.frameOffen,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14, // ✅ Standard-Bodytext
                                                ),
                                              ),
                                              if (showTranslation) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  originalGreeting,
                                                  style: TextStyle(
                                                    color: UIConstants.frameOffen.withValues(alpha: 0.8),
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                              // ✅ Zeit anzeigen (wenn vorhanden)
                              if (createdAt != null) ...[
                                const SizedBox(height: 4),
                                Align(
                                  alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Text(
                                    _formatShortTime(createdAt.toDate()),
                                    style: const TextStyle(fontSize: 11, color: UIConstants.colorGrey),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                  if (songsWithGreetings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8), // ✅ Kompakteres Padding
                      child: Text(
                        l10n.no_greetings_or_songs,
                        style: const TextStyle(
                          fontSize: 13,
                          color: UIConstants.colorGrey,
                        ),
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actionsAlignment: isRtl ? MainAxisAlignment.start : MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.close,
                style: const TextStyle(color: Colors.white70), // ✅ Weißer Text
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _unblockGuest(context, blockedDocId, clientId, name, partyId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: UIConstants.frameGespielt,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.unblock),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShortTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _unblockGuest(
    BuildContext context,
    String docId,
    String? clientId,
    String name,
    String partyId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    
    // ✅ Dialog: "Gast wieder freigeben?"
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: UIConstants.frameGesperrt, width: 2.0),
          ),
          title: Text(
            l10n.unblock_guest,
            style: const TextStyle(color: Colors.white),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          content: Text(
            '${l10n.confirm_unblock} $name ${l10n.really_unblock}',
            style: const TextStyle(color: Colors.white),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          actionsAlignment: isRtl ? MainAxisAlignment.start : MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: UIConstants.frameGespielt,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.unblock),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final firestoreDocId = docId.trim();
      if (firestoreDocId.isEmpty) {
        throw StateError('blocked_guests document id missing');
      }

      debugLog('🔓 ENTSPERR: Lösche blocked_guests Dokument: $firestoreDocId');

      await FirebaseFirestore.instance
          .collection('blocked_guests')
          .doc(firestoreDocId)
          .delete();
      
      debugLog('✅ ENTSPERR: Dokument aus blocked_guests gelöscht');

      // ✅ blocked_devices: Bei blockUser wird parallel ein Geräte-Anker gelegt (UserBlockingService).
      // Ohne Löschung bleibt die PWA gesperrt, weil isGuestBlockedFromData dort u. a. "permanent" erkennt.
      if (clientId != null && clientId.isNotEmpty) {
        debugLog('🔓 ENTSPERR: Lösche blocked_devices Dokument: $clientId');
        await FirebaseFirestore.instance
            .collection('blocked_devices')
            .doc(clientId)
            .delete();
        debugLog('✅ ENTSPERR: Dokument aus blocked_devices gelöscht');
      }

      // ✅ Stelle automatisch abgelehnte Wünsche wieder auf "pending"
      // WICHTIG: Nur Wünsche mit rejection_reason: 'user_blocked' wiederherstellen!
      // Manuell abgelehnte Songs (ohne rejection_reason) bleiben rejected
      try {
        final batch = FirebaseFirestore.instance.batch();
        int restoredCount = 0;
        
        if (clientId != null && clientId.isNotEmpty && partyId.isNotEmpty) {
          debugLog('🔓 ENTSPERR: Suche nach Wünschen mit rejection_reason: user_blocked');
          
          // ✅ PRÄZISE QUERY: Nur Wünsche mit rejection_reason: 'user_blocked'
          final wishesQuery = WishPaths.partyWishes(partyId)
              .where('client_id', isEqualTo: clientId)
              .where('status', isEqualTo: 'rejected')
              .where('rejection_reason', isEqualTo: 'user_blocked');
          
          final wishesSnapshot = await wishesQuery.get();
          debugLog('🔓 ENTSPERR: Gefundene Wünsche mit rejection_reason: user_blocked: ${wishesSnapshot.docs.length}');
          
          for (final wishDoc in wishesSnapshot.docs) {
            final wishData = wishDoc.data();
            final currentStatus = wishData['status'] as String?;
            final rejectionReason = wishData['rejection_reason'] as String?;
            
            // ✅ SICHERHEITS-CHECK: Nur Wünsche mit rejection_reason: 'user_blocked' wiederherstellen
            if (currentStatus == 'rejected' && rejectionReason == 'user_blocked') {
              batch.update(wishDoc.reference, {
                'status': 'pending',
                'rejection_reason': FieldValue.delete(), // ✅ Entferne rejection_reason
                'auto_rejected_by_block': FieldValue.delete(), // Kompatibilität
                'rejectedAt': FieldValue.delete(),
              });
              restoredCount++;
              debugLog('✅ ENTSPERR: Wunsch ${wishDoc.id} wird wiederhergestellt (pending)');
            } else {
              debugLog('⚠️ ENTSPERR: Wunsch ${wishDoc.id} übersprungen (Status: $currentStatus, Reason: $rejectionReason)');
            }
          }
          
          if (restoredCount > 0) {
            await batch.commit();
            debugLog('✅✅✅ ENTSPERR: $restoredCount Wünsche wiederhergestellt (pending)');
            
            // ✅ SnackBar mit Anzahl der reaktivierten Songs
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.unblock_user_songs_reactivated(name, restoredCount)),
                  backgroundColor: UIConstants.frameGespielt,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            debugLog('ℹ️ ENTSPERR: Keine Wünsche mit rejection_reason: user_blocked gefunden');
            
            // ✅ SnackBar auch wenn keine Songs reaktiviert wurden
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.unblock_user_wishes_restored(name)),
                  backgroundColor: UIConstants.frameGespielt,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          debugLog('⚠️ ENTSPERR: clientId oder partyId fehlt, kann keine Wünsche wiederherstellen');
        }
      } catch (e) {
        debugLog('⚠️ ENTSPERR: Fehler beim Wiederherstellen der Wünsche: $e');
        // Fehler nicht fatal - Sperre wurde bereits gelöscht
      }

      // ✅ SnackBar wird bereits in der restoredCount-Logik angezeigt
    } catch (e) {
      debugLog('❌ ENTSPERR: Fehler beim Freigeben: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error_unblocking} $e'),
            backgroundColor: UIConstants.frameGesperrt,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Titelleiste mit CustomPageHeader (erstes Kind)
            CustomPageHeader(
              icon: Icons.block,
              title: l10n.blocked_guests,
            ),
            // Content-Bereich (zweites Kind)
            Expanded(
              child: StickyPaginationLayout(
                currentPage: _currentPage > 0 ? _currentPage : 1,
                totalPages: 1,
                onPrevious: null,
                onNext: null,
                child: _buildBlockedGuestsBody(context, l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedGuestsBody(BuildContext context, AppLocalizations l10n) {
    final partyId = _partyIdForPage;
    if (partyId == null || partyId.isEmpty) {
      return const NoActivePartyDisplay();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('blocked_guests')
          .where('party_id', isEqualTo: partyId)
          .where(
            'block_status',
            whereIn: ['party_specific', 'permanent', 'temporary'],
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugLog('❌ GesperrtPage: Stream-Fehler: ${snapshot.error}');
          debugLog('   Party ID: $partyId');
          return Center(
            child: Text(
              '${l10n.error_loading_info} ${snapshot.error}',
              style: const TextStyle(color: UIConstants.frameGesperrt),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: UIConstants.appOrange),
          );
        }

        final filteredGuests = _filterBlockedGuestsSync(
          snapshot.data!.docs,
          partyId,
        );

        if (filteredGuests.isEmpty) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 100),
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: UIConstants.frameGespielt,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.gesperrt_page_empty_active_party,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: UIConstants.colorGrey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: UIConstants.kFooterPadding * 2),
              ],
            ),
          );
        }

        final totalPages = HistoryPaginationService.calculateTotalPages(
          filteredGuests.length,
          itemsPerPage: _resultsPerPage,
        );

        if (_currentPage > totalPages && totalPages > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentPage = totalPages;
              });
            }
          });
        }

        final paginatedGuests = HistoryPaginationService.getItemsForPage(
          filteredGuests,
          _currentPage > 0 ? _currentPage : 1,
          itemsPerPage: _resultsPerPage,
        );

        final bottomPadding = totalPages > 1 ? 8.0 : 150.0;

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              RepaintBoundary(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 8.0,
                    bottom: bottomPadding,
                  ),
                  itemCount: paginatedGuests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = paginatedGuests[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] as String? ?? l10n.unknown;
                    final clientId = data['client_id'] as String?;
                    final blockedAt = data['blocked_at'] as Timestamp?;
                    final djId = data['dj_id'] as String?;

                    return _BlockedGuestCard(
                      key: ValueKey(doc.id),
                      name: name,
                      clientId: clientId,
                      blockedAt: blockedAt,
                      djId: djId,
                      onShowInfo: () => _showGuestInfoDialog(
                        context,
                        name,
                        clientId,
                        data,
                        partyId,
                        blockedDocId: doc.id,
                      ),
                      onUnblock: () => _unblockGuest(
                        context,
                        doc.id,
                        clientId,
                        name,
                        partyId,
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                _buildPaginationButtons(_currentPage, totalPages, context),
              const SizedBox(height: UIConstants.kFooterPadding * 2),
            ],
          ),
        );
      },
    );
  }
}

/// Karte + Historie-Badge per Firestore-Stream (kein Future pro Listen-Refresh).
class _BlockedGuestCard extends StatelessWidget {
  const _BlockedGuestCard({
    super.key,
    required this.name,
    required this.clientId,
    required this.blockedAt,
    required this.djId,
    required this.onShowInfo,
    required this.onUnblock,
  });

  final String name;
  final String? clientId;
  final Timestamp? blockedAt;
  final String? djId;
  final VoidCallback onShowInfo;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cid = clientId?.trim() ?? '';
    final did = djId?.trim() ?? '';

    Widget cardContent(int totalBlockCount) {
      return Stack(
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: UIConstants.djShellPageBackground,
            shape: UIConstants.djChromeCardShape,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: UIConstants.frameGesperrt.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.block,
                  color: UIConstants.frameGesperrt,
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: UIConstants.frameGesperrt,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cid.isNotEmpty)
                    Text(
                      'ID: $cid',
                      style: TextStyle(
                        fontSize: 11,
                        color: UIConstants.frameGesperrt.withValues(alpha: 0.7),
                        fontFamily: 'monospace',
                      ),
                    ),
                  if (blockedAt != null)
                    Text(
                      '${l10n.blocked_at_label} ${FormattingUtils.formatDateTime(blockedAt!.toDate(), context)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: UIConstants.colorGrey,
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: onShowInfo,
                    tooltip: l10n.show_details,
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_open),
                    color: UIConstants.frameGespielt,
                    onPressed: onUnblock,
                    tooltip: l10n.unblock,
                  ),
                ],
              ),
            ),
          ),
          if (totalBlockCount > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: UIConstants.frameGesperrt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.gesperrt_block_history_badge(totalBlockCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (cid.isEmpty || did.isEmpty) {
      return cardContent(1);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('block_history')
          .where('client_id', isEqualTo: cid)
          .where('dj_id', isEqualTo: did)
          .snapshots(),
      builder: (context, historySnapshot) {
        final blockCount = historySnapshot.data?.docs.length ?? 0;
        final totalBlockCount = blockCount > 0 ? blockCount : 1;
        return cardContent(totalBlockCount);
      },
    );
  }
}
