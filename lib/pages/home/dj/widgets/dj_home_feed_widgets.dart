import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/song_request.dart';
import '../../../../services/active_party_service.dart';
import '../../../../services/dj_wish_notification_navigator.dart';
import '../../../../services/history_provider.dart';
import '../../../../services/navigation_service.dart';
import '../../../../services/open_wishes_visibility_service.dart';
import '../../../../services/wish_management_service.dart';
import '../../../../utils/pre_wish_helper.dart';
import '../../../../utils/wish_grouping_helper.dart';
import 'dj_home_feed_party_context.dart';

/// Letzte 3 erkannte Songs – Klick öffnet Musik-History.
/// Zeigt nie „Keine Party aktiv“ — nur Songs oder „noch keine erkannt“.
class DjHomeRecentHistoryWidget extends StatefulWidget {
  const DjHomeRecentHistoryWidget({super.key});

  @override
  State<DjHomeRecentHistoryWidget> createState() =>
      _DjHomeRecentHistoryWidgetState();
}

class _DjHomeRecentHistoryWidgetState extends State<DjHomeRecentHistoryWidget> {
  final _ctx = DjHomeFeedPartyContext.instance;
  String? _sessionId;
  bool _resolving = false;
  bool _resolveQueued = false;
  String? _lastResolvePartyId;
  bool _firestoreResolved = false;

  /// Stream nur einmal pro Session — sonst leerer StreamBuilder bei Rebuilds.
  String? _streamSessionId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _tracksStream;

  @override
  void initState() {
    super.initState();
    _ctx.retain();
    OpenWishesVisibilityService.visibilityNotifier
        .addListener(_scheduleSessionResolve);
    ActivePartyService.storedSessionNotifier
        .addListener(_scheduleSessionResolve);
    HistoryProvider.tracksRevision.addListener(_onTracksRevision);
    _primeSessionFromStored();
    _scheduleSessionResolve();
  }

  @override
  void dispose() {
    OpenWishesVisibilityService.visibilityNotifier
        .removeListener(_scheduleSessionResolve);
    ActivePartyService.storedSessionNotifier
        .removeListener(_scheduleSessionResolve);
    HistoryProvider.tracksRevision.removeListener(_onTracksRevision);
    _ctx.release();
    super.dispose();
  }

  void _onTracksRevision() {
    _firestoreResolved = false;
    _scheduleSessionResolve();
  }

  void _primeSessionFromStored() {
    final partyId = _ctx.resolveOpenWishesPartyId();
    final stored = ActivePartyService.getStoredSession();
    if (partyId == null ||
        partyId.isEmpty ||
        stored == null ||
        stored.partyId != partyId ||
        stored.sessionId == null ||
        stored.sessionId!.isEmpty) {
      return;
    }
    _sessionId = stored.sessionId;
    _lastResolvePartyId = partyId;
    _resolving = false;
    _ensureTracksStream(stored.sessionId!);
  }

  void _scheduleSessionResolve() {
    if (!mounted) return;
    final partyId = _ctx.resolveOpenWishesPartyId();
    // Nach tracksRevision ist _firestoreResolved false → immer neu auflösen.
    // Sonst: nicht an leerer stored/local Session kleben — Resolve holt Session-mit-Tracks.
    if (_firestoreResolved &&
        partyId == _lastResolvePartyId &&
        _sessionId != null &&
        _sessionId!.isNotEmpty &&
        _tracksStream != null) {
      final stored = ActivePartyService.getStoredSession();
      final storedSid = (stored != null && stored.partyId == partyId)
          ? stored.sessionId
          : null;
      if (storedSid == null ||
          storedSid.isEmpty ||
          storedSid == _sessionId) {
        return;
      }
    }
    if (_resolving) {
      _resolveQueued = true;
      return;
    }
    unawaited(_resolveSession());
  }

