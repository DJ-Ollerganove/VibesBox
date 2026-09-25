import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/pre_wish_export_models.dart';
import '../utils/string_utils.dart';
import 'formatting_utils.dart';

/// Vorab-Wünsche als TXT / CSV / PDF / M3U (Dateiname, Inhalt, Gruppierung).
class PreWishExportHelper {
  PreWishExportHelper._();

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static List<PreWishExportSong> songsFromGrouped({
    required List<Map<String, dynamic>> allGroups,
    required AppLocalizations l,
  }) {
    final songs = <PreWishExportSong>[];
    for (final group in allGroups) {
      final data = group['data'] as Map<String, dynamic>? ?? {};
      final artist = unescapeHtml((data['artist'] ?? '') as String).trim();
      final title = unescapeHtml((data['title'] ?? '') as String).trim();
      if (artist.isEmpty && title.isEmpty) continue;

      songs.add(
        PreWishExportSong(
          artist: artist,
          title: title,
          wishers: _wishersFromGroup(data, l),
          sortKey: _oldestTimestampInGroup(data),
        ),
      );
    }

    songs.sort((a, b) {
      final cmp = a.sortKey.compareTo(b.sortKey);
      if (cmp != 0) return cmp;
      return a.displayLine.compareTo(b.displayLine);
    });
    return songs;
  }

  static DateTime _oldestTimestampInGroup(Map<String, dynamic> data) {
    final cal = data['createdAt_list'];
    if (cal is List) {
      DateTime? oldest;
      for (final raw in cal) {
        if (raw is! Timestamp) continue;
        final d = raw.toDate();
        if (oldest == null || d.isBefore(oldest)) oldest = d;
      }
      if (oldest != null) return oldest;
    }
    return _epoch;
  }

  static List<PreWishExportWisher> _wishersFromGroup(
    Map<String, dynamic> data,
    AppLocalizations l,
  ) {
    final greetingsRaw = data['greetings'];
    if (greetingsRaw is List && greetingsRaw.isNotEmpty) {
      final out = <PreWishExportWisher>[];
      for (final raw in greetingsRaw) {
        if (raw is! Map) continue;
        final name = _displayName((raw['name'] ?? '').toString(), l);
        final greeting = (raw['greeting'] ?? '').toString().trim();
        out.add(PreWishExportWisher(name: name, greeting: greeting));
      }
      if (out.isNotEmpty) return out;
    }

    final rb = data['requested_by'];
    if (rb is List && rb.isNotEmpty) {
      return rb
          .whereType<String>()
          .map((n) => PreWishExportWisher(
                name: _displayName(n, l),
                greeting: '',
              ))
          .toList();
    }

    return const [];
  }

  static String _displayName(String raw, AppLocalizations l) {
    final n = raw.trim();
    return n.isEmpty ? l.no_name : n;
  }

  /// `{Startdatum} - {Partytitel}.{ext}` — Datum in DJ-App-Sprache.
  static String buildFileName({
    required String partyName,
    required DateTime partyStartDate,
    required BuildContext context,
    required String extension,
  }) {
    final dateLabel =
        FormattingUtils.formatDateForLocale(partyStartDate, context);
    final safeDate = _sanitizeFilenameSegment(dateLabel);
    final title = partyName.trim().isEmpty ? 'Party' : partyName.trim();
    final safeTitle = _sanitizeFilenameSegment(title);
    final datePart = safeDate.isEmpty
        ? partyStartDate.toLocal().toIso8601String().split('T').first
        : safeDate;
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '$datePart - $safeTitle.$ext';
  }

  static String partyDateTimeLine(DateTime start, BuildContext context) {
    return FormattingUtils.formatCompactDateTimeLine(start, context);
  }

  static String buildTxtContent({
    required List<PreWishExportSong> songs,
  }) {
    return songs.map((s) => s.titleArtistLine).join('\n');
  }

  static String buildCsvContent({
    required List<PreWishExportSong> songs,
  }) {
    return songs.map((s) => _csvCell(s.titleArtistLine)).join('\n');
  }

  static String buildPlsContent({
    required List<PreWishExportSong> songs,
  }) {
    return buildTxtContent(songs: songs);
  }

  static String buildM3uContent({
    required List<PreWishExportSong> songs,
  }) {
    final buf = StringBuffer('#EXTM3U\n');
    for (final s in songs) {
      buf.writeln(s.titleArtistLine);
    }
    return buf.toString();
  }

  static String _csvCell(String value) {
    final v = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (v.contains(',') || v.contains('"')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _sanitizeFilenameSegment(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  }
}
