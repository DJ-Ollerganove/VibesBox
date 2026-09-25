import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'pages/neue_party_page.dart';
import 'pages/beendete_partys_page.dart';
import 'l10n/app_localizations.dart';
import 'utils/formatting_utils.dart';
import 'utils/ui_constants.dart';
import 'utils/party_qr_launch_helper.dart';
import 'widgets/custom_page_header.dart';
import 'widgets/settings_help_dialog.dart';
import 'pages/dj_setlists_library_page.dart';
import 'services/active_party_service.dart';
import 'services/pro_feature_guard.dart';
import 'widgets/free_feature_locked.dart';
import 'services/party_autostart_service.dart';
import 'services/party_secure_service.dart';
import 'settings_party_edit_dialog.dart';
import 'settings_party_card_widget.dart';
import 'services/user_service.dart';
import 'services/navigation_service.dart';
import 'services/limit_service.dart';
import 'services/party_limit_service.dart';
import 'widgets/pro_promotion_banner.dart';
import 'models/user_model.dart';
import 'utils/debug_log.dart';
import 'app_scaffold_messenger.dart';
import 'pages/home/dj/dj_home_party_utils.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

// Party-Verwaltungsseite für Admin
class PartyVerwaltungPage extends StatefulWidget {
  /// Wird aufgerufen, wenn "Beendete Partys" geöffnet werden soll (Integration ins Haupt-Scaffold).
  final VoidCallback? onOpenEndedPartys;
  /// Admin-DJ-Ansicht: gleiche effektive DJ-ID wie auf der Startseite.
  final String? currentViewRole;

  const PartyVerwaltungPage({
    super.key,
    this.onOpenEndedPartys,
    this.currentViewRole,
  });

  @override
  State<PartyVerwaltungPage> createState() => _PartyVerwaltungPageState();
}

class _PartyVerwaltungPageState extends State<PartyVerwaltungPage> {
  bool _showEndedPartys = false;
  StreamController<DateTime>? _timeController;
  Timer? _timeTimer;

