part of 'main.dart';

class DJOgApp extends StatefulWidget {
  const DJOgApp({super.key});

  @override
  State<DJOgApp> createState() => _DJOgAppState();
}

class _DJOgAppState extends State<DJOgApp> {
  @override
  void initState() {
    super.initState();
    LocaleHelper.localeNotifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleHelper.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleHelper.localeNotifier.value;
    return MaterialApp(
      navigatorKey: appRootNavigatorKey,
      title: 'DJ OG – Wünsche',
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de'),
        Locale('en'),
        Locale('fr'),
        Locale('ru'),
        Locale('zh'),
        Locale('es'),
        Locale('tr', ''),
        // Locale('ar'), // deaktiviert: siehe LocaleHelper.supportedLanguageCodes
        Locale('pt'),
        Locale('it'),
        Locale('uk'),
      ],
      builder: (context, child) {
        // Hybrid-RTL: Globales Layout bleibt LTR (Hamburger/Icons/Navigation bleiben)
        // Nur Arabisch soll nicht automatisch auf RTL umschalten.
        if (locale.languageCode == 'ar') {
          // widgets.TextDirection aus package:flutter/widgets.dart (kein Konflikt mit dart:ui).
          return Directionality(
            textDirection: widgets.TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505), // Fast reines Schwarz
        primaryColor: const Color(0xFF00F2FF), // Neon-Blau
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F2FF), // Neon-Blau
          secondary: Color(0xFF0072FF), // Gradient-Endfarbe
          surface: Color(0xFF1F2937), // Helleres Grau-Blau für Cards
          onPrimary: Color(0xFF050505), // Dunkler Text auf Neon-Blau
          onSecondary: Color(0xFFFFFFFF), // Strahlendes Weiß
          onSurface: Color(0xFFFFFFFF), // Strahlendes Weiß
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
          bodyMedium: TextStyle(color: Color(0xFFFFFFFF)),
          bodySmall: TextStyle(color: Color(0xFFFFFFFF)),
          titleLarge: TextStyle(color: Color(0xFFFFFFFF)),
          titleMedium: TextStyle(color: Color(0xFFFFFFFF)),
          titleSmall: TextStyle(color: Color(0xFFFFFFFF)),
          labelLarge: TextStyle(color: Color(0xFFFFFFFF)),
          labelMedium: TextStyle(color: Color(0xFFFFFFFF)),
          labelSmall: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00F2FF), // Neon-Blau
            foregroundColor: const Color(0xFF050505), // Dunkler Text
            elevation: 0,
            shadowColor: const Color(0xFF00F2FF).withValues(alpha: 0.8),
          ).copyWith(
            elevation: WidgetStateProperty.all(0),
            shadowColor: WidgetStateProperty.all(const Color(0xFF00F2FF).withValues(alpha: 0.8)),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF00F2FF)), // Neon-Blau
            foregroundColor: WidgetStateProperty.all(const Color(0xFF050505)), // Dunkler Text
            elevation: WidgetStateProperty.all(0),
            shadowColor: WidgetStateProperty.all(const Color(0xFF00F2FF).withValues(alpha: 0.9)),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00F2FF), // Neon-Blau für Text
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1F2937), // Helleres Grau-Blau
          elevation: 8,
          shadowColor: const Color(0xFF00F2FF).withValues(alpha: 0.4), // Hellerer Neon-Blau Glow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: Color(0xFF00F2FF), // Neon-Blau Border
              width: 0.5,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: UIConstants.appBarBackgroundColor,
          foregroundColor: UIConstants.appBarForegroundColor,
          elevation: 0,
          iconTheme: UIConstants.appBarIconTheme,
          titleTextStyle: UIConstants.appBarTitleTextStyle,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1F2937), // Helleres Grau-Blau
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF00F2FF), // Neon-Blau für Trennlinien
          thickness: 1,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF00F2FF), // Neon-Blau Icons
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2D3748), // Hellerer Hintergrund für Eingabefelder
          labelStyle: const TextStyle(color: Color(0xFF00F2FF)), // Neon-Blau Labels
          hintStyle: TextStyle(color: const Color(0xFFFFFFFF).withValues(alpha: 0.7)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: const Color(0xFF00F2FF).withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: const Color(0xFF00F2FF).withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF00F2FF), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          errorStyle: const TextStyle(color: Colors.red),
        ),
      ),
      themeMode: ThemeMode.dark,
      // Eine MainPage-Instanz als home – keine verschachtelte MainPage (siehe FirestoreEmailVerifiedGate).
      home: const RepaintBoundary(
        child: MainPage(),
      ),
      routes: {
        '/wishes': (context) => const WishesPage(),
        '/contact': (context) => const ContactPage(),
        '/paywall': (context) => const PaywallPage(),
        '/register': (context) => const LoginPage(startInRegister: true),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
