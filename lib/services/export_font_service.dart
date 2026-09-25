import 'package:flutter/painting.dart' show TextStyle;
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/locale_helper.dart';
import '../utils/debug_log.dart';

/// Schriftarten für PDF- und QR-Bild-Export je Export-Sprache (Noto/Google Fonts).
class ExportFontService {
  ExportFontService._();

  static final Map<String, pw.ThemeData> _pdfThemeCache = {};
  static final Map<String, String> _flutterFamilyCache = {};

  static const _flutterFamilyPrefix = 'VibesBoxExport';

  static String normalizeCode(String? localeLanguageCode) =>
      LocaleHelper.mapToSupportedOrEnglish(localeLanguageCode ?? 'de');

  static Future<pw.Font> Function() _regularLoader(String code) {
    switch (code) {
      case 'zh':
        return PdfGoogleFonts.notoSansSCRegular;
      case 'ar':
        return PdfGoogleFonts.notoSansArabicRegular;
      case 'ja':
        return PdfGoogleFonts.notoSansJPRegular;
      case 'th':
        return PdfGoogleFonts.notoSansThaiRegular;
      case 'hi':
        return PdfGoogleFonts.notoSansDevanagariRegular;
      default:
        return PdfGoogleFonts.notoSansRegular;
    }
  }

  static Future<pw.Font> Function() _boldLoader(String code) {
    switch (code) {
      case 'zh':
        return PdfGoogleFonts.notoSansSCBold;
      case 'ar':
        return PdfGoogleFonts.notoSansArabicBold;
      case 'ja':
        return PdfGoogleFonts.notoSansJPBold;
      case 'th':
        return PdfGoogleFonts.notoSansThaiBold;
      case 'hi':
        return PdfGoogleFonts.notoSansDevanagariBold;
      default:
        return PdfGoogleFonts.notoSansBold;
    }
  }

  static Future<List<pw.Font>> _latinFallbackFonts(String code) async {
    final fallbacks = <pw.Font>[];
    if (code != 'zh') {
      try {
        fallbacks.add(await PdfGoogleFonts.notoSansSCRegular());
      } catch (_) {}
    }
    if (code != 'ar') {
      try {
        fallbacks.add(await PdfGoogleFonts.notoSansArabicRegular());
      } catch (_) {}
    }
    try {
      fallbacks.add(await PdfGoogleFonts.notoSansRegular());
      fallbacks.add(await PdfGoogleFonts.notoSansBold());
    } catch (_) {}
    return fallbacks;
  }

  /// PDF-Theme inkl. passender Unicode-Schrift für [localeLanguageCode].
  static Future<pw.ThemeData?> loadPdfTheme({String? localeLanguageCode}) async {
    final code = normalizeCode(localeLanguageCode);
    final cached = _pdfThemeCache[code];
    if (cached != null) return cached;

    try {
      final baseFont = await _regularLoader(code)();
      final boldFont = await _boldLoader(code)();
      final fallbacks = await _latinFallbackFonts(code);
      final theme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        fontFallback: fallbacks.isEmpty ? null : fallbacks,
      );
      _pdfThemeCache[code] = theme;
      return theme;
    } catch (e) {
      debugLog('⚠️ ExportFontService PDF: $code – $e');
      try {
        final baseFont = await PdfGoogleFonts.notoSansRegular();
        final boldFont = await PdfGoogleFonts.notoSansBold();
        final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
        _pdfThemeCache[code] = theme;
        return theme;
      } catch (e2) {
        debugLog('⚠️ ExportFontService PDF Fallback fehlgeschlagen: $e2');
        return null;
      }
    }
  }

  /// Lädt/registriert Flutter-Schrift für QR-Bild-Canvas; gibt [fontFamily] zurück.
  static Future<String> ensureFlutterExportFontFamily(String? localeLanguageCode) async {
    final code = normalizeCode(localeLanguageCode);
    final cached = _flutterFamilyCache[code];
    if (cached != null) return cached;

    final family = '${_flutterFamilyPrefix}_$code';
    final regular = await _regularLoader(code)();
    final bold = await _boldLoader(code)();

    final loader = FontLoader(family);
    if (regular is pw.TtfFont) {
      loader.addFont(Future.value(regular.data));
    }
    if (bold is pw.TtfFont) {
      loader.addFont(Future.value(bold.data));
    }
    await loader.load();
    _flutterFamilyCache[code] = family;
    return family;
  }

  /// [TextStyle] mit Export-Schrift für [localeLanguageCode] (nach [ensureFlutterExportFontFamily]).
  static TextStyle applyExportFont(TextStyle style, String fontFamily) =>
      style.copyWith(fontFamily: fontFamily);
}
