import 'dart:convert';
import 'dart:io';

import 'firebase_options.dart';

/// Firebase Auth/Firestore über REST — umgeht die macOS-Keychain von Firebase Auth.
class ToolRestClient {
  ToolRestClient();

  static const _projectId = 'dj-ollerganove';
  static const _region = 'us-central1';

  final String _apiKey = DefaultFirebaseOptions.windows.apiKey;

  Future<Map<String, dynamic>> signInWithCustomToken(String customToken) async {
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$_apiKey',
    );
    final data = await _postJson(uri, {
      'token': customToken,
      'returnSecureToken': true,
    });
    final idToken = (data['idToken'] ?? '').toString();
    final refreshToken = (data['refreshToken'] ?? '').toString();
    final expiresIn = int.tryParse('${data['expiresIn']}') ?? 3600;
    if (idToken.isEmpty || refreshToken.isEmpty) {
      throw StateError('Login-Antwort unvollständig.');
    }
    return {
      'idToken': idToken,
      'refreshToken': refreshToken,
      'expiryMs': DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
    };
  }

  Future<Map<String, dynamic>> refreshIdToken(String refreshToken) async {
    final uri = Uri.parse(
      'https://securetoken.googleapis.com/v1/token?key=$_apiKey',
    );
    final data = await _postForm(uri, {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });
    final idToken = (data['id_token'] ?? data['idToken'] ?? '').toString();
    final newRefresh = (data['refresh_token'] ?? data['refreshToken'] ?? refreshToken)
        .toString();
    final expiresIn = int.tryParse('${data['expires_in'] ?? data['expiresIn']}') ?? 3600;
    if (idToken.isEmpty) {
      throw StateError('Token-Refresh fehlgeschlagen.');
    }
    return {
      'idToken': idToken,
      'refreshToken': newRefresh,
      'expiryMs': DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
    };
  }

  Future<Map<String, dynamic>?> getPublicDocument({
    required String collection,
    required String docId,
  }) async {
    final encoded = Uri.encodeComponent(docId);
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$encoded?key=$_apiKey',
    );
    try {
      final decoded = await _getJson(uri);
      final fields = decoded['fields'];
      if (fields is! Map) return null;
      return decodeFirestoreFields(Map<String, dynamic>.from(fields));
    } on StateError catch (e) {
      final message = e.message;
      if (message.contains('404') ||
          message.contains('NOT_FOUND') ||
          message.contains('403') ||
          message.contains('PERMISSION_DENIED')) {
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDocument({
    required String idToken,
    required String collection,
    required String docId,
  }) async {
    final encoded = Uri.encodeComponent(docId);
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$encoded',
    );
    try {
      final decoded = await _getJson(uri, bearer: idToken);
      final fields = decoded['fields'];
      if (fields is! Map) return null;
      final out = decodeFirestoreFields(Map<String, dynamic>.from(fields));
      return out;
    } on StateError catch (e) {
      if (e.message.contains('404') || e.message.contains('NOT_FOUND')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> setDocument({
    required String idToken,
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final encoded = Uri.encodeComponent(docId);
    final name =
        'projects/$_projectId/databases/(default)/documents/$collection/$encoded';
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:commit',
    );
    await _postJson(
      uri,
      {
        'writes': [
          {
            'update': {
              'name': name,
              'fields': _encodeFields(data),
            },
          },
        ],
      },
      bearer: idToken,
    );
  }

  Future<void> incrementTransition({
    required String idToken,
    required String fromId,
    required String toId,
    required String fromArtist,
    required String fromTitle,
    required String fromVersion,
    required String toArtist,
    required String toTitle,
    required String toVersion,
    int? toBpm,
    String? toCamelot,
    required String software,
    required String osKey,
  }) async {
    final encoded = Uri.encodeComponent(fromId);
    final name =
        'projects/$_projectId/databases/(default)/documents/song_transitions/$encoded';
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:commit',
    );
    await _postJson(
      uri,
      {
        'writes': [
          {
            'update': {
              'name': name,
              'fields': _encodeFields({
                'from_artist': fromArtist,
                'from_title': fromTitle,
                'from_version': fromVersion,
                'next_tracks': {
                  toId: {
                    'to_artist': toArtist,
                    'to_title': toTitle,
                    'to_version': toVersion,
                    if (toBpm != null) 'to_bpm': toBpm,
                    if (toCamelot != null && toCamelot.isNotEmpty)
                      'to_camelot': toCamelot,
                  },
                },
              }),
            },
            'updateMask': {
              'fieldPaths': [
                'from_artist',
                'from_title',
                'from_version',
                'next_tracks.$toId.to_artist',
                'next_tracks.$toId.to_title',
                'next_tracks.$toId.to_version',
                if (toBpm != null) 'next_tracks.$toId.to_bpm',
                if (toCamelot != null && toCamelot.isNotEmpty)
                  'next_tracks.$toId.to_camelot',
              ],
            },
          },
          {
            'transform': {
              'document': name,
              'fieldTransforms': [
                {
                  'fieldPath': 'next_tracks.$toId.count',
                  'increment': {'integerValue': '1'},
                },
                {
                  'fieldPath': 'next_tracks.$toId.software_used.$software',
                  'increment': {'integerValue': '1'},
                },
                {
                  'fieldPath': 'next_tracks.$toId.os_used.$osKey',
                  'increment': {'integerValue': '1'},
                },
                {
                  'fieldPath': 'next_tracks.$toId.last_played_at',
                  'setToServerValue': 'REQUEST_TIME',
                },
              ],
            },
          },
        ],
      },
      bearer: idToken,
    );
  }

  Future<void> setLiveDoc({
    required String idToken,
    required String ownerUid,
    required Map<String, dynamic> payload,
  }) async {
    final name =
        'projects/$_projectId/databases/(default)/documents/rb_tool_live/$ownerUid';
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:commit',
    );
    await _postJson(
      uri,
      {
        'writes': [
          {
            'update': {
              'name': name,
              'fields': _encodeFields({
                ...payload,
                'updatedAt': DateTime.now().toUtc(),
              }),
            },
          },
        ],
      },
      bearer: idToken,
    );
  }

  Future<Map<String, dynamic>?> readRecommendPreview({
    required String idToken,
    required String ownerUid,
  }) async {
    final encoded = Uri.encodeComponent(ownerUid);
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/rb_tool_preview/$encoded',
    );
    try {
      final decoded = await _getJson(uri, bearer: idToken);
      final fields = decoded['fields'];
      if (fields is! Map) return null;
      return decodeFirestoreFields(Map<String, dynamic>.from(fields));
    } catch (_) {
      return null;
    }
  }

  /// Songs kommen als einzelne Zeilen, sobald das Modell einen fertig hat.
  Future<void> recommendTracksLive({
    required String idToken,
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    String scope = 'similar',
    String familiarity = 'hits',
    bool allowSameArtist = true,
    int count = 5,
    List<Map<String, String>> exclude = const <Map<String, String>>[],
    required void Function(Map<String, dynamic> track) onTrack,
  }) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/openaiMusicRecommendStream',
    );
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.acceptHeader, 'application/x-ndjson');
      req.write(jsonEncode({
        'title': title,
        'artist': artist,
        'scope': scope,
        'familiarity': familiarity,
        'allowSameArtist': allowSameArtist,
        'count': count < 1 ? 1 : (count > 20 ? 20 : count),
        if (bpm != null) 'bpm': bpm,
        if (camelot != null && camelot.isNotEmpty) 'camelot': camelot,
        'exclude': exclude,
      }));
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        await res.drain<void>();
        return;
      }
      var pending = '';
      await for (final chunk in res
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 28))) {
        pending += chunk;
        final lines = pending.split('\n');
        pending = lines.removeLast();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          dynamic decoded;
          try {
            decoded = jsonDecode(trimmed);
          } catch (_) {
            continue;
          }
          if (decoded is! Map) continue;
          if (decoded['done'] == true) return;
          final rowTitle = (decoded['title'] ?? '').toString();
          final rowArtist = (decoded['artist'] ?? '').toString();
          if (rowTitle.trim().isEmpty || rowArtist.trim().isEmpty) continue;
          onTrack(Map<String, dynamic>.from(decoded));
        }
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> recommendTracks({
    required String idToken,
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    String scope = 'similar',
    String familiarity = 'hits',
    bool allowSameArtist = true,
    int count = 5,
    List<Map<String, String>> exclude = const <Map<String, String>>[],
  }) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/openaiMusicProxy',
    );
    final decoded = await _postJson(
      uri,
      {
        'data': <String, dynamic>{
          'action': 'recommend',
          'title': title,
          'artist': artist,
          'scope': scope,
          'familiarity': familiarity,
          'allowSameArtist': allowSameArtist,
          'count': count < 1 ? 1 : (count > 20 ? 20 : count),
          if (bpm != null) 'bpm': bpm,
          if (camelot != null && camelot.isNotEmpty) 'camelot': camelot,
          'exclude': exclude,
        },
      },
      bearer: idToken,
    );
    final data = decoded['result'] is Map
        ? Map<String, dynamic>.from(decoded['result'] as Map)
        : decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'] as Map)
            : decoded;
    final raw = data['tracks'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      out.add(Map<String, dynamic>.from(entry));
      if (out.length >= 20) break;
    }
    return out;
  }

  Future<Map<String, dynamic>> getWishboard({
    required String idToken,
    bool includeSetlist = true,
    bool includePre = true,
    bool includeSongRec = true,
    bool partyOnly = false,
    bool playedOnly = false,
    String? partyId,
    Map<String, String>? install,
  }) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/getRbToolWishboard',
    );
    final payload = <String, dynamic>{
      'includeSetlist': includeSetlist,
      'includePre': includePre,
      'includeSongRec': includeSongRec,
      'partyOnly': partyOnly,
      'playedOnly': playedOnly,
    };
    final pid = partyId?.trim() ?? '';
    if (pid.isNotEmpty) payload['partyId'] = pid;
    if (install != null && install.isNotEmpty) payload['install'] = install;
    final decoded = await _postJson(
      uri,
      {'data': payload},
      bearer: idToken,
    );
    if (decoded['result'] is Map) {
      return Map<String, dynamic>.from(decoded['result'] as Map);
    }
    if (decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data'] as Map);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> setSongRec({
    required String idToken,
    required bool enabled,
    required String scope,
    required String familiarity,
    required bool allowSameArtist,
    required int count,
  }) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/setRbToolSongRec',
    );
    final decoded = await _postJson(
      uri,
      {
        'data': <String, dynamic>{
          'enabled': enabled,
          'scope': scope,
          'familiarity': familiarity,
          'allowSameArtist': allowSameArtist,
          'count': count,
        },
      },
      bearer: idToken,
    );
    if (decoded['result'] is Map) {
      return Map<String, dynamic>.from(decoded['result'] as Map);
    }
    if (decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data'] as Map);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> markRecognized({
    required String idToken,
    required String partyId,
    required String title,
    required String artist,
  }) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/markRbToolRecognized',
    );
    final decoded = await _postJson(
      uri,
      {
        'data': {
          'partyId': partyId,
          'title': title,
          'artist': artist,
        },
      },
      bearer: idToken,
    );
    if (decoded['result'] is Map) {
      return Map<String, dynamic>.from(decoded['result'] as Map);
    }
    if (decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data'] as Map);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> wishAction({
    required String idToken,
    required String partyId,
    required String action,
    List<String> wishIds = const [],
    String title = '',
    String artist = '',
    String direction = '',
  }) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/rbToolWishAction',
    );
    final decoded = await _postJson(
      uri,
      {
        'data': {
          'partyId': partyId,
          'action': action,
          'wishIds': wishIds,
          'title': title,
          'artist': artist,
          if (direction.isNotEmpty) 'direction': direction,
        },
      },
      bearer: idToken,
    );
    final result = decoded['result'];
    if (result is Map) return Map<String, dynamic>.from(result);
    return decoded;
  }

  Future<String?> translateGreeting({
    required String idToken,
    required String text,
    required String targetLanguage,
  }) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/translateGreeting',
    );
    final decoded = await _postJson(
      uri,
      {
        'data': {
          'text': text,
          'targetLanguage': targetLanguage,
        },
      },
      bearer: idToken,
    );
    final result = decoded['result'] is Map
        ? Map<String, dynamic>.from(decoded['result'] as Map)
        : decoded;
    if (result['skipped'] == true) return null;
    final translated = (result['translatedText'] ?? '').toString().trim();
    if (translated.isEmpty || translated == text.trim()) return null;
    return translated;
  }

  Future<void> revokeSession({
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/revokeRbToolSession',
    );
    try {
      await _postJson(uri, {'data': <String, dynamic>{}}, bearer: idToken);
    } catch (_) {
      // Lokales Logout soll nicht an Revoke hängen.
    }
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearer != null && bearer.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close();
      final text = await utf8.decodeStream(res);
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = _errorMessage(decoded) ?? 'HTTP ${res.statusCode}';
        throw StateError(message);
      }
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _postForm(
    Uri uri,
    Map<String, String> fields,
  ) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.parse(
        'application/x-www-form-urlencoded',
      );
      req.add(utf8.encode(Uri(queryParameters: fields).query));
      final res = await req.close();
      final text = await utf8.decodeStream(res);
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = _errorMessage(decoded) ?? 'HTTP ${res.statusCode}';
        throw StateError(message);
      }
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } finally {
      client.close(force: true);
    }
  }

  String? _errorMessage(Object decoded) {
    if (decoded is! Map) return null;
    final error = decoded['error'];
    if (error is Map) {
      final msg = error['message'];
      if (msg != null) return msg.toString();
    }
    return decoded['error']?.toString();
  }

  Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      fields[entry.key] = _encodeValue(entry.value);
    }
    return fields;
  }

  Map<String, dynamic> _encodeValue(Object? value) {
    if (value == null) return {'nullValue': 'NULL_VALUE'};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is double) return {'doubleValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is String) return {'stringValue': value};
    if (value is List) {
      return {
        'arrayValue': {
          'values': [for (final item in value) _encodeValue(item)],
        },
      };
    }
    if (value is Map) {
      final nested = <String, dynamic>{};
      for (final entry in value.entries) {
        nested['${entry.key}'] = _encodeValue(entry.value);
      }
      return {
        'mapValue': {'fields': nested},
      };
    }
    return {'stringValue': value.toString()};
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, {String? bearer}) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearer != null && bearer.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      final res = await req.close();
      final text = await utf8.decodeStream(res);
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = _errorMessage(decoded) ?? 'HTTP ${res.statusCode}';
        throw StateError(message);
      }
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } finally {
      client.close(force: true);
    }
  }
}

