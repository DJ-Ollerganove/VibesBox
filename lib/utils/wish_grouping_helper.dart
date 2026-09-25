import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/song_request.dart';
import '../services/duplicate_check_service.dart';
import 'debug_log.dart';
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
  /// Shadow-Dokumente bei Dubletten-Absendung (`is_duplicate: true`, siehe PWA/Gast-Listen).
  /// Nur das Original-Dokument gehört in DJ-Tabellen — sonst erscheint derselbe Song zweimal.
  static List<SongRequest> withoutDuplicateShadowDocuments(
    Iterable<SongRequest> requests,
  ) {
    return requests.where((r) => r.isDuplicate != true).toList();
  }

  /// Anzahl Shadow-Dokumente (`is_duplicate: true`) pro Gruppenschlüssel.
  static int _duplicateShadowCountForGroup(
    String groupKey,
    Iterable<SongRequest> allRequests,
    List<String> ignoredKeywords,
    String? sessionPartyId,
  ) {
    var count = 0;
    for (final r in allRequests) {
      if (r.isDuplicate != true) continue;
      if (_groupKeyForRequest(r, ignoredKeywords, sessionPartyId) == groupKey) {
        count++;
      }
    }
    return count;
  }

  /// Shadow-Dokument-IDs an die Gruppe hängen (Badge, isNew, Löschen).
  static void _attachShadowDocIds(
    Map<String, List<String>> groupedDocIds,
    Iterable<SongRequest> allRequests,
    List<String> ignoredKeywords,
    String? sessionPartyId,
  ) {
    for (final r in allRequests) {
      if (r.isDuplicate != true || r.id.isEmpty) continue;
      final groupKey = _groupKeyForRequest(r, ignoredKeywords, sessionPartyId);
      final ids = groupedDocIds[groupKey];
      if (ids != null && !ids.contains(r.id)) {
        ids.add(r.id);
      }
    }
  }

  static int _wishTotalCountFromParts({
    required int fromLists,
    required int firestoreDuplicateCount,
    required int shadowDuplicateCount,
  }) {
    final fromFirestore = firestoreDuplicateCount + 1;
    final fromShadows = shadowDuplicateCount > 0 ? shadowDuplicateCount + 1 : 1;
    return [fromLists, fromFirestore, fromShadows].reduce((a, b) => a > b ? a : b);
  }

  /// Verhindert doppelte Zeilen mit derselben Dokument-ID (Snapshot/Gruppierungs-Grenzfall).
  static List<Map<String, dynamic>> groupsWithUniqueDocumentIds(
    List<Map<String, dynamic>> groups,
    Map<String, List<String>> docIdsByGroupKey,
  ) {
    final seenDocIds = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final entry in groups) {
      final key = entry['key'] as String;
      final ids = docIdsByGroupKey[key] ?? const <String>[];
      final overlap = ids.where((id) => id.isNotEmpty && seenDocIds.contains(id));
      if (overlap.isNotEmpty) {
        debugLog(
          '⚠️ WishGroupingHelper: Gruppe übersprungen (docId bereits in Liste: ${overlap.join(", ")}, key=$key)',
        );
        continue;
      }
      for (final id in ids) {
        if (id.isNotEmpty) seenDocIds.add(id);
      }
      unique.add(entry);
    }
    return unique;
  }

  static Timestamp? _laterTimestamp(Timestamp? a, Timestamp? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.toDate().isAfter(b.toDate()) ? a : b;
  }

  static String _groupKeyForRequest(
    SongRequest request,
    List<String> ignoredKeywords,
    String? sessionPartyId,
  ) {
    final titleForKey =
        normalizeTextForDuplicateCheck(request.displayTitle, ignoredKeywords);
    final artistForKey =
        normalizeTextForDuplicateCheck(request.artist ?? '', ignoredKeywords);
    final partyForGroupKey =
        (sessionPartyId != null && sessionPartyId.trim().isNotEmpty)
            ? sessionPartyId.trim()
            : (request.partyId ?? '').trim();
    return '$titleForKey|$artistForKey|$partyForGroupKey';
  }

  /// Zeiten aus Shadow-Dokumenten (`is_duplicate: true`): Schlüssel `groupKey|Person`.
  static Map<String, Timestamp> _shadowTimestampsByPerson(
    Iterable<SongRequest> requests,
    List<String> ignoredKeywords,
    String? sessionPartyId,
  ) {
    final map = <String, Timestamp>{};
    for (final r in requests) {
      if (r.isDuplicate != true || r.createdAt == null) continue;
      final person = (r.name ?? '').trim();
      if (person.isEmpty) continue;
      final groupKey = _groupKeyForRequest(r, ignoredKeywords, sessionPartyId);
      final key = '$groupKey|$person';
      final existing = map[key];
      if (existing == null ||
          r.createdAt!.toDate().isAfter(existing.toDate())) {
        map[key] = r.createdAt!;
      }
    }
    return map;
  }

  /// Shadow-Docs (`is_duplicate: true`): Namen/Grüße in die Gruppe, wenn das
  /// Original-Update fehlgeschlagen ist (z. B. andere client_id → Firestore-Regel).
  static void _mergeShadowWisherInfoIntoGroup(
    Map<String, dynamic> group,
    String groupKey,
    Iterable<SongRequest> allRequests,
    List<String> ignoredKeywords,
    String? sessionPartyId,
  ) {
    final existingRb = List<String>.from((group['requested_by'] as List?) ?? []);
    final existingCal = List<Timestamp>.from(
      (group['createdAt_list'] as List?)?.whereType<Timestamp>() ?? [],
    );
    final existingGreetings = List<Map<String, dynamic>>.from(
      (group['greetings'] as List?)?.map((g) {
        final m = g is Map ? Map<String, dynamic>.from(g) : <String, dynamic>{};
        return {
          'name': (m['name'] ?? '').toString(),
          'greeting': (m['greeting'] ?? '').toString(),
        };
      }) ??
          [],
    );
    final existingReg = Map<String, bool>.from(
      (group['is_registered_users'] as Map<String, dynamic>?) ?? {},
    );
    final fallbackTs = group['createdAt'] as Timestamp?;

    void addGreetingIfNew(String person, String text) {
      final p = person.trim();
      final t = text.trim();
      if (p.isEmpty || t.isEmpty) return;
      final exists = existingGreetings.any(
        (g) => g['name'] == p && g['greeting'] == t,
      );
      if (!exists) {
        existingGreetings.add({'name': p, 'greeting': t});
      }
    }

    void appendTimestamp(List<Timestamp> cal, Timestamp? ts) {
      if (ts != null) {
        cal.add(ts);
      } else if (cal.isNotEmpty) {
        cal.add(cal.last);
      } else if (fallbackTs != null) {
        cal.add(fallbackTs);
      }
    }

    for (final r in allRequests) {
      if (r.isDuplicate != true) continue;
      if (_groupKeyForRequest(r, ignoredKeywords, sessionPartyId) != groupKey) {
        continue;
      }

      final persons = namesForRequest(r);
      if (persons.isEmpty) {
        existingRb.add('');
        appendTimestamp(existingCal, r.createdAt);
        continue;
      }

      for (final person in persons) {
        if (existingRb.contains(person)) continue;
        existingRb.add(person);
        appendTimestamp(existingCal, r.createdAt);
        for (final e in (r.isRegisteredUsers ?? const <String, bool>{}).entries) {
          existingReg[e.key] = e.value;
        }
      }

      final shadowName = (r.name ?? '').trim();
      addGreetingIfNew(shadowName, r.greeting ?? '');
      for (final g in r.greetings ?? const <Map<String, dynamic>>[]) {
        addGreetingIfNew(
          (g['name'] ?? '').toString(),
          (g['greeting'] ?? '').toString(),
        );
      }
    }

    group['requested_by'] = existingRb;
    group['createdAt_list'] = existingCal;
    group['greetings'] = existingGreetings;
    group['is_registered_users'] = existingReg;
  }

  /// Korrigiert Uhrzeiten in der Gruppe (Shadow-Docs + gespeicherte `createdAt_list`).
  static void _applyPerPersonTimestamps(
    Map<String, dynamic> group,
    String groupKey,
    Map<String, Timestamp> shadowTsByPerson,
  ) {
    final rb = List<String>.from((group['requested_by'] as List?) ?? []);
    if (rb.isEmpty) return;

    final cal = List<Timestamp>.from(
      (group['createdAt_list'] as List?)?.whereType<Timestamp>() ?? [],
    );
    final fallback = group['createdAt'] as Timestamp?;

    while (cal.length < rb.length) {
      if (cal.isNotEmpty) {
        cal.add(cal.last);
      } else if (fallback != null) {
        cal.add(fallback);
      }
    }

    for (var i = 0; i < rb.length; i++) {
      final person = rb[i].toString().trim();
      if (person.isEmpty) continue;
      final shadow = shadowTsByPerson['$groupKey|$person'];
      if (shadow != null) {
        cal[i] = shadow;
      }
    }
    group['createdAt_list'] = cal;
  }

  /// Badge / Zeilenanzahl: `wish_total_count` > Listen > `duplicate_count+1`.
  static int wishTotalCountForDisplay(
    Map<String, dynamic> data,
    Map<String, dynamic>? groupedData,
  ) {
    final src = groupedData ?? data;
    final wtc = src['wish_total_count'];
    if (wtc is int && wtc >= 1) return wtc;
    final cal = src['createdAt_list'];
    if (cal is List && cal.isNotEmpty) return cal.length;
    final rb = src['requested_by'];
    if (rb is List && rb.isNotEmpty) return rb.length;
    final dc = (data['duplicate_count'] as int?) ?? 0;
    return dc + 1;
  }

  /// Namen für WishCard: `requested_by` + `name`/`requestedBy` aus [request],
  /// auf [wishTotalCountForDisplay] auffüllen (anonym → leerer Slot → UI: „Kein Name“).
  static List<String> displayWisherNamesForCard({
    required Map<String, dynamic> data,
    Map<String, dynamic>? groupedData,
    SongRequest? request,
  }) {
    final owner = (data['name'] ?? '').toString().trim();
    final rb = List<String>.from((data['requested_by'] as List?) ?? []);
    var names = <String>[];

    if (rb.isNotEmpty) {
      names = dedupeNamesPreserveOrder(rb.map((e) => e.toString()).toList());
    } else if (owner.isNotEmpty) {
      names = [owner];
    }

    if (request != null) {
      for (final n in namesForRequest(request)) {
        if (n.isEmpty) continue;
        if (!names.contains(n)) {
          names.add(n);
        }
      }
    }

    final total = wishTotalCountForDisplay(data, groupedData);
    while (names.length < total) {
      names.add('');
    }

    if (names.isEmpty) {
      return total > 1 ? List<String>.filled(total, '') : const [''];
    }
    return names;
  }

  /// `requested_by` / `createdAt_list` auf [wish_total_count] erweitern (anonyme Dubletten).
  static void _padWisherListsToWishTotal(Map<String, dynamic> g) {
    final total = (g['wish_total_count'] as int?) ?? 1;
    if (total <= 1) return;
    final rb = List<String>.from((g['requested_by'] as List?) ?? []);
    if (rb.length >= total) return;
    final cal = List<Timestamp>.from(
      (g['createdAt_list'] as List?)?.whereType<Timestamp>() ?? [],
    );
    final tsFallback =
        g['latest_createdAt'] as Timestamp? ?? g['createdAt'] as Timestamp?;
    while (rb.length < total) {
      rb.add('');
      if (cal.length < rb.length) {
        cal.add(tsFallback ?? Timestamp.now());
      }
    }
    g['requested_by'] = rb;
    g['createdAt_list'] = cal;
  }

  /// Benannte Wünschende deduplizieren; leere Slots (anonym) bleiben pro Eintrag erhalten
  /// → Anzeige über [wisherDisplayName] als l10n `no_name`.
  static List<String> dedupeNamesPreserveOrder(List<String> names) {
    final out = <String>[];
    for (final raw in names) {
      final n = raw.trim();
      if (n.isEmpty) {
        out.add('');
        continue;
      }
      if (out.contains(n)) continue;
      out.add(n);
    }
    return out;
  }

  /// Alle Wünscher eines Dokuments: Ersteller (`name`) zuerst, dann `requested_by`.
  /// Wichtig nach Duplikat-Updates: dort steht oft nur der neue Name in `requested_by`,
  /// der ursprüngliche Wünscher bleibt in `name` — ohne `name` würde z. B. „Jens“ durch „Nele“ ersetzt.
  static List<String> namesForRequest(SongRequest request) {
    final out = <String>[];
    final name = (request.name ?? '').trim();
    if (name.isNotEmpty) out.add(name);
    for (final raw in request.requestedBy ?? const <String>[]) {
      final n = raw.trim();
      if (n.isNotEmpty && !out.contains(n)) out.add(n);
    }
    return out;
  }

  /// Anzeige-Slots: ohne Namen ein leerer Eintrag (`''`) → UI: l10n `no_name`.
  static List<String> wisherSlotsForRequest(SongRequest request) {
    final names = namesForRequest(request);
    if (names.isNotEmpty) return names;
    return const [''];
  }

  /// Weitere Dokumente in derselben Gruppe: nur noch nicht in der Gruppe vorhandene Namen.
  static List<String> _namesToAddWhenMerging(
    SongRequest request,
    List<String> alreadyInGroup,
  ) {
    return namesForRequest(request)
        .where((n) => !alreadyInGroup.contains(n))
        .toList();
  }

  /// `requested_by` und `createdAt_list` parallel bereinigen (nach Merge-Artefakten).
  static void _normalizeGroupWisherLists(Map<String, dynamic> group) {
    final rb = List<String>.from((group['requested_by'] as List?) ?? []);
    final cal = List<Timestamp>.from(
      (group['createdAt_list'] as List?)?.whereType<Timestamp>() ?? [],
    );
    final dedupedRb = <String>[];
    final dedupedCal = <Timestamp>[];
    final fallbackTs = group['createdAt'] as Timestamp?;
    Timestamp? calAt(int i) {
      if (i < cal.length) return cal[i];
      if (dedupedCal.isNotEmpty) return dedupedCal.last;
      return fallbackTs;
    }

    for (var i = 0; i < rb.length; i++) {
      final n = rb[i].toString().trim();
      if (n.isEmpty) {
        dedupedRb.add('');
        final ts = calAt(i);
        if (ts != null) dedupedCal.add(ts);
        continue;
      }
      if (dedupedRb.contains(n)) continue;
      dedupedRb.add(n);
      final ts = calAt(i);
      if (ts != null) dedupedCal.add(ts);
    }
    group['requested_by'] = dedupedRb;
    group['createdAt_list'] = dedupedCal;
  }

  /// Zeitstempel eines einzelnen Wunsches für die Gruppen-Sortierung (je Modus).
  static Timestamp? _contribListSortTs(SongRequest r, WishGroupListSort mode) {
    switch (mode) {
      case WishGroupListSort.byWishCreatedAt:
        return r.createdAt;
      case WishGroupListSort.byPlayedTimestamp:
        return r.playedAt ?? Timestamp.fromDate(r.sortTimestampPlayed);
      case WishGroupListSort.byRejectedTimestamp:
        return r.rejectedAt ?? Timestamp.fromDate(r.sortTimestampRejected);
    }
  }

  /// Gruppiert Wünsche nach Titel und Interpret.
  /// Für den Gruppenschlüssel wird die normalisierte Version verwendet (Klammern/Mix-Begriffe entfernt),
  /// damit z. B. "Warum hast du nicht nein gesagt" und "Warum hast du nicht nein gesagt (Club Mix)" als ein Eintrag (Counter 2) erscheinen.
  /// Die Anzeige nutzt weiterhin den ursprünglichen Titel (displayTitle).
  /// Gibt Map zurück mit: 'groups', 'firstRequests', 'docIds'
  ///
  /// [sessionPartyId]: Wenn gesetzt (z. B. aktive Party der Ansicht), wird sie für den
  /// Gruppierungsschlüssel verwendet statt [SongRequest.partyId]. So landen Wünsche mit
  /// fehlendem/parse-defektem `party_id` im Model nicht in einer **zweiten** Gruppe
  /// (`…|…|` vs. `…|…|<party>`) — dieselbe Zeile doppelt, Löschen wirkt auf alle Docs.
  static Map<String, dynamic> groupWishes(
    List<SongRequest> sortedRequests, {
    WishGroupListSort listSort = WishGroupListSort.byWishCreatedAt,
    String? sessionPartyId,
    /// Alle Dokumente inkl. `is_duplicate`-Shadows — für korrekte Uhrzeiten pro Person.
    List<SongRequest>? allRequestsForTimestamps,
  }) {
    final Map<String, Map<String, dynamic>> groupedWishes = {};
    final Map<String, List<String>> groupedDocIds = {};
    final Map<String, SongRequest> groupedFirstRequests = {};
    final ignoredKeywords = DuplicateCheckService.getCachedIgnoredKeywords();
    final shadowTsByPerson = _shadowTimestampsByPerson(
      allRequestsForTimestamps ?? sortedRequests,
      ignoredKeywords,
      sessionPartyId,
    );

    for (final request in sortedRequests) {
      final groupKey =
          _groupKeyForRequest(request, ignoredKeywords, sessionPartyId);
      
      if (!groupedWishes.containsKey(groupKey)) {
        // Erste Wunsch für diesen Song - erstelle Gruppeneintrag
        final name = request.name ?? '';
        final namesToShow = wisherSlotsForRequest(request);
        final greetings = List<Map<String, dynamic>>.from(
          (request.greetings ?? []).map((g) => {
            'name': g['name'] ?? '',
            'greeting': g['greeting'] ?? '',
          })
        );
        final greeting = request.greeting ?? '';
        if (greeting.isNotEmpty &&
            !greetings.any((g) => g['name'] == name && g['greeting'] == greeting)) {
          greetings.add({'name': name, 'greeting': greeting});
        }
        
        // createdAt_list: parallel zu requested_by; Shadow-Docs liefern fehlende Zeiten (z. B. Nele).
        final createdAtList = _createdAtListForNames(
          names: namesToShow,
          request: request,
          groupKey: groupKey,
          shadowTsByPerson: shadowTsByPerson,
        );

        groupedWishes[groupKey] = {
          'title': request.displayTitle,
          'artist': request.artist ?? '',
          'firestore_duplicate_count': request.duplicateCount ?? 0,
          'duplicate_count': request.duplicateCount ?? 0,
          'duplicate_updated_at': request.duplicateUpdatedAt,
          'requested_by': namesToShow,
          'greetings': greetings,
          'is_registered_users': Map<String, bool>.from(request.isRegisteredUsers ?? {}),
          'createdAt': request.createdAt, // Neueste Zeit für Sortierung (wird bei weiteren Wünschen aktualisiert)
          'list_sort_ts': _contribListSortTs(request, listSort),
          'createdAt_list': createdAtList, // Parallel zu requested_by, Index i = derselbe Wunsch/Person
          'party_id': (request.partyId != null &&
                  request.partyId!.trim().isNotEmpty)
              ? request.partyId
              : sessionPartyId,
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
          'auto_rejected_by_blacklist': request.autoRejectedByBlacklist ?? false,
          'auto_recognized': request.autoRecognized ?? false,
          'is_pre_wish': request.isPreWish == true,
          'pre_wish_published': request.preWishPublished == true,
          'is_dj_wish': request.isDjWish == true,
          'from_setlist': request.fromSetlist == true,
        };
        groupedDocIds[groupKey] = [request.id];
        groupedFirstRequests[groupKey] = request;
      } else {
        final idsForGroup = groupedDocIds[groupKey]!;
        if (idsForGroup.contains(request.id)) {
          debugLog(
            '⚠️ WishGroupingHelper: ${request.id} bereits in Gruppe $groupKey — übersprungen',
          );
          continue;
        }
        // Weitere Wunsch für diesen Song - füge Daten hinzu
        final group = groupedWishes[groupKey]!;
        final name = request.name ?? '';
        final namesToAdd = _namesToAddWhenMerging(
          request,
          List<String>.from(group['requested_by'] as List),
        );
        final greetings = List<Map<String, dynamic>>.from(
          (request.greetings ?? []).map((g) => {
            'name': g['name'] ?? '',
            'greeting': g['greeting'] ?? '',
          })
        );
        final greeting = request.greeting ?? '';
        if (greeting.isNotEmpty &&
            !greetings.any((g) => g['name'] == name && g['greeting'] == greeting)) {
          greetings.add({'name': name, 'greeting': greeting});
        }
        
        // requested_by und createdAt_list parallel: ein Eintrag pro (Wunsch, Person), Reihenfolge = neueste zuerst
        final existingRequestedBy = List<String>.from(group['requested_by'] as List);
        final existingCreatedAtList = List<Timestamp>.from((group['createdAt_list'] as List?) ?? []);
        final newCreatedAt = request.createdAt;
        if (namesToAdd.isNotEmpty) {
          for (final n in namesToAdd) {
            existingRequestedBy.add(n);
            final shadow = shadowTsByPerson['$groupKey|$n'];
            if (shadow != null) {
              existingCreatedAtList.add(shadow);
            } else if (newCreatedAt != null) {
              existingCreatedAtList.add(newCreatedAt);
            }
          }
        } else if (namesForRequest(request).isEmpty) {
          existingRequestedBy.add('');
          if (newCreatedAt != null) {
            existingCreatedAtList.add(newCreatedAt);
          }
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

        if (request.isPreWish == true) {
          group['is_pre_wish'] = true;
        }
        if (request.preWishPublished == true) {
          group['pre_wish_published'] = true;
        }
        if (request.isDjWish == true) {
          group['is_dj_wish'] = true;
        }
        if (request.fromSetlist == true) {
          group['from_setlist'] = true;
        }

        // Auto-Erkennung (Shazam): mindestens ein Wunsch der Gruppe automatisch abgehakt
        if (request.autoRecognized == true) {
          group['auto_recognized'] = true;
        }
        if (request.autoRejectedByBlacklist == true) {
          group['auto_rejected_by_blacklist'] = true;
        }

        final existingPlayed =
            (group['played_at'] as Timestamp?) ?? (group['playedAt'] as Timestamp?);
        final mergedPlayed = _laterTimestamp(existingPlayed, request.playedAt);
        if (mergedPlayed != null) {
          group['played_at'] = mergedPlayed;
          group['playedAt'] = mergedPlayed;
        }
        final existingRejected =
            (group['rejected_at'] as Timestamp?) ?? (group['rejectedAt'] as Timestamp?);
        final mergedRejected = _laterTimestamp(existingRejected, request.rejectedAt);
        if (mergedRejected != null) {
          group['rejected_at'] = mergedRejected;
          group['rejectedAt'] = mergedRejected;
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
        
        idsForGroup.add(request.id);
      }
    }

    // Badge & duplicate_count: Listen + Firestore duplicate_count + Shadow-Docs
    final allForShadows = allRequestsForTimestamps ?? sortedRequests;
    for (final entry in groupedWishes.entries) {
      final g = entry.value;
      _mergeShadowWisherInfoIntoGroup(
        g,
        entry.key,
        allForShadows,
        ignoredKeywords,
        sessionPartyId,
      );
      _applyPerPersonTimestamps(g, entry.key, shadowTsByPerson);
      _normalizeGroupWisherLists(g);
      final cal = (g['createdAt_list'] as List?) ?? [];
      final rb = (g['requested_by'] as List?) ?? [];
      final fromLists = cal.isNotEmpty
          ? cal.length
          : rb.isNotEmpty
              ? rb.length
              : 1;
      final fsDup = (g['firestore_duplicate_count'] as int?) ?? 0;
      final shadowDup = _duplicateShadowCountForGroup(
        entry.key,
        allForShadows,
        ignoredKeywords,
        sessionPartyId,
      );
      final total = _wishTotalCountFromParts(
        fromLists: fromLists,
        firestoreDuplicateCount: fsDup,
        shadowDuplicateCount: shadowDup,
      );
      g['wish_total_count'] = total;
      g['duplicate_count'] = total > 1 ? total - 1 : 0;
      g['additional_wishes_count'] = total > 1 ? total - 1 : 0;

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

      // Offen/Favoriten: Dublette → Gruppe nach oben (nach Wunsch-Zeit).
      if (listSort == WishGroupListSort.byWishCreatedAt) {
        final latest = g['latest_createdAt'] as Timestamp?;
        final dupUpdated = g['duplicate_updated_at'] as Timestamp?;
        final sortTs = _laterTimestamp(latest, dupUpdated);
        if (sortTs != null) {
          g['list_sort_ts'] = sortTs;
          g['createdAt'] = sortTs;
        }
      } else if (listSort == WishGroupListSort.byPlayedTimestamp) {
        final played =
            (g['played_at'] as Timestamp?) ?? (g['playedAt'] as Timestamp?);
        if (played != null) {
          g['list_sort_ts'] = played;
        }
      } else if (listSort == WishGroupListSort.byRejectedTimestamp) {
        final rejected =
            (g['rejected_at'] as Timestamp?) ?? (g['rejectedAt'] as Timestamp?);
        if (rejected != null) {
          g['list_sort_ts'] = rejected;
        }
      }

      _padWisherListsToWishTotal(g);
    }

    _attachShadowDocIds(
      groupedDocIds,
      allForShadows,
      ignoredKeywords,
      sessionPartyId,
    );
    
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

  /// Erstellt [createdAt_list] für die Namen eines Dokuments (Shadow > Firestore-Liste > createdAt).
  static List<Timestamp> _createdAtListForNames({
    required List<String> names,
    required SongRequest request,
    required String groupKey,
    required Map<String, Timestamp> shadowTsByPerson,
  }) {
    if (names.isEmpty) return [];

    final docList = request.createdAtList;
    final owner = (request.name ?? '').trim();
    final out = <Timestamp>[];

    for (var i = 0; i < names.length; i++) {
      final person = names[i];
      final shadow = shadowTsByPerson['$groupKey|$person'];
      if (shadow != null) {
        out.add(shadow);
        continue;
      }
      if (docList != null && i < docList.length) {
        out.add(docList[i]);
        continue;
      }
      if (docList != null && person == owner && docList.isNotEmpty) {
        out.add(docList.first);
        continue;
      }
      if (person == owner && request.createdAt != null) {
        out.add(request.createdAt!);
        continue;
      }
      if (request.createdAt != null) {
        out.add(request.createdAt!);
      }
    }
    return out;
  }
}
