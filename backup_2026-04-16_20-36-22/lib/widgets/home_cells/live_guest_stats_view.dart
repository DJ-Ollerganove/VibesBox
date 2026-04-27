import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_constants.dart';

/// Live-Gast-Statistik: Sprachverteilung aus `parties/{id}/guests`.
///
/// **Besucher gesamt** bevorzugt die Anzahl der Gast-Dokumente (stimmt mit der Summe
/// der Sprachen überein). Das Feld `parties.total_guest_count` kann höher sein
/// (z. B. PWA erhöht nur den Zähler, oder ältere Clients) — dannerscheint ein Hinweis.
class LiveGuestStatsView extends StatelessWidget {
  final String partyId;

  const LiveGuestStatsView({
    super.key,
    required this.partyId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .snapshots(),
      builder: (context, partySnapshot) {
        final int totalFromPartyField = (partySnapshot.hasData &&
                partySnapshot.data != null &&
                partySnapshot.data!.data() != null)
            ? (partySnapshot.data!.data() as Map<String, dynamic>)['total_guest_count'] as int? ?? 0
            : 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('parties')
                .doc(partyId)
                .collection('guests')
                .snapshots(),
            builder: (context, guestsSnapshot) {
              final guestDocCount =
                  guestsSnapshot.hasData ? guestsSnapshot.data!.docs.length : 0;

              final int headlineTotal;
              if (!guestsSnapshot.hasData) {
                headlineTotal = totalFromPartyField;
              } else if (guestDocCount > 0) {
                headlineTotal = guestDocCount;
              } else {
                headlineTotal = totalFromPartyField;
              }

              final showMismatchNote = guestsSnapshot.hasData &&
                  guestDocCount > 0 &&
                  totalFromPartyField != guestDocCount;

              final Map<String, int> languageDistribution = {};
              if (guestsSnapshot.hasData && guestsSnapshot.data!.docs.isNotEmpty) {
                for (final guestDoc in guestsSnapshot.data!.docs) {
                  final guestData = guestDoc.data() as Map<String, dynamic>;
                  final languageRaw = guestData['language'];
                  final String normalizedLang;
                  if (languageRaw == null || languageRaw.toString().trim().isEmpty) {
                    normalizedLang = 'UNBEKANNT';
                  } else {
                    normalizedLang = languageRaw.toString().trim().toUpperCase();
                  }
                  languageDistribution[normalizedLang] =
                      (languageDistribution[normalizedLang] ?? 0) + 1;
                }
              }

              final sortedLanguages = languageDistribution.entries
                  .where((entry) => entry.value > 0)
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final languageText = sortedLanguages.isEmpty
                  ? null
                  : sortedLanguages
                      .map((entry) => '${entry.key}: ${entry.value}')
                      .join(' | ');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${l10n.totalVisitors}: $headlineTotal',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (showMismatchNote)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        l10n.liveStatsPartyCounterMismatch(totalFromPartyField),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          height: 1.35,
                        ),
                      ),
                    ),
                  if (languageText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        languageText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: UIConstants.appOrange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
