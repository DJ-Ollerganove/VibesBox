import 'package:flutter/material.dart';

import '../../app_scaffold_messenger.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dj_song_blacklist_entry.dart';
import '../../services/party_song_blacklist_service.dart';
import '../../utils/ui_constants.dart';
import 'dj_song_blacklist_add_dialog.dart';
import 'dj_song_blacklist_chip.dart';

/// Blacklist-Icon auf der Party-Karte (bevorstehend / laufend).
class PartySongBlacklistButton extends StatelessWidget {
  const PartySongBlacklistButton({
    super.key,
    required this.partyId,
    this.dimColor,
  });

  final String partyId;
  final Color? dimColor;

  static Future<void> showSheet({
    required BuildContext context,
    required String partyId,
  }) async {
    if (partyId.isEmpty || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => _PartySongBlacklistSheet(partyId: partyId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (partyId.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final color = dimColor ?? UIConstants.colorSongBlacklist;
    return StreamBuilder<List<DjSongBlacklistEntry>>(
      stream: PartySongBlacklistService.instance.watch(partyId),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return IconButton(
          padding: EdgeInsets.zero,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip: l.translate('song_blacklist_party_icon_tooltip'),
          onPressed: dimColor != null
              ? null
              : () => showSheet(context: context, partyId: partyId),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            backgroundColor: UIConstants.colorSongBlacklistChip,
            textColor: UIConstants.colorSongBlacklistOnChip,
            child: Icon(Icons.playlist_remove, color: color, size: 18),
          ),
        );
      },
    );
  }
}

class _PartySongBlacklistSheet extends StatelessWidget {
  const _PartySongBlacklistSheet({required this.partyId});

  final String partyId;

  Future<void> _add(BuildContext context) async {
    final result = await DjSongBlacklistAddDialog.show(
      context: context,
      dialogTitleKey: 'song_blacklist_dialog_title_party',
    );
    if (result == null) return;
    try {
      await PartySongBlacklistService.instance.addEntry(
        partyId: partyId,
        title: result.$1,
        artist: result.$2,
      );
    } catch (e) {
      if (!context.mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.tp('song_blacklist_save_failed', {'error': '$e'})),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.playlist_remove,
                  color: UIConstants.colorSongBlacklist,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.translate('song_blacklist_temporary_section'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  tooltip: l.translate('song_blacklist_temporary_add_tooltip'),
                  onPressed: () => _add(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<DjSongBlacklistEntry>>(
              stream: PartySongBlacklistService.instance.watch(partyId),
              builder: (context, snapshot) {
                final items = DjSongBlacklistEntry.sortedCopy(
                  snapshot.data ?? const [],
                );
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      l.translate('song_blacklist_temporary_empty'),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in items)
                          DjSongBlacklistChip(
                            entry: item,
                            onRemove: () => PartySongBlacklistService.instance
                                .removeEntry(
                              partyId: partyId,
                              entryId: item.id,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
