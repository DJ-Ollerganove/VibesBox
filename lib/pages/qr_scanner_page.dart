import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';
import '../utils/qr_code_extractor.dart';
import '../utils/ui_constants.dart';

/// QR-Scanner-Seite für VibesBox-Party-Codes.
/// Dark Design (schwarz/orange), schließt automatisch bei Erfolg.
class QrScannerPage extends StatefulWidget {
  final ValueChanged<String> onCodeScanned;

  const QrScannerPage({
    super.key,
    required this.onCodeScanned,
  });

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleScan(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final code = extractPartyCodeFromQr(raw);
      if (code != null) {
        _hasScanned = true;
        HapticFeedback.mediumImpact();
        HapticFeedback.heavyImpact();
        widget.onCodeScanned(code);
        if (mounted) Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur']
        .contains(Localizations.localeOf(context).languageCode);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: UIConstants.colorWhite,
        title: Text(
          l10n.qr_scan_title,
          style: const TextStyle(color: UIConstants.colorWhite),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleScan,
          ),
          // Overlay: Scan-Rahmen (dezent, orange)
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: UIConstants.colorOrange.withValues(alpha: 0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: UIConstants.colorGreyGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: UIConstants.colorOrange,
                  width: 2,
                ),
              ),
              child: Text(
                l10n.qr_scan_hint,
                textAlign: TextAlign.center,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  color: UIConstants.colorWhite,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
