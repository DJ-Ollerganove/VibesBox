import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_flutter_charts/charts.dart' as sf_charts;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:app_links/app_links.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options.dart';
import 'spotify_service.dart';

// Globale Notification-Instanz
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Globale Theme-Notifier
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.light);

// Sanitization-Funktion: Entfernt potenziell gefährliche Zeichen und HTML-Tags
String sanitizeInput(String input) {
  if (input.isEmpty) return '';
  
  // Entferne HTML-Tags (einfache Regex-basierte Lösung)
  String sanitized = input
      .replaceAll(RegExp(r'<[^>]*>'), '') // Entferne HTML-Tags
      .replaceAll(RegExp(r'javascript:', caseSensitive: false), '') // Entferne javascript: Links
      .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '') // Entferne Event-Handler wie onclick=
      .trim();
  
  // Entferne gefährliche Zeichen-Kombinationen
  sanitized = sanitized
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#x2F;', '/');
  
  return sanitized;
}

// Sanitization-Funktion speziell für Email-Adressen
// Entfernt HTML/JavaScript, behält aber Email-Format bei
String sanitizeEmail(String email) {
  if (email.isEmpty) return '';
  
  // Entferne HTML-Tags und JavaScript
  String sanitized = email
      .replaceAll(RegExp(r'<[^>]*>'), '') // Entferne HTML-Tags
      .replaceAll(RegExp(r'javascript:', caseSensitive: false), '') // Entferne javascript: Links
      .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '') // Entferne Event-Handler
      .trim();
  
  // Entferne HTML-Entities (aber behalte @ und . für Email-Format)
  sanitized = sanitized
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#x2F;', '/');
  
  return sanitized;
}

// Hilfsfunktion zum Anzeigen von Firebase-Fehlern mit klickbaren Links
Widget buildFirebaseErrorWidget(Object error) {
  final errorString = error.toString();
  
  // Suche nach Firebase-Console-Links (verschiedene Patterns)
  String? url;
  
  // Pattern 1: Standard Firebase Console Link
  final urlRegex1 = RegExp(r'https://console\.firebase\.google\.com/[^\s\)\]]+');
  final match1 = urlRegex1.firstMatch(errorString);
  if (match1 != null) {
    url = match1.group(0);
  }
  
  // Pattern 2: Falls URL in Anführungszeichen steht
  if (url == null) {
    final urlRegex2 = RegExp(r'https://console\.firebase\.google\.com/[^\s\)\]]+');
    final match2 = urlRegex2.firstMatch(errorString);
    if (match2 != null) {
      url = match2.group(0);
    }
  }
  
  // Pattern 3: Suche nach "https://" und nimm alles bis zum nächsten Leerzeichen oder Zeilenende
  if (url == null) {
    final urlRegex3 = RegExp(r'https://console\.firebase\.google\.com/[^\s\n]+');
    final match3 = urlRegex3.firstMatch(errorString);
    if (match3 != null) {
      url = match3.group(0);
    }
  }
  
  if (url != null) {
    // Bereinige die URL (entferne mögliche abschließende Zeichen)
    final cleanUrl = url.replaceAll(RegExp(r'[\)\]\},;]+$'), '');
    
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Firebase Index erforderlich',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Bitte öffne den Link unten im Browser, um den Index zu erstellen:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // URL in SelectableText anzeigen
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: SelectableText(
                  cleanUrl,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Button zum Kopieren
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: cleanUrl));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL wurde in die Zwischenablage kopiert!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('URL kopieren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Button zum Öffnen (als Alternative)
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final uri = Uri.parse(cleanUrl);
                    final launched = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!launched && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Konnte Link nicht automatisch öffnen. Bitte kopiere die URL und öffne sie manuell im Browser.'),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fehler beim Öffnen: $e\nBitte kopiere die URL manuell.'),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Im Browser öffnen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tipp: Falls der Button nicht funktioniert, kopiere die URL und öffne sie manuell in deinem Browser.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Fallback: Normale Fehlermeldung mit vollständigem Text
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Fehler aufgetreten',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SelectableText(
            errorString,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

// Hilfsfunktion zum Erhöhen des deleted_count
Future<void> incrementDeletedCount() async {
  try {
    final statsRef = FirebaseFirestore.instance
        .collection('admin_stats')
        .doc('wishes');
    
    await statsRef.set({
      'deleted_count': FieldValue.increment(1),
    }, SetOptions(merge: true));
  } catch (e) {
    print('Fehler beim Erhöhen von deleted_count: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Lade Theme-Einstellung
  await _loadThemeMode();
  
  // Initialisiere Local Notifications
  await _initializeNotifications();
  
  runApp(const DJOgApp());
}

Future<void> _loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final mode = prefs.getString('theme_mode');
  if (mode == 'dark') {
    themeModeNotifier.value = ThemeMode.dark;
  } else {
    themeModeNotifier.value = ThemeMode.light;
  }
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
}

// Initialisiert den Notification-Service
Future<void> _initializeNotifications() async {
  // Android-Einstellungen
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  
  // iOS-Einstellungen (optional, für zukünftige iOS-Unterstützung)
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  
  // Initialisiere den Plugin
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      // Wird aufgerufen, wenn der User auf die Benachrichtigung tippt
      // Kann für Navigation verwendet werden
    },
  );
  
  // Android 13+ benötigt explizite Berechtigung
  if (Platform.isAndroid) {
    final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      
      // Lösche alten Channel (falls vorhanden) und erstelle neuen mit benutzerdefiniertem Sound
      // WICHTIG: Android erlaubt keine Änderung bestehender Channels, daher löschen und neu erstellen
      try {
        // Versuche den Channel zu löschen (funktioniert nur wenn er existiert)
        await androidPlugin.deleteNotificationChannel('new_wishes_channel');
        print('🔄 Alter Notification Channel gelöscht');
        // Warte kurz, damit Android den Löschvorgang verarbeitet
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('ℹ️ Channel existiert noch nicht oder konnte nicht gelöscht werden: $e');
      }
      
      // Erstelle Notification-Channel für Android 8.0+ mit benutzerdefiniertem Sound
      const androidChannel = AndroidNotificationChannel(
        'new_wishes_channel', // Channel-ID (muss mit AndroidNotificationDetails übereinstimmen)
        'Neue Wünsche', // Channel-Name
        description: 'Benachrichtigungen für neue Wünsche',
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'), // Eigener Warteton
        enableVibration: true,
        showBadge: true,
      );
      
      await androidPlugin.createNotificationChannel(androidChannel);
      print('✅ Notification Channel mit benutzerdefiniertem Sound erstellt');
      print('   Sound-Datei: notification.mp3');
    }
  }
}

class DJOgApp extends StatelessWidget {
  const DJOgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'DJ OG – Wünsche',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: mode,
          home: const MainPage(),
          routes: {
            '/wishes': (context) => const WishesPage(),
            '/contact': (context) => const ContactPage(),
          },
        );
      },
    );
  }
}

