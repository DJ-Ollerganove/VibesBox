import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';

enum UpdateCheckResult { forceUpdate, optionalUpdate, upToDate, skip }

class AppUpdateConfig {
  const AppUpdateConfig({
    required this.currentVersion,
    required this.minVersionGuest,
    required this.minVersionDj,
    required this.storeUrlAndroid,
    required this.storeUrlIos,
  });

  final String currentVersion;
  final String minVersionGuest;
  final String minVersionDj;
  final String storeUrlAndroid;
  final String storeUrlIos;
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService _instance = AppUpdateService._();
  static AppUpdateService get instance => _instance;

  static const String _adminConfigDocId = 'app_update';
  static const String defaultMinVersion = '1.0.21';
  static const String _playStoreDetailsUrl =
      'https://play.google.com/store/apps/details?id=com.vibesbox.dj&hl=de';
  static const String _appStoreFallbackUrl = 'https://apps.apple.com/';

  static final ValueNotifier<String> storeVersionDebug =
      ValueNotifier<String>('–');
  static bool _optionalPromptShownInSession = false;

  /// Verhindert viele Firestore-Reads bei schnellen Resume-/Lifecycle-Ketten (pro UID).
  static String? _lastLogUserAppVersionUid;
  static DateTime? _lastLogUserAppVersionAt;

  /// `flutter run` / Dev-APK: kein Zwang, wenn lokale Version älter als Store.
  static const bool _skipUpdateCheckFromDefine =
      bool.fromEnvironment('SKIP_APP_UPDATE_CHECK', defaultValue: false);

  /// Überall dieselbe Semver-Zeichenkette (alles nach `+` entfernen).
  static String normalizeSemver(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return '0.0.0';
    return t.split('+').first.trim();
  }

  static String _clean(String? v, {String fallback = ''}) {
    final t = (v ?? '').trim();
    return t.isEmpty ? fallback : t;
  }

