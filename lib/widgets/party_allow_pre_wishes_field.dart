import 'package:flutter/material.dart';
import 'package:vibesbox/l10n/app_localizations.dart';
import 'package:vibesbox/widgets/vibesbox_info_dialog.dart';

/// Checkbox „Vorab-Wünsche erhalten“ mit Info-Dialog (Anlegen + Party bearbeiten).
class PartyAllowPreWishesField extends StatelessWidget {
  const PartyAllowPreWishesField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  void _showInfoDialog(BuildContext context, AppLocalizations l10n) {
    showVibesBoxInfoDialog(
      context,
      title: l10n.party_allow_pre_wishes_info_title,
      body: l10n.party_allow_pre_wishes_info_body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CheckboxListTile(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            title: Text(
              l10n.party_allow_pre_wishes,
              style: const TextStyle(fontSize: 14),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, size: 22),
          tooltip: l10n.party_allow_pre_wishes_info_title,
          onPressed: () => _showInfoDialog(context, l10n),
        ),
      ],
    );
  }
}
