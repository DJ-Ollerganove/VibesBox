import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_log.dart';

/// Globaler Haupt-Navigationstab-Index – überlebt [MainPage]-Neuaufbau (Screenshot, Fokus, Route).
/// [MainPage] liest/schreibt nur hier; kein lokaler State für den Tab.
///
/// **Hydration:** [hydrateNavigationFromPrefs] wird in [main] **vor** [runApp] einmal aufgerufen,
/// damit Tab-Index und Admin-Ansicht **synchron** verfügbar sind – kein Race mit
/// [MainPage.initState] und kein Zurückspringen durch verzögertes Nachladen.
class NavigationService {
  NavigationService._();
  static final NavigationService _instance = NavigationService._();
  factory NavigationService() => _instance;
  static NavigationService get instance => _instance;

  static const String _prefsKey = 'main_navigation_tab_index';
  static const String _prefsKeyAdminViewRole = 'admin_ui_view_role';
  static const String _prefsKeyPreferredStartView = 'preferred_start_view';

  /// Einmal pro Prozess: [hydrateNavigationFromPrefs] darf Prefs nur einmal einlesen.
  bool _hydratedFromPrefs = false;

  /// Synchroner Spiegel der Prefs (Admin „Admin“ vs „DJ“) – gesetzt bei Hydration/Persist/Clear.
  String? _cachedAdminViewRole;
  String _cachedPreferredStartView = 'admin_dashboard';

  /// Aktueller Tab-Index (IndexedStack).
  final ValueNotifier<int> currentTabIndex = ValueNotifier<int>(0);

  /// Nach [hydrateNavigationFromPrefs]: Admin-UI ohne await (für [MainPage]-init / erste Frames).
  String? get cachedAdminViewRole => _cachedAdminViewRole;
  String get cachedPreferredStartView => _cachedPreferredStartView;
  String get preferredStartView => _cachedPreferredStartView;

  static String _sanitizePreferredStartView(String? value) {
    switch (value) {
      case 'admin_dashboard':
      case 'dj_area':
      case 'guest_area':
        return value!;
      default:
        return 'admin_dashboard';
    }
  }

  /// Liest Tab + Admin-Ansicht **einmal** aus SharedPreferences – vor [runApp] aufrufen.
  Future<void> hydrateNavigationFromPrefs() async {
    if (_hydratedFromPrefs) return;
    _hydratedFromPrefs = true;
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getInt(_prefsKey);
      if (v != null && v >= 0 && v < 64) {
        currentTabIndex.value = v;
      }
      final s = p.getString(_prefsKeyAdminViewRole);
      if (s == 'DJ' || s == 'Admin') {
        _cachedAdminViewRole = s;
      } else {
        _cachedAdminViewRole = null;
      }
      _cachedPreferredStartView = _sanitizePreferredStartView(
        p.getString(_prefsKeyPreferredStartView),
      );
      debugLog(
        'NavigationService: hydrate – tab=${currentTabIndex.value}, adminView=${_cachedAdminViewRole ?? "null"}, preferredStart=$_cachedPreferredStartView',
      );
    } catch (e) {
      debugLog('NavigationService.hydrateNavigationFromPrefs: $e');
    }
  }

  /// @deprecated Verwende [hydrateNavigationFromPrefs] in [main]. Alias für Kompatibilität.
  Future<void> loadPersistedIndex() => hydrateNavigationFromPrefs();

  Future<void> _persist(int index) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_prefsKey, index);
    } catch (_) {}
  }

  /// Tab wechseln (Drawer, Deep Link, Party, …). Persistiert sofort.
  void setTabIndex(int index, {bool force = false}) {
    if (index < 0 || index > 63) return;
    if (!force && currentTabIndex.value == index) return;
    currentTabIndex.value = index;
    _persist(index);
  }

  /// Nur bei **echtem Logout** (Firebase signOut) – Tab auf Startseite.
  void resetToHome() {
    setTabIndex(0, force: true);
  }

  /// Admin-Konten: gewählte UI-Ansicht „Admin“ vs „DJ“ (überlebt [MainPage]-Neuaufbau).
  Future<String?> loadPersistedAdminViewRole() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_prefsKeyAdminViewRole);
      if (s == 'DJ' || s == 'Admin') {
        _cachedAdminViewRole = s;
        return s;
      }
      _cachedAdminViewRole = null;
      return null;
    } catch (e) {
      debugLog('NavigationService.loadPersistedAdminViewRole: $e');
      return null;
    }
  }

  Future<void> persistAdminViewRole(String? role) async {
    if (role == 'DJ' || role == 'Admin') {
      _cachedAdminViewRole = role;
    } else {
      _cachedAdminViewRole = null;
    }
    try {
      final p = await SharedPreferences.getInstance();
      if (role == null || (role != 'DJ' && role != 'Admin')) {
        await p.remove(_prefsKeyAdminViewRole);
      } else {
        await p.setString(_prefsKeyAdminViewRole, role);
      }
    } catch (e) {
      debugLog('NavigationService.persistAdminViewRole: $e');
    }
  }

  Future<void> clearAdminViewRole() async {
    _cachedAdminViewRole = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_prefsKeyAdminViewRole);
    } catch (e) {
      debugLog('NavigationService.clearAdminViewRole: $e');
    }
  }

  Future<String> loadPersistedPreferredStartView() async {
    try {
      final p = await SharedPreferences.getInstance();
      _cachedPreferredStartView = _sanitizePreferredStartView(
        p.getString(_prefsKeyPreferredStartView),
      );
      return _cachedPreferredStartView;
    } catch (e) {
      debugLog('NavigationService.loadPersistedPreferredStartView: $e');
      return _cachedPreferredStartView;
    }
  }

  Future<void> persistPreferredStartView(String value) async {
    final sanitized = _sanitizePreferredStartView(value);
    _cachedPreferredStartView = sanitized;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKeyPreferredStartView, sanitized);
    } catch (e) {
      debugLog('NavigationService.persistPreferredStartView: $e');
    }
  }

  Future<void> setPreferredStartView(String value) =>
      persistPreferredStartView(value);
}
