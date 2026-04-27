import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../../models/playlist_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/relative_time_minutes.dart';

/// Widget für die Anzeige eines einzelnen Songs in der History
class SongTile extends StatelessWidget {
  final TrackEntry track;
  final String? sessionId;
  final String? trackId;
  final bool showDeleteButton;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SongTile({
    super.key,
    required this.track,
    this.sessionId,
    this.trackId,
    this.showDeleteButton = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              // Song-Info (Icon entfernt)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: isRtl ? TextAlign.right : null,
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                      textAlign: isRtl ? TextAlign.right : null,
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Zeitstempel
              Text(
                _formatTime(track.timestamp, context),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
                textDirection: TextDirection.ltr,
              ),
              // Lösch-Icon (nur wenn Party aktiv)
              if (showDeleteButton && onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.red,
                  onPressed: onDelete,
                  tooltip: l.delete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    final elapsed = RelativeTimeMinutes.elapsedCalendarMinutes(timestamp, now);

    if (elapsed < 0) {
      return l.history_time_just_now;
    }
    if (elapsed == 0) {
      return l.history_time_just_now;
    }
    if (elapsed < 60) {
      return (l.history_time_minutes_ago(elapsed));
    }
    if (difference.inDays < 1) {
      final hours = elapsed ~/ 60;
      return (l.history_time_hours_ago(hours));
    }
    final tag = Localizations.localeOf(context).toString();
    return intl.DateFormat.jm(tag).format(timestamp);
  }
}

