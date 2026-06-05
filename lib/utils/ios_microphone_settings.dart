import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Öffnet auf iOS bevorzugt die Systemseite **Datenschutz → Mikrofon**, wo der Schalter pro App liegt.
/// `openAppSettings()` landet nur bei den App-Einstellungen — dort gibt es oft **keinen** Mikrofon-Schalter.
Future<void> openIosMicrophonePrivacyOrAppSettings() async {
  if (!Platform.isIOS) {
    await openAppSettings();
    return;
  }
  final candidates = [
    Uri.parse('App-Prefs:root=Privacy&path=MICROPHONE'),
    Uri.parse('prefs:root=Privacy&path=MICROPHONE'),
  ];
  for (final uri in candidates) {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {}
  }
  await openAppSettings();
}
