part of 'main.dart';

// Hauptseite mit Drawer
class MainPage extends StatefulWidget {
  const MainPage({super.key, this.skipEmailVerification = false});

  /// Wenn true: keine E-Mail-Verifizierungs-Schranke (nur von [FirestoreEmailVerifiedGate] bei Override).
  final bool skipEmailVerification;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  /// Global in [NavigationService] – überlebt MainPage-Neuaufbau (Screenshot, Lifecycle).
  int get _currentIndex => NavigationService().currentTabIndex.value;

  int _previousTabIndex =
      0; // Für Zurück-Navigation von rechtlichen Seiten (IndexedStack)

  User? _previousUser;
  StreamSubscription<User?>? _authSubscription;
  bool _lastRegistrationGuard = false;
  String? _lastRoleId;
  String?
  _currentRoleName; // Rollenname aus Firestore (Gast/User/DJ/Admin/Location)

  // AnimationController für AppBar-Effekte
  late AnimationController _glowAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  final GlobalKey<ContactFormState> _contactFormKey =
      GlobalKey<ContactFormState>();

  Timer? _newWishesCheckTimer;
  int _newWishesCount = 0;
  DateTime?
  _lastNotifiedWishTime; // Speichert den letzten benachrichtigten Wunsch-Timestamp
  StreamSubscription<QuerySnapshot>?
  _wishesStreamSubscription; // Stream für neue Wünsche

  final GlobalKey<OffenPageState> _offenPageKey = GlobalKey<OffenPageState>();
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();
  static const MethodChannel _batteryChannel = MethodChannel(
    'dj_og_app/battery_optimization',
  );
  bool _batteryOptimizationChecked = false;

  /// Berechtigungsabfragen (Notification, Batterie) nur einmal pro Session nach DJ-Login
  bool _djPermissionsCheckDone = false;

  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<String>? _recognitionNotificationTapSubscription;

