import 'package:flutter/material.dart';

/// InheritedWidget für rechtliche Seiten im Gast-Bereich – wechselt IndexedStack-Index statt Navigator.push.
class LegalPageScope extends InheritedWidget {
  final VoidCallback showImpressum;
  final VoidCallback showDsgvo;
  final VoidCallback showAgb;

  const LegalPageScope({
    super.key,
    required this.showImpressum,
    required this.showDsgvo,
    required this.showAgb,
    required super.child,
  });

  static LegalPageScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LegalPageScope>();

  @override
  bool updateShouldNotify(LegalPageScope oldWidget) =>
      showImpressum != oldWidget.showImpressum ||
      showDsgvo != oldWidget.showDsgvo ||
      showAgb != oldWidget.showAgb;
}
