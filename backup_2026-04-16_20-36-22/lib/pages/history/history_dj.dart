import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/playlist_model.dart';
import '../../services/active_party_service.dart';
import '../../services/history_pagination_service.dart';
import '../../services/results_per_page_service.dart';
import '../../utils/ui_constants.dart';
import '../../widgets/empty_list_message.dart';
import '../../widgets/sticky_pagination_layout.dart';
import '../../widgets/custom_page_header.dart';
import '../../widgets/no_active_party_display.dart';
import '../../widgets/pro_promotion_banner.dart';
import '../../services/user_service.dart';
import 'archived_playlists_page.dart';
import 'widgets/song_tile.dart';
import '../../utils/debug_log.dart';

/// DJ/Admin-Ansicht für die Musik-History
/// Filtert nach party_code der aktiven Party
class HistoryDjPage extends StatefulWidget {
  const HistoryDjPage({super.key});

  @override
  State<HistoryDjPage> createState() => _HistoryDjPageState();
}

class _HistoryDjPageState extends State<HistoryDjPage> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  String? _currentPartyId;
  String? _currentSessionId;

  // Stream nur auf music_history/{currentSessionId}/tracks (Session aus ActivePartyService)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tracksSubscription;
  final StreamController<List<Map<String, dynamic>>> _tracksController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final List<Map<String, dynamic>> _accumulatedTracks = [];

  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
  }

  /// Navigiert zur vorherigen Seite
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
    }
  }

  /// Navigiert zur nächsten Seite
  void _goToNextPage(int totalPages) {
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
      });
    }
  }

  /// Baut die Paginierungs-Buttons mit Orange/Schwarz Design
  Widget _buildPaginationButtons(int currentPage, int totalPages, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
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

  /// Lädt alle Tracks für eine Session (clientseitig sortiert)
  Future<List<Map<String, dynamic>>> _loadSessionTracks(String sessionId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('music_history')
          .doc(sessionId)
          .collection('tracks')
          .get();

      return snapshot.docs.map((doc) {
        final docData = doc.data();
        return {
          'track': TrackEntry.fromFirestore(docData),
          'trackId': doc.id,
          'sessionId': sessionId,
        };
      }).toList()
        ..sort((a, b) {
          final trackA = a['track'] as TrackEntry;
          final trackB = b['track'] as TrackEntry;
          return trackB.timestamp.compareTo(trackA.timestamp); // Descending (neueste zuerst)
        });
    } catch (e) {
      debugLog('❌ History: Fehler beim Laden der Tracks für Session $sessionId: $e');
      return [];
    }
  }

  /// Lädt alle Tracks für eine Party (nach partyId gefiltert)
  /// STRICT ISOLATION: Serverseitige Filterung nach partyId (lange ID)
  Future<List<Map<String, dynamic>>> _loadTracksForPartyId(String partyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // VALIDIERUNG: Stelle sicher, dass partyId die lange ID ist
      if (partyId.isEmpty || partyId == 'manual') {
        debugLog('⚠️ HistoryDjPage: Ungültige partyId: $partyId');
        return [];
      }

      // Feld-Konsistenz: party_id (lange ID mit Unterstrich) für alle Abfragen
      debugLog('ANALYSE [History-Fetch]: Suche mit party_id = $partyId');
      debugLog('ANALYSE [Auth]: eingeloggt');
      debugLog('[DEBUG-UI] Lade music_history Sessions');
      var sessionsSnapshot = await FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: user.uid)
          .where('party_id', isEqualTo: partyId)
          .get();
      if (sessionsSnapshot.docs.isEmpty) {
        sessionsSnapshot = await FirebaseFirestore.instance
            .collection('music_history')
            .where('djId', isEqualTo: user.uid)
            .where('partyId', isEqualTo: partyId)
            .get();
      }
      debugLog('ANALYSE [History-Data]: Empfangen wurden ${sessionsSnapshot.docs.length} Dokumente (Sessions)');
      debugLog('[DEBUG-UI] Gefundene Sessions für Party $partyId: ${sessionsSnapshot.docs.length}');

      final allTracks = <Map<String, dynamic>>[];
      for (final sessionDoc in sessionsSnapshot.docs) {
        final sessionData = sessionDoc.data();
        final sessionPartyId = sessionData['party_id'] as String? ?? sessionData['partyId'] as String?;
        if (sessionPartyId != partyId) continue;
        final sessionTracks = await _loadSessionTracks(sessionDoc.id);
        allTracks.addAll(sessionTracks);
      }

      // Sortiere alle Tracks nach timestamp (neueste zuerst)
      allTracks.sort((a, b) {
        final trackA = a['track'] as TrackEntry;
        final trackB = b['track'] as TrackEntry;
        return trackB.timestamp.compareTo(trackA.timestamp);
      });

      return allTracks;
    } catch (e) {
      debugLog('ANALYSE [History-Error]: Firebase meldet folgenden Fehler: $e');
      debugLog('❌ History: Fehler beim Laden der Tracks für partyId $partyId: $e');
      return [];
    }
  }

  /// Initialisiert den Live-Stream auf music_history/{sessionId}/tracks.
  /// Session-ID kommt aus ActivePartyService; nur DocumentChangeType.added/removed werden verarbeitet.
  void _initializeTracksStream(String partyId, String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) {
      _tracksSubscription?.cancel();
      _tracksSubscription = null;
      _accumulatedTracks.clear();
      _currentSessionId = null;
      _currentPartyId = partyId;
      if (!_tracksController.isClosed) _tracksController.add([]);
      setState(() {
        _currentPage = 1;
        _isInitialLoading = false;
      });
      return;
    }

    if (_currentSessionId == sessionId && _tracksSubscription != null) {
      return;
    }

    _tracksSubscription?.cancel();
    _accumulatedTracks.clear();
    _currentPartyId = partyId;
    _currentSessionId = sessionId;
    setState(() {
      _currentPage = 1;
      _isInitialLoading = true;
    });
    if (!_tracksController.isClosed) _tracksController.add([]);

    _tracksSubscription = FirebaseFirestore.instance
        .collection('music_history')
        .doc(sessionId)
        .collection('tracks')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      debugLog('ANALYSE [History-Data]: Empfangen wurden ${snapshot.docs.length} Dokumente (Tracks)');
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          if (data != null) {
            _accumulatedTracks.add({
              'track': TrackEntry.fromFirestore(data),
              'sessionId': sessionId,
              'trackId': doc.id,
            });
          }
        } else if (change.type == DocumentChangeType.removed) {
          _accumulatedTracks.removeWhere((e) => e['trackId'] == change.doc.id);
        }
      }
      _accumulatedTracks.sort((a, b) {
        final tA = a['track'] as TrackEntry;
        final tB = b['track'] as TrackEntry;
        return tB.timestamp.compareTo(tA.timestamp);
      });
      if (mounted && !_tracksController.isClosed) {
        _tracksController.add(List<Map<String, dynamic>>.from(_accumulatedTracks));
      }
      if (_isInitialLoading && mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }, onError: (e) {
      debugLog('ANALYSE [History-Error]: Firebase meldet folgenden Fehler: $e');
      if (e.toString().contains('index') || e.toString().contains('Index')) {
        debugLog('ANALYSE [Index-Check]: Fehler enthält Index-Hinweis – prüfe ob Link zur Index-Erstellung in der Fehlermeldung steht.');
      }
      debugLog('❌ HistoryDjPage: Fehler im Tracks-Stream: $e');
      if (mounted && !_tracksController.isClosed) {
        _tracksController.add([]);
      }
      if (mounted) setState(() => _isInitialLoading = false);
    });
  }

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    _tracksController.close();
    super.dispose();
  }

  /// Zeigt Bestätigungsdialog zum Löschen eines Tracks
  Future<void> _showDeleteDialog(
    BuildContext context,
    TrackEntry track,
    String sessionId,
    String trackId,
  ) async {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: UIConstants.frameHistory, width: 2.0),
          ),
          title: Text(
            l.history_delete_song_title,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                l.history_label_title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: UIConstants.colorGrey,
                    ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
              ),
              Text(
                track.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
              ),
              const SizedBox(height: 12),
              Text(
                l.history_label_artist,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: UIConstants.colorGrey,
                    ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
              ),
              Text(
                track.artist,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
              ),
            ],
          ),
          actionsAlignment: isRtl ? MainAxisAlignment.start : MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: UIConstants.frameNoParty),
              child: Text(l.delete, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.history_track_delete_not_signed_in),
                backgroundColor: UIConstants.frameNoParty,
              ),
            );
          }
          return;
        }

        final sessionDoc = await FirebaseFirestore.instance
            .collection('music_history')
            .doc(sessionId)
            .get();

        if (!sessionDoc.exists) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.history_track_delete_session_missing),
                backgroundColor: UIConstants.frameNoParty,
              ),
            );
          }
          return;
        }

        final sessionData = sessionDoc.data() as Map<String, dynamic>?;
        // Feld-Konsistenz: party_id (mit Unterstrich) aus dem Session-Dokument lesen
        final sessionPartyId = sessionData?['party_id'] as String? ?? sessionData?['partyId'] as String?;

        final activeParty = await ActivePartyService.getActivePartyInfo(user.uid);
        final expectedPartyId = activeParty?.partyId;

        if (expectedPartyId == null || expectedPartyId.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.history_track_delete_no_active_party),
                backgroundColor: UIConstants.frameNoParty,
              ),
            );
          }
          return;
        }
        if (sessionPartyId != expectedPartyId) {
          debugLog('🚫 PARTY-FILTER: Session $sessionId gehört zu Party "$sessionPartyId", erwartet "$expectedPartyId" - Löschen verweigert');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.history_track_delete_session_wrong_party),
                backgroundColor: UIConstants.frameNoParty,
              ),
            );
          }
          return;
        }

        await FirebaseFirestore.instance
            .collection('music_history')
            .doc(sessionId)
            .collection('tracks')
            .doc(trackId)
            .delete();

        // Stream auf music_history/{sessionId}/tracks erhält DocumentChangeType.removed und aktualisiert die Liste
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.history_song_deleted),
              backgroundColor: UIConstants.frameGespielt,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                  content: Text('${l.error_deleting} $e'),
              backgroundColor: UIConstants.frameNoParty,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Titelleiste mit CustomPageHeader (erstes Kind)
            CustomPageHeader(
              icon: Icons.history,
              title: l.music_history_title,
              trailing: IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: l.history_archived_playlists,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ArchivedPlaylistsPage(),
                    ),
                  );
                },
              ),
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
                  builder: (context, activePartyInfo, _) {
                    final partyId = activePartyInfo?.partyId;

                    if (activePartyInfo == null || partyId == null || partyId.isEmpty) {
                      if (_currentPartyId != null || _currentSessionId != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _tracksSubscription?.cancel();
                            _tracksSubscription = null;
                            _accumulatedTracks.clear();
                            if (!_tracksController.isClosed) {
                              _tracksController.add([]);
                            }
                            setState(() {
                              _currentPartyId = null;
                              _currentSessionId = null;
                              _currentPage = 1;
                              _isInitialLoading = true;
                            });
                          }
                        });
                      }
                      return const NoActivePartyDisplay();
                    }

                    // Stream auf music_history/{sessionId}/tracks; Session aus ActivePartyService
                    final sessionId = activePartyInfo.sessionId;
                    if (partyId != _currentPartyId || sessionId != _currentSessionId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _initializeTracksStream(partyId, sessionId);
                      });
                    }

                    // Live-Stream für Tracks mit distinct() für Performance-Optimierung
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _tracksController.stream,
                      initialData: const <Map<String, dynamic>>[],
                      builder: (context, snapshot) {
                        final allTracks = snapshot.data ?? [];

                        // FALL C (Leer): Keine Daten vorhanden
                        if (allTracks.isEmpty) {
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
                                EmptyListMessage(
                                  emptyMessageWhenPartyActive: l.history_no_music_recognition_history,
                                ),
                                const SizedBox(height: UIConstants.kFooterPadding * 2),
                              ],
                            ),
                          );
                        }

                        // FALL D (Daten): Zeige Liste mit Paginierung (lokal gefiltert)
                        // Berechne Paginierung basierend auf Stream-Daten (Ergebnisse pro Seite aus Einstellungen)
                        final totalPages = HistoryPaginationService.calculateTotalPages(allTracks.length, itemsPerPage: _resultsPerPage);

                        // Stelle sicher, dass die aktuelle Seite gültig ist
                        if (_currentPage > totalPages && totalPages > 0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _currentPage = totalPages;
                              });
                            }
                          });
                        }

                        // Hole Tracks für die aktuelle Seite (INSTANT - nur lokale Filterung!)
                        final paginatedTrackData = HistoryPaginationService.getItemsForPage(
                          allTracks,
                          _currentPage > 0 ? _currentPage : 1,
                          itemsPerPage: _resultsPerPage,
                        );

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
                              RepaintBoundary(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                    top: 8.0,
                                    bottom: 8.0,
                                  ),
                                  itemCount: () {
                                    final len = paginatedTrackData.length;
                                    final isFree = UserService().sessionProStatus.value?.isActive != true;
                                    return isFree ? len + (len / 5).floor() : len;
                                  }(),
                                  itemBuilder: (context, index) {
                                    final isFree = UserService().sessionProStatus.value?.isActive != true;
                                    if (isFree && index % 6 == 5) {
                                      return const ProPromotionBanner();
                                    }
                                    final dataIndex = index - (index ~/ 6);
                                    final data = paginatedTrackData[dataIndex];
                                    final track = data['track'] as TrackEntry;
                                    final sessionId = data['sessionId'] as String;
                                    final trackId = data['trackId'] as String;
                                    return SongTile(
                                      key: ValueKey('$sessionId-$trackId'),
                                      track: track,
                                      sessionId: sessionId,
                                      trackId: trackId,
                                      showDeleteButton: true,
                                      onDelete: () => _showDeleteDialog(
                                        context,
                                        track,
                                        sessionId,
                                        trackId,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Paginierungs-Buttons (nur wenn mehr als 1 Seite) - INSTANT, keine Query!
                              if (totalPages > 1) _buildPaginationButtons(_currentPage, totalPages, context),
                              const SizedBox(height: UIConstants.kFooterPadding * 2),
                            ],
                          ),
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
