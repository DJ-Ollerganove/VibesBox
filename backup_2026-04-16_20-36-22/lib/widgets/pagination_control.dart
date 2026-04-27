import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Zentrale Konstante für Items pro Seite
const int kItemsPerPage = 10;

/// Zentrales Widget für Pagination-Steuerung
/// Enthält Buttons für Vor/Zurück und Seitenanzeige
/// Unterstützt RTL-Sprachen (Arabisch)
class PaginationControl extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  const PaginationControl({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPreviousPage,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    // Wenn nur eine Seite oder weniger, zeige keine Pagination
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Zurück-Button
          ElevatedButton.icon(
            onPressed: _canGoPrevious() ? onPreviousPage : null,
            icon: Icon(
              isRtl ? Icons.arrow_forward : Icons.arrow_back,
              size: 18,
            ),
            label: Text(l.history_page_previous),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[800],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
          // Seitenanzeige
          Text(
            '${l.history_page} $currentPage / $totalPages',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
            textAlign: TextAlign.center,
          ),
          // Vor-Button
          ElevatedButton.icon(
            onPressed: _canGoNext() ? onNextPage : null,
            icon: Icon(
              isRtl ? Icons.arrow_back : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(l.history_page_next),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[800],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Prüft ob zur vorherigen Seite navigiert werden kann
  bool _canGoPrevious() {
    return currentPage > 1;
  }

  /// Prüft ob zur nächsten Seite navigiert werden kann
  bool _canGoNext() {
    return currentPage < totalPages;
  }
}

