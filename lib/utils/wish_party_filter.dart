/// Client-Filter: Wunsch-Dokument gehört zur aktiven Party.
///
/// Query läuft über [WishPaths.partyWishes] (Subcollection). Fehlt [party_id]
/// im Dokument (Migration/ältere Writes), gilt der Pfad als Quelle der Wahrheit.
bool wishDocDataMatchesPartyId(Map<String, dynamic> data, String partyId) {
  final raw = data['party_id'] ?? data['partyId'];
  if (raw == null) return true;
  final docPartyId = raw.toString().trim();
  if (docPartyId.isEmpty) return true;
  return docPartyId == partyId;
}
