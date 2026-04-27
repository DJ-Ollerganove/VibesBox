import 'dart:math' show min;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:string_similarity/string_similarity.dart';

import '../utils/text_utils.dart';
import '../utils/debug_log.dart';

/// Treffer in der offenen Wunschliste (entspricht PWA `findSimilarWish`, Firestore-Zweig).
class SimilarPendingWishMatch {
  SimilarPendingWishMatch({required this.documentId, required this.data});
  final String documentId;
  final Map<String, dynamic> data;
}

/// Service für Dubletten-Checks
/// Prüft ob ein Song bereits in der History oder als gespielter Wunsch existiert
/// Nutzt duplicate_threshold und ignored_keywords aus party_settings/current
class DuplicateCheckService {
  static final DuplicateCheckService _instance = DuplicateCheckService._internal();
  factory DuplicateCheckService() => _instance;
  DuplicateCheckService._internal();

  static double? _cachedThreshold;
  static List<String>? _cachedIgnoredKeywords;

  /// Lädt party_settings/current und cached duplicate_threshold + ignored_keywords (einmal pro App-Lauf).
  static Future<void> ensurePartySettingsLoaded() async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .get();
      if (!settingsDoc.exists) {
        _cachedThreshold = 0.85;
        _cachedIgnoredKeywords = List<String>.from(kIgnoredKeywordsDefault);
        return;
      }
      final data = settingsDoc.data();
      final thresholdValue = data?['duplicate_threshold'];
      if (thresholdValue != null) {
        if (thresholdValue is double) {
          _cachedThreshold = thresholdValue;
        } else if (thresholdValue is num) {
          _cachedThreshold = thresholdValue.toDouble();
        } else {
          _cachedThreshold = 0.85;
        }
      } else {
        _cachedThreshold = 0.85;
      }
      final raw = data?['ignored_keywords'];
      if (raw != null && raw is List && raw.isNotEmpty) {
        _cachedIgnoredKeywords = raw
            .map((e) => e?.toString().trim())
            .where((e) => e != null && e.isNotEmpty)
            .cast<String>()
            .toList();
      } else {
        _cachedIgnoredKeywords = List<String>.from(kIgnoredKeywordsDefault);
      }
      debugLog('🔍 Duplikat-Check: Threshold ${((_cachedThreshold ?? 0.85) * 100).toStringAsFixed(1)}%, ignored_keywords: ${_cachedIgnoredKeywords?.length ?? 0}');
    } catch (e) {
      debugLog('⚠️ Fehler beim Laden der Party-Settings: $e');
      _cachedThreshold = 0.85;
      _cachedIgnoredKeywords = List<String>.from(kIgnoredKeywordsDefault);
    }
  }

  /// Gibt die gecachte Liste ignorierter Begriffe zurück (für Gruppierung/Vergleich). Nie null.
  static List<String> getCachedIgnoredKeywords() {
    return _cachedIgnoredKeywords != null
        ? List<String>.from(_cachedIgnoredKeywords!)
        : List<String>.from(kIgnoredKeywordsDefault);
  }

  static Future<double> _getDuplicateThreshold() async {
    if (_cachedThreshold == null) await ensurePartySettingsLoaded();
    return _cachedThreshold ?? 0.85;
  }

  /// Prüft ob ein Song bereits gespielt wurde
  /// Sucht in history (music_history) und wishes (Status: played) der aktuellen partyId
  /// Nutzt string_similarity mit Admin-Threshold
  /// Gibt true zurück, wenn der Song bereits lief
  static Future<bool> checkIfSongWasPlayed(String title, String artist, String partyId) async {
    try {
      if (partyId.isEmpty || partyId == 'manual') {
        return false; // Keine aktive Party
      }

      final threshold = await _getDuplicateThreshold();
      final ignoredKeywords = getCachedIgnoredKeywords();

      // Normalisiere für Vergleich (Klammern/Mix-Begriffe entfernen, Umlaute, Sonderzeichen)
      final normalizedTitle = normalizeTextForDuplicateCheck(title, ignoredKeywords);
      final normalizedArtist = normalizeTextForDuplicateCheck(artist, ignoredKeywords);

      if (normalizedTitle.isEmpty && normalizedArtist.isEmpty) {
        return false; // Keine Daten zum Vergleichen
      }

      // 1. Prüfe in music_history (History) – Filter: party_id
      try {
        var historySessions = await FirebaseFirestore.instance
            .collection('music_history')
            .where('party_id', isEqualTo: partyId)
            .get();
        if (historySessions.docs.isEmpty) {
          historySessions = await FirebaseFirestore.instance
              .collection('music_history')
              .where('partyId', isEqualTo: partyId)
              .get();
        }

        for (final sessionDoc in historySessions.docs) {
          final tracksSnapshot = await FirebaseFirestore.instance
              .collection('music_history')
              .doc(sessionDoc.id)
              .collection('tracks')
              .get();

          for (final trackDoc in tracksSnapshot.docs) {
            final trackData = trackDoc.data() as Map<String, dynamic>?;
            if (trackData == null) continue;

            final rawTrackTitle = trackData['title'] as String? ?? '';
            final rawTrackArtist = trackData['artist'] as String? ?? '';
            final trackTitle = normalizeTextForDuplicateCheck(rawTrackTitle, ignoredKeywords);
            final trackArtist = normalizeTextForDuplicateCheck(rawTrackArtist, ignoredKeywords);

            if (trackTitle.isEmpty && trackArtist.isEmpty) continue;

            double titleSimilarity = 0.0;
            double artistSimilarity = 0.0;
            if (normalizedTitle.isNotEmpty && trackTitle.isNotEmpty) {
              titleSimilarity = StringSimilarity.compareTwoStrings(normalizedTitle, trackTitle);
            }
            if (normalizedArtist.isNotEmpty && trackArtist.isNotEmpty) {
              artistSimilarity = StringSimilarity.compareTwoStrings(normalizedArtist, trackArtist);
            }
            final avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

            if (avgSimilarity >= threshold) {
              debugLog('✅ Song bereits in History gefunden (Ähnlichkeit: ${(avgSimilarity * 100).toStringAsFixed(1)}%)');
              return true;
            }
          }
        }
      } catch (e) {
        debugLog('⚠️ Fehler beim Prüfen der History: $e');
      }

      // 2. Prüfe in wishes (Status: played)
      try {
        final playedWishesSnapshot = await FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', isEqualTo: partyId)
            .where('status', isEqualTo: 'played')
            .get();

        for (final wishDoc in playedWishesSnapshot.docs) {
          final wishData = wishDoc.data() as Map<String, dynamic>;
          final rawWishTitle = (wishData['title'] ?? wishData['song'] ?? '') as String;
          final rawWishArtist = wishData['artist'] as String? ?? '';
          final wishTitle = normalizeTextForDuplicateCheck(rawWishTitle, ignoredKeywords);
          final wishArtist = normalizeTextForDuplicateCheck(rawWishArtist, ignoredKeywords);

          if (wishTitle.isEmpty && wishArtist.isEmpty) continue;

          double titleSimilarity = 0.0;
          double artistSimilarity = 0.0;
          if (normalizedTitle.isNotEmpty && wishTitle.isNotEmpty) {
            titleSimilarity = StringSimilarity.compareTwoStrings(normalizedTitle, wishTitle);
          }
          if (normalizedArtist.isNotEmpty && wishArtist.isNotEmpty) {
            artistSimilarity = StringSimilarity.compareTwoStrings(normalizedArtist, wishArtist);
          }
          final avgSimilarity = (titleSimilarity + artistSimilarity) / 2.0;

          if (avgSimilarity >= threshold) {
            debugLog('✅ Song bereits als gespielter Wunsch gefunden (Ähnlichkeit: ${(avgSimilarity * 100).toStringAsFixed(1)}%)');
            return true;
          }
        }
      } catch (e) {
        debugLog('⚠️ Fehler beim Prüfen der gespielten Wünsche: $e');
      }

      return false; // Song wurde nicht gefunden
    } catch (e) {
      debugLog('❌ Fehler beim Duplikat-Check: $e');
      return false; // Bei Fehler: Kein Duplikat (sicherer Fallback)
    }
  }

  /// Prüft, ob ein Song bereits in der offenen Wunschliste (status: pending) existiert.
  /// Nutzt dieselbe Logik wie die PWA (`findSimilarWish`).
  static Future<bool> checkIfSongInOpenWishes(String title, String artist, String partyId) async {
    final m = await findSimilarPendingWish(
      title: title,
      artist: artist,
      partyId: partyId,
      spotifyId: null,
    );
    return m != null;
  }

  /// Findet einen ähnlichen offenen Wunsch (Spotify-ID oder verschärfte String-Ähnlichkeit wie PWA).
  static Future<SimilarPendingWishMatch?> findSimilarPendingWish({
    required String title,
    required String artist,
    required String partyId,
    String? spotifyId,
  }) async {
    try {
      if (partyId.isEmpty || partyId == 'manual') return null;
      await ensurePartySettingsLoaded();
      final threshold = await _getDuplicateThreshold();
      final ignoredKeywords = getCachedIgnoredKeywords();
      final minTitleArtist = min(0.85, threshold);
      final titleThreshold = threshold * 0.8;
      final artistThreshold = threshold * 0.8;

      DateTime? partyStart;
      DateTime? partyEnd;
      try {
        final partyDoc = await FirebaseFirestore.instance.collection('parties').doc(partyId).get();
        final pd = partyDoc.data();
        final sd = pd?['start_date'];
        final ed = pd?['end_date'];
        if (sd is Timestamp) partyStart = sd.toDate();
        if (ed is Timestamp) partyEnd = ed.toDate();
      } catch (_) {}

      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('wishes')
          .where('party_id', isEqualTo: partyId)
          .where('status', isEqualTo: 'pending')
          .get();

      final normalizedInputTitle = normalizeTextForDuplicateCheck(title, ignoredKeywords);
      final normalizedInputArtist = normalizeTextForDuplicateCheck(artist, ignoredKeywords);

      final sid = spotifyId?.trim();
      if (sid != null && sid.isNotEmpty) {
        for (final doc in pendingSnapshot.docs) {
          final data = doc.data();
          if (data['is_duplicate'] == true) continue;
          final ts = data['createdAt'];
          if (ts is! Timestamp) continue;
          final createdDate = ts.toDate();
          if (partyStart != null && partyEnd != null) {
            if (createdDate.isBefore(partyStart) || !createdDate.isBefore(partyEnd)) continue;
          }
          final existingSpotifyId = data['spotify_id'] as String?;
          if (existingSpotifyId != null && existingSpotifyId == sid) {
            return SimilarPendingWishMatch(documentId: doc.id, data: data);
          }
        }
      }

      SimilarPendingWishMatch? bestMatch;
      var bestSimilarity = 0.0;

      for (final doc in pendingSnapshot.docs) {
        final data = doc.data();
        if (data['is_duplicate'] == true) continue;
        final ts = data['createdAt'];
        if (ts is! Timestamp) continue;
        final createdDate = ts.toDate();
        if (partyStart != null && partyEnd != null) {
          if (createdDate.isBefore(partyStart) || !createdDate.isBefore(partyEnd)) continue;
        }

        final rawWishTitle = (data['title'] ?? data['song'] ?? '') as String;
        final rawWishArtist = data['artist'] as String? ?? '';
        final existingTitle = normalizeTextForDuplicateCheck(rawWishTitle, ignoredKeywords);
        final existingArtist = normalizeTextForDuplicateCheck(rawWishArtist, ignoredKeywords);

        double titleSimilarity = 0.0;
        double artistSimilarity = 0.0;
        if (normalizedInputTitle.isNotEmpty && existingTitle.isNotEmpty) {
          titleSimilarity = StringSimilarity.compareTwoStrings(normalizedInputTitle, existingTitle);
        }
        if (normalizedInputArtist.isNotEmpty && existingArtist.isNotEmpty) {
          artistSimilarity = StringSimilarity.compareTwoStrings(normalizedInputArtist, existingArtist);
        }

        double combinedSimilarity = 0.0;
        if (normalizedInputTitle.isNotEmpty && normalizedInputArtist.isNotEmpty) {
          combinedSimilarity = titleSimilarity * 0.7 + artistSimilarity * 0.3;
        } else if (normalizedInputTitle.isNotEmpty) {
          combinedSimilarity = titleSimilarity;
        } else if (normalizedInputArtist.isNotEmpty) {
          combinedSimilarity = artistSimilarity;
        } else {
          continue;
        }

        final titleMatch = titleSimilarity >= titleThreshold;
        final artistMatch = artistSimilarity >= artistThreshold;
        final combinedMatch = combinedSimilarity >= threshold;
        final titleArtistMin = titleSimilarity >= minTitleArtist && artistSimilarity >= minTitleArtist;
        final bestMatchCondition = combinedSimilarity > bestSimilarity;
        final isDuplicate =
            titleArtistMin && ((titleMatch && artistMatch) || combinedMatch) && bestMatchCondition;

        if (isDuplicate) {
          bestSimilarity = combinedSimilarity;
          bestMatch = SimilarPendingWishMatch(documentId: doc.id, data: data);
        }
      }
      return bestMatch;
    } catch (e) {
      debugLog('⚠️ findSimilarPendingWish: $e');
      return null;
    }
  }
}


