import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// VibesBox-stilisierter Hilfe-Dialog zur Musikerkennung (l10n, dunkel + Orange/Grau-Verlauf).
Future<void> showMusicRecognitionInfoDialog(BuildContext context) async {
  final locale = Localizations.localeOf(context).languageCode;
  final isRtl = ['ar', 'he', 'fa', 'ur'].contains(locale);

  await showDialog<void>(
    context: context,
      builder: (ctx) {
      final l = AppLocalizations.of(ctx)!;
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _VibesBoxRecognitionInfoBody(l: l, maxContentHeight: MediaQuery.sizeOf(ctx).height * 0.62),
        ),
      );
    },
  );
}

class _VibesBoxRecognitionInfoBody extends StatelessWidget {
  const _VibesBoxRecognitionInfoBody({
    required this.l,
    required this.maxContentHeight,
  });

  final AppLocalizations l;
  final double maxContentHeight;

  static const LinearGradient _accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFF8C00),
      Color(0xFF6E6E6E),
      Color(0xFFFFA726),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _accentGradient,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => _accentGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => _accentGradient.createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                      child: Text(
                        l.info_music_recognition_title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxContentHeight),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.info_music_recognition_intro,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.25,
                        ),
                        textAlign: TextAlign.start,
                      ),
                      const SizedBox(height: 14),
                      _bullet(l.info_scan_process, l.info_scan_process_description),
                      const SizedBox(height: 12),
                      _bullet(l.info_scan_interval, l.info_scan_interval_description),
                      const SizedBox(height: 12),
                      _bullet(l.info_mic_sensitivity, l.info_mic_sensitivity_description),
                      const SizedBox(height: 12),
                      _bullet(l.info_recognition_threshold, l.info_recognition_threshold_description),
                      const SizedBox(height: 12),
                      _bullet(l.info_smart_threshold, l.info_smart_threshold_description),
                      const SizedBox(height: 12),
                      _bulletWithIcon(
                        Icons.bolt,
                        l.info_auto_start_recognition_info,
                        l.info_auto_start_recognition_info_description,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text(
                          l.understood,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => _accentGradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: const Text(
                '• ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => _accentGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, top: 4),
          child: Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.35,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }

  Widget _bulletWithIcon(IconData icon, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => _accentGradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => _accentGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 26, top: 4),
          child: Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.35,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }
}
