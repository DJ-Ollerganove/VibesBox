import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../services/dj_browser_service.dart';
import '../utils/ui_constants.dart';

/// Code-Dialog mit sofortigem Ladezustand — nur eine Instanz gleichzeitig.
class DjBrowserCodeDialog extends StatefulWidget {
  const DjBrowserCodeDialog({
    super.key,
    required this.partyId,
    required this.hostContext,
  });

  final String partyId;
  final BuildContext hostContext;

  static bool _flowActive = false;

  static Future<void> present(
    BuildContext context, {
    required String partyId,
  }) async {
    if (_flowActive) return;
    _flowActive = true;
    try {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) => DjBrowserCodeDialog(
          partyId: partyId,
          hostContext: context,
        ),
      );
    } finally {
      _flowActive = false;
    }
  }

  @override
  State<DjBrowserCodeDialog> createState() => _DjBrowserCodeDialogState();
}

class _DjBrowserCodeDialogState extends State<DjBrowserCodeDialog> {
  DjBrowserCodeResult? _result;
  bool _loading = true;
  bool _loadFailed = false;
  bool _cancelled = false;
  Timer? _timer;
  Timer? _statusPollTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_createCode());
  }

  Future<void> _createCode() async {
    try {
      final result =
          await DjBrowserService.instance.createCode(partyId: widget.partyId);
      if (!mounted || _loadFailed || _cancelled) return;
      setState(() {
        _result = result;
        _loading = false;
      });
      _startCountdownTimer();
      _startCodeStatusPolling();
    } catch (e) {
      if (!mounted) return;
      _loadFailed = true;
      if (widget.hostContext.mounted) {
        final l = AppLocalizations.of(widget.hostContext)!;
        final message = _createCodeErrorMessage(l, e);
        showVibesSnackBar(
          widget.hostContext,
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _createCodeErrorMessage(AppLocalizations l, Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'permission-denied') {
        return l.dj_browser_free_locked_description;
      }
      if (error.code == 'failed-precondition') {
        final msg = (error.message ?? '').toLowerCase();
        if (msg.contains('beendet') || msg.contains('ended')) {
          return l.dj_browser_party_ended;
        }
      }
    }
    return l.dj_browser_error_create;
  }

  void _startCountdownTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _result == null) return;
      if (_remainingMs <= 0) {
        unawaited(_onClose(revoke: true));
        return;
      }
      setState(() {});
    });
  }

  void _startCodeStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final code = _result?.code;
      if (!mounted || _closing || _cancelled || code == null || code.isEmpty) {
        return;
      }
      try {
        final status = await DjBrowserService.instance.getCodeStatus(
          partyId: widget.partyId,
          code: code,
        );
        if (!mounted || _closing || _cancelled) return;
        if (status.consumed) {
          await _onClose(revoke: false);
        }
      } catch (_) {
        // Polling-Fehler ignorieren — Countdown/Revoke bleibt aktiv.
      }
    });
  }

  int get _remainingMs {
    final expires = _result?.expiresAtMillis ?? 0;
    final left = expires - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? left : 0;
  }

  String get _countdownLabel {
    final totalSec = (_remainingMs / 1000).floor();
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _onClose({required bool revoke}) async {
    if (_closing) return;
    _closing = true;
    _cancelled = true;
    _timer?.cancel();
    _statusPollTimer?.cancel();
    final code = _result?.code;
    final partyId = widget.partyId;
    if (mounted) Navigator.of(context).pop();
    if (revoke && code != null && code.isNotEmpty) {
      unawaited(
        DjBrowserService.instance.revokeCode(
          partyId: partyId,
          code: code,
        ),
      );
    }
  }

  Future<void> _copyCode(AppLocalizations l) async {
    final code = _result?.code;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    showVibesSnackBar(
      widget.hostContext,
      SnackBar(
        content: Text(l.dj_browser_code_copied),
        backgroundColor: UIConstants.colorGreen,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_onClose(revoke: _result?.code != null));
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: UIConstants.djBrowserCodeDialogDecoration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 24),
            child: _loading ? _buildLoading(l, theme) : _buildCode(l, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(AppLocalizations l, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.dj_browser_dialog_title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              tooltip: l.close,
              onPressed: () => unawaited(_onClose(revoke: false)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: UIConstants.colorOrange,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l.dj_browser_creating_code,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildCode(AppLocalizations l, ThemeData theme) {
    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.dj_browser_dialog_title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              tooltip: l.close,
              onPressed: () => unawaited(_onClose(revoke: true)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l.dj_browser_dialog_body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          result.url.replaceFirst('https://', ''),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: UIConstants.colorOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => unawaited(_copyCode(l)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UIConstants.colorWhite, width: 2),
            ),
            child: Text(
              result.code,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                letterSpacing: 10,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l.dj_browser_dialog_countdown(_countdownLabel),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _remainingMs < 60000 ? Colors.redAccent : Colors.white54,
          ),
        ),
      ],
    );
  }
}
