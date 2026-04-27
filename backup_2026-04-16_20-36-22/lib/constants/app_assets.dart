import 'package:flutter/material.dart';

class AppAssets {
  AppAssets._();

  static const String defaultPlaceholder = 'assets/icon/vibesbox-logo.png';

  static Widget placeholder({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      defaultPlaceholder,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.music_note, color: Colors.white70),
      ),
    );
  }
}

