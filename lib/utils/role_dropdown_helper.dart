import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Helper-Klasse für Rollen-Dropdowns
/// Stellt sicher, dass alle möglichen Rollen-Werte in der Items-Liste vorhanden sind
class RoleDropdownHelper {
  /// Gibt die Liste aller verfügbaren Rollen-Dropdown-Items zurück
  /// Diese Liste muss alle Werte enthalten, die als currentViewRole gesetzt werden können
  static List<DropdownMenuItem<String?>> getRoleDropdownItems({
    required AppLocalizations l,
    required bool includeAdmin,
  }) {
    final items = <DropdownMenuItem<String?>>[];
    if (includeAdmin) {
      items.add(
        DropdownMenuItem<String?>(
          value: 'Admin',
          child: Text(l.role_switch_admin_area),
        ),
      );
    }
    items.addAll([
      DropdownMenuItem<String?>(
        value: 'DJ',
        child: Text(l.role_switch_dj_view),
      ),
      DropdownMenuItem<String?>(
        value: 'Gast',
        child: Text(l.role_switch_guest_view),
      ),
      DropdownMenuItem<String?>(
        value: 'Location',
        child: Text(l.role_switch_location_view),
      ),
    ]);
    return items;
  }

  /// Prüft, ob ein gegebener Wert in der Items-Liste vorhanden ist
  /// Falls nicht, gibt es null zurück (sicherer Fallback)
  static String? validateRoleValue(
    String? value, {
    required bool includeAdmin,
  }) {
    final validValues = <String?>['DJ', 'Gast', 'Location'];
    if (includeAdmin) validValues.insert(0, 'Admin');
    if (validValues.contains(value)) {
      return value;
    }
    // Fallback: Wenn Wert nicht gültig ist, verwende DJ.
    return 'DJ';
  }

  /// Gibt den Anzeigenamen für eine Rolle zurück
  static String getRoleDisplayName(AppLocalizations l, String? role) {
    switch (role) {
      case 'Admin':
        return l.role_switch_admin_area;
      case 'DJ':
        return l.role_switch_dj_view;
      case 'Gast':
        return l.role_switch_guest_view;
      case 'Location':
        return l.role_switch_location_view;
      default:
        return l.role_switch_dj_view; // Fallback
    }
  }
}
