import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/spotify_non_music_filter.dart';
import 'spotify_search_settings_service.dart';

/// Spotify-Artist aus der Such-API.
class SpotifyArtist {
  final String id;
  final String name;
  final String? imageUrl;

  const SpotifyArtist({required this.id, required this.name, this.imageUrl});

  factory SpotifyArtist.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as List?;
    String? url;
    if (images != null && images.isNotEmpty) {
      final first = images.first as Map<String, dynamic>?;
      url = first?['url'] as String?;
    }
    return SpotifyArtist(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      imageUrl: url,
    );
  }
}

/// Spotify-Track aus der Such-API.
class SpotifyTrack {
  final String id;
  final String name;
  final String artistName;
  final String album;
  final int? durationMs;
  final List<String> artistIds;
  final List<String> genres;

  const SpotifyTrack({
    required this.id,
    required this.name,
    required this.artistName,
    this.album = '',
    this.durationMs,
    this.artistIds = const [],
    this.genres = const [],
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final ids = json['artist_ids'] as List?;
    final artistIds = ids != null
        ? ids
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : <String>[];
    final genresRaw = json['genres'] as List?;
    final genres = genresRaw != null
        ? genresRaw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
        : <String>[];
    return SpotifyTrack(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      artistName: (json['artists'] as String?) ?? '',
      album: (json['album'] as String?) ?? '',
      durationMs: json['duration_ms'] as int?,
      artistIds: artistIds,
      genres: genres,
    );
  }
}

/// Ergebnis einer Spotify-Suche (Artist oder Track).
class SpotifySearchResult {
  final List<SpotifyArtist> artists;
  final List<SpotifyTrack> tracks;
  final String resultType; // 'artist' | 'track'

  const SpotifySearchResult({
    this.artists = const [],
    this.tracks = const [],
    this.resultType = 'track',
  });

  factory SpotifySearchResult.fromJson(Map<String, dynamic> json) {
    final resultType = (json['resultType'] as String?) ?? 'track';
    final artistsRaw = json['artists'] as List? ?? [];
    final tracksRaw = json['tracks'] as List? ?? [];
    return SpotifySearchResult(
      resultType: resultType,
      artists: artistsRaw
          .map(
            (e) => SpotifyArtist.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      tracks: tracksRaw
          .map(
            (e) => SpotifyTrack.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

/// Service für Spotify-API-Abfragen über die Cloud Function.
class SpotifyService {
  SpotifyService._();
  static final SpotifyService _instance = SpotifyService._();
  static SpotifyService get instance => _instance;

  Future<Map<String, String>> _buildSecurityHeaders() async {
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

  /// Sucht Artists oder Tracks über die Cloud Function.
  /// [q] Query (z.B. "Beatles" oder artist:"Beatles" track:"Hey Jude").
  /// [type] "artist" oder "track".
  Future<SpotifySearchResult> search({
    required String q,
    required String type,
  }) async {
    final trimmedQuery = q.trim();
    if (trimmedQuery.length < 2) {
      return const SpotifySearchResult();
    }
    await SpotifySearchSettingsService.instance.ensureLoadedForSearch();

    final uri = Uri.parse(
      AppConfig.spotifyFunctionUrl,
    ).replace(queryParameters: {'q': trimmedQuery, 'type': type});

    final headers = await _buildSecurityHeaders();
    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Spotify-Suche fehlgeschlagen: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = SpotifySearchResult.fromJson(data);
    if (raw.resultType == 'artist') {
      final artists = raw.artists
          .where((a) => !SpotifyNonMusicFilter.shouldExcludeArtistName(a.name))
          .toList();
      return SpotifySearchResult(
        resultType: raw.resultType,
        artists: artists,
        tracks: raw.tracks,
      );
    }
    final tracks = raw.tracks
        .where(
          (t) => !SpotifyNonMusicFilter.shouldExcludeTrack(
            name: t.name,
            artists: t.artistName,
            album: t.album,
            durationMs: t.durationMs,
            genres: t.genres,
          ),
        )
        .toList();
    return SpotifySearchResult(
      resultType: raw.resultType,
      artists: raw.artists,
      tracks: tracks,
    );
  }
}
