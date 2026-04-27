import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_helper.dart';
import '../services/party_pdf_service.dart';
import '../services/qr_code_service.dart';
import '../services/qr_dialog_options_service.dart';
import '../utils/formatting_utils.dart';
import '../utils/party_code_utils.dart';
import '../utils/ui_constants.dart';
import '../config/app_config.dart';

/// Daten für die Anzeige des QR-Code-Dialogs (Party-Infos für show()).
class Party {
  final String partyName;
  final DateTime startDate;
  final DateTime endDate;
  final String? partyCode;
  final String? partyId;
  final String? partyLocation;
  final String? locationUrl;

  const Party({
    required this.partyName,
    required this.startDate,
    required this.endDate,
    this.partyCode,
    this.partyId,
    this.partyLocation,
    this.locationUrl,
  });
}

/// Dialog, der QR-Code für eine Party anzeigt
class PartyQrCodeDialog extends StatefulWidget {
  final Party party;
  final String? djName;
  final String? djLogoUrl;
  final String? profileImageUrl;
  /// DJ-E-Mail (Firebase Auth / Firestore)
  final String? djEmail;
  /// DJ-Telefonnummer (Firestore phoneNumber)
  final String? djPhone;
  /// Alternative E-Mail (nur wenn useAlternativeEmail und alternativeEmail vorhanden)
  final String? djAlternativeEmail;
  final Function()? onQRCodeSaved;

  const PartyQrCodeDialog({
    super.key,
    required this.party,
    this.djName,
    this.djLogoUrl,
    this.profileImageUrl,
    this.djEmail,
    this.djPhone,
    this.djAlternativeEmail,
    this.onQRCodeSaved,
  });

  @override
  State<PartyQrCodeDialog> createState() => _PartyQrCodeDialogState();

  /// Zeigt den QR-Code-Dialog für eine Party.
  static Future<void> show({
    required BuildContext context,
    required Party party,
    String? djName,
    String? djLogoUrl,
    String? profileImageUrl,
    String? djEmail,
    String? djPhone,
    String? djAlternativeEmail,
  }) async {
    final partyCode = party.partyCode;
    if (partyCode == null || partyCode.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.no_party_code_available),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => PartyQrCodeDialog(
        party: party,
        djName: djName,
        djLogoUrl: djLogoUrl,
        profileImageUrl: profileImageUrl,
        djEmail: djEmail,
        djPhone: djPhone,
        djAlternativeEmail: djAlternativeEmail,
      ),
    );
  }
}

/// Sprachliste für Export (wie in main_main_page; Namen Englisch)
const List<Map<String, String>> _kExportLanguages = [
  {'code': 'de', 'flag': '🇩🇪', 'name': 'German'},
  {'code': 'en', 'flag': '🇬🇧', 'name': 'English'},
  {'code': 'fr', 'flag': '🇫🇷', 'name': 'French'},
  {'code': 'ru', 'flag': '🇷🇺', 'name': 'Russian'},
  {'code': 'zh', 'flag': '🇨🇳', 'name': 'Chinese'},
  {'code': 'es', 'flag': '🇪🇸', 'name': 'Spanish'},
  {'code': 'tr', 'flag': '🇹🇷', 'name': 'Turkish'},
  {'code': 'pt', 'flag': '🇵🇹', 'name': 'Portuguese'},
  {'code': 'it', 'flag': '\u{1F1EE}\u{1F1F9}', 'name': 'Italian'},
  {'code': 'uk', 'flag': '\u{1F1FA}\u{1F1E6}', 'name': 'Ukrainian'},
];

class _PartyQrCodeDialogState extends State<PartyQrCodeDialog> {
  /// Schalter: welche Felder im PDF/Bild angezeigt werden (werden aus SharedPreferences geladen)
  bool _showLocation = true;
  bool _showPhone = true;
  bool _showEmail = true;
  bool _showAlternativeEmail = true;
  /// Gewählte Sprache für den Bild-Export (Standard: aktuelle App-Sprache)
  late Locale _exportLocale;
  /// Lade-Status während PDF-Schriftarten-Download
  bool _isDownloadingFont = false;
  /// Lade-Status während PDF-Generierung (nach Font-Load, vor Druck-Dialog)
  bool _isGeneratingPdf = false;

