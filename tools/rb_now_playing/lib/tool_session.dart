import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'rekordbox_live.dart';
import 'tool_i18n.dart';
import 'tool_rest.dart';
import 'camelot.dart';

/// Sichtbarer Gerätename für die App, zum Beispiel „macOS 26.6.2“ oder „Windows 11“.
String formatToolDevice(String os, String version) {
  if (os == 'macos') {
    final match = RegExp(r'(\d+\.\d+(?:\.\d+)?)').firstMatch(version);
    final number = match?.group(1);
    return number == null || number.isEmpty ? 'macOS' : 'macOS $number';
  }
  if (os == 'windows') {
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(version);
    final build = int.tryParse(match?.group(3) ?? '') ?? 0;
    if (build >= 22000) return 'Windows 11';
    if (build > 0) return 'Windows 10';
    return 'Windows';
  }
  return os;
}

String toolDeviceLabel() {
  final label = formatToolDevice(
    Platform.operatingSystem,
    Platform.operatingSystemVersion,
  );
  return label.length > 40 ? label.substring(0, 40) : label;
}

class ToolSession extends ChangeNotifier {
  ToolSession();

  static const _tenDigits = {
    'de': 'Bitte 10 Ziffern eingeben.',
    'en': 'Enter 10 digits.',
    'es': 'Introduce 10 dígitos.',
    'fr': 'Saisis 10 chiffres.',
    'it': 'Inserisci 10 cifre.',
    'pt': 'Introduz 10 dígitos.',
    'nl': 'Voer 10 cijfers in.',
    'pl': 'Wpisz 10 cyfr.',
    'cs': 'Zadej 10 číslic.',
    'tr': '10 rakam gir.',
    'ru': 'Введите 10 цифр.',
    'uk': 'Введіть 10 цифр.',
    'el': 'Βάλε 10 ψηφία.',
    'ar': 'أدخل 10 أرقام.',
    'hi': '10 अंक डालें।',
    'ja': '10桁を入力してください。',
    'zh': '请输入10位数字。',
    'th': 'ใส่ตัวเลข 10 หลัก',
    'vi': 'Nhập 10 chữ số.',
    'sq': 'Fut 10 shifra.',
  };

  final _rest = ToolRestClient();
  String? _sessionId;
  String? _ownerUid;
  String? _idToken;
  String? _refreshToken;
  int _expiryMs = 0;
  String? _error;
  String? _lastFingerprint;
  String? _queuedFingerprint;
  Map<String, dynamic>? _lastNowPlaying;
  Future<void> _liveQueue = Future<void>.value();
  bool _busy = false;

  bool get isConnected =>
      _idToken != null &&
      _idToken!.isNotEmpty &&
      _sessionId != null &&
      _ownerUid != null;

  ToolRestClient get rest => _rest;
  String? get ownerUid => _ownerUid;

  Future<String?> freshIdTokenOrNull() async {
    if (!isConnected) return null;
    try {
      await _ensureFreshToken();
      return _idToken;
    } catch (_) {
      return null;
    }
  }

  String? get error => _error;
  bool get busy => _busy;

  Future<void> restore() async {
    final stored = await _readStore();
    if (stored == null) return;
    _sessionId = stored['sessionId'];
    _ownerUid = stored['ownerUid'];
    _idToken = stored['idToken'];
    _refreshToken = stored['refreshToken'];
    _expiryMs = stored['expiryMs'] ?? 0;
    try {
      await _ensureFreshToken();
      notifyListeners();
    } catch (_) {
      await _clearStore();
      _sessionId = null;
      _ownerUid = null;
      _idToken = null;
      _refreshToken = null;
      _expiryMs = 0;
    }
  }

