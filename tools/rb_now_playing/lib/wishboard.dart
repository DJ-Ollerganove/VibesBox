import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'tool_gate.dart';
import 'tool_session.dart';
import 'library_match.dart';
import 'tidal_lookup.dart';

class WishItem {
  const WishItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.status,
    required this.isPreWish,
    required this.preWishPublished,
    required this.name,
    required this.greeting,
    required this.greetingTranslation,
    this.greetingTranslationLang = '',
    this.clientId = '',
    this.userId = '',
    this.isFavorite = false,
    required this.createdAtMillis,
  });

  WishItem asPlayed() {
    return WishItem(
      id: id,
      title: title,
      artist: artist,
      status: 'played',
      isPreWish: isPreWish,
      preWishPublished: preWishPublished,
      name: name,
      greeting: greeting,
      greetingTranslation: greetingTranslation,
      greetingTranslationLang: greetingTranslationLang,
      clientId: clientId,
      userId: userId,
      isFavorite: isFavorite,
      createdAtMillis: createdAtMillis,
    );
  }

  final String id;
  final String title;
  final String artist;
  final String status;
  final bool isPreWish;
  final bool preWishPublished;
  final String name;
  final String greeting;
  final String greetingTranslation;
  final String greetingTranslationLang;
  final String clientId;
  final String userId;
  final bool isFavorite;
  final int createdAtMillis;

  bool matchesTab(String tab) {
    if (tab == 'vorab') {
      return status == 'pending' && isPreWish && !preWishPublished;
    }
    if (tab == 'offen') {
      return status == 'pending' && (!isPreWish || preWishPublished);
    }
    if (tab == 'gespielt') return status == 'played';
    if (tab == 'abgelehnt') return status == 'rejected';
    return false;
  }
}

class SetlistItem {
  const SetlistItem({
    required this.index,
    required this.title,
    required this.artist,
    this.bpm,
    this.camelot = '',
    this.reason = '',
  });

  final int index;
  final String title;
  final String artist;
  final double? bpm;
  final String camelot;
  final String reason;
}

class WishRow {
  const WishRow({
    required this.title,
    required this.artist,
    required this.count,
    required this.name,
    required this.greeting,
    required this.createdAtMillis,
    this.items = const [],
    this.inLibrary = false,
    this.playCount = 0,
    this.location,
    this.isTidal = false,
    this.tidalSearching = false,
    this.tidalUrl,
  });

  final String title;
  final String artist;
  final int count;
  final String name;
  final String greeting;
  final int createdAtMillis;
  final List<WishItem> items;
  final bool inLibrary;

  bool get hasGreeting =>
      greeting.trim().isNotEmpty ||
      items.any((item) => item.greeting.trim().isNotEmpty);
  final int playCount;
  final String? location;
  final bool isTidal;
  final bool tidalSearching;
  final String? tidalUrl;

  bool get canDrag => isRekordboxDragPath(location);
}

class Wishboard extends ChangeNotifier {
  Wishboard(this._session);

  static const _pollEvery = Duration(seconds: 8);
  static const _partyCheckEvery = Duration(minutes: 3);
  static const _partyWaitEvery = Duration(seconds: 20);
  static const _heavyEvery = Duration(minutes: 2);

  final ToolSession _session;
  Timer? _timer;
  Timer? _partyTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _wishSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _partyDocSub;
  String? _listenPartyId;
  bool _busy = false;
  String? partyId;
  String? partyName;
  String? error;
  bool loading = false;
  List<WishItem> wishes = const [];
  List<SetlistItem> setlist = const [];
  DateTime? _lastHeavyAt;
  String _fingerprint = '';
  String recFingerprint = '';
  bool recEnabled = true;
  bool sendRecognition = false;
  String recScope = 'similar';
  String recFamiliarity = 'hits';
  bool recAllowSameArtist = true;
  int recCount = 5;
  bool showGreetingTranslations = true;
  bool djAdmin = false;
  int resultsPerPage = 20;
  List<String> openWishOrder = const [];
  List<String> pinnedWishIds = const [];
  List<Map<String, String>> playedTracks = const [];
  int playedStamp = 0;
  String? _playedFor;
  bool _playedLoading = false;
  int _playedTries = 0;
  String? _playedTryParty;
  String? _catalogParty;
  bool? _partyWatchFast;
  bool _recheckParty = false;
  String? _pendingRecFp;
  DateTime? _pendingRecAt;

