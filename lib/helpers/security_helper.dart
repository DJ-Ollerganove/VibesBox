class SecurityHelper {
  SecurityHelper._();

  static final RegExp _stripDangerousBlocks = RegExp(
    r'<\s*(script|style|iframe|svg|object|embed|link|meta)[^>]*>[\s\S]*?<\s*/\s*\1\s*>',
    caseSensitive: false,
    multiLine: true,
  );

  static final RegExp _stripAnyTag = RegExp(r'<[^>]*>', caseSensitive: false);

  static final List<RegExp> _dangerousPatterns = <RegExp>[
    RegExp(r'javascript\s*:', caseSensitive: false),
    RegExp(r'vbscript\s*:', caseSensitive: false),
    RegExp(r'data\s*:\s*text\/html', caseSensitive: false),
    RegExp(r'onerror', caseSensitive: false),
    RegExp(r'onload', caseSensitive: false),
    RegExp(r'onclick', caseSensitive: false),
    RegExp(r'onmouseover', caseSensitive: false),
    RegExp(r'eval\s*\(', caseSensitive: false),
    RegExp(r'<\s*iframe', caseSensitive: false),
    RegExp(r'<\s*script', caseSensitive: false),
  ];

  static const Map<String, int> _fieldLengthLimits = <String, int>{
    'name': 50,
    'displayname': 50,
    'realname': 80,
    'party_name': 100,
    'title': 100,
    'artist': 100,
    'subject': 120,
    'message': 500,
    'greeting': 500,
    'description': 500,
    'location_name': 120,
    'location_address': 200,
    'location_city': 80,
    'location_street': 120,
    'phone': 40,
    'phonenumber': 40,
    'email': 200,
    'pendingemail': 200,
    'url': 300,
    'website': 300,
    'instagram': 300,
    'facebook': 300,
    'youtube': 300,
    'spotify': 300,
    'soundcloud': 300,
    'tiktok': 300,
    'whatsapp': 300,
    'status': 40,
  };

  /// Entfernt potenziell gefährliche HTML/JS-Muster aus Freitexten.
  ///
  /// [trimInput]: Bei `false` keine [String.trim]-Aufrufe — nötig z. B. in
  /// [TextField.onChanged], sonst werden Leerzeichen zwischen Wörtern sofort
  /// entfernt (das Leerzeichen ist bis zum nächsten Zeichen „trailing“).
  static String sanitize(
    String? input, {
    int? maxLength,
    bool trimInput = true,
  }) {
    if (input == null) return '';
    var value = input;

    value = value.replaceAll('\u0000', '');
    value = value.replaceAll(_stripDangerousBlocks, '');
    value = value.replaceAll(_stripAnyTag, '');
    for (final pattern in _dangerousPatterns) {
      value = value.replaceAll(pattern, '');
    }

    if (trimInput) {
      value = value.trim();
    }
    if (maxLength != null && maxLength > 0 && value.length > maxLength) {
      value = value.substring(0, maxLength);
    }
    return value;
  }

  /// Rekursive Bereinigung von Strings innerhalb von Maps/Listen vor Firestore-Schreibvorgängen.
  static dynamic sanitizeDynamic(dynamic value, {int? maxLength}) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return sanitize(value, maxLength: maxLength);
    }
    if (value is List) {
      return value.map((entry) => sanitizeDynamic(entry)).toList();
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, dynamic mapValue) {
        final safeKey = key is String ? key : key.toString();
        final normalizedKey = safeKey.toLowerCase();
        final keyLimit = _fieldLengthLimits[normalizedKey];
        result[safeKey] = sanitizeDynamic(mapValue, maxLength: keyLimit);
      });
      return result;
    }
    return value;
  }

  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> input) {
    return sanitizeDynamic(input) as Map<String, dynamic>;
  }
}
