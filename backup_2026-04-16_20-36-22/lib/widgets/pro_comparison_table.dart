import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Fügt in schmalen Spalten Soft-Hyphens ein für saubere Zeilenumbrüche.
String _softHyphen(String s) {
  return s
      .replaceAll('unbegrenzt', 'un\u00ADbe\u00ADgrenzt')
      .replaceAll('beendete', 'be\u00ADen\u00ADde\u00ADte');
}

/// Vergleichstabelle Free vs. Pro für die DJ-Startseite (nur bei Free-Status).
/// Vorschau: erste 4–5 Zeilen mit ShaderMask-Fade und "Alle Vorteile vergleichen".
/// Klick öffnet Full-View als zentriertes Dialog-Overlay (Mitgliedschafts-Karte).
class ProComparisonTable extends StatelessWidget {
  const ProComparisonTable({super.key});

  static const double _termFontSize = 12.0;
  static const double _freeProFontSize = 10.5;
  static const double _cellPaddingVertical = 10.0;
  static const double _cellPaddingHorizontal = 8.0;
  static const int _previewRowCount = 5;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => _showFullOverlay(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UIConstants.appOrange, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (Rect bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.0),
                ],
              ).createShader(bounds),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildTable(context, l, rowLimit: _previewRowCount),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: UIConstants.appOrange,
                    size: 28,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.pro_comparison_show_all,
                    style: const TextStyle(
                      fontSize: 13.0,
                      color: UIConstants.appOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullOverlay(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final maxHeight = MediaQuery.of(dialogContext).size.height * 0.85;
        final screenSize = MediaQuery.of(dialogContext).size;
        final dialogWidth = (screenSize.width * 0.95).clamp(0.0, 400.0);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: dialogWidth,
            height: maxHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UIConstants.appOrange, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildTable(
                      dialogContext,
                      l,
                      rowLimit: null,
                      dialogStyle: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pushNamed('/paywall');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: UIConstants.appOrange,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            l.pro_comparison_cta_button,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          l.close,
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTable(
    BuildContext context,
    AppLocalizations l, {
    int? rowLimit,
    bool dialogStyle = false,
  }) {
    final rows = _buildRowData(l);
    final dataRows = rowLimit == null ? rows : rows.take(rowLimit).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(context, l, dialogStyle: dialogStyle),
        ...dataRows.map((r) => r.build(context, dialogStyle: dialogStyle)),
      ],
    );
  }

  TableRow _headerRow(BuildContext context, AppLocalizations l, {bool dialogStyle = false}) {
    final double headerFontSize = dialogStyle ? _freeProFontSize : 11.0;
    final String freeLabel = (l.pro_comparison_vibesbox_free).toUpperCase();
    final String proLabel = (l.pro_comparison_vibesbox_pro).toUpperCase();
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: dialogStyle ? Colors.white10 : Colors.grey.shade600,
            width: 1,
          ),
        ),
      ),
      children: [
        _cell(context, '', align: TextAlign.left, bold: true, fontSize: _termFontSize),
        _cell(
          context,
          freeLabel,
          align: TextAlign.center,
          bold: true,
          fontSize: headerFontSize.toDouble(),
          color: Colors.red,
        ),
        _cell(
          context,
          proLabel,
          align: TextAlign.center,
          bold: true,
          fontSize: headerFontSize.toDouble(),
          color: Colors.green,
        ),
      ],
    );
  }

  List<_TableRowData> _buildRowData(AppLocalizations l) {
    return [
      _TableRowData.text(
        term: l.pro_comparison_party_anlegen,
        freeText: l.pro_comparison_one_per_month,
        proText: l.pro_comparison_unlimited,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_mic_settings,
        freeHasCheck: false,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_smart_adjustment,
        freeHasCheck: false,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_auto_music_recognition,
        freeHasCheck: false,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_live_translation,
        freeHasCheck: true,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_dj_logo_visible,
        freeHasCheck: false,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_social_media_links,
        freeHasCheck: false,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_favorites,
        freeHasCheck: false,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_guest_block,
        freeHasCheck: false,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_music_recognition,
        freeHasCheck: true,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_live_party_stats,
        freeHasCheck: true,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.statsAfterParty(
        term: l.pro_comparison_stats_after_party,
        freeText: l.pro_comparison_stats_last_finished_only,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
      _TableRowData.icon(
        term: l.pro_comparison_contact_form,
        freeHasCheck: false,
        cellPaddingV: _cellPaddingVertical,
        cellPaddingH: _cellPaddingHorizontal,
        termFontSize: _termFontSize,
      ),
    ];
  }

  Widget _cell(
    BuildContext context,
    String text, {
    TextAlign align = TextAlign.center,
    bool bold = false,
    double fontSize = 12.0,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: _cellPaddingVertical,
        horizontal: _cellPaddingHorizontal,
      ),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.white,
        ),
      ),
    );
  }
}

/// Hilfsklasse für eine Tabellenzeile (Text-Zeile oder Icon-Zeile).
class _TableRowData {
  _TableRowData._({
    required this.term,
    this.freeText,
    this.proText,
    this.freeHasCheck,
    this.statsAfterPartyFreeText,
    required this.cellPaddingV,
    required this.cellPaddingH,
    required this.termFontSize,
  });

