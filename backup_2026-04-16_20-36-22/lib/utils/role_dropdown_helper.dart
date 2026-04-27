import 'package:flutter/material.dart';

/// Helper-Klasse für Rollen-Dropdowns
/// Stellt sicher, dass alle möglichen Rollen-Werte in der Items-Liste vorhanden sind
class RoleDropdownHelper {
  /// Gibt die Liste aller verfügbaren Rollen-Dropdown-Items zurück
  /// Diese Liste muss alle Werte enthalten, die als currentViewRole gesetzt werden können
  static List<DropdownMenuItem<String?>> getRoleDropdownItems({
    required bool includeAdmin,
  }) {
    final items = <DropdownMenuItem<String?>>[];
    if (includeAdmin) {
      items.add(
        const DropdownMenuItem<String?>(
          value: 'Admin',
          child: Text('Admin-Bereich'),
        ),
      );
    }
    items.addAll(const [
      DropdownMenuItem<String?>(
        value: 'DJ',
        child: Text('DJ Ansicht'),
      ),
      DropdownMenuItem<String?>(
        value: 'Gast',
        child: Text('Gast Ansicht'),
      ),
      DropdownMenuItem<String?>(
        value: 'Location',
        child: Text('Location Ansicht'),
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
  static String getRoleDisplayName(String? role) {
    switch (role) {
      case 'Admin':
        return 'Admin-Bereich';
      case 'DJ':
        return 'DJ Ansicht';
      case 'Gast':
        return 'Gast Ansicht';
      case 'Location':
        return 'Location Ansicht';
      default:
        return 'DJ Ansicht'; // Fallback
    }
  }
}


