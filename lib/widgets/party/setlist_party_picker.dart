import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/home/dj/dj_home_party_utils.dart';
import '../../services/dj_setlist_store_service.dart';
import '../../utils/beendete_party_utils.dart';
import '../../utils/ui_constants.dart';

class SetlistPartyChoice {
  const SetlistPartyChoice({
    required this.partyId,
    required this.partyName,
    required this.startDate,
    required this.isRunning,
  });

  final String partyId;
  final String partyName;
  final DateTime startDate;
  final bool isRunning;
}

/// Nur laufende oder geplante Partys — nie beendet.
class SetlistPartyPicker {
  SetlistPartyPicker._();

  static Future<SetlistPartyChoice?> show(BuildContext context) {
    return showModalBottomSheet<SetlistPartyChoice>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => const _SetlistPartyPickerBody(),
    );
  }
}

class _SetlistPartyPickerBody extends StatefulWidget {
  const _SetlistPartyPickerBody();

  @override
  State<_SetlistPartyPickerBody> createState() => _SetlistPartyPickerBodyState();
}

class _SetlistPartyPickerBodyState extends State<_SetlistPartyPickerBody> {
  Set<String> _occupied = <String>{};

  @override
  void initState() {
    super.initState();
    DjSetlistStoreService.instance.partyIdsWithLists().then((ids) {
      if (!mounted) return;
      setState(() => _occupied = ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final l = AppLocalizations.of(context)!;
    if (uid == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l.not_logged_in,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.translate('dj_setlist_picker_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.translate('dj_setlist_picker_hint'),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('parties')
                    .where('created_by', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      '${l.error_loading_prefix}: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    );
                  }
                  final docs = snapshot.data?.docs ?? const [];
                  final eligible = DjHomePartyUtils.runningAndUpcoming(
                    docs,
                    context,
                  ).where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return !beendetePartyIsEnded(data);
                  }).toList();
                  if (eligible.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        l.translate('dj_setlist_no_party'),
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: eligible.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: Colors.white12,
                    ),
                    itemBuilder: (context, index) {
                      final doc = eligible[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['party_name'] as String?)?.trim().isNotEmpty ==
                                  true
                              ? (data['party_name'] as String).trim()
                          : l.unnamed_party;
                      final start =
                          DjHomePartyUtils.partyStartDate(data) ??
                              DateTime.now();
                      final end = DjHomePartyUtils.partyEndDate(data) ??
                          start.add(const Duration(hours: 1));
                      final isRunning = !DateTime.now().isBefore(start) &&
                          DateTime.now().isBefore(end);
                      final occupied = _occupied.contains(doc.id);
                      return ListTile(
                        dense: true,
                        enabled: !occupied,
                        title: Text(
                          name,
                          style: TextStyle(
                            color: occupied ? Colors.white38 : Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          occupied
                              ? l.translate('dj_setlist_already_has_list')
                              : (isRunning
                                  ? l.translate('dj_setlist_status_running')
                                  : l.translate('dj_setlist_status_planned')),
                          style: TextStyle(
                            color: occupied
                                ? Colors.white38
                                : (isRunning
                                    ? Colors.greenAccent
                                    : UIConstants.appOrange),
                            fontSize: 12,
                          ),
                        ),
                        onTap: occupied
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  SetlistPartyChoice(
                                    partyId: doc.id,
                                    partyName: name,
                                    startDate: start,
                                    isRunning: isRunning,
                                  ),
                                );
                              },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
