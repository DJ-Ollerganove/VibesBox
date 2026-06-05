/// Logische Wizard-Schritte (Reihenfolge je nach Party-Typ unterschiedlich).
enum PartyWizardStepKind {
  eventType,
  partyName,
  location,
  startTime,
  endTime,
  wishLimits,
  preWishes,
  /// Öffentlich: Location + Floor am Ende (nach Datum/Limits).
  locationWithFloor,
}

List<PartyWizardStepKind> partyWizardStepsForType(String partyType) {
  if (partyType == 'public') {
    return const [
      PartyWizardStepKind.eventType,
      PartyWizardStepKind.partyName,
      PartyWizardStepKind.startTime,
      PartyWizardStepKind.endTime,
      PartyWizardStepKind.wishLimits,
      PartyWizardStepKind.locationWithFloor,
    ];
  }
  return const [
    PartyWizardStepKind.eventType,
    PartyWizardStepKind.partyName,
    PartyWizardStepKind.location,
    PartyWizardStepKind.startTime,
    PartyWizardStepKind.endTime,
    PartyWizardStepKind.wishLimits,
    PartyWizardStepKind.preWishes,
  ];
}
