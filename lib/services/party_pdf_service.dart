import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http; // Hinzugefügt für Last-Resort-Download
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart' show Locale;

import '../config/app_config.dart';
import '../l10n/locale_helper.dart';
import '../utils/formatting_utils.dart';
import '../utils/party_code_utils.dart';
import 'user_service.dart';
import '../utils/debug_log.dart';

/// Service für die Generierung von Party-PDFs
class PartyPdfService {
  /// Gecachte Unicode-Schriftart für Latin/Cyrillic (Roboto, kleiner).
  static pw.ThemeData? _cachedThemeLatin;

  /// Gecachte Theme für Chinesisch (Noto Sans SC als Basis).
  static pw.ThemeData? _cachedThemeZh;

  /// Gecachte Theme für Arabisch (Noto Sans Arabic als Basis).
  static pw.ThemeData? _cachedThemeAr;

  /// Gecachte Grafik-Icons: Schwarz (#000) für Kontaktblock (transparenter Hintergrund, Briefumschlag/Hörer).
  static pw.ImageProvider? _cachedIconEmail;
  static pw.ImageProvider? _cachedIconPhone;

  /// Erzeugt ein E-Mail-Umschlag-Icon (24x24) programmatisch. [colorValue]: 0 = schwarz (#000000).
  /// Hintergrund: Weiß (#FFFFFF), da PDF keine per-pixel-Transparenz unterstützt – auf weißem Papier unsichtbar.
  static pw.ImageProvider? _createEmailIconWithColor(int colorValue) {
    try {
      const size = 24;
      final image = img.Image(width: size, height: size, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
      final color = img.ColorRgba8(colorValue, colorValue, colorValue, 255);
      // Umschlag-Rahmen: Rechteck 2,2 bis 22,18
      for (var x = 2; x <= 22; x++) {
        image.setPixel(x, 2, color);
        image.setPixel(x, 18, color);
      }
      for (var y = 2; y <= 18; y++) {
        image.setPixel(2, y, color);
        image.setPixel(22, y, color);
      }
      // Klappe (V-Form): Linien von (2,2)-(12,10) und (12,10)-(22,2)
      for (var i = 0; i <= 10; i++) {
        final t = i / 10;
        image.setPixel((2 + (12 - 2) * t).round(), (2 + (10 - 2) * t).round(), color);
        image.setPixel((12 + (22 - 12) * t).round(), (10 + (2 - 10) * t).round(), color);
      }
      final png = img.encodePng(image);
      return pw.MemoryImage(Uint8List.fromList(png));
    } catch (e) {
      return null;
    }
  }

  /// Erzeugt ein Telefon-Hörer-Icon (24x24). Klassische Silhouette: Ohrhörer oben, Mundstück unten, Bananen-Griff.
  static pw.ImageProvider? _createPhoneIconWithColor(int colorValue) {
    try {
      const size = 24;
      final image = img.Image(width: size, height: size, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
      final c = img.ColorRgba8(colorValue, colorValue, colorValue, 255);
      void row(int y, int x1, int x2) {
        for (var x = x1; x <= x2; x++) {
          if (x >= 0 && x < size && y >= 0 && y < size) image.setPixel(x, y, c);
        }
      }
      // Ohrhörer oben (kleine Kapsel)
      row(2, 10, 13);
      row(3, 9, 14);
      row(4, 8, 15);
      row(5, 9, 14);
      row(6, 10, 13);
      // Griff oben (Übergang)
      row(7, 9, 14);
      // Bananen-Kurve: in der Mitte am breitesten
      row(8, 7, 16);
      row(9, 5, 18);
      row(10, 4, 19);
      row(11, 4, 19);
      row(12, 5, 18);
      row(13, 7, 16);
      row(14, 9, 14);
      // Griff unten (Übergang)
      row(15, 9, 14);
      // Mundstück unten (breitere Kapsel)
      row(16, 8, 15);
      row(17, 7, 16);
      row(18, 7, 16);
      row(19, 8, 15);
      row(20, 9, 14);
      row(21, 10, 13);
      final png = img.encodePng(image);
      return pw.MemoryImage(Uint8List.fromList(png));
    } catch (e) {
      return null;
    }
  }

  /// Lädt die Kontakt-Icons: Beide programmatisch (weißer Hintergrund, schwarze Icons, keine schwarzen Klötze).
  static Future<void> _loadContactIcons() async {
    try {
      _cachedIconEmail = _createEmailIconWithColor(0);
      _cachedIconPhone = _createPhoneIconWithColor(0);
    } catch (_) {}
  }

  /// Prüft, ob für die Locale die volle Unicode-Schrift (CJK, Arabic) nötig ist.
  static bool _needsFullUnicodeFont(String? localeCode) =>
      localeCode == 'zh' || localeCode == 'ar';

  /// Lädt die PDF-Theme inkl. Unicode-Schrift. Nutzt Cache, lädt nur wenn nötig.
  static Future<pw.ThemeData?> _loadPdfTheme({String? localeLanguageCode}) async {
    if (localeLanguageCode == 'zh' && _cachedThemeZh != null) return _cachedThemeZh;
    if (localeLanguageCode == 'ar' && _cachedThemeAr != null) return _cachedThemeAr;
    if (!_needsFullUnicodeFont(localeLanguageCode) && _cachedThemeLatin != null) {
      return _cachedThemeLatin;
    }

    try {
      if (localeLanguageCode == 'zh') {
        final baseFont = await PdfGoogleFonts.notoSansSCRegular();
        final boldFont = await PdfGoogleFonts.notoSansSCBold();
        final fallbacks = <pw.Font>[];
        try {
          fallbacks.add(await PdfGoogleFonts.notoSansArabicRegular());
          fallbacks.add(await PdfGoogleFonts.notoSansArabicBold());
        } catch (_) {}
        try {
          fallbacks.add(await PdfGoogleFonts.notoSansRegular());
          fallbacks.add(await PdfGoogleFonts.notoSansBold());
        } catch (_) {}
        _cachedThemeZh = pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
          fontFallback: fallbacks.isEmpty ? null : fallbacks,
        );
        return _cachedThemeZh;
      } else if (localeLanguageCode == 'ar') {
        final baseFont = await PdfGoogleFonts.notoSansArabicRegular();
        final boldFont = await PdfGoogleFonts.notoSansArabicBold();
        final fallbacks = <pw.Font>[];
        try {
          fallbacks.add(await PdfGoogleFonts.notoSansSCRegular());
          fallbacks.add(await PdfGoogleFonts.notoSansSCBold());
        } catch (_) {}
        try {
          fallbacks.add(await PdfGoogleFonts.notoSansRegular());
          fallbacks.add(await PdfGoogleFonts.notoSansBold());
        } catch (_) {}
        _cachedThemeAr = pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
          fontFallback: fallbacks.isEmpty ? null : fallbacks,
        );
        return _cachedThemeAr;
      } else {
        final baseFont = await PdfGoogleFonts.robotoRegular();
        final boldFont = await PdfGoogleFonts.robotoBold();
        _cachedThemeLatin = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
        return _cachedThemeLatin;
      }
    } catch (e) {
      try {
        final baseFont = await PdfGoogleFonts.robotoRegular();
        final boldFont = await PdfGoogleFonts.robotoBold();
        final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
        _cachedThemeLatin ??= theme;
        return theme;
      } catch (e2) {
        debugLog('⚠️ PDF: Schriftart konnte nicht geladen werden: $e');
        return null;
      }
    }
  }

