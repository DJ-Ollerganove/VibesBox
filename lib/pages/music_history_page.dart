import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'history/history_dj.dart';
import 'history/history_guest.dart';

/// Router für die Musik-History (DJ-Shell vs. nicht eingeloggt).
class MusicHistoryPage extends StatelessWidget {
  const MusicHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const HistoryGuestPage();
    }
    return const HistoryDjPage();
  }
}
