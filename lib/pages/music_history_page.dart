import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/role_helper.dart';
import 'history/history_dj.dart';
import 'history/history_guest.dart';

/// Router für die Musik-History.
/// Lädt je nach Rolle die passende Ansicht (Guest vs DJ/Admin).
class MusicHistoryPage extends StatelessWidget {
  const MusicHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Nicht eingeloggt -> Guest-Ansicht
    if (user == null) {
      return const HistoryGuestPage();
    }

    return FutureBuilder<bool>(
      future: hasAnyRole(user, const ['DJ', 'Location', 'Admin']),
      builder: (context, snapshot) {
        final isDjOrAdmin = snapshot.data == true;
        if (isDjOrAdmin) {
          return const HistoryDjPage();
        }
        return const HistoryGuestPage();
      },
    );
  }
}


