import 'package:cloud_firestore/cloud_firestore.dart';

/// Sortierspalten der Merkliste.
enum MerklisteSortColumn {
  nr,
  song,
}

class SavedTrack {
  const SavedTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.bookmarkedAt,
    this.partyId,
    this.sourceWishId,
  });

  final String id;
  final String title;
  final String artist;
  final DateTime bookmarkedAt;
  final String? partyId;
  final String? sourceWishId;

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _string(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int && value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num && value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  factory SavedTrack.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SavedTrack.fromMap(doc.id, doc.data() ?? const {});
  }

  factory SavedTrack.fromMap(String id, Map<String, dynamic> data) {
    final bookmarkedAt =
        _dateTime(data['bookmarked_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return SavedTrack(
      id: id,
      title: _string(data['title']),
      artist: _string(data['artist']),
      bookmarkedAt: bookmarkedAt,
      partyId: _optionalString(data['party_id']),
      sourceWishId: _optionalString(data['source_wish_id']),
    );
  }
}
