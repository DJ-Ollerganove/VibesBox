import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/song_request.dart';
import '../services/party_statistics_service.dart';
import '../widgets/empty_list_message.dart';

/// Widget, das einen Stream von SongRequests filtert basierend auf dem aktiven Party-Status
/// 
/// FALL A: Keine Party aktiv -> Zeigt EmptyListMessage mit 'Aktuell läuft keine Party'
/// FALL B: Party aktiv, aber gefilterte Liste leer -> Zeigt EmptyListMessage mit 'Aktuell gibt es keine Wünsche'
/// FALL C: Party aktiv und gefilterte Daten vorhanden -> Zeigt die Liste über den builder
class LivePartyFilter extends StatelessWidget {
  final Stream<List<SongRequest>> stream;
  final Widget Function(List<SongRequest>) builder;

  const LivePartyFilter({
    super.key,
    required this.stream,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return EmptyListMessage();
    }

    return StreamBuilder<String?>(
      stream: PartyStatisticsService.getActivePartyIdStream(user.uid),
      builder: (context, partySnapshot) {
        final activePartyId = partySnapshot.data;
        final hasActiveParty = activePartyId != null;
        
        return StreamBuilder<List<SongRequest>>(
          stream: stream,
          builder: (context, wishesSnapshot) {
            if (wishesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (wishesSnapshot.hasError) {
              return Center(
                child: Text('Fehler: ${wishesSnapshot.error}'),
              );
            }

            final allWishes = wishesSnapshot.data ?? [];

            // FALL A: Keine Party aktiv
            if (!hasActiveParty) {
              return EmptyListMessage();
            }

            // Filtere nach aktiver Party-ID
            final filteredWishes = allWishes.where((w) => w.partyId == activePartyId).toList();

            // FALL B: Party aktiv, aber gefilterte Liste leer
            if (filteredWishes.isEmpty) {
              return EmptyListMessage();
            }

            // FALL C: Party aktiv und gefilterte Daten vorhanden
            return builder(filteredWishes);
          },
        );
      },
    );
  }
}