  Future<void> _resolveSession() async {
    if (_resolving) {
      _resolveQueued = true;
      return;
    }
    _resolving = true;
    if (mounted && (_sessionId == null || _sessionId!.isEmpty)) {
      setState(() {});
    }
    try {
      final partyId = _ctx.resolveOpenWishesPartyId();
      _lastResolvePartyId = partyId;
      final sessionId = await _ctx.resolveMusicHistorySessionId();
      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        _resolving = false;
        _firestoreResolved = true;
        if (sessionId != null && sessionId.isNotEmpty) {
          _ensureTracksStream(sessionId);
        } else {
          _streamSessionId = null;
          _tracksStream = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolving = false;
          _firestoreResolved = true;
        });
      } else {
        _resolving = false;
      }
    }
    if (_resolveQueued && mounted) {
      _resolveQueued = false;
      unawaited(_resolveSession());
    }
  }

  void _ensureTracksStream(String sessionId) {
    if (_streamSessionId == sessionId && _tracksStream != null) return;
    _streamSessionId = sessionId;
    _tracksStream = FirebaseFirestore.instance
        .collection('music_history')
        .doc(sessionId)
        .collection('tracks')
        .limit(25)
        .snapshots();
  }

  List<String> _topTrackLines(List<QueryDocumentSnapshot> docs) {
    final entries = <({DateTime ts, String line})>[];
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().trim();
      final artist = (data['artist'] ?? '').toString().trim();
      final line = artist.isNotEmpty ? '$title — $artist' : title;
      if (line.isEmpty) continue;
      final raw = data['timestamp'];
      DateTime ts = DateTime.fromMillisecondsSinceEpoch(0);
      if (raw is Timestamp) ts = raw.toDate();
      entries.add((ts: ts, line: line));
    }
    entries.sort((a, b) => b.ts.compareTo(a.ts));
    return entries.take(3).map((e) => e.line).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final partyId = _ctx.resolveOpenWishesPartyId();
    if (partyId == null || partyId.isEmpty) {
      return const SizedBox.shrink();
    }

    final onTap = () => NavigationService().setTabIndex(
          DjWishNotificationNavigator.djHistoryTabIndex,
          force: true,
        );

    if (_resolving && (_sessionId == null || _sessionId!.isEmpty)) {
      return _DjHomeTappableFeedCard(
        title: l.dj_home_music_history_title,
        child: const SizedBox(
          height: 36,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        onTap: onTap,
      );
    }

    final sessionId = _sessionId;
    final tracksStream = _tracksStream;
    if (sessionId == null ||
        sessionId.isEmpty ||
        tracksStream == null) {
      return _DjHomeTappableFeedCard(
        title: l.dj_home_music_history_title,
        message: l.dj_home_no_songs_yet,
        onTap: onTap,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: tracksStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _DjHomeTappableFeedCard(
            title: l.dj_home_music_history_title,
            message: l.dj_home_no_songs_yet,
            onTap: onTap,
          );
        }
        if (!snap.hasData) {
          return _DjHomeTappableFeedCard(
            title: l.dj_home_music_history_title,
            child: const SizedBox(
              height: 36,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            onTap: onTap,
          );
        }
        final lines = _topTrackLines(snap.data!.docs);
        if (lines.isEmpty) {
          return _DjHomeTappableFeedCard(
            title: l.dj_home_music_history_title,
            message: l.dj_home_no_songs_yet,
            onTap: onTap,
          );
        }
        return _DjHomeTappableFeedCard(
          title: l.dj_home_music_history_title,
          lines: lines,
          onTap: onTap,
        );
      },
    );
  }
}

/// Neueste 3 offene Wünsche (Status pending) – Klick öffnet VibesBox „Offen“.
class DjHomeOpenWishesCountWidget extends StatefulWidget {
  const DjHomeOpenWishesCountWidget({super.key});

  @override
  State<DjHomeOpenWishesCountWidget> createState() =>
      _DjHomeOpenWishesCountWidgetState();
}

