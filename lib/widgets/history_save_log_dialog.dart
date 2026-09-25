import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/history_save_log_service.dart';
import '../utils/ui_constants.dart';
import '../app_scaffold_messenger.dart';

/// History-Speicher-Log anzeigen, kopieren und teilen (nur Admin-DJ).
class HistorySaveLogDialog extends StatelessWidget {
  const HistorySaveLogDialog({super.key});

  static Future<void> show(BuildContext context) {
    if (!HistorySaveLogService.canAccess) return Future<void>.value();
    return showDialog<void>(
      context: context,
      builder: (ctx) => const HistorySaveLogDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: UIConstants.djShellPageBackground,
      title: Text(
        l.history_save_log_title,
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: ValueListenableBuilder<int>(
          valueListenable: HistorySaveLogService.revision,
          builder: (context, _, __) {
            final lines = HistorySaveLogService.lines;
            if (lines.isEmpty) {
              return Text(
                l.history_save_log_empty,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              );
            }
            return ListView.builder(
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[lines.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: HistorySaveLogService.clear,
          child: Text(l.clear),
        ),
        TextButton(
          onPressed: () async {
            await HistorySaveLogService.copyToClipboard();
            if (context.mounted) {
              showVibesSnackBar(
                context,
                SnackBar(content: Text(l.log_copied_to_clipboard)),
              );
            }
          },
          child: Text(l.copy),
        ),
        TextButton(
          onPressed: () async {
            await HistorySaveLogService.share();
          },
          child: Text(l.share),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}
