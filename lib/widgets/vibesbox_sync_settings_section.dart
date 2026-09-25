import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../services/rb_tool_service.dart';
import '../services/user_service.dart';
import '../services/vibesbox_sync_service.dart';
import '../utils/ui_constants.dart';

/// Admin-only: Verbindung zum Desktop-Tool und optional Song-Übernahme.
class VibesBoxSyncSettingsSection extends StatefulWidget {
  const VibesBoxSyncSettingsSection({super.key});

  static const macDownloadUrl =
      'https://vibesbox.app/download/vibesbox-sync-mac';
  static const windowsDownloadUrl =
      'https://vibesbox.app/download/vibesbox-sync-windows';

  @override
  State<VibesBoxSyncSettingsSection> createState() =>
      _VibesBoxSyncSettingsSectionState();
}

class _VibesBoxSyncSettingsSectionState
    extends State<VibesBoxSyncSettingsSection> {
  bool _creating = false;
  bool _disconnecting = false;

  @override
  void initState() {
    super.initState();
    VibesBoxSyncService.instance.addListener(_onSync);
    UserService().currentUser.addListener(_onSync);
  }

  @override
  void dispose() {
    VibesBoxSyncService.instance.removeListener(_onSync);
    UserService().currentUser.removeListener(_onSync);
    super.dispose();
  }

  void _onSync() {
    if (mounted) setState(() {});
  }

  Future<void> _onToggle(bool value) async {
    await VibesBoxSyncService.instance.setEnabled(value);
  }

  Future<void> _disconnect() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _disconnecting = true);
    try {
      await RbToolService.instance.disconnectOwnTool();
    } catch (_) {
      if (!mounted) return;
      showVibesSnackBar(
        context,
        SnackBar(content: Text(l.vibesbox_sync_error_create)),
      );
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  Future<void> _generateAndShowCode() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _creating = true);
    try {
      final result = await RbToolService.instance.createCode();
      if (!mounted) return;
      setState(() => _creating = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _VibesBoxSyncCodeDialog(result: result),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      showVibesSnackBar(
        context,
        SnackBar(content: Text(l.vibesbox_sync_error_create)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = VibesBoxSyncService.instance;
    if (!sync.isVisibleForCurrentUser) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context)!;
    final enabled = sync.enabled;
    final connected = sync.connected;
    final device = sync.deviceLabel;
    final muted = TextStyle(
      fontSize: 11,
      color: Colors.white.withValues(alpha: 0.65),
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.vibesbox_sync_title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              connected
                  ? l.vibesbox_sync_connected
                  : l.translate('vibesbox_sync_not_connected'),
              style: TextStyle(
                color: connected ? Colors.greenAccent : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            connected
                ? TextButton(
                    onPressed: _disconnecting ? null : _disconnect,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _disconnecting
                          ? '…'
                          : l.translate('vibesbox_sync_disconnect'),
                    ),
                  )
                : TextButton(
                    onPressed: _creating ? null : _generateAndShowCode,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: UIConstants.appOrange,
                    ),
                    child: Text(
                      _creating
                          ? l.admin_tool_creating_code
                          : l.translate('vibesbox_sync_connect'),
                    ),
                  ),
            if (connected && device.isNotEmpty)
              Text(
                l.tp('vibesbox_sync_with_device', {'device': device}),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.translate('vibesbox_sync_about'), style: muted),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: () => _openDownload(VibesBoxSyncSettingsSection.macDownloadUrl),
              child: Text(l.translate('vibesbox_sync_mac')),
            ),
            TextButton(
              onPressed: () => _openDownload(
                VibesBoxSyncSettingsSection.windowsDownloadUrl,
              ),
              child: Text(l.translate('vibesbox_sync_windows')),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeThumbColor: UIConstants.appOrange,
          title: Text(
            l.translate('vibesbox_sync_switch'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          value: enabled,
          onChanged: _onToggle,
        ),
        Text(l.vibesbox_sync_hint, style: muted),
      ],
    );
  }

  Future<void> _openDownload(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _VibesBoxSyncCodeDialog extends StatefulWidget {
  const _VibesBoxSyncCodeDialog({required this.result});

  final RbToolCodeResult result;

  @override
  State<_VibesBoxSyncCodeDialog> createState() => _VibesBoxSyncCodeDialogState();
}

class _VibesBoxSyncCodeDialogState extends State<_VibesBoxSyncCodeDialog> {
  Timer? _countdown;
  Timer? _connectWatch;

  int get _remainingMs {
    return (widget.result.expiresAtMillis -
            DateTime.now().millisecondsSinceEpoch)
        .clamp(0, 1 << 31);
  }

  String _formatRemain(int ms) {
    final s = (ms / 1000).ceil();
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingMs <= 0) {
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {});
    });
    _connectWatch = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      if (VibesBoxSyncService.instance.connected) {
        Navigator.of(context).maybePop();
      }
    });
    VibesBoxSyncService.instance.addListener(_onSync);
  }

  void _onSync() {
    if (!mounted) return;
    if (VibesBoxSyncService.instance.connected) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _connectWatch?.cancel();
    VibesBoxSyncService.instance.removeListener(_onSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final code = widget.result.code;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        l.vibesbox_sync_code_title,
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.vibesbox_sync_code_body,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 20),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.admin_tool_code_countdown(_formatRemain(_remainingMs)),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            l.vibesbox_sync_waiting,
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (!context.mounted) return;
            showVibesSnackBar(
              context,
              SnackBar(content: Text(l.admin_tool_code_copied)),
            );
          },
          child: Text(l.admin_tool_code_copied),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
