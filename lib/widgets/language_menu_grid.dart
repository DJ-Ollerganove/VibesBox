import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/generated/language_menu_entries.g.dart';
import '../l10n/locale_helper.dart';
import '../utils/ui_constants.dart';

/// Sprachwahl: Spalten à [LanguageMenuEntries.rowsPerColumn], horizontal wischbar mit sichtbaren Hinweisen.
class LanguageMenuGrid extends StatefulWidget {
  const LanguageMenuGrid({
    super.key,
    required this.currentLanguageCode,
    required this.onLanguageSelected,
    this.compact = false,
    this.showSwipeHint = true,
    this.includeAdminOnlyLanguages = false,
  });

  final String currentLanguageCode;
  final ValueChanged<String> onLanguageSelected;
  final bool compact;
  final bool showSwipeHint;
  final bool includeAdminOnlyLanguages;

  @override
  State<LanguageMenuGrid> createState() => _LanguageMenuGridState();
}

class _LanguageMenuGridState extends State<LanguageMenuGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollHints());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() => _updateScrollHints();

  void _updateScrollHints() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final left = pos.pixels > 8;
    final right = pos.pixels < pos.maxScrollExtent - 8;
    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
  }

  void _scrollByPage(int direction) {
    if (!_scrollController.hasClients) return;
    final delta = (widget.compact ? 140.0 : 156.0) * direction;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = LanguageMenuEntries.columnsFor(
      includeAdminOnly: widget.includeAdminOnlyLanguages,
    );
    final columnWidth = widget.compact ? 132.0 : 148.0;
    final bg = const Color(0xFF1F2937);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.compact ? 280 : 300,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _updateScrollHints();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < columns.length; c++) ...[
                        if (c > 0) SizedBox(width: widget.compact ? 8 : 12),
                        SizedBox(
                          width: columnWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var r = 0; r < columns[c].length; r++) ...[
                                if (r > 0) SizedBox(height: widget.compact ? 4 : 6),
                                _LanguageMenuTile(
                                  entry: columns[c][r],
                                  isCurrent: columns[c][r].code ==
                                      widget.currentLanguageCode,
                                  compact: widget.compact,
                                  onTap: () => widget.onLanguageSelected(
                                    columns[c][r].code,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      // Letzte Spalte angeschnitten → Wisch-Hinweis
                      SizedBox(width: widget.compact ? 20 : 28),
                    ],
                  ),
                ),
              ),
              if (_canScrollLeft)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 36,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [bg, bg.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_canScrollRight)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 36,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [bg, bg.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_canScrollLeft)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ScrollChevron(
                      icon: Icons.chevron_left,
                      onTap: () => _scrollByPage(-1),
                    ),
                  ),
                ),
              if (_canScrollRight)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ScrollChevron(
                      icon: Icons.chevron_right,
                      onTap: () => _scrollByPage(1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.showSwipeHint && (_canScrollLeft || _canScrollRight)) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swipe,
                size: 16,
                color: UIConstants.appOrange.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _swipeHintText(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_left,
                size: 16,
                color: UIConstants.appOrange.withValues(alpha: 0.9),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: UIConstants.appOrange.withValues(alpha: 0.9),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _swipeHintText(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'de') return 'Nach links oder rechts wischen';
    return 'Swipe left or right for more languages';
  }
}

class _ScrollChevron extends StatelessWidget {
  const _ScrollChevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: UIConstants.appOrange, size: 28),
        ),
      ),
    );
  }
}

class _LanguageMenuTile extends StatelessWidget {
  const _LanguageMenuTile({
    required this.entry,
    required this.isCurrent,
    required this.compact,
    required this.onTap,
  });

  final LanguageMenuEntry entry;
  final bool isCurrent;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final padV = compact ? 6.0 : 8.0;
    final padH = compact ? 8.0 : 10.0;
    return Material(
      color: isCurrent
          ? UIConstants.appOrange.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Row(
            children: [
              Text(entry.flag, style: TextStyle(fontSize: compact ? 18 : 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isCurrent)
                const Icon(Icons.check, color: Colors.green, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog mit Spalten-Sprachmenü (App-Bar-Globus).
Future<void> showLanguagePickerDialog(
  BuildContext context, {
  required String currentLanguageCode,
  required ValueChanged<String> onLanguageSelected,
}) async {
  final includeAdminOnly = LocaleHelper.canUseAdminOnlyLanguages;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final selectLabel =
          AppLocalizations.of(dialogContext)?.selectLanguage ?? 'Language';
      return Dialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: UIConstants.appOrange, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(dialogContext).width * 0.92,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                LanguageMenuGrid(
                  currentLanguageCode: currentLanguageCode,
                  includeAdminOnlyLanguages: includeAdminOnly,
                  onLanguageSelected: (code) {
                    Navigator.of(dialogContext).pop();
                    // Locale erst im nächsten Frame — verhindert Descendant-Assertion
                    // beim gleichzeitigen MaterialApp-Rebuild.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      onLanguageSelected(code);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
