/// Lesbare Gerätenamen für Admin/Support (iOS-Hardware-Codes → Marketingname).
class DeviceDisplayHelper {
  DeviceDisplayHelper._();

  static const Map<String, String> _iosMachineNames = {
    // iPhone 16
    'iPhone17,1': 'iPhone 16 Pro',
    'iPhone17,2': 'iPhone 16 Pro Max',
    'iPhone17,3': 'iPhone 16',
    'iPhone17,4': 'iPhone 16 Plus',
    'iPhone17,5': 'iPhone 16e',
    // iPhone 15
    'iPhone15,4': 'iPhone 15',
    'iPhone15,5': 'iPhone 15 Plus',
    'iPhone16,1': 'iPhone 15 Pro',
    'iPhone16,2': 'iPhone 15 Pro Max',
    // iPhone 14
    'iPhone14,7': 'iPhone 14',
    'iPhone14,8': 'iPhone 14 Plus',
    'iPhone15,2': 'iPhone 14 Pro',
    'iPhone15,3': 'iPhone 14 Pro Max',
    // iPhone 13 (Achtung: interne Codes beginnen mit „iPhone14,“)
    'iPhone14,4': 'iPhone 13 mini',
    'iPhone14,5': 'iPhone 13',
    'iPhone14,2': 'iPhone 13 Pro',
    'iPhone14,3': 'iPhone 13 Pro Max',
    // iPhone 12
    'iPhone13,1': 'iPhone 12 mini',
    'iPhone13,2': 'iPhone 12',
    'iPhone13,3': 'iPhone 12 Pro',
    'iPhone13,4': 'iPhone 12 Pro Max',
    // iPhone 11 / SE / Xr / Xs
    'iPhone12,1': 'iPhone 11',
    'iPhone12,3': 'iPhone 11 Pro',
    'iPhone12,5': 'iPhone 11 Pro Max',
    'iPhone12,8': 'iPhone SE (2. Gen.)',
    'iPhone11,8': 'iPhone XR',
    'iPhone11,2': 'iPhone XS',
    'iPhone11,4': 'iPhone XS Max',
    'iPhone11,6': 'iPhone XS Max',
    // iPhone X / 8 / 7 …
    'iPhone10,3': 'iPhone X',
    'iPhone10,6': 'iPhone X',
    'iPhone10,1': 'iPhone 8',
    'iPhone10,4': 'iPhone 8',
    'iPhone10,2': 'iPhone 8 Plus',
    'iPhone10,5': 'iPhone 8 Plus',
    'iPhone9,1': 'iPhone 7',
    'iPhone9,3': 'iPhone 7',
    'iPhone9,2': 'iPhone 7 Plus',
    'iPhone9,4': 'iPhone 7 Plus',
    'iPhone8,1': 'iPhone 6s',
    'iPhone8,2': 'iPhone 6s Plus',
    'iPhone8,4': 'iPhone SE (1. Gen.)',
    // iPad (Auswahl)
    'iPad14,1': 'iPad mini (6. Gen.)',
    'iPad14,2': 'iPad mini (6. Gen.)',
    'iPad13,18': 'iPad (10. Gen.)',
    'iPad13,19': 'iPad (10. Gen.)',
    'iPad14,3': 'iPad Pro 11" (4. Gen.)',
    'iPad14,4': 'iPad Pro 11" (4. Gen.)',
    'iPad14,5': 'iPad Pro 12.9" (6. Gen.)',
    'iPad14,6': 'iPad Pro 12.9" (6. Gen.)',
    'iPad16,3': 'iPad Pro 11" (M4)',
    'iPad16,4': 'iPad Pro 11" (M4)',
    'iPad16,5': 'iPad Pro 13" (M4)',
    'iPad16,6': 'iPad Pro 13" (M4)',
    // iPhone 17 (2025)
    'iPhone18,1': 'iPhone 17 Pro',
    'iPhone18,2': 'iPhone 17 Pro Max',
    'iPhone18,3': 'iPhone 17',
    'iPhone18,4': 'iPhone 17 Air',
  };

  /// Samsung-Modellcodes (SM-…) → Marketingname.
  static const Map<String, String> _samsungModelNames = {
    'SM-S938': 'Galaxy S25 Ultra',
    'SM-S936': 'Galaxy S25+',
    'SM-S931': 'Galaxy S25',
    'SM-S928': 'Galaxy S24 Ultra',
    'SM-S926': 'Galaxy S24+',
    'SM-S921': 'Galaxy S24',
    'SM-S918': 'Galaxy S23 Ultra',
    'SM-S916': 'Galaxy S23+',
    'SM-S911': 'Galaxy S23',
    'SM-A556': 'Galaxy A55 5G',
    'SM-A546': 'Galaxy A54 5G',
    'SM-A536': 'Galaxy A53 5G',
    'SM-A346': 'Galaxy A34 5G',
    'SM-A256': 'Galaxy A25 5G',
    'SM-A156': 'Galaxy A15 5G',
    'SM-F956': 'Galaxy Z Fold6',
    'SM-F946': 'Galaxy Z Fold5',
    'SM-F741': 'Galaxy Z Flip6',
    'SM-F731': 'Galaxy Z Flip5',
  };

  /// iOS-Hardware-Code (z. B. `iPhone14,5`) → `iPhone 13`.
  static String iosMarketingName(String machineCode) {
    final code = machineCode.trim();
    if (code.isEmpty) return '';
    final mapped = _iosMachineNames[code];
    if (mapped != null) return mapped;
    if (code.startsWith('iPhone')) return code;
    if (code.startsWith('iPad')) return code;
    return code;
  }

  /// Anzeige für Admin-UI; wandelt gespeicherte Rohwerte nach.
  static String displayStoredModel({
    required String? platform,
    required String? storedModel,
    String? storedModelCode,
  }) {
    final raw = (storedModel ?? '').trim();
    if (raw.isEmpty) return '–';
    final p = (platform ?? '').toLowerCase();
    if (p == 'ios') {
      final code = (storedModelCode ?? raw).trim();
      final friendly = iosMarketingName(code);
      if (friendly != code && friendly.isNotEmpty) return friendly;
      if (_iosMachineNames.containsKey(raw)) return _iosMachineNames[raw]!;
      return friendly.isNotEmpty ? friendly : raw;
    }
    final androidFriendly = _resolveSamsungMarketingName(raw.toUpperCase());
    if (androidFriendly != null) return androidFriendly;
    return raw;
  }

  static String androidDisplayName({
    required String manufacturer,
    required String model,
    String? brand,
    String? device,
    String? product,
  }) {
    final m = model.trim().toUpperCase();
    if (m.isEmpty) {
      final dev = (device ?? '').trim();
      if (dev.isNotEmpty) return _titleCase(dev);
      return 'Android-Gerät';
    }

    final samsungName = _resolveSamsungMarketingName(m);
    if (samsungName != null) return samsungName;

    final man = manufacturer.trim();
    final br = (brand ?? '').trim();
    final prefix = man.isNotEmpty
        ? _titleCase(man)
        : (br.isNotEmpty ? _titleCase(br) : '');
    if (prefix.isEmpty) return model.trim();
    if (m.toLowerCase().startsWith(prefix.toLowerCase())) {
      return _titleCase(model.trim());
    }
    return '$prefix ${model.trim()}';
  }

  static String? _resolveSamsungMarketingName(String modelUpper) {
    final direct = _samsungModelNames[modelUpper];
    if (direct != null) return direct;
    for (final entry in _samsungModelNames.entries) {
      if (modelUpper.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