  String? _currentViewRole; // Für Admin-Ansicht-Umschaltung
  String? _appUpdateCheckScope;
  bool _appUpdateCheckRunning = false;
  bool _announcementCheckDone =
      false; // Einmal pro Session: globale Ankündigung prüfen
  /// Timeout-Fallback: Nach 20 s ohne Profil-Antwort Fehlermeldung + Retry
  bool _profileLoadTimeoutReached = false;
  Timer? _profileLoadTimeoutTimer;
  bool _profileLoadTimeoutTimerStarted = false;
  bool _logoutTriggered = false;
  bool _mandatoryProfileDialogShown = false;
  bool wantsAdminView = false;
  bool _adminAuthRequiredAfterLogin = false;
  bool _adminBiometricCheckInProgress = false;
  String? _adminBiometricVerifiedUid;
  bool _adminUseAuthenticatorFallback = false;
  String? _adminOtpSecretFromFirestore;
  String? _adminOtpErrorText;
  bool _adminOtpChecking = false;
  DateTime? _lastBackPressedAt;
  static const Duration _exitBackPressWindow = Duration(seconds: 2);
  final List<TextEditingController> _adminOtpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _adminOtpFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );

  /// Firestore [email_verified_override] – niemals zweite MainPage nesten; Flag setzen und Gate verlassen.
  bool _emailVerifiedFirestoreOverride = false;

  /// Kaltstart-Dienste (forceRefresh, AppUpdate, …) nur einmal pro Firebase-UID –
  /// app-weit (überlebt MainPage-Neuinstanz / MaterialApp-Rebuild), nicht bei jedem Resume.
  /// PartyAutostart (Shazam) ist davon getrennt – startet sofort / bei Resume über [PartyAutostartService].
  static String? _appColdStartDoneUid;

  /// Letztes UserModel für UI-Updates (Header/PRO etc.) ohne ValueListenableBuilder um den IndexedStack.
  UserModel? _lastUserModelForUi;
  String? _lastNotificationLocaleTag;

  // Zentrale Datenverwaltung
  List<SongRequest> _currentWishesList =
      []; // Aktuelle Liste der Wünsche (wird nicht mehr verwendet)

  Future<void> _syncNotificationLocaleStrings() async {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    if (l == null) return;

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    if (_lastNotificationLocaleTag == localeTag) return;
    _lastNotificationLocaleTag = localeTag;

    await ShazamService().setNotificationStrings(
      l.status_notification_title,
      l.status_notification_listening,
      l.recognition_success,
    );
    await ShazamService().pushLocalizedNotificationContentNow();
  }

  /// Musikerkennung: nicht hinter Cold-Start-UID blockieren; nach Frame starten.
  void _kickPartyAutostart() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser == null) return;
      try {
        await PartyAutostartService().initialize();
      } catch (e) {
        debugLog('❌ PartyAutostartService.initialize: $e');
      }
    });
  }

  /// Einmal pro UID: gleiche Logik wie früher beim „Login“-Pfad, aber ohne erneutes Feuern bei Resume.
  void _runColdStartServicesForUser(User user) {
    if (_appColdStartDoneUid == user.uid) {
      debugLog(
        '🔐 MainPage: Cold-Start-Dienste bereits erledigt (appweit) – überspringe',
      );
      return;
    }
    _appColdStartDoneUid = user.uid;
    debugLog('🔐 MainPage: Cold-Start-Dienste');
    UserService().forceRefresh();
    debugLog('🔐 MainPage: UserService.forceRefresh() aufgerufen');
    SubscriptionSyncService.logIn(user.uid);
    SubscriptionSyncService.syncSubscriptionStatus(user.uid);
    AppUpdateService.logUserAppVersion();
    debugLog('🔐 MainPage: AppUpdateService.logUserAppVersion() aufgerufen');
    if (!kDebugMode) {
      AppUpdateService.debugFetchAndPrintStoreVersion();
    }
  }

  Future<bool> _runAdminBiometricGate(
    User user, {
    bool signOutOnFailure = true,
  }) async {
    if (_adminBiometricCheckInProgress) return false;
    if (_adminBiometricVerifiedUid == user.uid) return true;
    if (_adminUseAuthenticatorFallback) return false;

    _adminBiometricCheckInProgress = true;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return false;

      final isAdmin = userDoc.data()?['admin'] == true;
      if (!isAdmin) {
        _adminBiometricVerifiedUid = user.uid;
        return true;
      }

      final otpSecret =
          (userDoc.data()?['admin_otp_secret'] as String?)?.trim();

      final biometricAvailable = await BiometricService().isBiometricAvailable();
      if (!mounted) return false;
      if (!biometricAvailable) {
        debugLog(
          'Admin-Gate: Biometrie nicht verfuegbar, Authenticator-Fallback aktivieren.',
        );
        setState(() {
          _adminUseAuthenticatorFallback = true;
          _adminOtpSecretFromFirestore = otpSecret;
          _adminOtpErrorText = null;
        });
        _clearAdminOtpInput();
        return false;
      }

      final authenticated = await BiometricService().authenticateAdmin();
      if (!mounted) return false;

      if (authenticated) {
        setState(() {
          wantsAdminView = true;
          _adminAuthRequiredAfterLogin = false;
          _adminBiometricVerifiedUid = user.uid;
          _adminUseAuthenticatorFallback = false;
          _adminOtpErrorText = null;
          _currentViewRole = 'Admin';
        });
        unawaited(NavigationService().persistAdminViewRole('Admin'));
        _clearAdminOtpInput();
        return true;
      }

      if (signOutOnFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin-Check fehlgeschlagen. Login abgebrochen.'),
            backgroundColor: Colors.red,
          ),
        );
        await FirebaseAuth.instance.signOut();
      }
      return false;
    } catch (e) {
      debugLog('Admin-Biometrie fehlgeschlagen: $e');
      if (!mounted) return false;
      if (signOutOnFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin-Check fehlgeschlagen. Login abgebrochen.'),
            backgroundColor: Colors.red,
          ),
        );
        await FirebaseAuth.instance.signOut();
      }
      return false;
    } finally {
      _adminBiometricCheckInProgress = false;
    }
  }

  Future<bool> _runAdminBiometricGatePostFrame(
    User user, {
    bool signOutOnFailure = true,
  }) {
    final completer = Completer<bool>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final ok = await _runAdminBiometricGate(
          user,
          signOutOnFailure: signOutOnFailure,
        );
        if (!completer.isCompleted) completer.complete(ok);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(false);
      }
    });
    return completer.future;
  }

  void _clearAdminOtpInput() {
    for (final controller in _adminOtpControllers) {
      controller.clear();
    }
  }

  String _readAdminOtpInput() {
    return _adminOtpControllers.map((controller) => controller.text).join();
  }

  bool _isAdminOtpComplete() {
    return _adminOtpControllers.every((controller) => controller.text.length == 1);
  }

  void _onAdminOtpDigitChanged(int index, String rawValue, User user) {
    final digitsOnly = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly != rawValue) {
      _adminOtpControllers[index].text = digitsOnly;
      _adminOtpControllers[index].selection = TextSelection.collapsed(
        offset: _adminOtpControllers[index].text.length,
      );
    }

    if (digitsOnly.length > 1) {
      final chars = digitsOnly.split('');
      for (int i = 0; i < chars.length && (index + i) < 6; i++) {
        _adminOtpControllers[index + i].text = chars[i];
      }
      final nextIndex = (index + chars.length).clamp(0, 5);
      _adminOtpFocusNodes[nextIndex].requestFocus();
    } else if (digitsOnly.isNotEmpty && index < 5) {
      _adminOtpFocusNodes[index + 1].requestFocus();
    } else if (digitsOnly.isEmpty && index > 0) {
      _adminOtpFocusNodes[index - 1].requestFocus();
    }

    if (_adminOtpErrorText != null && mounted) {
      setState(() {
        _adminOtpErrorText = null;
      });
    }

    if (_isAdminOtpComplete()) {
      unawaited(_verifyAdminOtpCode(user));
    }
  }

  Future<void> _verifyAdminOtpCode(User user) async {
    if (_adminOtpChecking) return;

    final inputCode = _readAdminOtpInput();
    if (inputCode.length != 6) return;

    final secretRaw = _adminOtpSecretFromFirestore;
    if (secretRaw == null || secretRaw.isEmpty) {
      if (!mounted) return;
      setState(() {
        _adminOtpErrorText = 'Kein Admin-Secret hinterlegt.';
      });
      _clearAdminOtpInput();
      _adminOtpFocusNodes.first.requestFocus();
      return;
    }
    final secret = secretRaw.trim().toUpperCase();

    if (mounted) {
      setState(() {
        _adminOtpChecking = true;
        _adminOtpErrorText = null;
      });
    }

    try {
      final expectedCode = OTP.generateTOTPCodeString(
        secret,
        DateTime.now().millisecondsSinceEpoch,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      final isValid = expectedCode == inputCode;

      if (!mounted) return;
      if (isValid) {
        setState(() {
          wantsAdminView = true;
          _adminAuthRequiredAfterLogin = false;
          _adminBiometricVerifiedUid = user.uid;
          _adminUseAuthenticatorFallback = false;
          _adminOtpErrorText = null;
          _currentViewRole = 'Admin';
        });
        unawaited(NavigationService().persistAdminViewRole('Admin'));
        _clearAdminOtpInput();
      } else {
        setState(() {
          _adminOtpErrorText = 'Code ungültig. Bitte erneut versuchen.';
        });
        _clearAdminOtpInput();
        _adminOtpFocusNodes.first.requestFocus();
      }
    } catch (e) {
      debugLog('Admin-OTP-Pruefung fehlgeschlagen: $e');
      if (!mounted) return;
      setState(() {
        _adminOtpErrorText = 'Code-Prüfung fehlgeschlagen.';
      });
      _clearAdminOtpInput();
      _adminOtpFocusNodes.first.requestFocus();
    } finally {
      if (mounted) {
        setState(() {
          _adminOtpChecking = false;
        });
      } else {
        _adminOtpChecking = false;
      }
    }
  }

  Widget _buildAdminOtpCurtain(User user) {
    return Scaffold(
      backgroundColor: UIConstants.djShellPageBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Authenticator-Code erforderlich...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      width: 42,
                      child: TextField(
                        controller: _adminOtpControllers[index],
                        focusNode: _adminOtpFocusNodes[index],
                        enabled: !_adminOtpChecking,
                        keyboardType: TextInputType.number,
                        textInputAction: index < 5
                            ? TextInputAction.next
                            : TextInputAction.done,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLength: 1,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white10,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: UIConstants.appOrange,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: UIConstants.partyYellow,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            _onAdminOtpDigitChanged(index, value, user),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              if (_adminOtpErrorText != null)
                Text(
                  _adminOtpErrorText!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Taps auf die Versionsnummer im Drawer – beim 5. Tap öffnet sich das Deep-State-Experten-Menü
  int _deepStateTapCount = 0;

  /// Wird bei "Party verlassen" (Gast) erhöht, um WishesPage neu zu laden.
  int _guestPartyLeaveCount = 0;

  /// Wird bei erfolgreichem Check-In erhöht, damit SocialMediaPage, ContactPage, History neu laden.
  int _guestPartyJoinCount = 0;
  bool _guestAuthStartInRegister = false;
  /// Erhöht sich bei Party-Deep-Link ohne Login → [LoginPage] neu mounten (Party-Code-Feld).
  int _guestAuthPartyLinkNonce = 0;
  bool _partyDeepLinkLoading = false;
  bool _autoJoinStoredPartyRunning = false;
  String? _lastAutoJoinStoredPartyKey;

  int get currentIndex => NavigationService().currentTabIndex.value;

  void _openGuestLogin() {
    if (_guestAuthStartInRegister) {
      setState(() => _guestAuthStartInRegister = false);
    }
    NavigationService().setTabIndex(1);
  }

  void _openGuestRegister() {
    if (!_guestAuthStartInRegister) {
      setState(() => _guestAuthStartInRegister = true);
    }
    NavigationService().setTabIndex(1);
  }

  /// Einmaliger Hinweis nach Ablauf der 48h-Probezeit (DJ-Bereich).
  void _onTrialExpiryPromptNotifier() {
    final endMs = UserService().trialExpiryPromptNotifier.value;
    if (endMs == null || !mounted) return;
    UserService().trialExpiryPromptNotifier.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'trial_expired_dlg_$endMs';
      if (prefs.getBool(key) == true) return;

      final roleName = _currentRoleName;
      final isDjArea =
          roleName == 'DJ' ||
          roleName == 'Admin' ||
          roleName == 'Location';
      if (!isDjArea) return;

      final l = AppLocalizations.of(context)!;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: UIConstants.appOrange, width: 2),
          ),
          title: Text(
            l.vibesbox_free,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l.trial_expired_dialog_message,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                l.trial_expired_dialog_ok,
                style: const TextStyle(
                  color: UIConstants.appOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      await prefs.setBool(key, true);
    });
  }

  /// Reagiert auf Änderungen am zentralen User-Modell (role_id → Rollenname laden, ViewRole setzen).
  void _onUserModelChanged() async {
    final userModel = UserService().currentUser.value;
    if (!mounted) return;

    final prev = _lastUserModelForUi;
    _lastUserModelForUi = userModel;

    // Kein setState bei jedem Firestore-Tick: Header/PRO nutzen ValueListenableBuilder auf sessionProStatus/currentUser.
    // Shell nur bei Übergängen, die Tabs/IndexedStack-Logik betreffen (sonst Flackern + „neuer“ Seitenaufbau).
    if (prev?.photoURL != userModel?.photoURL && userModel != null) {
      unawaited(UserService.ensureDjLogoCached());
    }
    var shellNeedsRebuild = false;
    if ((prev == null) != (userModel == null)) {
      shellNeedsRebuild = true;
    } else if (prev != null && userModel != null) {
      if (prev.hasCompletedProfile != userModel.hasCompletedProfile ||
          prev.admin != userModel.admin ||
          prev.roleId != userModel.roleId) {
        shellNeedsRebuild = true;
      }
    }
    if (shellNeedsRebuild && mounted) {
      setState(() {});
    }

    final roleId = userModel?.roleId;
    if (roleId == _lastRoleId) return;
    _lastRoleId = roleId;

    String? roleName;
    try {
      if (roleId != null && roleId.isNotEmpty) {
        final roleDoc = await FirebaseFirestore.instance
            .collection('roles')
            .doc(roleId)
            .get();
        roleName = roleDoc.data()?['name'] as String?;
      }
    } catch (_) {
      roleName = null;
    }

    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;

    // Admin: gespeicherte Ansicht (Admin vs DJ) – zuerst synchroner Cache (main()-Hydration), dann ggf. Prefs.
    String? persistedAdminViewRole;
    String preferredStartView = NavigationService().cachedPreferredStartView;
    if (roleName == 'Admin') {
      persistedAdminViewRole =
          NavigationService().cachedAdminViewRole ??
          await NavigationService().loadPersistedAdminViewRole();
      preferredStartView =
          await NavigationService().loadPersistedPreferredStartView();
      if (!mounted) return;
    }

    // Absicherung: Bei null oder Gast sofort Flag setzen, damit die Berechtigungslogik bis zum DJ-Login schläft
    final isDjRole =
        roleName != null &&
        (roleName == 'DJ' || roleName == 'Admin' || roleName == 'Location');
    if (roleName == null || roleName == 'Gast') {
      _djPermissionsCheckDone = true;
    } else if (isDjRole) {
      final wasNonDj = _currentRoleName == null || _currentRoleName == 'Gast';
      if (wasNonDj) _djPermissionsCheckDone = false;
    }

    setState(() {
      _currentRoleName = roleName;
      if (user == null) {
        _currentViewRole = null;
        wantsAdminView = false;
        _adminAuthRequiredAfterLogin = false;
        return;
      }
      if (roleName == 'Admin') {
        final persisted = persistedAdminViewRole ?? 'DJ';
        if (preferredStartView == 'guest_area') {
          _currentViewRole = 'Gast';
          wantsAdminView = false;
          _adminAuthRequiredAfterLogin = false;
          return;
        }
        if (preferredStartView == 'dj_area') {
          _currentViewRole = 'DJ';
          wantsAdminView = false;
          _adminAuthRequiredAfterLogin = false;
          return;
        }
        if (_adminBiometricVerifiedUid == user?.uid) {
          _currentViewRole = persisted == 'Admin' ? 'Admin' : persisted;
          wantsAdminView = _currentViewRole == 'Admin';
        } else {
          _currentViewRole = persisted == 'Admin' ? 'DJ' : persisted;
          wantsAdminView = false;
        }
        return;
      }
      if (roleName == null || roleName == 'Gast') {
        _currentViewRole = null;
        wantsAdminView = false;
        _adminAuthRequiredAfterLogin = false;
        return;
      }
      _currentViewRole = (roleName == 'Location') ? 'DJ' : roleName;
      wantsAdminView = false;
      _adminAuthRequiredAfterLogin = false;
    });

    if (roleName == 'Admin' &&
        preferredStartView == 'admin_dashboard' &&
        user != null &&
        _adminAuthRequiredAfterLogin &&
        _adminBiometricVerifiedUid != user.uid &&
        !_adminBiometricCheckInProgress &&
        !_adminUseAuthenticatorFallback) {
      setState(() {
        wantsAdminView = true;
        _currentViewRole = 'Admin';
      });
      _adminAuthRequiredAfterLogin = false;
      unawaited(_runAdminBiometricGatePostFrame(user));
    }

    if (roleName == 'Gast' && user != null) {
      unawaited(_tryAutoJoinStoredPartyForGuest());
    }

    // Berechtigungen nur bei eindeutiger DJ-Rolle: roleName NICHT null UND exakt 'DJ', 'Admin' oder 'Location'
    if (roleName != null &&
        (roleName == 'DJ' || roleName == 'Admin' || roleName == 'Location') &&
        user != null &&
        !_djPermissionsCheckDone) {
      debugLog('Permissions Check - Aktuelle Rolle: $roleName');
      _djPermissionsCheckDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        initializeNotifications().then((_) {
          if (mounted) _requestDjPermissionsIfNeeded();
        });
      });
    }

    if (roleName != null &&
        (roleName == 'DJ' ||
            roleName == 'Location' ||
            roleName == 'Admin')) {
      unawaited(_migrateDjSpotifyMasterOnlyTabIndex());
    }
  }

  /// Admin-Konto: Umschaltung Admin- vs DJ-Ansicht persistieren (überlebt MainPage-Neuaufbau).
  void _handleHomeViewRoleChanged(String? newRole) {
    unawaited(_handleHomeViewRoleChangedAsync(newRole));
  }

  Future<void> _handleHomeViewRoleChangedAsync(String? newRole) async {
    final m = UserService().currentUser.value;
    if (!AppConfig.isAdminRole(m)) return;

    // Nicht-Admin-Ansichten wechseln sofort ohne zusätzliche Prüfung.
    if (newRole != 'Admin') {
      if (!mounted) return;
      setState(() {
        _currentViewRole = newRole;
        wantsAdminView = false;
        _adminAuthRequiredAfterLogin = false;
        // Rückweg aus Admin: nächste Admin-Auswahl muss erneut verifiziert werden.
        _adminBiometricVerifiedUid = null;
        _adminUseAuthenticatorFallback = false;
        _adminOtpErrorText = null;
        _adminOtpChecking = false;
      });
      _clearAdminOtpInput();
      if (newRole == 'DJ') {
        await NavigationService().persistAdminViewRole(newRole);
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Bereits verifiziert -> sofort umschalten.
    if (_adminBiometricVerifiedUid == user.uid) {
      if (!mounted) return;
      setState(() {
        wantsAdminView = true;
        _currentViewRole = 'Admin';
      });
      await NavigationService().persistAdminViewRole('Admin');
      return;
    }

    // Zielgerichteter Sicherheits-Flow nur für Admin.
    if (!mounted) return;
    final previousRole = _currentViewRole;
    setState(() {
      wantsAdminView = true;
      _adminUseAuthenticatorFallback = false;
      _adminOtpErrorText = null;
      _adminOtpChecking = false;
    });
    _clearAdminOtpInput();
    final verified = await _runAdminBiometricGatePostFrame(
      user,
      signOutOnFailure: false,
    );
    if (!verified && !_adminUseAuthenticatorFallback && mounted) {
      setState(() {
        wantsAdminView = false;
        _currentViewRole = previousRole ?? 'DJ';
      });
    }
  }

  static const Duration _profileLoadTimeoutDuration = Duration(seconds: 20);

  void _cancelProfileLoadTimeout() {
    _profileLoadTimeoutTimer?.cancel();
    _profileLoadTimeoutTimer = null;
    _profileLoadTimeoutTimerStarted = false;
  }

  void _startProfileLoadTimeout() {
    if (_profileLoadTimeoutTimerStarted) return;
    _profileLoadTimeoutTimerStarted = true;
    _profileLoadTimeoutTimer = Timer(_profileLoadTimeoutDuration, () {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser == null) return;
      if (UserService().currentUser.value != null)
        return; // Dokument inzwischen da
      setState(() {
        _profileLoadTimeoutReached = true;
        _profileLoadTimeoutTimerStarted = false;
      });
    });
  }

  /// Einmal-Migration: Cloud Function `massVerifyExistingUsers` (nur sichtbar mit
  /// `--dart-define=MASS_VERIFY_TRIGGER=true` und UID == [AppConfig.adminDjId]).
  /// Block nach erfolgreichem Lauf optional aus `main_main_page.dart` entfernen.
  Future<void> _runMassVerifyExistingUsersMigration() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final allowed = AppConfig.adminDjId;
    if (!AppConfig.massVerifyTriggerEnabled ||
        uid == null ||
        allowed == null ||
        uid != allowed) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(loc.email_migration_title),
          content: Text(loc.mass_verify_dialog_body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.email_migration_run),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 24),
                Expanded(child: Text(loc.email_migration_running)),
              ],
            ),
          ),
        );
      },
    );

    try {
      final r = await AdminService.instance.massVerifyExistingUsers();
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.mass_verify_snackbar_result(
              r.verifiedCount,
              r.scannedCount,
              r.errorCount,
            ),
          ),
          duration: const Duration(seconds: 10),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.email_migration_failed} ${e.code} – ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.email_migration_failed} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _triggerLogout() async {
    if (_logoutTriggered) return;
    _logoutTriggered = true;
    _cancelProfileLoadTimeout();
    if (!mounted) return;
    // Ladekreis sofort beenden, damit die App nicht einfriert (bei Nutzung von EasyLoading: EasyLoading.dismiss())
    setState(() {});
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.logout_profile_verify_failed),
          backgroundColor: Colors.red,
        ),
      );
      await SubscriptionSyncService.logOut();
      UserService().stopUserStream();
      UserService().clearCache();
      ProFeatureGuard.invalidateCache();
      await SavedLoginEmailStore.clear();
      await FirebaseAuth.instance.signOut();
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _onNavigationTabChanged() {
    if (mounted) setState(() {});
  }

  void _onIndexChanged(int newIndex) {
    final oldIndex = _currentIndex;
    NavigationService().setTabIndex(newIndex);

    // Wenn zur Home-Seite gewechselt wird (Index 0), lade alle Statistiken neu
    if (newIndex == 0) {
      // Warte kurz, damit die HomePage vollständig geladen ist
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Finde die HomePage im Widget-Tree und lade Statistiken neu
          final homePageState = _homePageKey.currentState;
          if (homePageState != null) {
            homePageState.loadUserData();
          }
        }
      });
    }

    // Wenn die Offen-Seite verlassen wird (Index 2 -> etwas anderes)
    // Speichere alle aktuell angezeigten Wunsch-IDs synchron als "gesehen"
    if (oldIndex == 2 && newIndex != 2) {
      final visibleIds =
          _offenPageKey.currentState?.getCurrentVisibleIds() ?? [];
      if (visibleIds.isNotEmpty) {
        // Synchron zum Set hinzufügen (kein await, blockiert nicht)
        ActivePartyService.seenWishIds.addAll(visibleIds);

        // Speichere im Hintergrund (Fire-and-Forget, kein await)
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Hole Party-Info asynchron und speichere dann
          ActivePartyService.getActivePartyInfoStream(user.uid).first
              .then((partyInfo) {
                if (partyInfo != null && partyInfo.partyId.isNotEmpty) {
                  // Speichere ohne await (Fire-and-Forget)
                  ActivePartyService.saveSeenWishIds(
                    partyInfo.partyId,
                  ).catchError((e) {
                    debugLog('⚠️ Fehler beim Speichern der SeenWishIds: $e');
                  });
                }
              })
              .catchError((e) {
                debugLog('⚠️ Fehler beim Abrufen der Party-Info: $e');
              });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugLog(
        '🔐 MainPage: initState – uid=${FirebaseAuth.instance.currentUser?.uid ?? "null"}',
      );
    }
    // Vor main()-Hydration war Tab/Admin-View ein Race; jetzt kommt alles aus NavigationService (synchroner Cache).
    _currentViewRole = NavigationService().cachedAdminViewRole;
    WidgetsBinding.instance.addObserver(this);
    NavigationService().currentTabIndex.addListener(_onNavigationTabChanged);
    _previousUser = FirebaseAuth.instance.currentUser;
    _adminAuthRequiredAfterLogin = _previousUser != null;

    // Zentraler User-Stream: bei Änderung (z. B. role_id) Rollenname laden
    UserService().currentUser.addListener(_onUserModelChanged);
    UserService().trialExpiryPromptNotifier.addListener(
      _onTrialExpiryPromptNotifier,
    );
    _onUserModelChanged();

    _lastRegistrationGuard = RegistrationFlowGuard.isRegistering.value;
    RegistrationFlowGuard.isRegistering.addListener(
      _onRegistrationFlowGuardChanged,
    );

    // Höre auf Auth-Änderungen (distinct nach UID: kein Token-Refresh-Spam → weniger Rebuilds/Timer).
    // Hinweis: initState läuft nur bei neuer State-Instanz; Auth distinct nach UID reduziert unnötige Rebuilds.
    debugLog('🔐 MainPage: registriere authStateChanges');
    _authSubscription = authStateChangesDistinctByUid().listen((user) {
      if (!mounted) return;

      final prev = _previousUser;
      // Nur UID / An-/Abmeldung – keine E-Mail-Vergleiche (bei Resume/Token können die falsch triggern).
      final loggedInChanged = (prev == null) != (user == null);
      final uidChanged = prev != null && user != null && prev.uid != user.uid;
      final accountSwitched = loggedInChanged || uidChanged;

      if (accountSwitched) {
        debugLog(
          '🔐 MainPage: auth – Login/Account gewechselt',
        );
        if (user != null && RegistrationFlowGuard.isRegistering.value) {
          debugLog(
            '🔐 MainPage: Registrierungs-Gate aktiv — überspringe Tab/Cold-Start bis Gate end()',
          );
          _previousUser = user;
          return;
        }
        if (user != null) {
          debugLog(
            '🔐 MainPage: Account-Wechsel / Login – Tab auf Start, Cold-Start-Dienste',
          );
          NavigationService().setTabIndex(0);
          setState(() {
            _previousUser = user;
            _logoutTriggered = false;
            _profileLoadTimeoutReached = false;
            _cancelProfileLoadTimeout();
            _emailVerifiedFirestoreOverride = false;
            wantsAdminView = false;
            _adminAuthRequiredAfterLogin = true;
            _adminBiometricVerifiedUid = null;
            _adminUseAuthenticatorFallback = false;
            _adminOtpSecretFromFirestore = null;
            _adminOtpErrorText = null;
            _adminOtpChecking = false;
          });
          _clearAdminOtpInput();
          _runColdStartServicesForUser(user);
          _kickPartyAutostart();
        } else {
          debugLog('🔐 MainPage: Logout – Dienste stoppen, Tab auf Start');
          SubscriptionSyncService.logOut();
          PartyAutostartService().dispose();
          NavigationService().resetToHome();
          unawaited(NavigationService().clearAdminViewRole());
          setState(() {
            _previousUser = null;
            _appColdStartDoneUid = null;
            _currentWishesList = [];
            _logoutTriggered = false;
            _profileLoadTimeoutReached = false;
            _cancelProfileLoadTimeout();
            _lastUserModelForUi = null;
            _emailVerifiedFirestoreOverride = false;
            wantsAdminView = false;
            _adminAuthRequiredAfterLogin = false;
            _adminBiometricVerifiedUid = null;
            _adminBiometricCheckInProgress = false;
            _adminUseAuthenticatorFallback = false;
            _adminOtpSecretFromFirestore = null;
            _adminOtpErrorText = null;
            _adminOtpChecking = false;
            // Nach Abmeldung (z. B. von Verify-Email): Login-Tab zeigt Anmeldung + Party-Code, nicht Registrierung
            _guestAuthStartInRegister = false;
          });
          _clearAdminOtpInput();
        }
      } else {
        _previousUser = user;
      }

      _setupNewWishesTimer(user);
    });

    // Kaltstart mit bestehender Session: gleiche Dienste wie Login-Pfad, aber nur einmal pro UID.
    final previousUser = _previousUser;
    if (previousUser != null) {
      debugLog(
        '🔐 MainPage: Kaltstart mit Session (${previousUser.uid}) – Cold-Start-Dienste falls nötig',
      );
      _runColdStartServicesForUser(previousUser);
      _kickPartyAutostart();
    } else {
      // Beim App-Start ohne Session immer auf Landing/Home bleiben (kein direkter Login-Tab).
      NavigationService().setTabIndex(0, force: true);
    }

    // Initial Timer-Setup
    _setupNewWishesTimer(_previousUser);

    // Berechtigungen (Notification, Batterie) werden NUR im DJ-Bereich nach Login angefragt – siehe _requestDjPermissionsIfNeeded()

    // Initialisiere Deep Link-Verarbeitung
    _initDeepLinks();
    _initRecognitionNotificationRouting();

    // Prüfe beim Start auf gespeicherten Party-Code
    _checkForStoredPartyCode();

    // Initialisiere AnimationController für AppBar-Effekte
    _glowAnimationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _glowAnimationController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_migrateDjSpotifyMasterOnlyTabIndex());
      unawaited(_migrateDjSpotifyTabIndex());
    });
  }

  /// [SpotifyPage] nur in Admin-Shell: bei DJ-Shell fehlt Tab 5 — gespeicherten Index einmal anpassen.
  Future<void> _migrateDjSpotifyMasterOnlyTabIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('dj_spotify_filter_removed_from_dj_shell_v1') == true) {
        return;
      }
      if (FirebaseAuth.instance.currentUser?.uid == null) return;

      final isRealAdmin = AppConfig.isAdminRole(UserService().currentUser.value);
      final inAdminShell =
          isRealAdmin &&
          (_currentViewRole == null || _currentViewRole == 'Admin');
      if (inAdminShell) {
        await prefs.setBool('dj_spotify_filter_removed_from_dj_shell_v1', true);
        return;
      }

      final roleName = _currentRoleName;
      if (roleName == null) return;
      if (roleName != 'DJ' &&
          roleName != 'Location' &&
          roleName != 'Admin') {
        await prefs.setBool('dj_spotify_filter_removed_from_dj_shell_v1', true);
        return;
      }
      final i = NavigationService().currentTabIndex.value;
      var newIndex = i;
      if (i == 5) {
        newIndex = 4;
      } else if (i > 5) {
        newIndex = i - 1;
      }
      if (newIndex != i) {
        NavigationService().setTabIndex(newIndex, force: true);
      }
      await prefs.setBool('dj_spotify_filter_removed_from_dj_shell_v1', true);
    } catch (_) {}
  }

  /// Einmalig nach Einführung der Spotify-Seite im DJ-Menü: alter Tab 5–8 → 6–9.
  Future<void> _migrateDjSpotifyTabIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('dj_spotify_tab_migrated_v1') == true) return;
      if (NavigationService().cachedAdminViewRole != 'DJ') {
        await prefs.setBool('dj_spotify_tab_migrated_v1', true);
        return;
      }
      final i = NavigationService().currentTabIndex.value;
      if (i >= 5 && i <= 8) {
        NavigationService().setTabIndex(i + 1, force: true);
      }
      await prefs.setBool('dj_spotify_tab_migrated_v1', true);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_syncNotificationLocaleStrings());
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    // Erzwingt sofortige Neubewertung beim System-Locale-Event.
    _lastNotificationLocaleTag = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncNotificationLocaleStrings());
    });
  }

  // Initialisiert die Deep Link-Verarbeitung
  void _initDeepLinks() {
    // Prüfe initialen Link (wenn App durch Deep Link geöffnet wurde)
    AppLinksService.instance.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Höre auf zukünftige Deep Links
    _linkSubscription = AppLinksService.instance.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugLog('Fehler beim Verarbeiten von Deep Links: $err');
      },
    );
  }

  void _initRecognitionNotificationRouting() {
    _recognitionNotificationTapSubscription?.cancel();
    _recognitionNotificationTapSubscription = ShazamService()
        .notificationNavigationStream
        .listen(_handleRecognitionNotificationTarget);

    ShazamService().consumePendingNavigationTarget().then((target) {
      if (target != null) {
        _handleRecognitionNotificationTarget(target);
      }
    });
  }

  void _handleRecognitionNotificationTarget(String target) {
    if (!mounted || target != 'history') return;
    final historyTabIndex = _resolveHistoryTabIndexForCurrentUser();
    NavigationService().setTabIndex(historyTabIndex, force: true);
  }

  int _resolveHistoryTabIndexForCurrentUser() {
    final uid = FirebaseAuth.instance.currentUser;
    final userModel = UserService().currentUser.value;
    final isRealAdmin = AppConfig.isAdminRole(userModel);
    final isAdminMode =
        isRealAdmin && (_currentViewRole == null || _currentViewRole == 'Admin');
    final roleName = _currentRoleName;
    final isDJMode =
        _currentViewRole == 'DJ' ||
        (uid != null &&
            (roleName == 'DJ' || roleName == 'Location') &&
            _currentViewRole != 'Admin');

    if (isAdminMode || isDJMode) return 4;
    if (uid == null) return 6;
    return 2;
  }

  /// Nur Ziffern, genau 8 Zeichen (sonst null).
  String? _eightDigitPartyCodeFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return null;
    return digits.substring(0, 8);
  }

  bool _isVibesboxWebHost(String host) {
    final h = host.toLowerCase();
    return h == 'vibesbox.app' || h == 'www.vibesbox.app';
  }

  /// Extrahiert den 8-stelligen Party-Code aus Web- oder Custom-Scheme-URLs.
  String? _extractPartyCodeFromDeepLink(Uri uri) {
    // vibesbox://party/[CODE] – erstes Pfadsegment
    if (uri.scheme == 'vibesbox' && uri.host == 'party') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final eight = _eightDigitPartyCodeFromRaw(segments.first);
        if (eight != null) return eight;
      }
    }

    // http(s)://vibesbox.app/... — Pfade z. B. /vb/p/12345678, /p/12345678, ?code=
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        _isVibesboxWebHost(uri.host)) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      for (var i = 0; i < segments.length - 1; i++) {
        final seg = segments[i].toLowerCase();
        if (seg == 'p' || seg == 'party') {
          final eight = _eightDigitPartyCodeFromRaw(segments[i + 1]);
          if (eight != null) return eight;
        }
      }
      if (segments.isNotEmpty) {
        final eight = _eightDigitPartyCodeFromRaw(segments.last);
        if (eight != null) return eight;
      }
      final eight = _eightDigitPartyCodeFromRaw(uri.queryParameters['code']);
      if (eight != null) return eight;
    }

    // djwunschbox://wunschbox?code=
    if (uri.scheme == 'djwunschbox' && uri.host == 'wunschbox') {
      final eight = _eightDigitPartyCodeFromRaw(uri.queryParameters['code']);
      if (eight != null) return eight;
    }

    return null;
  }

  /// E-Mail-Verifizierung: [AppLinksService.tryApplyVerificationDeepLink] → `applyActionCode`.
  Future<bool> _tryHandleEmailVerificationDeepLink(Uri uri) async {
    try {
      final applied =
          await AppLinksService.instance.tryApplyVerificationDeepLink(uri);
      if (!applied) return false;
      if (!mounted) return true;
      final l = AppLocalizations.of(context)!;
      final loc = l;
      if (loc != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => EmailVerificationResultDialog(
            isSuccess: true,
            statusText: loc.verify_success_title,
            instructionText: loc.verify_success_instruction,
            okLabel: loc.ok,
            onDismiss: () => Navigator.of(ctx).pop(),
          ),
        );
      }
      // Ohne setState bleibt die UI ggf. auf der Verify-Seite: authStateChangesDistinctByUid()
      // filtert gleiche UIDs, ein Rebuild nach reload() erfolgt sonst oft nicht.
      if (mounted) setState(() {});
    } on FirebaseAuthException catch (e, st) {
      debugLog('E-Mail-Verifizierung Deep Link: $e\n$st');
      if (!mounted) return true;
      final loc = AppLocalizations.of(context)!;
      if (loc != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => EmailVerificationResultDialog(
            isSuccess: false,
            statusText: loc.verify_error_title,
            instructionText: loc.verify_error_instruction_login,
            okLabel: loc.ok,
            onDismiss: () => Navigator.of(ctx).pop(),
          ),
        );
      }
    } catch (e, st) {
      debugLog('E-Mail-Verifizierung Deep Link: $e\n$st');
      if (!mounted) return true;
      final loc = AppLocalizations.of(context)!;
      if (loc != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => EmailVerificationResultDialog(
            isSuccess: false,
            statusText: loc.verify_error_title,
            instructionText: loc.verify_error_instruction_login,
            okLabel: loc.ok,
            onDismiss: () => Navigator.of(ctx).pop(),
          ),
        );
      }
    }
    return true;
  }

  /// Beim Resume: gepufferten `/verify?oobCode=`‑Link verarbeiten (nur Verifizierung, keine Party-URLs).
  Future<void> _tryConsumeVerifyDeepLinkOnResume() async {
    if (!mounted) return;
    final cu = FirebaseAuth.instance.currentUser;
    if (cu != null && cu.emailVerified) return;
    try {
      final uri = await AppLinksService.instance.getLatestLink();
      if (uri == null) return;
      if (!AuthService.uriLooksLikeAppEmailVerification(uri)) return;
      await _tryHandleEmailVerificationDeepLink(uri);
    } catch (e, st) {
      debugLog('Verifizierung Resume-Link: $e\n$st');
    }
  }

  // Verarbeitet einen Deep Link
  Future<void> _handleDeepLink(Uri uri) async {
    if (await _tryHandleEmailVerificationDeepLink(uri)) return;

    debugLog('Deep Link erhalten: $uri');

    // vibesbox://auth/login?action=verified|password_reset — zurück zur Anmeldung (Party-Code bleibt in Prefs)
    if (uri.scheme == 'vibesbox' && uri.host == 'auth') {
      final p = uri.path.toLowerCase();
      if (p == '/login' || p.endsWith('/login')) {
        await PartySessionService.instance.loadFromPrefs();
        if (!mounted) return;
        NavigationService().setTabIndex(1, force: true);
        return;
      }
    }

    final partyCode = _extractPartyCodeFromDeepLink(uri);
    if (partyCode == null || partyCode.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() => _partyDeepLinkLoading = true);
    }
    await PartySessionService.instance.persistPendingPartyCode(partyCode);

    final uid = FirebaseAuth.instance.currentUser;

    // Nicht eingeloggt: Party-Code nur merken → Login mit vorbefülltem Feld
    if (uid == null) {
      if (mounted) {
        setState(() {
          _partyDeepLinkLoading = false;
          _guestAuthPartyLinkNonce++;
        });
        NavigationService().setTabIndex(1, force: true);
      }
      return;
    }

    try {
      final feedback =
          await PartySessionService.instance.validateAndJoinParty(partyCode);
      if (!mounted) return;

      final userModel = UserService().currentUser.value;
      final isRealAdmin = AppConfig.isAdminRole(userModel);
      final isAdminMode =
          isRealAdmin &&
          (_currentViewRole == null || _currentViewRole == 'Admin');
      final roleName = _currentRoleName;
      final isDJMode =
          _currentViewRole == 'DJ' ||
          (uid != null &&
              (roleName == 'DJ' || roleName == 'Location') &&
              _currentViewRole != 'Admin');
      final int partyTabIndex;
      if (isAdminMode || isDJMode) {
        partyTabIndex = 2;
      } else {
        partyTabIndex = 1;
      }

      if (feedback == null) {
        setState(() {
          _guestPartyJoinCount++;
          _partyDeepLinkLoading = false;
        });
        NavigationService().setTabIndex(partyTabIndex, force: true);
      } else {
        setState(() => _partyDeepLinkLoading = false);
        NavigationService().setTabIndex(0, force: true);
      }
    } catch (e, st) {
      debugLog('Deep-Link validateAndJoinParty: $e\n$st');
      if (mounted) {
        setState(() => _partyDeepLinkLoading = false);
        NavigationService().setTabIndex(0, force: true);
      }
    }
  }

  // Prüft beim App-Start, ob ein Party-Code gespeichert wurde
  Future<void> _checkForStoredPartyCode() async {
    try {
      // Party-Code sollte bereits über Deep Link gesetzt sein
      // Falls die App ohne Deep Link gestartet wurde, prüfe SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedCode = prefs.getString('party_code');
      if (storedCode != null && storedCode.isNotEmpty) {
        debugLog(
          'Gespeicherter Party-Code in Prefs: $storedCode (kein Tab-Zwang – früherer setTabIndex(0) hat Admin/DJ von VibesBox zurück auf Startseite geschoben)',
        );
        // Kein setTabIndex hier: Der alte Code hat bei jedem MainPage-init bei Index≠0 auf Tab 0 erzwungen
        // (Admin-Startseite) und widersprach dem Kommentar „Wunschbox“. Tab kommt aus persistiertem Index.
      }
    } catch (e) {
      debugLog('Fehler beim Prüfen des gespeicherten Party-Codes: $e');
    }
  }

  Future<void> _tryAutoJoinStoredPartyForGuest({bool force = false}) async {
    if (_autoJoinStoredPartyRunning) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!user.emailVerified && !_emailVerifiedFirestoreOverride) return;
    if (_currentRoleName != 'Gast') return;

    final prefs = await SharedPreferences.getInstance();
    final storedCode = prefs.getString('party_code');
    if (storedCode == null || storedCode.trim().isEmpty) return;

    final key = '${user.uid}:${storedCode.trim()}';
    if (!force && _lastAutoJoinStoredPartyKey == key) return;
    _lastAutoJoinStoredPartyKey = key;

    _autoJoinStoredPartyRunning = true;
    try {
      final feedback = await PartySessionService.instance.validateAndJoin(
        storedCode,
      );
      if (!mounted) return;
      if (feedback == null) {
        setState(() {
          _guestPartyJoinCount++;
        });
        NavigationService().setTabIndex(1, force: true);
      }
    } catch (_) {
      // Kein aggressives Error-UI beim stillen Auto-Join
    } finally {
      _autoJoinStoredPartyRunning = false;
    }
  }

  /// Wird nur nach erfolgreichem Login im DJ-Bereich aufgerufen (einmal pro Session).
  /// Fragt Notification- und Batterie-Optimierungs-Berechtigung an; Erklär-Dialoge: schwarzer Hintergrund, orange Rahmen.
  Future<void> _requestDjPermissionsIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    final roleName = _currentRoleName;
    final isDj =
        roleName == 'DJ' || roleName == 'Location' || roleName == 'Admin';
    if (!isDj) return;

    if (Platform.isAndroid) {
      // 1) Notification-Berechtigung (z. B. Android 13+)
      final notificationStatus = await Permission.notification.status;
      if (notificationStatus.isDenied) {
        if (!mounted) return;
        await _showNotificationPermissionDialog();
        await Permission.notification.request();
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      // 2) Batterie-Optimierung
      await _checkBatteryOptimization();
    }
  }

  /// Erklär-Dialog für Benachrichtigungs-Berechtigung (Design: schwarzer Hintergrund, orange Rahmen)
  Future<void> _showNotificationPermissionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final loc = AppLocalizations.of(dialogContext)!;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 1.5),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.notification_permission_title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.notification_permission_body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        loc.laterButton,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(loc.permission_allow),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Prüft, ob die Batterie-Optimierung aktiviert ist und zeigt einen Dialog (nur aufgerufen aus _requestDjPermissionsIfNeeded)
  Future<void> _checkBatteryOptimization() async {
    if (_batteryOptimizationChecked) return;

    try {
      if (Platform.isAndroid) {
        final isIgnoring =
            await _batteryChannel.invokeMethod<bool>(
              'isIgnoringBatteryOptimizations',
            ) ??
            true;

        if (!isIgnoring && mounted) {
          _batteryOptimizationChecked = true;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) _showBatteryOptimizationDialog();
          });
        }
      }
    } catch (e) {
      debugLog('Fehler beim Prüfen der Batterie-Optimierung: $e');
    }
  }

  /// Erklär-Dialog für Batterie-Optimierung (Design: schwarzer Hintergrund, orange Rahmen)
  void _showBatteryOptimizationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final loc = AppLocalizations.of(dialogContext)!;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 1.5),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.battery_opt_dialog_title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.battery_opt_dialog_body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        loc.laterButton,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _requestIgnoreBatteryOptimizations();
                      },
                      child: Text(loc.permission_open_settings),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Öffnet die Einstellungen, um die Batterie-Optimierung zu deaktivieren
  Future<void> _requestIgnoreBatteryOptimizations() async {
    try {
      if (Platform.isAndroid) {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (e) {
      debugLog('Fehler beim Öffnen der Batterie-Optimierungs-Einstellungen: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.battery_settings_open_failed),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final user = FirebaseAuth.instance.currentUser;
    // Im DJ-Modus keine Admin-Timer (spart Akku)
    final isRealAdmin = AppConfig.isAdminRole(UserService().currentUser.value);
    final isAdminMode =
        isRealAdmin &&
        (_currentViewRole == null || _currentViewRole == 'Admin');

    debugLog('📱 App Lifecycle State geändert: $state');

    if (state == AppLifecycleState.resumed) {
      // App ist wieder im Vordergrund - Timer sollte laufen
      debugLog('✅ App ist im Vordergrund - Timer wird gestartet');
      unawaited(_tryConsumeVerifyDeepLinkOnResume());
      unawaited(ActivePartyService.refreshPartyTruthOnResume());
      unawaited(PartyAutostartService().reconcileAfterResume());
      if (isAdminMode) {
        _setupNewWishesTimer(user);
      }
      if (user != null && _currentRoleName == 'Gast') {
        unawaited(_tryAutoJoinStoredPartyForGuest(force: true));
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App ist im Hintergrund - stoppe Stream um Ressourcen zu sparen
      debugLog('⏸️ App ist im Hintergrund - stoppe Stream zur Ressourcenschonung');
      // Im DJ-Modus keine Admin-Streams (spart Akku)
      final isRealAdmin = AppConfig.isAdminRole(
        UserService().currentUser.value,
      );
      final isAdminMode =
          isRealAdmin &&
          (_currentViewRole == null || _currentViewRole == 'Admin');
      if (isAdminMode) {
        // Stoppe Stream wenn App in den Hintergrund geht
        _wishesStreamSubscription?.cancel();
        _wishesStreamSubscription = null;
        // Prüfe einmalig auf neue Wünsche (für Push-Benachrichtigung)
        _checkNewWishes();
        // Stelle sicher, dass Stream weiterläuft (wird nicht gestoppt)
        // Stream sollte weiterlaufen, aber prüfe ob er noch aktiv ist
        if (_wishesStreamSubscription == null) {
          debugLog('⚠️ Stream war nicht aktiv - starte neu');
          _setupNewWishesTimer(user);
        } else {
          debugLog('✅ Stream läuft weiter im Hintergrund');
        }
      }
    } else if (state == AppLifecycleState.detached) {
      // App wird beendet - Timer wird automatisch gestoppt
      debugLog('🛑 App wird beendet');
    }
  }

  void _setupNewWishesTimer(User? user) {
    _newWishesCheckTimer?.cancel();
    _wishesStreamSubscription?.cancel();
    // Im DJ-Modus keine Admin-Streams (spart Akku)
    final isRealAdmin = AppConfig.isAdminRole(UserService().currentUser.value);
    final isAdminMode =
        isRealAdmin &&
        (_currentViewRole == null || _currentViewRole == 'Admin');
    if (isAdminMode) {
      final currentState = WidgetsBinding.instance.lifecycleState;
      final isActive = currentState == AppLifecycleState.resumed;
      debugLog('⏰ Stream für neue Wünsche wird gestartet');
      debugLog('   App-Status: $currentState (Aktiv: $isActive)');

      // Nur starten wenn App aktiv ist (resumed) und gültige UID vorhanden
      if (isActive) {
        if (user == null) {
          debugLog('⏸️ Kein User – Stream für neue Wünsche wird nicht gestartet');
          return;
        }
        final uid = user.uid;
        // Sofort prüfen (nur einmal beim Start)
        _checkNewWishes();
        // Verwende Stream statt Timer - aktualisiert automatisch bei Änderungen
        // WICHTIG: Filtere auch nach party_id für die aktive Party
        ActivePartyService.getActivePartyInfo(uid)
            .then((partyInfo) {
              final partyId = partyInfo?.partyId;
              if (partyId != null && partyId.isNotEmpty) {
                debugLog('🔍 Stream-Check: Filtere nach party_id: $partyId');
                final query = FirebaseFirestore.instance
                    .collection('wishes')
                    .where('party_id', isEqualTo: partyId)
                    .where('status', isEqualTo: 'pending');
                _wishesStreamSubscription = query.snapshots().listen(
                  (snapshot) {
                    // Prüfe App-Status vor Verarbeitung - verhindert unnötige Last im Hintergrund
                    final currentStateCheck =
                        WidgetsBinding.instance.lifecycleState;
                    if (currentStateCheck == AppLifecycleState.resumed) {
                      // Stream aktualisiert automatisch - prüfe nur auf neue Wünsche
                      _checkNewWishesFromStream(snapshot);
                    } else {
                      debugLog(
                        '⏸️ App im Hintergrund (Status: $currentStateCheck) - überspringe Stream-Update',
                      );
                    }
                  },
                  onError: (error) {
                    debugLog('❌ Fehler im Wünsche-Stream: $error');
                  },
                  cancelOnError: false,
                );
                debugLog(
                  '✅ Stream gestartet - aktualisiert automatisch bei Änderungen (nur wenn App aktiv)',
                );
              } else {
                debugLog(
                  '⚠️ Stream-Check: Keine party_id – kein Wünsche-Stream (Security Rules verlangen party_id-Filter)',
                );
                _wishesStreamSubscription?.cancel();
                _wishesStreamSubscription = null;
              }
            })
            .catchError((e) {
              debugLog('❌ Fehler beim Holen der Party-Info für Stream: $e');
            });
      } else {
        debugLog(
          '⏸️ App nicht aktiv (Status: $currentState) - Stream wird nicht gestartet',
        );
        // Stoppe Stream wenn vorhanden
        _wishesStreamSubscription?.cancel();
        _wishesStreamSubscription = null;
      }
    }
  }

  Future<void> _checkNewWishes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !AppConfig.isAdminRole(UserService().currentUser.value))
      return;

    final appState = WidgetsBinding.instance.lifecycleState;
    debugLog('🔍 Prüfe auf neue Wünsche... (App-Status: $appState)');
    try {
      // Lade letzten "gesehen" Timestamp
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final lastViewed = userDoc.data()?['last_viewed_wishes_at'] as Timestamp?;
      DateTime lastViewedTime;

      if (lastViewed != null) {
        lastViewedTime = lastViewed.toDate();
        debugLog('📅 Last viewed time: $lastViewedTime');
      } else {
        // Beim ersten Start (nach Neuinstallation): Setze aktuellen Zeitpunkt
        // Damit werden nur Wünsche nach dem App-Start als "neu" erkannt
        debugLog(
          '⚠️ Kein last_viewed_wishes_at gefunden - setze aktuellen Zeitpunkt',
        );
        lastViewedTime = DateTime.now();
        debugLog('📅 Last viewed time (neu gesetzt): $lastViewedTime');
        // Speichere den aktuellen Zeitpunkt in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'last_viewed_wishes_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Zähle neue Wünsche (pending, erstellt nach lastViewedTime)
      // WICHTIG: Filtere auch nach party_id für die aktive Party
      final partyInfo = await ActivePartyService.getActivePartyInfo(user.uid);
      final partyId = partyInfo?.partyId;

      Query query;
      if (partyId != null && partyId.isNotEmpty) {
        debugLog('🔍 Hintergrund-Check: Filtere nach party_id: $partyId');
        query = FirebaseFirestore.instance
            .collection('wishes')
            .where('party_id', isEqualTo: partyId)
            .where('status', isEqualTo: 'pending');
      } else {
        debugLog(
          '⚠️ Hintergrund-Check: Keine party_id – überspringe Abfrage (Security Rules verlangen party_id-Filter)',
        );
        return; // Keine Query ohne party_id (permission-denied)
      }

      final snapshot = await query.get();

      // Filtere clientseitig: nur Wünsche nach lastViewedTime und keine Duplikate
      // WICHTIG: Im Hintergrund verwenden wir eine kleine Toleranz (5 Sekunden),
      // um auch Wünsche zu erfassen, die kurz vor dem Minimieren erstellt wurden
      final isBackground =
          appState == AppLifecycleState.paused ||
          appState == AppLifecycleState.inactive;
      final tolerance = isBackground
          ? const Duration(seconds: 5)
          : Duration.zero; // Im Vordergrund: Keine Toleranz

      final adjustedLastViewedTime = lastViewedTime.subtract(tolerance);

      // Zuerst: Finde alle neuen Wünsche (nach lastViewedTime, keine Duplikate)
      // Diese werden für die Badge-Anzeige verwendet
      final allNewWishes = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

        final isNotDuplicate = data['is_duplicate'] != true;
        final isAfterLastViewed = created.isAfter(adjustedLastViewedTime);

        return isNotDuplicate && isAfterLastViewed;
      }).toList();

      // Zähle alle neuen Wünsche für die Badge-Anzeige
      final newWishesCount = allNewWishes.length;

      // Dann: Filtere nur die, die noch nicht per Push benachrichtigt wurden
      // Diese werden für die Push-Benachrichtigung verwendet
      // WICHTIG: Ignoriere die Markierung, wenn der Wunsch nach _lastNotifiedWishTime erstellt wurde
      final newWishesForNotification = allNewWishes.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

        final isNotNotified =
            data['notified_via_push'] !=
            true; // Noch nicht per Push benachrichtigt

        // Wenn _lastNotifiedWishTime gesetzt ist, prüfe ob der Wunsch danach erstellt wurde
        // Wenn ja, ignoriere die Markierung (sie könnte falsch sein)
        if (_lastNotifiedWishTime != null &&
            created.isAfter(
              _lastNotifiedWishTime!.subtract(
                const Duration(milliseconds: 100),
              ),
            )) {
          // Wunsch wurde nach _lastNotifiedWishTime erstellt - behandle als nicht benachrichtigt
          return true;
        }

        return isNotNotified;
      }).toList();

      // Debug-Logs für Hintergrund-Modus
      // (isBackground wurde bereits oben deklariert)
      if (isBackground) {
        debugLog('🔍 Hintergrund-Prüfung:');
        debugLog('   Last viewed: $lastViewedTime');
        debugLog('   Toleranz: ${tolerance.inSeconds}s');
        debugLog('   Adjusted last viewed: $adjustedLastViewedTime');
        debugLog('   Aktuelle Zeit: ${DateTime.now()}');
        debugLog('   Gefilterte neue Wünsche: $newWishesCount');
        if (snapshot.docs.isNotEmpty) {
          // Finde den neuesten Wunsch (nicht nur den ersten)
          DateTime? newestCreated;
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final tsCreated = data['createdAt'] as Timestamp?;
            if (tsCreated != null) {
              final created = tsCreated.toDate();
              if (newestCreated == null || created.isAfter(newestCreated)) {
                newestCreated = created;
              }
            }
          }
          if (newestCreated != null) {
            debugLog('   Neuester Wunsch in DB: $newestCreated');
            final diff = newestCreated.difference(adjustedLastViewedTime);
            debugLog(
              '   Zeitdifferenz zum adjusted last viewed: ${diff.inMilliseconds}ms',
            );
          }
        }
      }

      // Prüfe, ob es wirklich neue Wünsche gibt
      if (allNewWishes.isNotEmpty) {
        // Finde den neuesten Wunsch (mit Titel und Interpret) aus ALLEN neuen Wünschen
        // (nicht nur aus denen, die noch nicht benachrichtigt wurden)
        DateTime? newestWishTime;
        String? newestWishTitle;
        String? newestWishArtist;
        QueryDocumentSnapshot? newestWishDoc;

        for (final doc in allNewWishes) {
          final data = doc.data() as Map<String, dynamic>;
          final tsCreated = data['createdAt'];
          final created = tsCreated is Timestamp
              ? tsCreated.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          if (newestWishTime == null || created.isAfter(newestWishTime)) {
            newestWishTime = created;
            newestWishTitle = data['title'] as String?;
            newestWishArtist = data['artist'] as String?;
            newestWishDoc = doc;
          }
        }

        // Finde den neuesten Wunsch aus den noch nicht benachrichtigten (für die Benachrichtigung)
        DateTime? newestNotifiedWishTime;
        String? newestNotifiedWishTitle;
        String? newestNotifiedWishArtist;

        for (final doc in newWishesForNotification) {
          final data = doc.data() as Map<String, dynamic>;
          final tsCreated = data['createdAt'];
          final created = tsCreated is Timestamp
              ? tsCreated.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          if (newestNotifiedWishTime == null ||
              created.isAfter(newestNotifiedWishTime)) {
            newestNotifiedWishTime = created;
            newestNotifiedWishTitle = data['title'] as String?;
            newestNotifiedWishArtist = data['artist'] as String?;
          }
        }

        // Sende Benachrichtigung nur, wenn es wirklich neue Wünsche gibt
        // (die nach dem letzten benachrichtigten Zeitpunkt erstellt wurden)
        // WICHTIG: Benachrichtige, wenn der neueste Wunsch NACH dem letzten benachrichtigten Zeitpunkt liegt
        // Verwende eine Toleranz von 500ms, um Rundungsfehler zu vermeiden
        // Wenn die App im Hintergrund ist, benachrichtige auch bei kleineren Unterschieden
        // (isBackground wurde bereits oben deklariert)

        // Entscheidungslogik für Benachrichtigung:
        // Wenn es neue Wünsche gibt, die noch nicht per Push benachrichtigt wurden, benachrichtige
        // Vergleiche mit _lastNotifiedWishTime, um sicherzustellen, dass es wirklich neue Wünsche sind
        bool shouldNotify = false;
        // Entscheidungslogik für Benachrichtigung:
        // Benachrichtige nur, wenn es Wünsche gibt, die noch nicht per Push benachrichtigt wurden
        // UND der neueste noch nicht benachrichtigte Wunsch nach _lastNotifiedWishTime liegt
        if (newWishesForNotification.isNotEmpty &&
            newestNotifiedWishTime != null) {
          if (_lastNotifiedWishTime == null) {
            // Erster Lauf: Immer benachrichtigen, wenn es neue Wünsche gibt
            shouldNotify = true;
            debugLog(
              '   ✅ Erster Lauf - benachrichtige (${newWishesForNotification.length} neue Wünsche)',
            );
          } else {
            // Prüfe, ob der neueste noch nicht benachrichtigte Wunsch nach dem letzten benachrichtigten Zeitpunkt liegt
            final diff = newestNotifiedWishTime.difference(
              _lastNotifiedWishTime!,
            );
            // Benachrichtigen nur, wenn der Wunsch wirklich neuer ist (mehr als 100ms später)
            // Dies verhindert, dass derselbe Wunsch mehrmals benachrichtigt wird
            shouldNotify =
                diff.inMilliseconds > 100; // > 100ms bedeutet wirklich später
            debugLog(
              '   ${isBackground ? "Hintergrund" : "Vordergrund"}: diff=${diff.inMilliseconds}ms, newWishesForNotification=${newWishesForNotification.length}, shouldNotify=$shouldNotify',
            );
          }
        } else {
          debugLog(
            '   ❌ Keine neuen Wünsche für Benachrichtigung: newWishesForNotification=${newWishesForNotification.length}, newestWishTime=$newestWishTime',
          );
          if (newWishesForNotification.isEmpty && allNewWishes.isNotEmpty) {
            debugLog(
              '   ⚠️ Alle ${allNewWishes.length} neuen Wünsche sind bereits als benachrichtigt markiert',
            );
          }
        }

        if (shouldNotify) {
          debugLog(
            '✅ Neue Wünsche gefunden: ${newWishesForNotification.length} (von $newWishesCount insgesamt) - sende Benachrichtigung',
          );
          debugLog('   Neuester Wunsch: $newestWishTime');
          debugLog(
            '   Letzter benachrichtigter Zeitpunkt: ${_lastNotifiedWishTime ?? "null"}',
          );
          debugLog('   App-Status: $appState (Hintergrund: $isBackground)');
          if (newestWishTime != null && _lastNotifiedWishTime != null) {
            final diff = newestWishTime.difference(_lastNotifiedWishTime!);
            debugLog('   Zeitdifferenz: ${diff.inMilliseconds}ms');
          }
          await _showNewWishNotification(
            newWishesForNotification.isNotEmpty
                ? newWishesForNotification.length
                : 1,
            newestNotifiedWishTitle ?? newestWishTitle,
            newestNotifiedWishArtist ?? newestWishArtist,
          );
          _lastNotifiedWishTime = newestNotifiedWishTime ?? newestWishTime;

          // Markiere NUR die Wünsche als "per Push benachrichtigt", die tatsächlich benachrichtigt wurden
          // WICHTIG: Nur markieren, wenn shouldNotify = true war und die Benachrichtigung gesendet wurde
          if (newWishesForNotification.isNotEmpty) {
            final batch = FirebaseFirestore.instance.batch();
            for (final doc in newWishesForNotification) {
              batch.update(doc.reference, {'notified_via_push': true});
            }
            await batch.commit();
            debugLog(
              '✅ ${newWishesForNotification.length} Wünsche als "per Push benachrichtigt" markiert',
            );
          } else {
            debugLog(
              '⚠️ Keine Wünsche zum Markieren (newWishesForNotification ist leer)',
            );
          }
        } else {
          debugLog('ℹ️ Keine neuen Wünsche oder bereits benachrichtigt');
          if (newestWishTime != null && _lastNotifiedWishTime != null) {
            final diff = newestWishTime.difference(_lastNotifiedWishTime!);
            debugLog('   Neuester Wunsch: $newestWishTime');
            debugLog(
              '   Letzter benachrichtigter Zeitpunkt: $_lastNotifiedWishTime',
            );
            debugLog('   Zeitdifferenz: ${diff.inMilliseconds}ms');
            if (isBackground) {
              debugLog('   (Im Hintergrund: Benachrichtigung bei >= 0ms)');
            } else {
              debugLog('   (Im Vordergrund: Benachrichtigung bei > 1000ms)');
            }
            debugLog('   App-Status: $appState (Hintergrund: $isBackground)');
          }
        }
      }

      if (mounted) {
        setState(() {
          _newWishesCount = newWishesCount;
        });
      }

      debugLog(
        '📊 Neue Wünsche: $newWishesCount (von ${snapshot.docs.length} pending Wünschen)',
      );
      debugLog('   Last viewed: $lastViewedTime');
    } catch (e) {
      debugLog('❌ Fehler beim Prüfen neuer Wünsche: $e');
    }
  }

  // Prüft neue Wünsche basierend auf Stream-Update (ohne setState für die gesamte Seite)
  Future<void> _checkNewWishesFromStream(QuerySnapshot snapshot) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !AppConfig.isAdminRole(UserService().currentUser.value))
      return;

    try {
      // Lade letzten "gesehen" Timestamp
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final lastViewed = userDoc.data()?['last_viewed_wishes_at'] as Timestamp?;
      DateTime lastViewedTime;

      if (lastViewed != null) {
        lastViewedTime = lastViewed.toDate();
      } else {
        lastViewedTime = DateTime.now();
      }

      // Zähle neue Wünsche (pending, erstellt nach lastViewedTime)
      final allNewWishes = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

        final isNotDuplicate = data['is_duplicate'] != true;
        final isAfterLastViewed = created.isAfter(lastViewedTime);

        return isNotDuplicate && isAfterLastViewed;
      }).toList();

      final newWishesCount = allNewWishes.length;

      // Prüfe auf neue Wünsche für Push-Benachrichtigungen
      final appState = WidgetsBinding.instance.lifecycleState;
      final isBackground =
          appState == AppLifecycleState.paused ||
          appState == AppLifecycleState.inactive;
      final tolerance = isBackground
          ? const Duration(seconds: 5)
          : Duration.zero;

      final adjustedLastViewedTime = lastViewedTime.subtract(tolerance);

      final newWishesForNotification = allNewWishes.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final tsCreated = data['createdAt'];
        final created = tsCreated is Timestamp
            ? tsCreated.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

        final isNotNotified = data['notified_via_push'] != true;

        if (_lastNotifiedWishTime != null &&
            created.isAfter(
              _lastNotifiedWishTime!.subtract(
                const Duration(milliseconds: 100),
              ),
            )) {
          return true;
        }

        return isNotNotified;
      }).toList();

      // Zeige Push-Benachrichtigung für neue Wünsche
      if (newWishesForNotification.isNotEmpty) {
        DateTime? newestWishTime;
        String? newestWishTitle;
        String? newestWishArtist;

        for (final doc in newWishesForNotification) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final tsCreated = data['createdAt'];
          final created = tsCreated is Timestamp
              ? tsCreated.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          if (newestWishTime == null || created.isAfter(newestWishTime)) {
            newestWishTime = created;
            newestWishTitle = data['title'] as String?;
            newestWishArtist = data['artist'] as String?;
          }
        }

        await _showNewWishNotification(
          newWishesCount,
          newestWishTitle,
          newestWishArtist,
        );

        // Markiere alle neuen Wünsche als benachrichtigt
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in newWishesForNotification) {
          batch.update(doc.reference, {'notified_via_push': true});
        }
        await batch.commit();

        _lastNotifiedWishTime = newestWishTime;
      }

      // Aktualisiere nur den Counter, wenn er sich geändert hat (verhindert unnötige Rebuilds)
      if (mounted && _newWishesCount != newWishesCount) {
        setState(() {
          _newWishesCount = newWishesCount;
        });
      }
    } catch (e) {
      debugLog('❌ Fehler beim Prüfen neuer Wünsche aus Stream: $e');
    }
  }

  // Zeigt eine Push-Benachrichtigung für neue Wünsche an
  Future<void> _showNewWishNotification(
    int count,
    String? wishTitle,
    String? wishArtist,
  ) async {
    try {
      final appState = WidgetsBinding.instance.lifecycleState;
      debugLog('🔔 Zeige Benachrichtigung für $count neue Wünsche an');
      debugLog('📱 App-Status: $appState');
      debugLog('   Benachrichtigung wird angezeigt (auch im Hintergrund)');

      // Titel der Benachrichtigung
      final title = count == 1
          ? 'Neuer Wunsch eingegangen!'
          : '$count neue Wünsche eingegangen!';

      // Body der Benachrichtigung: "Titel - Interpret"
      String body;
      if (wishTitle != null &&
          wishTitle.isNotEmpty &&
          wishArtist != null &&
          wishArtist.isNotEmpty) {
        body = '$wishTitle - $wishArtist';
      } else if (wishTitle != null && wishTitle.isNotEmpty) {
        body = wishTitle;
      } else if (wishArtist != null && wishArtist.isNotEmpty) {
        body = wishArtist;
      } else {
        body = 'Neuer Wunsch';
      }

      const androidDetails = AndroidNotificationDetails(
        'new_wishes_channel', // Channel-ID
        'Neue Wünsche', // Channel-Name
        channelDescription: 'Benachrichtigungen für neue Wünsche',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(
          'notification',
        ), // Eigener Warteton
        ongoing: false,
        autoCancel: true,
        visibility:
            NotificationVisibility.public, // Sichtbar auf Sperrbildschirm
        fullScreenIntent:
            false, // Wird auf Sperrbildschirm angezeigt, öffnet aber nicht Vollbild
        category: AndroidNotificationCategory.message,
        channelShowBadge: true,
        ticker:
            'Neuer Wunsch eingegangen!', // Text, der im Status-Bar angezeigt wird
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        0, // ID (0 = immer die neueste Benachrichtigung ersetzen)
        title,
        body,
        notificationDetails,
      );

      debugLog(
        '✅ Benachrichtigung erfolgreich angezeigt (mit Sound und Vibration)',
      );
    } catch (e) {
      debugLog('❌ Fehler beim Anzeigen der Benachrichtigung: $e');
    }
  }

  Future<void> _markWishesAsViewed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !AppConfig.isAdminRole(UserService().currentUser.value))
      return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'last_viewed_wishes_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Setze auch den letzten benachrichtigten Zeitpunkt zurück
      _lastNotifiedWishTime = null;

      if (mounted) {
        setState(() {
          _newWishesCount = 0;
        });
      }
    } catch (e) {
      debugLog('Fehler beim Markieren der Wünsche als gesehen: $e');
    }
  }

  /// Initialisiert den zentralen Wünsche-Service

  Future<void> _runAppUpdateCheck(BuildContext context) async {
    if (kDebugMode) return;
    if (_appUpdateCheckRunning) return;
    _appUpdateCheckRunning = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      bool isDJOrAdmin = false;
      if (user != null) {
        final roleName = await getUserRoleName(user);
        isDJOrAdmin =
            AppConfig.isAdminRole(UserService().currentUser.value) ||
            roleName == 'Admin' ||
            roleName == 'DJ' ||
            roleName == 'Location';
      }
      final r = await AppUpdateService.instance.checkForUpdate(
        isDJOrAdmin: isDJOrAdmin,
      );
      if (!mounted) return;
      if (r.result == UpdateCheckResult.forceUpdate ||
          r.result == UpdateCheckResult.optionalUpdate) {
        await AppUpdateService.showUpdateDialog(
          context: context,
          force: r.result == UpdateCheckResult.forceUpdate,
          availableVersion: r.currentVersion ?? r.minVersion ?? 'Neu',
          storeUrl: r.storeUrl ?? '',
        );
      }
    } catch (e) {
      debugLog('AppUpdateService Check Fehler: $e');
    } finally {
      _appUpdateCheckRunning = false;
    }
  }

  /// Nach [RegistrationFlowGuard.end]: einmal Cold-Start nachholen (war während Gate unterdrückt).
  void _onRegistrationFlowGuardChanged() {
    final registering = RegistrationFlowGuard.isRegistering.value;
    if (_lastRegistrationGuard && !registering && mounted) {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        debugLog(
          '🔐 MainPage: Registrierungs-Gate zu — nachgelagerter Cold-Start für uid=${u.uid}',
        );
        _runColdStartServicesForUser(u);
        _kickPartyAutostart();
      }
    }
    _lastRegistrationGuard = registering;
  }

  @override
  void dispose() {
    RegistrationFlowGuard.isRegistering.removeListener(
      _onRegistrationFlowGuardChanged,
    );
    NavigationService().currentTabIndex.removeListener(_onNavigationTabChanged);
    _profileLoadTimeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    UserService().currentUser.removeListener(_onUserModelChanged);
    UserService().trialExpiryPromptNotifier.removeListener(
      _onTrialExpiryPromptNotifier,
    );
    _linkSubscription?.cancel();
    _recognitionNotificationTapSubscription?.cancel();
    _newWishesCheckTimer?.cancel();
    _wishesStreamSubscription?.cancel();
    for (final controller in _adminOtpControllers) {
      controller.dispose();
    }
    for (final focusNode in _adminOtpFocusNodes) {
      focusNode.dispose();
    }
    _glowAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _handleRootBackNavigation() {
    final scaffoldState = mainPageScaffoldKey.currentState;
    if (scaffoldState?.isEndDrawerOpen ?? false) {
      scaffoldState?.closeEndDrawer();
      return;
    }

    // Zuerst logische Ebenen schließen (Dialoge/Modals/Unterseiten auf dem Navigator-Stack).
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
      return;
    }

    // Auf Hauptseiten nie linear durch Tabs zurückgehen – direkt auf Home springen.
    if (_currentIndex != 0) {
      NavigationService().setTabIndex(0);
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > _exitBackPressWindow) {
      _lastBackPressedAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Zum Beenden noch einmal drücken'),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }

    SystemNavigator.pop();
  }

  Widget _withRootBackScope(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleRootBackNavigation();
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    // App startet immer mit MainPage; Login nur über Route /login. Unverifizierte E-Mail → Verify-UI.
    // Hinweis: Kein periodisches E-Mail-Polling — Bestätigung nur per „Prüfen“/Resume ([FirestoreEmailVerifiedGate], [VerifyEmailPage]).
    if (!widget.skipEmailVerification &&
        !_emailVerifiedFirestoreOverride &&
        authUser != null &&
        authUser.email != null &&
        authUser.email!.isNotEmpty &&
        !authUser.emailVerified) {
      return _withRootBackScope(
        FirestoreEmailVerifiedGate(
          user: authUser,
          onEmailVerifiedOverride: () {
            if (mounted) setState(() => _emailVerifiedFirestoreOverride = true);
          },
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final checkScope = user == null ? 'guest-loggedout' : 'auth-${user.uid}';
    if (_appUpdateCheckScope != checkScope) {
      _appUpdateCheckScope = checkScope;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _runAppUpdateCheck(context),
      );
    }
    if (user != null && !_announcementCheckDone) {
      _announcementCheckDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 2500));
        if (!mounted) return;
        GlobalAnnouncementPopupService.checkAndShowIfNeeded(context);
      });
    }
    // LOGIN-CHECK: UserModel aus UserService-Cache; [_onUserModelChanged] → setState (ohne VL um IndexedStack).
    final userModel = UserService().currentUser.value;
    final roleName = _currentRoleName;
    // Admin-Erkennung ausschließlich über role_id (UserService/AppConfig.isAdminRole)
    final isRealAdmin = AppConfig.isAdminRole(userModel);
    // WICHTIG: Im DJ-Modus (currentViewRole == 'DJ') werden Admin-Privilegien ausgeblendet
    final isAdminMode =
        isRealAdmin &&
        (_currentViewRole == null || _currentViewRole == 'Admin');
    final isDJMode =
        _currentViewRole == 'DJ' ||
        (user != null &&
            (roleName == 'DJ' || roleName == 'Location') &&
            _currentViewRole != 'Admin');
    final isGuestMode =
        _currentViewRole == 'Gast' ||
        (roleName == 'Gast' && _currentViewRole != 'Admin' && _currentViewRole != 'DJ');
    final isWaitingForProfile =
        user != null && !isAdminMode && !isDJMode && !isGuestMode;

    final blockAdminContent =
        user != null &&
        wantsAdminView &&
        (_adminBiometricCheckInProgress || _adminBiometricVerifiedUid != user.uid);
    if (blockAdminContent) {
      if (_adminUseAuthenticatorFallback && user != null) {
        return _buildAdminOtpCurtain(user);
      }
      final waitingText = _adminUseAuthenticatorFallback
          ? 'Authenticator-Code erforderlich...'
          : 'Verifiziere Admin-Zugriff...';
      return _withRootBackScope(
        Scaffold(
        backgroundColor: UIConstants.djShellPageBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: UIConstants.appOrange),
              const SizedBox(height: 16),
              Text(
                waitingText,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        ),
      );
    }

    // Ereignisgesteuert: Solange Profil lädt (Dokument null) oder Rolle noch unklar → Ladeanzeige oder Timeout-UI
    if (isWaitingForProfile) {
      if (userModel == null) {
        if (_profileLoadTimeoutReached) {
          final l10n = AppLocalizations.of(context)!;
          return _withRootBackScope(
            Scaffold(
            backgroundColor: UIConstants.djShellPageBackground,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.profile_load_timeout_message,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _profileLoadTimeoutReached = false;
                          _profileLoadTimeoutTimerStarted = false;
                          _startProfileLoadTimeout();
                        });
                      },
                      icon: const Icon(
                        Icons.refresh,
                        color: UIConstants.appOrange,
                      ),
                      label: Text(
                        l10n.retry_button,
                        style: const TextStyle(color: UIConstants.appOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        }
        _startProfileLoadTimeout();
        return _withRootBackScope(
          const Scaffold(
          backgroundColor: UIConstants.djShellPageBackground,
          body: Center(
            child: CircularProgressIndicator(color: UIConstants.appOrange),
          ),
          ),
        );
      }
      // Dokument da: Rolle prüfen. Gäste (roleName == 'Gast') sind erlaubt und sehen die Gast-UI.
      _cancelProfileLoadTimeout();
      final roleId = userModel?.roleId;
      if (roleId == null || roleId.isEmpty) {
        _triggerLogout();
        return _withRootBackScope(
          const Scaffold(
          backgroundColor: UIConstants.djShellPageBackground,
          body: Center(
            child: CircularProgressIndicator(color: UIConstants.appOrange),
          ),
          ),
        );
      }
      // Gast ist gültige Rolle – kein Logout, Fall-Through zur Gast-UI
      if (roleName != null &&
          roleName != 'Admin' &&
          roleName != 'DJ' &&
          roleName != 'Location' &&
          roleName != 'Gast') {
        _triggerLogout();
        return _withRootBackScope(
          const Scaffold(
          backgroundColor: UIConstants.djShellPageBackground,
          body: Center(
            child: CircularProgressIndicator(color: UIConstants.appOrange),
          ),
          ),
        );
      }
      // Rolle noch nicht geladen (_currentRoleName null) → weiter warten
      if (roleName == null) {
        return _withRootBackScope(
          const Scaffold(
          backgroundColor: UIConstants.djShellPageBackground,
          body: Center(
            child: CircularProgressIndicator(color: UIConstants.appOrange),
          ),
          ),
        );
      }
      // Gast / DJ / Admin / Location: aus Warte-Block aussteigen, Hauptinhalt anzeigen
    }

    _cancelProfileLoadTimeout();
    if (user == null) {
      _profileLoadTimeoutReached = false;
      _mandatoryProfileDialogShown = false;
    }

    // DJ ohne vollständiges Pflicht-Profil: MandatoryProfileDialog einmalig anzeigen
    if (user != null &&
        userModel != null &&
        isDJMode &&
        !(userModel.hasCompletedProfile == true) &&
        !_mandatoryProfileDialogShown) {
      _mandatoryProfileDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const MandatoryProfileDialog(),
        ).then((result) {
          if (mounted) setState(() => _mandatoryProfileDialogShown = false);
        });
      });
    }

    // Stelle sicher, dass _currentIndex gültig ist
    // Admin-Bereich: inkl. Spotify-Filter. DJ-Bereich: ohne Spotify-Filter, dann Profil/Einstellungen …
    final showMasterAdminTestTab =
        AppConfig.isMasterAdminFirebaseUid(user?.uid);
    final List<Widget> children = (isAdminMode || isDJMode)
        ? (isAdminMode
              ? [
                  // Index 0: Home
                  HomePage(
                    key: _homePageKey,
                    currentViewRole: _currentViewRole,
                    requests: _currentWishesList,
                    onViewRoleChanged: _handleHomeViewRoleChanged,
                  ),
                  const PartyVerwaltungPage(),
                  DjVibesBoxPage(
                    offenPageKey: _offenPageKey,
                    requests: _currentWishesList,
                    onPageOpened: _markWishesAsViewed,
                    isActive: _currentIndex == 2,
                  ),
                  const GesperrtPage(),
                  const HistoryPage(),
                  const SpotifyPage(),
                  if (showMasterAdminTestTab) const TestPage(),
                  const BenutzerVerwaltungPage(),
                  const TodoPage(),
                  ImpressumPage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                  DSGVOPage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                  TermsOfServicePage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                ]
              : [
                  HomePage(
                    key: _homePageKey,
                    currentViewRole: _currentViewRole,
                    requests: _currentWishesList,
                    onViewRoleChanged: _handleHomeViewRoleChanged,
                  ),
                  const PartyVerwaltungPage(),
                  DjVibesBoxPage(
                    offenPageKey: _offenPageKey,
                    requests: _currentWishesList,
                    onPageOpened: _markWishesAsViewed,
                    isActive: _currentIndex == 2,
                  ),
                  const GesperrtPage(),
                  const HistoryPage(),
                  const ProfilPage(),
                  const SettingsPage(),
                  const SocialMediaPage(),
                  const AboutPage(),
                  ImpressumPage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                  DSGVOPage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                  TermsOfServicePage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                ])
        : (user == null
              ? [
                  HomePage(
                    key: _homePageKey,
                    currentViewRole: _currentViewRole,
                    requests: _currentWishesList,
                    onViewRoleChanged: _handleHomeViewRoleChanged,
                    onLoginRequested: _openGuestLogin,
                    onRegisterRequested: _openGuestRegister,
                    onOpenParty: () => NavigationService().setTabIndex(2),
                  ),
                  LoginPage(
                    key: ValueKey(
                      'guest_auth_${_guestAuthStartInRegister ? "register" : "login"}_${_guestAuthPartyLinkNonce}',
                    ),
                    startInRegister: _guestAuthStartInRegister,
                  ),
                  WishesPage(
                    key: ValueKey(
                      'wishes_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                    onPartyJoined: () {
                      if (mounted) setState(() => _guestPartyJoinCount++);
                    },
                  ),
                  ContactPage(
                    key: ValueKey(
                      'contact_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                    contactFormKey: _contactFormKey,
                  ),
                  SocialMediaPage(
                    key: ValueKey(
                      'social_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                  ),
                  const AboutPage(),
                  HistoryPage(
                    key: ValueKey(
                      'history_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                  ),
                  ImpressumPage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                  DSGVOPage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                  TermsOfServicePage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                ]
              : [
                  HomePage(
                    key: _homePageKey,
                    currentViewRole: _currentViewRole,
                    requests: _currentWishesList,
                    onViewRoleChanged: _handleHomeViewRoleChanged,
                    onLoginRequested: null,
                    onOpenParty: () => NavigationService().setTabIndex(1),
                  ),
                  WishesPage(
                    key: ValueKey(
                      'wishes_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                    onPartyJoined: () {
                      if (mounted) setState(() => _guestPartyJoinCount++);
                    },
                  ),
                  HistoryPage(
                    key: ValueKey(
                      'history_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                  ),
                  SocialMediaPage(
                    key: ValueKey(
                      'social_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                  ),
                  ContactPage(
                    key: ValueKey(
                      'contact_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                    contactFormKey: _contactFormKey,
                  ),
                  DeineWunschePage(
                    key: ValueKey(
                      'deine_wunsche_$_guestPartyLeaveCount$_guestPartyJoinCount',
                    ),
                  ),
                  const ProfilPage(),
                  const AboutPage(),
                  ImpressumPage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                  DSGVOPage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                  TermsOfServicePage(
                    onBack: () =>
                        NavigationService().setTabIndex(_previousTabIndex),
                  ),
                ]);

    // Wenn Index außerhalb des gültigen Bereichs, zurücksetzen
    // DJ-Bereich: weniger Tabs (ohne Spotify-Filter); Admin-Bereich: mit Spotify-Filter.
    final maxIndex = children.length;
    final safeStackIndex = maxIndex > 0
        ? _currentIndex.clamp(0, maxIndex - 1)
        : 0;

    // Index nur in gültigen Bereich korrigieren (z. B. weniger Tabs nach Rollenwechsel) – nie unkonditioniert auf Startseite.
    if (maxIndex > 0 && _currentIndex != safeStackIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          NavigationService().setTabIndex(safeStackIndex);
        }
      });
    }

    // Gast-Header: dynamische Höhe wenn Party aktiv (PWA-Layout wie vb/)
    final isDjArea =
        roleName == 'DJ' || roleName == 'Admin' || roleName == 'Location';
    final guestSvc = PartySessionService.instance;
    final hasActiveParty =
        !isDjArea &&
        guestSvc.hasSession &&
        (guestSvc.partyId ?? '').isNotEmpty &&
        guestSvc.partyId != 'manual';
    final appBarHeight = isDjArea ? 48.0 : (hasActiveParty ? 80.0 : 48.0);

    return _withRootBackScope(
      Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
      key: mainPageScaffoldKey,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: Padding(
          padding: const EdgeInsets.only(top: 0),
          child: AppBar(
            toolbarHeight: appBarHeight,
            leadingWidth:
                36, // Deutlich reduzierter Abstand – Logo sitzt weiter links
            clipBehavior:
                Clip.none, // Damit Glow-Effekte nicht abgeschnitten werden
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: UIConstants.appBarIconTheme,
            titleTextStyle: UIConstants.appBarTitleTextStyle,
            title: ValueListenableBuilder<SessionProStatus?>(
              valueListenable: UserService().sessionProStatus,
              builder: (context, session, _) {
                return ValueListenableBuilder<UserModel?>(
                  valueListenable: UserService().currentUser,
                  builder: (context, userModel, _) {
                // FREE/PRO-Badge nur im DJ-Bereich anzeigen; im Gast-Modus nur "VibesBox"
                final roleName = _currentRoleName;
                final isDjArea =
                    roleName == 'DJ' ||
                    roleName == 'Admin' ||
                    roleName == 'Location';
                final titleStyle = Theme.of(context).textTheme.titleLarge
                    ?.copyWith(
                      fontSize:
                          (userModel?.planType == 'trial' &&
                                  session?.isActive == true)
                              ? 15
                              : 18,
                      fontWeight: FontWeight.bold,
                      color: UIConstants.appBarForegroundColor,
                      letterSpacing: 0.5,
                    );
                if (!isDjArea) {
                  final svc = PartySessionService.instance;
                  final hasActiveParty =
                      svc.hasSession &&
                      (svc.partyId ?? '').isNotEmpty &&
                      svc.partyId != 'manual';
                  final djName = svc.djName;
                  final partyName = svc.partyName;
                  final l10n = AppLocalizations.of(context)!;

                  // PWA vb/ Layout: Logo links (größer bei Party), rechts 3 vertikale Zeilen
                  final logoSize = hasActiveParty ? 64.0 : 44.0;
                  final byPrefix = l10n.byDjPrefix;
                  final partyLabel = l10n.partyLabel;
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 0,
                      right: 8,
                      top: 6,
                      bottom: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo links (flex-shrink: 0)
                        Image.asset(
                          'assets/icon/vibesbox-logo.png',
                          height: logoSize,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) {
                            return AppAssets.placeholder(
                              width: logoSize,
                              height: logoSize,
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        // Rechts: 3 Zeilen vertikal, Flexible für Zeilenumbruch vor Hamburger
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Zeile 1: Hauptname VibesBox (Orange)
                              Text(
                                'VibesBox',
                                style: titleStyle?.copyWith(
                                  fontSize: hasActiveParty ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: UIConstants.appOrange,
                                  height: 1.2,
                                ),
                              ),
                              if (hasActiveParty) ...[
                                const SizedBox(height: 2),
                                if (djName != null && djName.isNotEmpty)
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '$byPrefix ',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                            color: UIConstants
                                                .appBarForegroundColor,
                                            height: 1.2,
                                          ),
                                        ),
                                        TextSpan(
                                          text: djName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: UIConstants
                                                .appBarForegroundColor,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    overflow: TextOverflow.clip,
                                    softWrap: true,
                                  ),
                                if (partyName != null && partyName.isNotEmpty)
                                  _buildPartyLineWithContour(
                                    partyLabel,
                                    partyName,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // DJ-Bereich: VibesBox + Status (FREE / PRO / PRO Life)
                final status = session?.status ?? ProFreeStatus.FREE;
                final String statusText;
                final Color statusColor;
                switch (status) {
                  case ProFreeStatus.PRO_LIFE:
                    statusText = ' PRO Life';
                    statusColor = UIConstants.appGreen;
                    break;
                  case ProFreeStatus.PRO:
                    statusText = ' PRO';
                    statusColor = UIConstants.appGreen;
                    break;
                  case ProFreeStatus.FREE:
                    statusText = ' FREE';
                    statusColor = Colors.red;
                    break;
                }
                final strokePaint = Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = UIConstants.appBarForegroundColor;
                final fillPaint = Paint()..color = statusColor;
                final l10nHeader = AppLocalizations.of(context)!;
                final showTrialSubline = session?.isActive == true &&
                    (userModel?.planType ?? '') == 'trial' &&
                    session?.proUntil != null;
                String trialHeaderLine = '';
                if (showTrialSubline && session!.proUntil != null) {
                  final locTag = Localizations.localeOf(context).toString();
                  final df = DateFormat.yMd(locTag).add_Hm();
                  trialHeaderLine =
                      '${l10nHeader.trial_period_until_prefix} ${df.format(session.proUntil!)}${l10nHeader.time_suffix}';
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final showStatus = constraints.maxWidth > 210;
                    final logoH = showTrialSubline ? 34.0 : 40.0;

                    return SizedBox(
                      height: 44,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/icon/vibesbox-logo.png',
                              height: logoH,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) {
                                return AppAssets.placeholder(
                                  width: logoH,
                                  height: logoH,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'VibesBox',
                                      style: titleStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (showStatus)
                                      Stack(
                                        children: [
                                          Text(
                                            statusText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: titleStyle?.copyWith(
                                              foreground: strokePaint,
                                              color: null,
                                            ),
                                          ),
                                          Text(
                                            statusText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: titleStyle?.copyWith(
                                              foreground: fillPaint,
                                              color: null,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                if (showTrialSubline) ...[
                                  const SizedBox(height: 1),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth - logoH - 16,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.78,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: UIConstants.appOrange,
                                          width: 0.9,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        child: Text(
                                          trialHeaderLine,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 8.5,
                                            height: 1.05,
                                            fontWeight: FontWeight.w600,
                                            color: UIConstants.appOrange,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                  },
                );
              },
            ),
            leading: ValueListenableBuilder<Locale>(
              valueListenable: LocaleHelper.localeNotifier,
              builder: (context, currentLocale, _) {
                final localizations = AppLocalizations.of(context)!;

                return PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.language,
                    size: 22,
                    color: UIConstants.appBarIconColor,
                  ),
                  tooltip: localizations.selectLanguage,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  onSelected: (String languageCode) {
                    LocaleHelper.saveLocale(languageCode);
                  },
                  itemBuilder: (BuildContext context) {
                    // Sprachnamen Englisch; Emoji-Flaggen (it/uk als Unicode-Escape)
                    final languages = [
                      {'code': 'de', 'flag': '🇩🇪', 'name': 'German'},
                      {'code': 'en', 'flag': '🇬🇧', 'name': 'English'},
                      {'code': 'fr', 'flag': '🇫🇷', 'name': 'French'},
                      {'code': 'ru', 'flag': '🇷🇺', 'name': 'Russian'},
                      {'code': 'zh', 'flag': '🇨🇳', 'name': 'Chinese'},
                      {'code': 'es', 'flag': '🇪🇸', 'name': 'Spanish'},
                      {'code': 'tr', 'flag': '🇹🇷', 'name': 'Turkish'},
                      // {'code': 'ar', 'flag': '🇸🇦', 'name': 'العربية'},
                      {'code': 'pt', 'flag': '🇵🇹', 'name': 'Portuguese'},
                      {'code': 'it', 'flag': '\u{1F1EE}\u{1F1F9}', 'name': 'Italian'},
                      {'code': 'uk', 'flag': '\u{1F1FA}\u{1F1E6}', 'name': 'Ukrainian'},
                    ];

                    // Englische Namen, vollständig alphabetisch (A–Z)
                    final sortedLanguages = List<Map<String, String>>.from(
                      languages,
                    )..sort(
                        (a, b) => (a['name'] as String)
                            .toLowerCase()
                            .compareTo((b['name'] as String).toLowerCase()),
                      );

                    return sortedLanguages.map((lang) {
                      final code = lang['code'] as String;
                      final flag = lang['flag'] as String;
                      final name = lang['name'] as String;
                      final isCurrent = code == currentLocale.languageCode;

                      return PopupMenuItem<String>(
                        value: code,
                        child: Row(
                          children: [
                            Text(flag, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Flexible(child: Text(name)),
                            if (isCurrent)
                              const Icon(
                                Icons.check,
                                color: Colors.green,
                                size: 20,
                              ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                );
              },
            ),
            flexibleSpace: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/vb-header.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xA6000000),
                        Color(0x8A000000),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            automaticallyImplyLeading: false,
            actions: [
              Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Stack(
                      children: [
                        Icon(
                          Icons.menu,
                          size: 24,
                          color: UIConstants.appBarIconColor,
                        ),
                        // Badge für offene Wünsche – vorübergehend deaktiviert (Counter-Logik bleibt erhalten)
                        // if (_newWishesCount > 0)
                        //   Positioned(
                        //     right: 0,
                        //     top: 0,
                        //     child: Container(
                        //       padding: const EdgeInsets.all(4),
                        //       decoration: const BoxDecoration(
                        //         color: Colors.red,
                        //         shape: BoxShape.circle,
                        //       ),
                        //       constraints: const BoxConstraints(
                        //         minWidth: 16,
                        //         minHeight: 16,
                        //       ),
                        //       child: Text(
                        //         '$_newWishesCount',
                        //         style: const TextStyle(
                        //           color: Colors.white,
                        //           fontSize: 10,
                        //           fontWeight: FontWeight.bold,
                        //         ),
                        //         textAlign: TextAlign.center,
                        //       ),
                        //     ),
                        //   ),
                      ],
                    ),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    iconSize: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      endDrawer: _buildDrawer(), // Rechts positioniert
      body: LegalPageScope(
        showImpressum: () {
          _previousTabIndex = _currentIndex;
          NavigationService().setTabIndex(children.length - 3);
        },
        showDsgvo: () {
          _previousTabIndex = _currentIndex;
          NavigationService().setTabIndex(children.length - 2);
        },
        showAgb: () {
          _previousTabIndex = _currentIndex;
          NavigationService().setTabIndex(children.length - 1);
        },
        child: SizedBox.expand(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/vb-header2.jpg'),
                fit: BoxFit.fill,
                alignment: Alignment.center,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _buildBrandSideRail(isLeft: true),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          color: UIConstants.djShellPageBackground,
                          child: ScrollIndicatorOverlay(
                            child: IndexedStack(
                              index: safeStackIndex,
                              children: children,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildBrandSideRail(isLeft: false),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isDjArea && authUser != null
          ? ShazamFooter(
              key: ValueKey('shazam_footer_${_currentRoleName ?? 'none'}'),
            )
          : !isDjArea
              ? const _GuestFrameFooter()
              : null,
      ),
          if (_partyDeepLinkLoading)
            Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: UIConstants.appOrange,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrandSideRail({required bool isLeft}) {
    return SizedBox(
      width: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/vb-header2.jpg'),
            fit: BoxFit.fill,
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          ),
        ),
      ),
    );
  }

  /// Party-Zeile mit grünem Text und schwarzer Kontur für Lesbarkeit auf blau-lila Verlauf.
  Widget _buildPartyLineWithContour(String label, String name) {
    const fontSize = 13.0;
    const height = 1.2;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black;

    return Stack(
      children: [
        // Schwarze Kontur (Hintergrund)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.normal,
                  foreground: strokePaint,
                  height: height,
                ),
              ),
              TextSpan(
                text: name,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  foreground: strokePaint,
                  height: height,
                ),
              ),
            ],
          ),
          overflow: TextOverflow.clip,
          softWrap: true,
        ),
        // Orangefarbener Text (Vordergrund)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: const TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.normal,
                  color: UIConstants.appOrange,
                  height: height,
                ),
              ),
              TextSpan(
                text: name,
                style: const TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: UIConstants.appOrange,
                  height: height,
                ),
              ),
            ],
          ),
          overflow: TextOverflow.clip,
          softWrap: true,
        ),
      ],
    );
  }

  /// Franken-State-Dialog: zerrissenes Zeitungsblatt, nur System-Diagnose (keine party_id/dj_id).
  Widget _buildFrankenStateContent(BuildContext ctx) {
    return DeepStateNewspaper(
      onReSyncStreams: () async {
        ActivePartyService.stopHeartbeat();
        await ActivePartyService.initialize();
      },
    );
  }

  /// Gast-Navigation: Menüpunkt ohne Rahmen (saubere Text-Navigation).
  Widget _guestNavTile(
    BuildContext context,
    AppLocalizations? localizations,
    int index,
    IconData icon,
    String title, {
    VoidCallback? onTapOverride,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        icon,
        size: 20,
        color: _currentIndex == index ? UIConstants.appOrange : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: Colors.white,
          fontWeight: _currentIndex == index
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      selected: _currentIndex == index,
      selectedTileColor: UIConstants.appOrange.withValues(alpha: 0.2),
      onTap:
          onTapOverride ??
          () {
            _onIndexChanged(index);
            Navigator.pop(context);
          },
    );
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final roleName = _currentRoleName;
    // Admin-Erkennung ausschließlich über role_id (UserService/AppConfig.isAdminRole)
    final isRealAdmin = AppConfig.isAdminRole(UserService().currentUser.value);
    // WICHTIG: Im DJ-Modus (currentViewRole == 'DJ') werden Admin-Privilegien ausgeblendet
    final isAdminMode =
        isRealAdmin &&
        (_currentViewRole == null || _currentViewRole == 'Admin');
    final isDJMode =
        _currentViewRole == 'DJ' ||
        (user != null &&
            (roleName == 'DJ' || roleName == 'Location') &&
            _currentViewRole != 'Admin');
    // DJ-Shell: kein Spotify-Filter in der Navigation — Indizes 5–8 = Profil … Über.
    const djProfilIndex = 5;
    const djSettingsIndex = 6;
    const djSocialIndex = 7;
    const djAboutIndex = 8;
    // Admin-Shell: Spotify-Filter = 5, optional nur Master-UID: Test, dann Benutzer / To-do
    final showMasterAdminTestTab =
        AppConfig.isMasterAdminFirebaseUid(user?.uid);
    const adminTestIndex = 6;
    final adminUserIndex = showMasterAdminTestTab ? 7 : 6;
    final adminTodoIndex = showMasterAdminTestTab ? 8 : 7;
    final localizations = AppLocalizations.of(context)!;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);

    return Directionality(
      // Nur Navigation/Drawer spiegeln (Text rechts, Icon ganz rechts) – global bleibt LTR.
      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Drawer(
        width: 200, // Deutlich schmaler (Standard: ~304px)
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: user == null ? UIConstants.djShellPageBackground : null,
            gradient: user != null
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      UIConstants.bgGradientStart,
                      UIConstants.bgGradientEnd,
                    ],
                  )
                : null,
            border: Border.fromBorderSide(
              BorderSide(
                color: user == null
                    ? UIConstants.appOrange
                    : UIConstants.partyYellow,
                width: 1.5,
              ),
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16.0),
              bottomRight: Radius.circular(16.0),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(
              listTileTheme: Theme.of(context).listTileTheme.copyWith(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Eigenes Header-Container (kein DrawerHeader) – vermeidet feste Höhe und RenderFlex-Overflow
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: user == null
                            ? UIConstants.appOrange
                            : UIConstants.partyYellow,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/icon/vibesbox-logo.png',
                        height: 72,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return AppAssets.placeholder(height: 72);
                        },
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          _deepStateTapCount++;
                          if (_deepStateTapCount >= 5) {
                            _deepStateTapCount = 0;
                            showDialog<void>(
                              context: context,
                              barrierColor: Colors.black54,
                              barrierDismissible: false,
                              builder: (ctx) => PopScope(
                                canPop: false,
                                child: Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildFrankenStateContent(ctx),
                                ),
                              ),
                            );
                          }
                        },
                        child: FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const SizedBox.shrink();
                            final info = snapshot.data!;
                            final versionText =
                                'v${info.version.split('+').first.trim()}';
                            return Text(
                              versionText,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    color: Colors.white54,
                                  ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (user != null)
                        _DrawerUserProfileRow(authUser: user)
                      else
                        Text(
                          localizations.guest,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Home ganz oben
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  leading: Icon(
                    Icons.home,
                    size: 20,
                    color: _currentIndex == 0
                        ? UIConstants.appOrange
                        : Colors.white,
                  ),
                  title: Text(
                    localizations.navStartseite,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: _currentIndex == 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: _currentIndex == 0,
                  selectedTileColor: UIConstants.appOrange.withValues(alpha: 0.2),
                  onTap: () {
                    _onIndexChanged(0);
                    Navigator.pop(context);
                  },
                ),
                // TEMP: Nach erfolgreicher Mass-E-Mail-Verifizierung entfernen (oder nie mit MASS_VERIFY_TRIGGER bauen).
                if (AppConfig.massVerifyTriggerEnabled &&
                    user != null &&
                    AppConfig.adminDjId != null &&
                    user.uid == AppConfig.adminDjId) ...[
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    leading: const Icon(
                      Icons.verified_user,
                      size: 20,
                      color: Colors.amber,
                    ),
                    title: Text(
                      localizations.mass_verify_dialog_title,
                      style: const TextStyle(fontSize: 13, color: Colors.amber),
                    ),
                    subtitle: Text(
                      localizations.mass_verify_dialog_body,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _runMassVerifyExistingUsersMigration();
                    },
                  ),
                ],
                Divider(height: 1, color: Colors.grey[800]),
                if (isDJMode || isAdminMode) ...[
                  // DJ-Menü (nur für DJ, nicht für Admin)
                  if (isDJMode)
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.event,
                        size: 20,
                        color: _currentIndex == 1
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.partyManagement,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == 1,
                      selectedTileColor: UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        _onIndexChanged(1);
                        Navigator.pop(context);
                      },
                    ),
                  if (isDJMode)
                    // Party-Steuerung: VibesBox, Gesperrt, History – optisch gruppiert (8px Padding, 1px gelb)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(
                          color: UIConstants.partyYellow,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.library_music,
                                  size: 20,
                                  color: _currentIndex == 2
                                      ? UIConstants.appOrange
                                      : Colors.white,
                                ),
                                // Badge für offene Wünsche – vorübergehend deaktiviert (Counter-Logik bleibt erhalten)
                                // if (_newWishesCount > 0)
                                //   Positioned(
                                //     right: -6,
                                //     top: -4,
                                //     child: Container(
                                //       padding: const EdgeInsets.all(3),
                                //       decoration: const BoxDecoration(
                                //         color: Colors.red,
                                //         shape: BoxShape.circle,
                                //       ),
                                //       constraints: const BoxConstraints(
                                //         minWidth: 14,
                                //         minHeight: 14,
                                //       ),
                                //       child: Text(
                                //         _newWishesCount > 99 ? '99+' : '$_newWishesCount',
                                //         style: const TextStyle(
                                //           color: Colors.white,
                                //           fontSize: 9,
                                //           fontWeight: FontWeight.bold,
                                //         ),
                                //         textAlign: TextAlign.center,
                                //       ),
                                //     ),
                                //   ),
                              ],
                            ),
                            title: Text(
                              'VibesBox',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: _currentIndex == 2
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: _currentIndex == 2,
                            selectedTileColor: UIConstants.appOrange
                                .withValues(alpha: 0.2),
                            onTap: () {
                              _onIndexChanged(2);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            leading: Icon(
                              Icons.block,
                              size: 20,
                              color: _currentIndex == 3
                                  ? UIConstants.appOrange
                                  : Colors.white,
                            ),
                            title: Text(
                              localizations.blocked,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: _currentIndex == 3
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: _currentIndex == 3,
                            selectedTileColor: UIConstants.appOrange
                                .withValues(alpha: 0.2),
                            onTap: () {
                              _onIndexChanged(3);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            leading: Icon(
                              Icons.history,
                              size: 20,
                              color: _currentIndex == 4
                                  ? UIConstants.appOrange
                                  : Colors.white,
                            ),
                            title: Text(
                              localizations.history,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: _currentIndex == 4
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: _currentIndex == 4,
                            selectedTileColor: UIConstants.appOrange
                                .withValues(alpha: 0.2),
                            onTap: () {
                              _onIndexChanged(4);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  // Profil/Einstellungen nur im DJ-Modus (kein Spotify-Filter — nur im Admin-Bereich)
                  if (isDJMode) ...[
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.person,
                        size: 20,
                        color: _currentIndex == djProfilIndex
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.profile,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == djProfilIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == djProfilIndex,
                      selectedTileColor:
                          UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        _onIndexChanged(djProfilIndex);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.settings,
                        size: 20,
                        color: _currentIndex == djSettingsIndex
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.settings_title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == djSettingsIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == djSettingsIndex,
                      selectedTileColor:
                          UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        _onIndexChanged(djSettingsIndex);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                  // Social Media & Über nur im DJ-Modus (nicht im Admin)
                  if (isDJMode) ...[
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.share,
                        size: 20,
                        color: _currentIndex == djSocialIndex
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.socialMedia,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == djSocialIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == djSocialIndex,
                      selectedTileColor:
                          UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        _onIndexChanged(djSocialIndex);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.info,
                        size: 20,
                        color: _currentIndex == djAboutIndex
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.about,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == djAboutIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == djAboutIndex,
                      selectedTileColor:
                          UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        _onIndexChanged(djAboutIndex);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                  // Admin-Bereich: Spotify-Blacklist/Filter (nicht in der DJ-Shell)
                  if (isAdminMode) ...[
                    ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        leading: Icon(
                          Icons.music_note,
                          size: 20,
                          color: _currentIndex == 5
                              ? UIConstants.appOrange
                              : Colors.white,
                        ),
                        title: Text(
                          'Spotify-Filter',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: _currentIndex == 5
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: _currentIndex == 5,
                        selectedTileColor:
                            UIConstants.appOrange.withValues(alpha: 0.2),
                        onTap: () {
                          _onIndexChanged(5);
                          Navigator.pop(context);
                        },
                      ),
                    if (showMasterAdminTestTab)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        leading: Icon(
                          Icons.bug_report,
                          size: 20,
                          color: _currentIndex == adminTestIndex
                              ? UIConstants.appOrange
                              : Colors.white,
                        ),
                        title: Text(
                          'Test',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: _currentIndex == adminTestIndex
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: _currentIndex == adminTestIndex,
                        selectedTileColor:
                            UIConstants.appOrange.withValues(alpha: 0.2),
                        onTap: () {
                          _onIndexChanged(adminTestIndex);
                          Navigator.pop(context);
                        },
                      ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.people,
                        size: 20,
                        color: _currentIndex == adminUserIndex
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.userManagement,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == adminUserIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == adminUserIndex,
                      selectedTileColor:
                          UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        _onIndexChanged(adminUserIndex);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.checklist,
                        size: 20,
                        color: _currentIndex == adminTodoIndex
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.todoList,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == adminTodoIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == adminTodoIndex,
                      selectedTileColor:
                          UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        _onIndexChanged(adminTodoIndex);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ] else ...[
                  // Gast-Bereich: Reihenfolge Startseite, VibesBox, History, Social Media, Kontakt, Über, Anmelden. Indizes unverändert.
                  if (user == null) ...[
                    // Gast: VibesBox, History, Social Media, Kontakt (orange Rahmen), Über
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(
                          color: UIConstants.appOrange,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _guestNavTile(
                            context,
                            localizations,
                            2,
                            Icons.music_note,
                            'VibesBox',
                          ),
                          _guestNavTile(
                            context,
                            localizations,
                            6,
                            Icons.history,
                            localizations.history,
                          ),
                          _guestNavTile(
                            context,
                            localizations,
                            4,
                            Icons.share,
                            localizations.socialMedia,
                          ),
                          _guestNavTile(
                            context,
                            localizations,
                            3,
                            Icons.contact_mail,
                            localizations.contact,
                            onTapOverride: () {
                              if (_currentIndex != 3) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _contactFormKey.currentState
                                      ?.resetSuccessMessage();
                                });
                              }
                              _onIndexChanged(3);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    _guestNavTile(
                      context,
                      localizations,
                      5,
                      Icons.info,
                      localizations.about,
                    ),
                  ] else ...[
                    // Eingeloggt: VibesBox, History, Social Media, Kontakt, Deine Wünsche (orange Rahmen), Profil, Über
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(
                          color: UIConstants.appOrange,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            leading: Icon(
                              Icons.music_note,
                              size: 20,
                              color: _currentIndex == 1
                                  ? UIConstants.appOrange
                                  : Colors.white,
                            ),
                            title: Text(
                              'VibesBox',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: _currentIndex == 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: _currentIndex == 1,
                            selectedTileColor: UIConstants.appOrange
                                .withValues(alpha: 0.2),
                            onTap: () {
                              NavigationService().setTabIndex(1);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            leading: Icon(
                              Icons.history,
                              size: 20,
                              color: _currentIndex == 2
                                  ? UIConstants.appOrange
                                  : Colors.white,
                            ),
                            title: Text(
                              localizations.history,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: _currentIndex == 2
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: _currentIndex == 2,
                            selectedTileColor: UIConstants.appOrange
                                .withValues(alpha: 0.2),
                            onTap: () {
                              NavigationService().setTabIndex(2);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            leading: Icon(
                              Icons.share,
                              size: 20,
                              color: _currentIndex == 3
                                  ? UIConstants.appOrange
                                  : Colors.white,
                            ),
                            title: Text(
                              localizations.socialMedia,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: _currentIndex == 3
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: _currentIndex == 3,
                            selectedTileColor: UIConstants.appOrange
                                .withValues(alpha: 0.2),
                            onTap: () {
                              NavigationService().setTabIndex(3);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            leading: Icon(
                              Icons.contact_mail,
                              size: 20,
                              color: _currentIndex == 4
                                  ? UIConstants.appOrange
                                  : Colors.white,
                            ),
                            title: Text(
                              localizations.contact,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: _currentIndex == 4
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: _currentIndex == 4,
                            selectedTileColor: UIConstants.appOrange
                                .withValues(alpha: 0.2),
                            onTap: () {
                              if (_currentIndex != 4) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _contactFormKey.currentState
                                      ?.resetSuccessMessage();
                                });
                              }
                              NavigationService().setTabIndex(4);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            leading: Icon(
                              Icons.favorite,
                              size: 20,
                              color: _currentIndex == 5
                                  ? UIConstants.appOrange
                                  : Colors.white,
                            ),
                            title: Text(
                              localizations.yourWishes,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: _currentIndex == 5
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: _currentIndex == 5,
                            selectedTileColor: UIConstants.appOrange
                                .withValues(alpha: 0.2),
                            onTap: () {
                              NavigationService().setTabIndex(5);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.person,
                        size: 20,
                        color: _currentIndex == 6
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.profile,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == 6
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == 6,
                      selectedTileColor: UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        NavigationService().setTabIndex(6);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      leading: Icon(
                        Icons.info,
                        size: 20,
                        color: _currentIndex == 7
                            ? UIConstants.appOrange
                            : Colors.white,
                      ),
                      title: Text(
                        localizations.about,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: _currentIndex == 7
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentIndex == 7,
                      selectedTileColor: UIConstants.appOrange.withValues(alpha: 0.2),
                      onTap: () {
                        NavigationService().setTabIndex(7);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ],
                Divider(height: 1, color: Colors.grey[800]),
                if (user == null) ...[
                  FutureBuilder<String?>(
                    future: Future.value(_guestPartyLeaveCount)
                        .then(
                          (_) => PartySessionService.instance.loadFromPrefs(),
                        )
                        .then((_) => PartySessionService.instance.shortCode),
                    builder: (context, snapshot) {
                      final code = snapshot.data;
                      final hasParty =
                          code != null && code.isNotEmpty && code != 'manual';
                      if (!hasParty) return const SizedBox.shrink();
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        leading: const Icon(
                          Icons.exit_to_app,
                          size: 20,
                          color: Colors.red,
                        ),
                        title: Text(
                          localizations.leaveParty,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await PartySessionService.instance.clearSession();
                          if (mounted) {
                            setState(() {
                              _guestPartyLeaveCount++;
                            });
                            NavigationService().setTabIndex(0);
                          }
                        },
                      );
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    leading: const Icon(
                      Icons.login,
                      size: 20,
                      color: UIConstants.appOrange,
                    ),
                    title: Text(
                      localizations.signIn,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      NavigationService().setTabIndex(1);
                    },
                  ),
                ] else ...[
                  FutureBuilder<bool>(
                    future: PartySessionService.instance.loadFromPrefs().then(
                      (_) => PartySessionService.instance.hasSession,
                    ),
                    builder: (context, snapshot) {
                      final hasSession = snapshot.data == true;
                      if (!hasSession) return const SizedBox.shrink();
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        leading: const Icon(
                          Icons.exit_to_app,
                          size: 20,
                          color: Colors.red,
                        ),
                        title: Text(
                          localizations.leavePartySession,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await PartySessionService.instance.clearSession();
                          if (mounted) {
                            setState(() {
                              _guestPartyLeaveCount++;
                              _guestPartyJoinCount++;
                            });
                            NavigationService().setTabIndex(0);
                          }
                        },
                      );
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    leading: const Icon(
                      Icons.logout,
                      size: 20,
                      color: Colors.white,
                    ),
                    title: Text(
                      localizations.signOut,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await SubscriptionSyncService.logOut();
                      UserService().stopUserStream();
                      UserService().clearCache();
                      ProFeatureGuard.invalidateCache();
                      await SavedLoginEmailStore.clear();
                      await FirebaseAuth.instance.signOut();
                      NavigationService().resetToHome();
                    },
                  ),
                ],
                // Zusätzliches Padding am Ende, damit der Abmelden-Button erreichbar ist
                const SizedBox(height: 32),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDjNameText(BuildContext context, String? djName) {
    final displayText = djName ?? 'VibesBox';
    return Flexible(
      child: Text(
        displayText,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

/// Isoliert: nur diese Zeile rebuildet bei User-Dokument-Updates, nicht der IndexedStack.
class _DrawerUserProfileRow extends StatelessWidget {
  const _DrawerUserProfileRow({required this.authUser});

  final User authUser;

  Widget _drawerPhotoChip(String? photoUrl) {
    final raw = photoUrl?.trim() ?? '';
    const size = 28.0;
    if (!isHttpImageUrl(raw)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[700],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: 14, color: Colors.grey[400]),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          raw!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[700],
            alignment: Alignment.center,
            child: Icon(Icons.person, size: 14, color: Colors.grey[400]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: UserService().currentUser,
      builder: (context, userModel, _) {
        final photoURL = userModel?.photoURL;
        final displayNameRaw = userModel?.displayName;
        final displayName =
            (displayNameRaw != null && displayNameRaw.trim().isNotEmpty)
            ? displayNameRaw.trim()
            : (authUser.displayName ?? authUser.email ?? 'User');
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _drawerPhotoChip(photoURL),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    authUser.email ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GuestFrameFooter extends StatelessWidget {
  const _GuestFrameFooter();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 8,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/header_bg.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
