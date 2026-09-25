/// Ein Wünschende mit optionalem übersetztem Gruß (Vorab-Export).
class PreWishExportWisher {
  const PreWishExportWisher({
    required this.name,
    required this.greeting,
    this.translatedGreeting,
  });

  final String name;
  final String greeting;
  final String? translatedGreeting;
}

/// Ein exportierter Vorab-Wunsch (gruppiert wie in der Übersicht).
class PreWishExportSong {
  const PreWishExportSong({
    required this.artist,
    required this.title,
    required this.wishers,
    required this.sortKey,
    this.metaLine = '',
  });

  final String artist;
  final String title;
  final List<PreWishExportWisher> wishers;
  final DateTime sortKey;
  /// Optional: BPM, Dauer, Genre, Camelot (Setliste). Vorab bleibt leer.
  final String metaLine;

  /// TXT / CSV / M3U / PDF-Zeile: „Titel - Interpret“.
  String get titleArtistLine {
    final a = artist.trim();
    final t = title.trim();
    if (t.isNotEmpty && a.isNotEmpty) return '$t - $a';
    return t.isNotEmpty ? t : a;
  }

  /// Sortierung / Legacy: „Interpret - Titel“.
  String get displayLine {
    final a = artist.trim();
    final t = title.trim();
    if (a.isNotEmpty && t.isNotEmpty) return '$a - $t';
    return t.isNotEmpty ? t : a;
  }
}

enum PreWishExportFormat { txt, csv, pdf, m3u, pls }

/// Alle Formate im Export-Dropdown (Reihenfolge: TXT → CSV → M3U → PLS → PDF).
const List<PreWishExportFormat> preWishListExportFormats = [
  PreWishExportFormat.txt,
  PreWishExportFormat.csv,
  PreWishExportFormat.m3u,
  PreWishExportFormat.pls,
  PreWishExportFormat.pdf,
];
