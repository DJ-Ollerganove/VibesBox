import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/guest_floor_option.dart';
import '../utils/guest_floor_display.dart';
import '../utils/ui_constants.dart';

/// Raum-/Floor-Auswahl für Gäste (Check-in, Weiterleitung, Raumwechsel).
class GuestFloorPickerWidget extends StatelessWidget {
  const GuestFloorPickerWidget({
    super.key,
    required this.options,
    required this.onSelected,
    this.infoMessage,
    this.isLoading = false,
  });

  final List<GuestFloorOption> options;
  final ValueChanged<GuestFloorOption> onSelected;
  final String? infoMessage;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UIConstants.appOrange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.guest_floor_picker_title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.guest_floor_picker_choose,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          if (infoMessage != null && infoMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              infoMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.orange.shade200,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (options.isEmpty)
            Text(
              l.party_code_invalid_or_inactive,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            )
          else
            ...options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => onSelected(option),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: UIConstants.appOrange, width: 2),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                  ),
                  child: Text(
                    GuestFloorDisplay.optionTitle(l, option),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
