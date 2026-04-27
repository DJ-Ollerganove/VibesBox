import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../utils/debug_log.dart';

/// Zentrale Konfigurationsdatei für alle URLs, Adressen und Zugangsdaten
/// 
/// Admin-Berechtigung wird über Firestore role_id gesteuert (nicht E-Mail).
class AppConfig {
  // PWA URL - Hauptdomain der Web-App
  static const String pwaUrl = 'https://vibesbox.app';
  
  // Website URL - Hauptwebsite
  static const String websiteUrl = 'https://www.dj-ollerganove.de';
  
  // Firebase Konfiguration
  static const String firebaseProjectId = 'dj-ollerganove';
  static const String firebaseAuthDomain = 'dj-ollerganove.firebaseapp.com';
  static const String firebaseStorageBucket = 'dj-ollerganove.firebasestorage.app';
  
  // Cloud Functions URLs
  static String get spotifyFunctionUrl => 
      'https://us-central1-$firebaseProjectId.cloudfunctions.net/searchSpotifyTracks';
  
  static String get saveToMusicDatabaseFunctionUrl => 
      'https://us-central1-$firebaseProjectId.cloudfunctions.net/saveToMusicDatabase';

  /// Globale Sprach-Statistik (`language_stats`), vgl. PWA `recordLanguageHit`.
  static String get recordLanguageHitFunctionUrl =>
      'https://us-central1-$firebaseProjectId.cloudfunctions.net/recordLanguageHit';
  
  static String get validateRecaptchaFunctionUrl =>
      'https://validaterecaptchaandsavecontact-5yehncoc7a-uc.a.run.app';

  /// App-Security-Key für Kontaktformular (Gäste-Modus ohne reCAPTCHA).
  /// Wird im Header X-App-Security-Key gesendet; Cloud Function prüft diesen Key gegen Spam.
  /// Release: optional `--dart-define=CONTACT_APP_SECURITY_KEY=...` (gleicher Wert wie
  /// `CONTACT_APP_GUEST_SECURITY_KEY` in Firebase Functions).
  static const String contactAppSecurityKey = String.fromEnvironment(
    'CONTACT_APP_SECURITY_KEY',
    defaultValue: 'vb-app-guest-2024-secure-key',
  );

