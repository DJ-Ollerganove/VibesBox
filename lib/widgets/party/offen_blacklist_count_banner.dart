import 'package:flutter/material.dart';

import '../../app_scaffold_messenger.dart';
import '../../l10n/app_localizations.dart';
import '../../services/dj_song_blacklist_service.dart';
import '../../utils/debug_log.dart';
import '../../utils/ui_constants.dart';

/// Live-Hinweis über der offenen Wunschliste: Zähler plus Snackbar bei neuen Treffern.
class OffenBlacklistCountBanner extends StatefulWidget {
  const OffenBlacklistCountBanner({
    super.key,
    required this.partyId,
    this.compact = false,
  });

  final String partyId;
  final bool compact;

  @override
  State<OffenBlacklistCountBanner> createState() =>
      _OffenBlacklistCountBannerState();
}

class _OffenBlacklistCountBannerState extends State<OffenBlacklistCountBanner> {
  final Set<String> _seenIds = {};
  bool _primed = false;

  @override
  void didUpdateWidget(OffenBlacklistCountBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partyId != widget.partyId) {
      _seenIds.clear();
      _primed = false;
    }
  }

  void _onHits(List<DjBlacklistRejectHit> hits) {
    final ids = hits.map((h) => h.id).toSet();
    if (!_primed) {
      _seenIds
        ..clear()
        ..addAll(ids);
      _primed = true;
      return;
    }
    final fresh = <DjBlacklistRejectHit>[];
    for (final hit in hits) {
      if (_seenIds.contains(hit.id)) continue;
      if (DjSongBlacklistService.instance.takeLiveHintSkip(hit.id)) continue;
      fresh.add(hit);
    }
    _seenIds
      ..clear()
      ..addAll(ids);
    if (fresh.isEmpty || !mounted) return;
    final l = AppLocalizations.of(context)!;
    for (final hit in fresh) {
      final song = hit.songLabel;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(
            song.isEmpty
                ? l.translate('song_blacklist_wish_moved')
                : l.tp('song_blacklist_live_hint', {'song': song}),
            style: const TextStyle(
              color: UIConstants.colorSongBlacklistOnChip,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: UIConstants.colorSongBlacklistChip,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.partyId.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: DjSongBlacklistService.instance.prefsNotifier,
      builder: (context, prefs, _) {
        // Gast-Sperre: Treffer landen nie unter Abgelehnt → kein Badge.
        // Reject-Modus: nur echte Blacklist-Abgelehnte zählen (nie Eintragsanzahl).
        if (!prefs.enabled || prefs.guestBlock) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<List<DjBlacklistRejectHit>>(
          stream: DjSongBlacklistService.instance.watchHits(widget.partyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugLog('OffenBlacklistCountBanner: ${snapshot.error}');
            }
            final hits = snapshot.data ?? const <DjBlacklistRejectHit>[];
            if (snapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _onHits(hits);
              });
            }
            if (hits.isEmpty) return const SizedBox.shrink();
            return _chip(hits.length);
          },
        );
      },
    );
  }

  Widget _chip(int count) {
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 10,
        vertical: widget.compact ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: UIConstants.colorSongBlacklistChip,
        borderRadius: BorderRadius.circular(widget.compact ? 8 : 4),
      ),
      child: Text(
        'BLACKLIST $count',
        style: TextStyle(
          color: UIConstants.colorSongBlacklistOnChip,
          fontSize: widget.compact ? 12 : 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
    if (widget.compact) return chip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: chip,
      ),
    );
  }
}
