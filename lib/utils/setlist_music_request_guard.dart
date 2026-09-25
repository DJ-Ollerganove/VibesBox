/// Client-Guard: keine OpenAI-/Function-Calls für offensichtliche Nicht-Musik-Texte.
class SetlistRejectedException implements Exception {
  const SetlistRejectedException(this.message);
  final String message;
}

class SetlistMusicRequestGuard {
  SetlistMusicRequestGuard._();

  static const rejectedMessage =
      'Das ist keine Musikanfrage. Die KI erstellt nur DJ-Setlisten.';

  static final _jailbreak = RegExp(
    r'ignore (all |any )?(previous|above)|system prompt|you are now|jailbreak|'
    r'\bDAN\b|developer mode|ignoriere (alle )?(vorherigen|bisherigen)|'
    r'du bist jetzt|neuer prompt',
    caseSensitive: false,
  );

  static final _offTopic = RegExp(
    r'\b(rezept|recipe|kochrezept|hausaufgaben|aufsatz|essay|'
    r'python|javascript|typescript|source code|sql query|'
    r'bitcoin wallet|medizinische diagnose|wie baue ich|'
    r'how to make a bomb|wetterbericht|schreib mir (ein|eine)|'
    r'write me (a|an))\b',
    caseSensitive: false,
  );

  static final _musicHint = RegExp(
    r'musik|music|song|lied|genre|party|dj|disco|house|techno|schlager|'
    r'pop|rock|hip.?hop|rap|hochzeit|wedding|dance|setlist|interpret|'
    r'artist|album|chart|fox|funk|salsa|reggaeton|hits|80er|90er|'
    r'evergreen|playlist|club|feier|geburtstag',
    caseSensitive: false,
  );

  static bool isMusicRequest({
    required String eventType,
    required String preferred,
    required String blacklist,
    String artistsMust = '',
  }) {
    final blob = '$eventType\n$preferred\n$blacklist\n$artistsMust';
    if (_jailbreak.hasMatch(blob) || _offTopic.hasMatch(blob)) {
      return false;
    }
    final p = preferred.trim();
    if (p.length >= 80 && p.contains('?') && !_musicHint.hasMatch(p)) {
      return false;
    }
    final a = artistsMust.trim();
    if (a.length >= 80 && a.contains('?') && !_musicHint.hasMatch(a)) {
      return false;
    }
    return true;
  }
}
