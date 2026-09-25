import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/app_diagnostic_log_service.dart';
import '../widgets/custom_page_header.dart';
import '../app_scaffold_messenger.dart';

/// Admin-DJ: Diagnoseprotokoll auf dem Gerät (Freeze, Abstürze, Shazam, Party).
class DiagnosticLogPage extends StatefulWidget {
  const DiagnosticLogPage({super.key});

  @override
  State<DiagnosticLogPage> createState() => _DiagnosticLogPageState();
}

class _DiagnosticLogPageState extends State<DiagnosticLogPage> {
  String _filter = 'ALL';
  bool _captureOn = true;

  @override
  void initState() {
    super.initState();
    _loadCaptureFlag();
  }

  Future<void> _loadCaptureFlag() async {
    await AppDiagnosticLogService.instance.install();
    if (!mounted) return;
    setState(() {
      _captureOn = AppDiagnosticLogService.instance.captureEnabledPreference;
    });
  }

  List<DiagnosticLogEntry> _filteredEntries() {
    final all = AppDiagnosticLogService.instance.entries;
    if (_filter == 'ALL') return all.reversed.toList();
    return all
        .where((e) => e.level == _filter)
        .toList()
        .reversed
        .toList();
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.redAccent;
      case 'SNACKBAR':
        return Colors.red;
      case 'PARTY':
        return Colors.deepOrangeAccent;
      case 'WARN':
        return Colors.orangeAccent;
      case 'SHAZAM':
        return Colors.lightBlueAccent;
      case 'HISTORY':
        return Colors.amberAccent;
      case 'LIFE':
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!AppDiagnosticLogService.canAccessDiagnosticUi()) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Text(
              'Nur für den Admin-DJ-Account.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: CustomPageHeader(
                      icon: Icons.bug_report_outlined,
                      title: l.diagnostic_log_title,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l.diagnostic_log_description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l.diagnostic_log_capture_active,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: Text(
                  _captureOn
                      ? l.diagnostic_log_capture_on_hint
                      : l.diagnostic_log_capture_off_hint,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
                value: _captureOn,
                activeThumbColor: Colors.orange,
                onChanged: (v) async {
                  await AppDiagnosticLogService.instance.setCaptureEnabled(v);
                  if (mounted) setState(() => _captureOn = v);
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final f in [
                    'ALL',
                    'SNACKBAR',
                    'PARTY',
                    'ERROR',
                    'LIFE',
                    'SHAZAM',
                    'HISTORY',
                    'INFO',
                    'WARN',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f == 'ALL' ? l.filter_all : f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: Colors.orange.withValues(alpha: 0.35),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _filter == f ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _actionButton(
                    icon: Icons.copy,
                    label: l.copy,
                    onPressed: _copyAll,
                  ),
                  _actionButton(
                    icon: Icons.share_outlined,
                    label: l.share,
                    onPressed: _shareLog,
                  ),
                  _actionButton(
                    icon: Icons.delete_outline,
                    label: l.clear,
                    onPressed: _clearLog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: AppDiagnosticLogService.instance.revision,
                builder: (context, _, _child) {
                  final items = _filteredEntries();
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        l.diagnostic_log_empty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final e = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _levelColor(e.level).withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.at.toLocal().toString().substring(0, 19)} · ${e.level}',
                              style: TextStyle(
                                color: _levelColor(e.level),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              e.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.orange),
      ),
    );
  }

  Future<void> _copyAll() async {
    final text = await AppDiagnosticLogService.instance.exportAsText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    showVibesSnackBar(context, 
      SnackBar(content: Text(l.log_copied_to_clipboard)),
    );
  }

  Future<void> _shareLog() async {
    final file = await AppDiagnosticLogService.instance.getLogFile();
    final text = await AppDiagnosticLogService.instance.exportAsText();
    if (file != null && await file.exists()) {
      await file.writeAsString(text, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain', name: 'vibesbox_diagnostic.log')],
        subject: AppLocalizations.of(context)!.diagnostic_log_share_subject,
      );
    } else {
      await Share.share(text, subject: AppLocalizations.of(context)!.diagnostic_log_share_subject);
    }
  }

  Future<void> _clearLog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
        title: Text(l.diagnostic_log_clear_title),
        content: Text(l.diagnostic_log_clear_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.clear),
          ),
        ],
      );
      },
    );
    if (ok != true) return;
    await AppDiagnosticLogService.instance.clear();
    if (mounted) setState(() {});
  }
}