  String get _pwaUrl => AppConfig.buildPwaUrlWithCode(widget.party.partyCode!);

  /// true, wenn Party einen echten Ort hat (partyLocation oder locationUrl nicht null/leer)
  bool get _hasLocation {
    final loc = widget.party.partyLocation?.trim();
    final hasMaps = widget.party.locationUrl != null && widget.party.locationUrl!.trim().isNotEmpty;
    return (loc != null && loc.isNotEmpty) || hasMaps;
  }

  bool get _hasPhone => (widget.djPhone?.trim().isEmpty ?? true) == false;
  bool get _hasEmail => (widget.djEmail?.trim().isNotEmpty ?? false);
  bool get _hasAlternativeEmail => (widget.djAlternativeEmail?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final code = LocaleHelper.mapToSupportedOrEnglish(
      LocaleHelper.localeNotifier.value.languageCode,
    );
    _exportLocale = Locale(code);
    _loadQrDialogOptions();
  }

  /// Lädt die gespeicherten QR-Dialog-Optionen aus SharedPreferences. Default: alle true.
  Future<void> _loadQrDialogOptions() async {
    final opts = await QrDialogOptionsService().load();
    if (!mounted) return;
    setState(() {
      _showLocation = opts.showLocation && _hasLocation;
      _showPhone = opts.showPhone && _hasPhone;
      _showEmail = opts.showEmail && _hasEmail;
      _showAlternativeEmail = opts.showAlternativeEmail && _hasAlternativeEmail;
    });
  }

  /// Speichert die aktuellen Optionen sofort in SharedPreferences.
  void _persistQrDialogOptions() {
    QrDialogOptionsService().save(
      showLocation: _showLocation,
      showPhone: _showPhone,
      showEmail: _showEmail,
      showAlternativeEmail: _showAlternativeEmail,
    );
  }

  /// Formatiert Datum für Party Dialog
  String _formatDateForPartyExtra(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day.$month.$year';
  }

