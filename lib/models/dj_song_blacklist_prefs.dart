import 'dj_song_blacklist_entry.dart';

/// Was beim Gast-Submit passiert, wenn Titel/Interpret auf der Blacklist steht.
enum SongBlacklistOutcome {
  none,
  rejectToDj,
  blockGuest,
}

/// DJ-Schalter auf `dj_song_blacklists/{djId}` (öffentlich lesbar, wie die Einträge).
class DjSongBlacklistPrefs {
  const DjSongBlacklistPrefs({
    required this.enabled,
    required this.guestBlock,
    this.entries = const [],
  });

  static const defaults = DjSongBlacklistPrefs(
    enabled: true,
    guestBlock: false,
  );

  /// Unsichtbarer Eintrag in `entries` — passt zu den live Rules (nur entries+updatedAt).
  static const prefsEntryId = '_vb_prefs';

  final bool enabled;
  /// true: Wunsch wird nicht geschrieben, Gast sieht eine höfliche Meldung.
  /// false: Wunsch landet in Abgelehnt (DJ sieht ihn).
  final bool guestBlock;
  final List<DjSongBlacklistEntry> entries;

  DjSongBlacklistPrefs copyWith({
    bool? enabled,
    bool? guestBlock,
    List<DjSongBlacklistEntry>? entries,
  }) {
    return DjSongBlacklistPrefs(
      enabled: enabled ?? this.enabled,
      guestBlock: guestBlock ?? this.guestBlock,
      entries: entries ?? this.entries,
    );
  }

  static Map<String, dynamic> prefsEntryJson({
    required bool enabled,
    required bool guestBlock,
  }) =>
      <String, dynamic>{
        'id': prefsEntryId,
        'enabled': enabled,
        'guest_block': guestBlock,
      };

  static List<Map<String, dynamic>> entriesPayload({
    required List<DjSongBlacklistEntry> songs,
    required bool enabled,
    required bool guestBlock,
  }) {
    final trimmed =
        songs.length > 199 ? songs.sublist(0, 199) : songs;
    return <Map<String, dynamic>>[
      prefsEntryJson(enabled: enabled, guestBlock: guestBlock),
      ...trimmed.map((e) => e.toJson()),
    ];
  }

  static DjSongBlacklistPrefs fromDoc(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    bool? enabledField;
    bool? guestBlockField;
    if (data.containsKey('enabled')) {
      enabledField = data['enabled'] == true;
    }
    if (data.containsKey('guest_block')) {
      guestBlockField = data['guest_block'] == true;
    }

    final raw = data['entries'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if ((map['id'] as String?)?.trim() != prefsEntryId) continue;
        if (enabledField == null && map.containsKey('enabled')) {
          enabledField = map['enabled'] == true;
        }
        if (guestBlockField == null && map.containsKey('guest_block')) {
          guestBlockField = map['guest_block'] == true;
        }
      }
    }

    final entries = DjSongBlacklistEntry.listFrom(raw);
    return DjSongBlacklistPrefs(
      enabled: enabledField ?? true,
      guestBlock: guestBlockField ?? false,
      entries: entries,
    );
  }

  SongBlacklistOutcome outcomeFor({
    required String title,
    required String artist,
    List<DjSongBlacklistEntry> extraEntries = const [],
  }) {
    if (!enabled) return SongBlacklistOutcome.none;
    final combined = <DjSongBlacklistEntry>[
      ...entries,
      ...extraEntries,
    ];
    if (!DjSongBlacklistEntry.matches(
      title: title,
      artist: artist,
      entries: combined,
    )) {
      return SongBlacklistOutcome.none;
    }
    if (guestBlock) return SongBlacklistOutcome.blockGuest;
    return SongBlacklistOutcome.rejectToDj;
  }
}
