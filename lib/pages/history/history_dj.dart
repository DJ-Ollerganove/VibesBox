import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_scaffold_messenger.dart';
import '../../l10n/app_localizations.dart';
import '../../models/playlist_model.dart';
import '../../services/active_party_service.dart';
import '../../services/app_diagnostic_log_service.dart';
import '../../services/history_provider.dart';
import '../../utils/ui_constants.dart';
import '../../widgets/custom_page_header.dart';
import '../../widgets/dj_wish_party_scope.dart';
import '../../widgets/empty_list_message.dart';
import '../../widgets/history_save_log_dialog.dart';
import 'widgets/song_tile.dart';

/// DJ-History: erkannte Songs der aktiven Party anzeigen und löschen.
/// Party-Erkennung **1:1 wie Offen** via [DjWishPartyScope].
class HistoryDjPage extends StatefulWidget {
  const HistoryDjPage({super.key});

  @override
  State<HistoryDjPage> createState() => _HistoryDjPageState();
}

class _HistoryDjPageState extends State<HistoryDjPage> {
  String? _sessionId;
  String? _boundPartyId;
  bool _resolving = false;

  String? _streamSessionId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _tracksStream;

  @override
  void initState() {
    super.initState();
    HistoryProvider.tracksRevision.addListener(_onTracksRevision);
    ActivePartyService.storedSessionNotifier.addListener(_onStoredSession);
  }

  @override
  void dispose() {
    HistoryProvider.tracksRevision.removeListener(_onTracksRevision);
    ActivePartyService.storedSessionNotifier.removeListener(_onStoredSession);
    super.dispose();
  }

  void _onTracksRevision() {
    final partyId = _boundPartyId;
    if (partyId == null || partyId.isEmpty) return;
    unawaited(_resolveSessionForParty(partyId, force: true));
  }

  void _onStoredSession() {
    final partyId = _boundPartyId;
    if (partyId == null || partyId.isEmpty) return;
    final stored = ActivePartyService.getStoredSession();
    if (stored != null &&
        stored.partyId == partyId &&
        stored.sessionId != null &&
        stored.sessionId!.isNotEmpty &&
        stored.sessionId != _sessionId) {
      unawaited(_resolveSessionForParty(partyId, force: true));
    }
  }

