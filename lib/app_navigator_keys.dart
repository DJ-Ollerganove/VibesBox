import 'package:flutter/material.dart';

/// Globaler Navigator-Key für [MaterialApp] — ohne Abhängigkeit von `main.dart` (z. B. DJ-Benachrichtigungen + l10n).
final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();
