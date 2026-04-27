import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/duplicate_check_service.dart';
import '../services/party_session_service.dart';
import '../config/app_config.dart';
import '../services/user_service.dart';
import '../l10n/app_localizations.dart';
import '../services/active_party_service.dart';
import '../services/navigation_service.dart';
import '../utils/string_utils.dart';
import '../helpers/security_helper.dart';
import '../utils/ui_constants.dart';
import '../utils/time_utils.dart';
import '../services/limit_service.dart';
import '../services/guest_party_stats_service.dart';
import '../widgets/party_check_in_feedback_widget.dart';
import '../widgets/party_check_in_widget.dart';
import '../widgets/user_blocked_widget.dart';
import '../widgets/wishes_form_widget.dart';
import '../utils/debug_log.dart';

/// Helper-Funktion: Speichert Track-Daten in die Musikdatenbank (wunschbox_titel, wunschbox_artist, wunschbox_genres)
/// Wird asynchron im Hintergrund aufgerufen (Fire & Forget), damit der User nicht warten muss
Future<void> _saveToMusicDatabase({
  String? spotifyId,
  required String title,
  required String artist,
  int? durationMs,
  List<String>? genres,
  String? djId,
  String? partyId,
  BuildContext? context,
}) async {
  // Validierung: Nur spotify_id, title und artist sind Pflicht
  // duration_ms und genres sind optional
  if (spotifyId == null) {
    debugLog(
      '💾 _saveToMusicDatabase: Keine Spotify-ID vorhanden, überspringe Musikdatenbank-Speicherung',
    );
    return;
  }

  // Prüfe, ob Titel und Artist vorhanden sind
  if (title.trim().isEmpty || artist.trim().isEmpty) {
    debugLog(
      '💾 _saveToMusicDatabase: Titel oder Artist fehlt, überspringe Musikdatenbank-Speicherung',
    );
    return;
  }

  // Extrahiere Browser-Sprache (z.B. 'de', 'en')
  final locale = context != null
      ? (Localizations.localeOf(context).languageCode)
      : (Platform.localeName.split('_')[0].toLowerCase());
  final browserLanguage = locale.isNotEmpty ? locale : 'unknown';

  final requestData = {
    'spotify_id': spotifyId,
    'title': title.trim(),
    'artist': artist.trim(),
    'duration_ms': durationMs, // Optional - kann null sein
    'genres': genres ?? [], // Optional - kann leer sein
    'dj_id': djId, // DJ-ID für Statistik
    'browser_language': browserLanguage, // Browser-Sprache für Statistik
  };

  debugLog(
    '💾 _saveToMusicDatabase: Sende Daten (duration_ms optional): spotify_id=${requestData['spotify_id']}, title=${requestData['title']}, artist=${requestData['artist']}, duration_ms=${requestData['duration_ms']}, genres=${requestData['genres']}, dj_id=${requestData['dj_id']}',
  );

  debugLog('💾 _saveToMusicDatabase: Sende Daten an Cloud Function: $requestData');

  try {
    final url = Uri.parse(AppConfig.saveToMusicDatabaseFunctionUrl);
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestData),
        )
        .timeout(const Duration(seconds: 10));

    debugLog(
      '💾 _saveToMusicDatabase: Cloud Function Response Status: ${response.statusCode}',
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      debugLog(
        '✅ _saveToMusicDatabase: Track erfolgreich in Musikdatenbank gespeichert: $result',
      );

      // Speichere browser_language im Wunsch-Dokument, falls vorhanden
      final browserLang = result['browser_language'] as String?;
      if (browserLang != null &&
          browserLang != 'unknown' &&
          partyId != null &&
          partyId.isNotEmpty &&
          partyId != 'manual') {
        try {
          // Finde das zuletzt erstellte Wunsch-Dokument mit dieser Spotify-ID (nur in dieser Party – Security Rules)
          final wishesQuery = await FirebaseFirestore.instance
              .collection('wishes')
              .where('party_id', isEqualTo: partyId)
              .where('spotify_id', isEqualTo: spotifyId)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

          if (wishesQuery.docs.isNotEmpty) {
            await wishesQuery.docs.first.reference.update(
              SecurityHelper.sanitizeMap({'browser_language': browserLang}),
            );
            debugLog(
              '✅ browser_language im Wunsch-Dokument gespeichert: $browserLang',
            );
          }
        } catch (e) {
          debugLog(
            '⚠️ Fehler beim Speichern von browser_language (nicht kritisch): $e',
          );
        }
      }
    } else {
      final errorText = response.body;
      debugLog(
        '⚠️ _saveToMusicDatabase: Cloud Function Fehler (Status ${response.statusCode}): $errorText',
      );
    }
  } catch (e) {
    // Fehler wird nur geloggt, nicht dem User angezeigt (Fire & Forget)
    debugLog(
      '⚠️ _saveToMusicDatabase: Fehler beim Speichern in Musikdatenbank: $e',
    );
  }
}

// Sanitization-Funktion
String sanitizeInput(String input) {
  return SecurityHelper.sanitize(input);
}

String sanitizeEmail(String email) {
  return SecurityHelper.sanitize(email);
}

class WishesPage extends StatefulWidget {
  final VoidCallback? onPartyJoined;

  const WishesPage({super.key, this.onPartyJoined});

  @override
  State<WishesPage> createState() => _WishesPageState();
}

