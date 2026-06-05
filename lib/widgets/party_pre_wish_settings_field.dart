import 'package:flutter/material.dart';
import 'package:vibesbox/l10n/app_localizations.dart';
import 'package:vibesbox/services/pre_wish_limit_service.dart';
import 'package:vibesbox/widgets/vibesbox_info_dialog.dart';

enum _PreWishLimitMode { unlimited, limited }

/// Vorab-Wünsche: Checkbox + Radio (unbegrenzt / Limit 1–50, Standard 5).
class PartyPreWishSettingsField extends StatefulWidget {
  const PartyPreWishSettingsField({
    super.key,
    required this.allowPreWishes,
    required this.limitPerGuest,
    required this.onAllowChanged,
    required this.onLimitChanged,
  });

  final bool allowPreWishes;
  /// 0 = unbegrenzt, 1–50 = Limit.
  final int limitPerGuest;
  final ValueChanged<bool> onAllowChanged;
  final ValueChanged<int> onLimitChanged;

  @override
  State<PartyPreWishSettingsField> createState() =>
      _PartyPreWishSettingsFieldState();
}

class _PartyPreWishSettingsFieldState extends State<PartyPreWishSettingsField> {
  _PreWishLimitMode get _mode =>
      PreWishLimitService.isUnlimited(widget.limitPerGuest)
          ? _PreWishLimitMode.unlimited
          : _PreWishLimitMode.limited;

  int get _limitedValue {
    final v = widget.limitPerGuest;
    if (v < PreWishLimitService.minLimited) {
      return PreWishLimitService.defaultLimited;
    }
    return v.clamp(
      PreWishLimitService.minLimited,
      PreWishLimitService.maxLimited,
    );
  }

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
    final limitItems = List.generate(
      PreWishLimitService.maxLimited,
      (i) => i + 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CheckboxListTile(
                value: widget.allowPreWishes,
                onChanged: (v) => widget.onAllowChanged(v ?? false),
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
        ),
        if (widget.allowPreWishes) ...[
          const SizedBox(height: 4),
          Text(
            l10n.party_pre_wish_limit_label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          RadioListTile<_PreWishLimitMode>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.party_pre_wish_limit_unlimited,
              style: const TextStyle(fontSize: 14),
            ),
            value: _PreWishLimitMode.unlimited,
            groupValue: _mode,
            onChanged: (_) => widget.onLimitChanged(0),
          ),
          RadioListTile<_PreWishLimitMode>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.party_pre_wish_limit_limited,
              style: const TextStyle(fontSize: 14),
            ),
            value: _PreWishLimitMode.limited,
            groupValue: _mode,
            onChanged: (_) {
              widget.onLimitChanged(
                PreWishLimitService.isUnlimited(widget.limitPerGuest)
                    ? PreWishLimitService.defaultLimited
                    : _limitedValue,
              );
            },
          ),
          if (_mode == _PreWishLimitMode.limited) ...[
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              value: _limitedValue,
              decoration: InputDecoration(
                labelText: l10n.party_pre_wish_limit_count,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: limitItems
                  .map(
                    (n) => DropdownMenuItem<int>(
                      value: n,
                      child: Text(n.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) widget.onLimitChanged(v);
              },
            ),
          ],
        ],
      ],
    );
  }
}
