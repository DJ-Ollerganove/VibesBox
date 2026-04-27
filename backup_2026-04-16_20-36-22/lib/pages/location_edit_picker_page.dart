import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/location_result.dart';
import '../utils/ui_constants.dart';
import 'location_map_picker_page.dart';
import '../widgets/places_autocomplete_field.dart';

/// Vollbild-Seite zum Ändern des Party-Ortes (Suche + Karte).
/// Gibt bei Auswahl ein [LocationResult] zurück.
class LocationEditPickerPage extends StatelessWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationName;

  const LocationEditPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.appBarBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.change_location),
        backgroundColor: UIConstants.appBarBackgroundColor,
        foregroundColor: UIConstants.appBarForegroundColor,
        iconTheme: UIConstants.appBarIconTheme,
        titleTextStyle: UIConstants.appBarTitleTextStyle,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Suche
            PlacesAutocompleteField(
              initialValue: initialLocationName,
              onPlaceSelected: (LocationResult? result) async {
                if (result == null) return;
                // Suche → Karte öffnen (automatischer Workflow wie neue_party_page)
                final refined = await Navigator.push<LocationResult?>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationMapPickerPage(
                      initialLatitude: result.latitude,
                      initialLongitude: result.longitude,
                      initialLocationName: result.name,
                    ),
                  ),
                );
                if (refined != null && context.mounted) {
                  Navigator.pop(context, refined);
                }
              },
            ),
            const SizedBox(height: 12),
            // Karten-Button
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<LocationResult?>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationMapPickerPage(
                      initialLatitude: initialLatitude,
                      initialLongitude: initialLongitude,
                      initialLocationName: initialLocationName,
                    ),
                  ),
                );
                if (result != null && context.mounted) {
                  Navigator.pop(context, result);
                }
              },
              icon: const Icon(Icons.map, color: UIConstants.appOrange),
                                label: const Text('Auf Karte wählen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: UIConstants.appOrange,
                side: const BorderSide(color: UIConstants.appOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
