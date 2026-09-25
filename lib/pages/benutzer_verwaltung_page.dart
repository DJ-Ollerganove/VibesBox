import 'dart:async';

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
import '../l10n/locale_helper.dart';
import '../utils/debug_log.dart';
import '../utils/formatting_utils.dart';
import '../utils/device_display_helper.dart';
import '../app_scaffold_messenger.dart';

/// Rollen-Filter für die Admin-Benutzerliste (IDs aus [AppConfig]).
enum _BenutzerVerwaltungRoleFilter { admin, dj, guest }

// Benutzer-Verwaltungsseite für Admin
class BenutzerVerwaltungPage extends StatefulWidget {
  /// Wenn [false], solange ein anderer Tab aktiv ist. Beim Wechsel auf diese Seite
  /// [true] → Stream wird neu angebunden (frische Firestore-Daten).
  const BenutzerVerwaltungPage({super.key, this.isActive = true});

  final bool isActive;

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _syncInstallsSub;
  Map<String, List<Map<String, dynamic>>> _syncInstallsByUser = {};

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

  @override
  void didUpdateWidget(BenutzerVerwaltungPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _refreshUsersStreamOnPageOpen();
    }
  }

  /// Neuen Snapshot-Stream erzeugen (z. B. nach Tab-Wechsel zurück auf Benutzerverwaltung).
  void _refreshUsersStreamOnPageOpen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final isAdmin = _currentUserIsAdmin == true;
    setState(() {
      _initializeUsersStream(uid: uid, isAdmin: isAdmin);
    });
    unawaited(_loadRoleNames());
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
        if (isAdmin) _listenSyncInstalls();
      }
    } catch (_) {
      if (mounted) setState(() => _currentUserIsAdmin = false);
    }
  }

  @override
  void dispose() {
    _syncInstallsSub?.cancel();
    super.dispose();
  }

  void _listenSyncInstalls() {
    _syncInstallsSub ??= FirebaseFirestore.instance
        .collection('rb_tool_installs')
        .limit(200)
        .snapshots()
        .listen((snap) {
      final next = <String, List<Map<String, dynamic>>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = (data['ownerUid'] ?? '').toString();
        if (uid.isEmpty) continue;
        next.putIfAbsent(uid, () => []).add(data);
      }
      for (final list in next.values) {
        list.sort((a, b) => _syncSeenMillis(b).compareTo(_syncSeenMillis(a)));
      }
      if (mounted) setState(() => _syncInstallsByUser = next);
    }, onError: (_) {});
  }

  int _syncSeenMillis(Map<String, dynamic> data) {
    final seen = data['lastSeen'];
    if (seen is Timestamp) return seen.millisecondsSinceEpoch;
    return 0;
  }

  Widget _syncInstallLines(String userId, {bool onDark = false}) {
    final installs = _syncInstallsByUser[userId];
    if (installs == null || installs.isEmpty) return const SizedBox.shrink();
    final color = onDark ? Colors.white70 : Colors.grey[600];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < installs.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                (installs[i]['platform'] ?? '').toString() == 'windows'
                    ? Icons.desktop_windows
                    : Icons.laptop_mac,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _syncInstallText(installs[i]),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                      ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _syncInstallText(Map<String, dynamic> data) {
    final os = (data['os'] ?? '').toString().trim();
    final version = (data['version'] ?? '').toString().trim();
    final seen = data['lastSeen'];
    final when = seen is Timestamp
        ? _formatDateTimeShort(seen.toDate())
        : '–';
    return 'VibesBox Sync · ${os.isEmpty ? '–' : os} · $version · zuletzt $when';
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

  bool _userDocMatchesRoleFilter(
    DocumentSnapshot doc, [
    _BenutzerVerwaltungRoleFilter? filter,
  ]) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;
    final rid = _roleIdFromUserDoc(data);
    final f = filter ?? _roleListFilter;
    switch (f) {
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
      showVibesSnackBar(context, 
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
      showVibesSnackBar(context, 
        SnackBar(
          content: Text('${l.error}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _roleFilterDropdownLabel(_BenutzerVerwaltungRoleFilter f, int count) {
    String base;
    switch (f) {
      case _BenutzerVerwaltungRoleFilter.admin:
        final id = AppConfig.adminRoleId;
        if (id != null && id.isNotEmpty) {
          final n = _roleNames[id];
          if (n != null && n.isNotEmpty) {
            base = n;
            break;
          }
        }
        base = 'Admin';
        break;
      case _BenutzerVerwaltungRoleFilter.dj:
        final id = AppConfig.djRoleId;
        if (id != null && id.isNotEmpty) {
          final n = _roleNames[id];
          if (n != null && n.isNotEmpty) {
            base = n;
            break;
          }
        }
        base = 'DJ';
        break;
      case _BenutzerVerwaltungRoleFilter.guest:
        final id = AppConfig.guestRoleId;
        if (id != null && id.isNotEmpty) {
          final n = _roleNames[id];
          if (n != null && n.isNotEmpty) {
            base = n;
            break;
          }
        }
        base = 'Gast';
        break;
    }
    return '$base ($count)';
  }

  int _roleFilterCount(
    List<QueryDocumentSnapshot<Object?>> docs,
    _BenutzerVerwaltungRoleFilter f,
  ) {
    return docs.where((d) => _userDocMatchesRoleFilter(d, f)).length;
  }

  /// Firestore liefert `devices` teils als `Map` mit dynamischen Key-Typen.
  Map<String, dynamic>? _coerceUserDevicesMap(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    try {
      final out = <String, dynamic>{};
      for (final e in raw.entries) {
        out[e.key.toString()] = e.value;
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  DateTime _deviceLastSeenDate(Map<String, dynamic> dev) {
    final lastSeen = dev['last_seen'];
    if (lastSeen is Timestamp) return lastSeen.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Build-Nummer aus „1.0.52 (52)“ oder Semver für Geräte-Vergleich.
  int _parseAppVersionBuildNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) return -1;
    final text = raw.trim();
    final parenMatch = RegExp(r'\((\d+)\)').firstMatch(text);
    if (parenMatch != null) {
      return int.tryParse(parenMatch.group(1)!) ?? -1;
    }
    final semver = text.split(RegExp(r'[\s+]')).first.trim();
    final parts = semver
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    if (parts.isEmpty) return -1;
    final major = parts.isNotEmpty ? parts[0] : 0;
    final minor = parts.length > 1 ? parts[1] : 0;
    final patch = parts.length > 2 ? parts[2] : 0;
    return major * 1000000 + minor * 1000 + patch;
  }

  /// Bevorzugt neuestes [last_seen] (aktuelles Gerät / letzte Aktivität).
  Map<String, dynamic>? _getMostRecentlySeenDevice(Map<String, dynamic>? devices) {
    if (devices == null || devices.isEmpty) return null;
    Map<String, dynamic>? bestData;
    DateTime bestSeen = DateTime.fromMillisecondsSinceEpoch(0);
    for (final e in devices.entries) {
      final dev = e.value is Map
          ? Map<String, dynamic>.from(e.value as Map)
          : null;
      if (dev == null) continue;
      final seen = _deviceLastSeenDate(dev);
      if (bestData == null || seen.isAfter(bestSeen)) {
        bestSeen = seen;
        bestData = dev;
      }
    }
    return bestData;
  }

  List<MapEntry<String, dynamic>> _deviceEntriesNewestFirst(
    Map<String, dynamic> devices,
  ) {
    final entries = devices.entries.toList();
    // Primär: zuletzt gesehen (aktuelles Gerät zuerst) — nicht nach Build-Nummer,
    // sonst wirkt eine ältere Session mit höherer Versionszahl „aktueller“.
    entries.sort((a, b) {
      final devA = a.value is Map
          ? Map<String, dynamic>.from(a.value as Map)
          : <String, dynamic>{};
      final devB = b.value is Map
          ? Map<String, dynamic>.from(b.value as Map)
          : <String, dynamic>{};
      final seenCmp =
          _deviceLastSeenDate(devB).compareTo(_deviceLastSeenDate(devA));
      if (seenCmp != 0) return seenCmp;
      return _parseAppVersionBuildNumber(
        devB['app_version']?.toString(),
      ).compareTo(
        _parseAppVersionBuildNumber(devA['app_version']?.toString()),
      );
    });
    return entries;
  }

  DateTime? _bestLastActivityForAdmin(
    Map<String, dynamic> data,
    Map<String, dynamic>? devices,
  ) {
    DateTime? best;
    final lastLogin = data['lastLogin'];
    if (lastLogin is Timestamp) {
      best = lastLogin.toDate();
    }
    final topSeen = data['last_seen'];
    if (topSeen is Timestamp) {
      final t = topSeen.toDate();
      if (best == null || t.isAfter(best)) best = t;
    }
    if (devices != null) {
      for (final e in devices.values) {
        final dev = e is Map ? Map<String, dynamic>.from(e as Map) : null;
        if (dev == null) continue;
        final seen = _deviceLastSeenDate(dev);
        if (seen.millisecondsSinceEpoch == 0) continue;
        if (best == null || seen.isAfter(best)) best = seen;
      }
    }
    return best;
  }

  String _formatSystemLocaleForAdmin(AppLocalizations l, String? rawTag) {
    if (rawTag == null || rawTag.trim().isEmpty) return '–';
    final tag = rawTag.trim();
    final code = LocaleHelper.mapToSupportedOrEnglish(tag);
    final label = _languageLabelForAdminCode(l, code);
    if (tag.toLowerCase().startsWith(code)) {
      return '$tag ($label)';
    }
    return '$tag → $code ($label)';
  }

  String _displayDeviceModel(Map<String, dynamic> dev) {
    return DeviceDisplayHelper.displayStoredModel(
      platform: dev['platform']?.toString(),
      storedModel: dev['device_model']?.toString(),
      storedModelCode: dev['device_model_code']?.toString(),
    );
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

  /// OS-Anzeige: „Android 14“ / „iOS 18.2“ (nicht nur die Zahl ohne Kontext).
  String _formatOsForAdmin(Map<String, dynamic> dev) {
    final platform = (dev['platform']?.toString() ?? '').trim().toLowerCase();
    final raw = (dev['os_version']?.toString() ?? '').trim();
    final ver = _osVersionOnly(raw);
    if (platform == 'ios') {
      if (ver == '–' || ver.isEmpty) return 'iOS';
      if (RegExp(r'^iOS\b', caseSensitive: false).hasMatch(raw)) {
        return raw.startsWith('iOS') ? raw : 'iOS $ver';
      }
      return 'iOS $ver';
    }
    if (platform == 'android') {
      if (ver == '–' || ver.isEmpty) return 'Android';
      if (RegExp(r'^Android\b', caseSensitive: false).hasMatch(raw)) {
        return raw.startsWith('Android') ? raw : 'Android $ver';
      }
      return 'Android $ver';
    }
    if (ver != '–' && ver.isNotEmpty) return ver;
    return '–';
  }

  String _formatCompactDeviceLine(AppLocalizations l, Map<String, dynamic> dev) {
    final osLabel = _formatOsForAdmin(dev);
    final appVer = dev['app_version']?.toString() ?? '–';
    final deviceName = _displayDeviceModel(dev);
    return '$deviceName · $osLabel · ${l.admin_user_app_prefix} $appVer';
  }

  IconData _platformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p == 'ios') return Icons.apple;
    if (p == 'android') return Icons.android;
    return Icons.devices_other;
  }

  /// Fallback, wenn `devices` leer ist, aber Top-Level-Telemetrie existiert.
  Map<String, dynamic>? _syntheticDeviceFromUserDoc(Map<String, dynamic> data) {
    final ver = data['app_version']?.toString().trim();
    if (ver == null || ver.isEmpty) return null;
    return {
      'app_version': ver,
      'platform': data['platform']?.toString() ?? '',
      'device_model': data['device_model']?.toString() ?? '',
      'device_model_code': data['device_model_code']?.toString() ?? '',
      'os_version': data['os_version']?.toString() ?? '',
      'last_seen': data['last_seen'] ?? data['app_version_updated_at'],
    };
  }

  Map<String, dynamic>? _effectiveDevicesForAdmin(
    Map<String, dynamic> data,
  ) {
    final devices = _coerceUserDevicesMap(data['devices']);
    if (devices != null && devices.isNotEmpty) return devices;
    final synthetic = _syntheticDeviceFromUserDoc(data);
    if (synthetic == null) return null;
    return {'_top_level': synthetic};
  }

  /// Alle registrierten Geräte (kompakt) für die Listenkarte — neuestes zuerst.
  Widget _buildAdminUserDevicesListPreview(
    AppLocalizations l,
    Map<String, dynamic>? devices,
  ) {
    if (devices == null || devices.isEmpty) {
      return Text(
        l.admin_user_no_device_registered,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
      );
    }
    final entries = _deviceEntriesNewestFirst(devices);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final dev = entries[i].value is Map
                  ? Map<String, dynamic>.from(entries[i].value as Map)
                  : <String, dynamic>{};
              final platform = (dev['platform']?.toString() ?? '').toLowerCase();
              return Row(
                children: [
                  Icon(
                    _platformIcon(platform),
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatCompactDeviceLine(l, dev),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  String _formatAdminDeviceFieldValue(dynamic v) {
    if (v == null) return '–';
    if (v is Timestamp) return _formatDateTime(v.toDate());
    if (v is DateTime) return _formatDateTime(v);
    return v.toString();
  }

  static const _adminDeviceKnownKeys = {
    'app_version',
    'app_language',
    'device_model',
    'device_model_code',
    'os_version',
    'platform',
    'system_locale_tag',
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
    final icon = _platformIcon(platform);

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
        _detailRow(l.admin_device_model, _displayDeviceModel(dev)),
        _detailRow(l.admin_device_os_version, _formatOsForAdmin(dev)),
        _detailRow(l.admin_device_app_version, nz(dev['app_version'])),
        if ((dev['app_language']?.toString().trim() ?? '').isNotEmpty)
          _detailRow(
            l.admin_user_app_language_label,
            '${dev['app_language']} – ${_languageLabelForAdminCode(l, LocaleHelper.mapToSupportedOrEnglish(dev['app_language'].toString()))}',
          ),
        _detailRow(
          l.admin_device_system_locale,
          _formatSystemLocaleForAdmin(l, dev['system_locale_tag']?.toString()),
        ),
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

  /// Letzter bekannter BCP47-/Locale-String aus allen `devices`-Einträgen (neuestes [last_seen] zuerst).
  String? _bestSystemLocaleTagFromDevices(Map<String, dynamic>? devices) {
    if (devices == null || devices.isEmpty) return null;
    final scored = <({DateTime t, String tag})>[];
    for (final e in devices.entries) {
      final dev = e.value is Map
          ? Map<String, dynamic>.from(e.value as Map)
          : null;
      if (dev == null) continue;
      String? tag;
      for (final key in [
        'system_locale_tag',
        'system_locale',
        'locale_tag',
        'device_locale',
      ]) {
        final v = dev[key]?.toString().trim();
        if (v != null && v.isNotEmpty) {
          tag = v;
          break;
        }
      }
      if (tag == null) continue;
      final lastSeen = dev['last_seen'];
      final t = lastSeen is Timestamp
          ? lastSeen.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      scored.add((t: t, tag: tag));
    }
    if (scored.isEmpty) return null;
    scored.sort((a, b) => b.t.compareTo(a.t));
    return scored.first.tag;
  }

  /// Rohwert für Admin-Sprache: Profil → [last_app_system_locale_tag] → alle Geräte-Einträge.
  String? _languageRawFromUserDocForAdmin(Map<String, dynamic> data) {
    final fromProfile = UserModel.parsePreferredLanguageFields(data);
    if (fromProfile != null && fromProfile.trim().isNotEmpty) {
      return fromProfile.trim();
    }
    final rootTag = data['last_app_system_locale_tag']?.toString().trim();
    if (rootTag != null && rootTag.isNotEmpty) {
      return rootTag;
    }
    final devices = _coerceUserDevicesMap(data['devices']);
    return _bestSystemLocaleTagFromDevices(devices);
  }

  /// Anzeige der in der App gewählten Sprache (Profil oder Geräte-Locale).
  String _formatAppLanguageForAdmin(
    Map<String, dynamic> data,
    AppLocalizations l,
  ) {
    final fromProfile = UserModel.parsePreferredLanguageFields(data)?.trim();
    final raw = _languageRawFromUserDocForAdmin(data);
    if (raw == null || raw.trim().isEmpty) {
      return l.admin_user_app_language_not_set;
    }
    final code = LocaleHelper.mapToSupportedOrEnglish(raw);
    final label = _languageLabelForAdminCode(l, code);
    final inferredFromDevice = fromProfile == null || fromProfile.isEmpty;
    final suffix = inferredFromDevice
        ? ' ${l.admin_user_app_language_from_device_suffix}'
        : '';
    return '$code – $label$suffix';
  }

  String _languageLabelForAdminCode(AppLocalizations l, String code) {
    switch (code) {
      case 'de':
        return l.german;
      case 'en':
        return l.english;
      case 'fr':
        return l.french;
      case 'ru':
        return l.russian;
      case 'zh':
        return l.chinese;
      case 'es':
        return l.spanish;
      case 'tr':
        return l.turkish;
      case 'pt':
        return l.portuguese;
      case 'it':
        return l.italian;
      case 'uk':
        return l.ukrainian;
      case 'hi':
        return l.hindi;
      case 'sq':
        return l.albanian;
      case 'vi':
        return l.vietnamese;
      case 'ja':
        return l.japanese;
      case 'el':
        return l.greek;
      case 'nl':
        return l.dutch;
      case 'pl':
        return l.polish;
      case 'cs':
        return l.czech;
      case 'th':
        return l.thai;
      default:
        return code;
    }
  }

  /// Kompakter Sprach-Code für die Listenkarte (Tooltip zeigt volle Bezeichnung).
  String _compactAppLanguageCode(Map<String, dynamic> data) {
    final raw = _languageRawFromUserDocForAdmin(data);
    if (raw == null || raw.trim().isEmpty) return '–';
    return LocaleHelper.mapToSupportedOrEnglish(raw).toUpperCase();
  }

  /// Öffnet den Benutzer-Detail-Dialog (VibesBox-Stil). Nutzt nur [data] – keine neuen Firestore-Abfragen.
  void _showUserDetailDialog(
    BuildContext context,
    String userId,
    Map<String, dynamic> data,
  ) {
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

    final devices = _effectiveDevicesForAdmin(data);
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

    final lastActivity = _bestLastActivityForAdmin(data, devices);
    final lastLoginStr = lastActivity != null
        ? _formatDateTimeShort(lastActivity)
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
              _detailRow(
                l.admin_user_app_language_label,
                _formatAppLanguageForAdmin(data, l),
              ),
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
              _sectionTitle('VibesBox Sync'),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _syncInstallsByUser[userId] == null ||
                        _syncInstallsByUser[userId]!.isEmpty
                    ? const Text(
                        'Kein Sync-Tool',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      )
                    : _syncInstallLines(userId, onDark: true),
              ),
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
                ..._deviceEntriesNewestFirst(devices).asMap().entries.map(
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
    return FormattingUtils.formatDateTimeCommaBetweenDateAndTime(date, context);
  }

  /// Kurzformat für „Letzter Login“: Datum und Uhrzeit nach App-Locale.
  String _formatDateTimeShort(DateTime date) {
    return FormattingUtils.formatDateTimeCommaBetweenDateAndTime(date, context);
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
        showVibesSnackBar(context, 
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
          showVibesSnackBar(context, 
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
        showVibesSnackBar(context, 
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
        showVibesSnackBar(context, 
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
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(l.snackbar_user_now_lifetime(displayName)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Entziehen: Nur bei explizitem Klick „Entziehen“ – User war Lifetime und wird zu Free.
        // Kulanz wie [ProFreeCheck]: Pro bis 23:59 des Folgetags nach dem Kalendertag des Entzugs;
        // free_period_start = erster Kalendertag danach (Abrechnungs-Stichtag), nicht der Klick-Zeitpunkt.
        final revokeInstant = DateTime.now();
        final freePeriodStart =
            ProFreeCheck.computeFreePeriodStartAfterProGrace(revokeInstant);
        await userRef.update(
          SecurityHelper.sanitizeMap({
            'isPro': false,
            'proUntil': Timestamp.fromDate(revokeInstant),
            'planType': 'free',
            'free_period_start': Timestamp.fromDate(freePeriodStart),
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
          showVibesSnackBar(context, 
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
        showVibesSnackBar(context, 
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
        showVibesSnackBar(context, 
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
                            showVibesSnackBar(context, 
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
                            showVibesSnackBar(dialogContext, 
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
                            showVibesSnackBar(dialogContext, 
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
                                        _roleFilterDropdownLabel(
                                          f,
                                          _roleFilterCount(users, f),
                                        ),
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
                          onTap: () => _showUserDetailDialog(context, userDoc.id, data),
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
                                // E-Mail + App-Sprache (kompakt mit Icon, Details im Tooltip)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                    ),
                                    Tooltip(
                                      message:
                                          '${l.admin_user_app_language_label}: ${_formatAppLanguageForAdmin(data, l)}',
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.language,
                                              size: 17,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _compactAppLanguageCode(data),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: Colors.grey[700],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Registrierungsdatum
                                Text(
                                  '${l.admin_user_registered_prefix}: $registrationText',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 6),
                                // Alle Geräte dieses DJs (je Gerät ein Eintrag in users.devices)
                                Builder(
                                  builder: (context) {
                                    final devices = _effectiveDevicesForAdmin(
                                      data,
                                    );
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _syncInstallLines(userDoc.id),
                                        if ((_syncInstallsByUser[userDoc.id] ??
                                                const [])
                                            .isNotEmpty)
                                          const SizedBox(height: 6),
                                        _buildAdminUserDevicesListPreview(
                                          l,
                                          devices,
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
