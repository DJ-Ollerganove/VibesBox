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
  });

  final List<VenueFloor> floors;
  final String? selectedFloorKey;
  final bool defaultFloorAvailable;
  final Set<String> occupiedFloorKeys;
  final bool hasVenueOverlap;
  final bool isLoading;
  final ValueChanged<String> onFloorSelected;
  final VoidCallback onAddFloor;
  final Map<String, FloorOccupancyInfo> floorOccupancy;
  final Future<void> Function(String floorKey, FloorOccupancyInfo info)?
      onOccupiedFloorTap;

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

    if (defaultFloorAvailable) {
      items.add(
        DropdownMenuItem(
          value: VenueConstants.defaultFloorKey,
          child: Text(l.party_floor_default_option),
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

    for (final floor in floors) {
      if (floor.key == VenueConstants.defaultFloorKey) continue;
      final occupied = occupiedFloorKeys.contains(floor.key);
      if (occupied && onOccupiedFloorTap != null) {
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
              '${floor.label} (${l.party_floor_occupied_hint})',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        );
      }
    }

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
              onPressed: onAddFloor,
              icon: const Icon(Icons.add_circle_outline,
                  color: UIConstants.appOrange),
            ),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: selectedFloorKey != null &&
                  items.any((i) => i.value == selectedFloorKey)
              ? selectedFloorKey
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: UIConstants.appOrange, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: UIConstants.appOrange, width: 2),
            ),
          ),
          dropdownColor: Colors.grey.shade900,
          style: const TextStyle(color: Colors.white),
          hint: Text(
            l.party_floor_select_hint,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          items: items,
          onChanged: (value) async {
            if (value == null) return;
            if (occupiedFloorKeys.contains(value) &&
                onOccupiedFloorTap != null) {
              final info = floorOccupancy[value];
              if (info != null) {
                await onOccupiedFloorTap!(value, info);
              }
              return;
            }
            onFloorSelected(value);
          },
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
