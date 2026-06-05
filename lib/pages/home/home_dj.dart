import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../services/navigation_service.dart';
import '../../widgets/home_cells/dual_statistics_card.dart';
import '../../widgets/home_cells/welcome_header.dart';
import '../../widgets/common/pwa_widget_cell.dart';
import '../../utils/admin_dj_bridge.dart';
import '../../settings_party_card_widget.dart';
import '../../settings_party_edit_dialog.dart';
import '../../settings_party_delete_dialog.dart';
import '../../widgets/party_qr_code_dialog.dart' show Party, PartyQrCodeDialog;
import '../../l10n/app_localizations.dart';
import '../../utils/formatting_utils.dart';
import '../../utils/ui_constants.dart';
import '../../services/active_party_service.dart';
import '../../services/grace_period_settings_service.dart';
import '../../services/limit_service.dart';
import '../../services/party_autostart_service.dart';
import '../../services/user_service.dart';
import '../../utils/party_grace_period_helper.dart';
import '../../services/dj_home_layout_service.dart';
import 'dj/dj_home_edit_sheet.dart';
import 'dj/dj_home_party_resolver.dart';
import 'dj/dj_home_widget_host.dart';

class HomeDj extends StatefulWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final Widget? adminRoleSwitcherBottom;
  final String? currentViewRole; // View-Mode für Admin-DJ-Umschaltung

  const HomeDj({
    super.key,
    required this.cardBuilder,
    this.adminRoleSwitcherBottom,
    this.currentViewRole,
  });

  @override
  State<HomeDj> createState() => _HomeDjState();
}

class _HomeDjState extends State<HomeDj> {
  String? _effectiveDjId;
  StreamController<DateTime>? _timeController;
  Timer? _timeTimer;
  Timer? _secondTickTimer;
  StreamSubscription<QuerySnapshot>? _partySubscription;
  List<QueryDocumentSnapshot>? _cachedParties;
  String? _lastDisplaySignature;
  int _timerIntervalSeconds = 60;
  int _gracePeriodMinutes = GracePeriodSettingsService.defaultGracePeriodMinutes;
  StreamSubscription<int>? _gracePeriodSub;

  static const int _thresholdSecondsForMinuteTick = 120;

  /// Gleicher Index wie [MainPage] DJ-Shell: Tab „Quickstart“ (ohne Admin-Dashboard-Variante).
  static const int _djQuickstartTabIndex = 9;

  bool _quickstartOnboardingDialogScheduled = false;
  VoidCallback? _quickstartUserListener;
  VoidCallback? _sessionProListener;
  bool? _lastSessionProActive;

