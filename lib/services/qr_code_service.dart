import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../l10n/locale_helper.dart';
import '../utils/formatting_utils.dart';
import '../utils/party_code_utils.dart';
import 'dart:ui' as ui;
import '../utils/ui_constants.dart';
import 'user_service.dart';

/// Service für QR-Code-Funktionalität
class QrCodeService {
  /// Lädt Logo als ui.Image (DJ-Cache oder VibesBox-Fallback)
  static Future<ui.Image?> _loadLogoImage() async {
    if (UserService.cachedDjLogo != null && UserService.cachedDjLogo!.isNotEmpty) {
      try {
        final codec = await ui.instantiateImageCodec(UserService.cachedDjLogo!);
        final frame = await codec.getNextFrame();
        return frame.image;
      } catch (_) {}
    }
    try {
      final byteData = await rootBundle.load('assets/icon/vibesbox-logo.png');
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {}
    return null;
  }

  /// Speichert QR-Code mit Party-Informationen als Bild (Neues professionelles Layout).
  static Future<bool> saveQRCodeAsImage(
    String pwaUrl,
    String partyCode,
    String partyName,
    DateTime startDate,
    DateTime endDate, {
    Locale? locale,
    String? fromLabel,
    String? djName,
    String? partyLocation,
    bool showLocationInExport = true,
    String? djEmail,
    String? djPhone,
    String? djAlternativeEmail,
    bool showEmailInExport = true,
    bool showPhoneInExport = true,
    bool showAlternativeEmailInExport = true,
  }) async {
    final exportLocale = locale ?? const Locale('de');
    final startTimeFormatted = FormattingUtils.formatStartTimeForExport(startDate, exportLocale);
    final translations = LocaleHelper.getTranslations(exportLocale);
    final partyCodeLabel = LocaleHelper.tr(translations, 'party_code_label');
    final contactLabel = LocaleHelper.tr(translations, 'contact_label');
    final startTimeLabel = LocaleHelper.tr(translations, 'party_start_label');
    final scanLine1 = LocaleHelper.tr(translations, 'scan_qr_code_line1');
    final scanLine2 = LocaleHelper.tr(translations, 'scan_qr_code_line2');
    final resolvedDjName = (djName != null && djName.trim().isNotEmpty)
        ? djName
        : LocaleHelper.tr(translations, 'party_export_dj_placeholder');
    final formattedCode = PartyCodeUtils.formatForDisplay(partyCode);

    final contactParts = <String>[];
    if (showEmailInExport && djEmail != null && djEmail.trim().isNotEmpty) contactParts.add(djEmail.trim());
    if (showPhoneInExport && djPhone != null && djPhone.trim().isNotEmpty) contactParts.add(djPhone.trim());
    if (showAlternativeEmailInExport && djAlternativeEmail != null && djAlternativeEmail.trim().isNotEmpty) contactParts.add(djAlternativeEmail!.trim());
    final hasContactBlock = contactParts.isNotEmpty;

    const totalWidth = 460.0;
    const borderWidth = 3.0;
    const padding = 28.0;
    const qrSize = 300.0; // 75% von 400
    const logoAreaSize = 200.0; // Deutlich größeres DJ-Logo (quadratisch/hochkant, BoxFit.contain)
    const headerTopSpacing = 10.0;
    const headerRowSpacing = 2.0; // Titel+Logo visuelle Einheit (kompakt)
    const logoToTimeSpacing = 25.0; // Abstand Logo ↔ Startzeit (wie PDF)
    const fillingSpacing = 15.0; // Nach dem Header (SizedBox 15)
    const musicTextSpacing = 15.0; // Abstand zwischen Location und Musikwunsch-Text, sowie zwischen Text und QR
    const contactFrameSpacing = 10.0; // Abstand zwischen Linien und Kontakt-Text
    const qrToCapsuleSpacing = 18.0; // Symmetrie: QR → Party-Code-Kapsel (15–20)
    const capsuleToUrlSpacing = 15.0; // Kapsel → VibesBox-URL
    const urlToContactSpacing = 30.0; // URL → Kontakt-Block (unteres Drittel abschließen)
    const capsulePaddingH = 24.0;
    const capsulePaddingV = 12.0;
    const innerWidth = totalWidth - padding * 2 - borderWidth * 2;
    const leftColWidth = logoAreaSize + 16;

    ui.Image? logoImage = await _loadLogoImage();

    // Header Zeile 1: Party-Name oben zentriert (groß, Kursiv, farbig – VibesBox-Blau)
    const partyNameColor = Color(0xFF1976D2); // Dezentes Blau (VibesBox-Nähe)
    final partyNameStyle = const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: partyNameColor);
    final partyNamePainter = TextPainter(
      text: TextSpan(text: partyName, style: partyNameStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
    );
    partyNamePainter.layout(maxWidth: innerWidth - 24);
    // Header Zeile 2: Logo links, Startzeit rechts (l10n: "Start:" + Datum)
    final startLabelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: UIConstants.colorWhite.withValues(alpha: 0.95));
    final startLabelPainter = TextPainter(
      text: TextSpan(text: startTimeLabel, style: startLabelStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );
    startLabelPainter.layout();
    final dateStyle = TextStyle(fontSize: 13, color: UIConstants.colorWhite.withValues(alpha: 0.9));
    final datePainter = TextPainter(
      text: TextSpan(text: startTimeFormatted, style: dateStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );
    datePainter.layout(maxWidth: innerWidth / 2 - 32);
    // Logo-Zeile nur so hoch wie nötig (Titel + Logo optisch zusammen) – kein riesiger Weißraum
    double headerRowHeight;
    if (logoImage != null) {
      final iw = logoImage.width.toDouble();
      final ih = logoImage.height.toDouble();
      final scale = (iw > 0 && ih > 0)
          ? min(logoAreaSize / iw, logoAreaSize / ih).clamp(0.0, 1.0)
          : 1.0;
      headerRowHeight = (ih * scale).clamp(40.0, logoAreaSize);
    } else {
      final djNameFallback = TextPainter(
        text: TextSpan(text: resolvedDjName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: UIConstants.colorWhite)),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
      );
      djNameFallback.layout(maxWidth: leftColWidth - 8);
      headerRowHeight = djNameFallback.height.clamp(40.0, logoAreaSize);
    }
    final totalHeaderHeight = headerTopSpacing + partyNamePainter.height + headerRowSpacing + headerRowHeight;

    // Location-Block (optional, einzeilig, mit Linien)
    final hasLocation = showLocationInExport && partyLocation != null && partyLocation.trim().isNotEmpty;
    double locationBlockHeight = 0;
    if (hasLocation) {
      final locPainter = TextPainter(
        text: TextSpan(text: partyLocation!.trim(), style: TextStyle(fontSize: 11, color: UIConstants.colorWhite.withValues(alpha: 0.8))),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      );
      locPainter.layout(maxWidth: innerWidth - 16);
      locationBlockHeight = 2 + 1 + 1 + locPainter.height + 1 + 1 + 2; // halbiert
    }

    // Musikwunsch-Text (zentriert, zweizeilig)
    final musicLineStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: UIConstants.colorWhite.withValues(alpha: 0.95));
    final musicLine1Painter = TextPainter(text: TextSpan(text: scanLine1, style: musicLineStyle), textDirection: ui.TextDirection.ltr, maxLines: 1);
    musicLine1Painter.layout(maxWidth: innerWidth);
    final musicLine2Painter = TextPainter(text: TextSpan(text: scanLine2, style: musicLineStyle), textDirection: ui.TextDirection.ltr, maxLines: 1);
    musicLine2Painter.layout(maxWidth: innerWidth);
    final musicTextBlockHeight = musicTextSpacing + musicLine1Painter.height + musicLine2Painter.height + musicTextSpacing;

    // Party-Code Kapsel (schwarz, weißer Text) – Breite intrinsic aus Textlänge für l10n (ohne Label-Verdopplung)
    final codeLineRaw = '$partyCodeLabel $formattedCode';
    final codeLine = codeLineRaw.replaceAllMapped(RegExp(r'(Party-Code:\s*)+', caseSensitive: false), (_) => 'Party-Code: ').trim();
    final codeCapsuleMaxTextWidth = innerWidth - capsulePaddingH * 2;
    final codeCapsulePainter = TextPainter(
      text: TextSpan(text: codeLine, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
    );
    codeCapsulePainter.layout(maxWidth: codeCapsuleMaxTextWidth);
    final codeCapsuleWidth = codeCapsulePainter.width + capsulePaddingH * 2;
    final codeCapsuleHeight = codeCapsulePainter.height + capsulePaddingV * 2;

    // Zweispaltiger Kontakt-Block (links: Kontakt + DJ-Name, rechts: Zeilen mit Icons)
    const vbUrl = 'www.VibesBox.App';
    final vbUrlPainter = TextPainter(
      text: TextSpan(text: vbUrl, style: TextStyle(fontSize: 12, color: UIConstants.colorWhite.withValues(alpha: 0.9))),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );
    vbUrlPainter.layout();

    double contactBlockHeight = 0;
    if (hasContactBlock) {
      final contactLabelStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: UIConstants.colorWhite);
      final contactRows = <String>[];
      if (showEmailInExport && djEmail != null && djEmail!.trim().isNotEmpty) contactRows.add('\u2709 ${djEmail!.trim()}');
      if (showPhoneInExport && djPhone != null && djPhone!.trim().isNotEmpty) contactRows.add('\u260E ${djPhone!.trim()}');
      if (showAlternativeEmailInExport && djAlternativeEmail != null && djAlternativeEmail!.trim().isNotEmpty) contactRows.add('\u2709 ${djAlternativeEmail!.trim()}');
      const rowSpacing = 10.0;
      const leftColContactRatio = 0.2; // Links 20 %, rechts 80 % (Flex 1:4)
      final rightColContactWidth = innerWidth * 0.8 - 24;
      double rightColHeight = 0;
      for (final row in contactRows) {
        var fontSize = 11.0;
        TextPainter? p;
        for (var attempts = 0; attempts < 2; attempts++) {
          p = TextPainter(
            text: TextSpan(text: row, style: TextStyle(fontSize: fontSize, color: UIConstants.colorWhite.withValues(alpha: 0.9))),
            textDirection: ui.TextDirection.ltr,
            maxLines: 2,
          );
          p.layout(maxWidth: rightColContactWidth);
          if (!p.didExceedMaxLines || fontSize <= 9) break;
          fontSize = (fontSize - 1).clamp(9.0, 11.0);
        }
        rightColHeight += (p?.height ?? 0) + rowSpacing;
      }
      rightColHeight = rightColHeight > 0 ? rightColHeight - rowSpacing : 0;
      final leftLabelP = TextPainter(text: TextSpan(text: '$contactLabel:', style: contactLabelStyle), textDirection: ui.TextDirection.ltr, maxLines: 1);
      leftLabelP.layout();
      final djNameStyle = const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: UIConstants.colorWhite); // +2pt, fett
      final leftNameP = TextPainter(text: TextSpan(text: resolvedDjName, style: djNameStyle), textDirection: ui.TextDirection.ltr, maxLines: 2);
      leftNameP.layout(maxWidth: innerWidth * leftColContactRatio - 24);
      final leftColHeight = leftLabelP.height + 8 + leftNameP.height;
      final contentHeight = leftColHeight > rightColHeight ? leftColHeight : rightColHeight;
      contactBlockHeight = contactFrameSpacing + 1 + contactFrameSpacing + contentHeight + contactFrameSpacing + 1 + contactFrameSpacing; // Linie oben, Abstand, Inhalt, Abstand, Linie unten
    }

