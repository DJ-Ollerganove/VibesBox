import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event_setlist_track.dart';
import '../../services/dj_setlist_store_service.dart';
import '../../services/dj_setlist_track_actions_service.dart';
import '../../utils/ui_constants.dart';
import 'setlist_paginated_track_list.dart';
import 'setlist_track_action_icons.dart';

/// Gelbes „SL: N“ neben VW — nur wenn eine Setliste verknüpft ist.
class PartyDjSetlistBadge extends StatelessWidget {
  const PartyDjSetlistBadge({
    super.key,
    required this.partyId,
    this.partyName = '',
    this.fontSize = 13,
    this.compact = false,
    this.dimColor,
  });

  final String partyId;
  final String partyName;
  final double fontSize;
  final bool compact;
  final Color? dimColor;

  @override
  Widget build(BuildContext context) {
    if (partyId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<int>(
      stream: DjSetlistStoreService.instance.watchTrackCount(partyId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count <= 0) {
          return const SizedBox.shrink();
        }
        final labelColor = dimColor ?? UIConstants.colorDjSetlist;
        final canTap = dimColor == null;
        final loc = AppLocalizations.of(context)!;
        final label = Text(
          loc.tp('dj_setlist_sl_badge', {'count': '$count'}),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: labelColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        );
        if (compact) {
          return GestureDetector(
            onTap: canTap ? () => _openList(context) : null,
            behavior: HitTestBehavior.opaque,
            child: label,
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canTap ? () => _openList(context) : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label,
                    if (canTap) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: labelColor),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openList(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final title = partyName.trim().isEmpty
        ? loc.translate('dj_setlist_badge_fallback')
        : partyName.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.72;
        return Dialog(
          backgroundColor: UIConstants.djShellPageBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: UIConstants.colorDjSetlist, width: 2),
          ),
          child: SizedBox(
            height: height,
            width: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: UIConstants.colorDjSetlist,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _BadgeSetlistBody(partyId: partyId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BadgeSetlistBody extends StatelessWidget {
  const _BadgeSetlistBody({required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventSetlistTrack>>(
      stream: DjSetlistStoreService.instance.watch(partyId),
      builder: (context, snapshot) {
        final tracks = snapshot.data ?? const <EventSetlistTrack>[];
        if (tracks.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.translate('dj_setlist_empty_songs'),
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        return SetlistPaginatedTrackList(
          tracks: tracks,
          onReasonsLocalized: (localized) =>
              DjSetlistTrackActionsService.instance.persistPartyTracks(
            partyId: partyId,
            tracks: localized,
          ),
          onDelete: (index, track) async {
            final ok = await SetlistTrackActionIcons.confirmDelete(
              context,
              title: track.title,
              artist: track.artist,
              removeFromSaved: true,
            );
            if (!ok) return;
            final next = [...tracks]..removeAt(index);
            await DjSetlistTrackActionsService.instance.persistPartyTracks(
              partyId: partyId,
              tracks: next,
            );
          },
        );
      },
    );
  }
}
