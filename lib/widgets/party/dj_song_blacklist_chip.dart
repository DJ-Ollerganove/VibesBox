import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dj_song_blacklist_entry.dart';
import '../../utils/ui_constants.dart';

class DjSongBlacklistChip extends StatelessWidget {
  const DjSongBlacklistChip({
    super.key,
    required this.entry,
    required this.onRemove,
  });

  final DjSongBlacklistEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 1, 0, 1),
      decoration: BoxDecoration(
        color: UIConstants.colorSongBlacklistChip,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: UIConstants.colorSongBlacklist, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              entry.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: UIConstants.colorSongBlacklist,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: AppLocalizations.of(context)!.translate('song_blacklist_remove'),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            icon: const Icon(
              Icons.close,
              size: 14,
              color: UIConstants.colorRed,
            ),
          ),
        ],
      ),
    );
  }
}
