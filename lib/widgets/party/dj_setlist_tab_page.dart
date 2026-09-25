import 'package:flutter/material.dart';

import '../../app_scaffold_messenger.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event_setlist_track.dart';
import '../../services/dj_setlist_store_service.dart';
import '../../services/dj_setlist_track_actions_service.dart';
import '../../utils/ui_constants.dart';
import 'setlist_paginated_track_list.dart';
import 'setlist_track_action_icons.dart';

/// Reiter „Setlist“ in der laufenden Party.
class DjSetlistTabPage extends StatefulWidget {
  const DjSetlistTabPage({super.key, required this.partyId});

  final String partyId;

  @override
  State<DjSetlistTabPage> createState() => _DjSetlistTabPageState();
}

class _DjSetlistTabPageState extends State<DjSetlistTabPage> {
  bool _busy = false;

  List<EventSetlistTrack> _without(
    List<EventSetlistTrack> tracks,
    int index,
  ) {
    if (index < 0 || index >= tracks.length) return tracks;
    return [...tracks]..removeAt(index);
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String okMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(okMessage),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tp(
              'dj_setlist_action_failed',
              {'error': '$e'},
            ),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox.expand(
      child: StreamBuilder<List<EventSetlistTrack>>(
        stream: DjSetlistStoreService.instance.watch(widget.partyId),
        builder: (context, snapshot) {
          final tracks = snapshot.data ?? const <EventSetlistTrack>[];
          final visible = tracks.where((t) => !t.moved).toList();
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: UIConstants.colorDjSetlist,
              ),
            );
          }
          if (visible.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l?.translate('dj_setlist_empty_party') ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            );
          }
          return SetlistPaginatedTrackList(
            tracks: tracks,
            omitMovedTracks: true,
            padForAppFooter: true,
            onReasonsLocalized: (localized) =>
                DjSetlistTrackActionsService.instance.persistPartyTracks(
              partyId: widget.partyId,
              tracks: localized,
            ),
            onReorder: (next) async {
              if (_busy) return;
              setState(() => _busy = true);
              try {
                await DjSetlistTrackActionsService.instance.persistPartyTracks(
                  partyId: widget.partyId,
                  tracks: next,
                );
              } catch (e) {
                if (!mounted) return;
                showVibesSnackBar(
                  context,
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!.tp(
                        'dj_setlist_action_failed',
                        {'error': '$e'},
                      ),
                    ),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            onMoveToOpen: (index, track) async {
              final ok = await SetlistTrackActionIcons.confirmMoveToOpen(
                context,
                title: track.title,
                artist: track.artist,
              );
              if (!ok || !mounted) return;
              await _run(
                () async {
                  await DjSetlistTrackActionsService.instance.createDjWish(
                    partyId: widget.partyId,
                    track: track,
                    status: 'pending',
                    fromSetlist: true,
                  );
                  await DjSetlistTrackActionsService.instance
                      .persistPartyTracks(
                    partyId: widget.partyId,
                    tracks: DjSetlistTrackActionsService.instance
                        .markMoved(tracks, index),
                  );
                },
                okMessage: l?.translate('dj_setlist_moved_to_open') ?? '',
              );
            },
            onMarkPlayed: (index, track) async {
              final ok = await SetlistTrackActionIcons.confirmMarkPlayed(
                context,
                title: track.title,
                artist: track.artist,
              );
              if (!ok || !mounted) return;
              await _run(
                () async {
                  await DjSetlistTrackActionsService.instance.createDjWish(
                    partyId: widget.partyId,
                    track: track,
                    status: 'played',
                    fromSetlist: true,
                  );
                  await DjSetlistTrackActionsService.instance
                      .persistPartyTracks(
                    partyId: widget.partyId,
                    tracks: DjSetlistTrackActionsService.instance
                        .markMoved(tracks, index),
                  );
                },
                okMessage: l?.translate('dj_setlist_marked_played') ?? '',
              );
            },
            onDelete: (index, track) async {
              final ok = await SetlistTrackActionIcons.confirmDelete(
                context,
                title: track.title,
                artist: track.artist,
                removeFromSaved: true,
              );
              if (!ok || !mounted) return;
              await _run(
                () => DjSetlistTrackActionsService.instance.persistPartyTracks(
                  partyId: widget.partyId,
                  tracks: _without(tracks, index),
                ),
                okMessage: l?.translate('dj_setlist_track_deleted') ?? '',
              );
            },
            onEdit: (index, track) async {
              final edited = await SetlistTrackActionIcons.editTrack(
                context,
                title: track.title,
                artist: track.artist,
              );
              if (edited == null || !mounted) return;
              if (index < 0 || index >= tracks.length) return;
              final next = [...tracks];
              next[index] = track.copyWith(
                title: edited.title,
                artist: edited.artist,
              );
              await _run(
                () => DjSetlistTrackActionsService.instance.persistPartyTracks(
                  partyId: widget.partyId,
                  tracks: next,
                ),
                okMessage: l?.translate('dj_setlist_track_saved') ?? '',
              );
            },
          );
        },
      ),
    );
  }
}
