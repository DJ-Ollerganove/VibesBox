import 'dart:async';

import 'package:flutter/material.dart';

import 'dj_library_prefs.dart';
import 'dj_source_factory.dart';
import 'library_store.dart';
import 'tidal_lookup.dart';
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
    required this.tidal,
    required this.djPrefs,
  });

  final ToolSession session;
  final Wishboard wishboard;
  final LibraryStore library;
  final TidalLookupStore tidal;
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
        widget.tidal,
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
            title: Text(
              toolI18n.text('settings'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _DjLibrarySection(
                prefs: widget.djPrefs,
                library: widget.library,
                error: _error ?? widget.library.error,
                onBrowse: _browsePath,
                onImport: _importLibrary,
                formatImported: _formatImported,
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFF2A2A36)),
              const SizedBox(height: 12),
              const Text(
                'Tidal',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                toolI18n.text('tidalHelp'),
                style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.tidal.loggingIn
                    ? null
                    : () => unawaited(
                          widget.tidal.loggedIn
                              ? widget.tidal.logout()
                              : widget.tidal.login(),
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.tidal.loggedIn
                      ? const Color(0xFF2A2A36)
                      : const Color(0xFF00E5FF),
                  foregroundColor: widget.tidal.loggedIn
                      ? Colors.white
                      : Colors.black,
                ),
                icon: widget.tidal.loggingIn
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        widget.tidal.loggedIn
                            ? Icons.logout
                            : Icons.login,
                        size: 18,
                      ),
                label: Text(
                  widget.tidal.loggingIn
                      ? toolI18n.text('tidalWindow')
                      : widget.tidal.loggedIn
                          ? toolI18n.text('tidalLogout')
                          : toolI18n.text('tidalLogin'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.tidal.loggedIn
                    ? toolI18n.text('tidalIn')
                    : toolI18n.text('tidalOut'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFF2A2A36)),
              const SizedBox(height: 12),
              Text(
                toolI18n.text('songRec'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (!connected)
                Text(
                  toolI18n.text('connectFirst'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
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
                  style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        toolI18n.text('suggestions'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: enabled,
                      activeThumbColor: const Color(0xFFFF8800),
                      activeTrackColor: const Color(0x6AFF8800),
                      onChanged: (v) => _apply(enabled: v),
                    ),
                  ],
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    toolI18n.text('scope'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  _ChipRow(
                    value: widget.wishboard.recScope,
                    options: [
                      ('strict', toolI18n.text('scopeStrict')),
                      ('similar', toolI18n.text('scopeSimilar')),
                      ('bold', toolI18n.text('scopeBold')),
                    ],
                    onSelected: (v) => _apply(scope: v),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    toolI18n.text('familiarity'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  _ChipRow(
                    value: widget.wishboard.recFamiliarity,
                    options: [
                      ('hits', toolI18n.text('famHits')),
                      ('mix', toolI18n.text('famMix')),
                    ],
                    onSelected: (v) => _apply(familiarity: v),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              toolI18n.text('sameArtist'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              toolI18n.text('sameArtistHint'),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: widget.wishboard.recAllowSameArtist,
                        activeThumbColor: const Color(0xFFFF8800),
                        activeTrackColor: const Color(0x6AFF8800),
                        onChanged: (v) => _apply(allowSameArtist: v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          toolI18n.text('countLabel'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      DropdownButton<int>(
                        value: widget.wishboard.recCount,
                        dropdownColor: const Color(0xFF1D1D28),
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
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
        Text(
          toolI18n.text('djSoftware'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          toolI18n.text('whichSystem'),
          style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1D28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DjSoftware>(
              value: software,
              isExpanded: true,
              hint: Text(
                toolI18n.text('pleaseChoose'),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              dropdownColor: const Color(0xFF1D1D28),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
          const SizedBox(height: 18),
          Text(
            toolI18n.text('readQ', {'name': software.label}),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            toolI18n.text('readHint'),
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          _ChipRow(
            value: prefs.readLibrary == true
                ? 'yes'
                : prefs.readLibrary == false
                    ? 'no'
                    : '',
            options: [
              ('yes', _yesNo(true)),
              ('no', _yesNo(false)),
            ],
            onSelected: (v) {
              unawaited(_onReadChoice(v == 'yes'));
            },
          ),
        ],
        if (software != null && prefs.readLibrary == true) ...[
          const SizedBox(height: 18),
          Text(
            toolI18n.text('libraryPath'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            prefs.isCustomPath(software)
                ? toolI18n.text('customPath', {'name': software.label})
                : toolI18n.text('defaultPath', {'name': software.label}),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: SelectableText(
              prefs.resolvedPath(software),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => unawaited(onBrowse()),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A36),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(toolI18n.text('browse')),
              ),
              if (prefs.isCustomPath(software)) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => unawaited(prefs.clearCustomPath(software)),
                  child: Text(toolI18n.text('defaultPathBtn')),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toolI18n.text('autoUpdate'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      toolI18n.text('autoHint'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: prefs.autoUpdate,
                activeThumbColor: const Color(0xFFFF8800),
                activeTrackColor: const Color(0x6AFF8800),
                onChanged: (v) => unawaited(prefs.setAutoUpdate(v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: library.importing ? null : () => unawaited(onImport()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF8800),
              foregroundColor: Colors.black,
            ),
            icon: library.importing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.library_music, size: 18),
            label: Text(
              library.importing
                  ? toolI18n.text('reading')
                  : library.hasLibrary
                      ? toolI18n.text('updateNow')
                      : toolI18n.text('importLib'),
            ),
          ),
          const SizedBox(height: 8),
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
            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                  style: const TextStyle(fontSize: 12),
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

String _yesNo(bool yes) {
  const yesMap = {
    'de': 'Ja',
    'en': 'Yes',
    'es': 'Sí',
    'fr': 'Oui',
    'it': 'Sì',
    'pt': 'Sim',
    'nl': 'Ja',
    'pl': 'Tak',
    'cs': 'Ano',
    'tr': 'Evet',
    'ru': 'Да',
    'uk': 'Так',
    'el': 'Ναι',
    'ar': 'نعم',
    'hi': 'हाँ',
    'ja': 'はい',
    'zh': '是',
    'th': 'ใช่',
    'vi': 'Có',
    'sq': 'Po',
  };
  const noMap = {
    'de': 'Nein',
    'en': 'No',
    'es': 'No',
    'fr': 'Non',
    'it': 'No',
    'pt': 'Não',
    'nl': 'Nee',
    'pl': 'Nie',
    'cs': 'Ne',
    'tr': 'Hayır',
    'ru': 'Нет',
    'uk': 'Ні',
    'el': 'Όχι',
    'ar': 'لا',
    'hi': 'नहीं',
    'ja': 'いいえ',
    'zh': '否',
    'th': 'ไม่',
    'vi': 'Không',
    'sq': 'Jo',
  };
  final map = yes ? yesMap : noMap;
  return map[toolI18n.code] ?? map['de']!;
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
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.$2),
            selected: value == option.$1,
            onSelected: (_) {
              if (value == option.$1) return;
              onSelected(option.$1);
            },
            selectedColor: const Color(0xFFFF8800),
            backgroundColor: const Color(0xFF1D1D28),
            labelStyle: TextStyle(
              color: value == option.$1 ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: value == option.$1
                  ? const Color(0xFFFF8800)
                  : Colors.white24,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