  final String term;
  final String? freeText;
  final String? proText;
  final bool? freeHasCheck;
  final String? statsAfterPartyFreeText;
  final double cellPaddingV;
  final double cellPaddingH;
  final double termFontSize;

  factory _TableRowData.text({
    required String term,
    required String freeText,
    required String proText,
    required double cellPaddingV,
    required double cellPaddingH,
    required double termFontSize,
  }) {
    return _TableRowData._(
      term: term,
      freeText: freeText,
      proText: proText,
      cellPaddingV: cellPaddingV,
      cellPaddingH: cellPaddingH,
      termFontSize: termFontSize,
    );
  }

  factory _TableRowData.icon({
    required String term,
    required bool freeHasCheck,
    required double cellPaddingV,
    required double cellPaddingH,
    required double termFontSize,
  }) {
    return _TableRowData._(
      term: term,
      freeHasCheck: freeHasCheck,
      cellPaddingV: cellPaddingV,
      cellPaddingH: cellPaddingH,
      termFontSize: termFontSize,
    );
  }

  factory _TableRowData.statsAfterParty({
    required String term,
    required String freeText,
    required double cellPaddingV,
    required double cellPaddingH,
    required double termFontSize,
  }) {
    return _TableRowData._(
      term: term,
      statsAfterPartyFreeText: freeText,
      cellPaddingV: cellPaddingV,
      cellPaddingH: cellPaddingH,
      termFontSize: termFontSize,
    );
  }

  TableRow build(BuildContext context, {bool dialogStyle = false}) {
    final double freeProFontSize = dialogStyle ? 10.5 : 11.0;
    final freeProBold = dialogStyle;
    final rowDecoration = dialogStyle
        ? const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white10, width: 1),
            ),
          )
        : null;

    if (statsAfterPartyFreeText != null) {
      final text = dialogStyle ? _softHyphen(statsAfterPartyFreeText!) : statsAfterPartyFreeText!;
      return TableRow(
        decoration: rowDecoration,
        children: [
          _cell(context, term, fontSize: termFontSize, isTerm: true),
          _cell(
            context,
            text,
            align: TextAlign.center,
            fontSize: freeProFontSize.toDouble(),
            bold: freeProBold,
            softWrap: true,
          ),
          _proColumnCell(dialogStyle, _iconCell(Icons.check_circle, Colors.green)),
        ],
      );
    }
    if (freeText != null && proText != null) {
      final free = dialogStyle ? _softHyphen(freeText!) : freeText!;
      final pro = dialogStyle ? _softHyphen(proText!) : proText!;
      return TableRow(
        decoration: rowDecoration,
        children: [
          _cell(context, term, fontSize: termFontSize, isTerm: true),
          _cell(
            context,
            free,
            align: TextAlign.center,
            fontSize: freeProFontSize.toDouble(),
            bold: freeProBold,
            softWrap: true,
          ),
          _proColumnCell(
            dialogStyle,
            _cell(
              context,
              pro,
              align: TextAlign.center,
              fontSize: freeProFontSize.toDouble(),
              bold: freeProBold,
              color: UIConstants.appOrange,
              softWrap: true,
            ),
          ),
        ],
      );
    }
    final freeYes = freeHasCheck == true;
    return TableRow(
      decoration: rowDecoration,
      children: [
        _cell(context, term, fontSize: termFontSize, isTerm: true),
        Padding(
          padding: EdgeInsets.symmetric(vertical: cellPaddingV, horizontal: cellPaddingH),
          child: Center(
            child: Icon(
              freeYes ? Icons.check_circle : Icons.cancel,
              size: 22,
              color: freeYes ? Colors.green : Colors.red,
            ),
          ),
        ),
        _proColumnCell(
          dialogStyle,
          Padding(
            padding: EdgeInsets.symmetric(vertical: cellPaddingV, horizontal: cellPaddingH),
            child: const Center(
              child: Icon(Icons.check_circle, size: 22, color: Colors.green),
            ),
          ),
        ),
      ],
    );
  }

  /// Im Dialog: Pro-Spalte (Spalte 3) mit dezentem orangefarbenem Hintergrund-Schimmer.
  Widget _proColumnCell(bool dialogStyle, Widget child) {
    if (!dialogStyle) return child;
    return Container(
      color: UIConstants.appOrange.withValues(alpha: 0.06),
      child: child,
    );
  }

  Widget _cell(
    BuildContext context,
    String text, {
    TextAlign align = TextAlign.left,
    double fontSize = 12.0,
    Color? color,
    bool isTerm = false,
    bool bold = false,
    bool softWrap = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: cellPaddingV, horizontal: cellPaddingH),
      child: Text(
        text,
        textAlign: align,
        softWrap: isTerm || softWrap,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.white,
        ),
      ),
    );
  }

  Widget _iconCell(IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: cellPaddingV, horizontal: cellPaddingH),
      child: Center(child: Icon(icon, size: 22, color: color)),
    );
  }
}
