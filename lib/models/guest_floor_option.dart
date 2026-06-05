/// Wählbare Floor-/Party-Kombination für Gäste (Festcode + mehrere aktive Partys).
class GuestFloorOption {
  final String partyId;
  final String floorKey;
  final String floorLabel;
  final String djName;
  final String? partyName;

  const GuestFloorOption({
    required this.partyId,
    required this.floorKey,
    required this.floorLabel,
    required this.djName,
    this.partyName,
  });
}

/// Gast soll nach Beendigung einer Floor-Party andere Räume wählen können.
class GuestFloorRedirectState {
  final String joinCode;
  final String endedFloorLabel;
  final List<GuestFloorOption> options;

  const GuestFloorRedirectState({
    required this.joinCode,
    required this.endedFloorLabel,
    required this.options,
  });
}
