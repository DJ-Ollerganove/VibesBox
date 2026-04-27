import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/app_config.dart';
import 'package:vibesbox/models/user_model.dart';
import '../../services/user_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_update_service.dart';
import '../../services/navigation_service.dart';
import '../../utils/ui_constants.dart';
import '../../helpers/security_helper.dart';
import '../../widgets/home_cells/global_announcement_card.dart';
import '../../widgets/home_cells/login_counter_card.dart';
import '../../widgets/home_cells/stats_pie_chart_card.dart';
import '../../widgets/home_statistics_cards.dart';
import '../../utils/debug_log.dart';

class HomeAdmin extends StatefulWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final Listenable reloadListenable;
  final String? currentViewRole;
  final ValueChanged<String?>? onViewRoleChanged;

  const HomeAdmin({
    super.key,
    required this.cardBuilder,
    required this.reloadListenable,
    required this.currentViewRole,
    required this.onViewRoleChanged,
  });

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  bool _loading = true;

  bool _wishboxManuallyEnabled = false;
  Map<String, dynamic>? _currentOrNextParty;

  /// Letzte Ankündigung (nur für Admin sichtbar); null = noch nicht geladen oder keine vorhanden.
  DocumentSnapshot? _lastAnnouncementDoc;
  bool _loadingLastAnnouncement = false;

  /// Bearbeitungsmodus: wenn gesetzt, werden initialSubject/initialMessage an GlobalAnnouncementCard übergeben.
  String? _editAnnouncementId;
  String? _editSubject;
  String? _editMessage;
  bool _lastAnnouncementLoadRequested = false;

  /// Erhöhen bei "Erneut versuchen" in StatsPieChartCard, damit der Stream neu gestartet wird.
  int _statsRetryKey = 0;

  double _duplicateThreshold = 0.85;
  final TextEditingController _thresholdController = TextEditingController();
  final TextEditingController _versionMajorController = TextEditingController();
  final TextEditingController _versionMinorController = TextEditingController();
  final TextEditingController _versionPatchController = TextEditingController();
  final TextEditingController _currentVersionController =
      TextEditingController();
  final TextEditingController _pdfFooterController = TextEditingController();
  bool _enableMinVersionDjAndroid = false;
  bool _enableMinVersionDjIos = false;
  bool _enableMinVersionGuestAndroid = false;
  bool _enableMinVersionGuestIos = false;
  int _currentBuildNumber = 0;
  String _preferredStartView = 'admin_dashboard';

  StreamSubscription<QuerySnapshot>? _partiesSub;

  @override
  void initState() {
    super.initState();
    widget.reloadListenable.addListener(_reload);
    _setupPartiesListener();
    _versionMajorController.addListener(_onVersionFieldChanged);
    _versionMinorController.addListener(_onVersionFieldChanged);
    _versionPatchController.addListener(_onVersionFieldChanged);
    PackageInfo.fromPlatform().then((info) {
      if (mounted)
        setState(
          () => _currentBuildNumber = int.tryParse(info.buildNumber) ?? 0,
        );
    });
    _preferredStartView = NavigationService.instance.preferredStartView;
    unawaited(_loadPreferredStartView());
    _reload();
  }

  void _onVersionFieldChanged() => setState(() {});

  Future<void> _loadPreferredStartView() async {
    final value = await NavigationService.instance
        .loadPersistedPreferredStartView();
    if (!mounted) return;
    setState(() => _preferredStartView = value);
  }

  Future<void> _setPreferredStartView(String value) async {
    await NavigationService.instance.setPreferredStartView(value);
    if (!mounted) return;
    setState(() => _preferredStartView = value);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Startansicht gespeichert!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Lädt die letzte Ankündigung (createdAt absteigend, Limit 1). Nur für Admin-UI.
  Future<void> _loadLastAnnouncement() async {
    if (_loadingLastAnnouncement) return;
    setState(() => _loadingLastAnnouncement = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('global_announcements')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        _lastAnnouncementDoc = snap.docs.isEmpty ? null : snap.docs.first;
        _loadingLastAnnouncement = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLastAnnouncement = false);
    }
  }

  /// Liest translations aus Firestore-Daten. Erwartet Map (de/en/... -> {subject, message}); bei List oder anderem Typ: leere Map.
  static Map<String, dynamic> _safeTranslationsMap(Map<String, dynamic>? data) {
    final raw = data?['translations'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  /// Liest Sprach-Map (z. B. de) aus translations. Erwartet Map mit subject/message; sonst leere Map.
  static Map<String, dynamic> _safeLangMap(
    Map<String, dynamic> translations,
    String langCode,
  ) {
    final raw = translations[langCode];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  void _showLastAnnouncement(BuildContext context) {
    if (UserScope.userOf(context)?.admin != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = _lastAnnouncementDoc;
    if (doc == null) return;
    final data = doc.data() as Map<String, dynamic>?;
    final translations = _safeTranslationsMap(data);
    final de = _safeLangMap(translations, 'de');
    final subject = (de['subject'] as String?)?.trim() ?? '';
    final message = (de['message'] as String?)?.trim() ?? '';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Text(
          subject.isEmpty ? 'Letzte Ankündigung' : subject,
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Text(
            message.isEmpty ? '—' : message,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Schließen',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _startEditLastAnnouncement(BuildContext context) {
    if (UserScope.userOf(context)?.admin != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = _lastAnnouncementDoc;
    if (doc == null) return;
    final data = doc.data() as Map<String, dynamic>?;
    final translations = _safeTranslationsMap(data);
    final de = _safeLangMap(translations, 'de');
    setState(() {
      _editAnnouncementId = doc.id;
      _editSubject = (de['subject'] as String?)?.trim() ?? '';
      _editMessage = (de['message'] as String?)?.trim() ?? '';
    });
  }

  void _clearEditMode() {
    setState(() {
      _editAnnouncementId = null;
      _editSubject = null;
      _editMessage = null;
    });
    _loadLastAnnouncement();
  }

  Future<void> _deleteLastAnnouncement(BuildContext context) async {
    if (UserScope.userOf(context)?.admin != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = _lastAnnouncementDoc;
    if (doc == null) return;
    final id = doc.id;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Ankündigung löschen',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Möchtest du diese Ankündigung wirklich unwiderruflich löschen?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (UserScope.userOf(context)?.admin != true) return;
    await FirebaseFirestore.instance
        .collection('global_announcements')
        .doc(id)
        .delete();
    if (!mounted) return;
    await _loadLastAnnouncement();
  }

  Widget _buildLastAnnouncementManagementCard(BuildContext context) {
    return widget.cardBuilder(
      context,
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1F2937),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.rule, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Letzte Ankündigung verwalten',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingLastAnnouncement)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              )
            else if (_lastAnnouncementDoc == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Keine Ankündigung vorhanden.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _lastAnnouncementSubjectPreview,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showLastAnnouncement(context),
                        icon: const Icon(
                          Icons.visibility,
                          size: 18,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          'Letzte Nachricht anzeigen',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _startEditLastAnnouncement(context),
                        icon: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          'Bearbeiten',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _deleteLastAnnouncement(context),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Löschen',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferredStartViewCard(BuildContext context) {
    return widget.cardBuilder(
      context,
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Standard-Startansicht festlegen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_preferredStartView),
              initialValue: _preferredStartView,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Startansicht',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.orange.withValues(alpha: 0.75),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange, width: 1.5),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'admin_dashboard',
                  child: Text('Admin-Dashboard'),
                ),
                DropdownMenuItem(value: 'dj_area', child: Text('DJ-Bereich')),
                DropdownMenuItem(
                  value: 'guest_area',
                  child: Text('Gast-Bereich'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                unawaited(_setPreferredStartView(value));
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _lastAnnouncementSubjectPreview {
    final doc = _lastAnnouncementDoc;
    if (doc == null) return '';
    final data = doc.data() as Map<String, dynamic>?;
    final translations = _safeTranslationsMap(data);
    final de = _safeLangMap(translations, 'de');
    final subject = (de['subject'] as String?)?.trim() ?? '';
    return subject.isEmpty ? '(Kein Betreff)' : subject;
  }

  @override
  void dispose() {
    widget.reloadListenable.removeListener(_reload);
    _partiesSub?.cancel();
    _thresholdController.dispose();
    _versionMajorController.removeListener(_onVersionFieldChanged);
    _versionMinorController.removeListener(_onVersionFieldChanged);
    _versionPatchController.removeListener(_onVersionFieldChanged);
    _versionMajorController.dispose();
    _versionMinorController.dispose();
    _versionPatchController.dispose();
    _currentVersionController.dispose();
    _pdfFooterController.dispose();
    super.dispose();
  }

  void _setupPartiesListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _partiesSub?.cancel();
    _partiesSub = FirebaseFirestore.instance
        .collection('parties')
        .where('created_by', isEqualTo: user.uid)
        .snapshots()
        .listen((_) => _loadWishboxStatus());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _loadWishboxStatus();
    await _loadGlobalDuplicateThreshold();
    await _loadMinVersions();
    await _loadPdfFooterText();
    if (mounted) setState(() => _loading = false);
  }

  static final RegExp _versionPart = RegExp(r'^\d{1,2}$');

  /// Parst "1.0.21" in [major, minor, patch]; leere Teile werden als "0" geliefert.
  static List<String> _parseVersionParts(String s) {
    final parts = s.trim().split(RegExp(r'[.\+]'));
    final major = (parts.isNotEmpty && _versionPart.hasMatch(parts[0].trim()))
        ? parts[0].trim()
        : '1';
    final minor = (parts.length > 1 && _versionPart.hasMatch(parts[1].trim()))
        ? parts[1].trim()
        : '0';
    final patch = (parts.length > 2 && _versionPart.hasMatch(parts[2].trim()))
        ? parts[2].trim()
        : '21';
    return [major, minor, patch];
  }

  Future<void> _loadMinVersions() async {
    try {
      final versions = await AppUpdateService.instance.getMinVersions();
      if (!mounted) return;
      final base = AppUpdateService.defaultMinVersion;
      final vDjA = versions['min_version_dj_android'] ?? base;
      final vDjI = versions['min_version_dj_ios'] ?? base;
      final vGA = versions['min_version_guest_android'] ?? base;
      final vGI = versions['min_version_guest_ios'] ?? base;
      final currentVersion = versions['current_version'] ?? base;
      String targetVersion = base;
      if (vDjA != base)
        targetVersion = vDjA;
      else if (vDjI != base)
        targetVersion = vDjI;
      else if (vGA != base)
        targetVersion = vGA;
      else if (vGI != base)
        targetVersion = vGI;
      final parts = _parseVersionParts(targetVersion);
      setState(() {
        _versionMajorController.text = parts[0];
        _versionMinorController.text = parts[1];
        _versionPatchController.text = parts[2];
        _currentVersionController.text = currentVersion;
        _enableMinVersionDjAndroid = vDjA != base;
        _enableMinVersionDjIos = vDjI != base;
        _enableMinVersionGuestAndroid = vGA != base;
        _enableMinVersionGuestIos = vGI != base;
      });
    } catch (_) {}
  }

  Future<void> _saveMinVersions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final major = _versionMajorController.text.trim();
    final minor = _versionMinorController.text.trim();
    final patch = _versionPatchController.text.trim();
    final target = (major.isEmpty || minor.isEmpty || patch.isEmpty)
        ? AppUpdateService.defaultMinVersion
        : '$major.$minor.$patch';
    final currentVersion = SecurityHelper.sanitize(
      _currentVersionController.text,
      maxLength: 20,
    ).trim();
    final base = AppUpdateService.defaultMinVersion;
    // Keys exakt wie in AppUpdateService.getMinVersions() erwartet
    final data = <String, dynamic>{
      'min_version_dj_android': _enableMinVersionDjAndroid ? target : base,
      'min_version_dj_ios': _enableMinVersionDjIos ? target : base,
      'min_version_guest_android': _enableMinVersionGuestAndroid
          ? target
          : base,
      'min_version_guest_ios': _enableMinVersionGuestIos ? target : base,
      'min_version_dj': _enableMinVersionDjAndroid || _enableMinVersionDjIos
          ? target
          : base,
      'min_version_guest':
          _enableMinVersionGuestAndroid || _enableMinVersionGuestIos
              ? target
              : base,
      'current_version': currentVersion.isNotEmpty ? currentVersion : target,
      'updated_at': FieldValue.serverTimestamp(),
    };
    try {
      await FirebaseFirestore.instance
          .collection('admin_config')
          .doc('app_update')
          .set(SecurityHelper.sanitizeMap(data), SetOptions(merge: true));
      debugLog('admin_config/app_update: Update erfolgreich gespeichert: $data');
      if (mounted) {
        final msg = AppLocalizations.of(context)!.updateSavedMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugLog('admin_config/app_update: Fehler beim Speichern in Firestore: $e');
      if (mounted) {
        final msg =
            AppLocalizations.of(context)!.updateSaveErrorMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadWishboxStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _loadCurrentOrNextParty();
      final partyId = _currentOrNextParty?['id'] as String?;
      if (partyId == null || partyId.isEmpty || !mounted) {
        if (mounted) setState(() => _wishboxManuallyEnabled = false);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();
      final enabled = doc.data()?['wishbox_enabled'] as bool? ?? false;
      if (mounted) setState(() => _wishboxManuallyEnabled = enabled);
    } catch (_) {}
  }

  Future<void> _loadCurrentOrNextParty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
        .collection('parties')
        .where('created_by', isEqualTo: user.uid)
        .get();
    if (query.docs.isNotEmpty && mounted) {
      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;
      data['start_date'] = (data['start_date'] as Timestamp).toDate();
      data['end_date'] = (data['end_date'] as Timestamp).toDate();
      setState(() => _currentOrNextParty = data);
    }
  }

  Future<void> _toggleWishbox(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final partyId = _currentOrNextParty?['id'] as String?;
    if (partyId == null || partyId.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final partyRef = FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId);
      batch.set(
        partyRef,
        SecurityHelper.sanitizeMap({'wishbox_enabled': enabled}),
        SetOptions(merge: true),
      );
      final logRef = partyRef.collection('status_logs').doc();
      batch.set(
        logRef,
        SecurityHelper.sanitizeMap({
          'status': enabled ? 'enabled' : 'disabled',
          'timestamp': FieldValue.serverTimestamp(),
          'action_by': user.uid,
        }),
      );
      await batch.commit();
      await _loadWishboxStatus();
    } catch (_) {}
  }

  Future<void> _loadGlobalDuplicateThreshold() async {
    final doc = await FirebaseFirestore.instance
        .collection('party_settings')
        .doc('current')
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _duplicateThreshold =
            (doc.data()?['duplicate_threshold'] as num?)?.toDouble() ?? 0.85;
        _thresholdController.text = (_duplicateThreshold * 100).toStringAsFixed(
          0,
        );
      });
    }
  }

  Future<void> _loadPdfFooterText() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_config')
          .doc('global_settings')
          .get();
      if (doc.exists && mounted) {
        final text = doc.data()?['pdf_footer_text'] as String? ?? '';
        setState(() => _pdfFooterController.text = text);
      }
    } catch (_) {}
  }

  Future<void> _savePdfFooterText() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final text = _pdfFooterController.text.trim();
      await FirebaseFirestore.instance
          .collection('admin_config')
          .doc('global_settings')
          .set(
            SecurityHelper.sanitizeMap({
              'pdf_footer_text': SecurityHelper.sanitize(text, maxLength: 120),
              'updated_at': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          );
      // In-Memory aktualisieren, damit die nächste PDF-Generierung sofort den neuen Text nutzt
      AppConfig.pdfFooterText = text.isEmpty ? null : text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.updateSavedMessage,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDuplicateThreshold() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !AppConfig.isAdminRole(UserService().currentUser.value))
      return;
    try {
      final val = double.tryParse(_thresholdController.text) ?? 85.0;
      await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .set(
            SecurityHelper.sanitizeMap({'duplicate_threshold': val / 100.0}),
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  Widget _buildAppUpdateMatrixCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.updateMatrixTitle;
    final subtitle = l10n.updateMatrixSubtitle;
    final milestoneHint = l10n.updateMilestoneHint;
    final targetLabel = l10n.updateTargetVersionLabel;
    final majorLabel = l10n.updateVersionMajor;
    final minorLabel = l10n.updateVersionMinor;
    final patchLabel = l10n.updateVersionPatch;
    final checkboxQuestion = l10n.updateCheckboxQuestion;
    final djAndroid = l10n.updateMinVersionDjAndroid;
    final djIos = l10n.updateMinVersionDjIos;
    final guestAndroid = l10n.updateMinVersionGuestAndroid;
    final guestIos = l10n.updateMinVersionGuestIos;
    final saveLabel = l10n.updateSaveButton;
    final currentVersionLabel = l10n.updateCurrentVersionLabel;
    final versionInputFormatters = [
      FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(2),
    ];
    final versionFieldDecoration = const InputDecoration(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.orange),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      isDense: true,
      counterText: '',
    );
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_config')
          .doc('app_update')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final liveVersion =
            (data['current_version'] as String?)?.trim().isNotEmpty == true
            ? (data['current_version'] as String).trim()
            : (data['min_version_dj_android'] as String?)?.trim().isNotEmpty ==
                true
            ? (data['min_version_dj_android'] as String).trim()
            : ((data['min_version_guest_android'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? (data['min_version_guest_android'] as String).trim()
                  : AppUpdateService.defaultMinVersion);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1F2937),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                milestoneHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'LIVE admin_config/app_update: $liveVersion',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                currentVersionLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _currentVersionController,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                  hintText: 'z.B. 22 oder 1.2.3',
                  isDense: true,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                targetLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: _versionMajorController,
                      decoration: versionFieldDecoration.copyWith(
                        hintText: '0',
                        semanticCounterText: majorLabel,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: versionInputFormatters,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: _versionMinorController,
                      decoration: versionFieldDecoration.copyWith(
                        hintText: '0',
                        semanticCounterText: minorLabel,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: versionInputFormatters,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: _versionPatchController,
                      decoration: versionFieldDecoration.copyWith(
                        hintText: '0',
                        semanticCounterText: patchLabel,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: versionInputFormatters,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final maj = _versionMajorController.text.trim().isEmpty
                      ? '0'
                      : _versionMajorController.text.trim();
                  final min = _versionMinorController.text.trim().isEmpty
                      ? '0'
                      : _versionMinorController.text.trim();
                  final pat = _versionPatchController.text.trim().isEmpty
                      ? '0'
                      : _versionPatchController.text.trim();
                  final nextBuild = _currentBuildNumber + 1;
                  final previewVersion = '$maj.$min.$pat+$nextBuild';
                  final previewLabel = l10n.updateNewTargetVersionPreview
                      .replaceAll('{version}', previewVersion);
                  return Text(
                    previewLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                checkboxQuestion,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _enableMinVersionDjAndroid,
                onChanged: (v) =>
                    setState(() => _enableMinVersionDjAndroid = v ?? false),
                title: Text(
                  djAndroid,
                  style: const TextStyle(color: Colors.white),
                ),
                activeColor: Colors.orange,
                checkColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _enableMinVersionDjIos,
                onChanged: (v) =>
                    setState(() => _enableMinVersionDjIos = v ?? false),
                title: Text(djIos, style: const TextStyle(color: Colors.white)),
                activeColor: Colors.orange,
                checkColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _enableMinVersionGuestAndroid,
                onChanged: (v) =>
                    setState(() => _enableMinVersionGuestAndroid = v ?? false),
                title: Text(
                  guestAndroid,
                  style: const TextStyle(color: Colors.white),
                ),
                activeColor: Colors.orange,
                checkColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _enableMinVersionGuestIos,
                onChanged: (v) =>
                    setState(() => _enableMinVersionGuestIos = v ?? false),
                title: Text(
                  guestIos,
                  style: const TextStyle(color: Colors.white),
                ),
                activeColor: Colors.orange,
                checkColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saveMinVersions,
                icon: const Icon(Icons.save, size: 18),
                label: Text(saveLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final UserService userService = UserService();
    // initialData: Sofort rendern, wenn User bereits geladen (verhindert ewigen Ladebalken)
    return StreamBuilder<UserModel?>(
      stream: userService.userStream,
      initialData: userService.currentUser.value,
      builder: (BuildContext context, AsyncSnapshot<UserModel?> snapshot) {
        final UserModel? userModel = snapshot.data as UserModel?;
        if (userModel?.admin != true) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Warte auf Benutzerdaten…',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }
          return const Center(
            child: Text(
              'Keine Admin-Berechtigung.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final UserModel adminUser = userModel!;
        final bool isAdminRole = adminUser.admin == true;
        if (!_lastAnnouncementLoadRequested) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _lastAnnouncementLoadRequested = true);
            _loadLastAnnouncement();
          });
        }
        final int loginCount = adminUser.loginCount ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Admin: globale Wünsche-Statistik (ohne djId/userId-Filter)
              StatsPieChartCard(
                key: ValueKey('admin_stats_$_statsRetryKey'),
                cardBuilder: widget.cardBuilder,
                isAdmin: true,
                onRetry: () => setState(() => _statsRetryKey++),
                currentUserRoleForError: adminUser.admin == true
                    ? 'admin'
                    : 'user',
              ),
              const SizedBox(height: 20),
              _buildPreferredStartViewCard(context),
              const SizedBox(height: 20),
              LoginCounterCard(
                loginCount: loginCount,
                cardBuilder: widget.cardBuilder,
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: UIConstants.appOrange,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              HomeThresholdCard(
                controller: _thresholdController,
                onSubmitted: _saveDuplicateThreshold,
                cardBuilder: widget.cardBuilder,
              ),
              const SizedBox(height: 20),
              // PDF-Footer-Text (admin_config/global_settings) – Schwarz/Orange
              widget.cardBuilder(
                context,
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: UIConstants.appOrange,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: UIConstants.bgGradientStart,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pdfFooterController,
                          decoration: InputDecoration(
                            labelText: 'PDF-Footer-Text',
                            hintText: 'a creation by Swen Steller © 2026',
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: UIConstants.appOrange,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          maxLength: 120,
                          maxLines: 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _savePdfFooterText,
                        icon: const Icon(Icons.save),
                        color: UIConstants.appOrange,
                        tooltip: 'Speichern',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // App-Update: Steuerungs-Matrix (admin_config/app_update)
              widget.cardBuilder(context, _buildAppUpdateMatrixCard(context)),
              const SizedBox(height: 20),
              if (isAdminRole) ...[
                _buildLastAnnouncementManagementCard(context),
                const SizedBox(height: 20),
              ],
              GlobalAnnouncementCard(
                cardBuilder: widget.cardBuilder,
                editAnnouncementId: _editAnnouncementId,
                initialSubject: _editSubject,
                initialMessage: _editMessage,
                onEditFinished: _clearEditMode,
              ),
              const SizedBox(height: 20),
              HomeAdminRoleSwitcherCard(
                currentViewRole: widget.currentViewRole,
                onChanged: widget.onViewRoleChanged,
                isAdminUser: isAdminRole,
                cardBuilder: widget.cardBuilder,
              ),
              const SizedBox(height: UIConstants.kFooterPadding),
            ],
          ),
        );
      },
    );
  }
}
