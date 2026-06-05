/// Belegung eines Floors durch eine überlappende Party (Venue-Kontext).
class FloorOccupancyInfo {
  final String partyId;
  final String djId;
  final String floorKey;
  final String? floorLabel;

  const FloorOccupancyInfo({
    required this.partyId,
    required this.djId,
    required this.floorKey,
    this.floorLabel,
  });
}
