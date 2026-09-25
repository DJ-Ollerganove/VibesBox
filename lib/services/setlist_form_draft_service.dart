import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_setlist_input.dart';

/// Letzte Setlisten-Formulareingaben (lokal, bis „FORMULARFELDER LEEREN“).
class SetlistFormDraft {
  const SetlistFormDraft({
    required this.occasionId,
    required this.occasionOther,
    required this.genreIds,
    required this.artistsMust,
    required this.blacklist,
    required this.marketIds,
    required this.marketPercents,
    required this.bpmBandId,
    required this.energyCurveId,
    required this.familiarityId,
    required this.scopeId,
    required this.ages,
    required this.mode,
    required this.songCount,
    required this.hours,
  });

  static const empty = SetlistFormDraft(
    occasionId: 'wedding',
    occasionOther: '',
    genreIds: <String>[],
    artistsMust: '',
    blacklist: '',
    marketIds: <String>[],
    marketPercents: <String, int>{},
    bpmBandId: 'any',
    energyCurveId: 'warm_peak_cool',
    familiarityId: 'hits',
    scopeId: 'strict',
    ages: <String>{},
    mode: EventSetlistSizeMode.songs,
    songCount: '20',
    hours: '6',
  );

  final String occasionId;
  final String occasionOther;
  final List<String> genreIds;
  final String artistsMust;
  final String blacklist;
  final List<String> marketIds;
  final Map<String, int> marketPercents;
  final String bpmBandId;
  final String energyCurveId;
  final String familiarityId;
  final String scopeId;
  final Set<String> ages;
  final EventSetlistSizeMode mode;
  final String songCount;
  final String hours;
}

class SetlistFormDraftService {
  SetlistFormDraftService._();

  static const _prefix = 'vb_setlist_form_draft_v5_';

  static Map<String, int> _parsePercents(List<String>? raw) {
    final out = <String, int>{};
    if (raw == null) return out;
    for (final entry in raw) {
      final parts = entry.split(':');
      if (parts.length != 2) continue;
      final id = parts[0].trim();
      final n = int.tryParse(parts[1].trim());
      if (id.isEmpty || n == null) continue;
      out[id] = n;
    }
    return out;
  }

  static Future<SetlistFormDraft> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final agesRaw = prefs.getStringList('${_prefix}ages') ?? const <String>[];
      final modeRaw = prefs.getString('${_prefix}mode') ?? 'songs';
      final genresRaw =
          prefs.getStringList('${_prefix}genres') ?? const <String>[];
      final marketsRaw =
          prefs.getStringList('${_prefix}markets') ?? const <String>[];
      final marketIds = EventSetlistInput.sanitizeIds(
        marketsRaw,
        EventSetlistInput.marketOptionIds,
        maxItems: EventSetlistInput.maxMarkets,
      );
      final percents = EventSetlistInput.normalizePercents(
        marketIds,
        _parsePercents(prefs.getStringList('${_prefix}marketPercents')),
      );
      return SetlistFormDraft(
        occasionId: EventSetlistInput.pickId(
          prefs.getString('${_prefix}occasionId'),
          EventSetlistInput.occasionOptionIds,
          'wedding',
        ),
        occasionOther: prefs.getString('${_prefix}occasionOther') ?? '',
        genreIds: EventSetlistInput.sanitizeIds(
          genresRaw,
          EventSetlistInput.genreOptionIds,
        ),
        artistsMust: prefs.getString('${_prefix}artistsMust') ?? '',
        blacklist: prefs.getString('${_prefix}blacklist') ?? '',
        marketIds: marketIds,
        marketPercents: percents,
        bpmBandId: EventSetlistInput.pickId(
          prefs.getString('${_prefix}bpmBandId'),
          EventSetlistInput.bpmBandOptionIds,
          'any',
        ),
        energyCurveId: EventSetlistInput.pickId(
          prefs.getString('${_prefix}energyCurveId'),
          EventSetlistInput.energyCurveOptionIds,
          'warm_peak_cool',
        ),
        familiarityId: EventSetlistInput.pickId(
          prefs.getString('${_prefix}familiarityId'),
          EventSetlistInput.familiarityOptionIds,
          'hits',
        ),
        scopeId: EventSetlistInput.pickId(
          prefs.getString('${_prefix}scopeId'),
          EventSetlistInput.scopeOptionIds,
          'strict',
        ),
        ages: agesRaw
            .map(EventSetlistInput.normalizeAgeId)
            .where((id) => id.isNotEmpty)
            .where(EventSetlistInput.ageOptionIds.contains)
            .toSet(),
        mode: modeRaw == 'duration'
            ? EventSetlistSizeMode.duration
            : EventSetlistSizeMode.songs,
        songCount: prefs.getString('${_prefix}songCount') ?? '20',
        hours: prefs.getString('${_prefix}hours') ?? '6',
      );
    } catch (_) {
      return SetlistFormDraft.empty;
    }
  }

  static Future<void> save(SetlistFormDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_prefix}occasionId', draft.occasionId);
      await prefs.setString('${_prefix}occasionOther', draft.occasionOther);
      await prefs.setStringList('${_prefix}genres', draft.genreIds);
      await prefs.setString('${_prefix}artistsMust', draft.artistsMust);
      await prefs.setString('${_prefix}blacklist', draft.blacklist);
      await prefs.setStringList('${_prefix}markets', draft.marketIds);
      await prefs.setStringList(
        '${_prefix}marketPercents',
        draft.marketPercents.entries
            .map((e) => '${e.key}:${e.value}')
            .toList(),
      );
      await prefs.setString('${_prefix}bpmBandId', draft.bpmBandId);
      await prefs.setString('${_prefix}energyCurveId', draft.energyCurveId);
      await prefs.setString('${_prefix}familiarityId', draft.familiarityId);
      await prefs.setString('${_prefix}scopeId', draft.scopeId);
      await prefs.setStringList('${_prefix}ages', draft.ages.toList());
      await prefs.setString(
        '${_prefix}mode',
        draft.mode == EventSetlistSizeMode.duration ? 'duration' : 'songs',
      );
      await prefs.setString('${_prefix}songCount', draft.songCount);
      await prefs.setString('${_prefix}hours', draft.hours);
    } catch (_) {}
  }

  static Future<void> clear() => save(SetlistFormDraft.empty);
}
