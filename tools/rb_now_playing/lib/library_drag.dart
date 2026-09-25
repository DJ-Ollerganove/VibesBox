import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'library_match.dart';
import 'tool_i18n.dart';

/// Welches Programm den Drop empfängt (Tidal-Suche ist nicht Finder-Standard).
String deckDragSoftware = 'rekordbox';

class LibraryMatchChrome extends StatelessWidget {
  const LibraryMatchChrome({
    super.key,
    required this.matched,
    required this.child,
    this.filePath,
    this.title,
    this.artist,
    this.isTidal = false,
    this.dragEnabled = true,
    this.roundedFrame = false,
    this.fill,
  });

  final bool matched;
  final Widget child;
  final String? filePath;
  final String? title;
  final String? artist;
  final bool isTidal;
  final bool dragEnabled;
  final bool roundedFrame;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    const hair = Color(0x33FFFFFF);
    final inner = roundedFrame && matched
        ? Stack(
            children: [
              child,
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: ColoredBox(color: Color(0xFF7CFFB2)),
              ),
            ],
          )
        : child;
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: fill ??
            (matched ? const Color(0xFF16301F) : Colors.transparent),
        borderRadius: roundedFrame ? BorderRadius.circular(8) : null,
        border: roundedFrame
            ? Border.all(color: hair, width: 0.6)
            : (matched
                ? const Border(
                    left: BorderSide(color: Color(0xFF7CFFB2), width: 3),
                  )
                : null),
      ),
      child: inner,
    );
    final row = roundedFrame
        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: decorated)
        : decorated;
    if (!dragEnabled) return row;
    final path = filePath;
    if (!isRekordboxDragPath(path)) return row;
    return _FinderFileDrag(
      path: path!,
      title: title ?? '',
      artist: artist ?? '',
      child: row,
    );
  }
}

class _FinderFileDrag extends StatefulWidget {
  const _FinderFileDrag({
    required this.path,
    required this.title,
    required this.artist,
    required this.child,
  });

  final String path;
  final String title;
  final String artist;
  final Widget child;

  @override
  State<_FinderFileDrag> createState() => _FinderFileDragState();
}

class _FinderFileDragState extends State<_FinderFileDrag> {
  static const _channel = MethodChannel('vibesbox_sync/file_drag');

  Future<void> _arm() async {
    final path = widget.path;
    if (path.startsWith('/')) {
      if (!File(path).existsSync()) return;
    } else if (!path.toLowerCase().startsWith('tidal:tracks:')) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('arm', {
        'path': path,
        'title': widget.title,
        'artist': widget.artist,
        'software': deckDragSoftware,
      });
    } catch (_) {}
  }

  Future<void> _disarm() async {
    try {
      await _channel.invokeMethod<bool>('cancel');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => unawaited(_arm()),
      onExit: (event) {
        if (event.down) return;
        unawaited(_disarm());
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => unawaited(_arm()),
        child: widget.child,
      ),
    );
  }
}

String libraryMatchLabel({
  required bool isTidal,
  required int playCount,
  required bool canDrag,
}) {
  final plays = playCount > 0 ? toolI18n.text('plays', {'n': '$playCount'}) : null;
  if (isTidal && canDrag) {
    return [?plays, toolI18n.text('tidalDrag')].join(' · ');
  }
  if (isTidal) {
    return [?plays, 'Tidal'].join(' · ');
  }
  return plays ?? toolI18n.text('libraryWord');
}

class LibraryPathText extends StatelessWidget {
  const LibraryPathText({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();
    final missing = path.startsWith('/') && !File(path).existsSync();
    return SelectableText(
      missing ? '$path\n${toolI18n.text('fileMissing')}' : path,
      style: TextStyle(
        color: missing ? const Color(0xFFFF8A80) : const Color(0xFF90A4AE),
        fontSize: 10,
        height: 1.3,
        fontFamily: 'Menlo',
      ),
    );
  }
}

class LibrarySourceIcon extends StatelessWidget {
  const LibrarySourceIcon({
    super.key,
    required this.visible,
    required this.isTidal,
    this.searching = false,
    this.onOpen,
  });

  final bool visible;
  final bool isTidal;
  final bool searching;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Padding(
        padding: EdgeInsets.only(right: 6, top: 1),
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: Color(0xFFFF8800),
          ),
        ),
      );
    }
    if (!visible) return const SizedBox.shrink();
    final icon = isTidal
        ? const CustomPaint(
            size: Size(12, 12),
            painter: _TidalLogoPainter(),
          )
        : const Icon(
            Icons.computer,
            size: 14,
            color: Color(0xFFB0BEC5),
          );
    return Tooltip(
      message: isTidal
          ? (onOpen == null ? 'Tidal' : toolI18n.text('tidalOpen'))
          : toolI18n.text('disk'),
      waitDuration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: onOpen == null
            ? icon
            : MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(onTap: onOpen, child: icon),
              ),
      ),
    );
  }
}

class _TidalLogoPainter extends CustomPainter {
  const _TidalLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final bar = w / 4.6;
    final gap = w / 14;
    final slant = h * 0.18;
    void barAt(double x, double top) {
      final path = Path()
        ..moveTo(x + slant * 0.35, top)
        ..lineTo(x + bar + slant * 0.35, top)
        ..lineTo(x + bar - slant * 0.15, h)
        ..lineTo(x - slant * 0.15, h)
        ..close();
      canvas.drawPath(path, paint);
    }

    barAt(0, h * 0.55);
    barAt(bar + gap, h * 0.28);
    barAt((bar + gap) * 2, 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
