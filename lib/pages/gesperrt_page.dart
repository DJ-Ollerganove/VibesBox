import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../services/active_party_service.dart';
import '../services/history_pagination_service.dart';
import '../services/open_wishes_visibility_service.dart';
import '../services/results_per_page_service.dart';
import '../services/wish_management_service.dart';
import '../utils/formatting_utils.dart';
import '../utils/ui_constants.dart';
import '../widgets/custom_page_header.dart';
import '../widgets/no_active_party_display.dart';
import '../utils/greeting_translator.dart';
import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';
import '../app_scaffold_messenger.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

class GesperrtPage extends StatefulWidget {
  const GesperrtPage({
    super.key,
    this.isActive = false,
  });

  /// Tab sichtbar (IndexedStack) — erzwingt Reload beim Öffnen.
  final bool isActive;

  @override
  State<GesperrtPage> createState() => _GesperrtPageState();
}

class _GesperrtPageState extends State<GesperrtPage> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _visibilityKeepAlive;

  /// Gleicher Cache-Pattern wie [RejectedWishesPage] — Stream nicht bei jedem Build neu.
  String? _cachedPartyId;
  Stream<QuerySnapshot>? _cachedRejectedWishesStream;
  Stream<QuerySnapshot>? _cachedBlockedGuestsStream;

  Stream<QuerySnapshot> _rejectedWishesStreamForParty(String partyId) {
    if (_cachedPartyId != partyId) {
      _cachedPartyId = partyId;
      _cachedRejectedWishesStream =
          WishManagementService.getWishesStream(partyId, 'rejected');
      _cachedBlockedGuestsStream = FirebaseFirestore.instance
          .collection('blocked_guests')
          .where('party_id', isEqualTo: partyId)
          .snapshots();
    }
    return _cachedRejectedWishesStream!;
  }

  Stream<QuerySnapshot> _blockedGuestsStreamForParty(String partyId) {
    if (_cachedPartyId != partyId) {
      _rejectedWishesStreamForParty(partyId);
    }
    return _cachedBlockedGuestsStream!;
  }

  @override
  void initState() {
    super.initState();
    OpenWishesVisibilityService.ensureWatching();
    _visibilityKeepAlive =
        OpenWishesVisibilityService.watch().listen((_) {});
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
  }

  @override
  void dispose() {
    unawaited(_visibilityKeepAlive?.cancel());
    _scrollController.dispose();
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
    final isRtl = VbTextDirection.isRtl(context);

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

  /// Clientseitig: Party-Treffer über Feld ODER Doc-ID (`clientId_partyId`).
  List<QueryDocumentSnapshot> _filterBlockedGuestsSync(
    List<QueryDocumentSnapshot> blockedGuests,
    String partyId,
  ) {
    final now = DateTime.now();
    final suffix = '_$partyId';
    return blockedGuests.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final docPartyId =
          (data['party_id'] ?? data['partyId'] ?? '').toString().trim();
      final idMatch = doc.id.endsWith(suffix);
      if (docPartyId != partyId && !idMatch) return false;
      final blockStatus = (data['block_status'] ?? '').toString().trim();
      if (blockStatus.isNotEmpty &&
          !const {'party_specific', 'permanent', 'temporary'}
              .contains(blockStatus)) {
        return false;
      }
      if (blockStatus == 'temporary') {
        final blockedUntil = data['blocked_until'] as Timestamp?;
        if (blockedUntil != null && now.isAfter(blockedUntil.toDate())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _guestDisplayName(Map<String, dynamic> data) {
    for (final key in ['name', 'guest_name', 'guest', 'blocked_as_name']) {
      final v = (data[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// blocked_guests + blocked_devices + Abgelehnt-Wünsche (user_blocked).
  List<_BlockedGuestRow> _mergeBlockedGuestRows({
    required String partyId,
    required List<QueryDocumentSnapshot> fromBlockedGuests,
    required List<QueryDocumentSnapshot> fromBlockedDevices,
    required List<QueryDocumentSnapshot> rejectedWishDocs,
  }) {
    final byClient = <String, _BlockedGuestRow>{};

    void upsert({
      required String docId,
      required String name,
      required String clientId,
      Timestamp? blockedAt,
      String? djId,
    }) {
      final key = clientId.isNotEmpty
          ? clientId
          : (name.isNotEmpty ? 'name:$name' : 'doc:$docId');
      if (key.startsWith('doc:') && name.isEmpty && clientId.isEmpty) return;
      final existing = byClient[key];
      if (existing != null) {
        if (existing.name.isEmpty && name.isNotEmpty) {
          byClient[key] = _BlockedGuestRow(
            docId: existing.docId,
            name: name,
            clientId: existing.clientId ??
                (clientId.isNotEmpty ? clientId : null),
            blockedAt: existing.blockedAt ?? blockedAt,
            djId: existing.djId ?? djId,
          );
        }
        return;
      }
      byClient[key] = _BlockedGuestRow(
        docId: docId,
        name: name,
        clientId: clientId.isNotEmpty ? clientId : null,
        blockedAt: blockedAt,
        djId: djId,
      );
    }

    for (final doc in fromBlockedGuests) {
      final data = doc.data() as Map<String, dynamic>;
      final clientId = (data['client_id'] ?? '').toString().trim();
      final djRaw = (data['dj_id'] ?? '').toString().trim();
      upsert(
        docId: doc.id,
        name: _guestDisplayName(data),
        clientId: clientId,
        blockedAt: data['blocked_at'] is Timestamp
            ? data['blocked_at'] as Timestamp
            : null,
        djId: djRaw.isEmpty ? null : djRaw,
      );
    }

    for (final doc in fromBlockedDevices) {
      final data = doc.data() as Map<String, dynamic>;
      final docParty =
          (data['party_id'] ?? data['partyId'] ?? '').toString().trim();
      if (docParty.isNotEmpty && docParty != partyId) continue;
      final clientId =
          (data['client_id'] ?? data['device_id'] ?? doc.id).toString().trim();
      final djRaw = (data['dj_id'] ?? '').toString().trim();
      upsert(
        docId: clientId.isNotEmpty ? '${clientId}_$partyId' : doc.id,
        name: _guestDisplayName(data),
        clientId: clientId,
        blockedAt: data['blocked_at'] is Timestamp
            ? data['blocked_at'] as Timestamp
            : null,
        djId: djRaw.isEmpty ? null : djRaw,
      );
    }

    for (final wish in rejectedWishDocs) {
      final data = wish.data() as Map<String, dynamic>;
      final rr = (data['rejection_reason'] ?? '').toString();
      final auto = data['auto_rejected_by_block'] == true;
      if (rr != 'user_blocked' && !auto) continue;

      final clientId = (data['client_id'] ?? '').toString().trim();
      final name = _guestDisplayName(data);
      if (clientId.isEmpty && name.isEmpty) continue;

      Timestamp? blockedAt;
      final raw = data['rejectedAt'] ?? data['rejected_at'] ?? data['createdAt'];
      if (raw is Timestamp) blockedAt = raw;

      upsert(
        docId: clientId.isNotEmpty
            ? '${clientId}_$partyId'
            : 'name_${name}_$partyId',
        name: name,
        clientId: clientId,
        blockedAt: blockedAt,
        djId: null,
      );
    }

    final rows = byClient.values.toList()
      ..sort((a, b) {
        final at = a.blockedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.blockedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    debugLog(
      'GesperrtPage: merge party=$partyId '
      'guests=${fromBlockedGuests.length} '
      'devices=${fromBlockedDevices.length} '
      'wishes=${rejectedWishDocs.length} '
      'rows=${rows.length}',
    );
    return rows;
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
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${l10n.error_loading_info} $e'),
            backgroundColor: UIConstants.frameGesperrt,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final isRtl = VbTextDirection.isRtl(context);

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
    final isRtl = VbTextDirection.isRtl(context);
    
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

      // Nur Wünsche wieder öffnen, die durch die Sperre geschlossen wurden.
      // Manuell Abgelehnte (andere rejection_reason, kein auto_rejected_by_block)
      // bleiben rejected — auch wenn sie vom selben Gast sind.
      try {
        final batch = FirebaseFirestore.instance.batch();
        int restoredCount = 0;

        if (clientId != null && clientId.isNotEmpty && partyId.isNotEmpty) {
          debugLog(
            '🔓 ENTSPERR: Suche durch Sperre geschlossene Wünsche (user_blocked)',
          );

          // Alle rejected dieses Gasts laden, dann strikt filtern:
          // nur user_blocked und/oder auto_rejected_by_block.
          final rejectedSnap = await WishPaths.partyWishes(partyId)
              .where('client_id', isEqualTo: clientId)
              .where('status', isEqualTo: 'rejected')
              .get();
          final wishDocs = rejectedSnap.docs.where((doc) {
            final d = doc.data();
            final rr = d['rejection_reason'] as String?;
            final auto = d['auto_rejected_by_block'] == true;
            return rr == 'user_blocked' || auto;
          }).toList();

          debugLog(
            '🔓 ENTSPERR: rejected gesamt=${rejectedSnap.docs.length}, '
            'nur Block-Rejects=${wishDocs.length}',
          );

          for (final wishDoc in wishDocs) {
            final wishData = wishDoc.data();
            final currentStatus = wishData['status'] as String?;
            final rejectionReason = wishData['rejection_reason'] as String?;
            final autoBlk = wishData['auto_rejected_by_block'] == true;

            // Doppelte Absicherung: nie manuelle Ablehnungen öffnen.
            if (currentStatus == 'rejected' &&
                (rejectionReason == 'user_blocked' || autoBlk)) {
              batch.update(wishDoc.reference, {
                'status': 'pending',
                'rejection_reason': FieldValue.delete(),
                'auto_rejected_by_block': FieldValue.delete(),
                'rejectedAt': FieldValue.delete(),
                'rejected_at': FieldValue.delete(),
              });
              restoredCount++;
              debugLog(
                '✅ ENTSPERR: Wunsch ${wishDoc.id} → pending (Block-Reject)',
              );
            } else {
              debugLog(
                '⚠️ ENTSPERR: Wunsch ${wishDoc.id} übersprungen '
                '(Status: $currentStatus, Reason: $rejectionReason, auto: $autoBlk)',
              );
            }
          }

          if (restoredCount > 0) {
            await batch.commit();
            debugLog(
              '✅✅✅ ENTSPERR: $restoredCount Wünsche wiederhergestellt (pending)',
            );

            if (context.mounted) {
              showVibesSnackBar(
                context,
                SnackBar(
                  content: Text(
                    l10n.unblock_user_songs_reactivated(name, restoredCount),
                  ),
                  backgroundColor: UIConstants.frameGespielt,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            debugLog(
              'ℹ️ ENTSPERR: Keine durch Sperre geschlossenen Wünsche gefunden',
            );

            if (context.mounted) {
              showVibesSnackBar(
                context,
                SnackBar(
                  content: Text(l10n.unblock_user_wishes_restored(name)),
                  backgroundColor: UIConstants.frameGespielt,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          debugLog(
            '⚠️ ENTSPERR: clientId oder partyId fehlt, kann keine Wünsche wiederherstellen',
          );
        }
      } catch (e) {
        debugLog('⚠️ ENTSPERR: Fehler beim Wiederherstellen der Wünsche: $e');
        if (context.mounted) {
          showVibesSnackBar(
            context,
            SnackBar(
              content: Text('${l10n.error_unblocking} $e'),
              backgroundColor: UIConstants.frameGesperrt,
            ),
          );
        }
      }

      // Liste aktualisiert sich über Firestore-Streams von selbst.
    } catch (e) {
      debugLog('❌ ENTSPERR: Fehler beim Freigeben: $e');
      if (context.mounted) {
        showVibesSnackBar(context, 
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
            CustomPageHeader(
              icon: Icons.block,
              title: l10n.blocked_guests,
            ),
            Expanded(
              // Party wie Offen: Visibility → Session → Heartbeat (nicht nur Visibility).
              child: ValueListenableBuilder(
                valueListenable:
                    OpenWishesVisibilityService.visibilityNotifier,
                builder: (context, visibility, _) {
                  return ValueListenableBuilder(
                    valueListenable:
                        ActivePartyService.storedSessionNotifier,
                    builder: (context, session, _) {
                      final partyId =
                          (OpenWishesVisibilityService.resolveDjWishPartyId() ??
                                  visibility?.partyId ??
                                  session?.partyId ??
                                  ActivePartyService.currentPartyId ??
                                  '')
                              .trim();

                      if (partyId.isEmpty) {
                        return const Center(child: NoActivePartyDisplay());
                      }
                      return _buildBlockedGuestsBody(context, l10n, partyId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedGuestsBody(
    BuildContext context,
    AppLocalizations l10n,
    String partyId,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: _blockedGuestsStreamForParty(partyId),
      builder: (context, blockedSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _rejectedWishesStreamForParty(partyId),
          builder: (context, wishesSnap) {
            final err = blockedSnap.error ?? wishesSnap.error;
            if (err != null) {
              debugLog('GesperrtPage stream error: $err');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${l10n.error_loading_info} $err',
                    style: const TextStyle(color: UIConstants.frameGesperrt),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (wishesSnap.connectionState == ConnectionState.waiting &&
                !wishesSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: UIConstants.appOrange),
              );
            }

            final fromGuests = _filterBlockedGuestsSync(
              blockedSnap.data?.docs ?? const [],
              partyId,
            );
            final rows = _mergeBlockedGuestRows(
              partyId: partyId,
              fromBlockedGuests: fromGuests,
              fromBlockedDevices: const [],
              rejectedWishDocs: wishesSnap.data?.docs ?? const [],
            );

            return _buildBlockedGuestsList(context, l10n, partyId, rows);
          },
        );
      },
    );
  }

  Widget _buildBlockedGuestsList(
    BuildContext context,
    AppLocalizations l10n,
    String partyId,
    List<_BlockedGuestRow> rows,
  ) {
    if (rows.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            const SizedBox(height: 24),
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
      rows.length,
      itemsPerPage: _resultsPerPage,
    );
    final page = (_currentPage < 1)
        ? 1
        : (_currentPage > totalPages ? totalPages : _currentPage);
    if (page != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = page);
      });
    }

    final paginatedGuests = HistoryPaginationService.getItemsForPage(
      rows,
      page,
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
          RepaintBoundary(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 8.0, bottom: bottomPadding),
              itemCount: paginatedGuests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = paginatedGuests[index];
                return _BlockedGuestCard(
                  key: ValueKey(row.docId),
                  name: row.name.isNotEmpty ? row.name : l10n.unknown,
                  clientId: row.clientId,
                  blockedAt: row.blockedAt,
                  djId: row.djId,
                  onShowInfo: () => _showGuestInfoDialog(
                    context,
                    row.name.isNotEmpty ? row.name : l10n.unknown,
                    row.clientId,
                    {
                      'name': row.name,
                      'client_id': row.clientId,
                      'dj_id': row.djId,
                      'party_id': partyId,
                      'blocked_at': row.blockedAt,
                    },
                    partyId,
                    blockedDocId: row.docId,
                  ),
                  onUnblock: () => _unblockGuest(
                    context,
                    row.docId,
                    row.clientId,
                    row.name,
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
  }
}

class _BlockedGuestRow {
  const _BlockedGuestRow({
    required this.docId,
    required this.name,
    required this.clientId,
    required this.blockedAt,
    required this.djId,
  });

  final String docId;
  final String name;
  final String? clientId;
  final Timestamp? blockedAt;
  final String? djId;
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
