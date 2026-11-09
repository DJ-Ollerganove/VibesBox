import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/results_per_page_service.dart';
import '../app_scaffold_messenger.dart';
import 'settings_choice_row.dart';

/// DJ-Einstellung: Treffer pro Seite (Offen, Gespielt, Vorab-Liste, History, …).
class ResultsPerPageSettingsSection extends StatefulWidget {
  const ResultsPerPageSettingsSection({
    super.key,
    required this.textDirectionRtl,
  });

  final bool textDirectionRtl;

  @override
  State<ResultsPerPageSettingsSection> createState() =>
      _ResultsPerPageSettingsSectionState();
}

class _ResultsPerPageSettingsSectionState
    extends State<ResultsPerPageSettingsSection> {
  int _value = ResultsPerPageService.defaultResultsPerPage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await ResultsPerPageService.load();
    if (mounted) {
      setState(() {
        _value = v;
        _loading = false;
      });
    }
  }

  Future<void> _onChanged(int? next) async {
    if (next == null || next == _value) return;
    try {
      await ResultsPerPageService.save(next);
      if (!mounted) return;
      setState(() => _value = next);
      final l = AppLocalizations.of(context)!;
      final msg = l.settingsResultsPerPageSaved(next);
      showVibesSnackBar(context, 
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showVibesSnackBar(context, 
        SnackBar(
          content: Text(AppLocalizations.of(context)!.error),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = widget.textDirectionRtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              l.results_per_page,
              style: SettingsType.title.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
                ),
              )
            else
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _value,
                  dropdownColor: const Color(0xFF2A2A2A),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                  style: SettingsType.title,
                  items: ResultsPerPageService.allowedValues
                      .map(
                        (n) => DropdownMenuItem<int>(
                          value: n,
                          child: Text('$n'),
                        ),
                      )
                      .toList(),
                  onChanged: _onChanged,
                ),
              ),
            if (!_loading) ...[
              const SizedBox(height: 4),
              Text(
                l.translate('info_settings_results_count_body'),
                style: SettingsType.hint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