  bool get hasVorab => wishes.any((w) => w.matchesTab('vorab'));
  bool get hasSetlist => setlist.isNotEmpty;

  List<String> visibleTabs() {
    final tabs = <String>[];
    if (hasSetlist) tabs.add('setlist');
    if (hasVorab) tabs.add('vorab');
    tabs.addAll(const ['offen', 'gespielt', 'abgelehnt']);
    return tabs;
  }

  List<WishRow> rowsFor(
    String tab, {
    LibraryIndex? library,
    TidalLookupStore? tidal,
  }) {
    final filtered = wishes.where((w) => w.matchesTab(tab)).toList();
    final grouped = <String, WishRow>{};
    for (final wish in filtered) {
      final hit = library?.match(wish.title, wish.artist);
      final online = hit == null ? tidal?.hitOf(wish.title, wish.artist) : null;
      final searching = hit == null &&
          (tidal?.isSearching(wish.title, wish.artist) ?? false);
      final title = hit?.title ?? online?.title ?? wish.title;
      final artist = hit?.artist ?? online?.artist ?? wish.artist;
      final key = hit != null
          ? 'lib:${hit.id}'
          : online != null
              ? 'tidal:${online.trackId}'
              : '${title.toLowerCase()}|${artist.toLowerCase()}';
      final prev = grouped[key];
      if (prev == null) {
        grouped[key] = WishRow(
          title: title,
          artist: artist,
          count: 1,
          name: wish.name,
          greeting: wish.greeting,
          createdAtMillis: wish.createdAtMillis,
          items: [wish],
          inLibrary: hit != null,
          playCount: hit?.playCount ?? 0,
          location: hit?.location ?? online?.location,
          isTidal: hit?.isTidal ?? online != null,
          tidalSearching: searching,
          tidalUrl: online?.url,
        );
      } else {
        grouped[key] = WishRow(
          title: prev.title,
          artist: prev.artist,
          count: prev.count + 1,
          name: prev.name.isNotEmpty ? prev.name : wish.name,
          greeting: prev.greeting.isNotEmpty ? prev.greeting : wish.greeting,
          createdAtMillis: wish.createdAtMillis > prev.createdAtMillis
              ? wish.createdAtMillis
              : prev.createdAtMillis,
          items: [...prev.items, wish],
          inLibrary: prev.inLibrary || hit != null,
          playCount: prev.playCount >= (hit?.playCount ?? 0)
              ? prev.playCount
              : hit?.playCount ?? prev.playCount,
          location: prev.location ?? hit?.location ?? online?.location,
          isTidal: prev.isTidal || (hit?.isTidal ?? false) || online != null,
          tidalSearching: prev.tidalSearching || searching,
          tidalUrl: prev.tidalUrl ?? online?.url,
        );
      }
    }
    final rows = grouped.values.toList();
    if (tab != 'offen' || openWishOrder.isEmpty) return rows;
    int rank(WishRow row) {
      final ids = row.items.map((item) => item.id).toSet();
      for (var i = 0; i < openWishOrder.length; i++) {
        final key = openWishOrder[i];
        if (ids.contains(key)) return i;
      }
      return openWishOrder.length + 1;
    }
    rows.sort((a, b) {
      final byOrder = rank(a).compareTo(rank(b));
      if (byOrder != 0) return byOrder;
      return b.createdAtMillis.compareTo(a.createdAtMillis);
    });
    return rows;
  }

