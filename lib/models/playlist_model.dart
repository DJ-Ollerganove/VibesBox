import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/string_utils.dart';

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

  /// Erstellt eine MusicSession aus Firestore-Daten (Migration: party_id und partyId)
  factory MusicSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MusicSession(
      id: doc.id,
      djId: data['djId'] as String,
      partyId: data['party_id'] as String? ?? data['partyId'] as String? ?? '',
      partyName: unescapeHtml(data['partyName'] as String? ?? ''),
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
  final double? bpm;
  final String? camelot;
  final String? key;
  final int? durationSec;
  final String? source;

  TrackEntry({
    required this.title,
    required this.artist,
    required this.timestamp,
    this.bpm,
    this.camelot,
    this.key,
    this.durationSec,
    this.source,
  });

  static DateTime _timestampFromFirestore(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  static double? _bpmFrom(dynamic raw) {
    if (raw is num && raw > 0) return raw.toDouble();
    return null;
  }

  static int? _durationFrom(dynamic raw) {
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw > 0) return raw.round();
    return null;
  }

  /// Erstellt einen TrackEntry aus Firestore-Daten
  factory TrackEntry.fromFirestore(Map<String, dynamic> data) {
    return TrackEntry(
      title: unescapeHtml(data['title'] as String? ?? ''),
      artist: unescapeHtml(data['artist'] as String? ?? ''),
      timestamp: _timestampFromFirestore(data['timestamp']),
      bpm: _bpmFrom(data['bpm']),
      camelot: (data['camelot'] as String?)?.trim(),
      key: (data['key'] as String?)?.trim(),
      durationSec: _durationFrom(data['durationSec']),
      source: (data['source'] as String?)?.trim(),
    );
  }

  /// Konvertiert einen TrackEntry zu Firestore-Daten
  Map<String, dynamic> toFirestore({bool includeMixMeta = true}) {
    return {
      'title': title,
      'artist': artist,
      'timestamp': Timestamp.fromDate(timestamp),
      if (includeMixMeta && bpm != null && bpm! > 0) 'bpm': bpm,
      if (includeMixMeta && camelot != null && camelot!.isNotEmpty) 'camelot': camelot,
      if (includeMixMeta && key != null && key!.isNotEmpty) 'key': key,
      if (includeMixMeta && durationSec != null && durationSec! > 0)
        'durationSec': durationSec,
      if (includeMixMeta && source != null && source!.isNotEmpty) 'source': source,
    };
  }

  String get mixMetaLabel {
    final bits = <String>[];
    if (durationSec != null && durationSec! > 0) {
      final m = durationSec! ~/ 60;
      final s = durationSec! % 60;
      bits.add('$m:${s.toString().padLeft(2, '0')}');
    }
    if (bpm != null && bpm! > 0) {
      final rounded = bpm! == bpm!.roundToDouble()
          ? bpm!.round().toString()
          : bpm!.toStringAsFixed(1);
      bits.add('$rounded BPM');
    }
    final cam = (camelot ?? '').trim();
    if (cam.isNotEmpty) bits.add(cam);
    return bits.join(' · ');
  }
}

