import 'package:flutter/material.dart';

import '../../constants/venue_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../models/floor_occupancy_info.dart';
import '../../models/venue_floor.dart';
import '../../utils/floor_key_utils.dart';
import '../../utils/ui_constants.dart';

/// Floor-Auswahl für öffentliche Partys (Venue-Kontext bereits geladen).
class PublicVenueFloorField extends StatelessWidget {
  const PublicVenueFloorField({
    super.key,
    required this.floors,
    required this.selectedFloorKey,
    required this.defaultFloorAvailable,
    required this.occupiedFloorKeys,
    required this.hasVenueOverlap,
    required this.isLoading,
    required this.onFloorSelected,
    required this.onAddFloor,
    this.floorOccupancy = const {},
    this.onOccupiedFloorTap,
    this.showOccupiedInDropdown = true,
    /// Nur benannte Floors im Dropdown (kein „Hauptfloor“-Eintrag; Wahl per Radio davor).
    this.floorsOnlyInDropdown = false,
  });

  final List<VenueFloor> floors;
  final String? selectedFloorKey;
  final bool defaultFloorAvailable;
  final Set<String> occupiedFloorKeys;
  final bool hasVenueOverlap;
  final bool isLoading;
  final ValueChanged<String> onFloorSelected;
  final Future<void> Function() onAddFloor;
  final Map<String, FloorOccupancyInfo> floorOccupancy;
  final Future<void> Function(String floorKey, FloorOccupancyInfo info)?
      onOccupiedFloorTap;
  /// Belegte Floors im Dropdown anzeigen (nicht wählbar, mit DJ-Name).
  final bool showOccupiedInDropdown;
  final bool floorsOnlyInDropdown;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final items = <DropdownMenuItem<String>>[];

    String occupiedLabel(String floorLabel, FloorOccupancyInfo? info) {
      final dj = info?.djDisplayName?.trim();
      if (dj != null && dj.isNotEmpty) {
        return '$floorLabel — $dj (${l.party_floor_occupied_hint})';
      }
      return '$floorLabel (${l.party_floor_occupied_hint})';
    }

    if (!floorsOnlyInDropdown) {
      if (defaultFloorAvailable) {
        items.add(
          DropdownMenuItem(
            value: VenueConstants.defaultFloorKey,
            child: Text(l.party_floor_default_option),
          ),
        );
      } else if (showOccupiedInDropdown) {
        final info = floorOccupancy[VenueConstants.defaultFloorKey];
        items.add(
          DropdownMenuItem(
            value: VenueConstants.defaultFloorKey,
            enabled: false,
            child: Text(
              occupiedLabel(l.party_floor_default_option, info),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        );
      } else if (onOccupiedFloorTap != null &&
          floorOccupancy.containsKey(VenueConstants.defaultFloorKey)) {
        items.add(
          DropdownMenuItem(
            value: VenueConstants.defaultFloorKey,
            child: Text(
              '${l.party_floor_default_option} (${l.party_floor_swap_request})',
              style: TextStyle(color: Colors.orange.shade200),
            ),
          ),
        );
      }
    }

    for (final floor in floors) {
      if (floor.key == VenueConstants.defaultFloorKey) continue;
      final occupied = occupiedFloorKeys.contains(floor.key);
      final info = floorOccupancy[floor.key];
      if (floorsOnlyInDropdown) {
        if (!occupied) {
          items.add(
            DropdownMenuItem(
              value: floor.key,
              child: Text(floor.label),
            ),
          );
        }
        continue;
      }
      if (occupied && showOccupiedInDropdown) {
        items.add(
          DropdownMenuItem(
            value: floor.key,
            enabled: false,
            child: Text(
              occupiedLabel(floor.label, info),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        );
      } else if (occupied && onOccupiedFloorTap != null) {
        items.add(
          DropdownMenuItem(
            value: floor.key,
            child: Text(
              '${floor.label} (${l.party_floor_swap_request})',
              style: TextStyle(color: Colors.orange.shade200),
            ),
          ),
        );
      } else if (!occupied) {
        items.add(
          DropdownMenuItem(
            value: floor.key,
            child: Text(floor.label),
          ),
        );
      } else {
        items.add(
          DropdownMenuItem(
            value: floor.key,
            enabled: false,
            child: Text(
              occupiedLabel(floor.label, info),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        );
      }
    }

    final effectiveValue = selectedFloorKey != null &&
            items.any((i) => i.value == selectedFloorKey)
        ? selectedFloorKey
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasVenueOverlap) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border.all(color: UIConstants.appOrange, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l.party_venue_overlap_info_body,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!floorsOnlyInDropdown)
          Row(
            children: [
              Expanded(
                child: Text(
                  l.party_floor_label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.party_floor_add_new,
                onPressed: () => onAddFloor(),
                icon: const Icon(Icons.add_circle_outline,
                    color: UIConstants.appOrange),
              ),
            ],
          ),
        if (!floorsOnlyInDropdown) const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: UIConstants.appOrange,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: UIConstants.appOrange,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: effectiveValue,
                    hint: Text(
                      l.party_floor_select_hint,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    dropdownColor: Colors.grey.shade900,
                    style: const TextStyle(color: Colors.white),
                    items: items,
                    onChanged: (value) async {
                      if (value == null) return;
                      if (occupiedFloorKeys.contains(value)) {
                        if (showOccupiedInDropdown) return;
                        if (onOccupiedFloorTap != null) {
                          final info = floorOccupancy[value];
                          if (info != null) {
                            await onOccupiedFloorTap!(value, info);
                          }
                        }
                        return;
                      }
                      onFloorSelected(value);
                    },
                  ),
                ),
              ),
            ),
            if (floorsOnlyInDropdown) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: l.party_floor_add_new,
                onPressed: () => onAddFloor(),
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: UIConstants.appOrange,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String labelForKey(
    AppLocalizations l,
    List<VenueFloor> floors,
    String floorKey,
  ) {
    if (FloorKeyUtils.isDefaultFloorKey(floorKey)) {
      return l.party_floor_default_option;
    }
    for (final floor in floors) {
      if (floor.key == floorKey) return floor.label;
    }
    return floorKey;
  }
}
