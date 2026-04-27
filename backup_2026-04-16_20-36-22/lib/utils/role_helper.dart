import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import '../services/user_service.dart';
import '../utils/debug_log.dart';

// Helper-Funktionen für Rollenprüfung (Berechtigung über Firestore role_id)

// Holt den Rollennamen für einen User aus Firestore (role_id → roles.name)
Future<String?> getUserRoleName(User? user) async {
  if (user == null) return null;

  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) return null;
    
    final roleId = userDoc.data()?['role_id'] as String?;
    if (roleId == null || roleId.isEmpty) return null;
    
    final roleDoc = await FirebaseFirestore.instance
        .collection('roles')
        .doc(roleId)
        .get();
    
    if (!roleDoc.exists) return null;
    
    return roleDoc.data()?['name'] as String?;
  } catch (e) {
    debugLog('❌ Fehler beim Abrufen der User-Rolle: $e');
    return null;
  }
}

// Prüft ob ein User eine bestimmte Rolle hat
Future<bool> hasRole(User? user, String roleName) async {
  if (user == null) return false;
  final userRoleName = await getUserRoleName(user);
  return userRoleName == roleName;
}

// Prüft ob ein User eine der angegebenen Rollen hat
Future<bool> hasAnyRole(User? user, List<String> roleNames) async {
  if (user == null) return false;
  final userRoleName = await getUserRoleName(user);
  return userRoleName != null && roleNames.contains(userRoleName);
}

// Prüft ob der übergebene User Admin ist (über Firestore role_id; aktueller User aus UserService)
bool isAdmin(User? user) {
  if (user == null) return false;
  final current = UserService().currentUser.value;
  return current != null && current.id == user.uid && AppConfig.isAdminRole(current);
}

// Prüft ob ein User DJ oder Location ist
Future<bool> isDJOrLocation(User? user) async {
  if (user == null) return false;
  final roleName = await getUserRoleName(user);
  return roleName == 'DJ' || roleName == 'Location';
}

// Prüft ob ein User Admin, DJ oder Location ist (für Party-Verwaltung)
Future<bool> canManageParties(User? user) async {
  if (user == null) return false;
  if (isAdmin(user)) return true;
  return await isDJOrLocation(user);
}

// Holt die Role-ID für einen Rollennamen (z.B. 'Gast', 'DJ', 'Admin')
Future<String?> getRoleIdByName(String roleName) async {
  try {
    final rolesSnapshot = await FirebaseFirestore.instance
        .collection('roles')
        .where('name', isEqualTo: roleName)
        .limit(1)
        .get();

    if (rolesSnapshot.docs.isNotEmpty) {
      return rolesSnapshot.docs.first.id;
    }

    return null;
  } catch (e) {
    debugLog('❌ Fehler beim Abrufen der Role-ID für $roleName: $e');
    return null;
  }
}




