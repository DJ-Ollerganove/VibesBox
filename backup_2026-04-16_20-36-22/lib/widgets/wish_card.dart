import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../l10n/app_localizations.dart';
import '../models/song_request.dart';
import '../utils/greeting_translator.dart';
import '../utils/ui_constants.dart';
import '../utils/relative_time_minutes.dart';
import '../services/wish_management_service.dart';
import '../services/user_blocking_service.dart';
import '../services/active_party_service.dart';
import '../services/user_service.dart';
import '../pages/rejected_wish_detail_page.dart';
import 'free_feature_locked.dart';
import '../utils/debug_log.dart';

/// Vereinheitlichtes Widget für die Anzeige von Musikwünschen
/// Unterstützt die Modi: 'Offen', 'Gespielt', 'Abgelehnt'
/// Design: Dunkelgrau (0xFF1E1E1E) mit weißer Schrift für maximalen Kontrast
/// Layout: Zeilen-basiert mit erweiterter Gäste-Logik
enum WishCardType { offen, gespielt, abgelehnt }

/// Dezentes Grau-Orange für Auto-Erkennung auf der Gespielt-Karte (nicht konkurrieren mit grünem „Gespielt“-Text).
const Color _kAutoRecognizedIconGespielt = Color(0xFF9E8A78);

/// Anzeige-Zähler für Badge: entspricht [createdAt_list]-Länge (bzw. [requested_by]), nicht duplicate_count+1 aus Firestore.
int wishCountForBadge(Map<String, dynamic> data, Map<String, dynamic>? groupedData) {
  if (groupedData != null) {
    final wtc = groupedData['wish_total_count'];
    if (wtc is int && wtc >= 1) return wtc;
    final cal = groupedData['createdAt_list'];
    if (cal is List && cal.isNotEmpty) return cal.length;
    final rb = groupedData['requested_by'];
    if (rb is List && rb.isNotEmpty) return rb.length;
  }
  final calSingle = data['createdAt_list'];
  if (calSingle is List && calSingle.isNotEmpty) return calSingle.length;
  final rbSingle = data['requested_by'];
  if (rbSingle is List && rbSingle.isNotEmpty) return rbSingle.length;
  final dc = (data['duplicate_count'] as int?) ?? 0;
  return dc + 1;
}

class WishCard extends StatelessWidget {
  final SongRequest? request; // Für einzelne Wünsche
  final Map<String, dynamic>? groupedData; // Für gruppierte Wünsche
  final List<String>? docIds; // Für gruppierte Wünsche
  final WishCardType type;
  final int number;
  final bool isNew;
  final DateTime? lastViewedTime;
  final VoidCallback? onTap;
  final Function(BuildContext, List<String>)? onPlay; // Für gruppierte Wünsche
  final Function(BuildContext, String)? onPlaySingle; // Für einzelne Wünsche
  final Function(BuildContext, List<String>)? onReject; // Für gruppierte Wünsche
  final Function(BuildContext, String)? onRejectSingle; // Für einzelne Wünsche
  final Function(BuildContext, List<String>)? onDelete; // Für gruppierte Wünsche
  final Function(BuildContext, String)? onDeleteSingle; // Für einzelne Wünsche
  final Function(BuildContext, SongRequest, Map<String, dynamic>, List<String>)? onBlockGrouped; // Für gruppierte Wünsche
  final Function(BuildContext, SongRequest)? onBlockSingle; // Für einzelne Wünsche
  final VoidCallback? onUndo;
  /// Abgelehnt → offen: nach Bestätigung asynchron ausführen; [detailContext] ist der Detail-Dialog (für [Navigator.pop] nach Erfolg).
  final Future<void> Function(BuildContext detailContext)? onRestore;
  final Key? cardKey;
  /// Optionale Rahmenfarbe für den Wunsch-Detail-Dialog (sonst aus Typ abgeleitet).
  final Color? detailDialogBorderColor;

  const WishCard({
    super.key,
    this.request,
    this.groupedData,
    this.docIds,
    required this.type,
    required this.number,
    this.isNew = false,
    this.lastViewedTime,
    this.onTap,
    this.onPlay,
    this.onPlaySingle,
    this.onReject,
    this.onRejectSingle,
    this.onDelete,
    this.onDeleteSingle,
    this.onBlockGrouped,
    this.onBlockSingle,
    this.onUndo,
    this.onRestore,
    this.cardKey,
    this.detailDialogBorderColor,
  }) : assert(
          request != null || groupedData != null,
          'Mindestens request oder groupedData muss gesetzt sein',
        );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    // Extrahiere Daten
    final data = groupedData ?? _requestToMap(request!);
    final title = (data['title'] ?? '') as String;
    final artist = (data['artist'] ?? '') as String;
    final requestedBy = List<String>.from((data['requested_by'] as List?) ?? []);
    final name = (data['name'] ?? '') as String;
    final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
    final isRegisteredUsers = Map<String, bool>.from(
      (data['is_registered_users'] as Map<String, dynamic>?) ?? {},
    );
    final greetings = List<Map<String, dynamic>>.from(
      (data['greetings'] as List?)?.map((g) => g as Map<String, dynamic>) ?? [],
    );
    final greeting = (data['greeting'] ?? '') as String;
    final tsCreated = data['createdAt'];
    final created = tsCreated is Timestamp
        ? tsCreated.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    final tsPlayed = data['played_at'] as Timestamp? ?? data['playedAt'] as Timestamp? ?? data['recognized_at'] as Timestamp?;
    final played = tsPlayed?.toDate();
    final tsRejected = data['rejected_at'] as Timestamp? ?? data['rejectedAt'] as Timestamp?;
    final rejected = tsRejected?.toDate();
    final autoRejectedByBlock = data['auto_rejected_by_block'] as bool? ?? false;
    final autoRecognized = data['auto_recognized'] as bool? ?? false;
    final isFavorite = (data['is_favorite'] as bool?) ?? false;
    final isDjWish = (data['is_dj_wish'] as bool?) ?? false;
    
    // ✅ SYNCHRONISIERT: Read-Status kombiniert beide Systeme (isSeen Feld + seenWishIds Set)
    // Ein Song gilt als "gelesen" (Blauer Rahmen), wenn:
    // 1. DAS FELD data['isSeen'] == true ist ODER
    // 2. DIE docId im lokalen Set ActivePartyService.seenWishIds enthalten ist
    final effectivelySeen = type == WishCardType.offen 
        ? (() {
            // Weg 1: Prüfe isSeen Feld in Firestore
            final isSeenValue = data['isSeen'];
            final isSeenFromField = isSeenValue is bool ? isSeenValue : (isSeenValue == null ? true : true);
            
            // Weg 2: Prüfe lokales seenWishIds Set
            final docIdsToCheck = docIds ?? (request != null ? [request!.id] : []);
            final isSeenFromSet = docIdsToCheck.isNotEmpty && 
                docIdsToCheck.any((id) => ActivePartyService.seenWishIds.contains(id));
            
            // Kombiniertes Ergebnis: EINES der beiden Systeme reicht
            final result = isSeenFromField || isSeenFromSet;
            
            // ✅ Erweitertes Debug-Logging
            if (type == WishCardType.offen) {
              debugLog('🔍 WishCard: isSeen Feld = $isSeenValue (→ $isSeenFromField) | seenWishIds Check = $isSeenFromSet | EFFEKTIV = $result');
            }
            return result;
          })()
        : true; // Für andere Seiten immer als "gelesen" betrachten

    // Design-Farben: Solides Dunkelgrau mit weißer Schrift
    // Hintergrundfarbe: Orange RGB(208, 162, 0) wenn neu, sonst Dunkelgrau
    final cardColor = isNew 
        ? const Color.fromRGBO(208, 162, 0, 0.25) 
        : const Color(0xFF1E1E1E);
    const textColor = Colors.white;
    const secondaryTextColor = Color(0xFFB0B0B0);

    // Erstelle Wünscher-Liste mit Sortierung (ältester zuerst)
    final wishersList = _buildWishersList(data, greetings, greeting, name, List<String>.from(namesToShow), isRegisteredUsers);
    final totalWishes = wishCountForBadge(data, groupedData);
    final showWishCount = totalWishes > 1;
    final hasGreeting = wishersList.any((w) => (w['greeting'] as String? ?? '').isNotEmpty);
    final titleVariants = List<String>.from((data['title_variants'] as List?)?.whereType<String>() ?? []);

