import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_localizations.dart';

/// Franken-State: Hastig zusammengesetzter, zerfetzter Zeitungsstapel mit Klebestreifen.
/// Überlappende asymmetrische Schnipsel, extremer Faserrand, fette Schreibmaschinenschrift.
class DeepStateNewspaper extends StatefulWidget {
  const DeepStateNewspaper({
    super.key,
    this.onReSyncStreams,
  });

  final VoidCallback? onReSyncStreams;

  @override
  State<DeepStateNewspaper> createState() => _DeepStateNewspaperState();
}

class _DeepStateNewspaperState extends State<DeepStateNewspaper>
    with TickerProviderStateMixin {
  bool _latencyLoading = false;
  int? _firestoreLatencyMs;
  String? _firestoreLatencyError;
  int? _httpLatencyMs;
  String? _httpLatencyError;

  String _deviceModel = '—';
  String _networkType = '—';
  String _firebaseState = '—';
  /// Installiert: `versionName` + Build (`versionCode`), z. B. `1.0.25 (25)`.
  String _localInstalledLabel = '…';
  /// Aus Play Store / App Store (new_version_plus), kein Firestore.
  String _storeListingVersion = '…';

  static const _paperColor = Color(0xFFF2E8D5);
  static const _ink = Color(0xFF1A1A1A);

  static const _paperW = 360.0;
  static const _paperH = 500.0;

  late AnimationController _controller;
  late List<Path> _paths;
  late List<double> _staggerDelays;
  late List<double> _pieceRotations;

  @override
  void initState() {
    super.initState();
    _paths = _buildAsymmetricTornPaths(_paperW, _paperH);
    final rnd = math.Random(54321);
    _staggerDelays = List.generate(_paths.length, (_) => rnd.nextDouble() * 0.5);
    const twoDeg = 2.0 * math.pi / 180;
    _pieceRotations = List.generate(_paths.length, (_) => (rnd.nextDouble() * 2 - 1) * twoDeg);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _controller.forward();
    _runLatencyCheck();
    _loadDeviceAndNetwork();
    _loadInstalledAndStoreVersions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Führt einen neuen Firestore-Ping aus und aktualisiert die Anzeige sofort.
  /// Firestore: ein `get` mit [Source.server] – Zeit bis Antwort vom Firestore-Backend
  /// (ein Dokument). Nutzt die bestehende Firebase-Verbindung; oft schneller als ein
  /// „kalter“ Request zur Website (WS).
  Future<(int?, String?)> _measureFirestoreLatency() async {
    try {
      final sw = Stopwatch()..start();
      await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .get(const GetOptions(source: Source.server));
      sw.stop();
      return (sw.elapsedMilliseconds, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  /// Website: [HEAD] auf `https://www.vibesbox.app` – oft höher als FS (neuer Host/TLS).
  /// Label in der UI: **WS** (Website).
  Future<(int?, String?)> _measureWebsiteLatency() async {
    if (kIsWeb) {
      return (null, 'web');
    }
    try {
      final sw = Stopwatch()..start();
      await http
          .head(Uri.parse('https://www.vibesbox.app'))
          .timeout(const Duration(seconds: 12));
      sw.stop();
      return (sw.elapsedMilliseconds, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  Future<void> _runLatencyCheck() async {
    if (_latencyLoading) return;
    setState(() {
      _latencyLoading = true;
      _firestoreLatencyError = null;
      _httpLatencyError = null;
      _firestoreLatencyMs = null;
      _httpLatencyMs = null;
      _firebaseState = '…';
    });

    if (kIsWeb) {
      final fire = await _measureFirestoreLatency();
      if (!mounted) return;
      setState(() {
        _latencyLoading = false;
        _firestoreLatencyMs = fire.$1;
        _firestoreLatencyError = fire.$2;
        _httpLatencyMs = null;
        _httpLatencyError = 'web';
        _firebaseState = fire.$2 == null ? 'connected' : 'error';
      });
      return;
    }

    final results = await Future.wait([
      _measureFirestoreLatency(),
      _measureWebsiteLatency(),
    ]);
    final fire = results[0];
    final httpR = results[1];

    if (!mounted) return;
    setState(() {
      _latencyLoading = false;
      _firestoreLatencyMs = fire.$1;
      _firestoreLatencyError = fire.$2;
      _httpLatencyMs = httpR.$1;
      _httpLatencyError = httpR.$2;
      _firebaseState = fire.$2 == null ? 'connected' : 'error';
    });
  }

  static Color _latencyColorForMs(int? ms) {
    if (ms == null) return Colors.red;
    if (ms < 150) return Colors.green;
    if (ms <= 400) return Colors.orange;
    return Colors.red;
  }

  Future<void> _loadDeviceAndNetwork() async {
    String model = '—';
    try {
      final deviceInfo = DeviceInfoPlugin();
      try {
        final android = await deviceInfo.androidInfo;
        model = android.model.isNotEmpty ? android.model : (android.brand ?? 'Android');
      } catch (_) {
        final ios = await deviceInfo.iosInfo;
        model = ios.utsname.machine.isNotEmpty ? ios.utsname.machine : (ios.model);
        if (model.isEmpty) model = ios.name;
      }
    } catch (_) {}
    String net = '—';
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.wifi)) {
        net = 'WiFi';
      } else if (result.contains(ConnectivityResult.mobile)) {
        net = 'Cellular';
      } else if (result.contains(ConnectivityResult.ethernet)) {
        net = 'Ethernet';
      } else if (result.isNotEmpty) {
        net = result.first.name;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _deviceModel = model;
        _networkType = net;
      });
    }
  }

  Future<void> _loadInstalledAndStoreVersions() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      final b = info.buildNumber.trim();
      final local = b.isNotEmpty ? '$v ($b)' : v;
      if (mounted) setState(() => _localInstalledLabel = local.isNotEmpty ? local : '—');
    } catch (_) {
      if (mounted) setState(() => _localInstalledLabel = '—');
    }

    if (kIsWeb) {
      if (mounted) setState(() => _storeListingVersion = '—');
      return;
    }

    try {
      final status = await NewVersionPlus().getVersionStatus();
      final store = status?.storeVersion.trim() ?? '';
      if (mounted) {
        setState(() => _storeListingVersion = store.isNotEmpty ? store : '—');
      }
    } catch (_) {
      if (mounted) setState(() => _storeListingVersion = '—');
    }
  }

  double _pieceOpacity(int index) {
    final t = _controller.value;
    const fadeDuration = 0.22;
    final start = _staggerDelays[index];
    if (t <= start) return 0.0;
    return ((t - start) / fadeDuration).clamp(0.0, 1.0);
  }

  bool get _allPiecesVisible {
    for (int i = 0; i < _paths.length; i++) {
      if (_pieceOpacity(i) < 0.99) return false;
    }
    return true;
  }

  /// STORE/LOKAL: dunkle Schrift mit weißer Kontur (Lesbarkeit auf Papier + Rand).
  Widget _outlinedInfoLine(String text) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _ink,
        fontFamily: 'Courier',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        height: 1.15,
        shadows: [
          Shadow(offset: Offset(-1, -1), color: Colors.white, blurRadius: 0),
          Shadow(offset: Offset(1, -1), color: Colors.white, blurRadius: 0),
          Shadow(offset: Offset(-1, 1), color: Colors.white, blurRadius: 0),
          Shadow(offset: Offset(1, 1), color: Colors.white, blurRadius: 0),
          Shadow(offset: Offset(0, -1.2), color: Colors.white, blurRadius: 0),
          Shadow(offset: Offset(0, 1.2), color: Colors.white, blurRadius: 0),
          Shadow(offset: Offset(-1.2, 0), color: Colors.white, blurRadius: 0),
          Shadow(offset: Offset(1.2, 0), color: Colors.white, blurRadius: 0),
        ],
      ),
    );
  }

  /// Überlappende, völlig asymmetrische Schnipsel mit extrem ausgefransten Rändern (Jitter pro ~1.5 px).
  static List<Path> _buildAsymmetricTornPaths(double w, double h) {
    const stepPx = 1.5;
    const jitterMax = 3.5;
    final rnd = math.Random(12345);

    Path tornPolygon(List<Offset> vertices) {
      final p = Path();
      for (int i = 0; i < vertices.length; i++) {
        final a = vertices[i];
        final b = vertices[(i + 1) % vertices.length];
        final len = (Offset(b.dx - a.dx, b.dy - a.dy)).distance;
        final steps = (len / stepPx).ceil().clamp(3, 400);
        final seed = (a.dx * 1000 + a.dy + b.dx * 10 + b.dy).hashCode;
        final edgeRnd = math.Random(seed);
        for (int k = 0; k <= steps; k++) {
          final t = steps > 0 ? k / steps : 1.0;
          final jx = (edgeRnd.nextDouble() - 0.5) * 2 * jitterMax;
          final jy = (edgeRnd.nextDouble() - 0.5) * 2 * jitterMax;
          final x = a.dx + (b.dx - a.dx) * t + jx;
          final y = a.dy + (b.dy - a.dy) * t + jy;
          if (k == 0 && i == 0) p.moveTo(x, y);
          else p.lineTo(x, y);
        }
      }
      p.close();
      return p;
    }

    double j(double scale) => (rnd.nextDouble() - 0.5) * scale;
    final j20 = 20.0;
    final j30 = 28.0;

    return [
      tornPolygon([
        Offset(0 + j(j20), 0 + j(j20)),
        Offset(w * 0.45 + j(j30), 0 + j(j20)),
        Offset(w * 0.5 + j(j30), h * 0.4 + j(j30)),
        Offset(w * 0.15 + j(j20), h * 0.55 + j(j30)),
        Offset(0 + j(j20), h * 0.35 + j(j20)),
      ]),
      tornPolygon([
        Offset(w * 0.35 + j(j30), 0 + j(j20)),
        Offset(w + j(j20), 0 + j(j20)),
        Offset(w * 0.85 + j(j20), h * 0.45 + j(j30)),
        Offset(w * 0.55 + j(j30), h * 0.4 + j(j30)),
      ]),
      tornPolygon([
        Offset(w * 0.1 + j(j20), h * 0.4 + j(j30)),
        Offset(w * 0.55 + j(j30), h * 0.35 + j(j30)),
        Offset(w * 0.6 + j(j30), h * 0.75 + j(j30)),
        Offset(0 + j(j20), h * 0.9 + j(j20)),
      ]),
      tornPolygon([
        Offset(w * 0.5 + j(j30), h * 0.35 + j(j30)),
        Offset(w * 0.95 + j(j20), h * 0.4 + j(j30)),
        Offset(w * 0.9 + j(j20), h * 0.85 + j(j20)),
        Offset(w * 0.5 + j(j30), h * 0.8 + j(j30)),
      ]),
      tornPolygon([
        Offset(0 + j(j20), h * 0.75 + j(j20)),
        Offset(w * 0.4 + j(j30), h * 0.7 + j(j30)),
        Offset(w * 0.35 + j(j30), h + j(j20)),
        Offset(0 + j(j20), h + j(j20)),
      ]),
      tornPolygon([
        Offset(w * 0.35 + j(j30), h * 0.65 + j(j30)),
        Offset(w * 0.85 + j(j20), h * 0.7 + j(j30)),
        Offset(w + j(j20), h + j(j20)),
        Offset(w * 0.4 + j(j30), h + j(j20)),
      ]),
      tornPolygon([
        Offset(w * 0.15 + j(j20), h * 0.2 + j(j30)),
        Offset(w * 0.7 + j(j30), h * 0.15 + j(j30)),
        Offset(w * 0.75 + j(j30), h * 0.55 + j(j30)),
        Offset(w * 0.25 + j(j20), h * 0.6 + j(j30)),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final header = l10n.connectionTestTitle;
    final latencyLabel = l10n.latencyLabel;
    final hardwareLabel = l10n.hardwareLabel;
    final networkLabel = l10n.networkLabel;
    final databaseLabel = l10n.databaseLabel;
    final storeLabel = l10n.updateStoreLabel;
    final localLabel = l10n.updateLocalLabel;
    final databaseStateText =
        _latencyLoading ? '…' : (_firestoreLatencyError != null ? 'error' : 'connected');

    final String fsDisplay;
    final Color fsColor;
    final String httpDisplay;
    final Color httpColor;
    if (_latencyLoading) {
      fsDisplay = '…';
      httpDisplay = '…';
      fsColor = _ink;
      httpColor = _ink;
    } else {
      if (_firestoreLatencyError != null) {
        fsDisplay = '—';
        fsColor = Colors.red;
      } else {
        fsDisplay = '${_firestoreLatencyMs ?? 0} ms';
        fsColor = _latencyColorForMs(_firestoreLatencyMs);
      }
      if (_httpLatencyError == 'web') {
        httpDisplay = 'n/a';
        httpColor = Colors.grey;
      } else if (_httpLatencyError != null) {
        httpDisplay = '—';
        httpColor = Colors.red;
      } else {
        httpDisplay = '${_httpLatencyMs ?? 0} ms';
        httpColor = _latencyColorForMs(_httpLatencyMs);
      }
    }
    return SizedBox(
      width: _paperW,
      height: _paperH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final opacities = List.generate(_paths.length, (i) => _pieceOpacity(i));
              return CustomPaint(
                size: const Size(_paperW, _paperH),
                painter: _TornStackPainter(
                  paths: _paths,
                  opacities: opacities,
                  rotations: _pieceRotations,
                  header: header,
                  latencyLabel: latencyLabel,
                  fsLatencyDisplay: fsDisplay,
                  httpLatencyDisplay: httpDisplay,
                  fsLatencyColor: fsColor,
                  httpLatencyColor: httpColor,
                  hardwareLabel: hardwareLabel,
                  deviceModel: _deviceModel,
                  networkLabel: networkLabel,
                  networkType: _networkType,
                  databaseLabel: databaseLabel,
                  databaseState: databaseStateText,
                ),
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: CustomPaint(
                size: const Size(40, 40),
                painter: _EddingXPainter(),
              ),
            ),
          ),
          Positioned(
            left: 248,
            top: 64,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _runLatencyCheck,
              child: SizedBox(
                width: 34,
                height: 34,
                child: CustomPaint(
                  size: const Size(34, 34),
                  painter: _EddingRefreshPainter(),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 26,
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _outlinedInfoLine('$storeLabel: $_storeListingVersion'),
                const SizedBox(height: 3),
                _outlinedInfoLine('$localLabel: $_localInstalledLabel'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _ink = Color(0xFF000000);
const _paperColor = Color(0xFFF2E8D5);

/// Tesafilm-Look: gelblich-transparent
const _tapeColor = Color(0x55E8DCB0);

/// Zeichnet Schnipsel (Faserrand, Schatten, Fill), dann Klebestreifen, Text fragmentiert. Pro Schnipsel ±2° Rotation.
class _TornStackPainter extends CustomPainter {
  _TornStackPainter({
    required this.paths,
    required this.opacities,
    required this.rotations,
    required this.header,
    required this.latencyLabel,
    required this.fsLatencyDisplay,
    required this.httpLatencyDisplay,
    required this.fsLatencyColor,
    required this.httpLatencyColor,
    required this.hardwareLabel,
    required this.deviceModel,
    required this.networkLabel,
    required this.networkType,
    required this.databaseLabel,
    required this.databaseState,
  });

  final List<Path> paths;
  final List<double> opacities;
  final List<double> rotations;
  final String header;
  final String latencyLabel;
  final String fsLatencyDisplay;
  final String httpLatencyDisplay;
  final Color fsLatencyColor;
  final Color httpLatencyColor;
  final String hardwareLabel;
  final String deviceModel;
  final String networkLabel;
  final String networkType;
  final String databaseLabel;
  final String databaseState;

  static const _mono = 'Courier';

  @override
  void paint(Canvas canvas, Size size) {
    const headerSize = 16.0;
    const lineSize = 17.0;
    final baseStyle = const TextStyle(fontFamily: _mono, fontSize: lineSize, fontWeight: FontWeight.w900, color: _ink);

    final headerTp = TextPainter(
      text: TextSpan(text: header, style: baseStyle.copyWith(fontSize: headerSize)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);

    // Zeile 1: Latenz FS … | Zeile 2: WS … (Website)
    final latencyTp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: '$latencyLabel FS ', style: baseStyle),
          TextSpan(
            text: fsLatencyDisplay,
            style: baseStyle.copyWith(color: fsLatencyColor, fontWeight: FontWeight.bold),
          ),
          TextSpan(text: '\nWS ', style: baseStyle),
          TextSpan(
            text: httpLatencyDisplay,
            style: baseStyle.copyWith(color: httpLatencyColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);

    final hardwareTp = TextPainter(
      text: TextSpan(text: '$hardwareLabel: $deviceModel', style: baseStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);

    final networkTp = TextPainter(
      text: TextSpan(text: '$networkLabel: $networkType', style: baseStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);

    final databaseValueColor = databaseState == 'connected'
        ? Colors.green
        : (databaseState == 'error' ? Colors.red : _ink);
    final databaseTp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: '$databaseLabel: ', style: baseStyle),
          TextSpan(
            text: databaseState,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold, color: databaseValueColor),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);

    const topPad = 32.0;
    final centerX = size.width / 2;
    final headerOffset = Offset(centerX - headerTp.width / 2, topPad);
    const leftPad = 44.0;
    final latencyOffset = Offset(leftPad, topPad + headerTp.height + 16);
    final hardwareOffset = Offset(leftPad, latencyOffset.dy + latencyTp.height + 12);
    final networkOffset = Offset(leftPad, hardwareOffset.dy + hardwareTp.height + 10);
    final databaseOffset = Offset(leftPad, networkOffset.dy + networkTp.height + 10);

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final opacity = opacities[i].clamp(0.0, 1.0);
      if (opacity <= 0.0) continue;

      final bounds = path.getBounds();
      final center = bounds.center;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotations[i]);
      canvas.translate(-center.dx, -center.dy);

      // 1. Weißer Faserrand (wie gerissenes Papier)
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // 2. Schatten
      canvas.drawShadow(path, Colors.black45, 5.0 + (i % 3) * 1.2, true);
      canvas.drawShadow(path, Colors.black26, 2.5, true);

      // 3. Fleckiges Altweiß/Beige
      canvas.drawPath(path, Paint()..color = _paperColor.withValues(alpha: opacity));
      canvas.drawPath(
        path,
        Paint()
          ..color = _ink.withValues(alpha: opacity * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // 4. Text hart über die Risse (Buchstabe bricht am Schnipselrand ab)
      canvas.saveLayer(path.getBounds(), Paint()..color = Colors.white.withValues(alpha: opacity));
      canvas.clipPath(path);
      headerTp.paint(canvas, headerOffset);
      latencyTp.paint(canvas, latencyOffset);
      hardwareTp.paint(canvas, hardwareOffset);
      networkTp.paint(canvas, networkOffset);
      databaseTp.paint(canvas, databaseOffset);
      canvas.restore();
      canvas.restore();
    }

    // 5. Klebestreifen (Tesafilm) über Ecken
    _drawTape(canvas, size);
  }

  void _drawTape(Canvas canvas, Size size) {
    final tape = Paint()
      ..color = _tapeColor
      ..style = PaintingStyle.fill;
    const tw = 28.0;
    const th = 14.0;

    canvas.save();
    canvas.translate(8, 12);
    canvas.rotate(-0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, tw, th), const Radius.circular(2)), tape);
    canvas.restore();

    canvas.save();
    canvas.translate(size.width - 50, size.height - 35);
    canvas.rotate(0.4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, tw * 1.2, th), const Radius.circular(2)), tape);
    canvas.restore();

    canvas.save();
    canvas.translate(4, size.height * 0.45);
    canvas.rotate(-0.15);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, th, tw), const Radius.circular(2)), tape);
    canvas.restore();

    canvas.save();
    canvas.translate(size.width - 38, 80);
    canvas.rotate(0.25);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, th, tw * 0.8), const Radius.circular(2)), tape);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TornStackPainter old) {
    return old.header != header ||
        old.fsLatencyDisplay != fsLatencyDisplay ||
        old.httpLatencyDisplay != httpLatencyDisplay ||
        old.fsLatencyColor != fsLatencyColor ||
        old.httpLatencyColor != httpLatencyColor ||
        old.deviceModel != deviceModel ||
        old.networkType != networkType ||
        old.databaseState != databaseState ||
        old.opacities != opacities;
  }
}

