import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/party_statistik_page.dart';
import '../l10n/app_localizations.dart';
import '../services/user_service.dart';
import '../settings_party_delete_dialog.dart';
import '../utils/formatting_utils.dart';
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';

const String _kPrefsKeyLimit = 'beendete_partys_limit';
const int _kDefaultLimit = 20;
const List<int> _kLimitOptions = [5, 10, 20, 30, 40, 50, 100];

/// Cache für einmal geladene Party-Details (Session-Cache).
final Map<String, Map<String, dynamic>> _partyDetailsCache = {};

class BeendetePartysPage extends StatefulWidget {
  /// Wenn true: Wird im bestehenden App-Layout (z. B. in Party-Verwaltung) ohne eigenes Scaffold angezeigt.
  final bool embeddedInMainScaffold;

  const BeendetePartysPage({super.key, this.embeddedInMainScaffold = false});

  @override
  State<BeendetePartysPage> createState() => _BeendetePartysPageState();
}

class _BeendetePartysPageState extends State<BeendetePartysPage> {
  int _limit = _kDefaultLimit;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _endedParties = [];
  int _totalCount = 0;
  bool _loading = true;
  Object? _error;
  String? _lastLoadedUid;

  @override
  void initState() {
    super.initState();
  }

  /// Lädt gespeichertes Limit aus Prefs (ohne setState), damit der erste Daten-Load das richtige Limit nutzt und kein Flackern entsteht.
  Future<int> _getSavedLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kPrefsKeyLimit);
    if (saved != null && _kLimitOptions.contains(saved)) return saved;
    return _kDefaultLimit;
  }

  /// Einmaliger Abruf: Filter lifecycle_status == 'finished', Sortierung start_date absteigend.
  /// Bei Free-DJ: limit(1) für Datenvolumen, kein Count-Aggregat.
  Future<void> _loadData(String uid) async {
    if (uid.isEmpty) {
      if (mounted) setState(() {
        _loading = false;
        _endedParties = [];
        _totalCount = 0;
        _error = null;
      });
      return;
    }
    final isFree = UserService().currentUser.value?.isFree ?? true;
    final effectiveLimit = isFree ? 1 : _limit;

    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final options = const GetOptions(source: Source.serverAndCache);

      // Gesamtanzahl nur für Pro (bei Free unnötig, spart Datenvolumen)
      int totalCount = 0;
      if (!isFree) {
        try {
          final countSnapshot = await firestore
              .collection('parties')
              .where('created_by', isEqualTo: uid)
              .where('lifecycle_status', isEqualTo: 'finished')
              .count()
              .get();
          totalCount = countSnapshot.count ?? 0;
        } catch (e) {
          debugLog('FIREBASE ERROR: $e');
          totalCount = -1;
        }
      } else {
        totalCount = -1;
      }

      final query = firestore
          .collection('parties')
          .where('created_by', isEqualTo: uid)
          .where('lifecycle_status', isEqualTo: 'finished')
          .orderBy('start_date', descending: true)
          .limit(effectiveLimit);
      final snapshot = await query.get(options);
      final list = snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

      if (mounted) {
        setState(() {
          _endedParties = list;
          _totalCount = totalCount;
          _loading = false;
          _lastLoadedUid = uid;
        });
      }
    } catch (e) {
      debugLog('FIREBASE ERROR: $e');
      if (mounted) setState(() {
        _loading = false;
        _endedParties = [];
        _totalCount = -1;
        _lastLoadedUid = uid;
        _error = e;
      });
    }
  }

  Future<void> _onLimitChanged(int newLimit) async {
    _limit = newLimit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefsKeyLimit, newLimit);
    if (mounted) setState(() {});
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) _loadData(uid);
  }

  Future<void> _openPartyDetails({
    required String partyId,
    required String partyName,
    required DateTime start,
    required DateTime end,
    required Map<String, dynamic> listItemData,
  }) async {
    Map<String, dynamic>? details = _partyDetailsCache[partyId];
    if (details == null) {
      if (listItemData.isNotEmpty) {
        details = listItemData;
        _partyDetailsCache[partyId] = details;
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
        try {
          final doc = await FirebaseFirestore.instance
              .collection('parties')
              .doc(partyId)
              .get();
          if (doc.exists && doc.data() != null) {
            details = Map<String, dynamic>.from(doc.data()!);
            _partyDetailsCache[partyId] = details!;
          }
        } finally {
          if (mounted) Navigator.of(context).pop();
        }
      }
    }
    if (!mounted) return;
    final data = details ?? listItemData;
    final name = data['party_name'] as String? ?? partyName;
    final startDate = (data['start_date'] as Timestamp?)?.toDate() ?? start;
    final endDate = (data['end_date'] as Timestamp?)?.toDate() ?? end;
    final partyCode = data['party_code'] as String? ?? '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyStatistikPage(
          partyId: partyId,
          partyName: name,
          startDate: startDate,
          endDate: endDate,
          partyCode: partyCode,
          preloadedPartyData: data,
        ),
      ),
    );
  }

  void _refresh() {
    final uid = _lastLoadedUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) _loadData(uid);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final user = snapshot.data;
        if (user == null || user.uid.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context)!.please_log_in),
          );
        }
        final uid = user.uid;
        if (_lastLoadedUid != uid) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted || _lastLoadedUid == uid) return;
            _limit = await _getSavedLimit();
            if (mounted && _lastLoadedUid != uid) await _loadData(uid);
          });
        }

        final body = _buildBody(context, l);
        if (widget.embeddedInMainScaffold) {
          return body;
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(l.ended_parties_title),
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l) {
    final isFree = UserService().currentUser.value?.isFree ?? true;
    // Auswahlzeile nur bei Pro, wenn Daten geladen und Liste nicht leer (vermeidet Flackern, leere Liste, Free)
    final showDropdownRow = !_loading && _endedParties.isNotEmpty && !isFree;

    final dropdownRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('${l.ended_parties_display_label} ', style: const TextStyle(fontSize: 14)),
          DropdownButton<int>(
            value: _limit,
            items: _kLimitOptions.map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
            onChanged: (v) {
              if (v != null) _onLimitChanged(v);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _totalCount >= 0
                  ? l.ended_parties_of_total_finished(_totalCount)
                  : l.ended_parties_list_count_shown(_endedParties.length),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDropdownRow) dropdownRow,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.ended_parties_error_loading('$_error'), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _refresh, child: Text(l.retry_button)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_loading && _endedParties.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (_endedParties.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Center(
                  child: Text(
                    l.no_finished_parties_found,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDropdownRow) dropdownRow,
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + UIConstants.kFooterPadding + 24,
              ),
              itemCount: _endedParties.length,
              itemBuilder: (context, index) {
                final doc = _endedParties[index];
                final data = doc.data();
                final start = (data['start_date'] as Timestamp?)?.toDate();
                final end = (data['end_date'] as Timestamp?)?.toDate();
                if (start == null || end == null) return const SizedBox.shrink();
                final partyId = doc.id;
                final rawName = data['party_name'];
                final partyName = rawName is String && rawName.trim().isNotEmpty
                    ? rawName
                    : l.unnamed_party;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: UIConstants.partyYellow, width: 1.5),
                  ),
                  child: ListTile(
                    title: Text(partyName),
                    subtitle: Text(
                      '${FormattingUtils.formatDateTime(start, context)} – ${FormattingUtils.formatDateTime(end, context)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final deleted = await SettingsPartyDeleteDialog.confirm(
                          context,
                          partyId,
                          partyName,
                        );
                        if (deleted == true && mounted) {
                          setState(() {
                            _endedParties.removeWhere((d) => d.id == partyId);
                            if (_totalCount > 0) _totalCount--;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l.party_deleted_success),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      tooltip: l.ended_party_delete_tooltip,
                    ),
                    onTap: () => _openPartyDetails(
                      partyId: partyId,
                      partyName: partyName,
                      start: start,
                      end: end,
                      listItemData: Map<String, dynamic>.from(data),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (isFree && _endedParties.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: UIConstants.partyYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: UIConstants.partyYellow, width: 1),
                  ),
                  child: Text(
                    l.finished_parties_pro_notice,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/paywall'),
                  icon: const Icon(Icons.workspace_premium, size: 20),
                  label: Text(l.getVibesboxPro),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