    return Padding(
      key: cardKey,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap ?? () => _showDetailModal(
          context,
          data,
          request,
          docIds,
          created,
          played,
          rejected,
          type,
          isNew,
          autoRecognized,
          autoRejectedByBlock,
          wishersList,
          title,
          artist,
          l,
          detailDialogBorderColor,
        ),
            splashColor: Colors.amber.shade800,
            highlightColor: Colors.amber.shade900.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getBorderColor(type, isNew, effectivelySeen),
                  width: 2.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactStatusRow(
                      context,
                      created,
                      played,
                      rejected,
                      type,
                      wishersList,
                      isNew,
                      autoRecognized,
                      isRtl,
                      textColor,
                      l,
                      data,
                      isFavorite,
                      docIds,
                    ),
                    const SizedBox(height: 8),
                    _buildCompactMusicRow(
                      context,
                      title,
                      artist,
                      autoRecognized,
                      type,
                      isRtl,
                      textColor,
                      l,
                      isDjWish: isDjWish,
                    ),
                    if (titleVariants.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Gewünschte Versionen: ${titleVariants.join(", ")}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Zeile 1: Kompakte Status-Zeile (Eingang + Icons)
  Widget _buildCompactStatusRow(
    BuildContext context,
    DateTime created,
    DateTime? played,
    DateTime? rejected,
    WishCardType type,
    List<Map<String, dynamic>> wishersList,
    bool isNew,
    bool autoRecognized,
    bool isRtl,
    Color textColor,
    AppLocalizations l,
    Map<String, dynamic> cardData,
    bool isFavorite,
    List<String>? docIds,
  ) {
    final loc = l;
    final hasGreeting = wishersList.any((w) => (w['greeting'] as String? ?? '').isNotEmpty);
    final summary = _resolveWishTimeSummary(cardData, created);
    final totalWishes = wishCountForBadge(cardData, groupedData);
    final showWishCount = totalWishes > 1;
    final showFavorite = type == WishCardType.offen && docIds != null && docIds.isNotEmpty;

    // Für Gespielt-Seite: Zweizeilige Anzeige (Weiß/Grün)
    Widget statusWidget;
    if (type == WishCardType.gespielt && played != null) {
      final playedTime = _formatClockWithSuffixForLocale(context, played, l);
      final waitMinutes = played.difference(summary.oldestWishDate).inMinutes;
      final minutesText = loc.minutes_short;
      
      statusWidget = Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zeile 1: Nur ältester Wunschzeitstempel
          Text(
            '${loc.requested_at} ${_formatClockWithSuffixForLocale(context, summary.oldestWishDate, l)}',
            style: TextStyle(
              fontSize: 12,
              color: textColor,
            ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          ),
          // Zeile 2: Gespielt (Grün, fett) mit Wartezeit in Klammern
          Row(
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Auto-Icon: in der Titelzeile (_buildCompactMusicRow), hier kein Duplikat
              // "Gespielt: [Datum] [Zeit]" in Grün
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${loc.played}: $playedTime',
                        style: const TextStyle(
                          fontSize: 12,
                          color: UIConstants.frameGespielt,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                // Wartezeit in Klammern (Weiß/Standardfarbe): "(Wartezeit: 3 Min)"
                TextSpan(
                  text: ' (${loc.wait_time_label}: $waitMinutes $minutesText)',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                    ],
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                ),
              ),
            ],
          ),
        ],
      );
    } else if (type == WishCardType.offen) {
      statusWidget = Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        children: [
          Text(
            _formatClockWithSuffixForLocale(context, summary.oldestWishDate, l),
            style: TextStyle(fontSize: 12, color: textColor),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _SinceTimeDisplay(
            wishDate: summary.oldestWishDate,
            textStyle: TextStyle(fontSize: 12, color: textColor),
            isRtl: isRtl,
            l: l,
          ),
        ],
      );
    } else if (type == WishCardType.abgelehnt && rejected != null) {
      final rejectedTime = _formatClockWithSuffixForLocale(context, rejected, l);
      
      statusWidget = Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zeile 1: Nur ältester Wunschzeitstempel
          Text(
            '${loc.requested_at} ${_formatClockWithSuffixForLocale(context, summary.oldestWishDate, l)}',
            style: TextStyle(
              fontSize: 12,
              color: textColor,
            ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          ),
          // Zeile 2: Abgelehnt (Orange, fett) + Absende-/Ablehnungs-Uhrzeit – ohne Wartezeit
          Row(
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${loc.rejected}: $rejectedTime',
                  style: const TextStyle(
                    fontSize: 12,
                    color: UIConstants.frameAbgelehnt,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Standard-Anzeige für andere Seiten: Nur Uhrzeit
      statusWidget = Text(
        _formatTime(created),
        style: TextStyle(
          fontSize: 12,
          color: textColor,
        ),
        textAlign: isRtl ? TextAlign.right : TextAlign.left,
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: statusWidget,
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: ui.TextDirection.ltr,
          children: [
            if (type == WishCardType.offen &&
                (showWishCount || hasGreeting || showFavorite))
              const SizedBox(width: 2),
            if (showWishCount)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: UIConstants.frameAbgelehnt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalWishes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (showWishCount && hasGreeting) const SizedBox(width: 8),
            if (hasGreeting)
              const Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: UIConstants.frameOffen,
              ),
            if (hasGreeting && showFavorite) const SizedBox(width: 8),
            if (showFavorite)
              Builder(
                builder: (context) {
                  final isFree = UserService().currentUser.value?.isFree ?? true;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (isFree) {
                          FreeFeatureLockedDialog.show(
                            context,
                            title: l.free_feature_favorites_title,
                            description:
                                l.free_feature_favorites_description,
                          );
                          return;
                        }
                        _toggleFavorite(context, docIds!.first);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: isFree
                                ? UIConstants.freeLimitBorderRed
                                : (isFavorite
                                      ? UIConstants.frameNoParty
                                      : Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  _WishTimeSummary _resolveWishTimeSummary(
    Map<String, dynamic> cardData,
    DateTime fallbackCreated,
  ) {
    final source = groupedData ?? cardData;
    final createdAtList = (source['createdAt_list'] as List?) ?? [];
    final dates = createdAtList
        .map((ts) {
          if (ts is Timestamp) return ts.toDate();
          if (ts is DateTime) return ts;
          return null;
        })
        .whereType<DateTime>()
        .toList();

    DateTime? oldest;
    DateTime? latest;
    if (dates.isNotEmpty) {
      dates.sort((a, b) => a.compareTo(b));
      oldest = dates.first;
      latest = dates.last;
    }

    final oldestFromGroup = source['oldest_createdAt'];
    if (oldest == null && oldestFromGroup is Timestamp) {
      oldest = oldestFromGroup.toDate();
    }
    final latestFromGroup = source['latest_createdAt'];
    if (latest == null && latestFromGroup is Timestamp) {
      latest = latestFromGroup.toDate();
    }

    oldest ??= fallbackCreated;
    latest ??= oldest;

    int additionalWishesCount = 0;
    final additionalFromGroup = source['additional_wishes_count'];
    if (additionalFromGroup is int && additionalFromGroup >= 0) {
      additionalWishesCount = additionalFromGroup;
    } else {
      final totalWishes = wishCountForBadge(cardData, groupedData);
      additionalWishesCount = totalWishes > 1 ? totalWishes - 1 : 0;
    }

    return _WishTimeSummary(
      oldestWishDate: oldest,
      latestWishDate: latest,
      additionalWishesCount: additionalWishesCount,
    );
  }

  String _buildAdditionalWishInfo(
    BuildContext context,
    AppLocalizations l,
    _WishTimeSummary summary,
  ) {
    final baseText = l.wishAdditionalRequests(summary.additionalWishesCount);
    final latest = _formatTimeForLocale(context, summary.latestWishDate);
    return '$baseText | ${l.last_request_label}: $latest';
  }

  /// Zeile 2: Kompakte Musik-Zeile (Titel + Interpret)
  Widget _buildCompactMusicRow(
    BuildContext context,
    String title,
    String artist,
    bool autoRecognized,
    WishCardType type,
    bool isRtl,
    Color textColor,
    AppLocalizations l, {
    bool isDjWish = false,
  }) {
    return Column(
      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          children: [
            // DJ-Wunsch-Icon (von DJ hinzugefügt)
            if (isDjWish)
              Padding(
                padding: EdgeInsets.only(
                  right: isRtl ? 0 : 6,
                  left: isRtl ? 6 : 0,
                ),
                child: const Icon(
                  Icons.headset_mic,
                  size: 14,
                  color: UIConstants.appOrange,
                ),
              ),
            if (autoRecognized)
              Padding(
                padding: EdgeInsets.only(
                  right: isRtl ? 0 : 6,
                  left: isRtl ? 6 : 0,
                ),
                child: Tooltip(
                  message: l.automatically_recognized,
                  child: Semantics(
                    label: l.automatically_recognized,
                    button: false,
                    image: false,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: type == WishCardType.gespielt
                          ? _kAutoRecognizedIconGespielt
                          : UIConstants.frameOffen,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Text(
                title.isNotEmpty
                    ? (() {
                        final label = type == WishCardType.gespielt
                            ? l.history_label_title
                            : l.wish_title_label;
                        return '${_getLabelWithoutColon(label)}: $title';
                      })()
                    : l.no_title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              ),
            ),
            // Anzahl der Wünsche beim Titel ENTFERNT - wird jetzt nur noch oben rechts angezeigt
            // (Keine Anzeige mehr beim Titel für Offen-Seite)
          ],
        ),
                              if (artist.isNotEmpty) ...[
          const SizedBox(height: 4),
                                Text(
            '${_getLabelWithoutColon(l.wish_artist_label)}: $artist',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor.withValues(alpha: 0.9),
                                  ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                                ),
                              ],
                            ],
    );
  }

  /// Zeile 3: Namen aller Wünscher (kommagetrennt)
  Widget _buildWishersNamesRow(
    BuildContext context,
    List<Map<String, dynamic>> wishersList,
    bool isRtl,
    Color textColor,
    AppLocalizations l,
  ) {
    return Column(
      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_getLabelWithoutColon(l.requested_by)}:',
          style: TextStyle(
            fontSize: 11,
            color: textColor.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        ),
        const SizedBox(height: 4),
        Wrap(
      spacing: 4,
      runSpacing: 4,
      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: wishersList.asMap().entries.map((entry) {
        final index = entry.key;
        final wisher = entry.value;
        final wisherName = wisher['name'] as String;
        final isRegisteredUser = wisher['isRegistered'] as bool;

        return Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          children: [
            Text(
              wisherName,
                              style: TextStyle(
                fontSize: 12,
                color: isRegisteredUser ? UIConstants.frameGespielt : textColor.withValues(alpha: 0.8),
                fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (index < wishersList.length - 1)
              Padding(
                padding: EdgeInsets.only(
                  right: isRtl ? 0 : 4,
                  left: isRtl ? 4 : 0,
                            ),
                            child: Text(
                  ',',
                              style: TextStyle(
                                fontSize: 12,
                    color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
        );
      }).toList(),
        ),
      ],
    );
  }

  /// Wünscher-Liste im Dialog (vertikale Liste)
  Widget _buildWishersRow(
    BuildContext context,
    List<Map<String, dynamic>> wishersList,
    bool isRtl,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: wishersList.map((wisher) {
        final wisherName = wisher['name'] as String;
        final wisherGreeting = wisher['greeting'] as String;
        final isRegisteredUser = wisher['isRegistered'] as bool;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
              // Name-Tag mit Rahmen (nur so breit wie der Name)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isRegisteredUser ? UIConstants.frameGespielt : Colors.grey.shade700,
                    width: 1,
                  ),
                            ),
                            child: Text(
                  wisherName,
                              style: TextStyle(
                    fontSize: 14,
                    color: isRegisteredUser ? UIConstants.frameGespielt : textColor,
                    fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                ),
              ),
              // Grußtext direkt neben dem Namen
              if (wisherGreeting.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                        children: [
                      // Original-Grußtext
                            Text(
                        wisherGreeting,
                              style: TextStyle(
                          fontSize: 14,
                                color: secondaryTextColor,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                      ),
                      // Übersetzung (asynchron geladen)
                      FutureBuilder<String?>(
                        future: GreetingTranslator.translateGreetingIfNeeded(wisherGreeting, context),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            // Minimaler Lade-Indikator
                            return const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: SizedBox(
                                height: 12,
                                width: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Color(0xFFB0B0B0),
                                ),
                              ),
                            );
                          }
                          
                          if (snapshot.hasData && snapshot.data != null) {
                            // Übersetzung vorhanden
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                            Icon(
                                    Icons.translate,
                              size: 14,
                                    color: secondaryTextColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                      snapshot.data!,
                                style: TextStyle(
                                        fontSize: 13,
                                        color: secondaryTextColor.withValues(alpha: 0.8),
                                        fontStyle: FontStyle.italic,
                                ),
                                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                                      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                              ),
                            ),
                          ],
                              ),
                            );
                          }
                          
                          // Keine Übersetzung nötig oder Fehler
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
            ),
          ),
        );
      }).toList(),
      ),
    );
  }

  /// Zeigt Detail-Modal mit allen Informationen und Aktionen.
  /// [borderColorOverride]: optionale Rahmenfarbe für den Dialog (sonst aus [type] abgeleitet).
  Future<void> _showDetailModal(
    BuildContext context,
    Map<String, dynamic> data,
    SongRequest? request,
    List<String>? docIds,
    DateTime created,
    DateTime? played,
    DateTime? rejected,
    WishCardType type,
    bool isNew,
    bool autoRecognized,
    bool autoRejectedByBlock,
    List<Map<String, dynamic>> wishersList,
    String title,
    String artist,
    AppLocalizations l,
    Color? borderColorOverride,
  ) async {
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    const textColor = Colors.white;
    const secondaryTextColor = Color(0xFFB0B0B0);
    final borderColor = borderColorOverride ?? _getBorderColor(type, false, true);

    // Für Offen-Seite: Markiere Wünsche als gelesen, wenn Detail-Dialog geöffnet wird
    if (type == WishCardType.offen && docIds != null && docIds.isNotEmpty) {
      await WishCard._markWishesAsSeen(docIds);
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Directionality(
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: borderColor,
              width: 2.0,
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 20.0), // Minimales Padding oben für Icons
                  child: Container(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Aktions-Leiste ganz oben (schmal)
                          if (type == WishCardType.offen && !autoRejectedByBlock)
                          Align(
                            alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                            child: _buildDetailActionIconsRow(
                              context,
                              type,
                              isRtl,
                              l,
                              title,
                              artist,
                              data,
                              request,
                              docIds,
                              setModalState, // Füge setModalState hinzu für Updates
                            ),
                          )
                    else if (autoRejectedByBlock)
                      Align(
                        alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          children: [
                            const Icon(
                              Icons.block,
                              color: UIConstants.frameGesperrt,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l.blocked,
                              style: const TextStyle(
                                color: UIConstants.frameGesperrt,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                        // Status-Zeile (Eingang, Gespielt um, Abgelehnt) für Gespielt- und Abgelehnt-Ansicht
                        if (type == WishCardType.gespielt || type == WishCardType.abgelehnt) ...[
                          _buildDetailStatusRow(context, data, created, played, rejected, type, isRtl, textColor, l),
                          const SizedBox(height: 8),
                        ],
                        // Song-Info Box direkt unter Icons (Haupt-Fokus)
                        const SizedBox(height: 8),
                        _buildDetailSongSection(context, title, artist, data, isNew, autoRecognized, isRtl, textColor, l, type),
                        // Gewünschte Versionen (abweichende Titel innerhalb der Gruppe)
                        if ((data['title_variants'] as List?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          _buildDetailTitleVariantsSection(
                            context,
                            List<String>.from((data['title_variants'] as List?)?.whereType<String>() ?? []),
                            isRtl,
                            textColor,
                            l,
                          ),
                        ],
                          // Wünscher-Liste: Absender-Zeile (hervorgehoben) + Gruß-Zelle (Abschluss)
                          if (wishersList.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailWishersTable(context, wishersList, data, docIds, isRtl, textColor, secondaryTextColor, l, type, played, rejected),
                          ],
                          if (type == WishCardType.gespielt && onUndo != null) ...[
                            const SizedBox(height: 12),
                            _buildPlayedRestoreButton(context, isRtl, l, onUndo!),
                          ] else if (type == WishCardType.abgelehnt && onRestore != null) ...[
                            const SizedBox(height: 12),
                            _buildRejectedRestoreToOpenButton(context, isRtl, l, onRestore!),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Status-Zeile im Detail-Modal
  Widget _buildDetailStatusRow(
    BuildContext context,
    Map<String, dynamic> data,
    DateTime created,
    DateTime? played,
    DateTime? rejected,
    WishCardType type,
    bool isRtl,
    Color textColor,
    AppLocalizations l,
  ) {
    final summary = _resolveWishTimeSummary(data, created);
    final oldestRequestedTime = _formatClockWithSuffixForLocale(
      context,
      summary.oldestWishDate,
      l,
    );

    return Container(
      width: double.infinity,
      child: Align(
        alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          alignment: isRtl ? WrapAlignment.end : WrapAlignment.start,
          children: [
                          Text(
              '${_getLabelWithoutColon(l.requested_at)}: $oldestRequestedTime',
                            style: TextStyle(
                              fontSize: 12,
                color: textColor,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            ),
            if (played != null)
              Text(
                '${_getLabelWithoutColon(l.played)}: ${_formatClockWithSuffixForLocale(context, played, l)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: UIConstants.frameGespielt,
                ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              ),
            if (rejected != null)
                          Text(
                '${_getLabelWithoutColon(l.rejected)}: ${_formatClockWithSuffixForLocale(context, rejected, l)}',
                            style: TextStyle(
                              fontSize: 12,
                  color: type == WishCardType.abgelehnt ? UIConstants.frameAbgelehnt : UIConstants.frameGesperrt,
                ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              ),
          ],
        ),
      ),
    );
  }

  /// Zeigt im Detail-Modal die Liste der gewünschten Versionen (abweichende Titel innerhalb der Gruppe).
  Widget _buildDetailTitleVariantsSection(
    BuildContext context,
    List<String> titleVariants,
    bool isRtl,
    Color textColor,
    AppLocalizations l,
  ) {
    if (titleVariants.isEmpty) return const SizedBox.shrink();
    final label = l.requested_versions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            alignment: isRtl ? WrapAlignment.end : WrapAlignment.start,
            children: titleVariants.map((v) => Text(
              v,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB0B0B0),
                fontStyle: FontStyle.italic,
              ),
              textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            )).toList(),
          ),
        ],
      ),
    );
  }

  /// Lädt Genres aus wunschbox_titel basierend auf spotify_id
  Future<List<String>> _loadGenresFromMusicDatabase(String? spotifyId) async {
    if (spotifyId == null || spotifyId.isEmpty) {
      return [];
    }
    
    try {
      // Suche Titel mit dieser spotify_id
      final titlesSnapshot = await FirebaseFirestore.instance
          .collection('wunschbox_titel')
          .where('spotify_id', isEqualTo: spotifyId)
          .limit(1)
          .get();

      if (titlesSnapshot.docs.isEmpty) {
        return [];
      }

      final titleDoc = titlesSnapshot.docs[0];
      final titleData = titleDoc.data();
      final genreIds = titleData['genre_ids'] as List<dynamic>? ?? [];

      // Lade Genre-Namen aus wunschbox_genres
      List<String> genreNames = [];
      if (genreIds.isNotEmpty) {
        final genrePromises = genreIds.map((genreId) async {
          final genreDoc = await FirebaseFirestore.instance
              .collection('wunschbox_genres')
              .doc(genreId.toString())
              .get();
          if (genreDoc.exists) {
            final genreName = genreDoc.data()?['name'] as String?;
            return genreName;
          }
          return null;
        });
        
        final genreResults = await Future.wait(genrePromises);
        genreNames = genreResults.whereType<String>().toList();
      }

      return genreNames;
    } catch (e) {
      debugLog('❌ Fehler beim Laden der Genres aus Musikdatenbank: $e');
      return [];
    }
  }

  /// Song-Bereich im Detail-Dialog: Titel, Interpret, optional Spotify-Daten
  /// Design: Abgerundete Box mit dunklem Grau-Hintergrund
  Widget _buildDetailSongSection(
    BuildContext context,
    String title,
    String artist,
    Map<String, dynamic> data,
    bool isNew,
    bool autoRecognized,
    bool isRtl,
    Color textColor,
    AppLocalizations l,
    WishCardType cardType,
  ) {
    final length = data['length'] as int?; // Länge in Sekunden (aus Shazam)
    // Sichere Typ-Konvertierung für duration_ms (int, double oder num)
    int? durationMs;
    final durationMsValue = data['duration_ms'];
    if (durationMsValue != null) {
      if (durationMsValue is int) {
        durationMs = durationMsValue;
      } else if (durationMsValue is double) {
        durationMs = durationMsValue.toInt();
      } else if (durationMsValue is num) {
        durationMs = durationMsValue.toInt();
      }
    }
    final spotifyId = data['spotify_id'] as String?;
    final genresFromWish = data['genres'] as List<dynamic>?; // Genres aus dem Wunsch (Fallback)
    // Browser-Sprache (neu) oder Fallback auf guest_country (alt)
    final browserLanguage = data['browser_language'] as String?;
    final guestCountry = data['guest_country'] as String?; // Fallback für alte Daten
    final displayLanguage = browserLanguage ?? guestCountry; // Priorisiere browser_language
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF333333), // Deutlich helleres Grau für besseren Kontrast
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titel mit Label
          Row(
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            children: [
              if (autoRecognized)
                Padding(
                  padding: EdgeInsets.only(
                    right: isRtl ? 0 : 6,
                    left: isRtl ? 6 : 0,
                  ),
                  child: Tooltip(
                    message: l.automatically_recognized,
                    child: Semantics(
                      label: l.automatically_recognized,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: cardType == WishCardType.gespielt
                            ? _kAutoRecognizedIconGespielt
                            : UIConstants.frameOffen,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_getLabelWithoutColon(l.wish_title_label)}:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title.isNotEmpty ? title : (l.no_title),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                        height: 1.25,
                      ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Interpret mit Label
          if (artist.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_getLabelWithoutColon(l.wish_artist_label)}:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artist,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          // Spotify-Daten (Länge, Genres, Sprache) wenn vorhanden
          if (length != null || durationMs != null || spotifyId != null || displayLanguage != null) ...[
            const SizedBox(height: 12),
            FutureBuilder<List<String>>(
              future: spotifyId != null ? _loadGenresFromMusicDatabase(spotifyId) : Future.value([]),
              builder: (context, snapshot) {
                // Verwende Genres aus Musikdatenbank, falls vorhanden, sonst Fallback auf Wunsch-Daten
                final genresFromDb = snapshot.data ?? [];
                final finalGenres = genresFromDb.isNotEmpty 
                    ? genresFromDb 
                    : (genresFromWish?.map((g) => g.toString()).toList() ?? []);
                
                // Berechne finale Länge (priorisiere duration_ms aus Spotify)
                final finalDurationSeconds = durationMs != null 
                    ? durationMs ~/ 1000 
                    : length;
                
                if (finalDurationSeconds == null && finalGenres.isEmpty && displayLanguage == null) {
                  return const SizedBox.shrink();
                }
                
                return Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  children: [
                    if (finalDurationSeconds != null)
                      Text(
                        _formatDuration(finalDurationSeconds),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    if (finalGenres.isNotEmpty)
                      Text(
                        finalGenres.join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    if (displayLanguage != null && displayLanguage.isNotEmpty && displayLanguage != 'unknown')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.language,
                            size: 12,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            displayLanguage.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Formatiert Sekunden in MM:SS Format
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Wünscher-Liste im Detail-Dialog: Name in Zeile 1, Zeit + relative Dauer in Zeile 2.
  Widget _buildDetailWishersTable(
    BuildContext context,
    List<Map<String, dynamic>> wishersList,
    Map<String, dynamic> data,
    List<String>? docIds,
    bool isRtl,
    Color textColor,
    Color secondaryTextColor,
    AppLocalizations l,
    WishCardType type,
    DateTime? played,
    DateTime? rejected,
  ) {
    final fallbackCreated = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final summary = _resolveWishTimeSummary(data, fallbackCreated);
    final createdAtList = groupedData != null ? (groupedData!['createdAt_list'] as List?) : null;

    final wishTimes = (createdAtList ?? [])
        .map((ts) => ts is Timestamp ? ts.toDate() : null)
        .whereType<DateTime>()
        .toList();

    if (wishTimes.isEmpty && data['createdAt'] is Timestamp) {
      wishTimes.add((data['createdAt'] as Timestamp).toDate());
    }

    final pairedWishers = <Map<String, dynamic>>[];
    for (int i = 0; i < wishersList.length; i++) {
      final wisher = wishersList[i];
      final fallback = summary.oldestWishDate;
      final createdAt = i < wishTimes.length ? wishTimes[i] : fallback;
      pairedWishers.add({
        'name': wisher['name'] as String? ?? '',
        'greeting': wisher['greeting'] as String? ?? '',
        'isRegistered': wisher['isRegistered'] as bool? ?? false,
        'createdAt': createdAt,
      });
    }

    if (pairedWishers.isEmpty) {
      return const SizedBox.shrink();
    }

    pairedWishers.sort((a, b) {
      final aDate = a['createdAt'] as DateTime? ?? summary.oldestWishDate;
      final bDate = b['createdAt'] as DateTime? ?? summary.oldestWishDate;
      return aDate.compareTo(bDate);
    });

    return Column(
      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: pairedWishers.map((wisher) {
        final name = wisher['name'] as String? ?? '';
        final greeting = wisher['greeting'] as String? ?? '';
        final isRegistered = wisher['isRegistered'] as bool? ?? false;
        final createdAt =
            wisher['createdAt'] as DateTime? ?? summary.oldestWishDate;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isRegistered ? UIConstants.frameGespielt : UIConstants.appOrange,
                ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              ),
              const SizedBox(height: 2),
              Text(
                _buildDetailTimeWithRelative(context, createdAt, l),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: secondaryTextColor,
                ),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (greeting.isNotEmpty) ...[
                const SizedBox(height: 6),
                FutureBuilder<String?>(
                  future: GreetingTranslator.translateGreetingIfNeeded(greeting, context),
                  builder: (context, snapshot) {
                    final hasTranslation =
                        snapshot.hasData && snapshot.data != null && snapshot.data != greeting;
                    final translation = snapshot.data;

                    return Column(
                      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipPath(
                          clipper: _ChatBubbleClipper(isRtl: isRtl),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: UIConstants.frameOffen.withValues(alpha: 0.15),
                              border: Border.all(
                                color: UIConstants.frameOffen.withValues(alpha: 0.5),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              greeting,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              textAlign: isRtl ? TextAlign.right : TextAlign.left,
                              textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                            ),
                          ),
                        ),
                        if (hasTranslation && translation != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                            children: [
                              Icon(
                                Icons.translate,
                                size: 12,
                                color: secondaryTextColor.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  translation,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.yellow,
                                  ),
                                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                                  textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  String _buildDetailTimeWithRelative(
    BuildContext context,
    DateTime wishDate,
    AppLocalizations l,
  ) {
    final clockTime = _formatClockWithSuffixForLocale(context, wishDate, l);
    final elapsed = RelativeTimeMinutes.elapsedCalendarMinutes(
      wishDate,
      DateTime.now(),
    );

    String relativeText;
    if (elapsed <= 0) {
      relativeText = l.history_time_just_now;
    } else {
      relativeText = elapsed < 60
          ? (l.wishSinceMinutes(elapsed))
          : (l.wishSinceHoursMinutes(elapsed ~/ 60, elapsed % 60));
    }

    return '$clockTime ($relativeText)';
  }

  /// Gespielt: Bestätigung → Detail schließen → [onUndo] (sync).
  Widget _buildPlayedRestoreButton(
    BuildContext context,
    bool isRtl,
    AppLocalizations l,
    VoidCallback onUndo,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmed = await RejectedWishReopenConfirmDialog.show(context);
          if (confirmed != true || !context.mounted) return;
          Navigator.of(context).pop();
          onUndo();
        },
        icon: const Icon(Icons.refresh, color: UIConstants.frameOffen),
        label: Text(l.back_to_open),
        style: ElevatedButton.styleFrom(
          backgroundColor: UIConstants.frameOffen.withValues(alpha: 0.3),
          foregroundColor: UIConstants.frameOffen,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Abgelehnt: Bestätigung → [onRestore] mit Detail-[context]; nach erfolgreichem Firestore-Update schließt der Callback den Dialog und wechselt den Tab.
  Widget _buildRejectedRestoreToOpenButton(
    BuildContext context,
    bool isRtl,
    AppLocalizations l,
    Future<void> Function(BuildContext detailContext) onRestore,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmed = await RejectedWishReopenConfirmDialog.show(context);
          if (confirmed != true || !context.mounted) return;
          await onRestore(context);
        },
        icon: const Icon(Icons.refresh, color: UIConstants.frameOffen),
        label: Text(l.back_to_open),
        style: ElevatedButton.styleFrom(
          backgroundColor: UIConstants.frameOffen.withValues(alpha: 0.3),
          foregroundColor: UIConstants.frameOffen,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Aktions-Icons im Detail-Modal (nur in Offen-Ansicht)
  Widget _buildDetailActionIconsRow(
    BuildContext context,
    WishCardType type,
    bool isRtl,
    AppLocalizations l,
    String title,
    String artist,
    Map<String, dynamic> data,
    SongRequest? request,
    List<String>? docIds,
    [StateSetter? setModalState,]
  ) {
    final displayText = title.isNotEmpty && artist.isNotEmpty
        ? '$title - $artist'
        : (title.isNotEmpty ? title : artist);
    final isGrouped = docIds != null && docIds.length > 0;
    final firstRequest = request ?? _mapToRequest(data);

    return Row(
      mainAxisAlignment: isRtl ? MainAxisAlignment.start : MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      children: [
        // Grüner Haken: Als gespielt markieren (nur Icon)
        if ((isGrouped && onPlay != null) || (!isGrouped && onPlaySingle != null))
          IconButton(
            onPressed: () {
              // Extrahiere partyId aus data oder request
              final partyId = data['party_id'] as String? ?? request?.partyId;
              if (partyId == null || partyId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fehler: Keine Party-ID gefunden'), backgroundColor: UIConstants.frameNoParty),
                );
                return;
              }
              
              if (isGrouped && docIds != null && docIds!.isNotEmpty) {
                WishManagementService.showConfirmUpdateGroupedStatusDialog(
                  context,
                  docIds!,
                  'played',
                  l.mark_as_played,
                  displayText,
                  partyId,
                );
              } else if (!isGrouped && request?.id != null) {
                WishManagementService.showConfirmUpdateGroupedStatusDialog(
                  context,
                  [request!.id],
                  'played',
                  l.mark_as_played,
                  displayText,
                  partyId,
                );
              }
            },
            icon: const Icon(Icons.check_circle, color: UIConstants.frameGespielt, size: 24),
            tooltip: l.played,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        if ((isGrouped && onPlay != null) || (!isGrouped && onPlaySingle != null))
          const SizedBox(width: 8),
        // Orange Cancel-Icon: Ablehnen
        if ((isGrouped && onReject != null) || (!isGrouped && onRejectSingle != null))
          IconButton(
            onPressed: () {
              debugLog('>>> UI-KLICK: Ablehnen-Button wurde gedrückt!');
              // Extrahiere partyId aus data oder request
              final partyId = data['party_id'] as String? ?? request?.partyId;
              if (partyId == null || partyId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fehler: Keine Party-ID gefunden'), backgroundColor: UIConstants.frameNoParty),
                );
                return;
              }
              
              if (isGrouped && docIds != null && docIds!.isNotEmpty) {
                WishManagementService.showConfirmUpdateGroupedStatusDialog(
                  context,
                  docIds!,
                  'rejected',
                  l.reject,
                  displayText,
                  partyId,
                );
              } else if (!isGrouped && request?.id != null) {
                WishManagementService.showConfirmUpdateGroupedStatusDialog(
                  context,
                  [request!.id],
                  'rejected',
                  l.reject,
                  displayText,
                  partyId,
                );
              }
            },
            icon: const Icon(Icons.cancel, color: UIConstants.frameAbgelehnt, size: 24),
            tooltip: l.reject,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        if ((isGrouped && onReject != null) || (!isGrouped && onRejectSingle != null))
          const SizedBox(width: 8),
        // Rotes Delete-Icon: Löschen
        if ((isGrouped && onDelete != null) || (!isGrouped && onDeleteSingle != null))
          IconButton(
            onPressed: () {
              debugLog('>>> UI-KLICK: Löschen-Button wurde gedrückt!');
              // Extrahiere partyId aus data oder request
              final partyId = data['party_id'] as String? ?? request?.partyId;
              if (partyId == null || partyId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fehler: Keine Party-ID gefunden'), backgroundColor: UIConstants.frameNoParty),
                );
                return;
              }
              
              if (isGrouped && docIds != null && docIds!.isNotEmpty) {
                WishManagementService.showConfirmDeleteGroupedDialog(
                  context,
                  docIds!,
                  displayText,
                  partyId,
                );
              } else if (!isGrouped && request?.id != null) {
                WishManagementService.showConfirmDeleteGroupedDialog(
                  context,
                  [request!.id],
                  displayText,
                  partyId,
                );
              }
            },
            icon: const Icon(Icons.delete_forever, color: UIConstants.frameGesperrt, size: 24),
            tooltip: l.delete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        if ((isGrouped && onDelete != null) || (!isGrouped && onDeleteSingle != null))
          const SizedBox(width: 8),
        // Rote Sperrscheibe: Sperren (nur Icon) – für Free-DJs: Pro-Dialog mit Paywall-Hinweis
        if ((isGrouped && onBlockGrouped != null) || (!isGrouped && onBlockSingle != null))
          Builder(
            builder: (context) {
              final isFreeBlock = UserService().currentUser.value?.isFree ?? true;
              return IconButton(
                onPressed: () {
                  if (isFreeBlock) {
                    FreeFeatureLockedDialog.show(
                      context,
                      title: l.free_feature_guest_block_title,
                      description: l.free_feature_guest_block_description,
                    );
                    return;
                  }
                  _showBlockDialog(
                    context,
                    firstRequest,
                    data,
                    docIds,
                    isGrouped,
                    l,
                  );
                },
                icon: const Icon(Icons.block, color: UIConstants.frameGesperrt, size: 24),
                tooltip: l.block,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            },
          ),
      ],
    );
  }

  /// Alte Aktions-Icons-Methode (nicht mehr verwendet, aber für Kompatibilität behalten)
  Widget _buildActionIconsRow(
    BuildContext context,
    WishCardType type,
    bool autoRejectedByBlock,
    bool isRtl,
    AppLocalizations l,
    String title,
    String artist,
    Map<String, dynamic> data,
    SongRequest? request,
    List<String>? docIds,
  ) {
    if (autoRejectedByBlock) {
      return Row(
                  mainAxisSize: MainAxisSize.min,
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  children: [
                    const Icon(
                      Icons.block,
            color: UIConstants.frameGesperrt,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
            l.blocked,
                      style: const TextStyle(
              color: UIConstants.frameGesperrt,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
      );
    }

    // Nur in Offen-Ansicht: 3 Icons
    if (type == WishCardType.offen) {
      final displayText = title.isNotEmpty && artist.isNotEmpty
          ? '$title - $artist'
          : (title.isNotEmpty ? title : artist);
      final isGrouped = docIds != null && docIds.length > 0;
      final firstRequest = request ?? _mapToRequest(data);

      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        children: [
          // Spacer: schiebt Icons nach außen (rechts bei LTR, links bei RTL)
          const Spacer(),
          // Grüner Haken: Als gespielt markieren
          if ((isGrouped && onPlay != null) || (!isGrouped && onPlaySingle != null))
            IconButton(
              icon: const Icon(Icons.check_circle, color: UIConstants.frameGespielt, size: 24),
              tooltip: l.played,
              onPressed: () {
                // Extrahiere partyId aus data oder request
                final partyId = data['party_id'] as String? ?? request?.partyId;
                if (partyId == null || partyId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fehler: Keine Party-ID gefunden'), backgroundColor: UIConstants.frameNoParty),
                  );
                  return;
                }
                
                if (isGrouped && docIds != null && docIds!.isNotEmpty) {
                  WishManagementService.showConfirmUpdateGroupedStatusDialog(
                    context,
                    docIds!,
                    'played',
                    l.mark_as_played,
                    displayText,
                    partyId,
                  );
                } else if (!isGrouped && request?.id != null) {
                  WishManagementService.showConfirmUpdateGroupedStatusDialog(
                    context,
                    [request!.id],
                    'played',
                    l.mark_as_played,
                    displayText,
                    partyId,
                  );
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 8),
          // Orange Cancel-Icon: Ablehnen
          if ((isGrouped && onReject != null) || (!isGrouped && onRejectSingle != null))
            IconButton(
              icon: const Icon(Icons.cancel, color: UIConstants.frameAbgelehnt, size: 24),
              tooltip: l.reject,
              onPressed: () {
                debugLog('>>> UI-KLICK: Ablehnen-Button wurde gedrückt!');
                // Extrahiere partyId aus data oder request
                final partyId = data['party_id'] as String? ?? request?.partyId;
                if (partyId == null || partyId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fehler: Keine Party-ID gefunden'), backgroundColor: UIConstants.frameNoParty),
                  );
                  return;
                }
                
                if (isGrouped && docIds != null && docIds!.isNotEmpty) {
                  WishManagementService.showConfirmUpdateGroupedStatusDialog(
                    context,
                    docIds!,
                    'rejected',
                    l.reject,
                    displayText,
                    partyId,
                  );
                } else if (!isGrouped && request?.id != null) {
                  WishManagementService.showConfirmUpdateGroupedStatusDialog(
                    context,
                    [request!.id],
                    'rejected',
                    l.reject,
                    displayText,
                    partyId,
                  );
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if ((isGrouped && onReject != null) || (!isGrouped && onRejectSingle != null))
            const SizedBox(width: 8),
          // Rotes Delete-Icon: Löschen
          if ((isGrouped && onDelete != null) || (!isGrouped && onDeleteSingle != null))
            IconButton(
              icon: const Icon(Icons.delete_forever, color: UIConstants.frameGesperrt, size: 24),
              tooltip: l.delete,
              onPressed: () {
                debugLog('>>> UI-KLICK: Löschen-Button wurde gedrückt!');
                // Extrahiere partyId aus data oder request
                final partyId = data['party_id'] as String? ?? request?.partyId;
                if (partyId == null || partyId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fehler: Keine Party-ID gefunden'), backgroundColor: UIConstants.frameNoParty),
                  );
                  return;
                }
                
                if (isGrouped && docIds != null && docIds!.isNotEmpty) {
                  WishManagementService.showConfirmDeleteGroupedDialog(
                    context,
                    docIds!,
                    displayText,
                    partyId,
                  );
                } else if (!isGrouped && request?.id != null) {
                  WishManagementService.showConfirmDeleteGroupedDialog(
                    context,
                    [request!.id],
                    displayText,
                    partyId,
                  );
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if ((isGrouped && onDelete != null) || (!isGrouped && onDeleteSingle != null))
            const SizedBox(width: 8),
          // Rote Sperrscheibe: Sperren – für Free-DJs: Pro-Dialog mit Paywall-Hinweis
          if ((isGrouped && onBlockGrouped != null) || (!isGrouped && onBlockSingle != null))
            Builder(
              builder: (context) {
                final isFreeBlock = UserService().currentUser.value?.isFree ?? true;
                return IconButton(
                  icon: const Icon(Icons.block, color: UIConstants.frameGesperrt, size: 24),
                  tooltip: l.block,
                  onPressed: () {
                    if (isFreeBlock) {
                      FreeFeatureLockedDialog.show(
                        context,
                        title: l.free_feature_guest_block_title,
                        description: l.free_feature_guest_block_description,
                      );
                      return;
                    }
                    _showBlockDialog(
                      context,
                      firstRequest,
                      data,
                      docIds,
                      isGrouped,
                      l,
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                );
              },
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// Erstellt sortierte Liste der Wünscher (ältester zuerst)
  List<Map<String, dynamic>> _buildWishersList(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> greetings,
    String greeting,
    String name,
    List<String> namesToShow,
    Map<String, bool> isRegisteredUsers,
  ) {
    final List<Map<String, dynamic>> wishersList = [];
    final remainingGreetings = List<Map<String, dynamic>>.from(greetings);

    // Reihenfolge von namesToShow beibehalten (bei Gruppierung = neueste zuerst, parallel zu createdAt_list)
    for (int i = 0; i < namesToShow.length; i++) {
      final wisherName = namesToShow[i];
      final isRegistered = isRegisteredUsers[wisherName] ??
          (wisherName.contains('@') &&
              wisherName.split('@').length == 2 &&
              wisherName.split('@')[1].contains('.'));

      String wisherGreeting = '';
      final greetingIndex = remainingGreetings.indexWhere(
        (g) => (g['name'] as String? ?? '') == wisherName,
      );
      if (greetingIndex >= 0) {
        final greetingEntry = remainingGreetings.removeAt(greetingIndex);
        wisherGreeting = greetingEntry['greeting'] as String? ?? '';
      } else if (greeting.isNotEmpty && namesToShow.length == 1 && wisherName == name) {
        wisherGreeting = greeting;
      }

      wishersList.add({
        'name': wisherName,
        'greeting': wisherGreeting,
        'isRegistered': isRegistered,
        'index': i,
      });
    }

    wishersList.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    return wishersList;
  }



  /// Dialog: Sperren (mit Auswahlmenü bei mehreren Wünschern)
  Future<void> _showBlockDialog(
    BuildContext context,
    SongRequest firstRequest,
    Map<String, dynamic> data,
    List<String>? docIds,
    bool isGrouped,
    AppLocalizations l,
  ) async {
    final requestedBy = List<String>.from((data['requested_by'] as List?) ?? []);
    final name = (data['name'] ?? '') as String;
    final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
    final greetings = List<Map<String, dynamic>>.from(
      (data['greetings'] as List?)?.map((g) => g as Map<String, dynamic>) ?? [],
    );
    final greeting = (data['greeting'] ?? '') as String;

    // Wenn mehr als 1 Wünscher: Zeige Auswahlmenü
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    if (namesToShow.length > 1) {
      final remainingGreetings = List<Map<String, dynamic>>.from(greetings);
      final selectEntries = namesToShow.map((n) {
        final greetingIndex = remainingGreetings.indexWhere(
          (g) => (g['name'] as String? ?? '') == n,
        );
        String wisherGreeting = '';
        if (greetingIndex >= 0) {
          final entry = remainingGreetings.removeAt(greetingIndex);
          wisherGreeting = entry['greeting'] as String? ?? '';
        } else if (greeting.isNotEmpty && n == name) {
          wisherGreeting = greeting;
        }
        return {'name': n, 'greeting': wisherGreeting};
      }).toList();

      final selectedWisher = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => Directionality(
          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: _buildDarkDialog(
            context,
            title: l.block_user,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: selectEntries.map((entry) {
                final n = entry['name'] as String? ?? '';
                final wisherGreeting = entry['greeting'] as String? ?? '';

                return ListTile(
                  title: Text(
                    n,
                    style: const TextStyle(color: Colors.white),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  ),
                  subtitle: wisherGreeting.isNotEmpty
                      ? Text(
                          wisherGreeting,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left,
                          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, {'name': n, 'greeting': wisherGreeting}),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel, style: const TextStyle(color: Colors.white70)),
              ),
            ],
            isRtl: isRtl,
          ),
        ),
      );

      if (selectedWisher == null || !context.mounted) return;
    }

    // Zeige Sperr-Dialog (One-Click: Ja -> Sofort sperren)
    final userName = namesToShow.isNotEmpty ? namesToShow[0] : name;
    final shouldBlock = await showDialog<bool>(
      context: context,
      builder: (context) {
        String localizedText =
            AppLocalizations.of(context)!.translate('block_user_confirm');
        // Teile den Text beim Platzhalter %s auf
        final parts = localizedText.split('%s');
        final textBefore = parts.isNotEmpty ? parts[0] : '';
        final textAfter = parts.length > 1 ? parts[1] : '';
        
        return Directionality(
          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: Dialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                color: UIConstants.frameGesperrt,
                width: 2.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Zeile 1: Frage mit farblich hervorgehobenem User-Namen
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: textBefore,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: userName,
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: textAfter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  ),
                const SizedBox(height: 24),
                // Button-Reihe: Zwei Buttons
                Row(
                  textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Button 1: Ja (Rot) - führt Sperre SOFORT aus
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.frameGesperrt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(l.yes),
                    ),
                    // Button 2: Nein (Schlicht) - schließt Dialog
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800, // Schlichte Standardfarbe
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(l.no),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
    );

    // ONE-CLICK: Bei "Ja" sofort sperren, kein zweiter Dialog!
    if (shouldBlock == true && context.mounted) {
      // FENSTER-MANAGEMENT: Schließe alle offenen Dialoge sofort
      // Wichtig: Navigator.pop() mehrmals aufrufen, falls mehrere Dialoge offen sind
      int popCount = 0;
      while (Navigator.canPop(context) && popCount < 5) {
        Navigator.pop(context);
        popCount++;
      }
      debugLog('🚪 FENSTER-MANAGEMENT: $popCount Dialog(e) geschlossen');
      
      // Direkt blockUser aufrufen mit clientId und partyId aus firstRequest
      final clientId = firstRequest.clientId;
      final partyId = firstRequest.partyId;
      final userId = firstRequest.userId;
      final name = firstRequest.name ?? userName;
      
      debugLog('📡 ONE-CLICK: Direkte Sperre');
      
      // Rufe blockUser direkt auf (ohne zweiten Dialog)
      await UserBlockingService.blockUser(
        context,
        userId,
        clientId,
        name,
        partyId,
        firstRequest.id,
      );
    }
  }

  /// Erstellt Dialog mit dunklem Hintergrund
  Widget _buildDarkDialog(
    BuildContext context, {
    required String title,
    required Widget content,
    required List<Widget> actions,
    bool isRtl = false,
  }) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: UIConstants.frameAbgelehnt,
          width: 2.0,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
        textAlign: isRtl ? TextAlign.right : TextAlign.left,
      ),
      content: content,
      actionsAlignment: isRtl ? MainAxisAlignment.start : MainAxisAlignment.end,
      actions: actions,
    );
  }

  /// Konvertiert Map zu SongRequest (für Fallback)
  SongRequest _mapToRequest(Map<String, dynamic> data) {
    return SongRequest(
      id: '',
      title: (data['title'] ?? '') as String,
      artist: (data['artist'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      greeting: (data['greeting'] ?? '') as String,
      createdAt: data['createdAt'] as Timestamp?,
      status: 'pending',
      partyId: (data['party_id'] ?? '') as String, // ✅ FIX: partyId für Fallback-Sicherheit
      clientId: (data['client_id'] ?? '') as String, // ✅ FIX: clientId für Fallback-Sicherheit
    );
  }

  Map<String, dynamic> _requestToMap(SongRequest request) {
    return {
      'title': request.displayTitle,
      'artist': request.artist ?? '',
      'name': request.name ?? '',
      'greeting': request.greeting ?? '',
      'duplicate_count': request.duplicateCount ?? 0,
      'requested_by': request.requestedBy ?? [],
      'is_registered_users': request.isRegisteredUsers ?? {},
      'greetings': request.greetings ?? [],
      'createdAt': request.createdAt,
      'played_at': request.playedAt,
      'rejected_at': request.rejectedAt,
      'auto_rejected_by_block': request.autoRejectedByBlock ?? false,
      'auto_recognized': request.autoRecognized ?? false,
      'isSeen': request.isSeen, // ✅ FIX: isSeen Feld für Read-Status-Logik
      'is_dj_wish': request.isDjWish ?? false,
    };
  }

  /// Entfernt Doppelpunkte aus Labels, um doppelte Doppelpunkte zu vermeiden
  String _getLabelWithoutColon(String? label) {
    if (label == null) return '';
    return label.replaceAll(':', '').trim();
  }

  /// Formatiert Datum immer im LTR-Format (Tag.Monat.Jahr)
  /// Das Datum wird durch Directionality-Widget vor RTL-Spiegelung geschützt
  String _formatShortDate(DateTime date, bool isRtl) {
    // Immer LTR-Format: Tag.Monat.Jahr (z.B. 13.01.2026)
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} Uhr';
  }

  /// Formatiert die Uhrzeit basierend auf der Locale (Hm = 24h, jm = 12h je nach Sprachnorm)
  String _formatTimeForLocale(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context);
    // 24h-Locales (de, fr, ru, zh, es, tr, ar, pt) → Hm; 12h → jm
    final use24h = ['de', 'fr', 'ru', 'zh', 'es', 'tr', 'ar', 'pt'].contains(locale.languageCode);
    return use24h ? DateFormat.Hm(locale.toString()).format(date) : DateFormat.jm(locale.toString()).format(date);
  }

  String _formatClockWithSuffixForLocale(
    BuildContext context,
    DateTime date,
    AppLocalizations l,
  ) {
    final clock = _formatTimeForLocale(context, date);
    final suffix = (l.time_suffix).trim();
    if (suffix.isEmpty) return clock;
    return '$clock\u00A0$suffix';
  }

  /// Formatiert die Zeitdifferenz zwischen einem Zeitstempel und jetzt
  /// Format: "seit X Min." oder "seit X Std. Y Min."
  /// Nutzt L10n für alle 8 Sprachen
  String _formatTimeDuration(DateTime timestamp, BuildContext context, AppLocalizations l) {
    final now = DateTime.now();
    final elapsed = RelativeTimeMinutes.elapsedCalendarMinutes(timestamp, now);

    // Gleiche Kalender-Minute wie jetzt → „Gerade eben“; Zukunft ebenfalls abfangen
    if (elapsed < 0) {
      return l.history_time_just_now;
    }
    if (elapsed == 0) {
      return l.history_time_just_now;
    }

    final totalMinutes = elapsed;
    final totalHours = elapsed ~/ 60;
    
    // Lokalisierung
    final minutesShort = l.minutes_short;
    final hoursText = totalHours == 1 
        ? (l.party_hour)
        : (l.party_hours);
    
    // Bestimme die Sprache für "seit"
    final locale = Localizations.localeOf(context);
    final sinceText = _getSinceText(locale.languageCode);
    
    // Weniger als 1 Stunde: Nur Minuten anzeigen
    if (elapsed < 60) {
      return '$sinceText $totalMinutes $minutesShort';
    }
    
    // 1 Stunde oder mehr: Stunden und Minuten anzeigen
    final hours = totalHours;
    final minutes = totalMinutes % 60;
    
    if (minutes == 0) {
      // Nur Stunden
      return '$sinceText $hours $hoursText';
    } else {
      // Stunden und Minuten
      return '$sinceText $hours $hoursText $minutes $minutesShort';
    }
  }

  /// Gibt den lokalisierten Text für "seit" zurück basierend auf der Sprachkennung
  String _getSinceText(String languageCode) {
    switch (languageCode) {
      case 'de':
        return 'seit';
      case 'en':
        return 'since';
      case 'fr':
        return 'il y a';
      case 'es':
        return 'hace';
      case 'ru':
        return 'с';
      case 'zh':
        return '前';
      case 'tr':
        return 'önce';
      case 'pt':
        return 'há';
      default:
        return 'seit'; // Default für Deutsch
    }
  }

  /// Zeigt Grüße-Info-Dialog für Gespielt-Seite (nur Grüße, oranger Rahmen)
  Future<void> _showGreetingsInfoDialog(
    BuildContext context,
    List<Map<String, dynamic>> wishersList,
    bool isRtl,
    AppLocalizations l,
  ) async {
    final greetingsWithText = wishersList.where((w) => (w['greeting'] as String? ?? '').isNotEmpty).toList();
    if (greetingsWithText.isEmpty) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Directionality(
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: UIConstants.frameAbgelehnt,
              width: 2.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: "Gruß" - Mit Align-Widget für korrekte RTL-Positionierung
                Align(
                  alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    _getLabelWithoutColon(AppLocalizations.of(context)!.greeting),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 16),
                // Grüße-Liste mit Übersetzung
                ...greetingsWithText.map((w) {
                  final wisherName = w['name'] as String? ?? '';
                  final wisherGreeting = w['greeting'] as String? ?? '';
                  final isRegistered = w['is_registered'] as bool? ?? false;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // Name (fett, grün wenn registriert)
                        Align(
                          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                          child: Text(
                            wisherName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isRegistered ? UIConstants.frameGespielt : Colors.white,
                            ),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left,
                            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Original-Grußtext
                        Align(
                          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                          child: Text(
                            wisherGreeting,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFB0B0B0),
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left,
                            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          ),
                        ),
                        // Übersetzung (asynchron geladen)
                        FutureBuilder<String?>(
                          future: GreetingTranslator.translateGreetingIfNeeded(wisherGreeting, context),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              // Minimaler Lade-Indikator
                              return const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: SizedBox(
                                  height: 12,
                                  width: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0xFFB0B0B0),
                                  ),
                                ),
                              );
                            }
                            
                            if (snapshot.hasData && snapshot.data != null) {
                              // Übersetzung vorhanden
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Align(
                                  alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Row(
                                    textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.translate,
                                        size: 14,
                                        color: const Color(0xFFB0B0B0).withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          snapshot.data!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: const Color(0xFFB0B0B0).withValues(alpha: 0.8),
                                            fontStyle: FontStyle.italic,
                                          ),
                                          textAlign: isRtl ? TextAlign.right : TextAlign.left,
                                          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            // Keine Übersetzung nötig oder Fehler
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                // Schließen-Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UIConstants.frameAbgelehnt.withValues(alpha: 0.3),
                      foregroundColor: UIConstants.frameAbgelehnt,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      l.close,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bestimmt die Rahmenfarbe basierend auf Typ, Neu-Status und Gelesen-Status
  /// Verwendet UIConstants-Rollen (frameOffen, frameNeu, frameGespielt, frameAbgelehnt) für zentrale Steuerung
  static Color _getBorderColor(WishCardType type, bool isNew, bool effectivelySeen) {
    if (type == WishCardType.offen) {
      if (!effectivelySeen) {
        return UIConstants.frameNeu;
      }
      return UIConstants.frameOffen;
    }
    if (type == WishCardType.abgelehnt) {
      return UIConstants.frameAbgelehnt;
    }
    if (type == WishCardType.gespielt) {
      return UIConstants.frameGespielt;
    }
    return UIConstants.frameOffen;
  }

  /// Toggelt das is_favorite Feld für einen Wunsch
  static Future<void> _toggleFavorite(
    BuildContext context,
    String docId,
    [StateSetter? setModalState,
    Map<String, dynamic>? data,]
  ) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('wishes').doc(docId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        debugLog('⚠️ WishCard: Dokument $docId existiert nicht');
        return;
      }
      
      final currentFavorite = (docSnapshot.data()?['is_favorite'] as bool?) ?? false;
      await docRef.update({'is_favorite': !currentFavorite});
      
      debugLog('✅ WishCard: Favorit-Status für $docId geändert: ${!currentFavorite}');
      
      // Aktualisiere das Modal, wenn setModalState verfügbar ist
      if (setModalState != null && data != null) {
        setModalState(() {
          data['is_favorite'] = !currentFavorite;
        });
      }
    } catch (e) {
      debugLog('❌ WishCard: Fehler beim Togglen des Favorit-Status: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Aktualisieren des Favorit-Status'),
            backgroundColor: UIConstants.frameNoParty,
          ),
        );
      }
    }
  }

  /// Setzt isSeen auf true für alle angegebenen Dokument-IDs
  /// ✅ SYNCHRONISIERT: Aktualisiert beide Systeme (Firestore isSeen Feld + lokales seenWishIds Set)
  static Future<void> _markWishesAsSeen(List<String> docIds) async {
    if (docIds.isEmpty) return;
    
    try {
      // Weg 1: Aktualisiere Firestore isSeen Feld
      final batch = FirebaseFirestore.instance.batch();
      for (final docId in docIds) {
        final docRef = FirebaseFirestore.instance.collection('wishes').doc(docId);
        batch.update(docRef, {'isSeen': true});
      }
      await batch.commit();
      
      // Weg 2: Aktualisiere lokales seenWishIds Set (für sofortige UI-Aktualisierung)
      ActivePartyService.seenWishIds.addAll(docIds);
      
      debugLog('✅ ${docIds.length} Wünsche als gelesen markiert (Firestore + seenWishIds)');
    } catch (e) {
      debugLog('⚠️ Fehler beim Markieren der Wünsche als gelesen: $e');
    }
  }
}

/// Echtzeit-Anzeige der vergangenen Zeit seit Wunscherstellung (nur Offen-Liste / Detail offen).
/// Stream.periodic(minute) + StreamBuilder: nur dieser Teil rebuildet – kein Flackern der ganzen Karte.
class _WishTimeSummary {
  final DateTime oldestWishDate;
  final DateTime latestWishDate;
  final int additionalWishesCount;

  const _WishTimeSummary({
    required this.oldestWishDate,
    required this.latestWishDate,
    required this.additionalWishesCount,
  });
}

class _SinceTimeDisplay extends StatefulWidget {
  final DateTime wishDate;
  final TextStyle textStyle;
  final bool isRtl;
  final AppLocalizations l;

  const _SinceTimeDisplay({
    required this.wishDate,
    required this.textStyle,
    required this.isRtl,
    required this.l,
  });

  @override
  State<_SinceTimeDisplay> createState() => _SinceTimeDisplayState();
}

class _SinceTimeDisplayState extends State<_SinceTimeDisplay> {
  /// Ein Stream pro Widget-Instanz (nicht in build() erzeugen).
  late final Stream<int> _minuteTick;

  @override
  void initState() {
    super.initState();
    _minuteTick = Stream.periodic(const Duration(minutes: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _minuteTick,
      initialData: 0,
      builder: (context, _) {
        final now = DateTime.now();
        final elapsed = RelativeTimeMinutes.elapsedCalendarMinutes(widget.wishDate, now);

        String text;
        if (elapsed < 0) {
          text = widget.l.history_time_just_now;
        } else if (elapsed == 0) {
          text = widget.l.history_time_just_now;
        } else if (elapsed < 60) {
          text = widget.l.wishSinceMinutes(elapsed);
        } else {
          final totalHours = elapsed ~/ 60;
          final minutes = elapsed % 60;
          text = widget.l.wishSinceHoursMinutes(totalHours, minutes);
        }
        return Text(
          ' ($text)',
          style: widget.textStyle,
          textAlign: widget.isRtl ? TextAlign.right : TextAlign.left,
          textDirection: widget.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// CustomClipper für Chat-Bubble-Form mit spitzer Ecke unten links (LTR) oder rechts (RTL)
class _ChatBubbleClipper extends CustomClipper<Path> {
  final bool isRtl;

  _ChatBubbleClipper({required this.isRtl});

  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = 12.0;
    final tailSize = 8.0; // Größe der spitzen Ecke

    if (isRtl) {
      // RTL: Spitze Ecke unten rechts
      // Oben links
      path.moveTo(radius, 0);
      // Oben rechts
      path.lineTo(size.width - radius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      // Unten rechts (mit spitzer Ecke)
      path.lineTo(size.width, size.height - radius - tailSize);
      path.lineTo(size.width - tailSize, size.height);
      path.lineTo(size.width - tailSize * 2, size.height - tailSize);
      path.lineTo(radius, size.height - tailSize);
      path.quadraticBezierTo(0, size.height - tailSize, 0, size.height - tailSize - radius);
      // Unten links
      path.lineTo(0, radius);
      path.quadraticBezierTo(0, 0, radius, 0);
    } else {
      // LTR: Spitze Ecke unten links
      // Oben links
      path.moveTo(radius, 0);
      // Oben rechts
      path.lineTo(size.width - radius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      // Unten rechts
      path.lineTo(size.width, size.height - radius);
      path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
      // Unten links (mit spitzer Ecke)
      path.lineTo(radius + tailSize * 2, size.height);
      path.lineTo(tailSize * 2, size.height - tailSize);
      path.lineTo(tailSize, size.height);
      path.lineTo(0, size.height - tailSize);
      path.lineTo(0, radius);
      path.quadraticBezierTo(0, 0, radius, 0);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
