enum EventSetlistSizeMode { songs, duration }

/// DJ-Vorgaben für die KI-Setliste (strukturiert für stabile Prompt-Qualität).
class EventSetlistInput {
  const EventSetlistInput({
    required this.occasionId,
    required this.occasionOther,
    required this.genreIds,
    required this.artistsMust,
    required this.blacklist,
    required this.ageStructure,
    required this.marketIds,
    required this.marketPercents,
    required this.bpmBandId,
    required this.energyCurveId,
    required this.familiarityId,
    required this.scopeId,
    required this.sizeMode,
    required this.songCount,
    required this.durationHours,
  });

  static const int minSongs = 1;
  static const int maxSongs = 500;
  static const int maxStoredSongs = 1000;
  static const int minHours = 1;
  static const int maxHours = 24;
  static const double minutesPerSong = 3.5;
  /// Max. Gäste-Regionen mit %-Verteilung.
  static const int maxMarkets = 3;

  static const List<String> ageOptionIds = <String>[
    '10_20',
    '20_30',
    '30_40',
    '40_50',
    '50_60',
    'over_60',
  ];

  /// Legacy-Entwurf / alte Chips → stabile ID.
  static String normalizeAgeId(String raw) {
    final s = raw
        .trim()
        .toLowerCase()
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('ü', 'u');
    switch (s) {
      case '10-20':
      case '10_20':
        return '10_20';
      case '20-30':
      case '20_30':
        return '20_30';
      case '30-40':
      case '30_40':
        return '30_40';
      case '40-50':
      case '40_50':
        return '40_50';
      case '50-60':
      case '50_60':
        return '50_60';
      case 'uber 60':
      case 'over 60':
      case 'over_60':
        return 'over_60';
      default:
        final t = raw.trim();
        return ageOptionIds.contains(t) ? t : '';
    }
  }

  /// @Deprecated — Alias für [ageOptionIds].
  static List<String> get ageOptions => ageOptionIds;

  /// Stable IDs → Prompt (englisch/neutral), Labels via l10n.
  static const List<String> occasionOptionIds = <String>[
    'wedding',
    'birthday',
    'corporate',
    'club',
    'graduation',
    'village_festival',
    'private_party',
    'other',
  ];

  static const List<String> genreOptionIds = <String>[
    // Jahrzehnte / Äras (als Genre-Chips, keine zweite Rubrik)
    '70s',
    '80s',
    '90s',
    '00s',
    '10s',
    '20s',
    // Mainstream
    'pop',
    'charts',
    'evergreen',
    'rock',
    'indie',
    // Dance / Electronic
    'disco',
    'house',
    'techno',
    'edm',
    'trance',
    'drum_and_bass',
    'eurodance',
    // Urban
    'hiphop',
    'rnb',
    'trap',
    'funk',
    'soul',
    // Latin / Caribbean
    'latin',
    'reggaeton',
    'salsa',
    'cumbia',
    'reggae_dancehall',
    // Africa
    'afrobeats',
    'amapiano',
    // Regionale Party-Welten
    'discofox',
    'schlager',
    'sertanejo',
    'brazilian_funk',
    'bollywood',
    'arabic',
    'kpop',
    'jpop',
    'turkish',
    'greek_laiko',
    'disco_polo',
    'country',
  ];

  /// Mehrfach wählbar. Leer = Auto (App-Sprache).
  static const List<String> marketOptionIds = <String>[
    // DACH / Europa
    'de', 'at', 'ch', 'nl', 'be', 'fr', 'it', 'es', 'pt-PT', 'pl', 'cs', 'sk',
    'hu', 'ro', 'bg', 'hr', 'rs', 'si', 'ba', 'mk', 'sq', 'el', 'tr', 'uk', 'ru',
    'se', 'no', 'dk', 'fi', 'ie', 'gb',
    // Amerika
    'us', 'ca', 'mx', 'pt-BR', 'argentina', 'co', 'cl', 'pe', 'cu', 'do',
    // Asien / Pazifik
    'vi', 'th', 'hi', 'id', 'my', 'ph', 'sg', 'kr', 'ja', 'zh', 'tw', 'kh', 'au', 'nz',
    // Afrika / Nahost
    'ar', 'za', 'ng', 'eg', 'ma', 'il',
    // International EN (Fallback-Mix)
    'en',
  ];

  static const List<String> bpmBandOptionIds = <String>[
    'any',
    'slow_80_110',
    'fox_110_130',
    'house_120_128',
    'peak_125_140',
    'open_100_140',
  ];

  static const List<String> energyCurveOptionIds = <String>[
    'warm_peak_cool',
    'flat_peak',
    'slow_build',
    'high_energy',
  ];

  static const List<String> familiarityOptionIds = <String>[
    'hits',
    'mix',
    'deep',
  ];

  static const List<String> scopeOptionIds = <String>[
    'strict',
    'similar',
    'bold',
  ];

