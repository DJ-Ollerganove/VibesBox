import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../helpers/security_helper.dart';
import '../services/admin_service.dart';
import '../services/pro_free_check.dart';
import '../utils/ui_constants.dart';
import '../l10n/app_localizations.dart';
import '../utils/debug_log.dart';

/// Rollen-Filter für die Admin-Benutzerliste (IDs aus [AppConfig]).
enum _BenutzerVerwaltungRoleFilter { admin, dj, guest }

// Benutzer-Verwaltungsseite für Admin
class BenutzerVerwaltungPage extends StatefulWidget {
  const BenutzerVerwaltungPage({super.key});

  @override
  State<BenutzerVerwaltungPage> createState() => _BenutzerVerwaltungPageState();
}

class _BenutzerVerwaltungPageState extends State<BenutzerVerwaltungPage> {
  Stream<QuerySnapshot>?
  _usersStream; // FIXIERT: Stream einmalig initialisiert (Anti-Flackern)
  Map<String, String> _roleNames = {}; // Cache für Rollen-Namen
  bool?
  _currentUserIsAdmin; // true wenn users/{uid}.admin == true (lokal geprüft für Passwort-Dialog)

  _BenutzerVerwaltungRoleFilter _roleListFilter =
      _BenutzerVerwaltungRoleFilter.dj;

