import 'package:flutter/material.dart';

/// Info-i wie im Musikerkennungs-Widget: rechts in der Titelzeile.
class SettingsInfoIconButton extends StatelessWidget {
  const SettingsInfoIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.info_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