  /// Lädt das PDF-Theme (Fonts) für die angegebene Locale. Wird vom QR-Dialog
  /// vor der PDF-Generierung aufgerufen, damit der Font-Lade-Status getrennt angezeigt werden kann.
  static Future<void> ensurePdfThemeLoaded({String? localeLanguageCode}) async {
    await _loadPdfTheme(localeLanguageCode: localeLanguageCode);
    await _loadContactIcons();
  }

  /// PDF-/Export-Strings für [localeLanguageCode] (gleiche Keys wie App-Übersetzungen).
  static Map<String, String> _pdfLocaleStrings(String? localeLanguageCode) {
    final code = LocaleHelper.mapToSupportedOrEnglish(localeLanguageCode ?? 'de');
    return LocaleHelper.getTranslations(Locale(code));
  }

  /// Formatiert DateTime für PDF (Sprache = Export-Locale).
  static String formatDateTimeForPdf(DateTime date, {String? localeLanguageCode}) {
    return FormattingUtils.formatDateTimeForLanguageExport(
      date,
      localeLanguageCode ?? 'de',
    );
  }

  static const String _defaultPdfFooterText = '(C) 2026 - a creation by Swen Steller';

  /// Gibt den aktuellen PDF-Footer-Text zurück.
  static String _getPdfFooterText() =>
      (AppConfig.pdfFooterText != null && AppConfig.pdfFooterText!.trim().isNotEmpty)
          ? AppConfig.pdfFooterText!.trim()
          : _defaultPdfFooterText;

  /// Lädt ein Logo-Asset
  static Future<pw.ImageProvider?> _loadLogoAsset(String assetPath) async {
    try {
      final logoBytes = await rootBundle.load(assetPath);
      final logoUint8List = logoBytes.buffer.asUint8List();
      return pw.MemoryImage(logoUint8List);
    } catch (e) {
      debugLog('❌ Fehler beim Laden des $assetPath Logos: $e');
      return null;
    }
  }

