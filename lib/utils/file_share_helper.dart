import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'debug_log.dart';

/// iOS/iPad: [Share.shareXFiles] braucht [sharePositionOrigin], sonst schlägt Export fehl.
class FileShareHelper {
  FileShareHelper._();

  static Rect sharePositionOriginFor(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox &&
        box.hasSize &&
        box.size.width > 0 &&
        box.size.height > 0) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.width > 0 && rect.height > 0) {
        return rect;
      }
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  static Future<void> shareXFiles({
    required BuildContext context,
    required List<XFile> files,
    String? subject,
    String? text,
  }) async {
    if (files.isEmpty) return;

    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }

    final shareContext =
        Navigator.of(context, rootNavigator: true).overlay?.context ?? context;
    final origin = sharePositionOriginFor(shareContext);

    try {
      final result = await Share.shareXFiles(
        files,
        subject: subject,
        text: text,
        sharePositionOrigin: origin,
      );
      debugLog('FileShareHelper: Share OK → $result');
    } catch (e, st) {
      debugLog('FileShareHelper: Share fehlgeschlagen: $e\n$st');
      rethrow;
    }
  }
}
