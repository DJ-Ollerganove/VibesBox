import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import '../services/user_service.dart';

/// Helper-Klasse für die Admin-DJ-Identitäts-Brücke (Berechtigung über Firestore role_id)
class AdminDjBridge {
  /// Gibt die effektive DJ-ID zurück (Admin-Rolle → adminDjId, sonst user.uid)
  static Future<String?> getEffectiveDjId(User? user, {bool forceDjMode = false}) async {
    if (user == null) return null;
    final currentModel = UserService().currentUser.value;
    final isAdmin = currentModel != null && currentModel.id == user.uid && AppConfig.isAdminRole(currentModel);

    if (isAdmin && forceDjMode && AppConfig.adminDjId != null) {
      return AppConfig.adminDjId;
    }
    return user.uid;
  }

  /// Prüft, ob der übergebene User die Admin-Rolle hat (aktueller User aus UserService)
  static bool isAdminUser(User? user) {
    if (user == null) return false;
    final current = UserService().currentUser.value;
    return current != null && current.id == user.uid && AppConfig.isAdminRole(current);
  }
  
  /// Prüft, ob der Admin im DJ-Modus ist
  /// (Wird durch einen View-Mode-State gesteuert)
  static bool isAdminInDjMode(String? viewMode) {
    // viewMode == 'DJ' bedeutet, dass Admin im DJ-Modus ist
    return viewMode == 'DJ';
  }
  
  /// Gibt die effektive DJ-ID basierend auf View-Mode zurück
  static Future<String?> getEffectiveDjIdByViewMode(User? user, String? viewMode) async {
    if (user == null) return null;
    
    final isAdmin = isAdminUser(user);
    final inDjMode = isAdmin && viewMode == 'DJ';
    
    return await getEffectiveDjId(user, forceDjMode: inDjMode);
  }
  
  /// Synchron-Version für Fälle, wo die adminDjId bereits geladen wurde
  /// WICHTIG: Nur verwenden, wenn sicher ist, dass adminDjId bereits gesetzt ist
  static String? getEffectiveDjIdSync(User? user, String? viewMode) {
    if (user == null) return null;
    
    final isAdmin = isAdminUser(user);
    final inDjMode = isAdmin && viewMode == 'DJ';
    
    if (isAdmin && inDjMode) {
      return AppConfig.adminDjId ?? user.uid;
    }
    
    return user.uid;
  }
}

