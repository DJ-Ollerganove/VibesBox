/**
 * Wunsch-Gruppierung für DJ-Browser (angelehnt an lib/utils/wish_grouping_helper.dart).
 */
(function (global) {
  const IGNORED_KEYWORDS_DEFAULT = ['Remix', 'Mix', 'Edit', 'Radio', 'Club', 'Extended', 'Video', 'Version'];

  function normalizeText(text) {
    return String(text || '')
      .trim()
      .toLowerCase()
      .replace(/ä/g, 'a')
      .replace(/ö/g, 'o')
      .replace(/ü/g, 'u')
      .replace(/ß/g, 'ss')
      .replace(/[^\w\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function normalizeTextForDuplicateCheck(text, ignoredKeywords) {
    if (!text || typeof text !== 'string') return '';
    let s = String(text).trim();
    s = s.replace(/\s*\([^)]*\)\s*/g, ' ');
    s = s.replace(/\s*\[[^\]]*\]\s*/g, ' ');
    const list = Array.isArray(ignoredKeywords) && ignoredKeywords.length
      ? ignoredKeywords
      : IGNORED_KEYWORDS_DEFAULT;
    const escaped = list.map((k) => String(k).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
    if (escaped) {
      const mixTerms = new RegExp('\\s+(' + escaped + ')\\s*$', 'gi');
      let prev = '';
      while (prev !== s) {
        prev = s;
        s = s.replace(mixTerms, ' ').trim();
      }
    }
    return normalizeText(s);
  }

  function displayTitle(wish) {
    return String(wish.title || wish.song_title || wish.songName || '').trim();
  }

  function displayArtist(wish) {
    return String(wish.artist || wish.song_artist || '').trim();
  }

  function groupKeyForWish(wish, partyId, ignoredKeywords) {
    const titleForKey = normalizeTextForDuplicateCheck(displayTitle(wish), ignoredKeywords);
    const artistForKey = normalizeTextForDuplicateCheck(displayArtist(wish), ignoredKeywords);
    const partyForGroupKey = String(partyId || wish.party_id || '').trim();
    return titleForKey + '|' + artistForKey + '|' + partyForGroupKey;
  }

  /** Wie Dart namesForRequest: Ersteller zuerst, dann requested_by. */
  function namesForWish(wish) {
    const out = [];
    const name = String(wish.name || wish.display_name || wish.guest_name || '').trim();
    if (name) out.push(name);
    const rb = Array.isArray(wish.requested_by) ? wish.requested_by : [];
    rb.forEach((raw) => {
      const n = String(raw || '').trim();
      if (n && !out.includes(n)) out.push(n);
    });
    return out.length ? out : [''];
  }

  function namesToAddWhenMerging(wish, alreadyInGroup) {
    return namesForWish(wish).filter((n) => n && !alreadyInGroup.includes(n));
  }

  function dedupeNamesPreserveOrder(names) {
    const out = [];
    names.forEach((raw) => {
      const n = String(raw || '').trim();
      if (!n) {
        out.push('');
        return;
      }
      if (out.includes(n)) return;
      out.push(n);
    });
    return out;
  }

  function wishCreatedTs(wish) {
    return wish.createdAt || wish.created_at || null;
  }

  function tsToMillis(ts) {
    if (!ts) return 0;
    if (typeof ts.toMillis === 'function') return ts.toMillis();
    if (typeof ts.seconds === 'number') return ts.seconds * 1000;
    return 0;
  }

  function shadowTimestampsByPerson(allWishes, partyId, ignoredKeywords) {
    const map = {};
    allWishes.forEach((wish) => {
      if (wish.is_duplicate !== true) return;
      const person = String(wish.name || wish.display_name || wish.guest_name || '').trim();
      if (!person) return;
      const gk = groupKeyForWish(wish, partyId, ignoredKeywords);
      const key = gk + '|' + person;
      const ts = wishCreatedTs(wish);
      const ms = tsToMillis(ts);
      if (!map[key] || ms > tsToMillis(map[key])) {
        map[key] = ts;
      }
    });
    return map;
  }

  /** Neuere von zwei Timestamps (ms). */
  function laterTs(a, b) {
    if (!a) return b || null;
    if (!b) return a;
    return tsToMillis(a) >= tsToMillis(b) ? a : b;
  }

  /**
   * Zeiten aus wish.requested_by ‖ wish.createdAt_list (nicht names-Reihenfolge!).
   * plus Owner-createdAt.
   */
  function timestampsByPersonFromWish(wish) {
    const map = {};
    const rb = Array.isArray(wish.requested_by) ? wish.requested_by : [];
    const cal = Array.isArray(wish.createdAt_list) ? wish.createdAt_list : [];
    rb.forEach((raw, i) => {
      const p = String(raw || '').trim();
      if (!p || i >= cal.length || !cal[i]) return;
      map[p] = laterTs(map[p], cal[i]);
    });
    const owner = String(wish.name || wish.display_name || wish.guest_name || '').trim();
    const created = wishCreatedTs(wish);
    if (owner && created) map[owner] = laterTs(map[owner], created);
    return map;
  }

  /** Wie Dart _createdAtListForNames: Shadow > Liste per Name > Index > createdAt. */
  function createdAtListForNames(names, wish, groupKey, shadowTsByPerson) {
    if (!names.length) return [];
    const byPerson = timestampsByPersonFromWish(wish);
    const docList = Array.isArray(wish.createdAt_list) ? wish.createdAt_list : [];
    const owner = String(wish.name || wish.display_name || wish.guest_name || '').trim();
    const fallback = wishCreatedTs(wish);
    const list = [];

    names.forEach((person, i) => {
      const p = String(person || '').trim();
      let ts = null;
      if (p) {
        const shadow = shadowTsByPerson[groupKey + '|' + p];
        const fromDoc = byPerson[p] || null;
        ts = laterTs(shadow, fromDoc);
      }
      if (!ts && i < docList.length && docList[i]) ts = docList[i];
      if (!ts && p && p === owner && docList.length && docList[0]) ts = docList[0];
      if (!ts && p === owner && fallback) ts = fallback;
      if (!ts && fallback) ts = fallback;
      if (ts) list.push(ts);
    });
    return list;
  }

  function mergeGreetings(existing, wish) {
    const greetings = existing.slice();
    const add = (person, text) => {
      const p = String(person || '').trim();
      const t = String(text || '').trim();
      if (!p || !t) return;
      if (greetings.some((g) => g.name === p && g.greeting === t)) return;
      greetings.push({ name: p, greeting: t });
    };
    if (Array.isArray(wish.greetings)) {
      wish.greetings.forEach((g) => add(g.name, g.greeting));
    }
    add(wish.name || wish.display_name || wish.guest_name, wish.greeting || wish.message || '');
    return greetings;
  }

  function duplicateShadowCountForGroup(groupKey, allWishes, partyId, ignoredKeywords) {
    let count = 0;
    allWishes.forEach((wish) => {
      if (wish.is_duplicate !== true) return;
      if (groupKeyForWish(wish, partyId, ignoredKeywords) === groupKey) count += 1;
    });
    return count;
  }

  function wishTotalCountFromParts(fromLists, firestoreDuplicateCount, shadowDuplicateCount) {
    const fromFirestore = firestoreDuplicateCount + 1;
    const fromShadows = shadowDuplicateCount > 0 ? shadowDuplicateCount + 1 : 1;
    return Math.max(fromLists, fromFirestore, fromShadows);
  }

  function wishTotalCount(group) {
    const wtc = group.wish_total_count;
    if (typeof wtc === 'number' && wtc >= 1) return wtc;
    const cal = group.createdAt_list;
    if (Array.isArray(cal) && cal.length) return cal.length;
    const rb = group.requested_by;
    if (Array.isArray(rb) && rb.length) return rb.length;
    return (group.duplicate_count || 0) + 1;
  }

  /** Shadow-Docs: nur neue Namen + passende Timestamps (wie Dart _mergeShadowWisherInfoIntoGroup). */
  function mergeShadowWisherInfo(group, groupKey, allWishes, partyId, ignoredKeywords) {
    const existingRb = Array.isArray(group.requested_by) ? group.requested_by.slice() : [];
    const existingCal = Array.isArray(group.createdAt_list) ? group.createdAt_list.slice() : [];
    let greetings = Array.isArray(group.greetings) ? group.greetings.slice() : [];
    const fallbackTs = group.createdAt;

    function appendTimestamp(cal, ts) {
      if (ts) cal.push(ts);
      else if (cal.length) cal.push(cal[cal.length - 1]);
      else if (fallbackTs) cal.push(fallbackTs);
    }

    allWishes.forEach((wish) => {
      if (wish.is_duplicate !== true) return;
      if (groupKeyForWish(wish, partyId, ignoredKeywords) !== groupKey) return;

      const persons = namesForWish(wish).filter(Boolean);
      if (!persons.length) {
        existingRb.push('');
        appendTimestamp(existingCal, wishCreatedTs(wish));
      } else {
        persons.forEach((person) => {
          if (existingRb.includes(person)) return;
          existingRb.push(person);
          appendTimestamp(existingCal, wishCreatedTs(wish));
        });
      }
      greetings = mergeGreetings(greetings, wish);
    });

    group.requested_by = existingRb;
    group.createdAt_list = existingCal;
    group.greetings = greetings;
  }

  /** Shadow-Zeiten pro Person setzen, Listenlänge angleichen (wie Dart _applyPerPersonTimestamps). */
  function applyPerPersonTimestamps(group, groupKey, shadowTsByPerson) {
    const rb = Array.isArray(group.requested_by) ? group.requested_by.slice() : [];
    if (!rb.length) return;

    const cal = Array.isArray(group.createdAt_list) ? group.createdAt_list.slice() : [];
    const fallback = group.createdAt;

    while (cal.length < rb.length) {
      if (cal.length) cal.push(cal[cal.length - 1]);
      else if (fallback) cal.push(fallback);
      else break;
    }

    rb.forEach((raw, i) => {
      const person = String(raw || '').trim();
      if (!person) return;
      const shadow = shadowTsByPerson[groupKey + '|' + person];
      // Neuere Zeit gewinnt (Shadow oft korrekt, wenn createdAt_list am Original fehlt/veraltet).
      if (shadow) cal[i] = laterTs(cal[i], shadow);
    });

    group.createdAt_list = cal.slice(0, rb.length);
  }

  /**
   * Anonyme Shadow-Zeiten (leerer Name oder Person schon gezählt) für Padding-Slots.
   */
  function unusedShadowTimestamps(allWishes, partyId, ignoredKeywords, groupKey, claimedPersons) {
    const out = [];
    const claimed = new Set(claimedPersons || []);
    allWishes.forEach((wish) => {
      if (wish.is_duplicate !== true) return;
      if (groupKeyForWish(wish, partyId, ignoredKeywords) !== groupKey) return;
      const person = String(wish.name || wish.display_name || wish.guest_name || '').trim();
      const ts = wishCreatedTs(wish);
      if (!ts) return;
      if (person) {
        if (claimed.has(person)) return;
        claimed.add(person);
      }
      out.push(ts);
    });
    return out;
  }

  /** Namen/Timestamps bereinigen (wie Dart _normalizeGroupWisherLists). */
  function normalizeGroupWisherLists(group) {
    const rb = Array.isArray(group.requested_by) ? group.requested_by : [];
    const cal = Array.isArray(group.createdAt_list) ? group.createdAt_list : [];
    const dedupedRb = [];
    const dedupedCal = [];
    const fallbackTs = group.createdAt;

    function calAt(i) {
      if (i < cal.length) return cal[i];
      if (dedupedCal.length) return dedupedCal[dedupedCal.length - 1];
      return fallbackTs;
    }

    rb.forEach((raw, i) => {
      const n = String(raw || '').trim();
      if (!n) {
        dedupedRb.push('');
        const ts = calAt(i);
        if (ts) dedupedCal.push(ts);
        return;
      }
      if (dedupedRb.includes(n)) return;
      dedupedRb.push(n);
      const ts = calAt(i);
      if (ts) dedupedCal.push(ts);
    });

    group.requested_by = dedupedRb;
    group.createdAt_list = dedupedCal;
  }

  function padWisherListsToWishTotal(group, unusedShadowTimes) {
    const total = group.wish_total_count || 1;
    if (total <= 1) return;
    const rb = Array.isArray(group.requested_by) ? group.requested_by.slice() : [];
    if (rb.length >= total) return;
    const cal = Array.isArray(group.createdAt_list) ? group.createdAt_list.slice() : [];
    const shadowQueue = Array.isArray(unusedShadowTimes) ? unusedShadowTimes.slice() : [];
    const tsFallback = group.latest_createdAt || group.createdAt;
    while (rb.length < total) {
      rb.push('');
      if (cal.length < rb.length) {
        const fromShadow = shadowQueue.shift();
        cal.push(fromShadow || tsFallback || group.createdAt);
      }
    }
    group.requested_by = rb;
    group.createdAt_list = cal;
  }

  function withoutDuplicateShadowDocuments(wishes) {
    return wishes.filter((w) => w.is_duplicate !== true);
  }

  /**
   * @returns {Array<{groupKey:string, docIds:string[], primaryId:string, group:object, sortMs:number}>}
   */
  function groupWishesForDisplay(primaryWishes, allWishesForShadows, partyId, ignoredKeywords) {
    const grouped = {};
    const docIdsByKey = {};
    const allForShadows = allWishesForShadows || primaryWishes;
    const shadowTsByPerson = shadowTimestampsByPerson(allForShadows, partyId, ignoredKeywords);

    primaryWishes.forEach((wish) => {
      const groupKey = groupKeyForWish(wish, partyId, ignoredKeywords);
      if (!grouped[groupKey]) {
        const names = namesForWish(wish);
        grouped[groupKey] = {
          title: displayTitle(wish),
          artist: displayArtist(wish),
          firestore_duplicate_count: Number(wish.duplicate_count) || 0,
          duplicate_count: Number(wish.duplicate_count) || 0,
          requested_by: names,
          greetings: mergeGreetings([], wish),
          createdAt: wishCreatedTs(wish),
          createdAt_list: createdAtListForNames(names, wish, groupKey, shadowTsByPerson),
          is_favorite: wish.is_favorite === true,
          is_pre_wish: wish.is_pre_wish === true,
          pre_wish_published: wish.pre_wish_published === true,
          is_dj_wish: wish.is_dj_wish === true,
          from_setlist: wish.from_setlist === true,
          auto_recognized: wish.auto_recognized === true,
          status: wish.status,
        };
        docIdsByKey[groupKey] = [String(wish.id)];
      } else {
        const group = grouped[groupKey];
        const existingNames = group.requested_by.slice();
        const existingCal = Array.isArray(group.createdAt_list) ? group.createdAt_list.slice() : [];
        const namesToAdd = namesToAddWhenMerging(wish, existingNames);
        const ts = wishCreatedTs(wish);

        if (namesToAdd.length) {
          namesToAdd.forEach((n) => {
            existingNames.push(n);
            const shadow = shadowTsByPerson[groupKey + '|' + n];
            existingCal.push(shadow || ts);
          });
        } else if (!namesForWish(wish).filter(Boolean).length) {
          existingNames.push('');
          if (ts) existingCal.push(ts);
        }

        group.requested_by = existingNames;
        group.createdAt_list = existingCal;
        group.greetings = mergeGreetings(group.greetings, wish);
        if (wish.is_favorite === true) group.is_favorite = true;
        if (wish.is_pre_wish === true) group.is_pre_wish = true;
        if (wish.pre_wish_published === true) group.pre_wish_published = true;
        if (wish.is_dj_wish === true) group.is_dj_wish = true;
        if (wish.from_setlist === true) group.from_setlist = true;
        if (wish.auto_recognized === true) group.auto_recognized = true;
        if (tsToMillis(ts) > tsToMillis(group.createdAt)) group.createdAt = ts;
        docIdsByKey[groupKey].push(String(wish.id));
      }
    });

    const entries = [];
    Object.keys(grouped).forEach((groupKey) => {
      const group = grouped[groupKey];
      mergeShadowWisherInfo(group, groupKey, allForShadows, partyId, ignoredKeywords);
      applyPerPersonTimestamps(group, groupKey, shadowTsByPerson);
      normalizeGroupWisherLists(group);

      const cal = group.createdAt_list || [];
      const rb = group.requested_by || [];
      const fromLists = cal.length || rb.length || 1;
      const fsDup = Number(group.firestore_duplicate_count) || 0;
      const shadowDup = duplicateShadowCountForGroup(groupKey, allForShadows, partyId, ignoredKeywords);
      const total = wishTotalCountFromParts(fromLists, fsDup, shadowDup);
      group.wish_total_count = total;
      group.duplicate_count = total > 1 ? total - 1 : 0;
      const claimed = (group.requested_by || [])
        .map((n) => String(n || '').trim())
        .filter(Boolean);
      const unusedShadows = unusedShadowTimestamps(
        allForShadows,
        partyId,
        ignoredKeywords,
        groupKey,
        claimed,
      );
      padWisherListsToWishTotal(group, unusedShadows);

      const timestamps = (group.createdAt_list || []).slice().sort((a, b) => tsToMillis(a) - tsToMillis(b));
      if (timestamps.length) {
        group.oldest_createdAt = timestamps[0];
        group.latest_createdAt = timestamps[timestamps.length - 1];
        group.createdAt = group.latest_createdAt;
      }

      entries.push({
        groupKey: groupKey,
        docIds: docIdsByKey[groupKey] || [],
        primaryId: (docIdsByKey[groupKey] || [])[0] || '',
        group: group,
        sortMs: tsToMillis(group.createdAt),
      });
    });

    entries.sort((a, b) => b.sortMs - a.sortMs);
    return entries;
  }

  function buildWishersList(group, noNameLabel) {
    let names = dedupeNamesPreserveOrder(
      (Array.isArray(group.requested_by) ? group.requested_by : []).map((n) => String(n ?? '')),
    );
    const cal = Array.isArray(group.createdAt_list) ? group.createdAt_list : [];
    const greetings = Array.isArray(group.greetings) ? group.greetings : [];
    const total = wishTotalCount(group);
    while (names.length < total) names.push('');
    names = names.slice(0, total);

    return names.map((rawName, i) => {
      const name = String(rawName || '').trim() || noNameLabel;
      const match = greetings.find(
        (g) => String(g.name || '').trim() === String(rawName || '').trim(),
      );
      return {
        name: name,
        rawName: rawName,
        greeting: match ? String(match.greeting || '').trim() : '',
        createdAt: i < cal.length ? cal[i] : group.createdAt,
      };
    });
  }

  global.DjWishGrouping = {
    IGNORED_KEYWORDS_DEFAULT: IGNORED_KEYWORDS_DEFAULT,
    normalizeTextForDuplicateCheck: normalizeTextForDuplicateCheck,
    withoutDuplicateShadowDocuments: withoutDuplicateShadowDocuments,
    groupWishesForDisplay: groupWishesForDisplay,
    wishTotalCount: wishTotalCount,
    buildWishersList: buildWishersList,
    displayTitle: displayTitle,
    displayArtist: displayArtist,
  };
})(window);
