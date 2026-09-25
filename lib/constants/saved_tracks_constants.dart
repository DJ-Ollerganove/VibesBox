/// Firestore-Pfade für die DJ-Merkliste (gespeicherte Titel).
class SavedTracksConstants {
  SavedTracksConstants._();

  static const String subcollection = 'saved_tracks';

  static const String sourcePre = 'pre';
  static const String sourceOpen = 'open';
  static const String sourcePlayed = 'played';
  static const String sourceRejected = 'rejected';
}