  /// Prompt-Labels (neutral, für OpenAI — nicht UI).
  static const Map<String, String> genrePromptLabels = <String, String>{
    '70s': '1970s dance / pop / disco era',
    '80s': '1980s dance / pop',
    '90s': '1990s dance / pop',
    '00s': '2000s dance / pop / charts',
    '10s': '2010s dance / pop / charts',
    '20s': '2020s dance / pop / charts',
    'pop': 'Pop',
    'charts': 'Current charts',
    'evergreen': 'Evergreens / classics',
    'rock': 'Rock',
    'indie': 'Indie / alternative pop',
    'disco': 'Disco',
    'house': 'House',
    'techno': 'Techno',
    'edm': 'EDM / big-room',
    'trance': 'Trance',
    'drum_and_bass': 'Drum and Bass',
    'eurodance': 'Eurodance / Hands Up',
    'hiphop': 'Hip-Hop / Rap',
    'rnb': 'R&B',
    'trap': 'Trap',
    'funk': 'Funk',
    'soul': 'Soul',
    'latin': 'Latin dancefloor',
    'reggaeton': 'Reggaeton',
    'salsa': 'Salsa / Bachata',
    'cumbia': 'Cumbia',
    'reggae_dancehall': 'Reggae / Dancehall',
    'afrobeats': 'Afrobeats',
    'amapiano': 'Amapiano',
    'discofox': 'Discofox',
    'schlager': 'German Schlager / Partyfox',
    'sertanejo': 'Sertanejo',
    'brazilian_funk': 'Brazilian Funk / Funk carioca',
    'bollywood': 'Bollywood / Hindi party',
    'arabic': 'Arabic pop / Shaabi / Khaleeji',
    'kpop': 'K-Pop',
    'jpop': 'J-Pop',
    'turkish': 'Turkish pop / dance',
    'greek_laiko': 'Greek Laiko / Nisiotika party',
    'disco_polo': 'Disco Polo',
    'country': 'Country',
  };

  static const Map<String, String> occasionPromptLabels = <String, String>{
    'wedding': 'Wedding',
    'birthday': 'Birthday party',
    'corporate': 'Corporate event',
    'club': 'Club / techno night',
    'graduation': 'Graduation / school party',
    'village_festival': 'Village / folk festival',
    'private_party': 'Private party',
    'other': 'Other occasion',
  };

  static const Map<String, String> marketPromptLabels = <String, String>{
    'de': 'Germany',
    'at': 'Austria',
    'ch': 'Switzerland',
    'nl': 'Netherlands',
    'be': 'Belgium',
    'fr': 'France',
    'it': 'Italy',
    'es': 'Spain',
    'pt-PT': 'Portugal',
    'pl': 'Poland',
    'cs': 'Czechia',
    'sk': 'Slovakia',
    'hu': 'Hungary',
    'ro': 'Romania',
    'bg': 'Bulgaria',
    'hr': 'Croatia',
    'rs': 'Serbia',
    'si': 'Slovenia',
    'ba': 'Bosnia and Herzegovina',
    'mk': 'North Macedonia',
    'sq': 'Albania',
    'el': 'Greece',
    'tr': 'Turkey',
    'uk': 'Ukraine',
    'ru': 'Russia',
    'se': 'Sweden',
    'no': 'Norway',
    'dk': 'Denmark',
    'fi': 'Finland',
    'ie': 'Ireland',
    'gb': 'United Kingdom',
    'us': 'United States',
    'ca': 'Canada',
    'mx': 'Mexico',
    'pt-BR': 'Brazil',
    'argentina': 'Argentina',
    'co': 'Colombia',
    'cl': 'Chile',
    'pe': 'Peru',
    'cu': 'Cuba',
    'do': 'Dominican Republic',
    'vi': 'Vietnam',
    'th': 'Thailand',
    'hi': 'India',
    'id': 'Indonesia',
    'my': 'Malaysia',
    'ph': 'Philippines',
    'sg': 'Singapore',
    'kr': 'South Korea',
    'ja': 'Japan',
    'zh': 'China',
    'tw': 'Taiwan',
    'kh': 'Cambodia',
    'au': 'Australia',
    'nz': 'New Zealand',
    'ar': 'Arabic-speaking markets',
    'za': 'South Africa',
    'ng': 'Nigeria',
    'eg': 'Egypt',
    'ma': 'Morocco',
    'il': 'Israel',
    'en': 'International English dancefloor',
  };

  final String occasionId;
  final String occasionOther;
  final List<String> genreIds;
  final String artistsMust;
  final String blacklist;
  final String ageStructure;
  final List<String> marketIds;
  /// Anteil je Markt-ID, Summe immer 100 (wenn Märkte gesetzt).
  final Map<String, int> marketPercents;
  final String bpmBandId;
  final String energyCurveId;
  final String familiarityId;
  final String scopeId;
  final EventSetlistSizeMode sizeMode;
  final int songCount;
  final int durationHours;