    final totalHeight = borderWidth * 2 + padding + totalHeaderHeight + fillingSpacing
        + locationBlockHeight
        + musicTextBlockHeight + qrSize + qrToCapsuleSpacing
        + codeCapsuleHeight + capsuleToUrlSpacing + vbUrlPainter.height + urlToContactSpacing
        + contactBlockHeight
        + padding;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fullRect = Rect.fromLTWH(0, 0, totalWidth, totalHeight);
    final innerRect = Rect.fromLTWH(borderWidth, borderWidth, totalWidth - borderWidth * 2, totalHeight - borderWidth * 2);

    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [UIConstants.bgGradientStart, UIConstants.bgGradientEnd],
      ).createShader(innerRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(16)),
      gradientPaint,
    );

    final borderPaint = Paint()
      ..color = UIConstants.partyYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(fullRect, const Radius.circular(16)),
      borderPaint,
    );

    final baseX = borderWidth + padding;
    double currentY = baseX + headerTopSpacing;

    // === HEADER Zeile 1: Party-Name zentriert (groß, farbig, Kursiv) ===
    partyNamePainter.paint(canvas, Offset(baseX + (innerWidth - partyNamePainter.width) / 2, currentY));
    currentY += partyNamePainter.height + headerRowSpacing;

    // === HEADER Zeile 2: Logo links (oder DJ-Name wenn kein Logo), Startzeit rechts ===
    final headerRowY = currentY;
    final leftCenterX = baseX + leftColWidth / 2;
    if (logoImage != null) {
      final iw = logoImage.width.toDouble();
      final ih = logoImage.height.toDouble();
      final scale = (iw > 0 && ih > 0)
          ? min(logoAreaSize / iw, logoAreaSize / ih).clamp(0.0, 1.0)
          : 1.0;
      final scaledW = iw * scale;
      final scaledH = ih * scale;
      final srcRect = Rect.fromLTWH(0, 0, iw, ih);
      final dstLeft = leftCenterX - scaledW / 2;
      final dstTop = headerRowY + (headerRowHeight - scaledH) / 2;
      canvas.drawImageRect(logoImage, srcRect, Rect.fromLTWH(dstLeft, dstTop, scaledW, scaledH), Paint()..filterQuality = FilterQuality.medium);
    } else {
      final djNameText = resolvedDjName;
      final djNameStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: UIConstants.colorWhite);
      final djNamePainter = TextPainter(
        text: TextSpan(text: djNameText, style: djNameStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
      );
      djNamePainter.layout(maxWidth: leftColWidth - 8);
      djNamePainter.paint(canvas, Offset(leftCenterX - djNamePainter.width / 2, headerRowY + (headerRowHeight - djNamePainter.height) / 2));
    }

    final rightColEnd = baseX + innerWidth - logoToTimeSpacing;
    startLabelPainter.paint(canvas, Offset(rightColEnd - startLabelPainter.width, headerRowY));
    datePainter.paint(canvas, Offset(rightColEnd - datePainter.width, headerRowY + startLabelPainter.height + 6));

    currentY += headerRowHeight + fillingSpacing;

    final linePaint = Paint()..color = UIConstants.colorWhite.withValues(alpha: 0.25)..strokeWidth = 1;

    // === LOCATION (optional, einzeilig, gerahmt) ===
    if (hasLocation) {
      final locY = currentY;
      canvas.drawLine(Offset(baseX, locY), Offset(baseX + innerWidth, locY), linePaint);
      currentY += 2;
      final locPainter = TextPainter(
        text: TextSpan(text: partyLocation!.trim(), style: TextStyle(fontSize: 11, color: UIConstants.colorWhite.withValues(alpha: 0.8))),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      );
      locPainter.layout(maxWidth: innerWidth - 16);
      locPainter.paint(canvas, Offset(baseX + 8, currentY));
      currentY += locPainter.height + 1;
      canvas.drawLine(Offset(baseX, currentY), Offset(baseX + innerWidth, currentY), linePaint);
      currentY += 2;
    }

    // === MUSIKWUNSCH-TEXT (zentriert, zweizeilig) ===
    currentY += musicTextSpacing;
    musicLine1Painter.paint(canvas, Offset(baseX + (innerWidth - musicLine1Painter.width) / 2, currentY));
    currentY += musicLine1Painter.height;
    musicLine2Painter.paint(canvas, Offset(baseX + (innerWidth - musicLine2Painter.width) / 2, currentY));
    currentY += musicLine2Painter.height + musicTextSpacing;

    // === QR-CODE (zentriert, 75% Größe) ===
    final qrLeft = baseX + (innerWidth - qrSize) / 2;
    final qrRect = RRect.fromRectAndRadius(Rect.fromLTWH(qrLeft, currentY, qrSize, qrSize), const Radius.circular(12));
    canvas.drawRRect(qrRect, Paint()..color = Colors.white);

    final qrPainter = QrPainter(
      data: pwaUrl,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
    const qrPadding = 8.0;
    canvas.save();
    canvas.translate(qrLeft + qrPadding, currentY + qrPadding);
    qrPainter.paint(canvas, const Size(qrSize - qrPadding * 2, qrSize - qrPadding * 2));
    canvas.restore();
    currentY += qrSize + qrToCapsuleSpacing;

    // === PARTY-CODE (schwarze Kapsel, flexibel mit Textlänge für l10n wie "Código de la fiesta") ===
    final codeCapsuleWidthClamped = (codeCapsuleWidth > innerWidth) ? innerWidth : codeCapsuleWidth;
    final codeCapsuleLeft = baseX + (innerWidth - codeCapsuleWidthClamped) / 2;
    final codeCapsuleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(codeCapsuleLeft, currentY, codeCapsuleWidthClamped, codeCapsuleHeight),
      Radius.circular(codeCapsuleHeight / 2),
    );
    canvas.drawRRect(codeCapsuleRect, Paint()..color = Colors.black);
    codeCapsulePainter.paint(
      canvas,
      Offset(codeCapsuleLeft + (codeCapsuleWidthClamped - codeCapsulePainter.width) / 2, currentY + capsulePaddingV),
    );
    currentY += codeCapsuleHeight + capsuleToUrlSpacing;

    // === VIBESBOX-URL (unter Party-Code, immer sichtbar, unabhängig von Location) ===
    vbUrlPainter.paint(canvas, Offset(baseX + (innerWidth - vbUrlPainter.width) / 2, currentY));
    currentY += vbUrlPainter.height + urlToContactSpacing;

    // === ZWEISPALTIGER KONTAKT-BLOCK (gerahmt wie Location: Linie oben, Abstand, Inhalt, Abstand, Linie unten) ===
    if (hasContactBlock) {
      canvas.drawLine(Offset(baseX, currentY), Offset(baseX + innerWidth, currentY), linePaint);
      currentY += contactFrameSpacing;

      const leftColContactRatio = 0.2;
      final contactLabelStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: UIConstants.colorWhite);
      final djNameStyle = const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: UIConstants.colorWhite);
      final contactRows = <String>[];
      if (showEmailInExport && djEmail != null && djEmail!.trim().isNotEmpty) contactRows.add('\u2709 ${djEmail!.trim()}');
      if (showPhoneInExport && djPhone != null && djPhone!.trim().isNotEmpty) contactRows.add('\u260E ${djPhone!.trim()}');
      if (showAlternativeEmailInExport && djAlternativeEmail != null && djAlternativeEmail!.trim().isNotEmpty) contactRows.add('\u2709 ${djAlternativeEmail!.trim()}');
      const rowSpacing = 10.0;
      final leftLabelP = TextPainter(text: TextSpan(text: '$contactLabel:', style: contactLabelStyle), textDirection: ui.TextDirection.ltr, maxLines: 1);
      leftLabelP.layout();
      leftLabelP.paint(canvas, Offset(baseX + 8, currentY));
      final leftNameP = TextPainter(text: TextSpan(text: resolvedDjName, style: djNameStyle), textDirection: ui.TextDirection.ltr, maxLines: 2);
      leftNameP.layout(maxWidth: innerWidth * leftColContactRatio - 24);
      leftNameP.paint(canvas, Offset(baseX + 8, currentY + leftLabelP.height + 8));
      final leftColHeight = leftLabelP.height + 8 + leftNameP.height;
      final rightColLeft = baseX + innerWidth * leftColContactRatio + 16;
      final rightColContactWidth = innerWidth * 0.8 - 24;
      double rightY = currentY;
      for (final row in contactRows) {
        var fontSize = 11.0;
        TextPainter? rowP;
        for (var attempts = 0; attempts < 2; attempts++) {
          rowP = TextPainter(
            text: TextSpan(text: row, style: TextStyle(fontSize: fontSize, color: UIConstants.colorWhite.withValues(alpha: 0.9))),
            textDirection: ui.TextDirection.ltr,
            maxLines: 2,
          );
          rowP.layout(maxWidth: rightColContactWidth);
          if (!rowP.didExceedMaxLines || fontSize <= 9) break;
          fontSize = (fontSize - 1).clamp(9.0, 11.0);
        }
        rowP!.paint(canvas, Offset(rightColLeft, rightY));
        rightY += rowP.height + rowSpacing;
      }
      final rightColHeight = rightY > currentY ? rightY - currentY - rowSpacing : 0.0;
      final contentHeight = (leftColHeight > rightColHeight ? leftColHeight : rightColHeight);
      currentY += contentHeight + contactFrameSpacing;
      // Untere Trennlinie
      canvas.drawLine(Offset(baseX, currentY), Offset(baseX + innerWidth, currentY), linePaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final result = await ImageGallerySaver.saveImage(
      pngBytes,
      quality: 100,
      name: 'QR_Code_$partyCode',
    );

    if (result['isSuccess'] == true) {
      return true;
    } else {
      throw Exception(LocaleHelper.tr(translations, 'qr_gallery_save_failed'));
    }
  }
}
