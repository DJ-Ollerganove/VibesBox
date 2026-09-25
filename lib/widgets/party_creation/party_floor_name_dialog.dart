import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/ui_constants.dart';

/// Dialog zum Anlegen eines neuen Venue-Floors (Controller wird im State disposed).
class PartyFloorNameDialog {
  PartyFloorNameDialog._();

  static Future<String?> show(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Gleicher Navigator wie der Party-Wizard-Dialog (kein Root-Navigator).
    return showDialog<String>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      builder: (ctx) => _PartyFloorNameDialogBody(
        title: l.party_floor_add_dialog_title,
        hint: l.party_floor_add_dialog_hint,
        cancelLabel: l.cancel,
        saveLabel: l.save,
      ),
    );
  }
}

class _PartyFloorNameDialogBody extends StatefulWidget {
  const _PartyFloorNameDialogBody({
    required this.title,
    required this.hint,
    required this.cancelLabel,
    required this.saveLabel,
  });

  final String title;
  final String hint;
  final String cancelLabel;
  final String saveLabel;

  @override
  State<_PartyFloorNameDialogBody> createState() =>
      _PartyFloorNameDialogBodyState();
}

class _PartyFloorNameDialogBodyState extends State<_PartyFloorNameDialogBody> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: UIConstants.bgGradientEnd,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(hintText: widget.hint),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }

  void _submit() {
    final label = _controller.text.trim();
    if (label.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, label);
  }
}
