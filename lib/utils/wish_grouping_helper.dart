import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/song_request.dart';
import '../services/duplicate_check_service.dart';
import 'text_utils.dart';

/// Reihenfolge der **Gruppen** nach dem neuesten zutreffenden Zeitpunkt (nicht nur Wunsch-Erstellung).
enum WishGroupListSort {
  /// Offene Wünsche / Favoriten: wie bisher nach jüngstem `createdAt` in der Gruppe.
  byWishCreatedAt,
  /// Tab „Gespielt“: nach Spiel-/Statuszeit ([SongRequest.sortTimestampPlayed]).
  byPlayedTimestamp,
  /// Tab „Abgelehnt“: nach Ablehnungszeit ([SongRequest.sortTimestampRejected]).
  byRejectedTimestamp,
}

/// Helper-Klasse für die Gruppierung von Musikwünschen
/// Gruppiert Wünsche nach normalisiertem Titel/Interpret (inkl. Remix-Zusätze), Anzeige bleibt Original-Titel
class WishGroupingHelper {
  static Timestamp? _laterTimestamp(Timestamp? a, Timestamp? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.toDate().isAfter(b.toDate()) ? a : b;
  }

  /// Zeitstempel eines einzelnen Wunsches für die Gruppen-Sortierung (je Modus).
  static Timestamp? _contribListSortTs(SongRequest r, WishGroupListSort mode) {
    switch (mode) {
      case WishGroupListSort.byWishCreatedAt:
        return r.createdAt;
      case WishGroupListSort.byPlayedTimestamp:
        return Timestamp.fromDate(r.sortTimestampPlayed);
      case WishGroupListSort.byRejectedTimestamp:
        return Timestamp.fromDate(r.sortTimestampRejected);
    }
  }

