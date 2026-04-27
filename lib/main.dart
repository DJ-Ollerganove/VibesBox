import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/widgets.dart' as widgets;

import 'dart:ui' as ui;


import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kDebugMode;

import 'app_navigator_keys.dart';
import 'services/app_local_notifications.dart';
import 'services/dj_wish_notification_service.dart';

import 'dart:async';

import 'dart:io';

import 'dart:math' as math;

import 'app_scaffold_messenger.dart';
import 'firebase_options.dart';

import 'pages/paywall_page.dart';

import 'spotify_page.dart';

import 'test_page.dart';

import 'party_verwaltung_page.dart';

import 'pages/profil_page.dart';

import 'pages/settings_page.dart';
import 'pages/guest_settings_page.dart';

import 'pages/home_page.dart';

import 'pages/wishes_page.dart' show WishesPage, ContactForm, ContactFormState;

import 'pages/benutzer_verwaltung_page.dart';

import 'pages/deine_wunsche_page.dart';

import 'pages/social_media_page.dart';

import 'pages/about_page.dart';
import 'pages/dj/quickstart_page.dart';

import 'pages/contact_page.dart';

import 'pages/impressum_page.dart';

import 'pages/dsgvo_page.dart';

import 'pages/terms_of_service_page.dart';

import 'pages/login_page.dart';

import 'offen_page.dart';

import 'dj_vibesbox_page.dart';

import 'pages/gesperrt_page.dart';

import 'pages/todo_page.dart';

import 'pages/history/history_page.dart';

import 'widgets/shazam_footer.dart';
import 'widgets/scroll_indicator_overlay.dart';
import 'widgets/legal_page_scope.dart';
import 'widgets/mandatory_profile_dialog.dart';
import 'widgets/email_verification_result_dialog.dart';
import 'widgets/deep_state_newspaper.dart';

import 'l10n/locale_helper.dart';

import 'l10n/app_localizations.dart';

import 'config/app_config.dart';
import 'services/text_scale_service.dart';
import 'constants/app_assets.dart';

import 'utils/ui_constants.dart';
import 'utils/network_image_url.dart';
import 'utils/role_helper.dart';

import 'services/party_autostart_service.dart';
import 'services/history_provider.dart';
import 'services/active_party_service.dart';
import 'services/party_session_service.dart';
import 'services/remote_config_service.dart';
import 'services/app_check_service.dart';
import 'services/email_verification_gate_sync.dart';
import 'services/party_cleanup_service.dart';
import 'services/app_update_service.dart';
import 'services/global_announcement_popup_service.dart';
import 'services/subscription_sync_service.dart';
import 'services/admin_service.dart';
import 'services/user_service.dart';
import 'services/registration_flow_guard.dart';
import 'services/auth_service.dart';
import 'services/app_links_service.dart';
import 'services/navigation_service.dart';
import 'services/shazam_service.dart';
import 'services/countries_service.dart';
import 'services/revenue_cat_bootstrap.dart';
import 'services/pro_free_check.dart';
import 'services/pro_feature_guard.dart';
import 'services/biometric_service.dart';
import 'services/saved_login_email_store.dart';
import 'models/song_request.dart';
import 'models/user_model.dart';
import 'utils/auth_stream_utils.dart';
import 'utils/debug_log.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:otp/otp.dart';

part 'main_djog_app.dart';
part 'main_main_page.dart';

/// Globaler Zugriff auf den Haupt-[Scaffold] (Drawer, SnackBars).
final GlobalKey<ScaffoldState> mainPageScaffoldKey = GlobalKey<ScaffoldState>();

// Globale Theme-Notifier - Immer Dark Mode

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.dark,
);

// Sanitizer wurden nach lib/utils/sanitize.dart ausgelagert.

// Hilfsfunktion zum Anzeigen von Firebase-Fehlern mit klickbaren Links