  void _onPartyIdChanged(String? partyId) {
    // Nie synchron setState aus dem DjWishPartyScope-build — sonst bleibt History leer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (partyId == null || partyId.isEmpty) {
        setState(() {
          _boundPartyId = null;
          _sessionId = null;
          _streamSessionId = null;
          _tracksStream = null;
          _resolving = false;
        });
        return;
      }
      final sameParty = _boundPartyId == partyId;
      _boundPartyId = partyId;
      // Immer neu auflösen (auch bei gleicher Party): lokale Session kann leer
      // sein, während Tracks in einer anderen music_history-Session liegen.
      unawaited(_resolveSessionForParty(partyId, force: sameParty));
    });
  }

  Future<void> _resolveSessionForParty(
    String partyId, {
    bool force = false,
  }) async {
    if (!mounted || _boundPartyId != partyId) return;
    if (_resolving && !force) return;
    setState(() => _resolving = true);
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final sessionId =
          await ActivePartyService.resolveMusicHistorySessionIdForParty(
        partyId,
        djId: authUid,
      );
      if (!mounted || _boundPartyId != partyId) return;

      // Fallback nur wenn Firestore nichts liefert — nie leere stored Session
      // über eine Session-mit-Tracks legen.
      final stored = ActivePartyService.getStoredSession();
      final storedSid = (stored != null &&
              stored.partyId == partyId &&
              stored.sessionId != null &&
              stored.sessionId!.isNotEmpty)
          ? stored.sessionId!
          : null;
      final sid = (sessionId != null && sessionId.isNotEmpty)
          ? sessionId
          : storedSid;

      setState(() {
        _sessionId = sid;
        _resolving = false;
        if (sid != null && sid.isNotEmpty) {
          _ensureTracksStream(sid);
        } else {
          _streamSessionId = null;
          _tracksStream = null;
        }
      });
    } catch (e) {
      debugPrint('HistoryDj: Session-Resolve fehlgeschlagen: $e');
      if (mounted) {
        setState(() => _resolving = false);
      } else {
        _resolving = false;
      }
    }
  }

  void _ensureTracksStream(String sessionId) {
    if (_streamSessionId == sessionId && _tracksStream != null) return;
    _streamSessionId = sessionId;
    _tracksStream = FirebaseFirestore.instance
        .collection('music_history')
        .doc(sessionId)
        .collection('tracks')
        .snapshots();
  }

  List<({TrackEntry track, String trackId})> _parseTracks(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rows = <({TrackEntry track, String trackId})>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString().trim();
      final artist = (data['artist'] ?? '').toString().trim();
      if (title.isEmpty && artist.isEmpty) continue;

      rows.add((
        track: TrackEntry.fromFirestore(data),
        trackId: doc.id,
      ));
    }
    rows.sort((a, b) => b.track.timestamp.compareTo(a.track.timestamp));
    return rows;
  }

  Future<void> _deleteTrack(
    BuildContext context,
    TrackEntry track,
    String trackId,
  ) async {
    final l = AppLocalizations.of(context)!;
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: UIConstants.frameHistory, width: 2),
        ),
        title: Text(l.history_delete_song_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(track.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(track.artist),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.frameNoParty,
            ),
            child: Text(l.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('music_history')
          .doc(sessionId)
          .collection('tracks')
          .doc(trackId)
          .delete();
      if (context.mounted) {
        showVibesSnackBar(
          context,
          SnackBar(
            content: Text(l.history_song_deleted),
            backgroundColor: UIConstants.frameGespielt,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showVibesSnackBar(
          context,
          SnackBar(
            content: Text('${l.error_deleting} $e'),
            backgroundColor: UIConstants.frameNoParty,
          ),
        );
      }
    }
  }

  Widget _buildTracksBody(AppLocalizations l, String partyId) {
    if (_resolving && (_sessionId == null || _sessionId!.isEmpty)) {
      return const Center(
        child: CircularProgressIndicator(color: UIConstants.appOrange),
      );
    }

    final sessionId = _sessionId;
    final stream = _tracksStream;
    if (sessionId == null || sessionId.isEmpty || stream == null) {
      return Center(
        child: EmptyListMessage(
          emptyMessageWhenPartyActive: l.history_no_music_recognition_history,
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: EmptyListMessage(
              emptyMessageWhenPartyActive: l.history_no_music_recognition_history,
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: UIConstants.appOrange),
          );
        }

        final rows = _parseTracks(snap.data!);
        if (rows.isEmpty) {
          return Center(
            child: EmptyListMessage(
              emptyMessageWhenPartyActive: l.history_no_music_recognition_history,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return SongTile(
              key: ValueKey('${sessionId}_${row.trackId}'),
              track: row.track,
              sessionId: sessionId,
              trackId: row.trackId,
              showDeleteButton: true,
              onDelete: () => _deleteTrack(context, row.track, row.trackId),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            CustomPageHeader(
              icon: Icons.history,
              title: l.music_history_title,
              trailing: AppDiagnosticLogService.canAccessDiagnosticUi()
                  ? IconButton(
                      tooltip: l.history_save_log_title,
                      icon: const Icon(
                        Icons.bug_report_outlined,
                        color: UIConstants.appOrange,
                      ),
                      onPressed: () => HistorySaveLogDialog.show(context),
                    )
                  : null,
            ),
            Expanded(
              child: DjWishPartyScope(
                emptyKey: 'history-none',
                onPartyIdChanged: _onPartyIdChanged,
                builder: (context, partyId, visibility) {
                  return _buildTracksBody(l, partyId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