  /// Gruppiert Wünsche nach Titel und Interpret.
  /// Für den Gruppenschlüssel wird die normalisierte Version verwendet (Klammern/Mix-Begriffe entfernt),
  /// damit z. B. "Warum hast du nicht nein gesagt" und "Warum hast du nicht nein gesagt (Club Mix)" als ein Eintrag (Counter 2) erscheinen.
  /// Die Anzeige nutzt weiterhin den ursprünglichen Titel (displayTitle).
  /// Gibt Map zurück mit: 'groups', 'firstRequests', 'docIds'
  static Map<String, dynamic> groupWishes(
    List<SongRequest> sortedRequests, {
    WishGroupListSort listSort = WishGroupListSort.byWishCreatedAt,
  }) {
    final Map<String, Map<String, dynamic>> groupedWishes = {};
    final Map<String, List<String>> groupedDocIds = {};
    final Map<String, SongRequest> groupedFirstRequests = {};
    final ignoredKeywords = DuplicateCheckService.getCachedIgnoredKeywords();

    for (final request in sortedRequests) {
      // Nur für den Gruppenschlüssel: normalisieren (Klammern, Mix-Begriffe, Umlaute, Sonderzeichen)
      final titleForKey = normalizeTextForDuplicateCheck(request.displayTitle, ignoredKeywords);
      final artistForKey = normalizeTextForDuplicateCheck(request.artist ?? '', ignoredKeywords);
      final partyId = request.partyId ?? '';
      final groupKey = '$titleForKey|$artistForKey|$partyId';
      
      if (!groupedWishes.containsKey(groupKey)) {
        // Erste Wunsch für diesen Song - erstelle Gruppeneintrag
        final requestedBy = request.requestedBy ?? [];
        final name = request.name ?? '';
        final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
        final greetings = List<Map<String, dynamic>>.from(
          (request.greetings ?? []).map((g) => {
            'name': g['name'] ?? '',
            'greeting': g['greeting'] ?? '',
          })
        );
        final greeting = request.greeting ?? '';
        if (greeting.isNotEmpty && !greetings.any((g) => g['greeting'] == greeting)) {
          greetings.add({'name': name, 'greeting': greeting});
        }
        
        // createdAt_list: ein Eintrag pro Name (parallel zu requested_by), neueste zuerst (Sortierung der Gruppe)
        final createdAtList = request.createdAt != null
            ? List<Timestamp>.filled(namesToShow.length, request.createdAt!)
            : <Timestamp>[];

        groupedWishes[groupKey] = {
          'title': request.displayTitle,
          'artist': request.artist ?? '',
          'duplicate_count': request.duplicateCount ?? 0,
          'requested_by': namesToShow,
          'greetings': greetings,
          'is_registered_users': Map<String, bool>.from(request.isRegisteredUsers ?? {}),
          'createdAt': request.createdAt, // Neueste Zeit für Sortierung (wird bei weiteren Wünschen aktualisiert)
          'list_sort_ts': _contribListSortTs(request, listSort),
          'createdAt_list': createdAtList, // Parallel zu requested_by, Index i = derselbe Wunsch/Person
          'party_id': request.partyId,
          'client_id': request.clientId, // ✅ FIX: client_id für Fallback-Sicherheit
          'is_duplicate': request.isDuplicate ?? false,
          'isSeen': request.isSeen, // ✅ FIX: isSeen Feld für Read-Status-Logik
          'is_favorite': request.isFavorite ?? false,
          'title_variants': <String>[], // Original-Titel, die vom Haupttitel abweichen (Set-Logik, keine Duplikate)
          'played_at': request.playedAt,
          'playedAt': request.playedAt,
          'recognized_at': request.recognizedAt,
          'rejected_at': request.rejectedAt,
          'rejectedAt': request.rejectedAt,
          'auto_rejected_by_block': request.autoRejectedByBlock ?? false,
          'auto_recognized': request.autoRecognized ?? false,
        };
        groupedDocIds[groupKey] = [request.id];
        groupedFirstRequests[groupKey] = request;
      } else {
        // Weitere Wunsch für diesen Song - füge Daten hinzu
        final group = groupedWishes[groupKey]!;
        final requestedBy = request.requestedBy ?? [];
        final name = request.name ?? '';
        final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
        final greetings = List<Map<String, dynamic>>.from(
          (request.greetings ?? []).map((g) => {
            'name': g['name'] ?? '',
            'greeting': g['greeting'] ?? '',
          })
        );
        final greeting = request.greeting ?? '';
        if (greeting.isNotEmpty && !greetings.any((g) => g['greeting'] == greeting)) {
          greetings.add({'name': name, 'greeting': greeting});
        }
        
        // requested_by und createdAt_list parallel: ein Eintrag pro (Wunsch, Person), Reihenfolge = neueste zuerst
        final existingRequestedBy = List<String>.from(group['requested_by'] as List);
        final existingCreatedAtList = List<Timestamp>.from((group['createdAt_list'] as List?) ?? []);
        final newCreatedAt = request.createdAt;
        for (final n in namesToShow) {
          existingRequestedBy.add(n);
          if (newCreatedAt != null) existingCreatedAtList.add(newCreatedAt);
        }

        final existingGreetings = List<Map<String, dynamic>>.from(group['greetings'] as List);
        for (final g in greetings) {
          if (!existingGreetings.any((eg) => eg['name'] == g['name'] && eg['greeting'] == g['greeting'])) {
            existingGreetings.add(g);
          }
        }
        
        final existingIsRegisteredUsers = Map<String, bool>.from(group['is_registered_users'] as Map<String, dynamic>);
        final newIsRegisteredUsers = Map<String, bool>.from(request.isRegisteredUsers ?? {});
        existingIsRegisteredUsers.addAll(newIsRegisteredUsers);
        
        // duplicate_count / Gesamtanzahl: wird nach der Schleife aus createdAt_list gesetzt
        // (kein + duplicateCount + 1 hier – Firestore duplicate_count würde sonst doppelt zählen)
        group['requested_by'] = existingRequestedBy;
        group['greetings'] = existingGreetings;
        group['is_registered_users'] = existingIsRegisteredUsers;
        group['createdAt_list'] = existingCreatedAtList;
        
        // Verwende das neueste createdAt für die Sortierung (damit Gruppe nach oben rutscht bei neuem Wunsch)
        final existingCreatedAt = group['createdAt'] as Timestamp?;
        if (newCreatedAt != null && (existingCreatedAt == null || newCreatedAt.toDate().isAfter(existingCreatedAt.toDate()))) {
          group['createdAt'] = newCreatedAt;
        }

        final prevListTs = group['list_sort_ts'] as Timestamp?;
        final contribTs = _contribListSortTs(request, listSort);
        group['list_sort_ts'] = _laterTimestamp(prevListTs, contribTs);
        
        // ✅ FIX: isSeen Logik - Gruppe ist gelesen, wenn mindestens ein Wunsch gelesen wurde
        final existingIsSeen = group['isSeen'] as bool?;
        final newIsSeen = request.isSeen;
        // Wenn einer der Wünsche gelesen wurde (true), ist die ganze Gruppe gelesen
        // Nur wenn ALLE Wünsche ungelesen sind (false), bleibt die Gruppe ungelesen
        if (newIsSeen == true || existingIsSeen == true) {
          group['isSeen'] = true;
        } else {
          // Beide sind false oder null - Gruppe bleibt ungelesen (false)
          group['isSeen'] = false;
        }
        
        // is_favorite: Gruppe ist Favorit, wenn mindestens ein Wunsch Favorit ist
        final existingFavorite = group['is_favorite'] as bool?;
        final newFavorite = request.isFavorite ?? false;
        if (newFavorite || (existingFavorite == true)) {
          group['is_favorite'] = true;
        } else {
          group['is_favorite'] = false;
        }

        // Auto-Erkennung (Shazam): mindestens ein Wunsch der Gruppe automatisch abgehakt
        if (request.autoRecognized == true) {
          group['auto_recognized'] = true;
        }

        final existingPlayed =
            (group['played_at'] as Timestamp?) ?? (group['playedAt'] as Timestamp?);
        final mergedPlayed = _laterTimestamp(existingPlayed, request.playedAt);
        if (mergedPlayed != null) {
          group['played_at'] = mergedPlayed;
          group['playedAt'] = mergedPlayed;
        }
        final existingRec = group['recognized_at'] as Timestamp?;
        final mergedRec = _laterTimestamp(existingRec, request.recognizedAt);
        if (mergedRec != null) {
          group['recognized_at'] = mergedRec;
        }
        
        // Titel-Varianten: Alle originalen Titel, die vom Haupttitel abweichen (Set-Logik)
        final mainTitle = ((group['title'] as String?) ?? '').trim();
        final requestedTitle = request.displayTitle.trim();
        if (requestedTitle.isNotEmpty && requestedTitle != mainTitle) {
          final variants = List<String>.from((group['title_variants'] as List?) ?? []);
          if (!variants.contains(requestedTitle)) {
            variants.add(requestedTitle);
          }
          group['title_variants'] = variants;
        }
        
        groupedDocIds[groupKey]!.add(request.id);
      }
    }

    // Badge & duplicate_count: exakt parallel zu Uhrzeiten-Liste (createdAt_list) bzw. requested_by
    for (final g in groupedWishes.values) {
      final cal = (g['createdAt_list'] as List?) ?? [];
      final rb = (g['requested_by'] as List?) ?? [];
      final n = cal.isNotEmpty
          ? cal.length
          : rb.isNotEmpty
              ? rb.length
              : 1;
      g['wish_total_count'] = n;
      g['duplicate_count'] = n > 1 ? n - 1 : 0;
      g['additional_wishes_count'] = n > 1 ? n - 1 : 0;

      final timestamps = cal
          .whereType<Timestamp>()
          .toList();
      if (timestamps.isNotEmpty) {
        timestamps.sort((a, b) => a.toDate().compareTo(b.toDate()));
        g['oldest_createdAt'] = timestamps.first;
        g['latest_createdAt'] = timestamps.last;
      } else {
        final fallback = g['createdAt'];
        if (fallback is Timestamp) {
          g['oldest_createdAt'] = fallback;
          g['latest_createdAt'] = fallback;
        }
      }
    }
    
    // Konvertiere gruppierte Wünsche zurück in sortierte Liste (Daten-Phase)
    final groupedList = groupedWishes.entries.map((entry) => {
      'key': entry.key,
      'data': entry.value,
    }).toList()
      ..sort((a, b) {
        final dataA = a['data'] as Map<String, dynamic>;
        final dataB = b['data'] as Map<String, dynamic>;
        final tsA = (dataA['list_sort_ts'] as Timestamp?) ?? (dataA['createdAt'] as Timestamp?);
        final tsB = (dataB['list_sort_ts'] as Timestamp?) ?? (dataB['createdAt'] as Timestamp?);
        final dateA = tsA?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = tsB?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    
    // WICHTIG: Nur Daten zurückgeben, kein UI-Code!
    return {
      'groups': groupedList,
      'firstRequests': groupedFirstRequests,
      'docIds': groupedDocIds,
    };
  }
}
