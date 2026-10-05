import 'dart:async';

import 'package:flutter/material.dart';

import 'dj_library_prefs.dart';
import 'dj_source_factory.dart';
import 'library_store.dart';
import 'tool_gate_pages.dart';
import 'tool_i18n.dart';
import 'tool_session.dart';
import 'wishboard.dart';

class SongRecSettingsPage extends StatefulWidget {
  const SongRecSettingsPage({
    super.key,
    required this.session,
    required this.wishboard,
    required this.library,
    required this.djPrefs,
  });

  final ToolSession session;
  final Wishboard wishboard;
  final LibraryStore library;
  final DjLibraryPrefs djPrefs;

  @override
  State<SongRecSettingsPage> createState() => _SongRecSettingsPageState();
}

class _SongRecSettingsPageState extends State<SongRecSettingsPage> {
  bool _saving = false;
  String? _error;

  Future<void> _importLibrary() async {
    final software = widget.djPrefs.software;
    if (software == null || !widget.djPrefs.wantsRead) return;
    setState(() => _error = null);
    final source = openDjLibrarySource(
      software,
      widget.djPrefs.resolvedPath(software),
    );
    try {
      await widget.library.importFrom(source);
    } finally {
      source.close();
    }
    if (!mounted) return;
    if (widget.library.error != null) {
      setState(() => _error = widget.library.error);
    }
  }

  Future<void> _browsePath() async {
    final software = widget.djPrefs.software;
    if (software == null) return;
    await widget.djPrefs.browse(software);
    if (!mounted) return;
    if (widget.djPrefs.wantsRead) {
      unawaited(_importLibrary());
    }
  }