  void attach() {
    _session.addListener(_onSession);
    _onSession();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _stopLive();
    super.dispose();
  }

  void _onSession() {
    if (_session.isConnected) {
      _armPartyWatch();
      unawaited(refresh());
    } else {
      _stopLive();
      partyId = null;
      partyName = null;
      wishes = const [];
      setlist = const [];
      _lastHeavyAt = null;
      recEnabled = true;
      sendRecognition = false;
      recScope = 'similar';
      recFamiliarity = 'hits';
      recAllowSameArtist = true;
      recCount = 5;
      showGreetingTranslations = true;
      djAdmin = false;
      playedTracks = const [];
      playedStamp++;
      _playedFor = null;
      _playedTries = 0;
      _playedTryParty = null;
      _catalogParty = null;
      _partyWatchFast = null;
      _recheckParty = false;
      recFingerprint = '';
      _pendingRecFp = null;
      _pendingRecAt = null;
      error = null;
      loading = false;
      _fingerprint = '';
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!_session.isConnected || _busy) return;
    _busy = true;
    if (_fingerprint.isEmpty &&
        wishes.isEmpty &&
        setlist.isEmpty &&
        partyId == null) {
      loading = true;
      notifyListeners();
    }
    try {
      final heavy = _lastHeavyAt == null ||
          partyId == null ||
          DateTime.now().difference(_lastHeavyAt!) >= _heavyEvery;
      final needCatalog = partyId == null || _catalogParty != partyId;
      final os = toolDeviceLabel();
      final install = await ToolInstallReporter.payloadIfDue(os: os);
      final data = await _session.fetchWishboard(
        includeSetlist: needCatalog,
        includePre: needCatalog,
        includeSongRec: heavy || needCatalog,
        partyId: partyId,
        install: install,
      );
      if (install != null) {
        await ToolInstallReporter.markReported(os: os);
      }
      final nextSend = data['syncSend'] == true;
      final sendChanged = nextSend != sendRecognition;
      sendRecognition = nextSend;
      final incoming = _parseWishes(data['wishes']);
      final preOmitted = data['preOmitted'] == true;
      final setlistOmitted = data['setlistOmitted'] == true;
      final nextPartyId = (data['partyId'] ?? '').toString();
      final nextPartyName = (data['partyName'] ?? '').toString();
      final partyChanged = nextPartyId != (partyId ?? '');
      final List<WishItem> nextWishes;
      final List<SetlistItem> nextSetlist;
      if (nextPartyId.isEmpty) {
        nextWishes = const [];
        nextSetlist = const [];
        _lastHeavyAt = null;
        _catalogParty = null;
      } else if (partyChanged && (preOmitted || setlistOmitted)) {
        nextWishes = incoming;
        nextSetlist = const [];
        _lastHeavyAt = null;
        _catalogParty = null;
      } else {
        nextWishes = preOmitted ? _mergeLiveWishes(incoming) : incoming;
        nextSetlist = setlistOmitted ? setlist : _parseSetlist(data['setlist']);
        if (!preOmitted && !setlistOmitted) _catalogParty = nextPartyId;
        if (heavy) _lastHeavyAt = DateTime.now();
      }
      final rec = data.containsKey('songRec')
          ? _parseSongRec(data['songRec'])
          : _SongRec(
              enabled: recEnabled,
              scope: recScope,
              familiarity: recFamiliarity,
              allowSameArtist: recAllowSameArtist,
              count: recCount,
            );
      final showTr = data.containsKey('showGreetingTranslations')
          ? data['showGreetingTranslations'] != false
          : showGreetingTranslations;
      final showChanged = showTr != showGreetingTranslations;
      final nextAdmin =
          data.containsKey('djAdmin') ? data['djAdmin'] == true : djAdmin;
      final adminChanged = nextAdmin != djAdmin;
      final fp = _wishFingerprint(nextPartyId, nextWishes, nextSetlist);
      final recFp = _recFp(
        rec.enabled,
        rec.scope,
        rec.familiarity,
        rec.allowSameArtist,
        rec.count,
      );
      final wasLoading = loading;
      error = null;
      loading = false;
      final wishesChanged = fp != _fingerprint;
      var recChanged = recFp != recFingerprint;
      if (_pendingRecFp != null) {
        final age = DateTime.now().difference(
          _pendingRecAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
        if (recFp == _pendingRecFp || age.inSeconds >= 12) {
          _pendingRecFp = null;
          _pendingRecAt = null;
        } else {
          recChanged = false;
        }
      }
      if (!wishesChanged &&
          !recChanged &&
          !sendChanged &&
          !showChanged &&
          !adminChanged) {
        if (wasLoading) notifyListeners();
        return;
      }
      showGreetingTranslations = showTr;
      djAdmin = nextAdmin;
      _fingerprint = fp;
      if (recChanged) {
        recFingerprint = recFp;
        recEnabled = rec.enabled;
        recScope = rec.scope;
        recFamiliarity = rec.familiarity;
        recAllowSameArtist = rec.allowSameArtist;
        recCount = rec.count;
      }
      if (wishesChanged) {
        partyId = nextPartyId.isEmpty ? null : nextPartyId;
        partyName = nextPartyName.isEmpty ? null : nextPartyName;
        wishes = nextWishes;
        setlist = nextSetlist;
      }
      notifyListeners();
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
      loading = false;
      notifyListeners();
    } finally {
      _busy = false;
      final id = partyId;
      if (_session.isConnected && id != null && id.isNotEmpty) {
        unawaited(_ensureLive(id));
        unawaited(ensurePlayedHistory());
      } else if (id == null || id.isEmpty) {
        _clearPlayed();
      }
      if (_session.isConnected) _armPartyWatch();
      if (_recheckParty && _session.isConnected) {
        _recheckParty = false;
        unawaited(_checkParty());
      }
    }
  }

  void _armPartyWatch() {
    final fast = partyId == null || partyId!.isEmpty;
    if (_partyTimer != null && _partyWatchFast == fast) return;
    final startNow = fast && _partyWatchFast != true;
    _partyWatchFast = fast;
    _partyTimer?.cancel();
    _partyTimer = Timer.periodic(
      fast ? _partyWaitEvery : _partyCheckEvery,
      (_) => unawaited(_checkParty()),
    );
    if (startNow) unawaited(_checkParty());
  }

  Future<void> noteRecognized(String title, String artist) async {
    final id = partyId;
    final song = title.trim();
    if (id == null || id.isEmpty || song.isEmpty || !_session.isConnected) {
      return;
    }
    try {
      final data = await _session.markRecognized(
        partyId: id,
        title: song,
        artist: artist.trim(),
      );
      if (partyId != id) return;
      _applyRecognized(data);
    } catch (_) {}
  }

  void _applyRecognized(Map<String, dynamic> data) {
    final ids = <String>{
      for (final id in (data['wishIds'] as List? ?? const [])) id.toString(),
    };
    final moved = <int>{
      for (final n in (data['movedIndexes'] as List? ?? const []))
        if (n is num) n.toInt(),
    };
    if (ids.isEmpty && moved.isEmpty) return;
    wishes = [
      for (final wish in wishes)
        if (ids.contains(wish.id)) wish.asPlayed() else wish,
    ];
    if (moved.isNotEmpty) {
      setlist = [
        for (final track in setlist)
          if (!moved.contains(track.index)) track,
      ];
    }
    _fingerprint = _wishFingerprint(partyId ?? '', wishes, setlist);
    notifyListeners();
  }

  void _clearPlayed() {
    if (playedTracks.isEmpty && _playedFor == null) return;
    playedTracks = const [];
    _playedFor = null;
    playedStamp++;
    notifyListeners();
  }

  /// Einmal pro Party: bisherige music_history nachladen. Kein Poll.
  Future<void> ensurePlayedHistory() async {
    final id = partyId;
    if (id == null || id.isEmpty || !_session.isConnected) {
      _clearPlayed();
      return;
    }
    if (_playedTryParty != id) {
      _playedTryParty = id;
      _playedTries = 0;
    }
    if (_playedFor == id || _playedLoading || _playedTries >= 2) return;
    _playedLoading = true;
    _playedTries++;
    try {
      final data = await _session.fetchWishboard(
        includeSetlist: false,
        includePre: false,
        includeSongRec: false,
        playedOnly: true,
        partyId: id,
      );
      if (partyId != id) return;
      final raw = data['played'];
      if (raw is! List) return;
      final next = <Map<String, String>>[];
      for (final entry in raw) {
          if (entry is! Map) continue;
          final title = (entry['title'] ?? '').toString().trim();
          final artist = (entry['artist'] ?? '').toString().trim();
          if (title.isEmpty) continue;
          next.add({'title': title, 'artist': artist});
      }
      _playedFor = id;
      playedTracks = next;
      playedStamp++;
      notifyListeners();
    } catch (_) {
    } finally {
      _playedLoading = false;
      final current = partyId;
      if (current != null && current.isNotEmpty && current != id && current != _playedFor) {
        unawaited(ensurePlayedHistory());
      }
    }
  }

  Future<void> _checkParty() async {
    if (!_session.isConnected) return;
    if (_busy) {
      _recheckParty = true;
      return;
    }
    try {
      final data = await _session.fetchWishboard(
        includeSetlist: false,
        includePre: false,
        includeSongRec: false,
        partyOnly: true,
        partyId: partyId,
      );
      final nextPartyId = (data['partyId'] ?? '').toString();
      if (nextPartyId == (partyId ?? '')) {
        final showTr = data['showGreetingTranslations'] != false;
        final nextSend = data['syncSend'] == true;
        final nextAdmin =
            data.containsKey('djAdmin') ? data['djAdmin'] == true : djAdmin;
        if (showTr == showGreetingTranslations &&
            nextSend == sendRecognition &&
            nextAdmin == djAdmin) {
          return;
        }
        showGreetingTranslations = showTr;
        sendRecognition = nextSend;
        djAdmin = nextAdmin;
        notifyListeners();
        return;
      }
      await refresh();
    } catch (_) {}
  }

  Future<void> _ensureLive(String id) async {
    if (_listenPartyId == id && _wishSub != null) return;
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    final owner = _session.ownerUid;
    if (user == null || owner == null || owner.isEmpty) {
      _timer ??= Timer.periodic(_pollEvery, (_) => unawaited(refresh()));
      return;
    }
    _timer?.cancel();
    _timer = null;
    _listenPartyId = id;
    await _partyDocSub?.cancel();
    _partyDocSub = FirebaseFirestore.instance
        .collection('parties')
        .doc(id)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      final raw = data?['open_wish_order'];
      final next = raw is List
          ? raw.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList()
          : <String>[];
      final pinRaw = data?['open_wish_pinned_keys'];
      final pins = pinRaw is List
          ? pinRaw.map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList()
          : <String>[];
      if (next.join('|') == openWishOrder.join('|') &&
          pins.join('|') == pinnedWishIds.join('|')) {
        return;
      }
      openWishOrder = next;
      pinnedWishIds = pins;
      notifyListeners();
    }, onError: (_) {});
    await _wishSub?.cancel();
    _wishSub = FirebaseFirestore.instance
        .collection('parties')
        .doc(id)
        .collection('wishes')
        .orderBy('createdAt', descending: true)
        .limit(400)
        .snapshots()
        .listen(_applyWishSnap, onError: (_) {
      _wishSub?.cancel();
      _wishSub = null;
      _listenPartyId = null;
      _timer ??= Timer.periodic(_pollEvery, (_) => unawaited(refresh()));
    });
    if (_userSub != null) return;
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(owner)
        .snapshots()
        .listen(_applyUserSnap, onError: (_) {});
  }

  void _applyWishSnap(QuerySnapshot<Map<String, dynamic>> snap) {
    final next = <WishItem>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final created = data['createdAt'];
      final millis = created is Timestamp ? created.millisecondsSinceEpoch : 0;
      next.add(WishItem(
        id: doc.id,
        title: '${data['title'] ?? data['song'] ?? ''}'.trim(),
        artist: '${data['artist'] ?? ''}'.trim(),
        status: '${data['status'] ?? 'pending'}',
        isPreWish: data['is_pre_wish'] == true,
        preWishPublished: data['pre_wish_published'] == true,
        name: '${data['name'] ?? data['display_name'] ?? ''}'.trim(),
        greeting: '${data['greeting'] ?? data['gruss'] ?? data['message'] ?? ''}'.trim(),
        greetingTranslation: '${data['greeting_translation'] ?? ''}'.trim(),
        greetingTranslationLang: '${data['greeting_translation_lang'] ?? ''}'.trim(),
        clientId: '${data['client_id'] ?? data['device_id'] ?? ''}'.trim(),
        userId: '${data['user_id'] ?? ''}'.trim(),
        isFavorite: data['is_favorite'] == true,
        createdAtMillis: millis,
      ));
    }
    final liveIds = next.map((w) => w.id).toSet();
    final merged = [
      ...next,
      ...wishes.where((w) => w.id.isNotEmpty && !liveIds.contains(w.id)),
    ];
    final fp = _wishFingerprint(partyId ?? '', merged, setlist);
    if (fp == _fingerprint) return;
    _fingerprint = fp;
    wishes = merged;
    notifyListeners();
  }

  void _applyUserSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return;
    final rec = _parseSongRec({
      'enabled': data['song_rec_enabled'],
      'scope': data['song_rec_scope'],
      'familiarity': data['song_rec_familiarity'],
      'allowSameArtist': data['song_rec_same_artist'],
      'count': data['song_rec_count'],
    });
    final recFp = _recFp(
      rec.enabled,
      rec.scope,
      rec.familiarity,
      rec.allowSameArtist,
      rec.count,
    );
    final nextSend = data['vibesbox_sync_enabled'] == true;
    final nextShow = data['show_greeting_translations'] != false;
    final nextAdmin = data['admin'] == true;
    final pageRaw = data['results_per_page'];
    final nextPage = pageRaw is num
        ? pageRaw.toInt().clamp(5, 100).toInt()
        : resultsPerPage;
    if (recFp == recFingerprint &&
        nextSend == sendRecognition &&
        nextShow == showGreetingTranslations &&
        nextAdmin == djAdmin &&
        nextPage == resultsPerPage) {
      return;
    }
    recFingerprint = recFp;
    recEnabled = rec.enabled;
    recScope = rec.scope;
    recFamiliarity = rec.familiarity;
    recAllowSameArtist = rec.allowSameArtist;
    recCount = rec.count;
    sendRecognition = nextSend;
    showGreetingTranslations = nextShow;
    djAdmin = nextAdmin;
    resultsPerPage = nextPage;
    notifyListeners();
  }

  void _stopLive() {
    _timer?.cancel();
    _timer = null;
    _partyTimer?.cancel();
    _partyTimer = null;
    _wishSub?.cancel();
    _wishSub = null;
    _userSub?.cancel();
    _userSub = null;
    _partyDocSub?.cancel();
    _partyDocSub = null;
    openWishOrder = const [];
    pinnedWishIds = const [];
    _listenPartyId = null;
    _partyWatchFast = null;
  }

  String _wishFingerprint(
    String nextPartyId,
    List<WishItem> nextWishes,
    List<SetlistItem> nextSetlist,
  ) {
    final wishesFp = [
      for (final w in nextWishes)
        '${w.id}:${w.status}:${w.name}:${w.greeting}:${w.greetingTranslation}:${w.isFavorite}',
    ]..sort();
    final setFp = [
      for (final s in nextSetlist) '${s.index}:${s.title}:${s.artist}',
    ]..sort();
    return '$nextPartyId|${wishesFp.join(',')}|${setFp.join(',')}';
  }

  List<WishItem> _mergeLiveWishes(List<WishItem> incoming) {
    final keptPre = wishes.where((w) => w.matchesTab('vorab')).toList();
    if (keptPre.isEmpty) return incoming;
    final liveIds = incoming.map((w) => w.id).toSet();
    return [
      ...incoming,
      ...keptPre.where((w) => !liveIds.contains(w.id)),
    ];
  }

  List<WishItem> _parseWishes(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((item) {
      final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      return WishItem(
        id: '${map['id'] ?? ''}',
        title: '${map['title'] ?? ''}',
        artist: '${map['artist'] ?? ''}',
        status: '${map['status'] ?? 'pending'}',
        isPreWish: map['is_pre_wish'] == true,
        preWishPublished: map['pre_wish_published'] == true,
        name: '${map['name'] ?? ''}',
        greeting: '${map['greeting'] ?? ''}',
        greetingTranslation: '${map['greeting_translation'] ?? ''}',
        greetingTranslationLang: '${map['greeting_translation_lang'] ?? ''}',
        clientId: '${map['client_id'] ?? ''}',
        userId: '${map['user_id'] ?? ''}',
        isFavorite: map['is_favorite'] == true,
        createdAtMillis: (map['createdAtMillis'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  List<SetlistItem> _parseSetlist(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((item) {
      final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      return SetlistItem(
        index: (map['index'] as num?)?.toInt() ?? 0,
        title: '${map['title'] ?? ''}',
        artist: '${map['artist'] ?? ''}',
        bpm: (map['bpm'] as num?)?.toDouble(),
        camelot: '${map['camelot'] ?? ''}',
        reason: '${map['reason'] ?? ''}',
      );
    }).toList();
  }

  void applyLocalSongRec({
    required bool enabled,
    required String scope,
    required String familiarity,
    required bool allowSameArtist,
    required int count,
  }) {
    recEnabled = enabled;
    recScope = scope;
    recFamiliarity = familiarity;
    recAllowSameArtist = allowSameArtist;
    recCount = count;
    recFingerprint = _recFp(enabled, scope, familiarity, allowSameArtist, count);
    _pendingRecFp = recFingerprint;
    _pendingRecAt = DateTime.now();
    notifyListeners();
  }

  static String _recFp(
    bool enabled,
    String scope,
    String familiarity,
    bool allowSameArtist,
    int count,
  ) {
    return '${enabled ? 1 : 0}|$scope|$familiarity|${allowSameArtist ? 1 : 0}|$count';
  }

  _SongRec _parseSongRec(Object? raw) {
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final scope = '${map['scope'] ?? 'similar'}';
    final fam = '${map['familiarity'] ?? 'hits'}';
    final countRaw = map['count'];
    final count = countRaw is int
        ? countRaw
        : countRaw is num
            ? countRaw.round()
            : int.tryParse('$countRaw') ?? 5;
    return _SongRec(
      enabled: map['enabled'] != false,
      scope: const ['strict', 'similar', 'bold'].contains(scope)
          ? scope
          : 'similar',
      familiarity: const ['hits', 'mix'].contains(fam) ? fam : 'hits',
      allowSameArtist: map['allowSameArtist'] != false,
      count: count < 1 ? 1 : (count > 20 ? 20 : count),
    );
  }
}

class _SongRec {
  const _SongRec({
    required this.enabled,
    required this.scope,
    required this.familiarity,
    required this.allowSameArtist,
    required this.count,
  });

  final bool enabled;
  final String scope;
  final String familiarity;
  final bool allowSameArtist;
  final int count;
}
