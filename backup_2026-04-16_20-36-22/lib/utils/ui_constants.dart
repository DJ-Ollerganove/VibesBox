import 'package:flutter/material.dart';

/// Zentrale UI-Konstanten für die gesamte App
/// Enthält wiederkehrende Werte wie Padding, Abstände, etc.
class UIConstants {
  UIConstants._(); // Privater Konstruktor, damit keine Instanz erstellt werden kann

  /// Padding am Ende von scrollbaren Bereichen, damit Inhalte nicht vom Footer verdeckt werden
  static const double kFooterPadding = 44.0;

  // ─── Palette (Farben) ─────────────────────────────────────────────────────
  static const Color colorBlue = Colors.blue;
  static const Color colorWhite = Colors.white;
  static const Color colorGreen = Colors.green;
  static const Color colorOrange = Color(0xFFFF9800);
  static const Color colorRed = Colors.red;
  static const Color colorGrey = Color(0xFF9E9E9E);
  static const Color colorYellow = Colors.yellow;

  // ─── Rollen (Rahmen/Akzente pro Screen) ───────────────────────────────────
  static const Color frameOffen = colorBlue;
  static const Color frameNeu = colorWhite;   // Neue/ungelesene Wünsche (Offen)
  static const Color frameGespielt = colorGreen;
  static const Color frameAbgelehnt = colorOrange; // Orange für abgelehnte Wünsche (Rahmen + Zeitstempel)
  static const Color frameGesperrt = colorRed;
  static const Color frameHistory = colorGrey;
  static const Color frameNoParty = colorRed;

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const Color bgGradientStart = Color(0xFF1F2937);
  static const Color bgGradientEnd = Color(0xFF121417);

  /// Rahmenfarbe für alle Bereiche der Partyverwaltung (Drawer-Party-Gruppe, Party-Verwaltung, Home-DJ, Dialoge)
  static const Color partyYellow = colorYellow;

  // ─── Tab-Bar (VibesBox) ────────────────────────────────────────────────────
  /// Schriftfarbe des aktiven Tabs (Weiß – hebt sich von den farbigen inaktiven Reitern ab)
  static const Color tabActiveColor = colorWhite;
  /// Themenfarben der inaktiven Tabs: Offen=Blau, Gespielt=Grün, Abgelehnt=Orange
  static const Color tabOffenColor = frameOffen;
  static const Color tabGespieltColor = frameGespielt;
  static const Color tabAbgelehntColor = frameAbgelehnt;

  // Legacy-Aliase (weiterhin nutzbar außerhalb der 6 DJ-Listen)
  static const Color appOrange = colorOrange;
  static const Color appBlue = colorBlue;
  static const Color appWhite = colorWhite;
  static const Color appGreen = colorGreen;
  static const Color appRed = colorRed;
  static const Color appGrey = colorGrey;

  /// PWA-Success-Grün für Submit-Button (--green-success: #28a745)
  static const Color appGreenSuccess = Color(0xFF28A745);

  // ─── Free-DJ-Sperre / Pro-Hinweis (Alarm-Rot, dezenter Grau-Verlauf) ───────
  /// Markanter roter Rahmen für gesperrte Free-Features (passend zu Alarm/Sperre).
  static const Color freeLimitBorderRed = Color(0xFFE53935);
  /// Dezenter Grau-Verlauf für Free-Limit-Boxen und -Dialoge.
  static const Color freeLimitGradientStart = Color(0xFF2C2C2E);
  static const Color freeLimitGradientEnd = Color(0xFF1C1C1E);
  /// Standard-Radius für Free-Limit-Elemente (abgerundete Ecken wie im App-Design).
  static const double freeLimitBorderRadius = 12.0;
  static const double freeLimitBorderWidth = 2.0;