  Future<void> _apply({
    bool? enabled,
    String? scope,
    String? familiarity,
    bool? allowSameArtist,
    int? count,
  }) async {
    if (!widget.session.isConnected || _saving) return;
    final nextEnabled = enabled ?? widget.wishboard.recEnabled;
    final nextScope = scope ?? widget.wishboard.recScope;
    final nextFam = familiarity ?? widget.wishboard.recFamiliarity;
    final nextSame = allowSameArtist ?? widget.wishboard.recAllowSameArtist;
    final nextCount = count ?? widget.wishboard.recCount;
    widget.wishboard.applyLocalSongRec(
      enabled: nextEnabled,
      scope: nextScope,
      familiarity: nextFam,
      allowSameArtist: nextSame,
      count: nextCount,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.saveSongRec(
        enabled: nextEnabled,
        scope: nextScope,
        familiarity: nextFam,
        allowSameArtist: nextSame,
        count: nextCount,
      );
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.session,
        widget.wishboard,
        widget.library,
        widget.djPrefs,
      ]),
      builder: (context, _) {
        final connected = widget.session.isConnected;
        final enabled = widget.wishboard.recEnabled;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 0,
            toolbarHeight: 40,
            title: Text(
              toolI18n.text('settings'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
            children: [
              _GroupFrame(
                child: Column(
                  children: [
                    _checkRow(
                      label: toolI18n.text('alwaysOnTop'),
                      value: widget.djPrefs.alwaysOnTop,
                      onChanged: (value) =>
                          unawaited(widget.djPrefs.setAlwaysOnTop(value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _GroupFrame(
                child: _DjLibrarySection(
                  prefs: widget.djPrefs,
                  library: widget.library,
                  error: _error ?? widget.library.error,
                  onBrowse: _browsePath,
                  onImport: _importLibrary,
                  formatImported: _formatImported,
                ),
              ),
              const SizedBox(height: 8),
              _GroupFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              _SectionTitle(toolI18n.text('songRec')),
              const SizedBox(height: 4),
              if (!connected)
                Text(
                  toolI18n.text('connectFirst'),
                  style: _hintStyle,
                )
              else if (widget.wishboard.recFingerprint.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                Text(
                  toolI18n.text('recBody'),
                  style: _hintStyle,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 6),
                _switchRow(
                  label: toolI18n.text('suggestions'),
                  value: enabled,
                  onChanged: (v) => _apply(enabled: v),
                ),
                if (enabled) ...[
                  const SizedBox(height: 6),
                  Text(toolI18n.text('scope'), style: _labelStyle),
                  const SizedBox(height: 4),
                  _ChipRow(
                    value: widget.wishboard.recScope,
                    options: [
                      ('strict', toolI18n.text('scopeStrict')),
                      ('similar', toolI18n.text('scopeSimilar')),
                      ('bold', toolI18n.text('scopeBold')),
                    ],
                    onSelected: (v) => _apply(scope: v),
                  ),
                  const SizedBox(height: 8),
                  Text(toolI18n.text('familiarity'), style: _labelStyle),
                  const SizedBox(height: 4),
                  _ChipRow(
                    value: widget.wishboard.recFamiliarity,
                    options: [
                      ('hits', toolI18n.text('famHits')),
                      ('mix', toolI18n.text('famMix')),
                    ],
                    onSelected: (v) => _apply(familiarity: v),
                  ),
                  const SizedBox(height: 6),
                  _switchRow(
                    label: toolI18n.text('sameArtist'),
                    hint: toolI18n.text('sameArtistHint'),
                    value: widget.wishboard.recAllowSameArtist,
                    onChanged: (v) => _apply(allowSameArtist: v),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          toolI18n.text('countLabel'),
                          style: _labelStyle,
                        ),
                      ),
                      DropdownButton<int>(
                        value: widget.wishboard.recCount,
                        isDense: true,
                        dropdownColor: const Color(0xFF1D1D28),
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        items: [
                          for (var n = 1; n <= 20; n++)
                            DropdownMenuItem<int>(
                              value: n,
                              child: Text('$n'),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          unawaited(_apply(count: v));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    toolI18n.text('countHint'),
                    style: _hintStyle,
                  ),
                ],
              ],
                  ],
                ),
              ),
              const ToolLegalFooter(),
            ],
          ),
        );
      },
    );
  }

  String _formatImported(DateTime at) {
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _DjLibrarySection extends StatelessWidget {
  const _DjLibrarySection({
    required this.prefs,
    required this.library,
    required this.error,
    required this.onBrowse,
    required this.onImport,
    required this.formatImported,
  });

  final DjLibraryPrefs prefs;
  final LibraryStore library;
  final String? error;
  final Future<void> Function() onBrowse;
  final Future<void> Function() onImport;
  final String Function(DateTime at) formatImported;

  @override
  Widget build(BuildContext context) {
    final software = prefs.software;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(toolI18n.text('djSoftware')),
        const SizedBox(height: 2),
        Text(toolI18n.text('whichSystem'), style: _hintStyle),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1D28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DjSoftware>(
              value: software,
              isExpanded: true,
              isDense: true,
              hint: Text(
                toolI18n.text('pleaseChoose'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              dropdownColor: const Color(0xFF1D1D28),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final item in DjSoftware.values)
                  DropdownMenuItem<DjSoftware>(
                    value: item,
                    child: Text(item.label),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                unawaited(prefs.setSoftware(v));
              },
            ),
          ),
        ),
        if (software != null) ...[
          const SizedBox(height: 6),
          _switchRow(
            label: toolI18n.text('readQ', {'name': software.label}),
            hint: toolI18n.text('readHint'),
            value: prefs.readLibrary == true,
            onChanged: (v) => unawaited(_onReadChoice(v)),
          ),
        ],
        if (software != null && prefs.readLibrary == true) ...[
          const SizedBox(height: 10),
          Text(toolI18n.text('libraryPath'), style: _labelStyle),
          const SizedBox(height: 2),
          Text(
            prefs.isCustomPath(software)
                ? toolI18n.text('customPath', {'name': software.label})
                : toolI18n.text('defaultPath', {'name': software.label}),
            style: _hintStyle,
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: SelectableText(
              prefs.resolvedPath(software),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => unawaited(onBrowse()),
                style: _tinyButtonStyle(
                  background: const Color(0xFF2A2A36),
                  foreground: Colors.white,
                ),
                icon: const Icon(Icons.folder_open, size: 14),
                label: Text(toolI18n.text('browse')),
              ),
              if (prefs.isCustomPath(software)) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => unawaited(prefs.clearCustomPath(software)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.white70,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(toolI18n.text('defaultPathBtn')),
                ),
              ],
            ],
          ),
          _switchRow(
            label: toolI18n.text('autoUpdate'),
            value: prefs.autoUpdate,
            dense: true,
            onChanged: (v) => unawaited(prefs.setAutoUpdate(v)),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: library.importing ? null : () => unawaited(onImport()),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFFFF8800),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
              child: library.importing
                  ? const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.4),
                    )
                  : Text(
                      library.hasLibrary
                          ? toolI18n.text('updateNow')
                          : toolI18n.text('importLib'),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            library.hasLibrary
                ? '${toolI18n.text('libStats', {
                      'name': software.label,
                      'count': '${library.trackCount}',
                      'plays': '${library.playSum}',
                    })}'
                    '${library.lastImportedAt == null ? '' : ' · ${formatImported(library.lastImportedAt!)}'}'
                : prefs.autoUpdate
                    ? toolI18n.text('noLibAuto', {'name': software.label})
                    : toolI18n.text('noLibManual', {'name': software.label}),
            style: _hintStyle,
          ),
          if (library.hasLibrary) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: library.importing
                    ? null
                    : () => unawaited(_confirmClearLibrary(context, software)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF8A80),
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  toolI18n.text('deleteLink', {'name': software.label}),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _onReadChoice(bool yes) async {
    await prefs.setReadLibrary(yes);
    if (yes && prefs.wantsRead) {
      await onImport();
    }
  }

  Future<void> _confirmClearLibrary(
    BuildContext context,
    DjSoftware software,
  ) async {
    final autoHint = prefs.autoUpdate
        ? '\n\n${toolI18n.text('deleteAuto', {'name': software.label})}'
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1D28),
          title: Text(toolI18n.text('deleteTitle', {'name': software.label})),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          content: Text(
            '${toolI18n.text('deleteBody', {'name': software.label})}$autoHint',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(toolI18n.text('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF8A80),
              ),
              child: Text(toolI18n.text('delete')),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await library.clearCurrent();
  }
}

