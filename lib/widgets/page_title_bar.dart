import 'package:flutter/material.dart';
import 'pulsating_title_bar.dart';

/// Standard Titelleiste - Delegiert an PulsatingTitleBar
class PageTitleBar extends StatelessWidget {
  final IconData icon;
  final String title;

  const PageTitleBar({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return PulsatingTitleBar(
      icon: icon,
      title: title,
    );
  }
}