  /// Grauer Farbverlauf für Dialoge/Karten (zentrales Design, nicht hell/weiß)
  static const LinearGradient colorGreyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [freeLimitGradientStart, freeLimitGradientEnd],
  );

  /// VibesBox-Verifizierung: durchgehender Orangeton (Rahmen Dialog / Fokus Felder)
  static const Color vibesBoxVerificationBorderOrange = Color(0xFFFF8C00);
  /// Statuszeile Erfolg (wie PWA)
  static const Color verifyStatusSuccessGreen = Color(0xFF00E676);
  /// Statuszeile Fehler (wie PWA)
  static const Color verifyStatusErrorRed = Color(0xFFFF5252);

  /// E-Mail-Verifizierungs-Dialoge (Deep-Link + manuell): grauer Verlauf, #FF8C00-Rahmen.
  static BoxDecoration get verificationDialogBoxDecoration => BoxDecoration(
        gradient: colorGreyGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vibesBoxVerificationBorderOrange,
          width: 2,
        ),
      );

  /// BoxDecoration für Gast-Ansicht (PartyCheckIn, Info-Boxen): Grau-Verlauf, oranger Rahmen.
  /// Entspricht PwaWidgetCell/DJ-Standard.
  static BoxDecoration get guestBoxDecoration => BoxDecoration(
        gradient: colorGreyGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appOrange, width: 2),
      );

  /// BoxDecoration für Eingabefelder (PWA-Glow-Style): Orange-Tint-Hintergrund, oranger Rahmen.
  /// Entspricht PWA: background rgba(255,165,0,0.2), border 2px orange.
  static BoxDecoration get guestInputBoxDecoration => BoxDecoration(
        color: appOrange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appOrange, width: 2),
      );

  /// OOB-/Verifizierungscode-Feld: konsistent mit Verifizierungs-Dialog (#FF8C00, stärker bei Fokus).
  static InputDecoration verificationOobCodeInputDecoration({
    required String? hintText,
  }) {
    const r = BorderRadius.all(Radius.circular(8));
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      filled: true,
      fillColor: Colors.black54,
      border: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(
          color: vibesBoxVerificationBorderOrange.withValues(alpha: 0.65),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(
          color: vibesBoxVerificationBorderOrange.withValues(alpha: 0.65),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(
          color: vibesBoxVerificationBorderOrange,
          width: 2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(
          color: vibesBoxVerificationBorderOrange.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  /// Erstellt einen einheitlichen Erfolgs-Dialog (grauer Verlauf, grüner Rahmen, Orange/Weiß-Button).
  /// Nutzung: showDialog(context: ctx, builder: (c) => UIConstants.buildSuccessDialog(context: c, ...))
  static Widget buildSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String buttonText,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: colorGreyGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorGreen, width: 2),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: colorGreen, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              textDirection: textDirection,
              style: const TextStyle(
                color: colorWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              textDirection: textDirection,
              style: const TextStyle(color: colorWhite, fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorOrange,
                  foregroundColor: colorWhite,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Erstellt einen Fehler-Dialog (grauer Verlauf, roter Rahmen, Orange/Weiß-Button).
  /// Gleicher Stil wie buildSuccessDialog, aber mit rotem Rahmen für Fehlermeldungen.
  static Widget buildErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String buttonText,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: colorGreyGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorRed, width: 2),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: colorRed, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              textDirection: textDirection,
              style: const TextStyle(
                color: colorWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              textDirection: textDirection,
              style: const TextStyle(color: colorWhite, fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorOrange,
                  foregroundColor: colorWhite,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Statische BoxDecoration: schwarzer Hintergrund, grüner Rahmen, Radius 8.
  static BoxDecoration get statusFrameGreen => BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appGreen, width: 1.0),
      );

  /// Statische BoxDecoration: schwarzer Hintergrund, roter Rahmen, Radius 8.
  static BoxDecoration get statusFrameRed => BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorRed, width: 1.0),
      );

  /// Legacy-Alias (weiterhin nutzbar)
  static BoxDecoration get statusFrameDecoration => statusFrameGreen;

  // ─── DJ-Shell: Vollflächen-Hintergrund (zentrales IndexedStack-Panel) ───
  /// Leicht transparentes Schwarz wie `Colors.black87`. **Nur** im zentralen Shell-Clip
  /// ([MainPage] → `IndexedStack`); Tab-Seiten darunter nutzen `Scaffold(backgroundColor: Colors.transparent)`,
  /// sonst doppelte Schicht (dunkler als z. B. [OffenPage]).
  static const Color djShellPageBackground = Color(0xDD000000); // == Colors.black87

  /// Panel/Hüllen im DJ-Bereich: halbtransparentes Schwarz + oranger Rahmen (Referenz: Party-Verwaltung).
  static BoxDecoration get djChromePanelDecoration => BoxDecoration(
        color: djShellPageBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appOrange, width: 2),
      );

  /// [Card.shape] / gleiche Außenlinie wie [djChromePanelDecoration].
  static final ShapeBorder djChromeCardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: const BorderSide(color: appOrange, width: 2),
  );

  // ─── AppBar (einheitlich für Gäste & DJ) ───────────────────────────────────
  /// Hintergrundfarbe der AppBar (Schwarz) – Fallback wenn kein Gradient
  static const Color appBarBackgroundColor = Color(0xFF050505);
  /// Lila Farbverlauf für Header (Logo + VibesBox)
  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
  );
  /// Text- und Iconfarbe (Weiß)
  static const Color appBarForegroundColor = colorWhite;
  /// Iconfarbe in der AppBar
  static const Color appBarIconColor = colorWhite;
  /// Einheitliches IconTheme für AppBar
  static const IconThemeData appBarIconTheme = IconThemeData(color: appBarIconColor);
  /// Einheitlicher Titel-TextStyle (Weiß, 20pt, bold)
  static const TextStyle appBarTitleTextStyle = TextStyle(
    color: appBarForegroundColor,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
}