  /// Lädt ein Logo aus einer URL (Last Resort)
  static Future<pw.ImageProvider?> _loadNetworkImage(String url) async {
    try {
      debugLog('📥 PDF-Service: Versuche Logo zu laden von (Last Resort): $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        if (response.bodyBytes.isNotEmpty) {
          debugLog('✅ PDF-Service: Logo erfolgreich geladen (${response.bodyBytes.length} bytes)');
          // Optional: Cache aktualisieren für nächste Mal
          UserService.cachedDjLogo = response.bodyBytes;
          return pw.MemoryImage(response.bodyBytes);
        } else {
          debugLog('⚠️ PDF-Service: Logo-Antwort war leer (0 bytes)');
          return null;
        }
      } else {
        debugLog('❌ PDF-Service: Logo-Download fehlgeschlagen. Status Code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugLog('❌ PDF-Service: Fehler beim Laden des Network-Images ($url): $e');
      return null;
    }
  }

  /// Nutzt den UserService-Cache, um das Branding-Logo zu laden.
  /// Falls leer, versucht es Fallback auf djLogoUrl/profileImageUrl (Last Resort).
  static Future<pw.ImageProvider?> _resolveBrandingLogoFromCache({String? djLogoUrl, String? profileImageUrl}) async {
    debugLog('DEBUG: PDF-Generator prüft Cache. Inhalt vorhanden? ${UserService.cachedDjLogo != null}');
    
    if (UserService.cachedDjLogo != null && UserService.cachedDjLogo!.isNotEmpty) {
      debugLog('✅ PDF-Service: Nutze gecachtes DJ-Logo (${UserService.cachedDjLogo!.length} bytes)');
      return pw.MemoryImage(UserService.cachedDjLogo!);
    }
    
    debugLog('ℹ️ PDF-Service: Kein gecachtes Logo vorhanden. Prüfe Last-Resort-Optionen...');
    
    // Last Resort: Versuche direkten Download, falls URLs vorhanden sind
    if (djLogoUrl != null && djLogoUrl.isNotEmpty) {
       final logo = await _loadNetworkImage(djLogoUrl);
       if (logo != null) return logo;
    }
    
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
       final logo = await _loadNetworkImage(profileImageUrl);
       if (logo != null) return logo;
    }

    debugLog('ℹ️ PDF-Service: Auch Last-Resort fehlgeschlagen. Verwende Text-Fallback.');
    return null;
  }

  static String _protectDjNameLineBreak(String djName) =>
      djName.replaceAll(' ', '\u00A0');

  /// Entfernt doppelte "Party-Code:"-Labels (z. B. "Party-Code: Party-Code: 530 166" -> "Party-Code: 530 166").
  static String _deduplicatePartyCodeLabel(String raw) {
    return raw.replaceAllMapped(
      RegExp(r'(Party-Code:\s*)+', caseSensitive: false),
      (_) => 'Party-Code: ',
    ).trim();
  }

