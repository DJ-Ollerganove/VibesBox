import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tool_i18n.dart';

class DragSpyBanner extends StatefulWidget {
  const DragSpyBanner({super.key});

  @override
  State<DragSpyBanner> createState() => _DragSpyBannerState();
}

class _DragSpyBannerState extends State<DragSpyBanner> {
  static const _events = EventChannel('vibesbox_sync/drag_spy');
  StreamSubscription<dynamic>? _sub;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _sub = _events.receiveBroadcastStream().listen((event) {
      if (!mounted) return;
      setState(() => _text = event?.toString() ?? '');
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFFFFCC80),
        ),
        onPressed: () async {
          final text = _text.trim();
          if (text.isEmpty) return;
          await Clipboard.setData(ClipboardData(text: text));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(toolI18n.text('copied', {'text': text})),
              duration: const Duration(milliseconds: 900),
            ),
          );
        },
        child: Text(
          toolI18n.text('dragTitle'),
          style: const TextStyle(
            fontSize: 12,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
