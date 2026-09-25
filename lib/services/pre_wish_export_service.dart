import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/pre_wish_export_models.dart';
import '../utils/greeting_translator.dart';
import '../utils/pre_wish_export_helper.dart';
import '../utils/file_share_helper.dart';
import 'export_font_service.dart';

class PreWishExportService {
  PreWishExportService._();

  static Future<List<PreWishExportSong>> enrichWithTranslations(
    List<PreWishExportSong> songs,
    BuildContext context,
  ) async {
    final out = <PreWishExportSong>[];
    for (final song in songs) {
      final wishers = <PreWishExportWisher>[];
      for (final w in song.wishers) {
        String? translation;
        if (w.greeting.trim().isNotEmpty) {
          translation =
              await GreetingTranslator.translateGreetingIfNeeded(
            w.greeting,
            context,
          );
        }
        wishers.add(
          PreWishExportWisher(
            name: w.name,
            greeting: w.greeting,
            translatedGreeting: translation,
          ),
        );
      }
      out.add(
        PreWishExportSong(
          artist: song.artist,
          title: song.title,
          wishers: wishers,
          sortKey: song.sortKey,
          metaLine: song.metaLine,
        ),
      );
    }
    return out;
  }

  static Future<void> shareExport({
    required BuildContext context,
    required PreWishExportFormat format,
    required String partyName,
    required DateTime partyStartDate,
    required List<PreWishExportSong> songs,
  }) async {
    if (songs.isEmpty) return;

    final l = AppLocalizations.of(context)!;
    final dateLine =
        PreWishExportHelper.partyDateTimeLine(partyStartDate, context);

    late final String fileName;
    late final List<int> bytes;
    late final String mimeType;

    switch (format) {
      case PreWishExportFormat.txt:
        fileName = PreWishExportHelper.buildFileName(
          partyName: partyName,
          partyStartDate: partyStartDate,
          context: context,
          extension: 'txt',
        );
        bytes = utf8.encode(
          PreWishExportHelper.buildTxtContent(songs: songs),
        );
        mimeType = 'text/plain';
        break;
      case PreWishExportFormat.csv:
        fileName = PreWishExportHelper.buildFileName(
          partyName: partyName,
          partyStartDate: partyStartDate,
          context: context,
          extension: 'csv',
        );
        bytes = utf8.encode(
          PreWishExportHelper.buildCsvContent(songs: songs),
        );
        mimeType = 'text/csv';
        break;
      case PreWishExportFormat.m3u:
        fileName = PreWishExportHelper.buildFileName(
          partyName: partyName,
          partyStartDate: partyStartDate,
          context: context,
          extension: 'm3u',
        );
        bytes = utf8.encode(
          PreWishExportHelper.buildM3uContent(songs: songs),
        );
        mimeType = 'audio/x-mpegurl';
        break;
      case PreWishExportFormat.pls:
        fileName = PreWishExportHelper.buildFileName(
          partyName: partyName,
          partyStartDate: partyStartDate,
          context: context,
          extension: 'pls',
        );
        bytes = utf8.encode(
          PreWishExportHelper.buildPlsContent(songs: songs),
        );
        mimeType = 'audio/x-scpls';
        break;
      case PreWishExportFormat.pdf:
        final enriched = await enrichWithTranslations(songs, context);
        if (!context.mounted) return;
        fileName = PreWishExportHelper.buildFileName(
          partyName: partyName,
          partyStartDate: partyStartDate,
          context: context,
          extension: 'pdf',
        );
        bytes = await _buildPdfBytes(
          context: context,
          partyName: partyName,
          partyDateTimeLine: dateLine,
          songs: enriched,
          l: l,
        );
        mimeType = 'application/pdf';
        break;
    }

    final dir = await getTemporaryDirectory();
    final diskName = _diskSafeFileName(fileName);
    final file = File('${dir.path}/$diskName');
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;

    await FileShareHelper.shareXFiles(
      context: context,
      files: [
        XFile(
          file.path,
          mimeType: mimeType,
          name: fileName,
        ),
      ],
      subject: fileName,
    );
  }

  /// Dateiname auf Platte (ohne Leerzeichen/Sonderzeichen) — Anzeigename bleibt [fileName].
  static String _diskSafeFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot) : '';
    final base = dot >= 0 ? fileName.substring(0, dot) : fileName;
    final safe = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final stem = safe.isEmpty ? 'vibesbox_export' : safe;
    return '$stem$ext';
  }

  static Future<Uint8List> _buildPdfBytes({
    required BuildContext context,
    required String partyName,
    required String partyDateTimeLine,
    required List<PreWishExportSong> songs,
    required AppLocalizations l,
  }) async {
    final localeCode = Localizations.localeOf(context).languageCode;
    final theme = await _loadPdfTheme(localeCode);
    final doc = pw.Document(theme: theme);

    final titleText = partyName.trim().isEmpty ? 'Party' : partyName.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Text(
            titleText,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            partyDateTimeLine,
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 18),
          ..._pdfSongBlocks(songs, l),
        ],
      ),
    );

    return doc.save();
  }

  static List<pw.Widget> _pdfSongBlocks(
    List<PreWishExportSong> songs,
    AppLocalizations l,
  ) {
    final blocks = <pw.Widget>[];
    for (var i = 0; i < songs.length; i++) {
      final song = songs[i];
      blocks.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${i + 1}. ${song.titleArtistLine}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (song.metaLine.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    song.metaLine.trim(),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              ...song.wishers.expand((w) {
                final lines = <pw.Widget>[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${l.requested_by}: ${w.name}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ];
                if (w.greeting.trim().isNotEmpty) {
                  lines.add(
                    pw.Text(
                      '${l.greeting}: ${w.greeting}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  );
                  final tr = w.translatedGreeting?.trim();
                  if (tr != null &&
                      tr.isNotEmpty &&
                      tr != w.greeting.trim()) {
                    lines.add(
                      pw.Text(
                        '${l.pre_wish_export_translation}: $tr',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    );
                  }
                }
                return lines;
              }),
            ],
          ),
        ),
      );
    }
    return blocks;
  }

  static Future<pw.ThemeData> _loadPdfTheme(String localeCode) async {
    final theme = await ExportFontService.loadPdfTheme(localeLanguageCode: localeCode);
    if (theme != null) return theme;
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    return pw.ThemeData.withFont(base: base, bold: bold);
  }
}
