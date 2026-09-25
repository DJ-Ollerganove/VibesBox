import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/song_request.dart';
import '../services/wish_management_service.dart';
import '../utils/pre_wish_helper.dart';
import '../utils/ui_constants.dart';
import '../utils/wish_grouping_helper.dart';
import 'pre_wishes_overview_dialog.dart';

int _countPrimaryPreWishesForParty(List<QueryDocumentSnapshot> docs) {
  final wishes = <SongRequest>[];
  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>?;
    if (!PreWishHelper.isPreWishInOverview(data)) continue;
    try {
      wishes.add(SongRequest.fromDocument(doc));
    } catch (_) {}
  }
  return WishGroupingHelper.withoutDuplicateShadowDocuments(wishes).length;
}

/// Kompaktes „VW: N“ für Party-Mini-Kacheln (nur sichtbar wenn count > 0).
class PartyPreWishesCompactBadge extends StatefulWidget {
  const PartyPreWishesCompactBadge({
    super.key,
    required this.partyId,
    required this.partyName,
    this.partyStartDate,
    this.enabled = true,
    this.fontSize = 10,
  });

  final String partyId;
  final String partyName;
  final DateTime? partyStartDate;
  final bool enabled;
  final double fontSize;

  @override
  State<PartyPreWishesCompactBadge> createState() =>
      _PartyPreWishesCompactBadgeState();
}

class _PartyPreWishesCompactBadgeState extends State<PartyPreWishesCompactBadge> {
  StreamSubscription<QuerySnapshot>? _subscription;
  int _count = 0;
  bool _hasSnapshot = false;

  @override
  void initState() {
    super.initState();
    _subscribe(widget.partyId);
  }

  @override
  void didUpdateWidget(covariant PartyPreWishesCompactBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partyId != widget.partyId) {
      _hasSnapshot = false;
      _count = 0;
      _subscribe(widget.partyId);
    }
  }

  void _subscribe(String partyId) {
    _subscription?.cancel();
    if (partyId.isEmpty) return;
    _subscription =
        WishManagementService.watchPreWishOverview(partyId).listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _count = _countPrimaryPreWishesForParty(snapshot.docs);
          _hasSnapshot = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _hasSnapshot = true);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSnapshot || _count <= 0) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context)!;
    final color = widget.enabled
        ? UIConstants.colorPreWish
        : Colors.grey.shade600;

    final label = l.pre_wishes_compact_count(_count);

    return GestureDetector(
      onTap: widget.enabled
          ? () => PreWishesOverviewDialog.show(
                context,
                partyId: widget.partyId,
                partyName: widget.partyName,
                partyStartDate: widget.partyStartDate,
              )
          : null,
      behavior: HitTestBehavior.opaque,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Klickbare Zeile „VW: N“ unter dem Party-Countdown (Party-Verwaltung, Lila).
class PartyPreWishesRow extends StatefulWidget {
  const PartyPreWishesRow({
    super.key,
    required this.partyId,
    required this.partyName,
    this.partyStartDate,
    this.dimColor,
  });

  final String partyId;
  final String partyName;
  final DateTime? partyStartDate;
  final Color? dimColor;

  @override
  State<PartyPreWishesRow> createState() => _PartyPreWishesRowState();
}

class _PartyPreWishesRowState extends State<PartyPreWishesRow> {
  StreamSubscription<QuerySnapshot>? _subscription;
  int? _count;
  bool _hasSnapshot = false;

  @override
  void initState() {
    super.initState();
    _subscribe(widget.partyId);
  }

  @override
  void didUpdateWidget(covariant PartyPreWishesRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partyId != widget.partyId) {
      _hasSnapshot = false;
      _count = null;
      _subscribe(widget.partyId);
    }
  }

  void _applySnapshot(QuerySnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _count = _countPrimaryPreWishesForParty(snapshot.docs);
      _hasSnapshot = true;
    });
  }

  void _subscribe(String partyId) {
    _subscription?.cancel();
    if (partyId.isEmpty) return;

    _subscription =
        WishManagementService.watchPreWishOverview(partyId).listen(
      _applySnapshot,
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _count ??= 0;
          _hasSnapshot = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _compactLabel(AppLocalizations l) {
    if (!_hasSnapshot || _count == null) return 'VW: …';
    return l.pre_wishes_compact_count(_count!);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labelColor = widget.dimColor ?? UIConstants.colorPreWish;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.dimColor != null
              ? null
              : () => PreWishesOverviewDialog.show(
                    context,
                    partyId: widget.partyId,
                    partyName: widget.partyName,
                    partyStartDate: widget.partyStartDate,
                  ),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _compactLabel(l),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                if (widget.dimColor == null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: labelColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