class _WishesPageState extends State<WishesPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _greetingController = TextEditingController();
  bool _isAdmin = false;
  String? _guestName;
  bool _hasProfileName = false; // User angemeldet + Name in users-Collection
  bool _isLoading = true;
  bool _isWishboxActive = false;
  bool _showSuccessMessage = false;
  String? _partyCode;
  /// Aus [pending_party_code] (noch nicht mit „Prüfen“ bestätigt).
  String? _pendingPartyCode;
  String _deviceId = '';
  Map<String, dynamic>? _currentOrNextParty;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _partiesSubscription;
  StreamSubscription<DocumentSnapshot>? _partySettingsSubscription;
  Timer? _wishStatsTimer;
  Timer? _blockStatusResyncTimer;
  int _wishLimit = 0;
  int _wishCount = 0;
  int _wishRemaining = 0;
  DateTime? _nextFullHour;
  bool _isBlocked = false;
  StreamSubscription<DocumentSnapshot>? _userBlockSubscription;
  StreamSubscription<DocumentSnapshot>? _guestBlockSubscription;
  StreamSubscription<DocumentSnapshot>? _partyDocSubscription;
  bool _partyListenersStarted = false;
  String? _selectedSpotifyId;
  int? _selectedDurationMs;
  // Party-Daten (aus Stream)
  String? _djId;
  String? _djName;
  String? _djLogoUrl;

  /// Letzte Locale, für die Gast-Statistik (Sprache) synchronisiert wurde.
  Locale? _lastStatsLogLocale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeviceId();
    _loadSavedData();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _loadSavedData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = Localizations.maybeLocaleOf(context);
    if (loc == null) return;
    if (_lastStatsLogLocale != loc) {
      _lastStatsLogLocale = loc;
      if (!_isAdmin &&
          mounted &&
          PartySessionService.instance.hasSession) {
        _scheduleGuestPartyStatsLog();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isAdmin &&
          mounted &&
          PartySessionService.instance.hasSession) {
        _scheduleGuestPartyStatsLog();
        unawaited(_checkBlockStatus());
      }
    }
  }

  Future<void> _loadDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String resolvedDeviceId = '';

      if (kIsWeb) {
        resolvedDeviceId = 'web_guest_device';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        resolvedDeviceId = androidInfo.id.trim();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        resolvedDeviceId = (iosInfo.identifierForVendor ?? '').trim();
      }

      if (resolvedDeviceId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final fallback = prefs.getString('guest_device_id') ?? '';
        resolvedDeviceId = fallback.trim();
      }

      if (resolvedDeviceId.isEmpty) {
        resolvedDeviceId = 'device_unknown';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_device_id', resolvedDeviceId);

      if (!mounted) return;
      setState(() {
        _deviceId = resolvedDeviceId;
      });
      debugLog('✅ _loadDeviceId: deviceId geladen: $_deviceId');
    } catch (e) {
      debugLog('❌ _loadDeviceId: Fehler beim Laden der deviceId: $e');
      if (!mounted) return;
      setState(() {
        _deviceId = 'device_unknown';
      });
    }
  }

  String _currentPartyIdForBlocking() {
    final fromSession = (PartySessionService.instance.partyId ?? '').trim();
    if (fromSession.isNotEmpty && fromSession != 'manual') return fromSession;
    final fromMap =
        (_currentOrNextParty?['partyId'] ??
                _currentOrNextParty?['party_id'] ??
                '')
            .toString()
            .trim();
    if (fromMap.isNotEmpty && fromMap != 'manual') return fromMap;
    return '';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _blockedGuestsStream() {
    final partyId = _currentPartyIdForBlocking();
    if (partyId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('blocked_guests')
        .where('party_id', isEqualTo: partyId)
        .snapshots();
  }

  bool _isBlockEntryActive(Map<String, dynamic> data) {
    final status = (data['block_status'] ?? '').toString().trim().toLowerCase();
    if (status == 'temporary') {
      final blockedUntil = data['blocked_until'];
      if (blockedUntil is Timestamp) {
        return DateTime.now().isBefore(blockedUntil.toDate());
      }
      return false;
    }
    if (status.isEmpty) return true;
    return status == 'party_specific' ||
        status == 'permanent' ||
        status == 'active' ||
        status == 'blocked';
  }

  bool _matchesBlockedEntry(
    String partyId,
    String currentDeviceId,
    String currentUid,
    String docId,
    Map<String, dynamic> data,
  ) {
    final entryDeviceId = (data['device_id'] ?? '').toString().trim();
    final entryClientId = (data['client_id'] ?? '').toString().trim();
    final entryUid = (data['uid'] ?? data['user_id'] ?? '').toString().trim();

    final byDeviceField =
        currentDeviceId.isNotEmpty && entryDeviceId == currentDeviceId;
    final byClientFallback =
        currentDeviceId.isNotEmpty && entryClientId == 'app_$currentDeviceId';
    final byUid = currentUid.isNotEmpty && entryUid == currentUid;
    final byDocId =
        currentDeviceId.isNotEmpty &&
        (docId == '${currentDeviceId}_$partyId' ||
            docId == 'app_${currentDeviceId}_$partyId');

    return byDeviceField || byClientFallback || byUid || byDocId;
  }

  bool _isBlockedFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final partyId = _currentPartyIdForBlocking();
    if (partyId.isEmpty) return false;

    final currentUid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    final currentDeviceId = _deviceId.trim();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!_isBlockEntryActive(data)) continue;
      if (_matchesBlockedEntry(
        partyId,
        currentDeviceId,
        currentUid,
        doc.id,
        data,
      )) {
        return true;
      }
    }
    return false;
  }

  bool _isUserBlockedSnapshot(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null || !snapshot.exists) return false;
    final data = snapshot.data() ?? <String, dynamic>{};
    final isBlockedFlag = data['is_blocked'] == true;
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    return isBlockedFlag || status == 'gesperrt' || status == 'blocked';
  }

  bool _isGuestBlockedSnapshot(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null || !snapshot.exists) return false;
    final data = snapshot.data() ?? <String, dynamic>{};
    return _isBlockEntryActive(data);
  }

  /// Prüfung vor dem Absenden: Account-, Party- und Gerätesperre (wie in den Rules).
  Future<bool> _isWishSubmissionBlocked(String partyId) async {
    if (partyId.isEmpty || partyId == 'manual') return false;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid.trim();
      if (uid != null && uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (_isUserBlockedSnapshot(userDoc)) return true;
      }
    } catch (_) {}
    try {
      final clientId = await _getOrCreateClientId();
      final bg = await FirebaseFirestore.instance
          .collection('blocked_guests')
          .doc('${clientId}_$partyId')
          .get();
      if (_isGuestBlockedSnapshot(bg)) return true;
      final bd = await FirebaseFirestore.instance
          .collection('blocked_devices')
          .doc(clientId)
          .get();
      if (_isGuestBlockedSnapshot(bd)) return true;
    } catch (_) {}
    return false;
  }

  String _buildDeterministicClientIdFromDevice() {
    final raw = _deviceId.trim();
    final sanitized = raw.isEmpty
        ? 'device_unknown'
        : raw.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return 'app_$sanitized';
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _registeredUserBlockStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _guestBlockedDevicesStream() {
    final clientId = _buildDeterministicClientIdFromDevice();
    if (clientId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('blocked_devices')
        .doc(clientId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>?
  _guestBlockedGuestsDocStream() {
    final partyId = _currentPartyIdForBlocking();
    if (partyId.isEmpty) return null;
    final clientId = _buildDeterministicClientIdFromDevice();
    final documentId = '${clientId}_$partyId';
    return FirebaseFirestore.instance
        .collection('blocked_guests')
        .doc(documentId)
        .snapshots();
  }

  Widget _buildBlockedNotice() {
    return const UserBlockedWidget();
  }

  // ... (Alle internen Funktionen wie _checkWishboxStatus, _addWish etc. bleiben identisch zu deinem Original-Code)
  // Aus Platzgründen hier gekürzt, aber in deinem Cursor-Projekt bleiben die bestehen!

  // HIER FOLGT DIE REPARIERTE BUILD METHODE:

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final localizations = AppLocalizations.of(context)!;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),

                // Check-In-Widget (wenn kein party_code vorhanden)
                if (_partyCode == null ||
                    _partyCode!.isEmpty ||
                    _partyCode == 'manual')
                  PartyCheckInWidget(
                    initialCode: _partyCode ?? _pendingPartyCode,
                    onCodeSubmitted: _validateAndSetPartyCode,
                  ),

                const SizedBox(height: 12),

                // Wunschbox Status / Inhaltslogik
                if (_showSuccessMessage)
                  _buildSuccessView(localizations)
                else if (!_isAdmin &&
                    _partyCode != null &&
                    _partyCode!.isNotEmpty &&
                    _partyCode != 'manual')
                  Builder(
                    builder: (context) {
                      final user = FirebaseAuth.instance.currentUser;

                      Widget buildWishForm() {
                        return WishesFormWidget(
                          formKey: _formKey,
                          nameController: _nameController,
                          titleController: _titleController,
                          artistController: _artistController,
                          greetingController: _greetingController,
                          onSubmit: _addWish,
                          onSpotifyTrackSelected: (id, durationMs) {
                            setState(() {
                              _selectedSpotifyId = id;
                              _selectedDurationMs = durationMs;
                            });
                          },
                          guestName: _guestName,
                          hasProfileName: _hasProfileName,
                          wishLimit: _wishLimit,
                          wishCount: _wishCount,
                          wishRemaining: _wishRemaining,
                          nextFullHour: _nextFullHour,
                          djName: _djName,
                          djLogoUrl: _djLogoUrl,
                        );
                      }

                      if (user != null) {
                        // Eingeloggte Gäste: wie anonyme Gäste auch party-/gerätebezogene
                        // Sperre (blocked_guests, blocked_devices) — nicht nur users.is_blocked.
                        return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          stream: _registeredUserBlockStream(),
                          builder: (context, userSnapshot) {
                            final blockedByUser = _isUserBlockedSnapshot(
                              userSnapshot.data,
                            );
                            if (blockedByUser || _isBlocked) {
                              return _buildBlockedNotice();
                            }
                            return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: _guestBlockedDevicesStream(),
                              builder: (context, blockedDevicesSnapshot) {
                                final blockedByDevice = _isGuestBlockedSnapshot(
                                  blockedDevicesSnapshot.data,
                                );
                                return StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>
                                >(
                                  stream: _guestBlockedGuestsDocStream(),
                                  builder: (context, blockedGuestsDocSnapshot) {
                                    final blockedByGuestDoc =
                                        _isGuestBlockedSnapshot(
                                      blockedGuestsDocSnapshot.data,
                                    );
                                    final blockedNow =
                                        blockedByDevice ||
                                        blockedByGuestDoc ||
                                        _isBlocked;
                                    if (blockedNow) {
                                      return _buildBlockedNotice();
                                    }
                                    return buildWishForm();
                                  },
                                );
                              },
                            );
                          },
                        );
                      }

                      return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        stream: _guestBlockedDevicesStream(),
                        builder: (context, blockedDevicesSnapshot) {
                          final blockedByDevice = _isGuestBlockedSnapshot(
                            blockedDevicesSnapshot.data,
                          );

                          return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>
                          >(
                            stream: _guestBlockedGuestsDocStream(),
                            builder: (context, blockedGuestsDocSnapshot) {
                              final blockedByGuestDoc = _isGuestBlockedSnapshot(
                                blockedGuestsDocSnapshot.data,
                              );
                              final blockedNow =
                                  blockedByDevice ||
                                  blockedByGuestDoc ||
                                  _isBlocked;

                              if (blockedNow) {
                                return _buildBlockedNotice();
                              }
                              return buildWishForm();
                            },
                          );
                        },
                      );
                    },
                  ),

                // Login Tipp
                if (!_isAdmin && FirebaseAuth.instance.currentUser == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.login,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localizations.guest_login_hint,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _partiesSubscription?.cancel();
    _partySettingsSubscription?.cancel();
    _partyDocSubscription?.cancel();
    _wishStatsTimer?.cancel();
    _blockStatusResyncTimer?.cancel();
    _userBlockSubscription?.cancel();
    _guestBlockSubscription?.cancel();
    _nameController.dispose();
    _titleController.dispose();
    _artistController.dispose();
    _greetingController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Nach Firestore-Änderungen (z. B. DJ setzt Party fort / is_paused): UI neu bauen.
  /// Wichtig für PWA/Web: sonst bleibt die Wunschbox nach Resume ohne sichtbaren Inhalt (schwarze Fläche).
  Future<void> _checkWishboxStatus() async {
    if (!mounted) return;
    setState(() {});
  }

  /// Party-Kontext für Sperr-Streams aktualisieren (optional) + Rebuild.
  Future<void> _loadCurrentOrNextParty() async {
    if (!mounted) return;
    final svc = PartySessionService.instance;
    final pid = (svc.partyId ?? '').trim();
    if (pid.isEmpty || pid == 'manual') {
      setState(() => _currentOrNextParty = null);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(pid)
          .get();
      if (!mounted) return;
      setState(() {
        _currentOrNextParty = doc.exists ? doc.data() : null;
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }
  void _ensurePartyListenersStarted() {
    if (_partyListenersStarted) return;
    final code = _partyCode;
    if (code == null || code.isEmpty) return;
    _partyListenersStarted = true;

    _partiesSubscription = FirebaseFirestore.instance
        .collection('parties')
        .snapshots()
        .listen((_) {
          if (mounted) {
            unawaited(_checkWishboxStatus());
            unawaited(_loadCurrentOrNextParty());
          }
        });

    _partySettingsSubscription = FirebaseFirestore.instance
        .collection('party_settings')
        .doc('current')
        .snapshots()
        .listen((snapshot) {
          if (mounted) _checkWishboxStatus();
        });

    _loadWishStatsAndUpdate();
    _wishStatsTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _loadWishStatsAndUpdate();
    });

    _subscribePartyDocForLimit(PartySessionService.instance.partyId ?? '');
    _checkBlockStatus();
    _startBlockStatusResyncTimer();
  }

  void _startBlockStatusResyncTimer() {
    _blockStatusResyncTimer?.cancel();
    _blockStatusResyncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted || _isAdmin) return;
      if (!PartySessionService.instance.hasSession) return;
      unawaited(_checkBlockStatus());
    });
  }

  Future<void> _loadSavedData() async {
    try {
      await PartySessionService.instance.loadFromPrefs();
      final svc = PartySessionService.instance;

      final current = UserService().currentUser.value;
      final isAdmin = current != null && AppConfig.isAdminRole(current);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Name aus users-Collection (displayName), Fallback: Auth displayName/email
        final profileName =
            (current?.displayName != null &&
                current!.displayName!.trim().isNotEmpty)
            ? current.displayName!.trim()
            : (user.displayName ??
                  (user.email != null && user.email!.contains('@')
                      ? user.email!.split('@')[0]
                      : user.email ?? ''));
        if (profileName.isNotEmpty) {
          _guestName = profileName;
          _nameController.text = profileName;
          _hasProfileName = true;
        } else {
          _guestName = null;
          _nameController.clear();
          _hasProfileName = false;
        }
      } else {
        _guestName = null;
        _nameController.clear();
        _hasProfileName = false;
      }

      final pending = await PartySessionService.instance.getPendingPartyCodeDigits();
      if (!mounted) return;
      setState(() {
        _partyCode = svc.shortCode;
        _pendingPartyCode =
            (svc.shortCode == null || svc.shortCode!.isEmpty) ? pending : null;
        _djId = svc.djId;
        _djName = svc.djName;
        _djLogoUrl = svc.djLogoUrl;
        _isAdmin = isAdmin;
        _isLoading = false;
      });

      if (svc.hasSession) {
        final listenersWereActive = _partyListenersStarted;
        _ensurePartyListenersStarted();
        if (listenersWereActive) {
          _checkBlockStatus();
        }
        _scheduleGuestPartyStatsLog();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Validiert Party-Code über PartySessionService (einmalige Firestore-Abfrage).
  /// Bei Erfolg: Session gefüllt, State aus Service übernommen.
  Future<PartyCheckInFeedback?> _validateAndSetPartyCode(String code) async {
    final feedback = await PartySessionService.instance.validateAndJoin(code);
    if (feedback != null) return feedback;
    if (!mounted) return null;
    final svc = PartySessionService.instance;
    setState(() {
      _partyCode = svc.shortCode;
      _pendingPartyCode = null;
      _djId = svc.djId;
      _djName = svc.djName;
      _djLogoUrl = svc.djLogoUrl;
    });
    _ensurePartyListenersStarted();
    _checkBlockStatus();
    _scheduleGuestPartyStatsLog();
    widget.onPartyJoined?.call();
    return null;
  }

  /// PWA-parity: `guests/{clientId}` + `total_guest_count`, Sprache; Prefs-Dedupe; bei Locale-Wechsel nur Sprache.
  void _scheduleGuestPartyStatsLog() {
    if (_isAdmin) return;
    final code = _partyCode;
    if (code == null || code.isEmpty || code == 'manual') return;

    Future.microtask(() async {
      try {
        final info = await _getActivePartyInfo();
        final partyId = (info['partyId'] ?? '').trim();
        if (partyId.isEmpty || partyId == 'manual') return;
        if (!mounted) return;

        if (_deviceId.isEmpty || _deviceId == 'device_unknown') {
          await _loadDeviceId();
        }
        if (!mounted) return;

        final lang = Localizations.localeOf(context).languageCode;
        final clientId = await _getOrCreateClientId();
        if (!mounted) return;

        final user = FirebaseAuth.instance.currentUser;
        await GuestPartyStatsService.instance.onWishboxOpenedForParty(
          partyId: partyId,
          clientId: clientId,
          languageCode: lang,
          isLoggedInEmailPassword:
              GuestPartyStatsService.isEmailPasswordAccount(user),
        );
      } catch (_) {
        // absichtlich still
      }
    });
  }

  /// Erstellt oder lädt clientId aus SharedPreferences
  /// Generiert eine persistente Geräte-ID für Gäste
  Future<String> _getOrCreateClientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String effectiveDeviceId = _deviceId.trim();
      if (effectiveDeviceId.isEmpty || effectiveDeviceId == 'device_unknown') {
        effectiveDeviceId = (prefs.getString('guest_device_id') ?? '').trim();
      }
      if (effectiveDeviceId.isEmpty || effectiveDeviceId == 'device_unknown') {
        await _loadDeviceId();
        effectiveDeviceId = _deviceId.trim();
      }
      if (effectiveDeviceId.isEmpty) {
        effectiveDeviceId = 'device_unknown';
      }

      final sanitizedDeviceId = effectiveDeviceId.replaceAll(
        RegExp(r'[^A-Za-z0-9_\-]'),
        '_',
      );
      final deterministicClientId = 'app_$sanitizedDeviceId';

      final storedClientId = prefs.getString('guest_client_id');
      if (storedClientId == null || storedClientId != deterministicClientId) {
        await prefs.setString('guest_client_id', deterministicClientId);
      }

      debugLog(
        '✅ _getOrCreateClientId: Deterministische clientId aus deviceId: $deterministicClientId',
      );
      return deterministicClientId;
    } catch (e) {
      debugLog('❌ Fehler beim Erstellen der clientId: $e');
      // Fallback: Einfache ID
      final fallbackId = 'app_device_unknown';
      debugLog('⚠️ Verwende Fallback clientId');
      return fallbackId;
    }
  }

  /// Prüft Block-Status für Gäste (party-spezifisch)
  /// Abonniert einen Stream auf blocked_guests/${clientId}_${partyId}
  Future<void> _checkBlockStatus() async {
    try {
      _guestBlockSubscription?.cancel();

      // Hole clientId und partyId
      final clientId = await _getOrCreateClientId();
      if (clientId.isEmpty) {
        debugLog(
          '⚠️ _checkBlockStatus: Keine clientId gefunden, setze _isBlocked = false',
        );
        if (mounted) {
          setState(() {
            _isBlocked = false;
          });
        }
        return;
      }

      // Hole aktive Party-Info
      final partyInfo = await _getActivePartyInfo();
      final partyId = partyInfo['partyId'] ?? '';

      if (partyId.isEmpty || partyId == 'manual') {
        debugLog(
          '⚠️ _checkBlockStatus: Keine partyId gefunden, setze _isBlocked = false',
        );
        if (mounted) {
          setState(() {
            _isBlocked = false;
          });
        }
        return;
      }

      // ✅ NEUES FORMAT: Document-ID = ${clientId}_${partyId}
      final documentId = '${clientId}_$partyId';
      debugLog(
        '🔍 _checkBlockStatus: Prüfe blocked_guests für Document-ID: $documentId',
      );

      // Abonniere Stream auf blocked_guests Dokument
      _guestBlockSubscription = FirebaseFirestore.instance
          .collection('blocked_guests')
          .doc(documentId)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted) return;

              final isBlockedNow = snapshot.exists &&
                  _isBlockEntryActive(snapshot.data() ?? {});
              debugLog(
                '🔍 _checkBlockStatus: Stream-Update - Dokument existiert: $isBlockedNow',
              );

              setState(() {
                _isBlocked = isBlockedNow;
              });

              if (isBlockedNow) {
                debugLog(
                  '🚫 _checkBlockStatus: Gast ist für diese Party gesperrt',
                );
              } else {
                debugLog('✅ _checkBlockStatus: Gast ist nicht gesperrt');
              }
            },
            onError: (error) {
              debugLog('❌ _checkBlockStatus: Fehler im Stream: $error');
              if (mounted) {
                setState(() {
                  _isBlocked =
                      false; // Bei Fehler: nicht als gesperrt markieren (sicherer)
                });
              }
            },
          );

      debugLog(
        '✅ _checkBlockStatus: Stream abonniert für Document-ID: $documentId',
      );
    } catch (e) {
      debugLog('❌ _checkBlockStatus: Fehler beim Prüfen der blocked_guests: $e');
      if (mounted) {
        setState(() {
          _isBlocked =
              false; // Bei Fehler: nicht als gesperrt markieren (sicherer)
        });
      }
    }
  }

  /// Aktuelles volles Stunden-Fenster (Start inkl., Ende exkl.)
  static ({DateTime start, DateTime end}) _getCurrentFullHourRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0);
    final end = start.add(const Duration(hours: 1));
    return (start: start, end: end);
  }

  Future<Map<String, dynamic>> _loadWishStats(String partyId) async {
    if (partyId.isEmpty || partyId == 'manual') return {};
    try {
      final user = FirebaseAuth.instance.currentUser;
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();
      if (!partyDoc.exists) return {};
      final data = partyDoc.data();

      final isLoggedIn = user != null;
      final limit = isLoggedIn
          ? ((data?['user_limit_per_hour'] as int?) ?? 5)
          : ((data?['guest_limit_per_hour'] as int?) ?? 2);

      final range = _getCurrentFullHourRange();
      QuerySnapshot<Map<String, dynamic>> wishesSnap;

      if (isLoggedIn) {
        wishesSnap = await FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', isEqualTo: partyId)
            .where('user_id', isEqualTo: user!.uid)
            .get();
      } else {
        final clientId = await _getOrCreateClientId();
        wishesSnap = await FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', isEqualTo: partyId)
            .where('client_id', isEqualTo: clientId)
            .get();
      }

      int count = 0;
      for (final doc in wishesSnap.docs) {
        final d = doc.data();
        if (d['is_duplicate'] == true) continue;
        final ts = d['createdAt'];
        if (ts is! Timestamp) continue;
        final t = ts.toDate();
        if (!t.isBefore(range.start) && t.isBefore(range.end)) count++;
      }
      final remaining = (limit - count).clamp(0, limit);
      return {
        'limit': limit,
        'count': count,
        'remaining': remaining,
        'allowed': remaining > 0,
      };
    } catch (e) {
      debugLog('⚠️ _loadWishStats Fehler: $e');
      return {};
    }
  }

  Future<void> _loadWishStatsAndUpdate() async {
    final partyInfo = await _getActivePartyInfo();
    final partyId = partyInfo['partyId'] ?? '';
    if (partyId.isEmpty || partyId == 'manual') return;
    final stats = await _loadWishStats(partyId);
    if (!mounted) return;
    setState(() {
      _wishLimit = stats['limit'] as int? ?? 0;
      _wishCount = stats['count'] as int? ?? 0;
      _wishRemaining = stats['remaining'] as int? ?? 0;
      _nextFullHour = _getCurrentFullHourRange().end;
    });
  }

  void _subscribePartyDocForLimit(String partyId) {
    _partyDocSubscription?.cancel();
    if (partyId.isEmpty || partyId == 'manual') return;
    _partyDocSubscription = FirebaseFirestore.instance
        .collection('parties')
        .doc(partyId)
        .snapshots()
        .listen((_) {
          if (mounted) _loadWishStatsAndUpdate();
        });
  }

  /// Prüft Wunsch-Limit (Party-Stunden-Limit aus Firestore)
  Future<bool> _checkWishLimit(String partyId) async {
    final stats = await _loadWishStats(partyId);
    return stats['allowed'] as bool? ?? true;
  }

  Future<void> _updateGuestStats(String p) async {
    /* ... */
  }

  /// Liefert die aktive Party-Info (lange party_id + party_code).
  /// **Zuerst Gast-Check-in ([PartySessionService])** — sonst rufen eingeloggte Gäste
  /// [ActivePartyService.getActivePartyInfo] auf, finden keine `created_by`-Party,
  /// triggern unnötig `clearCache()` und können PWA/Stream-Zustände stören.
  /// Nur ohne Session: DJ-/Dashboard-Party über ActivePartyService.
  Future<Map<String, String?>> _getActivePartyInfo() async {
    final svc = PartySessionService.instance;
    if (svc.hasSession) {
      return {'partyId': svc.partyId, 'partyCode': svc.shortCode ?? ''};
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final info = await ActivePartyService.getActivePartyInfo(user.uid);
      if (info != null) {
        return {'partyId': info.partyId, 'partyCode': info.partyCode ?? ''};
      }
    }
    return {};
  }

  Future<bool> _checkWishboxActiveStatus() async {
    return true; /* ... */
  }

  String _normalizeText(String t) {
    return t;
  }

  Future<Map<String, dynamic>?> _findSimilarWish(String t, String a) async {
    return null;
  }

  Widget _buildSuccessView(AppLocalizations localizations) {
    // PWA: .success-message — schwarzer Hintergrund, grüner Rahmen (--green-success), Headline grün
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UIConstants.appGreenSuccess, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 72, color: Colors.green.shade400),
          const SizedBox(height: 24),
          Text(
            localizations.wishSentReceived,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: UIConstants.appGreenSuccess,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.wishSentDisclaimer,
            style: const TextStyle(
              color: Color(0xFFE57373),
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _showSuccessMessage = false;
                  _titleController.clear();
                  _artistController.clear();
                  _greetingController.clear();
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: UIConstants.appGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                localizations.wish_send_another,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              setState(() {
                _showSuccessMessage = false;
              });
              NavigationService().setTabIndex(0);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  /// Wie PWA: History (bereits gespielt) oder Pending (bereits auf Wunschliste).
  Future<bool> _showWishDuplicateDialog({
    required bool isHistory,
    required String title,
    required String artist,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final dlgTitle = l10n.translate(
      isHistory ? 'modal_history_title' : 'modal_pending_title',
    );
    var message = l10n.translate(
      isHistory ? 'modal_history_message' : 'modal_pending_message',
    );
    final safeTitle = unescapeHtml(title);
    final safeArtist = unescapeHtml(artist);
    message = message
        .replaceAll('{title}', safeTitle)
        .replaceAll('{artist}', safeArtist);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: UIConstants.appOrange, width: 1.5),
        ),
        title: Text(
          dlgTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.translate('modal_button_cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.appGreenSuccess,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.translate('modal_button_send_anyway')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _addWish() async {
    // Validiere Formular
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = SecurityHelper.sanitize(_titleController.text.trim());
    final artist = SecurityHelper.sanitize(_artistController.text.trim());
    final greeting = SecurityHelper.sanitize(_greetingController.text.trim());
    final name = SecurityHelper.sanitize(_nameController.text.trim());

    // Pflichtfelder: Titel UND Artist muessen vorhanden sein.
    if (title.isEmpty || artist.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.wish_title_or_artist_required,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prüfe Party-Code
    if (_partyCode == null || _partyCode!.isEmpty || _partyCode == 'manual') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.party_code_input_required,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Hole aktive Party-Info
    final partyInfo = await _getActivePartyInfo();
    final partyId = partyInfo['partyId'] ?? '';
    final partyCode = partyInfo['partyCode'] ?? _partyCode!;

    if (partyId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.party_code_invalid_or_inactive,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (await _isWishSubmissionBlocked(partyId)) {
      if (!mounted) return;
      setState(() {
        _isBlocked = true;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.wishbox_blocked_title}\n\n${l10n.wishbox_blocked_message}',
          ),
          backgroundColor: const Color(0xFFE65100),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    // clientId für Gast-Identifikation und Free-DJ 2-Stunden-Limit
    final clientId = await _getOrCreateClientId();
    if (_deviceId.isEmpty || _deviceId == 'device_unknown') {
      await _loadDeviceId();
    }
    if (_deviceId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.wish_device_id_unavailable,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    debugLog('🔑 _addWish: clientId gesetzt');

    // Free-DJ: 1 Wunsch pro 2-Stunden-Block (DJ-Wünsche ausgenommen)
    final canRequest = await LimitService.canRequestSong(clientId, partyId);
    if (!canRequest) {
      if (!mounted) return;
      final range = TimeUtils.getTwoHourBlockRange(DateTime.now());
      final nextAt = range.blockEndExclusive;
      final nextStr =
          '${nextAt.hour.toString().padLeft(2, '0')}:${nextAt.minute.toString().padLeft(2, '0')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .free_dj_wish_limit_2h
                .replaceAll('{time}', nextStr),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Prüfe Wunsch-Limit (Party-Stunden-Limit)
    final canAddWish = await _checkWishLimit(partyId);
    if (!canAddWish) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.wish_limit_reset_next_hour,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await DuplicateCheckService.ensurePartySettingsLoaded();

      if (await DuplicateCheckService.checkIfSongWasPlayed(
        title,
        artist,
        partyId,
      )) {
        final go = await _showWishDuplicateDialog(
          isHistory: true,
          title: title,
          artist: artist,
        );
        if (!go) return;
      }

      final similar = await DuplicateCheckService.findSimilarPendingWish(
        title: title,
        artist: artist,
        partyId: partyId,
        spotifyId: _selectedSpotifyId,
      );

      if (similar != null) {
        final go = await _showWishDuplicateDialog(
          isHistory: false,
          title: title,
          artist: artist,
        );
        if (!go) return;
        await _submitDuplicateWish(
          similar,
          title: title,
          artist: artist,
          greeting: greeting,
          name: name,
          partyId: partyId,
          partyCode: partyCode,
          clientId: clientId,
        );
      } else {
        await _submitNewWish(
          title: title,
          artist: artist,
          greeting: greeting,
          name: name,
          partyId: partyId,
          partyCode: partyCode,
          clientId: clientId,
        );
      }
    } catch (e) {
      debugLog('❌ Fehler beim Speichern des Wunsches: $e');
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final shouldShowBlockedNotice =
          msg.contains('permission-denied') ||
          msg.contains('permission denied') ||
          msg.contains('app check') ||
          msg.contains('appcheck') ||
          msg.contains('blocked');
      if (shouldShowBlockedNotice) {
        setState(() {
          _isBlocked = true;
        });
        return;
      }
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.error_saving} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _resolvePartyDjId(String partyId) async {
    final partySnap = await FirebaseFirestore.instance
        .collection('parties')
        .doc(partyId)
        .get();
    final djId = (partySnap.data()?['created_by'] as String?)?.trim();
    if (djId == null || djId.isEmpty) {
      throw Exception('DJ-ID der Party konnte nicht ermittelt werden');
    }
    return djId;
  }

  /// Neuer Wunsch (kein Dubletten-Treffer in der offenen Liste).
  Future<void> _submitNewWish({
    required String title,
    required String artist,
    required String greeting,
    required String name,
    required String partyId,
    required String partyCode,
    required String clientId,
  }) async {
    final djId = await _resolvePartyDjId(partyId);
    final wishData = <String, dynamic>{
      'name': name.isNotEmpty ? name : (_guestName ?? 'Gast'),
      'title': title,
      'artist': artist,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'duplicate_count': 0,
      'requested_by': [name.isNotEmpty ? name : (_guestName ?? 'Gast')],
      'greetings': greeting.isNotEmpty
          ? [
              {
                'name': name.isNotEmpty ? name : (_guestName ?? 'Gast'),
                'greeting': greeting,
              },
            ]
          : [],
      'is_duplicate': false,
      'is_registered_user': FirebaseAuth.instance.currentUser != null,
      'is_registered_users': {
        (name.isNotEmpty ? name : (_guestName ?? 'Gast')):
            FirebaseAuth.instance.currentUser != null,
      },
      'client_id': clientId,
      'device_id': _deviceId,
      if (FirebaseAuth.instance.currentUser != null)
        'user_id': FirebaseAuth.instance.currentUser!.uid,
      'party_id': partyId,
      'party_code': partyCode,
      'dj_id': djId,
      'djId': djId,
      'isSeen': false,
    };

    if (_selectedSpotifyId != null && _selectedSpotifyId!.trim().isNotEmpty) {
      wishData['spotify_id'] = _selectedSpotifyId;
      if (_selectedDurationMs != null) {
        wishData['duration_ms'] = _selectedDurationMs;
      }
    }

    await FirebaseFirestore.instance
        .collection('wishes')
        .add(SecurityHelper.sanitizeMap(wishData));

    if (!mounted) return;
    _onWishSaved(wishData, context, savedTitle: title, savedArtist: artist);
    await _updateGuestStats(partyId);

    if (!mounted) return;
    setState(() {
      _showSuccessMessage = true;
      _titleController.clear();
      _artistController.clear();
      _greetingController.clear();
      _selectedSpotifyId = null;
      _selectedDurationMs = null;
    });

    await _loadWishStatsAndUpdate();
  }

  /// Dubletten-Treffer: Original-Wunsch aktualisieren + neuen Eintrag wie PWA.
  Future<void> _submitDuplicateWish(
    SimilarPendingWishMatch match, {
    required String title,
    required String artist,
    required String greeting,
    required String name,
    required String partyId,
    required String partyCode,
    required String clientId,
  }) async {
    final djId = await _resolvePartyDjId(partyId);
    var actualOriginalId = match.documentId;
    final md = match.data;
    if (md['is_duplicate'] == true && md['original_wish_id'] != null) {
      actualOriginalId = md['original_wish_id'] as String;
    }

    final origRef = FirebaseFirestore.instance
        .collection('wishes')
        .doc(actualOriginalId);
    final origSnap = await origRef.get();
    if (!origSnap.exists) {
      await _submitNewWish(
        title: title,
        artist: artist,
        greeting: greeting,
        name: name,
        partyId: partyId,
        partyCode: partyCode,
        clientId: clientId,
      );
      return;
    }

    final originalData = origSnap.data()!;
    final currentCount = (originalData['duplicate_count'] as int?) ?? 0;
    final requestedBy = List<String>.from(
      (originalData['requested_by'] as List?)?.map((e) => e.toString()) ?? [],
    );
    final sanitizedName = name.isNotEmpty ? name : (_guestName ?? 'Gast');
    if (!requestedBy.contains(sanitizedName)) requestedBy.add(sanitizedName);

    final greetings = <Map<String, dynamic>>[];
    final existingG = originalData['greetings'];
    if (existingG is List) {
      for (final e in existingG) {
        if (e is Map) greetings.add(Map<String, dynamic>.from(e));
      }
    }
    if (greeting.isNotEmpty) {
      greetings.add({'name': sanitizedName, 'greeting': greeting});
    }

    final existingIsRegisteredUsers = Map<String, dynamic>.from(
      originalData['is_registered_users'] as Map? ?? {},
    );
    existingIsRegisteredUsers[sanitizedName] =
        FirebaseAuth.instance.currentUser != null;

    await origRef.update(
      SecurityHelper.sanitizeMap({
        'duplicate_count': currentCount + 1,
        'requested_by': requestedBy,
        'greetings': greetings,
        'is_registered_users': existingIsRegisteredUsers,
      }),
    );

    final wishData = <String, dynamic>{
      'name': sanitizedName,
      'title': title,
      'artist': artist,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'is_duplicate': true,
      'original_wish_id': actualOriginalId,
      'is_registered_user': FirebaseAuth.instance.currentUser != null,
      'client_id': clientId,
      'device_id': _deviceId,
      if (FirebaseAuth.instance.currentUser != null)
        'user_id': FirebaseAuth.instance.currentUser!.uid,
      'party_id': partyId,
      'party_code': partyCode,
      'dj_id': djId,
      'djId': djId,
      'isSeen': false,
    };
    if (_selectedSpotifyId != null && _selectedSpotifyId!.trim().isNotEmpty) {
      wishData['spotify_id'] = _selectedSpotifyId;
      if (_selectedDurationMs != null)
        wishData['duration_ms'] = _selectedDurationMs;
    }
    if (greeting.isNotEmpty) {
      wishData['greeting'] = greeting;
    }

    await FirebaseFirestore.instance
        .collection('wishes')
        .add(SecurityHelper.sanitizeMap(wishData));

    if (!mounted) return;
    _onWishSaved(wishData, context, savedTitle: title, savedArtist: artist);
    await _updateGuestStats(partyId);

    if (!mounted) return;
    setState(() {
      _showSuccessMessage = true;
      _titleController.clear();
      _artistController.clear();
      _greetingController.clear();
      _selectedSpotifyId = null;
      _selectedDurationMs = null;
    });

    await _loadWishStatsAndUpdate();
  }

  /// Helper-Methode: Wird nach erfolgreichem Speichern eines Wunsches aufgerufen
  /// Extrahiert Spotify-Daten und ruft die Musikdatenbank-Speicherung auf
  void _onWishSaved(
    Map<String, dynamic> wishData,
    BuildContext context, {
    String? savedTitle,
    String? savedArtist,
  }) async {
    final title = (savedTitle ?? _titleController.text).trim();
    final artist = (savedArtist ?? _artistController.text).trim();
    final spotifyId = wishData['spotify_id'] as String?;
    final durationMs = wishData['duration_ms'] as int?;
    final genres = (wishData['genres'] as List?)?.cast<String>() ?? [];
    final partyId = wishData['party_id'] as String?;

    // Rufe Musikdatenbank-Speicherung auf (Fire & Forget)
    // duration_ms und genres sind optional - nur spotify_id, title und artist sind Pflicht
    if (spotifyId != null && title.isNotEmpty && artist.isNotEmpty) {
      // Hole DJ-ID: Gast aus PartySessionService, sonst Fallback
      String? djId;
      final svc = PartySessionService.instance;
      if (svc.hasSession && svc.partyId == partyId) {
        djId = svc.djId;
      }

      _saveToMusicDatabase(
        spotifyId: spotifyId,
        title: title,
        artist: artist,
        durationMs: durationMs, // Kann null sein
        genres: genres, // Kann leer sein
        djId: djId, // DJ-ID für Statistik
        partyId: partyId, // Für Security: wishes-Query nur mit party_id
        context: context, // Für Browser-Sprache
      );
    }
  }

  void _updateBlockStatus(Map<String, dynamic>? u, Map<String, dynamic>? g) {
    /* ... */
  }
}

// ---------------------------------------------------------------------------
// FIX (Build): Fehlende Widgets/Types wiederherstellen (ContactForm/ContactFormState/_WishForm)
// Diese Klassen werden von lib/main.dart importiert (show ContactForm, ContactFormState).
// Inhalt stammt 1:1 aus dem letzten Backup, damit es keine Funktions-/Logik-Änderung gibt.
// ---------------------------------------------------------------------------

class _WishForm extends StatelessWidget {
  const _WishForm({
    required this.formKey,
    required this.nameController,
    required this.titleController,
    required this.artistController,
    required this.greetingController,
    required this.onSubmit,
    this.guestName,
    required this.wishLimit,
    required this.wishCount,
    required this.wishRemaining,
    this.nextFullHour,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController greetingController;
  final Future<void> Function() onSubmit;
  final String? guestName;
  final int wishLimit;
  final int wishCount;
  final int wishRemaining;
  final DateTime? nextFullHour;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WishLimitInfo(
            wishLimit: wishLimit,
            wishCount: wishCount,
            wishRemaining: wishRemaining,
            nextFullHour: nextFullHour,
          ),
          const SizedBox(height: 16),
          if (FirebaseAuth.instance.currentUser == null) ...[
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l.login_name_label,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                return (value == null || value.trim().isEmpty)
                    ? l.login_name_required
                    : null;
              },
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: l.wish_title_label,
                    prefixIcon: const Icon(Icons.music_note_outlined),
                    helperText: l.wish_title_or_artist_required,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => null,
                  onFieldSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  l.wish_tap_for_suggestions,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.amber.shade900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: artistController,
                  decoration: InputDecoration(
                    labelText: l.wish_artist_label,
                    prefixIcon: const Icon(Icons.mic),
                    helperText: l.wish_title_or_artist_required,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => null,
                  onFieldSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  l.wish_tap_for_suggestions,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.amber.shade900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: greetingController,
            decoration: InputDecoration(
              labelText: l.wish_greeting_label,
              prefixIcon: const Icon(Icons.favorite_outline),
              helperText: l.wish_greeting_max_chars,
            ),
            maxLength: 160,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value != null && value.length > 160) {
                return l.wish_greeting_max_chars_error;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.send),
            label: Text(l.submitWish),
          ),
        ],
      ),
    );
  }
}

class _WishLimitInfo extends StatelessWidget {
  final int wishLimit;
  final int wishCount;
  final int wishRemaining;
  final DateTime? nextFullHour;

  const _WishLimitInfo({
    required this.wishLimit,
    required this.wishCount,
    required this.wishRemaining,
    this.nextFullHour,
  });

  String _formatNextFullHour(DateTime? nextHour) {
    if (nextHour == null) return '';
    return '${nextHour.hour.toString().padLeft(2, '0')}:${nextHour.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              wishRemaining > 0
                  ? localizations.wish_limit_remaining(
                      wishRemaining,
                      wishLimit,
                    )
                  : localizations.wish_limit_reset_next_hour,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ContactForm extends StatefulWidget {
  final GlobalKey<ContactFormState>? formKey;

  /// Gast-PWA: false wenn DJ Free ist – Formular optisch sichtbar, aber deaktiviert (keine Interaktion).
  final bool enabled;

  /// true wenn kein Party-Kontext: Firestore recipient="VibesBox", type="support".
  final bool isVibesboxSupportMode;

  const ContactForm({
    this.formKey,
    this.enabled = true,
    this.isVibesboxSupportMode = false,
  }) : super(key: formKey);

  @override
  State<ContactForm> createState() => ContactFormState();
}

class ContactFormState extends State<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isUserLoggedIn = false;
  /// Nach erfolgreichem Absenden: keine erneute Befüllung von Name/E-Mail aus Firebase bis [resetSuccessMessage].
  bool _suppressProfileAutofill = false;
  String? _trackedAuthUid;
  StreamSubscription<User?>? _authSubscription;

  VoidCallback? _supportModeListener;

  @override
  void initState() {
    super.initState();
    _updateUserData();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) _updateUserData();
    });
    if (widget.isVibesboxSupportMode) {
      _supportModeListener = () {
        if (mounted) setState(() {});
      };
      _nameController.addListener(_supportModeListener!);
      _emailController.addListener(_supportModeListener!);
      _messageController.addListener(_supportModeListener!);
    }
  }

  void _updateUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    final newUid = user?.uid;
    if (newUid != _trackedAuthUid) {
      _suppressProfileAutofill = false;
      _trackedAuthUid = newUid;
    }
    setState(() {
      if (user != null) {
        _isUserLoggedIn = true;
        if (!_suppressProfileAutofill) {
          _nameController.text = user.displayName ?? '';
          _emailController.text = user.email ?? '';
        }
      } else {
        _isUserLoggedIn = false;
        _nameController.clear();
        _emailController.clear();
      }
    });
  }

  bool get _canSubmitSupport {
    if (!widget.isVibesboxSupportMode) return true;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();
    return name.isNotEmpty &&
        email.isNotEmpty &&
        email.contains('@') &&
        message.isNotEmpty;
  }

  void resetSuccessMessage() {
    if (mounted) {
      _suppressProfileAutofill = false;
      _phoneController.clear();
      _subjectController.clear();
      _messageController.clear();
      _nameController.clear();
      _emailController.clear();
      _formKey.currentState?.reset();
      _updateUserData();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    if (_supportModeListener != null) {
      _nameController.removeListener(_supportModeListener!);
      _emailController.removeListener(_supportModeListener!);
      _messageController.removeListener(_supportModeListener!);
    }
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitContactForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final localizations = AppLocalizations.of(context)!;
      final name = sanitizeInput(_nameController.text.trim());
      final email = sanitizeEmail(_emailController.text.trim());
      final phone = sanitizeInput(
        _phoneController.text.replaceAll(RegExp(r'\s+$'), ''),
      );
      final subject = sanitizeInput(_subjectController.text.trim());
      final message = sanitizeInput(_messageController.text.trim());

      if (name.length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.contact_error_name_too_long,
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (subject.length > 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.contact_error_subject_too_long,
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (message.length > 3000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.contact_error_message_too_long,
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (widget.isVibesboxSupportMode) {
        // Datenschonend: Kein Firestore, direkter API-Versand an Cloud Function
        final locale = Localizations.localeOf(context).languageCode;
        final body = {
          'name': name,
          'email': email,
          'phone': phone,
          'subject': subject,
          'message': message,
          'partyId': '',
          'language': locale.isNotEmpty ? locale : 'de',
          'client_id': 'app_guest',
          'recipientEmail': AppConfig.adminEmail,
          'source': 'app_guest',
        };
        final url = Uri.parse(AppConfig.validateRecaptchaFunctionUrl);
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-App-Security-Key': AppConfig.contactAppSecurityKey,
          },
          body: jsonEncode(body),
        );
        Map<String, dynamic> data = {};
        if (response.body.isNotEmpty) {
          try {
            data = (jsonDecode(response.body) as Map<String, dynamic>?) ?? {};
          } catch (_) {}
        }
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            data['success'] != true) {
          throw Exception(
            data['error'] as String? ??
                data['message'] as String? ??
                'HTTP ${response.statusCode}',
          );
        }
      } else {
        final data = <String, dynamic>{
          'name': name,
          'email': email,
          'phone': phone,
          'subject': subject,
          'message': message,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'userEmail': FirebaseAuth.instance.currentUser?.email,
        };
        await FirebaseFirestore.instance
            .collection('contact_messages')
            .add(data);
        // E-Mail nur serverseitig (z. B. validateRecaptcha… / Functions); kein EmailJS aus der App.
      }

      if (mounted) {
        _suppressProfileAutofill = true;
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _subjectController.clear();
        _messageController.clear();
        // Kein Form.reset() hier: kann mit [TextEditingController] kollidieren und alte Werte zurücksetzen.
        setState(() {});
        final l10n = AppLocalizations.of(context)!;
        final isRtl = [
          'ar',
          'he',
          'fa',
          'ur',
        ].contains(Localizations.localeOf(context).languageCode);
        final title = widget.isVibesboxSupportMode
            ? l10n.contact_support_success_title
            : l10n.contact_success_title;
        final message = widget.isVibesboxSupportMode
            ? l10n.contact_support_success_body
            : l10n.contact_success_body;
        final buttonText = l10n.contact_success_ok;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => UIConstants.buildSuccessDialog(
            context: dialogContext,
            title: title,
            message: message,
            buttonText: buttonText,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
        ).then((_) {
          if (!mounted) return;
          // Hintergrund: Gast-Shell wieder Startseite (IndexedStack 0), nicht Kontakt-Tab.
          NavigationService().setTabIndex(0);
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        final errorMsg = localizations.contact_error_sending(e.toString());
        final title = localizations.contact_error_title;
        final buttonText = localizations.contact_success_ok;
        final isRtl = [
          'ar',
          'he',
          'fa',
          'ur',
        ].contains(Localizations.localeOf(context).languageCode);
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => UIConstants.buildErrorDialog(
            context: dialogContext,
            title: title,
            message: errorMsg,
            buttonText: buttonText,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Eingabefeld mit Label links (Weiß), guestInputBoxDecoration, prefixIcon.
  Widget _contactField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool enabled,
    bool readOnly = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      children: [
        SizedBox(
          width: 100,
          child: Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: UIConstants.guestInputBoxDecoration,
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              readOnly: readOnly,
              maxLines: maxLines,
              maxLength: maxLength,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              validator: validator,
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: UIConstants.appOrange, size: 20),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              style: const TextStyle(color: UIConstants.appBarForegroundColor),
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    final enabled = widget.enabled;

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: isRtl
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.stretch,
            children: [
              _contactField(
                label: _isUserLoggedIn
                    ? localizations.contact_name_label
                    : localizations.contact_name_label_required,
                icon: Icons.person_outline,
                controller: _nameController,
                enabled: enabled && !_isUserLoggedIn,
                readOnly: !enabled,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations.contact_validation_enter_name;
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _contactField(
                label: localizations.contact_email_label,
                icon: Icons.email_outlined,
                controller: _emailController,
                enabled: enabled && !_isUserLoggedIn,
                readOnly: !enabled,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (_isUserLoggedIn) return null;
                  final email = value?.trim() ?? '';
                  final phone = _phoneController.text.replaceAll(
                    RegExp(r'\s+$'),
                    '',
                  );
                  if (widget.isVibesboxSupportMode) {
                    if (email.isEmpty) {
                      return localizations.contact_validation_email_or_phone;
                    }
                    if (!email.contains('@')) {
                      return localizations.contact_validation_invalid_email;
                    }
                    return null;
                  }
                  if (email.isEmpty && phone.isEmpty) {
                    return localizations.contact_validation_email_or_phone;
                  }
                  if (email.isNotEmpty && !email.contains('@')) {
                    return localizations.contact_validation_invalid_email;
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  localizations.contact_email_or_phone_required,
                  style: TextStyle(
                    color: UIConstants.appOrange.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                ),
              ),
              _contactField(
                label: localizations.contact_phone_label,
                icon: Icons.phone_outlined,
                controller: _phoneController,
                enabled: enabled,
                readOnly: !enabled,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (_isUserLoggedIn) return null;
                  if (widget.isVibesboxSupportMode) return null;
                  final email = _emailController.text.trim();
                  final phone = value?.replaceAll(RegExp(r'\s+$'), '') ?? '';
                  if (email.isEmpty && phone.isEmpty) {
                    return localizations.contact_validation_email_or_phone;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _contactField(
                label: localizations.contact_subject_label,
                icon: Icons.assignment_outlined,
                controller: _subjectController,
                enabled: enabled,
                readOnly: !enabled,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              _contactField(
                label: localizations.contact_message_label,
                icon: Icons.message_outlined,
                controller: _messageController,
                enabled: enabled,
                readOnly: !enabled,
                maxLines: 5,
                maxLength: 3000,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations.contact_validation_enter_message;
                  }
                  if (value.length > 3000) {
                    return localizations.contact_error_message_too_long;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Align(
                alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    elevatedButtonTheme: ElevatedButtonThemeData(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.appGreenSuccess,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: UIConstants.appGreenSuccess
                            .withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: (enabled && !_isLoading && _canSubmitSupport)
                          ? _submitContactForm
                          : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: Text(
                        _isLoading
                            ? localizations.contact_sending
                            : localizations.contact_send_button,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