class _DjHomeOpenWishesCountWidgetState
    extends State<DjHomeOpenWishesCountWidget> {
  final _ctx = DjHomeFeedPartyContext.instance;
  String? _partyId;
  String? _cachedStreamPartyId;
  Stream<QuerySnapshot>? _wishesStream;

  @override
  void initState() {
    super.initState();
    _ctx.retain();
    OpenWishesVisibilityService.visibilityNotifier
        .addListener(_onPartyContextChanged);
    ActivePartyService.storedSessionNotifier
        .addListener(_onPartyContextChanged);
    _onPartyContextChanged();
  }

  @override
  void dispose() {
    OpenWishesVisibilityService.visibilityNotifier
        .removeListener(_onPartyContextChanged);
    ActivePartyService.storedSessionNotifier
        .removeListener(_onPartyContextChanged);
    _ctx.release();
    super.dispose();
  }

  void _onPartyContextChanged() {
    if (!mounted) return;
    final resolved = _ctx.resolveOpenWishesPartyId();
    if (resolved != null && resolved.isNotEmpty) {
      if (_partyId == resolved) return;
      setState(() => _partyId = resolved);
      return;
    }
    if (_partyId != null) {
      setState(() {
        _partyId = null;
        _cachedStreamPartyId = null;
        _wishesStream = null;
      });
    }
  }

  Stream<QuerySnapshot> _wishesStreamFor(String partyId) {
    if (_cachedStreamPartyId != partyId) {
      _cachedStreamPartyId = partyId;
      _wishesStream = WishManagementService.getWishesStream(partyId, 'pending');
    }
    return _wishesStream!;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final onTap = DjWishNotificationNavigator.instance.navigateToOpenWishesTab;
    final partyId = _partyId;

    if (partyId == null || partyId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _wishesStreamFor(partyId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return _DjHomeTappableFeedCard(
            title: l.dj_home_widget_open_wishes_count,
            child: const SizedBox(
              height: 36,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            onTap: onTap,
          );
        }
        final wishes = <SongRequest>[];
        for (final doc in snap.data!.docs) {
          try {
            final sr = SongRequest.fromDocument(doc);
            if (sr.status != 'pending') continue;
            if (sr.isPreWish == true && sr.preWishPublished != true) continue;
            wishes.add(sr);
          } catch (_) {}
        }
        final primary = WishGroupingHelper.withoutDuplicateShadowDocuments(
          wishes,
        );
        primary.sort((a, b) {
          final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
        final top3 = primary.take(3).toList();
        if (top3.isEmpty) {
          return _DjHomeTappableFeedCard(
            title: l.dj_home_widget_open_wishes_count,
            message: l.no_open_wishes,
            onTap: onTap,
          );
        }
        return _DjHomeTappableFeedCard(
          title: l.dj_home_widget_open_wishes_count,
          lines: top3.map(_wishLine).toList(),
          onTap: onTap,
        );
      },
    );
  }
}

/// 3 älteste Vorab-Wünsche – nur sichtbar wenn Session Vorab-Wünsche meldet.
class DjHomePreWishesCountWidget extends StatefulWidget {
  const DjHomePreWishesCountWidget({super.key});

  @override
  State<DjHomePreWishesCountWidget> createState() =>
      _DjHomePreWishesCountWidgetState();
}

class _DjHomePreWishesCountWidgetState extends State<DjHomePreWishesCountWidget> {
  final _ctx = DjHomeFeedPartyContext.instance;
  String? _partyId;
  bool _hasQueuedPreWishes = false;

  @override
  void initState() {
    super.initState();
    _ctx.retain();
    OpenWishesVisibilityService.visibilityNotifier
        .addListener(_onSessionChanged);
    ActivePartyService.storedSessionNotifier.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  @override
  void dispose() {
    OpenWishesVisibilityService.visibilityNotifier
        .removeListener(_onSessionChanged);
    ActivePartyService.storedSessionNotifier.removeListener(_onSessionChanged);
    _ctx.release();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    final stored = ActivePartyService.getStoredSession();
    final partyId = _ctx.resolveOpenWishesPartyId();
    final hasQueued = stored?.hasQueuedPreWishes == true;
    if (partyId == _partyId && hasQueued == _hasQueuedPreWishes) return;
    setState(() {
      _partyId = partyId;
      _hasQueuedPreWishes = hasQueued;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!_hasQueuedPreWishes) {
      return const SizedBox.shrink();
    }
    final partyId = _partyId;
    if (partyId == null || partyId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: WishManagementService.watchPreWishOverview(partyId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final queued = <SongRequest>[];
        for (final doc in snap.data!.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (!PreWishHelper.isQueuedPreWish(data)) continue;
          try {
            queued.add(SongRequest.fromDocument(doc));
          } catch (_) {}
        }
        final primary = WishGroupingHelper.withoutDuplicateShadowDocuments(
          queued,
        );
        primary.sort((a, b) {
          final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return ta.compareTo(tb);
        });
        final oldest3 = primary.take(3).toList();
        if (oldest3.isEmpty) {
          return const SizedBox.shrink();
        }
        return _DjHomeTappableFeedCard(
          title: l.dj_home_widget_pre_wishes_count,
          lines: oldest3.map(_wishLine).toList(),
          onTap: DjWishNotificationNavigator.instance.navigateToVorabTab,
        );
      },
    );
  }
}

String _wishLine(SongRequest w) {
  final title = (w.title ?? w.song ?? '').trim();
  final artist = (w.artist ?? '').trim();
  if (title.isEmpty && artist.isEmpty) return '—';
  if (artist.isEmpty) return title;
  if (title.isEmpty) return artist;
  return '$title — $artist';
}

class _DjHomeTappableFeedCard extends StatelessWidget {
  const _DjHomeTappableFeedCard({
    required this.title,
    required this.onTap,
    this.lines,
    this.message,
    this.child,
  });

  final String title;
  final VoidCallback onTap;
  final List<String>? lines;
  final String? message;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              if (child != null)
                child!
              else if (lines != null)
                ...lines!.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ),
                )
              else if (message != null)
                Text(
                  message!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