const _hintStyle = TextStyle(
  color: Colors.white54,
  fontSize: 10,
  height: 1.25,
);

const _labelStyle = TextStyle(
  color: Colors.white70,
  fontSize: 11,
  fontWeight: FontWeight.w600,
);

class _GroupFrame extends StatelessWidget {
  const _GroupFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF8800), width: 1),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
  }
}

ButtonStyle _tinyButtonStyle({
  required Color background,
  required Color foreground,
}) {
  return FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: foreground,
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  );
}

Widget _checkRow({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return InkWell(
    onTap: () => onChanged(!value),
    child: Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: value,
            activeColor: const Color(0xFFFF8800),
            checkColor: Colors.black,
            side: const BorderSide(color: Colors.white54),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (next) {
              if (next == null) return;
              onChanged(next);
            },
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

Widget _switchRow({
  required String label,
  String? hint,
  required bool value,
  required ValueChanged<bool> onChanged,
  bool dense = false,
}) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: dense
                  ? const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    )
                  : _labelStyle,
            ),
            if (hint != null && hint.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(hint, style: _hintStyle),
            ],
          ],
        ),
      ),
      Transform.scale(
        scale: dense ? 0.55 : 0.72,
        alignment: Alignment.centerRight,
        child: Switch(
          value: value,
          activeThumbColor: const Color(0xFFFF8800),
          activeTrackColor: const Color(0x6AFF8800),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: () {
              if (value == option.$1) return;
              onSelected(option.$1);
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: value == option.$1
                    ? const Color(0xFFFF8800)
                    : const Color(0xFF1D1D28),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: value == option.$1
                      ? const Color(0xFFFF8800)
                      : Colors.white24,
                  width: 0.6,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                child: Text(
                  option.$2,
                  style: TextStyle(
                    color: value == option.$1 ? Colors.black : Colors.white,
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
