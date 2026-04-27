import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/location_model.dart';
import '../../utils/ui_constants.dart';
import '../../widgets/common/pwa_widget_cell.dart';

/// Widget für die Auswahl einer gespeicherten Location
/// Zeigt einen Dialog mit allen gespeicherten Locations des aktuellen DJs
class LocationPicker extends StatelessWidget {
  final List<Map<String, dynamic>> locations;
  final Function(LocationModel location, bool useOneTimeEventCode) onLocationSelected;
  final VoidCallback? onCancel;

  const LocationPicker({
    super.key,
    required this.locations,
    required this.onLocationSelected,
    this.onCancel,
  });

  /// Zeigt den LocationPicker als Dialog mit PWA-Design
  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> locations,
    required Function(LocationModel location, bool useOneTimeEventCode) onLocationSelected,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: LocationPicker(
            locations: locations,
            onLocationSelected: (location, useOneTimeEventCode) {
              onLocationSelected(location, useOneTimeEventCode);
              Navigator.pop(dialogContext);
            },
            onCancel: () => Navigator.pop(dialogContext),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PwaWidgetCell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.location_on, color: UIConstants.appOrange, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Gespeicherte Locations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onCancel ?? () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Liste der Locations
          Flexible(
            child: locations.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'Keine gespeicherten Locations vorhanden',
                      style: TextStyle(color: Colors.grey.shade400),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: locations.length,
                    itemBuilder: (context, index) {
                      final location = locations[index];
                      return _LocationTile(
                        location: location,
                        onTap: () async {
                          // Lade vollständiges Location-Dokument
                          final locationDoc = await FirebaseFirestore.instance
                              .collection('locations')
                              .doc(location['id'] as String)
                              .get();
                          
                          if (!locationDoc.exists) return;
                          
                          final locationModel = LocationModel.fromFirestore(locationDoc);
                          final hasFixedCode = locationModel.fixedPartyCode != null;
                          
                          // Wenn Location einen festen Code hat, zeige Option für einmaligen Code
                          if (hasFixedCode) {
                            // Zeige Bestätigungs-Dialog mit Option für einmaligen Code
                            bool useCustomCode = false;
                            await showDialog(
                              context: context,
                              builder: (confirmContext) => StatefulBuilder(
                                builder: (context, setDialogState) => Dialog(
                                  backgroundColor: UIConstants.djShellPageBackground,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: UIConstants.appOrange, width: 2),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.location_on, color: UIConstants.appOrange, size: 24),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Location auswählen',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          locationModel.locationName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (locationModel.address != null && locationModel.address!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            locationModel.address!,
                                            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        // Checkbox für einmaligen Code
                                        CheckboxListTile(
                                          title: const Text(
                                            'Einmaligen Code für dieses Event generieren?',
                                            style: TextStyle(color: Colors.white, fontSize: 14),
                                          ),
                                          subtitle: Text(
                                            'Ansonsten wird der feste Code dieser Location verwendet',
                                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                          ),
                                          value: useCustomCode,
                                          activeColor: UIConstants.appOrange,
                                          checkColor: Colors.black,
                                          onChanged: (value) {
                                            setDialogState(() {
                                              useCustomCode = value ?? false;
                                            });
                                          },
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                'Abbrechen',
                                                style: TextStyle(color: Colors.grey.shade400),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: UIConstants.appOrange,
                                                foregroundColor: Colors.black,
                                              ),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                onLocationSelected(locationModel, useCustomCode);
                                              },
                                              child: const Text('Auswählen'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            // Kein fester Code - direkt übernehmen
                            onLocationSelected(locationModel, false);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final Map<String, dynamic> location;
  final VoidCallback onTap;

  const _LocationTile({
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.location_city, color: UIConstants.appOrange),
      title: Text(
        location['location_name'] as String,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: location['address'] != null && (location['address'] as String).isNotEmpty
          ? Text(
              location['address'] as String,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: UIConstants.appOrange),
      onTap: onTap,
    );
  }
}
