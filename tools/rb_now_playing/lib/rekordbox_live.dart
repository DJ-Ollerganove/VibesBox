import 'dj_library_source.dart';
import 'rekordbox_history.dart';

class LiveSnapshot {
  const LiveSnapshot({
    required this.history,
    required this.readAt,
    this.idle = false,
  });

  final HistorySnapshot history;
  final DateTime readAt;
  final bool idle;

  /// Letzter History-Eintrag, außer nach 10 Minuten ohne neuen Track.
  HistoryTrack? get nowPlaying => idle ? null : history.nowPlaying;

  String fingerprint() =>
      idle ? 'idle' : (history.nowPlaying?.identity ?? 'empty');

  LiveSnapshot asIdle() => LiveSnapshot(
        history: history,
        readAt: readAt,
        idle: true,
      );
}

class LiveReader {
  DjLibrarySource? source;

  LiveSnapshot read() {
    final src = source;
    if (src == null) {
      return LiveSnapshot(
        history: HistorySnapshot(
          dbPath: '',
          historyName: null,
          tracks: const [],
          readAt: DateTime.now(),
          debugNote: 'Keine DJ-Software in den Einstellungen gewählt',
        ),
        readAt: DateTime.now(),
        idle: true,
      );
    }
    return LiveSnapshot(
      history: src.readHistory(),
      readAt: DateTime.now(),
    );
  }
}
