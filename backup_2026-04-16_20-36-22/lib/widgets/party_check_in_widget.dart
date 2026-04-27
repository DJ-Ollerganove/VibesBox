import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../pages/qr_scanner_page.dart';
import '../services/party_session_service.dart';
import '../utils/party_code_utils.dart';
import '../utils/ui_constants.dart';
import 'party_check_in_feedback_widget.dart';

/// Widget für die 8-stellige Party-Code-Eingabe (nur Ziffern).
/// Kann von App & PWA verwendet werden.
class PartyCheckInWidget extends StatefulWidget {
  final Future<PartyCheckInFeedback?> Function(String code) onCodeSubmitted;
  final String? initialCode;

  const PartyCheckInWidget({
    super.key,
    required this.onCodeSubmitted,
    this.initialCode,
  });

  @override
  State<PartyCheckInWidget> createState() => _PartyCheckInWidgetState();
}

class _PartyCheckInWidgetState extends State<PartyCheckInWidget> {
  final _codeController = TextEditingController();
  bool _isValidating = false;
  PartyCheckInFeedback? _feedback;
  bool _showPermissionDeniedHint = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
    }
    _codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
    final digits = PartyCodeUtils.normalizeDigits(_codeController.text);
    if (digits.length == PartyCodeUtils.codeLength) {
      PartySessionService.instance.persistPendingPartyCode(digits);
    }
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final code = _codeController.text.trim();
    if (code.length != 8) return;

    setState(() {
      _isValidating = true;
      _feedback = null;
    });

    final result = await widget.onCodeSubmitted(code);
    if (mounted) {
      setState(() {
        _isValidating = false;
        _feedback = result;
      });
    }
  }

  Future<void> _onScanQrPressed() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      _showPermissionDeniedHint = false;
      if (!mounted) return;
      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (ctx) => QrScannerPage(
            onCodeScanned: (_) {},
          ),
        ),
      );
      if (code != null && mounted) {
        _codeController.text = code;
        setState(() {
          _feedback = null;
          _isValidating = true;
        });
        final result = await widget.onCodeSubmitted(code);
        if (mounted) setState(() {
          _feedback = result;
          _isValidating = false;
        });
      }
      return;
    }
    if (status.isPermanentlyDenied) {
      setState(() => _showPermissionDeniedHint = true);
      return;
    }
    final result = await Permission.camera.request();
    if (result.isGranted && mounted) {
      _showPermissionDeniedHint = false;
      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (ctx) => QrScannerPage(
            onCodeScanned: (_) {},
          ),
        ),
      );
      if (code != null && mounted) {
        _codeController.text = code;
        setState(() {
          _feedback = null;
          _isValidating = true;
        });
        final result = await widget.onCodeSubmitted(code);
        if (mounted) setState(() {
          _feedback = result;
          _isValidating = false;
        });
      }
    } else if (result.isPermanentlyDenied && mounted) {
      setState(() => _showPermissionDeniedHint = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    const labelStyle = TextStyle(
      color: UIConstants.colorWhite,
      fontSize: 14,
    );
    const hintStyle = TextStyle(
      color: UIConstants.colorGrey,
      fontSize: 14,
    );

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: UIConstants.guestBoxDecoration,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hinweistext
            Text(
              localizations.party_code_input_hint,
              style: const TextStyle(
                color: UIConstants.colorWhite,
                fontSize: 14,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 16),
            // QR-Scan-Button (Box mit oranger Rahmen, grauem Verlauf, Icon prominent)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _onScanQrPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: UIConstants.colorGreyGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: UIConstants.appOrange, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: UIConstants.appOrange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        localizations.qr_scan_button,
                        style: const TextStyle(
                          color: UIConstants.colorWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showPermissionDeniedHint) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: UIConstants.colorGreyGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: UIConstants.appOrange, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: UIConstants.colorWhite,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localizations.qr_scan_permission_denied,
                        style: const TextStyle(
                          color: UIConstants.colorWhite,
                          fontSize: 13,
                        ),
                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ),
                    TextButton(
                      onPressed: () => openAppSettings(),
                      child: Text(
                        localizations.settings_title,
                        style: const TextStyle(color: UIConstants.appOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
                // Code-Eingabefeld (8 Ziffern, nur Zahlen)
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  style: const TextStyle(color: UIConstants.colorWhite, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: localizations.party_code_label,
                    hintText: '12345678',
                    labelStyle: labelStyle,
                    hintStyle: hintStyle,
                    prefixIcon: const Icon(Icons.qr_code, color: UIConstants.appOrange),
                    prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    suffixIcon: _codeController.text.length == 8
                        ? IconButton(
                            icon: const Icon(Icons.check_circle, color: UIConstants.colorGreen),
                            onPressed: _handleSubmit,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: UIConstants.appOrange, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: UIConstants.appOrange.withValues(alpha: 0.6), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: UIConstants.appOrange, width: 2),
                    ),
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  onChanged: (value) {
                    setState(() {
                      _feedback = null;
                    });
                  },
              onFieldSubmitted: (_) => _handleSubmit(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return localizations.party_code_input_required;
                }
                if (value.trim().length != 8) {
                  return localizations.party_code_input_invalid;
                }
                return null;
              },
            ),
                const SizedBox(height: 16),
                // Submit-Button (Orange, konsistent mit Design)
                FilledButton.icon(
                  onPressed: _isValidating || _codeController.text.length != 8
                      ? null
                      : _handleSubmit,
                  icon: _isValidating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: UIConstants.colorWhite,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    localizations.confirm,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: UIConstants.appOrange,
                    foregroundColor: UIConstants.colorWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          // Feedback-Widget unterhalb des Eingabeblocks (nur wenn Prüfung stattgefunden)
          if (_feedback != null) ...[
            const SizedBox(height: 16),
            PartyCheckInFeedbackWidget(feedback: _feedback!),
          ],
        ],
      ),
    );
  }
}

