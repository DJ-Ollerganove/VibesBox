import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../helpers/security_helper.dart';
import 'dj_pro_session_service.dart';
import 'pro_feature_guard.dart';
import 'shazam_service.dart';
import 'trial_expiry_service.dart';
import '../l10n/locale_helper.dart';
import '../models/user_model.dart';
import '../utils/auth_stream_utils.dart';
import 'device_block_fusion_service.dart';
import 'dj_device_notification_prefs_service.dart';
import 'pdf_display_options_service.dart';
import '../utils/debug_log.dart';

export 'dj_pro_session_service.dart' show DjProSessionService, SessionProStatus;

/// Zentraler Service für User-Daten: Echtzeit-Stream auf users/{uid} und Logo-Cache.
/// Nach Login wird der Firestore-Stream gestartet; bei Logout [stopUserStream] aufrufen.
class UserService {
  static Map<String, dynamic> _sanitizeWriteMap(Map<String, dynamic> map) =>
      SecurityHelper.sanitizeMap(map);
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  /// Zentrales User-Modell (Echtzeit aus Firestore). Über [UserScope] in der UI verfügbar.
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);

  /// Stream für [currentUser] – für StreamBuilder (z. B. Admin-Dashboard). Beim Abonnieren wird sofort der aktuelle Wert gesendet.
  StreamController<UserModel?>? _userStreamController;
  Stream<UserModel?> get userStream {
    _userStreamController ??= StreamController<UserModel?>.broadcast();
    // Sende den aktuellen Wert sofort an neue Listener (verhindert verlorenes erstes Event)
    Timer.run(() => _userStreamController?.add(currentUser.value));
    return _userStreamController!.stream;
  }

  void _emitRawUser(UserModel? value) {
    if (currentUser.value == value) {
      return;
    }
    currentUser.value = value;
    _userStreamController?.add(value);
  }

  void _tearDownDevicePrefsListener() {
    _devicePrefsSub?.cancel();
    _devicePrefsSub = null;
    _devicePrefsStreamUid = null;
    _devicePrefsStreamInstallId = null;
    _devicePrefsData = null;
  }

  void _emitMergedFromCaches() {
    final root = _userModelFromRootDoc;
    if (root == null) {
      _emitRawUser(null);
      return;
    }
    _emitRawUser(
      DjDeviceNotificationPrefsService.merge(root, _devicePrefsData),
    );
  }

  /// Setzt das Root-[UserModel] aus `users/{uid}` und emittiert inkl. Geräte-Overrides.
  void _setRootUserAndEmit(UserModel? root) {
    if (root == null) {
      _tearDownDevicePrefsListener();
      _userModelFromRootDoc = null;
      _emitRawUser(null);
      return;
    }
    _userModelFromRootDoc = root;
    _emitMergedFromCaches();
  }

  Future<void> _maybeSeedOrCreateDeviceDocument(
    String uid,
    String installId,
  ) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final devRef =
        DjDeviceNotificationPrefsService.deviceDocRef(uid, installId);
    Map<String, dynamic>? reusablePrefs;
    try {
      final devCheck = await devRef.get();
      if (!devCheck.exists) {
        reusablePrefs =
            await DjDeviceNotificationPrefsService.findReusableSamePlatformPrefs(
          uid,
          installId,
        );
      }
    } catch (_) {
      // Seed trotzdem versuchen
    }
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final devSnap = await tx.get(devRef);
        if (!userSnap.exists) return;
        final uData = userSnap.data()!;
        final awaiting =
            uData[DjDeviceNotificationPrefsService.userFieldAwaitingFirstDeviceSeed] ==
                true;
        if (!devSnap.exists) {
          if (reusablePrefs != null) {
            tx.set(devRef, reusablePrefs);
          } else if (awaiting) {
            tx.set(
              devRef,
              DjDeviceNotificationPrefsService.fullDevicePayload(
                notifyNewWishes: uData['notifyNewWishes'] == true,
                enableNotificationSound:
                    uData['enableNotificationSound'] != false,
                showStatusNotification:
                    uData['show_status_notification'] == true,
              ),
            );
            tx.update(userRef, {
              DjDeviceNotificationPrefsService.userFieldAwaitingFirstDeviceSeed:
                  false,
            });
          } else {
            tx.set(
              devRef,
              DjDeviceNotificationPrefsService.fullDevicePayload(
                notifyNewWishes: false,
                enableNotificationSound: true,
                showStatusNotification: false,
              ),
            );
          }
        } else if (awaiting) {
          tx.update(userRef, {
            DjDeviceNotificationPrefsService.userFieldAwaitingFirstDeviceSeed:
                false,
          });
        }
      });
    } catch (e) {
      debugLog('👤 UserService: Seed dj_device_prefs: $e');
    }
  }

  Future<void> _ensureDevicePrefsForUid(String uid) async {
    try {
      final installId =
          await DjDeviceNotificationPrefsService.getOrCreateInstallId();
      if (_devicePrefsStreamUid != uid ||
          _devicePrefsStreamInstallId != installId) {
        _devicePrefsSub?.cancel();
        _devicePrefsStreamUid = uid;
        _devicePrefsStreamInstallId = installId;
        _devicePrefsData = null;
        final devRef =
            DjDeviceNotificationPrefsService.deviceDocRef(uid, installId);
        _devicePrefsSub = devRef.snapshots().listen(
          (DocumentSnapshot<Map<String, dynamic>> snap) {
            _devicePrefsData = snap.data();
            _emitMergedFromCaches();
          },
          onError: (Object e, StackTrace st) {
            debugLog('👤 UserService: dj_device_prefs Snapshot: $e');
          },
        );
      }
      await _maybeSeedOrCreateDeviceDocument(uid, installId);
    } catch (e) {
      debugLog('👤 UserService: device prefs Pipeline: $e');
    }
  }

  /// Firestore [isAdmin()] braucht `users.admin == true` — App erkennt Admin auch über role_id.
  Future<void> _syncFirestoreAdminFlagIfNeeded(
    String uid,
    UserModel userModel,
    Map<String, dynamic>? rawData,
  ) async {
    if (userModel.admin == true) return;
    final shouldBeAdmin = AppConfig.isAdminRole(userModel) ||
        AppConfig.isMasterAdminFirebaseUid(uid);
    if (!shouldBeAdmin) return;
    if (rawData != null && rawData['admin'] == true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'admin': true},
        SetOptions(merge: true),
      );
      debugLog('👤 UserService: admin=true in Firestore gesetzt für $uid');
    } catch (e) {
      debugLog('👤 UserService: admin-Sync fehlgeschlagen: $e');
    }
  }

  Future<void> _handleUserDocumentSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String uid, {
    bool syncLocale = true,
  }) async {
    userDocSnapshotReadyNotifier.value = true;
    final userModel = doc.exists ? UserModel.fromFirestore(doc) : null;
    _setRootUserAndEmit(userModel);
    if (userModel != null) {
      PdfDisplayOptionsService.cacheFromUserModel(userModel);
      if (syncLocale) {
        await LocaleHelper.syncLocaleFromUserProfile(userModel);
      }
      unawaited(_ensureDevicePrefsForUid(uid));
      unawaited(_syncFirestoreAdminFlagIfNeeded(uid, userModel, doc.data()));
    }
    debugLog(
      '👤 UserService: currentUser gesetzt (exists=${doc.exists})',
    );
    debugLog(
      '🔐 User-Dokument: admin-Feld = ${userModel?.admin == true}',
    );
    if (userModel == null) {
      DjProSessionService.instance.clear();
      return;
    }
    final historyEntries = await _loadPaymentHistoryEntriesOrEmpty(uid);
    _updateSessionFromCheck(userModel, historyEntries);
    unawaited(_reconcileTrialAfterUserLoad(userModel));
  }

  /// Trial-/Downgrade: lokales Root-Modell anpassen und mit Geräte-Prefs mergen.
  void _emitPatchedRootUser(UserModel patchedRoot) {
    _userModelFromRootDoc = patchedRoot;
    _emitMergedFromCaches();
  }

  /// Session-basierter Pro-Status — delegiert an [DjProSessionService] (eine Quelle).
  ValueNotifier<SessionProStatus?> get sessionProStatus =>
      DjProSessionService.instance.sessionProStatus;

  /// Gesetzt mit `trialUntil.millisecondsSinceEpoch`, wenn die Probezeit endet (Dialog einmalig).
  final ValueNotifier<int?> trialExpiryPromptNotifier =
      ValueNotifier<int?>(null);

  /// True nach dem ersten `users/{uid}`-Snapshot der aktuellen Session (Vergleich mit [AppConfig]-Rollen-IDs).
  final ValueNotifier<bool> userDocSnapshotReadyNotifier =
      ValueNotifier<bool>(false);

  /// Kurzform: Firestore-User-Dokument mindestens einmal eingetroffen — Rollen-Logout darf laufen.
  bool get isReady => userDocSnapshotReadyNotifier.value;

  Timer? _trialLocalTimer;
  String? _trialExpiryBusyUid;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  UserModel? _userModelFromRootDoc;
  Map<String, dynamic>? _devicePrefsData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _devicePrefsSub;
  String? _devicePrefsStreamUid;
  String? _devicePrefsStreamInstallId;

  String? _docListeningUid;

  /// Pro UID nur ein Log, wenn [users/uid/history] nicht lesbar ist (verhindert Log-Spam).
  String? _paymentHistoryDeniedLoggedForUid;
  bool _userDocSnapshotDeniedLogged = false;
  bool _forceRefreshSnapshotDeniedLogged = false;

  static bool _isPermissionDeniedFirestore(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('permission-denied') ||
        s.contains('permission_denied') ||
        s.contains('permission denied');
  }

  /// Zahlungs-/Pro-Historie unter [users/{uid}/history]. Bei Rules-Verweigerung: leere Liste, kein Throw.
  Future<List<Map<String, dynamic>>> _loadPaymentHistoryEntriesOrEmpty(
    String uid,
  ) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final historySnap = await userRef
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      return historySnap.docs.map((d) => d.data()).toList();
    } catch (e) {
      if (_isPermissionDeniedFirestore(e)) {
        if (_paymentHistoryDeniedLoggedForUid != uid) {
          _paymentHistoryDeniedLoggedForUid = uid;
          debugLog(
            '👤 UserService: users/$uid/history Lesen nicht erlaubt — Pro-Status ohne History (ein Log pro UID).',
          );
        }
        return [];
      }
      debugLog('👤 UserService: history Zusatzladen: $e');
      return [];
    }
  }

  /// Startet den Echtzeit-Stream: Auth-State → users/{uid}.snapshots() → [currentUser].
  /// In [main] bzw. nach App-Start einmal aufrufen. Bei Logout [stopUserStream] aufrufen.
  void startUserStream() {
    _authSub?.cancel();
    _docSub?.cancel();
    debugLog(
      '👤 UserService: startUserStream() – registriere authStateChanges',
    );
    _authSub = authStateChangesDistinctByUid().listen((User? user) {
      debugLog(
        '👤 UserService: authStateChanges (distinct UID)',
      );
      if (user == null) {
        _docSub?.cancel();
        _docSub = null;
        _docListeningUid = null;
        userDocSnapshotReadyNotifier.value = false;
        _cancelTrialLocalTimer();
        _setRootUserAndEmit(null);
        DjProSessionService.instance.clear();
        debugLog('👤 UserService: user null – currentUser zurückgesetzt');
        return;
      }
      // Gleiche UID + aktiver Doc-Stream: kein Cancel/Re-Subscribe (sonst Snapshot-Sturm + UI-Churn).
      if (_docListeningUid == user.uid && _docSub != null) {
        debugLog(
          '👤 UserService: gleiche UID, Doc-Stream bleibt aktiv',
        );
        return;
      }
      _docSub?.cancel();
      if (_docListeningUid != user.uid) {
        _paymentHistoryDeniedLoggedForUid = null;
        _userDocSnapshotDeniedLogged = false;
      }
      _docListeningUid = user.uid;
      userDocSnapshotReadyNotifier.value = false;
      unawaited(DeviceBlockFusionService.applyIfNeeded(user));
      debugLog(
        '👤 UserService: starte Firestore-Snapshot',
      );
      _docSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (DocumentSnapshot<Map<String, dynamic>> doc) async {
              await _handleUserDocumentSnapshot(doc, user.uid, syncLocale: true);
            },
            onError: (Object e, StackTrace st) {
              if (_isPermissionDeniedFirestore(e)) {
                if (!_userDocSnapshotDeniedLogged) {
                  _userDocSnapshotDeniedLogged = true;
                  debugLog(
                    '👤 UserService: users/{uid} Snapshot permission-denied (einmal): $e',
                  );
                }
                if (FirebaseAuth.instance.currentUser == null) {
                  _setRootUserAndEmit(null);
                }
                return;
              }
              debugLog('👤 UserService: Snapshot-Fehler users: $e');
            },
          );
      // Einmalig aus User-Dokument + Historie initialisieren (sichere Quellen)
      refreshSessionProStatus(user.uid);
    });
    debugLog('👤 UserService: Zentraler User-Stream gestartet');
  }

  /// Stoppt nur den Dokument-Stream und setzt [currentUser] und [sessionProStatus] auf null.
  /// Der Auth-Listener (_authSub) bleibt aktiv, damit bei neuem Login automatisch
  /// ein neuer Firestore-Snapshot-Listener für die neue UID erzeugt wird.
  void stopUserStream() {
    _cancelTrialLocalTimer();
    _docSub?.cancel();
    _docSub = null;
    _docListeningUid = null;
    userDocSnapshotReadyNotifier.value = false;
    _setRootUserAndEmit(null);
    DjProSessionService.instance.clear();
    debugLog(
      '👤 UserService: User-Stream beendet (Auth-Listener bleibt aktiv)',
    );
  }

  /// Erzwingt einen frischen Firestore-Snapshot-Listener für den aktuellen Auth-User.
  /// Nach neuem Login (neue UID) aufrufen, damit [currentUser] zuverlässig befüllt wird.
  void forceRefresh() {
    final user = FirebaseAuth.instance.currentUser;
    debugLog(
      '👤 UserService: forceRefresh()',
    );
    _docSub?.cancel();
    _docSub = null;
    if (user == null) {
      _docListeningUid = null;
      userDocSnapshotReadyNotifier.value = false;
      _setRootUserAndEmit(null);
      DjProSessionService.instance.clear();
      debugLog(
        '👤 UserService: forceRefresh – kein User, currentUser auf null',
      );
      return;
    }
    _forceRefreshSnapshotDeniedLogged = false;
    _docListeningUid = user.uid;
    debugLog(
      '👤 UserService: forceRefresh – starte Snapshot-Listener',
    );
    userDocSnapshotReadyNotifier.value = false;
    _docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (DocumentSnapshot<Map<String, dynamic>> doc) async {
            await _handleUserDocumentSnapshot(
              doc,
              user.uid,
              syncLocale: false,
            );
          },
          onError: (Object e, StackTrace st) {
            if (_isPermissionDeniedFirestore(e)) {
              if (!_forceRefreshSnapshotDeniedLogged) {
                _forceRefreshSnapshotDeniedLogged = true;
                debugLog(
                  '👤 UserService: forceRefresh users-Snapshot permission-denied (einmal): $e',
                );
              }
              if (FirebaseAuth.instance.currentUser == null) {
                _setRootUserAndEmit(null);
              }
              return;
            }
            debugLog('👤 UserService: forceRefresh Snapshot-Fehler users: $e');
          },
        );
    debugLog(
      '👤 UserService: forceRefresh – neuer Snapshot-Listener aktiv',
    );
  }

  /// Initialisiert [sessionProStatus] aus User-Dokument + Zahlungshistorie (sichere Quellen).
  /// Wird beim Login/App-Start und nach Kauf aufgerufen. Nutzt dieselbe Kette Life -> History -> Kulanz.
  Future<void> refreshSessionProStatus(String uid) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        DjProSessionService.instance.clear();
        return;
      }
      final userModel = UserModel.fromFirestore(userDoc);
      final historyEntries = await _loadPaymentHistoryEntriesOrEmpty(uid);
      _updateSessionFromCheck(userModel, historyEntries);
      unawaited(_reconcileTrialAfterUserLoad(userModel));
    } catch (e) {
      debugLog('👤 UserService: refreshSessionProStatus fehlgeschlagen: $e');
    }
  }

  void _cancelTrialLocalTimer() {
    _trialLocalTimer?.cancel();
    _trialLocalTimer = null;
  }

  /// Lokaler 60s-Check auf `trialUntil` (kein periodisches Firestore-Polling).
  void _scheduleTrialLocalWatch(UserModel user) {
    _cancelTrialLocalTimer();
    if (user.planType != 'trial' || user.trialUntil == null) return;
    final end = user.trialUntil!.toDate();
    if (!end.isAfter(DateTime.now())) return;

    void runCheck() {
      final cur = currentUser.value;
      if (cur == null || cur.id != user.id || cur.planType != 'trial') {
        _cancelTrialLocalTimer();
        return;
      }
      final curEnd = cur.trialUntil?.toDate();
      if (curEnd == null || !curEnd.isAfter(DateTime.now())) {
        _cancelTrialLocalTimer();
        unawaited(_applyLocalTrialExpired(cur));
      }
    }

    runCheck();
    _trialLocalTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      runCheck();
    });
  }

  Future<void> _reconcileTrialAfterUserLoad(UserModel user) async {
    if (user.planType != 'trial' || user.trialUntil == null) {
      _cancelTrialLocalTimer();
      return;
    }
    final end = user.trialUntil!.toDate();
    if (!end.isAfter(DateTime.now())) {
      await _applyLocalTrialExpired(user);
      return;
    }
    _scheduleTrialLocalWatch(user);
  }

  /// Sofort Free in UI + Firestore; triggert [trialExpiryPromptNotifier] für einmaligen Dialog.
  Future<void> _applyLocalTrialExpired(UserModel user) async {
    if (user.planType != 'trial' || user.trialUntil == null) return;
    if (_trialExpiryBusyUid == user.id) return;
    _trialExpiryBusyUid = user.id;
    try {
      final endMs = user.trialUntil!.millisecondsSinceEpoch;
      final patched = user.copyWith(planType: 'free', isPro: false);
      _emitPatchedRootUser(patched);
      _updateSessionFromCheck(patched, const []);
      ProFeatureGuard.invalidateCache();
      trialExpiryPromptNotifier.value = endMs;
      await TrialExpiryService.applyExpiredTrialDowngrade(user.id);
      await ShazamService().onDowngradedToFreeTier();
    } finally {
      _trialExpiryBusyUid = null;
    }
  }

  void _updateSessionFromCheck(
    UserModel user,
    List<Map<String, dynamic>> history,
  ) {
    DjProSessionService.instance.applyFromUser(user, history);
  }

  /// Gecachtes DJ-Logo als Bytes
  static Uint8List? cachedDjLogo;

  /// Lädt das DJ-Logo vor und speichert es im Cache.
  Future<void> preloadDjLogo(String? url) async {
    if (url == null || url.trim().isEmpty) {
      cachedDjLogo = null;
      debugLog('ℹ️ UserService: Logo-Cache geleert (URL leer)');
      return;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        cachedDjLogo = response.bodyBytes;
        debugLog(
          '✅ UserService: Logo gecacht (${response.bodyBytes.length} bytes)',
        );
      } else {
        cachedDjLogo = null;
      }
    } catch (e) {
      cachedDjLogo = null;
      debugLog('❌ UserService: Logo-Preload fehlgeschlagen: $e');
    }
  }

  /// Leert den Cache (z. B. bei Logout). Stoppt den User-Stream nicht – [stopUserStream] separat aufrufen.
  void clearCache() {
    cachedDjLogo = null;
    debugLog('ℹ️ UserService: Cache geleert');
  }

  /// Expliziter Logout (nur Nutzeraktionen, z. B. [deactivateAccount]).
  /// Keine automatischen Aufrufe aus Fehlerpfaden — Drawer nutzt direkt [FirebaseAuth.instance.signOut].
  Future<void> signOut() async {
    // Auth zuerst: sonst kann MainPage/_onUserModelChanged bei user!=null && userModel==null
    // vorzeitig returnen und DJ-Ansicht „kleben“ bleiben.
    await FirebaseAuth.instance.signOut();
    stopUserStream();
    clearCache();
  }

  /// Deaktiviert den Account: setzt status='inaktiv' und deactivated_at in Firestore,
  /// löscht den Auth-User (damit die E-Mail für Neuregistrierung frei wird), dann Logout.
  /// Muss nur vom eigentlichen User aufgerufen werden (nach Re-Auth).
  Future<void> deactivateAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update(
          _sanitizeWriteMap({
            'status': 'inaktiv',
            'deactivated_at': FieldValue.serverTimestamp(),
          }),
        );
    // Auth-User löschen als letzten Schritt vor signOut, damit die E-Mail sofort für Neuregistrierung frei ist
    await user.delete();
    await signOut();
  }

  /// Logo aus Firestore nachladen (z. B. nach Auto-Login).
  static Future<void> ensureDjLogoCached() async {
    if (cachedDjLogo != null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final url = data?['djLogoUrl'] ?? data?['dj_logo_url'];
      if (url != null && url is String && url.isNotEmpty) {
        await UserService().preloadDjLogo(url);
      }
    } catch (e) {
      debugLog('UserService ensureDjLogoCached: $e');
    }
  }
}

/// Stellt [UserService().currentUser] im Widget-Baum bereit.
/// Abhängige Widgets bauen bei jedem [ValueNotifier]-Update neu auf – daher in großen Shells
/// [ValueListenableBuilder] / direkten [UserService]-Zugriff bevorzugen, nicht flächig [userOf].
class UserScope extends InheritedNotifier<ValueNotifier<UserModel?>> {
  const UserScope({super.key, required super.notifier, required super.child});

  static ValueNotifier<UserModel?>? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UserScope>()?.notifier;
  }

  /// Aktuelles User-Modell. **Triggert Rebuild** bei jedem Stream-Update – nur in kleinen Teilbäumen nutzen.
  static UserModel? userOf(BuildContext context) {
    return of(context)?.value;
  }
}
