import 'event_setlist_track.dart';

/// Eine gespeicherte DJ-Setliste (Bibliothek, nicht Offen/Vorab).
class DjSetlistLibraryItem {
  const DjSetlistLibraryItem({
    required this.id,
    required this.title,
    required this.tracks,
    this.partyIds = const <String>[],
    this.partyNames = const <String, String>{},
  });

  final String id;
  final String title;
  final List<EventSetlistTrack> tracks;
  /// Eine Liste kann mehreren Partys zugeordnet sein; jede Party nur eine Liste.
  final List<String> partyIds;
  final Map<String, String> partyNames;

  /// Erste Party (Legacy-/Kurzanzeige).
  String? get partyId => partyIds.isEmpty ? null : partyIds.first;

  String? get partyName {
    final id = partyId;
    if (id == null) return null;
    final n = partyNames[id]?.trim();
    if (n != null && n.isNotEmpty) return n;
    return null;
  }

  bool get isAssignedToParty => partyIds.isNotEmpty;

  bool get isPartyStoreOnly => id.startsWith('party_');

  String partiesLabel({String separator = ', '}) {
    if (partyIds.isEmpty) return '';
    return partyIds
        .map((id) {
          final n = partyNames[id]?.trim();
          return (n != null && n.isNotEmpty) ? n : id;
        })
        .join(separator);
  }

  DjSetlistLibraryItem copyWith({
    List<EventSetlistTrack>? tracks,
    List<String>? partyIds,
    Map<String, String>? partyNames,
    String? title,
  }) {
    return DjSetlistLibraryItem(
      id: id,
      title: title ?? this.title,
      tracks: tracks ?? this.tracks,
      partyIds: partyIds ?? this.partyIds,
      partyNames: partyNames ?? this.partyNames,
    );
  }

  factory DjSetlistLibraryItem.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final title = (data['title'] as String?)?.trim() ?? '';
    final partyIds = <String>[];
    final partyNames = <String, String>{};

    final rawIds = data['partyIds'];
    if (rawIds is List) {
      for (final e in rawIds) {
        final s = e?.toString().trim() ?? '';
        if (s.isEmpty || partyIds.contains(s)) continue;
        partyIds.add(s);
        if (partyIds.length >= 50) break;
      }
    }
    final legacyId = (data['partyId'] as String?)?.trim();
    if (legacyId != null &&
        legacyId.isNotEmpty &&
        !partyIds.contains(legacyId)) {
      partyIds.insert(0, legacyId);
    }

    final rawNames = data['partyNames'];
    if (rawNames is Map) {
      rawNames.forEach((key, value) {
        final k = key.toString().trim();
        final v = value?.toString().trim() ?? '';
        if (k.isEmpty || v.isEmpty) return;
        partyNames[k] = v;
      });
    }
    final legacyName = (data['partyName'] as String?)?.trim();
    if (legacyId != null &&
        legacyId.isNotEmpty &&
        legacyName != null &&
        legacyName.isNotEmpty &&
        !partyNames.containsKey(legacyId)) {
      partyNames[legacyId] = legacyName;
    }

    return DjSetlistLibraryItem(
      id: id,
      title: title.isEmpty ? 'Setliste' : title,
      tracks: EventSetlistTrack.listFrom(data['tracks']),
      partyIds: partyIds,
      partyNames: partyNames,
    );
  }

  /// Virtueller Eintrag nur aus Party-Store (keine Library-Doc-ID).
  factory DjSetlistLibraryItem.partyStoreOnly({
    required String partyId,
    required String title,
    required List<EventSetlistTrack> tracks,
    String? partyName,
  }) {
    final name = partyName?.trim();
    return DjSetlistLibraryItem(
      id: 'party_$partyId',
      title: title,
      tracks: tracks,
      partyIds: <String>[partyId],
      partyNames: (name != null && name.isNotEmpty)
          ? <String, String>{partyId: name}
          : const <String, String>{},
    );
  }
}