  Future<void> _handlePdfExport(String format) async {
    setState(() => _isDownloadingFont = true);
    try {
      await PartyPdfService.ensurePdfThemeLoaded(localeLanguageCode: _exportLocale.languageCode);
      if (!mounted) return;
      setState(() {
        _isDownloadingFont = false;
        _isGeneratingPdf = true;
      });

      final exportTranslations = LocaleHelper.getTranslations(_exportLocale);
      final localizations = AppLocalizations.of(context)!;
      final introBefore = exportTranslations['party_pdf_single_intro_before'] ?? 'Scanne den Code und sende deine Musikwünsche direkt an ';
      final introAfter = exportTranslations['party_pdf_single_intro_after'] ?? '!';
      final venueLabel = exportTranslations['party_pdf_venue'] ?? 'Veranstaltungsort';
      final startTimeFormatted = FormattingUtils.formatStartTimeForExport(widget.party.startDate, _exportLocale);
      final pdfText = localizations.party_pdf_text;

      String? venueLine;
      String? venueLocation;
      if (_showLocation && _hasLocation) {
        final locTrim = widget.party.partyLocation?.trim();
        final hasMapsUrl = widget.party.locationUrl != null && widget.party.locationUrl!.trim().isNotEmpty;
        final locationDisplay = (locTrim != null && locTrim.isNotEmpty)
            ? locTrim
            : (hasMapsUrl ? (exportTranslations['location_on_map'] ?? 'Ort auf Karte') : null);
        if (locationDisplay != null && locationDisplay.isNotEmpty) {
          // PDF: nur Ortsname (ohne statisches Label wie „Veranstaltungsort“)
          venueLine = locationDisplay;
          venueLocation = locationDisplay;
        }
      }

      // Party Code Display, Kontakt, Startzeit-Label (l10n)
      final partyCodeLabel = exportTranslations['party_code_label'] ?? 'Party-Code:';
      final contactLabel = exportTranslations['contact_label'] ?? 'Kontakt';
      final startTimeLabel = exportTranslations['party_start_label'] ?? 'Start:';
      final scanLine1 = exportTranslations['scan_qr_code_line1'] ?? 'Scan den QR Code';
      final scanLine2 = exportTranslations['scan_qr_code_line2'] ?? 'für Deinen Musikwunsch';
      final code = widget.party.partyCode ?? '';
      final formattedCode = PartyCodeUtils.formatForDisplay(code);
      final partyCodeDisplay = '$partyCodeLabel $formattedCode';

      // E: und P: Präfixe für PDF-Icon-Rendering (Font Awesome); Unicode für Dialog-Anzeige
      final contactPartsForQr = <String>[];
      if (_showEmail && _hasEmail && widget.djEmail != null && widget.djEmail!.trim().isNotEmpty) contactPartsForQr.add('E:${widget.djEmail!.trim()}');
      if (_showPhone && _hasPhone && widget.djPhone != null && widget.djPhone!.trim().isNotEmpty) contactPartsForQr.add('P:${widget.djPhone!.trim()}');
      if (_showAlternativeEmail && _hasAlternativeEmail && widget.djAlternativeEmail != null && widget.djAlternativeEmail!.trim().isNotEmpty) contactPartsForQr.add('E:${widget.djAlternativeEmail!.trim()}');
      final contactBlockUnderQr = contactPartsForQr.isNotEmpty
          ? ['$contactLabel: ${widget.djName ?? 'DJ'}', contactPartsForQr.join(' | ')]
          : null;

      void onBeforeLayoutPdf() {
        if (mounted) setState(() {
          _isDownloadingFont = false;
          _isGeneratingPdf = false;
        });
      }

      switch (format) {
        case 'plakat':
          await PartyPdfService.generateSinglePartyPdf(
            widget.party.partyName,
            widget.party.startDate,
            widget.party.endDate,
            widget.party.partyCode!,
            introBefore: introBefore,
            djName: widget.djName ?? 'DJ',
            introAfter: introAfter,
            venueLine: venueLine,
            venueLabel: venueLabel,
            venueLocation: venueLocation,
            partyCodeDisplay: partyCodeDisplay,
            contactBlockUnderQr: contactBlockUnderQr,
            startTimeFormatted: startTimeFormatted,
            startTimeLabel: startTimeLabel,
            scanLine1: scanLine1,
            scanLine2: scanLine2,
            djLogoUrl: widget.djLogoUrl,
            profileImageUrl: widget.profileImageUrl,
            localeLanguageCode: _exportLocale.languageCode,
            onBeforeLayoutPdf: onBeforeLayoutPdf,
          );
          break;
        case 'table_stand':
          await PartyPdfService.generatePartyPdfTriple(
            widget.party.partyName,
            widget.party.startDate,
            widget.party.endDate,
            widget.party.partyCode!,
            pdfText: pdfText,
            startTimeFormatted: startTimeFormatted,
            startTimeLabel: startTimeLabel,
            introBefore: introBefore,
            djName: widget.djName ?? 'DJ',
            introAfter: introAfter,
            venueLine: venueLine,
            venueLabel: venueLabel,
            venueLocation: venueLocation,
            partyCodeDisplay: partyCodeDisplay,
            contactBlockUnderQr: contactBlockUnderQr,
            scanLine1: scanLine1,
            scanLine2: scanLine2,
            djLogoUrl: widget.djLogoUrl,
            profileImageUrl: widget.profileImageUrl,
            localeLanguageCode: _exportLocale.languageCode,
            onBeforeLayoutPdf: onBeforeLayoutPdf,
          );
          break;
        case 'double_a5':
          await PartyPdfService.generatePartyPdfDoubleA5(
            widget.party.partyName,
            widget.party.startDate,
            widget.party.endDate,
            widget.party.partyCode!,
            introBefore: introBefore,
            djName: widget.djName ?? 'DJ',
            introAfter: introAfter,
            venueLine: venueLine,
            venueLabel: venueLabel,
            venueLocation: venueLocation,
            partyCodeDisplay: partyCodeDisplay,
            contactBlockUnderQr: contactBlockUnderQr,
            startTimeFormatted: startTimeFormatted,
            startTimeLabel: startTimeLabel,
            scanLine1: scanLine1,
            scanLine2: scanLine2,
            djLogoUrl: widget.djLogoUrl,
            profileImageUrl: widget.profileImageUrl,
            localeLanguageCode: _exportLocale.languageCode,
            onBeforeLayoutPdf: onBeforeLayoutPdf,
          );
          break;
        case 'flyer':
          await PartyPdfService.generatePartyPdfFlyer(
            widget.party.partyName,
            widget.party.startDate,
            widget.party.endDate,
            widget.party.partyCode!,
            introBefore: introBefore,
            djName: widget.djName ?? 'DJ',
            introAfter: introAfter,
            venueLine: venueLine,
            venueLabel: venueLabel,
            venueLocation: venueLocation,
            partyCodeDisplay: partyCodeDisplay,
            contactBlockUnderQr: contactBlockUnderQr,
            startTimeFormatted: startTimeFormatted,
            startTimeLabel: startTimeLabel,
            scanLine1: scanLine1,
            scanLine2: scanLine2,
            djLogoUrl: widget.djLogoUrl,
            profileImageUrl: widget.profileImageUrl,
            localeLanguageCode: _exportLocale.languageCode,
            onBeforeLayoutPdf: onBeforeLayoutPdf,
          );
          break;
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.pdf_generation_error} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() {
        _isDownloadingFont = false;
        _isGeneratingPdf = false;
      });
    }
  }

  Widget _buildPdfCheckbox({
    required bool value,
    required void Function(bool?)? onChanged,
    required String label,
  }) {
    final enabled = onChanged != null;
    return GestureDetector(
      onTap: enabled ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return UIConstants.appOrange;
                  return null;
                }),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled ? UIConstants.colorWhite.withValues(alpha: 0.9) : UIConstants.colorWhite.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formatiert Uhrzeit für Party Dialog
   String _formatTimeForPartyExtra(DateTime date, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final clock = l10n.party_time_clock;
    return clock.isEmpty ? '$hour:$minute' : '$hour:$minute $clock';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              UIConstants.bgGradientStart,
              UIConstants.bgGradientEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: UIConstants.partyYellow, width: 1.5),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                final locTrim = widget.party.partyLocation?.trim();
                final hasMapsUrl = widget.party.locationUrl != null && widget.party.locationUrl!.trim().isNotEmpty;
                final locationDisplay = (locTrim != null && locTrim.isNotEmpty)
                    ? locTrim
                    : (hasMapsUrl ? l10n.location_on_map : null);

                final exportTranslations = LocaleHelper.getTranslations(_exportLocale);
                final startTimeFormatted = FormattingUtils.formatStartTimeForExport(widget.party.startDate, _exportLocale);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Dialog beginnt direkt mit Partyname (kein Logo/DJ in der App-Ansicht)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.party.partyName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: UIConstants.colorWhite,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_showLocation && locationDisplay != null && locationDisplay.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              locationDisplay,
                              style: TextStyle(
                                fontSize: 12,
                                color: UIConstants.colorWhite.withValues(alpha: 0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            startTimeFormatted,
                            style: TextStyle(
                              fontSize: 12,
                              color: UIConstants.colorWhite.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Block 1: Sprachauswahl (prominent zuerst)
                    PopupMenuButton<String>(
                      onSelected: (String languageCode) {
                        final code = LocaleHelper.mapToSupportedOrEnglish(
                          languageCode,
                        );
                        setState(() => _exportLocale = Locale(code));
                      },
                      offset: const Offset(0, 40),
                      padding: EdgeInsets.zero,
                      color: const Color(0xFF1E1E1E),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, size: 22, color: UIConstants.colorWhite.withValues(alpha: 0.9)),
                          const SizedBox(width: 8),
                          Text(
                            l10n.language,
                            style: TextStyle(fontSize: 12, color: UIConstants.colorWhite.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                      itemBuilder: (BuildContext context) {
                        final sortedLanguages = List<Map<String, String>>.from(
                          _kExportLanguages,
                        )..sort(
                            (a, b) =>
                                (a['name'] as String).toLowerCase().compareTo(
                                  (b['name'] as String).toLowerCase(),
                                ),
                          );
                        return sortedLanguages.map((lang) {
                          final code = lang['code'] as String;
                          final flag = lang['flag'] as String;
                          final name = lang['name'] as String;
                          final isCurrent = code == _exportLocale.languageCode;
                          return PopupMenuItem<String>(
                            value: code,
                            child: Row(
                              children: [
                                Text(flag, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Flexible(child: Text(name, style: const TextStyle(color: Colors.white))),
                                if (isCurrent) const Icon(Icons.check, color: Colors.green, size: 20),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                    const SizedBox(height: 12),
                    // Block 2: "Auf PDF einblenden:" + Checkboxen (2 pro Zeile)
                    Text(
                      l10n.pdf_display_options,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: UIConstants.colorWhite.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPdfCheckbox(
                                value: _showLocation,
                                onChanged: _hasLocation ? (v) { setState(() => _showLocation = v ?? false); _persistQrDialogOptions(); } : null,
                                label: l10n.pdf_checkbox_location,
                              ),
                              _buildPdfCheckbox(
                                value: _showPhone,
                                onChanged: _hasPhone ? (v) { setState(() => _showPhone = v ?? false); _persistQrDialogOptions(); } : null,
                                label: l10n.pdf_checkbox_phone,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPdfCheckbox(
                                value: _showEmail,
                                onChanged: _hasEmail ? (v) { setState(() => _showEmail = v ?? false); _persistQrDialogOptions(); } : null,
                                label: l10n.pdf_checkbox_email,
                              ),
                              _buildPdfCheckbox(
                                value: _showAlternativeEmail,
                                onChanged: _hasAlternativeEmail ? (v) { setState(() => _showAlternativeEmail = v ?? false); _persistQrDialogOptions(); } : null,
                                label: l10n.pdf_checkbox_alternative_email,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: UIConstants.colorWhite),
                          const SizedBox(width: 8),
                          Text(
                            '${l10n.party_start_label} ${_formatDateForPartyExtra(widget.party.startDate)} - ${_formatTimeForPartyExtra(widget.party.startDate, context)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: UIConstants.colorWhite),
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: UIConstants.colorWhite),
                          const SizedBox(width: 8),
                          Text(
                            '${l10n.party_end_label} ${_formatDateForPartyExtra(widget.party.endDate)} - ${_formatTimeForPartyExtra(widget.party.endDate, context)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: UIConstants.colorWhite),
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Quadratische QR-Zelle (minimales Padding, kompakt)
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Center(
                      child: QrImageView(
                        data: _pwaUrl,
                        version: QrVersions.auto,
                        size: 208,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Block unter QR: Party Code, Kontakt (nur wenn Felder ausgefüllt)
                Builder(
                  builder: (innerContext) {
                    final dialogL10n = AppLocalizations.of(innerContext)!;
                    final partyCodeLabel = exportTranslations['party_code_label'] ?? 'Party-Code:';
                    final contactLabel = exportTranslations['contact_label'] ?? 'Kontakt';
                    final code = widget.party.partyCode ?? '';
                    final formattedCode = PartyCodeUtils.formatForDisplay(code);
                    // Nur Felder anzeigen, die ausgefüllt UND per Checkbox aktiviert sind (mit Icons)
                    final contactParts = <String>[];
                    if (_showEmail && _hasEmail && widget.djEmail != null && widget.djEmail!.trim().isNotEmpty) contactParts.add('📧 ${widget.djEmail!.trim()}');
                    if (_showPhone && _hasPhone && widget.djPhone != null && widget.djPhone!.trim().isNotEmpty) contactParts.add('📱 ${widget.djPhone!.trim()}');
                    if (_showAlternativeEmail && _hasAlternativeEmail && widget.djAlternativeEmail != null && widget.djAlternativeEmail!.trim().isNotEmpty) contactParts.add('📧 ${widget.djAlternativeEmail!.trim()}');
                    final hasContactBlock = contactParts.isNotEmpty;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Zeile 1: Party Code: 1234 5678
                        InkWell(
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: _pwaUrl));
                            if (innerContext.mounted) {
                              ScaffoldMessenger.of(innerContext).showSnackBar(
                                SnackBar(
                                  content: Text(dialogL10n.pwa_link_copied),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              '$partyCodeLabel $formattedCode',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        if (hasContactBlock) ...[
                          const SizedBox(height: 6),
                          // Zeile 2: Kontakt: [DJ Name] (fett)
                          Text(
                            '$contactLabel: ${widget.djName ?? 'DJ'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: UIConstants.colorWhite,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          // Zeile 3: email | phone | alt_email (dezent)
                          Text(
                            contactParts.join(' | '),
                            style: TextStyle(
                              fontSize: 11,
                              color: UIConstants.colorWhite.withValues(alpha: 0.85),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                // Kompakte Reihe: LINK | PDF | SAVE – quadratische Icons, bündig ausgerichtet
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Link kopieren (Orange – hebt sich von PDF/Speichern ab)
                    Tooltip(
                      message: l10n.tooltip_copy_link,
                      child: SizedBox(
                        width: 44,
                        height: 48,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: _pwaUrl));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.pwa_link_copied),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: UIConstants.appOrange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: UIConstants.appOrange, width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.link, color: UIConstants.appOrange, size: 18),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.link,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: UIConstants.appOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // PDF Export – rotes Quadrat, nur Icon (bündig mit Link & Speichern)
                    Tooltip(
                      message: l10n.party_pdf_export,
                      child: Material(
                        color: Colors.transparent,
                        child: PopupMenuButton<String>(
                          enabled: !_isDownloadingFont && !_isGeneratingPdf,
                          offset: const Offset(0, 55),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: UIConstants.colorRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 28),
                            ),
                          ),
                          color: Colors.black,
                          elevation: 10,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: UIConstants.partyYellow, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'plakat',
                              child: Text(
                                l10n.party_pdf_poster_a4,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'double_a5',
                              child: Text(
                                l10n.party_pdf_a4_landscape_2xa5,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'table_stand',
                              child: Text(
                                l10n.party_pdf_table_stand,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'flyer',
                              child: Text(
                                l10n.party_pdf_flyer_4xa6,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                          onSelected: (value) => _handlePdfExport(value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  // QR-Code speichern (SAVE)
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final fromLabelExport = LocaleHelper.getTranslations(_exportLocale)['party_from_dj'] ?? 'von';
                          final success = await QrCodeService.saveQRCodeAsImage(
                            _pwaUrl,
                            widget.party.partyCode!,
                            widget.party.partyName,
                            widget.party.startDate,
                            widget.party.endDate,
                            locale: _exportLocale,
                            fromLabel: fromLabelExport,
                            djName: widget.djName,
                            partyLocation: widget.party.partyLocation,
                            showLocationInExport: _showLocation,
                            djEmail: widget.djEmail,
                            djPhone: widget.djPhone,
                            djAlternativeEmail: widget.djAlternativeEmail,
                            showEmailInExport: _showEmail,
                            showPhoneInExport: _showPhone,
                            showAlternativeEmailInExport: _showAlternativeEmail,
                          );
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)!.party_qr_saved),
                                backgroundColor: Colors.green,
                              ),
                            );
                            widget.onQRCodeSaved?.call();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${AppLocalizations.of(context)!.party_error_saving_qr} $e',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image, size: 16),
                          const SizedBox(height: 2),
                          Text(
                            l10n.save,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
            ),
            if (_isDownloadingFont || _isGeneratingPdf)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: UIConstants.appOrange),
                        const SizedBox(height: 12),
                        Text(
                          _isDownloadingFont
                              ? AppLocalizations.of(context)!.party_pdf_font_downloading
                              : AppLocalizations.of(context)!.party_pdf_generating,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

