import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tool_gate.dart';
import 'tool_i18n.dart';
import 'tool_session.dart';

class ToolWelcomePage extends StatefulWidget {
  const ToolWelcomePage({super.key, required this.onAccepted});

  final Future<void> Function() onAccepted;

  @override
  State<ToolWelcomePage> createState() => _ToolWelcomePageState();
}

class _ToolWelcomePageState extends State<ToolWelcomePage> {
  var _privacy = false;
  var _imprint = false;
  var _terms = false;
  var _hint = false;
  var _busy = false;

  bool get _all => _privacy && _imprint && _terms;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
              children: [
                Center(child: _logo(92)),
                const SizedBox(height: 18),
                const Text(
                  'VibesBox Sync',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF22E7FF),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  toolI18n.text('gateBody'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  toolI18n.text('gateAcceptLead'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _check(
                  value: _privacy,
                  label: toolI18n.text('gatePrivacy'),
                  url: kPrivacyUrl,
                  onChanged: (v) => setState(() => _privacy = v),
                ),
                _check(
                  value: _imprint,
                  label: toolI18n.text('gateImprint'),
                  url: kImprintUrl,
                  onChanged: (v) => setState(() => _imprint = v),
                ),
                _check(
                  value: _terms,
                  label: toolI18n.text('gateTerms'),
                  url: kTermsUrl,
                  onChanged: (v) => setState(() => _terms = v),
                ),
                if (_hint)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      toolI18n.text('gateMustCheck'),
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (!_all) {
                            setState(() => _hint = true);
                            return;
                          }
                          setState(() => _busy = true);
                          await widget.onAccepted();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8800),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(toolI18n.text('gateContinue')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToolConnectPage extends StatefulWidget {
  const ToolConnectPage({super.key, required this.session});

  final ToolSession session;

  @override
  State<ToolConnectPage> createState() => _ToolConnectPageState();
}

class _ToolConnectPageState extends State<ToolConnectPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.session,
          builder: (context, _) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
                  children: [
                    Center(child: _logo(72)),
                    const SizedBox(height: 16),
                    Text(
                      toolI18n.text('gateConnectTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      toolI18n.text('gateConnectBody'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                      ],
                      decoration: InputDecoration(
                        labelText: toolI18n.text('code'),
                        counterText: '',
                      ),
                    ),
                    if (widget.session.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.session.error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: widget.session.busy
                          ? null
                          : () => unawaited(
                                widget.session.connect(_controller.text),
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8800),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        widget.session.busy ? '…' : toolI18n.text('connectBtn'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Build $kSyncToolVersion · $kSyncToolWindowsBuildStamp',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF22E7FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ToolUpdatePage extends StatelessWidget {
  const ToolUpdatePage({super.key, required this.policy});

  final SyncToolPolicy policy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
              children: [
                Center(child: _logo(72)),
                const SizedBox(height: 16),
                Text(
                  toolI18n.text('updateRequiredTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  toolI18n.text('updateRequiredBody'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (policy.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    policy.note,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 18),
                if (policy.downloadUrl.isNotEmpty)
                  FilledButton(
                    onPressed: () => unawaited(openToolUrl(policy.downloadUrl)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8800),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(toolI18n.text('updateDownload')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToolOptionalUpdateBar extends StatelessWidget {
  const ToolOptionalUpdateBar({
    super.key,
    required this.policy,
    required this.onLater,
  });

  final SyncToolPolicy policy;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF8800)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              policy.note.isEmpty
                  ? toolI18n.text('updateOptionalBody')
                  : '${toolI18n.text('updateOptionalTitle')}: ${policy.note}',
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
          if (policy.downloadUrl.isNotEmpty)
            TextButton(
              onPressed: () => unawaited(openToolUrl(policy.downloadUrl)),
              child: Text(toolI18n.text('updateDownload')),
            ),
          TextButton(
            onPressed: onLater,
            child: Text(toolI18n.text('updateLater')),
          ),
        ],
      ),
    );
  }
}

class ToolLegalFooter extends StatelessWidget {
  const ToolLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Divider(color: Color(0xFF2A2A36), height: 12),
        const SizedBox(height: 6),
        Text(
          toolI18n.text('settingsLegal'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        _link(toolI18n.text('gatePrivacy'), kPrivacyUrl),
        _link(toolI18n.text('gateImprint'), kImprintUrl),
        _link(toolI18n.text('gateTerms'), kTermsUrl),
        const SizedBox(height: 6),
        Text(
          '${toolI18n.text('settingsVersion')} $kSyncToolVersion',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _link(String label, String url) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => unawaited(openToolUrl(url)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFFFF8800),
        ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

Widget _logo(double size) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.asset(
      'assets/vibesbox_logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

Widget _check({
  required bool value,
  required String label,
  required String url,
  required ValueChanged<bool> onChanged,
}) {
  return CheckboxListTile(
    value: value,
    onChanged: (v) => onChanged(v == true),
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    activeColor: const Color(0xFFFF8800),
    title: GestureDetector(
      onTap: () => unawaited(openToolUrl(url)),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFF8800),
          decoration: TextDecoration.underline,
          fontSize: 14,
        ),
      ),
    ),
  );
}
