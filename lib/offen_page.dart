import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart' show buildFirebaseErrorWidget;
import 'l10n/app_localizations.dart';
import '../services/active_party_service.dart';
import '../services/history_pagination_service.dart';
import '../services/wish_management_service.dart';
import '../services/user_blocking_service.dart';
import '../services/duplicate_check_service.dart';
import '../services/results_per_page_service.dart';
import '../utils/ui_constants.dart';
import '../utils/string_utils.dart';
import '../utils/wish_grouping_helper.dart';
import '../models/song_request.dart';
import '../widgets/empty_list_message.dart';
import '../widgets/sticky_pagination_layout.dart';
import '../widgets/wish_card.dart';
import '../widgets/no_active_party_display.dart';
import '../widgets/pro_promotion_banner.dart';
import '../services/user_service.dart';
import 'utils/debug_log.dart';

class OffenPage extends StatefulWidget {
  final List<SongRequest> requests;
  final VoidCallback? onPageOpened;
  final ValueNotifier<bool>? showOnlyFavoritesNotifier;

  const OffenPage({
    super.key,
    required this.requests,
    this.onPageOpened,
    this.showOnlyFavoritesNotifier,
  });

  @override
  State<OffenPage> createState() => _OffenPageState();
}

// Öffentliche abstrakte Klasse für den State, damit MainPage/DjVibesBoxPage darauf zugreifen kann
abstract class OffenPageState extends State<OffenPage> {
  List<String> getCurrentVisibleIds();
}