  Stream<DateTime> get _timeStream {
    _timeController ??= StreamController<DateTime>.broadcast();
    _timeController!.add(DateTime.now());
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_timeController != null && !_timeController!.isClosed) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = UserService().currentUser.value;
      if (user != null) {
        PartyLimitService.syncPartyStates(user);
      }
    });
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _timeController?.close();
    super.dispose();
  }

  String _formatDateTime(DateTime date, BuildContext? context) {
    if (context == null) {
      return FormattingUtils.formatCompactDateTimeWithoutContext(date);
    }
    return FormattingUtils.formatDateTime(date, context);
  }

  String _getPartyStatus(DateTime startDate, DateTime endDate, BuildContext context) {
    return DjHomePartyUtils.statusFromDates(startDate, endDate, context);
  }

  Color _getPartyStatusColor(String status, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final upcoming = l.party_status_upcoming;
    final running = l.party_status_running;
    final ended = l.party_status_ended;
    
    if (status == upcoming) {
      return Colors.blue;
    } else if (status == running) {
      return Colors.green;
    } else if (status == ended) {
      return Colors.grey;
    } else {
      return Colors.grey;
    }
  }

  /// Formatiert ein Datum lesbar für die Abrechnungszeitraum-Anzeige (App-Sprache).
  String _formatBillingDate(BuildContext context, DateTime date) {
    return FormattingUtils.formatDateForLocale(date, context);
  }

  /// Card mit aktuellem Abrechnungszeitraum für Free-DJ (Stichtag-Logik).
  /// Format: [L10n: Laufender Monat]: [Startdatum] bis [Enddatum], Datum sprachabhängig.
  Widget _buildBillingPeriodCard(BuildContext context, UserModel user) {
    final anchorDay = LimitService.getAnchorDay(user);
    final period = LimitService.getAbrechnungsZeitraum(DateTime.now(), anchorDay);
    final startStr = _formatBillingDate(context, period.start);
    final endStr = _formatBillingDate(context, period.end);
    final loc = AppLocalizations.of(context)!;
    final label = loc.current_billing_period;
    final to = loc.billing_period_to;
    final text = '$label: $startStr $to $endStr';
    return Container(
      decoration: UIConstants.djChromePanelDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: UIConstants.appOrange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Zeigt Sicherheitsdialog für Party-Löschung
  void _showDeleteConfirmationDialog(BuildContext context, String partyId, String partyName) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localizations.party_delete_title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            localizations.party_delete_confirm(partyName),
            style: const TextStyle(color: Colors.white70),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
          actions: [
            // Abbrechen-Button
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70, width: 1),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                localizations.party_cancel,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            // Löschen-Button (Rot)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteParty(partyId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                localizations.party_delete,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Löscht eine Party aus Firestore
  /// Prüft: DJ-Berechtigung (created_by), Zeit-Check (noch nicht gestartet)
  Future<void> _deleteParty(String partyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(l.snackbar_party_not_logged_in_long),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      // 1. Party-Dokument laden für Validierung
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();

      if (!partyDoc.exists) {
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(l.snackbar_party_not_found),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final partyData = partyDoc.data() as Map<String, dynamic>;

      // 2. DJ-Check: Nur der Ersteller darf löschen
      final createdBy = partyData['created_by'] as String?;
      final localizations = AppLocalizations.of(context)!;
      if (createdBy != user.uid) {
        debugLog('❌ Löschung verweigert: nicht der Ersteller');
        if (mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(localizations.delete_party_only_own),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 3. Zeit-Check: Party darf noch nicht gestartet sein
      final now = DateTime.now();
      final nowUnix = now.millisecondsSinceEpoch ~/ 1000; // Unix-Timestamp in Sekunden

      // Prüfe start_time_posix (falls vorhanden)
      final startTimePosix = partyData['start_time_posix'] as int? ??
          partyData['startTimePosix'] as int? ??
          partyData['start_time_posix_seconds'] as int? ??
          partyData['startTimePosixSeconds'] as int?;

      // Falls start_time_posix vorhanden, nutze es (kann Sekunden oder Millisekunden sein)
      int? startTimeSeconds;
      if (startTimePosix != null) {
        // Prüfe ob es Sekunden oder Millisekunden sind (Sekunden wenn < 1e10)
        startTimeSeconds = startTimePosix < 10000000000 
            ? startTimePosix 
            : (startTimePosix ~/ 1000);
      }

      // Falls kein start_time_posix, nutze start_date (Timestamp)
      DateTime? startDate;
      if (startTimeSeconds == null) {
        final startTimestamp = partyData['start_date'] as Timestamp?;
        if (startTimestamp != null) {
          startDate = startTimestamp.toDate();
        }
      } else {
        startDate = DateTime.fromMillisecondsSinceEpoch(startTimeSeconds * 1000);
      }

      if (startDate == null) {
        debugLog('⚠️ Keine Startzeit gefunden für Party $partyId');
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(l.error_party_start_time_unknown),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Zeit-Check: Party darf nur gelöscht werden, wenn sie noch nicht begonnen hat
      if (now.isAfter(startDate) || now.isAtSameMomentAs(startDate)) {
        debugLog('❌ Löschung verweigert: Party $partyId hat bereits begonnen (Start: $startDate, Jetzt: $now)');
        if (mounted) {
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(localizations.party_delete_not_started),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // 4. Alle Checks bestanden - Party löschen
      await FirebaseFirestore.instance.collection('parties').doc(partyId).delete();
      
      debugLog('Party gelöscht');
      
      if (mounted) {
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(localizations.party_deleted_success),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseException catch (e) {
      debugLog('❌ Firebase-Fehler beim Löschen: ${e.code} - ${e.message}');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        String errorMessage = loc.party_delete_error;
        if (e.code == 'permission-denied') {
          errorMessage = loc.party_delete_permission_denied;
        } else {
          errorMessage = '${loc.party_error_deleting} ${e.message ?? e.code}';
        }
        showVibesSnackBar(context, 
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Unerwarteter Fehler beim Löschen: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${loc.party_error_deleting} $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Zeigt Sicherheitsdialog für Party-Pause
  void _showPauseConfirmationDialog(BuildContext context, String partyId, String partyName, bool currentPauseState) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final l = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          title: Text(
            currentPauseState ? l.dialog_wishbox_confirm_resume : l.dialog_wishbox_confirm_pause,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            currentPauseState
                ? l.wishbox_pause_confirm_resume(partyName)
                : l.wishbox_pause_confirm_pause(partyName),
            style: const TextStyle(color: Colors.white70),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: UIConstants.partyYellow, width: 2),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                l.cancel,
                style: const TextStyle(color: Colors.white70),
              ),
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

  /// Pausiert oder setzt eine Party fort (umschaltet is_paused)
  Future<void> _togglePartyPause(String partyId, bool currentPauseState) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(l.snackbar_not_logged_in_short),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final partyRef = FirebaseFirestore.instance.collection('parties').doc(partyId);
      final newPauseState = !currentPauseState;
      final pauseType = newPauseState ? 'pause' : 'resume';

      // Hole aktuelles pause_log Array oder erstelle neues
      final partyDoc = await partyRef.get();
      final currentData = partyDoc.data() as Map<String, dynamic>?;
      final currentPauseLog = currentData?['pause_log'] as List<dynamic>? ?? [];

      // Erstelle neuen Log-Eintrag (ISO8601 String statt ServerTimestamp für Arrays)
      final newLogEntry = {
        'type': pauseType,
        'timestamp': DateTime.now().toIso8601String(), // ISO8601 String statt FieldValue.serverTimestamp()
        'party_id': partyId, // Lange Party-ID
        'dj_id': user.uid, // DJ-ID
      };

      // Füge neuen Eintrag zum Array hinzu
      final updatedPauseLog = [...currentPauseLog, newLogEntry];

      // Update Party-Dokument (serverseitig — Client-Rules blockieren Pause sonst oft)
      await PartySecureService.instance.updateParty(
        partyId: partyId,
        patch: {
          'is_paused': newPauseState,
          'pause_log': updatedPauseLog,
        },
      );

      if (mounted) {
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
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
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${l.snackbar_error_pausing_wishbox} $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Beendet eine Party manuell (setzt lifecycle_status auf 'finished')
  void _showEndPartyConfirmationDialog(BuildContext context, String partyId, String partyName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final l = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          title: Text(
            l.party_confirm_end_title,
            style: const TextStyle(color: Colors.white),
          ),
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                l.cancel,
                style: const TextStyle(color: Colors.white70),
              ),
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

  /// Beendet die Party: setzt lifecycle_status + end_date auf jetzt, stoppt Heartbeat sofort.
  Future<void> _endParty(String partyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(l.snackbar_not_logged_in_short),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final nowUtcSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      await PartySecureService.instance.updateParty(
        partyId: partyId,
        patch: {
          'lifecycle_status': 'finished',
          'finished_at': Timestamp.now(),
          'finished_by': user.uid,
          'finished_manually': true,
          'end_date': Timestamp.now(),
          'end_time_posix': nowUtcSeconds,
        },
      );
      ActivePartyService.stopHeartbeat();
      await PartyAutostartService().stopRecognitionNow();

      if (mounted) {
        setState(() {});
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
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
        showVibesSnackBar(context, 
          SnackBar(
            content: Text('${l.snackbar_error_ending_party} $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    final isRtl = VbTextDirection.isRtl(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ValueListenableBuilder<SessionProStatus?>(
          valueListenable: UserService().sessionProStatus,
          builder: (context, session, _) {
            return ValueListenableBuilder<UserModel?>(
              valueListenable: UserService().currentUser,
              builder: (context, user, __) {
                return Column(
                  children: [
                    // Titelleiste mit CustomPageHeader (erstes Kind)
                    CustomPageHeader(
                      icon: Icons.event,
                      title: AppLocalizations.of(context)!.party_management_title,
                      actionsBelowTitle: true,
                      onInfoPressed: () => showPageInfoHelp(
                        context,
                        titleKey: 'party_management_title',
                        prefix: 'info_page_party_management',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.queue_music),
                            color: UIConstants.colorDjSetlist,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            tooltip: AppLocalizations.of(context)!
                                .translate('dj_setlist_ai_title'),
                            onPressed: () {
                              final l = AppLocalizations.of(context)!;
                              if (!ProFeatureGuard.canUseProExclusiveNow()) {
                                FreeFeatureLockedDialog.show(
                                  context,
                                  title: l.free_feature_dj_setlist_title,
                                  description:
                                      l.free_feature_dj_setlist_description,
                                );
                                return;
                              }
                              DjSetlistsLibraryPage.requestCreate();
                              NavigationService().setTabIndex(12);
                            },
                          ),
                          _NewPartyButton(session: session, user: user),
                          IconButton(
                            icon: const Icon(Icons.archive),
                            color: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            tooltip: AppLocalizations.of(context)!.ended_parties_title,
                            onPressed: () {
                              setState(() {
                                _showEndedPartys = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Abrechnungszeitraum-Info nur für Free-DJ (unter Titel, über der Liste)
                    if (user != null && user.isFree && !_showEndedPartys) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _buildBillingPeriodCard(context, user),
                      ),
                    ],
                    // Content-Bereich (zweites Kind): entweder eingebettete Beendete-Partys-Seite oder Party-Liste
                    Expanded(
              child: _showEndedPartys
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            AppLocalizations.of(context)!.party_history_title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              icon: const Icon(Icons.arrow_back, size: 20, color: Colors.white70),
                              label: Text(
                                AppLocalizations.of(context)!.back,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              onPressed: () => setState(() => _showEndedPartys = false),
                            ),
                          ),
                        ),
                        const Expanded(child: BeendetePartysPage(embeddedInMainScaffold: true)),
                      ],
                    )
                  : SingleChildScrollView(
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
                      _buildPartyList(session: session, user: user),
                    ],
                  ),
                ),
                    ),
                  ],
                );
          },
          );
          },
        ),
      ),
    );
  }

  DateTime? _partyStartDate(Map<String, dynamic> data) {
    final startTs = data['start_date'] as Timestamp?;
    if (startTs != null) return startTs.toDate();
    return DjHomePartyUtils.partyStartDate(data);
  }

  DateTime? _partyEndDate(Map<String, dynamic> data) {
    final endTs = data['end_date'] as Timestamp?;
    if (endTs != null) return endTs.toDate();
    return DjHomePartyUtils.partyEndDate(data);
  }

  /// Backup-Logik (git HEAD) + posix-Fallback für Start/Ende.
  Widget _buildPartyList({
    required SessionProStatus? session,
    required UserModel? user,
  }) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      final l = AppLocalizations.of(context)!;
      return Text(
        l.not_logged_in,
        style: const TextStyle(color: Colors.white),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: authUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final l = AppLocalizations.of(context)!;
          return Text(
            '${l.error_loading_prefix}: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }
        final parties = snapshot.data?.docs ?? [];

        return StreamBuilder<DateTime>(
          stream: _timeStream,
          initialData: DateTime.now(),
          builder: (context, timeSnapshot) {
            final localizations = AppLocalizations.of(context)!;
            final runningLabel = localizations.party_status_running;
            final upcomingLabel = localizations.party_status_upcoming;

            final runningParties = <QueryDocumentSnapshot>[];
            final upcomingParties = <QueryDocumentSnapshot>[];

            for (final party in parties) {
              final data = party.data() as Map<String, dynamic>;
              if (data['lifecycle_status'] == 'finished' ||
                  data['finished_at'] != null) {
                continue;
              }
              final startDate = _partyStartDate(data);
              final endDate = _partyEndDate(data);
              if (startDate == null || endDate == null) continue;

              final status = _getPartyStatus(startDate, endDate, context);
              if (status == runningLabel) {
                runningParties.add(party);
              } else if (status == upcomingLabel) {
                upcomingParties.add(party);
              }
            }

            runningParties.sort((a, b) {
              final sa = _partyStartDate(a.data() as Map<String, dynamic>);
              final sb = _partyStartDate(b.data() as Map<String, dynamic>);
              return (sa ?? DateTime(0)).compareTo(sb ?? DateTime(0));
            });
            upcomingParties.sort((a, b) {
              final sa = _partyStartDate(a.data() as Map<String, dynamic>);
              final sb = _partyStartDate(b.data() as Map<String, dynamic>);
              return (sa ?? DateTime(0)).compareTo(sb ?? DateTime(0));
            });

            final nonFinishedParties = <QueryDocumentSnapshot>[
              ...runningParties,
              ...upcomingParties,
            ];
            final quotaExceededIds = (user != null && user.isFree)
                ? LimitService.getQuotaExceededPartyIds(user, nonFinishedParties)
                : <String>{};

            Widget buildSectionHeader(String title, Color color) {
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12, left: 4),
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }

            Widget buildPartyCard(QueryDocumentSnapshot party) {
              final data = party.data() as Map<String, dynamic>;
              final partyName =
                  data['party_name'] as String? ?? localizations.unnamed_party;
              final startDate = _partyStartDate(data);
              final endDate = _partyEndDate(data);
              if (startDate == null || endDate == null) {
                return const SizedBox.shrink();
              }
              final partyCode = data['party_code'] as String?;
              final partyId = party.id;
              final status = _getPartyStatus(startDate, endDate, context);
              final hasNotStarted = DateTime.now().isBefore(startDate);
              final statusColor = _getPartyStatusColor(status, context);
              final lifecycleStatus = data['lifecycle_status'] as String?;
              final isPaused = data['is_paused'] as bool? ?? false;
              final allowPreWishes = data['allow_pre_wishes'] == true;

              final startTimePosix =
                  (data['start_time_posix'] as int?) ??
                  (data['start_date'] as Timestamp?)?.seconds;
              final endTimePosix =
                  (data['end_time_posix'] as int?) ??
                  (data['end_date'] as Timestamp?)?.seconds;

              final auth = FirebaseAuth.instance.currentUser;
              final createdBy = data['created_by'] as String?;
              final isOwner = auth != null && createdBy == auth.uid;
              final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
              final partyNotStarted =
                  (startTimePosix ?? 0) > 0 && nowUnix < (startTimePosix ?? 0);
              final isUpcomingLifecycle =
                  lifecycleStatus == 'active' || lifecycleStatus == 'upcoming';
              final isStandbyLifecycle = lifecycleStatus == 'standby';
              final canDelete = isOwner &&
                  partyNotStarted &&
                  (isUpcomingLifecycle ||
                      isStandbyLifecycle ||
                      quotaExceededIds.contains(partyId));

              return SettingsPartyCard(
                key: ValueKey('party-card-$partyId'),
                allowPastScheduledEnd: true,
                partyId: partyId,
                partyName: partyName,
                partyType: data['party_type'] as String?,
                floorKey: data['floor_key'] as String?,
                floorLabel: data['floor_label'] as String?,
                allowPreWishes: allowPreWishes,
                startDate: startDate,
                endDate: endDate,
                partyCode: partyCode,
                status: status,
                statusColor: statusColor,
                hasNotStarted: hasNotStarted,
                isDeactivated: lifecycleStatus == 'standby' ||
                    quotaExceededIds.contains(partyId),
                timeStream: _timeStream,
                formatDateTime: _formatDateTime,
                borderColor: UIConstants.partyYellow,
                locationName: data['location_name'] as String?,
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
                onDelete: canDelete
                    ? () => _showDeleteConfirmationDialog(
                          context,
                          partyId,
                          partyName,
                        )
                    : null,
                onPause: status == runningLabel
                    ? () => _showPauseConfirmationDialog(
                          context,
                          partyId,
                          partyName,
                          isPaused,
                        )
                    : null,
                onEnd: status == runningLabel
                    ? () => _showEndPartyConfirmationDialog(
                          context,
                          partyId,
                          partyName,
                        )
                    : null,
                onQrCode: partyCode != null
                    ? () => PartyQrLaunchHelper.showForPartyData(
                          context: context,
                          partyId: partyId,
                          data: data,
                        )
                    : () {},
                isPaused: isPaused,
                startTimePosix: startTimePosix,
                endTimePosix: endTimePosix,
              );
            }

            final hasManaged = runningParties.isNotEmpty ||
                upcomingParties.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (runningParties.isNotEmpty) ...[
                  buildSectionHeader(runningLabel, Colors.green),
                  ...runningParties.map(buildPartyCard),
                ],
                if (upcomingParties.isNotEmpty) ...[
                  buildSectionHeader(upcomingLabel, UIConstants.appOrange),
                  ...upcomingParties.map(buildPartyCard),
                ],
                if (!hasManaged)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      localizations.no_further_parties_planned,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ),
                if (session?.isActive != true) ...[
                  const SizedBox(height: 20),
                  ProPromotionBanner(
                    message: localizations.party_management_pro_banner,
                    compactPadding: false,
                  ),
                ],
                const SizedBox(height: UIConstants.kFooterPadding * 2),
              ],
            );
          },
        );
      },
    );
  }
}


/// Button „Neue Party“: Bei Pro immer aktiv, bei Free nur wenn Kontingent nicht ausgeschöpft (sonst ausgegraut, Klick zeigt Dialog).
class _NewPartyButton extends StatefulWidget {
  final SessionProStatus? session;
  final UserModel? user;

  const _NewPartyButton({this.session, this.user});

  @override
  State<_NewPartyButton> createState() => _NewPartyButtonState();
}

class _NewPartyButtonState extends State<_NewPartyButton> {
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final user = widget.user;
    final isLoggedIn = session != null && user != null;

    if (!isLoggedIn) {
      return IconButton(
        icon: const Icon(Icons.add_circle_outline),
        color: Colors.grey,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: null,
        tooltip: AppLocalizations.of(context)!.new_party,
      );
    }

    // Wizard immer öffnen; Limit-Check erfolgt im Wizard bei Datumswahl (Stichtag-Logik).
    return IconButton(
      icon: const Icon(Icons.add_circle_outline),
      color: UIConstants.appOrange,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      tooltip: AppLocalizations.of(context)!.new_party,
      onPressed: () => NeuePartyPage.show(context),
    );
  }
}
