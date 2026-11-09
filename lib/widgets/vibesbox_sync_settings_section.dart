import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../services/dj_recognition_choice.dart';
import '../services/rb_tool_service.dart';
import '../services/user_service.dart';
import '../services/vibesbox_sync_service.dart';
import '../utils/ui_constants.dart';
import 'settings_choice_row.dart';

/// Admin-only: Verbindung zum Desktop-Tool und optional Song-Übernahme.
class VibesBoxSyncSettingsSection extends StatefulWidget {
  const VibesBoxSyncSettingsSection({
    super.key,
    this.showTitle = true,
    this.showEnableSwitch = true,
  });

  /// Überschrift ausblenden, wenn die Auswahl darüber schon „VibesBox Sync“ zeigt.
  final bool showTitle;

  /// Der Haken schreibt `vibesbox_sync_enabled`. In den Einstellungen
  /// setzt das die Auswahl oben; dort bleibt der Haken unsichtbar.
  final bool showEnableSwitch;

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await DjRecognitionChoiceStore.save(
        uid,
        value ? DjRecognitionChoice.sync : DjRecognitionChoice.microphone,
      );
    }
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
      await VibesBoxSyncService.instance.attachAfterPairingCode();
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
    final allowed = sync.isVisibleForCurrentUser;
    final l = AppLocalizations.of(context)!;
    final enabled = sync.enabled;
    final connected = sync.connected;
    final device = sync.deviceLabel;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Text(
            l.vibesbox_sync_title,
            style: SettingsType.title.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
        ],
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              connected
                  ? (device.isEmpty
                      ? l.vibesbox_sync_logged_in_plain
                      : l.vibesbox_sync_logged_in(device))
                  : (device.isEmpty
                      ? l.vibesbox_sync_needs_code_plain
                      : l.vibesbox_sync_needs_code(device)),
              style: TextStyle(
                color: connected ? Colors.greenAccent : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (connected)
              TextButton(
                onPressed: _disconnecting ? null : _disconnect,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _disconnecting ? '…' : l.vibesbox_sync_disconnect,
                ),
              ),
            TextButton(
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
                    : l.vibesbox_sync_generate_code,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.showEnableSwitch
              ? l.vibesbox_sync_about
              : l.translate('vibesbox_sync_about_selected'),
          style: SettingsType.hint,
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: () => _openDownload(VibesBoxSyncSettingsSection.macDownloadUrl),
              child: Text(l.vibesbox_sync_mac),
            ),
            TextButton(
              onPressed: () => _openDownload(
                VibesBoxSyncSettingsSection.windowsDownloadUrl,
              ),
              child: Text(l.vibesbox_sync_windows),
            ),
          ],
        ),
        if (widget.showEnableSwitch)
          SettingsChoiceRow(
            value: enabled,
            title: l.vibesbox_sync_switch,
            hint: l.vibesbox_sync_hint,
            enabled: allowed,
            onChanged: allowed ? (v) => _onToggle(v) : null,
          ),
      ],
    );
    if (allowed) return column;
    return Stack(
      children: [
        IgnorePointer(
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0, 0, 0, 0.55, 0,
            ]),
            child: column,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Text(
            l.vibesbox_sync_coming_soon,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
  bool _popScheduled = false;
  late final bool _openedConnected;
  late final String _openedDevice;
  bool _sawGap = false;

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
    final sync = VibesBoxSyncService.instance;
    _openedConnected = sync.connected;
    _openedDevice = sync.deviceLabel;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingMs <= 0) {
        _popWhenReady();
        return;
      }
      setState(() {});
    });
    _connectWatch = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      _closeWhenNewLogin();
    });
    VibesBoxSyncService.instance.addListener(_onSync);
  }

  void _onSync() {
    if (!mounted) return;
    _closeWhenNewLogin();
  }

  /// Ein schon verbundenes Sync bleibt offen. Zu geht der Dialog,
  /// wenn ein neues Gerät den Code annimmt.
  void _closeWhenNewLogin() {
    final sync = VibesBoxSyncService.instance;
    final now = sync.connected;
    final device = sync.deviceLabel;
    if (_openedConnected && !now) _sawGap = true;
    final freshLogin = !_openedConnected && now;
    final replaced = _openedConnected && _sawGap && now;
    final otherDevice = _openedConnected &&
        now &&
        device.isNotEmpty &&
        device != _openedDevice;
    if (freshLogin || replaced || otherDevice) _popWhenReady();
  }

  void _popWhenReady() {
    if (_popScheduled) return;
    _popScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _popScheduled = false;
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
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
          child: Text(l.ok),
        ),
      ],
    );
  }
}
