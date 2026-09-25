import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/pre_wish_export_models.dart';
import '../widgets/vibesbox_info_dialog.dart';
import '../utils/ui_constants.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

/// Formatwahl für Vorab-Wunsch-Export: Dropdown (alle Formate) + Export-Button.
class PreWishExportFormatDialog {
  PreWishExportFormatDialog._();

  static void _showFormatInfo(BuildContext context, AppLocalizations l) {
    showVibesBoxInfoDialog(
      context,
      title: l.pre_wish_export_format_info_title,
      body: l.pre_wish_export_format_info_body,
    );
  }

  static String _formatLabel(AppLocalizations l, PreWishExportFormat format) {
    switch (format) {
      case PreWishExportFormat.txt:
        return l.pre_wish_export_format_txt;
      case PreWishExportFormat.csv:
        return l.pre_wish_export_format_csv;
      case PreWishExportFormat.m3u:
        return l.pre_wish_export_format_m3u;
      case PreWishExportFormat.pls:
        return l.pre_wish_export_format_pls;
      case PreWishExportFormat.pdf:
        return l.pre_wish_export_format_pdf;
    }
  }

  static Future<PreWishExportFormat?> show(BuildContext context) {
    final isRtl = VbTextDirection.isRtl(context);
    final l = AppLocalizations.of(context)!;
    const borderColor = UIConstants.appGreen;

    return showDialog<PreWishExportFormat>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: _ExportFormatDialogBody(
          isRtl: isRtl,
          l10n: l,
          borderColor: borderColor,
          onInfo: () => _showFormatInfo(ctx, l),
          formatLabel: (f) => _formatLabel(l, f),
        ),
      ),
    );
  }
}

class _ExportFormatDialogBody extends StatefulWidget {
  const _ExportFormatDialogBody({
    required this.isRtl,
    required this.l10n,
    required this.borderColor,
    required this.onInfo,
    required this.formatLabel,
  });

  final bool isRtl;
  final AppLocalizations l10n;
  final Color borderColor;
  final VoidCallback onInfo;
  final String Function(PreWishExportFormat) formatLabel;

  @override
  State<_ExportFormatDialogBody> createState() =>
      _ExportFormatDialogBodyState();
}

class _ExportFormatDialogBodyState extends State<_ExportFormatDialogBody> {
  PreWishExportFormat? _selected;

  ButtonStyle get _greenButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: UIConstants.appGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        disabledBackgroundColor: UIConstants.appGreen.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white70,
      );

  @override
  Widget build(BuildContext context) {
    final l = widget.l10n;
    final isRtl = widget.isRtl;
    final hintStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: 14,
      fontStyle: FontStyle.italic,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: UIConstants.colorGreyGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.borderColor, width: 2),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.pre_wish_export_format_title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    size: 22,
                    color: UIConstants.appGreen.withValues(alpha: 0.95),
                  ),
                  tooltip: l.pre_wish_export_format_info_title,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: widget.onInfo,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: UIConstants.appGreen.withValues(alpha: 0.65),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PreWishExportFormat?>(
                        value: _selected,
                        isExpanded: true,
                        dropdownColor: UIConstants.bgGradientEnd,
                        hint: Text(l.pre_wish_export_choose_format, style: hintStyle),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: UIConstants.appGreen.withValues(alpha: 0.95),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        onChanged: (v) => setState(() => _selected = v),
                        items: [
                          DropdownMenuItem<PreWishExportFormat?>(
                            value: null,
                            enabled: false,
                            child: Text(
                              l.pre_wish_export_choose_format,
                              style: hintStyle,
                            ),
                          ),
                          ...preWishListExportFormats.map(
                            (f) => DropdownMenuItem<PreWishExportFormat?>(
                              value: f,
                              child: Text(widget.formatLabel(f)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
                  style: _greenButtonStyle,
                  child: Text(l.pre_wish_export),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l.cancel,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
