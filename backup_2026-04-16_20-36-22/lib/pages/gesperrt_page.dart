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

class GesperrtPage extends StatefulWidget {
  const GesperrtPage({super.key});

  @override
  State<GesperrtPage> createState() => _GesperrtPageState();
}

class _GesperrtPageState extends State<GesperrtPage> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  String? _currentPartyId;
  final ScrollController _scrollController = ScrollController(); // ✅ Für Scrollen nach oben beim Seitenwechsel

  @override
  void initState() {
    super.initState();
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
  }

  @override
  void dispose() {
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

  /// Filtert Gäste nach aktueller Party (clientseitig) - verwendet lange partyId
  Future<List<QueryDocumentSnapshot>> _filterGuestsByParty(
    List<QueryDocumentSnapshot> blockedGuests,
    String partyId,
  ) async {
    final filteredGuests = <QueryDocumentSnapshot>[];
    
    for (final doc in blockedGuests) {
      final data = doc.data() as Map<String, dynamic>;
      final clientId = data['client_id'] as String?;
      final name = data['name'] as String?;
      
      // SICHERHEITS-PRÜFUNG: Prüfe ob Dokument zur aktuellen Party gehört
      final docPartyId = data['party_id'] as String?;
      if (docPartyId != partyId) {
        debugLog('🚫 PARTY-FILTER: Gesperrter Gast ${doc.id} gehört zu Party "$docPartyId", erwartet "$partyId" - wird ausgeschlossen');
        continue;
      }
      
      // Prüfe ob temporäre Sperre noch aktiv ist
      final blockStatus = data['block_status'] as String?;
      if (blockStatus == 'temporary') {
        final blockedUntil = data['blocked_until'] as Timestamp?;
        if (blockedUntil != null) {
          final now = DateTime.now();
          final until = blockedUntil.toDate();
          if (now.isAfter(until)) {
            continue; // Sperre ist abgelaufen
          }
        }
      }
      
      // Prüfe ob Gast Wünsche in der aktiven Party hat (gefiltert nach party_id mit langer ID)
      bool hasWishesInParty = false;
      if (clientId != null && clientId.isNotEmpty) {
        final wishesQuery = await FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', isEqualTo: partyId)
            .where('client_id', isEqualTo: clientId)
            .limit(1)
            .get();
        hasWishesInParty = wishesQuery.docs.isNotEmpty;
      } else if (name != null && name.isNotEmpty) {
        final wishesQuery = await FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', isEqualTo: partyId)
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
        hasWishesInParty = wishesQuery.docs.isNotEmpty;
      }
      
      if (hasWishesInParty) {
        filteredGuests.add(doc);
      }
    }
    
    return filteredGuests;
  }

  String _formatDateTime(DateTime date) {
    return FormattingUtils.formatDateTime(date, context);
  }

  Future<void> _showGuestInfoDialog(
    BuildContext context,
    String name,
    String? clientId,
    Map<String, dynamic> blockData,
    String partyId,
  ) async {
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
        wishesSnapshot = await FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', isEqualTo: partyId) // ✅ Filter 1: Lange Party-ID
            .where('client_id', isEqualTo: clientId) // ✅ Filter 2: Client-ID
            .where('status', isEqualTo: 'rejected') // ✅ Filter 3: Status rejected
            .where('rejection_reason', isEqualTo: 'user_blocked') // ✅ Filter 4: Rejection-Reason
            .get();
        
        debugLog('   ✅ Query ausgeführt mit client_id. Gefundene Dokumente: ${wishesSnapshot.docs.length}');
      } else {
        // Fallback: Suche nach Name (weniger präzise, aber notwendig wenn clientId fehlt)
        debugLog('   ⚠️ Fallback: Query mit name statt client_id');
        wishesSnapshot = await FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', isEqualTo: partyId) // ✅ Filter 1: Lange Party-ID
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
                // ✅ WICHTIG: Document-ID = ${clientId}_${partyId}
                final documentId = clientId != null && clientId.isNotEmpty
                    ? '${clientId}_$partyId'
                    : name; // Fallback
                _unblockGuest(context, documentId, clientId, name, partyId);
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

  /// ✅ Hole die Anzahl der Sperren aus block_history für einen Gast
  Future<int> _getBlockHistoryCount(String? clientId, String? djId) async {
    if (clientId == null || clientId.isEmpty || djId == null || djId.isEmpty) {
      return 0;
    }
    
    try {
      final historyQuery = await FirebaseFirestore.instance
          .collection('block_history')
          .where('client_id', isEqualTo: clientId)
          .where('dj_id', isEqualTo: djId)
          .get();
      
      return historyQuery.docs.length;
    } catch (e) {
      debugLog('⚠️ Fehler beim Abrufen der Block-Historie: $e');
      return 0;
    }
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
      // ✅ FENSTER-MANAGEMENT: Schließe alle offenen Dialoge sofort
      int popCount = 0;
      while (Navigator.canPop(context) && popCount < 5) {
        Navigator.pop(context);
        popCount++;
      }
      debugLog('🚪 FENSTER-MANAGEMENT: $popCount Dialog(e) geschlossen');

      // ✅ WICHTIG: Document-ID = ${clientId}_${partyId}
      final documentId = clientId != null && clientId.isNotEmpty
          ? '${clientId}_$partyId'
          : docId; // Fallback falls clientId fehlt
      
      debugLog('🔓 ENTSPERR: Lösche blocked_guests Dokument: $documentId');
      
      // Lösche das Dokument aus blocked_guests
      await FirebaseFirestore.instance
          .collection('blocked_guests')
          .doc(documentId)
          .delete();
      
      debugLog('✅ ENTSPERR: Dokument aus blocked_guests gelöscht');

      // ✅ Stelle automatisch abgelehnte Wünsche wieder auf "pending"
      // WICHTIG: Nur Wünsche mit rejection_reason: 'user_blocked' wiederherstellen!
      // Manuell abgelehnte Songs (ohne rejection_reason) bleiben rejected
      try {
        final batch = FirebaseFirestore.instance.batch();
        int restoredCount = 0;
        
        if (clientId != null && clientId.isNotEmpty && partyId.isNotEmpty) {
          debugLog('🔓 ENTSPERR: Suche nach Wünschen mit rejection_reason: user_blocked');
          
          // ✅ PRÄZISE QUERY: Nur Wünsche mit rejection_reason: 'user_blocked'
          final wishesQuery = FirebaseFirestore.instance
              .collection('wishes')
              .where('client_id', isEqualTo: clientId)
              .where('party_id', isEqualTo: partyId)
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
                child: ValueListenableBuilder<ActivePartyInfo?>(
                  valueListenable: ActivePartyService.storedSessionNotifier,
                  builder: (context, info, _) {
                    final partyId = info?.partyId;
                    if (partyId != null && partyId.isNotEmpty && partyId != _currentPartyId) {
                      _currentPartyId = partyId;
                    } else if (partyId == null || partyId.isEmpty) {
                      _currentPartyId = null;
                    }
                    if (info == null || partyId == null || partyId.isEmpty) {
                      return const NoActivePartyDisplay();
                    }

                    // StreamBuilder für gesperrte Gäste - gefiltert nach party_id
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('blocked_guests')
                          .where('party_id', isEqualTo: partyId)
                          .where('block_status', whereIn: ['party_specific', 'permanent', 'temporary']) // ✅ Inkludiert party_specific
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
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

                        final blockedGuests = snapshot.data?.docs ?? [];
                        
                        debugLog('🔍 [DEBUG] GesperrtPage: Party-ID: $partyId, Gefundene gesperrte Gäste: ${blockedGuests.length}');

                        // SICHERHEITS-PRÜFUNG: Zusätzlicher clientseitiger Filter nach party_id
                        final partyFilteredGuests = blockedGuests.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final docPartyId = data['party_id'] as String?;
                          final matches = docPartyId == partyId;
                          if (!matches && partyId != null) {
                            debugLog('🚫 PARTY-FILTER: Gesperrter Gast ${doc.id} gehört zu Party "$docPartyId", erwartet "$partyId" - wird ausgeschlossen');
                          }
                          return matches;
                        }).toList();
                        
                        debugLog('🔍 [DEBUG] GesperrtPage: Nach Party-ID-Filter: ${partyFilteredGuests.length} von ${blockedGuests.length} Gästen verbleiben');

                        // Filtere Gäste nach aktiver Party (asynchron, zusätzliche Validierung)
                        return FutureBuilder<List<QueryDocumentSnapshot>>(
                          future: _filterGuestsByParty(partyFilteredGuests, partyId),
                          builder: (context, filterSnapshot) {
                            if (filterSnapshot.connectionState == ConnectionState.waiting) {
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

                            final filteredGuests = filterSnapshot.data ?? [];

                            // Spezialfall: Party aktiv, aber Liste leer
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

                            // ✅ Paginierung: Berechne Seiten (Ergebnisse pro Seite aus Einstellungen)
                            final totalPages = HistoryPaginationService.calculateTotalPages(filteredGuests.length, itemsPerPage: _resultsPerPage);
                            
                            // ✅ Stelle sicher, dass _currentPage automatisch korrigiert wird, wenn die Gesamtanzahl der Seiten sinkt
                            if (_currentPage > totalPages && totalPages > 0) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _currentPage = totalPages;
                                  });
                                }
                              });
                            }

                            // ✅ Hole paginierte Liste
                            final paginatedGuests = HistoryPaginationService.getItemsForPage(
                              filteredGuests,
                              _currentPage > 0 ? _currentPage : 1,
                              itemsPerPage: _resultsPerPage,
                            );

                            // ✅ Variable Logik für bottomPadding
                            // ✅ Kompakteres bottomPadding für weniger Abstand zwischen Gästen und Paginierungs-Buttons
                            final bottomPadding = totalPages > 1 ? 8.0 : 150.0;

                            return SingleChildScrollView(
                              controller: _scrollController, // ✅ ScrollController für Scrollen nach oben
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
                                      separatorBuilder: (_, __) => const SizedBox(height: 8), // ✅ Keine Divider, nur Abstand
                                      itemBuilder: (context, index) {
                                        final doc = paginatedGuests[index];
                                        final data = doc.data() as Map<String, dynamic>;
                                        final name = data['name'] as String? ?? l10n.unknown;
                                        final clientId = data['client_id'] as String?;
                                        final blockStatus = data['block_status'] as String?;
                                        final blockedAt = data['blocked_at'] as Timestamp?;
                                        final djId = data['dj_id'] as String?;

                                        return FutureBuilder<int>(
                                          // ✅ Historie-Badge: Anzahl der Sperren aus block_history
                                          future: _getBlockHistoryCount(clientId, djId),
                                          builder: (context, historySnapshot) {
                                            final blockCount = historySnapshot.data ?? 0;
                                            
                                            // ✅ Zähler-Fix: Inklusive aktueller Sperre (+1)
                                            final totalBlockCount = blockCount > 0 ? blockCount : 1; // Mindestens 1 (aktuelle Sperre)
                                            
                                            return Stack(
                                              children: [
                                                Card(
                                                  key: ValueKey(doc.id),
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
                                                        // ✅ Zeige Fingerprint-ID (clientId)
                                                        if (clientId != null && clientId.isNotEmpty)
                                                          Text(
                                                            'ID: $clientId',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: UIConstants.frameGesperrt.withValues(alpha: 0.7),
                                                              fontFamily: 'monospace',
                                                            ),
                                                          ),
                                                        // ✅ Status-Texte entfernt (nur Sperr-Datum)
                                                        if (blockedAt != null)
                                                          Text(
                                                            '${l10n.blocked_at_label} ${_formatDateTime(blockedAt.toDate())}',
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
                                                          onPressed: () => _showGuestInfoDialog(
                                                            context,
                                                            name,
                                                            clientId,
                                                            data,
                                                            partyId,
                                                          ),
                                                          tooltip: l10n.show_details,
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(Icons.lock_open),
                                                          color: UIConstants.frameGespielt,
                                                          onPressed: () {
                                                            // ✅ WICHTIG: Document-ID = ${clientId}_${partyId}
                                                            final documentId = clientId != null && clientId.isNotEmpty
                                                                ? '${clientId}_$partyId'
                                                                : doc.id; // Fallback
                                                            _unblockGuest(context, documentId, clientId, name, partyId);
                                                          },
                                                          tooltip: l10n.unblock,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                // ✅ Historie-Badge: Position rechts oberhalb der Buttons
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
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  // ✅ Paginierungs-Buttons (nur wenn mehr als 1 Seite) - ROT statt Orange/Blau/Grün
                                  if (totalPages > 1) _buildPaginationButtons(_currentPage, totalPages, context),
                                  const SizedBox(height: UIConstants.kFooterPadding * 2),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
