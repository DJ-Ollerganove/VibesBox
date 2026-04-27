import 'package:cloud_firestore/cloud_firestore.dart';

/// Repräsentiert eine Musik-Session (Party-Aufzeichnung)
class MusicSession {
  final String id;
  final String djId;
  final String partyId;
  final String partyName;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;

  MusicSession({
    required this.id,
    required this.djId,
    required this.partyId,
    required this.partyName,
    required this.startTime,
    this.endTime,
    required this.isActive,
  });

  /// Erstellt eine MusicSession aus Firestore-Daten
  factory MusicSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MusicSession(
      id: doc.id,
      djId: data['djId'] as String,
      partyId: data['partyId'] as String? ?? '',
      partyName: data['partyName'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] as bool? ?? false,
    );
  }

  /// Konvertiert eine MusicSession zu Firestore-Daten
  Map<String, dynamic> toFirestore() {
    return {
      'djId': djId,
      'partyId': partyId,
      'partyName': partyName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isActive': isActive,
    };
  }

  /// Erstellt eine Kopie mit geänderten Werten
  MusicSession copyWith({
    String? id,
    String? djId,
    String? partyId,
    String? partyName,
    DateTime? startTime,
    DateTime? endTime,
    bool? isActive,
  }) {
    return MusicSession(
      id: id ?? this.id,
      djId: djId ?? this.djId,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Repräsentiert einen einzelnen Track-Eintrag in einer Session
class TrackEntry {
  final String title;
  final String artist;
  final DateTime timestamp;

  TrackEntry({
    required this.title,
    required this.artist,
    required this.timestamp,
  });

  /// Erstellt einen TrackEntry aus Firestore-Daten
  factory TrackEntry.fromFirestore(Map<String, dynamic> data) {
    return TrackEntry(
      title: data['title'] as String? ?? '',
      artist: data['artist'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  /// Konvertiert einen TrackEntry zu Firestore-Daten
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'artist': artist,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

