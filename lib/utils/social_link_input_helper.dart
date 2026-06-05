/// DJ-Eingabe: Accountname / Handynummer → gespeicherte https-URL (Firestore).
/// Beim Bearbeiten: gespeicherte URL → kurze Anzeige im Textfeld.
class SocialLinkInputHelper {
  SocialLinkInputHelper._();

  /// Gespeicherte URL → Anzeige im Bearbeiten-Dialog (Account / Nummer / Domain).
  static String storedToDisplay(String platformId, String stored) {
    final trimmed = stored.trim();
    if (trimmed.isEmpty) return '';

    switch (platformId) {
      case 'whatsapp':
        return normalizeWhatsAppDigits(trimmed);
      case 'website':
        return _websiteToDisplay(trimmed);
      default:
        return _accountFromStoredUrl(platformId, trimmed);
    }
  }

  /// Eingabe des DJs → URL zum Speichern.
  static String inputToStored(String platformId, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    switch (platformId) {
      case 'whatsapp':
        final digits = normalizeWhatsAppDigits(trimmed);
        if (digits.isEmpty) return '';
        return 'https://wa.me/$digits';
      case 'website':
        return _websiteToStored(trimmed);
      default:
        final account = _normalizeAccountInput(platformId, trimmed);
        if (account.isEmpty) return '';
        return _buildPlatformUrl(platformId, account);
    }
  }

  static bool isValidInput(String platformId, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return true;
    if (platformId == 'whatsapp') {
      return isValidWhatsAppInput(trimmed);
    }
    final account = _normalizeAccountInput(platformId, trimmed);
    return account.isNotEmpty;
  }

  /// Nur Ziffern für wa.me — ohne Leerzeichen, ohne führende 0 / 0049.
  static String normalizeWhatsAppDigits(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';

    final waMatch =
        RegExp(r'wa\.me/(\d+)', caseSensitive: false).firstMatch(s);
    if (waMatch != null) {
      s = waMatch.group(1)!;
    } else if (s.contains('://')) {
      final uri = Uri.tryParse(s);
      final pathDigits = uri?.pathSegments
          .where((p) => p.isNotEmpty)
          .map((p) => p.replaceAll(RegExp(r'\D'), ''))
          .where((p) => p.isNotEmpty)
          .toList();
      if (pathDigits != null && pathDigits.isNotEmpty) {
        s = pathDigits.last;
      }
    }

    var digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    while (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0')) {
      digits = '49${digits.substring(1)}';
    } else if (!digits.startsWith('49') &&
        digits.length >= 10 &&
        digits.length <= 11 &&
        digits.startsWith('1')) {
      digits = '49$digits';
    }

    return digits;
  }

  static bool isValidWhatsAppInput(String input) {
    final digits = normalizeWhatsAppDigits(input);
    if (digits.length < 10 || digits.length > 15) return false;
    if (digits.startsWith('0')) return false;
    return true;
  }

  static String _normalizeAccountInput(String platformId, String input) {
    var s = input.trim();
    if (s.isEmpty) return '';

    if (s.contains('://') ||
        s.startsWith('www.') ||
        s.contains('.com/') ||
        s.contains('.me/')) {
      return _accountFromStoredUrl(platformId, _ensureHttps(s));
    }

    s = s.replaceFirst(RegExp(r'^@+'), '');
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s;
  }

  static String _accountFromStoredUrl(String platformId, String stored) {
    final withScheme =
        stored.contains('://') ? stored : 'https://${stored.trim()}';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) return stored.trim();

    switch (platformId) {
      case 'facebook':
        return _lastMeaningfulSegment(uri) ?? stored.trim();
      case 'instagram':
        return _lastMeaningfulSegment(uri)?.replaceAll('/', '') ??
            stored.trim();
      case 'tiktok':
        final seg = _lastMeaningfulSegment(uri) ?? '';
        return seg.replaceFirst(RegExp(r'^@+'), '');
      case 'spotify':
        return _spotifyDisplayPath(uri);
      case 'soundcloud':
        return _lastMeaningfulSegment(uri) ?? stored.trim();
      case 'youtube':
        return _youtubeDisplay(uri);
      default:
        return stored.trim();
    }
  }

  static String _spotifyDisplayPath(Uri uri) {
    final segs =
        uri.pathSegments.where((s) => s.isNotEmpty && s != 'intl-de').toList();
    if (segs.isEmpty) return uri.toString();
    if (segs.first.startsWith('intl-')) segs.removeAt(0);
    return segs.join('/');
  }

  static String _youtubeDisplay(Uri uri) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return uri.toString();
    final first = segs.first;
    if (first.startsWith('@')) return first;
    if (first == 'channel' || first == 'c' || first == 'user') {
      return segs.length > 1 ? '$first/${segs[1]}' : first;
    }
    return first.replaceFirst(RegExp(r'^@+'), '');
  }

  static String? _lastMeaningfulSegment(Uri uri) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return null;
    return segs.last;
  }

  static String _buildPlatformUrl(String platformId, String account) {
    final a = account.trim().replaceFirst(RegExp(r'^@+'), '');
    switch (platformId) {
      case 'facebook':
        return 'https://www.facebook.com/$a';
      case 'instagram':
        return 'https://www.instagram.com/$a/';
      case 'tiktok':
        return 'https://www.tiktok.com/@$a';
      case 'spotify':
        if (a.contains('/')) {
          return 'https://open.spotify.com/$a';
        }
        return 'https://open.spotify.com/user/$a';
      case 'soundcloud':
        return 'https://soundcloud.com/$a';
      case 'youtube':
        if (a.startsWith('@')) {
          return 'https://www.youtube.com/$a';
        }
        if (a.startsWith('channel/') ||
            a.startsWith('c/') ||
            a.startsWith('user/')) {
          return 'https://www.youtube.com/$a';
        }
        return 'https://www.youtube.com/@$a';
      default:
        return _ensureHttps(a);
    }
  }

  static String _websiteToStored(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://')) {
      s = s.replaceFirst('http://', 'https://');
    } else if (!s.startsWith('https://')) {
      s = 'https://$s';
    }
    return s;
  }

  static String _websiteToDisplay(String stored) {
    var s = stored.trim();
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.replaceFirst(RegExp(r'^www\.'), '');
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static String _ensureHttps(String input) {
    final s = input.trim();
    if (s.startsWith('https://')) return s;
    if (s.startsWith('http://')) return s.replaceFirst('http://', 'https://');
    return 'https://$s';
  }
}