Widget buildFirebaseErrorWidget(Object error) {
  final errorString = error.toString();

  // Suche nach Firebase-Console-Links (verschiedene Patterns)

  String? url;

  // Pattern 1: Standard Firebase Console Link

  final urlRegex1 = RegExp(
    r'https://console\.firebase\.google\.com/[^\s\)\]]+',
  );

  final match1 = urlRegex1.firstMatch(errorString);

  if (match1 != null) {
    url = match1.group(0);
  }

  // Pattern 2: Falls URL in Anführungszeichen steht

  if (url == null) {
    final urlRegex2 = RegExp(
      r'https://console\.firebase\.google\.com/[^\s\)\]]+',
    );

    final match2 = urlRegex2.firstMatch(errorString);

    if (match2 != null) {
      url = match2.group(0);
    }
  }

  // Pattern 3: Suche nach "https://" und nimm alles bis zum nächsten Leerzeichen oder Zeilenende

  if (url == null) {
    final urlRegex3 = RegExp(
      r'https://console\.firebase\.google\.com/[^\s\n]+',
    );

    final match3 = urlRegex3.firstMatch(errorString);

    if (match3 != null) {
      url = match3.group(0);
    }
  }

  if (url != null) {
    // Bereinige die URL (entferne mögliche abschließende Zeichen)

    final cleanUrl = url.replaceAll(RegExp(r'[\)\]\},;]+$'), '');

    return Builder(
      builder: (context) {
        final l = AppLocalizations.of(context)!;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Text(
                  l.firebase_index_required_title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l.firebase_index_instruction,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: SelectableText(
                    cleanUrl,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: cleanUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.url_copied_to_clipboard_snackbar),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(l.url_copy),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                          SnackBar(
                            content: Text(l.url_launch_failed_snackbar),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l.url_open_error_with_detail_snackbar('$e'),
                            ),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l.open_in_browser),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.firebase_index_browser_tip,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Fallback: Normale Fehlermeldung mit vollständigem Text

  return Builder(
    builder: (context) {
      final l = AppLocalizations.of(context)!;
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                l.error_occurred_generic,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
    },
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
    debugLog('Fehler beim Erhöhen von deleted_count: $e');
  }
}

// Initialisiert die Rollen-Collection mit Gast, DJ und Admin

Future<void> initializeRoles() async {
  try {
    debugLog('🔧 Initialisiere Rollen-Collection...');

    // Prüfe ob Rollen bereits existieren

    final rolesSnapshot = await FirebaseFirestore.instance
        .collection('roles')
        .get();

    if (rolesSnapshot.docs.isEmpty) {
      // Erstelle Rollen

      final roles = [
        {'name': 'Gast', 'level': 1},

        {'name': 'DJ', 'level': 2},

        {'name': 'Admin', 'level': 3},
      ];

      for (final role in roles) {
        await FirebaseFirestore.instance.collection('roles').add(role);
      }

      debugLog('✅ Rollen erfolgreich erstellt: Gast, DJ, Admin');
    } else {
      debugLog('ℹ️ Rollen existieren bereits');

      for (final doc in rolesSnapshot.docs) {
        debugLog('   - ${doc.data()['name']} (ID: ${doc.id})');
      }
    }
  } catch (e) {
    debugLog('❌ Fehler beim Initialisieren der Rollen: $e');
  }
}

// getRoleIdByName wurde nach lib/utils/role_helper.dart ausgelagert.

// ---------------------------------------------------------------------------
// Debug-only: Firestore-Flag email_verified_override für Bestands-User (FirestoreEmailVerifiedGate)
// ---------------------------------------------------------------------------

bool _silentEmailVerificationMigrationRunning = false;

/// Setzt auf allen Dokumenten in [users] das Feld [email_verified_override] = true.
/// Läuft **nur** in [kDebugMode], **einmal pro Gerät** (SharedPreferences), und nur wenn
/// der eingeloggte User die in [firestore.rules] freigegebene Admin-UID ist (sonst schlagen
/// Mass-Updates fehl).
Future<void> _runSilentEmailVerificationMigration() async {
  if (!kDebugMode) return;

  if (_silentEmailVerificationMigrationRunning) return;

  if (!AppConfig.isAdminRole(UserService().currentUser.value)) {
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  const prefKey = 'debug_silent_email_verified_override_migration_v1_done';
  if (prefs.getBool(prefKey) == true) {
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  final adminUid = AppConfig.adminDjId;
  if (user == null || adminUid == null || user.uid != adminUid) {
    return;
  }

  _silentEmailVerificationMigrationRunning = true;
  try {
    debugLog('[Migration] Start: email_verified_override für alle users/* …');
    final firestore = FirebaseFirestore.instance;
    const pageSize = 400;
    DocumentSnapshot? cursor;
    var totalUpdated = 0;

    while (true) {
      Query<Map<String, dynamic>> q = firestore
          .collection('users')
          .orderBy(FieldPath.documentId)
          .limit(pageSize);
      if (cursor != null) {
        q = q.startAfterDocument(cursor);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'email_verified_override': true});
      }
      await batch.commit();
      totalUpdated += snap.docs.length;
      cursor = snap.docs.last;
      if (snap.docs.length < pageSize) break;
    }

    await prefs.setBool(prefKey, true);
    debugLog(
      '[Migration] Fertig. $totalUpdated User-Dokument(e) mit email_verified_override aktualisiert.',
    );
  } catch (e, st) {
    debugLog('[Migration] Fehler: $e\n$st');
  } finally {
    _silentEmailVerificationMigrationRunning = false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tab-Index + Admin-Ansicht vor dem ersten Frame aus Prefs – verhindert Race mit MainPage.initState.
  await NavigationService().hydrateNavigationFromPrefs();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Diese App (iOS/Android): Firestore-Standard = lokale Persistenz auf dem Gerät.
  // Die eingebettete Web-PWA (vb/) nutzt separat memoryLocalCache — kein gemeinsamer
  // Multi-Tab-Listener; Konflikte zwischen beiden Clients entstehen nicht.

  try {
    await RemoteConfigService.initialize();
    debugLog('✅ Remote Config Service initialisiert');
  } catch (e) {
    debugLog('⚠️ Fehler beim Initialisieren des Remote Config Service: $e');
  }

  // App Check immer (Debug: Debug-Provider + Token in Console; Release: Play Integrity / App Attest).
  // Wichtig: Cloud Function sendAuthEmail erzwingt App Check — ohne Init schlagen Registrierung/Passwort-Mail fehl.
  try {
    await AppCheckService.initialize();
  } catch (e) {
    debugLog('⚠️ App Check Init: $e');
  }
  if (!RemoteConfigService.isAppCheckEnabled()) {
    debugLog(
      'ℹ️ Remote Config: enable_app_check=false — App Check läuft trotzdem für geschützte Callables.',
    );
  }

  await LocaleHelper.initializeAppLocale();

  await TextScaleService.instance.load();

  await _setFirebaseAuthLocaleHeader();

  // Debug: einmalige Firestore-Migration email_verified_override (siehe FirestoreEmailVerifiedGate)
  if (kDebugMode) {
    authStateChangesDistinctByUid().listen((_) {
      unawaited(_runSilentEmailVerificationMigration());
    });
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 2),
        _runSilentEmailVerificationMigration,
      ),
    );
  }

  // Einmalig: Länder-Collection in Firestore befüllen (ohne await = läuft im Hintergrund, blockiert nicht)
  CountriesService.seedCountries();

  // ✅ Lade globale Admin-Einstellungen (z. B. pdf_footer_text) für PDF-Generierung
  try {
    await AppConfig.loadGlobalSettings();
    debugLog('✅ Global Settings (admin_config/global_settings) geladen');
  } catch (e) {
    debugLog('⚠️ Fehler beim Laden der Global Settings: $e');
  }

  // Spotify-Suchfilter: nicht beim Cold Start / Login — wird bei erster Spotify-Suche
  // (SpotifyService) bzw. auf der Spotify-Einstellungsseite geladen (siehe ensureLoadedForSearch).

  // ✅ Lade PartySessionService + Hydrierung (shortCode ohne djId/djPlan → validateAndJoin)
  await PartySessionService.instance.loadFromPrefs();
  await PartySessionService.instance.hydrateIfNeeded();

  // RevenueCat (nur Mobile): kurz verzögert starten — entlastet den Main-Thread vor runApp
  if (!kIsWeb) {
    unawaited(RevenueCatBootstrap.ensureConfigured());
  }

  // Rollen-Seed nur bei explizitem Setup-Run (kein regulärer App-Start-Prozess).
  if (const bool.fromEnvironment('RUN_ROLE_SEED', defaultValue: false)) {
    await initializeRoles();
  }

  // Admin- und DJ-Rollen-IDs für Berechtigungsprüfung (role_id statt E-Mail)
  final adminRoleId = await getRoleIdByName('Admin');
  AppConfig.setAdminRoleId(adminRoleId);
  final djRoleId = await getRoleIdByName('DJ');
  AppConfig.setDjRoleId(djRoleId);
  final guestRoleId = await getRoleIdByName('Gast');
  AppConfig.setGuestRoleId(guestRoleId);
  final locationRoleId = await getRoleIdByName('Location');
  AppConfig.setLocationRoleId(locationRoleId);

  // Alle roles-Dokument-IDs pro Name (verhindert Logout, wenn users.role_id auf ein
  // zweites Admin-/DJ-Dokument zeigt — getRoleIdByName liefert nur die erste Zeile).
  AppConfig.allAdminRoleDocIds = await getAllRoleDocIdsByName('Admin');
  AppConfig.allDjRoleDocIds = await getAllRoleDocIdsByName('DJ');
  AppConfig.allGuestRoleDocIds = await getAllRoleDocIdsByName('Gast');
  AppConfig.allLocationRoleDocIds = await getAllRoleDocIdsByName('Location');
  if (adminRoleId != null) AppConfig.allAdminRoleDocIds.add(adminRoleId);
  if (djRoleId != null) AppConfig.allDjRoleDocIds.add(djRoleId);
  if (guestRoleId != null) AppConfig.allGuestRoleDocIds.add(guestRoleId);
  if (locationRoleId != null) AppConfig.allLocationRoleDocIds.add(locationRoleId);

  AppConfig.markRoleDocIdSetsHydrated();

  // Lade Theme-Einstellung

  await _loadThemeMode();

  // Local Notifications: [initializeAppLocalNotifications] in [main] (ohne Permission-Prompt).

  // ActivePartyService + HistoryProvider: erst nach stabiler Auth/E-Mail-Check in [MainPage]
  // (_ensureDeferredFirestoreStreamsOnce), damit keine Firestore-Zugriffe während des Verify-Gates.

  // Initialisiere Timezone-Datenbank (für Zeitzonen-Namen)
  try {
    tz_data.initializeTimeZones();
    debugLog('✅ Timezone-Datenbank initialisiert');
  } catch (e) {
    debugLog('⚠️ Fehler beim Initialisieren der Timezone-Datenbank: $e');
  }

  // Party-Daten-Cleanup: nur für eingeloggte Admins aus [MainPage._runColdStartServicesForUser]
  // (kein parties.get() ohne Berechtigung beim App-Start).

  if (!kIsWeb) {
    unawaited(initializeAppLocalNotifications());
  }
  DjWishNotificationService.instance.attach();

  runApp(const UserScopeWrapper());
}

/// Stellt den zentralen User-Stream bereit und startet ihn beim App-Start.
class UserScopeWrapper extends StatefulWidget {
  const UserScopeWrapper({super.key});

  @override
  State<UserScopeWrapper> createState() => _UserScopeWrapperState();
}

class _UserScopeWrapperState extends State<UserScopeWrapper> {
  @override
  void initState() {
    super.initState();
    UserService().startUserStream();
  }

  @override
  Widget build(BuildContext context) {
    return UserScope(
      notifier: UserService().currentUser,
      child: const DJOgApp(),
    );
  }
}

Future<void> _setFirebaseAuthLocaleHeader() async {
  try {
    final locale = await LocaleHelper.getSavedOrDeviceLocale();
    final lang = (locale.languageCode).trim().isEmpty
        ? 'en'
        : locale.languageCode.trim();
    await FirebaseAuth.instance.setLanguageCode(lang);
    debugLog('🌐 FirebaseAuth Sprache gesetzt: $lang');
  } catch (e) {
    debugLog('⚠️ FirebaseAuth Sprache konnte nicht gesetzt werden: $e');
  }
}

Future<void> _loadThemeMode() async {
  // Immer Dark Mode - keine Speicherung nötig

  themeModeNotifier.value = ThemeMode.dark;
}

Future<void> setThemeMode(ThemeMode mode) async {
  // Immer Dark Mode - keine Änderung möglich

  themeModeNotifier.value = ThemeMode.dark;
}

// DJOgApp wurde nach lib/main_djog_app.dart ausgelagert (part of main.dart).

// MainPage wurde nach lib/main_main_page.dart ausgelagert (part of main.dart).

// SplashScreen wurde nach lib/pages/splash_screen.dart ausgelagert.

// LoginPage / FirestoreEmailVerifiedGate: lib/pages/login_page.dart; App-Home: MainPage.

// ImpressumPage wurde nach lib/pages/impressum_page.dart ausgelagert.

// DSGVOPage wurde nach lib/pages/dsgvo_page.dart ausgelagert.

// ContactPage wurde nach lib/pages/contact_page.dart ausgelagert.
