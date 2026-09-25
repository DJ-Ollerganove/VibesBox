/// Belegung eines Floors durch eine überlappende Party (Venue-Kontext).
class FloorOccupancyInfo {
  final String partyId;
  final String djId;
  final String floorKey;
  final String? floorLabel;
  final String? djDisplayName;
  final DateTime? partyStart;
  final DateTime? partyEnd;
  final String? partyName;

  const FloorOccupancyInfo({
    required this.partyId,
    required this.djId,
    required this.floorKey,
    this.floorLabel,
    this.djDisplayName,
    this.partyStart,
    this.partyEnd,
    this.partyName,
  });
}
