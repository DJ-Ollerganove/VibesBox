import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../utils/debug_log.dart';
import 'user_self_settings_service.dart';
import 'user_service.dart';

enum SongRecScope { strict, similar, bold }

enum SongRecFamiliarity { hits, mix }

class SongRecommendationSettings {
  const SongRecommendationSettings({
    required this.enabled,
    required this.scope,
    required this.familiarity,
    required this.allowSameArtist,
    required this.count,
  });

  static const defaults = SongRecommendationSettings(
    enabled: true,
    scope: SongRecScope.similar,
    familiarity: SongRecFamiliarity.hits,
    allowSameArtist: true,
    count: 5,
  );

  static const fieldEnabled = 'song_rec_enabled';
  static const fieldScope = 'song_rec_scope';
  static const fieldFamiliarity = 'song_rec_familiarity';
  static const fieldSameArtist = 'song_rec_same_artist';
  static const fieldCount = 'song_rec_count';
  static const minCount = 1;
  static const maxCount = 20;

  final bool enabled;
  final SongRecScope scope;
  final SongRecFamiliarity familiarity;
  /// An: höchstens 2 Songs des erkannten Interpreten. Aus: keiner.
  final bool allowSameArtist;
  /// Anzahl Folgevorschläge, 1–20.
  final int count;

  int get maxSameArtistCount => allowSameArtist ? 2 : 0;

  String get cacheSuffix =>
      '${scope.name}_${familiarity.name}_sa${allowSameArtist ? 1 : 0}_n$count';

  Map<String, dynamic> toUserFields() => <String, dynamic>{
        fieldEnabled: enabled,
        fieldScope: scope.name,
        fieldFamiliarity: familiarity.name,
        fieldSameArtist: allowSameArtist,
        fieldCount: count,
      };

  static SongRecommendationSettings fromUser(UserModel user) {
    return SongRecommendationSettings(
      enabled: user.songRecEnabled,
      scope: parseScope(user.songRecScope),
      familiarity: parseFamiliarity(user.songRecFamiliarity),
      allowSameArtist: user.songRecSameArtist,
      count: clampCount(user.songRecCount),
    );
  }

  static SongRecommendationSettings? fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return null;
    final hasCloud = data.containsKey(fieldEnabled) ||
        data.containsKey(fieldScope) ||
        data.containsKey(fieldFamiliarity) ||
        data.containsKey(fieldSameArtist) ||
        data.containsKey(fieldCount) ||
        // Altes Feld: Tempo-Einstellung wurde entfernt, zählt weiter als „gespeichert“.
        data.containsKey('song_rec_tempo');
    if (!hasCloud) return null;
    return SongRecommendationSettings(
      enabled: data[fieldEnabled] != false,
      scope: parseScope(data[fieldScope] as String?),
      familiarity: parseFamiliarity(data[fieldFamiliarity] as String?),
      allowSameArtist: data[fieldSameArtist] != false,
      count: clampCount(data[fieldCount]),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SongRecommendationSettings &&
        enabled == other.enabled &&
        scope == other.scope &&
        familiarity == other.familiarity &&
        allowSameArtist == other.allowSameArtist &&
        count == other.count;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, scope, familiarity, allowSameArtist, count);

  SongRecommendationSettings copyWith({
    bool? enabled,
    SongRecScope? scope,
    SongRecFamiliarity? familiarity,
    bool? allowSameArtist,
    int? count,
  }) {
    return SongRecommendationSettings(
      enabled: enabled ?? this.enabled,
      scope: scope ?? this.scope,
      familiarity: familiarity ?? this.familiarity,
      allowSameArtist: allowSameArtist ?? this.allowSameArtist,
      count: clampCount(count ?? this.count),
    );
  }

  static int clampCount(Object? raw) {
    final n = raw is int
        ? raw
        : raw is num
            ? raw.round()
            : int.tryParse('$raw');
    if (n == null) return 5;
    if (n < minCount) return minCount;
    if (n > maxCount) return maxCount;
    return n;
  }

