import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dj_library_prefs.dart';
import 'tool_i18n.dart';

/// Logo so groß wie das Fenster erlaubt. Randfarbe des Logos: #000B27.
/// Hintergrund und Rahmen sind feste Ebenen, damit die Liste sie nicht neu zeichnet.
class ToolBackdrop extends StatelessWidget {
  const ToolBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _FrozenBackdrop(),
        child,
        const _LiveFrame(),
        // Getrennt positioniert: keine volle Titelleisten-Row (die wurde
        // beim Hover weiß/grau). Nur unsichtbare Drag-Zone + kleines X.
        if (!kIsWeb && Platform.isWindows) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 40,
            height: 28,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => WindowChrome.startDrag(),
            ),
          ),
          const Positioned(
            top: 4,
            right: 6,
            child: _WindowsCloseButton(),
          ),
        ],
      ],
    );
  }
}

/// Close ohne Material/Tooltip/IconButton – die erzeugen den weißen Hover-Streifen.
class _WindowsCloseButton extends StatefulWidget {
  const _WindowsCloseButton();

  @override
  State<_WindowsCloseButton> createState() => _WindowsCloseButtonState();
}

class _WindowsCloseButtonState extends State<_WindowsCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => WindowChrome.close(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? const Color(0x55F44336) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.close,
            color: Color(0xFFF44336),
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _FrozenBackdrop extends StatelessWidget {
  const _FrozenBackdrop();

  static const asset = 'assets/vibesbox_logo.png';

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(0xFF000B27)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.15,
              colors: [
                Color(0xFF03183A),
                Color(0xFF000B27),
                Color(0xFF02031B),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Positioned.fill(child: _LogoPlate()),
        Positioned.fill(child: _DarkGlass()),
      ],
    );
  }
}

class _LogoPlate extends StatelessWidget {
  const _LogoPlate();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
        child: Image(
          image: AssetImage(_FrozenBackdrop.asset),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _DarkGlass extends StatelessWidget {
  const _DarkGlass();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 1.05,
          colors: [
            Color(0x99000B27),
            Color(0xE6000B27),
            Color(0xF202031B),
          ],
          stops: [0.15, 0.55, 1.0],
        ),
      ),
    );
  }
}

class ToolFramePulse extends ChangeNotifier {
  bool working = false;

  void setWorking(bool value) {
    if (working == value) return;
    working = value;
    notifyListeners();
  }
}

final toolFramePulse = ToolFramePulse();

/// Ruhiger Lilaraum. Während Scan und Suche läuft eine weiche Welle,
/// danach blinkt der Rahmen dreimal und geht aus.
/// Eigene Ebene: Listen-Updates bauen diesen Rahmen nicht neu.
class _LiveFrame extends StatefulWidget {
  const _LiveFrame();

  @override
  State<_LiveFrame> createState() => _LiveFrameState();
}

enum _FramePhase { idle, flow, blink }

class _LiveFrameState extends State<_LiveFrame>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _blink;
  _FramePhase _phase = _FramePhase.idle;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1080),
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        if (toolFramePulse.working) return;
        setState(() => _phase = _FramePhase.idle);
      });
    toolFramePulse.addListener(_onPulse);
    if (toolFramePulse.working) {
      _phase = _FramePhase.flow;
      _spin.repeat();
    }
  }

  void _onPulse() {
    final working = toolFramePulse.working;
    if (working && _phase != _FramePhase.flow) {
      _blink.stop();
      _spin.repeat();
      setState(() => _phase = _FramePhase.flow);
    } else if (!working && _phase == _FramePhase.flow) {
      _spin.stop();
      setState(() => _phase = _FramePhase.blink);
      _blink.forward(from: 0);
    }
  }

  @override
  void dispose() {
    toolFramePulse.removeListener(_onPulse);
    _spin.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: _phase == _FramePhase.flow
            ? AnimatedBuilder(
                animation: _spin,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _PurpleRingPainter(turn: _spin.value),
                    child: const SizedBox.expand(),
                  );
                },
              )
            : _phase == _FramePhase.blink
                ? AnimatedBuilder(
                    animation: _blink,
                    builder: (context, _) {
                      final cycle = (_blink.value * 3).clamp(0.0, 2.999);
                      final local = cycle - cycle.floorToDouble();
                      final on = math.sin(local * math.pi);
                      return CustomPaint(
                        painter: _FlashRingPainter(on: on),
                        child: const SizedBox.expand(),
                      );
                    },
                  )
                : CustomPaint(
                    painter: _IdleRingPainter(),
                    child: const SizedBox.expand(),
                  ),
      ),
    );
  }
}

/// Gleicher lila Rahmen wie das Tool-Fenster.
class ToolFrameShell extends StatelessWidget {
  const ToolFrameShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _IdleRingPainter(),
      child: child,
    );
  }
}

class _IdleRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ring = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(2.5),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..color = const Color(0xFFD7B4FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(_IdleRingPainter oldDelegate) => false;
}

class _PurpleRingPainter extends CustomPainter {
  _PurpleRingPainter({required this.turn});

  final double turn;

  static final List<Color> _wave = _buildWave();

  static List<Color> _buildWave() {
    const steps = 48;
    const dark = Color(0xFF3A1860);
    const light = Color(0xFFF6E8FF);
    final colors = <Color>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final main = math.pow(
        0.5 + 0.5 * math.cos(t * math.pi * 2),
        1.7,
      ).toDouble();
      final side = 0.22 *
          math.pow(
            0.5 + 0.5 * math.cos(t * math.pi * 4 + 0.9),
            2.4,
          ).toDouble();
      final mix = (main * 0.88 + side).clamp(0.0, 1.0);
      colors.add(Color.lerp(dark, light, mix)!);
    }
    return colors;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = RRect.fromRectAndRadius(
      rect.deflate(2.5),
      const Radius.circular(16),
    );
    final shader = SweepGradient(
      transform: GradientRotation(turn * math.pi * 2),
      colors: _wave,
    ).createShader(rect);
    canvas.drawRRect(
      ring,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PurpleRingPainter oldDelegate) => oldDelegate.turn != turn;
}

class _FlashRingPainter extends CustomPainter {
  _FlashRingPainter({required this.on});

  final double on;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(2.5),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..color = const Color(0xFFD7B4FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    if (on < 0.02) return;
    canvas.drawRRect(
      ring,
      Paint()
        ..color = const Color(0xFFF8EEFF).withValues(alpha: on)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + 8 * on,
    );
  }

  @override
  bool shouldRepaint(_FlashRingPainter oldDelegate) => oldDelegate.on != on;
}
