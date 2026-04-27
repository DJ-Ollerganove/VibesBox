import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../helpers/security_helper.dart';
import 'pro_free_check.dart';
import 'pro_feature_guard.dart';
import 'shazam_service.dart';
import 'trial_expiry_service.dart';
import '../l10n/locale_helper.dart';
import '../models/user_model.dart';
import '../utils/auth_stream_utils.dart';
import 'device_block_fusion_service.dart';
import 'pdf_display_options_service.dart';
import '../utils/debug_log.dart';

/// Session-basierter Pro-Status: Wird aus User-Dokument + Zahlungshistorie initialisiert.
/// Widgets lesen primär diese Session, nicht direkt das UserModel.
class SessionProStatus {
  final bool isActive;
  final DateTime? proUntil;
  final bool isLifetime;
  final ProFreeStatus status;

  const SessionProStatus({
    required this.isActive,
    this.proUntil,
    this.isLifetime = false,
    required this.status,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionProStatus &&
        isActive == other.isActive &&
        proUntil == other.proUntil &&
        isLifetime == other.isLifetime &&
        status == other.status;
  }

  @override
  int get hashCode => Object.hash(isActive, proUntil, isLifetime, status);

  static SessionProStatus? fromUserModel(UserModel? user) {
    if (user == null) return null;
    final result = ProFreeCheck.determineStatus(user: user, historyEntries: []);
    return SessionProStatus(
      isActive: result.isActive,
      proUntil: result.displayDate,
      isLifetime: result.status == ProFreeStatus.PRO_LIFE,
      status: result.status,
    );
  }
}

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

  void _emitCurrentUser(UserModel? value) {
    if (currentUser.value == value) {
      return;
    }
    currentUser.value = value;
    _userStreamController?.add(value);
  }

  /// Session-basierter Pro-Status: Widgets nutzen primär diese Quelle.
  /// Initialisiert aus User-Dokument + Zahlungshistorie (sichere Quellen).
  final ValueNotifier<SessionProStatus?> sessionProStatus =
      ValueNotifier<SessionProStatus?>(null);

  /// Gesetzt mit `trialUntil.millisecondsSinceEpoch`, wenn die Probezeit endet (Dialog einmalig).
  final ValueNotifier<int?> trialExpiryPromptNotifier =
      ValueNotifier<int?>(null);

  Timer? _trialLocalTimer;
  String? _trialExpiryBusyUid;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _docSub;

  /// UID, für die [_docSub] aktiv ist – verhindert Neustart bei jedem authStateChanges-Tick (Token-Refresh).
  String? _docListeningUid;

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
        _cancelTrialLocalTimer();
        _emitCurrentUser(null);
        sessionProStatus.value = null;
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
      _docListeningUid = user.uid;
      unawaited(DeviceBlockFusionService.applyIfNeeded(user));
      debugLog(
        '👤 UserService: starte Firestore-Snapshot',
      );
      _docSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (DocumentSnapshot doc) async {
              final userModel = doc.exists
                  ? UserModel.fromFirestore(doc)
                  : null;
              _emitCurrentUser(userModel);
              if (userModel != null) {
                PdfDisplayOptionsService.cacheFromUserModel(userModel);
                await LocaleHelper.syncLocaleFromUserProfile(userModel);
              }
              debugLog(
                '👤 UserService: currentUser gesetzt (exists=${doc.exists})',
              );
              // Beweis-Log für Rules-Abgleich: exakter Pfad und Feld wie in firestore.rules isAdmin()
              debugLog(
                '🔐 User-Dokument: admin-Feld = ${userModel?.admin == true}',
              );
              if (userModel == null) {
                sessionProStatus.value = null;
                return;
              }
              final userRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid);
              final historySnap = await userRef
                  .collection('history')
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .get();
              final historyEntries = historySnap.docs
                  .map((d) => d.data())
                  .toList();
              _updateSessionFromCheck(userModel, historyEntries);
              unawaited(_reconcileTrialAfterUserLoad(userModel));
            },
            onError: (Object e, StackTrace st) {
              debugLog(
                '👤 UserService: Snapshot-Fehler users: $e',
              );
              if (e.toString().contains('PERMISSION_DENIED')) {
                debugLog(
                  '👤 UserService: Permission denied auf users-Doc – currentUser wird auf null gesetzt.',
                );
                _emitCurrentUser(null);
              }
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
    _emitCurrentUser(null);
    sessionProStatus.value = null;
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
      _emitCurrentUser(null);
      sessionProStatus.value = null;
      debugLog(
        '👤 UserService: forceRefresh – kein User, currentUser auf null',
      );
      return;
    }
    _docListeningUid = user.uid;
    debugLog(
      '👤 UserService: forceRefresh – starte Snapshot-Listener',
    );
    _docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (DocumentSnapshot doc) async {
            final userModel = doc.exists ? UserModel.fromFirestore(doc) : null;
            _emitCurrentUser(userModel);
            if (userModel != null) {
              PdfDisplayOptionsService.cacheFromUserModel(userModel);
            }
            debugLog(
              '👤 UserService: forceRefresh – currentUser gesetzt (exists=${doc.exists})',
            );
            debugLog(
              '🔐 User-Dokument: admin-Feld = ${userModel?.admin == true}',
            );
            if (userModel == null) {
              sessionProStatus.value = null;
              return;
            }
            final userRef = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid);
            final historySnap = await userRef
                .collection('history')
                .orderBy('timestamp', descending: true)
                .limit(10)
                .get();
            final historyEntries = historySnap.docs
                .map((d) => d.data())
                .toList();
            _updateSessionFromCheck(userModel, historyEntries);
            unawaited(_reconcileTrialAfterUserLoad(userModel));
          },
          onError: (Object e, StackTrace st) {
            debugLog(
              '👤 UserService: forceRefresh Snapshot-Fehler users: $e',
            );
            if (e.toString().contains('PERMISSION_DENIED')) {
              debugLog(
                '👤 UserService: Permission denied bei forceRefresh.',
              );
              _emitCurrentUser(null);
            }
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
        sessionProStatus.value = null;
        return;
      }
      final userModel = UserModel.fromFirestore(userDoc);
      final historySnap = await userRef
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      final historyEntries = historySnap.docs.map((d) => d.data()).toList();
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
      _emitCurrentUser(patched);
      _updateSessionFromCheck(patched, const []);
      ProFeatureGuard.invalidateCache();
      trialExpiryPromptNotifier.value = endMs;
      await TrialExpiryService.applyExpiredTrialDowngrade(user.id);
      await ShazamService().onDowngradedToFreeTier();
    } finally {
      _trialExpiryBusyUid = null;
    }
  }

  /// Aktualisiert [sessionProStatus] über ProFreeCheck (Life -> History -> Kulanz).
  /// Wird später von den Listenern aufgerufen, statt direkt aus dem User-Dokument zu pushen.
  void _updateSessionFromCheck(
    UserModel user,
    List<Map<String, dynamic>> history,
  ) {
    final result = ProFreeCheck.determineStatus(
      user: user,
      historyEntries: history,
    );
    final next = SessionProStatus(
      isActive: result.isActive,
      proUntil: result.displayDate,
      isLifetime: result.status == ProFreeStatus.PRO_LIFE,
      status: result.status,
    );
    if (sessionProStatus.value == next) return;
    sessionProStatus.value = next;
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

  /// Logout: Stream stoppen, Cache leeren, Firebase Auth abmelden.
  Future<void> signOut() async {
    stopUserStream();
    clearCache();
    await FirebaseAuth.instance.signOut();
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
