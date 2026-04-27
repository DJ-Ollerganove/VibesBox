import 'package:flutter/material.dart';
import 'pagination_control.dart';

/// Zentrales Widget für klebende Pagination-Buttons
/// Kapselt Stack, SafeArea, dynamische bottomGap-Berechnung und PaginationControl
/// Für Verwendung auf Listen-Seiten mit Pagination
class StickyPaginationLayout extends StatelessWidget {
  final Widget child;
  final int? totalPages;
  final int currentPage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Widget? stickyPagination;

  const StickyPaginationLayout({
    super.key,
    required this.child,
    this.totalPages,
    required this.currentPage,
    this.onPrevious,
    this.onNext,
    this.stickyPagination,
  });

  Widget _buildPagination(BuildContext context, int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();
    
    // Dynamischer Abstand zum unteren Rand
    // Mathematische Addition von System-Padding + Footer-Höhe - Überlappung
    final double bottomGap = MediaQuery.of(context).padding.bottom + 78.0 - 2.0;
    
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        margin: EdgeInsets.only(bottom: bottomGap),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: PaginationControl(
          currentPage: currentPage > 0 ? currentPage : 1,
          totalPages: totalPages,
          onPreviousPage: onPrevious,
          onNextPage: onNext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false, // TEST: SafeArea bottom deaktivieren, da wir padding.bottom manuell berücksichtigen
      child: Stack(
        children: [
          // Ebene 1: Scroll-Inhalt
          child,
          // Ebene 2: Sticky Buttons
          if (stickyPagination != null)
            stickyPagination!
          else if (totalPages != null)
            _buildPagination(context, totalPages!),
        ],
      ),
    );
  }
}