class _OffenPageState extends OffenPageState
    with AutomaticKeepAliveClientMixin {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  List<String> _currentVisibleIds =
      []; // Liste der aktuell angezeigten Dokument-IDs
  final ScrollController _scrollController =
      ScrollController(); // ✅ Für Scrollen nach oben beim Seitenwechsel
  bool _hasFavorites = false; // Prüft ob Favoriten vorhanden sind

  /// Gleiche Party: Stream-Instanz beibehalten — sonst neu-Subscribe bei jedem
  /// [storedSessionNotifier]-Tick → Flackern, Scroll-Sprung, doppelte Events.
  String? _cachedPendingStreamPartyId;
  Stream<QuerySnapshot>? _cachedPendingWishesStream;

  StreamSubscription<QuerySnapshot>? _favoritePresenceSub;
  String? _favoritePresencePartyId;

  Stream<QuerySnapshot> _pendingWishesStreamForParty(String partyId) {
    if (_cachedPendingStreamPartyId != partyId) {
      _cachedPendingStreamPartyId = partyId;
      _cachedPendingWishesStream =
          WishManagementService.getWishesStream(partyId, 'pending');
    }
    return _cachedPendingWishesStream!;
  }

  void _ensureFavoritePresenceListener(String partyId) {
    if (_favoritePresencePartyId == partyId && _favoritePresenceSub != null) {
      return;
    }
    unawaited(_favoritePresenceSub?.cancel());
    _favoritePresencePartyId = partyId;
    _favoritePresenceSub = FirebaseFirestore.instance
        .collection('wishes')
        .where('party_id', isEqualTo: partyId)
        .where('status', isEqualTo: 'pending')
        .where('is_favorite', isEqualTo: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          final hasFavorites = snapshot.docs.isNotEmpty;
          if (_hasFavorites != hasFavorites && mounted) {
            setState(() {
              _hasFavorites = hasFavorites;
            });
          }
        });
  }

  void _tearDownPartyStreams() {
    _cachedPendingStreamPartyId = null;
    _cachedPendingWishesStream = null;
    unawaited(_favoritePresenceSub?.cancel());
    _favoritePresenceSub = null;
    _favoritePresencePartyId = null;
  }

  @override
  bool get wantKeepAlive => true; // Tab-State beim Wechsel zu Gespielt/Abgelehnt erhalten – verhindert dispose + Neubau

  @override
  void initState() {
    super.initState();
    _currentVisibleIds = []; // Erstelle leere Liste
    widget.showOnlyFavoritesNotifier?.addListener(_onFavoritesFilterChanged);
    // Lade party_settings/current (duplicate_threshold + ignored_keywords) für Duplikat-Gruppierung
    DuplicateCheckService.ensurePartySettingsLoaded();
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
  }

  /// Prüft ob Favoriten vorhanden sind
  void _onFavoritesFilterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Massen-Update beim Verlassen entfernt: Es führte beim Tab-Wechsel (oder Route-Wechsel) dazu,
    // dass die Liste neu geladen wurde und Songs scheinbar verschwanden. "Gelesen" wird weiterhin
    // beim Öffnen der Detailansicht (WishCard._markWishesAsSeen) gesetzt.
    widget.showOnlyFavoritesNotifier?.removeListener(_onFavoritesFilterChanged);
    unawaited(_favoritePresenceSub?.cancel());
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

  /// Baut die Paginierungs-Buttons mit Blau/Schwarz Design (passend zu Offen-Songs)
  Widget _buildPaginationButtons(
    int currentPage,
    int totalPages,
    BuildContext context,
  ) {
    final l = AppLocalizations.of(context)!;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(
        top: 8,
        bottom: 16,
      ), // ✅ Kompakter oberer Abstand (8px statt 16px), unterer Abstand bleibt für Footer
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
            label: Text(l.history_page_previous),
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
            '${l.history_page} $currentPage / $totalPages',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          // Vor-Button
          ElevatedButton.icon(
            onPressed:
                HistoryPaginationService.hasNextPage(currentPage, totalPages)
                ? () => _goToNextPage(totalPages)
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_back : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(l.history_page_next),
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

  /// Gibt die aktuell angezeigten Wunsch-IDs zurück (für Navigation-basierte Speicherung)
  @override
  List<String> getCurrentVisibleIds() {
    return List<String>.from(_currentVisibleIds);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // erforderlich für AutomaticKeepAliveClientMixin

    return StickyPaginationLayout(
      currentPage: _currentPage > 0 ? _currentPage : 1,
      totalPages: 1,
      onPrevious: null,
      onNext: null,
      child: ValueListenableBuilder<ActivePartyInfo?>(
        valueListenable: ActivePartyService.storedSessionNotifier,
        builder: (context, info, _) {
          // Zentrale Session: nur storedSessionNotifier – kein Prefs-Fallback (Geister-Partys vermeiden).
          // Key erzwingt sauberen Rebuild bei Party-Wechsel.
          final activePartyId = info?.partyId;
          if (activePartyId == null || activePartyId.isEmpty) {
            _tearDownPartyStreams();
            return const KeyedSubtree(
              key: ValueKey<String>('none'),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(child: NoActivePartyDisplay()),
                  ),
                ],
              ),
            );
          }
          _ensureFavoritePresenceListener(activePartyId);
          return KeyedSubtree(
            key: ValueKey<String>(activePartyId),
            // Kein Prefs-Fallback: nur zentrale Session – sonst „Geister-Party“ bei verzögertem clear.
            child: StreamBuilder<QuerySnapshot>(
              stream: _pendingWishesStreamForParty(activePartyId),
              builder: (context, snapshot) => _buildWishesListWithPartyId(
                context,
                snapshot,
                activePartyId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWishesListWithPartyId(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot> snapshot,
    String partyId,
  ) {
    // Nur beim allerersten Laden ohne Daten: leere Platzhalter-UI (kein erneutes
    // „Leerflackern“ bei Stream-Neuaufbau, solange bereits Snapshots da waren).
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return SingleChildScrollView(
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
            EmptyListMessage(),
            const SizedBox(height: UIConstants.kFooterPadding * 2),
          ],
        ),
      );
    }

    // STREAM-ERROR-LOGGING: Detaillierte Fehlerausgabe
    if (snapshot.hasError) {
      debugLog('❌❌❌ STREAM FEHLER in offen_page.dart ❌❌❌');
      debugLog('   Error: ${snapshot.error}');
      debugLog('   Error Type: ${snapshot.error.runtimeType}');
      debugLog('   Party ID: ${ActivePartyService.currentPartyId}');
      if (snapshot.error is Error) {
        debugLog('   Stack Trace: ${(snapshot.error as Error).stackTrace}');
      }
      return buildFirebaseErrorWidget(snapshot.error!);
    }

    final wishesDocs = snapshot.data?.docs ?? [];

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] OffenPage: Party-ID: $partyId, Gefundene Wünsche: ${wishesDocs.length}',
      );
      if (wishesDocs.isEmpty) {
        debugLog('⚠️ [DEBUG] Keine Wünsche gefunden für Party-ID: $partyId');
      }
    }

    // SICHERHEITS-PRÜFUNG: Filter nach party_id (partyId wie History/Gesperrt)
    final partyFilteredDocs = wishesDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final docPartyId = data['party_id'] as String?;
      final matches = docPartyId == partyId;
      if (kDebugMode && !matches) {
        debugLog(
          '🚫 PARTY-FILTER: Dokument ${doc.id} gehört zu Party "$docPartyId", erwartet "$partyId" - wird ausgeschlossen',
        );
      }
      return matches;
    }).toList();

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] OffenPage: Nach Party-ID-Filter: ${partyFilteredDocs.length} von ${wishesDocs.length} Dokumenten verbleiben',
      );
    }

    // Sammle alle docIds der aktuell angezeigten Wünsche
    _currentVisibleIds.clear();
    for (final doc in partyFilteredDocs) {
      _currentVisibleIds.add(doc.id);
    }

    // Prüfe createdAt-Typ (Debug-Logging)
    for (final doc in partyFilteredDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAtValue = data['createdAt'];
      if (kDebugMode &&
          createdAtValue != null &&
          createdAtValue is! Timestamp) {
        debugLog(
          '⚠️ ZEIT-FEHLER: createdAt ist kein Timestamp, sondern ${createdAtValue.runtimeType} (Dokument-ID: ${doc.id})',
        );
      }
    }

    // Verwende partyFilteredDocs direkt (is_duplicate Filter entfernt, da Gruppierung jetzt party-spezifisch ist)
    final filteredDocs = partyFilteredDocs;

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] OffenPage: Nach Duplikat-Filter: ${filteredDocs.length} von ${wishesDocs.length} Dokumenten verbleiben',
      );
    }

    // Konvertiere zu SongRequest Objekten (mit Error-Handling)
    final openWishes = <SongRequest>[];
    final seenOpenWishDocIds = <String>{};
    for (final doc in filteredDocs) {
      if (!seenOpenWishDocIds.add(doc.id)) {
        if (kDebugMode) {
          debugLog(
            '⚠️ OffenPage: doppelte Dokument-ID im Snapshot übersprungen: ${doc.id}',
          );
        }
        continue;
      }
      try {
        final songRequest = SongRequest.fromDocument(doc);
        openWishes.add(songRequest);
      } catch (e, stackTrace) {
        debugLog('❌ Fehler beim Konvertieren von Dokument ${doc.id}: $e');
        debugLog('   Stack: $stackTrace');
        debugLog('   Document Data: ${doc.data()}');
        // Überspringe dieses Dokument, damit die App weiterläuft
        continue;
      }
    }

    if (kDebugMode) {
      debugLog(
        '🔍 [DEBUG] OffenPage: Nach Mapping: ${openWishes.length} SongRequest-Objekte erstellt',
      );
    }
    if (kDebugMode && partyId == 'B5wSVwhA67bM5Igp7wj2') {
      debugLog(
        '🔍 [DEBUG] OffenPage (Party B5wSVwhA67bM5Igp7wj2): docs=${wishesDocs.length} openWishes=${openWishes.length}',
      );
    }

    // Favoriten-Filter: Nur Markierte anzeigen, wenn Filter aktiv
    final showOnlyFavorites = widget.showOnlyFavoritesNotifier?.value == true;
    final wishesToShow = showOnlyFavorites
        ? openWishes.where((r) => r.isFavorite == true).toList()
        : openWishes;
    if (kDebugMode && partyId == 'B5wSVwhA67bM5Igp7wj2') {
      debugLog(
        '🔍 [DEBUG] OffenPage (Party B5wSVwhA67bM5Igp7wj2): showOnlyFavorites=$showOnlyFavorites wishesToShow=${wishesToShow.length}',
      );
    }

    // Wenn Liste leer: Hinweis, ob Filter "Nur Favoriten" Wünsche ausblendet (verhindert "Song ist weg"-Eindruck)
    if (wishesToShow.isEmpty) {
      final hiddenByFilter = showOnlyFavorites && openWishes.isNotEmpty;
      final l10n = AppLocalizations.of(context)!;
      return SingleChildScrollView(
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
            if (showOnlyFavorites && widget.showOnlyFavoritesNotifier != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () {
                      widget.showOnlyFavoritesNotifier!.value = false;
                    },
                    icon: const Icon(Icons.arrow_back, size: 22),
                    label: Text(l10n.back),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
            if (hiddenByFilter)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.offen_favorites_hidden(openWishes.length),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            EmptyListMessage(),
            const SizedBox(height: UIConstants.kFooterPadding * 2),
          ],
        ),
      );
    }

    // Sortiere nach createdAt (neueste zuerst)
    final sortedWishes = wishesToShow.toList()
      ..sort((a, b) {
        final tsA =
            a.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tsB =
            b.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tsB.compareTo(tsA);
      });

    // Gruppiere Wünsche
    final groupedResult = WishGroupingHelper.groupWishes(
      sortedWishes,
      sessionPartyId: partyId,
    );
    final allGroupedList =
        groupedResult['groups'] as List<Map<String, dynamic>>;
    final groupedFirstRequests =
        groupedResult['firstRequests'] as Map<String, SongRequest>;
    final groupedDocIds = groupedResult['docIds'] as Map<String, List<String>>;

    // Paginierung: Berechne Seiten (Ergebnisse pro Seite aus Einstellungen)
    final totalPages = HistoryPaginationService.calculateTotalPages(
      allGroupedList.length,
      itemsPerPage: _resultsPerPage,
    );

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

    // ✅ Reset auf Seite 1 bei neuem Stream (wenn sich Daten ändern)
    // Wird automatisch durch Stream-Update getriggert

    // Hole paginierte Liste
    final paginatedGroupedList = HistoryPaginationService.getItemsForPage(
      allGroupedList,
      _currentPage > 0 ? _currentPage : 1,
      itemsPerPage: _resultsPerPage,
    );

    // Variable Logik für bottomPadding
    // ✅ Kompakteres bottomPadding für weniger Abstand zwischen Songs und Paginierungs-Buttons
    // ✅ Vergleichbar mit history_dj.dart (dort: 8.0)
    final bottomPadding = totalPages > 1 ? 8.0 : 150.0;

    final l10nList = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      key: PageStorageKey<String>('offen_pending_scroll_$partyId'),
      controller:
          _scrollController, // ✅ ScrollController für Scrollen nach oben
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
          if (showOnlyFavorites && widget.showOnlyFavoritesNotifier != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    widget.showOnlyFavoritesNotifier!.value = false;
                  },
                  icon: const Icon(Icons.arrow_back, size: 22),
                  label: Text(l10nList.back),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
          RepaintBoundary(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 8.0, bottom: bottomPadding),
              itemCount: () {
                final len = paginatedGroupedList.length;
                final isFree =
                    UserService().sessionProStatus.value?.isActive != true;
                return isFree ? len + (len / 5).floor() : len;
              }(),
              itemBuilder: (context, index) {
                final isFree =
                    UserService().sessionProStatus.value?.isActive != true;
                if (isFree && index % 6 == 5) {
                  return const ProPromotionBanner();
                }
                final dataIndex = index - (index ~/ 6);
                final groupEntry = paginatedGroupedList[dataIndex];
                final groupKey = groupEntry['key'] as String;
                final data = groupEntry['data'] as Map<String, dynamic>;
                final docIds = groupedDocIds[groupKey]!;

                final number =
                    allGroupedList.length -
                    (HistoryPaginationService.calculateStartIndex(
                          _currentPage > 0 ? _currentPage : 1,
                          itemsPerPage: _resultsPerPage,
                        ) +
                        dataIndex);

                // Prüfe ob Wunsch als "NEU" markiert werden soll
                // Ein Wunsch ist neu, wenn mindestens eine seiner docIds NICHT im seenWishIds Set ist
                final isNew = docIds.any(
                  (docId) => !ActivePartyService.seenWishIds.contains(docId),
                );

                // Füge alle docIds dieser Gruppe zu _currentVisibleIds hinzu (falls noch nicht vorhanden)
                for (final docId in docIds) {
                  if (!_currentVisibleIds.contains(docId)) {
                    _currentVisibleIds.add(docId);
                  }
                }

                final titleDisp = unescapeHtml((data['title'] ?? '') as String);
                final artistDisp = unescapeHtml((data['artist'] ?? '') as String);
                final displayText = titleDisp.isNotEmpty && artistDisp.isNotEmpty
                    ? '$titleDisp - $artistDisp'
                    : (titleDisp.isNotEmpty ? titleDisp : artistDisp);

                return Stack(
                  children: [
                    WishCard(
                      key: ValueKey(
                        'offen-$partyId-$groupKey-$dataIndex',
                      ),
                      request:
                          groupedFirstRequests[groupKey], // ✅ FIX: Übergib originales SongRequest mit clientId
                      groupedData: data,
                      docIds: docIds,
                      type: WishCardType.offen,
                      number: number,
                      isNew: isNew,
                      // Kein onTap: volle Detailansicht der WishCard (mit Namen & Grüßen) wird geöffnet
                      onPlay: (ctx, ids) {
                        debugLog(
                          '>>> UI: Rufe jetzt den Dialog auf (von WishCard)',
                        );
                        if (ActivePartyService.currentPartyId != null &&
                            ActivePartyService.currentPartyId!.isNotEmpty) {
                          WishManagementService.showConfirmUpdateGroupedStatusDialog(
                            ctx,
                            ids,
                            'played',
                            AppLocalizations.of(ctx)!.mark_as_played,
                            displayText,
                            ActivePartyService.currentPartyId!,
                          );
                        } else {
                          debugLog(
                            '⚠️ Offen/onPlay: keine Party-ID – Dialog übersprungen',
                          );
                        }
                      },
                      onReject: (ctx, ids) {
                        final title = unescapeHtml((data['title'] ?? '') as String);
                        final artist = unescapeHtml((data['artist'] ?? '') as String);
                        final displayText =
                            title.isNotEmpty && artist.isNotEmpty
                            ? '$title - $artist'
                            : (title.isNotEmpty ? title : artist);
                        if (ActivePartyService.currentPartyId != null &&
                            ActivePartyService.currentPartyId!.isNotEmpty) {
                          WishManagementService.showConfirmUpdateGroupedStatusDialog(
                            ctx,
                            ids,
                            'rejected',
                            AppLocalizations.of(ctx)!.reject,
                            displayText,
                            ActivePartyService.currentPartyId!,
                          );
                        } else {
                          debugLog(
                            '⚠️ Offen/onReject: keine Party-ID – Dialog übersprungen',
                          );
                        }
                      },
                      onDelete: (ctx, ids) {
                        final title = unescapeHtml((data['title'] ?? '') as String);
                        final artist = unescapeHtml((data['artist'] ?? '') as String);
                        final displayText =
                            title.isNotEmpty && artist.isNotEmpty
                            ? '$title - $artist'
                            : (title.isNotEmpty ? title : artist);
                        if (ActivePartyService.currentPartyId != null &&
                            ActivePartyService.currentPartyId!.isNotEmpty) {
                          WishManagementService.showConfirmDeleteGroupedDialog(
                            ctx,
                            ids,
                            displayText,
                            ActivePartyService.currentPartyId!,
                          );
                        } else {
                          debugLog(
                            '⚠️ Offen/onDelete: keine Party-ID – Dialog übersprungen',
                          );
                        }
                      },
                      onBlockGrouped: (ctx, req, dataMap, ids) =>
                          UserBlockingService.showGroupedBlockDialog(
                            ctx,
                            req,
                            dataMap,
                            ids,
                          ),
                    ),
                    // NEU-Badge ENTFERNT (wird jetzt durch Hintergrundfarbe signalisiert)
                  ],
                );
              },
            ),
          ),
          // ✅ Paginierungs-Buttons (nur wenn mehr als 1 Seite) - BLAU statt Orange
          if (totalPages > 1)
            _buildPaginationButtons(_currentPage, totalPages, context),
          const SizedBox(height: UIConstants.kFooterPadding * 2),
        ],
      ),
    );
  }
}