  /// Google Maps / Places (Einschränkungen in Google Cloud Console setzen).
  /// Optional: `--dart-define=GOOGLE_MAPS_API_KEY=...`
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyC2ayswzUpQH_iEJDcASifUvb3GW8x6YAU',
  );

  /// RevenueCat SDK (Google Play `goog_…`; iOS ggf. separater `appl_…` per Build-Define).
  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'goog_sSzleukMHbvskClLmpQULcJTDmH',
  );
  
  // E-Mail Adressen
  static const String adminEmail = 'info@vibesbox.app';
  static const String noreplyEmail = 'noreply@vibesbox.app';
  /// Support-E-Mail für Fehlermeldungen (z. B. Profil-Daten konnten nicht geladen werden)
  static const String supportEmail = 'info@vibesbox.app';
  
  // Admin-DJ-Verknüpfung
  // Die DJ-ID, die dem Admin-Account zugeordnet ist
  // WICHTIG: Diese ID muss die Firebase User-ID (UID) des DJ-Accounts sein
  // FEST EINGETRAGEN: Die ID ist fest eingetragen und wird nicht mehr automatisch gesucht
  static String? adminDjId = 'rtJXMTULzTPUz0xtdQOw9Jm8SGD3'; // Firebase UID des DJ-Accounts

  /// Master-Admin (gleiche UID wie Cloud Function `MASTER_ADMIN_UID` / Mass-Verify).
  static bool isMasterAdminFirebaseUid(String? uid) {
    final id = adminDjId;
    if (id == null || id.isEmpty) return false;
    return uid != null && uid == id;
  }

  /// Einmal-Migration E-Mail: Trigger im Drawer nur mit
  /// `flutter run --dart-define=MASS_VERIFY_TRIGGER=true` (sonst unsichtbar).
  /// Muss dieselbe UID sein wie `firebase functions:config:set massverify.admin_uid=...`.
  static const bool massVerifyTriggerEnabled =
      bool.fromEnvironment('MASS_VERIFY_TRIGGER', defaultValue: false);

  /// PDF-Footer-Text aus admin_config/global_settings.
  /// Wird einmalig beim App-Start geladen, damit die PDF-Generierung ohne DB-Wartezeit auskommt.
  static String? pdfFooterText;

  /// Lädt admin_config/global_settings und setzt pdfFooterText.
  /// Soll beim App-Start einmalig aufgerufen werden.
  static Future<void> loadGlobalSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_config')
          .doc('global_settings')
          .get();
      final text = doc.data()?['pdf_footer_text'] as String?;
      pdfFooterText = (text != null && text.trim().isNotEmpty) ? text.trim() : null;
    } catch (_) {
      pdfFooterText = null;
    }
  }
  
  /// Lädt die adminDjId aus der Firebase-Datenbank
  /// Sucht nach einem User mit der Rolle "DJ" und der E-Mail des DJs
  /// Falls nicht gefunden, muss die ID manuell gesetzt werden
  /// DEAKTIVIERT: Diese Funktion wird nicht mehr automatisch aufgerufen, da die ID fest eingetragen ist
  /// Falls die ID geändert werden muss, bitte manuell in dieser Datei setzen
  /*
  static Future<String?> loadAdminDjId() async {
    if (adminDjId != null) {
      return adminDjId;
    }
    
    try {
      // Versuche, die DJ-ID über die parties-Collection zu finden
      // Suche nach Partys, die von einem User mit der Admin-E-Mail erstellt wurden
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by_email', isEqualTo: adminEmail)
          .limit(1)
          .get();
      
      if (partiesQuery.docs.isNotEmpty) {
        final partyData = partiesQuery.docs.first.data() as Map<String, dynamic>;
        final djId = partyData['created_by'] as String?;
        if (djId != null && djId.isNotEmpty) {
          adminDjId = djId;
          debugLog('✅ AppConfig: adminDjId automatisch geladen: $djId');
          return djId;
        }
      }
      
      // Fallback: Suche in users-Collection nach E-Mail
      // UND prüfe, ob dieser User Partys erstellt hat
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: adminEmail)
          .limit(1)
          .get();
      
      if (usersQuery.docs.isNotEmpty) {
        final userDoc = usersQuery.docs.first;
        final userId = userDoc.id;
        
        // Prüfe, ob dieser User Partys erstellt hat
        final userPartiesQuery = await FirebaseFirestore.instance
            .collection('parties')
            .where('created_by', isEqualTo: userId)
            .limit(1)
            .get();
        
        if (userPartiesQuery.docs.isNotEmpty) {
          adminDjId = userId;
          debugLog('✅ AppConfig: adminDjId über User-Partys gefunden');
          return userId;
        }
      }
      
      // HINWEIS: Falls die ID nicht automatisch gefunden wird,
      // muss sie manuell in der Config gesetzt werden
      debugLog('⚠️ AppConfig: adminDjId konnte nicht automatisch ermittelt werden.');
      debugLog('⚠️ AppConfig: Bitte manuell setzen mit: AppConfig.setAdminDjId("DEINE_DJ_UID")');
      debugLog('⚠️ AppConfig: Oder in der Firebase Console nach einem User mit E-Mail "$adminEmail" suchen, der Partys erstellt hat.');
      return null;
    } catch (e) {
      debugLog('❌ AppConfig: Fehler beim Laden der adminDjId: $e');
      return null;
    }
  }
  */
  
  /// Setzt die adminDjId manuell (falls automatisches Laden fehlschlägt)
  static void setAdminDjId(String djId) {
    adminDjId = djId;
    debugLog('✅ AppConfig: adminDjId manuell gesetzt: $djId');
  }
  
  // PWA URL Builder - Helper für Party-Code URLs
  // Format: https://vibesbox.app/?code=PARTYCODE
  static String buildPwaUrlWithCode(String partyCode) {
    return '$pwaUrl/?code=$partyCode';
  }
  
  /// Firestore-Rollen-ID für "Admin" (wird in main() via getRoleIdByName('Admin') gesetzt).
  static String? adminRoleId;

  /// Firestore-Rollen-ID für "DJ" (wird in main() via getRoleIdByName('DJ') gesetzt).
  static String? djRoleId;
  /// Firestore-Rollen-ID für "Gast" (wird in main() via getRoleIdByName('Gast') gesetzt).
  static String? guestRoleId;

  /// Setzt die Admin-Rollen-ID (wird beim App-Start aus Firestore geladen).
  static void setAdminRoleId(String? id) {
    adminRoleId = id;
    if (id != null) {
      debugLog('✅ AppConfig: Admin-Rollen-ID gesetzt: $id');
    }
  }

  /// Setzt die DJ-Rollen-ID (wird beim App-Start aus Firestore geladen).
  static void setDjRoleId(String? id) {
    djRoleId = id;
    if (id != null) {
      debugLog('✅ AppConfig: DJ-Rollen-ID gesetzt: $id');
    }
  }

  /// Setzt die Gast-Rollen-ID (wird beim App-Start aus Firestore geladen).
  static void setGuestRoleId(String? id) {
    guestRoleId = id;
    if (id != null) {
      debugLog('✅ AppConfig: Gast-Rollen-ID gesetzt: $id');
    }
  }

  /// Prüft, ob der User die Admin-Rolle hat (Boolean-Feld admin in users-Dokument).
  static bool isAdminRole(UserModel? userModel) {
    if (userModel == null) return false;
    if (userModel.admin == true) return true;
    return adminRoleId != null &&
        userModel.roleId != null &&
        userModel.roleId == adminRoleId;
  }

  /// Prüft, ob der User die DJ-Rolle hat (role_id == [djRoleId]).
  static bool isDjRole(UserModel? userModel) {
    if (userModel == null) return false;
    return djRoleId != null &&
        userModel.roleId != null &&
        userModel.roleId == djRoleId;
  }

  /// Bearbeitung von [admin_config/spotify_settings] (Blacklist, Filter) — nur App-Admin.
  static bool canManageSpotifySearchSettings(UserModel? userModel) {
    return isAdminRole(userModel);
  }

  /// Gibt die effektive DJ-ID zurück.
  /// Wenn der aktuelle User Admin-Rolle hat, wird adminDjId zurückgegeben, sonst userUid.
  static Future<String?> getEffectiveDjId(UserModel? currentUserModel, String? userUid) async {
    if (isAdminRole(currentUserModel) && adminDjId != null) {
      return adminDjId;
    }
    return userUid;
  }
}