Map<String, dynamic> decodeFirestoreFields(Map<String, dynamic> fields) {
  final out = <String, dynamic>{};
  for (final entry in fields.entries) {
    if (entry.value is Map) {
      out[entry.key] = decodeFirestoreValue(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
  }
  return out;
}

Object? decodeFirestoreValue(Map<String, dynamic> value) {
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('booleanValue')) return value['booleanValue'] == true;
  if (value.containsKey('integerValue')) {
    return int.tryParse('${value['integerValue']}') ?? 0;
  }
  if (value.containsKey('doubleValue')) {
    final n = value['doubleValue'];
    if (n is num) return n.toDouble();
    return double.tryParse('$n');
  }
  if (value.containsKey('timestampValue')) {
    return DateTime.tryParse('${value['timestampValue']}');
  }
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('arrayValue')) {
    final raw = value['arrayValue'];
    final values = raw is Map ? raw['values'] : null;
    if (values is! List) return const [];
    return [
      for (final item in values)
        if (item is Map)
          decodeFirestoreValue(Map<String, dynamic>.from(item)),
    ];
  }
  if (value.containsKey('mapValue')) {
    final raw = value['mapValue'];
    final fields = raw is Map ? raw['fields'] : null;
    if (fields is! Map) return <String, dynamic>{};
    return decodeFirestoreFields(Map<String, dynamic>.from(fields));
  }
  return null;
}
