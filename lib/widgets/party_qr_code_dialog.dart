import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_helper.dart';
import 'language_menu_grid.dart';
import '../services/party_pdf_service.dart';
import '../services/qr_code_service.dart';
import '../services/qr_dialog_options_service.dart';
import '../utils/formatting_utils.dart';
import '../utils/party_code_utils.dart';
import '../utils/ui_constants.dart';
import '../utils/party_export_filename_helper.dart';
import '../config/app_config.dart';
import '../app_scaffold_messenger.dart';

/// Daten für die Anzeige des QR-Code-Dialogs (Party-Infos für show()).
class Party {
  final String partyName;
  final DateTime startDate;
  final DateTime endDate;
  final String? partyCode;
  final String? partyId;
  final String? locationName;
  final String? locationAddress;
  final String? locationUrl;

  const Party({
    required this.partyName,
    required this.startDate,
    required this.endDate,
    this.partyCode,
    this.partyId,
    this.locationName,
    this.locationAddress,
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
        showVibesSnackBar(context, 
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

class _PartyQrCodeDialogState extends State<PartyQrCodeDialog> {
  bool _showLocationName = true;
  bool _showLocationAddress = true;
  bool _showPhone = true;
  bool _showEmail = true;
  bool _showAlternativeEmail = true;
  bool _showStartDate = true;
  bool _showStartTime = true;
  /// Gewählte Sprache für den Bild-Export (Standard: aktuelle App-Sprache)
  late Locale _exportLocale;
  /// Lade-Status während PDF-Schriftarten-Download
  bool _isDownloadingFont = false;
  /// Lade-Status während PDF-Generierung (nach Font-Load, vor Druck-Dialog)
  bool _isGeneratingPdf = false;

  String get _pwaUrl => AppConfig.buildPwaUrlWithCode(widget.party.partyCode!);

  bool get _hasLocationName {
    final n = widget.party.locationName?.trim();
    return n != null && n.isNotEmpty;
  }

  bool get _hasLocationAddress {
    final a = widget.party.locationAddress?.trim();
    return a != null && a.isNotEmpty;
  }

  String? get _exportLocationName =>
      _showLocationName && _hasLocationName ? widget.party.locationName!.trim() : null;

  String? get _exportLocationAddress => _showLocationAddress && _hasLocationAddress
      ? widget.party.locationAddress!.trim()
      : null;

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
      _showLocationName = opts.showLocationName && _hasLocationName;
      _showLocationAddress = opts.showLocationAddress && _hasLocationAddress;
      _showPhone = opts.showPhone && _hasPhone;
      _showEmail = opts.showEmail && _hasEmail;
      _showAlternativeEmail = opts.showAlternativeEmail && _hasAlternativeEmail;
      _showStartDate = opts.showStartDate;
      _showStartTime = opts.showStartTime;
    });
  }

  /// Speichert die aktuellen Optionen sofort in SharedPreferences.
  void _persistQrDialogOptions() {
    QrDialogOptionsService().save(
      showLocationName: _showLocationName,
      showLocationAddress: _showLocationAddress,
      showPhone: _showPhone,
      showEmail: _showEmail,
      showAlternativeEmail: _showAlternativeEmail,
      showStartDate: _showStartDate,
      showStartTime: _showStartTime,
    );
  }

  String _formatStartForExport(Locale locale) {
    return FormattingUtils.formatStartTimeForExport(
      widget.party.startDate,
      locale,
      includeDate: _showStartDate,
      includeTime: _showStartTime,
    );
  }

  String _pdfTemplateLabel(String format, AppLocalizations l10n) {
    switch (format) {
      case 'plakat':
        return l10n.party_pdf_poster_a4;
      case 'table_stand':
        return l10n.party_pdf_table_stand;
      case 'double_a5':
        return l10n.party_pdf_a4_landscape_2xa5;
      case 'flyer':
        return l10n.party_pdf_flyer_4xa6;
      default:
        return 'PDF';
    }
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
      final introBefore =
          LocaleHelper.tr(exportTranslations, 'party_pdf_single_intro_before');
      final introAfter =
          LocaleHelper.tr(exportTranslations, 'party_pdf_single_intro_after');
      final startTimeFormatted = _formatStartForExport(_exportLocale);
      final pdfText = localizations.party_pdf_text;
      final djExportName = (widget.djName != null && widget.djName!.trim().isNotEmpty)
          ? widget.djName!
          : LocaleHelper.tr(exportTranslations, 'party_export_dj_placeholder');

      final venueLocationName = _exportLocationName;
      final venueLocationAddress = _exportLocationAddress;

      // Party Code Display, Kontakt, Startzeit-Label (l10n)
      final partyCodeLabel = LocaleHelper.tr(exportTranslations, 'party_code_label');
      final contactLabel = LocaleHelper.tr(exportTranslations, 'contact_label');
      final startTimeLabel = startTimeFormatted.isEmpty
          ? ''
          : LocaleHelper.tr(exportTranslations, 'party_start_label');
      final scanLine1 = LocaleHelper.tr(exportTranslations, 'scan_qr_code_line1');
      final scanLine2 = LocaleHelper.tr(exportTranslations, 'scan_qr_code_line2');
      final code = widget.party.partyCode ?? '';
      final formattedCode = PartyCodeUtils.formatForDisplay(code);
      final partyCodeDisplay = '$partyCodeLabel $formattedCode';

      // E: und P: Präfixe für PDF-Icon-Rendering (Font Awesome); Unicode für Dialog-Anzeige
      final contactPartsForQr = <String>[];
      if (_showEmail && _hasEmail && widget.djEmail != null && widget.djEmail!.trim().isNotEmpty) contactPartsForQr.add('E:${widget.djEmail!.trim()}');
      if (_showPhone && _hasPhone && widget.djPhone != null && widget.djPhone!.trim().isNotEmpty) contactPartsForQr.add('P:${widget.djPhone!.trim()}');
      if (_showAlternativeEmail && _hasAlternativeEmail && widget.djAlternativeEmail != null && widget.djAlternativeEmail!.trim().isNotEmpty) contactPartsForQr.add('E:${widget.djAlternativeEmail!.trim()}');
      final contactBlockUnderQr = contactPartsForQr.isNotEmpty
          ? ['$contactLabel: $djExportName', contactPartsForQr.join(' | ')]
          : null;

      final exportFileName = PartyExportFilenameHelper.build(
        templateLabel: _pdfTemplateLabel(format, localizations),
        partyName: widget.party.partyName,
        partyStartDate: widget.party.startDate,
      );

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
            djName: djExportName,
            introAfter: introAfter,
            venueLocationName: venueLocationName,
            venueLocationAddress: venueLocationAddress,
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
            exportFileName: exportFileName,
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
            djName: djExportName,
            introAfter: introAfter,
            venueLocationName: venueLocationName,
            venueLocationAddress: venueLocationAddress,
            partyCodeDisplay: partyCodeDisplay,
            contactBlockUnderQr: contactBlockUnderQr,
            scanLine1: scanLine1,
            scanLine2: scanLine2,
            djLogoUrl: widget.djLogoUrl,
            profileImageUrl: widget.profileImageUrl,
            localeLanguageCode: _exportLocale.languageCode,
            onBeforeLayoutPdf: onBeforeLayoutPdf,
            exportFileName: exportFileName,
          );
          break;
        case 'double_a5':
          await PartyPdfService.generatePartyPdfDoubleA5(
            widget.party.partyName,
            widget.party.startDate,
            widget.party.endDate,
            widget.party.partyCode!,
            introBefore: introBefore,
            djName: djExportName,
            introAfter: introAfter,
            venueLocationName: venueLocationName,
            venueLocationAddress: venueLocationAddress,
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
            exportFileName: exportFileName,
          );
          break;
        case 'flyer':
          await PartyPdfService.generatePartyPdfFlyer(
            widget.party.partyName,
            widget.party.startDate,
            widget.party.endDate,
            widget.party.partyCode!,
            introBefore: introBefore,
            djName: djExportName,
            introAfter: introAfter,
            venueLocationName: venueLocationName,
            venueLocationAddress: venueLocationAddress,
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
            exportFileName: exportFileName,
          );
          break;
      }
    } catch (e) {
      if (mounted && context.mounted) {
        showVibesSnackBar(context, 
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
                final previewName = _exportLocationName;
                final previewAddress = _exportLocationAddress;

                final previewLocale = Localizations.localeOf(context);
                final startTimeFormatted = _formatStartForExport(previewLocale);

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
                          if (previewName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              previewName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: UIConstants.colorWhite.withValues(alpha: 0.85),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (previewAddress != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              previewAddress,
                              style: TextStyle(
                                fontSize: 12,
                                color: UIConstants.colorWhite.withValues(alpha: 0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          if (startTimeFormatted.isNotEmpty)
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
                    InkWell(
                      onTap: () {
                        showLanguagePickerDialog(
                          context,
                          currentLanguageCode: _exportLocale.languageCode,
                          onLanguageSelected: (languageCode) {
                            final code = LocaleHelper.mapToSupportedOrEnglish(
                              languageCode,
                            );
                            setState(() => _exportLocale = Locale(code));
                          },
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, size: 22, color: UIConstants.colorWhite.withValues(alpha: 0.9)),
                          const SizedBox(width: 8),
                          Text(
                            l10n.qr_export_language_label,
                            style: TextStyle(fontSize: 12, color: UIConstants.colorWhite.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
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
                          child: _buildPdfCheckbox(
                            value: _showLocationName,
                            onChanged: _hasLocationName
                                ? (v) {
                                    setState(() => _showLocationName = v ?? false);
                                    _persistQrDialogOptions();
                                  }
                                : null,
                            label: l10n.pdf_checkbox_location_name,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPdfCheckbox(
                            value: _showLocationAddress,
                            onChanged: _hasLocationAddress
                                ? (v) {
                                    setState(() => _showLocationAddress = v ?? false);
                                    _persistQrDialogOptions();
                                  }
                                : null,
                            label: l10n.pdf_checkbox_location_address,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildPdfCheckbox(
                            value: _showPhone,
                            onChanged: _hasPhone
                                ? (v) {
                                    setState(() => _showPhone = v ?? false);
                                    _persistQrDialogOptions();
                                  }
                                : null,
                            label: l10n.pdf_checkbox_phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPdfCheckbox(
                            value: _showEmail,
                            onChanged: _hasEmail
                                ? (v) {
                                    setState(() => _showEmail = v ?? false);
                                    _persistQrDialogOptions();
                                  }
                                : null,
                            label: l10n.pdf_checkbox_email,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPdfCheckbox(
                            value: _showAlternativeEmail,
                            onChanged: _hasAlternativeEmail
                                ? (v) {
                                    setState(
                                      () => _showAlternativeEmail = v ?? false,
                                    );
                                    _persistQrDialogOptions();
                                  }
                                : null,
                            label: l10n.pdf_checkbox_alternative_email,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildPdfCheckbox(
                            value: _showStartDate,
                            onChanged: (v) {
                              setState(() => _showStartDate = v ?? false);
                              _persistQrDialogOptions();
                            },
                            label: l10n.pdf_checkbox_start_date,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPdfCheckbox(
                            value: _showStartTime,
                            onChanged: (v) {
                              setState(() => _showStartTime = v ?? false);
                              _persistQrDialogOptions();
                            },
                            label: l10n.pdf_checkbox_start_time,
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
                            '${l10n.party_start_label} ${FormattingUtils.formatDateForLocale(widget.party.startDate, context)} ${l10n.party_time_at} ${FormattingUtils.formatTime(widget.party.startDate, context)}',
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
                            '${l10n.party_end_label} ${FormattingUtils.formatDateForLocale(widget.party.endDate, context)} ${l10n.party_time_at} ${FormattingUtils.formatTime(widget.party.endDate, context)}',
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
                    final partyCodeLabel = dialogL10n.party_code_label;
                    final contactLabel = dialogL10n.contact_label;
                    final djDisplayQr = (widget.djName != null && widget.djName!.trim().isNotEmpty)
                        ? widget.djName!
                        : dialogL10n.translate('party_export_dj_placeholder');
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
                              showVibesSnackBar(innerContext, 
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
                            '$contactLabel: $djDisplayQr',
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
                                showVibesSnackBar(context, 
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
                          final fromLabelExport = LocaleHelper.tr(
                            LocaleHelper.getTranslations(_exportLocale),
                            'party_from_dj',
                          );
                          final imageFileName =
                              PartyExportFilenameHelper.buildQrImageFileName(
                            partyName: widget.party.partyName,
                            partyStartDate: widget.party.startDate,
                          );
                          final success = await QrCodeService.saveQRCodeAsImage(
                            _pwaUrl,
                            widget.party.partyCode!,
                            widget.party.partyName,
                            widget.party.startDate,
                            widget.party.endDate,
                            locale: _exportLocale,
                            fromLabel: fromLabelExport,
                            djName: widget.djName,
                            partyLocationName: widget.party.locationName,
                            partyLocationAddress: widget.party.locationAddress,
                            showLocationNameInExport: _showLocationName,
                            showLocationAddressInExport: _showLocationAddress,
                            djEmail: widget.djEmail,
                            djPhone: widget.djPhone,
                            djAlternativeEmail: widget.djAlternativeEmail,
                            showEmailInExport: _showEmail,
                            showPhoneInExport: _showPhone,
                            showAlternativeEmailInExport: _showAlternativeEmail,
                            showStartDateInExport: _showStartDate,
                            showStartTimeInExport: _showStartTime,
                            exportFileName: imageFileName,
                          );
                          if (success && context.mounted) {
                            showVibesSnackBar(context, 
                              SnackBar(
                                content: Text(AppLocalizations.of(context)!.party_qr_saved),
                                backgroundColor: Colors.green,
                              ),
                            );
                            widget.onQRCodeSaved?.call();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showVibesSnackBar(context, 
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

