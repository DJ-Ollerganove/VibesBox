/// Logische Wizard-Schritte (Reihenfolge je nach Party-Typ unterschiedlich).
enum PartyWizardStepKind {
  eventType,
  partyName,
  location,
  startTime,
  endTime,
  wishLimits,
  preWishes,
  /// Öffentlich: Floor-Auswahl (nach Location).
  floor,
  /// Öffentlich: Einmal- vs. Fest-Party-Code.
  partyCode,
  /// Legacy: Location + Floor kombiniert (nur Bearbeitungsdialog).
  locationWithFloor,
}

List<PartyWizardStepKind> partyWizardStepsForType(String partyType) {
  if (partyType == 'public') {
    return const [
      PartyWizardStepKind.eventType,
      PartyWizardStepKind.startTime,
      PartyWizardStepKind.endTime,
      PartyWizardStepKind.location,
      PartyWizardStepKind.floor,
      PartyWizardStepKind.wishLimits,
      PartyWizardStepKind.partyName,
      PartyWizardStepKind.preWishes,
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
