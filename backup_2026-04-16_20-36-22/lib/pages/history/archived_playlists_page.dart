import 'package:flutter/material.dart';
import '../../models/playlist_model.dart';
import '../../services/history_provider.dart';
import 'widgets/playlist_detail_view.dart';

/// Seite für vergangene Playlists (Archiv)
class ArchivedPlaylistsPage extends StatefulWidget {
  const ArchivedPlaylistsPage({super.key});

  @override
  State<ArchivedPlaylistsPage> createState() => _ArchivedPlaylistsPageState();
}

class _ArchivedPlaylistsPageState extends State<ArchivedPlaylistsPage> {
  final historyProvider = HistoryProvider();

  /// Zeigt Bestätigungsdialog zum Löschen einer Playlist
  Future<void> _showDeleteDialog(
    BuildContext context,
    MusicSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playlist löschen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Playlist:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            Text(
              session.partyName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _formatSessionDate(session),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Möchten Sie diese Playlist wirklich komplett löschen? Alle Songs werden dabei entfernt.',
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

    if (confirmed == true && mounted) {
      final success = await historyProvider.deleteSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Playlist wurde gelöscht'
                  : 'Fehler beim Löschen der Playlist',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vergangene Playlists'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MusicSession>>(
          stream: historyProvider.getArchivedSessions(),
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

            final sessions = snapshot.data ?? [];

            if (sessions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Noch keine vergangenen Playlists',
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
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.playlist_play,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      session.partyName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(_formatSessionDate(session)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteDialog(context, session),
                          tooltip: 'Playlist löschen',
                        ),
                        Transform.flip(
                          flipX: isRtl,
                          child: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => PlaylistDetailView(
                          session: session,
                          loadTracks: historyProvider.getSessionTracks,
                          onDeleteTrack: (trackId) => historyProvider.deleteTrack(session.id, trackId),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatSessionDate(MusicSession session) {
    final startDate = session.startTime;
    final endDate = session.endTime;
    
    final startStr = '${startDate.day}.${startDate.month}.${startDate.year}';
    
    if (endDate != null) {
      final duration = endDate.difference(startDate);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '$startStr • ${hours}h ${minutes}min';
    }
    
    return startStr;
  }
}

