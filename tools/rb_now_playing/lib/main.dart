import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'camelot.dart';
import 'dj_library_prefs.dart';
import 'dj_library_source.dart';
import 'dj_source_factory.dart';
import 'library_drag.dart';
import 'library_match.dart';
import 'library_store.dart';
import 'song_catalog.dart';
import 'tidal_lookup.dart';
import 'rekordbox_history.dart';
import 'rekordbox_live.dart';
import 'song_rec_settings_page.dart';
import 'tool_chrome.dart';
import 'tool_gate.dart';
import 'tool_gate_pages.dart';
import 'tool_i18n.dart';
import 'tool_session.dart';
import 'wishboard.dart';

Future<void> _copyTitleArtist(
  BuildContext context,
  String title,
  String artist,
) async {
  final t = title.trim();
  final a = artist.trim();
  final text = a.isEmpty ? t : '$t - $a';
  if (text.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(toolI18n.text('copied', {'text': text})),
      duration: const Duration(milliseconds: 900),
    ),
  );
}

class _CopyTitleButton extends StatelessWidget {
  const _CopyTitleButton({required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: toolI18n.text('copyTitle'),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () => unawaited(_copyTitleArtist(context, title, artist)),
      icon: const Icon(Icons.copy, size: 15, color: Colors.white54),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await toolI18n.load();
  final session = ToolSession();
  await session.restore();
  runApp(RbNowPlayingApp(session: session));
}

class RbNowPlayingApp extends StatelessWidget {
  const RbNowPlayingApp({super.key, required this.session});

  final ToolSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: toolI18n,
      builder: (context, _) {
        return MaterialApp(
      title: 'VibesBox Sync',
      debugShowCheckedModeBanner: false,
      locale: Locale(toolI18n.code),
      builder: (context, child) {
        return Directionality(
          textDirection:
              toolIsRtl(toolI18n.code) ? TextDirection.rtl : TextDirection.ltr,
          child: ToolBackdrop(
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF22E7FF),
          secondary: Color(0xFFE040FB),
          surface: Color(0xCC0B1024),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xF00C1228),
        ),
        useMaterial3: true,
      ),
      home: NowPlayingPage(session: session),
        );
      },
    );
  }
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key, required this.session});

  final ToolSession session;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  static const _idleAfter = Duration(minutes: 10);
  static const _cOffen = Color(0xFF2196F3);
  static const _cGespielt = Color(0xFF4CAF50);
  static const _cAbgelehnt = Color(0xFFFF9800);
  static const _cVorab = Color(0xFF7986CB);
  static const _cSetlist = Color(0xFFFFEB3B);

  final _library = LibraryStore();
  final _djPrefs = DjLibraryPrefs();
  final _tidal = TidalLookupStore();
  final _liveReader = LiveReader();
  late final SongCatalogStore _catalog;
  DjLibrarySource? _source;
  late final Wishboard _wishboard;
  Timer? _timer;
  Timer? _libTimer;
  Timer? _libAfterPlay;
  String? _libTrackIdentity;
  String? _markedPlayId;
  HistoryTrack? _transitionFrom;
  LiveSnapshot? _snapshot;
  String? _error;
  String? _seenIdentity;
  DateTime? _seenAt;
  int _mainTab = 1;
  String _wishTab = 'offen';
  String _openWishMarkFp = '';
  int _suggestGen = 0;
  int? _slotGen;
  HistoryTrack? _slotTrack;
  List<Map<String, dynamic>> _slotItems = const [];
  List<Map<String, dynamic>> _slotSkip = const [];
  int _slotWant = 10;
  bool _slotStill = false;
  bool _slotNeedsRefill = false;
  String _playedSig = '';
  bool _showQueued = false;
  int _libraryPaintGen = 0;
  String? _suggestSeed;
  List<Map<String, dynamic>> _suggestions = const [];
  bool _suggesting = false;
  final List<_Heard> _heard = [];
  int _browse = 0;
  String _lastRecFp = '';
  var _tidalReady = false;
  var _djPrefsGen = 0;
  var _gateReady = false;
  var _consentOk = false;
  var _armed = false;
  var _updateDismissed = false;
  SyncToolPolicy _policy = const SyncToolPolicy.empty();

  @override
  void initState() {
    super.initState();
    _wishboard = Wishboard(widget.session);
    _catalog = SongCatalogStore(widget.session);
    _wishboard.attach();
    widget.session.addListener(_onSessionChanged);
    _wishboard.addListener(_onWishboard);
    _library.addListener(_onLibrary);
    _djPrefs.addListener(_onDjPrefs);
    _tidal.addListener(_onTidal);
    unawaited(_bootGate());
  }

  Future<void> _bootGate() async {
    final consent = await ToolConsentStore.load();
    final policy = await SyncToolPolicy.load();
    final dismissed = await UpdateDismissStore.isDismissed(policy.latest);
    if (!mounted) return;
    setState(() {
      _gateReady = true;
      _consentOk = consent;
      _policy = policy;
      _updateDismissed = dismissed;
    });
    _armIfAllowed();
  }

  void _armIfAllowed() {
    if (_armed) return;
    if (!_gateReady || !_consentOk || _policy.blocks) return;
    if (!widget.session.isConnected) return;
    _armed = true;
    unawaited(_startLibrary());
    unawaited(_startTidal());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _startTidal() async {
    await _tidal.load();
    _tidalReady = true;
    _enqueueTidalLookups();
  }

  Future<void> _startLibrary() async {
    await _djPrefs.load();
    await _applyDjPrefs();
    if (_djPrefs.wantsAuto && _source != null) {
      await _library.syncFrom(_source!);
    }
  }

  void _onDjPrefs() {
    unawaited(_applyDjPrefs());
  }

  Future<void> _applyDjPrefs() async {
    final gen = ++_djPrefsGen;
    final software = _djPrefs.software;
    final previousId = _library.softwareId;
    _source?.close();
    _source = software == null
        ? null
        : openDjLibrarySource(software, _djPrefs.resolvedPath(software));
    _liveReader.source = _source;
    _library.allowDeckDrag = software != null;
    deckDragSoftware = software?.id ?? 'rekordbox';
    await _library.bindSoftware(software?.id);
    if (!mounted || gen != _djPrefsGen) return;
    _libTimer?.cancel();
    _libTimer = null;
    if (_djPrefs.wantsAuto && _source != null) {
      _libTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        final src = _source;
        if (src == null) return;
        unawaited(_library.syncFrom(src));
      });
      if (previousId != null && previousId != software?.id) {
        unawaited(_library.syncFrom(_source!));
      }
    }
    if (mounted) setState(() {});
  }

  void _scheduleLibrarySync() {
    if (!_djPrefs.wantsAuto) return;
    _libAfterPlay?.cancel();
    _libAfterPlay = Timer(const Duration(seconds: 3), () {
      final src = _source;
      if (src == null) return;
      unawaited(_library.syncFrom(src));
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _wishboard.removeListener(_onWishboard);
    _library.removeListener(_onLibrary);
    _djPrefs.removeListener(_onDjPrefs);
    _tidal.removeListener(_onTidal);
    _timer?.cancel();
    _libTimer?.cancel();
    _libAfterPlay?.cancel();
    _wishboard.dispose();
    _library.dispose();
    _djPrefs.dispose();
    _tidal.dispose();
    _source?.close();
    super.dispose();
  }

  bool _shouldTreatAsIdle(HistoryTrack? track) {
    if (track == null) return true;
    final now = DateTime.now();
    final identity = track.identity;
    if (identity != _seenIdentity) {
      _seenIdentity = identity;
      _seenAt = now;
    }
    var age = _seenAt == null ? Duration.zero : now.difference(_seenAt!);
    final playedAt = track.playedAt;
    if (playedAt != null) {
      final fromPlayed = now.difference(playedAt);
      if (fromPlayed > age) age = fromPlayed;
    }
    return age >= _idleAfter;
  }

  String _deckKey(LiveSnapshot? snap) {
    if (snap == null || snap.idle) return '';
    final track = snap.nowPlaying;
    if (track == null) return '';
    return '${track.identity}|${track.bpm}|${track.musicalKey}';
  }

  void _refresh() {
    try {
      final snapshot = _liveReader.read();
      final effective =
          _shouldTreatAsIdle(snapshot.history.nowPlaying)
              ? snapshot.asIdle()
              : snapshot;
      final sameDeck = _deckKey(_snapshot) == _deckKey(effective);
      _snapshot = effective;
      if (!mounted) return;
      if (!sameDeck || _error != null) {
        setState(() => _error = null);
      }
      if (_wishboard.sendRecognition) {
        unawaited(widget.session.pushLive(effective));
      } else {
        unawaited(widget.session.pushPresence());
      }
      _captureHeard(effective);
      _kickSuggestions(effective);
      final playing = effective.idle ? null : effective.nowPlaying;
      final playingId = playing?.identity;
      if (playingId != null && playingId != _libTrackIdentity) {
        final previous = _transitionFrom;
        _libTrackIdentity = playingId;
        _transitionFrom = playing;
        _scheduleLibrarySync();
        if (previous != null && playing != null) {
          unawaited(
            _catalog.recordTransition(
              from: previous,
              to: playing,
              softwareId: _djPrefs.software?.id,
            ),
          );
        }
      } else if (effective.idle) {
        _libTrackIdentity = null;
        _transitionFrom = null;
      }
      if (playing != null && playing.title.trim().isNotEmpty) {
        final markId = playing.identity;
        if (markId != _markedPlayId) {
          _markedPlayId = markId;
          unawaited(
            _wishboard.noteRecognized(playing.title, playing.artist),
          );
        }
      }
    } catch (error) {
      _source?.close();
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _onLibrary() {
    if (!mounted) return;
    _enqueueTidalLookups();
    if (_library.importing) {
      setState(() {});
      return;
    }
    if (_suggestions.isEmpty) {
      setState(() {});
      return;
    }
    final now = _shownHit?.track;
    final items = List<Map<String, dynamic>>.from(_suggestions);
    final token = ++_libraryPaintGen;
    unawaited(() async {
      final matched = await _library.applyToSuggestionsAsync(
        items,
        skipTitle: now?.title,
        skipArtist: now?.artist,
      );
      if (!mounted || token != _libraryPaintGen) return;
      final shown = now == null
          ? matched
          : withoutSameAsPlaying(
              matched,
              seedTitle: now.title,
              seedArtist: now.artist,
              keep: _wishboard.recCount.clamp(1, 20),
              alsoSkip: _playedSkip(),
            );
      setState(() => _suggestions = shown);
      if (now == null) return;
      _sendSuggestions(now, shown);
      final want = _wishboard.recCount.clamp(1, 20);
      final live = _heard.isNotEmpty &&
          _heard.last.track.identity == now.identity;
      if (live &&
          shown.length < want &&
          !_suggesting &&
          _wishboard.recEnabled) {
        final gen = ++_suggestGen;
        setState(() => _suggesting = true);
        unawaited(_fetchSuggestions(
          now,
          gen,
          skipShown: shown,
          already: shown,
        ));
      }
    }());
  }

  void _onTidal() {
    if (mounted) setState(() {});
  }

  void _enqueueTidalLookups() {
    if (!_tidalReady) return;
    for (final wish in _wishboard.wishes) {
      if (wish.matchesTab('vorab')) continue;
      if (wish.title.trim().isEmpty) continue;
      if (_library.match(wish.title, wish.artist) != null) continue;
      _tidal.ensure(wish.title, wish.artist);
    }
    for (final item in _suggestions) {
      if (item['inLibrary'] == true) continue;
      final title = (item['title'] ?? '').toString();
      if (title.trim().isEmpty) continue;
      _tidal.ensure(title, (item['artist'] ?? '').toString());
    }
  }

  List<Map<String, dynamic>> _suggestionsForUi() {
    return [
      for (final item in _suggestions)
        _tidal.applyCatalog(item, allowDeckDrag: _library.allowDeckDrag),
    ];
  }

  String _openWishMarkFingerprint() {
    final parts = [
      for (final wish in _wishboard.wishes)
        if (wish.matchesTab('offen')) '${wish.title}|${wish.artist}',
    ]..sort();
    return parts.join('\n');
  }

  bool _suggestionIsOpenWish(String title, String artist) {
    return _openWishRow(title, artist) != null;
  }

  WishRow? _openWishRow(String title, String artist) {
    for (final row in _wishboard.rowsFor(
      'offen',
      library: _library.index,
      tidal: _tidal,
    )) {
      if (isSameWork(
        titleA: row.title,
        artistA: row.artist,
        titleB: title,
        artistB: artist,
      )) {
        return row;
      }
      for (final item in row.items) {
        if (isSameWork(
          titleA: item.title,
          artistA: item.artist,
          titleB: title,
          artistB: artist,
        )) {
          return row;
        }
      }
    }
    return null;
  }

  void _openSuggestionWish(BuildContext context, String title, String artist) {
    final row = _openWishRow(title, artist);
    if (row == null) return;
    _openWishDetail(
      context,
      widget.session,
      _wishboard.partyId ?? '',
      row,
      'offen',
      false,
      false,
      _wishboard.showGreetingTranslations,
      fromSuggestion: true,
      pinnedWishIds: _wishboard.pinnedWishIds,
    );
  }

  void _onWishboard() {
    _enqueueTidalLookups();
    _dropAlreadyPlayed();
    final openFp = _openWishMarkFingerprint();
    if (openFp != _openWishMarkFp) {
      _openWishMarkFp = openFp;
      if (mounted) setState(() {});
    }
    final fp = _wishboard.recFingerprint;
    if (fp == _lastRecFp) return;
    _lastRecFp = fp;
    if (!_wishboard.recEnabled) {
      _suggestGen++;
      _suggestSeed = null;
      final now = _snapshot?.nowPlaying;
      if (_suggestions.isNotEmpty || _suggesting) {
        setState(() {
          _suggestions = const [];
          _suggesting = false;
        });
      }
      if (now != null) _sendSuggestions(now, const []);
      return;
    }
    final snap = _snapshot;
    if (snap != null) _kickSuggestions(snap);
  }

  void _onSessionChanged() {
    _armIfAllowed();
    if (!widget.session.isConnected) return;
    final snap = _snapshot;
    if (snap == null) return;
    if (_suggestSeed != null && _suggestions.isEmpty && !_suggesting) {
      _suggestSeed = null;
      _kickSuggestions(snap);
    }
  }

  void _reloadSuggestions() {
    final hit = _shownHit;
    if (hit == null) return;
    if (_suggesting) return;
    for (final other in _heard) {
      other.searching = identical(other, hit);
    }
    final shown = List<Map<String, dynamic>>.from(hit.suggestions);
    hit.suggestions = const [];
    toolFramePulse.setWorking(true);
    final gen = ++_suggestGen;
    _suggestSeed = 'reload|$gen';
    setState(() {
      _suggestions = const [];
      _suggesting = true;
    });
    unawaited(_fetchSuggestions(
      hit.track,
      gen,
      bypassCache: true,
      excludeExtra: shown,
    ));
  }

  _Heard? get _shownHit => _heard.isEmpty ? null : _heard[_browse];

  bool get _viewingLatest =>
      _heard.isNotEmpty && _browse == _heard.length - 1;

  String _cacheKey(HistoryTrack track) =>
      '${track.title.trim().toLowerCase()}|${track.artist.trim().toLowerCase()}|${_wishboard.recFingerprint}';

  void _captureHeard(LiveSnapshot effective) {
    final playing = effective.idle ? null : effective.nowPlaying;
    if (playing == null) return;
    _appendHeard(playing);
  }

  void _appendHeard(HistoryTrack track) {
    if (_heard.isNotEmpty && _heard.last.track.identity == track.identity) {
      return;
    }
    final key = _cacheKey(track);
    List<Map<String, dynamic>> copied = const [];
    for (var i = _heard.length - 1; i >= 0; i--) {
      final older = _heard[i];
      if (older.cacheKey == key &&
          older.suggestions.isNotEmpty &&
          !older.searching) {
        copied = [
          for (final row in older.suggestions) Map<String, dynamic>.from(row),
        ];
        break;
      }
    }
    final hit = _Heard(track, key);
    hit.suggestions = copied;
    _heard.add(hit);
    _browse = _heard.length - 1;
    if (copied.isNotEmpty) {
      _suggestions = copied;
      _suggesting = false;
      _suggestSeed = key;
      _sendSuggestions(track, copied);
    }
    setState(() {});
    unawaited(_enrichHeard(hit));
  }

  Future<void> _enrichHeard(_Heard hit) async {
    final rows = await _library.applyToSuggestionsAsync([
      {'title': hit.track.title, 'artist': hit.track.artist},
    ]);
    if (!mounted || rows.isEmpty) return;
    final row = rows.first;
    if (row['inLibrary'] != true) return;
    final plays = row['playCount'];
    hit.playCount = plays is int ? plays : 0;
    if (hit.playCount > 0 && identical(_shownHit, hit)) setState(() {});
  }

  void _showLatestHeard() {
    if (_heard.isEmpty) return;
    final last = _heard.length - 1;
    setState(() {
      _browse = last;
      _suggestions = [
        for (final row in _heard[last].suggestions)
          Map<String, dynamic>.from(row),
      ];
    });
    _enqueueTidalLookups();
  }

  void _stepHeard(int delta) {
    if (_heard.isEmpty) return;
    final next = (_browse + delta).clamp(0, _heard.length - 1);
    if (next == _browse) return;
    setState(() {
      _browse = next;
      _suggestions = [
        for (final row in _heard[next].suggestions)
          Map<String, dynamic>.from(row),
      ];
    });
    _enqueueTidalLookups();
  }

  void _rememberHeard(
    HistoryTrack track,
    List<Map<String, dynamic>> items, {
    required bool searching,
  }) {
    final copy = [
      for (final row in items) Map<String, dynamic>.from(row),
    ];
    for (var i = _heard.length - 1; i >= 0; i--) {
      if (_heard[i].track.identity != track.identity) continue;
      _heard[i].suggestions = copy;
      _heard[i].searching = searching;
      break;
    }
  }

  bool _viewingTrack(HistoryTrack track) =>
      _shownHit?.track.identity == track.identity;

  void _sendSuggestions(
    HistoryTrack track,
    List<Map<String, dynamic>> items,
  ) {
    if (!widget.session.isConnected || !_wishboard.sendRecognition) return;
    if (_heard.isNotEmpty && _heard.last.track.identity != track.identity) {
      return;
    }
    unawaited(widget.session.pushSuggestions(
      title: track.title,
      artist: track.artist,
      suggestions: items,
    ));
  }

  void _kickSuggestions(LiveSnapshot snapshot, {bool force = false}) {
    if (!widget.session.isConnected) return;
    if (_wishboard.recFingerprint.isEmpty) return;
    if (!_wishboard.recEnabled) return;
    final now = snapshot.nowPlaying;
    if (now == null || snapshot.idle) return;
    final seed = _cacheKey(now);
    if (!force && seed == _suggestSeed) return;
    if (force && _suggesting) return;
    if (!force &&
        _heard.isNotEmpty &&
        _heard.last.cacheKey == seed &&
        _heard.last.suggestions.isNotEmpty &&
        !_heard.last.searching) {
      _suggestSeed = seed;
      if (_viewingLatest) {
        setState(() {
          _suggestions = [
            for (final row in _heard.last.suggestions)
              Map<String, dynamic>.from(row),
          ];
          _suggesting = false;
        });
      }
      return;
    }
    _suggestSeed = seed;
    final gen = ++_suggestGen;
    final viewing = _viewingLatest;
    for (final hit in _heard) {
      hit.searching = hit.track.identity == now.identity;
    }
    final skip = force
        ? List<Map<String, dynamic>>.from(_suggestions)
        : const <Map<String, dynamic>>[];
    toolFramePulse.setWorking(true);
    setState(() {
      if (viewing && !force) _suggestions = const [];
      _suggesting = true;
    });
    unawaited(_fetchSuggestions(now, gen, skipShown: skip));
  }

  /// Titel, die in den letzten 12 Stunden in der DJ-History standen.
  List<Map<String, String>> _recentHistorySkip() {
    final history = _snapshot?.history;
    if (history == null) return const [];
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    final out = <Map<String, String>>[];
    final seen = <String>{};
    void add(HistoryTrack track) {
      final at = track.playedAt;
      if (at == null || at.isBefore(cutoff)) return;
      final title = track.title.trim();
      final artist = track.artist.trim();
      if (title.isEmpty || artist.isEmpty) return;
      if (!seen.add('${title.toLowerCase()}|${artist.toLowerCase()}')) return;
      if (out.length >= 80) return;
      out.add({'title': title, 'artist': artist});
    }

    for (final track in history.recent) {
      add(track);
    }
    for (final track in history.tracks) {
      add(track);
    }
    return out;
  }

  List<Map<String, dynamic>> _playedSkip([
    List<Map<String, dynamic>> extra = const [],
  ]) {
    final out = <Map<String, dynamic>>[...extra, ..._recentHistorySkip()];
    for (final row in _wishboard.playedTracks) {
      out.add(row);
    }
    for (final wish in _wishboard.wishes) {
      if (wish.status != 'played' || wish.title.trim().isEmpty) continue;
      out.add({'title': wish.title, 'artist': wish.artist});
    }
    for (final hit in _heard) {
      out.add({'title': hit.track.title, 'artist': hit.track.artist});
    }
    return out;
  }

  void _dropAlreadyPlayed() {
    var wishPlayed = 0;
    for (final wish in _wishboard.wishes) {
      if (wish.status == 'played') wishPlayed++;
    }
    final sig = '${_wishboard.playedStamp}|$wishPlayed';
    if (sig == _playedSig) return;
    _playedSig = sig;
    if (_suggestions.isEmpty) return;
    final now = _shownHit?.track;
    if (now == null) return;
    final want = _wishboard.recCount.clamp(1, 20);
    final next = withoutSameAsPlaying(
      _suggestions,
      seedTitle: now.title,
      seedArtist: now.artist,
      keep: want,
      alsoSkip: _playedSkip(),
    );
    if (next.length == _suggestions.length) return;
    _rememberHeard(now, next, searching: _suggesting);
    if (mounted) setState(() => _suggestions = next);
    _sendSuggestions(now, next);
    if (_suggesting || !_wishboard.recEnabled || next.length >= want) return;
    final gen = ++_suggestGen;
    setState(() => _suggesting = true);
    unawaited(_fetchSuggestions(now, gen, skipShown: next, already: next));
  }

  List<Map<String, String>> _excludeFor(
    HistoryTrack track,
    List<Map<String, dynamic>> shown,
  ) {
    final out = <Map<String, String>>[
      {'title': track.title, 'artist': track.artist},
    ];
    final seen = <String>{
      '${track.title}|${track.artist}'.trim().toLowerCase(),
    };
    void add(String title, String artist) {
      final t = title.trim();
      final a = artist.trim();
      if (t.isEmpty || a.isEmpty || out.length >= 80) return;
      if (!seen.add('$t|$a'.toLowerCase())) return;
      out.add({'title': t, 'artist': a});
    }

    for (final row in _recentHistorySkip()) {
      add(row['title'] ?? '', row['artist'] ?? '');
    }
    // Gezeigte Titel zuerst, sonst füllt die Party-History die Plätze
    // und die Auffüllrunde bekommt dieselben Songs noch einmal.
    for (final item in shown) {
      add((item['title'] ?? '').toString(), (item['artist'] ?? '').toString());
    }
    for (final hit in _heard) {
      if (hit.track.identity == track.identity) continue;
      add(hit.track.title, hit.track.artist);
    }
    for (final row in _wishboard.playedTracks) {
      add(row['title'] ?? '', row['artist'] ?? '');
    }
    return out;
  }

  void _showFoundSoFar(
    HistoryTrack track,
    int gen,
    List<Map<String, dynamic>> acc,
    int want, {
    List<Map<String, dynamic>> skipShown = const [],
    required bool stillSearching,
    bool allowRefill = true,
  }) {
    if (!mounted || gen != _suggestGen) return;
    final playedSkip = _playedSkip(skipShown);
    final quick = withoutSameAsPlaying(
      acc,
      seedTitle: track.title,
      seedArtist: track.artist,
      keep: want,
      alsoSkip: playedSkip,
    );
    final needsRefill = allowRefill && !stillSearching && quick.length < want;
    if (quick.isEmpty && stillSearching) return;
    _slotGen = gen;
    _slotTrack = track;
    _slotItems = List<Map<String, dynamic>>.from(quick);
    _slotSkip = skipShown;
    _slotWant = want;
    _slotStill = stillSearching;
    _slotNeedsRefill = needsRefill;
    if (_showQueued) return;
    _showQueued = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _showQueued = false;
      final slotGen = _slotGen;
      final slotTrack = _slotTrack;
      if (slotGen == null ||
          slotTrack == null ||
          !mounted ||
          slotGen != _suggestGen) {
        return;
      }
      final items = List<Map<String, dynamic>>.from(_slotItems);
      final still = _slotStill;
      final skip = _slotSkip;
      final slotWant = _slotWant;
      final needsRefill = _slotNeedsRefill;
      _rememberHeard(slotTrack, items, searching: still);
      final viewing = _viewingTrack(slotTrack);
      setState(() {
        _suggesting = still;
        if (viewing) _suggestions = items;
      });
      if (items.isNotEmpty || !still) _sendSuggestions(slotTrack, items);
      if (!still &&
          needsRefill &&
          items.length < slotWant &&
          _wishboard.recEnabled) {
        final gen = ++_suggestGen;
        setState(() => _suggesting = true);
        unawaited(_fetchSuggestions(
          slotTrack,
          gen,
          skipShown: items,
          already: items,
        ));
        return;
      }
      if (items.isEmpty || !viewing) return;
      _enqueueTidalLookups();
      final token = ++_libraryPaintGen;
      unawaited(_fillLibraryMatch(
        slotTrack,
        slotGen,
        items,
        skip,
        slotWant,
        token,
      ));
    });
  }

  Future<void> _fillLibraryMatch(
    HistoryTrack track,
    int gen,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> skip,
    int want,
    int token,
  ) async {
    final matched = await _library.applyToSuggestionsAsync(
      items,
      skipTitle: track.title,
      skipArtist: track.artist,
    );
    if (!mounted || token != _libraryPaintGen || gen != _suggestGen) return;
    final ready = withoutSameAsPlaying(
      matched,
      seedTitle: track.title,
      seedArtist: track.artist,
      keep: want,
      alsoSkip: _playedSkip(skip),
    );
    _rememberHeard(track, ready, searching: _suggesting);
    if (_viewingTrack(track)) {
      setState(() => _suggestions = [
            for (final row in ready) Map<String, dynamic>.from(row),
          ]);
    }
    _sendSuggestions(track, ready);
  }

  Future<void> _fetchSuggestions(
    HistoryTrack track,
    int gen, {
    List<Map<String, dynamic>> skipShown = const [],
    List<Map<String, dynamic>> already = const [],
    List<Map<String, dynamic>> excludeExtra = const [],
    bool bypassCache = false,
  }) async {
    final keepPrevious = !bypassCache &&
        (skipShown.isNotEmpty || already.isNotEmpty);
    final want = _wishboard.recCount.clamp(1, 20);
    try {
      final acc = <Map<String, dynamic>>[...already];
      final skip = <Map<String, dynamic>>[];
      final seenSkip = <String>{};
      for (final row in [...skipShown, ...already, ...excludeExtra]) {
        final key =
            '${row['title'] ?? ''}|${row['artist'] ?? ''}'.trim().toLowerCase();
        if (key.isEmpty || !seenSkip.add(key)) continue;
        skip.add(row);
      }
      if (!keepPrevious) {
        final cached = bypassCache
            ? null
            : await _catalog.readSuggestions(
          track,
          scope: _wishboard.recScope,
          familiarity: _wishboard.recFamiliarity,
          allowSameArtist: _wishboard.recAllowSameArtist,
        );
        if (!mounted || gen != _suggestGen) return;
        List<Map<String, dynamic>> pool;
        if (cached != null && cached.length >= want) {
          pool = await _catalog.withTransitions(
            cached,
            track,
            scope: _wishboard.recScope,
            allowSameArtist: _wishboard.recAllowSameArtist,
          );
        } else {
          final raw = <Map<String, dynamic>>[];
          final seen = <String>{};
          void take(Map<String, dynamic> row) {
            if (!mounted || gen != _suggestGen) return;
            final key =
                '${row['title'] ?? ''}|${row['artist'] ?? ''}'.trim().toLowerCase();
            if (key.isEmpty || !seen.add(key)) return;
            raw.add(row);
            _showFoundSoFar(
              track,
              gen,
              raw,
              want,
              skipShown: skip,
              stillSearching: true,
            );
          }

          await widget.session.recommendLive(
            title: track.title,
            artist: track.artist,
            bpm: track.bpm,
            camelot: camelotFromScaleName(track.musicalKey),
            scope: _wishboard.recScope,
            familiarity: _wishboard.recFamiliarity,
            allowSameArtist: _wishboard.recAllowSameArtist,
            count: want,
            exclude: _excludeFor(track, excludeExtra),
            fresh: bypassCache,
            onTrack: take,
          );
          if (!mounted || gen != _suggestGen) return;
          if (raw.length >= want) {
            unawaited(_catalog.writeSuggestions(
              track,
              raw,
              scope: _wishboard.recScope,
              familiarity: _wishboard.recFamiliarity,
              allowSameArtist: _wishboard.recAllowSameArtist,
            ));
          }
          pool = await _catalog.withTransitions(
            raw,
            track,
            scope: _wishboard.recScope,
            allowSameArtist: _wishboard.recAllowSameArtist,
          );
        }
        if (!mounted || gen != _suggestGen) return;
        acc
          ..clear()
          ..addAll(pool);
      } else {
        final raw = <Map<String, dynamic>>[];
        final seen = <String>{};
        final gap = (want - already.length).clamp(1, want);
        // Bereits gezeigte Titel bleiben. skip blendet sie nur aus, wenn
        // keine Keep-Liste da ist (erneute Suche).
        final hide = already.isEmpty ? skip : const <Map<String, dynamic>>[];
        await widget.session.recommendLive(
          title: track.title,
          artist: track.artist,
          bpm: track.bpm,
          camelot: camelotFromScaleName(track.musicalKey),
          scope: _wishboard.recScope,
          familiarity: _wishboard.recFamiliarity,
          allowSameArtist: _wishboard.recAllowSameArtist,
          count: gap,
          exclude: _excludeFor(track, skip),
          onTrack: (row) {
            if (!mounted || gen != _suggestGen) return;
            final key =
                '${row['title'] ?? ''}|${row['artist'] ?? ''}'.trim().toLowerCase();
            if (key.isEmpty || !seen.add(key)) return;
            raw.add(row);
            _showFoundSoFar(
              track,
              gen,
              [...already, ...raw],
              want,
              skipShown: hide,
              stillSearching: true,
              allowRefill: false,
            );
          },
        );
        if (!mounted || gen != _suggestGen) return;
        acc
          ..clear()
          ..addAll(already)
          ..addAll(raw);
      }
      if (acc.isEmpty) {
        if (mounted && gen == _suggestGen) {
          _rememberHeard(
            track,
            keepPrevious ? _itemsOf(track) : const [],
            searching: false,
          );
          final viewing = _viewingTrack(track);
          setState(() {
            _suggesting = false;
            if (viewing && !keepPrevious) _suggestions = const [];
          });
        }
        return;
      }
      _showFoundSoFar(
        track,
        gen,
        acc,
        want,
        skipShown: keepPrevious && already.isNotEmpty
            ? const []
            : skip,
        stillSearching: false,
        allowRefill: !keepPrevious,
      );
    } catch (_) {
      if (!mounted || gen != _suggestGen) return;
      _rememberHeard(track, _itemsOf(track), searching: false);
      setState(() => _suggesting = false);
    }
  }

  List<Map<String, dynamic>> _itemsOf(HistoryTrack track) {
    for (var i = _heard.length - 1; i >= 0; i--) {
      if (_heard[i].track.identity == track.identity) {
        return _heard[i].suggestions;
      }
    }
    return _viewingTrack(track) ? _suggestions : const [];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.session, _wishboard, _library, _tidal]),
      builder: (context, _) {
        final searching = _suggesting || _library.importing;
        if (toolFramePulse.working != searching) {
          final next = searching;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            toolFramePulse.setWorking(next);
          });
        }
        if (!_gateReady) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!_consentOk) {
          return ToolWelcomePage(
            onAccepted: () async {
              await ToolConsentStore.accept();
              if (!mounted) return;
              setState(() => _consentOk = true);
              _armIfAllowed();
            },
          );
        }
        if (_policy.blocks) {
          return ToolUpdatePage(policy: _policy);
        }
        if (!widget.session.isConnected) {
          return ToolConnectPage(session: widget.session);
        }
        final tabs = _wishboard.visibleTabs();
        final wishTab = tabs.contains(_wishTab)
            ? _wishTab
            : (tabs.contains('offen') ? 'offen' : tabs.first);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_policy.optional && !_updateDismissed)
                    ToolOptionalUpdateBar(
                      policy: _policy,
                      onLater: () {
                        unawaited(UpdateDismissStore.dismiss(_policy.latest));
                        setState(() => _updateDismissed = true);
                      },
                    ),
                  Row(
                    children: [
                      const Text(
                        'VibesBox Sync',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF22E7FF),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: toolI18n.text(
                          widget.session.isConnected ? 'connected' : 'connectTip',
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openConnection(context),
                        icon: Icon(
                          widget.session.isConnected
                              ? Icons.link
                              : Icons.link_off,
                          size: 20,
                          color: widget.session.isConnected
                              ? const Color(0xFF22E7FF)
                              : Colors.white54,
                        ),
                      ),
                      IconButton(
                        tooltip: toolI18n.text('settings'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openSettings(context),
                        icon: const Icon(Icons.settings, size: 20),
                      ),
                      IconButton(
                        tooltip: toolI18n.text('language'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openLanguage(context),
                        icon: const Icon(Icons.public, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_error != null)
                    _ErrorCard(message: _error!)
                  else
                    _NowPlayingCard(
                      hit: _shownHit,
                      canPrev: _browse > 0,
                      canNext: _browse < _heard.length - 1,
                      onPrev: () => _stepHeard(-1),
                      onNext: () => _stepHeard(1),
                    ),
                  const SizedBox(height: 6),
                  _MainTabs(
                    index: _mainTab,
                    onChanged: (i) {
                      setState(() => _mainTab = i);
                      if (i == 1) _showLatestHeard();
                    },
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _mainTab == 1
                        ? _SuggestionsPane(
                            loading: (_shownHit?.searching ?? false) ||
                                (widget.session.isConnected &&
                                    _wishboard.recFingerprint.isEmpty &&
                                    _wishboard.recEnabled),
                            enabled: _wishboard.recEnabled,
                            isOpenWish: _suggestionIsOpenWish,
                            onOpenWish: _openSuggestionWish,
                            items: _suggestionsForUi(),
                            idle: _heard.isEmpty,
                            onReload: (widget.session.isConnected &&
                                    _shownHit != null &&
                                    _wishboard.recEnabled)
                                ? _reloadSuggestions
                                : null,
                          )
                        : _VibesBoxPane(
                            session: widget.session,
                            wishboard: _wishboard,
                            library: _library,
                            tidal: _tidal,
                            connected: widget.session.isConnected,
                            tab: wishTab,
                            onTab: (tab) => setState(() => _wishTab = tab),
                            tabColor: _tabColor,
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.session.isConnected
                        ? ([
                            if (widget.session.ownerLabel != null)
                              toolI18n.text(
                                'connectedAs',
                                {'name': widget.session.ownerLabel!},
                              ),
                            _wishboard.partyName == null
                                ? toolI18n.text('connectedNoParty')
                                : toolI18n.text(
                                    'connectedParty',
                                    {'name': _wishboard.partyName!},
                                  ),
                          ].join('\n'))
                        : toolI18n.text('localHint'),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _tabColor(String tab) {
    switch (tab) {
      case 'setlist':
        return _cSetlist;
      case 'vorab':
        return _cVorab;
      case 'offen':
        return _cOffen;
      case 'gespielt':
        return _cGespielt;
      case 'abgelehnt':
        return _cAbgelehnt;
      default:
        return Colors.white70;
    }
  }

  Future<void> _openLanguage(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xF00C1228),
          title: Text(toolI18n.text('language')),
          content: SizedBox(
            width: 280,
            height: 360,
            child: ListView(
              children: [
                for (final lang in toolLanguages)
                  ListTile(
                    dense: true,
                    leading: Text(lang.flag, style: const TextStyle(fontSize: 18)),
                    title: Text(lang.name),
                    trailing: lang.code == toolI18n.code
                        ? const Icon(Icons.check, color: Color(0xFFFF8800), size: 18)
                        : null,
                    onTap: () async {
                      await toolI18n.setCode(lang.code);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(toolI18n.text('close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openConnection(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ConnectionDialog(session: widget.session),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
                        builder: (_) => SongRecSettingsPage(
          session: widget.session,
          wishboard: _wishboard,
          library: _library,
          djPrefs: _djPrefs,
        ),
      ),
    );
  }

}

class _MainTabs extends StatelessWidget {
  const _MainTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A36))),
      ),
      child: Row(
        children: [
          _mainTabBtn('VibesBox', 0),
          _mainTabBtn(toolI18n.text('suggestions'), 1),
        ],
      ),
    );
  }

  Widget _mainTabBtn(String label, int i) {
    final active = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? const Color(0xFF22E7FF) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              letterSpacing: 1.4,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

class _VibesBoxPane extends StatelessWidget {
  const _VibesBoxPane({
    required this.session,
    required this.wishboard,
    required this.library,
    required this.tidal,
    required this.connected,
    required this.tab,
    required this.onTab,
    required this.tabColor,
  });

  final ToolSession session;
  final Wishboard wishboard;
  final LibraryStore library;
  final TidalLookupStore tidal;
  final bool connected;
  final String tab;
  final ValueChanged<String> onTab;
  final Color Function(String tab) tabColor;

  String _tabLabel(String tab) {
    switch (tab) {
      case 'setlist':
        return toolI18n.text('tabSetlist');
      case 'vorab':
        return toolI18n.text('tabPre');
      case 'offen':
        return toolI18n.text('tabOpen');
      case 'gespielt':
        return toolI18n.text('tabPlayed');
      case 'abgelehnt':
        return toolI18n.text('tabRejected');
      default:
        return tab;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!connected) {
      return Center(
        child: Text(
          toolI18n.text('connectWishes'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    if (wishboard.loading && wishboard.wishes.isEmpty && wishboard.setlist.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (wishboard.partyId == null) {
      return Center(
        child: Text(
          wishboard.error ?? toolI18n.text('noParty'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    final tabs = wishboard.visibleTabs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final id in tabs)
                _SubTab(
                  label: _tabLabel(id),
                  active: tab == id,
                  color: tabColor(id),
                  onTap: () => onTab(id),
                ),
            ],
          ),
        ),
        if (wishboard.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              wishboard.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: tab == 'setlist'
              ? _SetlistView(tracks: wishboard.setlist)
              : _WishListView(
                  session: session,
                  partyId: wishboard.partyId ?? '',
                  perPage: wishboard.resultsPerPage,
                  rows: wishboard.rowsFor(
                    tab,
                    library: library.index,
                    tidal: tidal,
                  ),
                  tab: tab,
                  dragEnabled: library.allowDeckDrag,
                  showTranslation: wishboard.showGreetingTranslations,
                  pinnedWishIds: wishboard.pinnedWishIds,
                ),
        ),
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  const _SubTab({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? color : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? color : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

class _WishListView extends StatefulWidget {
  const _WishListView({
    required this.session,
    required this.partyId,
    required this.perPage,
    required this.rows,
    required this.tab,
    required this.dragEnabled,
    required this.showTranslation,
    this.pinnedWishIds = const [],
  });

  final ToolSession session;
  final String partyId;
  final int perPage;
  final List<WishRow> rows;
  final String tab;
  final bool dragEnabled;
  final bool showTranslation;
  final List<String> pinnedWishIds;

  @override
  State<_WishListView> createState() => _WishListViewState();
}

class _WishListViewState extends State<_WishListView> {
  int _page = 1;
  String _tab = '';

  @override
  Widget build(BuildContext context) {
    if (_tab != widget.tab) {
      _tab = widget.tab;
      _page = 1;
    }
    final rows = widget.rows;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          widget.tab == 'offen'
              ? toolI18n.text('noOpen')
              : widget.tab == 'gespielt'
                  ? toolI18n.text('nothingPlayed')
                  : widget.tab == 'abgelehnt'
                      ? toolI18n.text('noRejected')
                      : toolI18n.text('noPre'),
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    final perPage = widget.perPage < 5 ? 20 : widget.perPage;
    final pages = (rows.length / perPage).ceil();
    if (_page > pages) _page = pages;
    final start = (_page - 1) * perPage;
    final slice = rows.skip(start).take(perPage).toList();
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: slice.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final row = slice[index];
              final global = start + index;
              return LibraryMatchChrome(
                key: ValueKey(
                  '${row.items.map((item) => item.id).join(',')}|${row.location ?? ''}',
                ),
                matched: row.inLibrary,
                filePath: row.location,
                title: row.title,
                artist: row.artist,
                isTidal: row.isTidal,
                dragEnabled: widget.dragEnabled,
                child: _WishCard(
                  session: widget.session,
                  partyId: widget.partyId,
                  row: row,
                  tab: widget.tab,
                  canUp: widget.tab == 'offen' && global > 0,
                  canDown: widget.tab == 'offen' && global < rows.length - 1,
                  showTranslation: widget.showTranslation,
                  pinnedWishIds: widget.pinnedWishIds,
                ),
              );
            },
          ),
        ),
        if (pages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _page > 1 ? () => setState(() => _page -= 1) : null,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: toolI18n.text('actUp'),
                ),
                Text(
                  '$_page / $pages',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                IconButton(
                  onPressed: _page < pages ? () => setState(() => _page += 1) : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: toolI18n.text('actDown'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard({
    required this.session,
    required this.partyId,
    required this.row,
    required this.tab,
    required this.canUp,
    required this.canDown,
    required this.showTranslation,
    this.pinnedWishIds = const [],
  });

  final ToolSession session;
  final String partyId;
  final WishRow row;
  final String tab;
  final bool canUp;
  final bool canDown;
  final bool showTranslation;
  final List<String> pinnedWishIds;

  @override
  Widget build(BuildContext context) {
    final title = row.title.isEmpty ? toolI18n.text('noTitle') : row.title;
    return Material(
      color: const Color(0x66101830),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openWishDetail(
          context,
          session,
          partyId,
          row,
          tab,
          canUp,
          canDown,
          showTranslation,
          pinnedWishIds: pinnedWishIds,
        ),
        child: SizedBox(
          height: 64,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _CopyTitleButton(title: row.title, artist: row.artist),
                LibrarySourceIcon(
                  visible: row.inLibrary || row.tidalUrl != null,
                  isTidal: row.isTidal || row.tidalUrl != null,
                  searching: row.tidalSearching &&
                      !row.inLibrary &&
                      row.tidalUrl == null,
                  onOpen: row.tidalUrl == null
                      ? null
                      : () => unawaited(openExternalUrl(row.tidalUrl!)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (row.artist.isNotEmpty)
                        Text(
                          row.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (row.hasGreeting)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: Colors.blue,
                    ),
                  ),
                _WishTrailing(row: row),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _openWishDetail(
  BuildContext context,
  ToolSession session,
  String partyId,
  WishRow row,
  String tab,
  bool canUp,
  bool canDown,
  bool showTranslation, {
  bool fromSuggestion = false,
  List<String> pinnedWishIds = const [],
}) {
  final items = row.items.isEmpty
      ? [
          WishItem(
            id: '',
            title: row.title,
            artist: row.artist,
            status: '',
            isPreWish: false,
            preWishPublished: false,
            name: row.name,
            greeting: row.greeting,
            greetingTranslation: '',
            createdAtMillis: row.createdAtMillis,
          ),
        ]
      : row.items;
  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ToolFrameShell(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
            decoration: BoxDecoration(
              color: const Color(0xFF000B27),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD7B4FF), width: 2.4),
            ),
            child: _WishDetailBody(
                session: session,
                partyId: partyId,
                row: row,
                items: items,
                tab: tab,
                canUp: canUp,
                canDown: canDown,
                showTranslation: showTranslation,
                fromSuggestion: fromSuggestion,
                isFavorite: items.any((item) => item.isFavorite),
                isPinned: items.any((item) => pinnedWishIds.contains(item.id)),
              ),
            ),
          ),
      );
    },
  );
}

class _WishDetailBody extends StatefulWidget {
  const _WishDetailBody({
    required this.session,
    required this.partyId,
    required this.row,
    required this.items,
    required this.tab,
    required this.canUp,
    required this.canDown,
    required this.showTranslation,
    this.fromSuggestion = false,
    this.isFavorite = false,
    this.isPinned = false,
  });

  final ToolSession session;
  final String partyId;
  final WishRow row;
  final List<WishItem> items;
  final String tab;
  final bool canUp;
  final bool canDown;
  final bool showTranslation;
  final bool fromSuggestion;
  final bool isFavorite;
  final bool isPinned;

  @override
  State<_WishDetailBody> createState() => _WishDetailBodyState();
}

class _WishDetailBodyState extends State<_WishDetailBody> {
  final Map<String, String> _translated = {};
  final Set<String> _loading = {};
  bool _busy = false;
  late bool _favorite;
  late bool _pinned;
  bool _saved = false;
  bool _listed = false;

  @override
  void initState() {
    super.initState();
    _favorite = widget.isFavorite;
    _pinned = widget.isPinned;
    unawaited(_loadMarks());
    if (widget.showTranslation) {
      for (final item in widget.items) {
        final greeting = item.greeting.trim();
        if (greeting.isEmpty) continue;
        final stored = _storedTranslation(item);
        if (stored != null) {
          _translated[greeting] = stored;
          continue;
        }
        _loading.add(greeting);
        unawaited(_load(greeting));
      }
    }
  }

  String? _storedTranslation(WishItem item) {
    final stored = item.greetingTranslation.trim();
    final greeting = item.greeting.trim();
    if (stored.isEmpty || stored == greeting) return null;
    final lang = item.greetingTranslationLang.trim();
    if (lang.isNotEmpty && lang != toolI18n.code) return null;
    return stored;
  }

  Future<void> _load(String greeting) async {
    String? text;
    try {
      text = await widget.session.translateGreeting(greeting);
    } catch (_) {
      text = null;
    }
    if (!mounted) return;
    setState(() {
      _loading.remove(greeting);
      if (text != null && text.isNotEmpty && text != greeting) {
        _translated[greeting] = text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.fromSuggestion)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: Text(
                toolI18n.text('openWishNote'),
                style: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _act(Icons.check_circle, toolI18n.text('actPlay'), true, () => _run('play', toolI18n.text('actPlay')), color: const Color(0xFF4CAF50)),
                  _act(Icons.cancel, toolI18n.text('actReject'), true, () => _run('reject', toolI18n.text('actReject')), color: const Color(0xFFFF9800)),
                  _act(Icons.delete_forever, toolI18n.text('actDelete'), true, () => _run('delete', toolI18n.text('actDelete')), color: const Color(0xFFF44336)),
                  _act(
                    Icons.block,
                    toolI18n.text('actBlock'),
                    true,
                    () => _run('block', toolI18n.text('actBlock')),
                    color: const Color(0xFFF44336),
                  ),
                ],
              ),
            ),
          ),
          Text(
            row.title.isEmpty ? toolI18n.text('noTitle') : row.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (row.artist.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(row.artist, style: const TextStyle(color: Colors.white70)),
            ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in widget.items) ...[
                    const Divider(color: Color(0xFF22222C)),
                    if (item.name.isNotEmpty)
                      Text('${toolI18n.text('wishGuest')}: ${item.name}'),
                    if (item.greeting.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(toolI18n.text('wishGreeting')),
                      Text(item.greeting),
                      if (widget.showTranslation) _translationLine(item.greeting.trim()),
                    ],
                    if (item.createdAtMillis > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _wishWhen(item.createdAtMillis),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Row(
            children: [
              _act(
                _favorite ? Icons.favorite : Icons.favorite_border,
                _favorite ? toolI18n.text('actFavOff') : toolI18n.text('actFav'),
                true,
                () => _toggle('favorite'),
                color: _favorite ? const Color(0xFFF44336) : Colors.white70,
              ),
              _act(
                Icons.anchor,
                _pinned ? toolI18n.text('actPinOff') : toolI18n.text('actPin'),
                true,
                () => _toggle('pin'),
                color: _pinned ? const Color(0xFFFF9800) : Colors.white70,
              ),
              _act(
                _saved ? Icons.bookmark : Icons.bookmark_border,
                _saved ? toolI18n.text('actUnsaved') : toolI18n.text('actSave'),
                true,
                () => _toggle('save'),
                color: _saved ? const Color(0xFFFF9800) : Colors.white70,
              ),
              _act(
                Icons.playlist_remove,
                _listed ? toolI18n.text('actUnlisted') : toolI18n.text('actBlacklist'),
                true,
                () => _toggle('blacklist'),
                color: _listed ? const Color(0xFF546E7A) : const Color(0xFFCFD8DC),
              ),
              const Spacer(),
              IconButton(
                tooltip: toolI18n.text('close'),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Color(0xFFF44336), size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _act(
    IconData icon,
    String tip,
    bool enabled,
    VoidCallback onTap, {
    Color color = Colors.white70,
  }) {
    return IconButton(
      tooltip: tip,
      onPressed: enabled && !_busy ? onTap : null,
      icon: Icon(icon, size: 22, color: enabled ? color : Colors.white24),
      visualDensity: VisualDensity.compact,
    );
  }

  void _toast(String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xF01A1030),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD7B4FF), width: 1.6),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (entry.mounted) entry.remove();
    });
  }

  (String, String) _song() {
    for (final item in widget.items) {
      if (item.title.trim().isNotEmpty || item.artist.trim().isNotEmpty) {
        return (item.title, item.artist);
      }
    }
    return (widget.row.title, widget.row.artist);
  }

  Future<void> _loadMarks() async {
    if (widget.partyId.isEmpty) return;
    final song = _song();
    try {
      final result = await widget.session.wishAction(
        partyId: widget.partyId,
        action: 'marks',
        wishIds: widget.items.map((item) => item.id).where((id) => id.isNotEmpty).toList(),
        title: song.$1,
        artist: song.$2,
      );
      if (!mounted) return;
      setState(() {
        _saved = result['saved'] == true;
        _listed = result['blacklisted'] == true;
      });
    } catch (_) {}
  }

  Future<void> _toggle(String action) async {
    if (_busy) return;
    if (widget.partyId.isEmpty) {
      _toast(toolI18n.text('actFailed'));
      return;
    }
    final song = _song();
    setState(() => _busy = true);
    try {
      final result = await widget.session.wishAction(
        partyId: widget.partyId,
        action: action,
        wishIds: widget.items.map((item) => item.id).where((id) => id.isNotEmpty).toList(),
        title: song.$1,
        artist: song.$2,
      );
      if (!mounted) return;
      final on = result['on'] == true;
      setState(() {
        _busy = false;
        if (action == 'favorite') _favorite = on;
        if (action == 'pin' && result['limit'] != true) _pinned = on;
        if (action == 'save') _saved = on;
        if (action == 'blacklist') _listed = on;
      });
      if (action == 'pin' && result['limit'] == true) {
        _toast(toolI18n.text('actPinLimit'));
      } else if (action == 'favorite') {
        _toast(on ? toolI18n.text('actFav') : toolI18n.text('actFavOff'));
      } else if (action == 'pin') {
        _toast(on ? toolI18n.text('actPin') : toolI18n.text('actPinOff'));
      } else if (action == 'save') {
        _toast(on ? toolI18n.text('actSaved') : toolI18n.text('actUnsaved'));
      } else if (action == 'blacklist') {
        _toast(on ? toolI18n.text('actListed') : toolI18n.text('actUnlisted'));
      }
    } catch (e) {
      if (!mounted) return;
      _toast(e is StateError && e.message.isNotEmpty
          ? e.message
          : toolI18n.text('actFailed'));
      setState(() => _busy = false);
    }
  }

  Future<void> _run(String action, String label) async {
    if (_busy) return;
    if (widget.partyId.isEmpty) {
      _toast(toolI18n.text('actFailed'));
      return;
    }
    if (action == 'block' &&
        !widget.items.any((item) => item.clientId.trim().isNotEmpty)) {
      _toast(toolI18n.text('actNoGuest'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ToolFrameShell(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF000B27),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD7B4FF), width: 2.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(toolI18n.text('no'))),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text(toolI18n.text('yes'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final song = _song();
    setState(() => _busy = true);
    try {
      await widget.session.wishAction(
        partyId: widget.partyId,
        action: action,
        wishIds: widget.items.map((item) => item.id).where((id) => id.isNotEmpty).toList(),
        title: song.$1,
        artist: song.$2,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast(e is StateError && e.message.isNotEmpty
          ? e.message
          : toolI18n.text('actFailed'));
      setState(() => _busy = false);
    }
  }

  Widget _translationLine(String greeting) {
    if (_loading.contains(greeting)) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    final text = _translated[greeting];
    if (text == null || text.isEmpty || text == greeting) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.g_translate,
              size: 12,
              color: Color(0xFFB0B0B0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                color: Color(0xFFB0B0B0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _wishWhen(int millis) {
  final time = DateTime.fromMillisecondsSinceEpoch(millis);
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _WishTrailing extends StatelessWidget {
  const _WishTrailing({required this.row});

  final WishRow row;

  @override
  Widget build(BuildContext context) {
    if (row.count <= 1) return const SizedBox.shrink();
    return Text(
      '${row.count}×',
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF7CFFB2),
      ),
    );
  }
}

class _SetlistView extends StatelessWidget {
  const _SetlistView({required this.tracks});

  final List<SetlistItem> tracks;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          toolI18n.text('noSetlist'),
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFF22222C)),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final meta = [
          if (track.bpm != null) '${track.bpm!.round()} BPM',
          if (track.camelot.isNotEmpty) track.camelot,
        ].join(' · ');
        return ListTile(
          dense: true,
          minLeadingWidth: 56,
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CopyTitleButton(title: track.title, artist: track.artist),
              Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFEB3B),
                ),
              ),
            ],
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [track.artist, if (meta.isNotEmpty) meta].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

class _SuggestionsPane extends StatelessWidget {
  const _SuggestionsPane({
    required this.loading,
    required this.enabled,
    required this.isOpenWish,
    required this.onOpenWish,
    required this.items,
    required this.idle,
    this.onReload,
  });

  final bool loading;
  final bool enabled;
  final bool Function(String title, String artist) isOpenWish;
  final void Function(BuildContext context, String title, String artist)
      onOpenWish;
  final List<Map<String, dynamic>> items;
  final bool idle;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Center(
        child: Text(
          toolI18n.text('recOff'),
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    if (idle && !loading && items.isEmpty) {
      return Center(
        child: Text(
          toolI18n.text('nothingPlaying'),
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                toolI18n.text('followups'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: toolI18n.text('newSuggestions'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: (loading || onReload == null) ? null : onReload,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF22E7FF),
              backgroundColor: Color(0x33FFFFFF),
            ),
          ),
        Expanded(
          child: (!loading && items.isEmpty)
              ? Center(
                  child: Text(
                    toolI18n.text('noSuggestions'),
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final title = (item['title'] ?? '').toString();
                    final artist = (item['artist'] ?? '').toString();
                    final open = isOpenWish(title, artist);
                    return _SuggestionRow(
                      item: item,
                      inOpenWishes: open,
                      onOpen: open
                          ? () => onOpenWish(context, title, artist)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatefulWidget {
  const _SuggestionRow({
    required this.item,
    required this.inOpenWishes,
    this.onOpen,
  });

  final Map<String, dynamic> item;
  final bool inOpenWishes;
  final VoidCallback? onOpen;

  @override
  State<_SuggestionRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends State<_SuggestionRow> {
  var _hover = false;

  Map<String, dynamic> get item => widget.item;

  String get _meta {
    final parts = <String>[];
    final bpm = item['bpm'];
    if (bpm is num && bpm >= 60 && bpm <= 220) {
      parts.add('${bpm.round()} BPM');
    }
    final camelot = (item['camelot'] ?? '').toString().trim();
    if (camelot.isNotEmpty) parts.add(camelot);
    final plays = item['playCount'];
    if (plays is int && plays > 0) parts.add('$plays×');
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? '').toString();
    final artist = (item['artist'] ?? '').toString();
    final meta = _meta;
    final matched = item['inLibrary'] == true;
    final fill = _hover
        ? (matched ? const Color(0xFF2A3830) : const Color(0xFF2A3140))
        : (matched ? const Color(0xFF16301F) : const Color(0xFF121826));
    return MouseRegion(
      cursor: widget.onOpen == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
      onTap: widget.onOpen,
      child: LibraryMatchChrome(
      matched: matched,
      roundedFrame: true,
      fill: fill,
      filePath: (item['location'] ?? '').toString().isEmpty
          ? null
          : (item['location'] ?? '').toString(),
      title: title,
      artist: artist,
      isTidal: item['isTidal'] == true,
      dragEnabled: item['canDrag'] == true,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.inOpenWishes)
            Tooltip(
              message: toolI18n.text('openWishMark'),
              waitDuration: const Duration(milliseconds: 250),
              child: const Padding(
                padding: EdgeInsets.only(top: 1, right: 4),
                child: Icon(
                  Icons.inbox,
                  size: 16,
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
          _CopyTitleButton(title: title, artist: artist),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: LibrarySourceIcon(
                        visible: item['inLibrary'] == true ||
                            item['isTidal'] == true,
                        isTidal: item['isTidal'] == true,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const TextSpan(
                        text: ' – ',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      TextSpan(
                        text: artist,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                    ),
                  ],
                ),
                Text(
                  meta.isEmpty ? '–' : meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: meta.isEmpty
                        ? Colors.white38
                        : const Color(0xFFFFCC80),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
      ),
    );
  }
}

class _Heard {
  _Heard(this.track, this.cacheKey);

  final HistoryTrack track;
  final String cacheKey;
  List<Map<String, dynamic>> suggestions = const [];
  bool searching = false;
  int playCount = 0;
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.hit,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
  });

  final _Heard? hit;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final hit = this.hit;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 2),
      decoration: BoxDecoration(
        color: const Color(0x66101830),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x6622E7FF)),
      ),
      child: hit == null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                toolI18n.text('nothingPlaying'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )
          : _recognized(hit),
    );
  }

  Widget _recognized(_Heard hit) {
    final track = hit.track;
    final camelot = camelotFromScaleName(track.musicalKey);
    final meta = <String>[
      if (track.bpm != null) '${track.bpm!.toStringAsFixed(0)} BPM',
      if (camelot != null && camelot.isNotEmpty) camelot,
      if ((camelot == null || camelot.isEmpty) &&
          (track.musicalKey ?? '').trim().isNotEmpty)
        track.musicalKey!.trim(),
      if (hit.playCount > 0) toolI18n.text('plays', {'n': '${hit.playCount}'}),
    ].join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${track.title}  –  ${track.artist}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFCC80),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ArrowButton(
                icon: Icons.chevron_left,
                enabled: canPrev,
                onPressed: onPrev,
              ),
              _ArrowButton(
                icon: Icons.chevron_right,
                enabled: canNext,
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        icon,
        size: 22,
        color: enabled ? Colors.white : Colors.white24,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1518),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: const TextStyle(height: 1.4)),
    );
  }
}

class _ConnectionDialog extends StatefulWidget {
  const _ConnectionDialog({required this.session});

  final ToolSession session;

  @override
  State<_ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<_ConnectionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final connected = widget.session.isConnected;
        return AlertDialog(
          backgroundColor: const Color(0xF00C1228),
          title: Text(
            connected ? toolI18n.text('connected') : toolI18n.text('connectTitle'),
          ),
          content: connected
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.session.ownerLabel != null) ...[
                      Text(
                        toolI18n.text(
                          'connectedAs',
                          {'name': widget.session.ownerLabel!},
                        ),
                        style: const TextStyle(
                          color: Color(0xFF22E7FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(toolI18n.text('stayConnected')),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(toolI18n.text('codeHint')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                      ],
                      decoration: InputDecoration(
                        labelText: toolI18n.text('code'),
                        counterText: '',
                      ),
                    ),
                    if (widget.session.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.session.error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(toolI18n.text('close')),
            ),
            if (connected)
              TextButton(
                onPressed: widget.session.busy
                    ? null
                    : () async {
                        await widget.session.disconnect();
                        if (context.mounted) Navigator.pop(context);
                      },
                child: Text(toolI18n.text('logout')),
              )
            else
              TextButton(
                onPressed: widget.session.busy
                    ? null
                    : () async {
                        final ok = await widget.session.connect(_controller.text);
                        if (ok && context.mounted) Navigator.pop(context);
                      },
                child: Text(widget.session.busy ? '…' : toolI18n.text('connectBtn')),
              ),
          ],
        );
      },
    );
  }
}

