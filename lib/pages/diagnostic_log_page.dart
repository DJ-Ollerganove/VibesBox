import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_diagnostic_log_service.dart';
import '../widgets/custom_page_header.dart';

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
      case 'WARN':
        return Colors.orangeAccent;
      case 'SHAZAM':
        return Colors.lightBlueAccent;
      case 'LIFE':
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Expanded(
                    child: CustomPageHeader(
                      icon: Icons.bug_report_outlined,
                      title: 'Diagnose-Log',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Protokoll auf diesem Gerät (auch Release). Nach Absturz oder Freeze: '
                'hier prüfen oder exportieren. Keine automatische Cloud-Übertragung.',
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
                title: const Text(
                  'Aufzeichnung aktiv',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: Text(
                  _captureOn
                      ? 'Fehler, Lifecycle, Shazam & wichtige Events'
                      : 'Pausiert — nur Anzeige alter Einträge',
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
                  for (final f in ['ALL', 'ERROR', 'LIFE', 'SHAZAM', 'INFO', 'WARN'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f == 'ALL' ? 'Alle' : f),
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
                    label: 'Kopieren',
                    onPressed: _copyAll,
                  ),
                  _actionButton(
                    icon: Icons.share_outlined,
                    label: 'Teilen',
                    onPressed: _shareLog,
                  ),
                  _actionButton(
                    icon: Icons.delete_outline,
                    label: 'Leeren',
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
                        'Noch keine Einträge.\nApp nutzen — bei Problemen erscheinen Zeilen hier.',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log in Zwischenablage kopiert')),
    );
  }

  Future<void> _shareLog() async {
    final file = await AppDiagnosticLogService.instance.getLogFile();
    final text = await AppDiagnosticLogService.instance.exportAsText();
    if (file != null && await file.exists()) {
      await file.writeAsString(text, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain', name: 'vibesbox_diagnostic.log')],
        subject: 'VibesBox Diagnose-Log',
      );
    } else {
      await Share.share(text, subject: 'VibesBox Diagnose-Log');
    }
  }

  Future<void> _clearLog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log leeren?'),
        content: const Text('Alle Einträge auf diesem Gerät werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leeren'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AppDiagnosticLogService.instance.clear();
    if (mounted) setState(() {});
  }
}
