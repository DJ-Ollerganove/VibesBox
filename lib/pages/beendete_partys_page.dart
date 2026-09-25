import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/party_statistik_page.dart';
import '../l10n/app_localizations.dart';
import '../services/user_service.dart';
import '../settings_party_delete_dialog.dart';
import '../utils/beendete_party_utils.dart';
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
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allEndedSorted = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _displayParties = [];
  int _totalCount = 0;
  bool _loading = true;
  Object? _error;
  String? _lastLoadedUid;
  int? _viewingYear;

  int get _currentCalendarYear => DateTime.now().year;

  int get _displayYear => _viewingYear ?? _currentCalendarYear;

  bool get _isPriorYearView => _displayYear < _currentCalendarYear;

  @override
  void initState() {
    super.initState();
  }

  Future<int> _getSavedLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kPrefsKeyLimit);
    if (saved != null && _kLimitOptions.contains(saved)) return saved;
    return _kDefaultLimit;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchAllPartiesForUser(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    const options = GetOptions(source: Source.serverAndCache);
    try {
      final snap = await firestore
          .collection('parties')
          .where('created_by', isEqualTo: uid)
          .orderBy('start_date', descending: true)
          .get(options);
      return snap.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      debugLog(
        'FIREBASE: Index fehlt für created_by+start_date – Fallback ohne orderBy',
      );
      final snap = await firestore
          .collection('parties')
          .where('created_by', isEqualTo: uid)
          .get(options);
      return snap.docs;
    }
  }

  void _rebuildDisplayList({required bool isFree}) {
    final yearParties = endedPartiesForYear(_allEndedSorted, _displayYear);
    final list = (!_isPriorYearView && !isFree)
        ? yearParties.take(_limit).toList()
        : yearParties;
    _displayParties = list;
    _totalCount = _allEndedSorted.length;
  }

  Future<void> _loadData(String uid) async {
    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _allEndedSorted = [];
          _displayParties = [];
          _totalCount = 0;
          _error = null;
        });
      }
      return;
    }
    final isFree = UserService().currentUser.value?.isFree ?? true;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await _fetchAllPartiesForUser(firestore, uid);
      final ended = filterEndedParties(snapshot);

      if (mounted) {
        setState(() {
          _allEndedSorted = ended;
          _rebuildDisplayList(isFree: isFree);
          _loading = false;
          _lastLoadedUid = uid;
        });
      }
    } catch (e) {
      debugLog('FIREBASE ERROR: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _allEndedSorted = [];
          _displayParties = [];
          _totalCount = -1;
          _lastLoadedUid = uid;
          _error = e;
        });
      }
    }
  }

  Future<void> _onLimitChanged(int newLimit) async {
    _limit = newLimit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefsKeyLimit, newLimit);
    final isFree = UserService().currentUser.value?.isFree ?? true;
    if (mounted) {
      setState(() => _rebuildDisplayList(isFree: isFree));
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) _loadData(uid);
  }

  void _openYear(int year) {
    final isFree = UserService().currentUser.value?.isFree ?? true;
    setState(() {
      _viewingYear = year;
      _rebuildDisplayList(isFree: isFree);
    });
  }

  void _backToCurrentYear() {
    final isFree = UserService().currentUser.value?.isFree ?? true;
    setState(() {
      _viewingYear = null;
      _rebuildDisplayList(isFree: isFree);
    });
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
    await PartyStatistikPage.show(
      context,
      partyId: partyId,
      partyName: name,
      startDate: startDate,
      endDate: endDate,
      partyCode: partyCode,
      preloadedPartyData: data,
    );
  }

  void _refresh() {
    final uid = _lastLoadedUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) _loadData(uid);
  }

  void _onPartyDeleted(String partyId) {
    final isFree = UserService().currentUser.value?.isFree ?? true;
    setState(() {
      _allEndedSorted.removeWhere((d) => d.id == partyId);
      if (_isPriorYearView &&
          endedPartiesForYear(_allEndedSorted, _displayYear).isEmpty) {
        _viewingYear = null;
      }
      _rebuildDisplayList(isFree: isFree);
    });
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
            title: Text(
              _isPriorYearView
                  ? l.party_history_year_title(_displayYear)
                  : l.ended_parties_title,
            ),
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l) {
    final isFree = UserService().currentUser.value?.isFree ?? true;
    final newestPartyId =
        _allEndedSorted.isNotEmpty ? _allEndedSorted.first.id : null;
    final priorYears = priorYearsWithEndedParties(
      _allEndedSorted,
      _currentCalendarYear,
    );
    final showDropdownRow = !_loading &&
        _displayParties.isNotEmpty &&
        !isFree &&
        !_isPriorYearView;

    final dropdownRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('${l.ended_parties_display_label} ', style: const TextStyle(fontSize: 14)),
          DropdownButton<int>(
            value: _limit,
            items: _kLimitOptions
                .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                .toList(),
            onChanged: (v) {
              if (v != null) _onLimitChanged(v);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _totalCount >= 0
                  ? l.ended_parties_of_total_finished(_totalCount)
                  : l.ended_parties_list_count_shown(_displayParties.length),
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

    if (_loading && _displayParties.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    final listChildren = <Widget>[
      if (_isPriorYearView)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 20, color: Colors.white70),
              label: Text(
                l.party_history_back_to_current_year,
                style: const TextStyle(color: Colors.white70),
              ),
              onPressed: _backToCurrentYear,
            ),
          ),
        ),
      if (_isPriorYearView)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            l.party_history_year_title(_displayYear),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      if (showDropdownRow) dropdownRow,
    ];

    if (_displayParties.isEmpty) {
      listChildren.add(
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.3,
              child: Center(
                child: Text(
                  _isPriorYearView
                      ? l.party_history_no_parties_in_year(_displayYear)
                      : l.no_finished_parties_found,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
      if (!_isPriorYearView && priorYears.isNotEmpty) {
        listChildren.add(_buildPriorYearsSection(context, l, priorYears));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: listChildren,
      );
    }

    listChildren.add(
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + UIConstants.kFooterPadding + 8,
            ),
            itemCount: _displayParties.length,
            itemBuilder: (context, index) {
              final doc = _displayParties[index];
              return _buildPartyTile(
                context: context,
                l: l,
                doc: doc,
                isFree: isFree,
                isViewable: !isFree || doc.id == newestPartyId,
              );
            },
          ),
        ),
      ),
    );

    if (!_isPriorYearView && priorYears.isNotEmpty) {
      listChildren.add(_buildPriorYearsSection(context, l, priorYears));
    }

    if (isFree && _allEndedSorted.isNotEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.finished_parties_pro_notice,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                  height: 1.45,
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: listChildren,
    );
  }

  Widget _buildPriorYearsSection(
    BuildContext context,
    AppLocalizations l,
    List<int> priorYears,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.party_history_prior_years_title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final year in priorYears)
                _YearLinkChip(
                  year: year,
                  count: endedPartiesForYear(_allEndedSorted, year).length,
                  onTap: () => _openYear(year),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartyTile({
    required BuildContext context,
    required AppLocalizations l,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool isFree,
    required bool isViewable,
  }) {
    final data = doc.data();
    final start = (data['start_date'] as Timestamp?)?.toDate();
    final end = (data['end_date'] as Timestamp?)?.toDate();
    if (start == null || end == null) return const SizedBox.shrink();
    final partyId = doc.id;
    final rawName = data['party_name'];
    final partyName = rawName is String && rawName.trim().isNotEmpty
        ? rawName
        : l.unnamed_party;
    final borderColor =
        isViewable ? UIConstants.partyYellow : Colors.grey.shade600;
    final titleColor = isViewable ? null : Colors.grey.shade500;
    final subtitleColor = isViewable ? null : Colors.grey.shade600;

    return Opacity(
      opacity: isViewable ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        child: ListTile(
          title: Text(
            partyName,
            style: titleColor != null ? TextStyle(color: titleColor) : null,
          ),
          subtitle: Text(
            '${FormattingUtils.formatDateTime(start, context)} – ${FormattingUtils.formatDateTime(end, context)}',
            style: subtitleColor != null ? TextStyle(color: subtitleColor) : null,
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
                _onPartyDeleted(partyId);
              }
            },
            tooltip: l.ended_party_delete_tooltip,
          ),
          onTap: isViewable
              ? () => _openPartyDetails(
                    partyId: partyId,
                    partyName: partyName,
                    start: start,
                    end: end,
                    listItemData: Map<String, dynamic>.from(data),
                  )
              : null,
        ),
      ),
    );
  }
}

class _YearLinkChip extends StatelessWidget {
  const _YearLinkChip({
    required this.year,
    required this.count,
    required this.onTap,
  });

  final int year;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: UIConstants.partyYellow.withValues(alpha: 0.6)),
          ),
          child: Text(
            '$year ($count)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
