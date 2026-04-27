import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
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

  static String _clean(String? v, {String fallback = ''}) {
    final t = (v ?? '').trim();
    return t.isEmpty ? fallback : t;
  }

  static Future<String> localVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    if (build.isNotEmpty) return build;
    return info.version.trim();
  }

  static int compareVersions(String a, String b) {
    final ai = int.tryParse(a.trim());
    final bi = int.tryParse(b.trim());
    if (ai != null && bi != null) {
      if (ai < bi) return -1;
      if (ai > bi) return 1;
      return 0;
    }
    final partsA = _parseVersion(a);
    final partsB = _parseVersion(b);
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

  /// Mindestversion direkt aus Firestore-Feldern (z. B. `min_version_dj_android`), wie im Admin gepflegt.
  static String _minVersionFromFirestoreForRole({
    required Map<String, dynamic>? data,
    required bool isDJOrAdmin,
    required bool isAndroid,
  }) {
    final base = defaultMinVersion;
    if (isAndroid) {
      final key =
          isDJOrAdmin ? 'min_version_dj_android' : 'min_version_guest_android';
      return _clean(data?[key] as String?, fallback: base);
    }
    final key = isDJOrAdmin ? 'min_version_dj_ios' : 'min_version_guest_ios';
    return _clean(data?[key] as String?, fallback: base);
  }

  /// Derselbe Play-Core-Pfad wie früher im Header / Easter Egg: `InAppUpdate.checkForUpdate()`.
  /// Aktualisiert [storeVersionDebug]. Optional [installedVersionCode], sonst aus [PackageInfo].
  static Future<({
    bool checkSuccessful,
    bool storeHasNewVersion,
    int? availableVersionCode,
  })> _playCoreCheckAndroid({int? installedVersionCode}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return (
        checkSuccessful: false,
        storeHasNewVersion: false,
        availableVersionCode: null,
      );
    }
    if (kDebugMode) {
      storeVersionDebug.value = 'n/a';
      return (
        checkSuccessful: false,
        storeHasNewVersion: false,
        availableVersionCode: null,
      );
    }
    final installed = installedVersionCode ??
        (int.tryParse((await PackageInfo.fromPlatform()).buildNumber.trim()) ?? 0);
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      final storeVersionCode = updateInfo.availableVersionCode;
      final availability = updateInfo.updateAvailability;
      storeVersionDebug.value =
          storeVersionCode != null ? storeVersionCode.toString() : 'null';
      debugLog(
        '🔎 AppUpdateService PlayCore: availability=$availability | storeCode=$storeVersionCode | installedCode=$installed',
      );
      final storeHasNewVersion =
          availability == UpdateAvailability.updateAvailable &&
              storeVersionCode != null &&
              storeVersionCode > installed;
      return (
        checkSuccessful: true,
        storeHasNewVersion: storeHasNewVersion,
        availableVersionCode: storeVersionCode,
      );
    } on PlatformException catch (e) {
      if (e.code == '-10' || e.code == 'ERROR_APP_NOT_OWNED') {
        storeVersionDebug.value = 'not-owned';
        debugLog(
          '🟠 AppUpdateService: PlayCore App-not-owned (-10). Debug/Sideload ohne Store-Ownership.',
        );
      } else {
        storeVersionDebug.value = 'fehler';
        debugLog('🔴 AppUpdateService: PlayCore PlatformException: $e');
      }
      return (
        checkSuccessful: false,
        storeHasNewVersion: false,
        availableVersionCode: null,
      );
    } catch (e) {
      storeVersionDebug.value = 'fehler';
      debugLog('🔴 AppUpdateService: PlayCore check Fehler: $e');
      return (
        checkSuccessful: false,
        storeHasNewVersion: false,
        availableVersionCode: null,
      );
    }
  }

  /// Wie früher im AppBar-Header: Play-Core-`availableVersionCode` → [storeVersionDebug].
  static Future<void> refreshStoreVersionDebugFromPlayCore() async {
    if (kIsWeb) {
      storeVersionDebug.value = 'web';
      return;
    }
    if (!Platform.isAndroid) {
      storeVersionDebug.value = 'n/a';
      return;
    }
    await _playCoreCheckAndroid();
  }

  static Future<void> debugFetchAndPrintStoreVersion() async {
    try {
      if (kIsWeb) {
        storeVersionDebug.value = 'web';
        return;
      }
      await refreshStoreVersionDebugFromPlayCore();
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

  Future<AppUpdateConfig> getUpdateConfig() async {
    final data = await _loadRawConfig();
    final isIos = !kIsWeb && Platform.isIOS;
    final oldMinDjAndroid =
        _clean(data?['min_version_dj_android'] as String?, fallback: defaultMinVersion);
    final oldMinDjIos =
        _clean(data?['min_version_dj_ios'] as String?, fallback: defaultMinVersion);
    final oldMinGuestAndroid = _clean(
      data?['min_version_guest_android'] as String?,
      fallback: defaultMinVersion,
    );
    final oldMinGuestIos = _clean(
      data?['min_version_guest_ios'] as String?,
      fallback: defaultMinVersion,
    );

    final minVersionDj = _clean(
      data?['min_version_dj'] as String?,
      fallback: isIos ? oldMinDjIos : oldMinDjAndroid,
    );
    final minVersionGuest = _clean(
      data?['min_version_guest'] as String?,
      fallback: isIos ? oldMinGuestIos : oldMinGuestAndroid,
    );
    final currentVersion = _clean(
      data?['current_version'] as String?,
      fallback: minVersionDj,
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

  Future<({
    UpdateCheckResult result,
    String? minVersion,
    String? currentVersion,
    String? localVersion,
    String? storeUrl,
  })> checkForUpdate({
    required bool isDJOrAdmin,
  }) async {
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

    final packageInfo = await PackageInfo.fromPlatform();
    final localDisplay = await localVersionLabel();
    final localSemver =
        packageInfo.version.split(RegExp(r'\+')).first.trim();
    final cfg = await getUpdateConfig();
    final raw = await _loadRawConfig();
    final minVersion = _minVersionFromFirestoreForRole(
      data: raw,
      isDJOrAdmin: isDJOrAdmin,
      isAndroid: Platform.isAndroid,
    );
    final storeUrl = Platform.isAndroid ? cfg.storeUrlAndroid : cfg.storeUrlIos;

    // 1) Pflicht-Update: installierte Semver vs. Firestore-Min (z. B. min_version_dj_android) — ohne Play Core.
    if (compareVersions(localSemver, minVersion) < 0) {
      return (
        result: UpdateCheckResult.forceUpdate,
        minVersion: minVersion,
        currentVersion: cfg.currentVersion,
        localVersion: localDisplay,
        storeUrl: storeUrl,
      );
    }

    // Android: optionales Update nur über Play Core (Release).
    if (Platform.isAndroid) {
      final installedCode =
          int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

      if (kDebugMode) {
        return (
          result: UpdateCheckResult.upToDate,
          minVersion: minVersion,
          currentVersion: cfg.currentVersion,
          localVersion: localDisplay,
          storeUrl: storeUrl,
        );
      }

      final play = await _playCoreCheckAndroid(
        installedVersionCode: installedCode,
      );

      if (!play.checkSuccessful) {
        return (
          result: UpdateCheckResult.upToDate,
          minVersion: minVersion,
          currentVersion: cfg.currentVersion,
          localVersion: localDisplay,
          storeUrl: storeUrl,
        );
      }

      if (!play.storeHasNewVersion) {
        return (
          result: UpdateCheckResult.upToDate,
          minVersion: minVersion,
          currentVersion: play.availableVersionCode?.toString() ?? cfg.currentVersion,
          localVersion: localDisplay,
          storeUrl: storeUrl,
        );
      }

      final storeVersionStr =
          play.availableVersionCode?.toString() ?? cfg.currentVersion;

      if (!_optionalPromptShownInSession) {
        _optionalPromptShownInSession = true;
        return (
          result: UpdateCheckResult.optionalUpdate,
          minVersion: minVersion,
          currentVersion: storeVersionStr,
          localVersion: localDisplay,
          storeUrl: storeUrl,
        );
      }

      return (
        result: UpdateCheckResult.upToDate,
        minVersion: minVersion,
        currentVersion: storeVersionStr,
        localVersion: localDisplay,
        storeUrl: storeUrl,
      );
    }

    // iOS: Empfehlung über Firestore current_version (Pflicht oben schon geprüft).
    final local = localDisplay;
    if (!_optionalPromptShownInSession &&
        compareVersions(localSemver, cfg.currentVersion) < 0) {
      _optionalPromptShownInSession = true;
      return (
        result: UpdateCheckResult.optionalUpdate,
        minVersion: minVersion,
        currentVersion: cfg.currentVersion,
        localVersion: local,
        storeUrl: storeUrl,
      );
    }

    return (
      result: UpdateCheckResult.upToDate,
      minVersion: minVersion,
      currentVersion: cfg.currentVersion,
      localVersion: local,
      storeUrl: storeUrl,
    );
  }

  /// Beendet die App: Android über [SystemNavigator.pop], sonst [exit] (z. B. iOS).
  static Future<void> _closeApp() async {
    try {
      if (kIsWeb) {
        await SystemNavigator.pop();
        return;
      }
      if (Platform.isAndroid) {
        await SystemNavigator.pop();
      } else {
        exit(0);
      }
    } catch (_) {
      if (!kIsWeb) {
        try {
          exit(0);
        } catch (_) {}
      }
    }
  }

  static Future<void> _openStoreAndClose(String storeUrl) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    await _closeApp();
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
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
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
                            await _closeApp();
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
                          await _openStoreAndClose(storeUrl);
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
