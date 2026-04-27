import 'package:flutter/material.dart';

import '../music_history_page.dart';

/// Wrapper: bleibt für Navigation/Index erhalten, lädt [MusicHistoryPage].
///
/// Gast: leere History / Party-Status → [HistoryGuestPage] (`history_guest.dart`)
/// mit [PartySessionService] und Keys `history_no_party_info` /
/// `history_empty_party_active_hint`.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MusicHistoryPage();
  }
}