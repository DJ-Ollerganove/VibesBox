import 'dart:async';

import 'package:flutter/material.dart';

import 'app_navigator_keys.dart';
import 'services/app_diagnostic_log_service.dart';
import 'utils/ui_constants.dart';

/// Globaler [ScaffoldMessenger] für SnackBars ohne sichtbaren Tab (z. B. App-Check bei Musikerkennung).
final GlobalKey<ScaffoldMessengerState> appRootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

OverlayEntry? _activeTopSnackEntry;
Timer? _activeTopSnackTimer;

bool isGreenSuccessSnackBar(SnackBar bar) {
  final c = bar.backgroundColor;
  if (c == null) return false;
  return c == Colors.green ||
      c == Colors.green.shade800 ||
      c == UIConstants.appGreen ||
      c == UIConstants.appGreenSuccess;
}

void _dismissActiveTopSnack() {
  _activeTopSnackTimer?.cancel();
  _activeTopSnackTimer = null;
  _activeTopSnackEntry?.remove();
  _activeTopSnackEntry = null;
}

/// Grüne Erfolgs- und rote Fehler-SnackBars ganz oben über Dialogen/Overlays (Root-Overlay).
void showTopOverlayVibesSnackBar(
  SnackBar snackBar, {
  String? tag,
  Object? error,
  StackTrace? stackTrace,
}) {
  AppDiagnosticLogService.instance.recordSnackBar(
    snackBar,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );

  _dismissActiveTopSnack();

  final overlay = appRootNavigatorKey.currentState?.overlay;
  if (overlay == null) {
    appRootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
    return;
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      final topInset = MediaQuery.paddingOf(context).top;
      return Positioned(
        top: topInset + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          color: snackBar.backgroundColor ?? Colors.green,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              child: snackBar.content,
            ),
          ),
        ),
      );
    },
  );

  _activeTopSnackEntry = entry;
  overlay.insert(entry);

  final duration = snackBar.duration;
  _activeTopSnackTimer = Timer(duration, _dismissActiveTopSnack);
}

bool isErrorSnackBar(SnackBar bar) {
  final c = bar.backgroundColor;
  if (c == null) return false;
  return c == Colors.red ||
      c == Colors.red.shade700 ||
      c == Colors.red.shade800 ||
      c == UIConstants.appRed ||
      (c.red > 180 && c.green < 100 && c.blue < 100);
}

void _showSnackBarResolved(
  SnackBar snackBar, {
  required void Function(SnackBar bar) fallback,
  String? tag,
  Object? error,
  StackTrace? stackTrace,
}) {
  // Erfolg UND Fehler oben über Dialogen/Overlays — sonst liegt die SnackBar hinter Modalen.
  if (isGreenSuccessSnackBar(snackBar) || isErrorSnackBar(snackBar)) {
    showTopOverlayVibesSnackBar(
      snackBar,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }
  AppDiagnosticLogService.instance.recordSnackBar(
    snackBar,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );
  fallback(snackBar);
}

/// Zeigt eine SnackBar und schreibt sie ins Admin-Diagnose-Log (rote Fehler mit Details).
/// Erfolgs- und Fehler-SnackBars erscheinen oben über Dialogen/Overlays.
void showVibesSnackBar(
  BuildContext context,
  SnackBar snackBar, {
  String? tag,
  Object? error,
  StackTrace? stackTrace,
}) {
  _showSnackBarResolved(
    snackBar,
    fallback: (bar) => ScaffoldMessenger.of(context).showSnackBar(bar),
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );
}

/// Wie [showVibesSnackBar], aber über den Root-[ScaffoldMessenger] (ohne BuildContext).
void showRootVibesSnackBar(
  SnackBar snackBar, {
  String? tag,
  Object? error,
  StackTrace? stackTrace,
}) {
  _showSnackBarResolved(
    snackBar,
    fallback: (bar) =>
        appRootScaffoldMessengerKey.currentState?.showSnackBar(bar),
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );
}
