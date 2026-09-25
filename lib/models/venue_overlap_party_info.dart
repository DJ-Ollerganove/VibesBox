/// Überlappende Party an einer Venue (für Hinweis-Dialog im Wizard).
class VenueOverlapPartyInfo {
  const VenueOverlapPartyInfo({
    required this.partyId,
    required this.partyName,
    required this.djId,
    this.djDisplayName,
    required this.start,
    required this.end,
    required this.floorKey,
    this.floorLabel,
  });

  final String partyId;
  final String partyName;
  final String djId;
  final String? djDisplayName;
  final DateTime start;
  final DateTime end;
  final String floorKey;
  final String? floorLabel;
}
