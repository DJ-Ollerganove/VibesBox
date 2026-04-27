import 'package:flutter/material.dart';

/// Globaler [ScaffoldMessenger] für SnackBars ohne sichtbaren Tab (z. B. App-Check bei Musikerkennung).
final GlobalKey<ScaffoldMessengerState> appRootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