  /// Initialisiert den Users-Stream sicher:
  /// - Admin: komplette users-Collection
  /// - Nicht-Admin/Fallback: nur eigenes users/{uid}-Dokument als zielgerichtete Query
  void _initializeUsersStream({required String uid, required bool isAdmin}) {
    final base = FirebaseFirestore.instance.collection('users');
    _usersStream = isAdmin
        ? base.snapshots()
        : base.where(FieldPath.documentId, isEqualTo: uid).snapshots();
  }

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _initializeUsersStream(uid: uid, isAdmin: false);
    }
    _loadRoleNames();
    _loadCurrentUserAdminFlag();
  }

  /// Lädt das admin-Flag des aktuellen Nutzers aus Firestore (users/{uid}.admin).
  /// Nur wenn true, darf der Passwort-Ändern-Dialog geöffnet werden.
  Future<void> _loadCurrentUserAdminFlag() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _currentUserIsAdmin = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isAdmin = doc.exists && (doc.data()?['admin'] == true);
      if (mounted) {
        setState(() {
          _currentUserIsAdmin = isAdmin;
          _initializeUsersStream(uid: user.uid, isAdmin: isAdmin);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _currentUserIsAdmin = false);
    }
  }

  // Lade alle Rollen-Namen in einen Cache
  Future<void> _loadRoleNames() async {
    try {
      // Prüfe ob User eingeloggt ist (Admin sollte eingeloggt sein)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugLog('⚠️ Kein User eingeloggt, kann Rollen nicht laden');
        return;
      }

      final rolesSnapshot = await FirebaseFirestore.instance
          .collection('roles')
          .get();

      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      final roleMap = <String, String>{};
      for (final doc in rolesSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        roleMap[doc.id] =
            (name != null && name.trim().isNotEmpty) ? name : l.unknown;
      }

      if (mounted) {
        setState(() {
          _roleNames = roleMap;
        });
      }
    } catch (e) {
      debugLog('❌ Fehler beim Abrufen der Rollen: $e');
    }
  }

  String? _roleIdFromUserDoc(Map<String, dynamic> data) {
    final r = data['role_id'];
    if (r == null) return null;
    if (r is String) {
      final t = r.trim();
      return t.isEmpty ? null : t;
    }
    final s = r.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool _userDocMatchesRoleFilter(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;
    final rid = _roleIdFromUserDoc(data);
    switch (_roleListFilter) {
      case _BenutzerVerwaltungRoleFilter.admin:
        if (data['admin'] == true) return true;
        final aid = AppConfig.adminRoleId?.trim();
        return aid != null && aid.isNotEmpty && rid != null && rid == aid;
      case _BenutzerVerwaltungRoleFilter.dj:
        final did = AppConfig.djRoleId?.trim();
        return did != null && did.isNotEmpty && rid != null && rid == did;
      case _BenutzerVerwaltungRoleFilter.guest:
        final gid = AppConfig.guestRoleId?.trim();
        return gid != null && gid.isNotEmpty && rid != null && rid == gid;
    }
  }

  /// Firestore-Admin-Konto (Boolean oder Admin-[role_id]) — kein Sperr-Toggle.
  bool _isFirestoreAdminAccount(Map<String, dynamic> data) {
    if (data['admin'] == true) return true;
    final rid = _roleIdFromUserDoc(data);
    final aid = AppConfig.adminRoleId?.trim();
    return aid != null && aid.isNotEmpty && rid != null && rid == aid;
  }

  /// Account-Sperre für Login (users.is_blocked / status).
  bool _isAccountLockedInUserDoc(Map<String, dynamic> data) {
    if (data['is_blocked'] == true) return true;
    final st = (data['status'] ?? '').toString().trim().toLowerCase();
    return st == 'gesperrt' || st == 'blocked';
  }

  bool _canToggleAccountLock({
    required String targetUid,
    required String roleName,
    required Map<String, dynamic> data,
  }) {
    if (_currentUserIsAdmin != true) return false;
    final self = FirebaseAuth.instance.currentUser?.uid;
    if (self == null || targetUid == self) return false;
    if (_isFirestoreAdminAccount(data)) return false;
    return roleName == 'DJ' || roleName == 'Gast';
  }

  Future<void> _toggleAccountLockFromAdmin({
    required BuildContext context,
    required String targetUid,
    required String displayName,
    required bool currentlyLocked,
  }) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              currentlyLocked ? Icons.lock_open : Icons.lock,
              color: Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                currentlyLocked
                    ? 'Konto entsperren?'
                    : 'Konto sperren (Login)?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          currentlyLocked
              ? 'Soll „$displayName“ wieder normal einloggen dürfen '
                  '(is_blocked=false, status=aktiv)?'
              : 'Soll „$displayName“ beim Login abgewiesen werden '
                  '(is_blocked=true, status=gesperrt)? '
                  'Party-/Gerätesperren bleiben unverändert.',
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
            ),
            child: Text(currentlyLocked ? 'Entsperren' : 'Sperren'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final payload = currentlyLocked
          ? <String, dynamic>{'is_blocked': false, 'status': 'aktiv'}
          : <String, dynamic>{'is_blocked': true, 'status': 'gesperrt'};
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .set(SecurityHelper.sanitizeMap(payload), SetOptions(merge: true));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyLocked
                ? 'Konto entsperrt: $displayName'
                : 'Konto gesperrt: $displayName',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugLog('Account-Sperre (Admin): $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.error}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _roleFilterDropdownLabel(_BenutzerVerwaltungRoleFilter f) {
    switch (f) {
      case _BenutzerVerwaltungRoleFilter.admin:
        final id = AppConfig.adminRoleId;
        if (id != null && id.isNotEmpty) {
          final n = _roleNames[id];
          if (n != null && n.isNotEmpty) return n;
        }
        return 'Admin';
      case _BenutzerVerwaltungRoleFilter.dj:
        final id = AppConfig.djRoleId;
        if (id != null && id.isNotEmpty) {
          final n = _roleNames[id];
          if (n != null && n.isNotEmpty) return n;
        }
        return 'DJ';
      case _BenutzerVerwaltungRoleFilter.guest:
        final id = AppConfig.guestRoleId;
        if (id != null && id.isNotEmpty) {
          final n = _roleNames[id];
          if (n != null && n.isNotEmpty) return n;
        }
        return 'Gast';
    }
  }

  /// Liefert die Geräte-Daten des Eintrags mit dem neuesten [last_seen], oder null wenn keine devices bzw. kein last_seen.
  Map<String, dynamic>? _getNewestDevice(Map<String, dynamic>? devices) {
    if (devices == null || devices.isEmpty) return null;
    Map<String, dynamic>? newestData;
    DateTime? newestDate;
    for (final e in devices.entries) {
      final dev = e.value is Map
          ? Map<String, dynamic>.from(e.value as Map)
          : null;
      if (dev == null) continue;
      final lastSeen = dev['last_seen'];
      final DateTime d = lastSeen is Timestamp
          ? lastSeen.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      if (newestDate == null || d.isAfter(newestDate)) {
        newestDate = d;
        newestData = dev;
      } else if (newestDate != null && d == newestDate) {
        // Gleiches last_seen: höhere Build-Nummer in app_version bevorzugen (Summary-Zeile).
        final a = _appVersionBuildRank(dev['app_version']);
        final b = _appVersionBuildRank(newestData!['app_version']);
        if (a > b) newestData = dev;
      }
    }
    return newestData;
  }

  /// Extrahiert Klammer-Build aus "1.2.3 (31)" für Vergleich; sonst 0.
  int _appVersionBuildRank(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    final m = RegExp(r'\((\d+)\)\s*$').firstMatch(s);
    if (m != null) return int.tryParse(m.group(1)!) ?? 0;
    return 0;
  }

  /// Entfernt "Android" oder "iOS" aus der OS-Versionszeichenkette, liefert nur die Versionsnummer.
  String _osVersionOnly(String osVersion) {
    final s = osVersion.trim();
    if (s.isEmpty) return '–';
    final withoutAndroid = s
        .replaceFirst(RegExp(r'^Android\s*', caseSensitive: false), '')
        .trim();
    final withoutIos = withoutAndroid
        .replaceFirst(RegExp(r'^iOS\s*', caseSensitive: false), '')
        .trim();
    return withoutIos.isEmpty ? s : withoutIos;
  }

  String _formatAdminDeviceFieldValue(dynamic v) {
    if (v == null) return '–';
    if (v is Timestamp) return _formatDateTime(v.toDate());
    if (v is DateTime) return _formatDateTime(v);
    return v.toString();
  }

  static const _adminDeviceKnownKeys = {
    'app_version',
    'device_model',
    'os_version',
    'platform',
    'last_seen',
  };

  /// Werte pro Eintrag in `users.devices` (siehe [AppUpdateService.logUserAppVersion]).
  Widget _adminUserDeviceDetailBlock({
    required AppLocalizations l,
    required int index,
    required MapEntry<String, dynamic> entry,
  }) {
    const twentyFourHours = Duration(hours: 24);
    final storageKey = entry.key;
    final dev = entry.value is Map
        ? Map<String, dynamic>.from(entry.value as Map)
        : <String, dynamic>{};

    final platform = (dev['platform']?.toString() ?? '').toLowerCase();
    final lastSeen = dev['last_seen'] as Timestamp?;
    final lastSeenDate = lastSeen?.toDate();
    final isRecent = lastSeenDate != null &&
        DateTime.now().difference(lastSeenDate) < twentyFourHours;
    final icon = platform == 'ios' ? Icons.apple : Icons.android;

    final extraKeys = dev.keys
        .where((k) => !_adminDeviceKnownKeys.contains(k))
        .toList()
      ..sort();

    String nz(dynamic x) {
      if (x == null) return '–';
      final t = x.toString().trim();
      return t.isEmpty ? '–' : t;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              '${l.admin_user_section_devices} #${index + 1}',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.circle,
              size: 10,
              color: isRecent ? Colors.green : Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _detailRow(l.admin_device_map_key, storageKey),
        _detailRow(l.admin_device_platform, nz(dev['platform'])),
        _detailRow(l.admin_device_model, nz(dev['device_model'])),
        _detailRow(l.admin_device_os_version, nz(dev['os_version'])),
        _detailRow(l.admin_device_app_version, nz(dev['app_version'])),
        _detailRow(
          l.admin_device_last_seen,
          _formatAdminDeviceFieldValue(dev['last_seen']),
        ),
        for (final k in extraKeys) _detailRow(k, _formatAdminDeviceFieldValue(dev[k])),
      ],
    );
  }

  /// Formatiert Geburtstag aus Timestamp oder DateTime-fähigem Wert.
  String _formatBirthday(dynamic value) {
    if (value == null) return '–';
    if (value is Timestamp) return _formatDateOnly(value.toDate());
    if (value is DateTime) return _formatDateOnly(value);
    return '–';
  }

  String _formatDateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day.$month.$year';
  }

  /// Öffnet den Benutzer-Detail-Dialog (VibesBox-Stil). Nutzt nur [data] – keine neuen Firestore-Abfragen.
  void _showUserDetailDialog(BuildContext context, Map<String, dynamic> data) {
    final l = AppLocalizations.of(context)!;
    final displayName = () {
      final s = data['displayName']?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : l.no_name;
    }();
    final email = () {
      final s = data['email']?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : l.no_email;
    }();
    final roleId = data['role_id'] as String?;
    final roleName = _getRoleName(roleId, l);
    final showProfilSection = roleName == 'Admin' || roleName == 'DJ';
    final showTechSection = roleName != 'Gast';

    final realName =
        data['real_name']?.toString() ?? data['realName']?.toString();
    final country = data['country']?.toString();
    final birthDate =
        data['birthDate'] as Timestamp? ??
        data['birthdate'] as Timestamp? ??
        data['birthday'] as Timestamp?;
    final birthdayStr = birthDate != null
        ? _formatBirthday(birthDate)
        : (data['birthday'] != null && data['birthday'] is! Timestamp
              ? data['birthday'].toString()
              : '–');

    final devices = data['devices'] as Map<String, dynamic>?;
    final createdAt = data['created_at'] as Timestamp?;
    final loginCount = data['loginCount'];
    final isPro = data['isPro'] == true;
    final micSensitivity = data['mic_sensitivity'];
    final shazamInterval = data['shazam_scan_interval_seconds'];
    final recognitionThreshold = data['recognition_threshold'];
    final smartThresholdEnabled = data['smart_threshold_enabled'] == true;
    final autoStartRecognition = data['auto_start_recognition'] == true;

    final createdStr = createdAt != null
        ? _formatDateTime(createdAt.toDate())
        : '–';
    final loginCountStr = loginCount != null ? loginCount.toString() : '–';

    // Neuestes last_seen aus der Geräte-Map für „Letzter Login“
    DateTime? latestLastSeen;
    if (devices != null) {
      for (final e in devices.values) {
        final dev = e is Map ? Map<String, dynamic>.from(e as Map) : null;
        final lastSeen = dev?['last_seen'];
        if (lastSeen is Timestamp) {
          final d = lastSeen.toDate();
          if (latestLastSeen == null || d.isAfter(latestLastSeen))
            latestLastSeen = d;
        }
      }
    }
    final lastLoginStr = latestLastSeen != null
        ? _formatDateTimeShort(latestLastSeen)
        : '–';

    const inactiveIconColor = Color(0xFF525252);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Benutzer (immer: E-Mail, Rolle)
              _sectionTitle(l.admin_user_section_user),
              _detailRow(l.email_address, email),
              _detailRow(l.admin_role_label, roleName, bold: true),
              // Profil nur für Admin/DJ: Realname, Land, Geburtstag
              if (showProfilSection) ...[
                const SizedBox(height: 16),
                _sectionTitle(l.profile),
                _detailRow(
                  l.admin_user_realname,
                  (realName ?? displayName).isEmpty
                      ? '–'
                      : (realName ?? displayName),
                ),
                _detailRow(
                  l.admin_user_origin_country,
                  country?.trim().isEmpty ?? true ? '–' : (country ?? '–'),
                ),
                _detailRow(l.profile_birthday, birthdayStr),
              ],
              const SizedBox(height: 16),
              // Geräte (Icon Android/iOS, nur OS-Versionsnummer, Aktivitäts-Punkt size 10)
              _sectionTitle(l.admin_user_section_devices),
              if (devices == null || devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.admin_user_no_devices,
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                )
              else
                ...devices.entries.toList().asMap().entries.map(
                  (ix) {
                    final i = ix.key;
                    final e = ix.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < devices.length - 1 ? 16 : 0),
                      child: _adminUserDeviceDetailBlock(
                        l: l,
                        index: i,
                        entry: e,
                      ),
                    );
                  },
                ),
              if (showTechSection) ...[
                const SizedBox(height: 16),
                // Technik (Schwellenwert, Icons orange/dunkelgrau)
                _sectionTitle(l.admin_user_section_tech),
                _detailRow(
                  l.admin_user_threshold_pegel,
                  recognitionThreshold != null
                      ? recognitionThreshold.toString()
                      : '–',
                ),
                _detailRow(
                  l.mic_sensitivity_label.replaceAll(':', ''),
                  micSensitivity != null ? micSensitivity.toString() : '–',
                ),
                _detailRow(
                  l.admin_user_shazam_interval_s,
                  shazamInterval != null ? shazamInterval.toString() : '–',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Tooltip(
                      message: smartThresholdEnabled
                          ? l.admin_smart_adapt_tooltip_on
                          : l.admin_smart_adapt_tooltip_off,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.psychology,
                            size: 20,
                            color: smartThresholdEnabled
                                ? Colors.orange
                                : inactiveIconColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.smart_threshold_label.replaceAll(':', ''),
                            style: TextStyle(
                              color: smartThresholdEnabled
                                  ? Colors.white70
                                  : Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            smartThresholdEnabled
                                ? l.admin_switch_on
                                : l.admin_switch_off,
                            style: TextStyle(
                              color: smartThresholdEnabled
                                  ? Colors.green
                                  : Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: autoStartRecognition
                          ? l.admin_auto_recognition_tooltip_on
                          : l.admin_auto_recognition_tooltip_off,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hearing,
                            size: 20,
                            color: autoStartRecognition
                                ? Colors.orange
                                : inactiveIconColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.admin_user_auto_recognition_short,
                            style: TextStyle(
                              color: autoStartRecognition
                                  ? Colors.white70
                                  : Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            autoStartRecognition
                                ? l.admin_switch_on
                                : l.admin_switch_off,
                            style: TextStyle(
                              color: autoStartRecognition
                                  ? Colors.green
                                  : Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              // Daten (Letzter Login = last_seen aktuellstes Gerät, Format dd.MM.yyyy, HH:mm)
              _sectionTitle(l.admin_user_section_data),
              _detailRow(l.todo_label_created, createdStr),
              _detailRow(l.admin_user_last_login, lastLoginStr),
              _detailRow(l.admin_user_login_count, loginCountStr),
              _detailRow(l.admin_user_pro_label, isPro ? l.yes : l.no),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.close,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white54),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Formatiert DateTime für Anzeige
  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute Uhr';
  }

  /// Kurzformat für „Letzter Login“: dd.MM.yyyy, HH:mm
  String _formatDateTimeShort(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }

  // Holt den Rollennamen basierend auf role_id
  String _getRoleName(String? roleId, AppLocalizations l) {
    if (roleId == null || roleId.isEmpty) {
      return l.admin_role_not_set;
    }
    return _roleNames[roleId] ?? l.unknown;
  }

  // Holt alle verfügbaren Rollen-IDs und Namen
  List<MapEntry<String, String>> _getAvailableRoles() {
    return _roleNames.entries.toList()..sort((a, b) {
      // Sortiere nach Level (wenn verfügbar) oder alphabetisch
      // Gast, DJ, Admin
      final order = {'Gast': 1, 'DJ': 2, 'Admin': 3};
      final orderA = order[a.value] ?? 999;
      final orderB = order[b.value] ?? 999;
      return orderA.compareTo(orderB);
    });
  }

  // Dialog zum Ändern der Rolle eines Benutzers
  Future<void> _showChangeRoleDialog(
    BuildContext context,
    String userId,
    String userName,
    String? currentRoleId,
  ) async {
    final availableRoles = _getAvailableRoles();

    if (availableRoles.isEmpty) {
      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.snackbar_no_roles_available),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    String? selectedRoleId = currentRoleId;

    await showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        final l = AppLocalizations.of(dialogCtx)!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l.dialog_admin_change_role_title(userName)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.admin_select_role_prompt),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(selectedRoleId),
                    initialValue: selectedRoleId,
                    decoration: InputDecoration(
                      labelText: l.admin_role_label,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(l.admin_role_not_set),
                      ),
                      // Verfügbare Rollen
                      ...availableRoles.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRoleId = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateUserRole(userId, selectedRoleId);
                  },
                  child: Text(l.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Aktualisiert die Rolle eines Benutzers
  Future<void> _updateUserRole(String userId, String? roleId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.snackbar_must_sign_in_for_roles),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      debugLog('🔧 Aktualisiere Rolle');
      debugLog('   Rolle wird aktualisiert');
      debugLog('   Neue Role-ID: $roleId');

      // Verwende set mit merge statt update, um sicherzustellen, dass es funktioniert
      final updateData = <String, dynamic>{};
      if (roleId != null && roleId.isNotEmpty) {
        updateData['role_id'] = roleId;
      } else {
        // Wenn roleId null oder leer ist, entferne das Feld
        updateData['role_id'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(SecurityHelper.sanitizeMap(updateData));

      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.snackbar_role_updated_success),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Fehler beim Aktualisieren der Rolle: $e');
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.snackbar_error_updating_todo} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Lifetime-Status umschalten (Dialog + Logik)
  Future<void> _toggleLifetimeStatus(
    String userId,
    String displayName,
    bool isLifetime,
  ) async {
    // Dialog anzeigen
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.orange, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.stars, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isLifetime
                      ? l.admin_lifetime_title_revoke
                      : l.admin_lifetime_title_grant,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          content: Text(
            isLifetime
                ? l.admin_lifetime_body_revoke(displayName)
                : l.admin_lifetime_body_grant(displayName),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isLifetime
                    ? l.admin_lifetime_action_revoke
                    : l.admin_lifetime_action_grant,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      if (!isLifetime) {
        // Freischalten: ProUntil auf 2099, isPro = true, planType = 'pro' (damit alle Checks greifen)
        await userRef.update(
          SecurityHelper.sanitizeMap({
            'isPro': true,
            'proUntil': Timestamp.fromDate(DateTime(2099, 1, 1)),
            'planType': 'pro',
          }),
        );

        // Zahlungshistorie: Eintrag für VibesBox Pro Life (Admin Geschenk)
        await userRef
            .collection('history')
            .add(
              SecurityHelper.sanitizeMap({
                'type': 'lifetime_grant',
                'amountGross': 0,
                'timestamp': FieldValue.serverTimestamp(),
                'source': 'ADMIN_GIFT',
                'description': 'VibesBox Pro Life (Admin Geschenk)',
              }),
            );

        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.snackbar_user_now_lifetime(displayName)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Entziehen: Nur bei explizitem Klick „Entziehen“ – User war Lifetime und wird zu Free.
        // free_period_start hier bewusst setzen (Neustart Abrechnungszyklus). Kein „stiller“ Reset:
        // Rolle ändern (_updateUserRole) und andere Bearbeitungen schreiben free_period_start nicht.
        await userRef.update(
          SecurityHelper.sanitizeMap({
            'isPro': false,
            'proUntil': FieldValue.serverTimestamp(),
            'planType': 'free',
            'free_period_start': FieldValue.serverTimestamp(),
          }),
        );

        // Zahlungshistorie: Eintrag für Entzug von Pro Life
        await userRef
            .collection('history')
            .add(
              SecurityHelper.sanitizeMap({
                'type': 'lifetime_revoked',
                'amountGross': 0,
                'timestamp': FieldValue.serverTimestamp(),
                'source': 'ADMIN_REVOKE',
                'description': 'VibesBox Pro Life entzogen',
              }),
            );

        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.snackbar_lifetime_revoked(displayName)),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugLog('❌ Fehler beim Ändern des Lifetime-Status: $e');
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Dialog zum Ändern des Passworts eines Benutzers (nur wenn _currentUserIsAdmin == true).
  Future<void> _showChangePasswordDialog(
    BuildContext context,
    String userId,
    String displayName,
  ) async {
    if (_currentUserIsAdmin != true) {
      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.snackbar_admin_password_change_forbidden),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final l = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(l.dialog_admin_change_password_title(displayName)),
              content: SingleChildScrollView(
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              decoration: InputDecoration(
                                labelText: l.admin_new_password_label,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setDialogState(
                                      () => obscurePassword = !obscurePassword,
                                    );
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Bitte Passwort eingeben.';
                                }
                                if (value.trim().length < 8) {
                                  return 'Mindestens 8 Zeichen erforderlich.';
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
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(l.cancel),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);
                          try {
                            // trim() vermeidet versehentliche Leerzeichen am Anfang/Ende
                            final newPassword = passwordController.text.trim();
                            await AdminService.instance.changeUserPassword(
                              targetUid: userId,
                              newPassword: newPassword,
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l.admin_password_changed_success(displayName),
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } on FirebaseFunctionsException catch (e) {
                            setDialogState(() => isLoading = false);
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.message ??
                                      '${l.admin_password_change_functions_error} ${e.code}',
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('${l.error}: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                  child: Text(l.save),
                ),
              ],
            );
          },
        );
      },
    );
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.userManagement)),
      body: _usersStream == null
          ? const Center(child: CircularProgressIndicator())
          : RepaintBoundary(
              // WICHTIG: RepaintBoundary isoliert die Liste komplett vom Rest der UI
              child: StreamBuilder<QuerySnapshot>(
                stream: _usersStream, // Verwende fixierte Stream-Instanz
                builder: (context, snapshot) {
                  final loc = AppLocalizations.of(context)!;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(loc.todo_stream_error(snapshot.error!)),
                    );
                  }

                  final users = snapshot.data?.docs ?? [];
                  final filtered =
                      users.where(_userDocMatchesRoleFilter).toList();

                  if (users.isEmpty) {
                    return Center(
                      child: Text(loc.admin_users_empty),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: UIConstants.bgGradientStart,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: UIConstants.appOrange,
                              width: 1.5,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<_BenutzerVerwaltungRoleFilter>(
                              value: _roleListFilter,
                              isExpanded: true,
                              dropdownColor: UIConstants.bgGradientStart,
                              iconEnabledColor: UIConstants.appOrange,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              items: _BenutzerVerwaltungRoleFilter.values
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f,
                                      child: Text(
                                        _roleFilterDropdownLabel(f),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _roleListFilter = v);
                              },
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    loc.admin_users_empty_for_role_filter,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 0,
                      bottom: 16 + UIConstants.kFooterPadding * 2,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final l = AppLocalizations.of(context)!;
                      final userDoc = filtered[index];
                      final data = userDoc.data() as Map<String, dynamic>;

                      final email = () {
                        final s = data['email']?.toString().trim();
                        return (s != null && s.isNotEmpty) ? s : l.no_email;
                      }();
                      final displayName = () {
                        final s = data['displayName']?.toString().trim();
                        return (s != null && s.isNotEmpty) ? s : l.no_name;
                      }();
                      final roleId = data['role_id'] as String?;
                      final roleName = _getRoleName(roleId, l);

                      // Registrierungsdatum (created_at oder lastLogin als Fallback)
                      Timestamp? registrationTimestamp;
                      if (data['created_at'] != null) {
                        registrationTimestamp =
                            data['created_at'] as Timestamp?;
                      } else if (data['lastLogin'] != null) {
                        // Falls created_at nicht vorhanden, nutze lastLogin als Näherung
                        registrationTimestamp = data['lastLogin'] as Timestamp?;
                      }

                      final registrationDate = registrationTimestamp?.toDate();
                      final registrationText = registrationDate != null
                          ? _formatDateTime(registrationDate)
                          : l.unknown;

                      // Farbe basierend auf Rolle
                      Color roleColor = Colors.grey;
                      if (roleName == 'Admin') {
                        roleColor = Colors.red;
                      } else if (roleName == 'DJ') {
                        roleColor = Colors.blue;
                      } else if (roleName == 'Gast') {
                        roleColor = Colors.green;
                      }

                      return Card(
                        key: ValueKey(
                          userDoc.id,
                        ), // WICHTIG: Stabilisiert die Liste (Anti-Flackern)
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showUserDetailDialog(context, data),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name und Rolle
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: roleColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        roleName,
                                        style: TextStyle(
                                          color: roleColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Email
                                Text(
                                  email,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                // Registrierungsdatum
                                Text(
                                  '${l.admin_user_registered_prefix}: $registrationText',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 6),
                                // Aktuellstes Gerät (neuestes last_seen) oder Fallback
                                Builder(
                                  builder: (context) {
                                    final devices =
                                        data['devices']
                                            as Map<String, dynamic>?;
                                    final newest = _getNewestDevice(devices);
                                    if (newest == null) {
                                      return Text(
                                        l.admin_user_no_device_registered,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.grey[500]),
                                      );
                                    }
                                    final platform =
                                        (newest['platform']?.toString() ?? '')
                                            .toLowerCase();
                                    final osVersionRaw =
                                        newest['os_version']?.toString() ?? '–';
                                    final osVersion = _osVersionOnly(
                                      osVersionRaw,
                                    );
                                    final appVer =
                                        newest['app_version']?.toString() ??
                                        '–';
                                    final icon = platform == 'ios'
                                        ? Icons.apple
                                        : Icons.android;
                                    return Row(
                                      children: [
                                        Icon(
                                          icon,
                                          size: 18,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$osVersion · ${l.admin_user_app_prefix} $appVer',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Buttons: Rolle ändern + Passwort ändern (nur für Admins)
                                Row(
                                  children: [
                                    // Lifetime nur für Nicht-Gäste (Gast = immer Free, kein Lifetime)
                                    if (roleName != 'Gast')
                                      Builder(
                                        builder: (context) {
                                          final proUntil =
                                              data['proUntil'] as Timestamp?;
                                          final isLifetime =
                                              proUntil != null &&
                                              proUntil.toDate().year == 2099;
                                          return IconButton(
                                            icon: Icon(
                                              isLifetime
                                                  ? Icons.stars
                                                  : Icons.stars_outlined,
                                              color: isLifetime
                                                  ? Colors.orange
                                                  : Colors.grey,
                                            ),
                                            tooltip: isLifetime
                                                ? l.admin_lifetime_tooltip_active
                                                : l.admin_lifetime_tooltip_grant,
                                            onPressed: () =>
                                                _toggleLifetimeStatus(
                                                  userDoc.id,
                                                  displayName,
                                                  isLifetime,
                                                ),
                                          );
                                        },
                                      ),
                                    // P/F-Indikator nur für DJs (Pro/Free inkl. Kulanz via ProFreeCheck)
                                    if (roleName == 'DJ')
                                      Builder(
                                        builder: (context) {
                                          final userModel =
                                              UserModel.fromFirestore(userDoc);
                                          final result =
                                              ProFreeCheck.determineStatus(
                                                user: userModel,
                                                historyEntries: [],
                                              );
                                          final isPro =
                                              result.status ==
                                                  ProFreeStatus.PRO ||
                                              result.status ==
                                                  ProFreeStatus.PRO_LIFE;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              left: 2,
                                            ),
                                            child: Tooltip(
                                              message:
                                                  result.status ==
                                                      ProFreeStatus.PRO_LIFE
                                                  ? l.admin_pro_tooltip_life
                                                  : result.status ==
                                                        ProFreeStatus.PRO
                                                  ? l.admin_pro_tooltip_pro
                                                  : l.admin_pro_tooltip_free,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: isPro
                                                        ? UIConstants.appGreen
                                                        : Colors.red,
                                                    width: 1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isPro ? 'P' : 'F',
                                                  style: TextStyle(
                                                    color: isPro
                                                        ? UIConstants.appGreen
                                                        : Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    if (_canToggleAccountLock(
                                      targetUid: userDoc.id,
                                      roleName: roleName,
                                      data: data,
                                    ))
                                      IconButton(
                                        icon: Icon(
                                          _isAccountLockedInUserDoc(data)
                                              ? Icons.lock
                                              : Icons.lock_open,
                                          color: _isAccountLockedInUserDoc(data)
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        tooltip: _isAccountLockedInUserDoc(data)
                                            ? 'Konto entsperren (Login)'
                                            : 'Konto sperren (Login)',
                                        onPressed: () {
                                          _toggleAccountLockFromAdmin(
                                            context: context,
                                            targetUid: userDoc.id,
                                            displayName: displayName,
                                            currentlyLocked:
                                                _isAccountLockedInUserDoc(data),
                                          );
                                        },
                                      ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        _showChangeRoleDialog(
                                          context,
                                          userDoc.id,
                                          displayName,
                                          roleId,
                                        );
                                      },
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: Text(l.admin_role_label),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                    if (_currentUserIsAdmin == true) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () {
                                          _showChangePasswordDialog(
                                            context,
                                            userDoc.id,
                                            displayName,
                                          );
                                        },
                                        icon: const Icon(Icons.lock_reset),
                                        color: Colors.orange,
                                        tooltip: l.change_password,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
