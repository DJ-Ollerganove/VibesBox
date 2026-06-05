import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/song_request.dart';
import '../../../../services/active_party_service.dart';
import '../../../../services/dj_wish_notification_navigator.dart';
import '../../../../services/navigation_service.dart';
import '../../../../services/wish_management_service.dart';
import '../../../../utils/pre_wish_helper.dart';
import '../../../../utils/wish_grouping_helper.dart';

/// Letzte 3 erkannte Songs – Klick öffnet Musik-History.
class DjHomeRecentHistoryWidget extends StatelessWidget {
  const DjHomeRecentHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return StreamBuilder<ActivePartyInfo?>(
      stream: ActivePartyService.getActivePartyInfoStream(
        FirebaseAuth.instance.currentUser?.uid,
      ),
      builder: (context, partySnap) {
        final sessionId = partySnap.data?.sessionId;
        if (sessionId == null || sessionId.isEmpty) {
          return _DjHomeTappableFeedCard(
            title: l.dj_home_music_history_title,
            message: l.no_active_party,
            onTap: () => NavigationService().setTabIndex(
              DjWishNotificationNavigator.djHistoryTabIndex,
              force: true,
            ),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('music_history')
              .doc(sessionId)
              .collection('tracks')
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return _DjHomeTappableFeedCard(
                title: l.dj_home_music_history_title,
                message: l.dj_home_no_songs_yet,
                onTap: () => NavigationService().setTabIndex(
                  DjWishNotificationNavigator.djHistoryTabIndex,
                  force: true,
                ),
              );
            }
            return _DjHomeTappableFeedCard(
              title: l.dj_home_music_history_title,
              lines: docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final title = (data['title'] ?? '').toString();
                final artist = (data['artist'] ?? '').toString();
                final line = artist.isNotEmpty ? '$title — $artist' : title;
                return line.trim().isEmpty ? '—' : line.trim();
              }).toList(),
              onTap: () => NavigationService().setTabIndex(
                DjWishNotificationNavigator.djHistoryTabIndex,
                force: true,
              ),
            );
          },
        );
      },
    );
  }
}

/// Neueste 3 offene Wünsche – Klick öffnet VibesBox „Offen“.
class DjHomeOpenWishesCountWidget extends StatelessWidget {
  const DjHomeOpenWishesCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ValueListenableBuilder<ActivePartyInfo?>(
      valueListenable: ActivePartyService.storedSessionNotifier,
      builder: (context, session, _) {
        final partyId = session?.partyId;
        if (partyId == null || partyId.isEmpty) {
          return _DjHomeTappableFeedCard(
            title: l.dj_home_widget_open_wishes_count,
            message: l.no_active_party,
            onTap: DjWishNotificationNavigator.instance.navigateToOpenWishesTab,
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: WishManagementService.getWishesStream(partyId, 'pending'),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final wishes = <SongRequest>[];
            for (final doc in snap.data!.docs) {
              try {
                final sr = SongRequest.fromDocument(doc);
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
                onTap: DjWishNotificationNavigator.instance.navigateToOpenWishesTab,
              );
            }
            return _DjHomeTappableFeedCard(
              title: l.dj_home_widget_open_wishes_count,
              lines: top3.map(_wishLine).toList(),
              onTap: DjWishNotificationNavigator.instance.navigateToOpenWishesTab,
            );
          },
        );
      },
    );
  }
}

/// 3 älteste Vorab-Wünsche – nur sichtbar wenn Session Vorab-Wünsche meldet.
class DjHomePreWishesCountWidget extends StatelessWidget {
  const DjHomePreWishesCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ValueListenableBuilder<ActivePartyInfo?>(
      valueListenable: ActivePartyService.storedSessionNotifier,
      builder: (context, session, _) {
        if (session == null || !session.hasQueuedPreWishes) {
          return const SizedBox.shrink();
        }
        final partyId = session.partyId;
        return StreamBuilder<QuerySnapshot>(
          stream: WishManagementService.getPreWishOverviewStream(partyId),
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
  });

  final String title;
  final VoidCallback onTap;
  final List<String>? lines;
  final String? message;

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
              if (lines != null)
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
