import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'pages/neue_party_page.dart';
import 'pages/beendete_partys_page.dart';
import 'l10n/app_localizations.dart';
import 'utils/formatting_utils.dart';
import 'utils/ui_constants.dart';
import 'widgets/party_qr_code_dialog.dart' show Party, PartyQrCodeDialog;
import 'widgets/custom_page_header.dart';
import 'widgets/sticky_pagination_layout.dart';
import 'services/active_party_service.dart';
import 'services/party_autostart_service.dart';
import 'settings_party_edit_dialog.dart';
import 'settings_party_card_widget.dart';
import 'services/user_service.dart';
import 'services/limit_service.dart';
import 'services/party_limit_service.dart';
import 'widgets/pro_promotion_banner.dart';
import 'models/user_model.dart';
import 'utils/debug_log.dart';

// Party-Verwaltungsseite für Admin
class PartyVerwaltungPage extends StatefulWidget {
  /// Wird aufgerufen, wenn "Beendete Partys" geöffnet werden soll (Integration ins Haupt-Scaffold).
  final VoidCallback? onOpenEndedPartys;

  const PartyVerwaltungPage({super.key, this.onOpenEndedPartys});

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
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
      return '$day.$month.$year um ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} Uhr';
    }
    return FormattingUtils.formatDateTime(date, context);
  }

  String _getPartyStatus(DateTime startDate, DateTime endDate, BuildContext context) {
    final now = DateTime.now();
    final l = AppLocalizations.of(context)!;
    // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende (Endzeit ist exklusiv)
    if (now.compareTo(startDate) < 0) {
      return l.party_status_upcoming;
    } else if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
      return l.party_status_running;
    } else {
      return l.party_status_ended;
    }
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

  /// Formatiert ein Datum lesbar (z. B. 06.02.2026) für die Abrechnungszeitraum-Anzeige.
  static String _formatBillingDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  /// Card mit aktuellem Abrechnungszeitraum für Free-DJ (Stichtag-Logik).
  /// Format: [L10n: Laufender Monat]: [Startdatum] bis [Enddatum], Datum dd.MM.yyyy.
  Widget _buildBillingPeriodCard(BuildContext context, UserModel user) {
    final anchorDay = LimitService.getAnchorDay(user);
    final period = LimitService.getAbrechnungsZeitraum(DateTime.now(), anchorDay);
    final startStr = _formatBillingDate(period.start);
    final endStr = _formatBillingDate(period.end);
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
        ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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

      // Update Party-Dokument
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.snackbar_not_logged_in_short),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

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
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _NewPartyButton(session: session, user: user),
                          // Icon 2: Beendete Partys – eingebettet im bestehenden Layout (mit DJ-Navigation)
                          IconButton(
                            icon: const Icon(Icons.archive),
                            color: Colors.white,
                            tooltip: AppLocalizations.of(context)!.ended_parties_title,
                            onPressed: () {
                              setState(() => _showEndedPartys = true);
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: TextButton.icon(
                            icon: const Icon(Icons.arrow_back, size: 20, color: Colors.white70),
                            label: Text(
                              AppLocalizations.of(context)!.back,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            onPressed: () => setState(() => _showEndedPartys = false),
                          ),
                        ),
                        const Expanded(child: BeendetePartysPage(embeddedInMainScaffold: true)),
                      ],
                    )
                  : StickyPaginationLayout(
                currentPage: 1,
                totalPages: 1,
                onPrevious: null,
                onNext: null,
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
                      // Liste der Partys
                      StreamBuilder<QuerySnapshot>(
                stream: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    // Wenn kein User eingeloggt, leere Query zurückgeben
                    return FirebaseFirestore.instance
                        .collection('parties')
                        .where('created_by', isEqualTo: '')
                        .snapshots();
                  }
                  // Filtere nach created_by, damit jeder DJ nur seine eigenen Partys sieht
                  return FirebaseFirestore.instance
                      .collection('parties')
                      .where('created_by', isEqualTo: user.uid)
                      .snapshots();
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('${AppLocalizations.of(context)!.party_error} ${snapshot.error}'),
                    );
                  }
                  final parties = snapshot.data?.docs ?? [];

                  // Zeit-Tick: Gruppierung bei jedem _timeStream-Tick neu berechnen (wie home_dj setState),
                  // damit „Läuft“ → „Beendet“ beim Zeitablauf ohne Firestore-Update umschaltet.
                  return StreamBuilder<DateTime>(
                    stream: _timeStream,
                    initialData: DateTime.now(),
                    builder: (context, timeSnapshot) {
                  // Gruppiere Partys: Laufend und Bevorstehend (basierend auf Start-/Enddatum)
                  // WICHTIG: Keine Filterung nach lifecycle_status - nutze die gesamte Datenbasis
                  // Die Anzeige basiert ausschließlich auf dem berechneten UI-Status (_getPartyStatus)
                  final localizations = AppLocalizations.of(context)!;
                  final running = localizations.party_status_running;
                  final upcoming = localizations.party_status_upcoming;

                  final runningParties = <QueryDocumentSnapshot>[];
                  final upcomingParties = <QueryDocumentSnapshot>[];

                  // Iteriere über ALLE Partys; Echtzeit: lifecycle_status/finished_at = sofort "Beendet"
                  for (final party in parties) {
                    final data = party.data() as Map<String, dynamic>;
                    if (data['lifecycle_status'] == 'finished' || data['finished_at'] != null) continue;
                    final startTimestamp = data['start_date'] as Timestamp?;
                    final endTimestamp = data['end_date'] as Timestamp?;

                    if (startTimestamp == null || endTimestamp == null) continue;

                    final startDate = startTimestamp.toDate();
                    final endDate = endTimestamp.toDate();
                    final status = _getPartyStatus(startDate, endDate, context);

                    if (status == running) {
                      runningParties.add(party);
                    } else if (status == upcoming) {
                      upcomingParties.add(party);
                    }
                  }

                  // Sortierung innerhalb der Gruppen (nach Startdatum aufsteigend)
                  runningParties.sort((a, b) {
                    final startA = (a.data() as Map<String, dynamic>)['start_date'] as Timestamp;
                    final startB = (b.data() as Map<String, dynamic>)['start_date'] as Timestamp;
                    return startA.toDate().compareTo(startB.toDate());
                  });

                  upcomingParties.sort((a, b) {
                    final startA = (a.data() as Map<String, dynamic>)['start_date'] as Timestamp;
                    final startB = (b.data() as Map<String, dynamic>)['start_date'] as Timestamp;
                    return startA.toDate().compareTo(startB.toDate());
                  });

                  // Dynamische Slot-Validierung: Free-DJ – pro Abrechnungszeitraum nur erste Party aktiv
                  final nonFinishedParties = <QueryDocumentSnapshot>[...runningParties, ...upcomingParties];
                  final quotaExceededIds = (user != null && user.isFree)
                      ? LimitService.getQuotaExceededPartyIds(user, nonFinishedParties)
                      : <String>{};

                  // Helper-Funktion für Party-Card
                  Widget buildPartyCard(QueryDocumentSnapshot party) {
                    final data = party.data() as Map<String, dynamic>;
                    final partyName = data['party_name'] as String? ?? localizations.unnamed_party;
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
                    
                    // Extrahiere Location und Timezone-Daten (Firestore liefert num → sicher zu double konvertieren)
                    final locationName = data['location_name'] as String?;
                    final locationStreet = (data['location_street'] as String?)?.trim();
                    final locationZip = (data['location_zip'] as String?)?.trim();
                    final locationCity = (data['location_city'] as String?)?.trim();
                    final latitude = (data['latitude'] as num?)?.toDouble();
                    final longitude = (data['longitude'] as num?)?.toDouble();
                    
                    // Prüfe verschiedene Feldnamen für timezone_id und behandle "null" Strings
                    dynamic timezoneIdRaw = data['timezone_id'] ?? 
                                           data['timezoneId'] ?? 
                                           data['time_zone_id'] ??
                                           data['timezone'];
                    
                    // Konvertiere "null" String zu null und prüfe auf leere Strings
                    // STANDARDWERT: Nutze System-Zeitzone wenn nicht vorhanden
                    String? timezoneId;
                    if (timezoneIdRaw == null) {
                      // Standardwert: System-Zeitzone ermitteln
                      final systemOffset = DateTime.now().timeZoneOffset.inHours;
                      if (systemOffset == 1 || systemOffset == 2) {
                        timezoneId = 'Europe/Berlin'; // Standard für Deutschland
                      } else {
                        timezoneId = null; // Wird später im Widget behandelt
                      }
                    } else if (timezoneIdRaw is String) {
                      // Behandle "null" String, leere Strings und Whitespace
                      final cleaned = timezoneIdRaw.trim();
                      if (cleaned.isEmpty || 
                          cleaned.toLowerCase() == 'null' || 
                          cleaned == '') {
                        // Standardwert statt null
                        final systemOffset = DateTime.now().timeZoneOffset.inHours;
                        timezoneId = (systemOffset == 1 || systemOffset == 2) ? 'Europe/Berlin' : null;
                      } else {
                        timezoneId = cleaned;
                      }
                    } else {
                      // Versuche zu String zu konvertieren
                      final converted = timezoneIdRaw.toString().trim();
                      if (converted.isEmpty || converted.toLowerCase() == 'null') {
                        // Standardwert statt null
                        final systemOffset = DateTime.now().timeZoneOffset.inHours;
                        timezoneId = (systemOffset == 1 || systemOffset == 2) ? 'Europe/Berlin' : null;
                      } else {
                        timezoneId = converted;
                      }
                    }
                    
                    final lifecycleStatus = data['lifecycle_status'] as String?;
                    final isPaused = data['is_paused'] as bool? ?? false;
                    
                    // startTimePosix kann als int (Sekunden) oder int (Millisekunden) gespeichert sein
                    // Prüfe verschiedene Feldnamen
                    final startTimePosixRaw = data['startTimePosix'] ?? 
                                             data['start_time_posix'] ?? 
                                             data['startTimePosixSeconds'] ??
                                             data['start_time_posix_seconds'];
                    
                    int? startTimePosix;
                    
                    if (startTimePosixRaw != null) {
                      if (startTimePosixRaw is int) {
                        startTimePosix = startTimePosixRaw < 10000000000 
                            ? startTimePosixRaw 
                            : (startTimePosixRaw ~/ 1000);
                      } else if (startTimePosixRaw is String) {
                        final parsed = int.tryParse(startTimePosixRaw);
                        if (parsed != null) {
                          startTimePosix = parsed < 10000000000 ? parsed : (parsed ~/ 1000);
                        }
                      }
                    }
                    
                    if (startTimePosix == null || startTimePosix <= 0) {
                      startTimePosix = startTimestamp.seconds;
                    }
                    
                    // endTimePosix extrahieren (analog zu startTimePosix)
                    final endTimePosixRaw = data['endTimePosix'] ?? 
                                           data['end_time_posix'] ?? 
                                           data['endTimePosixSeconds'] ??
                                           data['end_time_posix_seconds'];
                    
                    int? endTimePosix;
                    
                    if (endTimePosixRaw != null) {
                      if (endTimePosixRaw is int) {
                        endTimePosix = endTimePosixRaw < 10000000000 
                            ? endTimePosixRaw 
                            : (endTimePosixRaw ~/ 1000);
                      } else if (endTimePosixRaw is String) {
                        final parsed = int.tryParse(endTimePosixRaw);
                        if (parsed != null) {
                          endTimePosix = parsed < 10000000000 ? parsed : (parsed ~/ 1000);
                        }
                      }
                    }
                    
                    if (endTimePosix == null || endTimePosix <= 0) {
                      endTimePosix = endTimestamp.seconds;
                    }
                    
                    if (timezoneId == null || timezoneId.isEmpty) {
                      final systemOffset = DateTime.now().timeZoneOffset.inHours;
                      if (systemOffset == 1 || systemOffset == 2) {
                        timezoneId = 'Europe/Berlin';
                      } else if (systemOffset == 0) {
                        timezoneId = 'Europe/London';
                      } else {
                        timezoneId = 'UTC';
                      }
                    }
                    
                    // GEZIELTE LÖSCH-LOGIK: Prüfe mehrere Bedingungen
                    // 1. User muss der Ersteller sein (created_by)
                    // 2. Party muss noch nicht gestartet haben (start_time_posix > jetzt)
                    // 3. lifecycle_status muss "active" oder "upcoming" sein
                    final user = FirebaseAuth.instance.currentUser;
                    final createdBy = data['created_by'] as String?;
                    final isOwner = user != null && createdBy == user.uid;
                    
                    // Zeit-Check: Party darf noch nicht gestartet haben
                    final nowUnixSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
                    final partyNotStarted = startTimePosix != null && startTimePosix > 0 && nowUnixSeconds < startTimePosix;
                    
                    // Status-Check: Party muss lifecycle_status "active" oder "upcoming" haben
                    // Nutze die bereits vorhandene Variable lifecycleStatus (deklariert in Zeile 709)
                    final isUpcoming = lifecycleStatus == 'active' || lifecycleStatus == 'upcoming';
                    
                    // canDelete ist nur true, wenn ALLE Bedingungen erfüllt sind
                    final canDelete = isOwner && partyNotStarted && isUpcoming;
                    
                    return SettingsPartyCard(
                      partyId: partyId,
                      partyName: partyName,
                      startDate: startDate,
                      endDate: endDate,
                      partyCode: partyCode,
                      status: status,
                      statusColor: statusColor,
                      hasNotStarted: hasNotStarted,
                      isDeactivated: lifecycleStatus == 'standby' || quotaExceededIds.contains(partyId),
                      timeStream: _timeStream,
                      formatDateTime: _formatDateTime,
                      borderColor: UIConstants.partyYellow,
                      locationName: locationName,
                      locationStreet: locationStreet?.isNotEmpty == true ? locationStreet : null,
                      locationZip: locationZip?.isNotEmpty == true ? locationZip : null,
                      locationCity: locationCity?.isNotEmpty == true ? locationCity : null,
                      timezoneId: timezoneId,
                      startTimePosix: startTimePosix,
                      endTimePosix: endTimePosix,
                      latitude: latitude,
                      longitude: longitude,
                      isPaused: isPaused,
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
                      onDelete: canDelete ? () {
                        _showDeleteConfirmationDialog(context, partyId, partyName);
                      } : null,
                      onPause: status == running ? () {
                        _showPauseConfirmationDialog(context, partyId, partyName, isPaused);
                      } : null,
                      onEnd: status == running ? () {
                        _showEndPartyConfirmationDialog(context, partyId, partyName);
                      } : null,
                      onQrCode: partyCode != null
                          ? () async {
                              // Einzeilige Anzeige mit Dubletten-Schutz (Name nur wenn kein Duplikat von Straße/Ort)
                              final locName = locationName?.trim();
                              final street = locationStreet?.trim();
                              final zip = locationZip?.trim();
                              final city = locationCity?.trim();
                              final zipCityPart = [if (zip != null && zip.isNotEmpty) zip, if (city != null && city.isNotEmpty) city].join(' ').trim();
                              final addressPart = [if (street != null && street.isNotEmpty) street, if (zipCityPart.isNotEmpty) zipCityPart].join(', ');
                              final isExplicitName = locName != null && locName.isNotEmpty &&
                                  (street == null || street.isEmpty || locName.toLowerCase() != street.toLowerCase()) &&
                                  (city == null || city.isEmpty || locName.toLowerCase() != city.toLowerCase());
                              final locationDisplay = addressPart.isNotEmpty
                                  ? (isExplicitName ? '$locName · $addressPart' : addressPart)
                                  : (locName != null && locName.isNotEmpty ? locName : null);
                              final mapsUrl = (latitude != null && longitude != null)
                                  ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
                                  : null;

                              // Fetch DJ Logo + Kontaktdaten
                              String? djLogoUrl;
                              String? profileImageUrl;
                              String? djEmail;
                              String? djPhone;
                              String? djAlternativeEmail;
                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                  final userData = userDoc.data();
                                  djLogoUrl = userData?['djLogoUrl'];
                                  profileImageUrl = userData?['profileImageUrl'] ?? user.photoURL;
                                  djEmail = user.email ?? userData?['email'] as String?;
                                  djPhone = userData?['phoneNumber'] as String?;
                                  if (userData?['useAlternativeEmail'] == true) {
                                    djAlternativeEmail = userData?['alternativeEmail'] as String?;
                                  }
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
                                  partyLocation: locationDisplay,
                                  locationUrl: mapsUrl,
                                ),
                                djName: FirebaseAuth.instance.currentUser?.displayName,
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
                  }
                  
                  // Helper-Funktion für Sektions-Header
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
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sektion 1: LÄUFT
                      if (runningParties.isNotEmpty) ...[
                        buildSectionHeader(running, Colors.green),
                        ...runningParties.map((party) => buildPartyCard(party)),
                      ],
                      
                      // Sektion 2: BEVORSTEHEND
                      if (upcomingParties.isNotEmpty) ...[
                        buildSectionHeader(upcoming, UIConstants.appOrange),
                        ...upcomingParties.map((party) => buildPartyCard(party)),
                      ] else if (runningParties.isEmpty) ...[
                        // "Keine Partys" nur wenn beide Listen leer sind
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Aktuell sind keine weiteren Partys geplant.',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (session?.isActive != true) ...[
                        const SizedBox(height: 20),
                        const ProPromotionBanner(
                          message: 'Mit Pro unbegrenzt Partys planen',
                          compactPadding: false,
                        ),
                      ],
                      // Footer-Abstand
                      const SizedBox(height: UIConstants.kFooterPadding * 2),
                    ],
                  );
                    },
                  );
                    },
                  ),
                    ],
                  ),
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
        onPressed: null,
        tooltip: AppLocalizations.of(context)!.new_party,
      );
    }

    // Wizard immer öffnen; Limit-Check erfolgt im Wizard bei Datumswahl (Stichtag-Logik).
    return IconButton(
      icon: const Icon(Icons.add_circle_outline),
      color: UIConstants.appOrange,
      tooltip: AppLocalizations.of(context)!.new_party,
      onPressed: () => NeuePartyPage.show(context),
    );
  }
}
