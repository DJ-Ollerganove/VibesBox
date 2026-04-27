import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Deep-State-Menü als animiertes, zerstückeltes Zeitungspapier.
/// 6–8 Schnipsel liegen aneinander; Staggered Fade-In; Text fragmentiert pro Schnipsel.
class DeepStateOverlay extends StatefulWidget {
  const DeepStateOverlay({
    super.key,
    this.onRefreshStreams,
  });

  final VoidCallback? onRefreshStreams;

  @override
  State<DeepStateOverlay> createState() => _DeepStateOverlayState();
}

class _DeepStateOverlayState extends State<DeepStateOverlay>
    with TickerProviderStateMixin {
  int? _latencyMs;
  bool _latencyLoading = false;
  String? _latencyError;

  static const _paperColor = Color(0xFFF2E8D5);
  static const _ink = Color(0xFF1A1A1A);

  static const _paperW = 300.0;
  static const _paperH = 360.0;

  /// Leicht schiefes Blatt: leichte Rotation (Rad).
  static const _tiltRad = -0.02;

  late AnimationController _controller;
  late List<Path> _paths;
  /// Zufällige Startverzögerung pro Teil (0..1), fest pro initState.
  late List<double> _staggerDelays;

  @override
  void initState() {
    super.initState();
    _paths = _buildTornPuzzlePaths(_paperW, _paperH);
    final rnd = math.Random(12345);
    _staggerDelays = List.generate(_paths.length, (_) => rnd.nextDouble() * 0.35);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _controller.forward();
    _measureLatency();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opacity pro Teil: Staggered Fade-In, ~400ms pro Teil mit Überlappung.
  double _pieceOpacity(int index) {
    final t = _controller.value;
    const totalMs = 2400;
    const fadeMs = 400.0;
    final fadeDuration = fadeMs / totalMs; // Anteil der Gesamtdauer
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

  /// 6–8 Schnipsel mit geteilten, ausgefransten Kanten (ein Gesamtblatt).
  static List<Path> _buildTornPuzzlePaths(double w, double h) {
    const jitter = 6.0;

    int edgeKey(double x1, double y1, double x2, double y2) {
      final ax = x1.round();
      final ay = y1.round();
      final bx = x2.round();
      final by = y2.round();
      if (ax < bx || (ax == bx && ay <= by)) return (ax * 10000 + ay) * 10000 + bx * 100 + by;
      return (bx * 10000 + by) * 10000 + ax * 100 + ay;
    }

    final edgeCache = <int, List<Offset>>{};
    List<Offset> tornSegment(double x1, double y1, double x2, double y2) {
      final key = edgeKey(x1, y1, x2, y2);
      if (edgeCache.containsKey(key)) return edgeCache[key]!;
      final seed = key.hashCode;
      final r = math.Random(seed);
      double j() => (r.nextDouble() - 0.5) * jitter;
      const steps = 6;
      final pts = <Offset>[];
      for (int s = 0; s <= steps; s++) {
        final t = s / steps;
        pts.add(Offset(
          x1 + (x2 - x1) * t + j(),
          y1 + (y2 - y1) * t + j(),
        ));
      }
      edgeCache[key] = pts;
      edgeCache[edgeKey(x2, y2, x1, y1)] = pts.reversed.toList();
      return pts;
    }

    Path buildPiece(List<Offset> vertices) {
      final p = Path();
      final v = vertices;
      final allPts = <Offset>[];
      for (int i = 0; i < v.length; i++) {
        final a = v[i];
        final b = v[(i + 1) % v.length];
        final seg = tornSegment(a.dx, a.dy, b.dx, b.dy);
        if (i == 0) {
          allPts.addAll(seg);
        } else {
          allPts.addAll(seg.sublist(1));
        }
      }
      if (allPts.isEmpty) return p;
      p.moveTo(allPts[0].dx, allPts[0].dy);
      for (int i = 1; i < allPts.length; i++) {
        p.lineTo(allPts[i].dx, allPts[i].dy);
      }
      p.close();
      return p;
    }

    final w1 = w * 0.25;
    final w2 = w * 0.5;
    final w3 = w * 0.75;
    final h1 = h * 0.5;
    return [
      buildPiece([const Offset(0, 0), Offset(w1, 0), Offset(w1, h1), Offset(0, h1)]),
      buildPiece([Offset(w1, 0), Offset(w2, 0), Offset(w2, h1), Offset(w1, h1)]),
      buildPiece([Offset(w2, 0), Offset(w3, 0), Offset(w3, h1), Offset(w2, h1)]),
      buildPiece([Offset(w3, 0), Offset(w, 0), Offset(w, h1), Offset(w3, h1)]),
      buildPiece([Offset(0, h1), Offset(w1, h1), Offset(w1, h), Offset(0, h)]),
      buildPiece([Offset(w1, h1), Offset(w2, h1), Offset(w2, h), Offset(w1, h)]),
      buildPiece([Offset(w2, h1), Offset(w3, h1), Offset(w3, h), Offset(w2, h)]),
      buildPiece([Offset(w3, h1), Offset(w, h1), Offset(w, h), Offset(w3, h)]),
    ];
  }

  Future<void> _measureLatency() async {
    if (_latencyLoading) return;
    setState(() {
      _latencyLoading = true;
      _latencyError = null;
      _latencyMs = null;
    });
    try {
      final stopwatch = Stopwatch()..start();
      await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .get();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _latencyMs = stopwatch.elapsedMilliseconds;
          _latencyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _latencyError = e.toString();
          _latencyLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = l10n.signalLabel;
    final msText = _latencyLoading
        ? '... ms'
        : _latencyError != null
            ? '— ms'
            : '${_latencyMs ?? 0} ms';
    final allVisible = _allPiecesVisible;

    return Transform.rotate(
      angle: _tiltRad,
      child: SizedBox(
        width: _paperW,
        height: _paperH,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final opacities = List.generate(_paths.length, (i) => _pieceOpacity(i));
                return CustomPaint(
                  size: const Size(_paperW, _paperH),
                  painter: _TornPaperFragmentedPainter(
                    paths: _paths,
                    opacities: opacities,
                    label: label,
                    msText: msText,
                  ),
                );
              },
            ),
            // Refresh-Icon neben der ms-Anzeige (Latenz-Zeile im Painter)
            Positioned(
              left: _paperW / 2 + 55,
              top: _paperH * 0.32 + 14 + 12 - 10,
              child: AnimatedOpacity(
                opacity: allVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !allVisible,
                  child: GestureDetector(
                    onTap: allVisible ? _measureLatency : null,
                    child: CustomPaint(
                      size: const Size(40, 40),
                      painter: _HandDrawnRefreshPainter(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedOpacity(
                opacity: allVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !allVisible,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: CustomPaint(
                      size: const Size(36, 36),
                      painter: _HandDrawnXPainter(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zeichnet alle Schnipsel und den fragmentierten Text (pro Schnipsel geclippt + gleiche Opacity).
class _TornPaperFragmentedPainter extends CustomPainter {
  _TornPaperFragmentedPainter({
    required this.paths,
    required this.opacities,
    required this.label,
    required this.msText,
  });

  final List<Path> paths;
  final List<double> opacities;
  final String label;
  final String msText;

  static const _paperColor = Color(0xFFF2E8D5);
  static const _ink = Color(0xFF1A1A1A);

  @override
  void paint(Canvas canvas, Size size) {
    const labelFontSize = 14.0;
    const msFontSize = 24.0;
    final labelTp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: labelFontSize,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 56);

    final msTp = TextPainter(
      text: TextSpan(
        text: msText,
        style: const TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: msFontSize,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 56);

    labelTp.layout(maxWidth: size.width - 56);
    msTp.layout(maxWidth: size.width - 56);
    final centerX = size.width / 2;
    final labelOffset = Offset(centerX - labelTp.width / 2, size.height * 0.32);
    final msOffset = Offset(centerX - msTp.width / 2, labelOffset.dy + labelTp.height + 12);

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final opacity = opacities[i].clamp(0.0, 1.0);
      if (opacity <= 0.0) continue;

      canvas.save();
      canvas.drawShadow(path, Colors.black26, 4.0, true);
      canvas.drawPath(path, Paint()..color = _paperColor.withValues(alpha: opacity));
      canvas.drawPath(
        path,
        Paint()
          ..color = _ink.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.saveLayer(path.getBounds(), Paint()..color = Colors.white.withValues(alpha: opacity));
      canvas.clipPath(path);
      labelTp.paint(canvas, labelOffset);
      msTp.paint(canvas, msOffset);
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TornPaperFragmentedPainter oldDelegate) {
    return oldDelegate.label != label ||
        oldDelegate.msText != msText ||
        oldDelegate.opacities != opacities;
  }
}

/// Handgezeichnetes Refresh (Kreis + Pfeil).
class _HandDrawnRefreshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const ink = Color(0xFF1A1A1A);
    final rnd = math.Random(456);
    final c = Offset(size.width / 2, size.height / 2);
    const r = 16.0;
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path();
    for (double a = 0; a <= 2 * math.pi; a += 0.1) {
      final j = (rnd.nextDouble() - 0.5) * 1.0;
      path.lineTo(
        c.dx + (r + j) * math.cos(a),
        c.dy + (r + j) * math.sin(a),
      );
    }
    path.close();
    canvas.drawPath(path, paint);

    path.reset();
    path.moveTo(c.dx + r * 0.65, c.dy - r * 0.65);
    path.lineTo(c.dx + r * 1.1 + (rnd.nextDouble() - 0.5), c.dy - r * 0.25);
    path.moveTo(c.dx + r * 0.9, c.dy - r * 0.4);
    path.lineTo(c.dx + r * 1.15, c.dy - r * 0.1);
    path.moveTo(c.dx + r * 0.9, c.dy - r * 0.4);
    path.lineTo(c.dx + r * 0.7, c.dy + r * 0.1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Handgezeichnetes X (Schließen).
class _HandDrawnXPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const ink = Color(0xFF1A1A1A);
    final rnd = math.Random(789);
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    double j() => (rnd.nextDouble() - 0.5) * 1.5;
    canvas.drawLine(
      Offset(8 + j(), 8 + j()),
      Offset(size.width - 8 + j(), size.height - 8 + j()),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 8 + j(), 8 + j()),
      Offset(8 + j(), size.height - 8 + j()),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
