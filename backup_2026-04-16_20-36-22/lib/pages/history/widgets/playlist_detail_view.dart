import 'package:flutter/material.dart';
import '../../../models/playlist_model.dart';
import 'song_tile.dart';

/// Detailansicht für eine Playlist (Session)
/// Wird als BottomSheet oder Dialog angezeigt
class PlaylistDetailView extends StatelessWidget {
  final MusicSession session;
  final Future<List<Map<String, dynamic>>> Function(String) loadTracks;
  final Future<bool> Function(String)? onDeleteTrack;

  const PlaylistDetailView({
    super.key,
    required this.session,
    required this.loadTracks,
    this.onDeleteTrack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.partyName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(session.startTime),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Tracks-Liste
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: loadTracks(session.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Fehler beim Laden: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final trackDataList = snapshot.data ?? [];

                  if (trackDataList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keine Songs in dieser Playlist',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: trackDataList.length,
                    itemBuilder: (context, index) {
                      final data = trackDataList[index];
                      final track = data['track'] as TrackEntry;
                      final trackId = data['trackId'] as String;
                      return SongTile(
                        track: track,
                        sessionId: session.id,
                        trackId: trackId,
                        showDeleteButton: onDeleteTrack != null,
                        onDelete: onDeleteTrack != null
                            ? () => _showDeleteDialog(
                                  context,
                                  track,
                                  trackId,
                                )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Heute';
    } else if (difference.inDays == 1) {
      return 'Gestern';
    } else if (difference.inDays < 7) {
      return 'vor ${difference.inDays} Tagen';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  /// Zeigt Bestätigungsdialog zum Löschen eines Tracks
  Future<void> _showDeleteDialog(
    BuildContext context,
    TrackEntry track,
    String trackId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Song löschen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Titel:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            Text(
              track.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Interpret:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            Text(
              track.artist,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Möchten Sie diesen Song wirklich aus der Playlist löschen?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Ja, löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted && onDeleteTrack != null) {
      final success = await onDeleteTrack!(trackId);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song wurde gelöscht'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Schließe und öffne BottomSheet neu, um Liste zu aktualisieren
        Navigator.of(context).pop();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PlaylistDetailView(
            session: session,
            loadTracks: loadTracks,
            onDeleteTrack: onDeleteTrack,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Löschen des Songs'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