  /// Kompatibel für Music-Guard / Legacy: Anlass + Genres + Artists als Blob.
  String get eventTypeBlob {
    final base = occasionPromptLabels[occasionId] ?? occasionId;
    if (occasionId == 'other' && occasionOther.trim().isNotEmpty) {
      return '$base: ${occasionOther.trim()}';
    }
    return base;
  }

  String get preferredBlob {
    final parts = <String>[];
    if (genreIds.isNotEmpty) {
      parts.add(
        genreIds
            .map((id) => genrePromptLabels[id] ?? id)
            .join(', '),
      );
    }
    if (artistsMust.trim().isNotEmpty) {
      parts.add('Must-play artists: ${artistsMust.trim()}');
    }
    return parts.join('. ');
  }

  int get resolvedSongCount {
    if (sizeMode == EventSetlistSizeMode.duration) {
      return songsForHours(durationHours);
    }
    return songCount.clamp(minSongs, maxSongs);
  }

  static int songsForHours(int hours) {
    final h = hours.clamp(minHours, maxHours);
    return ((h * 60) / minutesPerSong).round().clamp(minSongs, maxSongs);
  }

  static List<String> sanitizeIds(
    Iterable<String> raw,
    List<String> allowed, {
    int? maxItems,
  }) {
    final out = <String>[];
    for (final id in raw) {
      if (!allowed.contains(id)) continue;
      if (out.contains(id)) continue;
      out.add(id);
      if (maxItems != null && out.length >= maxItems) break;
    }
    return out;
  }

  static String pickId(String? raw, List<String> allowed, String fallback) {
    final s = (raw ?? '').trim();
    return allowed.contains(s) ? s : fallback;
  }

  /// Gleichmäßige %-Verteilung auf [ids], Summe exakt 100.
  static Map<String, int> equalPercents(List<String> ids) {
    if (ids.isEmpty) return <String, int>{};
    if (ids.length == 1) return <String, int>{ids.first: 100};
    final base = 100 ~/ ids.length;
    var rest = 100 - (base * ids.length);
    final out = <String, int>{};
    for (final id in ids) {
      out[id] = base + (rest > 0 ? 1 : 0);
      if (rest > 0) rest--;
    }
    return out;
  }

  /// Hält nur Keys aus [ids], Summe = 100.
  static Map<String, int> normalizePercents(
    List<String> ids,
    Map<String, int> raw,
  ) {
    if (ids.isEmpty) return <String, int>{};
    if (ids.length == 1) return <String, int>{ids.first: 100};
    final cleaned = <String, int>{};
    for (final id in ids) {
      final v = raw[id] ?? 0;
      cleaned[id] = v < 0 ? 0 : (v > 100 ? 100 : v);
    }
    var sum = cleaned.values.fold<int>(0, (a, b) => a + b);
    if (sum <= 0) return equalPercents(ids);
    if (sum == 100) return cleaned;
    // Proportional skalieren, Rest auf ersten Key.
    final scaled = <String, int>{};
    var assigned = 0;
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      if (i == ids.length - 1) {
        scaled[id] = 100 - assigned;
      } else {
        final v = ((cleaned[id]! * 100) / sum).round();
        scaled[id] = v;
        assigned += v;
      }
    }
    // Negativ/Overflow absichern
    for (final id in ids) {
      if ((scaled[id] ?? 0) < 0) scaled[id] = 0;
    }
    sum = scaled.values.fold<int>(0, (a, b) => a + b);
    if (sum != 100) {
      final first = ids.first;
      scaled[first] = (scaled[first] ?? 0) + (100 - sum);
      if (scaled[first]! < 0) return equalPercents(ids);
    }
    return scaled;
  }

  /// Ein Slider ändern; andere werden angepasst, Summe bleibt 100.
  static Map<String, int> setPercentKeepingSum(
    List<String> ids,
    Map<String, int> current,
    String changedId,
    int newValue,
  ) {
    if (!ids.contains(changedId)) return normalizePercents(ids, current);
    if (ids.length == 1) return <String, int>{changedId: 100};
    final v = newValue.clamp(0, 100);
    final others = ids.where((id) => id != changedId).toList();
    final base = Map<String, int>.from(normalizePercents(ids, current));
    final oldOthersSum =
        others.fold<int>(0, (a, id) => a + (base[id] ?? 0));
    final targetOthers = 100 - v;
    base[changedId] = v;
    if (others.isEmpty) return normalizePercents(ids, base);
    if (oldOthersSum <= 0) {
      final share = targetOthers ~/ others.length;
      var rest = targetOthers - share * others.length;
      for (final id in others) {
        base[id] = share + (rest > 0 ? 1 : 0);
        if (rest > 0) rest--;
      }
      return normalizePercents(ids, base);
    }
    var assigned = 0;
    for (var i = 0; i < others.length; i++) {
      final id = others[i];
      if (i == others.length - 1) {
        base[id] = targetOthers - assigned;
      } else {
        final share =
            (((base[id] ?? 0) * targetOthers) / oldOthersSum).round();
        base[id] = share;
        assigned += share;
      }
    }
    return normalizePercents(ids, base);
  }
}