  Future<bool> connect(String rawCode) async {
    final code = rawCode.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{10}$').hasMatch(code)) {
      _error = _tenDigits[toolI18n.code] ?? _tenDigits['de']!;
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      // REST statt cloud_functions-Plugin (kein Windows-Host-API).
      final data = await _rest.redeemRbToolCode(code);
      final customToken = (data['customToken'] ?? '').toString();
      _sessionId = (data['sessionId'] ?? '').toString();
      _ownerUid = (data['ownerUid'] ?? '').toString();
      if (customToken.isEmpty ||
          _sessionId == null ||
          _sessionId!.isEmpty ||
          _ownerUid == null ||
          _ownerUid!.isEmpty) {
        throw StateError('Server-Antwort unvollständig.');
      }
      final tokens = await _rest.signInWithCustomToken(customToken);
      try {
        await FirebaseAuth.instance.signInWithCustomToken(customToken);
      } catch (_) {}
      _idToken = tokens['idToken'] as String;
      _refreshToken = tokens['refreshToken'] as String;
      _expiryMs = tokens['expiryMs'] as int;
      await _writeStore();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _busy = false;
      _error = e.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchWishboard({
    bool includeSetlist = true,
    bool includePre = true,
    bool includeSongRec = true,
    bool partyOnly = false,
    bool playedOnly = false,
    String? partyId,
    Map<String, String>? install,
  }) async {
    if (!isConnected) {
      throw StateError(toolI18n.text('notConnected'));
    }
    await _ensureFreshToken();
    return _rest.getWishboard(
      idToken: _idToken!,
      includeSetlist: includeSetlist,
      includePre: includePre,
      includeSongRec: includeSongRec,
      partyOnly: partyOnly,
      playedOnly: playedOnly,
      partyId: partyId,
      install: install,
    );
  }

  Future<Map<String, dynamic>> markRecognized({
    required String partyId,
    required String title,
    required String artist,
  }) async {
    if (!isConnected) {
      throw StateError(toolI18n.text('notConnected'));
    }
    await _ensureFreshToken();
    return _rest.markRecognized(
      idToken: _idToken!,
      partyId: partyId,
      title: title,
      artist: artist,
    );
  }

  Future<void> disconnect() async {
    try {
      if (isConnected) {
        await pushDisconnected();
        final token = _idToken;
        if (token != null) {
          await _rest.revokeSession(idToken: token);
        }
      }
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _clearStore();
    _sessionId = null;
    _ownerUid = null;
    _idToken = null;
    _refreshToken = null;
    _expiryMs = 0;
    _lastFingerprint = null;
    _queuedFingerprint = null;
    _lastNowPlaying = null;
    notifyListeners();
  }

  /// Verbunden bleiben, ohne den laufenden Song an die Musikerkennung zu schicken.
  void _enqueueLive(Future<void> Function() job) {
    _liveQueue = _liveQueue.then((_) => job()).catchError((Object _, StackTrace _) {});
  }

  Future<void> pushPresence() async {
    if (!isConnected || _sessionId == null || _ownerUid == null) return;
    final fingerprint = 'presence|${toolDeviceLabel()}';
    if (fingerprint == _lastFingerprint || fingerprint == _queuedFingerprint) {
      return;
    }
    _queuedFingerprint = fingerprint;
    _enqueueLive(() async {
      try {
        await _ensureFreshToken();
        await _rest.setLiveDoc(
          idToken: _idToken!,
          ownerUid: _ownerUid!,
          payload: {
            'sessionId': _sessionId,
            'connected': true,
            'source': toolDeviceLabel(),
            'nowPlaying': null,
            'decks': const <Map<String, dynamic>>[],
            'history': const <Map<String, dynamic>>[],
          },
        );
        _lastNowPlaying = null;
        _lastFingerprint = fingerprint;
      } finally {
        if (_queuedFingerprint == fingerprint) _queuedFingerprint = null;
      }
    });
  }

  Future<void> pushLive(LiveSnapshot snapshot) async {
    if (!isConnected || _sessionId == null || _ownerUid == null) return;
    final fingerprint = snapshot.fingerprint();
    if (fingerprint == _lastFingerprint || fingerprint == _queuedFingerprint) {
      return;
    }
    _queuedFingerprint = fingerprint;
    _enqueueLive(() async {
      try {
        await _ensureFreshToken();
        final now = snapshot.nowPlaying;
        final previous = _lastNowPlaying;
        final sameSong = now != null &&
            previous != null &&
            (previous['title'] ?? '').toString().trim() == now.title.trim() &&
            (previous['artist'] ?? '').toString().trim() == now.artist.trim();
        final kept = sameSong ? previous['suggestions'] : const <Map<String, dynamic>>[];
        final nowPlaying = now == null
            ? null
            : {
                'title': now.title,
                'artist': now.artist,
                'bpm': now.bpm,
                'key': now.musicalKey,
                'camelot': camelotFromScaleName(now.musicalKey),
                if (now.length != null) 'durationSec': now.length!.inSeconds,
                'suggestions': kept,
                if (sameSong && previous['suggestionsFor'] != null)
                  'suggestionsFor': previous['suggestionsFor'],
              };
        await _rest.setLiveDoc(
          idToken: _idToken!,
          ownerUid: _ownerUid!,
          payload: {
            'sessionId': _sessionId,
            'connected': true,
            'source': toolDeviceLabel(),
            'nowPlaying': nowPlaying,
            'decks': const <Map<String, dynamic>>[],
            'history': const <Map<String, dynamic>>[],
          },
        );
        _lastNowPlaying = nowPlaying == null
            ? null
            : Map<String, dynamic>.from(nowPlaying);
        _lastFingerprint = fingerprint;
      } finally {
        if (_queuedFingerprint == fingerprint) _queuedFingerprint = null;
      }
    });
  }

  Future<void> pushSuggestions({
    required String title,
    required String artist,
    required List<Map<String, dynamic>> suggestions,
  }) async {
    if (!isConnected || _sessionId == null || _ownerUid == null) return;
    final t = title.trim();
    final a = artist.trim();
    if (t.isEmpty || a.isEmpty) return;
    final slim = <Map<String, dynamic>>[];
    for (final raw in suggestions) {
      final item = _slimSuggestion(raw);
      if (item == null) continue;
      slim.add(item);
      if (slim.length >= 20) break;
    }
    _enqueueLive(() async {
      await _ensureFreshToken();
      final base = <String, dynamic>{
        ...?_lastNowPlaying,
        'title': t,
        'artist': a,
        'suggestions': slim,
        'suggestionsFor': '$t|$a',
      };
      await _rest.setLiveDoc(
        idToken: _idToken!,
        ownerUid: _ownerUid!,
        payload: {
          'sessionId': _sessionId,
          'connected': true,
          'source': toolDeviceLabel(),
          'nowPlaying': base,
          'decks': const <Map<String, dynamic>>[],
          'history': const <Map<String, dynamic>>[],
        },
      );
      _lastNowPlaying = base;
    });
  }

  /// Nur 5 kompakte Maps — gleicher Live-Doc, kein extra Store.
  static Map<String, dynamic>? _slimSuggestion(Map<String, dynamic> raw) {
    final title = (raw['title'] ?? '').toString().trim();
    final artist = (raw['artist'] ?? '').toString().trim();
    if (title.isEmpty || artist.isEmpty) return null;
    return <String, dynamic>{
      'title': title.length > 120 ? title.substring(0, 120) : title,
      'artist': artist.length > 120 ? artist.substring(0, 120) : artist,
      if (raw['bpm'] is num) 'bpm': raw['bpm'],
      if ((raw['camelot'] ?? '').toString().trim().isNotEmpty)
        'camelot': raw['camelot'].toString().trim(),
      if ((raw['genre'] ?? '').toString().trim().isNotEmpty)
        'genre': raw['genre'].toString().trim(),
      if ((raw['duration'] ?? '').toString().trim().isNotEmpty)
        'duration': raw['duration'].toString().trim(),
    };
  }

  final Map<String, String> _greetingCache = {};

  Future<Map<String, dynamic>> wishAction({
    required String partyId,
    required String action,
    List<String> wishIds = const [],
    String title = '',
    String artist = '',
    String direction = '',
  }) async {
    if (!isConnected) throw StateError(toolI18n.text('notConnected'));
    await _ensureFreshToken();
    return _rest.wishAction(
      idToken: _idToken!,
      partyId: partyId,
      action: action,
      wishIds: wishIds,
      title: title,
      artist: artist,
      direction: direction,
    );
  }

  Future<String?> translateGreeting(String text) async {
    final greeting = text.trim();
    if (!isConnected || greeting.isEmpty) return null;
    final key = '$greeting|${toolI18n.code}';
    final cached = _greetingCache[key];
    if (cached != null) return cached.isEmpty ? null : cached;
    await _ensureFreshToken();
    final translated = await _rest.translateGreeting(
      idToken: _idToken!,
      text: greeting,
      targetLanguage: toolI18n.code,
    );
    _greetingCache[key] = translated ?? '';
    return translated;
  }

  Future<void> saveSongRec({
    required bool enabled,
    required String scope,
    required String familiarity,
    required bool allowSameArtist,
    required int count,
  }) async {
    if (!isConnected) {
      throw StateError(toolI18n.text('notConnected'));
    }
    await _ensureFreshToken();
    await _rest.setSongRec(
      idToken: _idToken!,
      enabled: enabled,
      scope: scope,
      familiarity: familiarity,
      allowSameArtist: allowSameArtist,
      count: count,
    );
  }

  Future<void> recommendLive({
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    String scope = 'similar',
    String familiarity = 'hits',
    bool allowSameArtist = true,
    int count = 5,
    List<Map<String, String>> exclude = const <Map<String, String>>[],
    bool fresh = false,
    required void Function(Map<String, dynamic> track) onTrack,
  }) async {
    if (!isConnected || _ownerUid == null) return;
    await _ensureFreshToken();
    final forKey = '${title.trim()}|${artist.trim()}';
    String? seenPreview;
    final timer = Timer.periodic(const Duration(milliseconds: 280), (_) async {
      final doc = await _rest.readRecommendPreview(
        idToken: _idToken!,
        ownerUid: _ownerUid!,
      );
      if (doc == null || doc['forKey'] != forKey) return;
      final raw = doc['tracks'];
      if (raw is! List) return;
      final sig = raw.length.toString();
      if (fresh && seenPreview == null) {
        seenPreview = sig;
        return;
      }
      seenPreview = sig;
      for (final entry in raw) {
        if (entry is Map) onTrack(Map<String, dynamic>.from(entry));
      }
    });
    try {
      await _rest.recommendTracksLive(
        idToken: _idToken!,
        title: title,
        artist: artist,
        bpm: bpm,
        camelot: camelot,
        scope: scope,
        familiarity: familiarity,
        allowSameArtist: allowSameArtist,
        count: count,
        exclude: exclude,
        onTrack: onTrack,
      );
    } finally {
      timer.cancel();
    }
  }

  Future<List<Map<String, dynamic>>> recommendFor({
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
    if (!isConnected) return const <Map<String, dynamic>>[];
    await _ensureFreshToken();
    return _rest.recommendTracks(
      idToken: _idToken!,
      title: title,
      artist: artist,
      bpm: bpm,
      camelot: camelot,
      scope: scope,
      familiarity: familiarity,
      allowSameArtist: allowSameArtist,
      count: count,
      exclude: exclude,
    );
  }

  Future<void> pushDisconnected() async {
    if (_sessionId == null || _ownerUid == null || _idToken == null) return;
    try {
      await _ensureFreshToken();
      await _rest.setLiveDoc(
        idToken: _idToken!,
        ownerUid: _ownerUid!,
        payload: {
          'sessionId': _sessionId,
          'connected': false,
          'source': toolDeviceLabel(),
          'nowPlaying': null,
          'decks': const [],
          'history': const [],
        },
      );
    } catch (_) {}
  }

  Future<void> _ensureFreshToken() async {
    final refresh = _refreshToken;
    if (_idToken == null || refresh == null) {
      throw StateError(toolI18n.text('notConnected'));
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_expiryMs - now > 60000) return;
    final tokens = await _rest.refreshIdToken(refresh);
    _idToken = tokens['idToken'] as String;
    _refreshToken = tokens['refreshToken'] as String;
    _expiryMs = tokens['expiryMs'] as int;
    await _writeStore();
  }

  File _storeFile() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final Directory dir;
    if (Platform.isWindows) {
      final appData =
          Platform.environment['APPDATA'] ?? '$home\\AppData\\Roaming';
      dir = Directory('$appData\\VibesBoxRbTool');
    } else if (Platform.isMacOS) {
      dir = Directory('$home/Library/Application Support/VibesBoxRbTool');
    } else {
      dir = Directory('$home/.vibesbox_rb_tool');
    }
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/session.json');
  }

  Future<Map<String, dynamic>?> _readStore() async {
    try {
      final file = _storeFile();
      if (!file.existsSync()) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return null;
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeStore() async {
    final file = _storeFile();
    await file.writeAsString(
      jsonEncode({
        'sessionId': _sessionId,
        'ownerUid': _ownerUid,
        'idToken': _idToken,
        'refreshToken': _refreshToken,
        'expiryMs': _expiryMs,
      }),
    );
  }

  Future<void> _clearStore() async {
    try {
      final file = _storeFile();
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}
