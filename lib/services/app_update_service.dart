import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';
import '../l10n/locale_helper.dart';
import '../utils/stable_device_id.dart';
import '../utils/device_display_helper.dart';
import '../utils/callable_payload_serializer.dart';
import 'app_diagnostic_log_service.dart';

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
  static const String _prefOptionalDismissedStoreVersion =
      'optional_update_dismissed_store_version_v1';

  /// Einmal pro App-Session und UID (nicht bei jedem Rollen-Rebuild erneut).
  static String? _updateCheckCompletedUid;

  static void resetSessionForLogout() {
    _optionalPromptShownInSession = false;
    _updateCheckCompletedUid = null;
    _lastLogUserAppVersionUid = null;
    _lastLogUserAppVersionAt = null;
    _lastLoggedVersionString = null;
    _sessionTelemetrySucceededUid = null;
    _sessionTelemetryInFlight = null;
  }

  /// Erfolgreich geschriebene Geräte-/App-Version-Telemetrie für diese App-Session + UID.
  /// Erst nach erfolgreichem Write setzen — sonst erneute Versuche bei Login/Home/Resume.
  static String? _sessionTelemetrySucceededUid;
  static Future<bool>? _sessionTelemetryInFlight;

  /// Einmal pro Login-Session (manuell oder Auto-Login): aktuelle App-Version + Gerät
  /// nach Firestore schreiben. Bei Fehler **nicht** als erledigt markieren.
  static Future<bool> ensureSessionDeviceTelemetry({
    String reason = 'session',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || kIsWeb) return false;
    if (_sessionTelemetrySucceededUid == user.uid) {
      debugLog(
        '📱 AppUpdateService: Session-Telemetrie bereits OK '
        '(uid=${user.uid}, reason=$reason) — Soft-Refresh',
      );
      // Nach erstem Erfolg trotzdem last_seen/Version refreshen (gedrosselt),
      // sonst bleiben Admin-Daten stundenlang auf dem Stand vom Kaltstart.
      if (reason == 'resume' ||
          reason.startsWith('home_') ||
          reason == 'login') {
        return logUserAppVersion(force: false);
      }
      return true;
    }
    final inFlight = _sessionTelemetryInFlight;
    if (inFlight != null) {
      debugLog(
        '📱 AppUpdateService: Session-Telemetrie läuft bereits — warte '
        '(reason=$reason)',
      );
      return inFlight;
    }
    final future = _runSessionDeviceTelemetry(reason: reason);
    _sessionTelemetryInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_sessionTelemetryInFlight, future)) {
        _sessionTelemetryInFlight = null;
      }
    }
  }

  static Future<bool> _runSessionDeviceTelemetry({
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || kIsWeb) return false;

    debugLog(
      '📱 AppUpdateService: Session-Telemetrie starten '
      '(uid=${user.uid}, reason=$reason)',
    );
    // Auth/Token kann beim Kaltstart noch nicht bereit sein — kurz gestaffelt retryen.
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
          return false;
        }
      }
      final ok = await logUserAppVersion(force: true);
      if (ok) {
        _sessionTelemetrySucceededUid = user.uid;
        diagLog(
          'DEVICE',
          'Session-Telemetrie OK reason=$reason attempt=${attempt + 1}',
        );
        return true;
      }
      debugLog(
        '📱 AppUpdateService: Session-Telemetrie Versuch ${attempt + 1}/4 fehlgeschlagen',
      );
    }
    diagLog('DEVICE', 'Session-Telemetrie FEHLER reason=$reason');
    return false;
  }

  /// Fallback von DJ-/Gast-Home, falls Cold-Start die Telemetrie noch nicht geschafft hat.
  static Future<void> logUserAppVersionFromHomeShell({
    required String area,
  }) async {
    final normalizedArea = area.trim().toLowerCase();
    if (normalizedArea != 'dj' && normalizedArea != 'guest') return;
    await ensureSessionDeviceTelemetry(reason: 'home_$normalizedArea');
  }

  static bool hasCompletedUpdateCheckForUid(String uid) =>
      _updateCheckCompletedUid == uid;

  static void markUpdateCheckCompletedForUid(String uid) {
    _updateCheckCompletedUid = uid;
  }

  static Future<void> markOptionalUpdateDismissed(String storeVersion) async {
    final v = normalizeSemver(storeVersion);
    if (v.isEmpty || v == '0.0.0') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefOptionalDismissedStoreVersion, v);
    } catch (_) {}
  }

  static Future<bool> wasOptionalUpdateDismissed(String storeVersion) async {
    final v = normalizeSemver(storeVersion);
    if (v.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefOptionalDismissedStoreVersion) == v;
    } catch (_) {
      return false;
    }
  }

  /// Verhindert viele Firestore-Writes bei schnellen Resume-Ketten (pro UID).
  static String? _lastLogUserAppVersionUid;
  static DateTime? _lastLogUserAppVersionAt;
  static String? _lastLoggedVersionString;
  static const Duration _logUserAppVersionMinInterval = Duration(minutes: 5);

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

  /// Schreibt App-Version + Geräteinfos. [true] nur bei erfolgreichem Callable- oder Firestore-Write.
  static Future<bool> logUserAppVersion({bool force = false}) async {
    debugLog('📱 AppUpdateService: logUserAppVersion start (force=$force)');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || kIsWeb) return false;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version.trim();
      final build = packageInfo.buildNumber.trim();
      // Explizit Plattform-Version: Android=pubspec, iOS=xcconfig (getrennt!).
      final versionString = build.isEmpty ? version : '$version ($build)';

      final nowClock = DateTime.now();
      final sameUid = _lastLogUserAppVersionUid == user.uid;
      final versionUnchanged =
          sameUid && _lastLoggedVersionString == versionString;
      if (!force &&
          sameUid &&
          versionUnchanged &&
          _lastLogUserAppVersionAt != null &&
          nowClock.difference(_lastLogUserAppVersionAt!) <
              _logUserAppVersionMinInterval) {
        debugLog(
          '📱 AppUpdateService: logUserAppVersion übersprungen '
          '(≤${_logUserAppVersionMinInterval.inMinutes} min, gleiche Version)',
        );
        // Soft-Skip: Daten sind in dieser Session schon erfolgreich geschrieben.
        return _sessionTelemetrySucceededUid == user.uid ||
            _lastLoggedVersionString == versionString;
      }

      String deviceModel = '';
      String deviceModelCode = '';
      String osVersion = '';
      String platform = 'unknown';

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        deviceModelCode = androidInfo.model.trim();
        if (deviceModelCode.isEmpty) {
          deviceModelCode = androidInfo.device.trim();
        }
        deviceModel = DeviceDisplayHelper.androidDisplayName(
          manufacturer: androidInfo.manufacturer,
          model: androidInfo.model,
          brand: androidInfo.brand,
          device: androidInfo.device,
          product: androidInfo.product,
        );
        osVersion = androidInfo.version.release.trim();
        platform = 'android';
      } else if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        deviceModelCode = iosInfo.utsname.machine.isNotEmpty
            ? iosInfo.utsname.machine
            : iosInfo.model;
        deviceModel = DeviceDisplayHelper.iosMarketingName(deviceModelCode);
        if (deviceModel.isEmpty) {
          deviceModel = iosInfo.model.trim().isNotEmpty
              ? iosInfo.model.trim()
              : iosInfo.name.trim();
        }
        osVersion = iosInfo.systemVersion;
        platform = 'ios';
      } else {
        return false;
      }

      if (deviceModel.trim().isEmpty) {
        deviceModel = deviceModelCode.trim().isNotEmpty
            ? deviceModelCode.trim()
            : platform;
      }
      if (osVersion.trim().isEmpty) {
        osVersion = 'unknown';
      }

      final deviceId = await getStableDeviceId();
      final safeDeviceKey = deviceId.replaceAll('.', '_');
      final appLanguage = LocaleHelper.localeNotifier.value.languageCode;
      final systemLocaleTag =
          ui.PlatformDispatcher.instance.locale.toLanguageTag();
      final payload = <String, dynamic>{
        'app_version': versionString,
        'version_name': version,
        'build_number': build,
        'device_model': deviceModel,
        'device_model_code': deviceModelCode,
        'os_version': osVersion,
        'platform': platform,
        'app_language': appLanguage,
        'system_locale_tag': systemLocaleTag,
        'last_seen': FieldValue.serverTimestamp(),
      };

      final topLevel = <String, dynamic>{
        'app_version': versionString,
        'platform': platform,
        'device_model': deviceModel,
        'device_model_code': deviceModelCode,
        'os_version': osVersion,
        'app_version_updated_at': FieldValue.serverTimestamp(),
        'last_seen': FieldValue.serverTimestamp(),
        'last_app_system_locale_tag': systemLocaleTag,
      };

      var callableOk = false;
      Object? lastCallableError;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await _logDeviceTelemetryViaCallable(
            deviceKey: safeDeviceKey,
            payload: payload,
          );
          callableOk = true;
          debugLog('📱 AppUpdateService: Geräte-Telemetrie via Callable OK');
          break;
        } catch (callableError) {
          lastCallableError = callableError;
          debugLog(
            '📱 AppUpdateService: Callable Versuch ${attempt + 1}/3 fehlgeschlagen: $callableError',
          );
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 350 * (attempt + 1)),
            );
          }
        }
      }
      if (!callableOk && lastCallableError != null) {
        debugLog(
          '📱 AppUpdateService: Callable endgültig fehlgeschlagen: $lastCallableError',
        );
      }

      var firestoreOk = false;
      try {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await userRef.get();
        final update = <String, dynamic>{
          'devices.$safeDeviceKey': payload,
          ...topLevel,
        };
        if (doc.exists) {
          await userRef.update(update);
        } else {
          await userRef.set(
            <String, dynamic>{
              'devices': {safeDeviceKey: payload},
              ...topLevel,
            },
            SetOptions(merge: true),
          );
        }
        firestoreOk = true;
        debugLog('📱 AppUpdateService: Geräte-Telemetrie Firestore OK');
      } catch (firestoreError) {
        debugLog(
          '📱 AppUpdateService: Firestore Telemetrie fehlgeschlagen: $firestoreError',
        );
        if (!callableOk) rethrow;
      }

      if (!callableOk && !firestoreOk) {
        return false;
      }

      _lastLogUserAppVersionUid = user.uid;
      _lastLogUserAppVersionAt = nowClock;
      _lastLoggedVersionString = versionString;
      diagLog(
        'DEVICE',
        'Telemetrie OK uid=${user.uid} device=$safeDeviceKey version=$versionString model=$deviceModel',
      );
      return true;
    } catch (e, st) {
      debugLog('AppUpdateService: logUserAppVersion Fehler: $e\n$st');
      diagLog('DEVICE', 'Telemetrie FEHLER: $e');
      return false;
    }
  }

  static Future<void> _logDeviceTelemetryViaCallable({
    required String deviceKey,
    required Map<String, dynamic> payload,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('logUserDeviceTelemetry');
    final serializable = Map<String, dynamic>.from(payload)
      ..remove('last_seen');
    await callable.call<Map<String, dynamic>>({
      'deviceKey': deviceKey,
      'payload': serializeForCallable(serializable),
    });
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

  /// Einzelzelle aus Firestore; [aggregateKey] nur wenn die andere Plattform-Zelle noch Default ist (Legacy).
  static String _resolvedCell(
    Map<String, dynamic>? data, {
    required String cellKey,
    required String otherPlatformCellKey,
    required String aggregateKey,
  }) {
    final base = defaultMinVersion;
    final cell = normalizeSemver(
      _clean(data?[cellKey] as String?, fallback: base),
    );
    if (cell != base) return cell;
    final other = normalizeSemver(
      _clean(data?[otherPlatformCellKey] as String?, fallback: base),
    );
    final agg = normalizeSemver(
      _clean(data?[aggregateKey] as String?, fallback: base),
    );
    if (other == base && agg != base) return agg;
    return base;
  }

  /// Für Update-Vergleich: Default-Zelle = keine Pflicht (immer erfüllt).
  static String _policyMinOrZero(String v) {
    final n = normalizeSemver(v);
    return n == defaultMinVersion ? '0.0.0' : n;
  }

  /// Mindest-Semver für aktuelle Plattform + App-Rolle (Gast vs. DJ/Admin/…).
  static String effectivePolicyMinVersion({
    required Map<String, dynamic>? data,
    required bool isAndroid,
    required String? roleLabel,
  }) {
    final guestAndroid = _policyMinOrZero(
      _resolvedCell(
        data,
        cellKey: 'min_version_guest_android',
        otherPlatformCellKey: 'min_version_guest_ios',
        aggregateKey: 'min_version_guest',
      ),
    );
    final guestIos = _policyMinOrZero(
      _resolvedCell(
        data,
        cellKey: 'min_version_guest_ios',
        otherPlatformCellKey: 'min_version_guest_android',
        aggregateKey: 'min_version_guest',
      ),
    );
    final djAndroid = _policyMinOrZero(
      _resolvedCell(
        data,
        cellKey: 'min_version_dj_android',
        otherPlatformCellKey: 'min_version_dj_ios',
        aggregateKey: 'min_version_dj',
      ),
    );
    final djIos = _policyMinOrZero(
      _resolvedCell(
        data,
        cellKey: 'min_version_dj_ios',
        otherPlatformCellKey: 'min_version_dj_android',
        aggregateKey: 'min_version_dj',
      ),
    );

    String guestSlot() => isAndroid ? guestAndroid : guestIos;
    String djSlot() => isAndroid ? djAndroid : djIos;

    if (roleLabel == 'Gast') return guestSlot();
    if (roleLabel == null || roleLabel == 'loading') {
      final g = guestSlot();
      final d = djSlot();
      return compareVersions(g, d) >= 0 ? g : d;
    }
    return djSlot();
  }

  AppUpdateConfig _appUpdateConfigFromData(Map<String, dynamic>? data) {
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final minDjAndroid = _resolvedCell(
      data,
      cellKey: 'min_version_dj_android',
      otherPlatformCellKey: 'min_version_dj_ios',
      aggregateKey: 'min_version_dj',
    );
    final minDjIos = _resolvedCell(
      data,
      cellKey: 'min_version_dj_ios',
      otherPlatformCellKey: 'min_version_dj_android',
      aggregateKey: 'min_version_dj',
    );
    final minGuestAndroid = _resolvedCell(
      data,
      cellKey: 'min_version_guest_android',
      otherPlatformCellKey: 'min_version_guest_ios',
      aggregateKey: 'min_version_guest',
    );
    final minGuestIos = _resolvedCell(
      data,
      cellKey: 'min_version_guest_ios',
      otherPlatformCellKey: 'min_version_guest_android',
      aggregateKey: 'min_version_guest',
    );

    final minVersionDj = compareVersions(minDjAndroid, minDjIos) >= 0
        ? minDjAndroid
        : minDjIos;
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

    final isIos = !kIsWeb && Platform.isIOS;
    final minGuestResolved = isAndroid
        ? minGuestAndroid
        : (isIos ? minGuestIos : minGuestAndroid);
    final minDjResolved = isAndroid
        ? minDjAndroid
        : (isIos ? minDjIos : minDjAndroid);

    return AppUpdateConfig(
      currentVersion: currentVersion,
      minVersionGuest: minGuestResolved,
      minVersionDj: minDjResolved,
      storeUrlAndroid: storeUrlAndroid,
      storeUrlIos: storeUrlIos,
    );
  }

  Future<AppUpdateConfig> getUpdateConfig() async {
    final data = await _loadRawConfig();
    return _appUpdateConfigFromData(data);
  }

  Future<Map<String, String>> getMinVersions() async {
    final data = await _loadRawConfig();
    final base = defaultMinVersion;
    final cfg = _appUpdateConfigFromData(data);
    String cell(String k) =>
        normalizeSemver(_clean(data?[k] as String?, fallback: base));
    return {
      'current_version': cfg.currentVersion,
      'min_version_dj': normalizeSemver(
        _clean(data?['min_version_dj'] as String?, fallback: cfg.minVersionDj),
      ),
      'min_version_guest': normalizeSemver(
        _clean(
          data?['min_version_guest'] as String?,
          fallback: cfg.minVersionGuest,
        ),
      ),
      'min_version_dj_android': cell('min_version_dj_android'),
      'min_version_dj_ios': cell('min_version_dj_ios'),
      'min_version_guest_android': cell('min_version_guest_android'),
      'min_version_guest_ios': cell('min_version_guest_ios'),
      'store_url_android': cfg.storeUrlAndroid,
      'store_url_ios': cfg.storeUrlIos,
    };
  }

  /// Store-First: nur wenn Store-Semver > installiert → Firestore; sonst Abbruch.
  ///
  /// Pflicht: Mindest-Semver aus `admin_config/app_update` für **Plattform** (Android/iOS)
  /// und **Rolle** ([appRoleLabel]: `Gast` vs. sonst DJ/Admin/…) – siehe
  /// [effectivePolicyMinVersion]. Liegt über [PackageInfo.version] → Zwang/Dialog.
  /// Optional: neuer Store-Build, aber installiert erfüllt die Mindestpolicy.
  Future<({
    UpdateCheckResult result,
    String? minVersion,
    String? currentVersion,
    String? localVersion,
    String? storeUrl,
  })> checkForUpdate({String? appRoleLabel}) async {
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
    final firestoreMin = effectivePolicyMinVersion(
      data: raw,
      isAndroid: Platform.isAndroid,
      roleLabel: appRoleLabel,
    );
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
      if (await wasOptionalUpdateDismissed(gate.storeSemver)) {
        return (
          result: UpdateCheckResult.upToDate,
          minVersion: firestoreMin,
          currentVersion: gate.storeSemver,
          localVersion: localDisplay,
          storeUrl: storeUrlLaunch,
        );
      }
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
                          if (!force) {
                            await markOptionalUpdateDismissed(availableVersion);
                          } else {
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
