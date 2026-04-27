
/// Service für die Paginierung der History.
/// Nutzt results_per_page aus den Einstellungen (party_settings/current).
class HistoryPaginationService {
  static const int _defaultItemsPerPage = 10;

  /// Berechnet die Gesamtanzahl der Seiten basierend auf der Anzahl der Items.
  /// [itemsPerPage] aus Einstellungen (z. B. ResultsPerPageService.current).
  static int calculateTotalPages(int totalItems, {int? itemsPerPage}) {
    if (totalItems <= 0) return 0;
    final perPage = itemsPerPage ?? _defaultItemsPerPage;
    return ((totalItems - 1) ~/ perPage) + 1;
  }

  /// Berechnet den Start-Index für die aktuelle Seite.
  static int calculateStartIndex(int currentPage, {int? itemsPerPage}) {
    final perPage = itemsPerPage ?? _defaultItemsPerPage;
    return (currentPage - 1) * perPage;
  }

  /// Berechnet den End-Index für die aktuelle Seite.
  static int calculateEndIndex(int currentPage, int totalItems, {int? itemsPerPage}) {
    final perPage = itemsPerPage ?? _defaultItemsPerPage;
    final endIndex = currentPage * perPage;
    return endIndex < totalItems ? endIndex : totalItems;
  }

  /// Gibt die Items für die aktuelle Seite zurück.
  static List<T> getItemsForPage<T>(List<T> allItems, int currentPage, {int? itemsPerPage}) {
    if (allItems.isEmpty) return [];
    final perPage = itemsPerPage ?? _defaultItemsPerPage;
    final startIndex = calculateStartIndex(currentPage, itemsPerPage: perPage);
    final endIndex = calculateEndIndex(currentPage, allItems.length, itemsPerPage: perPage);
    if (startIndex >= allItems.length) return [];
    return allItems.sublist(startIndex, endIndex);
  }

  /// Prüft ob die vorherige Seite verfügbar ist
  static bool hasPreviousPage(int currentPage) {
    return currentPage > 1;
  }

  /// Prüft ob die nächste Seite verfügbar ist
  static bool hasNextPage(int currentPage, int totalPages) {
    return currentPage < totalPages;
  }
}