  static SongRecScope parseScope(String? raw) {
    return SongRecScope.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SongRecScope.similar,
    );
  }

  static SongRecFamiliarity parseFamiliarity(String? raw) {
    return SongRecFamiliarity.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SongRecFamiliarity.hits,
    );
  }
}

/// DJ-Einstellungen für die Vorschlags-KI — `users/{uid}` wie die anderen Settings.
class SongRecommendationSettingsService {
  SongRecommendationSettingsService._();

  static final SongRecommendationSettingsService instance =
      SongRecommendationSettingsService._();

  final ValueNotifier<SongRecommendationSettings> notifier =
      ValueNotifier<SongRecommendationSettings>(
        SongRecommendationSettings.defaults,
      );

  bool _loaded = false;
  bool _listening = false;
  String? _loadedUid;

  String _uid() => FirebaseAuth.instance.currentUser?.uid ?? 'anon';

  Future<SongRecommendationSettings> ensureLoaded() async {
    _bindUserListener();
    final uidKey = _uid();
    if (_loaded && _loadedUid == uidKey) return notifier.value;
    try {
      SongRecommendationSettings? fromCloud;
      if (uidKey != 'anon') {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uidKey)
            .get();
        fromCloud = SongRecommendationSettings.fromUserDoc(snap.data());
      }
      if (fromCloud != null) {
        notifier.value = fromCloud;
      } else {
        notifier.value = await _fromPrefs(uidKey);
        _loaded = true;
        _loadedUid = uidKey;
        if (uidKey != 'anon') {
          unawaited(save(notifier.value));
        }
        return notifier.value;
      }
    } catch (e) {
      debugLog('SongRecommendationSettingsService.load: $e');
      notifier.value = SongRecommendationSettings.defaults;
    }
    _loaded = true;
    _loadedUid = uidKey;
    return notifier.value;
  }

  Future<void> save(SongRecommendationSettings next) async {
    notifier.value = next;
    final uidKey = _uid();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vb_song_rec_set_${uidKey}_enabled', next.enabled);
      await prefs.setString('vb_song_rec_set_${uidKey}_scope', next.scope.name);
      await prefs.setString(
        'vb_song_rec_set_${uidKey}_familiarity',
        next.familiarity.name,
      );
      await prefs.setBool(
        'vb_song_rec_set_${uidKey}_same_artist',
        next.allowSameArtist,
      );
      await prefs.setInt('vb_song_rec_set_${uidKey}_count', next.count);
    } catch (e) {
      debugLog('SongRecommendationSettingsService.prefs: $e');
    }
    if (uidKey == 'anon') return;
    try {
      await UserSelfSettingsService.instance.write(
        next.toUserFields(),
        userId: uidKey,
      );
    } catch (e) {
      debugLog('SongRecommendationSettingsService.save: $e');
    }
  }

  void _bindUserListener() {
    if (_listening) return;
    _listening = true;
    UserService().currentUser.addListener(_onUserDoc);
  }

  void _onUserDoc() {
    final user = UserService().currentUser.value;
    if (user == null) return;
    if (_uid() != 'anon' && user.id != _uid()) return;
    if (!user.songRecStored) return;
    final next = SongRecommendationSettings.fromUser(user);
    if (next != notifier.value) notifier.value = next;
  }

  Future<SongRecommendationSettings> _fromPrefs(String uidKey) async {
    final prefs = await SharedPreferences.getInstance();
    return SongRecommendationSettings(
      enabled: prefs.getBool('vb_song_rec_set_${uidKey}_enabled') ?? true,
      scope: SongRecommendationSettings.parseScope(
        prefs.getString('vb_song_rec_set_${uidKey}_scope'),
      ),
      familiarity: SongRecommendationSettings.parseFamiliarity(
        prefs.getString('vb_song_rec_set_${uidKey}_familiarity'),
      ),
      allowSameArtist:
          prefs.getBool('vb_song_rec_set_${uidKey}_same_artist') ?? true,
      count: SongRecommendationSettings.clampCount(
        prefs.getInt('vb_song_rec_set_${uidKey}_count'),
      ),
    );
  }
}
