import 'package:http/http.dart' as http;
import 'dart:convert';

class SpotifyTrack {
  final String id;
  final String name;
  final String artists;
  final String album;
  final String? previewUrl;
  final Map<String, dynamic> externalUrls;

  SpotifyTrack({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    this.previewUrl,
    required this.externalUrls,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    return SpotifyTrack(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      artists: json['artists'] ?? '',
      album: json['album'] ?? '',
      previewUrl: json['previewUrl'],
      externalUrls: json['externalUrls'] ?? {},
    );
  }

  // Formatierte Anzeige: "Titel - Artist"
  String get displayText => '$name - $artists';
}

class SpotifyService {
  // Cloud Function URL - wird beim ersten Aufruf gesetzt
  static String? _cloudFunctionUrl;

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
  static Future<List<SpotifyTrack>> searchTracks(String query, {String searchType = 'track'}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      // Bestimme die Cloud Function URL
      String functionUrl;
      if (_cloudFunctionUrl != null) {
        functionUrl = _cloudFunctionUrl!;
      } else {
        // Standard URL für Production
        final projectId = 'dj-ollerganove';
        functionUrl = 'https://us-central1-$projectId.cloudfunctions.net/searchSpotifyTracks';
      }

      final url = Uri.parse('$functionUrl?q=${Uri.encodeComponent(query.trim())}&type=$searchType');
      
      print('🌐 HTTP Request: $url');
      final response = await http.get(url);
      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('📦 Response Data: ${data.keys}');
        
        if (data['tracks'] != null) {
          final List<dynamic> tracksJson = data['tracks'] as List<dynamic>;
          print('🎵 Anzahl Tracks: ${tracksJson.length}');
          return tracksJson.map((json) => SpotifyTrack.fromJson(json as Map<String, dynamic>)).toList();
        }
      } else {
        print('❌ Spotify-Suche Fehler: Status ${response.statusCode} - ${response.body}');
      }
      
      return [];
    } catch (e, stackTrace) {
      print('❌ Fehler bei der Spotify-Suche: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
}