// Hauptseite mit Drawer
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  User? _previousUser;
  StreamSubscription<User?>? _authSubscription;
  final GlobalKey<_ContactFormState> _contactFormKey = GlobalKey<_ContactFormState>();
  Timer? _newWishesCheckTimer;
  int _newWishesCount = 0;
  DateTime? _lastNotifiedWishTime; // Speichert den letzten benachrichtigten Wunsch-Timestamp
  StreamSubscription<QuerySnapshot>? _wishesStreamSubscription; // Stream für neue Wünsche
  final GlobalKey<_OffenPageState> _offenPageKey = GlobalKey<_OffenPageState>();
  static const MethodChannel _batteryChannel = MethodChannel('dj_og_app/battery_optimization');
  bool _batteryOptimizationChecked = false;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  // Getter für _currentIndex, damit andere Widgets darauf zugreifen können
  int get currentIndex => _currentIndex;
  
  void _onIndexChanged(int newIndex) {
    final oldIndex = _currentIndex;
    setState(() {
      _currentIndex = newIndex;
    });
    
    // Wenn die Offen-Seite verlassen wird (Index 2 -> etwas anderes)
    if (oldIndex == 2 && newIndex != 2) {
      _offenPageKey.currentState?.onPageLeft();
    }
    // Wenn zur Offen-Seite zurückgekehrt wird (etwas anderes -> Index 2)
    if (oldIndex != 2 && newIndex == 2) {
      _offenPageKey.currentState?.onPageReturned();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _previousUser = FirebaseAuth.instance.currentUser;
    // Höre auf Auth-Änderungen
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        // Wenn User-Status sich geändert hat, Index zurücksetzen
        if ((_previousUser == null) != (user == null) || 
            (_previousUser?.email != user?.email)) {
          setState(() {
            _currentIndex = 0;
            _previousUser = user;
          });
        } else {
          _previousUser = user;
        }
        // Timer starten/stoppen basierend auf Admin-Status
        _setupNewWishesTimer(user);
      }
    });
    // Initial Timer-Setup
    _setupNewWishesTimer(_previousUser);
    
    // Prüfe Batterie-Optimierung beim Start
    if (Platform.isAndroid) {
      _checkBatteryOptimization();
    }
    
    // Initialisiere Deep Link-Verarbeitung
    _initDeepLinks();
    
    // Prüfe beim Start auf gespeicherten Party-Code
    _checkForStoredPartyCode();
  }
  
  // Initialisiert die Deep Link-Verarbeitung
  void _initDeepLinks() {
    // Prüfe initialen Link (wenn App durch Deep Link geöffnet wurde)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
    
    // Höre auf zukünftige Deep Links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('Fehler beim Verarbeiten von Deep Links: $err');
      },
    );
  }
  
  // Verarbeitet einen Deep Link
  Future<void> _handleDeepLink(Uri uri) async {
    print('Deep Link erhalten: $uri');
    
    // Prüfe ob es ein Wunschbox-Link ist
    if (uri.scheme == 'djwunschbox' && uri.host == 'wunschbox') {
      // Extrahiere Party-Code aus Query-Parametern
      final partyCode = uri.queryParameters['code'];
      
      if (partyCode != null && partyCode.isNotEmpty) {
        // Speichere Party-Code in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('party_code', partyCode);
        print('Party-Code gespeichert: $partyCode');
        
        // Navigiere zur Wunschbox (Index 0 ist die Wunschbox)
        if (mounted) {
          setState(() {
            _currentIndex = 0;
          });
        }
      }
    }
  }
  
  // Prüft beim App-Start, ob ein Party-Code gespeichert wurde
  Future<void> _checkForStoredPartyCode() async {
    try {
      // Party-Code sollte bereits über Deep Link gesetzt sein
      // Falls die App ohne Deep Link gestartet wurde, prüfe SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedCode = prefs.getString('party_code');
      if (storedCode != null && storedCode.isNotEmpty) {
        print('Gespeicherter Party-Code gefunden beim App-Start: $storedCode');
        // Navigiere zur Wunschbox, falls noch nicht dort
        if (mounted && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      }
    } catch (e) {
      print('Fehler beim Prüfen des gespeicherten Party-Codes: $e');
    }
  }
  
  // Prüft, ob die Batterie-Optimierung aktiviert ist und zeigt einen Dialog
  Future<void> _checkBatteryOptimization() async {
    if (_batteryOptimizationChecked) return;
    
    try {
      if (Platform.isAndroid) {
        final isIgnoring = await _batteryChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
        
        if (!isIgnoring && mounted) {
          _batteryOptimizationChecked = true;
          
          // Zeige Dialog nach kurzer Verzögerung (damit die App vollständig geladen ist)
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _showBatteryOptimizationDialog();
            }
          });
        }
      }
    } catch (e) {
      print('Fehler beim Prüfen der Batterie-Optimierung: $e');
    }
  }
  
  // Zeigt einen Dialog, der den Benutzer auffordert, die Batterie-Optimierung zu deaktivieren
  void _showBatteryOptimizationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Batterie-Optimierung deaktivieren'),
          content: const Text(
            'Damit die App im Hintergrund neue Wünsche empfangen kann, '
            'muss die Batterie-Optimierung für diese App deaktiviert werden.\n\n'
            'Bitte tippe auf "Einstellungen öffnen" und wähle "Nicht optimieren".'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Später'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestIgnoreBatteryOptimizations();
              },
              child: const Text('Einstellungen öffnen'),
            ),
          ],
        );
      },
    );
  }
  
  // Öffnet die Einstellungen, um die Batterie-Optimierung zu deaktivieren
  Future<void> _requestIgnoreBatteryOptimizations() async {
    try {
      if (Platform.isAndroid) {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (e) {
      print('Fehler beim Öffnen der Batterie-Optimierungs-Einstellungen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Öffnen der Einstellungen. Bitte manuell öffnen: Einstellungen → Apps → DJ WunschBox → Batterie → Nicht optimieren'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null && user.email == 'info@dj-ollerganove.de';
    
    print('📱 App Lifecycle State geändert: $state');
    
    if (state == AppLifecycleState.resumed) {
      // App ist wieder im Vordergrund - Timer sollte laufen
      print('✅ App ist im Vordergrund - Timer wird gestartet');
      if (isAdmin) {
        _setupNewWishesTimer(user);
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App ist im Hintergrund - Timer läuft weiter, prüfe sofort und stelle sicher, dass Timer läuft
      print('⏸️ App ist im Hintergrund - prüfe sofort auf neue Wünsche');
      if (isAdmin) {
        // Prüfe sofort, wenn App in den Hintergrund geht
        _checkNewWishes();
        // Stelle sicher, dass Stream weiterläuft (wird nicht gestoppt)
        // Stream sollte weiterlaufen, aber prüfe ob er noch aktiv ist
        if (_wishesStreamSubscription == null) {
          print('⚠️ Stream war nicht aktiv - starte neu');
          _setupNewWishesTimer(user);
        } else {
          print('✅ Stream läuft weiter im Hintergrund');
        }
      }
    } else if (state == AppLifecycleState.detached) {
      // App wird beendet - Timer wird automatisch gestoppt
      print('🛑 App wird beendet');
    }
  }

  void _setupNewWishesTimer(User? user) {
    _newWishesCheckTimer?.cancel();
    _wishesStreamSubscription?.cancel();
    final isAdmin = user != null && (user.email == 'info@dj-ollerganove.de');
    if (isAdmin) {
      final currentState = WidgetsBinding.instance.lifecycleState;
      print('⏰ Stream für neue Wünsche wird gestartet');
      print('   App-Status: $currentState');
      // Sofort prüfen (nur einmal beim Start)
      _checkNewWishes();
      // Verwende Stream statt Timer - aktualisiert automatisch bei Änderungen
      _wishesStreamSubscription = FirebaseFirestore.instance
          .collection('wishes')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        // Stream aktualisiert automatisch - prüfe nur auf neue Wünsche
        _checkNewWishesFromStream(snapshot);
      });
      print('✅ Stream gestartet - aktualisiert automatisch bei Änderungen');
    }
  }

  Future<void> _checkNewWishes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email != 'info@dj-ollerganove.de') return;

    final appState = WidgetsBinding.instance.lifecycleState;
    print('🔍 Prüfe auf neue Wünsche... (App-Status: $appState)');
    try {
      // Lade letzten "gesehen" Timestamp
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final lastViewed = userDoc.data()?['last_viewed_wishes_at'] as Timestamp?;
      DateTime lastViewedTime;
      
      if (lastViewed != null) {
        lastViewedTime = lastViewed.toDate();
        print('📅 Last viewed time: $lastViewedTime');
      } else {
        // Beim ersten Start (nach Neuinstallation): Setze aktuellen Zeitpunkt
        // Damit werden nur Wünsche nach dem App-Start als "neu" erkannt
        print('⚠️ Kein last_viewed_wishes_at gefunden - setze aktuellen Zeitpunkt');
        lastViewedTime = DateTime.now();
        print('📅 Last viewed time (neu gesetzt): $lastViewedTime');
        // Speichere den aktuellen Zeitpunkt in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'last_viewed_wishes_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      // Zähle neue Wünsche (pending, erstellt nach lastViewedTime)
      // Lade alle pending Wünsche und filtere clientseitig (um Index zu vermeiden)
      final query = FirebaseFirestore.instance
          .collection('wishes')
          .where('status', isEqualTo: 'pending');

      final snapshot = await query.get();
      
      // Filtere clientseitig: nur Wünsche nach lastViewedTime und keine Duplikate
      // WICHTIG: Im Hintergrund verwenden wir eine kleine Toleranz (5 Sekunden), 
      // um auch Wünsche zu erfassen, die kurz vor dem Minimieren erstellt wurden
      final isBackground = appState == AppLifecycleState.paused || 
                          appState == AppLifecycleState.inactive;
      final tolerance = isBackground 
          ? const Duration(seconds: 5) // Im Hintergrund: 5 Sekunden Toleranz
          : Duration.zero; // Im Vordergrund: Keine Toleranz
      
      final adjustedLastViewedTime = lastViewedTime.subtract(tolerance);
      
      // Zuerst: Finde alle neuen Wünsche (nach lastViewedTime, keine Duplikate)
      // Diese werden für die Badge-Anzeige verwendet
      final allNewWishes = snapshot.docs.where((doc) {
        final data = doc.data();
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        
        final isNotDuplicate = data['is_duplicate'] != true;
        final isAfterLastViewed = created.isAfter(adjustedLastViewedTime);
        
        return isNotDuplicate && isAfterLastViewed;
      }).toList();
      
      // Zähle alle neuen Wünsche für die Badge-Anzeige
      final newWishesCount = allNewWishes.length;
      
      // Dann: Filtere nur die, die noch nicht per Push benachrichtigt wurden
      // Diese werden für die Push-Benachrichtigung verwendet
      // WICHTIG: Ignoriere die Markierung, wenn der Wunsch nach _lastNotifiedWishTime erstellt wurde
      final newWishesForNotification = allNewWishes.where((doc) {
        final data = doc.data();
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        
        final isNotNotified = data['notified_via_push'] != true; // Noch nicht per Push benachrichtigt
        
        // Wenn _lastNotifiedWishTime gesetzt ist, prüfe ob der Wunsch danach erstellt wurde
        // Wenn ja, ignoriere die Markierung (sie könnte falsch sein)
        if (_lastNotifiedWishTime != null && created.isAfter(_lastNotifiedWishTime!.subtract(const Duration(milliseconds: 100)))) {
          // Wunsch wurde nach _lastNotifiedWishTime erstellt - behandle als nicht benachrichtigt
          return true;
        }
        
        return isNotNotified;
      }).toList();
      
      // Debug-Logs für Hintergrund-Modus
      // (isBackground wurde bereits oben deklariert)
      if (isBackground) {
        print('🔍 Hintergrund-Prüfung:');
        print('   Last viewed: $lastViewedTime');
        print('   Toleranz: ${tolerance.inSeconds}s');
        print('   Adjusted last viewed: $adjustedLastViewedTime');
        print('   Aktuelle Zeit: ${DateTime.now()}');
        print('   Gefilterte neue Wünsche: $newWishesCount');
        if (snapshot.docs.isNotEmpty) {
          // Finde den neuesten Wunsch (nicht nur den ersten)
          DateTime? newestCreated;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final tsCreated = data['createdAt'] as Timestamp?;
            if (tsCreated != null) {
              final created = tsCreated.toDate();
              if (newestCreated == null || created.isAfter(newestCreated)) {
                newestCreated = created;
              }
            }
          }
          if (newestCreated != null) {
            print('   Neuester Wunsch in DB: $newestCreated');
            final diff = newestCreated.difference(adjustedLastViewedTime);
            print('   Zeitdifferenz zum adjusted last viewed: ${diff.inMilliseconds}ms');
          }
        }
      }
      
      // Prüfe, ob es wirklich neue Wünsche gibt
      if (allNewWishes.isNotEmpty) {
        // Finde den neuesten Wunsch (mit Titel und Interpret) aus ALLEN neuen Wünschen
        // (nicht nur aus denen, die noch nicht benachrichtigt wurden)
        DateTime? newestWishTime;
        String? newestWishTitle;
        String? newestWishArtist;
        QueryDocumentSnapshot? newestWishDoc;
        
        for (final doc in allNewWishes) {
          final data = doc.data();
          final tsCreated = data['createdAt'];
          final created = tsCreated is Timestamp
              ? tsCreated.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          
          if (newestWishTime == null || created.isAfter(newestWishTime)) {
            newestWishTime = created;
            newestWishTitle = data['title'] as String?;
            newestWishArtist = data['artist'] as String?;
            newestWishDoc = doc;
          }
        }
        
        // Finde den neuesten Wunsch aus den noch nicht benachrichtigten (für die Benachrichtigung)
        DateTime? newestNotifiedWishTime;
        String? newestNotifiedWishTitle;
        String? newestNotifiedWishArtist;
        
        for (final doc in newWishesForNotification) {
          final data = doc.data();
          final tsCreated = data['createdAt'];
          final created = tsCreated is Timestamp
              ? tsCreated.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          
          if (newestNotifiedWishTime == null || created.isAfter(newestNotifiedWishTime)) {
            newestNotifiedWishTime = created;
            newestNotifiedWishTitle = data['title'] as String?;
            newestNotifiedWishArtist = data['artist'] as String?;
          }
        }
        
        // Sende Benachrichtigung nur, wenn es wirklich neue Wünsche gibt
        // (die nach dem letzten benachrichtigten Zeitpunkt erstellt wurden)
        // WICHTIG: Benachrichtige, wenn der neueste Wunsch NACH dem letzten benachrichtigten Zeitpunkt liegt
        // Verwende eine Toleranz von 500ms, um Rundungsfehler zu vermeiden
        // Wenn die App im Hintergrund ist, benachrichtige auch bei kleineren Unterschieden
        // (isBackground wurde bereits oben deklariert)
        
        // Entscheidungslogik für Benachrichtigung:
        // Wenn es neue Wünsche gibt, die noch nicht per Push benachrichtigt wurden, benachrichtige
        // Vergleiche mit _lastNotifiedWishTime, um sicherzustellen, dass es wirklich neue Wünsche sind
        bool shouldNotify = false;
        // Entscheidungslogik für Benachrichtigung:
        // Benachrichtige nur, wenn es Wünsche gibt, die noch nicht per Push benachrichtigt wurden
        // UND der neueste noch nicht benachrichtigte Wunsch nach _lastNotifiedWishTime liegt
        if (newWishesForNotification.isNotEmpty && newestNotifiedWishTime != null) {
          if (_lastNotifiedWishTime == null) {
            // Erster Lauf: Immer benachrichtigen, wenn es neue Wünsche gibt
            shouldNotify = true;
            print('   ✅ Erster Lauf - benachrichtige (${newWishesForNotification.length} neue Wünsche)');
          } else {
            // Prüfe, ob der neueste noch nicht benachrichtigte Wunsch nach dem letzten benachrichtigten Zeitpunkt liegt
            final diff = newestNotifiedWishTime.difference(_lastNotifiedWishTime!);
            // Benachrichtigen nur, wenn der Wunsch wirklich neuer ist (mehr als 100ms später)
            // Dies verhindert, dass derselbe Wunsch mehrmals benachrichtigt wird
            shouldNotify = diff.inMilliseconds > 100; // > 100ms bedeutet wirklich später
            print('   ${isBackground ? "Hintergrund" : "Vordergrund"}: diff=${diff.inMilliseconds}ms, newWishesForNotification=${newWishesForNotification.length}, shouldNotify=$shouldNotify');
          }
        } else {
          print('   ❌ Keine neuen Wünsche für Benachrichtigung: newWishesForNotification=${newWishesForNotification.length}, newestWishTime=$newestWishTime');
          if (newWishesForNotification.isEmpty && allNewWishes.isNotEmpty) {
            print('   ⚠️ Alle ${allNewWishes.length} neuen Wünsche sind bereits als benachrichtigt markiert');
          }
        }
        
        if (shouldNotify) {
          print('✅ Neue Wünsche gefunden: ${newWishesForNotification.length} (von $newWishesCount insgesamt) - sende Benachrichtigung');
          print('   Neuester Wunsch: $newestWishTime');
          print('   Letzter benachrichtigter Zeitpunkt: ${_lastNotifiedWishTime ?? "null"}');
          print('   App-Status: $appState (Hintergrund: $isBackground)');
          if (newestWishTime != null && _lastNotifiedWishTime != null) {
            final diff = newestWishTime.difference(_lastNotifiedWishTime!);
            print('   Zeitdifferenz: ${diff.inMilliseconds}ms');
          }
          await _showNewWishNotification(
            newWishesForNotification.isNotEmpty ? newWishesForNotification.length : 1, 
            newestNotifiedWishTitle ?? newestWishTitle, 
            newestNotifiedWishArtist ?? newestWishArtist
          );
          _lastNotifiedWishTime = newestNotifiedWishTime ?? newestWishTime;
          
          // Markiere NUR die Wünsche als "per Push benachrichtigt", die tatsächlich benachrichtigt wurden
          // WICHTIG: Nur markieren, wenn shouldNotify = true war und die Benachrichtigung gesendet wurde
          if (newWishesForNotification.isNotEmpty) {
            final batch = FirebaseFirestore.instance.batch();
            for (final doc in newWishesForNotification) {
              batch.update(doc.reference, {
                'notified_via_push': true,
              });
            }
            await batch.commit();
            print('✅ ${newWishesForNotification.length} Wünsche als "per Push benachrichtigt" markiert');
          } else {
            print('⚠️ Keine Wünsche zum Markieren (newWishesForNotification ist leer)');
          }
        } else {
          print('ℹ️ Keine neuen Wünsche oder bereits benachrichtigt');
          if (newestWishTime != null && _lastNotifiedWishTime != null) {
            final diff = newestWishTime.difference(_lastNotifiedWishTime!);
            print('   Neuester Wunsch: $newestWishTime');
            print('   Letzter benachrichtigter Zeitpunkt: $_lastNotifiedWishTime');
            print('   Zeitdifferenz: ${diff.inMilliseconds}ms');
            if (isBackground) {
              print('   (Im Hintergrund: Benachrichtigung bei >= 0ms)');
            } else {
              print('   (Im Vordergrund: Benachrichtigung bei > 1000ms)');
            }
            print('   App-Status: $appState (Hintergrund: $isBackground)');
          }
        }
      }
      
      if (mounted) {
    setState(() {
          _newWishesCount = newWishesCount;
        });
      }
      
      print('📊 Neue Wünsche: $newWishesCount (von ${snapshot.docs.length} pending Wünschen)');
      print('   Last viewed: $lastViewedTime');
    } catch (e) {
      print('❌ Fehler beim Prüfen neuer Wünsche: $e');
    }
  }

  // Prüft neue Wünsche basierend auf Stream-Update (ohne setState für die gesamte Seite)
  Future<void> _checkNewWishesFromStream(QuerySnapshot snapshot) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email != 'info@dj-ollerganove.de') return;

    try {
      // Lade letzten "gesehen" Timestamp
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final lastViewed = userDoc.data()?['last_viewed_wishes_at'] as Timestamp?;
      DateTime lastViewedTime;
      
      if (lastViewed != null) {
        lastViewedTime = lastViewed.toDate();
      } else {
        lastViewedTime = DateTime.now();
      }

      // Zähle neue Wünsche (pending, erstellt nach lastViewedTime)
      final allNewWishes = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        
        final isNotDuplicate = data['is_duplicate'] != true;
        final isAfterLastViewed = created.isAfter(lastViewedTime);
        
        return isNotDuplicate && isAfterLastViewed;
      }).toList();
      
      final newWishesCount = allNewWishes.length;
      
      // Prüfe auf neue Wünsche für Push-Benachrichtigungen
      final appState = WidgetsBinding.instance.lifecycleState;
      final isBackground = appState == AppLifecycleState.paused || 
                          appState == AppLifecycleState.inactive;
      final tolerance = isBackground 
          ? const Duration(seconds: 5)
          : Duration.zero;
      
      final adjustedLastViewedTime = lastViewedTime.subtract(tolerance);
      
      final newWishesForNotification = allNewWishes.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        
        final isNotNotified = data['notified_via_push'] != true;
        
        if (_lastNotifiedWishTime != null && created.isAfter(_lastNotifiedWishTime!.subtract(const Duration(milliseconds: 100)))) {
          return true;
        }
        
        return isNotNotified;
      }).toList();
      
      // Zeige Push-Benachrichtigung für neue Wünsche
      if (newWishesForNotification.isNotEmpty) {
        DateTime? newestWishTime;
        String? newestWishTitle;
        String? newestWishArtist;
        
        for (final doc in newWishesForNotification) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final tsCreated = data['createdAt'];
          final created = tsCreated is Timestamp
              ? tsCreated.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          
          if (newestWishTime == null || created.isAfter(newestWishTime)) {
            newestWishTime = created;
            newestWishTitle = data['title'] as String?;
            newestWishArtist = data['artist'] as String?;
          }
        }
        
        await _showNewWishNotification(newWishesCount, newestWishTitle, newestWishArtist);
        
        // Markiere alle neuen Wünsche als benachrichtigt
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in newWishesForNotification) {
          batch.update(doc.reference, {'notified_via_push': true});
        }
        await batch.commit();
        
        _lastNotifiedWishTime = newestWishTime;
      }
      
      // Aktualisiere nur den Counter, wenn er sich geändert hat (verhindert unnötige Rebuilds)
      if (mounted && _newWishesCount != newWishesCount) {
        setState(() {
          _newWishesCount = newWishesCount;
        });
      }
    } catch (e) {
      print('❌ Fehler beim Prüfen neuer Wünsche aus Stream: $e');
    }
  }

  // Zeigt eine Push-Benachrichtigung für neue Wünsche an
  Future<void> _showNewWishNotification(int count, String? wishTitle, String? wishArtist) async {
    try {
      final appState = WidgetsBinding.instance.lifecycleState;
      print('🔔 Zeige Benachrichtigung für $count neue Wünsche an');
      print('📱 App-Status: $appState');
      print('   Benachrichtigung wird angezeigt (auch im Hintergrund)');
      
      // Titel der Benachrichtigung
      final title = count == 1 
          ? 'Neuer Wunsch eingegangen!'
          : '$count neue Wünsche eingegangen!';
      
      // Body der Benachrichtigung: "Titel - Interpret"
      String body;
      if (wishTitle != null && wishTitle.isNotEmpty && 
          wishArtist != null && wishArtist.isNotEmpty) {
        body = '$wishTitle - $wishArtist';
      } else if (wishTitle != null && wishTitle.isNotEmpty) {
        body = wishTitle;
      } else if (wishArtist != null && wishArtist.isNotEmpty) {
        body = wishArtist;
      } else {
        body = 'Neuer Wunsch';
      }

      const androidDetails = AndroidNotificationDetails(
        'new_wishes_channel', // Channel-ID
        'Neue Wünsche', // Channel-Name
        channelDescription: 'Benachrichtigungen für neue Wünsche',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'), // Eigener Warteton
        ongoing: false,
        autoCancel: true,
        visibility: NotificationVisibility.public, // Sichtbar auf Sperrbildschirm
        fullScreenIntent: false, // Wird auf Sperrbildschirm angezeigt, öffnet aber nicht Vollbild
        category: AndroidNotificationCategory.message,
        channelShowBadge: true,
        ticker: 'Neuer Wunsch eingegangen!', // Text, der im Status-Bar angezeigt wird
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        0, // ID (0 = immer die neueste Benachrichtigung ersetzen)
        title,
        body,
        notificationDetails,
      );
      
      print('✅ Benachrichtigung erfolgreich angezeigt (mit Sound und Vibration)');
    } catch (e) {
      print('❌ Fehler beim Anzeigen der Benachrichtigung: $e');
    }
  }

  Future<void> _markWishesAsViewed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email != 'info@dj-ollerganove.de') return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'last_viewed_wishes_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      // Setze auch den letzten benachrichtigten Zeitpunkt zurück
      _lastNotifiedWishTime = null;
      
      if (mounted) {
        setState(() {
          _newWishesCount = 0;
        });
      }
    } catch (e) {
      print('Fehler beim Markieren der Wünsche als gesehen: $e');
    }
  }

  @override
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    _newWishesCheckTimer?.cancel();
    _wishesStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null && (user.email == 'info@dj-ollerganove.de');
    
    // Stelle sicher, dass _currentIndex gültig ist
    final children = isAdmin
        ? const [
            HomePage(),
            PartyVerwaltungPage(),
            OffenPage(),
            GespieltPage(),
            AbgelehntPage(),
            ProfilPage(),
            SocialMediaPage(),
            AboutPage(),
          ]
        : [
            const HomePage(),
            const WishesPage(),
            if (user != null) const DeineWunschePage(),
            if (user != null) const ProfilPage(),
            ContactPage(contactFormKey: _contactFormKey),
            const SocialMediaPage(),
            const AboutPage(),
          ];
    
    // Wenn Index außerhalb des gültigen Bereichs, zurücksetzen
    if (_currentIndex >= children.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
    setState(() {
            _currentIndex = 0;
          });
        }
      });
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/logo.png',
          height: 40,
          fit: BoxFit.contain,
          color: null,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              height: 40,
              width: 40,
              child: Icon(Icons.music_note, size: 24),
            );
          },
        ),
        leading: null,
        automaticallyImplyLeading: false,
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.menu, size: 24),
                    if (_newWishesCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$_newWishesCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                iconSize: 24,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              );
            },
          ),
        ],
      ),
      endDrawer: _buildDrawer(), // Rechts positioniert
      body: IndexedStack(
        index: _currentIndex < (isAdmin ? 8 : children.length) ? _currentIndex : 0,
        children: isAdmin
            ? [
                const HomePage(),
                const PartyVerwaltungPage(),
                OffenPage(key: _offenPageKey, onPageOpened: _markWishesAsViewed),
                const GespieltPage(),
                const AbgelehntPage(),
                const ProfilPage(),
                const SocialMediaPage(),
                const AboutPage(),
              ]
            : children,
      ),
    );
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null && (user.email == 'info@dj-ollerganove.de');

    return Drawer(
      width: 200, // Deutlich schmaler (Standard: ~304px)
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            padding: const EdgeInsets.all(12), // Kleineres Padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 40, // Kleiner (statt 60)
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.music_note, size: 30);
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (user != null)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          String? photoURL;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            photoURL = data?['photoURL'] as String?;
                          }
                          return CircleAvatar(
                            radius: 15, // Kleiner (statt 20)
                            backgroundColor: Colors.grey[300],
                            backgroundImage: photoURL != null
                                ? NetworkImage(photoURL)
                                : null,
                            child: photoURL == null
                                ? Icon(
                                    Icons.person,
                                    size: 15, // Kleiner (statt 20)
                                    color: Colors.grey[600],
                                  )
                                : null,
                          );
                        },
                      ),
                    if (user != null) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user != null
                                ? (user.displayName ?? user.email ?? 'User')
                                : 'Gast',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 14, // Kleiner
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user != null)
                            Text(
                              user.email ?? '',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10, // Kleiner
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Home ganz oben
          ListTile(
            dense: true, // Kompakter
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.home, size: 20), // Kleiner
            title: const Text('Home', style: TextStyle(fontSize: 14)),
            selected: _currentIndex == 0,
            onTap: () {
              _onIndexChanged(0);
              Navigator.pop(context);
            },
          ),
          const Divider(height: 1),
          if (isAdmin) ...[
            // Admin-Menü
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.event, size: 20),
              title: const Text('Party-Verwaltung', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == 1,
              onTap: () {
                _onIndexChanged(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.pending, size: 20),
                  if (_newWishesCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          _newWishesCount > 99 ? '99+' : '$_newWishesCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              title: const Text('Offen', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == 2,
              onTap: () {
                _onIndexChanged(2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.check_circle, size: 20),
              title: const Text('Gespielt', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == 3,
              onTap: () {
                _onIndexChanged(3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.cancel, size: 20),
              title: const Text('Abgelehnt', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == 4,
              onTap: () {
                _onIndexChanged(4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.person, size: 20),
              title: const Text('Profil', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == 5,
              onTap: () {
                _onIndexChanged(5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.share, size: 20),
              title: const Text('Social Media', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == 6,
              onTap: () {
                _onIndexChanged(6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.info, size: 20),
              title: const Text('ÜBER DJ WB', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == 7,
              onTap: () {
                _onIndexChanged(7);
                Navigator.pop(context);
              },
            ),
          ] else ...[
            // Normales User-Menü
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.music_note, size: 20),
              title: const Text('Wunschbox', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == 1,
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
            if (user != null)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.favorite, size: 20),
                title: const Text('Deine Wünsche', style: TextStyle(fontSize: 14)),
                selected: _currentIndex == 2,
                onTap: () {
                  setState(() => _currentIndex = 2);
                  Navigator.pop(context);
                },
              ),
            if (user != null)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.person, size: 20),
                title: const Text('Profil', style: TextStyle(fontSize: 14)),
                selected: _currentIndex == 3,
                onTap: () {
                  setState(() => _currentIndex = 3);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.contact_mail, size: 20),
              title: const Text('Kontakt', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == (user != null ? 4 : 2),
              onTap: () {
                final newIndex = user != null ? 4 : 2;
                // Wenn wir zur ContactPage navigieren, setze Erfolgsmeldung zurück
                if (_currentIndex != newIndex) {
                  // Setze Erfolgsmeldung direkt zurück, bevor wir navigieren
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _contactFormKey.currentState?.resetSuccessMessage();
                  });
                }
                setState(() => _currentIndex = newIndex);
                Navigator.pop(context);
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.share, size: 20),
              title: const Text('Social Media', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == (user != null ? 5 : 3),
              onTap: () {
                setState(() => _currentIndex = user != null ? 5 : 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.info, size: 20),
              title: const Text('ÜBER DJ WB', style: TextStyle(fontSize: 14)),
              selected: _currentIndex == (user != null ? 6 : 4),
              onTap: () {
                setState(() => _currentIndex = user != null ? 6 : 4);
                Navigator.pop(context);
              },
            ),
          ],
          const Divider(height: 1),
          if (user == null)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.login, size: 20),
              title: const Text('Anmelden', style: TextStyle(fontSize: 14)),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
                setState(() {});
              },
            )
          else
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.logout, size: 20),
              title: const Text('Abmelden', style: TextStyle(fontSize: 14)),
              onTap: () async {
                Navigator.pop(context);
                // Lösche gespeichertes Passwort beim Abmelden
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('saved_email');
                await prefs.remove('saved_password');
                await FirebaseAuth.instance.signOut();
                setState(() {
                  _currentIndex = 0; // Index zurücksetzen beim Ausloggen
                });
              },
            ),
        ],
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Nach 2 Sekunden zur Hauptseite navigieren
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WishesPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/logo.png',
              height: 120,
              fit: BoxFit.contain,
              color: null, // Wichtig: Keine Farbe setzen, damit Transparenz erhalten bleibt
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                // Fallback wenn Logo nicht gefunden wird
                return const SizedBox(
                  height: 120,
                  child: Icon(Icons.music_note, size: 80),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Musikwünsche',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // User ist eingeloggt
          return const WishesPage();
        }
        // User ist nicht eingeloggt
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true; // true = Login, false = Registrierung
  bool _isLoading = false;
  bool _showPassword = true;
  bool _showConfirmPassword = true;
  bool _savePassword = false; // Checkbox zum Speichern des Passworts

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    
    if (savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _savePassword = true;
      });
      
      // Automatisch einloggen
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _signInWithEmail();
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Bitte gib ein Passwort ein.';
    }
    if (value.length < 8) {
      return 'Das Passwort muss mindestens 8 Zeichen lang sein.';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Das Passwort muss mindestens einen Großbuchstaben enthalten.';
    }
    if (!value.contains(RegExp(r'[-_!()]'))) {
      return 'Das Passwort muss mindestens eines der folgenden Sonderzeichen enthalten: - _ ! ( )';
    }
    return null;
  }

  bool _isAdminEmail(String? email) {
    if (email == null) return false;
    final adminEmails = [
      'info@dj-ollerganove.de',
      // Weitere Admin-Emails können hier hinzugefügt werden
    ];
    return adminEmails.contains(email.toLowerCase());
  }
  
  // Admin-Passwort für zusätzliche Sicherheit
  static const String _adminPassword = 'OG-1005-OG';
  
  bool _isAdminPassword(String password) {
    return password == _adminPassword;
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    // Sanitize Email gegen Schadcode (Passwort wird NICHT sanitisiert, da Sonderzeichen wichtig sind)
    final email = sanitizeEmail(_emailController.text.trim());
    final password = _passwordController.text; // Passwort nicht sanitisieren - Sonderzeichen sind wichtig!

    // Prüfe Admin-Passwort, wenn es eine Admin-Email ist
    if (_isAdminEmail(email)) {
      if (!_isAdminPassword(password)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falsches Admin-Passwort.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Login-Zähler und letzten Login aktualisieren
      print('=== LOGIN ERFOLGREICH ===');
      print('User UID: ${userCredential.user?.uid}');
      print('User Email: ${userCredential.user?.email}');
      if (userCredential.user != null) {
        print('Starte Firestore-Update für Login-Statistik...');
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          int currentCount = 0;
          Timestamp? previousLogin;
          if (userDoc.exists) {
            final data = userDoc.data();
            final loginCountValue = data?['loginCount'];
            if (loginCountValue is int) {
              currentCount = loginCountValue;
            } else if (loginCountValue is num) {
              currentCount = loginCountValue.toInt();
            }
            // Speichere den aktuellen lastLogin als previousLogin
            final lastLoginValue = data?['lastLogin'];
            if (lastLoginValue is Timestamp) {
              previousLogin = lastLoginValue;
            }
            print('Aktueller Login-Zähler aus Firestore: $currentCount');
            print('Vorheriger Login: $previousLogin');
          } else {
            print('User-Dokument existiert noch nicht, erstelle neues Dokument');
          }
          
          final newCount = currentCount + 1;
          final now = Timestamp.now();
          print('Neuer Login-Zähler wird gespeichert: $newCount');
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'email': userCredential.user!.email,
            'displayName': userCredential.user!.displayName,
            'loginCount': newCount,
            'lastLogin': now, // Aktueller Login
            'previousLogin': previousLogin, // Vorheriger Login (für Anzeige)
          }, SetOptions(merge: true));
          
          print('Login-Zähler erfolgreich aktualisiert: $newCount');
          
          // Verifiziere, dass die Daten gespeichert wurden
          final verifyDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();
          if (verifyDoc.exists) {
            final verifyData = verifyDoc.data();
            print('Verifizierung - Gespeicherter loginCount: ${verifyData?['loginCount']}');
            print('Verifizierung - Gespeicherter lastLogin: ${verifyData?['lastLogin']}');
          }
        } catch (e, stackTrace) {
          // Zeige Fehler an, damit wir das Problem sehen können
          print('Firestore login update fehlgeschlagen: $e');
          print('Stack trace: $stackTrace');
          // Fehler wird nicht angezeigt, da User bereits eingeloggt ist
          // Aber wir loggen es für Debugging
        }
      }
      
      // Speichere Passwort, wenn Checkbox aktiviert ist
      if (_savePassword) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);
      } else {
        // Lösche gespeichertes Passwort, wenn Checkbox deaktiviert ist
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }
      
      // Erfolgreich eingeloggt - zurück navigieren
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.code)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isNameBlocked(String name) {
    final normalizedName = name.trim().toUpperCase();
    
    // Blockierte Namen
    final blockedNames = ['DJ', 'OLLERGANOVE', 'GANOVE', 'OLLER', 'ADMIN'];
    if (blockedNames.contains(normalizedName)) {
      return true;
    }
    
    // Blacklist für unangemessene Begriffe
    final inappropriateWords = [
      // Schimpfwörter
      'FUCK', 'SHIT', 'ASS', 'BITCH', 'DAMN', 'HELL',
      'CUNT', 'SLUT', 'WHORE', 'BASTARD', 'DICK',
      'PUSSY', 'COCK', 'TITS', 'BOOBS', 'NIGGER',
      'FAGGOT', 'RETARD', 'IDIOT', 'STUPID',
      // Sexuelle Begriffe
      'SEX', 'PORN', 'PENIS', 'VAGINA', 'ORGASM',
      'MASTURBAT', 'EROTIC', 'NAKED', 'NUDE',
      'HARDCORE', 'XXX', 'ADULT', 'EROTIC',
      // Weitere unangemessene Begriffe
      'RAPE', 'VIOLENCE', 'HATE', 'KILL',
    ];
    
    for (final word in inappropriateWords) {
      if (normalizedName.contains(word)) {
        return true;
      }
    }
    
    return false;
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    // Sanitize Email gegen Schadcode
    final email = sanitizeEmail(_emailController.text.trim());
    
    // Blockiere Registrierung mit Admin-Email
    if (_isAdminEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diese Email-Adresse kann nicht für die Registrierung verwendet werden.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prüfe auf blockierte Namen
    final name = sanitizeInput(_nameController.text.trim());
    if (_isNameBlocked(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dieser Name ist nicht erlaubt. Bitte wähle einen anderen Namen.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: sanitizeEmail(_emailController.text.trim()),
        password: _passwordController.text, // Passwort nicht sanitisieren - Sonderzeichen sind wichtig!
      );

      // Name im User-Profil speichern
      await credential.user?.updateDisplayName(_nameController.text.trim());
      await credential.user?.reload();

      // Login-Zähler und letzten Login beim ersten Login setzen
      if (credential.user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(credential.user!.uid)
              .set({
            'email': credential.user!.email,
            'displayName': credential.user!.displayName,
            'loginCount': 1,
            'lastLogin': Timestamp.now(),
          }, SetOptions(merge: true));
        } catch (e) {
          // Firestore-Update ist optional, Fehler ignorieren
          print('Firestore registration update fehlgeschlagen: $e');
        }
      }

      // Bestätigungs-Email senden
      await credential.user?.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registrierung erfolgreich! Bitte prüfe deine Emails für die Bestätigung.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.code)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib deine Email-Adresse ein.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: sanitizeEmail(_emailController.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwort-Reset-Email wurde gesendet!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Kein Account mit dieser Email gefunden.';
      case 'wrong-password':
        return 'Falsches Passwort.';
      case 'invalid-credential':
        return 'Ungültige Anmeldedaten. Bitte prüfe Email und Passwort. Für Admin-Login: Email muss info@dj-ollerganove.de sein und Passwort muss OG-1005-OG sein.';
      case 'email-already-in-use':
        return 'Diese Email ist bereits registriert.';
      case 'weak-password':
        return 'Passwort ist zu schwach (mindestens 6 Zeichen).';
      case 'invalid-email':
        return 'Ungültige Email-Adresse.';
      case 'operation-not-allowed':
        return 'Email/Passwort-Authentifizierung ist nicht aktiviert. Bitte aktiviere sie in der Firebase-Konsole unter Authentication → Sign-in method.';
      default:
        return 'Fehler: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                Image.asset(
                  'assets/logo.png',
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.music_note, size: 80);
                  },
                ),
                const SizedBox(height: 32),
            Text(
                  _isLogin ? 'Anmelden' : 'Registrieren',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Email Feld
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email fehlt';
                    }
                    if (!value.contains('@')) {
                      return 'Ungültige Email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Name Feld nur bei Registrierung
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Dein Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (!_isLogin && (value == null || value.trim().isEmpty)) {
                        return 'Name fehlt';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                // Passwort Feld
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Passwort',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: _isLogin
                        ? IconButton(
                            icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.help_outline, size: 20),
                                tooltip: 'Passwort-Anforderungen',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Passwort-Anforderungen'),
                                      content: const Text(
                                        'Das Passwort muss:\n'
                                        '• Mindestens 8 Zeichen lang sein\n'
                                        '• Mindestens einen Großbuchstaben enthalten\n'
                                        '• Mindestens eines der folgenden Sonderzeichen enthalten: - _ ! ( )',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                            ],
                          ),
                  ),
                  obscureText: _showPassword,
                  validator: _isLogin
                      ? (value) {
                          if (value == null || value.isEmpty) {
                            return 'Passwort fehlt';
                          }
                          return null;
                        }
                      : _validatePassword,
                ),
                // Passwort bestätigen (nur bei Registrierung)
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Passwort bestätigen',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _showConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte bestätige das Passwort.';
                      }
                      if (value != _passwordController.text) {
                        return 'Die Passwörter stimmen nicht überein.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 8),
                // Passwort vergessen und Passwort speichern (nur bei Login)
                if (_isLogin) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Checkbox(
                        value: _savePassword,
                        onChanged: (value) {
                          setState(() {
                            _savePassword = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text('Passwort speichern'),
                      ),
                      TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Passwort vergessen?'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Login/Registrieren Button
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : (_isLogin ? _signInWithEmail : _registerWithEmail),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isLogin ? 'Anmelden' : 'Registrieren'),
                ),
                const SizedBox(height: 16),
                // Wechsel zwischen Login und Registrierung
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Noch kein Account? Jetzt registrieren'
                        : 'Bereits registriert? Jetzt anmelden',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Home-Seite
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _loginCount = 0;
  DateTime? _previousLogin; // Vorheriger Login (nicht der aktuelle)
  int _totalWishes = 0; // Anzahl aller gesendeten Wünsche (für normale User)
  int _playedWishes = 0; // Anzahl der gespielten Wünsche (für normale User)
  // Admin-Statistiken
  int _totalWishesAdmin = 0; // Alle Wünsche insgesamt
  int _pendingWishesAdmin = 0; // Noch offene Wünsche
  int _playedWishesAdmin = 0; // Gespielte Wünsche
  int _rejectedWishesAdmin = 0; // Abgelehnte Wünsche
  int _deletedWishesAdmin = 0; // Gelöschte Wünsche (aus Firestore deleted_count)
  // Daten für Kreisdiagramm (ohne pending)
  int _chartPlayed = 0; // Gespielte für Diagramm
  int _chartRejected = 0; // Abgelehnte für Diagramm
  int _chartNotPlayed = 0; // Nicht gespielte (andere Status) für Diagramm
  int _chartDeleted = 0; // Gelöschte für Diagramm
  bool _wishboxManuallyEnabled = false; // Manueller Schalter für Wunschbox
  bool _hasActiveParty = false; // Ob eine aktive Party läuft
  bool _isLoading = true;
  // Aktive oder nächste bevorstehende Party für Admin-Anzeige
  Map<String, dynamic>? _currentOrNextParty;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  StreamSubscription<QuerySnapshot>? _partiesSubscription;
  StreamSubscription<DocumentSnapshot>? _partySettingsSubscription;
  Timer? _wishboxStatusTimer; // Timer für periodische Status-Updates

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    // Höre auf Auth-Änderungen, damit die Daten neu geladen werden
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        // Längeres Delay, damit Firestore-Update abgeschlossen ist
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _loadUserData();
            _setupUserDocListener();
            _setupPartiesListener();
            _setupWishboxStatusTimer();
          }
        });
      }
    });
    
    _setupUserDocListener();
    _setupPartiesListener();
    _setupWishboxStatusTimer();
  }

  void _setupWishboxStatusTimer() {
    // Timer entfernt - verwende jetzt Streams für Echtzeit-Updates
    _wishboxStatusTimer?.cancel();
    _wishboxStatusTimer = null;
  }

  void _setupPartiesListener() {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null && user.email == 'info@dj-ollerganove.de';
    
    _partiesSubscription?.cancel();
    
    if (isAdmin) {
      _partiesSubscription = FirebaseFirestore.instance
          .collection('parties')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _loadWishboxStatus();
        }
      });
      
      // Stream für party_settings
      _partySettingsSubscription = FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _loadWishboxStatus();
        }
      });
    } else {
      _partiesSubscription = null;
      _partySettingsSubscription = null;
    }
  }
  
  void _setupUserDocListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userDocSubscription?.cancel();
      print('Setup UserDocListener für UID: ${user.uid}');
      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        print('StreamListener: Snapshot empfangen. Exists: ${snapshot.exists}');
        if (mounted && snapshot.exists) {
          final data = snapshot.data();
          print('StreamListener: Daten: $data');
          setState(() {
            // Prüfe verschiedene mögliche Typen für loginCount
            final loginCountValue = data?['loginCount'];
            print('StreamListener: loginCountValue: $loginCountValue (Typ: ${loginCountValue.runtimeType})');
            if (loginCountValue is int) {
              _loginCount = loginCountValue;
            } else if (loginCountValue is num) {
              _loginCount = loginCountValue.toInt();
            } else {
              _loginCount = 0;
            }
            print('StreamListener: Gesetzter _loginCount: $_loginCount');
            
            // Prüfe previousLogin (vorheriger Login, nicht der aktuelle)
            final previousLoginValue = data?['previousLogin'];
            print('StreamListener: previousLoginValue: $previousLoginValue (Typ: ${previousLoginValue.runtimeType})');
            if (previousLoginValue is Timestamp) {
              _previousLogin = previousLoginValue.toDate();
            } else if (previousLoginValue != null) {
              try {
                _previousLogin = (previousLoginValue as Timestamp).toDate();
              } catch (e) {
                _previousLogin = null;
              }
            } else {
              _previousLogin = null;
            }
            print('StreamListener: Gesetzter _previousLogin: $_previousLogin');
            
            _isLoading = false;
          });
        } else if (mounted && !snapshot.exists) {
          print('StreamListener: Dokument existiert nicht');
        }
      }, onError: (error) {
        print('StreamListener Fehler: $error');
      });
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh entfernt - Streams aktualisieren automatisch
  }


  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    _partiesSubscription?.cancel();
    _wishboxStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        print('Lade User-Daten für UID: ${user.uid}');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          print('User-Dokument gefunden. Daten: $data');
          setState(() {
            // Prüfe verschiedene mögliche Typen für loginCount
            final loginCountValue = data?['loginCount'];
            print('loginCountValue aus Firestore: $loginCountValue (Typ: ${loginCountValue.runtimeType})');
            if (loginCountValue is int) {
              _loginCount = loginCountValue;
            } else if (loginCountValue is num) {
              _loginCount = loginCountValue.toInt();
            } else {
              _loginCount = 0;
            }
            print('Gesetzter _loginCount: $_loginCount');
            
            // Prüfe previousLogin (vorheriger Login, nicht der aktuelle)
            final previousLoginValue = data?['previousLogin'];
            print('previousLoginValue aus Firestore: $previousLoginValue (Typ: ${previousLoginValue.runtimeType})');
            if (previousLoginValue is Timestamp) {
              _previousLogin = previousLoginValue.toDate();
            } else if (previousLoginValue != null) {
              // Versuche zu konvertieren falls es ein anderes Format ist
              try {
                _previousLogin = (previousLoginValue as Timestamp).toDate();
              } catch (e) {
                _previousLogin = null;
              }
            } else {
              _previousLogin = null;
            }
            print('Gesetzter _previousLogin: $_previousLogin');
            
            _isLoading = false;
          });
          
          // Lade Wünsche-Statistiken
          final isAdmin = user.email == 'info@dj-ollerganove.de';
          if (isAdmin) {
            _loadAdminStatistics();
            _loadWishboxStatus();
          } else {
            _loadWishesStatistics();
          }
        } else {
          // Dokument existiert nicht - setze auf 0
          print('User-Dokument existiert nicht in Firestore');
          setState(() {
            _loginCount = 0;
            _previousLogin = null;
            _isLoading = false;
          });
          final isAdmin = user.email == 'info@dj-ollerganove.de';
          if (isAdmin) {
            _loadAdminStatistics();
            _loadWishboxStatus();
          } else {
            _loadWishesStatistics();
          }
        }
      } catch (e, stackTrace) {
        print('Fehler beim Laden der User-Daten: $e');
        print('Stack trace: $stackTrace');
        setState(() {
          _isLoading = false;
        });
        final isAdmin = user.email == 'info@dj-ollerganove.de';
        if (isAdmin) {
          _loadAdminStatistics();
        } else {
          _loadWishesStatistics();
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWishesStatistics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _totalWishes = 0;
        _playedWishes = 0;
      });
      return;
    }

    try {
      // Lade alle Wünsche des Users (nach aktuellem Namen)
      final currentName = user.displayName ?? user.email?.split('@')[0] ?? '';
      final wishesQuery = await FirebaseFirestore.instance
          .collection('wishes')
          .where('name', isEqualTo: currentName)
          .get();

      int total = 0;
      int played = 0;

      for (final doc in wishesQuery.docs) {
        final data = doc.data();
        total++;
        if (data['status'] == 'played') {
          played++;
        }
      }

      setState(() {
        _totalWishes = total;
        _playedWishes = played;
      });
    } catch (e) {
      print('Fehler beim Laden der Wünsche-Statistiken: $e');
      setState(() {
        _totalWishes = 0;
        _playedWishes = 0;
      });
    }
  }

  Future<void> _loadAdminStatistics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isAdmin = user.email == 'info@dj-ollerganove.de';
    if (!isAdmin) return;

    try {
      // Lade alle Wünsche (ohne Filter)
      final wishesQuery = await FirebaseFirestore.instance
          .collection('wishes')
          .get();

      int total = 0;
      int pending = 0;
      int played = 0;
      int rejected = 0;
      int notPlayed = 0; // Für Diagramm: Wünsche mit anderen Status (außer pending, played, rejected)

      for (final doc in wishesQuery.docs) {
        final data = doc.data();
        total++;
        final status = data['status'] as String?;
        if (status == 'played') {
          played++;
        } else if (status == 'rejected') {
          rejected++;
        } else if (status == 'pending' || status == null) {
          pending++;
        } else {
          // Alle anderen Status (z.B. 'not_played', 'skipped' oder andere) zählen als "nicht gespielt"
          notPlayed++;
        }
      }
      
      // Debug-Ausgabe um zu sehen, welche Status-Werte existieren
      print('=== Status-Verteilung ===');
      print('Total: $total');
      print('Pending: $pending');
      print('Played: $played');
      print('Rejected: $rejected');
      print('Not Played (andere Status): $notPlayed');

      // Lade deleted_count aus Firestore (falls vorhanden)
      int deletedCount = 0;
      try {
        final statsDoc = await FirebaseFirestore.instance
            .collection('admin_stats')
            .doc('wishes')
            .get();
        if (statsDoc.exists) {
          final data = statsDoc.data();
          deletedCount = data?['deleted_count'] as int? ?? 0;
        }
      } catch (e) {
        print('Fehler beim Laden der deleted_count: $e');
      }

      // Für Diagramm:
      // "Nicht gespielt" = alle bearbeiteten Wünsche (nicht pending), die nicht gespielt oder abgelehnt sind.
      // Deleted werden separat gezählt (kommen nicht mehr in der Collection vor).
      final chartNotPlayed = total - pending - played - rejected;
      final clampedNotPlayed = chartNotPlayed > 0 ? chartNotPlayed : 0;

      // Für Diagramm: Gelöschte separat behandeln
      setState(() {
        _totalWishesAdmin = total;
        _pendingWishesAdmin = pending;
        _playedWishesAdmin = played;
        _rejectedWishesAdmin = rejected;
        _deletedWishesAdmin = deletedCount;
        // Diagramm-Daten (ohne pending)
        _chartPlayed = played;
        _chartRejected = rejected;
        _chartNotPlayed = clampedNotPlayed;
        _chartDeleted = deletedCount;
      });
      
      print('=== Diagramm-Daten ===');
      print('Total Wünsche (ohne gelöschte): $total');
      print('Pending (OFFEN - nicht im Diagramm): $pending');
      print('Gespielt (GRÜN): $_chartPlayed');
      print('Abgelehnt (ROT): $_chartRejected');
      print('Nicht gespielt (BLAU): $_chartNotPlayed');
      print('Gelöscht (SCHWARZ): $_chartDeleted');
      print('Summe im Diagramm: ${_chartPlayed + _chartRejected + _chartNotPlayed + _chartDeleted}');
    } catch (e) {
      print('Fehler beim Laden der Admin-Statistiken: $e');
      setState(() {
        _totalWishesAdmin = 0;
        _pendingWishesAdmin = 0;
        _playedWishesAdmin = 0;
        _rejectedWishesAdmin = 0;
        _deletedWishesAdmin = 0;
        // Diagramm-Daten zurücksetzen
        _chartPlayed = 0;
        _chartRejected = 0;
        _chartNotPlayed = 0;
        _chartDeleted = 0;
      });
    }
  }

  Future<void> _loadWishboxStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isAdmin = user.email == 'info@dj-ollerganove.de';
    if (!isAdmin) return;

    try {
      // Lade manuellen Schalter-Status
      final doc = await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .get();
      
      bool manuallyEnabled = false;
      if (doc.exists) {
        final data = doc.data()!;
        manuallyEnabled = data['wishbox_manually_enabled'] as bool? ?? false;
      }

      // Prüfe, ob eine aktive Party läuft
      final now = DateTime.now();
      // Lade nur Partys, die nicht älter als 7 Tage sind (für Performance)
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      print('=== _loadWishboxStatus: Prüfe aktive Partys ===');
      print('Aktuelle Zeit: $now');
      print('Lade nur Partys mit end_date >= $sevenDaysAgo');
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('end_date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();
      
      print('Gefundene Partys: ${partiesQuery.docs.length}');
      bool hasActiveParty = false;
      for (final partyDoc in partiesQuery.docs) {
        final data = partyDoc.data();
        final partyName = data['party_name'] as String? ?? 'Unbenannte Party';
        final startTimestamp = data['start_date'] as Timestamp?;
        final endTimestamp = data['end_date'] as Timestamp?;
        
        print('\n--- Party: $partyName ---');
        if (startTimestamp != null && endTimestamp != null) {
          final startDate = startTimestamp.toDate();
          final endDate = endTimestamp.toDate();
          
          print('Start: $startDate');
          print('Ende: $endDate');
          print('Vergleich Start: ${now.compareTo(startDate)} (>= 0: ${now.compareTo(startDate) >= 0})');
          print('Vergleich Ende: ${now.compareTo(endDate)} (< 0: ${now.compareTo(endDate) < 0})');
          
          // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende (Endzeit ist exklusiv)
          if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
            print('✓ Party ist AKTIV!');
            hasActiveParty = true;
            break;
          } else {
            print('✗ Party ist nicht aktiv');
          }
        } else {
          print('FEHLER: Start oder End Timestamp fehlt!');
        }
      }
      print('hasActiveParty: $hasActiveParty');

      // Wenn eine Party läuft, setze wishbox_manually_enabled standardmäßig auf true
      // (es sei denn, es wurde explizit auf false gesetzt)
      if (hasActiveParty) {
        print('Party ist aktiv, prüfe manuellen Schalter...');
        if (!doc.exists) {
          // Dokument existiert nicht, setze es auf true
          print('Dokument existiert nicht, setze wishbox_manually_enabled auf true');
          await FirebaseFirestore.instance
              .collection('party_settings')
              .doc('current')
              .set({
            'wishbox_manually_enabled': true,
          }, SetOptions(merge: true));
          manuallyEnabled = true;
        } else {
          // Dokument existiert, prüfe ob es explizit auf false gesetzt wurde
          final data = doc.data()!;
          final currentValue = data['wishbox_manually_enabled'];
          print('Aktueller Wert von wishbox_manually_enabled: $currentValue');
          // Wenn eine Party aktiv ist, setze wishbox_manually_enabled auf true
          // (es sei denn, es wurde gerade vom Admin auf false gesetzt)
          // Für jetzt: Wenn Party aktiv ist, setze es immer auf true beim Laden
          // Der Admin kann es dann auf false setzen, wenn er will
          if (currentValue != true) {
            print('Setze wishbox_manually_enabled auf true (Party ist aktiv)');
            await FirebaseFirestore.instance
                .collection('party_settings')
                .doc('current')
                .set({
              'wishbox_manually_enabled': true,
            }, SetOptions(merge: true));
          }
          manuallyEnabled = true;
          print('manuallyEnabled gesetzt auf: $manuallyEnabled (Party ist aktiv)');
        }
        print('manuallyEnabled nach Party-Prüfung: $manuallyEnabled');
      } else {
        // Keine aktive Party läuft
        // Respektiere den manuell gesetzten Wert - überschreibe ihn nicht
        // Wenn das Dokument nicht existiert, setze es auf false
        if (!doc.exists) {
          manuallyEnabled = false;
        }
        // Wenn doc.exists ist, behalte den aktuellen Wert (manuallyEnabled wurde bereits aus doc gelesen)
      }

      // Finde aktive oder nächste bevorstehende Party für Anzeige
      await _loadCurrentOrNextParty();

      setState(() {
        _wishboxManuallyEnabled = manuallyEnabled;
        _hasActiveParty = hasActiveParty;
      });
    } catch (e) {
      print('Fehler beim Laden des Wunschbox-Status: $e');
    }
  }

  // Lädt die aktive Party oder die nächste bevorstehende Party
  Future<void> _loadCurrentOrNextParty() async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('end_date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();
      
      Map<String, dynamic>? activeParty;
      Map<String, dynamic>? nextUpcomingParty;
      DateTime? nextUpcomingStart;
      
      for (final partyDoc in partiesQuery.docs) {
        final data = partyDoc.data();
        final startTimestamp = data['start_date'] as Timestamp?;
        final endTimestamp = data['end_date'] as Timestamp?;
        
        if (startTimestamp != null && endTimestamp != null) {
          final startDate = startTimestamp.toDate();
          final endDate = endTimestamp.toDate();
          
          // Prüfe ob Party aktiv ist
          if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
            activeParty = {
              'id': partyDoc.id,
              'party_name': data['party_name'] as String? ?? 'Unbenannte Party',
              'start_date': startDate,
              'end_date': endDate,
              'party_code': data['party_code'] as String?,
            };
            break; // Aktive Party hat Priorität
          }
          
          // Prüfe ob Party bevorstehend ist
          if (now.compareTo(startDate) < 0) {
            if (nextUpcomingParty == null || startDate.isBefore(nextUpcomingStart!)) {
              nextUpcomingStart = startDate;
              nextUpcomingParty = {
                'id': partyDoc.id,
                'party_name': data['party_name'] as String? ?? 'Unbenannte Party',
                'start_date': startDate,
                'end_date': endDate,
                'party_code': data['party_code'] as String?,
              };
            }
          }
        }
      }
      
      setState(() {
        _currentOrNextParty = activeParty ?? nextUpcomingParty;
      });
    } catch (e) {
      print('Fehler beim Laden der aktuellen/nächsten Party: $e');
      setState(() {
        _currentOrNextParty = null;
      });
    }
  }

  // Prüft ob eine Party aktiv ist
  bool _isPartyActive(Map<String, dynamic> party) {
    final now = DateTime.now();
    final startDate = party['start_date'] as DateTime;
    final endDate = party['end_date'] as DateTime;
    return now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0;
  }

  // Formatiert DateTime für Bild (kompakt)
  String _formatDateTimeForImage(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }

  // Formatiert DateTime für Anzeige
  String _formatDateTimeForDisplay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year um $hour:$minute Uhr';
  }

  // Formatiert Datum für Party Extra Dialog
  String _formatDateForPartyExtra(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day.$month.$year';
  }

  // Formatiert Uhrzeit für Party Extra Dialog
  String _formatTimeForPartyExtra(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute Uhr';
  }

  // Speichert QR-Code mit Party-Code als Bild
  Future<void> _saveQRCodeAsImage(
    BuildContext context,
    String pwaUrl,
    String partyCode,
    String partyName,
    DateTime startDate,
  ) async {
    try {
      // Erstelle ein Bild mit QR-Code und Party-Code
      const qrSize = 500.0;
      const padding = 40.0;
      const textHeight = 60.0;
      const titleHeight = 80.0;
      const dateHeight = 50.0;
      const spacing = 20.0;
      const totalHeight = titleHeight + spacing + dateHeight + spacing + qrSize + spacing + textHeight;
      const totalWidth = qrSize + (padding * 2);

      // Erstelle ein PictureRecorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Weißer Hintergrund
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, totalWidth, totalHeight),
        whitePaint,
      );

      double currentY = padding;

      // Zeichne Party-Titel über dem QR-Code
      final titleStyle = TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      );
      final titleSpan = TextSpan(
        text: partyName,
        style: titleStyle,
      );
      final titlePainter = TextPainter(
        text: titleSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      );
      titlePainter.layout(maxWidth: qrSize);
      final titleX = (totalWidth - titlePainter.width) / 2;
      titlePainter.paint(canvas, Offset(titleX, currentY));
      currentY += titlePainter.height + spacing;

      // Zeichne Party-Datum
      final dateText = _formatDateTimeForImage(startDate);
      final dateStyle = TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      );
      final dateSpan = TextSpan(
        text: dateText,
        style: dateStyle,
      );
      final datePainter = TextPainter(
        text: dateSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      datePainter.layout(maxWidth: qrSize);
      final dateX = (totalWidth - datePainter.width) / 2;
      datePainter.paint(canvas, Offset(dateX, currentY));
      currentY += datePainter.height + spacing;

      // Zeichne QR-Code
      final qrPainter = QrPainter(
        data: pwaUrl,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      
      // Verschiebe Canvas für QR-Code (zentriert)
      canvas.save();
      canvas.translate(padding, currentY);
      qrPainter.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
      currentY += qrSize + spacing;

      // Zeichne Party-Code Text unter dem QR-Code
      final textStyle = TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 4,
        color: Colors.black,
      );
      final textSpan = TextSpan(
        text: partyCode,
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Zentriere den Text
      final textX = (totalWidth - textPainter.width) / 2;
      textPainter.paint(canvas, Offset(textX, currentY));

      // Konvertiere zu Bild
      final picture = recorder.endRecording();
      final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Speichere das Bild direkt in der Galerie
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: 'QR_Code_$partyCode',
      );

      if (context.mounted) {
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR-Code wurde in der Galerie gespeichert'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler beim Speichern in der Galerie'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Fehler beim Speichern des QR-Codes: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Zeigt QR-Code-Dialog für Party
  void _showPartyQRCodeDialog(
    BuildContext context,
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String? partyCode,
  ) {
    if (partyCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kein Party-Code verfügbar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    partyName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                            Text(
                              'Beginn: ${_formatDateForPartyExtra(startDate)} - ${_formatTimeForPartyExtra(startDate)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Ende: ${_formatDateForPartyExtra(endDate)} - ${_formatTimeForPartyExtra(endDate)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.left,
                        ),
                          ],
                      ),
                    ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: pwaUrl,
                          version: QrVersions.auto,
                          size: 250,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          partyCode,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Buttons nebeneinander
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 3-tlg Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _generatePartyPDFForHomePage(
                              partyName,
                              startDate,
                              endDate,
                              partyCode,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                '3-tlg',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Einzel Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _generateSinglePartyPDFForHomePage(
                              partyName,
                              startDate,
                              endDate,
                              partyCode,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                'Einzel',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // QR-Code speichern Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _saveQRCodeAsImage(context, pwaUrl, partyCode, partyName, startDate);
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
                              const Icon(Icons.image, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                'Speichern',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Erstellt eine Spalte für die Party-Informationen (für HomePage)
  pw.Widget _buildPartyColumnForHomePage(
    String partyName,
    DateTime startDate,
    String pwaUrl,
    String partyCode,
    pw.ImageProvider? logoImage,
    pw.ImageProvider? djWbLogoImage,
  ) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          // Überschrift oben in jeder Spalte
          pw.Text(
            'Hier kannst Du dem DJ Deine Musikwünsche mitteilen',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 16),
          // Partyname
          pw.Text(
            partyName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 12),
          // Beginndatum
          pw.Text(
            _formatDateTimeForPDF(startDate),
            style: const pw.TextStyle(fontSize: 12),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 20),
          // QR-Code
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: pwaUrl,
            width: 180,
            height: 180,
          ),
          pw.SizedBox(height: 12),
          // Code unter dem QR-Code (kleiner)
          pw.Text(
            partyCode,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 3,
            ),
            textAlign: pw.TextAlign.center,
          ),
          // Logo (falls vorhanden)
          if (logoImage != null) ...[
            pw.SizedBox(height: 16),
            pw.Image(logoImage, width: 180, fit: pw.BoxFit.contain),
          ],
          // Website-Adresse
          pw.SizedBox(height: 8),
          pw.Text(
            'www.dj-ollerganove.de',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
          // Fußzeile mit DJ-WB Logo und Text
          pw.Spacer(),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (djWbLogoImage != null) ...[
                pw.Image(djWbLogoImage, width: 40, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 8),
              ],
              pw.Text(
                'a creation by DJ Ollerganove',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Generiert PDF für Party (für HomePage)
  Future<void> _generatePartyPDFForHomePage(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode,
  ) async {
    try {
      final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
      
      // Lade Logo (logo.png für oben)
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logo.png');
        final logoUint8List = logoBytes.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoUint8List);
        print('✅ logo.png Logo erfolgreich geladen');
      } catch (e) {
        print('❌ Fehler beim Laden des logo.png Logos: $e');
        // Kein Fallback - Logo bleibt null wenn es nicht geladen werden kann
      }
      
      // Lade DJ-WB.png Logo für die Fußzeile
      pw.ImageProvider? djWbLogoImage;
      try {
        final djWbLogoBytes = await rootBundle.load('assets/DJ-WB.png');
        final djWbLogoUint8List = djWbLogoBytes.buffer.asUint8List();
        djWbLogoImage = pw.MemoryImage(djWbLogoUint8List);
        print('✅ DJ-WB.png Logo erfolgreich geladen');
      } catch (e) {
        print('❌ Fehler beim Laden des DJ-WB.png Logos: $e');
      }
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Spalte 1
                _buildPartyColumnForHomePage(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
                // Spalte 2
                _buildPartyColumnForHomePage(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
                // Spalte 3
                _buildPartyColumnForHomePage(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
              ],
            );
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Generiert eine einzelne Spalte PDF im Hochformat
  Future<void> _generateSinglePartyPDFForHomePage(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode,
  ) async {
    try {
      final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
      
      // Lade Logo (logo.png für oben)
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logo.png');
        final logoUint8List = logoBytes.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoUint8List);
      } catch (e) {
        print('❌ Fehler beim Laden des logo.png Logos: $e');
      }
      
      // Lade DJ-WB.png Logo für die Fußzeile
      pw.ImageProvider? djWbLogoImage;
      try {
        final djWbLogoBytes = await rootBundle.load('assets/DJ-WB.png');
        final djWbLogoUint8List = djWbLogoBytes.buffer.asUint8List();
        djWbLogoImage = pw.MemoryImage(djWbLogoUint8List);
      } catch (e) {
        print('❌ Fehler beim Laden des DJ-WB.png Logos: $e');
      }
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return _buildPartyColumnForHomePage(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage);
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Formatiert DateTime für PDF
  String _formatDateTimeForPDF(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }

  Future<void> _toggleWishbox(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isAdmin = user.email == 'info@dj-ollerganove.de';
    if (!isAdmin) return;

    try {
      await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .set({
        'wishbox_manually_enabled': enabled,
      }, SetOptions(merge: true));

      setState(() {
        _wishboxManuallyEnabled = enabled;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled 
                ? 'Wunschbox wurde manuell aktiviert.' 
                : 'Wunschbox wurde manuell deaktiviert.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Ändern des Status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Guten Morgen';
    } else if (hour >= 12 && hour < 17) {
      return 'Guten Tag';
    } else if (hour >= 17 && hour < 22) {
      return 'Guten Abend';
    } else {
      return 'Schöne Nacht';
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Noch nie';
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year um $hour:$minute Uhr';
  }

  // Erstellt das Kreisdiagramm
  Widget _buildPieChart() {
    final total = _chartPlayed + _chartRejected + _chartNotPlayed + _chartDeleted;
    if (total == 0) {
      return const Center(
        child: Text('Keine Daten verfügbar'),
      );
    }

    final playedPercent = (_chartPlayed / total * 100);
    final rejectedPercent = (_chartRejected / total * 100);
    final notPlayedPercent = (_chartNotPlayed / total * 100);
    final deletedPercent = (_chartDeleted / total * 100);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        startDegreeOffset: 270, // startet unten
        sections: [
          // Gelöschte (Schwarz) immer zuerst, damit sie unten sind
          if (_chartDeleted > 0)
            PieChartSectionData(
              value: _chartDeleted.toDouble(),
              title: '${deletedPercent.toStringAsFixed(1)}%',
              color: Colors.black,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          // Gespielte (Grün)
          if (_chartPlayed > 0)
            PieChartSectionData(
              value: _chartPlayed.toDouble(),
              title: '${playedPercent.toStringAsFixed(1)}%',
              color: Colors.green,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          // Abgelehnte (Rot)
          if (_chartRejected > 0)
            PieChartSectionData(
              value: _chartRejected.toDouble(),
              title: '${rejectedPercent.toStringAsFixed(1)}%',
              color: Colors.red,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          // Nicht gespielt (Blau)
          if (_chartNotPlayed > 0)
            PieChartSectionData(
              value: _chartNotPlayed.toDouble(),
              title: '${notPlayedPercent.toStringAsFixed(1)}%',
              color: Colors.blue,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // Erstellt die Legende für das Diagramm
  Widget _buildChartLegend() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_chartPlayed > 0) ...[
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gespielt\n($_chartPlayed)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_chartRejected > 0) ...[
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Abgelehnt\n($_chartRejected)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_chartNotPlayed > 0) ...[
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nicht gespielt\n($_chartNotPlayed)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_chartDeleted > 0) ...[
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gelöscht\n($_chartDeleted)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null && (user.email == 'info@dj-ollerganove.de');

    if (_isLoading) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Begrüßung - Separates Fenster
              if (user != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()} ${user.displayName ?? user.email?.split('@')[0] ?? 'User'}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Schön Dich wieder zu sehen.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Willkommen bei den Musikwünschen!',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Aktive oder nächste bevorstehende Party - Zwischen Begrüßung und Statistik
              if (isAdmin && _currentOrNextParty != null) ...[
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isPartyActive(_currentOrNextParty!)
                                        ? 'Deine aktuell laufende Party'
                                        : 'Deine nächste geplante Party',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentOrNextParty!['party_name'] as String,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code),
                              onPressed: () {
                                final startDate = _currentOrNextParty!['start_date'] as DateTime;
                                final endDate = _currentOrNextParty!['end_date'] as DateTime;
                                final partyCode = _currentOrNextParty!['party_code'] as String?;
                                _showPartyQRCodeDialog(
                                  context,
                                  _currentOrNextParty!['party_name'] as String,
                                  startDate,
                                  endDate,
                                  partyCode,
                                );
                              },
                              tooltip: 'QR-Code anzeigen',
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Start: ${_formatDateTimeForDisplay(_currentOrNextParty!['start_date'] as DateTime)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Statistik-Karten - Nach der nächsten Party
              if (user != null) ...[
                // Login-Statistiken für normale User
                if (!isAdmin && (_loginCount > 0 || _previousLogin != null || _totalWishes > 0)) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deine Statistiken',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          if (_loginCount > 0)
                            Row(
                              children: [
                                Icon(Icons.login, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Du hast Dich schon $_loginCount mal eingeloggt.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          if (_loginCount > 0 && _previousLogin != null) const SizedBox(height: 12),
                          if (_previousLogin != null)
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dein letzter Login war am ${_formatDateTime(_previousLogin)}.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          if (_totalWishes > 0) ...[
                            if (_loginCount > 0 || _previousLogin != null) const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.music_note, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Du hast bis jetzt $_totalWishes ${_totalWishes == 1 ? 'Musikwunsch' : 'Musikwünsche'} geschickt.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            if (_playedWishes > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.check_circle, size: 20, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$_playedWishes ${_playedWishes == 1 ? 'Lied wurde' : 'Lieder wurden'} davon gespielt.',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Admin-Statistiken
                if (isAdmin && _totalWishesAdmin > 0) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Statistiken',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.music_note, size: 20, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Es sind bisher $_totalWishesAdmin ${_totalWishesAdmin == 1 ? 'Musikwunsch' : 'Musikwünsche'} eingegangen.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          if (_pendingWishesAdmin > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_pendingWishesAdmin ${_pendingWishesAdmin == 1 ? 'Wunsch ist' : 'Wünsche sind'} noch offen.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_playedWishesAdmin > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 20, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_playedWishesAdmin ${_playedWishesAdmin == 1 ? 'Wunsch wurde' : 'Wünsche wurden'} davon gespielt.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_rejectedWishesAdmin > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.cancel, size: 20, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_rejectedWishesAdmin ${_rejectedWishesAdmin == 1 ? 'Wunsch wurde' : 'Wünsche wurden'} davon abgelehnt.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_chartNotPlayed > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.music_off, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_chartNotPlayed ${_chartNotPlayed == 1 ? 'Wunsch wurde' : 'Wünsche wurden'} nicht gespielt.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_deletedWishesAdmin > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.black),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_deletedWishesAdmin ${_deletedWishesAdmin == 1 ? 'Wunsch wurde' : 'Wünsche wurden'} komplett gelöscht.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Kreisdiagramm (nur wenn es Daten gibt, die nicht pending sind)
                          if ((_chartPlayed + _chartRejected + _chartNotPlayed) > 0) ...[
                            const SizedBox(height: 24),
                            Divider(),
                            const SizedBox(height: 16),
                            Text(
                              'Verteilung der bearbeiteten Wünsche',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: Row(
                                children: [
                                  // Kreisdiagramm
                                  Expanded(
                                    flex: 2,
                                    child: _buildPieChart(),
                                  ),
                                  const SizedBox(width: 16),
                                  // Legende
                                  Expanded(
                                    flex: 1,
                                    child: _buildChartLegend(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Schieberegler für manuelle Aktivierung/Deaktivierung
                          const SizedBox(height: 16),
                          Divider(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.toggle_on, size: 20, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _hasActiveParty
                                      ? (_wishboxManuallyEnabled
                                          ? 'Wunschbox in der laufenden Party deaktivieren'
                                          : 'Wunschbox bei der laufenden Party einschalten')
                                      : 'Wunschbox manuell aktivieren',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Switch(
                                value: _wishboxManuallyEnabled,
                                onChanged: _toggleWishbox,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hasActiveParty
                                ? (_wishboxManuallyEnabled
                                    ? 'Die Wunschbox ist während der laufenden Party aktiviert.'
                                    : 'Die Wunschbox ist während der laufenden Party deaktiviert.')
                                : (_wishboxManuallyEnabled
                                    ? 'Die Wunschbox ist manuell aktiviert und funktioniert unabhängig von der Party-Zeit.'
                                    : 'Die Wunschbox ist nur während der Party-Zeit aktiv (falls eine Party angelegt wurde).'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
              // Info-Fenster für nicht eingeloggte User
              if (user == null) ...[
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Als angemeldeter User kannst du mehr nutzen:',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Deine abgegebenen Musikwünsche jederzeit einsehen',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.blue.shade900,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Dein Profil verwalten und bearbeiten',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.blue.shade900,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Statistiken zu deinen Musikwünschen sehen',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.blue.shade900,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: Colors.blue.shade300),
                              const SizedBox(height: 8),
                              Text(
                                'Als Gast verfügbar:',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.music_note, size: 16, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Musikwünsche abschicken',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.blue.shade900,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.contact_mail, size: 16, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Kontaktformular nutzen',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.blue.shade900,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.share, size: 16, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Social Media Links aufrufen',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.blue.shade900,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Hinweis für normale User (nicht Admin)
              if (user != null && !isAdmin) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Im Navigationsmenü kannst du:',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• Eine Wunschbox sehen',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Dein Profil einsehen und bearbeiten',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Deine abgegebenen Musikwünsche sehen',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Das Kontaktformular nutzen',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Social Media Links aufrufen',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WishesPage extends StatefulWidget {
  const WishesPage({super.key});

  @override
  State<WishesPage> createState() => _WishesPageState();
}

class _WishesPageState extends State<WishesPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _greetingController = TextEditingController();
  bool _isAdmin = false;
  String? _guestName; // Name des aktuellen Gastes
  bool _isLoading = true; // Lade-Status für gespeicherte Werte
  bool _isWishboxActive = false; // Status der Wunschbox
  bool _showSuccessMessage = false; // Zeige Erfolgsmeldung anstelle des Formulars
  String? _partyCode; // Gespeicherter Party-Code
  Map<String, dynamic>? _currentOrNextParty; // Aktive oder nächste Party
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _partiesSubscription;
  StreamSubscription<DocumentSnapshot>? _partySettingsSubscription;
  Timer? _wishboxStatusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedData();
    _loadCurrentOrNextParty(); // Lade aktuelle/nächste Party
    
    // Höre auf Auth-Änderungen, damit die Seite neu gebaut wird
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _loadSavedData(); // Lade Daten neu, wenn sich Auth-Status ändert
        _loadCurrentOrNextParty(); // Lade auch Party neu
      }
    });

    // Timer entfernt - verwende jetzt Streams für Echtzeit-Updates
    _wishboxStatusTimer = null;

    // Höre auf Änderungen in der parties Collection
    _partiesSubscription = FirebaseFirestore.instance
        .collection('parties')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        print('Partys-Collection hat sich geändert, prüfe Wunschbox-Status...');
        _checkWishboxStatus();
        _loadCurrentOrNextParty(); // Lade Party neu wenn sich Collection ändert
      }
    });

    // Höre auf Änderungen in party_settings/current (für manuellen Schalter)
    _partySettingsSubscription = FirebaseFirestore.instance
        .collection('party_settings')
        .doc('current')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        print('party_settings/current hat sich geändert, prüfe Wunschbox-Status...');
        _checkWishboxStatus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh entfernt - Streams aktualisieren automatisch
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _partiesSubscription?.cancel();
    _partySettingsSubscription?.cancel();
    _wishboxStatusTimer?.cancel();
    _nameController.dispose();
    _titleController.dispose();
    _artistController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  Future<void> _checkWishboxStatus() async {
    final wishboxActive = await _checkWishboxActiveStatus();
    if (mounted && _isWishboxActive != wishboxActive) {
      setState(() {
        _isWishboxActive = wishboxActive;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Lifecycle-Observer bleibt für zukünftige Erweiterungen
    // Der Name wird jetzt beim App-Start in _loadSavedData gelöscht, wenn User nicht eingeloggt ist
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    // Lade gespeicherten Party-Code
    final savedPartyCode = prefs.getString('party_code');
    
    // Prüfe Wunschbox-Status
    final wishboxActive = await _checkWishboxActiveStatus();
    
    setState(() {
      // Admin-Status basierend auf Email setzen
      _isAdmin = user != null ? _isAdminEmail(user.email) : false;
      
      // Wenn User eingeloggt ist, verwende seinen Namen
      if (user != null) {
        _guestName = user.displayName ?? user.email?.split('@')[0] ?? 'Gast';
        _nameController.text = _guestName!;
      } else {
        // User ist nicht eingeloggt - lösche den Namen beim App-Start
        // (initState wird nur beim App-Start aufgerufen, nicht beim Minimieren)
        _clearGuestName();
        _guestName = null;
        _nameController.clear();
      }
      _partyCode = savedPartyCode;
      _isWishboxActive = wishboxActive;
      _isLoading = false;
    });
  }
  
  void _checkAdminStatus() {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null ? _isAdminEmail(user.email) : false;
    if (_isAdmin != isAdmin) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _saveAdminStatus(bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAdmin', isAdmin);
  }

  Future<void> _saveGuestName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guestName', name);
  }

  Future<void> _clearGuestName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guestName');
  }

  // Lädt die aktive Party oder die nächste bevorstehende Party (wie in HomePage)
  Future<void> _loadCurrentOrNextParty() async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('end_date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();
      
      Map<String, dynamic>? activeParty;
      Map<String, dynamic>? nextUpcomingParty;
      DateTime? nextUpcomingStart;
      
      for (final partyDoc in partiesQuery.docs) {
        final data = partyDoc.data();
        final startTimestamp = data['start_date'] as Timestamp?;
        final endTimestamp = data['end_date'] as Timestamp?;
        
        if (startTimestamp != null && endTimestamp != null) {
          final startDate = startTimestamp.toDate();
          final endDate = endTimestamp.toDate();
          
          // Prüfe ob Party aktiv ist
          if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
            activeParty = {
              'id': partyDoc.id,
              'party_name': data['party_name'] as String? ?? 'Unbenannte Party',
              'start_date': startDate,
              'end_date': endDate,
              'party_code': data['party_code'] as String?,
            };
            break; // Aktive Party hat Priorität
          }
          
          // Prüfe ob Party bevorstehend ist
          if (now.compareTo(startDate) < 0) {
            if (nextUpcomingParty == null || startDate.isBefore(nextUpcomingStart!)) {
              nextUpcomingStart = startDate;
              nextUpcomingParty = {
                'id': partyDoc.id,
                'party_name': data['party_name'] as String? ?? 'Unbenannte Party',
                'start_date': startDate,
                'end_date': endDate,
                'party_code': data['party_code'] as String?,
              };
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _currentOrNextParty = activeParty ?? nextUpcomingParty;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der aktuellen/nächsten Party in WishesPage: $e');
      if (mounted) {
        setState(() {
          _currentOrNextParty = null;
        });
      }
    }
  }

  Future<bool> _checkWishboxActiveStatus() async {
    try {
      print('=== Wunschbox-Aktivitätsprüfung gestartet ===');
      
      final now = DateTime.now();
      print('Aktuelle Zeit: $now');
      
      // Prüfe ZUERST, ob eine Party-Zeit aktiv ist
      // Wenn eine Party aktiv ist, ist die Wunschbox IMMER aktiv (unabhängig vom manuellen Schalter)
      // Lade nur Partys, die nicht älter als 7 Tage sind (für Performance)
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('end_date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();
      
      print('Gefundene Partys in Collection: ${partiesQuery.docs.length}');
      
      if (partiesQuery.docs.isNotEmpty) {
        for (final doc in partiesQuery.docs) {
          final data = doc.data();
          final partyName = data['party_name'] as String? ?? 'Unbenannte Party';
          final startTimestamp = data['start_date'] as Timestamp?;
          final endTimestamp = data['end_date'] as Timestamp?;
          
          print('\n--- Party: $partyName ---');
          print('Start Timestamp: $startTimestamp');
          print('End Timestamp: $endTimestamp');
          
          if (startTimestamp == null || endTimestamp == null) {
            print('FEHLER: Start oder End Timestamp fehlt!');
            continue;
          }
          
          final startDate = startTimestamp.toDate();
          final endDate = endTimestamp.toDate();
          
          print('Start Datum: $startDate');
          print('Ende Datum: $endDate');
          
          // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende (Endzeit ist exklusiv)
          final isAfterOrEqualStart = now.compareTo(startDate) >= 0;
          final isBeforeEnd = now.compareTo(endDate) < 0;
          
          print('Jetzt >= Start: $isAfterOrEqualStart (Vergleich: ${now.compareTo(startDate)})');
          print('Jetzt < Ende: $isBeforeEnd (Vergleich: ${now.compareTo(endDate)})');
          
          if (isAfterOrEqualStart && isBeforeEnd) {
            print('✓✓✓ PARTY IST AKTIV! Wunschbox wird aktiviert (unabhängig vom manuellen Schalter) ✓✓✓');
            return true;
          } else {
            print('✗ Party ist nicht aktiv');
          }
        }
      }
      
      print('=== Keine aktive Party gefunden, prüfe manuellen Schalter ===');
      
      // Wenn keine Party aktiv ist, prüfe den manuellen Schalter
      final settingsDoc = await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .get();
      
      if (settingsDoc.exists) {
        final settingsData = settingsDoc.data()!;
        final manuallyEnabled = settingsData['wishbox_manually_enabled'];
        print('Manueller Schalter Wert: $manuallyEnabled (Typ: ${manuallyEnabled.runtimeType})');
        
        // Wenn explizit auf true gesetzt, ist Wunschbox aktiv
        if (manuallyEnabled == true) {
          print('Wunschbox ist manuell aktiviert!');
          return true;
        }
        
        // Wenn explizit auf false gesetzt oder null, ist Wunschbox inaktiv
        print('Wunschbox ist manuell deaktiviert oder nicht gesetzt.');
        return false;
      } else {
        print('party_settings/current existiert nicht, Wunschbox ist inaktiv.');
        return false;
      }
    } catch (e, stackTrace) {
      print('FEHLER beim Prüfen der Wunschbox-Aktivität: $e');
      print('Stack Trace: $stackTrace');
      return false;
    }
  }


  // Hilfsfunktion zur Normalisierung von Text (für bessere Duplikaterkennung)
  String _normalizeText(String text) {
    if (text.isEmpty) return '';
    
    // Normalisiere häufige Variationen
    String normalized = text.toLowerCase().trim();
    
    // Ersetze häufige Variationen von Artikeln und Präpositionen
    normalized = normalized.replaceAll(RegExp(r'\bvom\b'), 'von');
    normalized = normalized.replaceAll(RegExp(r'\bder\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bdem\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bden\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bdes\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bdas\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bdie\b'), '');
    
    // Normalisiere häufige Tippfehler/Variationen
    normalized = normalized.replaceAll(RegExp(r'\bmodell\b'), 'modul');
    normalized = normalized.replaceAll(RegExp(r'\bmodul\b'), 'modul');
    
    // Entferne doppelte Leerzeichen
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Entferne Sonderzeichen für Vergleich (behalte aber Umlaute)
    normalized = normalized.replaceAll(RegExp(r'[^\w\säöüß]'), '');
    
    return normalized.trim();
  }

  // Hilfsfunktion zum Finden ähnlicher Wünsche mit Fuzzy Matching
  // Prüft nur Wünsche innerhalb der aktiven Party-Zeit
  Future<Map<String, dynamic>?> _findSimilarWish(String normalizedTitle, String normalizedArtist) async {
    try {
      // Prüfe zuerst, ob eine aktive Party läuft
      final now = DateTime.now();
      DateTime? partyStartDate;
      DateTime? partyEndDate;
      
      // Lade alle Partys und finde die aktive Party
      // Lade nur Partys, die nicht älter als 7 Tage sind (für Performance)
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('end_date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();
      
      for (final partyDoc in partiesQuery.docs) {
        final partyData = partyDoc.data();
        final startTimestamp = partyData['start_date'] as Timestamp?;
        final endTimestamp = partyData['end_date'] as Timestamp?;
        
        if (startTimestamp != null && endTimestamp != null) {
          final startDate = startTimestamp.toDate();
          final endDate = endTimestamp.toDate();
          
          // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende (Endzeit ist exklusiv)
          if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
            partyStartDate = startDate;
            partyEndDate = endDate;
            print('=== DUPLIKAT-SUCHE: Aktive Party gefunden ===');
            print('Party Start: $partyStartDate');
            print('Party Ende: $partyEndDate');
            break;
          }
        }
      }
      
      // Wenn keine aktive Party gefunden wurde, keine Duplikat-Prüfung
      if (partyStartDate == null || partyEndDate == null) {
        print('=== DUPLIKAT-SUCHE: Keine aktive Party - keine Duplikat-Prüfung ===');
        return null;
      }
      
      // Lade alle pending Wünsche
      print('=== LADE ALLE PENDING WÜNSCHE ===');
      final wishesSnapshot = await FirebaseFirestore.instance
          .collection('wishes')
          .where('status', isEqualTo: 'pending')
          .get();
      
      double bestSimilarity = 0.0;
      Map<String, dynamic>? bestMatch;
      
      // Normalisiere die Eingabe
      final normalizedInputTitle = _normalizeText(normalizedTitle);
      final normalizedInputArtist = _normalizeText(normalizedArtist);
      
      print('=== DUPLIKAT-SUCHE ===');
      print('Eingabe normalisiert: Titel="$normalizedInputTitle", Artist="$normalizedInputArtist"');
      print('Party-Zeitraum: $partyStartDate bis $partyEndDate');
      print('Aktuelle Zeit: $now');
      print('Anzahl zu prüfender Wünsche (vor Filterung): ${wishesSnapshot.docs.length}');
      
      // Debug: Zeige alle Wünsche
      for (var i = 0; i < wishesSnapshot.docs.length; i++) {
        final doc = wishesSnapshot.docs[i];
        final data = doc.data();
        final docTitle = (data['title'] ?? data['song'] ?? '') as String;
        final docArtist = (data['artist'] ?? '') as String;
        final docCreatedAt = data['createdAt'];
        final isDuplicate = data['is_duplicate'] == true;
        print('Wunsch $i: "$docTitle - $docArtist" (is_duplicate: $isDuplicate, createdAt: $docCreatedAt)');
      }
      
      int wishesInPartyTime = 0;
      
      for (final doc in wishesSnapshot.docs) {
        final data = doc.data();
        
        // Überspringe Duplikate (nur Original-Wünsche prüfen)
        if (data['is_duplicate'] == true) {
          continue;
        }
        
        // Prüfe, ob der Wunsch innerhalb der Party-Zeit erstellt wurde
        final createdAtTimestamp = data['createdAt'];
        DateTime? createdAt;
        if (createdAtTimestamp is Timestamp) {
          createdAt = createdAtTimestamp.toDate();
        } else if (createdAtTimestamp is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtTimestamp);
        }
        
        // Wenn kein createdAt vorhanden ist oder außerhalb der Party-Zeit, überspringe
        if (createdAt == null) {
          print('Wunsch "${data['title'] ?? ''}" hat kein createdAt - überspringe');
          continue;
        }
        
        // Prüfe, ob der Wunsch innerhalb der Party-Zeit liegt
        if (createdAt.compareTo(partyStartDate) < 0 || createdAt.compareTo(partyEndDate) >= 0) {
          print('Wunsch "${data['title'] ?? ''}" liegt außerhalb der Party-Zeit (erstellt: $createdAt) - überspringe');
          continue;
        }
        
        wishesInPartyTime++;
        
        final existingTitle = _normalizeText((data['title'] ?? data['song'] ?? '') as String);
        final existingArtist = _normalizeText((data['artist'] ?? '') as String);
        
        // Berechne Ähnlichkeit für Titel und Artist
        double titleSimilarity = 0.0;
        double artistSimilarity = 0.0;
        
        if (normalizedInputTitle.isNotEmpty && existingTitle.isNotEmpty) {
          titleSimilarity = StringSimilarity.compareTwoStrings(normalizedInputTitle, existingTitle);
        }
        
        if (normalizedInputArtist.isNotEmpty && existingArtist.isNotEmpty) {
          artistSimilarity = StringSimilarity.compareTwoStrings(normalizedInputArtist, existingArtist);
        }
        
        // Kombinierte Ähnlichkeit - vereinfachte Logik
        double combinedSimilarity = 0.0;
        if (normalizedInputTitle.isNotEmpty && normalizedInputArtist.isNotEmpty) {
          // Beide Felder vorhanden - gewichteter Durchschnitt
          combinedSimilarity = (titleSimilarity * 0.7 + artistSimilarity * 0.3);
        } else if (normalizedInputTitle.isNotEmpty) {
          // Nur Titel vorhanden
          combinedSimilarity = titleSimilarity;
        } else if (normalizedInputArtist.isNotEmpty) {
          // Nur Artist vorhanden
          combinedSimilarity = artistSimilarity;
        }
        
        // Debug-Ausgabe für alle Vergleiche
        print('Vergleich mit "${data['title'] ?? ''} - ${data['artist'] ?? ''}" (erstellt: $createdAt): '
            'Titel=${titleSimilarity.toStringAsFixed(3)}, '
            'Artist=${artistSimilarity.toStringAsFixed(3)}, '
            'Gesamt=${combinedSimilarity.toStringAsFixed(3)}');
        
        // Schwellenwert für Duplikat-Erkennung - NOCH NIEDRIGER für bessere Erkennung
        // Wenn Titel sehr ähnlich ist (>= 0.60) ODER kombinierte Ähnlichkeit >= 0.55
        if ((titleSimilarity >= 0.60 || combinedSimilarity >= 0.55) && combinedSimilarity > bestSimilarity) {
          bestSimilarity = combinedSimilarity;
          bestMatch = {
            'id': doc.id,
            'data': data,
            'similarity': combinedSimilarity,
            'titleSimilarity': titleSimilarity,
          };
          print('✓ POTENTIELLES DUPLIKAT GEFUNDEN! Ähnlichkeit: ${combinedSimilarity.toStringAsFixed(3)}');
        }
      }
      
      print('Anzahl Wünsche innerhalb der Party-Zeit: $wishesInPartyTime');
      
      if (bestMatch != null) {
        print('✓✓✓ DUPLIKAT BESTÄTIGT! ID: ${bestMatch['id']}, Ähnlichkeit: ${bestMatch['similarity']}');
      } else {
        print('✗ Kein Duplikat gefunden');
      }
      
      return bestMatch;
    } catch (e, stackTrace) {
      print('FEHLER beim Suchen ähnlicher Wünsche: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  Future<void> _addWish() async {
    print('=== _addWish() WURDE AUFGERUFEN ===');
    if (!_formKey.currentState!.validate()) {
      print('✗ Formular-Validierung fehlgeschlagen');
      return;
    }
    print('✓ Formular-Validierung erfolgreich');
    
    // Bestimme den Namen: für eingeloggte User aus Firebase Auth, sonst aus Eingabe
    String finalName;
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // Eingeloggter User: Name aus Firebase Auth
      finalName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      // Speichere für spätere Verwendung
      if (_guestName != finalName) {
        setState(() => _guestName = finalName);
        await _saveGuestName(finalName);
      }
    } else {
      // Nicht eingeloggter User: Name aus Eingabe oder gespeichert
      if (_guestName != null) {
        finalName = _guestName!;
        // Stelle sicher, dass der Controller auch den Wert hat
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = finalName;
        }
      } else {
        finalName = sanitizeInput(_nameController.text.trim());
        if (finalName.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bitte gib deinen Namen ein.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        setState(() => _guestName = finalName);
        // Speichere den Gast-Namen persistent
        await _saveGuestName(finalName);
      }
    }
    
    // Sanitize Eingaben gegen Schadcode
    final title = sanitizeInput(_titleController.text.trim());
    final artist = sanitizeInput(_artistController.text.trim());
    final greeting = sanitizeInput(_greetingController.text.trim());
    
    // Längenbegrenzungen für zusätzliche Sicherheit
    if (title.length > 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Titel ist zu lang (max. 200 Zeichen).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (artist.length > 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interpret ist zu lang (max. 200 Zeichen).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (greeting.length > 160) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gruß ist zu lang (max. 160 Zeichen).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Mindestens Titel ODER Interpret muss ausgefüllt sein
    if (title.isEmpty && artist.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte gib einen Titel oder einen Interpret ein.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Normalisiere Titel und Artist für Vergleich (Kleinschreibung, trim)
      final normalizedTitle = title.toLowerCase().trim();
      final normalizedArtist = artist.toLowerCase().trim();
      
      // Suche nach ähnlichen Wünschen (Fuzzy Matching)
      print('=== DUPLIKAT-PRÜFUNG STARTET ===');
      print('Eingabe: Titel="$title", Artist="$artist"');
      print('Normalisiert: Titel="$normalizedTitle", Artist="$normalizedArtist"');
      
      final similarWish = await _findSimilarWish(normalizedTitle, normalizedArtist);
      
      print('=== DUPLIKAT-PRÜFUNG ERGEBNIS ===');
      if (similarWish != null) {
        print('✓✓✓ DUPLIKAT GEFUNDEN! ✓✓✓');
        print('Original-ID: ${similarWish['id']}');
        print('Original-Daten: ${similarWish['data']}');
      } else {
        print('✗✗✗ KEIN DUPLIKAT GEFUNDEN - NEUER WUNSCH WIRD ERSTELLT ✗✗✗');
      }
      
      if (similarWish != null) {
        // Duplikat gefunden
        final originalWishRef = FirebaseFirestore.instance
            .collection('wishes')
            .doc(similarWish['id'] as String);
        
        final originalData = similarWish['data'] as Map<String, dynamic>;
        
        // Erhöhe Duplikatzähler
        final currentCount = (originalData['duplicate_count'] as int?) ?? 0;
        
        // Sammle Namen
        final requestedBy = List<String>.from(originalData['requested_by'] as List? ?? []);
        if (!requestedBy.contains(finalName)) {
          requestedBy.add(finalName);
        }
        
        // Sammle Grüße (mit Namen)
        final greetings = List<Map<String, dynamic>>.from(
          (originalData['greetings'] as List?)?.map((g) => g as Map<String, dynamic>) ?? []
        );
        if (greeting.isNotEmpty) {
          greetings.add({'name': finalName, 'greeting': greeting});
        }
        
        // Aktualisiere den ursprünglichen Wunsch
        // Firestore-Regeln erlauben Updates für authentifizierte User ODER für Gäste,
        // wenn nur Duplikat-Felder (duplicate_count, requested_by, greetings) geändert werden
        try {
          print('=== AKTUALISIERE URSPRÜNGLICHEN WUNSCH ===');
          print('Original-ID: ${similarWish['id']}');
          print('Aktueller duplicate_count: $currentCount');
          print('Neuer duplicate_count: ${currentCount + 1}');
          print('requested_by vorher: ${originalData['requested_by']}');
          print('requested_by nachher: $requestedBy');
          
          // Erstelle/aktualisiere is_registered_users Map
          final existingIsRegisteredUsers = Map<String, bool>.from((originalData['is_registered_users'] as Map<String, dynamic>?) ?? {});
          // Setze Status für alle Namen in requestedBy
          for (final n in requestedBy) {
            if (!existingIsRegisteredUsers.containsKey(n)) {
              // Neuer Name - setze basierend auf aktuellem User
              existingIsRegisteredUsers[n] = user != null;
            }
            // Wenn Name bereits existiert, behalte den bestehenden Status
          }
          
          final updateData = {
            'duplicate_count': currentCount + 1,
            'requested_by': requestedBy,
            'greetings': greetings.map((g) => {
              'name': g['name'],
              'greeting': g['greeting'],
            }).toList(),
            'is_registered_users': existingIsRegisteredUsers,
          };
          
          print('Update-Daten: $updateData');
          
          await originalWishRef.update(updateData);
          print('✓✓✓ Ursprünglicher Wunsch erfolgreich aktualisiert! ✓✓✓');
          
          // Verifiziere das Update
          final updatedDoc = await originalWishRef.get();
          final updatedData = updatedDoc.data();
          print('Verifizierung - duplicate_count nach Update: ${updatedData?['duplicate_count']}');
          print('Verifizierung - requested_by nach Update: ${updatedData?['requested_by']}');
        } catch (e, stackTrace) {
          print('✗✗✗ FEHLER beim Aktualisieren des ursprünglichen Wunsches ✗✗✗');
          print('Fehler: $e');
          print('Stack Trace: $stackTrace');
          // Falls Update fehlschlägt (z.B. wegen Firestore-Regeln), erstelle trotzdem den neuen Wunsch
        }
        
        // Erstelle trotzdem einen eigenen Wunsch-Eintrag (für User-Sichtbarkeit)
        // Verwende aktuelle/nächste Party oder Fallback für manuelle Wunschbox
        final currentPartyId = (_currentOrNextParty?['id'] as String?) ?? 'manual';
        final currentPartyCode = (_currentOrNextParty?['party_code'] as String?) ?? 'manual';

        final wishData = {
          'name': finalName,
          'title': title,
          'artist': artist,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'is_duplicate': true,
          'original_wish_id': similarWish['id'] as String,
          'is_registered_user': user != null, // Speichere, ob User angemeldet ist
          'party_id': currentPartyId,
          'party_code': currentPartyCode,
        };
        
        if (greeting.isNotEmpty) {
          wishData['greeting'] = greeting;
        }
        
        await FirebaseFirestore.instance.collection('wishes').add(wishData);
      } else {
        // Kein Duplikat - erstelle neuen Wunsch mit Duplikat-Feldern
        // Verwende aktuelle/nächste Party oder Fallback für manuelle Wunschbox
        final currentPartyId = (_currentOrNextParty?['id'] as String?) ?? 'manual';
        final currentPartyCode = (_currentOrNextParty?['party_code'] as String?) ?? 'manual';

        final wishData = {
          'name': finalName,
          'title': title,
          'artist': artist,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'duplicate_count': 0,
          'requested_by': [finalName],
          'greetings': greeting.isNotEmpty ? [{'name': finalName, 'greeting': greeting}] : [],
          'is_duplicate': false,
          'is_registered_user': user != null, // Speichere, ob User angemeldet ist
          'is_registered_users': {finalName: user != null}, // Speichere User-Status für jeden Namen
          'party_id': currentPartyId,
          'party_code': currentPartyCode,
        };
        
        if (greeting.isNotEmpty) {
          wishData['greeting'] = greeting;
        }
        
        await FirebaseFirestore.instance.collection('wishes').add(wishData);
      }

      _titleController.clear();
      _artistController.clear();
      _greetingController.clear();

      // Für nicht eingeloggte User: Name zurücksetzen, damit das Feld wieder leer und editierbar ist
      if (user == null) {
        _nameController.clear();
        setState(() {
          _guestName = null;
        });
        await _clearGuestName();
      }

      if (mounted) {
        // Zeige Erfolgsmeldung anstelle des Formulars
        setState(() {
          _showSuccessMessage = true;
        });
        
        // Nach 5 Sekunden wieder das Formular anzeigen
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showSuccessMessage = false;
            });
          }
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Absenden:\n$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        // Debug: Ausgabe in Konsole
        debugPrint('Firestore Fehler: $e');
        debugPrint('Stack Trace: $stackTrace');
      }
    }
  }

  Future<void> _updateWishStatus(String docId, String newStatus) async {
    final updateData = <String, dynamic>{
      'status': newStatus,
    };
    
    // Setze Zeitstempel basierend auf Status
    if (newStatus == 'played') {
      updateData['playedAt'] = FieldValue.serverTimestamp();
      // Lösche rejectedAt falls vorhanden
      updateData['rejectedAt'] = FieldValue.delete();
    } else if (newStatus == 'rejected') {
      updateData['rejectedAt'] = FieldValue.serverTimestamp();
      // Lösche playedAt falls vorhanden
      updateData['playedAt'] = FieldValue.delete();
    } else if (newStatus == 'pending') {
      // Lösche beide Zeitstempel wenn zurück auf pending
      updateData['playedAt'] = FieldValue.delete();
      updateData['rejectedAt'] = FieldValue.delete();
    }
    
    await FirebaseFirestore.instance
        .collection('wishes')
        .doc(docId)
        .update(updateData);
  }

  Future<void> _deleteWish(String docId, String wishName) async {
    // Prüfe, ob der User der Besitzer des Wunsches ist
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final currentUserName = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? '';
    if (currentUserName != wishName) {
      // User ist nicht der Besitzer
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Du kannst nur deine eigenen Wünsche löschen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Prüfe Status des Wunsches
    final doc = await FirebaseFirestore.instance
        .collection('wishes')
        .doc(docId)
        .get();
    
    final status = doc.data()?['status'] ?? 'pending';
    if (status != 'pending') {
      // Nur pending Wünsche können gelöscht werden
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nur noch offene Wünsche können gelöscht werden.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Bestätigungsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wunsch löschen?'),
        content: const Text('Möchtest du diesen Wunsch wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('wishes')
            .doc(docId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wunsch wurde gelöscht.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Löschen: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  bool _isAdminEmail(String? email) {
    if (email == null) return false;
    final adminEmails = [
      'info@dj-ollerganove.de',
      // Weitere Admin-Emails können hier hinzugefügt werden
    ];
    return adminEmails.contains(email.toLowerCase());
  }
  
  // Admin-Passwort für zusätzliche Sicherheit
  static const String _adminPassword = 'OG-1005-OG';
  
  bool _isAdminPassword(String password) {
    return password == _adminPassword;
  }

  Future<void> _logout() async {
    // Lösche gespeichertes Passwort beim Abmelden
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    
    // Firebase Auth Logout
    await FirebaseAuth.instance.signOut();
    
    setState(() {
      _isAdmin = false;
      _guestName = null; // Reset Gast-Name beim Ausloggen
    });
    _saveAdminStatus(false); // Lösche Admin-Status
    _clearGuestName(); // Lösche Gast-Namen
    _nameController.clear(); // Leere Namensfeld
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'played':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Gespielt';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        text = 'Abgelehnt';
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
        text = 'Offen';
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(text),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Zeige Ladebildschirm während gespeicherte Daten geladen werden
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Wunschbox',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Party-Code anzeigen (wenn vorhanden)
              if (_partyCode != null && _partyCode!.isNotEmpty) ...[
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.qr_code,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Party-Code',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _partyCode!,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Prüfe, ob Wunschbox aktiv ist
              if (!_isWishboxActive && !_isAdmin) ...[
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Die Wunschbox ist derzeit nicht aktiv. Sie ist nur während der Party-Zeit oder wenn sie manuell aktiviert wurde verfügbar.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Formular oder Erfolgsmeldung nur für Nicht-Admins anzeigen, wenn Wunschbox aktiv ist
              if (!_isAdmin && _isWishboxActive) ...[
                if (_showSuccessMessage)
                  // Erfolgsmeldung anstelle des Formulars
                  Card(
                    color: Colors.green.shade50,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Wunsch wurde abgeschickt!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vielen Dank für deinen Musikwunsch!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Formular anzeigen
                  Builder(
                    builder: (context) {
                      // Stelle sicher, dass der Controller den guestName-Wert hat
                      if (_guestName != null && _nameController.text.trim() != _guestName) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _nameController.text = _guestName!;
                          }
                        });
                      }
                      return _WishForm(
                        formKey: _formKey,
                        nameController: _nameController,
                        titleController: _titleController,
                        artistController: _artistController,
                        greetingController: _greetingController,
                        onSubmit: _addWish,
                        guestName: _guestName,
                      );
                    },
                  ),
                const SizedBox(height: 12),
              ],
              if (!_isAdmin) ...[
                // Tipp für nicht eingeloggte User
                if (FirebaseAuth.instance.currentUser == null) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.login, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tipp: Melde dich an, um deine abgegebenen Musikwünsche jederzeit einsehen zu können.',
                              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                            ),
            ),
          ],
        ),
      ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$day.$month.$year';
  }
}

class _WishForm extends StatefulWidget {
  const _WishForm({
    required this.formKey,
    required this.nameController,
    required this.titleController,
    required this.artistController,
    required this.greetingController,
    required this.onSubmit,
    this.guestName,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController greetingController;
  final Future<void> Function() onSubmit;
  final String? guestName;

  @override
  State<_WishForm> createState() => _WishFormState();
}

class _WishFormState extends State<_WishForm> {
  Timer? _titleDebounceTimer;
  Timer? _artistDebounceTimer;
  List<SpotifyTrack> _titleSuggestions = [];
  List<SpotifyTrack> _artistSuggestions = [];
  bool _isLoadingTitle = false;
  bool _isLoadingArtist = false;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _artistFocusNode = FocusNode();
  final LayerLink _titleLayerLink = LayerLink();
  final LayerLink _artistLayerLink = LayerLink();
  OverlayEntry? _titleOverlayEntry;
  OverlayEntry? _artistOverlayEntry;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleDebounceTimer?.cancel();
    _artistDebounceTimer?.cancel();
    _titleFocusNode.dispose();
    _artistFocusNode.dispose();
    super.dispose();
  }

  void _searchTitle(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _titleSuggestions = [];
        _isLoadingTitle = false;
      });
      return;
    }

    // Debounce: Warte 500ms nach dem letzten Tastendruck
    _titleDebounceTimer?.cancel();
    _titleDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isLoadingTitle = true;
      });

      try {
        print('🔍 Spotify-Suche für Titel: "$query"');
        final tracks = await SpotifyService.searchTracks(query);
        print('✅ ${tracks.length} Tracks gefunden für Titel');
        if (mounted) {
          setState(() {
            _titleSuggestions = tracks;
            _isLoadingTitle = false;
          });
          print('✅ ${tracks.length} Titel-Vorschläge gesetzt');
          // Vorschläge werden automatisch im Formular angezeigt
        }
      } catch (e) {
        print('❌ Fehler bei Spotify-Suche (Titel): $e');
        if (mounted) {
          setState(() {
            _titleSuggestions = [];
            _isLoadingTitle = false;
          });
        }
      }
    });
  }

  void _searchArtist(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _artistSuggestions = [];
        _isLoadingArtist = false;
      });
      return;
    }

    // Debounce: Warte 500ms nach dem letzten Tastendruck
    _artistDebounceTimer?.cancel();
    _artistDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isLoadingArtist = true;
      });

      try {
        print('🔍 Spotify-Suche für Interpret: "$query"');
        final tracks = await SpotifyService.searchTracks(query, searchType: 'artist');
        print('✅ ${tracks.length} Tracks gefunden für Interpret');
        if (mounted) {
          setState(() {
            _artistSuggestions = tracks;
            _isLoadingArtist = false;
          });
          print('✅ ${tracks.length} Interpret-Vorschläge gesetzt');
          // Vorschläge werden automatisch im Formular angezeigt
        }
      } catch (e) {
        print('❌ Fehler bei Spotify-Suche (Interpret): $e');
        if (mounted) {
          setState(() {
            _artistSuggestions = [];
            _isLoadingArtist = false;
          });
        }
      }
    });
  }

  void _onTitleSelected(SpotifyTrack track) {
    setState(() {
      widget.titleController.text = track.name;
      widget.artistController.text = track.artists;
      _titleSuggestions = [];
    });
  }

  void _onArtistSelected(SpotifyTrack track) {
    setState(() {
      widget.titleController.text = track.name;
      widget.artistController.text = track.artists;
      _artistSuggestions = [];
    });
  }

  void _showTitleSuggestionsModal(BuildContext context) {
    if (_titleSuggestions.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle-Bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Titel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Vorschläge für Titel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            // Liste der Vorschläge
            Flexible(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _titleSuggestions.length,
                itemBuilder: (context, index) {
                  final track = _titleSuggestions[index];
                  return ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(
                      track.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(track.artists),
                    onTap: () {
                      Navigator.pop(context);
                      _onTitleSelected(track);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArtistSuggestionsModal(BuildContext context) {
    if (_artistSuggestions.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle-Bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Titel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Vorschläge für Interpret',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            // Liste der Vorschläge
            Flexible(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _artistSuggestions.length,
                itemBuilder: (context, index) {
                  final track = _artistSuggestions[index];
                  return ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(
                      track.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(track.artists),
                    onTap: () {
                      Navigator.pop(context);
                      _onArtistSelected(track);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Namensfeld nur anzeigen, wenn User nicht eingeloggt ist
          if (FirebaseAuth.instance.currentUser == null) ...[
            TextFormField(
              controller: widget.nameController,
              decoration: const InputDecoration(
                labelText: 'Dein Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                return (value == null || value.trim().isEmpty) ? 'Name fehlt' : null;
              },
            ),
            const SizedBox(height: 8),
          ],
          // Autocomplete für Titel
          // Vorschläge für Titel anzeigen (oberhalb des Eingabefeldes)
          if (_titleSuggestions.isNotEmpty && _titleFocusNode.hasFocus)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _titleSuggestions.length > 20 ? 20 : _titleSuggestions.length,
                itemBuilder: (context, index) {
                  final track = _titleSuggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      track.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      track.artists,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      _onTitleSelected(track);
                    },
                  );
                },
              ),
            ),
          TextFormField(
            controller: widget.titleController,
            focusNode: _titleFocusNode,
            decoration: InputDecoration(
              labelText: 'Titel',
              prefixIcon: const Icon(Icons.music_note_outlined),
              helperText: 'Titel oder Interpret muss ausgefüllt sein',
              suffixIcon: _isLoadingTitle
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              _searchTitle(value);
            },
            validator: (value) {
              return null;
            },
            onFieldSubmitted: (_) => widget.onSubmit(),
          ),
          const SizedBox(height: 8),
          // Autocomplete für Interpret
          // Vorschläge für Interpret anzeigen (oberhalb des Eingabefeldes)
          if (_artistSuggestions.isNotEmpty && _artistFocusNode.hasFocus)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _artistSuggestions.length > 20 ? 20 : _artistSuggestions.length,
                itemBuilder: (context, index) {
                  final track = _artistSuggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      track.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      track.artists,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      _onArtistSelected(track);
                    },
                  );
                },
              ),
            ),
          TextFormField(
            controller: widget.artistController,
            focusNode: _artistFocusNode,
            decoration: InputDecoration(
              labelText: 'Interpret',
              prefixIcon: const Icon(Icons.mic),
              helperText: 'Titel oder Interpret muss ausgefüllt sein',
              suffixIcon: _isLoadingArtist
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              _searchArtist(value);
            },
            validator: (value) {
              return null;
            },
            onFieldSubmitted: (_) => widget.onSubmit(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.greetingController,
            decoration: const InputDecoration(
              labelText: 'Gruß (optional)',
              prefixIcon: Icon(Icons.favorite_outline),
              helperText: 'Max. 160 Zeichen',
            ),
            maxLength: 160,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value != null && value.length > 160) {
                return 'Maximal 160 Zeichen erlaubt';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onSubmit,
            icon: const Icon(Icons.send),
            label: const Text('Wunsch abschicken'),
          ),
        ],
      ),
    );
  }
}

// Kontaktformular Widget
class _ContactForm extends StatefulWidget {
  final GlobalKey<_ContactFormState>? formKey;
  
  const _ContactForm({this.formKey}) : super(key: formKey);

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isUserLoggedIn = false;
  bool _showSuccessMessage = false; // Zeige Erfolgsmeldung anstelle des Formulars
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _updateUserData();
    
    // Höre auf Auth-Änderungen
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _updateUserData();
        // Setze Erfolgsmeldung zurück, wenn sich der Auth-Status ändert
        // (z.B. beim Logout/Login, damit beim nächsten Öffnen die Felder leer sind)
        if (_showSuccessMessage) {
          setState(() {
            _showSuccessMessage = false;
          });
        }
      }
    });
  }
  
  void _updateUserData() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      if (user != null) {
        _isUserLoggedIn = true;
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
      } else {
        _isUserLoggedIn = false;
        _nameController.clear();
        _emailController.clear();
      }
    });
  }

  // Öffentliche Methode, um die Erfolgsmeldung zurückzusetzen
  void resetSuccessMessage() {
    if (mounted && _showSuccessMessage) {
      setState(() {
        _showSuccessMessage = false;
        // Stelle sicher, dass alle Felder leer sind (außer Name/Email wenn User eingeloggt)
        _phoneController.clear();
        _subjectController.clear();
        _messageController.clear();
        _formKey.currentState?.reset();
        // Lade User-Daten neu, falls User eingeloggt ist
        _updateUserData();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitContactForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Sanitize Eingaben gegen Schadcode
      final name = sanitizeInput(_nameController.text.trim());
      // Sanitize Email gegen Schadcode (Email wird auch von EmailJS validiert)
      final email = sanitizeEmail(_emailController.text.trim());
      // Telefonnummer ohne trim() am Anfang, um führende 0 zu erhalten
      // Nur Leerzeichen am Ende entfernen
      final phone = sanitizeInput(_phoneController.text.replaceAll(RegExp(r'\s+$'), ''));
      final subject = sanitizeInput(_subjectController.text.trim());
      final message = sanitizeInput(_messageController.text.trim());
      
      // Längenbegrenzungen für zusätzliche Sicherheit
      if (name.length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name ist zu lang (max. 100 Zeichen).'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (subject.length > 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Betreff ist zu lang (max. 200 Zeichen).'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (message.length > 3000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nachricht ist zu lang (max. 3000 Zeichen).'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Speichere Kontaktanfrage in Firestore
      await FirebaseFirestore.instance.collection('contact_messages').add({
        'name': name,
        'email': email,
        'phone': phone,
        'subject': subject,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email,
      });

      // Versuche Email über EmailJS zu senden
      try {
        await _sendEmailViaEmailJS(name, email, phone, subject, message);
      } catch (e) {
        // Email-Versand fehlgeschlagen, aber Firestore-Speicherung war erfolgreich
        // Das ist ok, die Nachricht ist in Firestore gespeichert
        print('Email-Versand fehlgeschlagen: $e');
      }

      if (mounted) {
        // Formular leeren
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _subjectController.clear();
        _messageController.clear();
        _formKey.currentState!.reset();
        // Zeige Erfolgsmeldung anstelle des Formulars
        setState(() {
          _showSuccessMessage = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Senden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendEmailViaEmailJS(String name, String email, String phone, String subject, String message) async {
    // EmailJS Konfiguration
    // TODO: Ersetze diese Werte mit deinen EmailJS-Daten
    // Registriere dich bei https://www.emailjs.com/
    const String emailJSServiceId = 'service_0e6txde';
    const String emailJSTemplateId = 'template_upsc3oi';
    const String emailJSPublicKey = '5ChQmGAWG7rTP-Q9K';
    const String emailJSUserId = '5ChQmGAWG7rTP-Q9K';

    // EmailJS API URL
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    // Email-Daten (EmailJS Format)
    final emailData = {
      'service_id': emailJSServiceId,
      'template_id': emailJSTemplateId,
      'user_id': emailJSUserId,
      'template_params': {
        'to_email': 'info@dj-ollerganove.de',
        'from_name': name,
        'from_email': email.isNotEmpty ? email : 'noreply@dj-ollerganove.de',
        'phone': phone.isNotEmpty ? phone : 'Nicht angegeben',
        'subject': subject.isNotEmpty ? subject : 'Kontaktanfrage von $name',
        'message': message,
        'reply_to': email.isNotEmpty ? email : 'noreply@dj-ollerganove.de',
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode(emailData),
      );

      if (response.statusCode != 200) {
        throw Exception('Email-Versand fehlgeschlagen: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Email-Versand fehlgeschlagen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Zeige Erfolgsmeldung anstelle des Formulars
    if (_showSuccessMessage) {
      return Card(
        color: Colors.green.shade50,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Nachricht wurde erfolgreich gesendet!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Vielen Dank für deine Nachricht. Ich melde mich schnellstens.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Zeige Formular
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isUserLoggedIn,
                decoration: InputDecoration(
                  labelText: _isUserLoggedIn ? 'Name' : 'Vor- und Nachname *',
                  prefixIcon: const Icon(Icons.person),
                  filled: _isUserLoggedIn,
                  fillColor: _isUserLoggedIn 
                      ? Theme.of(context).colorScheme.surfaceVariant 
                      : null,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte gib deinen Namen ein.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                enabled: !_isUserLoggedIn,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  helperText: _isUserLoggedIn 
                      ? null 
                      : 'Email oder Telefon muss ausgefüllt sein',
                  filled: _isUserLoggedIn,
                  fillColor: _isUserLoggedIn 
                      ? Theme.of(context).colorScheme.surfaceVariant 
                      : null,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  // Wenn User eingeloggt ist, ist Email bereits vorhanden
                  if (_isUserLoggedIn) {
                    return null;
                  }
                  
                  final email = value?.trim() ?? '';
                  // Nur Leerzeichen am Ende entfernen, nicht am Anfang (für führende 0)
                  final phone = _phoneController.text.replaceAll(RegExp(r'\s+$'), '');
                  
                  if (email.isEmpty && phone.isEmpty) {
                    return 'Bitte gib Email oder Telefon ein.';
                  }
                  
                  if (email.isNotEmpty && !email.contains('@')) {
                    return 'Bitte gib eine gültige Email-Adresse ein.';
                  }
                  
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefon',
                  prefixIcon: const Icon(Icons.phone),
                  helperText: _isUserLoggedIn 
                      ? 'Für schnellere Kontaktaufnahme\nbitte noch deine Telefonnr' 
                      : 'Email oder Telefon muss ausgefüllt sein',
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.text, // Text statt phone, um führende 0 zu erhalten
                validator: (value) {
                  // Wenn User eingeloggt ist, ist Email bereits vorhanden, Telefon ist optional
                  if (_isUserLoggedIn) {
                    return null;
                  }
                  
                  final email = _emailController.text.trim();
                  // Nur Leerzeichen am Ende entfernen, nicht am Anfang (für führende 0)
                  final phone = value?.replaceAll(RegExp(r'\s+$'), '') ?? '';
                  
                  if (email.isEmpty && phone.isEmpty) {
                    return 'Bitte gib Email oder Telefon ein.';
                  }
                  
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Betreff',
                  prefixIcon: Icon(Icons.subject),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Nachricht *',
                  prefixIcon: Icon(Icons.message),
                  helperText: 'Max. 3000 Zeichen',
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                maxLength: 3000,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte gib eine Nachricht ein.';
                  }
                  if (value.length > 3000) {
                    return 'Die Nachricht darf maximal 3000 Zeichen lang sein.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isLoading ? null : _submitContactForm,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isLoading ? 'Wird gesendet...' : 'Nachricht senden'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Deine Wünsche-Seite
class DeineWunschePage extends StatefulWidget {
  const DeineWunschePage({super.key});

  @override
  State<DeineWunschePage> createState() => _DeineWunschePageState();
}

class _DeineWunschePageState extends State<DeineWunschePage> {
  String? _guestName;

  @override
  void initState() {
    super.initState();
    _loadGuestName();
  }

  Future<void> _loadGuestName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('guestName');
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // Wenn eingeloggt, verwende den Namen aus SharedPreferences oder DisplayName
      setState(() {
        _guestName = savedName ?? user.displayName ?? user.email?.split('@')[0] ?? 'User';
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'played':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Gespielt';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        text = 'Abgelehnt';
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
        text = 'Offen';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWish(String docId, String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wunsch löschen?'),
        content: const Text('Möchtest du diesen Wunsch wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('wishes').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wunsch gelöscht'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Löschen: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Bitte melde dich an',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Du musst angemeldet sein, um deine Wünsche zu sehen.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_guestName == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Deine Wünsche',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('wishes')
                      .where('name', isEqualTo: _guestName)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return buildFirebaseErrorWidget(snapshot.error!);
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Du hast noch keine Wünsche abgeschickt.'),
                      );
                    }
                    // Filtere Duplikate heraus - zeige nur Original-Wünsche
                    final originalDocs = docs.where((doc) {
                      final data = doc.data();
                      return data['is_duplicate'] != true;
                    }).toList();
                    
                    if (originalDocs.isEmpty) {
                      return const Center(
                        child: Text('Keine offenen Wünsche.'),
                      );
                    }
                    
                    // Sortiere clientseitig nach createdAt (älteste zuerst)
                    final sortedDocs = originalDocs.toList()
                      ..sort((a, b) {
                        final tsA = a.data()['createdAt'];
                        final tsB = b.data()['createdAt'];
                        final dateA = tsA is Timestamp
                            ? tsA.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        final dateB = tsB is Timestamp
                            ? tsB.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        return dateB.compareTo(dateA); // Neueste zuerst
                      });
                    return ListView.separated(
                      shrinkWrap: false,
                      physics: const ClampingScrollPhysics(),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = sortedDocs[index];
                        final data = doc.data();
                        // Rückwärtskompatibilität: alte Wünsche haben 'song' statt 'title'
                        final title = (data['title'] ?? data['song'] ?? '') as String;
                        final artist = (data['artist'] ?? '') as String;
                        final name = (data['name'] ?? '') as String;
                        final greeting = (data['greeting'] ?? '') as String;
                        final status = (data['status'] ?? 'pending') as String;
                        final ts = data['createdAt'];
                        final created = ts is Timestamp
                            ? ts.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        
                        // Titel/Interpret anzeigen
                        String displayText = '';
                        if (title.isNotEmpty && artist.isNotEmpty) {
                          displayText = '$title - $artist';
                        } else if (title.isNotEmpty) {
                          displayText = title;
                        } else if (artist.isNotEmpty) {
                          displayText = artist;
                        }

                        // Nummerierung: sortedDocs.length - index (neueste = 1)
                        final number = sortedDocs.length - index;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.grey.shade100,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                          ),
                          child: InkWell(
                            onTap: () {}, // Leerer onTap für visuelles Feedback
                            splashColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade800
                                : Colors.amber.shade200,
                            highlightColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade900.withOpacity(0.3)
                                : Colors.amber.shade100,
                            child: ListTile(
                              title: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                                    child: Text(
                                      '$number.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(_formatDate(created)),
                                if (greeting.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.blue.shade900.withOpacity(0.3)
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.blue.shade700
                                            : Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 16,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.blue.shade300
                                              : Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            greeting,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.blue.shade200
                                                  : Colors.blue.shade900,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                _buildStatusBadge(status),
                              ],
                            ),
                            trailing: status == 'pending'
                                ? IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Wunsch löschen',
                                    onPressed: () => _deleteWish(doc.id, name),
                                  )
                                : null,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Party-Verwaltungsseite für Admin
class PartyVerwaltungPage extends StatefulWidget {
  const PartyVerwaltungPage({super.key});

  @override
  State<PartyVerwaltungPage> createState() => _PartyVerwaltungPageState();
}

class _PartyVerwaltungPageState extends State<PartyVerwaltungPage> {
  StreamController<DateTime>? _timeController;
  Timer? _timeTimer;
  
  // Stream für periodische Zeit-Updates (für Countdowns)
  Stream<DateTime> get _timeStream {
    _timeController ??= StreamController<DateTime>();
    _timeController!.add(DateTime.now());
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_timeController!.isClosed) {
        _timeController!.add(DateTime.now());
      } else {
        timer.cancel();
      }
    });
    return _timeController!.stream;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _timeController?.close();
    super.dispose();
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year um $hour:$minute Uhr';
  }

  // Formatiert DateTime für Bild (kompakt)
  String _formatDateTimeForImage(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }

  // Formatiert Datum für Party Extra Dialog
  String _formatDateForPartyExtra(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day.$month.$year';
  }

  // Formatiert Uhrzeit für Party Extra Dialog
  String _formatTimeForPartyExtra(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute Uhr';
  }

  String _getPartyStatus(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende (Endzeit ist exklusiv)
    if (now.compareTo(startDate) < 0) {
      return 'Bevorstehend';
    } else if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
      return 'Läuft';
    } else {
      return 'Beendet';
    }
  }

  Color _getPartyStatusColor(String status) {
    switch (status) {
      case 'Bevorstehend':
        return Colors.blue;
      case 'Läuft':
        return Colors.green;
      case 'Beendet':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Erstellt eine Spalte für die Party-Informationen
  pw.Widget _buildPartyColumn(
    String partyName,
    DateTime startDate,
    String pwaUrl,
    String partyCode,
    pw.ImageProvider? logoImage,
    pw.ImageProvider? djWbLogoImage,
  ) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          // Überschrift oben in jeder Spalte
          pw.Text(
            'Hier kannst Du dem DJ Deine Musikwünsche mitteilen',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 16),
          // Partyname
          pw.Text(
            partyName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 12),
          // Beginndatum
          pw.Text(
            _formatDateTimeForPDF(startDate),
            style: const pw.TextStyle(fontSize: 12),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 20),
          // QR-Code
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: pwaUrl,
            width: 180,
            height: 180,
          ),
          pw.SizedBox(height: 12),
          // Code unter dem QR-Code (kleiner)
          pw.Text(
            partyCode,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 3,
            ),
            textAlign: pw.TextAlign.center,
          ),
          // Logo (falls vorhanden)
          if (logoImage != null) ...[
            pw.SizedBox(height: 16),
            pw.Image(logoImage, width: 180, fit: pw.BoxFit.contain),
          ],
          // Website-Adresse
          pw.SizedBox(height: 8),
          pw.Text(
            'www.dj-ollerganove.de',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
          // Fußzeile mit DJ-WB Logo und Text
          pw.Spacer(),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (djWbLogoImage != null) ...[
                pw.Image(djWbLogoImage, width: 40, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 8),
              ],
              pw.Text(
                'a creation by DJ Ollerganove',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Generiert eine PDF-Datei mit Party-Informationen und QR-Code
  Future<void> _generatePartyPDF(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode,
  ) async {
    try {
      final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
      
      // Lade Logo (logo.png für oben)
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logo.png');
        final logoUint8List = logoBytes.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoUint8List);
        print('✅ logo.png Logo erfolgreich geladen');
      } catch (e) {
        print('❌ Fehler beim Laden des logo.png Logos: $e');
        // Kein Fallback - Logo bleibt null wenn es nicht geladen werden kann
      }
      
      // Lade DJ-WB.png Logo für die Fußzeile
      pw.ImageProvider? djWbLogoImage;
      try {
        final djWbLogoBytes = await rootBundle.load('assets/DJ-WB.png');
        final djWbLogoUint8List = djWbLogoBytes.buffer.asUint8List();
        djWbLogoImage = pw.MemoryImage(djWbLogoUint8List);
        print('✅ DJ-WB.png Logo erfolgreich geladen');
      } catch (e) {
        print('❌ Fehler beim Laden des DJ-WB.png Logos: $e');
      }
      
      // Erstelle PDF im Querformat
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Spalte 1
                _buildPartyColumn(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
                // Spalte 2
                _buildPartyColumn(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
                // Spalte 3
                _buildPartyColumn(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
              ],
            );
          },
        ),
      );
      
      // Zeige PDF-Vorschau und Download-Dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Generiert eine einzelne Spalte PDF im Hochformat
  Future<void> _generateSinglePartyPDF(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode,
  ) async {
    try {
      final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
      
      // Lade Logo (logo.png für oben)
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logo.png');
        final logoUint8List = logoBytes.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoUint8List);
      } catch (e) {
        print('❌ Fehler beim Laden des logo.png Logos: $e');
      }
      
      // Lade DJ-WB.png Logo für die Fußzeile
      pw.ImageProvider? djWbLogoImage;
      try {
        final djWbLogoBytes = await rootBundle.load('assets/DJ-WB.png');
        final djWbLogoUint8List = djWbLogoBytes.buffer.asUint8List();
        djWbLogoImage = pw.MemoryImage(djWbLogoUint8List);
      } catch (e) {
        print('❌ Fehler beim Laden des DJ-WB.png Logos: $e');
      }
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return _buildPartyColumn(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage);
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Formatiert DateTime für PDF (ohne "um")
  String _formatDateTimeForPDF(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }

  // Speichert QR-Code mit Party-Code als Bild
  Future<void> _saveQRCodeAsImage(
    BuildContext context,
    String pwaUrl,
    String partyCode,
    String partyName,
    DateTime startDate,
  ) async {
    try {
      // Erstelle ein Bild mit QR-Code und Party-Code
      const qrSize = 500.0;
      const padding = 40.0;
      const textHeight = 60.0;
      const titleHeight = 80.0;
      const dateHeight = 50.0;
      const spacing = 20.0;
      const totalHeight = titleHeight + spacing + dateHeight + spacing + qrSize + spacing + textHeight;
      const totalWidth = qrSize + (padding * 2);

      // Erstelle ein PictureRecorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Weißer Hintergrund
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, totalWidth, totalHeight),
        whitePaint,
      );

      double currentY = padding;

      // Zeichne Party-Titel über dem QR-Code
      final titleStyle = TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      );
      final titleSpan = TextSpan(
        text: partyName,
        style: titleStyle,
      );
      final titlePainter = TextPainter(
        text: titleSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      );
      titlePainter.layout(maxWidth: qrSize);
      final titleX = (totalWidth - titlePainter.width) / 2;
      titlePainter.paint(canvas, Offset(titleX, currentY));
      currentY += titlePainter.height + spacing;

      // Zeichne Party-Datum
      final dateText = _formatDateTimeForImage(startDate);
      final dateStyle = TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      );
      final dateSpan = TextSpan(
        text: dateText,
        style: dateStyle,
      );
      final datePainter = TextPainter(
        text: dateSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      datePainter.layout(maxWidth: qrSize);
      final dateX = (totalWidth - datePainter.width) / 2;
      datePainter.paint(canvas, Offset(dateX, currentY));
      currentY += datePainter.height + spacing;

      // Zeichne QR-Code
      final qrPainter = QrPainter(
        data: pwaUrl,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      
      // Verschiebe Canvas für QR-Code (zentriert)
      canvas.save();
      canvas.translate(padding, currentY);
      qrPainter.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
      currentY += qrSize + spacing;

      // Zeichne Party-Code Text unter dem QR-Code
      final textStyle = TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 4,
        color: Colors.black,
      );
      final textSpan = TextSpan(
        text: partyCode,
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Zentriere den Text
      final textX = (totalWidth - textPainter.width) / 2;
      textPainter.paint(canvas, Offset(textX, currentY));

      // Konvertiere zu Bild
      final picture = recorder.endRecording();
      final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Speichere das Bild direkt in der Galerie
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: 'QR_Code_$partyCode',
      );

      if (context.mounted) {
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR-Code wurde in der Galerie gespeichert'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler beim Speichern in der Galerie'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Fehler beim Speichern des QR-Codes: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Zeigt einen Dialog mit QR-Code für die Party
  void _showQRCodeDialog(
    BuildContext context,
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode,
  ) {
    // PWA-URL mit Code als Parameter
    final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Titel
                  Text(
                    partyName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                            Text(
                              'Beginn: ${_formatDateForPartyExtra(startDate)} - ${_formatTimeForPartyExtra(startDate)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Ende: ${_formatDateForPartyExtra(endDate)} - ${_formatTimeForPartyExtra(endDate)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.left,
                        ),
                          ],
                      ),
                    ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // QR-Code mit Code darunter
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: pwaUrl,
                          version: QrVersions.auto,
                          size: 250,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          partyCode,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Buttons nebeneinander
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 3-tlg Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _generatePartyPDF(
                              partyName,
                              startDate,
                              endDate,
                              partyCode,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                '3-tlg',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Einzel Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _generateSinglePartyPDF(
                              partyName,
                              startDate,
                              endDate,
                              partyCode,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                'Einzel',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // QR-Code speichern Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _saveQRCodeAsImage(context, pwaUrl, partyCode, partyName, startDate);
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
                              const Icon(Icons.image, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                'Speichern',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Formatiere Countdown für bevorstehende Partys
  String _formatCountdown(DateTime startDate) {
    final now = DateTime.now();
    final difference = startDate.difference(now);
    
    if (difference.isNegative) {
      return 'Gestartet';
    }
    
    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final days = difference.inDays;
    
    // Wenn mehr als 24 Stunden: Tage, Stunden, Minuten
    if (totalHours >= 24) {
      final hours = totalHours % 24;
      final minutes = totalMinutes % 60;
      
      if (hours == 0 && minutes == 0) {
        return '$days Tag${days != 1 ? 'e' : ''}';
      } else if (hours == 0) {
        return '$days Tag${days != 1 ? 'e' : ''}, $minutes Minute${minutes != 1 ? 'n' : ''}';
      } else if (minutes == 0) {
        return '$days Tag${days != 1 ? 'e' : ''}, $hours Stunde${hours != 1 ? 'n' : ''}';
      } else {
        return '$days Tag${days != 1 ? 'e' : ''}, $hours Stunde${hours != 1 ? 'n' : ''}, $minutes Minute${minutes != 1 ? 'n' : ''}';
      }
    } else {
      // Weniger als 24 Stunden: Stunden und Minuten
      final hours = totalHours;
      final minutes = totalMinutes % 60;
      
      if (hours == 0 && minutes == 0) {
        return 'Startet jetzt';
      } else if (hours == 0) {
        return '$minutes Minute${minutes != 1 ? 'n' : ''}';
      } else if (minutes == 0) {
        return '$hours Stunde${hours != 1 ? 'n' : ''}';
      } else {
        return '$hours Stunde${hours != 1 ? 'n' : ''}, $minutes Minute${minutes != 1 ? 'n' : ''}';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Überschrift
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                'Party-Verwaltung',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // Liste der Partys
            Expanded(
              child: StreamBuilder<DateTime>(
                stream: _timeStream,
                builder: (context, timeSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('parties')
                        .orderBy('start_date', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Fehler: ${snapshot.error}'),
                        );
                      }
                      final parties = snapshot.data?.docs ?? [];
                      
                      // Filtere Partys: nur bevorstehende und laufende
                      final now = DateTime.now();
                      final activeParties = parties.where((party) {
                        final data = party.data() as Map<String, dynamic>;
                        final startTimestamp = data['start_date'] as Timestamp?;
                        final endTimestamp = data['end_date'] as Timestamp?;
                        
                        if (startTimestamp == null || endTimestamp == null) {
                          return false;
                        }
                        
                        final startDate = startTimestamp.toDate();
                        final endDate = endTimestamp.toDate();
                        final status = _getPartyStatus(startDate, endDate);
                        
                        // Nur bevorstehende und laufende Partys
                        return status == 'Bevorstehend' || status == 'Läuft';
                      }).toList();
                      
                      // Sortiere: Bevorstehende Partys zuerst (nach Startdatum aufsteigend), dann laufende
                      activeParties.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final startTimestampA = dataA['start_date'] as Timestamp?;
                        final startTimestampB = dataB['start_date'] as Timestamp?;
                        final endTimestampA = dataA['end_date'] as Timestamp?;
                        final endTimestampB = dataB['end_date'] as Timestamp?;
                        
                        if (startTimestampA == null || startTimestampB == null ||
                            endTimestampA == null || endTimestampB == null) {
                          return 0;
                        }
                        
                        final startDateA = startTimestampA.toDate();
                        final startDateB = startTimestampB.toDate();
                        final endDateA = endTimestampA.toDate();
                        final endDateB = endTimestampB.toDate();
                        
                        final statusA = _getPartyStatus(startDateA, endDateA);
                        final statusB = _getPartyStatus(startDateB, endDateB);
                        
                        // Bevorstehende Partys kommen vor laufenden
                        if (statusA == 'Bevorstehend' && statusB == 'Läuft') {
                          return -1;
                        }
                        if (statusA == 'Läuft' && statusB == 'Bevorstehend') {
                          return 1;
                        }
                        
                        // Innerhalb derselben Kategorie: nach Startdatum sortieren (aufsteigend)
                        return startDateA.compareTo(startDateB);
                      });
                      
                      // Zähle beendete Partys
                      final endedPartiesCount = parties.where((party) {
                        final data = party.data() as Map<String, dynamic>;
                        final startTimestamp = data['start_date'] as Timestamp?;
                        final endTimestamp = data['end_date'] as Timestamp?;
                        
                        if (startTimestamp == null || endTimestamp == null) {
                          return false;
                        }
                        
                        final startDate = startTimestamp.toDate();
                        final endDate = endTimestamp.toDate();
                        final status = _getPartyStatus(startDate, endDate);
                        
                        return status == 'Beendet';
                      }).length;
                      
                      return Column(
                        children: [
                          Expanded(
                            child: activeParties.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Keine aktiven Partys',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: activeParties.length,
                                itemBuilder: (context, index) {
                                  final party = activeParties[index];
                                  final data = party.data() as Map<String, dynamic>;
                                  final partyName = data['party_name'] as String? ?? 'Unbenannte Party';
                                  final startTimestamp = data['start_date'] as Timestamp?;
                                  final endTimestamp = data['end_date'] as Timestamp?;
                                  
                                  if (startTimestamp == null || endTimestamp == null) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  final startDate = startTimestamp.toDate();
                                  final endDate = endTimestamp.toDate();
                                  final status = _getPartyStatus(startDate, endDate);
                                  final partyCode = data['party_code'] as String?;
                                  
                                  final partyId = party.id;
                                  final hasNotStarted = DateTime.now().compareTo(startDate) < 0;
                                  
                                  return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: partyCode != null
                              ? IconButton(
                                  icon: const Icon(Icons.qr_code),
                                  onPressed: () {
                                    _showQRCodeDialog(
                                      context,
                                      partyName,
                                      startDate,
                                      endDate,
                                      partyCode,
                                    );
                                  },
                                  tooltip: 'QR-Code anzeigen',
                                )
                              : null,
                          title: Text(
                            partyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text('Start: ${_formatDateTime(startDate)}'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text('Ende: ${_formatDateTime(endDate)}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Bearbeiten-Icon (immer sichtbar) - klein und quadratisch
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      iconSize: 16,
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        _showEditPartyDialog(
                                          context,
                                          partyId,
                                          partyName,
                                          startDate,
                                          endDate,
                                          data['party_type'] as String?,
                                        );
                                      },
                                      tooltip: 'Bearbeiten',
                                    ),
                                  ),
                                  // Löschen-Icon (nur wenn Party noch nicht angefangen hat) - klein und quadratisch
                                  if (hasNotStarted) ...[
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        iconSize: 16,
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          _confirmDeleteParty(context, partyId, partyName);
                                        },
                                        tooltip: 'Löschen',
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getPartyStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getPartyStatusColor(status),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: _getPartyStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Countdown für bevorstehende Partys in separater Zeile
                              if (status == 'Bevorstehend') ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'in: ${_formatCountdown(startDate)}',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                                },
                              ),
                            ),
                      // Button "Beendet" außerhalb der ListView, damit er immer sichtbar ist
                      if (endedPartiesCount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BeendetePartysPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.history),
                            label: Text('Beendet ($endedPartiesCount)'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.grey[800],
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            // Button "Neue Party anlegen"
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NeuePartyPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Neue Party anlegen'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Zeigt Bearbeitungs-Dialog für Party
  void _showEditPartyDialog(
    BuildContext context,
    String partyId,
    String currentPartyName,
    DateTime currentStartDate,
    DateTime currentEndDate,
    String? currentPartyType,
  ) {
    final partyNameController = TextEditingController(text: currentPartyName);
    DateTime? startDate = currentStartDate;
    TimeOfDay? startTime = TimeOfDay.fromDateTime(currentStartDate);
    DateTime? endDate = currentEndDate;
    TimeOfDay? endTime = TimeOfDay.fromDateTime(currentEndDate);
    String? partyType = currentPartyType ?? 'private';
    final hasNotStarted = DateTime.now().compareTo(currentStartDate) < 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Party bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Party-Name (nur bearbeitbar wenn noch nicht begonnen)
                    if (hasNotStarted) ...[
                      TextFormField(
                        controller: partyNameController,
                        decoration: const InputDecoration(
                          labelText: 'Name der Party',
                          border: OutlineInputBorder(),
                        ),
                        enabled: hasNotStarted,
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        'Name: $currentPartyName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Party-Typ (nur bearbeitbar wenn noch nicht begonnen)
                    if (hasNotStarted) ...[
                      const Text('Art der Veranstaltung:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'private',
                              groupValue: partyType,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              onChanged: (value) {
                                setDialogState(() {
                                  partyType = value;
                                });
                              },
                              title: const Text('Privat', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'public',
                              groupValue: partyType,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              onChanged: (value) {
                                setDialogState(() {
                                  partyType = value;
                                });
                              },
                              title: const Text('Öffentlich', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        'Art: ${partyType == 'public' ? 'Öffentlich' : 'Privat'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Start-Datum und Start-Uhrzeit (nur bearbeitbar wenn Party noch nicht begonnen)
                    if (hasNotStarted) ...[
                      const Text('Start:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Datum:', style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: startDate ?? currentStartDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        startDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            startDate != null
                                                ? '${startDate!.day.toString().padLeft(2, '0')}.${startDate!.month.toString().padLeft(2, '0')}.${startDate!.year}'
                                                : 'Nicht ausgewählt',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 14),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Zeit:', style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: startTime ?? TimeOfDay.fromDateTime(currentStartDate),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        startTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            startTime != null
                                                ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')} Uhr'
                                                : 'Nicht ausgewählt',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 14),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        'Start: ${_formatDateTime(currentStartDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // End-Datum und End-Uhrzeit (immer bearbeitbar)
                    const Text('Ende:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Datum:', style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: endDate ?? currentEndDate,
                                    firstDate: hasNotStarted ? (startDate ?? currentStartDate) : currentStartDate,
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      endDate = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          endDate != null
                                              ? '${endDate!.day.toString().padLeft(2, '0')}.${endDate!.month.toString().padLeft(2, '0')}.${endDate!.year}'
                                              : 'Nicht ausgewählt',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 14),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Zeit:', style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: endTime ?? TimeOfDay.fromDateTime(currentEndDate),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      endTime = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          endTime != null
                                              ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')} Uhr'
                                              : 'Nicht ausgewählt',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 14),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validierung für Start-Datum/Zeit (wenn bearbeitbar)
                    DateTime newStartDateTime = currentStartDate;
                    if (hasNotStarted) {
                      if (startDate == null || startTime == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bitte wähle Start-Datum und Start-Uhrzeit aus.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      newStartDateTime = DateTime(
                        startDate!.year,
                        startDate!.month,
                        startDate!.day,
                        startTime!.hour,
                        startTime!.minute,
                      );
                    }
                    
                    // Validierung für End-Datum/Zeit
                    if (endDate == null || endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bitte wähle End-Datum und End-Uhrzeit aus.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final newEndDateTime = DateTime(
                      endDate!.year,
                      endDate!.month,
                      endDate!.day,
                      endTime!.hour,
                      endTime!.minute,
                    );

                    if (newEndDateTime.isBefore(newStartDateTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Das Enddatum muss nach dem Startdatum liegen.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      final updateData = <String, dynamic>{
                        'end_date': Timestamp.fromDate(newEndDateTime),
                      };

                      if (hasNotStarted) {
                        updateData['party_name'] = sanitizeInput(partyNameController.text.trim());
                        updateData['party_type'] = partyType;
                        updateData['start_date'] = Timestamp.fromDate(newStartDateTime);
                      }

                      await FirebaseFirestore.instance
                          .collection('parties')
                          .doc(partyId)
                          .update(updateData);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Party wurde erfolgreich aktualisiert.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fehler beim Aktualisieren: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Bestätigt und löscht eine Party
  Future<void> _confirmDeleteParty(BuildContext context, String partyId, String partyName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Party löschen'),
          content: Text('Möchtest du die Party "$partyName" wirklich löschen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('parties')
            .doc(partyId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Party wurde erfolgreich gelöscht.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Löschen: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Seite für beendete Partys
class BeendetePartysPage extends StatefulWidget {
  const BeendetePartysPage({super.key});

  @override
  State<BeendetePartysPage> createState() => _BeendetePartysPageState();
}

class _BeendetePartysPageState extends State<BeendetePartysPage> {
  StreamController<DateTime>? _timeController;
  Timer? _timeTimer;
  
  // Stream für periodische Zeit-Updates (für Countdowns)
  Stream<DateTime> get _timeStream => _timeController!.stream;

  @override
  void initState() {
    super.initState();
    _timeController = StreamController<DateTime>();
    _timeController!.add(DateTime.now());
    _timeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_timeController!.isClosed && mounted) {
        _timeController!.add(DateTime.now());
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _timeController?.close();
    super.dispose();
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year um $hour:$minute Uhr';
  }

  // Formatiert DateTime für Bild (kompakt)
  String _formatDateTimeForImage(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }

  // Formatiert Datum für Party Extra Dialog
  String _formatDateForPartyExtra(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day.$month.$year';
  }

  // Formatiert Uhrzeit für Party Extra Dialog
  String _formatTimeForPartyExtra(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute Uhr';
  }

  String _getPartyStatus(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende (Endzeit ist exklusiv)
    if (now.compareTo(startDate) < 0) {
      return 'Bevorstehend';
    } else if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
      return 'Läuft';
    } else {
      return 'Beendet';
    }
  }

  Color _getPartyStatusColor(String status) {
    switch (status) {
      case 'Bevorstehend':
        return Colors.blue;
      case 'Läuft':
        return Colors.green;
      case 'Beendet':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Formatiert DateTime kompakt für beendete Partys (09.12.25 19:03 Uhr)
  String _formatDateTimeCompact(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2); // Nur letzte 2 Ziffern
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }
  
  // Erstellt eine Spalte für die Party-Informationen
  pw.Widget _buildPartyColumn(
    String partyName,
    DateTime startDate,
    String pwaUrl,
    String partyCode,
    pw.ImageProvider? logoImage,
    pw.ImageProvider? djWbLogoImage,
  ) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          // Überschrift oben in jeder Spalte
          pw.Text(
            'Hier kannst Du dem DJ Deine Musikwünsche mitteilen',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 16),
          // Partyname
          pw.Text(
            partyName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 12),
          // Beginndatum
          pw.Text(
            _formatDateTimeForPDF(startDate),
            style: const pw.TextStyle(fontSize: 12),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 20),
          // QR-Code
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: pwaUrl,
            width: 180,
            height: 180,
          ),
          pw.SizedBox(height: 12),
          // Code unter dem QR-Code (kleiner)
          pw.Text(
            partyCode,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 3,
            ),
            textAlign: pw.TextAlign.center,
          ),
          // Logo (falls vorhanden)
          if (logoImage != null) ...[
            pw.SizedBox(height: 16),
            pw.Image(logoImage, width: 180, fit: pw.BoxFit.contain),
          ],
          // Website-Adresse
          pw.SizedBox(height: 8),
          pw.Text(
            'www.dj-ollerganove.de',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
          // Fußzeile mit DJ-WB Logo und Text
          pw.Spacer(),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (djWbLogoImage != null) ...[
                pw.Image(djWbLogoImage, width: 40, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 8),
              ],
              pw.Text(
                'a creation by DJ Ollerganove',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Generiert eine PDF-Datei mit Party-Informationen und QR-Code
  Future<void> _generatePartyPDF(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode,
  ) async {
    try {
      final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
      
      // Lade Logo (logo.png für oben)
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logo.png');
        final logoUint8List = logoBytes.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoUint8List);
        print('✅ logo.png Logo erfolgreich geladen');
      } catch (e) {
        print('❌ Fehler beim Laden des logo.png Logos: $e');
        // Kein Fallback - Logo bleibt null wenn es nicht geladen werden kann
      }
      
      // Lade DJ-WB.png Logo für die Fußzeile
      pw.ImageProvider? djWbLogoImage;
      try {
        final djWbLogoBytes = await rootBundle.load('assets/DJ-WB.png');
        final djWbLogoUint8List = djWbLogoBytes.buffer.asUint8List();
        djWbLogoImage = pw.MemoryImage(djWbLogoUint8List);
        print('✅ DJ-WB.png Logo erfolgreich geladen');
      } catch (e) {
        print('❌ Fehler beim Laden des DJ-WB.png Logos: $e');
      }
      
      // Erstelle PDF im Querformat
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Spalte 1
                _buildPartyColumn(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
                // Spalte 2
                _buildPartyColumn(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
                // Spalte 3
                _buildPartyColumn(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage),
              ],
            );
          },
        ),
      );
      
      // Zeige PDF-Vorschau und Download-Dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Generiert eine einzelne Spalte PDF im Hochformat
  Future<void> _generateSinglePartyPDF(
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode,
  ) async {
    try {
      final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
      
      // Lade Logo (logo.png für oben)
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logo.png');
        final logoUint8List = logoBytes.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoUint8List);
      } catch (e) {
        print('❌ Fehler beim Laden des logo.png Logos: $e');
      }
      
      // Lade DJ-WB.png Logo für die Fußzeile
      pw.ImageProvider? djWbLogoImage;
      try {
        final djWbLogoBytes = await rootBundle.load('assets/DJ-WB.png');
        final djWbLogoUint8List = djWbLogoBytes.buffer.asUint8List();
        djWbLogoImage = pw.MemoryImage(djWbLogoUint8List);
      } catch (e) {
        print('❌ Fehler beim Laden des DJ-WB.png Logos: $e');
      }
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return _buildPartyColumn(partyName, startDate, pwaUrl, partyCode, logoImage, djWbLogoImage);
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Formatiert DateTime für PDF (ohne "um")
  String _formatDateTimeForPDF(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }

  // Speichert QR-Code mit Party-Code als Bild
  Future<void> _saveQRCodeAsImage(
    BuildContext context,
    String pwaUrl,
    String partyCode,
    String partyName,
    DateTime startDate,
  ) async {
    try {
      // Erstelle ein Bild mit QR-Code und Party-Code
      const qrSize = 500.0;
      const padding = 40.0;
      const textHeight = 60.0;
      const titleHeight = 80.0;
      const dateHeight = 50.0;
      const spacing = 20.0;
      const totalHeight = titleHeight + spacing + dateHeight + spacing + qrSize + spacing + textHeight;
      const totalWidth = qrSize + (padding * 2);

      // Erstelle ein PictureRecorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Weißer Hintergrund
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, totalWidth, totalHeight),
        whitePaint,
      );

      double currentY = padding;

      // Zeichne Party-Titel über dem QR-Code
      final titleStyle = TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      );
      final titleSpan = TextSpan(
        text: partyName,
        style: titleStyle,
      );
      final titlePainter = TextPainter(
        text: titleSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      );
      titlePainter.layout(maxWidth: qrSize);
      final titleX = (totalWidth - titlePainter.width) / 2;
      titlePainter.paint(canvas, Offset(titleX, currentY));
      currentY += titlePainter.height + spacing;

      // Zeichne Party-Datum
      final dateText = _formatDateTimeForImage(startDate);
      final dateStyle = TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      );
      final dateSpan = TextSpan(
        text: dateText,
        style: dateStyle,
      );
      final datePainter = TextPainter(
        text: dateSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      datePainter.layout(maxWidth: qrSize);
      final dateX = (totalWidth - datePainter.width) / 2;
      datePainter.paint(canvas, Offset(dateX, currentY));
      currentY += datePainter.height + spacing;

      // Zeichne QR-Code
      final qrPainter = QrPainter(
        data: pwaUrl,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      
      // Verschiebe Canvas für QR-Code (zentriert)
      canvas.save();
      canvas.translate(padding, currentY);
      qrPainter.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
      currentY += qrSize + spacing;

      // Zeichne Party-Code Text unter dem QR-Code
      final textStyle = TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 4,
        color: Colors.black,
      );
      final textSpan = TextSpan(
        text: partyCode,
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Zentriere den Text
      final textX = (totalWidth - textPainter.width) / 2;
      textPainter.paint(canvas, Offset(textX, currentY));

      // Konvertiere zu Bild
      final picture = recorder.endRecording();
      final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Speichere das Bild direkt in der Galerie
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: 'QR_Code_$partyCode',
      );

      if (context.mounted) {
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR-Code wurde in der Galerie gespeichert'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler beim Speichern in der Galerie'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Fehler beim Speichern des QR-Codes: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Zeigt einen Dialog mit QR-Code für die Party
  void _showQRCodeDialog(
    BuildContext context,
    String partyName,
    DateTime startDate,
    DateTime endDate,
    String partyCode,
  ) {
    // PWA-URL mit Code als Parameter
    final pwaUrl = 'https://dj-ollerganove.web.app/?code=$partyCode';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Titel
                  Text(
                    partyName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                            Text(
                              'Beginn: ${_formatDateForPartyExtra(startDate)} - ${_formatTimeForPartyExtra(startDate)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Ende: ${_formatDateForPartyExtra(endDate)} - ${_formatTimeForPartyExtra(endDate)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.left,
                        ),
                          ],
                      ),
                    ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // QR-Code mit Code darunter
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: pwaUrl,
                          version: QrVersions.auto,
                          size: 250,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          partyCode,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Buttons nebeneinander
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 3-tlg Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _generatePartyPDF(
                              partyName,
                              startDate,
                              endDate,
                              partyCode,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                '3-tlg',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Einzel Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _generateSinglePartyPDF(
                              partyName,
                              startDate,
                              endDate,
                              partyCode,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                'Einzel',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // QR-Code speichern Button
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _saveQRCodeAsImage(context, pwaUrl, partyCode, partyName, startDate);
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
                              const Icon(Icons.image, size: 20),
                              const SizedBox(height: 2),
                              const Text(
                                'Speichern',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Beendete Partys'),
      ),
      body: SafeArea(
        child: StreamBuilder<DateTime>(
          stream: _timeStream,
          builder: (context, timeSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('parties')
                  .orderBy('start_date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Fehler: ${snapshot.error}'),
                  );
                }
                final parties = snapshot.data?.docs ?? [];
                
                // Filtere nur beendete Partys
                final endedParties = parties.where((party) {
                  final data = party.data() as Map<String, dynamic>;
                  final startTimestamp = data['start_date'] as Timestamp?;
                  final endTimestamp = data['end_date'] as Timestamp?;
                  
                  if (startTimestamp == null || endTimestamp == null) {
                    return false;
                  }
                  
                  final startDate = startTimestamp.toDate();
                  final endDate = endTimestamp.toDate();
                  final status = _getPartyStatus(startDate, endDate);
                  
                  return status == 'Beendet';
                }).toList();
                
                if (endedParties.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Keine beendeten Partys',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: endedParties.length,
              itemBuilder: (context, index) {
                final party = endedParties[index];
                final data = party.data() as Map<String, dynamic>;
                final partyName = data['party_name'] as String? ?? 'Unbenannte Party';
                final startTimestamp = data['start_date'] as Timestamp?;
                final endTimestamp = data['end_date'] as Timestamp?;
                
                if (startTimestamp == null || endTimestamp == null) {
                  return const SizedBox.shrink();
                }
                
                final startDate = startTimestamp.toDate();
                final endDate = endTimestamp.toDate();
                final status = _getPartyStatus(startDate, endDate);
                final partyCode = data['party_code'] as String?;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      partyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text('${_formatDateTimeCompact(startDate)} - ${_formatDateTimeCompact(endDate)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getPartyStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getPartyStatusColor(status),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: _getPartyStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PartyStatistikPage(
                                      partyId: party.id,
                                      partyName: partyName,
                                      startDate: startDate,
                                      endDate: endDate,
                                      partyCode: partyCode ?? '',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.bar_chart, size: 18),
                              label: const Text('Statistik'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
              },
            );
          },
        ),
      ),
    );
  }
}

// Hilfsklasse für Chart-Daten
class _PieChartData {
  final String category;
  final double value;
  final Color color;

  _PieChartData(this.category, this.value, this.color);
}

// Seite für Party-Statistik
class PartyStatistikPage extends StatefulWidget {
  final String partyId;
  final String partyName;
  final DateTime startDate;
  final DateTime endDate;
  final String partyCode;

  const PartyStatistikPage({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.startDate,
    required this.endDate,
    required this.partyCode,
  });

  @override
  State<PartyStatistikPage> createState() => _PartyStatistikPageState();
}

class _PartyStatistikPageState extends State<PartyStatistikPage> {
  int _totalWishes = 0;
  int _playedWishes = 0;
  int _rejectedWishes = 0;
  int _notPlayedWishes = 0;
  Map<int, int> _wishesPerHour = {}; // Stunde -> Anzahl Wünsche
  double _averagePlayTimeMinutes = 0.0; // Durchschnittliche Zeit bis zum Spielen in Minuten
  List<Map<String, dynamic>> _playedWishesList = []; // Liste der gespielten Wünsche (sortiert nach playedAt)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _closePendingWishesAndLoadStatistics();
  }

  // Schließt pending-Wünsche für diese Party und lädt dann die Statistik
  Future<void> _closePendingWishesAndLoadStatistics() async {
    try {
      // Prüfe zuerst, ob es noch pending-Wünsche für diese Party gibt
      final pendingWishesSnapshot = await FirebaseFirestore.instance
          .collection('wishes')
          .where('party_id', isEqualTo: widget.partyId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      
      // Nur Cloud Function aufrufen, wenn pending-Wünsche vorhanden sind
      if (pendingWishesSnapshot.docs.isNotEmpty) {
        print('Pending-Wünsche gefunden, rufe Cloud Function auf...');
        final functionUrl = 'https://us-central1-dj-ollerganove.cloudfunctions.net/closePendingWishesForEndedParty?partyId=${widget.partyId}';
        final response = await http.get(Uri.parse(functionUrl));
        
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          print('Cloud Function Ergebnis: $result');
        } else {
          print('Cloud Function Fehler: ${response.statusCode} - ${response.body}');
        }
      } else {
        print('Keine pending-Wünsche gefunden, überspringe Cloud Function');
      }
    } catch (e) {
      print('Fehler beim Prüfen/Aufruf: $e');
      // Weiter mit Statistik laden, auch wenn Fehler auftritt
    }
    
    // Lade Statistik nach dem Schließen der pending-Wünsche (oder direkt wenn keine vorhanden)
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Lade alle Wünsche für diese Party (ohne gelöschte)
      final wishesSnapshot = await FirebaseFirestore.instance
          .collection('wishes')
          .where('party_id', isEqualTo: widget.partyId)
          .get();

      int total = 0;
      int played = 0;
      int rejected = 0;
      int notPlayed = 0;
      Map<int, int> wishesPerHour = {}; // Stunde -> Anzahl Wünsche
      List<int> playTimeDurations = []; // Liste der Zeiten in Minuten zwischen createdAt und playedAt
      List<Map<String, dynamic>> playedWishesList = []; // Liste der gespielten Wünsche

      for (var doc in wishesSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        
        // Überspringe gelöschte Wünsche
        if (status == 'deleted') {
          continue;
        }

        total++;
        
        if (status == 'played') {
          played++;
          
          // Speichere gespielten Wunsch für PDF
          final title = (data['title'] ?? data['song'] ?? '') as String;
          final artist = (data['artist'] ?? '') as String;
          final playedAt = data['playedAt'] as Timestamp?;
          
          if (playedAt != null) {
            playedWishesList.add({
              'title': title,
              'artist': artist,
              'playedAt': playedAt,
            });
          }
          
          // Berechne Zeit zwischen Absendung und Spielen
          final createdAt = data['createdAt'] as Timestamp?;
          
          if (createdAt != null && playedAt != null) {
            final createdDate = createdAt.toDate();
            final playedDate = playedAt.toDate();
            final difference = playedDate.difference(createdDate);
            final minutes = difference.inMinutes.toDouble();
            if (minutes >= 0) { // Nur positive Werte berücksichtigen
              playTimeDurations.add(minutes.toInt());
            }
          }
        } else if (status == 'rejected') {
          rejected++;
        } else if (status == 'not_played') {
          notPlayed++;
        }
        // pending wird ignoriert, da es bei beendeten Partys nicht vorkommt
        
        // Gruppiere nach Stunden
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final date = createdAt.toDate();
          final hour = date.hour;
          wishesPerHour[hour] = (wishesPerHour[hour] ?? 0) + 1;
        }
      }
      
      // Sortiere gespielte Wünsche nach playedAt (chronologisch)
      playedWishesList.sort((a, b) {
        final playedAtA = a['playedAt'] as Timestamp;
        final playedAtB = b['playedAt'] as Timestamp;
        return playedAtA.compareTo(playedAtB);
      });
      
      // Berechne Durchschnitt
      double averagePlayTime = 0.0;
      if (playTimeDurations.isNotEmpty) {
        final totalMinutes = playTimeDurations.reduce((a, b) => a + b);
        averagePlayTime = totalMinutes / playTimeDurations.length;
      }

      setState(() {
        _totalWishes = total;
        _playedWishes = played;
        _rejectedWishes = rejected;
        _notPlayedWishes = notPlayed;
        _wishesPerHour = wishesPerHour;
        _averagePlayTimeMinutes = averagePlayTime;
        _playedWishesList = playedWishesList;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Statistiken: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year um $hour:$minute Uhr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party-Statistik'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Party-Daten
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.partyName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Party-Code: ${widget.partyCode}'),
                          const SizedBox(height: 4),
                          Text('Start: ${_formatDateTime(widget.startDate)}'),
                          const SizedBox(height: 4),
                          Text('Ende: ${_formatDateTime(widget.endDate)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Statistiken
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statistiken',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow('Gesamt Wünsche', _totalWishes.toString(), Colors.blue),
                          const SizedBox(height: 8),
                          _buildStatRow('Gespielte Songs', _playedWishes.toString(), Colors.green),
                          const SizedBox(height: 8),
                          _buildStatRow('Abgelehnte Songs', _rejectedWishes.toString(), Colors.red),
                          const SizedBox(height: 8),
                          _buildStatRow('Nicht gespielte Songs', _notPlayedWishes.toString(), Colors.orange),
                          if (_playedWishes > 0 && _averagePlayTimeMinutes > 0) ...[
                            const SizedBox(height: 8),
                            _buildStatRow(
                              'Ø Zeit bis zum Spielen',
                              '${_averagePlayTimeMinutes.toStringAsFixed(1)} Min',
                              Colors.purple,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Balkendiagramm: Wünsche pro Stunde
                  if (_wishesPerHour.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wünsche pro Stunde',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildBarChartWithPercentages(),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Kreisdiagramm
                  if (_totalWishes > 0)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Verteilung',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 250,
                              child: PieChart(
                                PieChartData(
                                  sections: _buildPieChartSections(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 60,
                                  startDegreeOffset: _calculateStartOffset(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLegend(),
                          ],
                        ),
                      ),
                    )
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('Keine Wünsche vorhanden'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // PDF-Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _generateSmallStatisticsPDF(),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Kleine Statistik'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _generateDetailedStatisticsPDF(),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Ausführliche Statistik'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Berechnet den Start-Offset, damit "nicht gespielte Songs" immer unten ist
  double _calculateStartOffset() {
    if (_totalWishes == 0) {
      return -90;
    }
    
    // Berechne die Winkel für gespielte und abgelehnte Songs
    final playedAngle = (_playedWishes / _totalWishes) * 360;
    final rejectedAngle = (_rejectedWishes / _totalWishes) * 360;
    
    // Der Offset muss so sein, dass nach gespielten + abgelehnten Songs
    // die "nicht gespielten Songs" unten (bei 90 Grad) starten
    // Standard-Start ist oben (-90 Grad), also müssen wir rotieren
    // bis "nicht gespielte Songs" unten ist
    final offset = -90 + playedAngle + rejectedAngle;
    
    return offset;
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final sections = <PieChartSectionData>[];
    
    if (_totalWishes == 0) {
      return sections;
    }

    final playedPercentage = (_playedWishes / _totalWishes) * 100;
    final rejectedPercentage = (_rejectedWishes / _totalWishes) * 100;
    final notPlayedPercentage = (_notPlayedWishes / _totalWishes) * 100;

    // Reihenfolge: Gespielte, Abgelehnte, Nicht gespielte (wird durch Offset unten positioniert)
    if (playedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _playedWishes.toDouble(),
          title: '${playedPercentage.toStringAsFixed(1)}%',
          color: Colors.green,
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (rejectedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _rejectedWishes.toDouble(),
          title: '${rejectedPercentage.toStringAsFixed(1)}%',
          color: Colors.red,
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Nicht gespielte Songs zuletzt - wird durch Offset unten positioniert
    if (notPlayedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _notPlayedWishes.toDouble(),
          title: '${notPlayedPercentage.toStringAsFixed(1)}%',
          color: Colors.orange,
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildLegend() {
    return Column(
      children: [
        _buildLegendItem('Gespielte Songs', Colors.green, _playedWishes),
        const SizedBox(height: 8),
        _buildLegendItem('Abgelehnte Songs', Colors.red, _rejectedWishes),
        const SizedBox(height: 8),
        _buildLegendItem('Nicht gespielte Songs', Colors.orange, _notPlayedWishes),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Einheitliche Farbe für alle Balken
  Color _getBarColor() {
    return Colors.blue;
  }

  List<BarChartGroupData> _buildBarChartGroups() {
    final groups = <BarChartGroupData>[];
    final color = _getBarColor();

    // Erstelle Gruppen für alle 24 Stunden (0-23)
    // Für horizontale Balken: x = Stunde (Y-Achse), toY = Anzahl (X-Achse)
    for (int hour = 0; hour < 24; hour++) {
      final count = _wishesPerHour[hour] ?? 0;

      groups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: color,
              width: 16,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
            ),
          ],
          barsSpace: 2,
        ),
      );
    }

    return groups;
  }

  // Formatiert DateTime für PDF
  String _formatDateTimeForPDF(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }

  // Generiert kleine Statistik-PDF
  Future<void> _generateSmallStatisticsPDF() async {
    try {
      // Lade DJ-WB.png Logo für die Fußzeile
      pw.ImageProvider? djWbLogoImage;
      try {
        final djWbLogoBytes = await rootBundle.load('assets/DJ-WB.png');
        final djWbLogoUint8List = djWbLogoBytes.buffer.asUint8List();
        djWbLogoImage = pw.MemoryImage(djWbLogoUint8List);
      } catch (e) {
        print('❌ Fehler beim Laden des DJ-WB.png Logos: $e');
      }

      // Erstelle das Kreisdiagramm-Widget
      final pieChartWidget = await _buildPieChartWidget();

      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Titel
                pw.Text(
                  widget.partyName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Party-Code: ${widget.partyCode}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Start: ${_formatDateTimeForPDF(widget.startDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Ende: ${_formatDateTimeForPDF(widget.endDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 24),
                
                // Statistiken und Verteilung nebeneinander
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Linke Spalte: Statistiken
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 1),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Statistiken',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            _buildPDFStatRow('Gesamt', _totalWishes.toString()),
                            pw.SizedBox(height: 6),
                            _buildPDFStatRow('Gespielt', _playedWishes.toString()),
                            pw.SizedBox(height: 6),
                            _buildPDFStatRow('Abgelehnt', _rejectedWishes.toString()),
                            pw.SizedBox(height: 6),
                            _buildPDFStatRow('Nicht gespielt', _notPlayedWishes.toString()),
                            if (_playedWishes > 0 && _averagePlayTimeMinutes > 0) ...[
                              pw.SizedBox(height: 6),
                              _buildPDFStatRow(
                                'Ø Zeit',
                                '${_averagePlayTimeMinutes.toStringAsFixed(1)} Min',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    // Rechte Spalte: Verteilung
                    if (_totalWishes > 0)
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 1),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Verteilung',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              _buildPDFStatRow('Gespielt', '${(_playedWishes / _totalWishes * 100).toStringAsFixed(1)}%'),
                              pw.SizedBox(height: 6),
                              _buildPDFStatRow('Abgelehnt', '${(_rejectedWishes / _totalWishes * 100).toStringAsFixed(1)}%'),
                              pw.SizedBox(height: 6),
                              _buildPDFStatRow('Nicht gespielt', '${(_notPlayedWishes / _totalWishes * 100).toStringAsFixed(1)}%'),
                              pw.SizedBox(height: 12),
                              // Kreisdiagramm
                              pw.Center(
                                child: pieChartWidget,
                              ),
                              pw.SizedBox(height: 8),
                              // Legende
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  if (_playedWishes > 0) ...[
                                    pw.Container(
                                      width: 8,
                                      height: 8,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.green,
                                        shape: pw.BoxShape.circle,
                                      ),
                                    ),
                                    pw.SizedBox(width: 4),
                                    pw.Text('Gespielt', style: const pw.TextStyle(fontSize: 8)),
                                  ],
                                  if (_playedWishes > 0 && _rejectedWishes > 0) pw.SizedBox(width: 8),
                                  if (_rejectedWishes > 0) ...[
                                    pw.Container(
                                      width: 8,
                                      height: 8,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.red,
                                        shape: pw.BoxShape.circle,
                                      ),
                                    ),
                                    pw.SizedBox(width: 4),
                                    pw.Text('Abgelehnt', style: const pw.TextStyle(fontSize: 8)),
                                  ],
                                  if ((_playedWishes > 0 || _rejectedWishes > 0) && _notPlayedWishes > 0) pw.SizedBox(width: 8),
                                  if (_notPlayedWishes > 0) ...[
                                    pw.Container(
                                      width: 8,
                                      height: 8,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.orange,
                                        shape: pw.BoxShape.circle,
                                      ),
                                    ),
                                    pw.SizedBox(width: 4),
                                    pw.Text('Nicht gespielt', style: const pw.TextStyle(fontSize: 8)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Fußzeile mit Logo
                pw.SizedBox(height: 24),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (djWbLogoImage != null) ...[
                      pw.Image(djWbLogoImage, width: 40, fit: pw.BoxFit.contain),
                      pw.SizedBox(width: 8),
                    ],
                    pw.Text(
                      'a creation by DJ Ollerganove',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Generiert ausführliche Statistik-PDF
  Future<void> _generateDetailedStatisticsPDF() async {
    try {
      // Lade DJ-WB.png Logo für die Fußzeile
      pw.ImageProvider? djWbLogoImage;
      try {
        final djWbLogoBytes = await rootBundle.load('assets/DJ-WB.png');
        final djWbLogoUint8List = djWbLogoBytes.buffer.asUint8List();
        djWbLogoImage = pw.MemoryImage(djWbLogoUint8List);
      } catch (e) {
        print('❌ Fehler beim Laden des DJ-WB.png Logos: $e');
      }

      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Titel
                pw.Text(
                  widget.partyName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Party-Code: ${widget.partyCode}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Start: ${_formatDateTimeForPDF(widget.startDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Ende: ${_formatDateTimeForPDF(widget.endDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 24),
                
                // Statistiken (wie in kleiner Statistik)
                pw.Text(
                  'Statistiken',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildPDFStatRow('Gesamt Wünsche', _totalWishes.toString()),
                pw.SizedBox(height: 8),
                _buildPDFStatRow('Gespielte Songs', _playedWishes.toString()),
                pw.SizedBox(height: 8),
                _buildPDFStatRow('Abgelehnte Songs', _rejectedWishes.toString()),
                pw.SizedBox(height: 8),
                _buildPDFStatRow('Nicht gespielte Songs', _notPlayedWishes.toString()),
                if (_playedWishes > 0 && _averagePlayTimeMinutes > 0) ...[
                  pw.SizedBox(height: 8),
                  _buildPDFStatRow(
                    'Ø Zeit bis zum Spielen',
                    '${_averagePlayTimeMinutes.toStringAsFixed(1)} Min',
                  ),
                ],
                pw.SizedBox(height: 24),
                
                // Wünsche pro Stunde
                if (_wishesPerHour.isNotEmpty) ...[
                  pw.Text(
                    'Wünsche pro Stunde',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  ...List.generate(24, (hour) {
                    final count = _wishesPerHour[hour] ?? 0;
                    if (count == 0) return pw.SizedBox.shrink();
                    final hourStr = hour.toString().padLeft(2, '0');
                    final percentage = _totalWishes > 0 ? (count / _totalWishes * 100) : 0.0;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        children: [
                          pw.Text('$hourStr Uhr:', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(width: 8),
                          pw.Text('$count', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('(${percentage.toStringAsFixed(1)}%)', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    );
                  }),
                  pw.SizedBox(height: 24),
                ],
                
                // Verteilung
                if (_totalWishes > 0) ...[
                  pw.Text(
                    'Verteilung',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildPDFStatRow('Gespielte Songs', '$_playedWishes (${(_playedWishes / _totalWishes * 100).toStringAsFixed(1)}%)'),
                  pw.SizedBox(height: 8),
                  _buildPDFStatRow('Abgelehnte Songs', '$_rejectedWishes (${(_rejectedWishes / _totalWishes * 100).toStringAsFixed(1)}%)'),
                  pw.SizedBox(height: 8),
                  _buildPDFStatRow('Nicht gespielte Songs', '$_notPlayedWishes (${(_notPlayedWishes / _totalWishes * 100).toStringAsFixed(1)}%)'),
                  pw.SizedBox(height: 24),
                ],
                
                // Gespielte Wünsche Liste
                if (_playedWishesList.isNotEmpty) ...[
                  pw.Text(
                    'Gespielte Songs',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  // 2-spaltige Liste
                  ...List.generate((_playedWishesList.length / 2).ceil(), (rowIndex) {
                    final leftIndex = rowIndex * 2;
                    final rightIndex = leftIndex + 1;
                    
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Linke Spalte
                          pw.Expanded(
                            child: pw.Text(
                              leftIndex < _playedWishesList.length
                                  ? '${leftIndex + 1}. ${_formatWishForPDF(_playedWishesList[leftIndex])}'
                                  : '',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.SizedBox(width: 16),
                          // Rechte Spalte
                          pw.Expanded(
                            child: pw.Text(
                              rightIndex < _playedWishesList.length
                                  ? '${rightIndex + 1}. ${_formatWishForPDF(_playedWishesList[rightIndex])}'
                                  : '',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  pw.SizedBox(height: 24),
                  // Fußzeile mit Logo
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (djWbLogoImage != null) ...[
                        pw.Image(djWbLogoImage, width: 40, fit: pw.BoxFit.contain),
                        pw.SizedBox(width: 8),
                      ],
                      pw.Text(
                        'a creation by DJ Ollerganove',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Generieren der PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Hilfsfunktion für PDF-Statistik-Zeilen
  pw.Widget _buildPDFStatRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // Formatiert Wunsch für PDF (Titel - Interpret)
  String _formatWishForPDF(Map<String, dynamic> wish) {
    final title = wish['title'] as String? ?? '';
    final artist = wish['artist'] as String? ?? '';
    
    if (title.isNotEmpty && artist.isNotEmpty) {
      return '$title - $artist';
    } else if (title.isNotEmpty) {
      return title;
    } else if (artist.isNotEmpty) {
      return artist;
    }
    return '';
  }

  // Erstellt ein Kreisdiagramm-Widget für PDF
  // Verwendet Syncfusion Charts für echtes Kreisdiagramm
  Future<pw.Widget> _buildPieChartWidget() async {
    if (_totalWishes == 0) {
      return pw.SizedBox.shrink();
    }

    try {
      // Rendere das Kreisdiagramm mit Syncfusion als Bild
      final imageBytes = await _renderPieChartWithSyncfusion();
      
      if (imageBytes != null && imageBytes.isNotEmpty) {
        return pw.Image(
          pw.MemoryImage(imageBytes),
          width: 120,
          height: 120,
        );
      }
    } catch (e) {
      print('Fehler beim Rendern des Kreisdiagramms mit Syncfusion: $e');
    }

    // Fallback: Einfache Darstellung
    return _buildSimplePieChartWidget();
  }

  // Rendert ein Kreisdiagramm mit Syncfusion Charts als PNG-Bild
  Future<Uint8List?> _renderPieChartWithSyncfusion() async {
    try {
      // Erstelle die Daten für das Kreisdiagramm
      final chartData = <_PieChartData>[];
      if (_playedWishes > 0) {
        chartData.add(_PieChartData('Gespielt', _playedWishes.toDouble(), Colors.green));
      }
      if (_rejectedWishes > 0) {
        chartData.add(_PieChartData('Abgelehnt', _rejectedWishes.toDouble(), Colors.red));
      }
      if (_notPlayedWishes > 0) {
        chartData.add(_PieChartData('Nicht gespielt', _notPlayedWishes.toDouble(), Colors.orange));
      }

      if (chartData.isEmpty) {
        return null;
      }

      // Erstelle einen GlobalKey für das Chart
      final chartKey = GlobalKey<sf_charts.SfCircularChartState>();

      // Erstelle das Chart-Widget
      final chartWidget = SizedBox(
        width: 120,
        height: 120,
        child: sf_charts.SfCircularChart(
          key: chartKey,
          series: <sf_charts.PieSeries<_PieChartData, String>>[
            sf_charts.PieSeries<_PieChartData, String>(
              dataSource: chartData,
              xValueMapper: (_PieChartData data, _) => data.category,
              yValueMapper: (_PieChartData data, _) => data.value,
              pointColorMapper: (_PieChartData data, _) => data.color,
              dataLabelSettings: const sf_charts.DataLabelSettings(
                isVisible: false, // Keine Labels für bessere Darstellung
              ),
            ),
          ],
          legend: const sf_charts.Legend(isVisible: false),
        ),
      );

      // Rendere das Widget als Bild mit der bestehenden Funktion
      // Diese Funktion rendert das Widget und konvertiert es zu PNG-Bytes
      return await _renderWidgetToImage(chartWidget, 120, 120);
    } catch (e, stackTrace) {
      print('Fehler bei Syncfusion Kreisdiagramm: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  // Erstellt ein einzelnes Segment des Kreisdiagramms (nicht mehr verwendet, aber für Fallback)
  pw.Widget _buildPieSegment({
    required PdfColor color,
    required double startAngle,
    required double sweepAngle,
    required double radius,
    required double percentage,
  }) {
    if (sweepAngle < 1) {
      return pw.SizedBox.shrink();
    }

    final size = radius * 2;
    final center = radius;

    // Für große Segmente (>= 180 Grad): Verwende einen vollen Kreis
    if (sweepAngle >= 180) {
      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          color: color,
          shape: pw.BoxShape.circle,
        ),
        child: percentage > 10
            ? pw.Center(
                child: pw.Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              )
            : pw.SizedBox.shrink(),
      );
    }

    // Für Segmente >= 90 Grad: Verwende einen Halbkreis mit korrekter Position
    if (sweepAngle >= 90) {
      // Normalisiere den Winkel auf 0-360
      final normalizedAngle = (startAngle % 360 + 360) % 360;
      
      // Bestimme Quadrant basierend auf Startwinkel
      double left = 0;
      double top = 0;
      pw.BorderRadius borderRadius;
      
      if (normalizedAngle >= 0 && normalizedAngle < 90) {
        // Rechts oben
        left = center;
        top = 0;
        borderRadius = pw.BorderRadius.only(
          topRight: pw.Radius.circular(radius),
        );
      } else if (normalizedAngle >= 90 && normalizedAngle < 180) {
        // Links oben
        left = 0;
        top = 0;
        borderRadius = pw.BorderRadius.only(
          topLeft: pw.Radius.circular(radius),
        );
      } else if (normalizedAngle >= 180 && normalizedAngle < 270) {
        // Links unten
        left = 0;
        top = center;
        borderRadius = pw.BorderRadius.only(
          bottomLeft: pw.Radius.circular(radius),
        );
      } else {
        // Rechts unten
        left = center;
        top = center;
        borderRadius = pw.BorderRadius.only(
          bottomRight: pw.Radius.circular(radius),
        );
      }

      return pw.Positioned(
        left: left,
        top: top,
        child: pw.Container(
          width: radius,
          height: radius,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: borderRadius,
          ),
        ),
      );
    }

    // Für kleine Segmente (< 90 Grad): Verwende einen kleinen farbigen Bereich
    // Positioniere basierend auf Startwinkel (Mitte des Segments)
    final normalizedAngle = (startAngle % 360 + 360) % 360;
    final midAngle = normalizedAngle + (sweepAngle / 2);
    final angleRad = midAngle * (pi / 180);
    final segmentSize = max((sweepAngle / 360) * size * 0.6, 8.0); // Mindestgröße 8
    
    // Berechne Position basierend auf Winkel (Mitte des Segments)
    final x = center + (center * 0.6) * cos(angleRad) - segmentSize / 2;
    final y = center + (center * 0.6) * sin(angleRad) - segmentSize / 2;

    return pw.Positioned(
      left: x.clamp(0.0, size - segmentSize),
      top: y.clamp(0.0, size - segmentSize),
      child: pw.Container(
        width: segmentSize,
        height: segmentSize,
        decoration: pw.BoxDecoration(
          color: color,
          shape: pw.BoxShape.circle,
        ),
      ),
    );
  }

  // Rendert ein Widget zu einem Bild (PNG-Bytes)
  // Verwendet einen vereinfachten Ansatz mit RenderRepaintBoundary
  Future<Uint8List?> _renderWidgetToImage(Widget widget, double width, double height) async {
    try {
      // Stelle sicher, dass Flutter initialisiert ist
      WidgetsFlutterBinding.ensureInitialized();
      
      // Erstelle einen GlobalKey für das RepaintBoundary
      final globalKey = GlobalKey();
      
      // Erstelle das Widget mit RepaintBoundary
      final repaintBoundary = RepaintBoundary(
        key: globalKey,
        child: SizedBox(
          width: width,
          height: height,
          child: widget,
        ),
      );
      
      // Erstelle einen neuen PipelineOwner und BuildOwner
      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());
      
      // Erstelle einen RenderConstrainedBox für die Größe
      final renderConstrainedBox = RenderConstrainedBox(
        additionalConstraints: BoxConstraints.tightFor(width: width, height: height),
      );
      
      // Hole den ersten verfügbaren FlutterView oder verwende einen Dummy
      ui.FlutterView? flutterView;
      try {
        final views = ui.PlatformDispatcher.instance.views;
        if (views.isNotEmpty) {
          flutterView = views.first;
        }
      } catch (e) {
        print('Kein FlutterView verfügbar: $e');
      }
      
      // Wenn kein FlutterView verfügbar ist, verwenden wir einen anderen Ansatz
      if (flutterView == null) {
        print('Kein FlutterView verfügbar, verwende Fallback');
        return null;
      }
      
      // Erstelle RenderView mit dem FlutterView
      final renderView = RenderView(
        view: flutterView,
        child: renderConstrainedBox,
      );
      
      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();
      
      // Erstelle das Element für das RepaintBoundary
      final element = repaintBoundary.createElement();
      element.mount(null, null);
      
      // Hole das RenderObject vom Element
      final renderObject = element.renderObject;
      if (renderObject is! RenderRepaintBoundary) {
        print('RenderObject ist kein RenderRepaintBoundary');
        return null;
      }
      
      // Setze das RenderObject als Child des RenderConstrainedBox
      renderConstrainedBox.child = renderObject;
      
      // Build und Layout durchführen
      buildOwner.buildScope(element);
      buildOwner.finalizeTree();
      
      // Layout, Compositing und Paint durchführen
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();
      
      // Warte, damit alles gerendert wird
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Konvertiere zu Bild
      final image = await renderObject.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      
      return null;
    } catch (e, stackTrace) {
      print('Fehler bei Widget-zu-Bild-Konvertierung: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  // Erstellt die PieChart-Sections für PDF (ähnlich wie auf der Seite)
  List<PieChartSectionData> _buildPieChartSectionsForPDF() {
    final sections = <PieChartSectionData>[];
    
    if (_totalWishes == 0) {
      return sections;
    }

    final playedPercentage = (_playedWishes / _totalWishes) * 100;
    final rejectedPercentage = (_rejectedWishes / _totalWishes) * 100;
    final notPlayedPercentage = (_notPlayedWishes / _totalWishes) * 100;

    // Reihenfolge: Gespielte, Abgelehnte, Nicht gespielte (wird durch Offset unten positioniert)
    if (playedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _playedWishes.toDouble(),
          title: '${playedPercentage.toStringAsFixed(1)}%',
          color: Colors.green,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (rejectedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _rejectedWishes.toDouble(),
          title: '${rejectedPercentage.toStringAsFixed(1)}%',
          color: Colors.red,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (notPlayedPercentage > 0) {
      sections.add(
        PieChartSectionData(
          value: _notPlayedWishes.toDouble(),
          title: '${notPlayedPercentage.toStringAsFixed(1)}%',
          color: Colors.orange,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  // Einfache Fallback-Darstellung
  pw.Widget _buildSimplePieChartWidget() {
    final playedPercent = (_playedWishes / _totalWishes) * 100;
    final rejectedPercent = (_rejectedWishes / _totalWishes) * 100;
    final notPlayedPercent = (_notPlayedWishes / _totalWishes) * 100;

    PdfColor mainColor;
    double mainPercent;
    if (playedPercent >= rejectedPercent && playedPercent >= notPlayedPercent) {
      mainColor = PdfColors.green;
      mainPercent = playedPercent;
    } else if (rejectedPercent >= notPlayedPercent) {
      mainColor = PdfColors.red;
      mainPercent = rejectedPercent;
    } else {
      mainColor = PdfColors.orange;
      mainPercent = notPlayedPercent;
    }

    return pw.Container(
      width: 120,
      height: 120,
      decoration: pw.BoxDecoration(
        color: mainColor,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
      ),
      child: pw.Center(
        child: pw.Text(
          '${mainPercent.toStringAsFixed(0)}%',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    );
  }

  // Erstellt ein horizontales Balkendiagramm
  Widget _buildBarChartWithPercentages() {
    if (_totalWishes == 0) {
      return const SizedBox.shrink();
    }

    final maxCount = _wishesPerHour.values.isEmpty 
        ? 0 
        : _wishesPerHour.values.reduce((a, b) => a > b ? a : b);
    final maxY = ((maxCount / 5).ceil() * 5); // Runde auf nächste 5er-Stelle
    final availableWidth = MediaQuery.of(context).size.width - 120; // -120 für Labels und Padding
    final barHeight = 16.0;
    final barSpacing = 4.0;
    final totalBarHeight = (barHeight + barSpacing) * 24;
    
    return SizedBox(
      height: totalBarHeight + 60, // +60 für X-Achse Labels
      child: Column(
        children: [
          // Y-Achse Label (Stunden) und Balken
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Y-Achse: Stunden 01-23
                SizedBox(
                  width: 40,
                  child: Column(
                    children: List.generate(24, (hour) {
                      final hourStr = hour.toString().padLeft(2, '0');
                      return SizedBox(
                        height: barHeight + barSpacing,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              hourStr,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Balken und X-Achse
                Expanded(
                  child: Stack(
                    children: [
                      // Grid-Linien (vertikal für X-Achse)
                      ...List.generate((maxY ~/ 5) + 1, (index) {
                        final value = index * 5;
                        final xPosition = (value / maxY) * availableWidth;
                        return Positioned(
                          left: xPosition,
                          top: 0,
                          bottom: 40,
                          child: Container(
                            width: 1,
                            color: Colors.grey[300],
                          ),
                        );
                      }),
                      // Balken
                      ...List.generate(24, (hour) {
                        final count = _wishesPerHour[hour] ?? 0;
                        final barLength = maxY > 0 ? (count / maxY) * availableWidth : 0.0;
                        final barY = hour * (barHeight + barSpacing);
                        final percentage = count > 0 ? ((count / _totalWishes) * 100) : 0.0;
                        
                        return Positioned(
                          left: 0,
                          top: barY,
                          child: Row(
                            children: [
                              // Balken mit Prozentangabe drin
                              if (count > 0)
                                Stack(
                                  children: [
                                    Container(
                                      width: barLength,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: _getBarColor(),
                                        borderRadius: const BorderRadius.horizontal(
                                          right: Radius.circular(4),
                                        ),
                                      ),
                                    ),
                                    // Prozentangabe in weiß im Balken
                                    if (barLength > 30) // Nur anzeigen wenn Balken breit genug
                                      Positioned(
                                        left: 4,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: Text(
                                            '${percentage.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              // Anzahl der Wünsche rechts neben dem Balken
                              if (count > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  count.toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      // X-Achse Labels (unten)
                      ...List.generate((maxY ~/ 5) + 1, (index) {
                        final value = index * 5;
                        final xPosition = (value / maxY) * availableWidth;
                        return Positioned(
                          left: xPosition - 10,
                          bottom: 0,
                          child: Text(
                            value.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Seite zum Anlegen einer neuen Party
class NeuePartyPage extends StatefulWidget {
  const NeuePartyPage({super.key});

  @override
  State<NeuePartyPage> createState() => _NeuePartyPageState();
}

class _NeuePartyPageState extends State<NeuePartyPage> {
  final _formKey = GlobalKey<FormState>();
  final _partyNameController = TextEditingController();
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  String _partyType = 'private'; // Standard: privat
  bool _isLoading = false;

  @override
  void dispose() {
    _partyNameController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()).add(const Duration(hours: 1)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _saveParty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _startTime == null || _endDate == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle alle Datums- und Uhrzeiten aus.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Das Enddatum muss nach dem Startdatum liegen.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('=== Speichere Party ===');
      print('Party Name: ${_partyNameController.text.trim()}');
      print('Start DateTime: $startDateTime');
      print('End DateTime: $endDateTime');
      print('Start Timestamp: ${Timestamp.fromDate(startDateTime)}');
      print('End Timestamp: ${Timestamp.fromDate(endDateTime)}');
      
      // Generiere einen zufälligen 4-stelligen Code
      final random = Random();
      final partyCode = (1000 + random.nextInt(9000)).toString(); // 1000-9999
      
      // Hole aktuellen User (DJ)
      final user = FirebaseAuth.instance.currentUser;
      final createdBy = user?.uid ?? '';
      final createdByEmail = user?.email ?? '';
      
      final docRef = await FirebaseFirestore.instance
          .collection('parties')
          .add({
        'party_name': sanitizeInput(_partyNameController.text.trim()),
        'start_date': Timestamp.fromDate(startDateTime),
        'end_date': Timestamp.fromDate(endDateTime),
        'created_at': Timestamp.now(),
        'party_code': partyCode, // 4-stelliger Code
        'party_type': _partyType, // 'private' oder 'public'
        'created_by': createdBy, // User-ID des DJs
        'created_by_email': createdByEmail, // Email des DJs
      });
      
      print('Party gespeichert mit ID: ${docRef.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Party wurde erfolgreich angelegt.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Zurück zur Übersicht
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nicht ausgewählt';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Nicht ausgewählt';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} Uhr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Überschrift
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Neue Party anlegen',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                // Art der Veranstaltung (muss ausgewählt werden)
                const Text(
                  'Art der Veranstaltung:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Privat'),
                        value: 'private',
                        groupValue: _partyType,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (value) {
                          setState(() {
                            _partyType = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Öffentlich'),
                        value: 'public',
                        groupValue: _partyType,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (value) {
                          setState(() {
                            _partyType = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Party-Name
                TextFormField(
                  controller: _partyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Name der Party',
                    hintText: 'z.B. Geburtstagsfeier, Hochzeit, etc.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte gib einen Partynamen ein.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Beginn
                const Text(
                  'Beginn:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Datum:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _selectStartDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatDate(_startDate),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Zeit:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _selectStartTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatTime(_startTime),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Ende
                const Text(
                  'Ende:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Datum:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _selectEndDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatDate(_endDate),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Zeit:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _selectEndTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatTime(_endTime),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Speichern-Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveParty,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Party-Daten speichern'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Admin-Seiten für Status-Filterung
class OffenPage extends StatefulWidget {
  final VoidCallback? onPageOpened;
  
  const OffenPage({super.key, this.onPageOpened});

  @override
  State<OffenPage> createState() => _OffenPageState();
}

class _OffenPageState extends State<OffenPage> {
  Stream<DocumentSnapshot>? _lastViewedStream;
  
  @override
  void initState() {
    super.initState();
    // Initialisiere Stream einmalig
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == 'info@dj-ollerganove.de') {
      _lastViewedStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
  }
  
  // Wird von MainPage aufgerufen, wenn die Seite verlassen wird
  void onPageLeft() {
    _markWishesAsViewedOnPageExit();
  }

  // Wird von MainPage aufgerufen, wenn zur Seite zurückgekehrt wird
  void onPageReturned() {
    // Kein Refresh mehr nötig - Stream aktualisiert automatisch
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _markWishesAsViewedOnPageExit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email != 'info@dj-ollerganove.de') return;

    try {
      // Verwende serverTimestamp, um sicherzustellen, dass der Zeitpunkt korrekt ist
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'last_viewed_wishes_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      // Rufe auch den Callback auf, um das Badge zu aktualisieren
      widget.onPageOpened?.call();
    } catch (e) {
      print('Fehler beim Markieren der Wünsche als gesehen: $e');
    }
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().substring(2)}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pending,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Offen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: _lastViewedStream == null
                    ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('wishes')
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, snapshot) {
                          return _buildWishesListWithoutNew(context, snapshot);
                        },
                      )
                    : StreamBuilder<DocumentSnapshot>(
                        stream: _lastViewedStream,
                        builder: (context, lastViewedSnapshot) {
                          // Lade lastViewedTime aus Stream
                          DateTime? lastViewedTime;
                          if (lastViewedSnapshot.hasData && lastViewedSnapshot.data!.exists) {
                            final data = lastViewedSnapshot.data!.data() as Map<String, dynamic>?;
                            final lastViewed = data?['last_viewed_wishes_at'] as Timestamp?;
                            lastViewedTime = lastViewed?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                          } else {
                            lastViewedTime = DateTime.fromMillisecondsSinceEpoch(0);
                          }
                          
                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('wishes')
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return buildFirebaseErrorWidget(snapshot.error!);
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('Keine offenen Wünsche.'),
                          );
                        }
                        // Filtere Duplikate heraus - zeige nur Original-Wünsche
                        final originalDocs = docs.where((doc) {
                          final data = doc.data();
                          return data['is_duplicate'] != true;
                        }).toList();
                        
                        if (originalDocs.isEmpty) {
                          return const Center(
                            child: Text('Keine offenen Wünsche.'),
                          );
                        }
                        
                        // Sortiere clientseitig nach createdAt (neueste zuerst)
                        final sortedDocs = originalDocs.toList()
                          ..sort((a, b) {
                            final tsA = a.data()['createdAt'];
                            final tsB = b.data()['createdAt'];
                            final dateA = tsA is Timestamp
                                ? tsA.toDate()
                                : DateTime.fromMillisecondsSinceEpoch(0);
                            final dateB = tsB is Timestamp
                                ? tsB.toDate()
                                : DateTime.fromMillisecondsSinceEpoch(0);
                            return dateB.compareTo(dateA); // Neueste zuerst
                          });
                        return ListView.separated(
                          shrinkWrap: false,
                          physics: const ClampingScrollPhysics(),
                          itemCount: sortedDocs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final doc = sortedDocs[index];
                            final data = doc.data();
                            final title = (data['title'] ?? data['song'] ?? '') as String;
                            final artist = (data['artist'] ?? '') as String;
                            final name = (data['name'] ?? '') as String;
                            final greeting = (data['greeting'] ?? '') as String;
                            final duplicateCount = (data['duplicate_count'] as int?) ?? 0;
                            final requestedBy = List<String>.from((data['requested_by'] as List?) ?? []);
                            // Wenn requestedBy leer ist, verwende den ursprünglichen Namen
                            final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
                            // Lade is_registered_users Map für Farbbestimmung
                            final isRegisteredUsers = Map<String, bool>.from((data['is_registered_users'] as Map<String, dynamic>?) ?? {});
                            // Wenn nur ein Name vorhanden ist und is_registered_users leer ist, verwende is_registered_user
                            if (namesToShow.length == 1 && isRegisteredUsers.isEmpty && data['is_registered_user'] != null) {
                              isRegisteredUsers[namesToShow[0]] = data['is_registered_user'] as bool;
                            }
                            final greetings = List<Map<String, dynamic>>.from(
                              (data['greetings'] as List?)?.map((g) => g as Map<String, dynamic>) ?? []
                            );
                            final tsCreated = data['createdAt'];
                            final created = tsCreated is Timestamp
                                ? tsCreated.toDate()
                                : DateTime.fromMillisecondsSinceEpoch(0);
                            
                            // Prüfe, ob dieser Wunsch "neu" ist
                            // Ein Wunsch ist "neu", wenn er nach dem letzten "gesehen" Zeitpunkt (lastViewedTime) erstellt wurde
                            // Die Markierung bleibt sichtbar, bis die Seite verlassen wird (dann wird lastViewedTime aktualisiert)
                            final isNew = lastViewedTime != null && created.isAfter(lastViewedTime!);
                        
                        String displayText = '';
                        if (title.isNotEmpty && artist.isNotEmpty) {
                          displayText = '$title - $artist';
                        } else if (title.isNotEmpty) {
                          displayText = title;
                        } else if (artist.isNotEmpty) {
                          displayText = artist;
                        }

                        // Nummerierung: sortedDocs.length - index (neueste = 1)
                        final number = sortedDocs.length - index;

                        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isNew 
                              ? (isDarkMode ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50)
                              : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                              color: isNew 
                                  ? (isDarkMode ? Colors.amber.shade700 : Colors.amber.shade300)
                                  : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                              width: isNew ? 1.5 : 0.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {}, // Leerer onTap für visuelles Feedback
                            splashColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade800
                                : Colors.amber.shade200,
                            highlightColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade900.withOpacity(0.3)
                                : Colors.amber.shade100,
                            child: ListTile(
                              title: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                                    child: Text(
                                      '$number.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  if (isNew)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade700,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'NEU',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (duplicateCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.copy, size: 14, color: Colors.orange.shade800),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${duplicateCount + 1}x',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${_formatShortDate(created)} • ${_formatTime(created)}'),
                                  // Zeige alle Namen, die diesen Wunsch gewünscht haben
                                  if (namesToShow.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        ...namesToShow.map((n) {
                                          // Prüfe, ob der User angemeldet ist
                                          // Verwende is_registered_users Map, falls vorhanden, sonst prüfe Email-Format
                                          final isRegisteredUser = isRegisteredUsers[n] ?? 
                                            (n.contains('@') && n.split('@').length == 2 && n.split('@')[1].contains('.'));
                                          return Chip(
                                            label: Text(
                                              n,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isRegisteredUser ? Colors.green.shade700 : Colors.grey[700],
                                                fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                                ? (isRegisteredUser ? Colors.green.shade900.withOpacity(0.3) : Colors.grey.shade800)
                                                : (isRegisteredUser ? Colors.green.shade50 : Colors.grey.shade100),
                                          );
                                        }),
                                      ],
                                    ),
                                  ],
                                  // Zeige alle Grüße mit Namen
                                  if (greetings.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...greetings.map((g) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.favorite, size: 16, color: Colors.blue.shade700),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Builder(
                                                    builder: (context) {
                                                      final name = g['name'] as String? ?? '';
                                                      // Prüfe, ob der User angemeldet ist
                                                      // Verwende is_registered_users Map, falls vorhanden, sonst prüfe Email-Format
                                                      final isRegisteredUser = isRegisteredUsers[name] ?? 
                                                        (name.contains('@') && name.split('@').length == 2 && name.split('@')[1].contains('.'));
                                                      return Text(
                                                        name,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
                                                          color: isRegisteredUser ? Colors.green.shade700 : Colors.grey[700],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    g['greeting'] as String? ?? '',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.blue.shade900,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )),
                                  ],
                                  // Fallback: Zeige einzelne Gruß, falls vorhanden (für Rückwärtskompatibilität)
                                  if (greeting.isNotEmpty && greetings.isEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.favorite, size: 16, color: Colors.blue.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              greeting,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.blue.shade900,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    tooltip: 'Als gespielt markieren',
                                    onPressed: () => _confirmUpdateStatus(context, doc.id, 'played', 'Als gespielt markieren', displayText),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Löschen',
                                    onPressed: () => _confirmDeleteOrReject(context, doc.id, displayText),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                        },
                      );
                    },
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildWishesListWithoutNew(BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return buildFirebaseErrorWidget(snapshot.error!);
    }
    final docs = snapshot.data?.docs ?? [];
    if (docs.isEmpty) {
      return const Center(
        child: Text('Keine offenen Wünsche.'),
      );
    }
    final originalDocs = docs.where((doc) {
      final data = doc.data();
      return data['is_duplicate'] != true;
    }).toList();
    
    if (originalDocs.isEmpty) {
      return const Center(
        child: Text('Keine offenen Wünsche.'),
      );
    }
    
    final sortedDocs = originalDocs.toList()
      ..sort((a, b) {
        final tsA = a.data()['createdAt'];
        final tsB = b.data()['createdAt'];
        final dateA = tsA is Timestamp
            ? tsA.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = tsB is Timestamp
            ? tsB.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    
    return ListView.separated(
      shrinkWrap: false,
      physics: const ClampingScrollPhysics(),
      itemCount: sortedDocs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final doc = sortedDocs[index];
        final data = doc.data();
        final title = (data['title'] ?? data['song'] ?? '') as String;
        final artist = (data['artist'] ?? '') as String;
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        
        String displayText = '';
        if (title.isNotEmpty && artist.isNotEmpty) {
          displayText = '$title - $artist';
        } else if (title.isNotEmpty) {
          displayText = title;
        } else if (artist.isNotEmpty) {
          displayText = artist;
        }
        
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 0.5,
            ),
          ),
          child: ListTile(
            title: Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${_formatShortDate(created)} • ${_formatTime(created)}'),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteOrReject(BuildContext context, String docId, String wishText) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wunsch löschen oder ablehnen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wishText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('Was möchtest du mit diesem Wunsch machen?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'nein'),
            child: const Text('Nichts'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'ablehnen'),
            child: const Text('Ablehnen', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'löschen'),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == 'ablehnen') {
      await _updateWishStatus(context, docId, 'rejected');
    } else if (result == 'löschen') {
      await _deleteWish(context, docId);
    }
  }

  Future<void> _deleteWish(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('wishes').doc(docId).delete();
      // Erhöhe deleted_count
      await incrementDeletedCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wunsch wurde gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmUpdateStatus(BuildContext context, String docId, String status, String action, String wishText) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wishText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text('Möchtest du diesen Wunsch wirklich $action?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nein'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Ja', style: TextStyle(color: status == 'played' ? Colors.green : Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateWishStatus(context, docId, status);
    }
  }

  Future<void> _updateWishStatus(BuildContext context, String docId, String status) async {
    try {
      final now = Timestamp.now();
      final updateData = <String, dynamic>{
        'status': status,
      };
      
      if (status == 'played') {
        updateData['playedAt'] = now;
        updateData['rejectedAt'] = FieldValue.delete();
      } else if (status == 'rejected') {
        updateData['rejectedAt'] = now;
        updateData['playedAt'] = FieldValue.delete();
      } else if (status == 'pending') {
        updateData['playedAt'] = FieldValue.delete();
        updateData['rejectedAt'] = FieldValue.delete();
      }
      
      await FirebaseFirestore.instance.collection('wishes').doc(docId).update(updateData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status aktualisiert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class GespieltPage extends StatelessWidget {
  const GespieltPage({super.key});

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().substring(2)}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Gespielt',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('wishes')
                      .where('status', isEqualTo: 'played')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return buildFirebaseErrorWidget(snapshot.error!);
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Keine gespielten Wünsche.'),
                      );
                    }
                    // Filtere Duplikate heraus - zeige nur Original-Wünsche
                    final originalDocs = docs.where((doc) {
                      final data = doc.data();
                      return data['is_duplicate'] != true;
                    }).toList();
                    
                    if (originalDocs.isEmpty) {
                      return const Center(
                        child: Text('Keine gespielten Wünsche.'),
                      );
                    }
                    
                    // Sortiere clientseitig nach createdAt (neueste zuerst)
                    final sortedDocs = originalDocs.toList()
                      ..sort((a, b) {
                        final tsA = a.data()['createdAt'];
                        final tsB = b.data()['createdAt'];
                        final dateA = tsA is Timestamp
                            ? tsA.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        final dateB = tsB is Timestamp
                            ? tsB.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        return dateB.compareTo(dateA); // Neueste zuerst
                      });
                    return ListView.separated(
                      shrinkWrap: false,
                      physics: const ClampingScrollPhysics(),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = sortedDocs[index];
                        final data = doc.data();
                        final title = (data['title'] ?? data['song'] ?? '') as String;
                        final artist = (data['artist'] ?? '') as String;
                        final name = (data['name'] ?? '') as String;
                        final greeting = (data['greeting'] ?? '') as String;
                        final duplicateCount = (data['duplicate_count'] as int?) ?? 0;
                        final requestedBy = List<String>.from((data['requested_by'] as List?) ?? []);
                        // Wenn requestedBy leer ist, verwende den ursprünglichen Namen
                        final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
                        // Lade is_registered_users Map für Farbbestimmung
                        final isRegisteredUsers = Map<String, bool>.from((data['is_registered_users'] as Map<String, dynamic>?) ?? {});
                        // Wenn nur ein Name vorhanden ist und is_registered_users leer ist, verwende is_registered_user
                        if (namesToShow.length == 1 && isRegisteredUsers.isEmpty && data['is_registered_user'] != null) {
                          isRegisteredUsers[namesToShow[0]] = data['is_registered_user'] as bool;
                        }
                        final greetings = List<Map<String, dynamic>>.from(
                          (data['greetings'] as List?)?.map((g) => g as Map<String, dynamic>) ?? []
                        );
                        final tsCreated = data['createdAt'];
                        final created = tsCreated is Timestamp
                            ? tsCreated.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        final tsPlayed = data['playedAt'];
                        final played = tsPlayed is Timestamp
                            ? tsPlayed.toDate()
                            : null;
                        
                        String displayText = '';
                        if (title.isNotEmpty && artist.isNotEmpty) {
                          displayText = '$title - $artist';
                        } else if (title.isNotEmpty) {
                          displayText = title;
                        } else if (artist.isNotEmpty) {
                          displayText = artist;
                        }

                        // Nummerierung: sortedDocs.length - index (neueste = 1)
                        final number = sortedDocs.length - index;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.grey.shade100,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                          ),
                          child: InkWell(
                            onTap: () {}, // Leerer onTap für visuelles Feedback
                            splashColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade800
                                : Colors.amber.shade200,
                            highlightColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade900.withOpacity(0.3)
                                : Colors.amber.shade100,
                            child: ListTile(
                              title: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                                    child: Text(
                                      '$number.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  if (duplicateCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.copy, size: 14, color: Colors.orange.shade800),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${duplicateCount + 1}x',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${_formatShortDate(created)} • ${_formatTime(created)}'),
                                  if (played != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Gespielt: ${_formatShortDate(played)} • ${_formatTime(played)}',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                // Zeige alle Namen, die diesen Wunsch gewünscht haben
                                if (namesToShow.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      ...namesToShow.map((n) {
                                        // Prüfe, ob der User angemeldet ist
                                        // Verwende is_registered_users Map, falls vorhanden, sonst prüfe Email-Format
                                        final isRegisteredUser = isRegisteredUsers[n] ?? 
                                          (n.contains('@') && n.split('@').length == 2 && n.split('@')[1].contains('.'));
                                        return Chip(
                                          label: Text(
                                            n,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isRegisteredUser ? Colors.green.shade700 : Colors.grey[700],
                                              fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: isRegisteredUser ? Colors.green.shade50 : Colors.grey.shade100,
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                                // Zeige alle Grüße mit Namen
                                if (greetings.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...greetings.map((g) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.favorite, size: 16, color: Colors.blue.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Builder(
                                                  builder: (context) {
                                                    final name = g['name'] as String? ?? '';
                                                    // Prüfe, ob der User angemeldet ist
                                                    // Verwende is_registered_users Map, falls vorhanden, sonst prüfe Email-Format
                                                    final isRegisteredUser = isRegisteredUsers[name] ?? 
                                                      (name.contains('@') && name.split('@').length == 2 && name.split('@')[1].contains('.'));
                                                    return Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
                                                        color: isRegisteredUser ? Colors.green.shade700 : Colors.grey[700],
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  g['greeting'] as String? ?? '',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.blue.shade900,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                                ],
                                // Fallback: Zeige einzelne Gruß, falls vorhanden (für Rückwärtskompatibilität)
                                if (greeting.isNotEmpty && greetings.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.blue.shade900.withOpacity(0.3)
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.blue.shade700
                                            : Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 16,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.blue.shade300
                                              : Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            greeting,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.blue.shade200
                                                  : Colors.blue.shade900,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.blue),
                                  tooltip: 'Zurück auf offen',
                                  onPressed: () => _updateWishStatus(context, doc.id, 'pending'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Endgültig löschen',
                                  onPressed: () => _confirmDelete(context, doc.id, displayText),
                                ),
                              ],
                            ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String docId, String wishText) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Endgültig löschen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wishText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('Möchtest du diesen Wunsch wirklich endgültig löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nein'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteWish(context, docId);
    }
  }

  Future<void> _deleteWish(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('wishes').doc(docId).delete();
      // Erhöhe deleted_count
      await incrementDeletedCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wunsch wurde gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateWishStatus(BuildContext context, String docId, String status) async {
    try {
      final now = Timestamp.now();
      final updateData = <String, dynamic>{
        'status': status,
      };
      
      if (status == 'played') {
        updateData['playedAt'] = now;
        updateData['rejectedAt'] = FieldValue.delete();
      } else if (status == 'rejected') {
        updateData['rejectedAt'] = now;
        updateData['playedAt'] = FieldValue.delete();
      } else if (status == 'pending') {
        updateData['playedAt'] = FieldValue.delete();
        updateData['rejectedAt'] = FieldValue.delete();
      }
      
      await FirebaseFirestore.instance.collection('wishes').doc(docId).update(updateData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status aktualisiert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class AbgelehntPage extends StatelessWidget {
  const AbgelehntPage({super.key});

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().substring(2)}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Abgelehnt',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('wishes')
                      .where('status', isEqualTo: 'rejected')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return buildFirebaseErrorWidget(snapshot.error!);
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Keine abgelehnten Wünsche.'),
                      );
                    }
                    // Filtere Duplikate heraus - zeige nur Original-Wünsche
                    final originalDocs = docs.where((doc) {
                      final data = doc.data();
                      return data['is_duplicate'] != true;
                    }).toList();
                    
                    if (originalDocs.isEmpty) {
                      return const Center(
                        child: Text('Keine abgelehnten Wünsche.'),
                      );
                    }
                    
                    // Sortiere clientseitig nach createdAt (neueste zuerst)
                    final sortedDocs = originalDocs.toList()
                      ..sort((a, b) {
                        final tsA = a.data()['createdAt'];
                        final tsB = b.data()['createdAt'];
                        final dateA = tsA is Timestamp
                            ? tsA.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        final dateB = tsB is Timestamp
                            ? tsB.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        return dateB.compareTo(dateA); // Neueste zuerst
                      });
                    return ListView.separated(
                      shrinkWrap: false,
                      physics: const ClampingScrollPhysics(),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = sortedDocs[index];
                        final data = doc.data();
                        final title = (data['title'] ?? data['song'] ?? '') as String;
                        final artist = (data['artist'] ?? '') as String;
                        final name = (data['name'] ?? '') as String;
                        final greeting = (data['greeting'] ?? '') as String;
                        final duplicateCount = (data['duplicate_count'] as int?) ?? 0;
                        final requestedBy = List<String>.from((data['requested_by'] as List?) ?? []);
                        // Wenn requestedBy leer ist, verwende den ursprünglichen Namen
                        final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
                        // Lade is_registered_users Map für Farbbestimmung
                        final isRegisteredUsers = Map<String, bool>.from((data['is_registered_users'] as Map<String, dynamic>?) ?? {});
                        // Wenn nur ein Name vorhanden ist und is_registered_users leer ist, verwende is_registered_user
                        if (namesToShow.length == 1 && isRegisteredUsers.isEmpty && data['is_registered_user'] != null) {
                          isRegisteredUsers[namesToShow[0]] = data['is_registered_user'] as bool;
                        }
                        final greetings = List<Map<String, dynamic>>.from(
                          (data['greetings'] as List?)?.map((g) => g as Map<String, dynamic>) ?? []
                        );
                        final tsCreated = data['createdAt'];
                        final created = tsCreated is Timestamp
                            ? tsCreated.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        final tsRejected = data['rejectedAt'];
                        final rejected = tsRejected is Timestamp
                            ? tsRejected.toDate()
                            : null;
                        
                        String displayText = '';
                        if (title.isNotEmpty && artist.isNotEmpty) {
                          displayText = '$title - $artist';
                        } else if (title.isNotEmpty) {
                          displayText = title;
                        } else if (artist.isNotEmpty) {
                          displayText = artist;
                        }

                        // Nummerierung: sortedDocs.length - index (neueste = 1)
                        final number = sortedDocs.length - index;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.grey.shade100,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                          ),
                          child: InkWell(
                            onTap: () {}, // Leerer onTap für visuelles Feedback
                            splashColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade800
                                : Colors.amber.shade200,
                            highlightColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade900.withOpacity(0.3)
                                : Colors.amber.shade100,
                            child: ListTile(
                              title: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                                    child: Text(
                                      '$number.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  if (duplicateCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.copy, size: 14, color: Colors.orange.shade800),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${duplicateCount + 1}x',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${_formatShortDate(created)} • ${_formatTime(created)}'),
                                  if (rejected != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Abgelehnt: ${_formatShortDate(rejected)} • ${_formatTime(rejected)}',
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                // Zeige alle Namen, die diesen Wunsch gewünscht haben
                                if (namesToShow.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      ...namesToShow.map((n) {
                                        // Prüfe, ob der User angemeldet ist
                                        // Verwende is_registered_users Map, falls vorhanden, sonst prüfe Email-Format
                                        final isRegisteredUser = isRegisteredUsers[n] ?? 
                                          (n.contains('@') && n.split('@').length == 2 && n.split('@')[1].contains('.'));
                                        return Chip(
                                          label: Text(
                                            n,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isRegisteredUser ? Colors.green.shade700 : Colors.grey[700],
                                              fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: isRegisteredUser ? Colors.green.shade50 : Colors.grey.shade100,
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                                // Zeige alle Grüße mit Namen
                                if (greetings.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...greetings.map((g) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.favorite, size: 16, color: Colors.blue.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Builder(
                                                  builder: (context) {
                                                    final name = g['name'] as String? ?? '';
                                                    // Prüfe, ob der User angemeldet ist
                                                    // Verwende is_registered_users Map, falls vorhanden, sonst prüfe Email-Format
                                                    final isRegisteredUser = isRegisteredUsers[name] ?? 
                                                      (name.contains('@') && name.split('@').length == 2 && name.split('@')[1].contains('.'));
                                                    return Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
                                                        color: isRegisteredUser ? Colors.green.shade700 : Colors.grey[700],
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  g['greeting'] as String? ?? '',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.blue.shade900,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                                ],
                                // Fallback: Zeige einzelne Gruß, falls vorhanden (für Rückwärtskompatibilität)
                                if (greeting.isNotEmpty && greetings.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.blue.shade900.withOpacity(0.3)
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.blue.shade700
                                            : Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 16,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.blue.shade300
                                              : Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            greeting,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.blue.shade200
                                                  : Colors.blue.shade900,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.blue),
                                  tooltip: 'Zurück auf offen',
                                  onPressed: () => _updateWishStatus(context, doc.id, 'pending'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Endgültig löschen',
                                  onPressed: () => _confirmDelete(context, doc.id, displayText),
                                ),
                              ],
                            ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String docId, String wishText) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Endgültig löschen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wishText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('Möchtest du diesen Wunsch wirklich endgültig löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nein'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteWish(context, docId);
    }
  }

  Future<void> _deleteWish(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('wishes').doc(docId).delete();
      // Erhöhe deleted_count
      await incrementDeletedCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wunsch wurde gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateWishStatus(BuildContext context, String docId, String status) async {
    try {
      final now = Timestamp.now();
      final updateData = <String, dynamic>{
        'status': status,
      };
      
      if (status == 'played') {
        updateData['playedAt'] = now;
        updateData['rejectedAt'] = FieldValue.delete();
      } else if (status == 'rejected') {
        updateData['rejectedAt'] = now;
        updateData['playedAt'] = FieldValue.delete();
      } else if (status == 'pending') {
        updateData['playedAt'] = FieldValue.delete();
        updateData['rejectedAt'] = FieldValue.delete();
      }
      
      await FirebaseFirestore.instance.collection('wishes').doc(docId).update(updateData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status aktualisiert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Profil-Seite
class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  StreamSubscription<User?>? _authSubscription;
  String? _profileImageUrl;
  bool _isLoadingImage = false;

  bool get _isDarkMode => themeModeNotifier.value == ThemeMode.dark;
  
  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    // Höre auf Theme-Änderungen, damit der Schalter aktualisiert wird
    themeModeNotifier.addListener(_onThemeChanged);
    // Höre auf Auth-Änderungen, um Email-Änderungen zu erkennen
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        // Prüfe ob eine Email-Änderung aussteht
        _checkPendingEmailChange(user);
        _loadProfileImage();
      } else {
        setState(() {
          _profileImageUrl = null;
        });
      }
    });
  }
  
  @override
  void dispose() {
    themeModeNotifier.removeListener(_onThemeChanged);
    _authSubscription?.cancel();
    super.dispose();
  }
  
  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }
  
  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _profileImageUrl = data?['photoURL'] as String?;
          });
        }
      } catch (e) {
        print('Fehler beim Laden des Profilbilds: $e');
      }
    }
  }

  Future<void> _checkPendingEmailChange(User user) async {
    // Prüfe ob eine Email-Änderung aussteht
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final data = userDoc.data();
      final pendingEmail = data?['pendingEmail'] as String?;
      
      // Wenn Email geändert wurde und pendingEmail gesetzt war, aktualisiere Firestore
      if (pendingEmail != null && user.email == pendingEmail) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'email': user.email,
          'pendingEmail': FieldValue.delete(),
          'emailChangeRequestedAt': FieldValue.delete(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email wurde erfolgreich geändert.'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {}); // Aktualisiere die UI
        }
      }
    }
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<Uint8List?> _compressImage(File imageFile) async {
    try {
      // Lade das Bild
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) return null;
      
      // Maximal 500x500px (für Profilbilder ausreichend)
      const maxSize = 500;
      img.Image resizedImage = image;
      
      if (image.width > maxSize || image.height > maxSize) {
        // Berechne neue Größe, behalte Seitenverhältnis
        double ratio = image.width / image.height;
        int newWidth, newHeight;
        
        if (image.width > image.height) {
          newWidth = maxSize;
          newHeight = (maxSize / ratio).round();
        } else {
          newHeight = maxSize;
          newWidth = (maxSize * ratio).round();
        }
        
        resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
      }
      
      // Komprimiere als JPEG mit 80% Qualität
      final compressedBytes = img.encodeJpg(resizedImage, quality: 80);
      
      // Prüfe Dateigröße (max 2MB)
      if (compressedBytes.length > 2 * 1024 * 1024) {
        // Wenn zu groß, weiter komprimieren mit niedrigerer Qualität
        int quality = 70;
        while (compressedBytes.length > 2 * 1024 * 1024 && quality > 30) {
          final testBytes = img.encodeJpg(resizedImage, quality: quality);
          if (testBytes.length <= 2 * 1024 * 1024) {
            return Uint8List.fromList(testBytes);
          }
          quality -= 10;
        }
      }
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('Fehler beim Komprimieren: $e');
      return null;
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 100, // Wir komprimieren selbst
      );

      if (image == null) return;

      setState(() => _isLoadingImage = true);

      // Komprimiere das Bild
      final compressedBytes = await _compressImage(File(image.path));
      if (compressedBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler beim Verarbeiten des Bildes.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoadingImage = false);
        return;
      }

      // Prüfe Dateigröße (max 2MB)
      if (compressedBytes.length > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Das Bild ist zu groß. Bitte wähle ein kleineres Bild (max. 2MB).'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoadingImage = false);
        return;
      }

      // Upload zu Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      final uploadTask = storageRef.putData(
        compressedBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      await uploadTask;

      // Hole die Download-URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Speichere URL in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'photoURL': downloadUrl,
      }, SetOptions(merge: true));

      setState(() {
        _profileImageUrl = downloadUrl;
        _isLoadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profilbild wurde erfolgreich hochgeladen.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Hochladen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Hochladen: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingImage = false);
      }
    }
  }

  Future<void> _deleteProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profilbild löschen?'),
        content: const Text('Möchtest du dein Profilbild wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoadingImage = true);

      // Lösche aus Firebase Storage
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');
        await storageRef.delete();
      } catch (e) {
        // Ignoriere Fehler, falls Datei nicht existiert
        print('Fehler beim Löschen aus Storage: $e');
      }

      // Entferne URL aus Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'photoURL': FieldValue.delete(),
      });

      setState(() {
        _profileImageUrl = null;
        _isLoadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profilbild wurde gelöscht.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Löschen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingImage = false);
      }
    }
  }

  bool _isNameBlocked(String name) {
    final normalizedName = name.trim().toUpperCase();
    
    // Blockierte Namen
    final blockedNames = ['DJ', 'OLLERGANOVE', 'GANOVE', 'OLLER', 'ADMIN'];
    if (blockedNames.contains(normalizedName)) {
      return true;
    }
    
    // Blacklist für unangemessene Begriffe
    final inappropriateWords = [
      'FUCK', 'SHIT', 'ASS', 'BITCH', 'DAMN', 'HELL',
      'CUNT', 'SLUT', 'WHORE', 'BASTARD', 'DICK',
    ];
    
    for (final word in inappropriateWords) {
      if (normalizedName.contains(word)) {
        return true;
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Bitte melde dich an',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Du musst angemeldet sein, um dein Profil zu sehen.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Registrierungsdatum aus User-Metadaten
    final creationTime = user.metadata.creationTime ?? DateTime.now();
    final displayName = user.displayName ?? 'Kein Name';
    final email = user.email ?? 'Keine Email';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Profil',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Profilbild
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300], // Graues Profilbild
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[600],
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: _isLoadingImage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : PopupMenuButton<String>(
                                icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onSelected: (value) {
                                  if (value == 'upload') {
                                    _pickAndUploadImage();
                                  } else if (value == 'delete') {
                                    _deleteProfileImage();
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'upload',
                                    child: Row(
                                      children: [
                                        Icon(Icons.camera_alt, size: 20),
                                        SizedBox(width: 8),
                                        Text('Bild ändern'),
                                      ],
                                    ),
                                  ),
                                  if (_profileImageUrl != null)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Bild löschen', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Profil-Informationen
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Name:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          displayName,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Email:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          email,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Registriert seit:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          _formatShortDate(creationTime),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Bearbeiten Button
              ElevatedButton.icon(
                onPressed: () => _showEditDialog(context, user),
                icon: const Icon(Icons.edit),
                label: const Text('Bearbeiten'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              // Passwort ändern Button
              ElevatedButton.icon(
                onPressed: () => _showChangePasswordDialog(context),
                icon: const Icon(Icons.lock),
                label: const Text('Passwort ändern'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              // Theme-Umschalter
              Card(
                child: SwitchListTile(
                  subtitle: const Text('Zwischen hellem und dunklem Design wechseln'),
                  value: _isDarkMode,
                  onChanged: (value) {
                    final mode = value ? ThemeMode.dark : ThemeMode.light;
                    setThemeMode(mode);
                    setState(() {});
                  },
                  secondary: Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: _isDarkMode ? Colors.amber : Colors.blueGrey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Account löschen Button
              ElevatedButton.icon(
                onPressed: () => _confirmDeleteAccount(context),
                icon: const Icon(Icons.delete_forever),
                label: const Text('ACCOUNT LÖSCHEN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account löschen?'),
        content: const Text(
          'Möchtest du deinen Account wirklich löschen? Dein Account wird deaktiviert und du wirst ausgeloggt. Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja, löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount(context);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Setze Account auf inactive in Firestore (falls du eine users-Collection hast)
      // Für jetzt setzen wir einfach ein Custom Claim oder speichern es in Firestore
      // Da wir keine users-Collection haben, loggen wir den User einfach aus
      // Du könntest später eine users-Collection erstellen, um den Status zu speichern
      
      // Alternative: User-Dokument in Firestore erstellen/aktualisieren
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'email': user.email,
        'displayName': user.displayName,
        'inactive': true,
        'deletedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      // Lösche gespeichertes Passwort beim Account löschen
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      
      // User ausloggen
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account wurde gelöscht. Du wurdest ausgeloggt.'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigiere zurück zur Hauptseite
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Bitte gib ein Passwort ein.';
    }
    if (value.length < 8) {
      return 'Das Passwort muss mindestens 8 Zeichen lang sein.';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Das Passwort muss mindestens einen Großbuchstaben enthalten.';
    }
    if (!value.contains(RegExp(r'[-_!()]'))) {
      return 'Das Passwort muss mindestens eines der folgenden Sonderzeichen enthalten: - _ ! ( )';
    }
    return null;
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final formKey = GlobalKey<FormState>();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Passwort ändern'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Neues Passwort
                  TextFormField(
                    controller: newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Neues Passwort',
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.help_outline, size: 20),
                            tooltip: 'Passwort-Anforderungen',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Passwort-Anforderungen'),
                                  content: const Text(
                                    'Das Passwort muss:\n'
                                    '• Mindestens 8 Zeichen lang sein\n'
                                    '• Mindestens einen Großbuchstaben enthalten\n'
                                    '• Mindestens eines der folgenden Sonderzeichen enthalten: - _ ! ( )',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(showNewPassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setDialogState(() {
                                showNewPassword = !showNewPassword;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    obscureText: !showNewPassword,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),
                  // Passwort bestätigen
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Neues Passwort bestätigen',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setDialogState(() {
                            showConfirmPassword = !showConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: !showConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte bestätige das neue Passwort.';
                      }
                      if (value != newPasswordController.text) {
                        return 'Die Passwörter stimmen nicht überein.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    // Ändere das Passwort (man ist ja bereits eingeloggt)
                    await user.updatePassword(newPasswordController.text);
                    
                    // Aktualisiere gespeichertes Passwort, falls vorhanden
                    final prefs = await SharedPreferences.getInstance();
                    final savedEmail = prefs.getString('saved_email');
                    if (savedEmail == user.email) {
                      // Passwort ist gespeichert, aktualisiere es
                      await prefs.setString('saved_password', newPasswordController.text);
                    }
                    
                    if (context.mounted) {
                      newPasswordController.dispose();
                      confirmPasswordController.dispose();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Passwort wurde erfolgreich geändert. Beim nächsten Öffnen der App wird das neue Passwort verwendet.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      String errorMessage = 'Fehler beim Ändern des Passworts.';
                      if (e.toString().contains('weak-password')) {
                        errorMessage = 'Das neue Passwort ist zu schwach.';
                      } else if (e.toString().contains('requires-recent-login')) {
                        errorMessage = 'Bitte melde dich erneut an, um das Passwort zu ändern.';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Passwort ändern'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, User user) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Name ändern'),
              onTap: () => Navigator.pop(context, 'name'),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email ändern'),
              onTap: () => Navigator.pop(context, 'email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );

    if (result == 'name') {
      await _editName(context, user);
    } else if (result == 'email') {
      await _editEmail(context, user);
    }
  }

  Future<void> _editName(BuildContext context, User user) async {
    final nameController = TextEditingController(text: user.displayName ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name ändern'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Neuer Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name darf nicht leer sein';
              }
              if (value.trim().length < 3) {
                return 'Name muss mindestens 3 Zeichen lang sein';
              }
              if (_isNameBlocked(value)) {
                return 'Dieser Name ist nicht erlaubt';
              }
              return null;
            },
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newName = sanitizeInput(nameController.text.trim());
      final oldName = user.displayName ?? '';

      try {
        // Aktualisiere DisplayName in Firebase Auth
        await user.updateDisplayName(newName);
        await user.reload();
        
        // Versuche auch in Firestore users Collection zu aktualisieren (optional)
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'displayName': newName,
            'email': user.email,
          }, SetOptions(merge: true));
        } catch (e) {
          // Firestore-Update ist optional, Fehler ignorieren
          print('Firestore users update fehlgeschlagen: $e');
        }

        // Aktualisiere auch alle Wünsche mit dem neuen Namen (nur wenn alter Name vorhanden war)
        if (oldName.isNotEmpty) {
          try {
            final wishesQuery = await FirebaseFirestore.instance
                .collection('wishes')
                .where('name', isEqualTo: oldName)
                .get();

            if (wishesQuery.docs.isNotEmpty) {
              final batch = FirebaseFirestore.instance.batch();
              for (final doc in wishesQuery.docs) {
                batch.update(doc.reference, {'name': newName});
              }
              await batch.commit();
            }
          } catch (e) {
            // Wünsche-Update ist optional, Fehler ignorieren
            print('Wünsche-Update fehlgeschlagen: $e');
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name wurde erfolgreich geändert.'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {}); // Aktualisiere die UI
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Ändern des Namens: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    nameController.dispose();
  }

  Future<void> _editEmail(BuildContext context, User user) async {
    final emailController = TextEditingController(text: user.email ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email ändern'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Neue Email-Adresse',
              prefixIcon: Icon(Icons.email_outlined),
              helperText: 'Du erhältst eine Bestätigungs-Email an die neue Adresse.',
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email darf nicht leer sein';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Bitte gib eine gültige Email-Adresse ein';
              }
              if (value == user.email) {
                return 'Das ist bereits deine aktuelle Email-Adresse';
              }
              return null;
            },
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Bestätigungs-Email senden'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Sanitize Email gegen Schadcode
      final newEmail = sanitizeEmail(emailController.text.trim());
      
      try {
        // Versuche zuerst ohne Re-Authentifizierung (falls User kürzlich eingeloggt war)
        await user.verifyBeforeUpdateEmail(newEmail);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Eine Bestätigungs-Email wurde an $newEmail gesendet. Bitte klicke auf den Link in der Email, um die Änderung zu bestätigen.'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        // Speichere die neue Email in Firestore als pending (optional)
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'pendingEmail': newEmail,
            'emailChangeRequestedAt': Timestamp.now(),
          }, SetOptions(merge: true));
        } catch (e) {
          // Firestore-Update ist optional, Fehler ignorieren
          print('Firestore update fehlgeschlagen: $e');
        }

      } catch (e) {
        // Wenn requires-recent-login Fehler, dann Passwort abfragen
        if (e.toString().contains('requires-recent-login')) {
          final passwordController = TextEditingController();
          final passwordFormKey = GlobalKey<FormState>();
          
          final passwordConfirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Passwort bestätigen'),
              content: Form(
                key: passwordFormKey,
                child: TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Dein Passwort',
                    prefixIcon: Icon(Icons.lock_outline),
                    helperText: 'Bitte gib dein Passwort ein, um die Email-Änderung zu bestätigen.',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Passwort darf nicht leer sein';
                    }
                    return null;
                  },
                  autofocus: true,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () {
                    if (passwordFormKey.currentState!.validate()) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('Bestätigen'),
                ),
              ],
            ),
          );

          if (passwordConfirmed != true) {
            passwordController.dispose();
            emailController.dispose();
            return;
          }
          
          try {
            // Re-Authentifizierung mit Passwort
            final credential = EmailAuthProvider.credential(
              email: user.email!,
              password: passwordController.text,
            );
            await user.reauthenticateWithCredential(credential);
            
            // Passwort-Controller jetzt löschen (Passwort wurde verwendet)
            passwordController.dispose();
            
            // Jetzt kann die Email geändert werden
            await user.verifyBeforeUpdateEmail(newEmail);
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Eine Bestätigungs-Email wurde an $newEmail gesendet. Bitte klicke auf den Link in der Email, um die Änderung zu bestätigen.'),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 5),
                ),
              );
            }

            // Speichere die neue Email in Firestore als pending (optional)
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set({
                'pendingEmail': newEmail,
                'emailChangeRequestedAt': Timestamp.now(),
              }, SetOptions(merge: true));
            } catch (e) {
              // Firestore-Update ist optional, Fehler ignorieren
              print('Firestore update fehlgeschlagen: $e');
            }

          } catch (e2) {
            passwordController.dispose();
            
            String errorMessage = 'Fehler beim Senden der Bestätigungs-Email.';
            if (e2.toString().contains('email-already-in-use') || 
                e2.toString().contains('already exists')) {
              errorMessage = 'Diese Email-Adresse wird bereits verwendet.';
            } else if (e2.toString().contains('invalid-email')) {
              errorMessage = 'Bitte gib eine gültige Email-Adresse ein.';
            } else if (e2.toString().contains('wrong-password') || 
                       e2.toString().contains('invalid-credential')) {
              errorMessage = 'Falsches Passwort. Bitte versuche es erneut.';
            } else {
              errorMessage = 'Fehler: $e2';
            }
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        } else {
          // Anderer Fehler (nicht requires-recent-login)
          String errorMessage = 'Fehler beim Senden der Bestätigungs-Email.';
          if (e.toString().contains('email-already-in-use') || 
              e.toString().contains('already exists')) {
            errorMessage = 'Diese Email-Adresse wird bereits verwendet.';
          } else if (e.toString().contains('invalid-email')) {
            errorMessage = 'Bitte gib eine gültige Email-Adresse ein.';
          } else {
            errorMessage = 'Fehler: $e';
          }
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
    
    emailController.dispose();
    
    emailController.dispose();
  }
}

// Kontakt-Seite
class SocialMediaPage extends StatefulWidget {
  const SocialMediaPage({super.key});

  @override
  State<SocialMediaPage> createState() => _SocialMediaPageState();
}

class _SocialMediaPageState extends State<SocialMediaPage> {
  String? _pressedIcon;
  
  bool get _isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  Future<void> _openLink(String url, String iconName) async {
    setState(() {
      _pressedIcon = iconName;
    });

    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konnte Link nicht öffnen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Öffnen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Nach kurzer Zeit das visuelle Feedback entfernen
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _pressedIcon = null;
        });
      }
    });
  }

  Widget _buildSocialIcon({
    required IconData icon,
    required String url,
    required String name,
    required Color color,
    required String displayName,
  }) {
    final isPressed = _pressedIcon == name;
    // Im Dark Mode: weißer Hintergrund, sonst transparent
    final backgroundColor = _isDarkMode 
        ? (isPressed ? color.withOpacity(0.3) : Colors.white)
        : (isPressed ? color.withOpacity(0.3) : Colors.transparent);
    // Border-Farbe: im Dark Mode auf weißem Hintergrund dunkler, sonst wie bisher
    final borderColor = _isDarkMode
        ? (isPressed ? color : Colors.grey.shade400)
        : (isPressed ? color : Colors.grey.shade300);
    // Text-Farbe: im Dark Mode auf weißem Hintergrund dunkler
    final textColor = _isDarkMode ? Colors.grey[800] : Colors.grey[700];
    
    return GestureDetector(
      onTap: () => _openLink(url, name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isPressed ? 2 : 1,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.share,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Social Media',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Beschreibungstext
              Text(
                'Hier findest du mich auf verschiedenen Social Media Plattformen oder meiner Website',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 32),
              // Social Media Icons
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildSocialIcon(
                    icon: FontAwesomeIcons.facebook,
                    url: 'https://www.facebook.com/djollerganove',
                    name: 'facebook',
                    color: const Color(0xFF1877F2), // Facebook Blau
                    displayName: 'Facebook',
                  ),
                  _buildSocialIcon(
                    icon: FontAwesomeIcons.instagram,
                    url: 'https://www.instagram.com/djollerganove',
                    name: 'instagram',
                    color: const Color(0xFFE4405F), // Instagram Pink
                    displayName: 'Instagram',
                  ),
                  _buildSocialIcon(
                    icon: FontAwesomeIcons.tiktok,
                    url: 'https://www.tiktok.com/@ollerganove',
                    name: 'tiktok',
                    color: const Color(0xFF000000), // TikTok Schwarz
                    displayName: 'TikTok',
                  ),
                  _buildSocialIcon(
                    icon: FontAwesomeIcons.whatsapp,
                    url: 'https://wa.me/4915254168549',
                    name: 'whatsapp',
                    color: const Color(0xFF25D366), // WhatsApp Grün
                    displayName: 'WhatsApp',
                  ),
                  _buildSocialIcon(
                    icon: FontAwesomeIcons.spotify,
                    url: 'https://open.spotify.com/playlist/2oVYkMONLq5MVsuJn0fxGO?si=5r9mK_cfTvaJLroSTYanww',
                    name: 'spotify',
                    color: const Color(0xFF1DB954), // Spotify Grün
                    displayName: 'Spotify',
                  ),
                  _buildSocialIcon(
                    icon: FontAwesomeIcons.globe,
                    url: 'https://www.dj-ollerganove.de',
                    name: 'website',
                    color: Theme.of(context).colorScheme.primary,
                    displayName: 'Website',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Über DJ WB Seite
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ÜBER DJ WB',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // App-Informationen
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DJ Wunschbox',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Version: 1.0.0',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Die DJ Wunschbox App ermöglicht es dir, Musikwünsche für deine Lieblings-Party zu senden.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Links zu Impressum und DSGVO
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Impressum'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ImpressumPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Datenschutzerklärung (DSGVO)'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DSGVOPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Impressum-Seite
class ImpressumPage extends StatelessWidget {
  const ImpressumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impressum'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Angaben gemäß § 5 TMG',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'DJ Ollerganove',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Anschrift:\n'
                        '[Ihre Straße und Hausnummer]\n'
                        '[PLZ Ort]',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kontakt',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Telefon: [Ihre Telefonnummer]\n'
                        'E-Mail: info@dj-ollerganove.de',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verantwortlich für den Inhalt nach § 55 Abs. 2 RStV',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'DJ Ollerganove\n'
                        '[Ihre Straße und Hausnummer]\n'
                        '[PLZ Ort]',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// DSGVO-Seite
class DSGVOPage extends StatefulWidget {
  const DSGVOPage({super.key});

  @override
  State<DSGVOPage> createState() => _DSGVOPageState();
}

class _DSGVOPageState extends State<DSGVOPage> {
  String _privacyText = '';

  @override
  void initState() {
    super.initState();
    _loadPrivacyText();
  }

  Future<void> _loadPrivacyText() async {
    try {
      final text = await DefaultAssetBundle.of(context).loadString('assets/datenschutz.txt');
      setState(() {
        _privacyText = text;
      });
    } catch (e) {
      // Datei existiert noch nicht oder ist leer, zeige Platzhalter
      setState(() {
        _privacyText = 'Die Datenschutzerklärung wird noch erstellt und hier eingefügt.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datenschutzerklärung'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _privacyText.isEmpty
                    ? 'Lade Datenschutzerklärung...'
                    : _privacyText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContactPage extends StatefulWidget {
  final GlobalKey<_ContactFormState>? contactFormKey;
  
  const ContactPage({super.key, this.contactFormKey});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  late final GlobalKey<_ContactFormState> _formKey;
  
  @override
  void initState() {
    super.initState();
    // Verwende den übergebenen Key oder erstelle einen neuen
    _formKey = widget.contactFormKey ?? GlobalKey<_ContactFormState>();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.contact_mail,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kontakt',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ContactForm(formKey: _formKey),
            ],
          ),
        ),
      ),
    );
  }
}