  static Future<String> localVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    if (build.isNotEmpty) return build;
    return normalizeSemver(info.version);
  }

  static int compareVersions(String a, String b) {
    final na = normalizeSemver(a);
    final nb = normalizeSemver(b);
    final ai = int.tryParse(na.trim());
    final bi = int.tryParse(nb.trim());
    if (ai != null && bi != null) {
      if (ai < bi) return -1;
      if (ai > bi) return 1;
      return 0;
    }
    final partsA = _parseVersion(na);
    final partsB = _parseVersion(nb);
    for (int i = 0; i < partsA.length || i < partsB.length; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va < vb) return -1;
      if (va > vb) return 1;
    }
    return 0;
  }

  static List<int> _parseVersion(String v) {
    final withoutBuild = v.split(RegExp(r'\+')).first.trim();
    return withoutBuild
        .split(RegExp(r'\.'))
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  static NewVersionPlus _newVersionPlus() => NewVersionPlus(
        androidPlayStoreCountry: 'de',
        iOSAppStoreCountry: 'DE',
      );

  /// Store-Semver (Play / App Store) vs. installiert.
  ///
  /// Bei Fehler (z. B. HTTP 404 ohne Store-Eintrag in Debug): `null` → [checkForUpdate]
  /// wertet das wie **upToDate** (kein Absturz, kein Update-Dialog).
  static Future<VersionStatus?> getVersionStatusOrNull() async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    try {
      return await _newVersionPlus().getVersionStatus();
    } catch (e, _) {
      final msg = e.toString();
      final looks404 = msg.contains('404') ||
          msg.toLowerCase().contains('not found');
      debugLog(
        'ℹ️ AppUpdateService: Store-Version nicht ermittelbar '
        '(${looks404 ? '404 / kein Listing' : 'Fehler'}) — behandle als upToDate. $msg',
      );
      return null;
    }
  }

  /// Intern: gleiche Semantik wie [getVersionStatusOrNull].
  static Future<VersionStatus?> _fetchStoreVersionStatus() async {
    return getVersionStatusOrNull();
  }

  /// Play-/App-Store-Abgleich (primärer Gatekeeper). Aktualisiert [storeVersionDebug].
  static Future<({
    bool storeHasNewerSemver,
    String localSemver,
    String storeSemver,
    String? storePageUrl,
  })> _storeFirstGate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final localSemver = normalizeSemver(packageInfo.version);

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return (
        storeHasNewerSemver: false,
        localSemver: localSemver,
        storeSemver: localSemver,
        storePageUrl: null,
      );
    }

    final status = await _fetchStoreVersionStatus();
    if (status == null) {
      storeVersionDebug.value = 'n/a';
      return (
        storeHasNewerSemver: false,
        localSemver: localSemver,
        storeSemver: localSemver,
        storePageUrl: null,
      );
    }

    final storeSemver = normalizeSemver(status.storeVersion);
    storeVersionDebug.value = storeSemver;

    final newer = compareVersions(storeSemver, localSemver) > 0;
    debugLog(
      '🔎 AppUpdateService Store-First: local=$localSemver store=$storeSemver newer=$newer',
    );

    return (
      storeHasNewerSemver: newer,
      localSemver: localSemver,
      storeSemver: storeSemver,
      storePageUrl: status.appStoreLink,
    );
  }

  static Future<void> refreshStoreVersionDebugFromPlayCore() async {
    await _storeFirstGate();
  }

  static Future<void> debugFetchAndPrintStoreVersion() async {
    try {
      if (kIsWeb) {
        storeVersionDebug.value = 'web';
        return;
      }
      await _storeFirstGate();
      debugLog(
        '🔍 APP UPDATE DEBUG: storeVersionDebug=${storeVersionDebug.value}',
      );
    } catch (e) {
      debugLog('🔴 APP UPDATE DEBUG Fehler: $e');
    }
  }

  static Future<void> logUserAppVersion() async {
    debugLog('📱 AppUpdateService: logUserAppVersion start');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || kIsWeb) return;

    final nowClock = DateTime.now();
    if (_lastLogUserAppVersionUid == user.uid &&
        _lastLogUserAppVersionAt != null &&
        nowClock.difference(_lastLogUserAppVersionAt!) <
            const Duration(minutes: 2)) {
      debugLog('📱 AppUpdateService: logUserAppVersion übersprungen (≤2 min)');
      return;
    }
    _lastLogUserAppVersionUid = user.uid;
    _lastLogUserAppVersionAt = nowClock;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version.trim();
      final build = packageInfo.buildNumber.trim();
      final versionString = build.isEmpty ? version : '$version ($build)';

      final deviceInfo = DeviceInfoPlugin();
      String deviceId = '';
      String deviceModel = '';
      String osVersion = '';
      String platform = 'unknown';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        if (deviceId.isEmpty) {
          deviceId = androidInfo.fingerprint ?? 'android_unknown';
        }
        deviceModel = androidInfo.model;
        osVersion = androidInfo.version.release;
        platform = 'android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
        if (deviceId.isEmpty) deviceId = 'ios_${iosInfo.model}_unknown';
        deviceModel = iosInfo.utsname.machine.isNotEmpty
            ? iosInfo.utsname.machine
            : iosInfo.model;
        if (deviceModel.isEmpty) deviceModel = iosInfo.name;
        osVersion = iosInfo.systemVersion;
        platform = 'ios';
      } else {
        return;
      }

      final safeDeviceKey = deviceId.replaceAll('.', '_');
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await userRef.get();
      final devices = doc.data()?['devices'] as Map<String, dynamic>?;
      final existing = devices != null
          ? devices[safeDeviceKey] as Map<String, dynamic>?
          : null;
      final storedVersion = existing?['app_version'] as String?;
      final lastSeen = existing?['last_seen'] as Timestamp?;
      final now = DateTime.now();
      final lastSeenOlderThan24h =
          lastSeen == null || now.difference(lastSeen.toDate()).inHours >= 24;
      final versionChanged = storedVersion?.trim() != versionString;

      if (!versionChanged && !lastSeenOlderThan24h) return;

      final payload = {
        'app_version': versionString,
        'device_model': deviceModel,
        'os_version': osVersion,
        'platform': platform,
        'last_seen': FieldValue.serverTimestamp(),
      };

      if (doc.exists) {
        await userRef.update({'devices.$safeDeviceKey': payload});
      } else {
        await userRef.set({
          'devices': {safeDeviceKey: payload},
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugLog('AppUpdateService: logUserAppVersion Fehler: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadRawConfig() async {
    final docRef = FirebaseFirestore.instance
        .collection('admin_config')
        .doc(_adminConfigDocId);
    try {
      final doc = await docRef.get(const GetOptions(source: Source.server));
      return doc.data();
    } catch (_) {
      try {
        final cachedDoc = await docRef.get(const GetOptions(source: Source.cache));
        return cachedDoc.data();
      } catch (_) {
        return null;
      }
    }
  }

  AppUpdateConfig _appUpdateConfigFromData(Map<String, dynamic>? data) {
    final isIos = !kIsWeb && Platform.isIOS;
    final oldMinDjAndroid =
        normalizeSemver(_clean(data?['min_version_dj_android'] as String?, fallback: defaultMinVersion));
    final oldMinDjIos =
        normalizeSemver(_clean(data?['min_version_dj_ios'] as String?, fallback: defaultMinVersion));
    final oldMinGuestAndroid = normalizeSemver(_clean(
      data?['min_version_guest_android'] as String?,
      fallback: defaultMinVersion,
    ));
    final oldMinGuestIos = normalizeSemver(_clean(
      data?['min_version_guest_ios'] as String?,
      fallback: defaultMinVersion,
    ));

    final minVersionDj = normalizeSemver(
      _clean(
        data?['min_version_dj'] as String?,
        fallback: isIos ? oldMinDjIos : oldMinDjAndroid,
      ),
    );
    final minVersionGuest = normalizeSemver(
      _clean(
        data?['min_version_guest'] as String?,
        fallback: isIos ? oldMinGuestIos : oldMinGuestAndroid,
      ),
    );
    final currentVersion = normalizeSemver(
      _clean(
        data?['current_version'] as String?,
        fallback: minVersionDj,
      ),
    );
    final storeUrlAndroid = _clean(
      data?['store_url_android'] as String?,
      fallback: _playStoreDetailsUrl,
    );
    final storeUrlIos = _clean(
      data?['store_url_ios'] as String?,
      fallback: _appStoreFallbackUrl,
    );

    return AppUpdateConfig(
      currentVersion: currentVersion,
      minVersionGuest: minVersionGuest,
      minVersionDj: minVersionDj,
      storeUrlAndroid: storeUrlAndroid,
      storeUrlIos: storeUrlIos,
    );
  }

  Future<AppUpdateConfig> getUpdateConfig() async {
    final data = await _loadRawConfig();
    return _appUpdateConfigFromData(data);
  }

  Future<Map<String, String>> getMinVersions() async {
    final cfg = await getUpdateConfig();
    return {
      'current_version': cfg.currentVersion,
      'min_version_dj': cfg.minVersionDj,
      'min_version_guest': cfg.minVersionGuest,
      'min_version_dj_android': cfg.minVersionDj,
      'min_version_dj_ios': cfg.minVersionDj,
      'min_version_guest_android': cfg.minVersionGuest,
      'min_version_guest_ios': cfg.minVersionGuest,
      'store_url_android': cfg.storeUrlAndroid,
      'store_url_ios': cfg.storeUrlIos,
    };
  }

  /// Store-First: nur wenn Store-Semver > installiert → Firestore; sonst Abbruch.
  ///
  /// Pflicht: strengere der Policies [cfg.minVersionDj] / [cfg.minVersionGuest]
  /// (inkl. `min_version_dj` / `min_version_guest` und *_android/ios) liegt über
  /// der installierten [PackageInfo.version]-Semver.
  /// Optional: neuer Store-Build, aber installiert erfüllt die Mindestpolicy.
  Future<({
    UpdateCheckResult result,
    String? minVersion,
    String? currentVersion,
    String? localVersion,
    String? storeUrl,
  })> checkForUpdate() async {
    if (kIsWeb) {
      return (
        result: UpdateCheckResult.skip,
        minVersion: null,
        currentVersion: null,
        localVersion: null,
        storeUrl: null,
      );
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      return (
        result: UpdateCheckResult.skip,
        minVersion: null,
        currentVersion: null,
        localVersion: null,
        storeUrl: null,
      );
    }
    // Debug-Build oder z. B. `flutter run --dart-define=SKIP_APP_UPDATE_CHECK=true`
    // (Profil/Release-APK mit älterer Version als im Store, ohne Update-Dialoge).
    if (kDebugMode || _skipUpdateCheckFromDefine) {
      return (
        result: UpdateCheckResult.skip,
        minVersion: null,
        currentVersion: null,
        localVersion: null,
        storeUrl: null,
      );
    }

    final localDisplay = await localVersionLabel();

    final gate = await _storeFirstGate();
    if (!gate.storeHasNewerSemver) {
      return (
        result: UpdateCheckResult.upToDate,
        minVersion: null,
        currentVersion: null,
        localVersion: localDisplay,
        storeUrl: null,
      );
    }

    final raw = await _loadRawConfig();
    final cfg = _appUpdateConfigFromData(raw);
    // Pflicht-Mindestversion: strengeres aus DJ- und Gast-Policy (Firestore:
    // `min_version_dj` / `min_version_guest` inkl. Fallback auf *_android/ios).
    // So gilt „für alle“ auch auf der Startseite ohne Login (sonst nur Gast-Keys).
    final firestoreMin = compareVersions(cfg.minVersionDj, cfg.minVersionGuest) >= 0
        ? cfg.minVersionDj
        : cfg.minVersionGuest;
    final storeUrlPreferred = Platform.isAndroid ? cfg.storeUrlAndroid : cfg.storeUrlIos;
    final storeUrlLaunch =
        (gate.storePageUrl != null && gate.storePageUrl!.isNotEmpty)
            ? gate.storePageUrl!
            : storeUrlPreferred;

    final localSemver = gate.localSemver;

    // Pflicht: Mindestversion aus Firestore liegt über der Installation.
    if (compareVersions(firestoreMin, localSemver) > 0) {
      return (
        result: UpdateCheckResult.forceUpdate,
        minVersion: firestoreMin,
        currentVersion: gate.storeSemver,
        localVersion: localDisplay,
        storeUrl: storeUrlLaunch,
      );
    }

    // Optional: Store neuer als installiert, aber installiert erfüllt Mindestpolicy.
    if (!_optionalPromptShownInSession) {
      _optionalPromptShownInSession = true;
      return (
        result: UpdateCheckResult.optionalUpdate,
        minVersion: firestoreMin,
        currentVersion: gate.storeSemver,
        localVersion: localDisplay,
        storeUrl: storeUrlLaunch,
      );
    }

    return (
      result: UpdateCheckResult.upToDate,
      minVersion: firestoreMin,
      currentVersion: gate.storeSemver,
      localVersion: localDisplay,
      storeUrl: storeUrlLaunch,
    );
  }

  static Future<void> _exitAppHard() async {
    if (kIsWeb) {
      await SystemNavigator.pop();
      return;
    }
    exit(0);
  }

  static Future<void> _openStoreExternal(String storeUrl) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static Future<void> showUpdateDialog({
    required BuildContext context,
    required bool force,
    required String availableVersion,
    required String storeUrl,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final title = force
        ? l10n.updateRequiredTitle
        : l10n.updateAvailableTitle;
    final description = force
        ? l10n.updateDescriptionMandatory
        : l10n.updateDescriptionOptional;
    final versionText = l10n.updateVersionAvailable
        .replaceAll('{version}', availableVersion);
    final secondaryDismissLabel =
        force ? l10n.updateMandatoryExitButton : l10n.laterButton;
    final updateText = l10n.updateButton;

    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UIConstants.appOrange, width: 2),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: UIConstants.appWhite,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: UIConstants.appWhite,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  versionText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: UIConstants.appWhite,
                      ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          if (force) {
                            await _exitAppHard();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: UIConstants.appOrange,
                          ),
                          foregroundColor: UIConstants.appWhite,
                        ),
                        child: Text(secondaryDismissLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _openStoreExternal(storeUrl);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: UIConstants.appOrange,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(updateText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