  /// PDF-Anzeige: Rohcode aus DB → „Party-Code: 1234 5678“ (kein Speichern mit Leerzeichen).
  static String _partyCodeLineForPdf(String? partyCodeDisplay, String partyCode) {
    final combined = (partyCodeDisplay != null && partyCodeDisplay.trim().isNotEmpty)
        ? partyCodeDisplay.trim()
        : partyCode.trim();
    final withoutLabel = combined.replaceAllMapped(
      RegExp(r'party-code:\s*', caseSensitive: false),
      (_) => '',
    ).trim();
    var digits = withoutLabel.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      digits = PartyCodeUtils.normalizeDigits(partyCode);
    }
    final visual = PartyCodeUtils.formatForDisplay(digits.isNotEmpty ? digits : partyCode);
    if (visual.isEmpty) return _deduplicatePartyCodeLabel(combined);
    return _deduplicatePartyCodeLabel('Party-Code: $visual');
  }

  /// Universelle Layout-Funktion: pw.Column mit start, Header isoliert + Spacer unten.
  static pw.Widget _buildModularPartyContent({
    required String partyName,
    required String pwaUrl,
    required String partyCode,
    String? partyCodeDisplay,
    List<String>? contactBlockUnderQr,
    required String dateTimeText,
    String? startTimeLabel,
    String? scanLine1,
    String? scanLine2,
    required double qrSize,
    required double headerFontSize,
    required double bodyFontSize,
    required double logoHeight,
    required double maxWidth,
    double? introFontSize,
    String? introText,
    String? introBefore,
    String? djName,
    String? introAfter,
    String? venueLabel,
    String? venueLocation,
    String? venueLine,
    bool showVenue = false,
    bool useFullIntro = false,
    pw.ImageProvider? brandingLogo, // DJ Logo
    String? brandingText, // DJ Name als Fallback
    pw.ImageProvider? footerLogoImage,
    required String footerText,
    bool isArabicLocale = false,
    bool isFlyerLayout = false,
    String? pdfExportLanguageCode,
  }) {
    final exportMap = LocaleHelper.getTranslations(
      Locale(LocaleHelper.mapToSupportedOrEnglish(pdfExportLanguageCode ?? 'de')),
    );
    final resolvedStartTimeLabel =
        (startTimeLabel != null && startTimeLabel!.trim().isNotEmpty)
        ? startTimeLabel!
        : LocaleHelper.tr(exportMap, 'party_start_label');
    final resolvedDjDisplay =
        (djName != null && djName!.trim().isNotEmpty)
        ? djName!
        : LocaleHelper.tr(exportMap, 'party_export_dj_placeholder');

    final introDir = isArabicLocale ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    const ltr = pw.TextDirection.ltr;
    final introSize = introFontSize ?? bodyFontSize;
    final partyNameColor = PdfColor.fromHex('#1976D2'); // VibesBox-Blau
    final partyNameTitleSize =
        isFlyerLayout ? (headerFontSize * 1.2) : (headerFontSize + 12);
    final partyNameTitleStyle = pw.TextStyle(
      fontSize: partyNameTitleSize,
      fontWeight: pw.FontWeight.bold,
      color: partyNameColor,
    );
    final bodyStyle = pw.TextStyle(fontSize: bodyFontSize, color: PdfColors.grey700);

    // Header: Party-Name oben zentriert (groß, farbig), darunter Logo links (an Spalte angepasst) + Startzeit rechts
    final effectiveLogoHeight = isFlyerLayout
        ? (logoHeight * 1.1).clamp(56.0, (maxWidth * 0.38).clamp(56.0, 120.0))
        : (logoHeight * 1.5).clamp(80.0, (maxWidth * 0.55).clamp(80.0, 280.0));
    final startLabelStyle = pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800);
    final headerDateStyle = pw.TextStyle(fontSize: bodyFontSize, color: PdfColors.grey700);
    final hasLocation = showVenue &&
        ((venueLocation != null && venueLocation.isNotEmpty) || (venueLine != null && venueLine.isNotEmpty));
    // Nur Ortsname / Kartentext – kein „Veranstaltungsort“-Label (alle Sprachen)
    final locationText = (venueLocation != null && venueLocation.isNotEmpty)
        ? venueLocation
        : (venueLine ?? '');
    final qrSizeScaled = qrSize * (isFlyerLayout ? 0.60 : 0.75);
    final codeDisplay = _partyCodeLineForPdf(partyCodeDisplay, partyCode);
    final hasContactBlock = contactBlockUnderQr != null && contactBlockUnderQr.isNotEmpty;
    final contactHeaderStyle = pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800);
    final contactDjNameStyle = pw.TextStyle(fontSize: bodyFontSize + 2, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800);
    final contactDetailStyle = pw.TextStyle(fontSize: bodyFontSize - 1, color: PdfColors.grey700);
    final scanTextStyle = pw.TextStyle(fontSize: bodyFontSize, color: PdfColors.grey700);
    final footerStyle = const pw.TextStyle(fontSize: 8, color: PdfColors.grey700);
    final gapSmall = isFlyerLayout ? 5.0 : 10.0;
    final gapLarge = isFlyerLayout ? 7.0 : 15.0;
    final urlFontSize = isFlyerLayout ? 9.0 : 12.0;

    // Party-Code-Kachel: proportional zur verfügbaren Spaltenbreite (alle PDF-Formate)
    final codeBoxMaxW = maxWidth * 0.88;
    final codePadH = maxWidth * 0.040;
    final codePadV = maxWidth * 0.022;
    final codeCornerRadius = maxWidth * 0.032;
    final codeTextFontSize = bodyFontSize * 1.12;

    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.max,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // 1. HEADER (kompakt, dynamisch: kein starrer Logo-Container, Titel+Logo visuelle Einheit)
        pw.SizedBox(height: gapSmall),
        pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Center(
              child: pw.Text(partyName, style: partyNameTitleStyle, textAlign: pw.TextAlign.center, textDirection: ltr),
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Center(
                  child: brandingLogo != null
                      ? pw.Image(brandingLogo, height: effectiveLogoHeight, width: effectiveLogoHeight, fit: pw.BoxFit.contain)
                      : (brandingText != null && brandingText.isNotEmpty)
                          ? pw.Text(brandingText!, style: pw.TextStyle(fontSize: bodyFontSize + 6, fontWeight: pw.FontWeight.bold, color: PdfColors.black), textAlign: pw.TextAlign.center)
                          : pw.SizedBox.shrink(),
                ),
                pw.SizedBox(width: 25),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(resolvedStartTimeLabel, style: startLabelStyle, textAlign: pw.TextAlign.right, textDirection: ltr),
                    pw.SizedBox(height: 2),
                    pw.Text(dateTimeText, style: headerDateStyle, textAlign: pw.TextAlign.right, textDirection: ltr),
                  ],
                ),
              ],
            ),
          ],
        ),
        // 2. MITTELTEIL (Location optional, QR, Party-Code) – feste Abstände
        pw.SizedBox(height: gapLarge),
        if (hasLocation && locationText.isNotEmpty) ...[
          pw.Container(
            width: maxWidth,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Text(
              locationText,
              style: pw.TextStyle(fontSize: bodyFontSize - 1, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
              textDirection: ltr,
              maxLines: 1,
            ),
          ),
          pw.SizedBox(height: gapLarge),
        ],
        if (!hasLocation || locationText.isEmpty) pw.SizedBox(height: gapLarge),
        // Musikwunsch-Text (L10n, zentriert, zweizeilig)
        pw.SizedBox(height: gapLarge),
        if (scanLine1 != null && scanLine1.isNotEmpty)
          pw.Center(
            child: pw.Text(scanLine1, style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800), textAlign: pw.TextAlign.center, textDirection: ltr),
          ),
        if (scanLine2 != null && scanLine2.isNotEmpty)
          pw.Center(
            child: pw.Text(scanLine2, style: pw.TextStyle(fontSize: bodyFontSize - 1, color: PdfColors.grey700), textAlign: pw.TextAlign.center, textDirection: ltr),
          ),
        pw.SizedBox(height: gapLarge),
        pw.Center(
          child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: pwaUrl, width: qrSizeScaled, height: qrSizeScaled),
        ),
        pw.SizedBox(height: gapSmall),
        pw.Center(
          child: pw.ConstrainedBox(
            constraints: pw.BoxConstraints(maxWidth: codeBoxMaxW),
            child: pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: codePadH, vertical: codePadV),
              decoration: pw.BoxDecoration(
                color: PdfColors.black,
                borderRadius: pw.BorderRadius.circular(codeCornerRadius),
              ),
              child: pw.Text(
                codeDisplay,
                style: pw.TextStyle(
                  fontSize: codeTextFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textDirection: ltr,
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
        ),
        // 3. FOOTER-FIX (VibesBox-URL immer sichtbar, Kontakt nur wenn aktiv)
        pw.SizedBox(height: gapSmall),
        pw.Center(
          child: pw.Text(
            'www.VibesBox.App',
            style: pw.TextStyle(fontSize: urlFontSize, color: PdfColors.grey700),
            textDirection: ltr,
          ),
        ),
        // Spacer: drückt Kontakt-Block nach unten, Header bleibt oben zusammengeklebt
        pw.Flexible(fit: pw.FlexFit.tight, child: pw.SizedBox.shrink()),
        if (hasContactBlock) ...[
          pw.Container(
            width: maxWidth,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              ),
            ),
            padding: isFlyerLayout
                ? const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4)
                : const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.max,
              children: [
                // Linke Spalte: 35–40 % der Breite, DJ-Name umbricht nur wenn nötig
                pw.SizedBox(
                  width: maxWidth * 0.38,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('${contactBlockUnderQr!.first.split(':').first.trim()}:', style: contactHeaderStyle, textDirection: ltr),
                      pw.SizedBox(height: 4),
                      pw.Text(resolvedDjDisplay, style: contactDjNameStyle, textDirection: ltr, maxLines: 2),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                // Rechte Spalte: Expanded = restlicher Platz für E-Mails, kein Wortabbruch
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      if (contactBlockUnderQr.length > 1)
                        ...(contactBlockUnderQr[1].split(' | ').map((line) {
                          pw.ImageProvider? iconProvider;
                          String text = line;
                          if (line.startsWith('E:')) {
                            iconProvider = _cachedIconEmail;
                            text = line.substring(2).trim();
                          } else if (line.startsWith('P:')) {
                            iconProvider = _cachedIconPhone;
                            text = line.substring(2).trim();
                          }
                          const iconSize = 16.0;
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: iconProvider != null
                                ? pw.Row(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    mainAxisSize: pw.MainAxisSize.min,
                                    children: [
                                      pw.SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                        child: pw.Image(iconProvider, fit: pw.BoxFit.contain),
                                      ),
                                      pw.SizedBox(width: 6),
                                      pw.Expanded(
                                        child: pw.FittedBox(
                                          fit: pw.BoxFit.scaleDown,
                                          alignment: pw.Alignment.centerLeft,
                                          child: pw.Text(text, style: contactDetailStyle, textDirection: ltr, maxLines: 2),
                                        ),
                                      ),
                                    ],
                                  )
                                : pw.Text(line, style: contactDetailStyle, textDirection: ltr),
                          );
                        })),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (footerLogoImage != null) ...[
              pw.Image(footerLogoImage, height: logoHeight > 60 ? 28 : 20, fit: pw.BoxFit.contain),
              pw.SizedBox(width: 8),
            ],
            pw.Text(footerText, style: footerStyle, textDirection: ltr),
          ],
        ),
      ],
    );
  }

  /// Tischaufsteller-Spalte
  static pw.Widget _buildPartyColumn({
    required String partyName,
    required DateTime startDate,
    required String pwaUrl,
    required String partyCode,
    String? partyCodeDisplay,
    List<String>? contactBlockUnderQr,
    pw.ImageProvider? brandingLogo,
    String? brandingText,
    pw.ImageProvider? djWbLogoImage,
    String? pdfText,
    String? dateText,
    String? startTimeLabel,
    String? footerText,
    String? introBefore,
    String? djName,
    String? introAfter,
    String? venueLine,
    String? venueLabel,
    String? venueLocation,
    bool isArabicLocale = false,
    String? scanLine1,
    String? scanLine2,
    String? localeLanguageCode,
  }) {
    final useFullIntro =
        introBefore != null && djName != null && introAfter != null;
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        child: _buildModularPartyContent(
          partyName: partyName,
          pwaUrl: pwaUrl,
          partyCode: partyCode,
          partyCodeDisplay: partyCodeDisplay,
          contactBlockUnderQr: contactBlockUnderQr,
          dateTimeText: dateText ??
              formatDateTimeForPdf(startDate, localeLanguageCode: localeLanguageCode),
          startTimeLabel: startTimeLabel,
          qrSize: 160,
          headerFontSize: 12,
          bodyFontSize: 10,
          logoHeight: 160, // Deutlich größeres Logo für Tischaufsteller
          maxWidth: 175,
          introFontSize: 10,
          introText: useFullIntro ? null : pdfText,
          introBefore: introBefore,
          djName: djName,
          introAfter: introAfter,
          venueLine: venueLine,
          venueLabel: venueLabel,
          venueLocation: venueLocation,
          brandingLogo: brandingLogo,
          brandingText: brandingText,
          footerLogoImage: djWbLogoImage,
          footerText: footerText ?? _defaultPdfFooterText,
          useFullIntro: useFullIntro,
          showVenue: (venueLocation != null && venueLocation.isNotEmpty) || (venueLine != null && venueLine.isNotEmpty),
          isArabicLocale: isArabicLocale,
          scanLine1: scanLine1,
          scanLine2: scanLine2,
          pdfExportLanguageCode: localeLanguageCode,
        ),
      ),
    );
  }

  /// Generiert PDF für Party im 3-spaltigen Querformat (Tischaufsteller)
  static Future<void> generatePartyPdfTriple(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode, {
    String? pdfText,
    String? dateText,
    String? startTimeFormatted,
    String? startTimeLabel,
    String? introBefore,
    String? djName,
    String? introAfter,
    String? venueLine,
    String? venueLabel,
    String? venueLocation,
    String? partyCodeDisplay,
    List<String>? contactBlockUnderQr,
    String? scanLine1,
    String? scanLine2,
    // Parameter können genutzt werden für Last-Resort
    String? djLogoUrl,
    String? profileImageUrl,
    String? localeLanguageCode,
    void Function()? onBeforeLayoutPdf,
  }) async {
    // Sicherstellen, dass das Logo geladen ist (für Auto-Login Fälle)
    await UserService.ensureDjLogoCached();

    final pwaUrl = AppConfig.buildPwaUrlWithCode(partyCode);

    // Logo aus Cache oder Last-Resort
    final brandingLogo = await _resolveBrandingLogoFromCache(
      djLogoUrl: djLogoUrl,
      profileImageUrl: profileImageUrl,
    );
    
    final djWbLogoImage = await _loadLogoAsset('assets/DJ-WB.png');
    if (djWbLogoImage != null) {
      debugLog('✅ DJ-WB.png Logo erfolgreich geladen');
    }

    final footerText = _getPdfFooterText();

    final pdfTheme = await _loadPdfTheme(localeLanguageCode: localeLanguageCode);
    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        orientation: pw.PageOrientation.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          final isAr = localeLanguageCode == 'ar';
          final foldMarkColor = PdfColors.grey400;
          final foldMark = () => pw.Container(width: 0.5, height: 6, color: foldMarkColor);
          final foldLine = () => pw.VerticalDivider(
            thickness: 0.5,
            width: 4,
            color: foldMarkColor,
            borderStyle: pw.BorderStyle.dashed,
          );
          return pw.Column(
            children: [
              pw.Row(
                children: [
                  pw.Expanded(child: pw.SizedBox.shrink()),
                  foldMark(),
                  pw.Expanded(child: pw.SizedBox.shrink()),
                  foldMark(),
                  pw.Expanded(child: pw.SizedBox.shrink()),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Expanded(
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.max,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _buildPartyColumn(partyName: partyName, startDate: startDate, pwaUrl: pwaUrl, partyCode: partyCode, partyCodeDisplay: partyCodeDisplay, contactBlockUnderQr: contactBlockUnderQr, brandingLogo: brandingLogo, brandingText: djName, djWbLogoImage: djWbLogoImage, pdfText: pdfText, dateText: startTimeFormatted ?? dateText, startTimeLabel: startTimeLabel, footerText: footerText, introBefore: introBefore, djName: djName, introAfter: introAfter, venueLine: venueLine, venueLabel: venueLabel, venueLocation: venueLocation, isArabicLocale: isAr, scanLine1: scanLine1, scanLine2: scanLine2, localeLanguageCode: localeLanguageCode),
                    foldLine(),
                    _buildPartyColumn(partyName: partyName, startDate: startDate, pwaUrl: pwaUrl, partyCode: partyCode, partyCodeDisplay: partyCodeDisplay, contactBlockUnderQr: contactBlockUnderQr, brandingLogo: brandingLogo, brandingText: djName, djWbLogoImage: djWbLogoImage, pdfText: pdfText, dateText: startTimeFormatted ?? dateText, startTimeLabel: startTimeLabel, footerText: footerText, introBefore: introBefore, djName: djName, introAfter: introAfter, venueLine: venueLine, venueLabel: venueLabel, venueLocation: venueLocation, isArabicLocale: isAr, scanLine1: scanLine1, scanLine2: scanLine2, localeLanguageCode: localeLanguageCode),
                    foldLine(),
                    _buildPartyColumn(partyName: partyName, startDate: startDate, pwaUrl: pwaUrl, partyCode: partyCode, partyCodeDisplay: partyCodeDisplay, contactBlockUnderQr: contactBlockUnderQr, brandingLogo: brandingLogo, brandingText: djName, djWbLogoImage: djWbLogoImage, pdfText: pdfText, dateText: startTimeFormatted ?? dateText, startTimeLabel: startTimeLabel, footerText: footerText, introBefore: introBefore, djName: djName, introAfter: introAfter, venueLine: venueLine, venueLabel: venueLabel, venueLocation: venueLocation, isArabicLocale: isAr, scanLine1: scanLine1, scanLine2: scanLine2, localeLanguageCode: localeLanguageCode),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.SizedBox.shrink()),
                  foldMark(),
                  pw.Expanded(child: pw.SizedBox.shrink()),
                  foldMark(),
                  pw.Expanded(child: pw.SizedBox.shrink()),
                ],
              ),
            ],
          );
        },
      ),
    );

    onBeforeLayoutPdf?.call();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      format: PdfPageFormat.a4.landscape,
    );
  }

  /// Generiert PDF im neuen A4 Querformat (2x A5 nebeneinander)
  static Future<void> generatePartyPdfDoubleA5(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode, {
    String? introBefore,
    String? djName,
    String? introAfter,
    String? venueLine,
    String? venueLabel,
    String? venueLocation,
    String? partyCodeDisplay,
    List<String>? contactBlockUnderQr,
    String? scanLine1,
    String? scanLine2,
    String? startTimeFormatted,
    String? startTimeLabel,
    String? djLogoUrl,
    String? profileImageUrl,
    String? localeLanguageCode,
    void Function()? onBeforeLayoutPdf,
  }) async {
    await UserService.ensureDjLogoCached();
    final pwaUrl = AppConfig.buildPwaUrlWithCode(partyCode);
    final brandingLogo = await _resolveBrandingLogoFromCache(
      djLogoUrl: djLogoUrl,
      profileImageUrl: profileImageUrl,
    );
    final vibesboxLogoImage = await _loadLogoAsset('assets/icon/vibesbox-logo.png');
    final footerText = _getPdfFooterText();
    final pdfTheme = await _loadPdfTheme(localeLanguageCode: localeLanguageCode);
    final pdf = pw.Document(theme: pdfTheme);
    final isAr = localeLanguageCode == 'ar';
    final pdfLoc = _pdfLocaleStrings(localeLanguageCode);

    final cellContent = _buildModularPartyContent(
      partyName: partyName,
      pwaUrl: pwaUrl,
      partyCode: partyCode,
      partyCodeDisplay: partyCodeDisplay,
      contactBlockUnderQr: contactBlockUnderQr,
      dateTimeText: startTimeFormatted ??
          formatDateTimeForPdf(startDate, localeLanguageCode: localeLanguageCode),
      startTimeLabel: startTimeLabel,
      scanLine1: scanLine1,
      scanLine2: scanLine2,
      qrSize: 200,
      headerFontSize: 18,
      bodyFontSize: 12,
      logoHeight: 180, // Deutlich größeres Logo für A5
      maxWidth: 350,
      introFontSize: 12,
      introBefore: introBefore ??
          LocaleHelper.tr(pdfLoc, 'party_pdf_single_intro_before'),
      djName: (djName != null && djName.trim().isNotEmpty)
          ? djName
          : LocaleHelper.tr(pdfLoc, 'party_export_dj_placeholder'),
      introAfter: introAfter ??
          LocaleHelper.tr(pdfLoc, 'party_pdf_single_intro_after'),
      venueLine: venueLine,
      venueLabel: venueLabel,
      venueLocation: venueLocation,
      showVenue: (venueLocation != null && venueLocation.isNotEmpty) || (venueLine != null && venueLine.isNotEmpty),
      useFullIntro: true,
      brandingLogo: brandingLogo,
      brandingText: djName,
      footerLogoImage: vibesboxLogoImage,
      footerText: footerText,
      isArabicLocale: isAr,
      pdfExportLanguageCode: localeLanguageCode,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        orientation: pw.PageOrientation.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          const cutLineColor = PdfColors.grey400;
          return pw.Row(
            children: [
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(16),
                  child: cellContent,
                ),
              ),
              pw.VerticalDivider(
                thickness: 0.5,
                width: 4,
                color: cutLineColor,
                borderStyle: pw.BorderStyle.dashed,
              ),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(16),
                  child: cellContent,
                ),
              ),
            ],
          );
        },
      ),
    );

    onBeforeLayoutPdf?.call();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      format: PdfPageFormat.a4.landscape,
    );
  }

  /// Generiert PDF für Flyer: 4x A6 auf A4 Hochformat (2x2 Raster)
  static Future<void> generatePartyPdfFlyer(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode, {
    String? introBefore,
    String? djName,
    String? introAfter,
    String? venueLine,
    String? venueLabel,
    String? venueLocation,
    String? partyCodeDisplay,
    List<String>? contactBlockUnderQr,
    String? startTimeFormatted,
    String? startTimeLabel,
    String? scanLine1,
    String? scanLine2,
    String? djLogoUrl,
    String? profileImageUrl,
    String? localeLanguageCode,
    void Function()? onBeforeLayoutPdf,
  }) async {
    // Sicherstellen, dass das Logo geladen ist (für Auto-Login Fälle)
    await UserService.ensureDjLogoCached();

    final pwaUrl = AppConfig.buildPwaUrlWithCode(partyCode);
    final brandingLogo = await _resolveBrandingLogoFromCache(
      djLogoUrl: djLogoUrl,
      profileImageUrl: profileImageUrl,
    );
    final vibesboxLogoImage = await _loadLogoAsset('assets/icon/vibesbox-logo.png');
    final footerText = _getPdfFooterText();
    final pdfTheme = await _loadPdfTheme(localeLanguageCode: localeLanguageCode);
    final pdf = pw.Document(theme: pdfTheme);
    final isAr = localeLanguageCode == 'ar';
    final pdfLocFlyer = _pdfLocaleStrings(localeLanguageCode);

    final cellContent = _buildModularPartyContent(
      partyName: partyName,
      pwaUrl: pwaUrl,
      partyCode: partyCode,
      partyCodeDisplay: partyCodeDisplay,
      contactBlockUnderQr: contactBlockUnderQr,
      dateTimeText: startTimeFormatted ??
          formatDateTimeForPdf(startDate, localeLanguageCode: localeLanguageCode),
      startTimeLabel: startTimeLabel,
      qrSize: 140,
      headerFontSize: 14,
      bodyFontSize: 10,
      logoHeight: 140, // Deutlich größeres Logo für Flyer
      maxWidth: 260,
      introFontSize: 10,
      introBefore: introBefore ??
          LocaleHelper.tr(pdfLocFlyer, 'party_pdf_single_intro_before'),
      djName: (djName != null && djName.trim().isNotEmpty)
          ? djName
          : LocaleHelper.tr(pdfLocFlyer, 'party_export_dj_placeholder'),
      introAfter: introAfter ??
          LocaleHelper.tr(pdfLocFlyer, 'party_pdf_single_intro_after'),
      venueLine: venueLine,
      venueLabel: venueLabel,
      venueLocation: venueLocation,
      showVenue: (venueLocation != null && venueLocation.isNotEmpty) || (venueLine != null && venueLine.isNotEmpty),
      useFullIntro: true,
      brandingLogo: brandingLogo,
      brandingText: djName,
      footerLogoImage: vibesboxLogoImage,
      footerText: footerText,
      isArabicLocale: isAr,
      isFlyerLayout: true,
      scanLine1: scanLine1,
      scanLine2: scanLine2,
      pdfExportLanguageCode: localeLanguageCode,
    );

    const cutLineColor = PdfColors.grey400;
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(8), child: cellContent)),
                    pw.VerticalDivider(thickness: 0.5, width: 2, color: cutLineColor, borderStyle: pw.BorderStyle.dashed),
                    pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(8), child: cellContent)),
                  ],
                ),
              ),
              pw.Divider(thickness: 0.5, height: 2, color: cutLineColor, borderStyle: pw.BorderStyle.dashed),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(8), child: cellContent)),
                    pw.VerticalDivider(thickness: 0.5, width: 2, color: cutLineColor, borderStyle: pw.BorderStyle.dashed),
                    pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(8), child: cellContent)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    onBeforeLayoutPdf?.call();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /// Generiert eine einzelne Spalte PDF im Hochformat (A4-Eventplakat)
  static Future<void> generateSinglePartyPdf(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode, {
    String? introBefore,
    String? djName,
    String? introAfter,
    String? venueLine,
    String? venueLabel,
    String? venueLocation,
    String? partyCodeDisplay,
    List<String>? contactBlockUnderQr,
    String? startTimeFormatted,
    String? startTimeLabel,
    String? scanLine1,
    String? scanLine2,
    String? djLogoUrl,
    String? profileImageUrl,
    String? localeLanguageCode,
    void Function()? onBeforeLayoutPdf,
  }) async {
    // Sicherstellen, dass das Logo geladen ist (für Auto-Login Fälle)
    await UserService.ensureDjLogoCached();

    final pwaUrl = AppConfig.buildPwaUrlWithCode(partyCode);

    // Logos laden
    final brandingLogo = await _resolveBrandingLogoFromCache(
      djLogoUrl: djLogoUrl,
      profileImageUrl: profileImageUrl,
    );
    final vibesboxLogoImage = await _loadLogoAsset('assets/icon/vibesbox-logo.png');

    final footerText = _getPdfFooterText();

    final pdfTheme = await _loadPdfTheme(localeLanguageCode: localeLanguageCode);
    final pdf = pw.Document(theme: pdfTheme);
    final pdfIntroSingle = _pdfLocaleStrings(localeLanguageCode);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return _buildModularPartyContent(
            partyName: partyName,
            pwaUrl: pwaUrl,
            partyCode: partyCode,
            partyCodeDisplay: partyCodeDisplay,
            contactBlockUnderQr: contactBlockUnderQr,
            dateTimeText: startTimeFormatted ??
                formatDateTimeForPdf(startDate, localeLanguageCode: localeLanguageCode),
            startTimeLabel: startTimeLabel,
            qrSize: 300,
            headerFontSize: 28,
            bodyFontSize: 16,
            logoHeight: 200, // Deutlich größeres Logo für Plakat
            maxWidth: 380,
            introFontSize: 19,
            introBefore: introBefore ??
                LocaleHelper.tr(pdfIntroSingle, 'party_pdf_single_intro_before'),
            djName: (djName != null && djName.trim().isNotEmpty)
                ? djName
                : LocaleHelper.tr(pdfIntroSingle, 'party_export_dj_placeholder'),
            introAfter: introAfter ??
                LocaleHelper.tr(pdfIntroSingle, 'party_pdf_single_intro_after'),
            venueLine: venueLine,
            venueLabel: venueLabel,
            venueLocation: venueLocation,
            showVenue: (venueLocation != null && venueLocation.isNotEmpty) || (venueLine != null && venueLine.isNotEmpty),
            useFullIntro: true,
            brandingLogo: brandingLogo,
            brandingText: djName,
            footerLogoImage: vibesboxLogoImage,
            footerText: footerText,
            isArabicLocale: localeLanguageCode == 'ar',
            scanLine1: scanLine1,
            scanLine2: scanLine2,
            pdfExportLanguageCode: localeLanguageCode,
          );
        },
      ),
    );

    onBeforeLayoutPdf?.call();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

}