  Stream<DateTime> get _timeStream {
    _timeController ??= StreamController<DateTime>.broadcast();
    _timeController!.add(DateTime.now());
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_timeController!.isClosed) {
        _timeController!.add(DateTime.now());
      } else {
        timer.cancel();
      }
    });
    return _timeController!.stream;
  }

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      DjHomeLayoutService.instance.startForUid(uid);
    }
    _loadEffectiveDjId();
    _quickstartUserListener = _tryScheduleQuickstartOnboarding;
    UserService().currentUser.addListener(_quickstartUserListener!);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _tryScheduleQuickstartOnboarding());
    _lastSessionProActive =
        UserService().sessionProStatus.value?.isActive == true;
    _sessionProListener = _onSessionProStatusChanged;
    UserService().sessionProStatus.addListener(_sessionProListener!);
  }

  void _onSessionProStatusChanged() {
    final active = UserService().sessionProStatus.value?.isActive == true;
    final wasPro = _lastSessionProActive == true;
    _lastSessionProActive = active;
    if (wasPro && !active) {
      unawaited(DjHomeLayoutService.instance.applyProToFreePromotionPin());
    }
  }

  void _startPartyStreamAndTimer() {
    if (_effectiveDjId == null) return;
    _partySubscription?.cancel();
    _partySubscription = FirebaseFirestore.instance
        .collection('parties')
        .where('created_by', isEqualTo: _effectiveDjId!)
        .snapshots()
        .listen((snapshot) {
      _cachedParties = snapshot.docs;
    });
    _gracePeriodSub?.cancel();
    _gracePeriodSub =
        GracePeriodSettingsService.streamForDj(_effectiveDjId!).listen((m) {
      if (mounted) {
        setState(() => _gracePeriodMinutes = m);
      }
    });
    _scheduleTickTimer();
  }

  void _scheduleTickTimer() {
    _secondTickTimer?.cancel();
    _secondTickTimer = Timer.periodic(
      Duration(seconds: _timerIntervalSeconds),
      (_) => _onTick(),
    );
  }

  void _onTick() {
    if (!mounted) return;
    final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final nowDate = DateTime.now();
    final parties = _cachedParties ?? [];
    bool hasActive = false;
    int? secondsUntilNextStart;
    int? secondsUntilGraceEnd;
    for (final party in parties) {
      final data = party.data() as Map<String, dynamic>;
      if (data['lifecycle_status'] == 'finished' ||
          data['lifecycle_status'] == 'standby' ||
          data['finished_at'] != null) {
        continue;
      }
      final startPosix = data['start_time_posix'] as int?;
      final endPosix = data['end_time_posix'] as int?;
      if (startPosix == null || endPosix == null) continue;
      if (nowUnix >= startPosix && nowUnix < endPosix) {
        hasActive = true;
        break;
      }
      if (startPosix > nowUnix) {
        final sec = startPosix - nowUnix;
        if (secondsUntilNextStart == null || sec < secondsUntilNextStart) {
          secondsUntilNextStart = sec;
        }
      }
    }
    if (!hasActive) {
      for (final party in parties) {
        final data = party.data() as Map<String, dynamic>;
        if (data['lifecycle_status'] == 'standby') continue;
        final end = PartyGracePeriodHelper.partyEndDate(data);
        if (end == null || nowDate.isBefore(end)) continue;
        if (PartyGracePeriodHelper.wishesManuallyHidden(data)) continue;
        if (!PartyGracePeriodHelper.isWithinGracePeriod(
          nowDate,
          end,
          _gracePeriodMinutes,
        )) {
          continue;
        }
        final sec = PartyGracePeriodHelper.graceEndsAt(end, _gracePeriodMinutes)
            .difference(nowDate)
            .inSeconds;
        if (sec > 0 &&
            (secondsUntilGraceEnd == null || sec < secondsUntilGraceEnd)) {
          secondsUntilGraceEnd = sec;
        }
      }
    }
    String signature;
    int nextInterval;
    if (hasActive) {
      signature = 'running';
      nextInterval = 60;
    } else if (secondsUntilGraceEnd != null) {
      signature = 'grace_$secondsUntilGraceEnd';
      nextInterval =
          secondsUntilGraceEnd > _thresholdSecondsForMinuteTick ? 60 : 1;
    } else if (secondsUntilNextStart != null) {
      signature = 'upcoming_$secondsUntilNextStart';
      nextInterval = secondsUntilNextStart > _thresholdSecondsForMinuteTick ? 60 : 1;
    } else {
      signature = 'none';
      nextInterval = 60;
    }
    if (signature != _lastDisplaySignature && mounted) {
      final wasRunning = _lastDisplaySignature == 'running';
      _lastDisplaySignature = signature;
      if (wasRunning && signature != 'running') {
        ActivePartyService.stopHeartbeat();
        PartyAutostartService().stopRecognitionNow();
      }
      setState(() {});
    }
    if (nextInterval != _timerIntervalSeconds && mounted) {
      _timerIntervalSeconds = nextInterval;
      _scheduleTickTimer();
    }
  }

  @override
  void dispose() {
    DjHomeLayoutService.instance.stop();
    if (_sessionProListener != null) {
      UserService().sessionProStatus.removeListener(_sessionProListener!);
    }
    if (_quickstartUserListener != null) {
      UserService().currentUser.removeListener(_quickstartUserListener!);
    }
    _secondTickTimer?.cancel();
    _partySubscription?.cancel();
    _gracePeriodSub?.cancel();
    _timeTimer?.cancel();
    _timeController?.close();
    super.dispose();
  }

  String _resolveDisplayName(User user, AppLocalizations l) {
    final userModel = UserScope.userOf(context);
    final fromModel = userModel?.displayName?.trim();
    final emailParts = user.email?.split('@');
    return (fromModel != null && fromModel.isNotEmpty)
        ? fromModel
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (emailParts != null && emailParts.isNotEmpty
                ? emailParts[0]
                : null)) ??
            l.dj_home_display_name_fallback;
  }

  void _tryScheduleQuickstartOnboarding() {
    if (_quickstartOnboardingDialogScheduled || !mounted) return;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;
    final um = UserService().currentUser.value;
    if (um == null) return;
    if (um.hasSeenQuickstart) {
      if (_quickstartUserListener != null) {
        UserService().currentUser.removeListener(_quickstartUserListener!);
        _quickstartUserListener = null;
      }
      return;
    }
    _quickstartOnboardingDialogScheduled = true;
    if (_quickstartUserListener != null) {
      UserService().currentUser.removeListener(_quickstartUserListener!);
      _quickstartUserListener = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showQuickstartOnboardingDialog());
    });
  }

  Future<void> _showQuickstartOnboardingDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    final l = AppLocalizations.of(context)!;
    final body = l.dj_quickstart_onboarding_body;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: UIConstants.appOrange, width: 2),
        ),
        title: Text(
          l.dj_quickstart_nav,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            body,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: UIConstants.appOrange,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set(
                      {'hasSeenQuickstart': true},
                      SetOptions(merge: true),
                    );
              } catch (_) {}
              if (!mounted) return;
              NavigationService().setTabIndex(_djQuickstartTabIndex);
            },
            child: Text(l.dj_quickstart_onboarding_button),
          ),
        ],
      ),
    );
  }

  Future<void> _loadEffectiveDjId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final effectiveDjId = await AdminDjBridge.getEffectiveDjIdByViewMode(user, widget.currentViewRole);
    if (effectiveDjId == null || !mounted) return;

    setState(() {
      _effectiveDjId = effectiveDjId;
    });
    _startPartyStreamAndTimer();
  }

  String _formatDateTime(DateTime date, BuildContext? context) {
    if (context == null) {
      return FormattingUtils.formatCompactDateTimeWithoutContext(date);
    }
    return FormattingUtils.formatDateTime(date, context);
  }

  String _getPartyStatus(DateTime startDate, DateTime endDate, BuildContext context) {
    final now = DateTime.now();
    final localizations = AppLocalizations.of(context)!;
    if (now.compareTo(startDate) < 0) {
      return localizations.party_status_upcoming;
    } else if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
      return localizations.party_status_running;
    } else {
      return localizations.party_status_ended;
    }
  }

  Color _getPartyStatusColor(String status, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final upcoming = localizations.party_status_upcoming;
    final running = localizations.party_status_running;
    
    if (status == upcoming) {
      return Colors.blue;
    } else if (status == running) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  /// Trial-Banner: nur sichtbar wenn Session nicht aktiv (echt FREE) und Trial noch nicht genutzt.
  /// In Kulanz-Pro (Session aktiv) wird das Banner ausgeblendet – kein Gratis-Test-Werbung für Pro-Nutzer.
  Widget _buildTrialBanner(BuildContext context) {
    final userModel = UserScope.userOf(context);
    final sessionActive = UserService().sessionProStatus.value?.isActive == true;
    if (userModel == null || sessionActive || userModel.trialUsed) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: UIConstants.bgGradientEnd,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UIConstants.appOrange, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.dj_home_trial_banner_title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pushNamed('/paywall'),
                style: FilledButton.styleFrom(
                  backgroundColor: UIConstants.appOrange,
                  foregroundColor: Colors.black,
                ),
                child: Text(AppLocalizations.of(context)!.unlock_now_button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Aktiviert eine bevorstehende Party manuell (lifecycle_status: active, is_paused: false)
  Future<void> _startPartyManually(String partyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !mounted) return;
      await FirebaseFirestore.instance.collection('parties').doc(partyId).update({
        'lifecycle_status': 'active',
        'is_paused': false,
      });
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.snackbar_party_started),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.snackbar_error_starting_party} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Pausiert oder setzt eine Party fort (umschaltet is_paused)
  Future<void> _togglePartyPause(String partyId, bool currentPauseState) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !mounted) return;
      final partyRef = FirebaseFirestore.instance.collection('parties').doc(partyId);
      final newPauseState = !currentPauseState;
      final partyDoc = await partyRef.get();
      final currentData = partyDoc.data() as Map<String, dynamic>?;
      final currentPauseLog = currentData?['pause_log'] as List<dynamic>? ?? [];
      final newLogEntry = {
        'type': newPauseState ? 'pause' : 'resume',
        'timestamp': DateTime.now().toIso8601String(),
        'party_id': partyId,
        'dj_id': user.uid,
      };
      final updatedPauseLog = [...currentPauseLog, newLogEntry];
      await partyRef.update({
        'is_paused': newPauseState,
        'pause_log': updatedPauseLog,
      });
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newPauseState ? l.wishbox_paused : l.wishbox_resumed),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.snackbar_error_pausing_wishbox} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPauseConfirmationDialog(BuildContext context, String partyId, String partyName, bool currentPauseState) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          title: Text(
            currentPauseState ? l.dialog_wishbox_confirm_resume : l.dialog_wishbox_confirm_pause,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            currentPauseState ? l.wishbox_pause_confirm_resume(partyName) : l.wishbox_pause_confirm_pause(partyName),
            style: const TextStyle(color: Colors.white70),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: UIConstants.partyYellow, width: 2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l.cancel, style: const TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _togglePartyPause(partyId, currentPauseState);
              },
              child: Text(
                currentPauseState ? l.party_resume : l.party_pause,
                style: const TextStyle(color: UIConstants.appOrange, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEndPartyConfirmationDialog(BuildContext context, String partyId, String partyName) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          title: Text(l.party_confirm_end_title, style: const TextStyle(color: Colors.white)),
          content: Text(
            l.party_confirm_end_body(partyName),
            style: const TextStyle(color: Colors.white70),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: UIConstants.partyYellow, width: 2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l.cancel, style: const TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _endParty(partyId);
              },
              child: Text(
                l.party_confirm_end_action,
                style: const TextStyle(color: UIConstants.appOrange, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _endParty(String partyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !mounted) return;
      // end_date + end_time_posix sofort auf jetzt setzen, damit die Party systemweit als beendet gilt (PWA, Autostart, Heartbeat, Echtzeit-UI)
      final nowUtcSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      await FirebaseFirestore.instance.collection('parties').doc(partyId).update({
        'lifecycle_status': 'finished',
        'finished_at': FieldValue.serverTimestamp(),
        'finished_by': user.uid,
        'finished_manually': true,
        'end_date': Timestamp.now(),
        'end_time_posix': nowUtcSeconds,
      });
      ActivePartyService.stopHeartbeat();
      await PartyAutostartService().stopRecognitionNow();
      if (mounted) {
        setState(() {});
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.snackbar_party_ended_success),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.snackbar_error_ending_party} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUpcomingPartyHomeCard(
    BuildContext context,
    QueryDocumentSnapshot party,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final data = party.data() as Map<String, dynamic>;
    final partyName =
        data['party_name'] as String? ?? localizations.unnamed_party;
    final startTimestamp = data['start_date'] as Timestamp?;
    final endTimestamp = data['end_date'] as Timestamp?;
    if (startTimestamp == null || endTimestamp == null) {
      return const SizedBox.shrink();
    }
    final startDate = startTimestamp.toDate();
    final endDate = endTimestamp.toDate();
    final status = _getPartyStatus(startDate, endDate, context);
    final partyCode = data['party_code'] as String?;
    final partyId = party.id;
    final hasNotStarted = DateTime.now().compareTo(startDate) < 0;
    final statusColor = _getPartyStatusColor(status, context);
    final startTimePosix = data['start_time_posix'] as int?;
    final endTimePosix = data['end_time_posix'] as int?;
    dynamic timezoneIdRaw = data['timezone_id'] ??
        data['timezoneId'] ??
        data['time_zone_id'] ??
        data['timezone'];
    final timezoneId = (timezoneIdRaw != null &&
            timezoneIdRaw is String &&
            timezoneIdRaw.trim().isNotEmpty)
        ? timezoneIdRaw.trim()
        : null;
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    final locationName = data['location_name'] as String?;
    final locationStreet = (data['location_street'] as String?)?.trim();
    final locationZip = (data['location_zip'] as String?)?.trim();
    final locationCity = (data['location_city'] as String?)?.trim();
    final isPaused = data['is_paused'] as bool? ?? false;
    final allowPreWishes = data['allow_pre_wishes'] == true;

    return SettingsPartyCard(
      partyId: partyId,
      partyName: partyName,
      startDate: startDate,
      endDate: endDate,
      partyCode: partyCode,
      status: status,
      statusColor: statusColor,
      hasNotStarted: hasNotStarted,
      timeStream: _timeStream,
      formatDateTime: _formatDateTime,
      startTimePosix: startTimePosix,
      endTimePosix: endTimePosix,
      timezoneId: timezoneId,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      locationStreet: locationStreet?.isNotEmpty == true ? locationStreet : null,
      locationZip: locationZip?.isNotEmpty == true ? locationZip : null,
      locationCity: locationCity?.isNotEmpty == true ? locationCity : null,
      isPaused: hasNotStarted ? true : isPaused,
      hideActions: true,
      hideCalendarExport: true,
      hideMapsLink: false,
      hideBorder: false,
      allowPreWishes: allowPreWishes,
      onEdit: () {},
      onQrCode: () {},
    );
  }

  Widget _buildStatisticsSection(BuildContext context, String? partyId) {
    // Wenn DJ-ID noch nicht geladen ist, zeige Loading-Indikator
    if (_effectiveDjId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Nutze DualStatisticsCard mit onlyFirstCard=true, damit nur die erste Karte (Party-Statistik) angezeigt wird
    // und hideBorder=true, damit kein Rahmen angezeigt wird (wird bereits vom Container oben bereitgestellt)
    // Die DualStatisticsCard identifiziert die Party automatisch, aber wir können partyId als Hinweis übergeben
    // Falls partyId null ist, wird die aktuelle/letzte Party automatisch identifiziert
    return DualStatisticsCard(
      cardBuilder: (context, child) => child, // Kein zusätzlicher Rahmen
      effectiveDjId: _effectiveDjId!,
      onlyFirstCard: true, // Nur erste Karte anzeigen, Rahmen verstecken
      preferredPartyId: partyId, // Von Startseite berechnet: active oder letzte beendete Party
    );
  }

  Widget _buildPartyStatusSection(
    BuildContext context,
    List<QueryDocumentSnapshot> parties,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser!;

    if (_effectiveDjId == null) {
      return _partyStatusLoadingShell(localizations);
    }

    final partySnap = DjHomePartySnapshot.resolve(
      parties,
      gracePeriodMinutes: _gracePeriodMinutes,
    );
    final activeParty = partySnap.activeParty;
    final lastFinishedParty = partySnap.lastFinishedParty;
    final upcomingParty = partySnap.upcomingParty;
    final graceParty = partySnap.graceParty;

    String statusTitle;
    Color statusTitleColor;
    if (activeParty != null) {
      statusTitle = localizations.status_running;
      statusTitleColor = Colors.green;
    } else if (graceParty != null) {
      statusTitle = localizations.party_status_grace_period;
      statusTitleColor = Colors.orange;
    } else if (upcomingParty != null) {
      statusTitle = localizations.status_upcoming;
      statusTitleColor = Colors.white;
    } else {
      statusTitle = localizations.status_no_party_planned;
      statusTitleColor = Colors.white;
    }

    String statsTitle;
    if (activeParty != null) {
      statsTitle = localizations.stats_live;
    } else if (lastFinishedParty != null) {
      statsTitle = localizations.stats_last_party;
    } else {
      statsTitle = localizations.stats_no_party_completed;
    }

    return PwaWidgetCell(
      borderColor: (activeParty ?? graceParty ?? upcomingParty) != null
          ? UIConstants.partyYellow
          : UIConstants.appOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            statusTitle,
            style: TextStyle(
              fontSize: 12,
              color: statusTitleColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final displayParty =
                  activeParty ?? graceParty ?? upcomingParty;

              if (displayParty == null) {
                return Text(
                  localizations.no_further_parties_planned,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                );
              }

              final data = displayParty.data() as Map<String, dynamic>;
              final partyName =
                  data['party_name'] as String? ?? localizations.unnamed_party;
              final startTimestamp = data['start_date'] as Timestamp?;
              final endTimestamp = data['end_date'] as Timestamp?;

              if (startTimestamp == null || endTimestamp == null) {
                return const SizedBox.shrink();
              }

              final startDate = startTimestamp.toDate();
              final endDate = endTimestamp.toDate();
              final isGraceDisplay =
                  graceParty != null && displayParty.id == graceParty.id;
              final status = isGraceDisplay
                  ? localizations.party_status_ended
                  : _getPartyStatus(startDate, endDate, context);
              final partyCode = data['party_code'] as String?;
              final partyId = displayParty.id;
              final hasNotStarted = DateTime.now().compareTo(startDate) < 0;
              final statusColor = isGraceDisplay
                  ? Colors.orange
                  : _getPartyStatusColor(status, context);
              final gracePeriodEndsAt = isGraceDisplay
                  ? PartyGracePeriodHelper.graceEndsAt(
                      endDate,
                      _gracePeriodMinutes,
                    )
                  : null;

              final startTimePosix = data['start_time_posix'] as int?;
              final endTimePosix = data['end_time_posix'] as int?;
              dynamic timezoneIdRaw = data['timezone_id'] ??
                  data['timezoneId'] ??
                  data['time_zone_id'] ??
                  data['timezone'];
              final timezoneId =
                  (timezoneIdRaw != null &&
                          timezoneIdRaw is String &&
                          timezoneIdRaw.trim().isNotEmpty)
                      ? timezoneIdRaw.trim()
                      : null;
              final latitude = (data['latitude'] as num?)?.toDouble();
              final longitude = (data['longitude'] as num?)?.toDouble();
              final locationName = data['location_name'] as String?;
              final locationStreet =
                  (data['location_street'] as String?)?.trim();
              final locationZip = (data['location_zip'] as String?)?.trim();
              final locationCity = (data['location_city'] as String?)?.trim();
              final isPaused = data['is_paused'] as bool? ?? false;
              final running = localizations.party_status_running;
              final isRunning = status == running;
              final isUpcoming = hasNotStarted;
              final userModel = UserScope.userOf(context);
              final lifecycleStatus = data['lifecycle_status'] as String?;
              final nonFinishedParties = parties.where((p) {
                final d = p.data() as Map<String, dynamic>?;
                return d != null &&
                    d['lifecycle_status'] != 'finished' &&
                    d['finished_at'] == null;
              }).toList();
              final quotaExceededIds = (userModel != null && userModel.isFree)
                  ? LimitService.getQuotaExceededPartyIds(
                      userModel,
                      nonFinishedParties,
                    )
                  : <String>{};
              final isDeactivated = lifecycleStatus == 'standby' ||
                  quotaExceededIds.contains(partyId);

              return SettingsPartyCard(
                partyId: partyId,
                partyName: partyName,
                startDate: startDate,
                endDate: endDate,
                partyCode: partyCode,
                status: status,
                statusColor: statusColor,
                hasNotStarted: hasNotStarted,
                timeStream: _timeStream,
                formatDateTime: _formatDateTime,
                startTimePosix: startTimePosix,
                endTimePosix: endTimePosix,
                timezoneId: timezoneId,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName,
                locationStreet:
                    locationStreet?.isNotEmpty == true ? locationStreet : null,
                locationZip: locationZip?.isNotEmpty == true ? locationZip : null,
                locationCity:
                    locationCity?.isNotEmpty == true ? locationCity : null,
                isPaused: isUpcoming ? true : isPaused,
                hideActions: false,
                hideCalendarExport: true,
                hideMapsLink: false,
                hideBorder: true,
                isDeactivated: isDeactivated,
                gracePeriodEndsAt: gracePeriodEndsAt,
                onEdit: () {
                  SettingsPartyEditDialog.show(
                    context,
                    partyId,
                    partyName,
                    startDate,
                    endDate,
                    data['party_type'] as String?,
                    _formatDateTime,
                    currentGuestLimit: data['guest_limit_per_hour'] as int?,
                    currentUserLimit: data['user_limit_per_hour'] as int?,
                  );
                },
                onDelete: isUpcoming
                    ? () => SettingsPartyDeleteDialog.confirm(
                          context,
                          partyId,
                          partyName,
                        )
                    : null,
                onPause: isRunning
                    ? () => _showPauseConfirmationDialog(
                          context,
                          partyId,
                          partyName,
                          isPaused,
                        )
                    : null,
                onEnd: isRunning
                    ? () => _showEndPartyConfirmationDialog(
                          context,
                          partyId,
                          partyName,
                        )
                    : null,
                onQrCode: partyCode != null && partyCode.isNotEmpty
                    ? () async {
                        final locName = locationName?.trim();
                        final street = locationStreet?.trim();
                        final zip = locationZip?.trim();
                        final city = locationCity?.trim();
                        final zipCityPart = [
                          if (zip != null && zip.isNotEmpty) zip,
                          if (city != null && city.isNotEmpty) city,
                        ].join(' ').trim();
                        final addressPart = [
                          if (street != null && street.isNotEmpty) street,
                          if (zipCityPart.isNotEmpty) zipCityPart,
                        ].join(', ');
                        final isExplicitName = locName != null &&
                            locName.isNotEmpty &&
                            (street == null ||
                                street.isEmpty ||
                                locName.toLowerCase() !=
                                    street.toLowerCase()) &&
                            (city == null ||
                                city.isEmpty ||
                                locName.toLowerCase() != city.toLowerCase());
                        final locationDisplay = addressPart.isNotEmpty
                            ? (isExplicitName
                                ? '$locName · $addressPart'
                                : addressPart)
                            : (locName != null && locName.isNotEmpty
                                ? locName
                                : null);
                        final mapsUrl = (latitude != null && longitude != null)
                            ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
                            : null;

                        String? djLogoUrl;
                        String? profileImageUrl;
                        String? djEmail;
                        String? djPhone;
                        String? djAlternativeEmail;
                        try {
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .get();
                          final userData = userDoc.data();
                          djLogoUrl = userData?['djLogoUrl'];
                          profileImageUrl =
                              userData?['profileImageUrl'] ?? user.photoURL;
                          djEmail = user.email ?? userData?['email'] as String?;
                          djPhone = userData?['phoneNumber'] as String?;
                          if (userData?['useAlternativeEmail'] == true) {
                            djAlternativeEmail =
                                userData?['alternativeEmail'] as String?;
                          }
                        } catch (_) {}

                        if (context.mounted) {
                          PartyQrCodeDialog.show(
                            context: context,
                            party: Party(
                              partyName: partyName,
                              startDate: startDate,
                              endDate: endDate,
                              partyCode: partyCode,
                              partyId: partyId,
                              partyLocation: locationDisplay,
                              locationUrl: mapsUrl,
                            ),
                            djName:
                                FirebaseAuth.instance.currentUser?.displayName,
                            djLogoUrl: djLogoUrl,
                            profileImageUrl: profileImageUrl,
                            djEmail: djEmail,
                            djPhone: djPhone,
                            djAlternativeEmail: djAlternativeEmail,
                          );
                        }
                      }
                    : () {},
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            statsTitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          if (activeParty != null || lastFinishedParty != null)
            _buildStatisticsSection(
              context,
              activeParty?.id ?? lastFinishedParty?.id,
            )
          else
            Text(
              localizations.stats_no_party_completed_hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _partyStatusLoadingShell(AppLocalizations localizations) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: UIConstants.appOrange,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localizations.status_no_party_planned,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              localizations.stats_no_party_completed,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    // RTL-Support: Dynamische Textrichtung basierend auf der aktuellen Sprache
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<DjHomeLayoutConfig>(
              valueListenable: DjHomeLayoutService.instance.configNotifier,
              builder: (context, layout, _) {
                return ValueListenableBuilder<SessionProStatus?>(
                  valueListenable: UserService().sessionProStatus,
                  builder: (context, session, _) {
                return ValueListenableBuilder<ActivePartyInfo?>(
                  valueListenable: ActivePartyService.storedSessionNotifier,
                  builder: (context, activeSession, _) {
                final l = AppLocalizations.of(context)!;
                final displayName = _resolveDisplayName(user, l);
                final isFreeDj = session?.isActive != true;
                final trialUsed =
                    UserScope.userOf(context)?.trialUsed ?? true;
                final visibleIds = layout.modularVisibleOrderForSession(
                  isFreeDj: isFreeDj,
                  trialUsed: trialUsed,
                  showPreWishesWidget:
                      activeSession?.hasQueuedPreWishes == true,
                );

                Widget buildWidgets(List<QueryDocumentSnapshot> parties) {
                  final partySnap = DjHomePartySnapshot.resolve(
                    parties,
                    gracePeriodMinutes: _gracePeriodMinutes,
                  );
                  final deps = DjHomeWidgetDeps(
                    effectiveDjId: _effectiveDjId,
                    gracePeriodMinutes: _gracePeriodMinutes,
                    cardBuilder: widget.cardBuilder,
                    partySnapshot: partySnap,
                    parties: parties,
                    timeStream: _timeStream,
                    formatDateTime: _formatDateTime,
                    buildPartyStatusSection: (ctx) =>
                        _buildPartyStatusSection(ctx, parties),
                    buildTrialBanner: _buildTrialBanner,
                    buildUpcomingPartyCard: _buildUpcomingPartyHomeCard,
                    displayName: displayName,
                    onCustomizeHome: () => showDjHomeEditSheet(context),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WelcomeHeader(
                        displayNameOrFallback: displayName,
                        onCustomize: () => showDjHomeEditSheet(context),
                      ),
                      const SizedBox(height: 16),
                      for (final id in visibleIds)
                        if (DjHomeWidgetHost.build(context, id, deps)
                            case final child?)
                          ...[
                            child,
                            const SizedBox(height: 16),
                          ],
                    ],
                  );
                }

                if (_effectiveDjId == null) {
                  return buildWidgets(const []);
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('parties')
                      .where('created_by', isEqualTo: _effectiveDjId!)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final parties = snapshot.hasData
                        ? snapshot.data!.docs
                        : (_cachedParties ?? []);
                    return buildWidgets(parties);
                  },
                );
                  },
                );
                  },
                );
              },
            ),
            if (widget.adminRoleSwitcherBottom != null) ...[
              widget.adminRoleSwitcherBottom!,
              const SizedBox(height: 24),
            ],
            const SizedBox(height: 200),
          ],
        ),
      ),
    );
  }
}
