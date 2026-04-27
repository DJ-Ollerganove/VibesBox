import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../l10n/app_localizations.dart';
import '../../services/party_session_service.dart';
import '../../utils/ui_constants.dart';
import '../../models/playlist_model.dart';
import '../../services/history_pagination_service.dart';
import '../../services/results_per_page_service.dart';
import '../../utils/footer_helper.dart';
import '../../widgets/scroll_indicator_overlay.dart';
import 'widgets/song_tile.dart';

/// Guest-Ansicht für die Musik-History.
/// Gäste können keine Party starten – daher keine Start-Party-Hinweise.
class HistoryGuestPage extends StatefulWidget {
  const HistoryGuestPage({super.key});

  @override
  State<HistoryGuestPage> createState() => _HistoryGuestPageState();
}

class _HistoryGuestPageState extends State<HistoryGuestPage> {
  int _currentPage = 1;
  int _resultsPerPage = ResultsPerPageService.defaultResultsPerPage;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _trackSubscriptions = [];
  final StreamController<List<TrackEntry>> _tracksController = StreamController<List<TrackEntry>>.broadcast();
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _currentSessionDocs;
  String? _currentDjId;
  String? _currentPartyId;

  /// Nach erstem [PartySessionService]-Load: Header-Subtitle und Body nutzen dieselbe Quelle.
  bool _guestSessionResolved = false;
  String? _guestPartyId;
  String? _guestDjId;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveGuestSession());
    ResultsPerPageService.load().then((v) {
      if (mounted) setState(() => _resultsPerPage = v);
    });
  }

  Future<void> _resolveGuestSession() async {
    final s = await _loadSession();
    if (!mounted) return;
    setState(() {
      _guestSessionResolved = true;
      _guestPartyId = s.partyId;
      _guestDjId = s.djId;
    });
  }

  /// Gleiche Semantik wie bisher: Party + DJ aus Session (Check-in).
  bool _guestInPartySession() {
    final p = _guestPartyId?.trim() ?? '';
    final d = _guestDjId?.trim() ?? '';
    return p.isNotEmpty && p != 'manual' && d.isNotEmpty;
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

  /// Baut die Paginierungs-Navigation auf
  Widget _buildPaginationButtons(int currentPage, int totalPages, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
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
              backgroundColor: Colors.grey[900],
              foregroundColor: UIConstants.appBarForegroundColor,
              disabledBackgroundColor: Colors.grey[800],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          // Seitenanzeige
          Text(
            '${l.history_page} $currentPage / $totalPages',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
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
              backgroundColor: Colors.grey[900],
              foregroundColor: UIConstants.appBarForegroundColor,
              disabledBackgroundColor: Colors.grey[800],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<({String? partyId, String? djId})> _loadSession() async {
    await PartySessionService.instance.loadFromPrefs();
    final svc = PartySessionService.instance;
    if (!svc.hasSession) return (partyId: null, djId: null);
    return (partyId: svc.partyId, djId: svc.djId);
  }

  /// Normalisiert Party-ID für vergleich (Trim, String – vermeidet Typ-/Leerzeichen-Fehler).
  static String? _normPartyId(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Lädt Tracks aus allen Sessions dieser Party einmalig (Fallback, wenn kein Live-Stream).
  Future<void> _loadTracksFallback(String djId, String partyId) async {
    try {
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: djId)
          .get(const GetOptions(source: Source.serverAndCache));
      final partyIdNorm = _normPartyId(partyId);
      final allTracks = <TrackEntry>[];
      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final sessionPartyId = _normPartyId(data['party_id']) ?? _normPartyId(data['partyId']);
        if (sessionPartyId != partyIdNorm) continue;
        final tracksSnapshot = await FirebaseFirestore.instance
            .collection('music_history')
            .doc(doc.id)
            .collection('tracks')
            .get(const GetOptions(source: Source.serverAndCache));
        for (final t in tracksSnapshot.docs) {
          try {
            allTracks.add(TrackEntry.fromFirestore(t.data()));
          } catch (_) {}
        }
      }
      allTracks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted && !_tracksController.isClosed) {
        _tracksController.add(allTracks);
      }
    } catch (_) {
      if (mounted && !_tracksController.isClosed) _tracksController.add([]);
    }
  }

  /// Setzt einen einzelnen Stream auf music_history/{sessionId}/tracks (wie in der App).
  /// sessionId = Session für diese Party (bevorzugt aktive, sonst erste passende).
  void _setupTracksStreamForSession(String? sessionId) {
    for (final sub in _trackSubscriptions) {
      sub.cancel();
    }
    _trackSubscriptions.clear();

    if (sessionId == null || sessionId.isEmpty) {
      if (!_tracksController.isClosed) _tracksController.add([]);
      return;
    }

    final trackSubscription = FirebaseFirestore.instance
        .collection('music_history')
        .doc(sessionId)
        .collection('tracks')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final allTracks = <TrackEntry>[];
      for (final doc in snapshot.docs) {
        try {
          allTracks.add(TrackEntry.fromFirestore(doc.data()));
        } catch (_) {}
      }
      allTracks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!_tracksController.isClosed) {
        _tracksController.add(allTracks);
      }
    }, onError: (e) {
      if (!_tracksController.isClosed) _tracksController.add([]);
    });
    _trackSubscriptions.add(trackSubscription);
  }

  @override
  void dispose() {
    for (final sub in _trackSubscriptions) {
      sub.cancel();
    }
    _trackSubscriptions.clear();
    _tracksController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    return Scaffold(
      body: SafeArea(
        child: isRtl
            ? Directionality(
                textDirection: TextDirection.rtl,
                child: _buildContent(context, l, isRtl),
              )
            : _buildContent(context, l, isRtl),
      ),
    );
  }

  /// Zentriertes Widget für "Keine Party"-Zustand (Kein Stream, keine Firestore-Abfragen).
  /// FALL A: Text bleibt [history_no_party_info].
  Widget _buildNoPartyWidget(BuildContext context, AppLocalizations l, bool isRtl) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history,
                size: 64,
                color: UIConstants.colorOrange,
              ),
              const SizedBox(height: 16),
              Text(
                l.history_no_party_info,
                textAlign: TextAlign.center,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: UIConstants.colorGrey,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// FALL B: In Party, aber noch keine Tracks — [history_empty_party_active_hint].
  /// Scrollbar bei langen Übersetzungen; History + Uhr nebeneinander, darunter Fließtext.
  Widget _buildHistoryEmptyState(BuildContext context, AppLocalizations l, bool isRtl) {
    final iconColor = UIConstants.colorOrange;
    final muted = UIConstants.colorGrey.withValues(alpha: 0.65);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Icon(Icons.history, size: 56, color: iconColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.access_time,
                      size: 52,
                      color: muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                l.history_empty_party_active_hint,
                textAlign: TextAlign.center,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: UIConstants.appBarForegroundColor,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l, bool isRtl) {
    return Column(
      children: [
        // Titelleiste: Design konsistent zu Kontakt / Social Media / Über (schwarz, weiß)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: UIConstants.appBarBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Icon(
                Icons.history,
                size: 32,
                color: UIConstants.appBarIconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: isRtl
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.history,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: UIConstants.appBarForegroundColor,
                          ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<List<TrackEntry>>(
                      stream: _tracksController.stream,
                      initialData: const <TrackEntry>[],
                      builder: (context, tracksSnapshot) {
                        if (!_guestSessionResolved) {
                          return const SizedBox(height: 18);
                        }
                        final hasEntries =
                            (tracksSnapshot.data?.isNotEmpty ?? false);
                        final inParty = _guestInPartySession();
                        final String subtitle;
                        if (!inParty) {
                          subtitle = l.history_no_party_info;
                        } else if (hasEntries) {
                          subtitle = l.history_subtitle_active;
                        } else {
                          subtitle = l.history_empty_party_active_hint;
                        }
                        return Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14.5,
                            height: 1.35,
                          ),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left,
                          textDirection:
                              isRtl ? TextDirection.rtl : TextDirection.ltr,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ScrollIndicatorOverlay(
            child: Builder(
            builder: (context) {
              if (!_guestSessionResolved) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2,
                  ),
                );
              }

              final partyId = _guestPartyId;
              final djId = _guestDjId;

              if (partyId == null || partyId.isEmpty || djId == null || djId.isEmpty) {
                return _buildNoPartyWidget(context, l, isRtl);
              }

              final partyIdNorm = _normPartyId(partyId) ?? partyId;
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('music_history')
                        .where('djId', isEqualTo: djId)
                        .snapshots(),
                    builder: (context, sessionsSnapshot) {
                      // Kein dauerhafter Lade-Indicator: bei Wartezeit sofort Hinweis anzeigen
                      final connectionState = sessionsSnapshot.connectionState;
                      if (!sessionsSnapshot.hasData) {
                        return Center(
                          child: connectionState == ConnectionState.waiting
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const SizedBox.shrink(),
                        );
                      }

                      // Clientseitig nach party_id / partyId filtern (normalisiert, Typ-sicher)
                      final allDocs = sessionsSnapshot.data!.docs;
                      final matchingDocs = allDocs.where((doc) {
                        final data = doc.data();
                        final sessionPartyId = _normPartyId(data['party_id']) ?? _normPartyId(data['partyId']);
                        return sessionPartyId != null && sessionPartyId == partyIdNorm;
                      }).toList();

                      // Bevorzugt aktive Session (isActive == true), sonst erste passende
                      final activeFirst = matchingDocs.where((doc) {
                        final v = doc.data()['isActive'];
                        return v == true || v == 'true';
                      }).toList();
                      final chosen = activeFirst.isNotEmpty ? activeFirst.first : (matchingDocs.isNotEmpty ? matchingDocs.first : null);
                      final sessionId = chosen?.id;

                      _currentSessionDocs = matchingDocs;
                      _currentDjId = djId;
                      _currentPartyId = partyId;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (sessionId != null && sessionId.isNotEmpty) {
                          _setupTracksStreamForSession(sessionId);
                        } else {
                          _setupTracksStreamForSession(null);
                          // Fallback: letzte Tracks der Party einmalig laden
                          _loadTracksFallback(djId, partyId);
                        }
                      });

                      // Immer Tracks-Stream anzeigen (initialData: [], kein Hänger)
                      return StreamBuilder<List<TrackEntry>>(
                        stream: _tracksController.stream,
                        initialData: const <TrackEntry>[],
                        builder: (context, tracksSnapshot) {
                          final allTracks = tracksSnapshot.data ?? const [];

                          // FALL: Keine Songs -> Empty State (Layout wie Screenshot)
                          if (allTracks.isEmpty) {
                            return _buildHistoryEmptyState(context, l, isRtl);
                          }

                          // FALL: Songs vorhanden -> Liste mit Paginierung anzeigen (Ergebnisse pro Seite aus Einstellungen)
                          final totalPages = HistoryPaginationService.calculateTotalPages(allTracks.length, itemsPerPage: _resultsPerPage);
                          
                          // Stelle sicher, dass die aktuelle Seite gültig ist
                          if (_currentPage > totalPages && totalPages > 0) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _currentPage = totalPages;
                              });
                            });
                          }
                          
                          // Hole Tracks für die aktuelle Seite
                          final paginatedTracks = HistoryPaginationService.getItemsForPage(
                            allTracks,
                            _currentPage > 0 ? _currentPage : 1,
                            itemsPerPage: _resultsPerPage,
                          );
                          
                          return Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  padding: FooterHelper.getFooterPadding(context),
                                  itemCount: paginatedTracks.length,
                                  itemBuilder: (context, index) {
                                    final track = paginatedTracks[index];
                                    return SongTile(
                                      track: track,
                                      showDeleteButton: false,
                                    );
                                  },
                                ),
                              ),
                              // Paginierungs-Buttons
                              _buildPaginationButtons(_currentPage, totalPages, context),
                              // Leerblock am Ende, damit der letzte Eintrag vollständig oberhalb der Pegellinie scrollbar ist
                              const SizedBox(height: 200),
                            ],
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
    );
  }
}


