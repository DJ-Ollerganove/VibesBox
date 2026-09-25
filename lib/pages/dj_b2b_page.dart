import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/dj_b2b_service.dart';
import '../services/user_service.dart';
import '../utils/formatting_utils.dart';
import '../utils/ui_constants.dart';
import '../widgets/custom_page_header.dart';
import '../app_scaffold_messenger.dart';

class DjB2bPage extends StatefulWidget {
  const DjB2bPage({super.key});

  @override
  State<DjB2bPage> createState() => _DjB2bPageState();
}

class _DjB2bPageState extends State<DjB2bPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DjB2bService.instance.getOverview();
      if (!mounted) return;
      setState(() {
        _overview = data;
        _loading = false;
      });
    } catch (e) {
      DjB2bService.logFunctionsError(e, 'getOverview');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copy(String value, String snackMessage) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showVibesSnackBar(context, 
      SnackBar(content: Text(snackMessage)),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: UIConstants.appOrange),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: UIConstants.appOrange),
            child: Text(l.yes),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _startConsumption() async {
    final l = AppLocalizations.of(context)!;
    final paid = _overview?['paidSubscriptionActive'] == true;
    if (paid) {
      final proUntil = _overview?['proUntil'] as String?;
      final store = (_overview?['store'] as String?) ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: Text(
            l.dj_b2b_blocked_paid_title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            l.dj_b2b_blocked_paid_body(
              proUntil != null
                  ? FormattingUtils.formatDateForLocale(
                      DateTime.parse(proUntil), context)
                  : '—',
              store.toLowerCase().contains('app')
                  ? l.dj_b2b_store_app_store
                  : l.dj_b2b_store_play_store,
            ),
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.ok),
            ),
          ],
        ),
      );
      return;
    }

    if (!await _confirm(
      l.dj_b2b_start_confirm_title,
      l.dj_b2b_start_confirm_body,
    )) {
      return;
    }

    try {
      await DjB2bService.instance.startConsumption();
      final uid = UserService().currentUser.value?.id;
      if (uid != null) await UserService().refreshSessionProStatus(uid);
      await _load();
      if (!mounted) return;
      showVibesSnackBar(context, 
        SnackBar(content: Text(l.dj_b2b_start_success)),
      );
    } catch (e) {
      DjB2bService.logFunctionsError(e, 'startConsumption');
      if (!mounted) return;
      showVibesSnackBar(context, 
        SnackBar(content: Text('${l.dj_b2b_action_failed} $e')),
      );
    }
  }

  Future<void> _stopConsumption() async {
    final l = AppLocalizations.of(context)!;
    if (!await _confirm(
      l.dj_b2b_stop_confirm_title,
      l.dj_b2b_stop_confirm_body,
    )) {
      return;
    }
    try {
      await DjB2bService.instance.stopConsumption();
      final uid = UserService().currentUser.value?.id;
      if (uid != null) await UserService().refreshSessionProStatus(uid);
      await _load();
      if (!mounted) return;
      showVibesSnackBar(context, 
        SnackBar(content: Text(l.dj_b2b_stop_success)),
      );
    } catch (e) {
      DjB2bService.logFunctionsError(e, 'stopConsumption');
      if (!mounted) return;
      showVibesSnackBar(context, 
        SnackBar(content: Text('${l.dj_b2b_action_failed} $e')),
      );
    }
  }

  Widget _statTile(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  bool _isProLife(Map<String, dynamic>? o) {
    final proUntil = o?['proUntil'] as String?;
    if (proUntil == null) return false;
    try {
      return DateTime.parse(proUntil).year >= 2099;
    } catch (_) {
      return false;
    }
  }

  ({String label, bool isActive}) _accountStatus(AppLocalizations l) {
    final o = _overview;
    if (o == null) return (label: '—', isActive: false);
    final plan = (o['planType'] as String?) ?? 'free';
    final ledger = Map<String, dynamic>.from(o['ledger'] as Map? ?? {});
    if (ledger['consumptionActive'] == true) {
      return (label: l.vibesbox_pro_dj_b2b, isActive: true);
    }
    if (_isProLife(o)) {
      return (label: l.vibesbox_pro_life, isActive: true);
    }
    if (plan == 'trial') {
      return (label: l.dj_b2b_status_trial, isActive: true);
    }
    if (o['paidSubscriptionActive'] == true || (o['isPro'] == true && plan == 'pro')) {
      return (label: l.vibesbox_pro, isActive: true);
    }
    if (plan == 'free' || o['isPro'] != true) {
      return (label: l.vibesbox_free, isActive: false);
    }
    return (label: l.vibesbox_pro, isActive: true);
  }

  Widget _statusLabelText(String label, {required bool isActive}) {
    if (isActive) {
      return Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: UIConstants.appGreen,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.white,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final o = _overview;
    final ledger = o == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(o['ledger'] as Map? ?? {});
    final code = (o?['code'] as String?) ?? '—';
    final inviteUrl = (o?['inviteUrl'] as String?) ?? '';
    final referralCount = (o?['referralCount'] as num?)?.toInt() ?? 0;
    final accountStatus = _accountStatus(l);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CustomPageHeader(
                icon: Icons.groups_outlined,
                title: l.dj_b2b_page_title,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: UIConstants.appOrange,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration:
                                    UIConstants.guestBoxDecoration.copyWith(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  l.dj_b2b_intro,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.5,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: accountStatus.isActive
                                    ? UIConstants.statusFrameGreen
                                    : UIConstants.statusFrameRed,
                                child: Column(
                                  children: [
                                    Text(
                                      l.dj_b2b_account_status,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _statusLabelText(
                                      accountStatus.label,
                                      isActive: accountStatus.isActive,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _statTile(
                                    l.dj_b2b_stat_referred,
                                    '$referralCount',
                                  ),
                                  const SizedBox(width: 8),
                                  _statTile(
                                    l.dj_b2b_stat_lifetime,
                                    '${ledger['lifetime'] ?? 0}',
                                    color: UIConstants.appGreen,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _statTile(
                                    l.dj_b2b_stat_available,
                                    '${ledger['available'] ?? 0}',
                                  ),
                                  const SizedBox(width: 8),
                                  _statTile(
                                    l.dj_b2b_stat_pending,
                                    '${ledger['pending'] ?? 0}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                ledger['consumptionActive'] == true
                                    ? l.dj_b2b_consumption_active
                                    : l.dj_b2b_consumption_paused,
                                style: TextStyle(
                                  color: ledger['consumptionActive'] == true
                                      ? UIConstants.appGreen
                                      : Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                l.dj_b2b_your_code,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _copyRow(context, code, l.dj_b2b_code_copied),
                              if (inviteUrl.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  l.dj_b2b_your_link,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _copyRow(
                                  context,
                                  inviteUrl,
                                  l.dj_b2b_link_copied,
                                  small: true,
                                ),
                              ],
                              const SizedBox(height: 24),
                              if (ledger['consumptionActive'] == true)
                                ElevatedButton(
                                  onPressed: _stopConsumption,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white24,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(l.dj_b2b_stop_button),
                                )
                              else
                                ElevatedButton(
                                  onPressed:
                                      (ledger['available'] as num? ?? 0) > 0
                                          ? _startConsumption
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: UIConstants.appOrange,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: Text(l.dj_b2b_use_days_button),
                                ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copyRow(
    BuildContext context,
    String value,
    String snackMessage, {
    bool small = false,
  }) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: small ? 12 : 16,
                fontFamily: small ? null : 'monospace',
              ),
            ),
          ),
          IconButton(
            tooltip: l.dj_b2b_code_copied,
            onPressed: () => _copy(value, snackMessage),
            icon: const Icon(Icons.copy, color: UIConstants.appOrange),
          ),
        ],
      ),
    );
  }
}
