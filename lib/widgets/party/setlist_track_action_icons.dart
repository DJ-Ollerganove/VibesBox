import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/ui_constants.dart';

/// Icons nach Antippen eines Setlist-Songs.
class SetlistTrackActionIcons extends StatelessWidget {
  const SetlistTrackActionIcons({
    super.key,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
    this.onMoveToOpen,
    this.onMarkPlayed,
    this.onDelete,
  });

  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onMoveToOpen;
  final VoidCallback? onMarkPlayed;
  final VoidCallback? onDelete;

  /// Dialog: Interpret + Titel bearbeiten. `null` = abgebrochen.
  static Future<({String title, String artist})?> editTrack(
    BuildContext context, {
    required String title,
    required String artist,
  }) async {
    final l = AppLocalizations.of(context)!;
    final titleCtrl = TextEditingController(text: title);
    final artistCtrl = TextEditingController(text: artist);
    final result = await showDialog<({String title, String artist})>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        title: Text(
          l.translate('dj_setlist_edit_track_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: artistCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l.wish_artist_label,
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: UIConstants.colorDjSetlist),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l.translate('wish_title_label'),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: UIConstants.colorDjSetlist),
                ),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: UIConstants.colorDjSetlist, width: 2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.cancel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              final t = titleCtrl.text.trim();
              final a = artistCtrl.text.trim();
              if (t.isEmpty || a.isEmpty) return;
              Navigator.pop(ctx, (title: t, artist: a));
            },
            child: Text(
              l.save,
              style: const TextStyle(
                color: UIConstants.colorDjSetlist,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    artistCtrl.dispose();
    return result;
  }

  static Future<bool> confirmDelete(
    BuildContext context, {
    required String title,
    required String artist,
    bool removeFromSaved = false,
  }) {
    final l = AppLocalizations.of(context)!;
    return confirmTrackAction(
      context,
      dialogTitle: l.translate('dj_setlist_delete_track_title'),
      body: l.tp(
        removeFromSaved
            ? 'dj_setlist_delete_track_body_saved'
            : 'dj_setlist_delete_track_body',
        {
          'title': title,
          'artist': artist,
        },
      ),
      confirmLabel: l.delete,
      accent: UIConstants.colorRed,
    );
  }

  static Future<bool> confirmMoveToOpen(
    BuildContext context, {
    required String title,
    required String artist,
  }) {
    final l = AppLocalizations.of(context)!;
    return confirmTrackAction(
      context,
      dialogTitle: l.translate('dj_setlist_move_to_open'),
      body: l.tp('dj_setlist_move_to_open_body', {
        'title': title,
        'artist': artist,
      }),
      confirmLabel: l.translate('dj_setlist_move_to_open'),
      accent: UIConstants.frameOffen,
    );
  }

  static Future<bool> confirmMarkPlayed(
    BuildContext context, {
    required String title,
    required String artist,
  }) {
    final l = AppLocalizations.of(context)!;
    return confirmTrackAction(
      context,
      dialogTitle: l.translate('dj_setlist_mark_played_title'),
      body: l.tp('dj_setlist_mark_played_body', {
        'title': title,
        'artist': artist,
      }),
      confirmLabel: l.played,
      accent: UIConstants.frameGespielt,
    );
  }

  static Future<bool> confirmTrackAction(
    BuildContext context, {
    required String dialogTitle,
    required String body,
    required String confirmLabel,
    required Color accent,
  }) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        title: Text(
          dialogTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          body,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: accent, width: 2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.cancel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onMoveUp != null)
          IconButton(
            onPressed: onMoveUp,
            tooltip: l.translate('dj_setlist_move_up'),
            icon: const Icon(
              Icons.arrow_upward,
              color: UIConstants.colorDjSetlist,
              size: 24,
            ),
          ),
        if (onMoveDown != null)
          IconButton(
            onPressed: onMoveDown,
            tooltip: l.translate('dj_setlist_move_down'),
            icon: const Icon(
              Icons.arrow_downward,
              color: UIConstants.colorDjSetlist,
              size: 24,
            ),
          ),
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            tooltip: l.edit,
            icon: const Icon(
              Icons.edit,
              color: UIConstants.colorDjSetlist,
              size: 24,
            ),
          ),
        if (onMoveToOpen != null)
          IconButton(
            onPressed: onMoveToOpen,
            tooltip: l.translate('dj_setlist_move_to_open'),
            icon: const Icon(
              Icons.queue_music,
              color: UIConstants.frameOffen,
              size: 24,
            ),
          ),
        if (onMarkPlayed != null)
          IconButton(
            onPressed: onMarkPlayed,
            tooltip: l.played,
            icon: const Icon(
              Icons.check_circle,
              color: UIConstants.frameGespielt,
              size: 24,
            ),
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            tooltip: l.delete,
            icon: const Icon(
              Icons.delete_forever,
              color: UIConstants.frameGesperrt,
              size: 24,
            ),
          ),
      ],
    );
  }
}