/// Großer fetter Kreispfeil direkt neben Latenz-Wert, Edding-Stil (handgemalt), klickbar.
class _EddingRefreshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(456);
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.38;
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (double a = 0; a <= 2 * math.pi; a += 0.08) {
      final j = (rnd.nextDouble() - 0.5) * 1.8;
      path.lineTo(c.dx + (r + j) * math.cos(a), c.dy + (r + j) * math.sin(a));
    }
    path.close();
    canvas.drawPath(path, paint);

    path.reset();
    path.moveTo(c.dx + r * 0.6, c.dy - r * 0.6);
    path.lineTo(c.dx + r * 1.12 + (rnd.nextDouble() - 0.5), c.dy - r * 0.22);
    path.moveTo(c.dx + r * 0.88, c.dy - r * 0.42);
    path.lineTo(c.dx + r * 1.18, c.dy - r * 0.08);
    path.lineTo(c.dx + r * 0.72, c.dy + r * 0.12);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fettes schwarzes X, Edding-Stil.
class _EddingXPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(789);
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    double j() => (rnd.nextDouble() - 0.5) * 2.0;
    canvas.drawLine(Offset(10 + j(), 10 + j()), Offset(size.width - 10 + j(), size.height - 10 + j()), paint);
    canvas.drawLine(Offset(size.width - 10 + j(), 10 + j()), Offset(10 + j(), size.height - 10 + j()), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
