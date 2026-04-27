import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/app_config.dart';
import 'services/spotify_search_settings_service.dart';
import 'utils/spotify_non_music_filter.dart';
import 'utils/debug_log.dart';

class SpotifyTrack {
  final String id;
  final String name;
  final String artists;
  final String album;
  final String? previewUrl;
  final Map<String, dynamic> externalUrls;
  final int? durationMs;
  final List<String> genres;

  SpotifyTrack({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    this.previewUrl,
    required this.externalUrls,
    this.durationMs,
    this.genres = const [],
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    // Genres können als List<dynamic> kommen, konvertiere zu List<String>
    List<String> genresList = [];
    if (json['genres'] != null) {
      if (json['genres'] is List) {
        genresList = (json['genres'] as List).map((e) => e.toString()).toList();
      }
    }

    return SpotifyTrack(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      artists: json['artists'] ?? '',
      album: json['album'] ?? '',
      previewUrl: json['previewUrl'],
      externalUrls: json['externalUrls'] ?? {},
      durationMs: json['duration_ms'] as int?,
      genres: genresList,
    );
  }

  // Formatierte Anzeige: "Titel - Artist"
  String get displayText => '$name - $artists';
}

class SpotifyService {
  // Cloud Function URL - wird beim ersten Aufruf gesetzt
  static String? _cloudFunctionUrl;

  static Future<Map<String, String>> _buildSecurityHeaders() async {
    final headers = <String, String>{};

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final idToken = await user.getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $idToken';
      }
      headers['X-Client-Id'] = user.uid;
    }

    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken();
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheckToken;
      }
    } catch (_) {
      // Kein App Check (z. B. Debug-Build ohne Aktivierung)
    }

    return headers;
  }

  /// Setzt die Cloud Function URL (optional, für lokale Tests)
  static void setCloudFunctionUrl(String? url) {
    _cloudFunctionUrl = url;
  }

  /// Sucht Tracks über die Spotify API via Cloud Function
  ///
  /// [query] - Suchbegriff (Titel oder Artist)
  /// [searchType] - Art der Suche: 'track' (Standard), 'artist' oder 'both'
  ///
  /// Gibt eine Liste von SpotifyTrack-Objekten zurück
  static Future<List<SpotifyTrack>> searchTracks(
    String query, {
    String searchType = 'track',
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      return [];
    }
    try {
      await SpotifySearchSettingsService.instance.ensureLoadedForSearch();
      // Bestimme die Cloud Function URL
      String functionUrl;
      if (_cloudFunctionUrl != null) {
        functionUrl = _cloudFunctionUrl!;
      } else {
        // Standard URL für Production
        functionUrl = AppConfig.spotifyFunctionUrl;
      }

      final url = Uri.parse(
        '$functionUrl?q=${Uri.encodeComponent(trimmedQuery)}&type=$searchType',
      );

      debugLog('🌐 HTTP Request: $url');
      final headers = await _buildSecurityHeaders();
      final response = await http.get(url, headers: headers);
      debugLog('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        debugLog('📦 Response Data: ${data.keys}');

        if (data['tracks'] != null) {
          final List<dynamic> tracksJson = data['tracks'] as List<dynamic>;
          final parsed = tracksJson
              .map(
                (json) => SpotifyTrack.fromJson(json as Map<String, dynamic>),
              )
              .toList();
          final filtered = parsed
              .where(
                (t) => !SpotifyNonMusicFilter.shouldExcludeTrack(
                  name: t.name,
                  artists: t.artists,
                  album: t.album,
                  durationMs: t.durationMs,
                  genres: t.genres,
                ),
              )
              .toList();
          debugLog('🎵 Anzahl Tracks: ${parsed.length} → nach Filter: ${filtered.length}');
          return filtered;
        }
      } else {
        debugLog(
          '❌ Spotify-Suche Fehler: Status ${response.statusCode} - ${response.body}',
        );
      }

      return [];
    } catch (e, stackTrace) {
      debugLog('❌ Fehler bei der Spotify-Suche: $e');
      debugLog('Stack trace: $stackTrace');
      return [];
    }
  }
}
