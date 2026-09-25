import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Admin steuert VibesBox Sync. Gleiche Versionszeile wie die App-Matrix,
/// nur macOS und Windows. Das Tool ist nur für DJs.
class AdminSyncToolCard extends StatefulWidget {
  const AdminSyncToolCard({super.key});

  @override
  State<AdminSyncToolCard> createState() => _AdminSyncToolCardState();
}

class _AdminSyncToolCardState extends State<AdminSyncToolCard> {
  final _macMajor = TextEditingController();
  final _macMinor = TextEditingController();
  final _macPatch = TextEditingController();
  final _macUrl = TextEditingController();
  final _macNote = TextEditingController();
  final _winMajor = TextEditingController();
  final _winMinor = TextEditingController();
  final _winPatch = TextEditingController();
  final _winUrl = TextEditingController();
  final _winNote = TextEditingController();
  var _macRequired = false;
  var _winRequired = false;
  var _loading = true;
  var _saving = false;
  String? _message;

  static final _digits = [
    FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(2),
  ];

  static const _fieldDecoration = InputDecoration(
    border: OutlineInputBorder(),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.orange),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    isDense: true,
    counterText: '',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _macMajor.dispose();
    _macMinor.dispose();
    _macPatch.dispose();
    _macUrl.dispose();
    _macNote.dispose();
    _winMajor.dispose();
    _winMinor.dispose();
    _winPatch.dispose();
    _winUrl.dispose();
    _winNote.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_config')
          .doc('sync_tool')
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final shared = (data['min_version'] ?? data['latest_version'] ?? '')
          .toString();
      final mac = _first(data['mac_min_version'], _first(data['mac_latest_version'], shared));
      final win = _first(data['win_min_version'], _first(data['win_latest_version'], shared));
      final macParts = _parts(mac);
      final winParts = _parts(win);
      _macMajor.text = macParts[0];
      _macMinor.text = macParts[1];
      _macPatch.text = macParts[2];
      _winMajor.text = winParts[0];
      _winMinor.text = winParts[1];
      _winPatch.text = winParts[2];
      _macUrl.text = (data['mac_url'] ?? '').toString();
      _winUrl.text = (data['win_url'] ?? '').toString();
      final note = (data['note'] ?? '').toString();
      _macNote.text = _first(data['mac_note'], note);
      _winNote.text = _first(data['win_note'], note);
      _macRequired = (data['mac_min_version'] ?? '').toString().trim().isNotEmpty;
      _winRequired = (data['win_min_version'] ?? '').toString().trim().isNotEmpty;
    } catch (e) {
      _message = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final macUrl = _macUrl.text.trim();
    final winUrl = _winUrl.text.trim();
    if (!_urlOk(macUrl) || !_urlOk(winUrl)) {
      setState(() => _message = 'Download-Links müssen mit https beginnen, oder leer sein.');
      return;
    }
    final macVersion = _compose(_macMajor, _macMinor, _macPatch);
    final winVersion = _compose(_winMajor, _winMinor, _winPatch);
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await FirebaseFirestore.instance.collection('admin_config').doc('sync_tool').set({
        'mac_latest_version': _macRequired ? macVersion : '',
        'mac_min_version': _macRequired ? macVersion : '',
        'mac_url': macUrl,
        'mac_note': _macNote.text.trim(),
        'win_latest_version': _winRequired ? winVersion : '',
        'win_min_version': _winRequired ? winVersion : '',
        'win_url': winUrl,
        'win_note': _winNote.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _message = 'Gespeichert.');
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _first(Object? specific, String fallback) {
    final value = (specific ?? '').toString().trim();
    return value.isNotEmpty ? value : fallback;
  }

  List<String> _parts(String raw) {
    final bits = raw.split('+').first.split('.');
    String part(int i) {
      if (i >= bits.length) return '0';
      final n = int.tryParse(bits[i].trim());
      if (n == null || n < 0) return '0';
      return n > 99 ? '99' : '$n';
    }

    return [part(0), part(1), part(2)];
  }

  String _compose(
    TextEditingController major,
    TextEditingController minor,
    TextEditingController patch,
  ) {
    String cell(TextEditingController c) {
      final t = c.text.trim();
      if (t.isEmpty) return '0';
      final n = int.tryParse(t) ?? 0;
      return n > 99 ? '99' : '$n';
    }

    return '${cell(major)}.${cell(minor)}.${cell(patch)}';
  }

  bool _urlOk(String value) {
    if (value.isEmpty) return true;
    final uri = Uri.tryParse(value);
    return uri != null && uri.isScheme('https') && uri.host.isNotEmpty;
  }

  String _liveCell(Object? raw) {
    final t = (raw ?? '').toString().trim();
    return t.isEmpty ? '—' : t;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1F2937),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: Colors.orange),
          ),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_config')
          .doc('sync_tool')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final liveLine =
            'LIVE admin_config/sync_tool — macOS ${_liveCell(data['mac_min_version'])} | '
            'Windows ${_liveCell(data['win_min_version'])}';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1F2937),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VibesBox Sync',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                liveLine,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _platformBlock(
                title: 'macOS',
                major: _macMajor,
                minor: _macMinor,
                patch: _macPatch,
                url: _macUrl,
                note: _macNote,
                forceMin: _macRequired,
                onForceMin: (v) => setState(() => _macRequired = v),
              ),
              const SizedBox(height: 14),
              _platformBlock(
                title: 'Windows',
                major: _winMajor,
                minor: _winMinor,
                patch: _winPatch,
                url: _winUrl,
                note: _winNote,
                forceMin: _winRequired,
                onForceMin: (v) => setState(() => _winRequired = v),
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                label: const Text('Speichern'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _platformBlock({
    required String title,
    required TextEditingController major,
    required TextEditingController minor,
    required TextEditingController patch,
    required TextEditingController url,
    required TextEditingController note,
    required bool forceMin,
    required ValueChanged<bool> onForceMin,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Zielversion',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
        ),
        const SizedBox(height: 6),
        _digitRow(major, minor, patch),
        const SizedBox(height: 6),
        Text(
          '$title: ${_compose(major, minor, patch)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.orange,
                fontSize: 12,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: url,
          maxLength: 300,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
          decoration: _fieldDecoration.copyWith(
            labelText: 'Download (https)',
            labelStyle: const TextStyle(color: Colors.white54),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: note,
          maxLength: 240,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
          decoration: _fieldDecoration.copyWith(
            labelText: 'Hinweis',
            labelStyle: const TextStyle(color: Colors.white54),
          ),
        ),
        CheckboxListTile(
          value: forceMin,
          onChanged: (v) => onForceMin(v ?? false),
          title: const Text(
            'Mindestversion',
            style: TextStyle(color: Colors.white),
          ),
          activeColor: Colors.orange,
          checkColor: Colors.black,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _digitRow(
    TextEditingController major,
    TextEditingController minor,
    TextEditingController patch,
  ) {
    Widget box(TextEditingController controller) {
      return SizedBox(
        width: 52,
        child: TextField(
          controller: controller,
          decoration: _fieldDecoration.copyWith(hintText: '0'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLength: 2,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: _digits,
          onChanged: (_) => setState(() {}),
        ),
      );
    }

    Widget dot() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [box(major), dot(), box(minor), dot(), box(patch)],
    );
  }
}
